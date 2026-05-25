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

## Source the shared daily-caps helpers (check_daily_caps, _compute_day_merged_minutes, etc.)
_CONFIGURE_VALIDATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
if [ -f "${_CONFIGURE_VALIDATION_DIR}/daily-caps.sh" ]; then
    source "${_CONFIGURE_VALIDATION_DIR}/daily-caps.sh"
fi
unset _CONFIGURE_VALIDATION_DIR

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
# Process Hours Array to Intervals
#
# Purpose:
#   Helper function to process any hours array (restriction hours, lock hours,
#   or uninstall lock hours) and convert time ranges to minute-level intervals
#   on the unified weekly timeline.
#
# Parameters:
#   $1 - hours_array: Array of hour configuration lines
#        Format: "DAYVAR=RANGE" or "CONFIG_LOCK_HOURS_DAYVAR=RANGE" or "UNINSTALL_LOCK_HOURS_DAYVAR=RANGE"
#   $2 - intervals_ref: Name of array to append intervals to (pass by reference)
#
# Output:
#   Appends interval strings in format "START:END" to the intervals_ref array
#
# Algorithm:
#   - Extracts day index from line prefix (SUNDAY=0, MONDAY=1, etc.)
#   - Parses time ranges (handles comma-separated and overnight ranges)
#   - Converts to minute-level intervals on unified timeline
#   - Handles overnight ranges by splitting into two segments
#
# Example:
#   process_hours_array "config_lines" "all_intervals"
#   # Processes all entries in config_lines array and adds intervals to all_intervals
###############################################################################
process_hours_array() {
    local -n hours_array_ref="$1"  # Pass array by reference
    local -n intervals_ref="$2"    # Pass intervals array by reference
    
    # Process each day (indices 0-6: Sunday-Saturday)
    for i in 0 1 2 3 4 5 6; do
        local line="${hours_array_ref[$i]}"
        
        # Skip empty entries (day not configured)
        if [ -z "${line}" ]; then
            continue
        fi
        
        # Parse format: "DAYVAR=RANGE" or "CONFIG_LOCK_HOURS_DAYVAR=RANGE" or "UNINSTALL_LOCK_HOURS_DAYVAR=RANGE"
        # Extract everything after '=' (the range part)
        local range="${line#*=}"
        
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
            # Supports both integer ("7") and HH:MM ("07:00") formats.
            local start_part="${r%%-*}"
            local end_part="${r##*-}"

            local start_hour start_min_offset end_hour end_min_offset
            if [[ "${start_part}" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
                start_hour="${BASH_REMATCH[1]}"
                start_min_offset="${BASH_REMATCH[2]}"
            elif [[ "${start_part}" =~ ^([0-9]{1,2})$ ]]; then
                start_hour="${start_part}"
                start_min_offset="0"
            else
                continue  # Unrecognised format
            fi

            if [[ "${end_part}" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
                end_hour="${BASH_REMATCH[1]}"
                end_min_offset="${BASH_REMATCH[2]}"
            elif [[ "${end_part}" =~ ^([0-9]{1,2})$ ]]; then
                end_hour="${end_part}"
                end_min_offset="0"
            else
                continue  # Unrecognised format
            fi

            # Validate using 10# prefix to avoid octal interpretation of 08, 09.
            local _sh=$((10#${start_hour})) _sm=$((10#${start_min_offset}))
            local _eh=$((10#${end_hour}))   _em=$((10#${end_min_offset}))
            if [ "${_sh}" -gt 23 ] || [ "${_eh}" -gt 23 ] || \
               [ "${_sm}" -gt 59 ] || [ "${_em}" -gt 59 ]; then
                continue  # Out-of-range, skip
            fi

            # Convert to minutes within the day (using validated base-10 values)
            local start_minute=$(( _sh * MINUTES_PER_HOUR + _sm ))
            local end_minute=$(( _eh * MINUTES_PER_HOUR + _em ))
            
            if [ "${_sh}" -gt "${_eh}" ] || ([ "${_sh}" -eq "${_eh}" ] && [ "${_sm}" -gt "${_em}" ]); then
                # Overnight range detected: start time > end time (e.g., "23-6", "23:30-06:00")
                # Split into two segments that span midnight
                
                # Segment 1: From start hour to end of current day
                # Example: "23-6" on Monday → [1380, 1440) = Monday 23:00-23:59
                local day_end=$((day_offset + MINUTES_PER_DAY))
                intervals_ref+=("$((day_offset + start_minute)):${day_end}")
                
                # Segment 2: From start of next day to end hour
                # Example: "23-6" on Monday → [0, 360) = Tuesday 00:00-05:59
                # Handle wrap-around: Saturday (day 6) → Sunday (day 0)
                local next_day=$(((i + 1) % 7))
                local next_offset=$((next_day * MINUTES_PER_DAY))
                intervals_ref+=("${next_offset}:$((next_offset + end_minute))")
            else
                # Normal range: start hour <= end hour (e.g., "0-5", "9-17")
                # Single segment on current day: [start_minute, end_minute)
                # Example: "0-5" on Monday → [1440, 1740) = Monday 00:00-04:59
                intervals_ref+=("$((day_offset + start_minute)):$((day_offset + end_minute))")
            fi
        done
    done
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
#   **EXTENDED**: Now validates the combined total of:
#   - Restriction hours (main schedule for sleep warnings)
#   - Config lock hours (additional hours for config locking and configure.sh blocking)
#   - Uninstall lock hours (additional hours for difficult uninstall verification)
#
# Algorithm Overview:
#   1. Parse arguments to separate three array types (restriction, lock, uninstall lock)
#   2. Process each array type to convert time ranges to minute-level intervals
#   3. Combine all intervals into unified weekly timeline (0-10079 minutes)
#   4. Merge overlapping/adjacent intervals (handles overlaps within and across types)
#   5. Calculate total restricted minutes from merged intervals
#   6. Compare against thresholds to determine validation result
#
# Input:
#   Variable number of arguments containing:
#   - config_lines: Array of restriction hour lines (format: "DAYVAR=RANGE")
#   - lock_hours_lines: Array of config lock hour lines (format: "CONFIG_LOCK_HOURS_DAYVAR=RANGE")
#   - uninstall_lock_hours_lines: Array of uninstall lock hour lines (format: "UNINSTALL_LOCK_HOURS_DAYVAR=RANGE")
#
#   Arrays are detected by pattern matching:
#   - Lines starting with "CONFIG_LOCK_HOURS_" → lock_hours_lines
#   - Lines starting with "UNINSTALL_LOCK_HOURS_" → uninstall_lock_hours_lines
#   - Lines matching "^(SUNDAY|MONDAY|...|SATURDAY)=" → config_lines
#
#   Examples:
#     - "SUNDAY=0-5"        → Sunday restriction hours 0-4 (5 hours)
#     - "CONFIG_LOCK_HOURS_MONDAY=9-17" → Monday lock hours 9-16 (8 hours)
#     - "UNINSTALL_LOCK_HOURS_TUESDAY=23-6" → Tuesday uninstall lock hours 23:00-05:59 (7 hours)
#
# Output:
#   Returns one of three strings via stdout:
#   - "ok"    : Valid configuration (<= 5040 minutes/week ≈ ≤12 hours/day avg)
#   - "warn"  : High restriction level (> 5040 and <= 6720 minutes/week, ≈ 12-16 h/day avg)
#   - "block" : Excessive restrictions (> 6720 minutes/week, > 16 hours/day avg)
#
# Usage:
#   # Pass all three arrays (backward compatible if only config_lines passed)
#   result=$(check_restriction_coverage "${config_lines[@]}" "${lock_hours_lines[@]}" "${uninstall_lock_hours_lines[@]}")
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
#   - Cross-type overlaps: Different hour types overlap on same day
#     Example: Restriction "0-8", Lock "7-15", Uninstall "10-18" all overlap
#   - All overlaps are automatically merged to avoid double-counting
#
# Validation Scope:
#   - Always validates additional hours regardless of feature enablement
#   - This prevents dangerous configurations even if features are disabled
#   - Safety check, not runtime check
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
#   Time complexity: O(n log n) where n = total number of time ranges across all types
#   Space complexity: O(n) for interval arrays
#   Runs once per configuration save (not continuously)
#
# Error Handling:
#   - Invalid hour values (< 0 or > 23): skipped silently
#   - Invalid range format: skipped silently (should be caught by format validation first)
#   - Empty days: counted as 0 restricted minutes
#   - No restrictions configured: returns "ok" immediately
#   - Backward compatible: If only config_lines passed, works as before
#
# Related:
#   - Enhancement #22: Prevent 24/7 Restriction Configuration
#   - Enhancement #20: Additional Hours for Config Locking
#   - Enhancement #26 Phase 2: Additional Uninstall Lock Hours
#   - lib/time-validation.sh: Time range format validation
#   - lib/configure-ui.sh: Error/warning dialogs (show_24_7_error, show_high_restriction_warning)
###############################################################################
check_restriction_coverage() {
    local all_args=("$@")
    local all_intervals=()
    
    # Parse arguments to separate three array types
    # Pattern detection (same approach as write_config() uses):
    # - CONFIG_LOCK_HOURS_ prefix → lock_hours_lines
    # - UNINSTALL_LOCK_HOURS_ prefix → uninstall_lock_hours_lines
    # - Day name patterns (SUNDAY=, MONDAY=, etc.) → config_lines
    local config_lines=()
    local lock_hours_lines=()
    local uninstall_lock_hours_lines=()
    
    for arg in "${all_args[@]}"; do
        if [[ "${arg}" =~ ^CONFIG_LOCK_HOURS_ ]]; then
            # Lock hours line (e.g., "CONFIG_LOCK_HOURS_MONDAY=9-17")
            # Extract day index from day name in the line
            local day_name="${arg#CONFIG_LOCK_HOURS_}"
            day_name="${day_name%%=*}"
            local day_index
            case "${day_name}" in
                SUNDAY) day_index=0 ;;
                MONDAY) day_index=1 ;;
                TUESDAY) day_index=2 ;;
                WEDNESDAY) day_index=3 ;;
                THURSDAY) day_index=4 ;;
                FRIDAY) day_index=5 ;;
                SATURDAY) day_index=6 ;;
                *) continue ;;  # Skip invalid day name
            esac
            lock_hours_lines[${day_index}]="${arg}"
        elif [[ "${arg}" =~ ^UNINSTALL_LOCK_HOURS_ ]]; then
            # Uninstall lock hours line (e.g., "UNINSTALL_LOCK_HOURS_MONDAY=9-17")
            # Extract day index from day name in the line
            local day_name="${arg#UNINSTALL_LOCK_HOURS_}"
            day_name="${day_name%%=*}"
            local day_index
            case "${day_name}" in
                SUNDAY) day_index=0 ;;
                MONDAY) day_index=1 ;;
                TUESDAY) day_index=2 ;;
                WEDNESDAY) day_index=3 ;;
                THURSDAY) day_index=4 ;;
                FRIDAY) day_index=5 ;;
                SATURDAY) day_index=6 ;;
                *) continue ;;  # Skip invalid day name
            esac
            uninstall_lock_hours_lines[${day_index}]="${arg}"
        elif [[ "${arg}" =~ ^(SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)= ]]; then
            # Restriction hours line (e.g., "MONDAY=0-5")
            # Extract day index from day name
            local day_name="${arg%%=*}"
            local day_index
            case "${day_name}" in
                SUNDAY) day_index=0 ;;
                MONDAY) day_index=1 ;;
                TUESDAY) day_index=2 ;;
                WEDNESDAY) day_index=3 ;;
                THURSDAY) day_index=4 ;;
                FRIDAY) day_index=5 ;;
                SATURDAY) day_index=6 ;;
                *) continue ;;  # Skip invalid day name
            esac
            config_lines[${day_index}]="${arg}"
        fi
    done
    
    # Process restriction hours (existing behavior - backward compatible)
    process_hours_array "config_lines" "all_intervals"
    
    # Process lock hours (new - Enhancement #20)
    process_hours_array "lock_hours_lines" "all_intervals"
    
    # Process uninstall lock hours (new - Enhancement #26 Phase 2)
    process_hours_array "uninstall_lock_hours_lines" "all_intervals"
    
    # Constants for time calculations
    # These constants define the time units used in the unified weekly timeline
    # Use centralized readonly constants from configure-core.sh (MINUTES_PER_DAY, MINUTES_PER_WEEK)
    
    # Validation thresholds are defined globally in configure-core.sh:
    # - THRESHOLD_BLOCK: 24/7 restrictions (calculated from HOURS_PER_DAY_BLOCK)
    # - THRESHOLD_WARN: High restriction level (calculated from HOURS_PER_DAY_WARN)
    # These are used directly from the global scope
    
    
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
    
    # Determine validation result based on weekly-average thresholds.
    # Thresholds are defined globally in configure-core.sh:
    #   THRESHOLD_BLOCK = HOURS_PER_DAY_BLOCK × 60 × 7 (default: 16 h/day avg = 6720 min)
    #   THRESHOLD_WARN  = HOURS_PER_DAY_WARN  × 60 × 7 (default: 12 h/day avg = 5040 min)
    #
    # Comparison semantics use strict ">" so that a config which exactly hits
    # the per-day 16-hour cap on every day (= 6720 min/week) is still allowed.
    # The per-day cap in lib/daily-caps.sh is the primary safety enforcer; this
    # weekly check is a defense-in-depth backstop.
    #
    # Boundary cases:
    #   total == THRESHOLD_WARN  → "ok"
    #   total >  THRESHOLD_WARN and  ≤ THRESHOLD_BLOCK  → "warn"
    #   total >  THRESHOLD_BLOCK → "block"
    if [ "${total}" -gt "${THRESHOLD_BLOCK}" ]; then
        echo "block"
    elif [ "${total}" -gt "${THRESHOLD_WARN}" ]; then
        echo "warn"
    else
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

