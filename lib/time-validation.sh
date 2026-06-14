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
    validate_time_range "${ranges}"
}

# Validate time range(s) - supports HH-HH and HH:MM-HH:MM
validate_time_range() {
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
        
        if ! validate_single_time_range "${range}"; then
            return 1
        fi
    done
    
    return 0
}

# Validate a single time range
validate_single_time_range() {
    local range="$1"
    
    # Normalize input for validation (lowercase)
    range=$(echo "${range}" | tr '[:upper:]' '[:lower:]')
    
    if [[ ! "${range}" =~ ^[0-9]{1,2}(:[0-9]{2})?(am|pm)?-[0-9]{1,2}(:[0-9]{2})?(am|pm)?$ ]]; then
        return 1
    fi
    
    local start_part="${range%%-*}"
    local end_part="${range##*-}"
    
    # Validate start and end parts
    if ! validate_single_time_value "${start_part}"; then return 1; fi
    if ! validate_single_time_value "${end_part}"; then return 1; fi

    # Reject zero-length windows (start == end in minute precision)
    if type parse_time_token_to_24h_hm >/dev/null 2>&1; then
        local start_parts end_parts start_h start_m end_h end_m _hm start_min end_min
        if start_parts=$(parse_time_token_to_24h_hm "${start_part}") &&
           end_parts=$(parse_time_token_to_24h_hm "${end_part}"); then
            if type _split_24h_hm_parts >/dev/null 2>&1; then
                _hm=$(_split_24h_hm_parts "${start_parts}") || return 1
                start_h="${_hm%% *}"
                start_m="${_hm#* }"
                _hm=$(_split_24h_hm_parts "${end_parts}") || return 1
                end_h="${_hm%% *}"
                end_m="${_hm#* }"
            else
                start_h="${start_parts%% *}"
                start_m="${start_parts#* }"
                end_h="${end_parts%% *}"
                end_m="${end_parts#* }"
                if [ "${start_h}" = "${start_m}" ]; then start_m=0; fi
                if [ "${end_h}" = "${end_m}" ]; then end_m=0; fi
            fi
            start_min=$((10#${start_h} * 60 + 10#${start_m}))
            end_min=$((10#${end_h} * 60 + 10#${end_m}))
            if [ "${start_min}" -eq "${end_min}" ]; then
                return 1
            fi
        fi
    elif echo "${range}" | grep -qE '^[0-9]+-[0-9]+$'; then
        local start_hour end_hour
        start_hour=$(echo "${range}" | cut -d'-' -f1)
        end_hour=$(echo "${range}" | cut -d'-' -f2)
        if [ "${start_hour}" -eq "${end_hour}" ]; then
            return 1
        fi
    fi
    
    return 0
}

# Validate a single time value (HH, HH:MM, HHam, HH:MMpm, etc.)
validate_single_time_value() {
    local val="$1"
    
    # Normalize input for validation (lowercase, remove am/pm for numeric check)
    local input
    input=$(echo "${val}" | tr '[:upper:]' '[:lower:]')
    local is_12h=false
    if [[ "${input}" =~ am|pm ]]; then
        is_12h=true
    fi
    
    local numeric_part
    numeric_part=$(echo "${input}" | sed 's/[ap]m$//')
    
    local h m
    if [[ "${numeric_part}" =~ : ]]; then
        h=$(echo "${numeric_part}" | cut -d':' -f1)
        m=$(echo "${numeric_part}" | cut -d':' -f2)
    else
        h="${numeric_part}"
        m=0
    fi
    
    # Basic numeric validation
    if ! [[ "${h}" =~ ^[0-9]+$ ]] || ! [[ "${m}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [ "${is_12h}" = "true" ]; then
        # 12-hour format: 1-12
        if [ "${h}" -lt 1 ] || [ "${h}" -gt 12 ]; then return 1; fi
    else
        # 24-hour format: 0-23
        if [ "${h}" -lt 0 ] || [ "${h}" -gt 23 ]; then return 1; fi
    fi
    
    if [ "${m}" -lt 0 ] || [ "${m}" -gt 59 ]; then return 1; fi
    
    return 0
}

# Check if current hour is within a single range
# Handles both normal ranges (0-5) and overnight ranges (23-6) that span midnight
is_hour_in_single_range() {
    local current_hour="$1"
    local range="$2"
    
    local current_time_hhmm
    current_time_hhmm=$(printf "%02d00" "${current_hour}")
    
    is_time_in_single_range "${current_time_hhmm}" "${range}"
}

# Check if current time is within restricted range(s) - supports comma-separated multiple ranges
is_restricted_hour() {
    local current_hour="$1"
    local ranges="$2"
    
    # Extract current minute if not provided (for backward compatibility)
    local current_minute="${3:-0}"
    
    # Call new minute-precision function
    local current_time_hhmm
    current_time_hhmm=$(printf "%02d%02d" "${current_hour}" "${current_minute}")
    
    is_restricted_time "${current_time_hhmm}" "${ranges}"
}

# Check if current time (HHMM) is within restricted range(s)
is_restricted_time() {
    local current_time_hhmm="$1"
    local ranges="$2"
    
    # Handle empty range (no restrictions)
    if [ -z "${ranges}" ]; then
        return 1
    fi
    
    # Split by comma and check each range
    local IFS=','
    for range in ${ranges}; do
        # Trim whitespace
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Check if current time is within this range
        if is_time_in_single_range "${current_time_hhmm}" "${range}"; then
            return 0
        fi
    done
    
    return 1
}

# Check if current time (HHMM) is within a single range
# Handles both normal ranges (09:00-17:00) and overnight ranges (23:30-05:30)
is_time_in_single_range() {
    local current_time_hhmm="$1"
    local range="$2"
    
    # Normalize range to HHMM-HHMM
    local start_time end_time
    
    # Handle legacy HH-HH format by appending 00
    local start_part="${range%%-*}"
    local end_part="${range##*-}"
    
    if [[ "${start_part}" =~ : ]]; then
        start_time=$(echo "${start_part}" | tr -d ':')
    else
        start_time=$(printf "%02d00" "${start_part}")
    fi
    
    if [[ "${end_part}" =~ : ]]; then
        end_time=$(echo "${end_part}" | tr -d ':')
    else
        end_time=$(printf "%02d00" "${end_part}")
    fi
    
    # Handle overnight ranges (start > end, spans midnight)
    if [ "${start_time}" -gt "${end_time}" ]; then
        # Overnight range: current time >= start OR current time < end
        if [ "${current_time_hhmm}" -ge "${start_time}" ] || [ "${current_time_hhmm}" -lt "${end_time}" ]; then
            return 0
        fi
    else
        # Normal range: current time >= start AND current time < end
        if [ "${current_time_hhmm}" -ge "${start_time}" ] && [ "${current_time_hhmm}" -lt "${end_time}" ]; then
            return 0
        fi
    fi
    
    return 1
}

# Get current time in HHMM format
get_current_time() {
    date +%H%M
}

# Get current hour (0-23)
get_current_hour() {
    date +%H
}

# Check whether current HHMM falls in the post-midnight tail of any overnight
# range from the previous day. This intentionally ignores whether the current
# day has its own non-active range; previous-day overnight carry still applies.
is_time_in_previous_day_overnight_tail() {
    local current_time_hhmm="$1"
    local prev_day_ranges="$2"

    if [ -z "${prev_day_ranges}" ]; then
        return 1
    fi

    local IFS=','
    local range
    for range in ${prev_day_ranges}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -n "${range}" ] || continue

        local start_part="${range%%-*}"
        local end_part="${range##*-}"
        local start_time end_time

        if [[ "${start_part}" =~ : ]]; then
            start_time=$(echo "${start_part}" | tr -d ':')
        else
            start_time=$(printf "%02d00" "${start_part}")
        fi

        if [[ "${end_part}" =~ : ]]; then
            end_time=$(echo "${end_part}" | tr -d ':')
        else
            end_time=$(printf "%02d00" "${end_part}")
        fi

        if [ "${start_time}" -gt "${end_time}" ] && [ "${current_time_hhmm}" -lt "${end_time}" ]; then
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

# Check if current hour is within uninstall lock hours range(s) - supports comma-separated multiple ranges
# This function checks if the current hour falls within configured uninstall lock hours
# Uninstall lock hours are separate from restriction hours and configure.sh lock hours, used for uninstall protection
# This is for Enhancement #26 Phase 2 (Additional Uninstall Lock Hours)
#
# Parameters:
#   $1 - current_hour (0-23)
#   $2 - uninstall_lock_ranges (comma-separated ranges, e.g., "9-17" or "0-5,22-23")
#
# Returns:
#   0 - Current hour is within uninstall lock hours (should apply protection)
#   1 - Current hour is not within uninstall lock hours (should allow)
#
# Dependencies:
#   - validate_hour_range() - for format validation
#   - is_hour_in_single_range() - for single range checking
#   - log_message() - for warning messages (optional)
#
# This function uses the same logic as is_restricted_hour() and is_lock_hour() for consistency
is_uninstall_lock_hour() {
    local current_hour="$1"
    local uninstall_lock_ranges="$2"
    
    # Handle empty range (no uninstall lock hours configured)
    if [ -z "${uninstall_lock_ranges}" ]; then
        return 1
    fi
    
    # Validate ranges format
    if ! validate_hour_range "${uninstall_lock_ranges}"; then
        if type log_message >/dev/null 2>&1; then
            log_message "warning" "Invalid uninstall lock hours range format: ${uninstall_lock_ranges}"
        fi
        return 1
    fi
    
    # Split by comma and check each range
    local IFS=','
    for range in ${uninstall_lock_ranges}; do
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
    
    # Get current time in HHMM format (Enhancement 16b)
    local current_time_hhmm
    current_time_hhmm=$(get_current_time)
    
    # Parse configuration for current day (restriction hours)
    local restricted_range
    restricted_range=$(parse_config "${current_day}")
    
    # Parse lock hours for current day (Phase 2)
    local lock_hours_range=""
    if type parse_lock_hours >/dev/null 2>&1; then
        lock_hours_range=$(parse_lock_hours "${current_day}")
    fi
    
    # Check if current time is within restricted range for current day
    if is_restricted_time "${current_time_hhmm}" "${restricted_range}"; then
        # Current time is restricted - block execution
        return 1
    fi
    
    # Check if current time is within lock hours for current day (Phase 2)
    if [ -n "${lock_hours_range}" ] && type is_restricted_time >/dev/null 2>&1; then
        if is_restricted_time "${current_time_hhmm}" "${lock_hours_range}"; then
            # Current time is in lock hours - block execution
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
    
    # Check previous day's restriction hours for overnight ranges that carry into today.
    if type parse_config >/dev/null 2>&1; then
        local prev_day_range
        prev_day_range=$(parse_config "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_range}"; then
            return 1
        fi
    fi
    
    # Check previous day's lock hours for overnight ranges that carry into today.
    if type parse_lock_hours >/dev/null 2>&1; then
        local prev_day_lock_hours
        prev_day_lock_hours=$(parse_lock_hours "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_lock_hours}"; then
            return 1
        fi
    fi
    
    # Not in restricted hours or lock hours - allow execution
    return 0
}

# Check if uninstall protection should be applied based on current time
# Returns protection mode string ("none" or "difficult") if in restricted hours
# Returns "none" if not in restricted hours or mode is "none"
# This is for Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)
#
# Returns:
#   "none" - No protection needed (not in restricted hours or mode is "none")
#   "difficult" - Protection needed (in restricted hours and mode is "difficult")
#
# Exit Codes:
#   0 - Success (always returns successfully, check return value)
check_uninstall_protection_time() {
    # Get uninstall protection mode from config
    local protection_mode="none"
    if type get_uninstall_protection_mode >/dev/null 2>&1; then
        protection_mode=$(get_uninstall_protection_mode)
    fi
    
    # If protection is disabled, return "none"
    if [ "${protection_mode}" != "difficult" ]; then
        echo "none"
        return 0
    fi
    
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    
    # Get current time in HHMM format (Enhancement 16b)
    local current_time_hhmm
    current_time_hhmm=$(get_current_time)
    
    # Parse configuration for current day (restriction hours)
    local restricted_range
    if type parse_config >/dev/null 2>&1; then
        restricted_range=$(parse_config "${current_day}")
    fi
    
    # Check if current time is within restricted range for current day
    if [ -n "${restricted_range}" ] && type is_restricted_time >/dev/null 2>&1; then
        if is_restricted_time "${current_time_hhmm}" "${restricted_range}"; then
            # Current time is restricted - return protection mode
            echo "${protection_mode}"
            return 0
        fi
    fi
    
    # Current day may not have restrictions, but check if previous day has overnight ranges
    # that extend into current day (same logic as sleep-warning.sh)
    # Calculate previous day (handle wrap-around: Sunday (0) -> Saturday (6))
    local prev_day
    if [ "${current_day}" -eq 0 ]; then
        prev_day=6  # Sunday -> Saturday
    else
        prev_day=$((current_day - 1))
    fi
    
    # Check previous day's restriction hours for overnight ranges that carry into today.
    if type parse_config >/dev/null 2>&1; then
        local prev_day_range
        prev_day_range=$(parse_config "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_range}"; then
            echo "${protection_mode}"
            return 0
        fi
    fi
    
    # Phase 2: Check uninstall lock hours (separate from restriction hours)
    # Parse uninstall lock hours for current day
    local uninstall_lock_range
    if type parse_uninstall_lock_hours >/dev/null 2>&1; then
        uninstall_lock_range=$(parse_uninstall_lock_hours "${current_day}")
    fi
    
    # Check if current time is within uninstall lock hours for current day
    if [ -n "${uninstall_lock_range}" ] && type is_restricted_time >/dev/null 2>&1; then
        if is_restricted_time "${current_time_hhmm}" "${uninstall_lock_range}"; then
            # Current time is in uninstall lock hours - return protection mode
            echo "${protection_mode}"
            return 0
        fi
    fi
    
    # Check previous day's uninstall lock hours for overnight ranges that carry into today.
    if type parse_uninstall_lock_hours >/dev/null 2>&1; then
        local prev_day_uninstall_lock_range
        prev_day_uninstall_lock_range=$(parse_uninstall_lock_hours "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_uninstall_lock_range}"; then
            echo "${protection_mode}"
            return 0
        fi
    fi
    
    # Not in restricted hours or uninstall lock hours - return "none" (no protection needed)
    echo "none"
    return 0
}
