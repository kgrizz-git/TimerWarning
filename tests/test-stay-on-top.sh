#!/bin/bash

###############################################################################
# Test Stay-On-Top Methods for KDE/zenity
#
# This script tests different methods to keep a popup window on top
# to identify which methods work with KDE/KWin window manager.
#
# Requirements:
# - bash
# - zenity
# - xdotool or wmctrl (for window manipulation)
#
# Usage (from root project directory):
#   ./tests/test-stay-on-top.sh
###############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WINDOW_TITLE="Stay On Top Test"
TEST_DURATION=10  # Test for 10 seconds

# Check for required tools
check_tools() {
    local missing_tools=()
    
    if ! command -v zenity >/dev/null 2>&1; then
        missing_tools+=("zenity")
    fi
    
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

# Get window manipulation tool
get_window_tool() {
    if command -v xdotool >/dev/null 2>&1; then
        echo "xdotool"
    elif command -v wmctrl >/dev/null 2>&1; then
        echo "wmctrl"
    fi
}

# Find window ID by title
find_window_id() {
    local title="$1"
    local tool="$2"
    local max_attempts=10
    local attempt=0
    local window_id=""
    
    while [ "${attempt}" -lt "${max_attempts}" ] && [ -z "${window_id}" ]; do
        case "${tool}" in
            xdotool)
                # Try exact match first
                window_id=$(xdotool search --name "${title}" 2>/dev/null | head -n1)
                # If not found, try searching all zenity windows
                if [ -z "${window_id}" ]; then
                    for wid in $(xdotool search --class zenity 2>/dev/null | tail -3); do
                        local win_name
                        win_name=$(xdotool getwindowname "${wid}" 2>/dev/null)
                        if echo "${win_name}" | grep -qi "${title}"; then
                            window_id="${wid}"
                            break
                        fi
                    done
                fi
                ;;
            wmctrl)
                window_id=$(wmctrl -l | grep -i "${title}" | head -n1 | awk '{print $1}')
                ;;
        esac
        
        if [ -z "${window_id}" ]; then
            sleep 0.2
            attempt=$((attempt + 1))
        fi
    done
    
    echo "${window_id}"
}

# Show window properties for debugging
show_window_properties() {
    local window_id="$1"
    local tool="$2"
    
    if [ -z "${window_id}" ]; then
        return
    fi
    
    echo -e "\n${YELLOW}Window Properties:${NC}"
    case "${tool}" in
        xdotool)
            echo "  Window ID: ${window_id}"
            echo "  Window Name: $(xdotool getwindowname "${window_id}" 2>/dev/null)"
            echo "  Window Class: $(xdotool getwindowclassname "${window_id}" 2>/dev/null)"
            echo "  Window State (_NET_WM_STATE):"
            xprop -id "${window_id}" _NET_WM_STATE 2>/dev/null | head -1
            echo "  Window Type (_NET_WM_WINDOW_TYPE):"
            xprop -id "${window_id}" _NET_WM_WINDOW_TYPE 2>/dev/null | head -1
            echo "  Window Above (_NET_WM_STATE_ABOVE):"
            xprop -id "${window_id}" _NET_WM_STATE 2>/dev/null | grep -i ABOVE || echo "    Not set"
            ;;
        wmctrl)
            echo "  Window ID: ${window_id}"
            wmctrl -lG | grep "${window_id}" | head -1
            ;;
    esac
}

