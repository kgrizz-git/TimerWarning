#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration Validation Module
#
# This module provides validation functions for the configuration wizard,
# including checking for 24/7 restrictions and high restriction levels.
#
# Functions:
# - check_restriction_coverage()  - Check total restricted minutes across week
# - merge_overlapping_intervals() - Merge overlapping/adjacent time intervals
#
# Dependencies:
# - configure-core.sh (for DAY_VARS array, though not strictly required)
#
# Usage: Source this file after configure-core.sh
#   source lib/configure-core.sh
#   source lib/configure-validation.sh
###############################################################################

###############################################################################
# Merge Overlapping/Adjacent Time Intervals
#
# Purpose:
#   Merges overlapping or adjacent time intervals to avoid double-counting
#   restricted minutes. This is critical for accurate restriction coverage
#   calculation, especially when:
#   - Multiple ranges on the same day overlap (e.g., "0-10,9-23")
#   - Overnight ranges overlap with next day's ranges (e.g., Monday "23-6" and Tuesday "0-5")
#
# Algorithm:
#   1. Sort all intervals by start minute (O(n log n))
#   2. Iterate through sorted intervals, merging overlapping/adjacent ones (O(n))
#   3. Two intervals are merged if: start2 <= end1 (overlap or adjacent)
#   4. Merged interval spans from min(start1, start2) to max(end1, end2)
#
# Input:
#   Array of "start:end" strings representing time intervals in minutes
#   Example: ("0:600", "540:1380", "1320:1440")
#   - Each string format: "START_MINUTE:END_MINUTE"
#   - Intervals use half-open range: [start, end) - inclusive start, exclusive end
#
# Output:
#   Merged "start:end" strings (one per line, sorted by start minute)
#   Example: "0:1380\n1320:1440" (first two intervals merged)
#
# Performance:
#   Time complexity: O(n log n) due to sorting
#   Space complexity: O(n) for sorted array
#
# Edge Cases:
#   - Empty array: returns immediately (no output)
#   - Single interval: returns that interval unchanged
#   - Adjacent intervals (end1 == start2): merged into single interval
#   - Completely overlapping intervals: merged into single interval
#
# Example:
#   Input:  ("0:600", "540:1380", "1500:1800")
#   Output: "0:1380\n1500:1800"
#   Explanation: First two intervals overlap at minutes 540-600, so they merge
###############################################################################
merge_overlapping_intervals() {
    local intervals=("$@")
    
    # Handle empty array
    if [ ${#intervals[@]} -eq 0 ]; then
        return 0
    fi
    
    # Sort intervals by start minute
    IFS=$'\n' sorted=($(sort -t: -k1 -n <<< "${intervals[*]}"))
    unset IFS
    
    # Start with first interval
    local current_start="${sorted[0]%%:*}"
    local current_end="${sorted[0]##*:}"
    
    # Process remaining intervals
    local i=1
    while [ $i -lt ${#sorted[@]} ]; do
        local interval="${sorted[$i]}"
        local start="${interval%%:*}"
        local end="${interval##*:}"
        
        if [ "${start}" -le "${current_end}" ]; then
            # Overlap or adjacent: extend current interval
            if [ "${end}" -gt "${current_end}" ]; then
                current_end="${end}"
            fi
        else
            # No overlap: output current, start new
            echo "${current_start}:${current_end}"
            current_start="${start}"
            current_end="${end}"
        fi
        i=$((i + 1))
    done
    
    # Output last interval
    echo "${current_start}:${current_end}"
}

###############################################################################
# Check Total Restriction Coverage Across All Days
#
# Purpose:
#   Validates configuration to prevent users from accidentally configuring
#   24/7 restrictions (all 24 hours, 7 days a week) which would effectively
#   lock them out of their computer. Also detects high restriction levels
#   (> HOURS_PER_DAY_WARN hours/day, default: 16 hours/day) and warns the user.
#
# Algorithm Overview:
#   1. Parse all time ranges from config_lines array (7 days: Sunday-Saturday)
#   2. Convert each range to minute-level intervals on unified weekly timeline
#      - Normal ranges: [start_hour×60, end_hour×60) on same day
#      - Overnight ranges: split into two segments spanning midnight
#   3. Map all intervals to absolute minutes (0-10079) across entire week
#   4. Merge overlapping/adjacent intervals (handles both within-day and cross-day overlaps)
#   5. Calculate total restricted minutes from merged intervals
#   6. Compare against thresholds to determine validation result
#
# Input:
#   config_lines array: Array of 7 strings (indices 0-6: Sunday-Saturday)
#   Format: "DAYVAR=RANGE" or "DAYVAR=" for skipped days
#   Examples:
#     - "SUNDAY=0-5"        → Sunday hours 0-4 (5 hours)
#     - "MONDAY=0-5,22-23"  → Monday hours 0-4 and 22-23 (7 hours total)
#     - "TUESDAY=23-6"      → Tuesday 23:00 → Wednesday 5:59 (overnight, 7 hours)
#     - "WEDNESDAY="        → Wednesday skipped (0 hours)
#
# Output:
#   Returns one of three strings via stdout:
#   - "ok"    : Valid configuration (<= 6720 minutes, <= 16 hours/day)
#   - "warn"  : High restriction level (> 6720 minutes, > 16 hours/day, but < 10080)
#   - "block" : 24/7 restrictions detected (>= 10080 minutes, all 24 hours × 7 days)
#
# Usage:
#   result=$(check_restriction_coverage "${config_lines[@]}")
#   case "${result}" in
#       "block") # Show error, prevent saving ;;
#       "warn")  # Show warning, allow confirmation ;;
#       "ok")    # Proceed normally ;;
#   esac
#
# Time Range Semantics:
#   - Hour ranges are inclusive of start hour, exclusive of end hour
#   - Example: "0-23" covers hours 0-22 (23 hours: 00:00-22:59)
#   - Example: "0-5" covers hours 0-4 (5 hours: 00:00-04:59)
#   - To cover all 24 hours, use combination like "0-12,12-0"
#
# Overnight Range Handling:
#   - Overnight ranges identified when start_hour > end_hour (e.g., "23-6")
#   - Split into two segments:
#     Segment 1: [start_hour×60, 1440) on current day
#     Segment 2: [0, end_hour×60) on next day
#   - Handles wrap-around: Saturday overnight ranges wrap to Sunday
#
# Overlap Detection:
#   - Within-day overlaps: Multiple ranges on same day (e.g., "0-10,9-23")
#   - Cross-day overlaps: Overnight ranges overlap with next day's ranges
#     Example: Monday "23-6" and Tuesday "0-5" overlap at hours 0-5
#   - All overlaps are automatically merged to avoid double-counting
#
# Thresholds:
#   Thresholds are defined globally in configure-core.sh:
#   - THRESHOLD_BLOCK = HOURS_PER_DAY_BLOCK × 60 × 7 (default: 24 hours/day = 10080 minutes)
#     → Configuration blocked if total >= THRESHOLD_BLOCK
#   - THRESHOLD_WARN = HOURS_PER_DAY_WARN × 60 × 7 (default: 16 hours/day = 6720 minutes)
#     → Warning shown if total > THRESHOLD_WARN but < THRESHOLD_BLOCK
#   - Boundary cases:
#     * Exactly THRESHOLD_WARN minutes: returns "ok" (no warning)
#     * Exactly (THRESHOLD_BLOCK - 1) minutes: returns "warn" (high but not 24/7)
#     * Exactly THRESHOLD_BLOCK minutes: returns "block" (24/7 detected)
#   To change thresholds, modify HOURS_PER_DAY_WARN or HOURS_PER_DAY_BLOCK in configure-core.sh
#
# Performance:
#   Time complexity: O(n log n) where n = total number of time ranges
#   Space complexity: O(n) for interval arrays
#   Runs once per configuration save (not continuously)
#
# Error Handling:
#   - Invalid hour values (< 0 or > 23): skipped silently
#   - Invalid range format: skipped silently (should be caught by format validation first)
#   - Empty days: counted as 0 restricted minutes
#   - No restrictions configured: returns "ok" immediately
#
# Related:
#   - Enhancement #22: Prevent 24/7 Restriction Configuration
#   - lib/time-validation.sh: Time range format validation
#   - lib/configure-ui.sh: Error/warning dialogs (show_24_7_error, show_high_restriction_warning)
###############################################################################
check_restriction_coverage() {
    local config_lines=("$@")
    local all_intervals=()
    
    # Constants for time calculations
    # These constants define the time units used in the unified weekly timeline
    # Use centralized constants from configure-core.sh if available, otherwise use fallback values
    local MINUTES_PER_DAY="${MINUTES_PER_DAY:-1440}"     # 24 hours × 60 minutes = 1440 minutes per day
    local MINUTES_PER_WEEK="${MINUTES_PER_WEEK:-10080}"   # 7 days × 1440 minutes = 10080 minutes per week
    
    # Validation thresholds are defined globally in configure-core.sh:
    # - THRESHOLD_BLOCK: 24/7 restrictions (calculated from HOURS_PER_DAY_BLOCK)
    # - THRESHOLD_WARN: High restriction level (calculated from HOURS_PER_DAY_WARN)
    # These are used directly from the global scope
    
    # Process each day (indices 0-6: Sunday-Saturday)
    for i in 0 1 2 3 4 5 6; do
        local line="${config_lines[$i]}"
        
        # Skip empty entries (day not configured)
        if [ -z "${line}" ]; then
            continue
        fi
        
        # Parse format: "DAYVAR=RANGE" (e.g., "SUNDAY=0-5" or "MONDAY=")
        local range="${line#*=}"  # Extract everything after '='
        
        # Skip if range is empty (day explicitly skipped)
        if [ -z "${range}" ]; then
            continue
        fi
        
        # Calculate day offset in minutes for unified weekly timeline
        # Day 0 (Sunday): minutes 0-1439
        # Day 1 (Monday): minutes 1440-2879
        # Day 2 (Tuesday): minutes 2880-4319
        # Day 3 (Wednesday): minutes 4320-5759
        # Day 4 (Thursday): minutes 5760-7199
        # Day 5 (Friday): minutes 7200-8639
        # Day 6 (Saturday): minutes 8640-10079
        local day_offset=$((i * MINUTES_PER_DAY))
        
        # Parse comma-separated ranges (e.g., "0-5,22-23")
        local IFS=','
        local ranges=()
        read -ra ranges <<< "${range}"
        unset IFS
        
        # Process each range on this day
        for r in "${ranges[@]}"; do
            # Trim whitespace
            r=$(echo "${r}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Skip empty ranges
            [ -z "${r}" ] && continue
            
            # Parse range: "START-END"
            local start_hour="${r%%-*}"
            local end_hour="${r##*-}"
            
            # Validate hour values (should already be validated, but check for safety)
            if ! [[ "${start_hour}" =~ ^[0-9]+$ ]] || ! [[ "${end_hour}" =~ ^[0-9]+$ ]]; then
                continue  # Skip invalid range
            fi
            
            if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ] || \
               [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
                continue  # Skip invalid hour values
            fi
            
            # Convert hours to minutes
            # Note: MINUTES_PER_HOUR is defined globally in configure-core.sh
            local start_minute=$((start_hour * MINUTES_PER_HOUR))
            local end_minute=$((end_hour * MINUTES_PER_HOUR))
            
            if [ "${start_hour}" -gt "${end_hour}" ]; then
                # Overnight range detected: start hour > end hour (e.g., "23-6")
                # Split into two segments that span midnight
                
                # Segment 1: From start hour to end of current day
                # Example: "23-6" on Monday → [1380, 1440) = Monday 23:00-23:59
                local day_end=$((day_offset + MINUTES_PER_DAY))
                all_intervals+=("$((day_offset + start_minute)):${day_end}")
                
                # Segment 2: From start of next day to end hour
                # Example: "23-6" on Monday → [0, 360) = Tuesday 00:00-05:59
                # Handle wrap-around: Saturday (day 6) → Sunday (day 0)
                local next_day=$(((i + 1) % 7))
                local next_offset=$((next_day * MINUTES_PER_DAY))
                all_intervals+=("${next_offset}:$((next_offset + end_minute))")
            else
                # Normal range: start hour <= end hour (e.g., "0-5", "9-17")
                # Single segment on current day: [start_minute, end_minute)
                # Example: "0-5" on Monday → [1440, 1740) = Monday 00:00-04:59
                all_intervals+=("$((day_offset + start_minute)):$((day_offset + end_minute))")
            fi
        done
    done
    
    # Handle case where no restrictions are configured
    if [ ${#all_intervals[@]} -eq 0 ]; then
        echo "ok"
        return 0
    fi
    
    # Merge all overlapping/adjacent intervals to avoid double-counting
    # This single merge pass handles both:
    # 1. Within-day overlaps: Multiple ranges on same day (e.g., "0-10,9-23" → "0-23")
    # 2. Cross-day overlaps: Overnight ranges overlapping with next day's ranges
    #    Example: Monday "23-6" [1380, 1440) + [0, 360) and Tuesday "0-5" [1440, 1740)
    #    → Monday overnight [1380, 1440) + [0, 360) overlaps with Tuesday [1440, 1740)
    #    → Merged result: [1380, 1740) (correctly counts 6 hours total, not 13 hours)
    #
    # Since all intervals are mapped to absolute minutes (0-10079) on unified timeline,
    # a single sort-and-merge pass correctly handles all overlap cases.
    local final_intervals
    final_intervals=$(merge_overlapping_intervals "${all_intervals[@]}")
    
    # Calculate total restricted minutes from merged intervals
    # Each interval is in format "start:end", representing [start, end) in minutes
    # Length of interval = end - start (half-open range)
    local total=0
    while IFS= read -r interval; do
        [ -z "${interval}" ] && continue
        
        local start="${interval%%:*}"
        local end="${interval##*:}"
        local length=$((end - start))
        total=$((total + length))
    done <<< "${final_intervals}"
    
    # Determine validation result based on thresholds
    # Note: Thresholds are defined globally in configure-core.sh:
    # - THRESHOLD_BLOCK = HOURS_PER_DAY_BLOCK × 60 × 7 (default: 24 hours/day = 10080 minutes)
    # - THRESHOLD_WARN = HOURS_PER_DAY_WARN × 60 × 7 (default: 16 hours/day = 6720 minutes)
    # Boundary cases:
    # - Exactly THRESHOLD_WARN minutes: returns "ok" (no warning)
    # - Exactly THRESHOLD_BLOCK minutes: returns "block" (prevents saving)
    if [ "${total}" -ge "${THRESHOLD_BLOCK}" ]; then
        # 24/7 restrictions detected: total >= THRESHOLD_BLOCK minutes
        # Configuration must be blocked to prevent accidental lockout
        echo "block"
    elif [ "${total}" -gt "${THRESHOLD_WARN}" ]; then
        # High restriction level: total > THRESHOLD_WARN but < THRESHOLD_BLOCK minutes
        # Show warning dialog, allow user to confirm or modify
        echo "warn"
    else
        # Valid configuration: total <= THRESHOLD_WARN minutes
        # Proceed with normal save flow
        echo "ok"
    fi
}

###############################################################################
# Validate Popup Timing Configuration
#
# Purpose:
#   Validates that POPUP_MIN_DISPLAY_TIME (in seconds) does not exceed
#   CHECK_INTERVAL (in minutes) * 60. This prevents multiple popups from
#   appearing simultaneously when the timer fires while a popup is still
#   in its minimum display time period.
#
# Parameters:
#   $1 - min_display_time - Minimum display time in seconds (0-300)
#   $2 - check_interval - Check interval in minutes (1-60)
#
# Returns:
#   0 if valid (no conflict), 1 if conflict detected (hard error)
#
# Error Message:
#   If conflict detected, error message is returned via stdout with both
#   fix options (increase interval OR decrease min time) presented equally.
#
# Usage:
#   if ! validate_popup_timing_config "${min_time}" "${interval}"; then
#       error_msg=$(validate_popup_timing_config "${min_time}" "${interval}" 2>&1)
#       show_error_dialog "Configuration Error" "${error_msg}"
#       return 1  # Block user from proceeding
#   fi
#
# This is for Enhancement #9 (Popup Queue Prevention)
###############################################################################
validate_popup_timing_config() {
    local min_display_time="$1"
    local check_interval="$2"
    
    # Validate inputs
    if [ -z "${min_display_time}" ] || ! [[ "${min_display_time}" =~ ^[0-9]+$ ]]; then
        return 0  # Invalid input, let other validation catch it
    fi
    
    if [ -z "${check_interval}" ] || ! [[ "${check_interval}" =~ ^[0-9]+$ ]]; then
        return 0  # Invalid input, let other validation catch it
    fi
    
    # Convert check interval to seconds
    local check_interval_seconds
    check_interval_seconds=$((check_interval * 60))
    
    # Check if min display time exceeds check interval
    if [ "${min_display_time}" -gt "${check_interval_seconds}" ]; then
        # Conflict detected - return error message
        echo "Error: Minimum display time (${min_display_time} seconds) is greater than check interval (${check_interval} minutes = ${check_interval_seconds} seconds). This will cause multiple popups to appear simultaneously. Please adjust one of these values: either increase CHECK_INTERVAL or decrease POPUP_MIN_DISPLAY_TIME." >&2
        return 1
    fi
    
    return 0
}
