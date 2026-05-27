#!/bin/bash

###############################################################################
# Sleep Warning System - Time Calculations Module
#
# This module provides time calculation functions for both configuration
# validation (hour-based) and runtime popup display (minute-based).
#
# Functions:
# Hour-based Calculations (for Configuration Validation):
# - calculate_range_duration()        - Calculate duration in hours of a single time range
# - calculate_total_day_duration()     - Calculate total duration for a day including overnight from previous day
#
# Minute-based Calculations (for Runtime Popup Display):
# - build_weekly_restricted_intervals() - Build weekly timeline of restricted intervals in minutes
# - get_current_minute_offset()         - Calculate current minute offset from start of week
# - is_minute_restricted()              - Check if minute is restricted
# - format_minute_offset_to_time()      - Format minute offset to human-readable time
# - get_next_unrestricted_time()        - Calculate next unrestricted time
#
# Dependencies:
# - config.sh (for parse_config function)
# - configure-validation.sh (for merge_overlapping_intervals - used by minute-based functions)
#
# Usage: Source this file after config.sh
#   source lib/config.sh
#   source lib/time-calculations.sh
###############################################################################

###############################################################################
# Hour-based Calculations (for Configuration Validation)
###############################################################################

# Calculate the duration in hours of a single time range
# Handles both normal ranges (0-5) and overnight ranges (23-6)
# Parameters:
#   $1 - range (format: START-END, e.g., "0-5" or "23-6")
# Returns:
#   The number of hours the range spans (stdout)
# Examples:
#   calculate_range_duration "0-5"   -> 5 (normal range)
#   calculate_range_duration "23-6"  -> 7 (overnight range: 1 hour + 6 hours)
#   calculate_range_duration "0-12"  -> 12 (exactly 12 hours)
#   calculate_range_duration "0-13"  -> 13 (over 12 hours, will trigger warning)
# Note: Input should be validated before calling this function
calculate_range_duration() {
    local range="$1"
    
    # Trim whitespace
    range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    local start_part end_part
    start_part=$(echo "${range}" | cut -d'-' -f1)
    end_part=$(echo "${range}" | cut -d'-' -f2)
    
    local start_m end_m
    
    # Convert to minutes
    if [[ "${start_part}" =~ : ]]; then
        local h=$(echo "${start_part}" | cut -d':' -f1)
        local m=$(echo "${start_part}" | cut -d':' -f2)
        start_m=$((h * 60 + m))
    else
        start_m=$((start_part * 60))
    fi
    
    if [[ "${end_part}" =~ : ]]; then
        local h=$(echo "${end_part}" | cut -d':' -f1)
        local m=$(echo "${end_part}" | cut -d':' -f2)
        end_m=$((h * 60 + m))
    else
        end_m=$((end_part * 60))
    fi
    
    # Handle overnight ranges (start > end, spans midnight)
    if [ "${start_m}" -gt "${end_m}" ]; then
        # Overnight: (1440 - start) + end
        echo $(((1440 - start_m + end_m) / 60))
    else
        # Normal range: end - start
        echo $(((end_m - start_m) / 60))
    fi
}