###############################################################################
# Check Minute Precision Compatibility with Timer Interval
#
# Purpose:
#   Checks if minute-precision restrictions (e.g., 11:30 PM) are compatible
#   with the current CHECK_INTERVAL. If CHECK_INTERVAL is too large (e.g., 60),
#   restrictions starting at non-zero minutes may not trigger on time.
#
# Parameters:
#   $1 - check_interval - Check interval in minutes (1-60)
#   $2... - config_lines - All restriction hour lines
#
# Returns:
#   0 if compatible (no warning), 1 if warning recommended
#
# Warning Message:
#   If warning recommended, message is returned via stdout.
###############################################################################
check_minute_precision_compatibility() {
    local check_interval="$1"
    shift
    local config_lines=("$@")
    
    # If check interval is 15 or less, it's generally fine
    if [ "${check_interval}" -le 15 ]; then
        return 0
    fi
    
    # Check if any restriction uses non-zero minutes
    local has_minute_precision=false
    for line in "${config_lines[@]}"; do
        local range="${line#*=}"
        if [[ "${range}" =~ :[1-5][0-9] ]]; then
            # Found non-zero minutes (e.g., :30, :15)
            # Note: :00 is not considered minute precision for this check
            has_minute_precision=true
            break
        fi
    done
    
    if [ "${has_minute_precision}" = "true" ]; then
        echo "Warning: You have configured restrictions with minute precision (e.g., 11:30 PM), but your check interval is set to ${check_interval} minutes. This means warnings may be delayed by up to ${check_interval} minutes. For exact timing, we recommend setting CHECK_INTERVAL to 15 or less."
        return 1
    fi
    
    return 0
}
