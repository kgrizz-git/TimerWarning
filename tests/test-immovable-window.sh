#!/bin/bash

###############################################################################
# Test Immovable Window Methods
#
# ⚠️ NOTE: This is an old test script. Not important to run for now.
# It tests different methods for making a popup window immovable
# as described in dev-docs/FUTURE_ENHANCEMENTS.md section 13.
#
# Each method is tested one at a time with a 5-second countdown.
# The user can try to move the window during each test to see if it works.
#
# Requirements:
# - bash
# - zenity (or yad/kdialog as fallback)
# - xprop (for X11 methods)
# - xdotool or wmctrl (for window manipulation)
#
# Usage (from root project directory):
#   ./tests/test-immovable-window.sh [method_number]
#   If method_number is provided, only test that method (1-4)
#   Otherwise, test all methods sequentially
###############################################################################

# Test configuration
COUNTDOWN_TIME=5
WINDOW_TITLE="Sleep Warning Test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running on X11
check_x11() {
    # Set DISPLAY if not set
    if [ -z "${DISPLAY}" ]; then
        if [ -S "/tmp/.X11-unix/X0" ] || [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; then
            export DISPLAY=":0"
        else
            echo -e "${RED}Error: DISPLAY not set and cannot determine X11 display.${NC}"
            echo "Please set DISPLAY environment variable (e.g., export DISPLAY=:0)"
            exit 1
        fi
    fi
    
    if [ "${XDG_SESSION_TYPE}" = "wayland" ]; then
        echo -e "${RED}Error: This test requires X11. Wayland is not supported.${NC}"
        echo "Please switch to an X11 session."
        exit 1
    fi
    
    # Ensure DISPLAY is exported
    export DISPLAY
}

# Check for required tools
check_tools() {
    local missing_tools=()
    
    # Check for dialog tool
    if ! command -v zenity >/dev/null 2>&1 && ! command -v yad >/dev/null 2>&1 && ! command -v kdialog >/dev/null 2>&1; then
        missing_tools+=("zenity/yad/kdialog")
    fi
    
    # Check for xprop
    if ! command -v xprop >/dev/null 2>&1; then
        missing_tools+=("xprop")
    fi
    
    # Check for window manipulation tools
    if ! command -v xdotool >/dev/null 2>&1 && ! command -v wmctrl >/dev/null 2>&1; then
        missing_tools+=("xdotool or wmctrl")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - ${tool}"
        done
        exit 1
    fi
}

# Get dialog tool
get_dialog_tool() {
    if command -v zenity >/dev/null 2>&1; then
        echo "zenity"
    elif command -v yad >/dev/null 2>&1; then
        echo "yad"
    elif command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"
    fi
}

# Get window manipulation tool
get_window_tool() {
    if command -v xdotool >/dev/null 2>&1; then
        echo "xdotool"
    elif command -v wmctrl >/dev/null 2>&1; then
        echo "wmctrl"
    fi
}

# Find window ID by title (with retries)
find_window_id() {
    local title="$1"
    local tool="$2"
    local popup_pid="$3"
    local max_attempts=15
    local attempt=0
    local window_id=""
    
    while [ "${attempt}" -lt "${max_attempts}" ] && [ -z "${window_id}" ]; do
        case "${tool}" in
            xdotool)
                # Use the same approach as sleep-warning.sh: search by name directly
                # xdotool search --name does partial matching, so get all matches and filter
                local candidates
                candidates=$(xdotool search --name "${title}" 2>/dev/null)
                
                if [ -n "${candidates}" ]; then
                    # Check each candidate to find the best match
                    local best_match=""
                    local best_score=0
                    
                    for wid in ${candidates}; do
                        local win_name
                        win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                        
                        if [ -z "${win_name}" ]; then
                            continue
                        fi
                        
                        # Score: exact match = 100, starts with title = 75, contains title = 50
                        local score=0
                        if [ "${win_name}" = "${title}" ]; then
                            score=100
                            best_match="${wid}"
                            break  # Exact match, use it immediately
                        elif echo "${win_name}" | grep -qi "^${title}"; then
                            score=75
                        elif echo "${win_name}" | grep -qi "${title}"; then
                            score=50
                        fi
                        
                        if [ "${score}" -gt "${best_score}" ]; then
                            best_score=${score}
                            best_match="${wid}"
                        fi
                    done
                    
                    if [ -n "${best_match}" ]; then
                        window_id="${best_match}"
                    fi
                fi
                
                # Fallback: if not found by name, try searching all visible windows
                if [ -z "${window_id}" ]; then
                    # Get recent windows and check their names
                    for wid in $(xdotool search --onlyvisible --name ".*" 2>/dev/null | tail -20); do
                        local win_name
                        win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                        
                        if [ "${win_name}" = "${title}" ]; then
                            window_id="${wid}"
                            break
                        fi
                    done
                fi
                ;;
            wmctrl)
                # Try exact match first
                window_id=$(wmctrl -l | grep -i "${title}" | head -n1 | awk '{print $1}')
                # If not found, try searching all windows
                if [ -z "${window_id}" ]; then
                    window_id=$(wmctrl -l | grep -i ".*${title}.*" | head -n1 | awk '{print $1}')
                fi
                ;;
        esac
        
        if [ -z "${window_id}" ]; then
            # Check if process is still running
            if [ -n "${popup_pid}" ] && ! kill -0 "${popup_pid}" 2>/dev/null; then
                # Process died, window won't appear
                break
            fi
            sleep 0.3
            attempt=$((attempt + 1))
        fi
    done
    
    echo "${window_id}"
}

