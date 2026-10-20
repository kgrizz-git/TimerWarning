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
    # A killed parent cannot run normal marker cleanup. Never remove a recent
    # expiry latch that a still-running popup session may be consulting.
    local marker
    for marker in "${CONFIG_DIR}"/.popup_pid.expired.*; do
        [ -f "${marker}" ] || continue
        find "${marker}" -mmin +10 -delete 2>/dev/null || true
    done
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
    if [ -n "${_popup_watchdog_expired_file:-}" ]; then
        rm -f "${_popup_watchdog_expired_file}"
        _popup_watchdog_expired_file=""
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
    if ! save_popup_pid "${popup_pid}"; then
        close_popup_process "${popup_pid}" "${dialog_tool}" || true
        _popup_linux_release_spawn_lock
        return 1
    fi
    _popup_linux_release_spawn_lock

    local _popup_watchdog_seconds
    if type popup_compute_watchdog_seconds >/dev/null 2>&1; then
        _popup_watchdog_seconds=$(popup_compute_watchdog_seconds "${min_display_time}" "${popup_auto_close}")
    else
        _popup_watchdog_seconds="${POPUP_ABSOLUTE_MAX_SECONDS:-120}"
    fi
    if type popup_start_pid_file_watchdog >/dev/null 2>&1; then
        _popup_watchdog_expired_file=$(mktemp "${POPUP_PID_FILE}.expired.XXXXXX") || {
            close_popup_process "${popup_pid}" "${dialog_tool}" || true
            cleanup_popup_pid "${popup_pid}"
            return 1
        }
        if ! popup_start_pid_file_watchdog "${_popup_watchdog_seconds}" "${POPUP_PID_FILE}" "${_popup_watchdog_expired_file}" >/dev/null; then
            close_popup_process "${popup_pid}" "${dialog_tool}" || true
            cleanup_popup_pid "${popup_pid}"
            _popup_linux_cancel_watchdog
            return 1
        fi
        _popup_watchdog_pid="${POPUP_WATCHDOG_LAST_PID:-}"
        if ! [[ "${_popup_watchdog_pid}" =~ ^[0-9]+$ ]] || ! kill -0 "${_popup_watchdog_pid}" 2>/dev/null; then
            close_popup_process "${popup_pid}" "${dialog_tool}" || true
            cleanup_popup_pid "${popup_pid}"
            _popup_linux_cancel_watchdog
            return 1
        fi
    else
        _popup_watchdog_pid=""
        close_popup_process "${popup_pid}" "${dialog_tool}" || true
        cleanup_popup_pid "${popup_pid}"
        return 1
    fi
    log_to_file "INFO" "Popup displayed successfully (PID: ${popup_pid}), Dialog tool: ${dialog_tool}, Size: ${popup_size}, Position: ${popup_position}, Min display time: ${min_display_time}s, Auto-close: ${auto_close_status}"
    return 0
}

# Last-resort non-modal alert when no dialog can be shown (spawn failure or
# no usable display). Returns 0 only when notify-send accepts the message.
# Gaming Mode often has no notification daemon; a missing or failing
# notify-send is logged and returns 1.
_popup_linux_notify_send_fallback() {
    if ! command -v notify-send >/dev/null 2>&1; then
        log_to_file "ERROR" "notify-send fallback unavailable"
        return 1
    fi
    if notify-send "ALERT: Restricted time window" "You are using your computer during restricted hours. Please consider resting." >/dev/null 2>&1; then
        log_to_file "WARNING" "notify-send fallback used (non-modal)"
        return 0
    fi
    log_to_file "ERROR" "notify-send fallback failed"
    return 1
}

# Handle spawn failure: release lock, optional notify-send fallback.
# Returns 0 on notify-send fallback success, 1 on hard failure.
_popup_linux_on_spawn_failure() {
    log_to_file "ERROR" "Failed to display popup, Dialog tool: ${dialog_tool}"
    _popup_linux_release_spawn_lock
    _popup_linux_notify_send_fallback
}

