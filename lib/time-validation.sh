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
