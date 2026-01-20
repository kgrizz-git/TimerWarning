#!/bin/bash

###############################################################################
# Sleep Warning System - Window Management Module
#
# This module handles all window manipulation functionality including:
# - Window manager tool detection (wmctrl/xdotool)
# - Window state detection (X11 and Wayland)
# - Window manipulation (keep on top, make immovable, etc.)
# - Popup geometry calculation
#
# Dependencies: config.sh (for get_popup_immovable())
#
# Usage: Source this file after config.sh
#   source lib/config.sh
#   source lib/window-management.sh
###############################################################################

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

# Calculate popup position coordinates (for yad --geometry or window repositioning)
# Supports only center and top-left positions (simplified for maintainability)
# Returns format: "WIDTHxHEIGHT+X+Y" for yad geometry or "X Y" if only_coords is true
calculate_popup_geometry() {
    local position="$1"
    local width="$2"
    local height="$3"
    local only_coords="${4:-false}"  # If true, only return "X Y" instead of full geometry
    
    # Get screen dimensions (requires xrandr or xdpyinfo)
    local screen_width screen_height
    if command -v xrandr >/dev/null 2>&1; then
        local screen_info geometry
        
        # Try to get primary display first (usually the main screen)
        screen_info=$(xrandr --current 2>/dev/null | grep -E " connected primary " | head -n1)
        if [ -z "${screen_info}" ]; then
            # No primary display, get first connected display
            screen_info=$(xrandr --current 2>/dev/null | grep -E " connected " | head -n1)
        fi
        
        if [ -n "${screen_info}" ]; then
            # Extract geometry using regex pattern (handles both primary and non-primary displays)
            # Pattern: WIDTHxHEIGHT+X+Y (e.g., "1920x1080+0+0" or "1280x800+2560+640")
            geometry=$(echo "${screen_info}" | grep -oE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' | head -n1)
            
            if [ -n "${geometry}" ]; then
                # Extract width and height from geometry string
                screen_width=$(echo "${geometry}" | cut -d'x' -f1)
                screen_height=$(echo "${geometry}" | cut -d'x' -f2 | cut -d'+' -f1)
            fi
        fi
    elif command -v xdpyinfo >/dev/null 2>&1; then
        local dimensions
        dimensions=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}')
        if [ -n "${dimensions}" ]; then
            screen_width=$(echo "${dimensions}" | cut -d'x' -f1)
            screen_height=$(echo "${dimensions}" | cut -d'x' -f2)
        fi
    fi
    
    # Validate dimensions are numeric and reasonable
    if ! [[ "${screen_width}" =~ ^[0-9]+$ ]] || ! [[ "${screen_height}" =~ ^[0-9]+$ ]] || \
       [ "${screen_width}" -lt 640 ] || [ "${screen_height}" -lt 480 ]; then
        # Invalid dimensions, use safe default (1920x1080)
        screen_width=1920
        screen_height=1080
    fi
    
    # Define margins that account for window decorations and panels
    # - Window decorations (title bar + borders): ~40-50px
    # - Taskbar/panel: ~40-60px
    # - Safety buffer: ~10-20px
    local margin_x=30        # Horizontal margin (left/right)
    local margin_y_top=60    # Top margin (accounts for title bar + panels)
    local margin_y_bottom=80 # Bottom margin (accounts for taskbar + title bar + decorations)
    
    local x y
    
    case "${position}" in
        center)
            x=$(( (screen_width - width) / 2 ))
            y=$(( (screen_height - height) / 2 ))
            ;;
        top-left)
            x=${margin_x}
            y=${margin_y_top}
            ;;
        *)
            # Default to center for invalid positions
            x=$(( (screen_width - width) / 2 ))
            y=$(( (screen_height - height) / 2 ))
            ;;
    esac
    
    # Bounds checking: ensure window stays fully on screen
    # Account for the fact that window managers add decorations to the content area
    local min_x=${margin_x}
    local min_y=${margin_y_top}
    local max_x=$(( screen_width - width - margin_x ))
    local max_y=$(( screen_height - height - margin_y_bottom ))
    
    # Clamp x coordinate
    if [ "${x}" -lt "${min_x}" ]; then
        x=${min_x}
    elif [ "${x}" -gt "${max_x}" ]; then
        x=${max_x}
    fi
    
    # Clamp y coordinate
    if [ "${y}" -lt "${min_y}" ]; then
        y=${min_y}
    elif [ "${y}" -gt "${max_y}" ]; then
        y=${max_y}
    fi
    
    if [ "${only_coords}" = "true" ]; then
        echo "${x} ${y}"
    else
        echo "${width}x${height}+${x}+${y}"
    fi
}

# Reposition popup window after creation (for dialog tools that don't support position)
# This is a workaround for zenity and kdialog which lack built-in position control
reposition_popup_window() {
    local window_title="$1"
    local tool="$2"
    local position="$3"
    local width="$4"
    local height="$5"
    local max_attempts="${6:-10}"  # Default 10 attempts if not specified
    
    if [ -z "${tool}" ] || [ "${position}" = "center" ]; then
        # No tool available or center position (default), skip repositioning
        return 0
    fi
    
    # Wait for window to be fully created and rendered
    sleep 1.0
    
    # Try to find and reposition window with retries
    local attempt=0
    local window_id=""
    
    while [ "${attempt}" -lt "${max_attempts}" ] && [ -z "${window_id}" ]; do
        case "${tool}" in
            wmctrl)
                window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
                ;;
            xdotool)
                window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
                ;;
        esac
        
        if [ -z "${window_id}" ]; then
            sleep 0.2
            attempt=$((attempt + 1))
        fi
    done
    
    if [ -z "${window_id}" ]; then
        # Window not found, can't reposition
        return 1
    fi
    
    # Calculate target position
    local coords
    coords=$(calculate_popup_geometry "${position}" "${width}" "${height}" "true")
    local target_x target_y
    target_x=$(echo "${coords}" | cut -d' ' -f1)
    target_y=$(echo "${coords}" | cut -d' ' -f2)
    
    # Move window to target position
    case "${tool}" in
        wmctrl)
            # wmctrl format: -e gravity,x,y,width,height (use 0 for gravity, -1 to keep size)
            wmctrl -i -r "${window_id}" -e "0,${target_x},${target_y},-1,-1" 2>/dev/null
            ;;
        xdotool)
            xdotool windowmove "${window_id}" "${target_x}" "${target_y}" 2>/dev/null
            ;;
    esac
    
    return 0
}
