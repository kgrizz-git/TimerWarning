#!/bin/bash

###############################################################################
# Sleep Warning System - Linux popup lifecycle (post-spawn orchestration)
#
# Extracted from lib/popup-display.sh show_warning() to keep the orchestrator
# small. Spawn/update/respawn dialogs live in popup-dialog-implementations.sh.
#
# Dynamic scoping: functions expect caller (show_warning) to define:
#   dialog_tool, window_title, popup_size, popup_position, min_display_time,
#   popup_auto_close, window_tool, base_message, pause_available, pause_duration,
#   popup_pid, _popup_lock_fd, _popup_watchdog_pid, zenity_output_file
###############################################################################

# Release Phase 2.4 spawn flock when held.
_popup_linux_release_spawn_lock() {
    if [ -n "${_popup_lock_fd:-}" ]; then
        flock -u "${_popup_lock_fd}" 2>/dev/null
        exec {_popup_lock_fd}>&- 2>/dev/null
        _popup_lock_fd=""
    fi
}

# Acquire per-process-group spawn lock (Linux flock). Sets _popup_lock_fd in caller scope.
_popup_linux_acquire_spawn_lock() {
    _popup_lock_fd=""
    local _popup_lock_file="${CONFIG_DIR}/.popup.lock"
    if command -v flock >/dev/null 2>&1; then
        exec {_popup_lock_fd}>"${_popup_lock_file}" 2>/dev/null || true
        if [ -n "${_popup_lock_fd}" ]; then
            if ! flock -w 5 "${_popup_lock_fd}" 2>/dev/null; then
                log_to_file "WARNING" "Popup lock timed out after 5s — another instance may be active; proceeding without lock"
                exec {_popup_lock_fd}>&- 2>/dev/null
                _popup_lock_fd=""
            fi
        fi
    fi
}

# If an existing popup is younger than display frequency, skip spawning a new one.
# Returns 0 when caller should return 0 (skip); 1 when spawn may proceed.
_popup_linux_should_skip_for_existing_popup() {
    local existing_popup_info
    existing_popup_info=$(is_popup_running)

    if [ -z "${existing_popup_info}" ]; then
        return 1
    fi

    local existing_pid existing_age
    existing_pid=$(echo "${existing_popup_info}" | cut -d'|' -f1)
    existing_age=$(echo "${existing_popup_info}" | cut -d'|' -f2)

    local popup_freq_minutes popup_freq_seconds
    popup_freq_minutes=$(get_popup_display_frequency)
    popup_freq_seconds=$((popup_freq_minutes * 60))

    if [ "${existing_age}" -gt "${popup_freq_seconds}" ]; then
        log_to_file "INFO" "Existing popup (PID ${existing_pid}) has been open ${existing_age}s (longer than display frequency ${popup_freq_seconds}s), closing and showing new popup"
        close_existing_popups >/dev/null
        return 1
    fi

    log_to_file "INFO" "Skipping new popup: Existing popup (PID ${existing_pid}) has been open ${existing_age}s (less than display frequency ${popup_freq_seconds}s)"
    _popup_linux_release_spawn_lock
    return 0
}

# Cancel absolute watchdog if still running.
_popup_linux_cancel_watchdog() {
    if [ -n "${_popup_watchdog_pid:-}" ] && kill -0 "${_popup_watchdog_pid}" 2>/dev/null; then
        kill "${_popup_watchdog_pid}" 2>/dev/null
        wait "${_popup_watchdog_pid}" 2>/dev/null || true
        _popup_watchdog_pid=""
    fi
}

# Log spawn success, save PID, release lock, start absolute watchdog.
_popup_linux_on_spawn_success() {
    local auto_close_status="disabled"
    if [ "${popup_auto_close}" = "true" ]; then
        if [ "${min_display_time}" -gt 0 ]; then
            auto_close_status="enabled (10s after ${min_display_time}s min display = $((min_display_time + 10))s total)"
        else
            auto_close_status="enabled (10s after popup appears)"
        fi
    fi
    log_to_file "INFO" "Popup displayed successfully (PID: ${popup_pid}), Dialog tool: ${dialog_tool}, Size: ${popup_size}, Position: ${popup_position}, Min display time: ${min_display_time}s, Auto-close: ${auto_close_status}"

    save_popup_pid "${popup_pid}"
    _popup_linux_release_spawn_lock

    local _popup_watchdog_seconds
    if type popup_compute_watchdog_seconds >/dev/null 2>&1; then
        _popup_watchdog_seconds=$(popup_compute_watchdog_seconds "${min_display_time}" "${popup_auto_close}")
    else
        _popup_watchdog_seconds="${POPUP_ABSOLUTE_MAX_SECONDS:-120}"
    fi
    if type popup_start_pid_file_watchdog >/dev/null 2>&1; then
        popup_start_pid_file_watchdog "${_popup_watchdog_seconds}" "${POPUP_PID_FILE}" >/dev/null
        _popup_watchdog_pid="${POPUP_WATCHDOG_LAST_PID:-}"
    else
        _popup_watchdog_pid=""
    fi
}

