#!/bin/bash

###############################################################################
# Sleep Warning System - macOS show_warning implementation
###############################################################################

show_warning_darwin() {
    local _pd_dir
    _pd_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck disable=SC1091
    [ -f "${_pd_dir}/popup-safety.sh" ] && source "${_pd_dir}/popup-safety.sh"
    # shellcheck disable=SC1091
    [ -f "${_pd_dir}/popup-dialog-implementations-darwin.sh" ] && source "${_pd_dir}/popup-dialog-implementations-darwin.sh"

    local env_type display_id
    env_type=$(detect_display_environment)
    if [ "${env_type}" = "none" ]; then
        log_to_file "WARNING" "macOS: No GUI session available, skipping popup"
        return 1
    fi
    display_id=$(get_display_identifier "${env_type}")

    local dialog_tool="osascript"
    local check_interval popup_size popup_position
    check_interval=$(get_check_interval)
    popup_size=$(get_popup_size)
    popup_position=$(get_popup_position)

    local min_display_time popup_auto_close
    min_display_time=$(popup_safe_get_min_display_time)
    popup_auto_close=$(popup_safe_get_auto_close)

    local dimensions width height
    dimensions=$(get_popup_dimensions "${popup_size}" 2>/dev/null || echo "400 300")
    width=$(echo "${dimensions}" | cut -d' ' -f1)
    height=$(echo "${dimensions}" | cut -d' ' -f2)

    local interval_text next_unrestricted_time base_message message
    interval_text="$(_popup_get_interval_text "${check_interval}")"
    next_unrestricted_time=$(get_next_unrestricted_time)
    base_message="$(_popup_build_base_message "${next_unrestricted_time}" "${interval_text}")"
    base_message="$(dialog_safe_text "${base_message}")"
    countdown_msg="$(_popup_build_initial_countdown_suffix "${min_display_time}" "${popup_auto_close}")"
    message="${base_message}${countdown_msg}"
    message="$(dialog_safe_text "${message}")"

    local pause_available=false pause_duration=""
    if can_pause_today; then
        pause_available=true
        pause_duration=$(get_pause_duration)
    fi

    cleanup_stale_pid

    local existing_popup_info
    existing_popup_info=$(is_popup_running)
    if [ -n "${existing_popup_info}" ]; then
        local existing_pid existing_age
        existing_pid=$(echo "${existing_popup_info}" | cut -d'|' -f1)
        existing_age=$(echo "${existing_popup_info}" | cut -d'|' -f2)
        local check_interval_seconds=$((check_interval * 60))
        if [ "${existing_age}" -le "${check_interval_seconds}" ]; then
            log_to_file "INFO" "macOS: Skipping duplicate popup (PID ${existing_pid}, age ${existing_age}s)"
            return 0
        fi
        close_existing_popups >/dev/null
    fi

    local popup_pid window_title="ALERT: Restricted time window"
    local watchdog_seconds
    watchdog_seconds=$(popup_compute_watchdog_seconds "${min_display_time}" "${popup_auto_close}")

    _popup_spawn_warning_dialog() {
        _popup_spawn_warning_dialog_darwin "${message}" "${base_message}"
    }

    popup_run_with_watchdog _popup_spawn_warning_dialog "${watchdog_seconds}"
    local watchdog_rc=$?

    if [ -z "${popup_pid}" ] || ! [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
        log_to_file "ERROR" "macOS: Failed to display popup"
        if type _darwin_display_notification >/dev/null 2>&1; then
            _darwin_display_notification "ALERT: Restricted time window" \
                "You are using your computer during restricted hours."
            log_to_file "WARNING" "macOS: notification fallback used"
            return 0
        fi
        return 1
    fi

    save_popup_pid "${popup_pid}"
    log_to_file "INFO" "macOS popup displayed (PID ${popup_pid}), watchdog=${watchdog_seconds}s, min_display=${min_display_time}s"

    # Wait for dialog process (bounded by watchdog in popup_run_with_watchdog)
    if kill -0 "${popup_pid}" 2>/dev/null; then
        wait "${popup_pid}" 2>/dev/null || true
    fi

    if [ "${pause_available}" = "true" ]; then
        _popup_maybe_handle_pause_click_darwin || true
    fi

    cleanup_popup_pid "${popup_pid}"
    rm -f "${POPUP_DARWIN_RESULT_FILE:-}" 2>/dev/null

    if [ "${watchdog_rc}" -eq 124 ]; then
        log_to_file "WARNING" "macOS: Popup closed by safety watchdog"
    fi

    return 0
}
