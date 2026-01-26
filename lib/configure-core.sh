#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration Core Module
#
# This module provides core utilities, constants, and helper functions used
# throughout the configuration wizard.
#
# Functions:
# - has_zenity()             - Check if zenity is available (legacy, uses get_dialog_tool)
# - has_dialog_tool()        - Check if any dialog tool is available
# - get_dialog_tool()        - Get the currently selected dialog tool
# - has_gui()                - Check if GUI is available
# - minutes_to_oncalendar()  - Convert minutes to systemd OnCalendar format
# - format_hour_12h()        - Format hour to 12-hour format with AM/PM
# - get_threshold_warn_description()  - Get human-readable warning threshold description
# - get_threshold_block_description() - Get human-readable block threshold description
# - day_num_to_name_upper()  - Convert day number to uppercase day name (for config file)
# - day_num_to_name_title()  - Convert day number to titlecase day name (for display)
#
# Dependencies:
#   - desktop-environment.sh (for check_dialog_tool and detect_display_environment)
#   - config.sh (for get_dialog_tool_config, Enhancement #25)
#     Note: Functions handle case where dependencies are not yet loaded
#
# Global Variables/Constants:
# - SCRIPT_NAME              - Script identifier for configuration
# - CONFIG_DIR               - Configuration directory path
# - CONFIG_FILE              - Configuration file path
# - SYSTEMD_USER_DIR         - Systemd user directory path
# - TIMER_FILE               - Timer file path
# - SERVICE_NAME             - Service name for systemd
# - DAY_NAMES                - Array of day names (Sunday-Saturday)
# - DAY_VARS                 - Array of day variable names for config file
# - HOURS_PER_DAY_WARN       - Warning threshold in hours/day (default: 23)
# - HOURS_PER_DAY_BLOCK      - Block threshold in hours/day (default: 24)
# - THRESHOLD_WARN           - Warning threshold in minutes/week (calculated)
# - THRESHOLD_BLOCK          - Block threshold in minutes/week (calculated)
#
# Dependencies: None (base module)
###############################################################################

# Script configuration
SCRIPT_NAME="sleep-warning-configure"
CONFIG_DIR="${HOME}/.config/sleep-warning"
# Enhancement #18: Config file is now in subdirectory
CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
TIMER_FILE="${SYSTEMD_USER_DIR}/sleep-warning.timer"
SERVICE_NAME="sleep-warning"

# Day names array
declare -a DAY_NAMES=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
declare -a DAY_VARS=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")

# Restriction validation thresholds (Enhancement #22)
# These define when to warn or block configuration based on total restricted minutes per week
# Calculated as: hours_per_day × 60 minutes × 7 days
# To change thresholds, modify HOURS_PER_DAY_WARN or HOURS_PER_DAY_BLOCK
HOURS_PER_DAY_WARN=16      # Warning threshold: > 16 hours/day
HOURS_PER_DAY_BLOCK=24     # Block threshold: >= 24 hours/day (24/7 restrictions)
readonly MINUTES_PER_HOUR=60
readonly DAYS_PER_WEEK=7
readonly MINUTES_PER_DAY=$((MINUTES_PER_HOUR * 24))      # 1440 minutes per day
readonly MINUTES_PER_WEEK=$((MINUTES_PER_DAY * DAYS_PER_WEEK))  # 10080 minutes per week
THRESHOLD_WARN=$((HOURS_PER_DAY_WARN * MINUTES_PER_HOUR * DAYS_PER_WEEK))      # Currently 6720
THRESHOLD_BLOCK=$((HOURS_PER_DAY_BLOCK * MINUTES_PER_HOUR * DAYS_PER_WEEK))     # 10080

# Hour range constants (for validation)
readonly MIN_HOUR=0
readonly MAX_HOUR=23

# Time range constants (for minimum display time validation)
readonly MIN_DISPLAY_TIME=0
readonly MAX_DISPLAY_TIME=300

# Check interval constants (for validation)
readonly MIN_CHECK_INTERVAL=1
readonly MAX_CHECK_INTERVAL=60

# Check if any dialog tool is available
# Requires desktop-environment.sh to be sourced
has_dialog_tool() {
    if type check_dialog_tool >/dev/null 2>&1 && type detect_display_environment >/dev/null 2>&1; then
        local env_type
        env_type=$(detect_display_environment 2>/dev/null || echo "x11")
        local tool
        tool=$(check_dialog_tool "${env_type}" 2>/dev/null)
        [ -n "${tool}" ]
    else
        # Fallback: check for any tool directly
        command -v yad >/dev/null 2>&1 || \
        command -v zenity >/dev/null 2>&1 || \
        command -v kdialog >/dev/null 2>&1
    fi
}