# Handle spawn failure: release lock, optional notify-send fallback.
# Returns 0 on notify-send fallback success, 1 on hard failure.
_popup_linux_on_spawn_failure() {
    log_to_file "ERROR" "Failed to display popup, Dialog tool: ${dialog_tool}"
    _popup_linux_release_spawn_lock
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "ALERT: Restricted time window" "You are using your computer during restricted hours. Please consider resting." >/dev/null 2>&1
        log_to_file "WARNING" "notify-send fallback used (non-modal)"
        return 0
    fi
    log_to_file "ERROR" "notify-send fallback unavailable"
    return 1
}

# Keep popup window on top after spawn.
_popup_linux_start_stay_on_top() {
    if [ -n "${window_tool}" ] && [ -n "${popup_pid}" ]; then
        sleep 1.0
        keep_window_on_top "${window_title}" "${window_tool}"
        local on_top_duration=${min_display_time}
        if [ "${on_top_duration}" -eq 0 ]; then
            on_top_duration=300
        fi
        keep_window_on_top_periodic "${window_title}" "${window_tool}" "${popup_pid}" "${on_top_duration}" &
    fi
}

# Close and reopen popup with updated countdown (min-display respawn).
_popup_linux_update_countdown() {
    local remaining_seconds=$1
    local old_pid="${popup_pid}"

    local countdown_msg="\n\n⏱️  This popup must remain visible for ${remaining_seconds} more second(s) before it can be closed."
    local updated_message="${base_message}${countdown_msg}"
    updated_message="$(dialog_safe_text "${updated_message}")"

    cleanup_popup_pid "${old_pid}"

    if kill -0 "${popup_pid}" 2>/dev/null; then
        kill "${popup_pid}" 2>/dev/null
        wait "${popup_pid}" 2>/dev/null
    fi

    _popup_spawn_warning_dialog "${updated_message}"

    if [ -n "${window_tool}" ]; then
        sleep 0.3
        make_window_unclosable "${window_title}" "${window_tool}" "${remaining_seconds}"
        keep_window_on_top "${window_title}" "${window_tool}"
        keep_window_on_top_periodic "${window_title}" "${window_tool}" "${popup_pid}" "${remaining_seconds}" &
    fi

    if [ -n "${popup_pid}" ] && [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
        save_popup_pid "${popup_pid}"
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "INFO" "Popup respawned: Old PID ${old_pid} cleaned up, new PID ${popup_pid} saved"
        fi
    fi
}

# Min-display enforcement loop (countdown redraw + respawn-on-dismiss).
_popup_linux_enforce_min_display_time() {
    if [ -n "${window_tool}" ]; then
        make_window_unclosable "${window_title}" "${window_tool}" "${min_display_time}"
    fi

    local start_timestamp
    start_timestamp=$(date +%s)
    local elapsed=0
    local remaining=${min_display_time}
    local last_redraw_elapsed=0
    local last_remaining=${min_display_time}

    while [ "${elapsed}" -lt "${min_display_time}" ]; do
        sleep 1
        local current_timestamp
        current_timestamp=$(date +%s)
        elapsed=$((current_timestamp - start_timestamp))
        remaining=$((min_display_time - elapsed))

        if [ "${elapsed}" -ge "${min_display_time}" ]; then
            elapsed="${min_display_time}"
            remaining=0
        fi

        if ! kill -0 "${popup_pid}" 2>/dev/null; then
            local popup_exit_code=0
            wait "${popup_pid}" 2>/dev/null
            popup_exit_code=$?

            if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                if _popup_maybe_handle_pause_click "${popup_exit_code}"; then
                    _popup_linux_cancel_watchdog
                    return 0
                fi
            fi

            _popup_linux_update_countdown "${remaining}"
        else
            local should_redraw=false

            if [ "${min_display_time}" -le 30 ]; then
                if [ $((elapsed - last_redraw_elapsed)) -ge 10 ] && [ "${elapsed}" -gt 0 ]; then
                    should_redraw=true
                    last_redraw_elapsed=${elapsed}
                elif [ "${remaining}" -le 0 ]; then
                    should_redraw=true
                fi
            else
                local threshold_75=$((min_display_time * 75 / 100))
                local threshold_50=$((min_display_time * 50 / 100))
                local threshold_25=$((min_display_time * 25 / 100))

                if [ "${remaining}" -le "${threshold_75}" ] && [ "${last_remaining}" -gt "${threshold_75}" ]; then
                    should_redraw=true
                    last_remaining=${remaining}
                elif [ "${remaining}" -le "${threshold_50}" ] && [ "${last_remaining}" -gt "${threshold_50}" ]; then
                    should_redraw=true
                    last_remaining=${remaining}
                elif [ "${remaining}" -le "${threshold_25}" ] && [ "${last_remaining}" -gt "${threshold_25}" ]; then
                    should_redraw=true
                    last_remaining=${remaining}
                elif [ "${remaining}" -le 0 ] && [ "${last_remaining}" -gt 0 ]; then
                    should_redraw=true
                    last_remaining=${remaining}
                fi
            fi

            if [ "${should_redraw}" = "true" ]; then
                _popup_linux_update_countdown "${remaining}"
            fi
        fi
    done

    if [ -n "${window_tool}" ]; then
        reenable_window_closing "${window_title}" "${window_tool}"
    fi

    return 1
}

# Wait for user close (or auto-close) after min display elapsed.
_popup_linux_wait_after_min_display() {
    local auto_close_timer_pid=""
    if [ "${popup_auto_close}" = "true" ] && kill -0 "${popup_pid}" 2>/dev/null; then
        log_to_file "INFO" "Auto-close enabled: Popup will close automatically 10 seconds after minimum display time (total: $((min_display_time + 10)) seconds)"
        auto_close_popup "${popup_pid}" "${dialog_tool}" "${window_title}" "${window_tool}" &
        auto_close_timer_pid=$!
        log_to_file "INFO" "Auto-close timer started (timer PID: ${auto_close_timer_pid})"
    fi

    if kill -0 "${popup_pid}" 2>/dev/null; then
        wait "${popup_pid}" 2>/dev/null
        local popup_exit_code=$?

        if [ -n "${auto_close_timer_pid}" ] && kill -0 "${auto_close_timer_pid}" 2>/dev/null; then
            log_to_file "INFO" "User closed popup manually, cancelling auto-close timer (timer PID: ${auto_close_timer_pid})"
            kill "${auto_close_timer_pid}" 2>/dev/null
            wait "${auto_close_timer_pid}" 2>/dev/null
        fi

        if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
            if _popup_maybe_handle_pause_click "${popup_exit_code}"; then
                _popup_linux_cancel_watchdog
                return 0
            fi
        fi

        if [ ${popup_exit_code} -eq 0 ]; then
            log_to_file "INFO" "Popup closed by user after minimum display time"
        else
            log_to_file "WARNING" "Popup exited with code ${popup_exit_code}"
        fi

        cleanup_popup_pid "${popup_pid}"
        _popup_linux_cancel_watchdog
    else
        log_to_file "WARNING" "Popup process (PID ${popup_pid}) already exited before wait"
    fi

    return 1
}

# Wait path when min_display_time is 0.
_popup_linux_wait_without_min_display() {
    local auto_close_timer_pid=""
    if [ "${popup_auto_close}" = "true" ] && [ -n "${popup_pid}" ] && kill -0 "${popup_pid}" 2>/dev/null; then
        log_to_file "INFO" "Auto-close enabled: Popup will close automatically after 10 seconds (minimum display time is 0)"
        auto_close_popup "${popup_pid}" "${dialog_tool}" "${window_title}" "${window_tool}" &
        auto_close_timer_pid=$!
        log_to_file "INFO" "Auto-close timer started (timer PID: ${auto_close_timer_pid})"
    fi

    if [ -n "${popup_pid}" ]; then
        if kill -0 "${popup_pid}" 2>/dev/null; then
            wait "${popup_pid}" 2>/dev/null
            local popup_exit_code=$?

            if [ -n "${auto_close_timer_pid}" ] && kill -0 "${auto_close_timer_pid}" 2>/dev/null; then
                log_to_file "INFO" "User closed popup manually, cancelling auto-close timer (timer PID: ${auto_close_timer_pid})"
                kill "${auto_close_timer_pid}" 2>/dev/null
                wait "${auto_close_timer_pid}" 2>/dev/null
            fi

            if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                if _popup_maybe_handle_pause_click "${popup_exit_code}"; then
                    _popup_linux_cancel_watchdog
                    return 0
                fi
            fi

            if [ ${popup_exit_code} -eq 0 ]; then
                log_to_file "INFO" "Popup closed by user"
            else
                log_to_file "WARNING" "Popup exited with code ${popup_exit_code}"
            fi

            cleanup_popup_pid "${popup_pid}"
            _popup_linux_cancel_watchdog
        else
            log_to_file "WARNING" "Popup process (PID ${popup_pid}) already exited before wait"
        fi
    fi

    return 1
}

# Post-spawn lifecycle: stay-on-top, min-display, wait, pause semantics, watchdog cleanup.
_popup_linux_run_post_spawn_lifecycle() {
    _popup_linux_start_stay_on_top

    if [ "${min_display_time}" -gt 0 ] && [ -n "${popup_pid}" ]; then
        if _popup_linux_enforce_min_display_time; then
            return 0
        fi
        if _popup_linux_wait_after_min_display; then
            return 0
        fi
    else
        if _popup_linux_wait_without_min_display; then
            return 0
        fi
    fi

    _popup_linux_cancel_watchdog
    return 0
}