# Merge overlapping hour intervals for a single day
# Input: Array of "start:end" strings representing hour intervals [start, end)
# Output: Merged intervals (one per line, sorted by start hour)
# Example: ("0:5", "4:10") -> "0:10" (merged)
merge_hour_intervals() {
    local intervals=("$@")
    
    # Handle empty array
    if [ ${#intervals[@]} -eq 0 ]; then
        return 0
    fi
    
    # Sort intervals by start hour
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

# Calculate total duration in hours for a day, including overnight ranges from previous day
# This checks both the current day's ranges and any overnight ranges from the previous day
# that extend into the current day (e.g., previous day's "23-6" extends into current day 0-5)
# 
# IMPORTANT: 
# - For overnight ranges on the current day (e.g., "21-5"), only the portion
#   on the current day is counted (21-24 = 3 hours), not the full span (21-5 = 8 hours).
#   The remaining portion (0-5 = 5 hours) is counted on the next day.
# - Overlapping intervals are merged to avoid double-counting. For example, if Sunday has
#   "23-5" and Monday has "0-5", these overlap at hours 0-4, so Monday counts only 5 hours,
#   not 10 hours.
#
# Parameters:
#   $1 - day_index (0-6, Sunday=0, Saturday=6)
#   $2 - current_day_ranges (comma-separated ranges for current day, e.g., "0-5,22-23")
# Returns:
#   Total duration in hours (stdout)
# Examples:
#   calculate_total_day_duration 1 "0-5" -> 5 (Monday, no overnight from Sunday)
#   calculate_total_day_duration 1 "0-5" (if Sunday has "23-5") -> 5 (overlap merged, not 10)
#   calculate_total_day_duration 1 "23-5" (if Sunday has "23-5") -> 6 (0-5 from Sunday + 23-23 from Monday)
# Note: Requires parse_config from config.sh to read previous day's ranges
calculate_total_day_duration() {
    local day_index="$1"
    local current_day_ranges="$2"
    
    local intervals=()
    
    # Helper to parse time to minutes
    parse_to_min() {
        local val="$1"
        if [[ "${val}" =~ : ]]; then
            local h=$(echo "${val}" | cut -d':' -f1)
            local m=$(echo "${val}" | cut -d':' -f2)
            echo $((h * 60 + m))
        else
            echo $((val * 60))
        fi
    }
    
    # Collect intervals from current day's ranges
    if [ -n "${current_day_ranges}" ]; then
        local IFS=','
        for range in ${current_day_ranges}; do
            range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "${range}" ]; then
                local start_part end_part
                start_part=$(echo "${range}" | cut -d'-' -f1)
                end_part=$(echo "${range}" | cut -d'-' -f2)
                
                local start_m end_m
                start_m=$(parse_to_min "${start_part}")
                end_m=$(parse_to_min "${end_part}")
                
                if [ "${start_m}" -gt "${end_m}" ]; then
                    # Overnight range: only count portion on current day
                    intervals+=("${start_m}:1440")
                else
                    # Normal range
                    intervals+=("${start_m}:${end_m}")
                fi
            fi
        done
    fi
    
    # Collect intervals from previous day's overnight ranges
    local prev_day_index
    if [ "${day_index}" -eq 0 ]; then
        prev_day_index=6
    else
        prev_day_index=$((day_index - 1))
    fi
    
    local prev_day_ranges=""
    if type parse_config >/dev/null 2>&1; then
        prev_day_ranges=$(parse_config "${prev_day_index}" 2>/dev/null || echo "")
    fi
    
    if [ -n "${prev_day_ranges}" ]; then
        local IFS=','
        for range in ${prev_day_ranges}; do
            range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "${range}" ]; then
                local start_part end_part
                start_part=$(echo "${range}" | cut -d'-' -f1)
                end_part=$(echo "${range}" | cut -d'-' -f2)
                
                local start_m end_m
                start_m=$(parse_to_min "${start_part}")
                end_m=$(parse_to_min "${end_part}")
                
                if [ "${start_m}" -gt "${end_m}" ]; then
                    # Overnight range from previous day extends into current day
                    intervals+=("0:${end_m}")
                fi
            fi
        done
    fi
    
    # Merge overlapping intervals
    local merged_intervals
    merged_intervals=$(merge_overlapping_intervals "${intervals[@]}")
    
    # Calculate total duration in minutes
    local total_min=0
    while IFS= read -r interval; do
        [ -z "${interval}" ] && continue
        local start="${interval%%:*}"
        local end="${interval##*:}"
        total_min=$((total_min + end - start))
    done <<< "${merged_intervals}"
    
    # Return duration in hours (rounded up)
    echo $(((total_min + 59) / 60))
}

###############################################################################
# Minute-based Calculations (for Runtime Popup Display)
###############################################################################

###############################################################################
# Build Weekly Restricted Intervals
#
# Purpose:
#   Builds a complete weekly timeline of all restricted intervals by parsing
#   the configuration file for all 7 days and converting time ranges to
#   minute-level intervals on a unified weekly timeline (0-10079 minutes).
#
# Algorithm:
#   1. For each day (0-6: Sunday-Saturday):
#      - Parse all time ranges from config file
#      - For each range:
#        * Normal range (start < end): single segment on same day
#        * Overnight range (start > end): split into two segments spanning midnight
#      - Convert to minute offsets from start of week
#   2. Return array of "start:end" interval strings
#
# Output:
#   Array of "start:end" strings representing restricted intervals in minutes
#   Example: ("0:300", "1440:1740", "1380:1440", "0:360")
#
# Note: This function does NOT merge intervals - that's done separately
###############################################################################
build_weekly_restricted_intervals() {
    local all_intervals=()
    
    # Constants for time calculations (use centralized constants if available)
    # Note: MINUTES_PER_HOUR / MINUTES_PER_DAY may be readonly globals (from configure-core.sh),
    # so do not attempt to assign to those names locally.
    local minutes_per_hour="${MINUTES_PER_HOUR:-60}"
    local minutes_per_day="${MINUTES_PER_DAY:-1440}"
    
    # Process each day (indices 0-6: Sunday-Saturday)
    local i
    for i in 0 1 2 3 4 5 6; do
        # Parse configuration for this day
        local range
        range=$(parse_config "${i}")
        
        # Skip if no restrictions for this day
        if [ -z "${range}" ]; then
            continue
        fi
        
        # Calculate day offset in minutes for unified weekly timeline
        local day_offset=$((i * minutes_per_day))
        
        # Parse comma-separated ranges (e.g., "0-5,22-23")
        local IFS=','
        local ranges=()
        read -ra ranges <<< "${range}"
        unset IFS
        
        # Process each range on this day
        local r
        for r in "${ranges[@]}"; do
            # Trim whitespace
            r=$(echo "${r}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Skip empty ranges
            [ -z "${r}" ] && continue
            
            # Parse range: "START-END"
            local start_hour="${r%%-*}"
            local end_hour="${r##*-}"
            
            # Validate hour values
            if ! [[ "${start_hour}" =~ ^[0-9]+$ ]] || ! [[ "${end_hour}" =~ ^[0-9]+$ ]]; then
                continue  # Skip invalid range
            fi
            
            if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ] || \
               [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
                continue  # Skip invalid hour values
            fi
            
            # Convert hours to minutes
            local start_minute=$((start_hour * minutes_per_hour))
            local end_minute=$((end_hour * minutes_per_hour))
            
            if [ "${start_hour}" -gt "${end_hour}" ]; then
                # Overnight range detected: start hour > end hour (e.g., "23-6")
                # Split into two segments that span midnight
                
                # Segment 1: From start hour to end of current day
                local day_end=$((day_offset + minutes_per_day))
                all_intervals+=("$((day_offset + start_minute)):${day_end}")
                
                # Segment 2: From start of next day to end hour
                # Handle wrap-around: Saturday (day 6) -> Sunday (day 0)
                local next_day=$(((i + 1) % 7))
                local next_offset=$((next_day * minutes_per_day))
                all_intervals+=("${next_offset}:$((next_offset + end_minute))")
            else
                # Normal range: start hour <= end hour (e.g., "0-5", "9-17")
                # Single segment on current day
                all_intervals+=("$((day_offset + start_minute)):$((day_offset + end_minute))")
            fi
        done
    done
    
    # Return intervals (one per line)
    printf '%s\n' "${all_intervals[@]}"
}

###############################################################################
# Get Current Minute Offset
#
# Purpose:
#   Calculates the current time as a minute offset from the start of the week
#   (Sunday 00:00 = minute 0).
#
# Output:
#   Minute offset (0-10079) representing current time in the weekly timeline
###############################################################################
get_current_minute_offset() {
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    # Remove leading zero if present
    current_day=$((10#${current_day}))
    
    # Get current hour (0-23)
    local current_hour
    current_hour=$(date +%H)
    # Remove leading zero if present
    current_hour=$((10#${current_hour}))
    
    # Get current minute (0-59)
    local current_minute
    current_minute=$(date +%M)
    # Remove leading zero if present
    current_minute=$((10#${current_minute}))
    
    # Calculate minute offset from start of week
    local minutes_per_day=1440
    local minutes_per_hour=60
    local offset=$((current_day * minutes_per_day + current_hour * minutes_per_hour + current_minute))
    
    echo "${offset}"
}

###############################################################################
# Check if Minute is Restricted
#
# Purpose:
#   Checks if a given minute offset falls within any of the restricted intervals.
#
# Parameters:
#   $1 - minute_offset: Minute offset to check (0-10079)
#   $2 - merged_intervals: Newline-separated list of "start:end" intervals
#
# Returns:
#   0 if minute is restricted, 1 if unrestricted
###############################################################################
is_minute_restricted() {
    local minute_offset=$1
    local merged_intervals="$2"
    
    # Check if minute falls within any restricted interval
    while IFS= read -r interval; do
        [ -z "${interval}" ] && continue
        
        local start="${interval%%:*}"
        local end="${interval##*:}"
        
        # Check if minute is in [start, end) range (half-open)
        if [ "${minute_offset}" -ge "${start}" ] && [ "${minute_offset}" -lt "${end}" ]; then
            return 0  # Restricted
        fi
    done <<< "${merged_intervals}"
    
    return 1  # Unrestricted
}

###############################################################################
# Format Minute Offset to Human-Readable Time
#
# Purpose:
#   Converts a minute offset (0-10079) to a human-readable time string with
#   relative day information (today, tomorrow, or day name).
#
# Parameters:
#   $1 - minute_offset: Minute offset to format (0-10079)
#   $2 - current_minute_offset: Current minute offset for relative formatting
#
# Output:
#   Human-readable time string
#   Examples:
#     - "in 15 minutes" (if < 60 minutes away)
#     - "at 5:00 AM" (if later today)
#     - "Tomorrow at 6:00 AM" (if next day)
#     - "Friday at 9:00 AM" (if 2+ days away)
###############################################################################
format_minute_offset_to_time() {
    local minute_offset=$1
    local current_minute_offset=$2
    
    # Use constants from configure-core.sh if available, otherwise use local fallback values
    # Note: MINUTES_PER_* may be readonly globals (from configure-core.sh).
    local minutes_per_day="${MINUTES_PER_DAY:-1440}"
    local minutes_per_hour="${MINUTES_PER_HOUR:-60}"
    local minutes_per_week="${MINUTES_PER_WEEK:-10080}"
    
    # Calculate day, hour, and minute from offset
    local day=$((minute_offset / minutes_per_day))
    local hour=$(((minute_offset % minutes_per_day) / minutes_per_hour))
    local minute=$((minute_offset % minutes_per_hour))
    
    # Calculate current day, hour, minute
    local current_day=$((current_minute_offset / minutes_per_day))
    local current_hour=$(((current_minute_offset % minutes_per_day) / minutes_per_hour))
    local current_minute=$((current_minute_offset % minutes_per_hour))
    
    # Day names
    local day_names=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
    local day_name="${day_names[${day}]}"
    
    # Format hour in 12-hour format
    local hour_12
    local am_pm
    if [ "${hour}" -eq 0 ]; then
        hour_12=12
        am_pm="AM"
    elif [ "${hour}" -lt 12 ]; then
        hour_12="${hour}"
        am_pm="AM"
    elif [ "${hour}" -eq 12 ]; then
        hour_12=12
        am_pm="PM"
    else
        hour_12=$((hour - 12))
        am_pm="PM"
    fi
    
    # Format minute with leading zero if needed
    local minute_str
    if [ "${minute}" -lt 10 ]; then
        minute_str="0${minute}"
    else
        minute_str="${minute}"
    fi
    
    # Calculate time difference in minutes
    local diff_minutes
    if [ "${minute_offset}" -ge "${current_minute_offset}" ]; then
        diff_minutes=$((minute_offset - current_minute_offset))
    else
        # Wrap around to next week
        diff_minutes=$((minutes_per_week - current_minute_offset + minute_offset))
    fi
    
    # Format based on time difference
    if [ "${diff_minutes}" -lt 60 ]; then
        # Less than 1 hour away
        if [ "${diff_minutes}" -eq 1 ]; then
            echo "in 1 minute"
        else
            echo "in ${diff_minutes} minutes"
        fi
    elif [ "${day}" -eq "${current_day}" ]; then
        # Same day
        echo "at ${hour_12}:${minute_str} ${am_pm}"
    elif [ "${day}" -eq $(((current_day + 1) % 7)) ]; then
        # Next day
        echo "Tomorrow at ${hour_12}:${minute_str} ${am_pm}"
    else
        # 2+ days away
        echo "${day_name} at ${hour_12}:${minute_str} ${am_pm}"
    fi
}

###############################################################################
# Get Next Unrestricted Time
#
# Purpose:
#   Calculates when the next unrestricted time will occur based on the current
#   configuration. Handles overnight intervals and multiple intervals per day.
#
# Algorithm:
#   1. Build weekly restricted intervals from config
#   2. Merge overlapping intervals
#   3. Get current minute offset
#   4. Search forward from current time to find first unrestricted minute
#   5. Format result as human-readable string
#
# Output:
#   Human-readable time string indicating when restrictions end
#   Returns empty string if no unrestricted time found (24/7 restrictions)
###############################################################################
get_next_unrestricted_time() {
    # Build all restricted intervals
    local all_intervals_str
    all_intervals_str=$(build_weekly_restricted_intervals)
    
    # Handle case where no restrictions are configured
    if [ -z "${all_intervals_str}" ]; then
        echo "now (no restrictions configured)"
        return 0
    fi
    
    # Convert newline-separated intervals to array
    local all_intervals=()
    while IFS= read -r interval; do
        [ -z "${interval}" ] && continue
        all_intervals+=("${interval}")
    done <<< "${all_intervals_str}"
    
    # Merge overlapping intervals (reuse function from configure-validation.sh)
    local merged_intervals
    merged_intervals=$(merge_overlapping_intervals "${all_intervals[@]}")
    
    # Get current minute offset
    local current_minute
    current_minute=$(get_current_minute_offset)
    
    # Search forward from current time to find first unrestricted minute
    # Optimize by jumping to end of restricted intervals instead of checking minute by minute
    # Note: MINUTES_PER_WEEK may be a readonly global (from configure-core.sh).
    local minutes_per_week="${MINUTES_PER_WEEK:-10080}"
    local search_minute="${current_minute}"
    local start_minute="${current_minute}"
    local found=false
    
    # Search up to one full week ahead
    local search_count=0
    while [ ${search_count} -lt ${minutes_per_week} ]; do
        # Check if this minute is restricted
        if ! is_minute_restricted "${search_minute}" "${merged_intervals}"; then
            # Found unrestricted time
            found=true
            break
        fi
        
        # Find the end of the current restricted interval to jump ahead
        local interval_end="${minutes_per_week}"  # Default: end of week
        while IFS= read -r interval; do
            [ -z "${interval}" ] && continue
            
            local start="${interval%%:*}"
            local end="${interval##*:}"
            
            # Check if search_minute is in this interval
            if [ "${search_minute}" -ge "${start}" ] && [ "${search_minute}" -lt "${end}" ]; then
                # We're in this interval - the next unrestricted time is at 'end'
                # Use the earliest end time (in case of overlapping intervals, though they should be merged)
                if [ "${end}" -lt "${interval_end}" ]; then
                    interval_end="${end}"
                fi
            fi
        done <<< "${merged_intervals}"
        
        # Jump to the end of the current restricted interval
        if [ "${interval_end}" -lt "${minutes_per_week}" ]; then
            # Normal case: end is in current week
            local jump_distance=$((interval_end - search_minute))
            search_minute="${interval_end}"
            search_count=$((search_count + jump_distance))
        else
            # Shouldn't happen if we found an interval, but fallback: move to next minute
            search_minute=$(((search_minute + 1) % minutes_per_week))
            search_count=$((search_count + 1))
        fi
        
        # Safety check: if we've wrapped around to start, stop (24/7 restrictions)
        if [ "${search_minute}" -eq "${start_minute}" ]; then
            break
        fi
    done
    
    # Format result
    if [ "${found}" = "true" ]; then
        format_minute_offset_to_time "${search_minute}" "${current_minute}"
    else
        # No unrestricted time found (24/7 restrictions - should never happen with validation)
        echo "No unrestricted time scheduled (24/7 restrictions active)"
    fi
}