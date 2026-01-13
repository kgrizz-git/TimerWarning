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
LOG_FILE="${CONFIG_DIR}/warnings.log"
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10 MB max log size

# Default check interval (in minutes) - used if config file missing or invalid
DEFAULT_CHECK_INTERVAL=10

# Default popup size - used if config file missing or invalid
DEFAULT_POPUP_SIZE="medium"

# Default popup position - used if config file missing or invalid
DEFAULT_POPUP_POSITION="center"

# Default minimum display time (in seconds) - used if config file missing or invalid
DEFAULT_MIN_DISPLAY_TIME=30

# Default popup immovable setting - used if config file missing or invalid
DEFAULT_POPUP_IMMOVABLE=true

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

# File-based logging function
log_to_file() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "${CONFIG_DIR}"
    
    # Rotate log if it exceeds max size
    if [ -f "${LOG_FILE}" ] && [ -s "${LOG_FILE}" ]; then
        local log_size
        log_size=$(stat -f%s "${LOG_FILE}" 2>/dev/null || stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0)
        if [ "${log_size}" -gt "${MAX_LOG_SIZE}" ]; then
            # Rotate: keep last 1000 lines
            tail -n 1000 "${LOG_FILE}" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "${LOG_FILE}" 2>/dev/null
        fi
    fi
    
    # Append to log file
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null
}

# Detect display environment type (X11, Wayland, gamescope)
detect_display_environment() {
    # Check for Wayland first (including gamescope)
    if [ -n "${WAYLAND_DISPLAY}" ]; then
        # Check if gamescope is running
        if pgrep -x gamescope >/dev/null 2>&1 || [ -n "${GAMESCOPE_SESSION}" ]; then
            echo "gamescope"
            return 0
        else
            echo "wayland"
            return 0
        fi
    fi
    
    # Check for X11
    if [ -n "${DISPLAY}" ]; then
        echo "x11"
        return 0
    fi
    
    # Try to detect via loginctl
    if command -v loginctl >/dev/null 2>&1; then
        local session_id
        session_id=$(loginctl list-sessions --no-legend 2>/dev/null | grep "$(whoami)" | grep -v "tty" | head -n1 | awk '{print $1}')
        
        if [ -n "${session_id}" ]; then
            local session_type
            session_type=$(loginctl show-session "${session_id}" -p Type --value 2>/dev/null)
            
            if [ "${session_type}" = "wayland" ]; then
                # Check if it's gamescope
                if pgrep -x gamescope >/dev/null 2>&1; then
                    echo "gamescope"
                    return 0
                else
                    echo "wayland"
                    return 0
                fi
            elif [ "${session_type}" = "x11" ]; then
                echo "x11"
                return 0
            fi
        fi
    fi
    
    # Default fallback
    echo "unknown"
    return 1
}

# Get display identifier (DISPLAY or WAYLAND_DISPLAY value)
get_display_identifier() {
    local env_type="$1"
    
    case "${env_type}" in
        x11)
            if [ -n "${DISPLAY}" ]; then
                echo "${DISPLAY}"
                return 0
            fi
            ;;
        wayland|gamescope)
            if [ -n "${WAYLAND_DISPLAY}" ]; then
                echo "${WAYLAND_DISPLAY}"
                return 0
            fi
            ;;
    esac
    
    # Fallback: try to get from loginctl
    if command -v loginctl >/dev/null 2>&1; then
        local session_id
        session_id=$(loginctl list-sessions --no-legend 2>/dev/null | grep "$(whoami)" | grep -v "tty" | head -n1 | awk '{print $1}')
        
        if [ -n "${session_id}" ]; then
            if [ "${env_type}" = "x11" ]; then
                local display_env
                display_env=$(loginctl show-session "${session_id}" -p Display --value 2>/dev/null)
                if [ -n "${display_env}" ]; then
                    echo "${display_env}"
                    return 0
                fi
            else
                # For Wayland, try to get from session
                local wayland_display
                wayland_display=$(loginctl show-session "${session_id}" -p Display --value 2>/dev/null)
                if [ -n "${wayland_display}" ]; then
                    echo "${wayland_display}"
                    return 0
                fi
            fi
        fi
    fi
    
    # Last resort for X11
    if [ "${env_type}" = "x11" ] && [ -S "/tmp/.X11-unix/X0" ]; then
        echo ":0"
        return 0
    fi
    
    echo "unknown"
    return 1
}

