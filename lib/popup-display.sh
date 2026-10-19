#!/bin/bash

###############################################################################
# Sleep Warning System - Popup Display Module
#
# This module handles the display of warning popups including:
# - Display environment detection and configuration
# - Dialog tool selection and invocation
# - Window manipulation (stay on top, immovable, minimum display time)
# - Logging of popup events
# - Calculation of next unrestricted time (via time-calculations.sh)
#
# Dependencies:
#   - config.sh (for configuration functions)
#   - logging.sh (for logging functions)
#   - pause-state.sh (for pause state management functions - Enhancement #21)
#   - display-detection.sh (for display environment detection)
#   - desktop-environment.sh (for dialog tool detection)
#   - window-management.sh (for window manipulation)
#   - time-calculations.sh (for time calculation functions: get_next_unrestricted_time, etc.)
#
# Usage: Source this file after all dependency modules
#   source lib/config.sh
#   source lib/logging.sh
#   source lib/pause-state.sh
#   source lib/display-detection.sh
#   source lib/desktop-environment.sh
#   source lib/window-management.sh
#   source lib/popup-display.sh
###############################################################################

# Unicode / locale safety helper (prevents GTK dialog tools from crashing when
# locale is non-UTF-8 by sanitizing dialog strings to ASCII as needed).
if ! type dialog_safe_text >/dev/null 2>&1; then
    _POPUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck disable=SC1090
    if [ -f "${_POPUP_DIR}/unicode-dialog-safety.sh" ]; then
        source "${_POPUP_DIR}/unicode-dialog-safety.sh"
    fi
    unset _POPUP_DIR
fi

# Hard fallback: keep popups functional even if helper can't be sourced.
if ! type dialog_safe_text >/dev/null 2>&1; then
    dialog_safe_text() { printf '%s' "${1:-}"; }
fi

# Ensure we have a UTF-8 locale before invoking GTK dialog tools (yad/zenity).
# SteamOS/systemd user services can run with locale "C" (non-UTF-8), which makes
# GTK reject Unicode text (e.g., ⚠️ / ⏱️) with errors like:
#   "Unable to parse command line: Invalid byte sequence in conversion input"
# This results in yad exiting immediately, which then triggers respawn loops.
#
# Prefer portable C.UTF-8 even when host LANG already reports UTF-8 (Nix yad
# otherwise falls back to plain C and rejects Unicode argv). Delegates to
# dialog_prepare_utf8_locale when available.
ensure_utf8_locale_for_dialogs() {
    if type dialog_prepare_utf8_locale >/dev/null 2>&1; then
        DIALOG_UTF8_CONFIRMED=""
        dialog_prepare_utf8_locale
        return 0
    fi

    # Fallback when unicode-dialog-safety.sh did not load.
    command -v locale >/dev/null 2>&1 || return 0

    local candidate
    for candidate in "C.UTF-8" "C.utf8" "en_US.UTF-8" "en_US.utf8"; do
        if LC_ALL="${candidate}" locale charmap 2>/dev/null | grep -qi "utf-8"; then
            export LC_ALL="${candidate}"
            if [ -z "${LANG:-}" ]; then
                export LANG="${candidate}"
            fi
            if type log_to_file >/dev/null 2>&1; then
                log_to_file "WARNING" "Locale was not UTF-8; set LC_ALL=${candidate} for dialog compatibility"
            fi
            return 0
        fi
    done

    return 0
}

## Popup PID/state helpers are sourced from a submodule to keep this file smaller.
_POPUP_DISPLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
if [ -f "${_POPUP_DISPLAY_DIR}/popup-pid-management.sh" ]; then
    source "${_POPUP_DISPLAY_DIR}/popup-pid-management.sh"
fi
unset _POPUP_DISPLAY_DIR

## Popup dialog-tool implementations are sourced from a submodule to keep this
## file smaller, while preserving yad/zenity/kdialog support (NON-NEGOTIABLE).
_POPUP_DIALOGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
if [ -f "${_POPUP_DIALOGS_DIR}/popup-dialog-implementations.sh" ]; then
    source "${_POPUP_DIALOGS_DIR}/popup-dialog-implementations.sh"
fi
if [ -f "${_POPUP_DIALOGS_DIR}/popup-display-darwin.sh" ]; then
    source "${_POPUP_DIALOGS_DIR}/popup-display-darwin.sh"
