#!/bin/bash

###############################################################################
# Sleep Warning System - Time Validation Module
#
# This module handles time range validation and checking including:
# - Single hour range validation (e.g., 0-5, 23-6)
# - Multiple hour range validation (comma-separated)
# - Overnight range support (ranges that span midnight)
# - Checking if current hour falls within restricted ranges
#
# Dependencies: logging.sh (for log_message())
#
# Usage: Source this file after logging.sh
#   source lib/logging.sh
#   source lib/time-validation.sh
###############################################################################

# Validate a single hour range (START-END format)
# Supports both normal ranges (0-5) and overnight ranges (23-6) that span midnight
validate_single_range() {
    local range="$1"
    
    # Check format: should be START-END
    if ! echo "${range}" | grep -qE '^[0-9]+-[0-9]+$'; then
        return 1
    fi
    
    local start_hour end_hour
    start_hour=$(echo "${range}" | cut -d'-' -f1)
    end_hour=$(echo "${range}" | cut -d'-' -f2)
    
    # Validate hour values (0-23)
    if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ]; then
        return 1
    fi
    
    if [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
        return 1
    fi
    
    # Both normal ranges (start < end) and overnight ranges (start > end) are valid
    # Overnight ranges like 23-6 mean 11 PM to 6 AM (spans midnight)
    # We only reject if start == end (which would be invalid)
    if [ "${start_hour}" -eq "${end_hour}" ]; then
        return 1
    fi
    
    return 0
}

# Validate hour range(s) - supports single range or comma-separated multiple ranges
validate_hour_range() {
    local ranges="$1"
    
    # Handle empty range (no restrictions)
    if [ -z "${ranges}" ]; then
        return 0
    fi
    
    # Split by comma and validate each range
    local IFS=','
    for range in ${ranges}; do
        # Trim whitespace
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if ! validate_single_range "${range}"; then
            return 1
        fi
    done
    
    return 0
}

# Check if current hour is within a single range
# Handles both normal ranges (0-5) and overnight ranges (23-6) that span midnight
is_hour_in_single_range() {
    local current_hour="$1"
    local range="$2"
    
    local start_hour end_hour
    start_hour=$(echo "${range}" | cut -d'-' -f1)
    end_hour=$(echo "${range}" | cut -d'-' -f2)
    
    # Handle overnight ranges (start > end, spans midnight)
    # Example: 23-6 means 11 PM to 5:59 AM (23:00 to 05:59)
    if [ "${start_hour}" -gt "${end_hour}" ]; then
        # Overnight range: current hour >= start OR current hour < end
        if [ "${current_hour}" -ge "${start_hour}" ] || [ "${current_hour}" -lt "${end_hour}" ]; then
            return 0
        fi
    else
        # Normal range: current hour >= start AND current hour < end
        if [ "${current_hour}" -ge "${start_hour}" ] && [ "${current_hour}" -lt "${end_hour}" ]; then
            return 0
        fi
    fi
    
    return 1
}

# Check if current hour is within restricted range(s) - supports comma-separated multiple ranges
is_restricted_hour() {
    local current_hour="$1"
    local ranges="$2"
    
    # Handle empty range (no restrictions)
    if [ -z "${ranges}" ]; then
        return 1
    fi
    
    # Validate ranges format
    if ! validate_hour_range "${ranges}"; then
        log_message "warning" "Invalid hour range format: ${ranges}"
        return 1
    fi
    
    # Split by comma and check each range
    local IFS=','
    for range in ${ranges}; do
        # Trim whitespace
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Check if current hour is within this range
        if is_hour_in_single_range "${current_hour}" "${range}"; then
            return 0
        fi
    done
    
    return 1
}

# Check if current hour is within lock hours range(s) - supports comma-separated multiple ranges
# This function checks if the current hour falls within configured lock hours
# Lock hours are separate from restriction hours and used for blocking configure.sh and manage.sh
# This is for Enhancement #19 Phase 2 (Additional Configurable Lock Hours)
#
# Parameters:
#   $1 - current_hour (0-23)
#   $2 - lock_ranges (comma-separated ranges, e.g., "9-17" or "0-5,22-23")
#
# Returns:
#   0 - Current hour is within lock hours (should block)
#   1 - Current hour is not within lock hours (should allow)
#
# Dependencies:
#   - validate_hour_range() - for format validation
#   - is_hour_in_single_range() - for single range checking
#   - log_message() - for warning messages (optional)
#
# This function uses the same logic as is_restricted_hour() for consistency
is_lock_hour() {
    local current_hour="$1"
    local lock_ranges="$2"
    
    # Handle empty range (no lock hours configured)
    if [ -z "${lock_ranges}" ]; then
        return 1
    fi
    
    # Validate ranges format
    if ! validate_hour_range "${lock_ranges}"; then
        if type log_message >/dev/null 2>&1; then
            log_message "warning" "Invalid lock hours range format: ${lock_ranges}"
        fi
        return 1
    fi
    
    # Split by comma and check each range
    local IFS=','
    for range in ${lock_ranges}; do
        # Trim whitespace
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Check if current hour is within this range
        if is_hour_in_single_range "${current_hour}" "${range}"; then
            return 0
        fi
    done
    
    return 1
}

