#!/bin/bash

###############################################################################
# Sleep Warning System - Status Check Script
#
# This script displays the current status and configuration of the sleep
# warning system, including timer status, service status, and configured
# restricted hours.
#
# Requirements:
# - bash
# - systemctl
#
# Usage:
#   ./status.sh
#   sleep-warning-status (after installation)
#
# Output:
# - Displays current status and configuration in terminal
###############################################################################

SCRIPT_NAME="sleep-warning-status"
CONFIG_DIR="${HOME}/.config/sleep-warning"
CONFIG_FILE="${CONFIG_DIR}/sleep-warning.conf"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
TIMER_FILE="${SYSTEMD_USER_DIR}/sleep-warning.timer"
SERVICE_FILE="${SYSTEMD_USER_DIR}/sleep-warning.service"
SERVICE_NAME="sleep-warning"

# ANSI color codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_BLUE="\033[34m"
COLOR_CYAN="\033[36m"

# Check if colors are supported
if [ ! -t 1 ]; then
    # Not a terminal, disable colors
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_BLUE=""
    COLOR_CYAN=""
fi

# Print section header
print_header() {
    local title="$1"
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}${title}${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

# Print status with color
print_status() {
    local label="$1"
    local value="$2"
    local status="$3"  # "good", "warning", "error", or ""
    
    local color=""
    case "${status}" in
        good) color="${COLOR_GREEN}" ;;
        warning) color="${COLOR_YELLOW}" ;;
        error) color="${COLOR_RED}" ;;
    esac
    
    printf "  %-30s ${color}%s${COLOR_RESET}\n" "${label}:" "${value}"
}

# Format hour to 12-hour format with AM/PM
format_hour_12h() {
    local hour="$1"
    if [ "${hour}" -eq 0 ]; then
        echo "12:00 AM"
    elif [ "${hour}" -eq 12 ]; then
        echo "12:00 PM"
    elif [ "${hour}" -lt 12 ]; then
        printf "%d:00 AM" "${hour}"
    else
        printf "%d:00 PM" "$((hour - 12))"
    fi
}

# Format a single range to human-readable format
format_range_human() {
    local range="$1"
    local day_name="$2"
    
    local start_hour end_hour
    start_hour=$(echo "${range}" | cut -d'-' -f1)
    end_hour=$(echo "${range}" | cut -d'-' -f2)
    
    local start_12h end_12h
    start_12h=$(format_hour_12h "${start_hour}")
    end_12h=$(format_hour_12h "${end_hour}")
    
    # Handle overnight ranges
    if [ "${start_hour}" -gt "${end_hour}" ]; then
        echo "${start_12h} → ${end_12h} (overnight)"
    else
        echo "${start_12h} → ${end_12h}"
    fi
}

# Format multiple ranges to human-readable format
format_ranges_human() {
    local ranges="$1"
    local day_name="$2"
    
    local IFS=','
    local formatted_ranges=()
    for range in ${ranges}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        formatted_ranges+=("$(format_range_human "${range}" "${day_name}")")
    done
    
    # Join with " AND "
    local result=""
    local first=true
    for formatted in "${formatted_ranges[@]}"; do
        if [ "${first}" = "true" ]; then
            result="${formatted}"
            first=false
        else
            result="${result} AND ${formatted}"
        fi
    done
    
    echo "${result}"
}

# Check installation status
check_installation() {
    print_header "INSTALLATION STATUS"
    
    # Check if service file exists
    if [ -f "${SERVICE_FILE}" ]; then
        print_status "Service File" "Installed" "good"
    else
        print_status "Service File" "Not Installed" "error"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run './install.sh' to install the service${COLOR_RESET}"
        return 1
    fi
    
    # Check if timer file exists
    if [ -f "${TIMER_FILE}" ]; then
        print_status "Timer File" "Installed" "good"
    else
        print_status "Timer File" "Not Installed" "error"
        return 1
    fi
    
    # Check if config file exists
    if [ -f "${CONFIG_FILE}" ]; then
        print_status "Configuration File" "Found" "good"
    else
        print_status "Configuration File" "Not Found" "warning"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run 'sleep-warning-configure' or './configure.sh' to create configuration${COLOR_RESET}"
    fi
    
    return 0
}