fi
if [ -f "${_POPUP_DIALOGS_DIR}/popup-safety.sh" ]; then
    # shellcheck disable=SC1091
    source "${_POPUP_DIALOGS_DIR}/popup-safety.sh"
fi
if [ -f "${_POPUP_DIALOGS_DIR}/popup-display-linux.sh" ]; then
    # shellcheck disable=SC1091
    source "${_POPUP_DIALOGS_DIR}/popup-display-linux.sh"
fi
unset _POPUP_DIALOGS_DIR

# Close popup process using process termination
# Parameters:
#   $1 - popup_pid - Process ID of the popup
#   $2 - dialog_tool - Dialog tool used (zenity/yad/kdialog)
# Returns: 0 on success, 1 on failure
# This is for Enhancement #15 (Auto-Close Popup Window)
close_popup_process() {
    local popup_pid="$1"
    local dialog_tool="$2"
    
    # Check if process is still running
    if ! kill -0 "${popup_pid}" 2>/dev/null; then
        # Process already exited (user closed manually)
        log_to_file "INFO" "Popup process (PID ${popup_pid}) already exited (user closed manually)"
        return 0
    fi
    
    # Try SIGTERM first (graceful shutdown)
    log_to_file "INFO" "Attempting to close popup (PID ${popup_pid}) using SIGTERM"
    kill -TERM "${popup_pid}" 2>/dev/null
    
    # Wait briefly for process to exit
    sleep 0.5
    
    # Check if process exited
    if ! kill -0 "${popup_pid}" 2>/dev/null; then
        log_to_file "INFO" "Popup closed successfully using SIGTERM"
        return 0
    fi
    
    # Process still running, try SIGKILL (force termination)
    log_to_file "WARNING" "Popup process (PID ${popup_pid}) did not exit with SIGTERM, trying SIGKILL"
    kill -KILL "${popup_pid}" 2>/dev/null
    
    # Wait briefly for process to exit
    sleep 0.5
    
    # Check if process exited
    if ! kill -0 "${popup_pid}" 2>/dev/null; then
        log_to_file "INFO" "Popup closed successfully using SIGKILL"
        return 0
    fi
    
    # Both SIGTERM and SIGKILL failed
    log_to_file "WARNING" "Failed to close popup process (PID ${popup_pid}) - both SIGTERM and SIGKILL failed"
    return 1
}

# Auto-close popup timer function (runs in background)
# Parameters:
#   $1 - popup_pid - Process ID of the popup
#   $2 - dialog_tool - Dialog tool used (zenity/yad/kdialog)
#   $3 - window_title - Window title for logging
#   $4 - window_tool - Window management tool (for logging)
# This is for Enhancement #15 (Auto-Close Popup Window)
auto_close_popup() {
    local popup_pid="$1"
    local dialog_tool="$2"
    local window_title="$3"
    local window_tool="$4"
    
    # Sleep for 10 seconds (fixed delay after minimum display time)
    sleep 10
    
    # Check if popup process is still running
    if ! kill -0 "${popup_pid}" 2>/dev/null; then
        # Popup already closed (user closed manually)
        log_to_file "INFO" "Auto-close timer: Popup already closed by user (PID ${popup_pid})"
        return 0
    fi
    
    # Close the popup
    log_to_file "INFO" "Auto-close timer: Closing popup (PID ${popup_pid}) after 10-second delay"
    if close_popup_process "${popup_pid}" "${dialog_tool}"; then
        log_to_file "INFO" "Auto-close: Popup closed successfully (PID ${popup_pid})"
        return 0
    else
        log_to_file "WARNING" "Auto-close: Failed to close popup (PID ${popup_pid})"
        return 1
    fi
}

# Build the human-friendly interval text used in the popup message.
# Parameters:
# - $1: check_interval_minutes
_popup_get_interval_text() {
    local check_interval_minutes="$1"

    if [ "${check_interval_minutes}" -eq 1 ]; then
        echo "every minute"
    else
        echo "every ${check_interval_minutes} minutes"
    fi
}

# Build the base (non-countdown) popup message.
# Parameters:
# - $1: next_unrestricted_time
# - $2: interval_text
_popup_build_base_message() {
    local next_unrestricted_time="$1"
    local interval_text="$2"

    # NOTE: This string is intentionally kept byte-for-byte equivalent to the
    # previous inlined `base_message` definition (including newlines and emojis).
    printf '%s' "⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Next unrestricted time: ${next_unrestricted_time}

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear ${interval_text} while you continue using your computer during these hours."
}