# Detect if running on KDE
is_kde() {
    if [ -n "${KDE_SESSION_VERSION}" ] || [ -n "${KDE_FULL_SESSION}" ] || [ "${XDG_CURRENT_DESKTOP}" = "KDE" ] || [ "${XDG_SESSION_DESKTOP}" = "kde" ]; then
        return 0
    fi
    # Also check if KWin is running
    if pgrep -x kwin >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check if a dialog tool is available (with environment-aware priority)
check_dialog_tool() {
    # On KDE, prefer kdialog for better window manager integration
    # TEMPORARILY DISABLED: kdialog appears to have issues with window manipulation on some KDE systems
    # if is_kde && command -v kdialog >/dev/null 2>&1; then
    #     echo "kdialog"
    #     return 0
    # fi
    
    # Otherwise, use standard priority
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

# Get DISPLAY environment variable, with fallback (enhanced for Wayland and gamescope)
get_display() {
    local env_type
    env_type=$(detect_display_environment)
    
    case "${env_type}" in
        x11)
            local display_id
            display_id=$(get_display_identifier "x11")
            if [ -n "${display_id}" ] && [ "${display_id}" != "unknown" ]; then
                echo "${display_id}"
                return 0
            fi
            ;;
        wayland|gamescope)
            local wayland_id
            wayland_id=$(get_display_identifier "wayland")
            if [ -n "${wayland_id}" ] && [ "${wayland_id}" != "unknown" ]; then
                # For Wayland, try to find X11 display as fallback for tools that need it
                if [ -S "/tmp/.X11-unix/X0" ]; then
                    echo ":0"
                    return 0
                fi
                # Return wayland display identifier (will be used to set WAYLAND_DISPLAY in show_warning)
                echo "${wayland_id}"
                return 0
            fi
            ;;
    esac
    
    # Last resort: try common X11 display values
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
            height=225
            ;;
        medium)
            width=500
            height=375
            ;;
        large)
            width=875
            height=660
            ;;
        *)
            # Custom format (WIDTHxHEIGHT)
            if echo "${size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                width=$(echo "${size}" | cut -d'x' -f1)
                height=$(echo "${size}" | cut -d'x' -f2)
                # Validate dimensions
                if [ "${width}" -lt 200 ] || [ "${width}" -gt 2000 ] || [ "${height}" -lt 100 ] || [ "${height}" -gt 2000 ]; then
                    # Invalid dimensions, use medium default
                    width=500
                    height=375
                fi
            else
                # Invalid format, use medium default
                width=500
                height=375
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