# Log-only gamescope exit line. No-op when the debug flag is off.
# Parameters: $1 exit code, $2 pause handler ran (true/false)
_popup_linux_note_gamescope_debug_exit() {
    if type gamescope_overlay_debug_log_exit >/dev/null 2>&1; then
        gamescope_overlay_debug_log_exit "${1:-}" "${2:-false}" "${gamescope_debug_event:-spawn}" || true
    fi
}

# Tag the current popup for the gamescope overlay plane without blocking the
# min-display loop. apply_gamescope_overlay_atoms polls for up to a few seconds;
# that wait runs in this background job, then atoms are refreshed every 2s
# until duration elapses or popup_pid exits. Each respawn gets its own job;
# the previous job exits once its captured PID is gone.
# Parameters: $1 duration in seconds (min-display or remaining countdown).
_popup_linux_arm_gamescope_atoms() {
    local duration="${1:-0}"
    if [ "${env_type:-}" != "gamescope" ] || [ -z "${popup_pid:-}" ]; then
        return 0
    fi
    if ! type apply_gamescope_overlay_atoms >/dev/null 2>&1; then
        return 0
    fi
    local title="${window_title}"
    local tool="${window_tool:-}"
    local pid="${popup_pid}"
    (
        apply_gamescope_overlay_atoms "${title}" "${tool}" "${pid}" || true
        if [ -z "${tool}" ]; then
            local elapsed=0
            while [ "${elapsed}" -lt "${duration}" ] && kill -0 "${pid}" 2>/dev/null; do
                sleep 2
                elapsed=$((elapsed + 2))
                if kill -0 "${pid}" 2>/dev/null; then
                    apply_gamescope_overlay_atoms "${title}" "" "${pid}" >/dev/null 2>&1 || true
                fi
            done
        fi
    ) &
}

# Keep popup window on top after spawn.
_popup_linux_start_stay_on_top() {
    local on_top_duration=${min_display_time}
    if [ "${on_top_duration}" -eq 0 ]; then
        on_top_duration=300
    fi
    _popup_linux_arm_gamescope_atoms "${on_top_duration}"
    if [ -n "${window_tool}" ] && [ -n "${popup_pid}" ]; then
        sleep 1.0
        keep_window_on_top "${window_title}" "${window_tool}"
        keep_window_on_top_periodic "${window_title}" "${window_tool}" "${popup_pid}" "${on_top_duration}" &
    fi
}