# Check service/timer status
check_service_status() {
    print_header "SERVICE STATUS"
    
    # Check if timer is enabled
    if systemctl --user is-enabled "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
        print_status "Timer Enabled" "Yes" "good"
    else
        print_status "Timer Enabled" "No" "warning"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run './manage.sh enable' to enable the timer${COLOR_RESET}"
    fi
    
    # Check if timer is active (running)
    if systemctl --user is-active "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
        print_status "Timer Active" "Running" "good"
        
        # Get next trigger time
        local next_trigger
        next_trigger=$(systemctl --user list-timers "${SERVICE_NAME}.timer" 2>/dev/null | grep "${SERVICE_NAME}.timer" | awk '{print $1, $2, $3}')
        if [ -n "${next_trigger}" ] && [ "${next_trigger}" != "- - -" ] && [ "${next_trigger}" != "- -" ]; then
            # Remove any leading dashes if present
            next_trigger=$(echo "${next_trigger}" | sed 's/^- - //')
            if [ "${next_trigger}" != "-" ]; then
                print_status "Next Check" "${next_trigger}"
            else
                print_status "Next Check" "Calculating..." "warning"
            fi
        else
            print_status "Next Check" "Calculating..." "warning"
        fi
        
        # Get last trigger time from list-timers
        # Format: NEXT(date time tz) LEFT LAST(date time tz) PASSED UNIT ACTIVATES
        local timer_line
        timer_line=$(systemctl --user list-timers "${SERVICE_NAME}.timer" 2>/dev/null | grep "${SERVICE_NAME}.timer")
        if [ -n "${timer_line}" ]; then
            # Extract the PASSED column (shows time since last trigger)
            # Find "ago" and work backwards to get the time value(s)
            local passed
            passed=$(echo "${timer_line}" | awk '{
                for(i=1;i<=NF;i++){
                    if($i=="ago"){
                        # If previous field looks like timezone, skip it
                        if($(i-1) ~ /^[A-Z]{3,4}$/){
                            # Timezone before "ago", get the time value before that
                            if(i>=3) print $(i-2), $(i-1), $i
                        } else {
                            # No timezone, print time values
                            if(i==2) print $(i-1), $i
                            else if(i>=3) print $(i-2), $(i-1), $i
                        }
                        break
                    }
                }
            }')
            # Remove timezone if it's still there (EST, PST, etc.)
            passed=$(echo "${passed}" | sed 's/\b[A-Z]\{3,4\}\b //')
            if [ -n "${passed}" ] && [ "${passed}" != "n/a" ] && [ "${passed}" != "-" ]; then
                print_status "Last Check" "${passed}"
            fi
        fi
    else
        print_status "Timer Active" "Not Running" "error"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run './manage.sh start' to start the timer${COLOR_RESET}"
    fi
    
    # Check service status (only shows if recently triggered)
    if systemctl --user is-active "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        print_status "Service Status" "Running (check in progress)" "good"
    else
        # Check if service failed
        if systemctl --user is-failed "${SERVICE_NAME}.service" >/dev/null 2>&1; then
            print_status "Service Status" "Failed" "error"
            echo ""
            echo -e "${COLOR_YELLOW}  → Run 'systemctl --user status ${SERVICE_NAME}.service' for details${COLOR_RESET}"
        else
            print_status "Service Status" "Idle (waiting for next check)"
        fi
    fi
}

