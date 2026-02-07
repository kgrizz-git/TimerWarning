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
# This function attempts to set a UTF-8 locale (preferring C.UTF-8) only when the
# current locale does not already appear to be UTF-8.
ensure_utf8_locale_for_dialogs() {
    # If locale(1) isn't available, we can't safely detect; do nothing.
    command -v locale >/dev/null 2>&1 || return 0

    # If any locale category is already UTF-8, do nothing.
    if locale 2>/dev/null | grep -qi "utf-8"; then
        return 0
    fi

    # Prefer widely-available UTF-8 locales.
    local candidate
    for candidate in "C.UTF-8" "en_US.UTF-8"; do
        if locale -a 2>/dev/null | tr -d '\r' | grep -qx "${candidate}"; then
            export LC_ALL="${candidate}"
            # Keep LANG consistent if it's unset/empty.
            if [ -z "${LANG:-}" ]; then
                export LANG="${candidate}"
            fi
            if type log_to_file >/dev/null 2>&1; then
                log_to_file "WARNING" "Locale was not UTF-8; set LC_ALL=${candidate} for dialog compatibility"
            fi
            return 0
        fi
    done

    # No known UTF-8 locale found; proceed without changing environment.
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
    local dialog_tool
    local display_env
    local env_type
    local display_id

    # Prefer UTF-8 locale when available; otherwise we will sanitize dialog text.
    if type dialog_prepare_utf8_locale >/dev/null 2>&1; then
        dialog_prepare_utf8_locale
    else
        ensure_utf8_locale_for_dialogs
    fi
    
    # Detect display environment type
    env_type=$(detect_display_environment)
    display_id=$(get_display_identifier "${env_type}")

    # Get display environment
    display_env=$(get_display "${env_type}")
    if [ -z "${display_env}" ]; then
        log_message "warning" "No display available, cannot show warning popup"
        log_to_file "WARNING" "No display available, cannot show warning popup. Detection path: ${DISPLAY_DETECTION_PATH}. ${DISPLAY_DETECTION_NOTE}"
        return 1
    fi
    
    # Set display environment variables
    if [ "${env_type}" = "x11" ]; then
        export DISPLAY="${display_env}"
    else
        # For Wayland/gamescope, set both DISPLAY (for tools that need it) and WAYLAND_DISPLAY
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
    
    # Get check interval for message
    local check_interval
    check_interval=$(get_check_interval)
    
    # Get popup size and position
    local popup_size popup_position
    popup_size=$(get_popup_size)
    popup_position=$(get_popup_position)
    
    # Get minimum display time
    local min_display_time
    min_display_time=$(get_min_display_time)
    
    # Get auto-close setting (Enhancement #15)
    local popup_auto_close
    popup_auto_close=$(get_popup_auto_close)
    
    # Get dimensions
    local dimensions
    dimensions=$(get_popup_dimensions "${popup_size}")
    local width height
    width=$(echo "${dimensions}" | cut -d' ' -f1)
    height=$(echo "${dimensions}" | cut -d' ' -f2)
    
    # Warning message
    local interval_text
    interval_text="$(_popup_get_interval_text "${check_interval}")"
    
    # Calculate next unrestricted time
    local next_unrestricted_time
    next_unrestricted_time=$(get_next_unrestricted_time)
    
    # Check if pause is available (Enhancement #21)
    local pause_available=false
    local pause_duration=""
    if can_pause_today; then
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
    local window_tool
    window_tool=$(check_window_tools)
    
    # Check for existing popup before spawning new one (Enhancement #9)
    local existing_popup_info
    existing_popup_info=$(is_popup_running)
    
    if [ -n "${existing_popup_info}" ]; then
        local existing_pid existing_age
        existing_pid=$(echo "${existing_popup_info}" | cut -d'|' -f1)
        existing_age=$(echo "${existing_popup_info}" | cut -d'|' -f2)
        
        # Get check interval in seconds
        local check_interval_minutes
        check_interval_minutes=$(get_check_interval)
        local check_interval_seconds
        check_interval_seconds=$((check_interval_minutes * 60))
        
        if [ "${existing_age}" -gt "${check_interval_seconds}" ]; then
            # Existing popup has been open longer than CHECK_INTERVAL, close it and show new one
            log_to_file "INFO" "Existing popup (PID ${existing_pid}) has been open ${existing_age} seconds (longer than CHECK_INTERVAL ${check_interval_seconds}s), closing and showing new popup"
            close_existing_popups >/dev/null
            # Continue to show new popup below
        else
            # Existing popup has been open less than CHECK_INTERVAL, skip showing new popup
            log_to_file "INFO" "Skipping new popup: Existing popup (PID ${existing_pid}) has been open ${existing_age} seconds (less than CHECK_INTERVAL ${check_interval_seconds}s)"
            return 0
        fi
    fi
    
    # Display popup based on available tool
    # Note: Window title is set to a specific string to avoid matching unrelated windows.
    local popup_pid
    # Used by zenity to capture which extra button was clicked (Enhancement #21).
    local zenity_output_file
    local window_title="ALERT: Restricted time window"
    window_title="$(dialog_safe_text "${window_title}")"

    _popup_spawn_warning_dialog "${message}"
    
    # Log popup display attempt or fallback to notify-send
    if [ -n "${popup_pid}" ]; then
        local auto_close_status="disabled"
        if [ "${popup_auto_close}" = "true" ]; then
            if [ "${min_display_time}" -gt 0 ]; then
                auto_close_status="enabled (10s after ${min_display_time}s min display = $((min_display_time + 10))s total)"
            else
                auto_close_status="enabled (10s after popup appears)"
            fi
        fi
        log_to_file "INFO" "Popup displayed successfully (PID: ${popup_pid}), Dialog tool: ${dialog_tool}, Size: ${popup_size}, Position: ${popup_position}, Min display time: ${min_display_time}s, Auto-close: ${auto_close_status}"
        
        # Save popup PID to file (Enhancement #9)
        save_popup_pid "${popup_pid}"
    else
        log_to_file "ERROR" "Failed to display popup, Dialog tool: ${dialog_tool}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "ALERT: Restricted time window" "You are using your computer during restricted hours. Please consider resting." >/dev/null 2>&1
            log_to_file "WARNING" "notify-send fallback used (non-modal)"
            return 0
        fi
        log_to_file "ERROR" "notify-send fallback unavailable"
        return 1
    fi
    
    # Ensure window stays on top (always, not just during minimum display time)
    # Wait longer for window to be fully created before trying to manipulate it
    if [ -n "${window_tool}" ] && [ -n "${popup_pid}" ]; then
        # Give the window more time to appear and stabilize
        sleep 1.0
        keep_window_on_top "${window_title}" "${window_tool}"
        # Start periodic on-top enforcement (runs until popup closes)
        # Use minimum display time if set, otherwise default to 5 minutes
        local on_top_duration=${min_display_time}
        if [ "${on_top_duration}" -eq 0 ]; then
            on_top_duration=300  # 5 minutes default
        fi
        keep_window_on_top_periodic "${window_title}" "${window_tool}" "${popup_pid}" "${on_top_duration}" &
    fi
    
    # Function to update popup with current countdown
    # This function closes and reopens the popup with updated countdown text
    # Preserves pause button if it was available initially
    update_popup_countdown() {
        local remaining_seconds=$1
        local old_pid="${popup_pid}"
        
        # Build updated message with countdown
        local countdown_msg="\n\n⏱️  This popup must remain visible for ${remaining_seconds} more second(s) before it can be closed."
        local updated_message="${base_message}${countdown_msg}"
        updated_message="$(dialog_safe_text "${updated_message}")"
        
        # Clean up old PID file before killing old popup (Enhancement #9)
        cleanup_popup_pid "${old_pid}"
        
        # Kill existing popup if still running
        if kill -0 "${popup_pid}" 2>/dev/null; then
            kill "${popup_pid}" 2>/dev/null
            wait "${popup_pid}" 2>/dev/null
        fi
        
        # Reopen popup with updated message, preserving pause button if available
        _popup_spawn_warning_dialog "${updated_message}"
        
        # Re-apply window restrictions and keep on top
        if [ -n "${window_tool}" ]; then
            sleep 0.3
            make_window_unclosable "${window_title}" "${window_tool}" "${remaining_seconds}"
            keep_window_on_top "${window_title}" "${window_tool}"
            keep_window_on_top_periodic "${window_title}" "${window_tool}" "${popup_pid}" "${remaining_seconds}" &
        fi
        
        # Save new PID to file after respawning popup (Enhancement #9)
        if [ -n "${popup_pid}" ] && [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
            save_popup_pid "${popup_pid}"
            if type log_to_file >/dev/null 2>&1; then
                log_to_file "INFO" "Popup respawned: Old PID ${old_pid} cleaned up, new PID ${popup_pid} saved"
            fi
        fi
    }
    
    # If minimum display time is set, enforce it
    if [ "${min_display_time}" -gt 0 ] && [ -n "${popup_pid}" ]; then
        # Try to make window unclosable if window tools are available
        if [ -n "${window_tool}" ]; then
            make_window_unclosable "${window_title}" "${window_tool}" "${min_display_time}"
        fi
        
        # Wait for minimum display time, showing countdown
        # Use actual wall-clock time instead of sleep iterations to avoid drift
        # Record start timestamp to calculate actual elapsed time accurately
        local start_timestamp
        start_timestamp=$(date +%s)
        local elapsed=0
        local remaining=${min_display_time}
        local last_redraw_elapsed=0
        local last_remaining=${min_display_time}
        
        while [ "${elapsed}" -lt "${min_display_time}" ]; do
            sleep 1
            # Calculate actual elapsed time based on wall-clock, not loop iterations
            # This prevents drift accumulation if sleep takes longer than 1 second
            local current_timestamp
            current_timestamp=$(date +%s)
            elapsed=$((current_timestamp - start_timestamp))
            remaining=$((min_display_time - elapsed))
            
            # Safety check: if elapsed reaches/exceeds min_display_time, clamp values.
            # IMPORTANT: Do NOT break here. We want the redraw logic below to run
            # once with remaining=0 so the popup always updates at countdown zero.
            if [ "${elapsed}" -ge "${min_display_time}" ]; then
                elapsed="${min_display_time}"
                remaining=0
            fi
            
            # Check if popup is still running
            if ! kill -0 "${popup_pid}" 2>/dev/null; then
                # Popup was closed - check if it was due to pause button click (Enhancement #21)
                local popup_exit_code=0
                wait "${popup_pid}" 2>/dev/null
                popup_exit_code=$?
                
                # Handle pause button clicks
                if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                    if _popup_maybe_handle_pause_click "${popup_exit_code}"; then
                        return 0
                    fi
                fi
                
                # Popup was closed (not due to pause), reopen it with updated countdown immediately
                update_popup_countdown "${remaining}"
            else
                # Determine when to redraw based on minimum display time
                local should_redraw=false
                
                if [ "${min_display_time}" -le 30 ]; then
                    # For min_display_time ≤ 30: redraw every 10 seconds and at 0
                    # Track last redraw time to avoid multiple redraws at same threshold
                    if [ $((elapsed - last_redraw_elapsed)) -ge 10 ] && [ "${elapsed}" -gt 0 ]; then
                        should_redraw=true
                        last_redraw_elapsed=${elapsed}
                    elif [ "${remaining}" -le 0 ]; then
                        # Redraw at zero (final redraw before loop exits)
                        should_redraw=true
                    fi
                else
                    # For min_display_time > 30: redraw at 75%, 50%, 25%, and 0 time remaining
                    # Check if we have crossed a threshold since last check (using wall-clock time)
                    local threshold_75=$((min_display_time * 75 / 100))
                    local threshold_50=$((min_display_time * 50 / 100))
                    local threshold_25=$((min_display_time * 25 / 100))
                    
                    # Check if we crossed a threshold (remaining decreased past threshold)
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
                    # Update countdown at specified intervals
                    update_popup_countdown "${remaining}"
                fi
            fi
        done
        
        # Re-enable window closing after timeout
        if [ -n "${window_tool}" ]; then
            reenable_window_closing "${window_title}" "${window_tool}"
        fi
        
        # Start auto-close timer if enabled (Enhancement #15)
        local auto_close_timer_pid=""
        if [ "${popup_auto_close}" = "true" ] && kill -0 "${popup_pid}" 2>/dev/null; then
            # Log auto-close configuration
            log_to_file "INFO" "Auto-close enabled: Popup will close automatically 10 seconds after minimum display time (total: $((min_display_time + 10)) seconds)"
            
            # Start auto-close timer in background
            auto_close_popup "${popup_pid}" "${dialog_tool}" "${window_title}" "${window_tool}" &
            auto_close_timer_pid=$!
            log_to_file "INFO" "Auto-close timer started (timer PID: ${auto_close_timer_pid})"
        fi
        
        # Wait for user to actually close it (now they can) or for auto-close
        # Check if popup is still running before waiting
        if kill -0 "${popup_pid}" 2>/dev/null; then
            wait "${popup_pid}" 2>/dev/null
            local popup_exit_code=$?
            
            # Cancel auto-close timer if user closed popup manually
            if [ -n "${auto_close_timer_pid}" ] && kill -0 "${auto_close_timer_pid}" 2>/dev/null; then
                log_to_file "INFO" "User closed popup manually, cancelling auto-close timer (timer PID: ${auto_close_timer_pid})"
                kill "${auto_close_timer_pid}" 2>/dev/null
                wait "${auto_close_timer_pid}" 2>/dev/null
            fi
            
            # Handle pause button clicks after minimum display time (Enhancement #21)
            if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                if _popup_maybe_handle_pause_click "${popup_exit_code}"; then
                    return 0
                fi
            fi
            
            if [ ${popup_exit_code} -eq 0 ]; then
                log_to_file "INFO" "Popup closed by user after minimum display time"
            else
                log_to_file "WARNING" "Popup exited with code ${popup_exit_code}"
            fi
            
            # Clean up PID file when popup closes (Enhancement #9)
            cleanup_popup_pid "${popup_pid}"
        else
            log_to_file "WARNING" "Popup process (PID ${popup_pid}) already exited before wait"
        fi
    else
        # No minimum display time, just wait normally
        # Start auto-close timer if enabled (Enhancement #15)
        local auto_close_timer_pid=""
        if [ "${popup_auto_close}" = "true" ] && [ -n "${popup_pid}" ] && kill -0 "${popup_pid}" 2>/dev/null; then
            # Log auto-close configuration
            log_to_file "INFO" "Auto-close enabled: Popup will close automatically after 10 seconds (minimum display time is 0)"
            
            # Start auto-close timer in background
            auto_close_popup "${popup_pid}" "${dialog_tool}" "${window_title}" "${window_tool}" &
            auto_close_timer_pid=$!
            log_to_file "INFO" "Auto-close timer started (timer PID: ${auto_close_timer_pid})"
        fi
        
        if [ -n "${popup_pid}" ]; then
            # Check if popup is still running before waiting
            if kill -0 "${popup_pid}" 2>/dev/null; then
                wait "${popup_pid}" 2>/dev/null
                local popup_exit_code=$?
                
                # Cancel auto-close timer if user closed popup manually
                if [ -n "${auto_close_timer_pid}" ] && kill -0 "${auto_close_timer_pid}" 2>/dev/null; then
                    log_to_file "INFO" "User closed popup manually, cancelling auto-close timer (timer PID: ${auto_close_timer_pid})"
                    kill "${auto_close_timer_pid}" 2>/dev/null
                    wait "${auto_close_timer_pid}" 2>/dev/null
                fi
                
                # Handle pause button clicks (Enhancement #21)
                if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                    if _popup_maybe_handle_pause_click "${popup_exit_code}"; then
                        return 0
                    fi
                fi
                
                if [ ${popup_exit_code} -eq 0 ]; then
                    log_to_file "INFO" "Popup closed by user"
                else
                    log_to_file "WARNING" "Popup exited with code ${popup_exit_code}"
                fi
                
                # Clean up PID file when popup closes (Enhancement #9)
                cleanup_popup_pid "${popup_pid}"
            else
                log_to_file "WARNING" "Popup process (PID ${popup_pid}) already exited before wait"
            fi
        fi
    fi
    
    return $?
}
