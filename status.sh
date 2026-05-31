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

# Format a 24-hour time string "HH[:MM]" to 12-hour format with AM/PM
format_hour_12h() {
    local time_str="$1"
    local hour minute

    if [[ "${time_str}" == *:* ]]; then
        hour="${time_str%%:*}"
        minute="${time_str##*:}"
    else
        hour="${time_str}"
        minute="0"
    fi

    # Basic numeric validation
    if ! [[ "${hour}" =~ ^[0-9]+$ ]] || ! [[ "${minute}" =~ ^[0-9]+$ ]]; then
        echo "${time_str}"
        return 0
    fi

    local display_hour="${hour}"
    local ampm="AM"

    if [ "${hour}" -ge 12 ]; then
        ampm="PM"
        if [ "${hour}" -gt 12 ]; then
            display_hour=$((hour - 12))
        fi
    fi

    if [ "${display_hour}" -eq 0 ]; then
        display_hour=12
    fi

    printf "%d:%02d %s" "${display_hour}" "${minute}" "${ampm}"
}

# Format a single range to human-readable format
format_range_human() {
    local range="$1"
    local day_name="$2"
    
    local start_raw end_raw
    start_raw=$(echo "${range}" | cut -d'-' -f1)
    end_raw=$(echo "${range}" | cut -d'-' -f2)
    
    local start_12h end_12h
    start_12h=$(format_hour_12h "${start_raw}")
    end_12h=$(format_hour_12h "${end_raw}")

    # Determine if this is an overnight range using HHMM-style comparison
    local overnight="false"

    # Parse start time
    local shour smin
    if [[ "${start_raw}" == *:* ]]; then
        shour="${start_raw%%:*}"
        smin="${start_raw##*:}"
    else
        shour="${start_raw}"
        smin="0"
    fi

    # Parse end time
    local ehour emin
    if [[ "${end_raw}" == *:* ]]; then
        ehour="${end_raw%%:*}"
        emin="${end_raw##*:}"
    else
        ehour="${end_raw}"
        emin="0"
    fi

    if [[ "${shour}" =~ ^[0-9]+$ ]] && [[ "${smin}" =~ ^[0-9]+$ ]] && \
       [[ "${ehour}" =~ ^[0-9]+$ ]] && [[ "${emin}" =~ ^[0-9]+$ ]]; then
        local shour_p ehour_p smin_p emin_p
        printf -v shour_p "%02d" "${shour}"
        printf -v ehour_p "%02d" "${ehour}"
        printf -v smin_p  "%02d" "${smin}"
        printf -v emin_p  "%02d" "${emin}"

        local start_total end_total
        start_total=$((10#${shour_p}${smin_p}))
        end_total=$((10#${ehour_p}${emin_p}))

        if [ "${start_total}" -gt "${end_total}" ]; then
            overnight="true"
        fi
    fi
    
    # Handle overnight ranges
    if [ "${overnight}" = "true" ]; then
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
show_configuration() {
    print_header "CONFIGURATION"
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "  ${COLOR_YELLOW}No configuration file found${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run 'sleep-warning-configure' or './configure.sh' to create configuration${COLOR_RESET}"
        return 1
    fi
    
    # Read popup display frequency (Enhancement #30); fallback CHECK_INTERVAL for migration
    local popup_freq
    popup_freq=$(grep -E "^[[:space:]]*POPUP_DISPLAY_FREQUENCY=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${popup_freq}" ]; then
        popup_freq=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    fi
    if [ -z "${popup_freq}" ]; then
        popup_freq="10 (default)"
    else
        popup_freq="${popup_freq} minute(s)"
    fi
    print_status "Popup display frequency" "${popup_freq}"
    
    # Read popup size
    local popup_size
    popup_size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    # Format with dimensions if get_popup_dimensions function is available
    local display_size
    if [ -z "${popup_size}" ]; then
        popup_size="medium"
        if type get_popup_dimensions >/dev/null 2>&1; then
            local dimensions
            dimensions=$(get_popup_dimensions "${popup_size}")
            local width height
            width=$(echo "${dimensions}" | cut -d' ' -f1)
            height=$(echo "${dimensions}" | cut -d' ' -f2)
            display_size="medium (default) - ${width}x${height}"
        else
            display_size="medium (default)"
        fi
    else
        # Check if it's a custom size - if so, read the custom size value
        if [ "${popup_size}" = "custom" ]; then
            local custom_size
            custom_size=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
            if [ -n "${custom_size}" ]; then
                # Show custom size value (e.g., "95%x95%")
                if type get_popup_dimensions >/dev/null 2>&1; then
                    local dimensions
                    dimensions=$(get_popup_dimensions "${popup_size}")
                    local width height
                    width=$(echo "${dimensions}" | cut -d' ' -f1)
                    height=$(echo "${dimensions}" | cut -d' ' -f2)
                    display_size="custom ${custom_size} (${width}x${height})"
                else
                    display_size="custom ${custom_size}"
                fi
            else
                # Fallback if custom size not found
                if type get_popup_dimensions >/dev/null 2>&1; then
                    local dimensions
                    dimensions=$(get_popup_dimensions "${popup_size}")
                    local width height
                    width=$(echo "${dimensions}" | cut -d' ' -f1)
                    height=$(echo "${dimensions}" | cut -d' ' -f2)
                    display_size="custom (${width}x${height})"
                else
                    display_size="custom"
                fi
            fi
        elif type get_popup_dimensions >/dev/null 2>&1; then
            local dimensions
            dimensions=$(get_popup_dimensions "${popup_size}")
            local width height
            width=$(echo "${dimensions}" | cut -d' ' -f1)
            height=$(echo "${dimensions}" | cut -d' ' -f2)
            
            # Check if it's a custom size (already contains 'x')
            if echo "${popup_size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                display_size="${popup_size}"
            else
                display_size="${popup_size} (${width}x${height})"
            fi
        else
            display_size="${popup_size}"
        fi
    fi
    print_status "Popup Size" "${display_size}"
    
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
    
    # Read configure block enabled setting (Enhancement #19)
    local configure_block_enabled
    configure_block_enabled=$(grep -E "^[[:space:]]*CONFIGURE_BLOCK_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -z "${configure_block_enabled}" ]; then
        configure_block_enabled="Disabled (default)"
    elif [ "${configure_block_enabled}" = "true" ] || [ "${configure_block_enabled}" = "1" ] || [ "${configure_block_enabled}" = "yes" ]; then
        configure_block_enabled="Enabled"
    else
        configure_block_enabled="Disabled"
    fi
    print_status "Block Scripts During Restricted Hours" "${configure_block_enabled}"
    
    # Read uninstall protection mode setting (Enhancement #26)
    local uninstall_protection_mode
    uninstall_protection_mode=$(grep -E "^[[:space:]]*UNINSTALL_PROTECTION_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -z "${uninstall_protection_mode}" ]; then
        uninstall_protection_mode="Difficult Uninstall (default)"
    elif [ "${uninstall_protection_mode}" = "difficult" ]; then
        uninstall_protection_mode="Difficult Uninstall (Enabled)"
    else
        uninstall_protection_mode="None"
    fi
    print_status "Uninstall Protection" "${uninstall_protection_mode}"
    
    # Read pause settings (Enhancement #21)
    local pause_enabled pause_duration pause_cooldown_hours
    if type get_pause_enabled >/dev/null 2>&1; then
        pause_enabled=$(get_pause_enabled)
        pause_duration=$(get_pause_duration)
        pause_cooldown_hours=$(get_pause_cooldown_hours)
    else
        pause_enabled=$(grep -E "^[[:space:]]*PAUSE_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        pause_duration=$(grep -E "^[[:space:]]*PAUSE_DURATION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        pause_cooldown_hours=$(grep -E "^[[:space:]]*PAUSE_COOLDOWN_HOURS=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    fi
    if [ -z "${pause_enabled}" ] || [ "${pause_enabled}" = "true" ] || [ "${pause_enabled}" = "1" ] || [ "${pause_enabled}" = "yes" ]; then
        print_status "Pause Feature" "Enabled"
    else
        print_status "Pause Feature" "Disabled"
    fi
    if [ -z "${pause_duration}" ]; then
        pause_duration="5"
    fi
    print_status "Pause Duration" "${pause_duration} minutes"
    if [ -z "${pause_cooldown_hours}" ]; then
        pause_cooldown_hours="24"
    fi
    print_status "Pause Cooldown" "${pause_cooldown_hours} hours"
    
    print_header "PAUSE STATUS"
    
    if type is_pause_active >/dev/null 2>&1 && type can_pause_now >/dev/null 2>&1; then
        if is_pause_active; then
            local pause_end_timestamp
            pause_end_timestamp=$(get_pause_end_timestamp)
            if [ -n "${pause_end_timestamp}" ]; then
                local pause_end_time
                pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                print_status "Pause Status" "Active until ${pause_end_time}" "good"
            else
                print_status "Pause Status" "Active (end time unknown)" "warning"
            fi
        elif can_pause_now; then
            print_status "Pause Status" "Available" "good"
        elif [ "${pause_enabled}" = "true" ] || [ "${pause_enabled}" = "1" ] || [ "${pause_enabled}" = "yes" ] || [ -z "${pause_enabled}" ]; then
            local next_available_ts next_available_label
            next_available_ts=""
            if type get_next_pause_available_timestamp >/dev/null 2>&1; then
                next_available_ts=$(get_next_pause_available_timestamp)
            fi
            if [ -n "${next_available_ts}" ]; then
                next_available_label=$(date -d "@${next_available_ts}" +"%Y-%m-%d %H:%M" 2>/dev/null || date -r "${next_available_ts}" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
                print_status "Pause Status" "Cooldown until ${next_available_label}" "warning"
            else
                print_status "Pause Status" "Cooldown (not available yet)" "warning"
            fi
        else
            print_status "Pause Status" "Disabled" "warning"
        fi
        
        local last_pause_date last_pause_timestamp
        last_pause_date=$(get_last_pause_date)
        last_pause_timestamp=$(get_last_pause_timestamp)
        if [ -n "${last_pause_date}" ]; then
            print_status "Last Pause Date" "${last_pause_date}"
        else
            print_status "Last Pause Date" "Never used"
        fi
        if [ -n "${last_pause_timestamp}" ]; then
            local last_pause_time
            last_pause_time=$(date -d "@${last_pause_timestamp}" +"%Y-%m-%d %H:%M" 2>/dev/null || date -r "${last_pause_timestamp}" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
            print_status "Last Pause Started" "${last_pause_time}"
        fi
    else
        print_status "Pause Status" "Unable to check (pause-state.sh not available)" "warning"
    fi
    
    # Get dialog tool configuration (Enhancement #25)
    local configured_dialog_tool
    if type get_dialog_tool_config >/dev/null 2>&1; then
        configured_dialog_tool=$(get_dialog_tool_config)
    else
        # Fallback to manual parsing if function not available
        configured_dialog_tool=$(grep -E "^[[:space:]]*DIALOG_TOOL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -z "${configured_dialog_tool}" ]; then
            configured_dialog_tool="auto"
        fi
    fi
    
    # Detect and display dialog tool
    local dialog_tool
    local dialog_tool_status=""
    local dialog_tool_display=""
    
    if [ -n "${configured_dialog_tool}" ] && [ "${configured_dialog_tool}" != "auto" ]; then
        # User has manually selected a dialog tool
        if command -v "${configured_dialog_tool}" >/dev/null 2>&1; then
            dialog_tool="${configured_dialog_tool}"
            dialog_tool_display="${configured_dialog_tool} (user-selected)"
            dialog_tool_status="good"
        else
            # Selected tool not installed, will fall back to automatic
            dialog_tool_display="${configured_dialog_tool} (not installed, will use automatic)"
            dialog_tool_status="warning"
        fi
    else
        # Use automatic priority system (YAD → Zenity → KDialog)
        if type check_dialog_tool >/dev/null 2>&1; then
            # Use the function from desktop-environment.sh if available
            local env_type
            env_type=$(echo "${XDG_SESSION_TYPE:-x11}" | tr '[:upper:]' '[:lower:]')
            dialog_tool=$(check_dialog_tool "${env_type}")
        else
            # Fallback: check tools manually in priority order
            if command -v yad >/dev/null 2>&1; then
                dialog_tool="yad"
            elif command -v zenity >/dev/null 2>&1; then
                dialog_tool="zenity"
            elif command -v kdialog >/dev/null 2>&1; then
                dialog_tool="kdialog"
            fi
        fi
        
        if [ -n "${dialog_tool}" ]; then
            dialog_tool_display="${dialog_tool} (automatic selection)"
            dialog_tool_status="good"
        else
            dialog_tool_display="None available"
            dialog_tool_status="error"
        fi
    fi
    
    # Show installed tools for reference
    local installed_tools=()
    if command -v yad >/dev/null 2>&1; then
        installed_tools+=("yad")
    fi
    if command -v zenity >/dev/null 2>&1; then
        installed_tools+=("zenity")
    fi
    if command -v kdialog >/dev/null 2>&1; then
        installed_tools+=("kdialog")
    fi
    
    if [ ${#installed_tools[@]} -gt 0 ]; then
        local tools_list
        tools_list=$(IFS=', '; echo "${installed_tools[*]}")
        dialog_tool_display="${dialog_tool_display} [Installed: ${tools_list}]"
    fi
    
    print_status "Dialog Tool" "${dialog_tool_display}" "${dialog_tool_status}"
    
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
    
    # Read lock hours (Enhancement #19 Phase 2)
    print_header "LOCK HOURS (CONFIGURE/MANAGE SCRIPTS)"
    
    local has_lock_hours=false
    
    for i in {0..6}; do
        local day_name="${day_names[${i}]}"
        local day_var="${day_vars[${i}]}"
        local ranges
        ranges=$(grep -E "^[[:space:]]*CONFIG_LOCK_HOURS_${day_var}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        
        if [ -n "${ranges}" ]; then
            has_lock_hours=true
            local formatted
            formatted=$(format_ranges_human "${ranges}" "${day_name}")
            printf "  ${COLOR_BOLD}%-12s${COLOR_RESET} %s\n" "${day_name}:" "${formatted}"
        fi
    done
    
    if [ "${has_lock_hours}" = "false" ]; then
        echo -e "  ${COLOR_YELLOW}No lock hours configured${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Use 'sleep-warning-configure' Security/Lock Hours menus to set optional lock hours${COLOR_RESET}"
    fi
    
    echo ""
    
    # Read uninstall lock hours (Enhancement #26 Phase 2)
    print_header "UNINSTALL LOCK HOURS"
    
    local has_uninstall_lock_hours=false
    
    for i in {0..6}; do
        local day_name="${day_names[${i}]}"
        local day_var="${day_vars[${i}]}"
        local ranges
        ranges=$(grep -E "^[[:space:]]*UNINSTALL_LOCK_HOURS_${day_var}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        
        if [ -n "${ranges}" ]; then
            has_uninstall_lock_hours=true
            local formatted
            formatted=$(format_ranges_human "${ranges}" "${day_name}")
            printf "  ${COLOR_BOLD}%-12s${COLOR_RESET} %s\n" "${day_name}:" "${formatted}"
        fi
    done
    
    if [ "${has_uninstall_lock_hours}" = "false" ]; then
        echo -e "  ${COLOR_YELLOW}No uninstall lock hours configured${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Use 'sleep-warning-configure' Uninstall Lock Hours menu to set optional uninstall lock hours${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}  → Note: Uninstall lock hours only take effect when Uninstall Protection is set to 'difficult'${COLOR_RESET}"
    fi
    
    # Check minute precision compatibility (Enhancement 16b); use run interval (Enhancement #30)
    if type check_minute_precision_compatibility >/dev/null 2>&1 && type get_timer_run_interval >/dev/null 2>&1; then
        local popup_freq_val run_interval
        popup_freq_val=$(grep -E "^[[:space:]]*POPUP_DISPLAY_FREQUENCY=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ -z "${popup_freq_val}" ] && popup_freq_val=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${popup_freq_val}" ]; then
            run_interval=$(get_timer_run_interval "${popup_freq_val}")
            local config_lines=()
            for day_var in SUNDAY MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY SATURDAY; do
                local line
                line=$(grep -E "^[[:space:]]*${day_var}=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
                [ -n "${line}" ] && config_lines+=("${line}")
            done
            
            local compatibility_warning
            compatibility_warning=$(check_minute_precision_compatibility "${run_interval}" "${config_lines[@]}")
            if [ $? -ne 0 ]; then
                echo ""
                echo -e "  ${COLOR_YELLOW}⚠️  TIMER INTERVAL WARNING:${COLOR_RESET}"
                echo -e "  ${COLOR_YELLOW}${compatibility_warning}${COLOR_RESET}"
            fi
        fi
    fi
}

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