# Display configuration
show_configuration() {
    print_header "CONFIGURATION"
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "  ${COLOR_YELLOW}No configuration file found${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run 'sleep-warning-configure' or './configure.sh' to create configuration${COLOR_RESET}"
        return 1
    fi
    
    # Read check interval
    local check_interval
    check_interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${check_interval}" ]; then
        check_interval="10 (default)"
    else
        check_interval="${check_interval} minute(s)"
    fi
    print_status "Check Interval" "${check_interval}"
    
    # Read popup size
    local popup_size
    popup_size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${popup_size}" ]; then
        popup_size="medium (default)"
    fi
    print_status "Popup Size" "${popup_size}"
    
    # Read popup position
    local popup_position
    popup_position=$(grep -E "^[[:space:]]*POPUP_POSITION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${popup_position}" ]; then
        popup_position="center (default)"
    fi
    print_status "Popup Position" "${popup_position}"
    
    # Read minimum display time
    local min_display_time
    min_display_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${min_display_time}" ]; then
        min_display_time="30 seconds (default)"
    elif [ "${min_display_time}" -eq 0 ]; then
        min_display_time="Disabled"
    else
        min_display_time="${min_display_time} seconds"
    fi
    print_status "Min Display Time" "${min_display_time}"
    
    # Read popup immovable setting
    local popup_immovable
    popup_immovable=$(grep -E "^[[:space:]]*POPUP_IMMOVABLE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -z "${popup_immovable}" ]; then
        popup_immovable="true (default)"
    elif [ "${popup_immovable}" = "true" ] || [ "${popup_immovable}" = "1" ] || [ "${popup_immovable}" = "yes" ]; then
        popup_immovable="Enabled"
    else
        popup_immovable="Disabled"
    fi
    print_status "Prevent Window Movement" "${popup_immovable}"
    
    # Read restricted hours
    print_header "RESTRICTED HOURS"
    
    local has_restrictions=false
    declare -a day_names=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
    declare -a day_vars=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")
    
    for i in {0..6}; do
        local day_name="${day_names[${i}]}"
        local day_var="${day_vars[${i}]}"
        local ranges
        ranges=$(grep -E "^[[:space:]]*${day_var}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        
        if [ -n "${ranges}" ]; then
            has_restrictions=true
            local formatted
            formatted=$(format_ranges_human "${ranges}" "${day_name}")
            printf "  ${COLOR_BOLD}%-12s${COLOR_RESET} %s\n" "${day_name}:" "${formatted}"
        fi
    done
    
    if [ "${has_restrictions}" = "false" ]; then
        echo -e "  ${COLOR_YELLOW}No restricted hours configured${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run 'sleep-warning-configure' or './configure.sh' to set up restricted hours${COLOR_RESET}"
    fi
}

# Display usage tips
show_tips() {
    print_header "QUICK COMMANDS"
    
    echo -e "  ${COLOR_BOLD}Configuration:${COLOR_RESET}"
    echo "    sleep-warning-configure  - Configure restricted hours (installed)"
    echo "    ./configure.sh          - Configure restricted hours (local)"
    echo ""
    echo -e "  ${COLOR_BOLD}Status:${COLOR_RESET}"
    echo "    sleep-warning-status    - View system status (this command)"
    echo ""
    echo -e "  ${COLOR_BOLD}Management:${COLOR_RESET}"
    echo "    sleep-warning-manage    - Interactive management menu (installed)"
    echo "    ./manage.sh             - Interactive management menu (local)"
    echo "    Note: Interactive menu - no command-line flags needed"
    echo ""
    echo -e "  ${COLOR_BOLD}Logs:${COLOR_RESET}"
    echo "    sleep-warning-manage    - View logs via interactive menu"
    echo "    ./manage.sh             - View logs via interactive menu"
    echo ""
    echo -e "  ${COLOR_BOLD}Disable/Uninstall:${COLOR_RESET}"
    echo "    sleep-warning-manage    - Disable via interactive menu (keeps installed)"
    echo "    sleep-warning-uninstall - Remove the system completely (installed)"
    echo "    sleep-warning-uninstall --remove-config  - Uninstall including config"
    echo "    ./uninstall.sh          - Remove the system completely (local)"
    echo "    ./uninstall.sh --remove-config  - Uninstall including config"
}

# Main function
main() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}               SLEEP WARNING SYSTEM - STATUS CHECK${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"
    
    # Check installation
    if ! check_installation; then
        echo ""
        return 1
    fi
    
    # Check service status
    check_service_status
    
    # Show configuration
    show_configuration
    
    # Show tips
    show_tips
    
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
}

# Run main function
main "$@"