# Get the currently selected dialog tool
# Respects user preference from DIALOG_TOOL config (Enhancement #25)
# Requires desktop-environment.sh and config.sh to be sourced
get_dialog_tool() {
    if type check_dialog_tool >/dev/null 2>&1 && type detect_display_environment >/dev/null 2>&1; then
        local env_type
        env_type=$(detect_display_environment 2>/dev/null || echo "x11")
        
        # Get user preference for dialog tool (Enhancement #25)
        local user_preference=""
        if type get_dialog_tool_config >/dev/null 2>&1; then
            user_preference=$(get_dialog_tool_config 2>/dev/null || echo "auto")
        else
            # Fallback if config.sh not sourced
            user_preference="auto"
        fi
        
        check_dialog_tool "${env_type}" "${user_preference}"
    else
        # Fallback: return first available tool
        if command -v yad >/dev/null 2>&1; then
            echo "yad"
        elif command -v zenity >/dev/null 2>&1; then
            echo "zenity"
        elif command -v kdialog >/dev/null 2>&1; then
            echo "kdialog"
        fi
    fi
}

# Check if zenity is available (legacy function for backward compatibility)
# Now uses get_dialog_tool() to check for any dialog tool
has_zenity() {
    local tool
    tool=$(get_dialog_tool)
    [ -n "${tool}" ]
}

# Check if GUI is available
# Now checks both DISPLAY and dialog tool availability
has_gui() {
    # Check for display
    if [ -z "${DISPLAY}" ] && [ ! -S "/tmp/.X11-unix/X0" ] && ! command -v loginctl >/dev/null 2>&1; then
        return 1
    fi
    # Check for dialog tool
    has_dialog_tool
}

# Convert minutes to systemd OnCalendar format
minutes_to_oncalendar() {
    local minutes="$1"
    
    # Systemd timer format: *:0/N means every N minutes starting from minute 0
    # This works for any N from 1 to 60
    # Examples:
    #   *:0/1  = every minute
    #   *:0/5  = every 5 minutes (at :00, :05, :10, etc.)
    #   *:0/10 = every 10 minutes (at :00, :10, :20, etc.)
    #   *:0/15 = every 15 minutes (at :00, :15, :30, :45)
    echo "*:0/${minutes}"
}

# Format hour to 12-hour format with AM/PM
format_hour_12h() {
    local hour="$1"
    if [ "${hour}" -eq 0 ]; then
        echo "12:00 AM"
    elif [ "${hour}" -eq 12 ]; then
        echo "12:00 PM"
    elif [ "${hour}" -lt 12 ]; then
        echo "${hour}:00 AM"
    else
        echo "$((hour - 12)):00 PM"
    fi
}

# Get human-readable description of warning threshold
# Returns: "X hours/day" format
get_threshold_warn_description() {
    echo "${HOURS_PER_DAY_WARN} hours/day"
}

# Get human-readable description of block threshold
# Returns: "24/7" or "X hours/day" format
get_threshold_block_description() {
    if [ "${HOURS_PER_DAY_BLOCK}" -eq 24 ]; then
        echo "24/7"
    else
        echo "${HOURS_PER_DAY_BLOCK} hours/day"
    fi
}

# Convert day number to uppercase day name (for config file)
# Parameters:
#   $1 - day_num (0-6, Sunday=0, Saturday=6)
# Returns: Uppercase day name (e.g., "SUNDAY", "MONDAY")
# Exit codes: 0 on success, 1 on invalid day number
# This function uses the DAY_VARS array for consistency
day_num_to_name_upper() {
    local day_num="$1"
    if [ "${day_num}" -ge 0 ] && [ "${day_num}" -le 6 ]; then
        echo "${DAY_VARS[${day_num}]}"
    else
        return 1
    fi
}

# Convert day number to titlecase day name (for display)
# Parameters:
#   $1 - day_num (0-6, Sunday=0, Saturday=6)
# Returns: Titlecase day name (e.g., "Sunday", "Monday")
# Exit codes: 0 on success, 1 on invalid day number
# This function uses the DAY_NAMES array for consistency
day_num_to_name_title() {
    local day_num="$1"
    if [ "${day_num}" -ge 0 ] && [ "${day_num}" -le 6 ]; then
        echo "${DAY_NAMES[${day_num}]}"
    else
        return 1
    fi
}