# Get popup immovable setting from configuration file
get_popup_immovable() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_POPUP_IMMOVABLE}"
        return 0
    fi
    
    # Read POPUP_IMMOVABLE from config file
    local immovable
    immovable=$(grep -E "^[[:space:]]*POPUP_IMMOVABLE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    if [ "${immovable}" = "true" ] || [ "${immovable}" = "1" ] || [ "${immovable}" = "yes" ]; then
        echo "true"
        return 0
    elif [ "${immovable}" = "false" ] || [ "${immovable}" = "0" ] || [ "${immovable}" = "no" ]; then
        echo "false"
        return 0
    else
        # Invalid or missing, use default
        echo "${DEFAULT_POPUP_IMMOVABLE}"
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

# Detect active window state (X11)
detect_window_state_x11() {
    local tool="$1"
    local state="unknown"
    local window_title=""
    
    # Use xdotool if available (works with both wmctrl and xdotool tool selection)
    if command -v xdotool >/dev/null 2>&1; then
        # Get active window ID
        local active_id
        active_id=$(xdotool getactivewindow 2>/dev/null)
        
        if [ -n "${active_id}" ]; then
            # Get window title
            window_title=$(xdotool getwindowname "${active_id}" 2>/dev/null)
            
            # Check window state using xprop (most reliable)
            if command -v xprop >/dev/null 2>&1; then
                local net_wm_state
                net_wm_state=$(xprop -id "${active_id}" _NET_WM_STATE 2>/dev/null)
                
                if echo "${net_wm_state}" | grep -q "_NET_WM_STATE_FULLSCREEN"; then
                    state="fullscreen"
                elif echo "${net_wm_state}" | grep -q "_NET_WM_STATE_MAXIMIZED_HORZ" && echo "${net_wm_state}" | grep -q "_NET_WM_STATE_MAXIMIZED_VERT"; then
                    state="maximized"
                else
                    state="windowed"
                fi
            else
                # Fallback: check window geometry (less reliable)
                local geometry
                geometry=$(xdotool getwindowgeometry "${active_id}" 2>/dev/null)
                # Without xprop, we can't reliably detect fullscreen
                state="windowed (detection limited)"
            fi
        fi
    elif [ "${tool}" = "wmctrl" ] && command -v wmctrl >/dev/null 2>&1; then
        # Fallback to wmctrl if xdotool not available
        # Get active window using wmctrl (limited)
        local active_list
        active_list=$(wmctrl -l 2>/dev/null | head -n1)
        if [ -n "${active_list}" ]; then
            # Extract window title (last field)
            window_title=$(echo "${active_list}" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[[:space:]]*//')
            # wmctrl alone can't reliably detect fullscreen state
            state="windowed (detection limited)"
        fi
    fi
    
    # Output format: state|title
    echo "${state}|${window_title}"
}

# Detect active window state (Wayland)
detect_window_state_wayland() {
    local env_type="$1"
    local state="unknown"
    local window_title=""
    
    # Wayland window state detection is limited
    if [ "${env_type}" = "gamescope" ]; then
        # gamescope-specific: check if a game is running
        if pgrep -x gamescope >/dev/null 2>&1; then
            # Try to detect if we're in a game (limited detection)
            # Most games in gamescope will be fullscreen
            state="fullscreen (gamescope)"
            window_title="gamescope session"
        else
            state="unknown (gamescope)"
        fi
    else
        # Try swaymsg if available (Sway/i3)
        if command -v swaymsg >/dev/null 2>&1; then
            local focused
            focused=$(swaymsg -t get_tree | grep -A 10 '"focused": true' 2>/dev/null | head -n20)
            if [ -n "${focused}" ]; then
                # Extract window title if available
                window_title=$(echo "${focused}" | grep -o '"name": "[^"]*"' 2>/dev/null | head -n1 | cut -d'"' -f4)
                # Check if fullscreen
                local fullscreen_mode
                fullscreen_mode=$(echo "${focused}" | grep -o '"fullscreen_mode": [0-9]*' 2>/dev/null | cut -d' ' -f2)
                if [ -n "${fullscreen_mode}" ] && [ "${fullscreen_mode}" != "0" ]; then
                    state="fullscreen"
                else
                    state="windowed"
                fi
            fi
        else
            # Limited detection on Wayland without swaymsg
            state="unknown (wayland - limited detection)"
        fi
    fi
    
    # Output format: state|title
    echo "${state}|${window_title}"
}

# Detect window state (wrapper function)
detect_window_state() {
    local env_type="$1"
    local window_tool="$2"
    
    case "${env_type}" in
        x11)
            if [ -n "${window_tool}" ]; then
                detect_window_state_x11 "${window_tool}"
            else
                echo "unknown|"
            fi
            ;;
        wayland|gamescope)
            detect_window_state_wayland "${env_type}"
            ;;
        *)
            echo "unknown|"
            ;;
    esac
}