# Build the initial countdown/auto-close suffix shown on first render.
# Parameters:
# - $1: min_display_time (seconds)
# - $2: popup_auto_close ("true"/"false")
_popup_build_initial_countdown_suffix() {
    local min_display_time="$1"
    local popup_auto_close="$2"

    # Add initial countdown message if minimum display time is set
    # Also include auto-close information if enabled (Enhancement #15)
    local countdown_msg=""
    if [ "${min_display_time}" -gt 0 ]; then
        if [ "${popup_auto_close}" = "true" ]; then
            countdown_msg="\n\n⏱️  This popup must remain visible for ${min_display_time} more second(s) before it can be closed. It will auto-close 10 seconds after that."
        else
            countdown_msg="\n\n⏱️  This popup must remain visible for ${min_display_time} more second(s) before it can be closed."
        fi
    elif [ "${popup_auto_close}" = "true" ]; then
        # Minimum display time is 0, but auto-close is enabled
        countdown_msg="\n\n⏱️  This popup will auto-close in 10 seconds."
    fi

    printf '%s' "${countdown_msg}"
}

# Display warning popup
show_warning() {
    if type is_darwin >/dev/null 2>&1 && is_darwin && type show_warning_darwin >/dev/null 2>&1; then
        show_warning_darwin
        return $?
    fi

    local dialog_tool
    local display_env
    local env_type
    local display_id

    # Prefer portable UTF-8 via ensure_utf8_locale_for_dialogs (resets the
    # prepare cache and delegates to dialog_prepare_utf8_locale when loaded).
    ensure_utf8_locale_for_dialogs
    
    # Detect display environment type
    env_type=$(detect_display_environment)
    display_id=$(get_display_identifier "${env_type}")

    # Get display environment
    display_env=$(get_display "${env_type}")
    if [ -z "${display_env}" ]; then
        log_message "warning" "No display available, cannot show warning popup"
        log_to_file "WARNING" "No display available, cannot show warning popup. Detection path: ${DISPLAY_DETECTION_PATH:-}. ${DISPLAY_DETECTION_NOTE:-}"
        # notify-send is for a graphical session whose display did not answer
        # (including gamescope, and a DISPLAY we could not probe). A headless
        # or SSH check has no DISPLAY and must not log a notify-send error
        # on every interval.
        if [ "${env_type}" = "gamescope" ] || [ "${env_type}" = "x11" ] || [ "${env_type}" = "wayland" ] || [ -n "${DISPLAY:-}" ]; then
            if type _popup_linux_notify_send_fallback >/dev/null 2>&1; then
                _popup_linux_notify_send_fallback
                return $?
            fi
        fi
        return 1
    fi
    
    # Set display environment variables
    export POPUP_FORCE_X11_BACKEND="false"
    if [ "${env_type}" = "x11" ]; then
        export DISPLAY="${display_env}"
    elif [ "${env_type}" = "gamescope" ]; then
        # For SteamOS Gaming Mode (gamescope), force Xwayland (:0) so xprop can tag STEAM_OVERLAY=1
        export DISPLAY="${display_env}"
        unset WAYLAND_DISPLAY
        export POPUP_FORCE_X11_BACKEND="true"
    else
        # For Wayland, set both DISPLAY (for tools that need it) and WAYLAND_DISPLAY
        if [ -n "${display_id}" ] && [ "${display_id}" != "unknown" ]; then
            export WAYLAND_DISPLAY="${display_id}"
        fi
        # Also set DISPLAY as fallback for tools that may need it
        export DISPLAY="${display_env}"
    fi
    
    # Detect window state before showing popup
    local window_tool
    window_tool=$(check_window_tools)
    local window_state_info
    window_state_info=$(detect_window_state "${env_type}" "${window_tool}")
    local window_state window_title
    window_state=$(echo "${window_state_info}" | cut -d'|' -f1)
    window_title=$(echo "${window_state_info}" | cut -d'|' -f2-)
    
    # Log display environment and detection path
    log_to_file "INFO" "Display environment: ${env_type}, Display ID: ${display_id}, Detection path: ${DISPLAY_DETECTION_PATH}"
    if [ -n "${DISPLAY_DETECTION_NOTE}" ]; then
        log_to_file "WARNING" "Display detection note: ${DISPLAY_DETECTION_NOTE}"
    fi

    # Log window state
    log_to_file "INFO" "Window state: ${window_state}, Window title: ${window_title}"
    
    # Check user preference for dialog tool (Enhancement #25)
    # Note: get_dialog_tool_config() is from config.sh, which should be sourced by the calling script
    local user_dialog_preference
    if type get_dialog_tool_config >/dev/null 2>&1; then
        user_dialog_preference=$(get_dialog_tool_config)
    else
        # Fallback if config.sh not sourced (should not happen in normal operation)
        user_dialog_preference="auto"
    fi
    dialog_tool=$(check_dialog_tool "${env_type}" "${user_dialog_preference}")
    if [ -z "${dialog_tool}" ]; then
        log_message "warning" "No dialog tool available (zenity/yad/kdialog)"
        log_to_file "ERROR" "No dialog tool available (zenity/yad/kdialog), Display: ${env_type}, Display ID: ${display_id}"
        return 1
    fi
    
    # Log selection reason
    if [ -n "${user_dialog_preference}" ] && [ "${user_dialog_preference}" != "auto" ]; then
        if [ "${dialog_tool}" = "${user_dialog_preference}" ]; then
            log_to_file "INFO" "Using user-selected dialog tool: ${dialog_tool}"
        else
            log_to_file "WARNING" "User-selected dialog tool '${user_dialog_preference}' not installed, falling back to automatic selection: ${dialog_tool}"
        fi
    else
        log_to_file "INFO" "Using automatically selected dialog tool: ${dialog_tool}"
    fi
    
    # Popup display frequency for message (Enhancement #30; matches sleep-warning.sh throttle)
    local popup_freq_minutes
    popup_freq_minutes=$(get_popup_display_frequency)
    
    # Get popup size and position
    local popup_size popup_position
    popup_size=$(get_popup_size)
    popup_position=$(get_popup_position)
    
    # Get minimum display time and auto-close (popup-safety clamps on darwin)
    local min_display_time popup_auto_close
    if type popup_safe_get_min_display_time >/dev/null 2>&1; then
        min_display_time=$(popup_safe_get_min_display_time)
        popup_auto_close=$(popup_safe_get_auto_close)
    else
        min_display_time=$(get_min_display_time)
        popup_auto_close=$(get_popup_auto_close)
    fi
    
    # Get dimensions
    local dimensions
    dimensions=$(get_popup_dimensions "${popup_size}")
    local width height
    width=$(echo "${dimensions}" | cut -d' ' -f1)
    height=$(echo "${dimensions}" | cut -d' ' -f2)
    
    # Warning message
    local interval_text
    interval_text="$(_popup_get_interval_text "${popup_freq_minutes}")"
    
    # Calculate next unrestricted time
    local next_unrestricted_time
    next_unrestricted_time=$(get_next_unrestricted_time)
    
    # Check if pause is available (Enhancement #21)
    local pause_available=false
    local pause_duration=""
    if can_pause_now; then
        pause_available=true
        pause_duration=$(get_pause_duration)
    fi
    
    # Build base message (without countdown - countdown will be added dynamically)
    local base_message
    base_message="$(_popup_build_base_message "${next_unrestricted_time}" "${interval_text}")"
    
    local countdown_msg
    countdown_msg="$(_popup_build_initial_countdown_suffix "${min_display_time}" "${popup_auto_close}")"
    
    local message="${base_message}${countdown_msg}"
    message="$(dialog_safe_text "${message}")"
    
    # Check for window manager tools (needed for stay-on-top and minimum display time)
    window_tool=$(check_window_tools)
    
    local popup_pid
    local _popup_watchdog_pid=""
    local _popup_watchdog_expired_file=""
    local zenity_output_file
    local window_title="ALERT: Restricted time window"
    local _popup_lock_fd=""

    _popup_linux_acquire_spawn_lock

    if _popup_linux_should_skip_for_existing_popup; then
        return 0
    fi

    window_title="$(dialog_safe_text "${window_title}")"
    _popup_spawn_warning_dialog "${message}"

    if [ -n "${popup_pid}" ]; then
        if ! _popup_linux_on_spawn_success; then
            _popup_linux_on_spawn_failure
            return $?
        fi
    else
        if _popup_linux_on_spawn_failure; then
            return 0
        fi
        return 1
    fi

    _popup_linux_run_post_spawn_lifecycle
    return $?
}
