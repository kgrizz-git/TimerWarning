#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration Core Module
#
# This module provides core utilities, constants, and helper functions used
# throughout the configuration wizard. It has no dependencies on other modules.
#
# Functions:
# - has_zenity()             - Check if zenity is available
# - has_gui()                - Check if GUI is available
# - minutes_to_oncalendar()  - Convert minutes to systemd OnCalendar format
# - format_hour_12h()        - Format hour to 12-hour format with AM/PM
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

# Check if zenity is available
has_zenity() {
    command -v zenity >/dev/null 2>&1
}

# Check if GUI is available
has_gui() {
    [ -n "${DISPLAY}" ] || [ -S "/tmp/.X11-unix/X0" ] || command -v loginctl >/dev/null 2>&1
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
