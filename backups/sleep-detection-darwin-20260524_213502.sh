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

    check_system_resume() {
        local boot_ts last_boot stored_boot
        boot_ts=$(_darwin_get_boot_timestamp)
        if [ -z "${boot_ts}" ]; then
            return 1
        fi

        if [ -f "${LAST_UPTIME_FILE:-}" ]; then
            stored_boot=$(grep -E '^LAST_BOOT_TIMESTAMP=' "${LAST_UPTIME_FILE}" 2>/dev/null | cut -d= -f2 | tr -d ' ')
            if [ -n "${stored_boot}" ] && [ "${stored_boot}" != "${boot_ts}" ]; then
                return 0
            fi
        fi
        return 1
    }

    get_last_resume_time() {
        _darwin_get_boot_timestamp
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