# Show popup and return PID
show_popup() {
    local dialog_tool="$1"
    local message="$2"
    local popup_pid
    
    case "${dialog_tool}" in
        zenity)
            # Use --timeout to keep it open, but we'll close it manually
            # Redirect to /dev/null to prevent blocking, and run in background
            (zenity --warning \
                --title="${WINDOW_TITLE}" \
                --text="${message}" \
                --modal \
                --width=400 \
                --height=200 \
                --timeout=999999 \
                >/dev/null 2>&1) &
            popup_pid=$!
            # Disown the process so it doesn't block
            disown $popup_pid 2>/dev/null || true
            ;;
        yad)
            # Use --timeout to keep it open, but we'll close it manually
            (yad --warning \
                --title="${WINDOW_TITLE}" \
                --text="${message}" \
                --modal \
                --width=400 \
                --height=200 \
                --on-top \
                --timeout=999999 \
                >/dev/null 2>&1) &
            popup_pid=$!
            disown $popup_pid 2>/dev/null || true
            ;;
        kdialog)
            # kdialog doesn't support timeout, but we can still background it
            (kdialog --title "${WINDOW_TITLE}" \
                --warning "${message}" \
                >/dev/null 2>&1) &
            popup_pid=$!
            disown $popup_pid 2>/dev/null || true
            ;;
    esac
    
    echo "${popup_pid}"
}

