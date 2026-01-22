#!/bin/bash

###############################################################################
# Sleep Warning System - Pause State Management Module
#
# This module handles pause state file management including:
# - Checking if pause is currently active
# - Activating pause for specified duration
# - Checking if user can pause today (once-per-day limit)
# - Clearing expired pause state
# - Reading pause state file values
#
# Dependencies:
#   - config.sh (for PAUSE_STATE_FILE, get_pause_enabled, get_pause_once_per_day)
#   - logging.sh (for logging functions)
#
# Usage: Source this file after config.sh and logging.sh
#   source lib/config.sh
#   source lib/logging.sh
#   source lib/pause-state.sh
###############################################################################

# Check if pause is currently active
# Returns 0 if pause is active, 1 if not
is_pause_active() {
    # Check if pause state file exists
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        return 1  # No pause state file, pause not active
    fi
    
    # Read pause end timestamp from state file
    local pause_end_timestamp
    pause_end_timestamp=$(get_pause_end_timestamp)
    
    if [ -z "${pause_end_timestamp}" ]; then
        # Invalid or missing timestamp, pause not active
        return 1
    fi
    
    # Get current time
    local current_time
    current_time=$(date +%s)
    
    # Check if current time is before pause end time
    if [ "${current_time}" -lt "${pause_end_timestamp}" ]; then
        return 0  # Pause is active
    else
        return 1  # Pause has expired
    fi
}

# Get pause end timestamp from state file
# Returns Unix timestamp or empty string if not found/invalid
get_pause_end_timestamp() {
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        echo ""
        return 0
    fi
    
    # Read PAUSE_END_TIMESTAMP from state file
    local timestamp
    timestamp=$(grep -E "^[[:space:]]*PAUSE_END_TIMESTAMP=" "${PAUSE_STATE_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    # Validate timestamp (must be numeric)
    if [ -n "${timestamp}" ] && [[ "${timestamp}" =~ ^[0-9]+$ ]]; then
        echo "${timestamp}"
        return 0
    else
        echo ""
        return 0
    fi
}

# Get last pause date from state file
# Returns YYYY-MM-DD format date or empty string if not found/invalid
get_last_pause_date() {
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        echo ""
        return 0
    fi
    
    # Read LAST_PAUSE_DATE from state file
    local last_date
    last_date=$(grep -E "^[[:space:]]*LAST_PAUSE_DATE=" "${PAUSE_STATE_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    # Validate date format (must be YYYY-MM-DD)
    if [ -n "${last_date}" ] && echo "${last_date}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        echo "${last_date}"
        return 0
    else
        echo ""
        return 0
    fi
}

# Check if user can pause today
# Returns 0 if user can pause, 1 if not
# Note: Once-per-day limit is ALWAYS enforced (not configurable)
can_pause_today() {
    # Check if pause is enabled
    local pause_enabled
    pause_enabled=$(get_pause_enabled)
    
    if [ "${pause_enabled}" != "true" ]; then
        # Pause feature is disabled
        return 1
    fi
    
    # Once-per-day limit is ALWAYS enforced - check last pause date
    local last_pause_date
    last_pause_date=$(get_last_pause_date)
    
    # Get today's date
    local today
    today=$(date +%Y-%m-%d)
    
    # If last pause date is empty or different from today, user can pause
    if [ -z "${last_pause_date}" ] || [ "${last_pause_date}" != "${today}" ]; then
        return 0  # Can pause
    else
        return 1  # Already used pause today
    fi
}

# Activate pause for specified duration
# Parameters:
#   $1 - duration_minutes (5 or 10)
# Returns:
#   0 on success, 1 on error
activate_pause() {
    local duration_minutes="$1"
    
    # Validate duration
    if [ -z "${duration_minutes}" ] || [[ ! "${duration_minutes}" =~ ^[0-9]+$ ]]; then
        log_message "error" "Invalid pause duration: ${duration_minutes}"
        return 1
    fi
    
    if [ "${duration_minutes}" -ne 5 ] && [ "${duration_minutes}" -ne 10 ]; then
        log_message "error" "Invalid pause duration: ${duration_minutes} (must be 5 or 10)"
        return 1
    fi
    
    # Get current time
    local current_time
    current_time=$(date +%s)
    
    # Calculate pause end timestamp
    local pause_end_timestamp
    pause_end_timestamp=$((current_time + (duration_minutes * 60)))
    
    # Get today's date
    local today
    today=$(date +%Y-%m-%d)
    
    # Create config directory if it doesn't exist
    mkdir -p "${CONFIG_DIR}"
    
    # Write pause state file
    {
        echo "PAUSE_END_TIMESTAMP=${pause_end_timestamp}"
        echo "LAST_PAUSE_DATE=${today}"
    } > "${PAUSE_STATE_FILE}"
    
    # Set file permissions to 0600 (user read/write only)
    chmod 0600 "${PAUSE_STATE_FILE}"
    
    # Log pause activation
    local pause_end_time
    pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
    log_message "info" "Pause activated for ${duration_minutes} minutes, expires at ${pause_end_time}"
    log_to_file "INFO" "Pause activated: Duration=${duration_minutes} minutes, End timestamp=${pause_end_timestamp}, End time=${pause_end_time}, Date=${today}"
    
    return 0
}

# Clear expired or invalid pause state
clear_pause_state() {
    if [ -f "${PAUSE_STATE_FILE}" ]; then
        rm -f "${PAUSE_STATE_FILE}"
        log_message "info" "Pause state cleared"
        log_to_file "INFO" "Pause state file removed"
    fi
}

# Check if pause expired and clear if needed
# This function should be called before showing warnings
check_and_clear_expired_pause() {
    # Check if pause state file exists
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        return 0  # No pause state, nothing to clear
    fi
    
    # Get pause end timestamp
    local pause_end_timestamp
    pause_end_timestamp=$(get_pause_end_timestamp)
    
    if [ -z "${pause_end_timestamp}" ]; then
        # Invalid timestamp, clear state file
        clear_pause_state
        log_to_file "WARNING" "Pause state file had invalid timestamp, cleared"
        return 0
    fi
    
    # Get current time
    local current_time
    current_time=$(date +%s)
    
    # If pause has expired, clear only the timestamp (keep LAST_PAUSE_DATE)
    if [ "${current_time}" -ge "${pause_end_timestamp}" ]; then
        # Pause has expired, but keep LAST_PAUSE_DATE for once-per-day enforcement
        local last_pause_date
        last_pause_date=$(get_last_pause_date)
        
        # If we have a valid last pause date, keep it; otherwise remove the file
        if [ -n "${last_pause_date}" ]; then
            # Keep LAST_PAUSE_DATE, remove PAUSE_END_TIMESTAMP by rewriting file
            {
                echo "LAST_PAUSE_DATE=${last_pause_date}"
            } > "${PAUSE_STATE_FILE}"
            chmod 0600 "${PAUSE_STATE_FILE}"
            log_to_file "INFO" "Pause expired, cleared PAUSE_END_TIMESTAMP (kept LAST_PAUSE_DATE=${last_pause_date})"
        else
            # No valid last pause date, remove entire file
            clear_pause_state
            log_to_file "INFO" "Pause expired, cleared pause state file"
        fi
    fi
    
    return 0
}
