#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration Module
#
# This module handles all configuration-related functionality including:
# - Configuration file paths and constants
# - Default values for all settings
# - Functions to read and parse configuration values
#
# Dependencies: None (base module)
#
# Usage: Source this file to access configuration functions
#   source lib/config.sh
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
    [0]="1-5"  # Sunday: 1:00 AM to 4:59 AM
    [1]="0-5"  # Monday: Midnight to 4:59 AM
    [2]="0-5"  # Tuesday: Midnight to 4:59 AM
    [3]="0-5"  # Wednesday: Midnight to 4:59 AM
    [4]="0-5"  # Thursday: Midnight to 4:59 AM
    [5]="0-5"  # Friday: Midnight to 4:59 AM
    [6]="1-5"  # Saturday: 1:00 AM to 4:59 AM
)

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
            width=400
            height=250
            ;;
        medium)
            width=800
            height=500
            ;;
        large)
            width=2000
            height=1350
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
    
    # Validate position (only center and top-left are supported)
    case "${position}" in
        center|top-left)
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
    
    # Check if day line exists in config file (even if empty)
    local day_line_exists
    day_line_exists=$(grep -E "^[[:space:]]*${day_name}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
    
    if [ -z "${day_line_exists}" ]; then
        # Day line doesn't exist in config file = not configured yet, use default
        echo "${DEFAULT_HOURS[${day_num}]}"
        return 0
    fi
    
    # Day line exists - extract value (may be empty if explicitly skipped)
    local config_line
    config_line=$(echo "${day_line_exists}" | sed 's/^[[:space:]]*//' | cut -d'=' -f2- | tr -d '[:space:]')
    
    if [ -n "${config_line}" ]; then
        # Has a value, use it
        echo "${config_line}"
        return 0
    else
        # Line exists but is empty = explicitly skipped, no restrictions
        echo ""
        return 0
    fi
}