# Method 1: Use xprop to set _NET_WM_ALLOWED_ACTIONS (remove MOVE action)
test_method_1() {
    echo -e "\n${BLUE}=== Method 1: xprop _NET_WM_ALLOWED_ACTIONS ===${NC}"
    echo "This method uses xprop to remove _NET_WM_ACTION_MOVE from allowed actions."
    echo -e "${YELLOW}Try to move the window during the 5-second countdown...${NC}\n"
    
    local dialog_tool
    dialog_tool=$(get_dialog_tool)
    
    local message="⚠️  Test Method 1: xprop _NET_WM_ALLOWED_ACTIONS ⚠️

This window should be immovable.
Try dragging it - it should not move.

Countdown: ${COUNTDOWN_TIME} seconds"
    
    # Show popup (will stay open until manually closed)
    local popup_pid
    popup_pid=$(show_popup "${dialog_tool}" "${message}")
    
    # Give immediate feedback
    echo "Popup started (PID: ${popup_pid}), waiting for window to appear..."
    
    # Wait a moment for window to start appearing
    sleep 0.8
    
    # Find window ID (function will retry internally)
    local window_tool
    window_tool=$(get_window_tool)
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${window_tool}" "${popup_pid}")
    
    # Immediate feedback about window detection
    if [ -n "${window_id}" ]; then
        echo "✓ Window detected (ID: ${window_id})"
    else
        echo "✗ Window not detected yet, will continue searching during countdown..."
    fi
    
    # Debug: List all windows if not found
    if [ -z "${window_id}" ]; then
        echo "Debug: Could not find window with title '${WINDOW_TITLE}'"
        echo "Debug: Popup PID: ${popup_pid}, Process running: $(kill -0 "${popup_pid}" 2>/dev/null && echo 'yes' || echo 'no')"
        echo "Debug: Searching for windows by class:"
        case "${window_tool}" in
            xdotool)
                echo "  Trying search by name '${WINDOW_TITLE}':"
                local name_results
                name_results=$(xdotool search --name "${WINDOW_TITLE}" 2>/dev/null)
                if [ -n "${name_results}" ]; then
                    for wid in ${name_results}; do
                        local win_name
                        win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                        echo "    Found: ID=${wid}, Name='${win_name}'"
                    done
                else
                    echo "    No windows found with that name"
                fi
                echo "  Recent visible windows:"
                local found_any=false
                for wid in $(xdotool search --onlyvisible --name ".*" 2>/dev/null | tail -10); do
                    local win_name
                    win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                    if [ -n "${win_name}" ] && [ "${win_name}" != "" ]; then
                        echo "    ID: ${wid}, Name: '${win_name}'"
                        found_any=true
                    fi
                done
                if [ "${found_any}" = "false" ]; then
                    echo "    No visible windows found"
                fi
                ;;
            wmctrl)
                wmctrl -l 2>/dev/null | grep -i "zenity\|yad\|kdialog\|warning\|sleep\|test" | head -10 || echo "  No matching windows found"
                ;;
        esac
    fi
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        
        # Method 1: Remove MOVE action from _NET_WM_ALLOWED_ACTIONS
        # Get current allowed actions
        local current_actions
        current_actions=$(xprop -id "${window_id}" _NET_WM_ALLOWED_ACTIONS 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        
        if [ -n "${current_actions}" ]; then
            echo "Current allowed actions: ${current_actions}"
            
            # Remove _NET_WM_ACTION_MOVE from the list
            # Format: _NET_WM_ACTION_CLOSE _NET_WM_ACTION_RESIZE (without MOVE)
            xprop -id "${window_id}" \
                -f _NET_WM_ALLOWED_ACTIONS 32a \
                -set _NET_WM_ALLOWED_ACTIONS \
                _NET_WM_ACTION_CLOSE \
                _NET_WM_ACTION_RESIZE \
                _NET_WM_ACTION_MINIMIZE \
                _NET_WM_ACTION_MAXIMIZE_H \
                _NET_WM_ACTION_MAXIMIZE_V \
                2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Successfully set _NET_WM_ALLOWED_ACTIONS (removed MOVE)${NC}"
            else
                echo -e "${RED}✗ Failed to set _NET_WM_ALLOWED_ACTIONS${NC}"
            fi
        else
            echo -e "${YELLOW}Warning: Could not read current allowed actions${NC}"
        fi
    else
        echo -e "${RED}✗ Could not find window ID${NC}"
    fi
    
    # Countdown
    local remaining=${COUNTDOWN_TIME}
    while [ "${remaining}" -gt 0 ]; do
        echo -e "\r${YELLOW}Time remaining: ${remaining} seconds${NC}" | tr -d '\n'
        sleep 1
        remaining=$((remaining - 1))
    done
    echo -e "\r${GREEN}Test complete!${NC}          "
    
    # Kill popup
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
}