# Test Method 1: wmctrl -b add,above
test_method_1() {
    echo -e "\n${BLUE}=== Method 1: wmctrl -b add,above ===${NC}"
    
    local tool
    tool=$(get_window_tool)
    
    if [ "${tool}" != "wmctrl" ]; then
        echo -e "${YELLOW}Skipping - wmctrl not available${NC}"
        return
    fi
    
    zenity --info --title="${WINDOW_TITLE}" --text="Method 1: wmctrl -b add,above\n\nTry to bring another window on top.\nThis window should stay above others." --width=400 --height=200 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
        echo -e "${GREEN}Applied: wmctrl -i -r ${window_id} -b add,above${NC}"
        
        echo "Monitoring for ${TEST_DURATION} seconds..."
        local elapsed=0
        while [ "${elapsed}" -lt "${TEST_DURATION}" ]; do
            sleep 1
            # Re-apply every second
            wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
            elapsed=$((elapsed + 1))
            echo -e "\r${YELLOW}Time: ${elapsed}/${TEST_DURATION}s${NC}" | tr -d '\n'
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Test Method 2: xdotool windowraise
test_method_2() {
    echo -e "\n${BLUE}=== Method 2: xdotool windowraise ===${NC}"
    
    local tool
    tool=$(get_window_tool)
    
    if [ "${tool}" != "xdotool" ]; then
        echo -e "${YELLOW}Skipping - xdotool not available${NC}"
        return
    fi
    
    zenity --info --title="${WINDOW_TITLE}" --text="Method 2: xdotool windowraise\n\nTry to bring another window on top.\nThis window should stay above others." --width=400 --height=200 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        echo -e "${GREEN}Applied: xdotool windowraise${NC}"
        
        echo "Monitoring for ${TEST_DURATION} seconds..."
        local elapsed=0
        while [ "${elapsed}" -lt "${TEST_DURATION}" ]; do
            sleep 0.5
            # Re-apply every 0.5 seconds
            xdotool windowraise "${window_id}" 2>/dev/null
            elapsed=$((elapsed + 1))
            if [ $((elapsed % 2)) -eq 0 ]; then
                echo -e "\r${YELLOW}Time: $((elapsed/2))/${TEST_DURATION}s${NC}" | tr -d '\n'
            fi
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Test Method 3: xprop _NET_WM_STATE_ABOVE
test_method_3() {
    echo -e "\n${BLUE}=== Method 3: xprop _NET_WM_STATE_ABOVE ===${NC}"
    
    local tool
    tool=$(get_window_tool)
    
    if [ "${tool}" != "xdotool" ]; then
        echo -e "${YELLOW}Skipping - xdotool not available${NC}"
        return
    fi
    
    zenity --info --title="${WINDOW_TITLE}" --text="Method 3: xprop _NET_WM_STATE_ABOVE\n\nTry to bring another window on top.\nThis window should stay above others." --width=400 --height=200 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE 2>/dev/null
        echo -e "${GREEN}Applied: xprop _NET_WM_STATE_ABOVE${NC}"
        
        echo "Monitoring for ${TEST_DURATION} seconds..."
        local elapsed=0
        while [ "${elapsed}" -lt "${TEST_DURATION}" ]; do
            sleep 1
            # Re-apply every second
            xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE 2>/dev/null
            elapsed=$((elapsed + 1))
            echo -e "\r${YELLOW}Time: ${elapsed}/${TEST_DURATION}s${NC}" | tr -d '\n'
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Test Method 4: Combined (windowraise + xprop)
test_method_4() {
    echo -e "\n${BLUE}=== Method 4: Combined (windowraise + xprop) ===${NC}"
    
    local tool
    tool=$(get_window_tool)
    
    if [ "${tool}" != "xdotool" ]; then
        echo -e "${YELLOW}Skipping - xdotool not available${NC}"
        return
    fi
    
    zenity --info --title="${WINDOW_TITLE}" --text="Method 4: Combined approach\n\nTry to bring another window on top.\nThis window should stay above others." --width=400 --height=200 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        echo -e "${GREEN}Applied: Combined methods${NC}"
        
        echo "Monitoring for ${TEST_DURATION} seconds..."
        local elapsed=0
        while [ "${elapsed}" -lt "${TEST_DURATION}" ]; do
            sleep 0.5
            # Apply multiple methods every 0.5 seconds
            xdotool windowraise "${window_id}" 2>/dev/null
            xdotool windowfocus "${window_id}" 2>/dev/null
            xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE 2>/dev/null
            xdotool windowraise "${window_id}" 2>/dev/null
            elapsed=$((elapsed + 1))
            if [ $((elapsed % 2)) -eq 0 ]; then
                echo -e "\r${YELLOW}Time: $((elapsed/2))/${TEST_DURATION}s${NC}" | tr -d '\n'
            fi
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Test Method 5: KDE-specific (qdbus - multiple methods)
test_method_5() {
    echo -e "\n${BLUE}=== Method 5: KDE-specific (qdbus) ===${NC}"
    
    if ! command -v qdbus >/dev/null 2>&1; then
        echo -e "${YELLOW}Skipping - qdbus not available${NC}"
        return
    fi
    
    local tool
    tool=$(get_window_tool)
    
    zenity --info --title="${WINDOW_TITLE}" --text="Method 5: KDE qdbus\n\nTry to bring another window on top.\nThis window should stay above others." --width=400 --height=200 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        show_window_properties "${window_id}" "${tool}"
        
        # Try multiple KDE D-Bus methods
        local hex_id
        hex_id=$(printf "0x%x" "${window_id}")
        
        # Method 5a: setKeepAbove
        qdbus org.kde.KWin /KWin org.kde.KWin.setKeepAbove "${hex_id}" true 2>/dev/null
        echo -e "${GREEN}Applied: qdbus KWin setKeepAbove${NC}"
        
        # Method 5b: setOnAllDesktops (might help)
        qdbus org.kde.KWin /KWin org.kde.KWin.setOnAllDesktops "${hex_id}" true 2>/dev/null
        
        # Method 5c: Try using window ID as decimal
        qdbus org.kde.KWin /KWin org.kde.KWin.setKeepAbove "${window_id}" true 2>/dev/null
        
        echo "Monitoring for ${TEST_DURATION} seconds..."
        local elapsed=0
        while [ "${elapsed}" -lt "${TEST_DURATION}" ]; do
            sleep 0.5
            # Re-apply every 0.5 seconds with multiple methods
            qdbus org.kde.KWin /KWin org.kde.KWin.setKeepAbove "${hex_id}" true 2>/dev/null
            qdbus org.kde.KWin /KWin org.kde.KWin.setKeepAbove "${window_id}" true 2>/dev/null
            elapsed=$((elapsed + 1))
            if [ $((elapsed % 2)) -eq 0 ]; then
                echo -e "\r${YELLOW}Time: $((elapsed/2))/${TEST_DURATION}s${NC}" | tr -d '\n'
            fi
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Test Method 6: wmctrl -i -a (activate)
test_method_6() {
    echo -e "\n${BLUE}=== Method 6: wmctrl -i -a (activate) ===${NC}"
    
    local tool
    tool=$(get_window_tool)
    
    if [ "${tool}" != "wmctrl" ]; then
        echo -e "${YELLOW}Skipping - wmctrl not available${NC}"
        return
    fi
    
    zenity --info --title="${WINDOW_TITLE}" --text="Method 6: wmctrl activate\n\nTry to bring another window on top.\nThis window should stay above others." --width=400 --height=200 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        show_window_properties "${window_id}" "${tool}"
        echo -e "${GREEN}Applied: wmctrl -i -a${NC}"
        
        echo "Monitoring for ${TEST_DURATION} seconds..."
        local elapsed=0
        while [ "${elapsed}" -lt "${TEST_DURATION}" ]; do
            sleep 0.5
            # Activate every 0.5 seconds
            wmctrl -i -a "${window_id}" 2>/dev/null
            elapsed=$((elapsed + 1))
            if [ $((elapsed % 2)) -eq 0 ]; then
                echo -e "\r${YELLOW}Time: $((elapsed/2))/${TEST_DURATION}s${NC}" | tr -d '\n'
            fi
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Test Method 7: Very aggressive continuous focus/raise
test_method_7() {
    echo -e "\n${BLUE}=== Method 7: Very Aggressive (continuous focus/raise) ===${NC}"
    
    local tool
    tool=$(get_window_tool)
    
    zenity --info --title="${WINDOW_TITLE}" --text="Method 7: Very aggressive\n\nTry to bring another window on top.\nThis window should stay above others." --width=400 --height=200 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        show_window_properties "${window_id}" "${tool}"
        echo -e "${GREEN}Applied: Very aggressive continuous focus/raise${NC}"
        
        echo "Monitoring for ${TEST_DURATION} seconds (checking 10 times per second)..."
        local elapsed=0
        local check_count=$((TEST_DURATION * 10))
        local check_num=0
        
        while [ "${check_num}" -lt "${check_count}" ]; do
            sleep 0.1
            # Apply all methods every 0.1 seconds (very aggressive)
            case "${tool}" in
                xdotool)
                    xdotool windowfocus "${window_id}" 2>/dev/null
                    xdotool windowraise "${window_id}" 2>/dev/null
                    xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE 2>/dev/null
                    ;;
                wmctrl)
                    wmctrl -i -a "${window_id}" 2>/dev/null
                    wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
                    ;;
            esac
            
            # Also try KDE method if available
            if command -v qdbus >/dev/null 2>&1; then
                local hex_id
                hex_id=$(printf "0x%x" "${window_id}")
                qdbus org.kde.KWin /KWin org.kde.KWin.setKeepAbove "${hex_id}" true 2>/dev/null
            fi
            
            check_num=$((check_num + 1))
            if [ $((check_num % 10)) -eq 0 ]; then
                elapsed=$((check_num / 10))
                echo -e "\r${YELLOW}Time: ${elapsed}/${TEST_DURATION}s${NC}" | tr -d '\n'
            fi
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Test Method 8: Using kdialog instead of zenity
test_method_8() {
    echo -e "\n${BLUE}=== Method 8: Using kdialog (KDE-native) ===${NC}"
    
    if ! command -v kdialog >/dev/null 2>&1; then
        echo -e "${YELLOW}Skipping - kdialog not available${NC}"
        return
    fi
    
    local tool
    tool=$(get_window_tool)
    
    kdialog --title "${WINDOW_TITLE}" --msgbox "Method 8: kdialog (KDE-native)\n\nTry to bring another window on top.\nThis window should stay above others." 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        show_window_properties "${window_id}" "${tool}"
        
        # Apply all methods
        case "${tool}" in
            xdotool)
                xdotool windowraise "${window_id}" 2>/dev/null
                xdotool windowfocus "${window_id}" 2>/dev/null
                xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE 2>/dev/null
                ;;
            wmctrl)
                wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
                wmctrl -i -a "${window_id}" 2>/dev/null
                ;;
        esac
        
        # Try KDE method
        if command -v qdbus >/dev/null 2>&1; then
            local hex_id
            hex_id=$(printf "0x%x" "${window_id}")
            qdbus org.kde.KWin /KWin org.kde.KWin.setKeepAbove "${hex_id}" true 2>/dev/null
        fi
        
        echo -e "${GREEN}Applied: All methods to kdialog window${NC}"
        
        echo "Monitoring for ${TEST_DURATION} seconds..."
        local elapsed=0
        while [ "${elapsed}" -lt "${TEST_DURATION}" ]; do
            sleep 0.5
            # Re-apply every 0.5 seconds
            case "${tool}" in
                xdotool)
                    xdotool windowraise "${window_id}" 2>/dev/null
                    xdotool windowfocus "${window_id}" 2>/dev/null
                    ;;
                wmctrl)
                    wmctrl -i -a "${window_id}" 2>/dev/null
                    wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
                    ;;
            esac
            if command -v qdbus >/dev/null 2>&1; then
                local hex_id
                hex_id=$(printf "0x%x" "${window_id}")
                qdbus org.kde.KWin /KWin org.kde.KWin.setKeepAbove "${hex_id}" true 2>/dev/null
            fi
            elapsed=$((elapsed + 1))
            if [ $((elapsed % 2)) -eq 0 ]; then
                echo -e "\r${YELLOW}Time: $((elapsed/2))/${TEST_DURATION}s${NC}" | tr -d '\n'
            fi
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Test Method 9: Check if window type affects behavior
test_method_9() {
    echo -e "\n${BLUE}=== Method 9: Setting window type hints ===${NC}"
    
    local tool
    tool=$(get_window_tool)
    
    zenity --info --title="${WINDOW_TITLE}" --text="Method 9: Window type hints\n\nTry to bring another window on top.\nThis window should stay above others." --width=400 --height=200 2>/dev/null &
    local popup_pid=$!
    
    sleep 0.8
    local window_id
    window_id=$(find_window_id "${WINDOW_TITLE}" "${tool}")
    
    if [ -n "${window_id}" ]; then
        echo "Found window ID: ${window_id}"
        show_window_properties "${window_id}" "${tool}"
        
        # Set window type to DIALOG and NOTIFICATION
        xprop -id "${window_id}" -f _NET_WM_WINDOW_TYPE 32a -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DIALOG 2>/dev/null
        xprop -id "${window_id}" -f _NET_WM_WINDOW_TYPE 32a -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_NOTIFICATION 2>/dev/null
        
        # Set state to ABOVE and STAYS_ON_TOP
        xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE _NET_WM_STATE_STAYS_ON_TOP 2>/dev/null
        
        # Also try standard methods
        case "${tool}" in
            xdotool)
                xdotool windowraise "${window_id}" 2>/dev/null
                xdotool windowfocus "${window_id}" 2>/dev/null
                ;;
            wmctrl)
                wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
                wmctrl -i -a "${window_id}" 2>/dev/null
                ;;
        esac
        
        echo -e "${GREEN}Applied: Window type hints + standard methods${NC}"
        echo "New window properties:"
        show_window_properties "${window_id}" "${tool}"
        
        echo "Monitoring for ${TEST_DURATION} seconds..."
        local elapsed=0
        while [ "${elapsed}" -lt "${TEST_DURATION}" ]; do
            sleep 0.5
            # Re-apply every 0.5 seconds
            xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE _NET_WM_STATE_STAYS_ON_TOP 2>/dev/null
            case "${tool}" in
                xdotool)
                    xdotool windowraise "${window_id}" 2>/dev/null
                    ;;
                wmctrl)
                    wmctrl -i -a "${window_id}" 2>/dev/null
                    ;;
            esac
            elapsed=$((elapsed + 1))
            if [ $((elapsed % 2)) -eq 0 ]; then
                echo -e "\r${YELLOW}Time: $((elapsed/2))/${TEST_DURATION}s${NC}" | tr -d '\n'
            fi
        done
        echo -e "\r${GREEN}Test complete!${NC}          "
    else
        echo -e "${RED}Could not find window${NC}"
    fi
    
    kill "${popup_pid}" 2>/dev/null
    wait "${popup_pid}" 2>/dev/null
    sleep 1
}