# Check if configuration scripts should be blocked due to restricted hours or lock hours
# Returns 0 if execution is allowed, 1 if execution should be blocked
# This function checks CONFIGURE_BLOCK_ENABLED and current time against:
#   - Restricted hours (Phase 1)
#   - Lock hours (Phase 2, if configured)
# Blocks if current time is in restriction hours OR lock hours (OR logic)
# This is for Enhancement #19 (Prevent configure.sh and manage.sh Execution)
# Dependencies: config.sh (for get_configure_block_enabled, parse_config, parse_lock_hours)
check_config_lock_time() {
    # Check if configure blocking is enabled
    local block_enabled
    block_enabled=$(get_configure_block_enabled)
    
    # If blocking is disabled, allow execution
    if [ "${block_enabled}" != "true" ]; then
        return 0
    fi
    
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    
    # Get current hour (0-23)
    local current_hour
    current_hour=$(date +%H)
    # Remove leading zero if present
    current_hour=$((10#${current_hour}))
    
    # Parse configuration for current day (restriction hours)
    local restricted_range
    restricted_range=$(parse_config "${current_day}")
    
    # Parse lock hours for current day (Phase 2)
    local lock_hours_range=""
    if type parse_lock_hours >/dev/null 2>&1; then
        lock_hours_range=$(parse_lock_hours "${current_day}")
    fi
    
    # Check if current hour is within restricted range for current day
    if is_restricted_hour "${current_hour}" "${restricted_range}"; then
        # Current hour is restricted - block execution
        return 1
    fi
    
    # Check if current hour is within lock hours for current day (Phase 2)
    if [ -n "${lock_hours_range}" ] && type is_lock_hour >/dev/null 2>&1; then
        if is_lock_hour "${current_hour}" "${lock_hours_range}"; then
            # Current hour is in lock hours - block execution
            return 1
        fi
    fi
    
    # Current day may not have restrictions or lock hours, but check if previous day has overnight ranges
    # that extend into current day (same logic as sleep-warning.sh)
    # Check both restriction hours and lock hours from previous day
    
    # Calculate previous day (handle wrap-around: Sunday (0) -> Saturday (6))
    local prev_day
    if [ "${current_day}" -eq 0 ]; then
        prev_day=6  # Sunday -> Saturday
    else
        prev_day=$((current_day - 1))
    fi
    
    # Check previous day's restriction hours (overnight ranges)
    if [ -z "${restricted_range}" ]; then
        # Current day is empty/skipped (no restrictions for this day)
        # Check if previous day has an overnight range that extends into current day
        local prev_day_range
        prev_day_range=$(parse_config "${prev_day}")
        
        # Check if previous day has overnight ranges that extend into current day
        if [ -n "${prev_day_range}" ]; then
            # Check each range in previous day's configuration
            local IFS=','
            for range in ${prev_day_range}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_hour end_hour
                start_hour=$(echo "${range}" | cut -d'-' -f1)
                end_hour=$(echo "${range}" | cut -d'-' -f2)
                
                # Check if this is an overnight range (start > end) that extends into current day
                if [ "${start_hour}" -gt "${end_hour}" ]; then
                    # Overnight range: check if current hour falls within the end portion (before end_hour)
                    # Example: prev_day has 23-5, current hour is 2, then 2 < 5, so it's restricted
                    if [ "${current_hour}" -lt "${end_hour}" ]; then
                        # Current hour is within overnight range from previous day - block execution
                        return 1
                    fi
                fi
            done
        fi
    fi
    
    # Check previous day's lock hours (overnight ranges) - Phase 2
    if [ -z "${lock_hours_range}" ] && type parse_lock_hours >/dev/null 2>&1; then
        local prev_day_lock_hours
        prev_day_lock_hours=$(parse_lock_hours "${prev_day}")
        
        # Check if previous day has overnight lock hours that extend into current day
        if [ -n "${prev_day_lock_hours}" ]; then
            # Check each range in previous day's lock hours
            local IFS=','
            for range in ${prev_day_lock_hours}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_hour end_hour
                start_hour=$(echo "${range}" | cut -d'-' -f1)
                end_hour=$(echo "${range}" | cut -d'-' -f2)
                
                # Check if this is an overnight range (start > end) that extends into current day
                if [ "${start_hour}" -gt "${end_hour}" ]; then
                    # Overnight range: check if current hour falls within the end portion (before end_hour)
                    if [ "${current_hour}" -lt "${end_hour}" ]; then
                        # Current hour is within overnight lock hours from previous day - block execution
                        return 1
                    fi
                fi
            done
        fi
    fi
    
    # Not in restricted hours or lock hours - allow execution
    return 0
}