# Method 2: Use xdotool/wmctrl to set window properties
test_method_2() {
    echo -e "\n${BLUE}=== Method 2: xdotool/wmctrl Window Properties ===${NC}"
    echo "This method uses xdotool or wmctrl to set window properties that prevent movement."
    echo -e "${YELLOW}Try to move the window during the 5-second countdown...${NC}\n"
    
    local dialog_tool
    dialog_tool=$(get_dialog_tool)
    
    local message="⚠️  Test Method 2: xdotool/wmctrl Properties ⚠️

This window should be immovable.
Try dragging it - it should not move.

Countdown: ${COUNTDOWN_TIME} seconds"
    
    # Show popup (will stay open until manually closed)
    local popup_pid
    popup_pid=$(show_popup "${dialog_tool}" "${message}")
    
    # Give immediate feedback
    echo "Popup started (PID: ${popup_pid}), waiting for window to appear..."
    
    # Wait a moment for window to start appearing
    sleep 0.8
    
    # Find window ID (function will retry internally)
    local window_tool
    window_tool=$(get_window_tool)
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${window_tool}" "${popup_pid}")
    
    # Immediate feedback about window detection
    if [ -n "${window_id}" ]; then
        echo "✓ Window detected (ID: ${window_id})"
    else
        echo "✗ Window not detected yet, will continue searching during countdown..."
    fi
    
    # Debug: List all windows if not found
    if [ -z "${window_id}" ]; then
        echo "Debug: Could not find window with title '${WINDOW_TITLE}'"
        echo "Debug: Popup PID: ${popup_pid}, Process running: $(kill -0 "${popup_pid}" 2>/dev/null && echo 'yes' || echo 'no')"
        echo "Debug: Searching for windows by class:"
        case "${window_tool}" in
            xdotool)
                echo "  Trying search by name '${WINDOW_TITLE}':"
                local name_results
                name_results=$(xdotool search --name "${WINDOW_TITLE}" 2>/dev/null)
                if [ -n "${name_results}" ]; then
                    for wid in ${name_results}; do
                        local win_name
                        win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                        echo "    Found: ID=${wid}, Name='${win_name}'"
                    done
                else
                    echo "    No windows found with that name"
                fi
                echo "  Recent visible windows:"
                local found_any=false
                for wid in $(xdotool search --onlyvisible --name ".*" 2>/dev/null | tail -10); do
                    local win_name
                    win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                    if [ -n "${win_name}" ] && [ "${win_name}" != "" ]; then
                        echo "    ID: ${wid}, Name: '${win_name}'"
                        found_any=true
                    fi
                done
                if [ "${found_any}" = "false" ]; then
                    echo "    No visible windows found"
                fi
                ;;
            wmctrl)
                wmctrl -l 2>/dev/null | grep -i "zenity\|yad\|kdialog\|warning\|sleep\|test" | head -10 || echo "  No matching windows found"
                ;;
        esac
    fi
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        
        case "${window_tool}" in
            xdotool)
                # Try to set window as non-resizable and fixed position
                # Note: xdotool doesn't directly prevent movement, but we can try some properties
                xdotool windowfocus "${window_id}" 2>/dev/null
                xdotool windowraise "${window_id}" 2>/dev/null
                
                # Try setting window type hint (may help with some WMs)
                xprop -id "${window_id}" \
                    -f _NET_WM_WINDOW_TYPE 32a \
                    -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DIALOG \
                    2>/dev/null
                
                echo -e "${GREEN}✓ Applied xdotool properties (limited effect)${NC}"
                ;;
            wmctrl)
                # Set window as sticky and above
                wmctrl -i -r "${window_id}" -b add,sticky,above 2>/dev/null
                
                # Try to set window type via xprop (since wmctrl doesn't prevent movement directly)
                xprop -id "${window_id}" \
                    -f _NET_WM_WINDOW_TYPE 32a \
                    -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DIALOG \
                    2>/dev/null
                
                echo -e "${GREEN}✓ Applied wmctrl properties (limited effect)${NC}"
                ;;
        esac
    else
        echo -e "${RED}✗ Could not find window ID${NC}"
    fi
    
    # Countdown
    local remaining=${COUNTDOWN_TIME}
    while [ "${remaining}" -gt 0 ]; do
        echo -e "\r${YELLOW}Time remaining: ${remaining} seconds${NC}" | tr -d '\n'
        sleep 1
        remaining=$((remaining - 1))
    done
    echo -e "\r${GREEN}Test complete!${NC}          "
    
    # Kill popup
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
}

