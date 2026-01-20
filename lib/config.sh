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

# Default configure block enabled setting - used if config file missing or invalid
# This controls whether configure.sh and manage.sh are blocked during restricted hours (Enhancement #19)
DEFAULT_CONFIGURE_BLOCK_ENABLED=false

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

# Get configure block enabled setting from configuration file
# Returns "true" if configure.sh and manage.sh blocking is enabled, "false" otherwise
# This is for Enhancement #19 (Prevent configure.sh and manage.sh Execution)
get_configure_block_enabled() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_CONFIGURE_BLOCK_ENABLED}"
        return 0
    fi
    
    # Read CONFIGURE_BLOCK_ENABLED from config file
    local block_enabled
    block_enabled=$(grep -E "^[[:space:]]*CONFIGURE_BLOCK_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    if [ "${block_enabled}" = "true" ] || [ "${block_enabled}" = "1" ] || [ "${block_enabled}" = "yes" ]; then
        echo "true"
        return 0
    elif [ "${block_enabled}" = "false" ] || [ "${block_enabled}" = "0" ] || [ "${block_enabled}" = "no" ]; then
        echo "false"
        return 0
    else
        # Invalid or missing, use default
        echo "${DEFAULT_CONFIGURE_BLOCK_ENABLED}"
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

# Parse lock hours from configuration file
# This function reads CONFIG_LOCK_HOURS_DAYNAME lines (e.g., CONFIG_LOCK_HOURS_MONDAY=9-17)
# These are separate from restriction hours and used for blocking configure.sh and manage.sh
# This is for Enhancement #19 Phase 2 (Additional Configurable Lock Hours)
#
# Parameters:
#   $1 - day_num (0-6, Sunday=0, Saturday=6)
#
# Returns:
#   Time range string (e.g., "9-17" or "0-5,22-23") if configured
#   Empty string if not configured or explicitly disabled
#
# Exit Codes:
#   0 - Success (returns range or empty string)
#   1 - Invalid day number
#
# Dependencies: None (standalone function)
parse_lock_hours() {
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
        # No config file = no lock hours configured
        echo ""
        return 0
    fi
    
    # Check if lock hours line exists in config file (even if empty)
    local lock_line_exists
    lock_line_exists=$(grep -E "^[[:space:]]*CONFIG_LOCK_HOURS_${day_name}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
    
    if [ -z "${lock_line_exists}" ]; then
        # Lock hours line doesn't exist = not configured, no lock hours
        echo ""
        return 0
    fi
    
    # Lock hours line exists - extract value (may be empty if explicitly disabled)
    local lock_config
    lock_config=$(echo "${lock_line_exists}" | sed 's/^[[:space:]]*//' | cut -d'=' -f2- | tr -d '[:space:]')
    
    if [ -n "${lock_config}" ]; then
        # Has a value - validate format before returning
        # Source time-validation.sh if available for validation
        if type validate_hour_range >/dev/null 2>&1; then
            if validate_hour_range "${lock_config}"; then
                echo "${lock_config}"
                return 0
            else
                # Invalid format - log warning and return empty
                if type log_message >/dev/null 2>&1; then
                    log_message "warning" "Invalid lock hours format for ${day_name}: ${lock_config}"
                fi
                echo ""
                return 0
            fi
        else
            # Validation function not available - return as-is (will be validated later)
            echo "${lock_config}"
            return 0
        fi
    else
        # Line exists but is empty = explicitly disabled, no lock hours
        echo ""
        return 0
    fi
}
