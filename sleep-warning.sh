#!/bin/bash

###############################################################################
# Sleep Warning System - Main Script
#
# This script checks if the current time falls within user-defined restricted
# hours and displays a modal warning popup if usage is detected during those
# hours. It is designed to help users maintain healthy sleep schedules.
#
# Requirements:
# - bash
# - zenity (or yad/kdialog as fallback)
# - systemd (for timer integration)
# - Graphical desktop environment
#
# Configuration:
# - Reads from ~/.config/sleep-warning/sleep-warning.conf
# - Falls back to default values if config file missing
#
# Usage:
# - Typically run by systemd timer every 10 minutes
# - Can also be run manually for testing
#
# Output:
# - Displays modal warning dialog during restricted hours
# - Exits silently during non-restricted hours or if GUI unavailable
###############################################################################

# Script configuration
SCRIPT_NAME="sleep-warning"
CONFIG_DIR="${HOME}/.config/sleep-warning"
CONFIG_FILE="${CONFIG_DIR}/sleep-warning.conf"

# Default check interval (in minutes) - used if config file missing or invalid
DEFAULT_CHECK_INTERVAL=10

# Default popup size - used if config file missing or invalid
DEFAULT_POPUP_SIZE="medium"

# Default popup position - used if config file missing or invalid
DEFAULT_POPUP_POSITION="center"

# Default minimum display time (in seconds) - used if config file missing or invalid
DEFAULT_MIN_DISPLAY_TIME=30

# Default restricted hours (used if config file missing or invalid)
# Format: day_number=start_hour-end_hour
# Day numbers: 0=Sunday, 1=Monday, ..., 6=Saturday
declare -A DEFAULT_HOURS=(
    [0]="1-5"  # Sunday: 1:00 AM to 5:59 AM
    [1]="0-5"  # Monday: Midnight to 5:59 AM
    [2]="0-5"  # Tuesday: Midnight to 5:59 AM
    [3]="0-5"  # Wednesday: Midnight to 5:59 AM
    [4]="0-5"  # Thursday: Midnight to 5:59 AM
    [5]="0-5"  # Friday: Midnight to 5:59 AM
    [6]="1-5"  # Saturday: 1:00 AM to 5:59 AM
)

# Logging function (optional, logs to systemd journal if available)
log_message() {
    local level="$1"
    shift
    local message="$*"
    
    # Try to log to systemd journal if available
    if command -v logger >/dev/null 2>&1; then
        logger -t "${SCRIPT_NAME}" -p "user.${level}" "${message}"
    fi
}

# Check if a dialog tool is available
check_dialog_tool() {
    if command -v zenity >/dev/null 2>&1; then
        echo "zenity"
        return 0
    elif command -v yad >/dev/null 2>&1; then
        echo "yad"
        return 0
    elif command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"
        return 0
    else
        return 1
    fi
}

# Get DISPLAY environment variable, with fallback
get_display() {
    # First, check if DISPLAY is already set
    if [ -n "${DISPLAY}" ]; then
        echo "${DISPLAY}"
        return 0
    fi
    
    # Try to find active user session using loginctl
    if command -v loginctl >/dev/null 2>&1; then
        local session_id
        session_id=$(loginctl list-sessions --no-legend 2>/dev/null | grep "$(whoami)" | grep -v "tty" | head -n1 | awk '{print $1}')
        
        if [ -n "${session_id}" ]; then
            local display_env
            display_env=$(loginctl show-session "${session_id}" -p Display --value 2>/dev/null)
            if [ -n "${display_env}" ]; then
                echo "${display_env}"
                return 0
            fi
        fi
    fi
    
    # Last resort: try common display values
    if [ -S "/tmp/.X11-unix/X0" ]; then
        echo ":0"
        return 0
    fi
    
    return 1
}

# Get check interval from configuration file
get_check_interval() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_CHECK_INTERVAL}"
        return 0
    fi
    
    # Read CHECK_INTERVAL from config file
    local interval
    interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    if [ -n "${interval}" ] && [[ "${interval}" =~ ^[0-9]+$ ]] && [ "${interval}" -ge 1 ] && [ "${interval}" -le 60 ]; then
        echo "${interval}"
        return 0
    else
        # Invalid or missing, use default
        echo "${DEFAULT_CHECK_INTERVAL}"
        return 0
    fi
}

# Get popup size from configuration file
get_popup_size() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_POPUP_SIZE}"
        return 0
    fi
    
    # Read POPUP_SIZE from config file
    local size
    size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    if [ -z "${size}" ]; then
        echo "${DEFAULT_POPUP_SIZE}"
        return 0
    fi
    
    # Validate size
    case "${size}" in
        small|medium|large)
            echo "${size}"
            return 0
            ;;
        *)
            # Check if it's custom format (WIDTHxHEIGHT)
            if echo "${size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                echo "${size}"
                return 0
            else
                # Invalid, use default
                echo "${DEFAULT_POPUP_SIZE}"
                return 0
            fi
            ;;
    esac
}