# Method 3: Window Manager Hints (gravity and type hints)
test_method_3() {
    echo -e "\n${BLUE}=== Method 3: Window Manager Hints (Gravity & Type) ===${NC}"
    echo "This method sets window gravity and type hints via xprop."
    echo -e "${YELLOW}Try to move the window during the 5-second countdown...${NC}\n"
    
    local dialog_tool
    dialog_tool=$(get_dialog_tool)
    
    local message="⚠️  Test Method 3: Window Manager Hints ⚠️

This window should be immovable.
Try dragging it - it should not move.

Countdown: ${COUNTDOWN_TIME} seconds"
    
    # Show popup (will stay open until manually closed)
    local popup_pid
    popup_pid=$(show_popup "${dialog_tool}" "${message}")
    
    # Give immediate feedback
    echo "Popup started (PID: ${popup_pid}), waiting for window to appear..."
    
    # Wait a moment for window to start appearing
    sleep 0.8
    
    # Find window ID (function will retry internally)
    local window_tool
    window_tool=$(get_window_tool)
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${window_tool}" "${popup_pid}")
    
    # Immediate feedback about window detection
    if [ -n "${window_id}" ]; then
        echo "✓ Window detected (ID: ${window_id})"
    else
        echo "✗ Window not detected yet, will continue searching during countdown..."
    fi
    
    # Debug: List all windows if not found
    if [ -z "${window_id}" ]; then
        echo "Debug: Could not find window with title '${WINDOW_TITLE}'"
        echo "Debug: Popup PID: ${popup_pid}, Process running: $(kill -0 "${popup_pid}" 2>/dev/null && echo 'yes' || echo 'no')"
        echo "Debug: Searching for windows by class:"
        case "${window_tool}" in
            xdotool)
                echo "  Trying search by name '${WINDOW_TITLE}':"
                local name_results
                name_results=$(xdotool search --name "${WINDOW_TITLE}" 2>/dev/null)
                if [ -n "${name_results}" ]; then
                    for wid in ${name_results}; do
                        local win_name
                        win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                        echo "    Found: ID=${wid}, Name='${win_name}'"
                    done
                else
                    echo "    No windows found with that name"
                fi
                echo "  Recent visible windows:"
                local found_any=false
                for wid in $(xdotool search --onlyvisible --name ".*" 2>/dev/null | tail -10); do
                    local win_name
                    win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                    if [ -n "${win_name}" ] && [ "${win_name}" != "" ]; then
                        echo "    ID: ${wid}, Name: '${win_name}'"
                        found_any=true
                    fi
                done
                if [ "${found_any}" = "false" ]; then
                    echo "    No visible windows found"
                fi
                ;;
            wmctrl)
                wmctrl -l 2>/dev/null | grep -i "zenity\|yad\|kdialog\|warning\|sleep\|test" | head -10 || echo "  No matching windows found"
                ;;
        esac
    fi
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        
        # Set window type to DIALOG (may help with some WMs)
        xprop -id "${window_id}" \
            -f _NET_WM_WINDOW_TYPE 32a \
            -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DIALOG \
            2>/dev/null
        
        # Try to set window gravity (STATIC gravity should prevent movement)
        # Note: This is a GTK property, may not work with all toolkits
        xprop -id "${window_id}" \
            -f _GTK_WINDOW_GRAVITY 32c \
            -set _GTK_WINDOW_GRAVITY "STATIC" \
            2>/dev/null
        
        # Also try WM_HINTS gravity (older method)
        # Get current position first
        local pos
        pos=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}')
        
        if [ -n "${pos}" ]; then
            echo "Window position: ${pos}"
            echo -e "${GREEN}✓ Applied window manager hints (gravity and type)${NC}"
        else
            echo -e "${YELLOW}Warning: Could not get window position${NC}"
        fi
    else
        echo -e "${RED}✗ Could not find window ID${NC}"
    fi
    
    # Countdown
    local remaining=${COUNTDOWN_TIME}
    while [ "${remaining}" -gt 0 ]; do
        echo -e "\r${YELLOW}Time remaining: ${remaining} seconds${NC}" | tr -d '\n'
        sleep 1
        remaining=$((remaining - 1))
    done
    echo -e "\r${GREEN}Test complete!${NC}          "
    
    # Kill popup
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
}

