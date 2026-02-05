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

# Clean up stale PID file if process no longer exists
# This function checks if the PID in the PID file is still running
# If not, removes the PID file
# Returns: 0 if cleaned up or file doesn't exist, 1 on error
# This is for Enhancement #9 (Popup Queue Prevention)
cleanup_stale_pid() {
    if [ ! -f "${POPUP_PID_FILE}" ]; then
        return 0  # No PID file, nothing to clean up
    fi
    
    local stored_pid
    stored_pid=$(cat "${POPUP_PID_FILE}" 2>/dev/null | tr -d '\n')
    
    if [ -z "${stored_pid}" ] || ! [[ "${stored_pid}" =~ ^[0-9]+$ ]]; then
        # Invalid PID in file, remove it
        rm -f "${POPUP_PID_FILE}" 2>/dev/null
        return 0
    fi
    
    # Check if process is still running
    if ! kill -0 "${stored_pid}" 2>/dev/null; then
        # Process no longer exists, remove stale PID file
        rm -f "${POPUP_PID_FILE}" 2>/dev/null
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "INFO" "Cleaned up stale PID file: Process ${stored_pid} no longer exists"
        fi
        return 0
    fi
    
    return 0
}

# Get age of popup in seconds
# Parameters:
#   $1 - popup_pid - Process ID of the popup
# Returns: Age in seconds, or 0 if cannot determine
# This is for Enhancement #9 (Popup Queue Prevention)
get_popup_age() {
    local popup_pid="$1"
    
    if [ -z "${popup_pid}" ] || ! [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
        echo "0"
        return 1
    fi
    
    # Try to get process start time from /proc
    if [ -d "/proc/${popup_pid}" ]; then
        local start_time
        start_time=$(stat -c %Y "/proc/${popup_pid}" 2>/dev/null || echo "")
        
        if [ -n "${start_time}" ]; then
            local current_time
            current_time=$(date +%s)
            local age
            age=$((current_time - start_time))
            echo "${age}"
            return 0
        fi
    fi
    
    # Fallback: Try to get from PID file timestamp
    if [ -f "${POPUP_PID_FILE}" ]; then
        local file_timestamp
        file_timestamp=$(stat -c %Y "${POPUP_PID_FILE}" 2>/dev/null || echo "")
        
        if [ -n "${file_timestamp}" ]; then
            local current_time
            current_time=$(date +%s)
            local age
            age=$((current_time - file_timestamp))
            echo "${age}"
            return 0
        fi
    fi
    
    echo "0"
    return 1
}

# Check if popup is already running
# Returns: PID and age if found (format: "PID|AGE"), empty string if not found
# This is for Enhancement #9 (Popup Queue Prevention)
is_popup_running() {
    # Clean up stale PIDs first
    cleanup_stale_pid
    
    # Primary method: Check PID file
    if [ -f "${POPUP_PID_FILE}" ]; then
        local stored_pid
        stored_pid=$(cat "${POPUP_PID_FILE}" 2>/dev/null | tr -d '\n')
        
        if [ -n "${stored_pid}" ] && [[ "${stored_pid}" =~ ^[0-9]+$ ]]; then
            # Check if process is still running
            if kill -0 "${stored_pid}" 2>/dev/null; then
                local age
                age=$(get_popup_age "${stored_pid}")
                echo "${stored_pid}|${age}"
                return 0
            fi
        fi
    fi
    
    # Secondary method: Window title matching (if window tools available)
    local window_tool
    window_tool=$(check_window_tools)
    
    if [ -n "${window_tool}" ]; then
        local window_title="Restricted Hours Alert"
        local found_pid=""
        
        case "${window_tool}" in
            wmctrl)
                # Use wmctrl to find window by title
                found_pid=$(wmctrl -l 2>/dev/null | grep -i "Restricted Hours Alert" | head -n1 | awk '{print $1}' | xargs -I {} wmctrl -lp 2>/dev/null | grep "{}" | awk '{print $3}' | head -n1)
                ;;
            xdotool)
                # Use xdotool to find window by title
                found_pid=$(xdotool search --name "Restricted Hours Alert" 2>/dev/null | head -n1)
                if [ -n "${found_pid}" ]; then
                    # Get process PID from window ID
                    found_pid=$(xdotool getwindowpid "${found_pid}" 2>/dev/null || echo "")
                fi
                ;;
        esac
        
        if [ -n "${found_pid}" ] && [[ "${found_pid}" =~ ^[0-9]+$ ]]; then
            # Verify it's actually a dialog tool process
            local proc_name
            proc_name=$(ps -p "${found_pid}" -o comm= 2>/dev/null | tr -d '\n')
            if echo "${proc_name}" | grep -qE "^(zenity|yad|kdialog)$"; then
                local age
                age=$(get_popup_age "${found_pid}")
                echo "${found_pid}|${age}"
                return 0
            fi
        fi
    fi
    
    # Final fallback: Process tree checking
    local dialog_pids
    dialog_pids=$(pgrep -f "zenity.*Restricted Hours Alert\|yad.*Restricted Hours Alert\|kdialog.*Restricted Hours Alert" 2>/dev/null | head -n1)
    
    if [ -n "${dialog_pids}" ] && [[ "${dialog_pids}" =~ ^[0-9]+$ ]]; then
        local age
        age=$(get_popup_age "${dialog_pids}")
        echo "${dialog_pids}|${age}"
        return 0
    fi
    
    return 1
}