# Convert popup size to width and height
get_popup_dimensions() {
    local size="$1"
    local width height
    
    case "${size}" in
        small)
            width=300
            height=150
            ;;
        medium)
            width=400
            height=200
            ;;
        large)
            width=500
            height=250
            ;;
        *)
            # Custom format (WIDTHxHEIGHT)
            if echo "${size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                width=$(echo "${size}" | cut -d'x' -f1)
                height=$(echo "${size}" | cut -d'x' -f2)
                # Validate dimensions
                if [ "${width}" -lt 200 ] || [ "${width}" -gt 2000 ] || [ "${height}" -lt 100 ] || [ "${height}" -gt 2000 ]; then
                    # Invalid dimensions, use medium default
                    width=400
                    height=200
                fi
            else
                # Invalid format, use medium default
                width=400
                height=200
            fi
            ;;
    esac
    
    echo "${width} ${height}"
}

# Get popup position from configuration file
get_popup_position() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_POPUP_POSITION}"
        return 0
    fi
    
    # Read POPUP_POSITION from config file
    local position
    position=$(grep -E "^[[:space:]]*POPUP_POSITION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    if [ -z "${position}" ]; then
        echo "${DEFAULT_POPUP_POSITION}"
        return 0
    fi
    
    # Validate position
    case "${position}" in
        center|top-left|top-right|bottom-left|bottom-right|top-center|bottom-center)
            echo "${position}"
            return 0
            ;;
        *)
            # Invalid, use default
            echo "${DEFAULT_POPUP_POSITION}"
            return 0
            ;;
    esac
}

# Get minimum display time from configuration file
get_min_display_time() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_MIN_DISPLAY_TIME}"
        return 0
    fi
    
    # Read POPUP_MIN_DISPLAY_TIME from config file
    local min_time
    min_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    if [ -n "${min_time}" ] && [[ "${min_time}" =~ ^[0-9]+$ ]] && [ "${min_time}" -ge 0 ] && [ "${min_time}" -le 300 ]; then
        echo "${min_time}"
        return 0
    else
        # Invalid or missing, use default
        echo "${DEFAULT_MIN_DISPLAY_TIME}"
        return 0
    fi
}

# Check if window manager tools are available
check_window_tools() {
    if command -v wmctrl >/dev/null 2>&1; then
        echo "wmctrl"
        return 0
    elif command -v xdotool >/dev/null 2>&1; then
        echo "xdotool"
        return 0
    else
        return 1
    fi
}

# Make window unclosable and unminimizable using window manager tools
make_window_unclosable() {
    local window_title="$1"
    local tool="$2"
    local timeout="$3"
    
    if [ -z "${tool}" ] || [ "${timeout}" -eq 0 ]; then
        return 0
    fi
    
    # Wait a moment for window to appear
    sleep 0.5
    
    case "${tool}" in
        wmctrl)
            # Find window by title
            local window_id
            window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
            
            if [ -n "${window_id}" ]; then
                # Remove window decorations (makes it harder to close)
                # Make window sticky (stays on all desktops)
                wmctrl -i -r "${window_id}" -b add,sticky 2>/dev/null
                # Keep window on top
                wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
            fi
            ;;
        xdotool)
            # Find window by title
            local window_id
            window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
            
            if [ -n "${window_id}" ]; then
                # Make window sticky
                xdotool set_window --overrideredirect 0 "${window_id}" 2>/dev/null
                # Keep window on top
                xdotool windowraise "${window_id}" 2>/dev/null
            fi
            ;;
    esac
}

# Re-enable window closing after timeout
reenable_window_closing() {
    local window_title="$1"
    local tool="$2"
    
    if [ -z "${tool}" ]; then
        return 0
    fi
    
    case "${tool}" in
        wmctrl)
            local window_id
            window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
            if [ -n "${window_id}" ]; then
                wmctrl -i -r "${window_id}" -b remove,sticky 2>/dev/null
            fi
            ;;
        xdotool)
            local window_id
            window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
            if [ -n "${window_id}" ]; then
                xdotool set_window --overrideredirect 0 "${window_id}" 2>/dev/null
            fi
            ;;
    esac
}