# Make window unclosable and unminimizable using window manager tools
make_window_unclosable() {
    local window_title="$1"
    local tool="$2"
    local timeout="$3"
    
    if [ -z "${tool}" ] || [ "${timeout}" -eq 0 ]; then
        return 0
    fi
    
    # Check if immovable window feature is enabled
    local popup_immovable
    popup_immovable=$(get_popup_immovable)
    
    # Wait a moment for window to appear
    sleep 0.5
    
    case "${tool}" in
        wmctrl)
            # Find window by title
            local window_id
            window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
            
            if [ -n "${window_id}" ]; then
                # Make window sticky (stays on all desktops)
                wmctrl -i -r "${window_id}" -b add,sticky 2>/dev/null
                # Keep window on top (xprop commands disabled - they cause windows to close on KDE)
                # if command -v xprop >/dev/null 2>&1; then
                #     xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE _NET_WM_STATE_STAYS_ON_TOP 2>/dev/null
                # fi
                wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
                wmctrl -i -a "${window_id}" 2>/dev/null  # Also activate/raise
                
                # If immovable is enabled, start position monitoring
                if [ "${popup_immovable}" = "true" ]; then
                    make_window_immovable "${window_id}" "${tool}" "${timeout}" &
                fi
            fi
            ;;
        xdotool)
            # Find window by title
            local window_id
            window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
            
            if [ -n "${window_id}" ]; then
                # Keep window on top (xprop commands disabled - they cause windows to close on KDE)
                # Set window type to DIALOG
                # xprop -id "${window_id}" -f _NET_WM_WINDOW_TYPE 32a -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DIALOG 2>/dev/null
                # Set window state to ABOVE and STAYS_ON_TOP (this works on KDE!)
                # xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE _NET_WM_STATE_STAYS_ON_TOP 2>/dev/null
                # Also raise and focus
                xdotool windowraise "${window_id}" 2>/dev/null
                xdotool windowfocus "${window_id}" 2>/dev/null
                xdotool windowraise "${window_id}" 2>/dev/null
                
                # If immovable is enabled, start position monitoring
                if [ "${popup_immovable}" = "true" ]; then
                    make_window_immovable "${window_id}" "${tool}" "${timeout}" &
                fi
            fi
            ;;
    esac
}

# Keep window on top of other windows (with retries for reliability)
keep_window_on_top() {
    local window_title="$1"
    local tool="$2"
    local max_attempts="${3:-5}"  # Default 5 attempts if not specified
    
    if [ -z "${tool}" ]; then
        return 0
    fi
    
    local attempt=0
    local window_id=""
    
    # Try to find window with retries
    while [ "${attempt}" -lt "${max_attempts}" ] && [ -z "${window_id}" ]; do
        sleep 0.2
        case "${tool}" in
            wmctrl)
                window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
                ;;
            xdotool)
                window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
                ;;
        esac
        attempt=$((attempt + 1))
    done
    
    if [ -z "${window_id}" ]; then
        return 0  # Window not found, can't set on top
    fi
    
    # Try xprop approach for setting window properties (works well with zenity on KDE)
    # Use multiple state atoms for better compatibility
    if command -v xprop >/dev/null 2>&1; then
        # Verify window exists before setting properties
        if xprop -id "${window_id}" _NET_WM_NAME >/dev/null 2>&1; then
            # Set the ABOVE state using xprop (more reliable than wmctrl for some dialogs)
            xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE 2>/dev/null || true
        fi
    fi
    
    # Also apply standard methods for compatibility with other window managers
    case "${tool}" in
        wmctrl)
            # Set above flag
            wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
            # Activate and raise the window
            wmctrl -i -a "${window_id}" 2>/dev/null
            ;;
        xdotool)
            # Raise and focus the window multiple times for better reliability
            xdotool windowraise "${window_id}" 2>/dev/null
            xdotool windowfocus "${window_id}" 2>/dev/null
            sleep 0.1
            xdotool windowraise "${window_id}" 2>/dev/null
            xdotool windowactivate "${window_id}" 2>/dev/null
            ;;
    esac
}

# Keep window on top periodically (runs in background)
keep_window_on_top_periodic() {
    local window_title="$1"
    local tool="$2"
    local popup_pid="$3"
    local duration="${4:-300}"  # Default 5 minutes if not specified
    
    if [ -z "${tool}" ]; then
        return 0
    fi
    
    # Check every 0.5 seconds to ensure window stays on top (more aggressive)
    local elapsed=0
    local check_count=$((duration * 2))  # Check twice per second
    local check_num=0
    
    while [ "${check_num}" -lt "${check_count}" ]; do
        # Check if popup process is still running
        if [ -n "${popup_pid}" ] && ! kill -0 "${popup_pid}" 2>/dev/null; then
            # Process ended, stop monitoring
            break
        fi
        
        # Apply stay-on-top every 0.5 seconds
        keep_window_on_top "${window_title}" "${tool}" 2  # Quick retry (2 attempts)
        
        sleep 0.5
        check_num=$((check_num + 1))
    done
}