# Close all existing popups found
# This function finds and closes all popups matching our window title
# Returns: Number of popups closed
# This is for Enhancement #9 (Popup Queue Prevention)
close_existing_popups() {
    local closed_count=0
    local window_tool
    window_tool=$(check_window_tools)
    
    # Find all popups by window title
    local window_title="Restricted Hours Alert"
    local window_ids=""
    
    if [ -n "${window_tool}" ]; then
        case "${window_tool}" in
            wmctrl)
                window_ids=$(wmctrl -l 2>/dev/null | grep -i "${window_title}" | awk '{print $1}')
                ;;
            xdotool)
                window_ids=$(xdotool search --name "${window_title}" 2>/dev/null)
                ;;
        esac
    fi
    
    # Also check PID file
    if [ -f "${POPUP_PID_FILE}" ]; then
        local stored_pid
        stored_pid=$(cat "${POPUP_PID_FILE}" 2>/dev/null | tr -d '\n')
        if [ -n "${stored_pid}" ] && [[ "${stored_pid}" =~ ^[0-9]+$ ]]; then
            if kill -0 "${stored_pid}" 2>/dev/null; then
                # Close process
                if close_popup_process "${stored_pid}" "unknown"; then
                    closed_count=$((closed_count + 1))
                fi
            fi
            # Clean up PID file
            rm -f "${POPUP_PID_FILE}" 2>/dev/null
        fi
    fi
    
    # Close windows found by window tools
    if [ -n "${window_ids}" ]; then
        local window_id
        for window_id in ${window_ids}; do
            # Get process PID from window
            local window_pid=""
            case "${window_tool}" in
                wmctrl)
                    window_pid=$(wmctrl -lp 2>/dev/null | grep "${window_id}" | awk '{print $3}' | head -n1)
                    ;;
                xdotool)
                    window_pid=$(xdotool getwindowpid "${window_id}" 2>/dev/null)
                    ;;
            esac
            
            if [ -n "${window_pid}" ] && [[ "${window_pid}" =~ ^[0-9]+$ ]]; then
                # Verify it's a dialog tool
                local proc_name
                proc_name=$(ps -p "${window_pid}" -o comm= 2>/dev/null | tr -d '\n')
                if echo "${proc_name}" | grep -qE "^(zenity|yad|kdialog)$"; then
                    if close_popup_process "${window_pid}" "${proc_name}"; then
                        closed_count=$((closed_count + 1))
                    fi
                fi
            fi
        done
    fi
    
    if [ "${closed_count}" -gt 0 ] && type log_to_file >/dev/null 2>&1; then
        log_to_file "INFO" "Closed ${closed_count} existing popup(s)"
    fi
    
    echo "${closed_count}"
    return 0
}

