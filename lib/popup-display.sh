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
    
    # Check for available dialog tool
    dialog_tool=$(check_dialog_tool "${env_type}")
    if [ -z "${dialog_tool}" ]; then
        log_message "warning" "No dialog tool available (zenity/yad/kdialog)"
        log_to_file "ERROR" "No dialog tool available (zenity/yad/kdialog), Display: ${env_type}, Display ID: ${display_id}"
        return 1
    fi
    
    # Log dialog tool used
    log_to_file "INFO" "Using dialog tool: ${dialog_tool} (env: ${env_type})"
    
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
    local countdown_msg=""
    if [ "${min_display_time}" -gt 0 ]; then
        countdown_msg="\n\n⏱️  This popup must remain visible for ${min_display_time} more second(s) before it can be closed."
    fi
    
    local message="${base_message}${countdown_msg}"
    
    # Check for window manager tools (needed for stay-on-top and minimum display time)
    local window_tool
    window_tool=$(check_window_tools)
    
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
            # kdialog has no size/position control
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
        log_to_file "INFO" "Popup displayed successfully (PID: ${popup_pid}), Dialog tool: ${dialog_tool}, Size: ${popup_size}, Position: ${popup_position}, Min display time: ${min_display_time}s"
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
    update_popup_countdown() {
        local remaining_seconds=$1
        
        # Build updated message with countdown
        local countdown_msg="\n\n⏱️  This popup must remain visible for ${remaining_seconds} more second(s) before it can be closed."
        local updated_message="${base_message}${countdown_msg}"
        
        # Kill existing popup if still running
        if kill -0 "${popup_pid}" 2>/dev/null; then
            kill "${popup_pid}" 2>/dev/null
            wait "${popup_pid}" 2>/dev/null
        fi
        
        # Reopen popup with updated message
        case "${dialog_tool}" in
            zenity)
                zenity --warning \
                    --title="${window_title}" \
                    --text="${updated_message}" \
                    --modal \
                    --width="${width}" \
                    --height="${height}" \
                    2>/dev/null &
                popup_pid=$!
                
                # Reposition if needed (top-left only)
                if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                    reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
                fi
                ;;
            yad)
                # Use same positioning approach as initial popup
                if [ "${popup_position}" = "center" ]; then
                    # Use --center flag for proper centering
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
                else
                    # For top-left or other positions, calculate coordinates and use --posx/--posy
                    local coords
                    coords=$(calculate_popup_geometry "${popup_position}" "${width}" "${height}" "true")
                    local pos_x pos_y
                    pos_x=$(echo "${coords}" | cut -d' ' -f1)
                    pos_y=$(echo "${coords}" | cut -d' ' -f2)
                    
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
    }
    
    # If minimum display time is set, enforce it
    if [ "${min_display_time}" -gt 0 ] && [ -n "${popup_pid}" ]; then
        # Try to make window unclosable if window tools are available
        if [ -n "${window_tool}" ]; then
            make_window_unclosable "${window_title}" "${window_tool}" "${min_display_time}"
        fi
        
        # Wait for minimum display time, showing countdown
        local elapsed=0
        local remaining=${min_display_time}
        
        while [ "${elapsed}" -lt "${min_display_time}" ]; do
            sleep 1
            elapsed=$((elapsed + 1))
            remaining=$((min_display_time - elapsed))
            
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
                                                2>/dev/null
                                            
                                            # Return early (bypass minimum display time)
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
                                        2>/dev/null
                                    
                                    # Return early (bypass minimum display time)
                                    return 0
                                fi
                            fi
                            ;;
                        kdialog)
                            # kdialog: show menu dialog after warning closes (even during minimum display time)
                            if can_pause_today; then
                                local pause_choice
                                pause_choice=$(kdialog --title "Pause Warnings" \
                                    --menu "Pause warning popups for:" \
                                    "5" "5 minutes" \
                                    "10" "10 minutes" \
                                    "cancel" "Cancel" \
                                    2>/dev/null)
                                
                                if [ -n "${pause_choice}" ] && [ "${pause_choice}" != "cancel" ]; then
                                    if [ "${pause_choice}" = "5" ] || [ "${pause_choice}" = "10" ]; then
                                        if activate_pause "${pause_choice}"; then
                                            local pause_end_timestamp
                                            pause_end_timestamp=$(get_pause_end_timestamp)
                                            local pause_end_time
                                            pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                            
                                            kdialog --title "Pause Activated" \
                                                --msgbox "Warning popups paused until ${pause_end_time}" \
                                                2>/dev/null
                                            
                                            # Return early (bypass minimum display time)
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
            elif [ $((elapsed % 5)) -eq 0 ] && [ "${elapsed}" -gt 0 ]; then
                # Update countdown every 5 seconds (at 5, 10, 15, etc.)
                update_popup_countdown "${remaining}"
            fi
        done
        
        # Re-enable window closing after timeout
        if [ -n "${window_tool}" ]; then
            reenable_window_closing "${window_title}" "${window_tool}"
        fi
        
        # Wait for user to actually close it (now they can)
        # Check if popup is still running before waiting
        if kill -0 "${popup_pid}" 2>/dev/null; then
            wait "${popup_pid}" 2>/dev/null
            local popup_exit_code=$?
            
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
                                            2>/dev/null
                                        
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
                                    2>/dev/null
                                
                                return 0
                            fi
                        fi
                        ;;
                    kdialog)
                        # kdialog: show menu dialog after warning closes
                        if can_pause_today; then
                            local pause_choice
                            pause_choice=$(kdialog --title "Pause Warnings" \
                                --menu "Pause warning popups for:" \
                                "5" "5 minutes" \
                                "10" "10 minutes" \
                                "cancel" "Cancel" \
                                2>/dev/null)
                            
                            if [ -n "${pause_choice}" ] && [ "${pause_choice}" != "cancel" ]; then
                                if [ "${pause_choice}" = "5" ] || [ "${pause_choice}" = "10" ]; then
                                    if activate_pause "${pause_choice}"; then
                                        local pause_end_timestamp
                                        pause_end_timestamp=$(get_pause_end_timestamp)
                                        local pause_end_time
                                        pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                        
                                        kdialog --title "Pause Activated" \
                                            --msgbox "Warning popups paused until ${pause_end_time}" \
                                            2>/dev/null
                                        
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
        else
            log_to_file "WARNING" "Popup process (PID ${popup_pid}) already exited before wait"
        fi
    else
        # No minimum display time, just wait normally
        if [ -n "${popup_pid}" ]; then
            # Check if popup is still running before waiting
            if kill -0 "${popup_pid}" 2>/dev/null; then
                wait "${popup_pid}" 2>/dev/null
                local popup_exit_code=$?
                
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
                                                2>/dev/null
                                            
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
                                        2>/dev/null
                                    
                                    return 0
                                fi
                            fi
                            ;;
                        kdialog)
                            # kdialog: show menu dialog after warning closes
                            if can_pause_today; then
                                local pause_choice
                                pause_choice=$(kdialog --title "Pause Warnings" \
                                    --menu "Pause warning popups for:" \
                                    "5" "5 minutes" \
                                    "10" "10 minutes" \
                                    "cancel" "Cancel" \
                                    2>/dev/null)
                                
                                if [ -n "${pause_choice}" ] && [ "${pause_choice}" != "cancel" ]; then
                                    if [ "${pause_choice}" = "5" ] || [ "${pause_choice}" = "10" ]; then
                                        if activate_pause "${pause_choice}"; then
                                            local pause_end_timestamp
                                            pause_end_timestamp=$(get_pause_end_timestamp)
                                            local pause_end_time
                                            pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                                            
                                            kdialog --title "Pause Activated" \
                                                --msgbox "Warning popups paused until ${pause_end_time}" \
                                                2>/dev/null
                                            
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
            else
                log_to_file "WARNING" "Popup process (PID ${popup_pid}) already exited before wait"
            fi
        fi
    fi
    
    return $?
}