# Make window immovable by monitoring and restoring position (Method 4)
make_window_immovable() {
    local window_id="$1"
    local tool="$2"
    local timeout="$3"
    
    if [ -z "${window_id}" ] || [ -z "${tool}" ] || [ "${timeout}" -eq 0 ]; then
        return 0
    fi
    
    # Get initial position
    local initial_x initial_y
    case "${tool}" in
        xdotool)
            initial_x=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f1)
            initial_y=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f2)
            ;;
        wmctrl)
            local geometry
            geometry=$(wmctrl -lG 2>/dev/null | grep "${window_id}" | awk '{print $3, $4}')
            initial_x=$(echo "${geometry}" | awk '{print $1}')
            initial_y=$(echo "${geometry}" | awk '{print $2}')
            ;;
    esac
    
    if [ -z "${initial_x}" ] || [ -z "${initial_y}" ]; then
        # Could not get initial position, skip monitoring
        return 0
    fi
    
    # Monitor position for the duration of the timeout
    # Check 5 times per second (every 200ms)
    local check_count=$((timeout * 5))
    local check_num=0
    
    while [ "${check_num}" -lt "${check_count}" ]; do
        sleep 0.2
        
        # Check current position
        local current_x current_y
        case "${tool}" in
            xdotool)
                current_x=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f1)
                current_y=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f2)
                ;;
            wmctrl)
                local geometry
                geometry=$(wmctrl -lG 2>/dev/null | grep "${window_id}" | awk '{print $3, $4}')
                current_x=$(echo "${geometry}" | awk '{print $1}')
                current_y=$(echo "${geometry}" | awk '{print $2}')
                ;;
        esac
        
        # If position changed, restore it
        if [ -n "${current_x}" ] && [ -n "${current_y}" ]; then
            if [ "${current_x}" != "${initial_x}" ] || [ "${current_y}" != "${initial_y}" ]; then
                # Position changed, restore it
                case "${tool}" in
                    xdotool)
                        xdotool windowmove "${window_id}" "${initial_x}" "${initial_y}" 2>/dev/null
                        ;;
                    wmctrl)
                        wmctrl -i -r "${window_id}" -e 0,"${initial_x}","${initial_y}",-1,-1 2>/dev/null
                        ;;
                esac
            fi
        fi
        
        check_num=$((check_num + 1))
    done
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
# Supports both normal ranges (0-5) and overnight ranges (23-6) that span midnight
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
    
    # Both normal ranges (start < end) and overnight ranges (start > end) are valid
    # Overnight ranges like 23-6 mean 11 PM to 6 AM (spans midnight)
    # We only reject if start == end (which would be invalid)
    if [ "${start_hour}" -eq "${end_hour}" ]; then
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
# Handles both normal ranges (0-5) and overnight ranges (23-6) that span midnight
is_hour_in_single_range() {
    local current_hour="$1"
    local range="$2"
    
    local start_hour end_hour
    start_hour=$(echo "${range}" | cut -d'-' -f1)
    end_hour=$(echo "${range}" | cut -d'-' -f2)
    
    # Handle overnight ranges (start > end, spans midnight)
    # Example: 23-6 means 11 PM to 6 AM (23:00 to 05:59)
    if [ "${start_hour}" -gt "${end_hour}" ]; then
        # Overnight range: current hour >= start OR current hour < end
        if [ "${current_hour}" -ge "${start_hour}" ] || [ "${current_hour}" -lt "${end_hour}" ]; then
            return 0
        fi
    else
        # Normal range: current hour >= start AND current hour < end
        if [ "${current_hour}" -ge "${start_hour}" ] && [ "${current_hour}" -lt "${end_hour}" ]; then
            return 0
        fi
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
    local env_type
    local display_id
    
    # Detect display environment type
    env_type=$(detect_display_environment)
    display_id=$(get_display_identifier "${env_type}")
    
    # Get display environment
    display_env=$(get_display)
    if [ -z "${display_env}" ]; then
        log_message "warning" "No display available, cannot show warning popup"
        log_to_file "WARNING" "No display available, cannot show warning popup"
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
    
    # Log display environment and window state
    log_to_file "INFO" "Display environment: ${env_type}, Display ID: ${display_id}, Window state: ${window_state}, Window title: ${window_title}"
    
    # Check for available dialog tool
    dialog_tool=$(check_dialog_tool)
    if [ -z "${dialog_tool}" ]; then
        log_message "warning" "No dialog tool available (zenity/yad/kdialog)"
        log_to_file "ERROR" "No dialog tool available (zenity/yad/kdialog), Display: ${env_type}, Display ID: ${display_id}"
        return 1
    fi
    
    # Log dialog tool used
    log_to_file "INFO" "Using dialog tool: ${dialog_tool}"
    
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
    
    # Check for window manager tools (needed for stay-on-top and minimum display time)
    local window_tool
    window_tool=$(check_window_tools)
    
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
            # Give kdialog a moment to start
            sleep 0.2
            # Check if process is still running (if it exited immediately, popup failed)
            if ! kill -0 "${popup_pid}" 2>/dev/null; then
                log_to_file "ERROR" "kdialog popup failed to start (PID ${popup_pid} exited immediately)"
                popup_pid=""
            fi
            ;;
    esac
    
    # Log popup display attempt
    if [ -n "${popup_pid}" ]; then
        log_to_file "INFO" "Popup displayed successfully (PID: ${popup_pid}), Dialog tool: ${dialog_tool}, Size: ${popup_size}, Position: ${popup_position}, Min display time: ${min_display_time}s"
    else
        log_to_file "ERROR" "Failed to display popup, Dialog tool: ${dialog_tool}"
        return 1
    fi
    
    # Ensure window stays on top (always, not just during minimum display time)
    # Wait longer for window to be fully created before trying to manipulate it
    if [ -n "${window_tool}" ] && [ -n "${popup_pid}" ]; then
        # Give the window more time to appear and stabilize
        sleep 1.0
        keep_window_on_top "Sleep Warning" "${window_tool}"
        # Start periodic on-top enforcement (runs until popup closes)
        # Use minimum display time if set, otherwise default to 5 minutes
        local on_top_duration=${min_display_time}
        if [ "${on_top_duration}" -eq 0 ]; then
            on_top_duration=300  # 5 minutes default
        fi
        keep_window_on_top_periodic "Sleep Warning" "${window_tool}" "${popup_pid}" "${on_top_duration}" &
    fi
    
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
                    kdialog)
                        kdialog --title "Sleep Warning" \
                            --warning "${updated_message}" \
                            2>/dev/null &
                        popup_pid=$!
                        ;;
                esac
                
                # Re-apply window restrictions and keep on top
                if [ -n "${window_tool}" ]; then
                    sleep 0.5
                    make_window_unclosable "Sleep Warning" "${window_tool}" "${remaining}"
                    # Also ensure it stays on top
                    keep_window_on_top "Sleep Warning" "${window_tool}"
                    # Restart periodic on-top enforcement for remaining time
                    keep_window_on_top_periodic "Sleep Warning" "${window_tool}" "${popup_pid}" "${remaining}" &
                fi
            fi
        done
        
        # Re-enable window closing after timeout
        if [ -n "${window_tool}" ]; then
            reenable_window_closing "Sleep Warning" "${window_tool}"
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
        
        # Get display environment info for logging
        local env_type display_id
        env_type=$(detect_display_environment)
        display_id=$(get_display_identifier "${env_type}")
        
        # Log warning trigger with full context
        log_to_file "WARNING" "Restricted hour detected - Day: ${current_day}, Hour: ${current_hour}, Range: ${restricted_range}, Display: ${env_type}, Display ID: ${display_id}"
        
        show_warning
    else
        # Not a restricted hour, exit silently
        exit 0
    fi
}

# Run main function
main "$@"