# Method 4: Monitor and restore position (fallback method)
test_method_4() {
    echo -e "\n${BLUE}=== Method 4: Monitor and Restore Position (Fallback) ===${NC}"
    echo "This method monitors the window position and restores it if moved."
    echo -e "${YELLOW}Try to move the window - it should snap back to original position...${NC}\n"
    
    local dialog_tool
    dialog_tool=$(get_dialog_tool)
    
    local message="⚠️  Test Method 4: Position Monitoring ⚠️

This window should snap back if moved.
Try dragging it - it should return to original position.

Countdown: ${COUNTDOWN_TIME} seconds"
    
    # Show popup (will stay open until manually closed)
    local popup_pid
    popup_pid=$(show_popup "${dialog_tool}" "${message}")
    
    # Give immediate feedback
    echo "Popup started (PID: ${popup_pid}), waiting for window to appear..."
    
    # Wait a moment for window to start appearing
    sleep 0.8
    
    # Find window ID (function will retry internally)
    local window_tool
    window_tool=$(get_window_tool)
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${window_tool}" "${popup_pid}")
    
    # Immediate feedback about window detection
    if [ -n "${window_id}" ]; then
        echo "✓ Window detected (ID: ${window_id})"
    else
        echo "✗ Window not detected yet, will continue searching during countdown..."
    fi
    
    # Debug: List all windows if not found
    if [ -z "${window_id}" ]; then
        echo "Debug: Could not find window with title '${WINDOW_TITLE}'"
        echo "Debug: Popup PID: ${popup_pid}, Process running: $(kill -0 "${popup_pid}" 2>/dev/null && echo 'yes' || echo 'no')"
        echo "Debug: Searching for windows by class:"
        case "${window_tool}" in
            xdotool)
                echo "  Trying search by name '${WINDOW_TITLE}':"
                local name_results
                name_results=$(xdotool search --name "${WINDOW_TITLE}" 2>/dev/null)
                if [ -n "${name_results}" ]; then
                    for wid in ${name_results}; do
                        local win_name
                        win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                        echo "    Found: ID=${wid}, Name='${win_name}'"
                    done
                else
                    echo "    No windows found with that name"
                fi
                echo "  Recent visible windows:"
                local found_any=false
                for wid in $(xdotool search --onlyvisible --name ".*" 2>/dev/null | tail -10); do
                    local win_name
                    win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                    if [ -n "${win_name}" ] && [ "${win_name}" != "" ]; then
                        echo "    ID: ${wid}, Name: '${win_name}'"
                        found_any=true
                    fi
                done
                if [ "${found_any}" = "false" ]; then
                    echo "    No visible windows found"
                fi
                ;;
            wmctrl)
                wmctrl -l 2>/dev/null | grep -i "zenity\|yad\|kdialog\|warning\|sleep\|test" | head -10 || echo "  No matching windows found"
                ;;
        esac
    fi
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        
        # Get initial position
        local initial_x initial_y
        case "${window_tool}" in
            xdotool)
                initial_x=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f1)
                initial_y=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f2)
                ;;
            wmctrl)
                local geometry
                geometry=$(wmctrl -lG | grep "${window_id}" | awk '{print $3, $4, $5, $6}')
                initial_x=$(echo "${geometry}" | awk '{print $1}')
                initial_y=$(echo "${geometry}" | awk '{print $2}')
                ;;
        esac
        
        if [ -n "${initial_x}" ] && [ -n "${initial_y}" ]; then
            echo "Initial position: X=${initial_x}, Y=${initial_y}"
            echo -e "${GREEN}✓ Monitoring window position...${NC}"
            
            # Monitor position in background
            (
                local check_count=$((COUNTDOWN_TIME * 5))  # Check 5 times per second
                while [ "${check_count}" -gt 0 ]; do
                    sleep 0.2  # Check every 200ms
                    
                    local current_x current_y
                    case "${window_tool}" in
                        xdotool)
                            current_x=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f1)
                            current_y=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f2)
                            ;;
                        wmctrl)
                            local geometry
                            geometry=$(wmctrl -lG | grep "${window_id}" | awk '{print $3, $4, $5, $6}')
                            current_x=$(echo "${geometry}" | awk '{print $1}')
                            current_y=$(echo "${geometry}" | awk '{print $2}')
                            ;;
                    esac
                    
                    # If position changed, restore it
                    if [ -n "${current_x}" ] && [ -n "${current_y}" ]; then
                        if [ "${current_x}" != "${initial_x}" ] || [ "${current_y}" != "${initial_y}" ]; then
                            case "${window_tool}" in
                                xdotool)
                                    xdotool windowmove "${window_id}" "${initial_x}" "${initial_y}" 2>/dev/null
                                    ;;
                                wmctrl)
                                    wmctrl -i -r "${window_id}" -e 0,"${initial_x}","${initial_y}",-1,-1 2>/dev/null
                                    ;;
                            esac
                        fi
                    fi
                    
                    check_count=$((check_count - 1))
                done
            ) &
            local monitor_pid=$!
            
            # Countdown
            local remaining=${COUNTDOWN_TIME}
            while [ "${remaining}" -gt 0 ]; do
                echo -e "\r${YELLOW}Time remaining: ${remaining} seconds${NC}" | tr -d '\n'
                sleep 1
                remaining=$((remaining - 1))
            done
            echo -e "\r${GREEN}Test complete!${NC}          "
            
            # Stop monitoring
            kill "${monitor_pid}" 2>/dev/null
            wait "${monitor_pid}" 2>/dev/null
        else
            echo -e "${RED}✗ Could not get initial window position${NC}"
            # Still do countdown
            local remaining=${COUNTDOWN_TIME}
            while [ "${remaining}" -gt 0 ]; do
                echo -e "\r${YELLOW}Time remaining: ${remaining} seconds${NC}" | tr -d '\n'
                sleep 1
                remaining=$((remaining - 1))
            done
            echo -e "\r${GREEN}Test complete!${NC}          "
        fi
    else
        echo -e "${RED}✗ Could not find window ID${NC}"
        # Still do countdown
        local remaining=${COUNTDOWN_TIME}
        while [ "${remaining}" -gt 0 ]; do
            echo -e "\r${YELLOW}Time remaining: ${remaining} seconds${NC}" | tr -d '\n'
            sleep 1
            remaining=$((remaining - 1))
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    fi
    
    # Kill popup
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
}

