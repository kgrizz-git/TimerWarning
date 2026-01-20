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
#
# Dependencies:
#   - desktop-environment.sh (for check_dialog_tool and detect_display_environment)
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
#
# Dependencies: None (base module)
###############################################################################

# Script configuration
SCRIPT_NAME="sleep-warning-configure"
CONFIG_DIR="${HOME}/.config/sleep-warning"
CONFIG_FILE="${CONFIG_DIR}/sleep-warning.conf"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
TIMER_FILE="${SYSTEMD_USER_DIR}/sleep-warning.timer"
SERVICE_NAME="sleep-warning"

# Day names array
declare -a DAY_NAMES=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
declare -a DAY_VARS=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")

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
# Requires desktop-environment.sh to be sourced
get_dialog_tool() {
    if type check_dialog_tool >/dev/null 2>&1 && type detect_display_environment >/dev/null 2>&1; then
        local env_type
        env_type=$(detect_display_environment 2>/dev/null || echo "x11")
        check_dialog_tool "${env_type}"
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