# Calculate popup position coordinates (for yad --geometry)
calculate_popup_geometry() {
    local position="$1"
    local width="$2"
    local height="$3"
    
    # Get screen dimensions (requires xrandr or xdpyinfo)
    local screen_width screen_height
    if command -v xrandr >/dev/null 2>&1; then
        local screen_info
        screen_info=$(xrandr --current 2>/dev/null | grep -E " connected " | head -n1)
        if [ -n "${screen_info}" ]; then
            screen_width=$(echo "${screen_info}" | awk '{print $4}' | cut -d'+' -f1 | cut -d'x' -f1)
            screen_height=$(echo "${screen_info}" | awk '{print $4}' | cut -d'+' -f1 | cut -d'x' -f2)
        fi
    elif command -v xdpyinfo >/dev/null 2>&1; then
        screen_width=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f1)
        screen_height=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f2)
    fi
    
    # Default to 1920x1080 if we can't detect
    screen_width=${screen_width:-1920}
    screen_height=${screen_height:-1080}
    
    local x y
    
    case "${position}" in
        center)
            x=$(( (screen_width - width) / 2 ))
            y=$(( (screen_height - height) / 2 ))
            ;;
        top-left)
            x=50
            y=50
            ;;
        top-right)
            x=$(( screen_width - width - 50 ))
            y=50
            ;;
        bottom-left)
            x=50
            y=$(( screen_height - height - 50 ))
            ;;
        bottom-right)
            x=$(( screen_width - width - 50 ))
            y=$(( screen_height - height - 50 ))
            ;;
        top-center)
            x=$(( (screen_width - width) / 2 ))
            y=50
            ;;
        bottom-center)
            x=$(( (screen_width - width) / 2 ))
            y=$(( screen_height - height - 50 ))
            ;;
        *)
            # Default to center
            x=$(( (screen_width - width) / 2 ))
            y=$(( (screen_height - height) / 2 ))
            ;;
    esac
    
    echo "${width}x${height}+${x}+${y}"
}

# Parse configuration file
parse_config() {
    local day_num="$1"
    local day_name
    
    # Convert day number to day name
    case "${day_num}" in
        0) day_name="SUNDAY" ;;
        1) day_name="MONDAY" ;;
        2) day_name="TUESDAY" ;;
        3) day_name="WEDNESDAY" ;;
        4) day_name="THURSDAY" ;;
        5) day_name="FRIDAY" ;;
        6) day_name="SATURDAY" ;;
        *) return 1 ;;
    esac
    
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        # Use default value
        echo "${DEFAULT_HOURS[${day_num}]}"
        return 0
    fi
    
    # Read config file, ignoring comments and empty lines
    local config_line
    config_line=$(grep -E "^[[:space:]]*${day_name}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | sed 's/^[[:space:]]*//' | cut -d'=' -f2 | tr -d '[:space:]')
    
    if [ -n "${config_line}" ]; then
        echo "${config_line}"
        return 0
    else
        # No configuration for this day, use default
        echo "${DEFAULT_HOURS[${day_num}]}"
        return 0
    fi
}

# Validate a single hour range (START-END format)
validate_single_range() {
    local range="$1"
    
    # Check format: should be START-END
    if ! echo "${range}" | grep -qE '^[0-9]+-[0-9]+$'; then
        return 1
    fi
    
    local start_hour end_hour
    start_hour=$(echo "${range}" | cut -d'-' -f1)
    end_hour=$(echo "${range}" | cut -d'-' -f2)
    
    # Validate hour values (0-23)
    if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ]; then
        return 1
    fi
    
    if [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
        return 1
    fi
    
    # Start should be less than end
    if [ "${start_hour}" -ge "${end_hour}" ]; then
        return 1
    fi
    
    return 0
}

# Validate hour range(s) - supports single range or comma-separated multiple ranges
validate_hour_range() {
    local ranges="$1"
    
    # Handle empty range (no restrictions)
    if [ -z "${ranges}" ]; then
        return 0
    fi
    
    # Split by comma and validate each range
    local IFS=','
    for range in ${ranges}; do
        # Trim whitespace
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if ! validate_single_range "${range}"; then
            return 1
        fi
    done
    
    return 0
}

# Check if current hour is within a single range
is_hour_in_single_range() {
    local current_hour="$1"
    local range="$2"
    
    local start_hour end_hour
    start_hour=$(echo "${range}" | cut -d'-' -f1)
    end_hour=$(echo "${range}" | cut -d'-' -f2)
    
    # Check if current hour is within range
    if [ "${current_hour}" -ge "${start_hour}" ] && [ "${current_hour}" -lt "${end_hour}" ]; then
        return 0
    fi
    
    return 1
}

# Check if current hour is within restricted range(s) - supports comma-separated multiple ranges
is_restricted_hour() {
    local current_hour="$1"
    local ranges="$2"
    
    # Handle empty range (no restrictions)
    if [ -z "${ranges}" ]; then
        return 1
    fi
    
    # Validate ranges format
    if ! validate_hour_range "${ranges}"; then
        log_message "warning" "Invalid hour range format: ${ranges}"
        return 1
    fi
    
    # Split by comma and check each range
    local IFS=','
    for range in ${ranges}; do
        # Trim whitespace
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Check if current hour is within this range
        if is_hour_in_single_range "${current_hour}" "${range}"; then
            return 0
        fi
    done
    
    return 1
}