# Main function
main() {
    # Ensure unbuffered output by redirecting to stderr for immediate display
    exec 1>&2
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Immovable Window Test Script                           ║${NC}"
    echo -e "${BLUE}║   Testing methods to prevent window movement              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    # Check environment
    check_x11
    check_tools
    
    # Get method number from argument
    local method_num="$1"
    
    if [ -n "${method_num}" ]; then
        # Test specific method
        case "${method_num}" in
            1)
                test_method_1
                ;;
            2)
                test_method_2
                ;;
            3)
                test_method_3
                ;;
            4)
                test_method_4
                ;;
            *)
                echo -e "${RED}Error: Invalid method number. Use 1-4.${NC}"
                exit 1
                ;;
        esac
    else
        # Test all methods
        echo -e "\n${YELLOW}This will test all 4 methods sequentially.${NC}"
        echo -e "${YELLOW}Each test will run for ${COUNTDOWN_TIME} seconds.${NC}"
        echo -e "${YELLOW}Press Enter to start, or Ctrl+C to cancel...${NC}"
        read -r
        
        test_method_1
        sleep 2
        
        test_method_2
        sleep 2
        
        test_method_3
        sleep 2
        
        test_method_4
    fi
    
    echo -e "\n${GREEN}All tests completed!${NC}"
    echo -e "\n${BLUE}Summary:${NC}"
    echo "  Method 1: xprop _NET_WM_ALLOWED_ACTIONS (removes MOVE action)"
    echo "  Method 2: xdotool/wmctrl window properties"
    echo "  Method 3: Window manager hints (gravity and type)"
    echo "  Method 4: Monitor and restore position (fallback)"
    echo -e "\n${YELLOW}Note: Effectiveness depends on your window manager.${NC}"
    echo -e "${YELLOW}Some methods may not work with all window managers.${NC}"
}

# Run main function
main "$@"