# Main function
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Stay-On-Top Test Script for KDE/zenity                 ║${NC}"
    echo -e "${BLUE}║   Testing different methods to keep window on top          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    check_tools
    
    local tool
    tool=$(get_window_tool)
    echo -e "\n${GREEN}Detected window tool: ${tool}${NC}"
    
    if command -v qdbus >/dev/null 2>&1; then
        echo -e "${GREEN}KDE qdbus available: Yes${NC}"
    else
        echo -e "${YELLOW}KDE qdbus available: No${NC}"
    fi
    
    echo -e "\n${YELLOW}This will test 6 different methods.${NC}"
    echo -e "${YELLOW}Each test runs for ${TEST_DURATION} seconds.${NC}"
    echo -e "${YELLOW}Try to bring another window on top during each test.${NC}"
    echo -e "${YELLOW}Press Enter to start, or Ctrl+C to cancel...${NC}"
    read -r
    
    test_method_1
    test_method_2
    test_method_3
    test_method_4
    test_method_5
    test_method_6
    test_method_7
    test_method_8
    test_method_9
    
    echo -e "\n${GREEN}All tests completed!${NC}"
    echo -e "\n${BLUE}Summary:${NC}"
    echo "  Method 1: wmctrl -b add,above"
    echo "  Method 2: xdotool windowraise"
    echo "  Method 3: xprop _NET_WM_STATE_ABOVE"
    echo "  Method 4: Combined (windowraise + xprop)"
    echo "  Method 5: KDE qdbus (KWin setKeepAbove)"
    echo "  Method 6: wmctrl -i -a (activate)"
    echo "  Method 7: Very aggressive (10 checks/second)"
    echo "  Method 8: Using kdialog (KDE-native)"
    echo "  Method 9: Window type hints (DIALOG/NOTIFICATION)"
    echo -e "\n${YELLOW}Which method(s) kept the window on top?${NC}"
    echo -e "${YELLOW}This will help us identify the best approach for KDE.${NC}"
    echo -e "\n${YELLOW}Note: If none worked, KDE might be ignoring these hints.${NC}"
    echo -e "${YELLOW}We may need to check KDE settings or use a different approach.${NC}"
}

# Run main function
main "$@"
