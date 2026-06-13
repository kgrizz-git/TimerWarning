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
# Enhancement #18: Config file is now in subdirectory
# Use new location, but check old location as fallback for backward compatibility
CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
CONFIG_FILE_OLD="${CONFIG_DIR}/sleep-warning.conf"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
TIMER_FILE="${SYSTEMD_USER_DIR}/sleep-warning.timer"
SERVICE_FILE="${SYSTEMD_USER_DIR}/sleep-warning.service"
SERVICE_NAME="sleep-warning"

# Get script directory for sourcing libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"
INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning"

for _bootstrap_lib in \
    "${INSTALLED_LIB_DIR}/_bootstrap-bash4.sh" \
    "${SCRIPT_LIB_DIR}/_bootstrap-bash4.sh"; do
    if [ -f "${_bootstrap_lib}" ]; then
        # shellcheck disable=SC1090
        source "${_bootstrap_lib}"
        _bootstrap_bash4 "${BASH_SOURCE[0]}" "$@"
        break
    fi
done
unset _bootstrap_lib

# Load shared library loader helper
LIB_HELPER_PATH=""
for candidate in \
    "${INSTALLED_LIB_DIR}/library-loader.sh" \
    "${SCRIPT_LIB_DIR}/library-loader.sh"; do
    if [ -z "${LIB_HELPER_PATH}" ] && [ -f "${candidate}" ]; then
        LIB_HELPER_PATH="${candidate}"
    fi
done

if [ -z "${LIB_HELPER_PATH}" ]; then
    echo "Error: library loader helper not found. Please reinstall the Sleep Warning System." >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${LIB_HELPER_PATH}"
init_library_paths "${INSTALLED_LIB_DIR}" "${SCRIPT_LIB_DIR}"

# Source configuration library if available (for get_popup_dimensions function)
if source_optional_lib "config.sh"; then
    # Source resolution detection for Enhancement #3 (needed by get_popup_dimensions)
    source_optional_lib "resolution-detection.sh" || true
    # Override CONFIG_FILE with fallback logic if lib/config.sh was sourced
    # (lib/config.sh defines CONFIG_FILE, but we want fallback support)
    if [ ! -f "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE_OLD}" ]; then
        CONFIG_FILE="${CONFIG_FILE_OLD}"
    fi
else
    # If lib/config.sh not available, use fallback logic
    if [ ! -f "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE_OLD}" ]; then
        CONFIG_FILE="${CONFIG_FILE_OLD}"
    fi
fi

# Source desktop environment library if available (for dialog tool detection)
source_optional_lib "desktop-environment.sh" || true

# Source pause state library if available (for pause status display - Enhancement #21)
source_optional_lib "pause-state.sh" || true
source_optional_lib "scheduler-platform.sh" || true

if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
    TIMER_FILE="${HOME}/Library/LaunchAgents/com.sleep-warning.plist"
    SERVICE_FILE="${TIMER_FILE}"
fi

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


# Configuration display (restricted hours, lock hours, pause, etc.)
if [ -f "${INSTALLED_LIB_DIR}/status-config-display.sh" ]; then
    # shellcheck disable=SC1090
    source "${INSTALLED_LIB_DIR}/status-config-display.sh"
elif [ -f "${SCRIPT_LIB_DIR}/status-config-display.sh" ]; then
    # shellcheck disable=SC1090
    source "${SCRIPT_LIB_DIR}/status-config-display.sh"
else
    echo "Error: status-config-display.sh not found. Please reinstall the Sleep Warning System." >&2
    exit 1
fi

# Check installation status
check_installation() {
    print_header "INSTALLATION STATUS"

    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        if [ -f "${TIMER_FILE}" ]; then
            print_status "LaunchAgent" "Installed" "good"
        else
            print_status "LaunchAgent" "Not Installed" "error"
            echo ""
            echo -e "${COLOR_YELLOW}  → Run './install.sh' to install${COLOR_RESET}"
            return 1
        fi
    else
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

    if [ "$(uname -s 2>/dev/null)" = "Darwin" ] && type scheduler_status_lines >/dev/null 2>&1; then
        while IFS= read -r line; do
            print_status "Scheduler" "${line}" ""
        done < <(scheduler_status_lines)

        # Derive last run time from warnings.log (macOS has no systemd timers).
        local warnings_log="${CONFIG_DIR}/warnings.log"
        if [ -f "${warnings_log}" ]; then
            # Prefer the most recent restricted-time entry; fall back to any log line.
            local last_line=""
            last_line=$(grep -E "\\[WARNING\\] Restricted time detected" "${warnings_log}" 2>/dev/null | tail -n1)
            if [ -z "${last_line}" ]; then
                last_line=$(tail -n1 "${warnings_log}" 2>/dev/null)
            fi
            if [ -n "${last_line}" ]; then
                # Extract leading timestamp: [YYYY-MM-DD HH:MM:SS]
                local last_ts
                last_ts=$(echo "${last_line}" | sed -n 's/^\[\([0-9-]\+ [0-9:]\+\)\].*/\1/p')
                if [ -n "${last_ts}" ]; then
                    print_status "Last Run" "${last_ts}"
                fi
            fi
        fi
        return 0
    fi
    
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
# Display usage tips
show_tips() {
    print_header "QUICK COMMANDS"
    
    echo -e "  ${COLOR_BOLD}Configuration:${COLOR_RESET}"
    echo "    sleep-warning-configure  - Configure restricted hours (run from ~/.local/bin)"
    echo "    sleep-warning-configure --text  - Force text mode (useful for SSH)"
    echo "    ./configure.sh          - Configure restricted hours (run from project folder)"
    echo "    ./configure.sh --text    - Force text mode"
    echo ""
    echo -e "  ${COLOR_BOLD}Status:${COLOR_RESET}"
    echo "    sleep-warning-status    - View system status (this command)"
    echo "    systemctl --user list-timers              - List all user timers"
    echo "    systemctl --user list-timers sleep-warning.timer  - List timer details"
    echo "    systemctl --user status sleep-warning.timer  - Detailed timer status"
    echo "    systemctl --user status sleep-warning.service  - Service status"
    echo ""
    echo -e "  ${COLOR_BOLD}Management:${COLOR_RESET}"
    echo "    sleep-warning-manage    - Interactive management menu (run from ~/.local/bin)"
    echo "    ./manage.sh             - Interactive management menu (run from project folder)"
    echo "    Note: Interactive menu - no command-line flags needed"
    echo ""
    echo -e "  ${COLOR_BOLD}Logs:${COLOR_RESET}"
    echo "    sleep-warning-manage    - View logs via interactive menu"
    echo "    ./manage.sh             - View logs via interactive menu"
    echo ""
    echo -e "  ${COLOR_BOLD}Disable/Uninstall:${COLOR_RESET}"
    echo "    sleep-warning-manage    - Disable via interactive menu (keeps installed)"
    echo "    sleep-warning-uninstall - Remove installed system files (run from ~/.local/bin)"
    echo "    sleep-warning-uninstall --remove-config  - Uninstall including config"
    echo "    ./uninstall.sh          - Remove installed system files (run from project folder)"
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
