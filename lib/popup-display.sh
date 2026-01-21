#!/bin/bash

###############################################################################
# Sleep Warning System - Popup Display Module
#
# This module handles the display of warning popups including:
# - Display environment detection and configuration
# - Dialog tool selection and invocation
# - Window manipulation (stay on top, immovable, minimum display time)
# - Logging of popup events
# - Calculation of next unrestricted time
#
# Dependencies:
#   - config.sh (for configuration functions)
#   - logging.sh (for logging functions)
#   - display-detection.sh (for display environment detection)
#   - desktop-environment.sh (for dialog tool detection)
#   - window-management.sh (for window manipulation)
#
# Usage: Source this file after all dependency modules
#   source lib/config.sh
#   source lib/logging.sh
#   source lib/display-detection.sh
#   source lib/desktop-environment.sh
#   source lib/window-management.sh
#   source lib/popup-display.sh
###############################################################################

###############################################################################
# Build Weekly Restricted Intervals
#
# Purpose:
#   Builds a complete weekly timeline of all restricted intervals by parsing
#   the configuration file for all 7 days and converting time ranges to
#   minute-level intervals on a unified weekly timeline (0-10079 minutes).
#
# Algorithm:
#   1. For each day (0-6: Sunday-Saturday):
#      - Parse all time ranges from config file
#      - For each range:
#        * Normal range (start < end): single segment on same day
#        * Overnight range (start > end): split into two segments spanning midnight
#      - Convert to minute offsets from start of week
#   2. Return array of "start:end" interval strings
#
# Output:
#   Array of "start:end" strings representing restricted intervals in minutes
#   Example: ("0:300", "1440:1740", "1380:1440", "0:360")
#
# Note: This function does NOT merge intervals - that's done separately
###############################################################################
build_weekly_restricted_intervals() {
    local all_intervals=()
    
    # Constants for time calculations
    local MINUTES_PER_HOUR=60
    local MINUTES_PER_DAY=1440
    
    # Process each day (indices 0-6: Sunday-Saturday)
    local i
    for i in 0 1 2 3 4 5 6; do
        # Parse configuration for this day
        local range
        range=$(parse_config "${i}")
        
        # Skip if no restrictions for this day
        if [ -z "${range}" ]; then
            continue
        fi
        
        # Calculate day offset in minutes for unified weekly timeline
        local day_offset=$((i * MINUTES_PER_DAY))
        
        # Parse comma-separated ranges (e.g., "0-5,22-23")
        local IFS=','
        local ranges=()
        read -ra ranges <<< "${range}"
        unset IFS
        
        # Process each range on this day
        local r
        for r in "${ranges[@]}"; do
            # Trim whitespace
            r=$(echo "${r}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Skip empty ranges
            [ -z "${r}" ] && continue
            
            # Parse range: "START-END"
            local start_hour="${r%%-*}"
            local end_hour="${r##*-}"
            
            # Validate hour values
            if ! [[ "${start_hour}" =~ ^[0-9]+$ ]] || ! [[ "${end_hour}" =~ ^[0-9]+$ ]]; then
                continue  # Skip invalid range
            fi
            
            if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ] || \
               [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
                continue  # Skip invalid hour values
            fi
            
            # Convert hours to minutes
            local start_minute=$((start_hour * MINUTES_PER_HOUR))
            local end_minute=$((end_hour * MINUTES_PER_HOUR))
            
            if [ "${start_hour}" -gt "${end_hour}" ]; then
                # Overnight range detected: start hour > end hour (e.g., "23-6")
                # Split into two segments that span midnight
                
                # Segment 1: From start hour to end of current day
                local day_end=$((day_offset + MINUTES_PER_DAY))
                all_intervals+=("$((day_offset + start_minute)):${day_end}")
                
                # Segment 2: From start of next day to end hour
                # Handle wrap-around: Saturday (day 6) -> Sunday (day 0)
                local next_day=$(((i + 1) % 7))
                local next_offset=$((next_day * MINUTES_PER_DAY))
                all_intervals+=("${next_offset}:$((next_offset + end_minute))")
            else
                # Normal range: start hour <= end hour (e.g., "0-5", "9-17")
                # Single segment on current day
                all_intervals+=("$((day_offset + start_minute)):$((day_offset + end_minute))")
            fi
        done
    done
    
    # Return intervals (one per line)
    printf '%s\n' "${all_intervals[@]}"
}

###############################################################################
# Get Current Minute Offset
#
# Purpose:
#   Calculates the current time as a minute offset from the start of the week
#   (Sunday 00:00 = minute 0).
#
# Output:
#   Minute offset (0-10079) representing current time in the weekly timeline
###############################################################################
get_current_minute_offset() {
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    # Remove leading zero if present
    current_day=$((10#${current_day}))
    
    # Get current hour (0-23)
    local current_hour
    current_hour=$(date +%H)
    # Remove leading zero if present
    current_hour=$((10#${current_hour}))
    
    # Get current minute (0-59)
    local current_minute
    current_minute=$(date +%M)
    # Remove leading zero if present
    current_minute=$((10#${current_minute}))
    
    # Calculate minute offset from start of week
    local MINUTES_PER_DAY=1440
    local MINUTES_PER_HOUR=60
    local offset=$((current_day * MINUTES_PER_DAY + current_hour * MINUTES_PER_HOUR + current_minute))
    
    echo "${offset}"
}

###############################################################################
# Check if Minute is Restricted
#
# Purpose:
#   Checks if a given minute offset falls within any of the restricted intervals.
#
# Parameters:
#   $1 - minute_offset: Minute offset to check (0-10079)
#   $2 - merged_intervals: Newline-separated list of "start:end" intervals
#
# Returns:
#   0 if minute is restricted, 1 if unrestricted
###############################################################################
is_minute_restricted() {
    local minute_offset=$1
    local merged_intervals="$2"
    
    # Check if minute falls within any restricted interval
    while IFS= read -r interval; do
        [ -z "${interval}" ] && continue
        
        local start="${interval%%:*}"
        local end="${interval##*:}"
        
        # Check if minute is in [start, end) range (half-open)
        if [ "${minute_offset}" -ge "${start}" ] && [ "${minute_offset}" -lt "${end}" ]; then
            return 0  # Restricted
        fi
    done <<< "${merged_intervals}"
    
    return 1  # Unrestricted
}

###############################################################################
# Format Minute Offset to Human-Readable Time
#
# Purpose:
#   Converts a minute offset (0-10079) to a human-readable time string with
#   relative day information (today, tomorrow, or day name).
#
# Parameters:
#   $1 - minute_offset: Minute offset to format (0-10079)
#   $2 - current_minute_offset: Current minute offset for relative formatting
#
# Output:
#   Human-readable time string
#   Examples:
#     - "in 15 minutes" (if < 60 minutes away)
#     - "at 5:00 AM" (if later today)
#     - "Tomorrow at 6:00 AM" (if next day)
#     - "Friday at 9:00 AM" (if 2+ days away)
###############################################################################
format_minute_offset_to_time() {
    local minute_offset=$1
    local current_minute_offset=$2
    
    local MINUTES_PER_DAY=1440
    local MINUTES_PER_HOUR=60
    local MINUTES_PER_WEEK=10080
    
    # Calculate day, hour, and minute from offset
    local day=$((minute_offset / MINUTES_PER_DAY))
    local hour=$(((minute_offset % MINUTES_PER_DAY) / MINUTES_PER_HOUR))
    local minute=$((minute_offset % MINUTES_PER_HOUR))
    
    # Calculate current day, hour, minute
    local current_day=$((current_minute_offset / MINUTES_PER_DAY))
    local current_hour=$(((current_minute_offset % MINUTES_PER_DAY) / MINUTES_PER_HOUR))
    local current_minute=$((current_minute_offset % MINUTES_PER_HOUR))
    
    # Day names
    local day_names=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
    local day_name="${day_names[${day}]}"
    
    # Format hour in 12-hour format
    local hour_12
    local am_pm
    if [ "${hour}" -eq 0 ]; then
        hour_12=12
        am_pm="AM"
    elif [ "${hour}" -lt 12 ]; then
        hour_12="${hour}"
        am_pm="AM"
    elif [ "${hour}" -eq 12 ]; then
        hour_12=12
        am_pm="PM"
    else
        hour_12=$((hour - 12))
        am_pm="PM"
    fi
    
    # Format minute with leading zero if needed
    local minute_str
    if [ "${minute}" -lt 10 ]; then
        minute_str="0${minute}"
    else
        minute_str="${minute}"
    fi
    
    # Calculate time difference in minutes
    local diff_minutes
    if [ "${minute_offset}" -ge "${current_minute_offset}" ]; then
        diff_minutes=$((minute_offset - current_minute_offset))
    else
        # Wrap around to next week
        diff_minutes=$((MINUTES_PER_WEEK - current_minute_offset + minute_offset))
    fi
    
    # Format based on time difference
    if [ "${diff_minutes}" -lt 60 ]; then
        # Less than 1 hour away
        if [ "${diff_minutes}" -eq 1 ]; then
            echo "in 1 minute"
        else
            echo "in ${diff_minutes} minutes"
        fi
    elif [ "${day}" -eq "${current_day}" ]; then
        # Same day
        echo "at ${hour_12}:${minute_str} ${am_pm}"
    elif [ "${day}" -eq $(((current_day + 1) % 7)) ]; then
        # Next day
        echo "Tomorrow at ${hour_12}:${minute_str} ${am_pm}"
    else
        # 2+ days away
        echo "${day_name} at ${hour_12}:${minute_str} ${am_pm}"
    fi
}

###############################################################################
# Get Next Unrestricted Time
#
# Purpose:
#   Calculates when the next unrestricted time will occur based on the current
#   configuration. Handles overnight intervals and multiple intervals per day.
#
# Algorithm:
#   1. Build weekly restricted intervals from config
#   2. Merge overlapping intervals
#   3. Get current minute offset
#   4. Search forward from current time to find first unrestricted minute
#   5. Format result as human-readable string
#
# Output:
#   Human-readable time string indicating when restrictions end
#   Returns empty string if no unrestricted time found (24/7 restrictions)
###############################################################################
get_next_unrestricted_time() {
    # Build all restricted intervals
    local all_intervals_str
    all_intervals_str=$(build_weekly_restricted_intervals)
    
    # Handle case where no restrictions are configured
    if [ -z "${all_intervals_str}" ]; then
        echo "now (no restrictions configured)"
        return 0
    fi
    
    # Convert newline-separated intervals to array
    local all_intervals=()
    while IFS= read -r interval; do
        [ -z "${interval}" ] && continue
        all_intervals+=("${interval}")
    done <<< "${all_intervals_str}"
    
    # Merge overlapping intervals (reuse function from configure-validation.sh)
    local merged_intervals
    merged_intervals=$(merge_overlapping_intervals "${all_intervals[@]}")
    
    # Get current minute offset
    local current_minute
    current_minute=$(get_current_minute_offset)
    
    # Search forward from current time to find first unrestricted minute
    # Optimize by jumping to end of restricted intervals instead of checking minute by minute
    local MINUTES_PER_WEEK=10080
    local search_minute="${current_minute}"
    local start_minute="${current_minute}"
    local found=false
    
    # Search up to one full week ahead
    local search_count=0
    while [ ${search_count} -lt ${MINUTES_PER_WEEK} ]; do
        # Check if this minute is restricted
        if ! is_minute_restricted "${search_minute}" "${merged_intervals}"; then
            # Found unrestricted time
            found=true
            break
        fi
        
        # Find the end of the current restricted interval to jump ahead
        local interval_end="${MINUTES_PER_WEEK}"  # Default: end of week
        while IFS= read -r interval; do
            [ -z "${interval}" ] && continue
            
            local start="${interval%%:*}"
            local end="${interval##*:}"
            
            # Check if search_minute is in this interval
            if [ "${search_minute}" -ge "${start}" ] && [ "${search_minute}" -lt "${end}" ]; then
                # We're in this interval - the next unrestricted time is at 'end'
                # Use the earliest end time (in case of overlapping intervals, though they should be merged)
                if [ "${end}" -lt "${interval_end}" ]; then
                    interval_end="${end}"
                fi
            fi
        done <<< "${merged_intervals}"
        
        # Jump to the end of the current restricted interval
        if [ "${interval_end}" -lt "${MINUTES_PER_WEEK}" ]; then
            # Normal case: end is in current week
            local jump_distance=$((interval_end - search_minute))
            search_minute="${interval_end}"
            search_count=$((search_count + jump_distance))
        else
            # Shouldn't happen if we found an interval, but fallback: move to next minute
            search_minute=$(((search_minute + 1) % MINUTES_PER_WEEK))
            search_count=$((search_count + 1))
        fi
        
        # Safety check: if we've wrapped around to start, stop (24/7 restrictions)
        if [ "${search_minute}" -eq "${start_minute}" ]; then
            break
        fi
    done
    
    # Format result
    if [ "${found}" = "true" ]; then
        format_minute_offset_to_time "${search_minute}" "${current_minute}"
    else
        # No unrestricted time found (24/7 restrictions - should never happen with validation)
        echo "No unrestricted time scheduled (24/7 restrictions active)"
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
            zenity --warning \
                --title="${window_title}" \
                --text="${message}" \
                --modal \
                --width="${width}" \
                --height="${height}" \
                2>/dev/null &
            popup_pid=$!
            
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
            if [ "${popup_position}" = "center" ]; then
                # Use --center flag for proper centering
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
            else
                # For top-left or other positions, calculate coordinates and use --posx/--posy
                local coords
                coords=$(calculate_popup_geometry "${popup_position}" "${width}" "${height}" "true")
                local pos_x pos_y
                pos_x=$(echo "${coords}" | cut -d' ' -f1)
                pos_y=$(echo "${coords}" | cut -d' ' -f2)
                
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
                
                # Also reposition as backup in case --posx/--posy doesn't work properly (top-left only)
                if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                    reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
                fi
            fi
            ;;
        kdialog)
            # kdialog has no size/position control
            # Note: kdialog doesn't support --warning, use --sorry for warning messages
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
                # Popup was closed prematurely, reopen it with updated countdown immediately
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