# Close and reopen popup with updated countdown (min-display respawn).
_popup_linux_update_countdown() {
    local remaining_seconds=$1
    local old_pid="${popup_pid}"
    if [ -n "${_popup_watchdog_expired_file:-}" ] && [ -s "${_popup_watchdog_expired_file}" ]; then
        return 1
    fi

    local countdown_msg="\n\n⏱️  This popup must remain visible for ${remaining_seconds} more second(s) before it can be closed."
    local updated_message="${base_message}${countdown_msg}"
    updated_message="$(dialog_safe_text "${updated_message}")"

    # Keep the current PID registered until it is dead. The absolute watchdog
    # must still be able to KILL a dialog that ignores this redraw's TERM.
    if kill -0 "${popup_pid}" 2>/dev/null; then
        kill "${popup_pid}" 2>/dev/null
        wait "${popup_pid}" 2>/dev/null
    fi
    cleanup_popup_pid "${old_pid}"

    if [ -n "${_popup_watchdog_expired_file:-}" ] && [ -s "${_popup_watchdog_expired_file}" ]; then
        return 1
    fi

    local spawn_attempt
    for spawn_attempt in 1 2 3; do
        if [ -n "${_popup_watchdog_expired_file:-}" ] && [ -s "${_popup_watchdog_expired_file}" ]; then
            return 1
        fi
        _popup_spawn_warning_dialog "${updated_message}" || true
        [ -z "${popup_pid}" ] || break
        [ "${spawn_attempt}" -ge 3 ] || sleep 1
    done
    if [ -z "${popup_pid}" ]; then
        _popup_linux_notify_send_fallback || true
        return 1
    fi

    # Register immediately, before window-tool delays. Expiry may have raced
    # with spawning while the previous PID file was absent: in that case the
    # one-shot watchdog has already ended, so terminate this new child here.
    if ! save_popup_pid "${popup_pid}"; then
        close_popup_process "${popup_pid}" "${dialog_tool}" || true
        return 1
    fi
    if [ -n "${_popup_watchdog_expired_file:-}" ] && [ -s "${_popup_watchdog_expired_file}" ]; then
        close_popup_process "${popup_pid}" "${dialog_tool}" || true
        cleanup_popup_pid "${popup_pid}"
        return 1
    fi

    gamescope_debug_event="respawn"
    _popup_linux_arm_gamescope_atoms "${remaining_seconds}"

    if [ -n "${window_tool}" ]; then
        sleep 0.3
        make_window_unclosable "${window_title}" "${window_tool}" "${remaining_seconds}"
        keep_window_on_top "${window_title}" "${window_tool}"
        keep_window_on_top_periodic "${window_title}" "${window_tool}" "${popup_pid}" "${remaining_seconds}" &
    fi

    if [ -n "${popup_pid}" ] && [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
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
        if [ -n "${_popup_watchdog_expired_file:-}" ] && [ -s "${_popup_watchdog_expired_file}" ]; then
            break
        fi
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
                    _popup_linux_note_gamescope_debug_exit "${popup_exit_code}" "true"
                    _popup_linux_cancel_watchdog
                    return 0
                fi
            fi

            _popup_linux_update_countdown "${remaining}" || return 1
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
                _popup_linux_update_countdown "${remaining}" || return 1
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

    if [ -n "${popup_pid}" ]; then
        local popup_exit_code=0
        wait "${popup_pid}" 2>/dev/null || popup_exit_code=$?

        if [ -n "${auto_close_timer_pid}" ] && kill -0 "${auto_close_timer_pid}" 2>/dev/null; then
            log_to_file "INFO" "User closed popup manually, cancelling auto-close timer (timer PID: ${auto_close_timer_pid})"
            kill "${auto_close_timer_pid}" 2>/dev/null
            wait "${auto_close_timer_pid}" 2>/dev/null
        fi

        if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
            if _popup_maybe_handle_pause_click "${popup_exit_code}"; then
                _popup_linux_note_gamescope_debug_exit "${popup_exit_code}" "true"
                _popup_linux_cancel_watchdog
                return 0
            fi
        fi

        _popup_linux_note_gamescope_debug_exit "${popup_exit_code}" "false"
        if [ ${popup_exit_code} -eq 0 ]; then
            log_to_file "INFO" "Popup closed by user after minimum display time"
        else
            log_to_file "WARNING" "Popup exited with code ${popup_exit_code}"
        fi

        cleanup_popup_pid "${popup_pid}"
        _popup_linux_cancel_watchdog
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
        local popup_exit_code=0
        wait "${popup_pid}" 2>/dev/null || popup_exit_code=$?

        if [ -n "${auto_close_timer_pid}" ] && kill -0 "${auto_close_timer_pid}" 2>/dev/null; then
            log_to_file "INFO" "User closed popup manually, cancelling auto-close timer (timer PID: ${auto_close_timer_pid})"
            kill "${auto_close_timer_pid}" 2>/dev/null
            wait "${auto_close_timer_pid}" 2>/dev/null
        fi

        if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
            if _popup_maybe_handle_pause_click "${popup_exit_code}"; then
                _popup_linux_note_gamescope_debug_exit "${popup_exit_code}" "true"
                _popup_linux_cancel_watchdog
                return 0
            fi
        fi

        _popup_linux_note_gamescope_debug_exit "${popup_exit_code}" "false"
        if [ ${popup_exit_code} -eq 0 ]; then
            log_to_file "INFO" "Popup closed by user"
        else
            log_to_file "WARNING" "Popup exited with code ${popup_exit_code}"
        fi

        cleanup_popup_pid "${popup_pid}"
        _popup_linux_cancel_watchdog

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