# Display warning popup
show_warning() {
    local dialog_tool
    local display_env
    
    # Get display environment
    display_env=$(get_display)
    if [ -z "${display_env}" ]; then
        log_message "warning" "No display available, cannot show warning popup"
        return 1
    fi
    
    export DISPLAY="${display_env}"
    
    # Check for available dialog tool
    dialog_tool=$(check_dialog_tool)
    if [ -z "${dialog_tool}" ]; then
        log_message "warning" "No dialog tool available (zenity/yad/kdialog)"
        return 1
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
    
    # Add countdown message if minimum display time is set
    local countdown_msg=""
    if [ "${min_display_time}" -gt 0 ]; then
        countdown_msg="\n\nThis popup must remain visible for ${min_display_time} seconds."
    fi
    
    local message="⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear ${interval_text} while you continue using your computer during these hours.${countdown_msg}"
    
    # Check for window manager tools if minimum display time is set
    local window_tool=""
    if [ "${min_display_time}" -gt 0 ]; then
        window_tool=$(check_window_tools)
    fi
    
    # Display popup based on available tool
    local popup_pid
    case "${dialog_tool}" in
        zenity)
            # zenity doesn't support position, only size
            zenity --warning \
                --title="Sleep Warning" \
                --text="${message}" \
                --modal \
                --width="${width}" \
                --height="${height}" \
                2>/dev/null &
            popup_pid=$!
            ;;
        yad)
            # yad supports both size and position via --geometry
            local geometry
            geometry=$(calculate_popup_geometry "${popup_position}" "${width}" "${height}")
            
            yad --warning \
                --title="Sleep Warning" \
                --text="${message}" \
                --modal \
                --geometry="${geometry}" \
                --on-top \
                2>/dev/null &
            popup_pid=$!
            ;;
        kdialog)
            # kdialog has limited size/position control
            kdialog --title "Sleep Warning" \
                --warning "${message}" \
                2>/dev/null &
            popup_pid=$!
            ;;
    esac
    
    # If minimum display time is set, enforce it
    if [ "${min_display_time}" -gt 0 ] && [ -n "${popup_pid}" ]; then
        # Try to make window unclosable if window tools are available
        if [ -n "${window_tool}" ]; then
            make_window_unclosable "Sleep Warning" "${window_tool}" "${min_display_time}"
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
                # Popup was closed prematurely, reopen it with updated countdown
                local countdown_msg="\n\n⏱️  This popup must remain visible for ${remaining} more second(s) before it can be closed."
                local updated_message="${message%${countdown_msg}*}${countdown_msg}"
                
                case "${dialog_tool}" in
                    zenity)
                        zenity --warning \
                            --title="Sleep Warning" \
                            --text="${updated_message}" \
                            --modal \
                            --width="${width}" \
                            --height="${height}" \
                            2>/dev/null &
                        popup_pid=$!
                        ;;
                    yad)
                        local geometry
                        geometry=$(calculate_popup_geometry "${popup_position}" "${width}" "${height}")
                        yad --warning \
                            --title="Sleep Warning" \
                            --text="${updated_message}" \
                            --modal \
                            --geometry="${geometry}" \
                            --on-top \
                            2>/dev/null &
                        popup_pid=$!
                        ;;
                esac
                
                # Re-apply window restrictions
                if [ -n "${window_tool}" ]; then
                    sleep 0.5
                    make_window_unclosable "Sleep Warning" "${window_tool}" "${remaining}"
                fi
            fi
        done
        
        # Re-enable window closing after timeout
        if [ -n "${window_tool}" ]; then
            reenable_window_closing "Sleep Warning" "${window_tool}"
        fi
        
        # Wait for user to actually close it (now they can)
        wait "${popup_pid}" 2>/dev/null
    else
        # No minimum display time, just wait normally
        if [ -n "${popup_pid}" ]; then
            wait "${popup_pid}" 2>/dev/null
        fi
    fi
    
    return $?
}

# Main function
main() {
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    
    # Get current hour (0-23)
    local current_hour
    current_hour=$(date +%H)
    # Remove leading zero if present
    current_hour=$((10#${current_hour}))
    
    # Parse configuration for current day
    local restricted_range
    restricted_range=$(parse_config "${current_day}")
    
    # Check if current hour is within restricted range
    if is_restricted_hour "${current_hour}" "${restricted_range}"; then
        log_message "info" "Restricted hour detected: Day ${current_day}, Hour ${current_hour}, Range ${restricted_range}"
        show_warning
    else
        # Not a restricted hour, exit silently
        exit 0
    fi
}

# Run main function
main "$@"