# Save popup PID to state file (atomic operation)
# Parameters:
#   $1 - popup_pid - Process ID to save
# Returns: 0 on success, 1 on failure
# This is for Enhancement #9 (Popup Queue Prevention)
save_popup_pid() {
    local popup_pid="$1"
    
    if [ -z "${popup_pid}" ] || ! [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Ensure config directory exists
    local config_dir
    config_dir=$(dirname "${POPUP_PID_FILE}")
    if [ ! -d "${config_dir}" ]; then
        mkdir -p "${config_dir}" 2>/dev/null || return 1
    fi
    
    # Atomic write: write to temp file then rename
    local temp_file
    temp_file="${POPUP_PID_FILE}.tmp"
    echo "${popup_pid}" > "${temp_file}" 2>/dev/null
    if [ $? -eq 0 ]; then
        mv "${temp_file}" "${POPUP_PID_FILE}" 2>/dev/null || return 1
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "INFO" "Saved popup PID to file: ${popup_pid}"
        fi
        return 0
    fi
    
    return 1
}

# Clean up popup PID file
# Parameters:
#   $1 - popup_pid - Process ID to verify (optional, if provided verifies it matches)
# Returns: 0 on success, 1 on failure
# This is for Enhancement #9 (Popup Queue Prevention)
cleanup_popup_pid() {
    local expected_pid="$1"
    
    if [ ! -f "${POPUP_PID_FILE}" ]; then
        return 0  # No PID file, nothing to clean up
    fi
    
    # If expected PID provided, verify it matches
    if [ -n "${expected_pid}" ] && [[ "${expected_pid}" =~ ^[0-9]+$ ]]; then
        local stored_pid
        stored_pid=$(cat "${POPUP_PID_FILE}" 2>/dev/null | tr -d '\n')
        if [ "${stored_pid}" != "${expected_pid}" ]; then
            # PID doesn't match, don't remove (might be a different popup)
            return 0
        fi
    fi
    
    # Remove PID file
    rm -f "${POPUP_PID_FILE}" 2>/dev/null
    if type log_to_file >/dev/null 2>&1; then
        if [ -n "${expected_pid}" ]; then
            log_to_file "INFO" "Cleaned up popup PID file: ${expected_pid}"
        else
            log_to_file "INFO" "Cleaned up popup PID file"
        fi
    fi
    return 0
}

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

# Display warning popup
show_warning() {
    local dialog_tool
    local display_env
    local env_type
    local display_id
    
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
    if [ "${check_interval}" -eq 1 ]; then
        interval_text="every minute"
    else
        interval_text="every ${check_interval} minutes"
    fi
    
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
    local base_message="⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Next unrestricted time: ${next_unrestricted_time}

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear ${interval_text} while you continue using your computer during these hours."
    
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
    
    local message="${base_message}${countdown_msg}"
    
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
    # Note: Window title is "Restricted Hours Alert" to avoid matching "Sleep Warning Configuration"
    local popup_pid
    local window_title="Restricted Hours Alert"
    
    case "${dialog_tool}" in
        zenity)
            # zenity doesn't support position natively, only size
            # Check if pause button should be added (Enhancement #21)
            local zenity_output_file
            zenity_output_file=$(mktemp)
            
            if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                # Add pause button based on configured duration
                local pause_button_label="Pause ${pause_duration} min"
                zenity --warning \
                    --title="${window_title}" \
                    --text="${message}" \
                    --modal \
                    --width="${width}" \
                    --height="${height}" \
                    --extra-button="${pause_button_label}" \
                    > "${zenity_output_file}" 2>/dev/null &
                popup_pid=$!
            else
                # No pause button
                zenity --warning \
                    --title="${window_title}" \
                    --text="${message}" \
                    --modal \
                    --width="${width}" \
                    --height="${height}" \
                    > "${zenity_output_file}" 2>/dev/null &
                popup_pid=$!
            fi
            
            # Reposition window after creation if position is top-left
            if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
            fi
            ;;
        yad)
            # yad supports both size and position via --geometry, --posx/--posy, or --center
            # Use --fixed to enforce dimensions (prevents YAD from auto-resizing based on text)
            # For center position, use --center flag (more reliable than geometry calculation)
            # For top-left, use --posx and --posy flags (more reliable than --geometry)
            # Check if pause button should be added (Enhancement #21)
            if [ "${popup_position}" = "center" ]; then
                # Use --center flag for proper centering
                if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                    # Add pause button based on configured duration
                    yad --warning \
                        --title="${window_title}" \
                        --text="${message}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --center \
                        --fixed \
                        --on-top \
                        --button="Pause ${pause_duration} min:${pause_duration}" \
                        --button="OK:0" \
                        2>/dev/null &
                    popup_pid=$!
                else
                    # No pause button
                    yad --warning \
                        --title="${window_title}" \
                        --text="${message}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --center \
                        --fixed \
                        --on-top \
                        2>/dev/null &
                    popup_pid=$!
                fi
            else
                # For top-left or other positions, calculate coordinates and use --posx/--posy
                local coords
                coords=$(calculate_popup_geometry "${popup_position}" "${width}" "${height}" "true")
                local pos_x pos_y
                pos_x=$(echo "${coords}" | cut -d' ' -f1)
                pos_y=$(echo "${coords}" | cut -d' ' -f2)
                
                if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                    # Add pause button based on configured duration
                    yad --warning \
                        --title="${window_title}" \
                        --text="${message}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --posx="${pos_x}" \
                        --posy="${pos_y}" \
                        --fixed \
                        --on-top \
                        --button="Pause ${pause_duration} min:${pause_duration}" \
                        --button="OK:0" \
                        2>/dev/null &
                    popup_pid=$!
                else
                    # No pause button
                    yad --warning \
                        --title="${window_title}" \
                        --text="${message}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --posx="${pos_x}" \
                        --posy="${pos_y}" \
                        --fixed \
                        --on-top \
                        2>/dev/null &
                    popup_pid=$!
                fi
                
                # Also reposition as backup in case --posx/--posy doesn't work properly (top-left only)
                if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                    reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
                fi
            fi
            ;;
        kdialog)
            # kdialog --geometry is not supported for --sorry dialogs (only works for --textbox and --textinputbox)
            # Note: kdialog doesn't support --warning, use --sorry for warning messages
            # kdialog doesn't support custom buttons on --sorry, so we'll show menu after warning closes
            kdialog --title "${window_title}" \
                --sorry "${message}" \
                2>/dev/null &
            popup_pid=$!
            # Give kdialog a moment to start
            sleep 0.2
            # Check if process is still running (if it exited immediately, popup failed)
            if ! kill -0 "${popup_pid}" 2>/dev/null; then
                log_to_file "ERROR" "kdialog popup failed to start (PID ${popup_pid} exited immediately)"
                popup_pid=""
            fi
            
            # Reposition window after creation if position is top-left
            if [ -n "${popup_pid}" ] && [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
            fi
            ;;
    esac
    
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
            notify-send "Restricted Hours Alert" "You are using your computer during restricted hours. Please consider resting." >/dev/null 2>&1
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
        
        # Clean up old PID file before killing old popup (Enhancement #9)
        cleanup_popup_pid "${old_pid}"
        
        # Kill existing popup if still running
        if kill -0 "${popup_pid}" 2>/dev/null; then
            kill "${popup_pid}" 2>/dev/null
            wait "${popup_pid}" 2>/dev/null
        fi
        
        # Reopen popup with updated message, preserving pause button if available
        case "${dialog_tool}" in
            zenity)
                # Recreate output file if it doesn't exist (for pause button handling)
                if [ -z "${zenity_output_file}" ]; then
                    zenity_output_file=$(mktemp)
                fi
                
                if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                    # Add pause button based on configured duration
                    local pause_button_label="Pause ${pause_duration} min"
                    zenity --warning \
                        --title="${window_title}" \
                        --text="${updated_message}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --extra-button="${pause_button_label}" \
                        > "${zenity_output_file}" 2>/dev/null &
                    popup_pid=$!
                else
                    # No pause button
                    zenity --warning \
                        --title="${window_title}" \
                        --text="${updated_message}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        > "${zenity_output_file}" 2>/dev/null &
                    popup_pid=$!
                fi
                
                # Reposition if needed (top-left only)
                if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                    reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
                fi
                ;;
            yad)
                # Use same positioning approach as initial popup
                if [ "${popup_position}" = "center" ]; then
                    # Use --center flag for proper centering
                    if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                        # Add pause button based on configured duration
                        yad --warning \
                            --title="${window_title}" \
                            --text="${updated_message}" \
                            --modal \
                            --width="${width}" \
                            --height="${height}" \
                            --center \
                            --fixed \
                            --on-top \
                            --button="Pause ${pause_duration} min:${pause_duration}" \
                            --button="OK:0" \
                            2>/dev/null &
                        popup_pid=$!
                    else
                        # No pause button
                        yad --warning \
                            --title="${window_title}" \
                            --text="${updated_message}" \
                            --modal \
                            --width="${width}" \
                            --height="${height}" \
                            --center \
                            --fixed \
                            --on-top \
                            2>/dev/null &
                        popup_pid=$!
                    fi
                else
                    # For top-left or other positions, calculate coordinates and use --posx/--posy
                    local coords
                    coords=$(calculate_popup_geometry "${popup_position}" "${width}" "${height}" "true")
                    local pos_x pos_y
                    pos_x=$(echo "${coords}" | cut -d' ' -f1)
                    pos_y=$(echo "${coords}" | cut -d' ' -f2)
                    
                    if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                        # Add pause button based on configured duration
                        yad --warning \
                            --title="${window_title}" \
                            --text="${updated_message}" \
                            --modal \
                            --width="${width}" \
                            --height="${height}" \
                            --posx="${pos_x}" \
                            --posy="${pos_y}" \
                            --fixed \
                            --on-top \
                            --button="Pause ${pause_duration} min:${pause_duration}" \
                            --button="OK:0" \
                            2>/dev/null &
                        popup_pid=$!
                    else
                        # No pause button
                        yad --warning \
                            --title="${window_title}" \
                            --text="${updated_message}" \
                            --modal \
                            --width="${width}" \
                            --height="${height}" \
                            --posx="${pos_x}" \
                            --posy="${pos_y}" \
                            --fixed \
                            --on-top \
                            2>/dev/null &
                        popup_pid=$!
                    fi
                    
                    # Reposition as backup (top-left only)
                    if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                        reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
                    fi
                fi
                ;;
            kdialog)
                kdialog --title "${window_title}" \
                    --sorry "${updated_message}" \
                    2>/dev/null &
                popup_pid=$!
                
                # Reposition if needed (top-left only)
                if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                    reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
                fi
                ;;
        esac
        
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
            
            # Safety check: if elapsed exceeds min_display_time, break immediately
            if [ "${elapsed}" -ge "${min_display_time}" ]; then
                remaining=0
                break
            fi
            
            # Check if popup is still running
            if ! kill -0 "${popup_pid}" 2>/dev/null; then
                # Popup was closed - check if it was due to pause button click (Enhancement #21)
                local popup_exit_code=0
                wait "${popup_pid}" 2>/dev/null
                popup_exit_code=$?
                
                # Handle pause button clicks
                if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                    case "${dialog_tool}" in
                        zenity)
                            # zenity: exit code 1 = extra button clicked
                            if [ ${popup_exit_code} -eq 1 ]; then
                                local button_label
                                button_label=$(cat "${zenity_output_file}" 2>/dev/null | tr -d '\n')
                                rm -f "${zenity_output_file}"
                                
                                if [ -n "${button_label}" ] && echo "${button_label}" | grep -q "Pause.*min"; then
                                    # Extract duration from button label
                                    local clicked_duration
                                    clicked_duration=$(echo "${button_label}" | grep -oE '[0-9]+' | head -n1)
                                    
                                    if [ -n "${clicked_duration}" ] && [ "${clicked_duration}" -eq "${pause_duration}" ]; then
                                        # Activate pause
                                        if activate_pause "${clicked_duration}"; then
                                            # Show confirmation dialog
                                            local pause_end_timestamp
                                            pause_end_timestamp=$(get_pause_end_timestamp)
                                            local pause_end_time
                                            pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                            
                                            zenity --info \
                                                --title="Pause Activated" \
                                                --text="Warning popups paused until ${pause_end_time}" \
                                                --width=400 \
                                                --height=150 \
                                                --timeout=30 \
                                                2>/dev/null
                                            
                                            # Return early (bypass minimum display time)
                                            if [ -n "${popup_pid}" ]; then
                                                cleanup_popup_pid "${popup_pid}"
                                            fi
                                            return 0
                                        fi
                                    fi
                                fi
                            fi
                            rm -f "${zenity_output_file}"
                            ;;
                        yad)
                            # yad: exit code matches button value
                            if [ ${popup_exit_code} -eq "${pause_duration}" ]; then
                                # Pause button was clicked
                                if activate_pause "${pause_duration}"; then
                                    # Show confirmation dialog
                                    local pause_end_timestamp
                                    pause_end_timestamp=$(get_pause_end_timestamp)
                                    local pause_end_time
                                    pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                    
                                    yad --info \
                                        --title="Pause Activated" \
                                        --text="Warning popups paused until ${pause_end_time}" \
                                        --width=400 \
                                        --height=150 \
                                        --button="OK:0" \
                                        --timeout=30 \
                                        2>/dev/null
                                    
                                    # Return early (bypass minimum display time)
                                    if [ -n "${popup_pid}" ]; then
                                        cleanup_popup_pid "${popup_pid}"
                                    fi
                                    return 0
                                fi
                            fi
                            ;;
                        kdialog)
                            # kdialog: show menu dialog after warning closes (even during minimum display time)
                            if can_pause_today; then
                                local pause_choice
                                pause_choice=$(timeout 30 kdialog --title "Pause Warnings" \
                                    --menu "Pause warning popups for:" \
                                    "5" "5 minutes" \
                                    "10" "10 minutes" \
                                    "cancel" "Cancel" \
                                    2>/dev/null || echo "")
                                
                                if [ -n "${pause_choice}" ] && [ "${pause_choice}" != "cancel" ]; then
                                    if [ "${pause_choice}" = "5" ] || [ "${pause_choice}" = "10" ]; then
                                        if activate_pause "${pause_choice}"; then
                                            local pause_end_timestamp
                                            pause_end_timestamp=$(get_pause_end_timestamp)
                                            local pause_end_time
                                            pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                            
                                            kdialog --passivepopup "Warning popups paused until ${pause_end_time}" 30 \
                                                2>/dev/null
                                            
                                            # Return early (bypass minimum display time)
                                            if [ -n "${popup_pid}" ]; then
                                                cleanup_popup_pid "${popup_pid}"
                                            fi
                                            return 0
                                        fi
                                    fi
                                fi
                            fi
                            ;;
                    esac
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
                case "${dialog_tool}" in
                    zenity)
                        # zenity: exit code 1 = extra button clicked
                        if [ ${popup_exit_code} -eq 1 ]; then
                            local button_label
                            button_label=$(cat "${zenity_output_file}" 2>/dev/null | tr -d '\n')
                            rm -f "${zenity_output_file}"
                            
                            if [ -n "${button_label}" ] && echo "${button_label}" | grep -q "Pause.*min"; then
                                local clicked_duration
                                clicked_duration=$(echo "${button_label}" | grep -oE '[0-9]+' | head -n1)
                                
                                if [ -n "${clicked_duration}" ] && [ "${clicked_duration}" -eq "${pause_duration}" ]; then
                                    if activate_pause "${clicked_duration}"; then
                                        local pause_end_timestamp
                                        pause_end_timestamp=$(get_pause_end_timestamp)
                                        local pause_end_time
                                        pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                        
                                        zenity --info \
                                            --title="Pause Activated" \
                                            --text="Warning popups paused until ${pause_end_time}" \
                                            --width=400 \
                                            --height=150 \
                                            --timeout=30 \
                                            2>/dev/null
                                        
                                        if [ -n "${popup_pid}" ]; then
                                            cleanup_popup_pid "${popup_pid}"
                                        fi
                                        return 0
                                    fi
                                fi
                            fi
                        fi
                        rm -f "${zenity_output_file}"
                        ;;
                    yad)
                        # yad: exit code matches button value
                        if [ ${popup_exit_code} -eq "${pause_duration}" ]; then
                            if activate_pause "${pause_duration}"; then
                                local pause_end_timestamp
                                pause_end_timestamp=$(get_pause_end_timestamp)
                                local pause_end_time
                                pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                
                                yad --info \
                                    --title="Pause Activated" \
                                    --text="Warning popups paused until ${pause_end_time}" \
                                    --width=400 \
                                    --height=150 \
                                    --button="OK:0" \
                                    --timeout=30 \
                                    2>/dev/null
                                
                                if [ -n "${popup_pid}" ]; then
                                    cleanup_popup_pid "${popup_pid}"
                                fi
                                return 0
                            fi
                        fi
                        ;;
                    kdialog)
                        # kdialog: show menu dialog after warning closes
                        if can_pause_today; then
                            local pause_choice
                            pause_choice=$(timeout 30 kdialog --title "Pause Warnings" \
                                --menu "Pause warning popups for:" \
                                "5" "5 minutes" \
                                "10" "10 minutes" \
                                "cancel" "Cancel" \
                                2>/dev/null || echo "")
                            
                            if [ -n "${pause_choice}" ] && [ "${pause_choice}" != "cancel" ]; then
                                if [ "${pause_choice}" = "5" ] || [ "${pause_choice}" = "10" ]; then
                                    if activate_pause "${pause_choice}"; then
                                        local pause_end_timestamp
                                        pause_end_timestamp=$(get_pause_end_timestamp)
                                        local pause_end_time
                                        pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                        
                                        kdialog --passivepopup "Warning popups paused until ${pause_end_time}" 30 \
                                            2>/dev/null
                                        
                                        if [ -n "${popup_pid}" ]; then
                                            cleanup_popup_pid "${popup_pid}"
                                        fi
                                        return 0
                                    fi
                                fi
                            fi
                        fi
                        ;;
                esac
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
                    case "${dialog_tool}" in
                        zenity)
                            # zenity: exit code 1 = extra button clicked
                            if [ ${popup_exit_code} -eq 1 ]; then
                                local button_label
                                button_label=$(cat "${zenity_output_file}" 2>/dev/null | tr -d '\n')
                                rm -f "${zenity_output_file}"
                                
                                if [ -n "${button_label}" ] && echo "${button_label}" | grep -q "Pause.*min"; then
                                    local clicked_duration
                                    clicked_duration=$(echo "${button_label}" | grep -oE '[0-9]+' | head -n1)
                                    
                                    if [ -n "${clicked_duration}" ] && [ "${clicked_duration}" -eq "${pause_duration}" ]; then
                                        if activate_pause "${clicked_duration}"; then
                                            local pause_end_timestamp
                                            pause_end_timestamp=$(get_pause_end_timestamp)
                                            local pause_end_time
                                            pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                            
                                            zenity --info \
                                                --title="Pause Activated" \
                                                --text="Warning popups paused until ${pause_end_time}" \
                                                --width=400 \
                                                --height=150 \
                                                --timeout=30 \
                                                2>/dev/null
                                            
                                            if [ -n "${popup_pid}" ]; then
                                                cleanup_popup_pid "${popup_pid}"
                                            fi
                                            return 0
                                        fi
                                    fi
                                fi
                            fi
                            rm -f "${zenity_output_file}"
                            ;;
                        yad)
                            # yad: exit code matches button value
                            if [ ${popup_exit_code} -eq "${pause_duration}" ]; then
                                if activate_pause "${pause_duration}"; then
                                    local pause_end_timestamp
                                    pause_end_timestamp=$(get_pause_end_timestamp)
                                    local pause_end_time
                                    pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                    
                                    yad --info \
                                        --title="Pause Activated" \
                                        --text="Warning popups paused until ${pause_end_time}" \
                                        --width=400 \
                                        --height=150 \
                                        --button="OK:0" \
                                        --timeout=30 \
                                        2>/dev/null
                                    
                                    if [ -n "${popup_pid}" ]; then
                                        cleanup_popup_pid "${popup_pid}"
                                    fi
                                    return 0
                                fi
                            fi
                            ;;
                        kdialog)
                            # kdialog: show menu dialog after warning closes
                            if can_pause_today; then
                                local pause_choice
                                pause_choice=$(timeout 30 kdialog --title "Pause Warnings" \
                                    --menu "Pause warning popups for:" \
                                    "5" "5 minutes" \
                                    "10" "10 minutes" \
                                    "cancel" "Cancel" \
                                    2>/dev/null || echo "")
                                
                                if [ -n "${pause_choice}" ] && [ "${pause_choice}" != "cancel" ]; then
                                    if [ "${pause_choice}" = "5" ] || [ "${pause_choice}" = "10" ]; then
                                        if activate_pause "${pause_choice}"; then
                                            local pause_end_timestamp
                                            pause_end_timestamp=$(get_pause_end_timestamp)
                                            local pause_end_time
                                            pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                            
                                            kdialog --passivepopup "Warning popups paused until ${pause_end_time}" 30 \
                                                2>/dev/null
                                            
                                            if [ -n "${popup_pid}" ]; then
                                                cleanup_popup_pid "${popup_pid}"
                                            fi
                                            return 0
                                        fi
                                    fi
                                fi
                            fi
                            ;;
                    esac
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
