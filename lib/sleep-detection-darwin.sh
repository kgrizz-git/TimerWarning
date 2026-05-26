#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Sleep/Resume Detection (Phase 3)
#
# Uses sysctl kern.boottime and uptime file tracking for resume grace period.
###############################################################################

if [ -z "${SLEEP_DETECTION_DARWIN_LOADED:-}" ]; then
    SLEEP_DETECTION_DARWIN_LOADED=1

    _darwin_get_boot_timestamp() {
        local boot_sec
        boot_sec=$(sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | tr -d ',')
        if [ -n "${boot_sec}" ] && [[ "${boot_sec}" =~ ^[0-9]+$ ]]; then
            echo "${boot_sec}"
            return 0
        fi
        echo ""
    }

    # True when a pmset log line is a user-visible sleep/wake resume (not MaintenanceWake,
    # Wake Requests, "Delays to Wake notifications", etc.).
    _darwin_pmset_line_is_user_sleep_wake() {
        local line="$1"
        # Event type is field 4 after "YYYY-MM-DD HH:MM:SS TZ".
        # Real resume: "2026-05-26 13:03:49 -0400 Wake  Wake from Deep Idle ..."
        # False positive: "... Assertions  ... MaintenanceWake ..."
        # False positive: "... Wake Requests  ..."
        echo "${line}" | awk '
            /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/ {
                if ($4 == "Wake" && $5 != "Requests") {
                    exit 0
                }
                exit 1
            }
            { exit 1 }
        '
    }

    _darwin_epoch_from_pmset_line() {
        local line="$1"
        local wake_dt
        wake_dt=$(echo "${line}" | awk '{print $1, $2}')
        date -j -f "%Y-%m-%d %H:%M:%S" "${wake_dt}" +%s 2>/dev/null
    }

    # Phase 3.5: parse pmset log for the most recent user sleep/wake timestamp (epoch).
    # Returns epoch seconds or empty string if not found / pmset unavailable.
    _darwin_get_last_wake_timestamp() {
        if ! command -v pmset >/dev/null 2>&1; then
            echo ""
            return 1
        fi
        # "pmset -g log" can be verbose; limit scan to the last 500 lines for speed.
        local wake_line line
        while IFS= read -r line; do
            if _darwin_pmset_line_is_user_sleep_wake "${line}"; then
                wake_line="${line}"
            fi
        done < <(pmset -g log 2>/dev/null | tail -500)

        if [ -z "${wake_line:-}" ]; then
            echo ""
            return 1
        fi

        local wake_epoch
        wake_epoch=$(_darwin_epoch_from_pmset_line "${wake_line}") || {
            echo ""
            return 1
        }
        if [ -z "${wake_epoch}" ] || ! [[ "${wake_epoch}" =~ ^[0-9]+$ ]]; then
            echo ""
            return 1
        fi
        echo "${wake_epoch}"
        return 0
    }

    # Phase 3.5: check_system_resume now EMITS the resume epoch timestamp to stdout
    # (in addition to returning 0/1), so callers can compare against current time.
    # Detects both reboots (boot time change) and sleep/wake events (pmset log).
    check_system_resume() {
        local boot_ts
        boot_ts=$(_darwin_get_boot_timestamp)

        # --- Detect reboot: boot timestamp changed since last check ---
        if [ -n "${boot_ts}" ]; then
            if [ -f "${LAST_UPTIME_FILE:-}" ]; then
                local stored_boot
                stored_boot=$(grep -E '^LAST_BOOT_TIMESTAMP=' "${LAST_UPTIME_FILE}" 2>/dev/null \
                    | cut -d= -f2 | tr -d ' ')
                if [ -n "${stored_boot}" ] && [ "${stored_boot}" != "${boot_ts}" ]; then
                    echo "${boot_ts}"   # emit timestamp
                    return 0
                fi
            fi
        fi

        # --- Detect sleep/wake: check pmset log for a recent Wake event ---
        local wake_ts
        wake_ts=$(_darwin_get_last_wake_timestamp)
        if [ -n "${wake_ts}" ]; then
            # Only count as a new wake if it happened after the last stored check time
            local stored_check
            stored_check=$(grep -E '^LAST_CHECK_TIMESTAMP=' "${LAST_UPTIME_FILE:-/dev/null}" 2>/dev/null \
                | cut -d= -f2 | tr -d ' ')
            if [ -z "${stored_check}" ] || [ "${wake_ts}" -gt "${stored_check}" ]; then
                echo "${wake_ts}"   # emit timestamp
                return 0
            fi
        fi

        return 1
    }

    get_last_resume_time() {
        # Returns the most recent resume timestamp (reboot or sleep/wake)
        local _ts
        _ts=$(check_system_resume) && echo "${_ts}"
    }

    update_uptime_tracking() {
        local boot_ts
        boot_ts=$(_darwin_get_boot_timestamp)
        if [ -z "${boot_ts}" ]; then
            return 1
        fi
        mkdir -p "$(dirname "${LAST_UPTIME_FILE}")" 2>/dev/null
        {
            echo "LAST_BOOT_TIMESTAMP=${boot_ts}"
            echo "LAST_CHECK_TIMESTAMP=$(date +%s)"
        } > "${LAST_UPTIME_FILE}" 2>/dev/null
    }

    is_within_resume_grace_period() {
        local resume_timestamp="$1"
        if [ -z "${resume_timestamp}" ] || ! [[ "${resume_timestamp}" =~ ^[0-9]+$ ]]; then
            return 1
        fi
        local current_time time_since_resume
        current_time=$(date +%s)
        time_since_resume=$((current_time - resume_timestamp))
        if [ "${time_since_resume}" -ge 0 ] && [ "${time_since_resume}" -le "${SLEEP_RESUME_GRACE_PERIOD:-60}" ]; then
            return 0
        fi
        return 1
    }

    should_skip_warning_after_resume() {
        local resume_timestamp
        resume_timestamp=$(check_system_resume)
        local resume_detected=$?
        if [ "${resume_detected}" -eq 0 ] && [ -n "${resume_timestamp}" ]; then
            if is_within_resume_grace_period "${resume_timestamp}"; then
                if type log_to_file >/dev/null 2>&1; then
                    log_to_file "INFO" "Skipping warning: macOS resume grace period active"
                fi
                return 0
            fi
        fi
        update_uptime_tracking
        return 1
    }
fi
