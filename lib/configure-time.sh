#!/bin/bash

###############################################################################
# Sleep Warning System - Time Formatting and Validation Module
#
# This module provides time range formatting, validation, and analysis functions
# for the configuration wizard.
#
# Functions:
# - format_range_human()         - Format single time range to human-readable
# - format_ranges_human()        - Format multiple time ranges
# - detect_overlaps()            - Detect overnight range overlaps between days
# - get_inherited_restrictions() - Get restrictions inherited from previous day
#
# Dependencies:
# - configure-core.sh (for DAY_NAMES, format_hour_12h)
###############################################################################

# Format a single range to human-readable format
format_range_human() {
    local range="$1"
    local day_name="$2"
    
    # Handle empty or invalid ranges (e.g., skipped days)
    if [ -z "${range}" ] || [ "${range}" = "(no restrictions)" ] || ! echo "${range}" | grep -qE '^[0-9]+-[0-9]+$'; then
        echo "(no restrictions)"
        return 0
    fi
    
    local start_hour end_hour
    start_hour=$(echo "${range}" | cut -d'-' -f1)
    end_hour=$(echo "${range}" | cut -d'-' -f2)
    
    local start_12h end_12h
    start_12h=$(format_hour_12h "${start_hour}")
    end_12h=$(format_hour_12h "${end_hour}")
    
    # Handle overnight ranges
    if [ "${start_hour}" -gt "${end_hour}" ]; then
        # Get next day name
        local next_day
        case "${day_name}" in
            Sunday) next_day="Monday" ;;
            Monday) next_day="Tuesday" ;;
            Tuesday) next_day="Wednesday" ;;
            Wednesday) next_day="Thursday" ;;
            Thursday) next_day="Friday" ;;
            Friday) next_day="Saturday" ;;
            Saturday) next_day="Sunday" ;;
            *) next_day="next day" ;;
        esac
        echo "${start_12h} → ${end_12h} (${next_day})"
    else
        echo "${start_12h} → ${end_12h}"
    fi
}

# Format multiple ranges to human-readable format
format_ranges_human() {
    local ranges="$1"
    local day_name="$2"
    
    local IFS=','
    local formatted_ranges=()
    for range in ${ranges}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        formatted_ranges+=("$(format_range_human "${range}" "${day_name}")")
    done
    
    # Join with " AND "
    local result=""
    local first=true
    for formatted in "${formatted_ranges[@]}"; do
        if [ "${first}" = "true" ]; then
            result="${formatted}"
            first=false
        else
            result="${result} AND ${formatted}"
        fi
    done
    
    echo "${result}"
}

# Detect overlaps between days
detect_overlaps() {
    local day1_index="$1"
    local day1_ranges="$2"
    local day2_index="$3"
    local day2_ranges="$4"
    
    # Only check if day2 is the next day after day1
    local expected_next=$(( (day1_index + 1) % 7 ))
    if [ "${day2_index}" -ne "${expected_next}" ]; then
        return 1  # Not adjacent days, no overlap possible
    fi
    
    # Check if day1 has overnight range that overlaps with day2's early morning range
    if [ -z "${day1_ranges}" ] || [ -z "${day2_ranges}" ]; then
        return 1  # No overlap if either is empty
    fi
    
    # Extract overnight ranges from day1 (start > end)
    local IFS=','
    for range1 in ${day1_ranges}; do
        range1=$(echo "${range1}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local start1 end1
        start1=$(echo "${range1}" | cut -d'-' -f1)
        end1=$(echo "${range1}" | cut -d'-' -f2)
        
        # If day1 has overnight range (start > end)
        if [ "${start1}" -gt "${end1}" ]; then
            # Check if day2 has early morning range that overlaps
            for range2 in ${day2_ranges}; do
                range2=$(echo "${range2}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start2 end2
                start2=$(echo "${range2}" | cut -d'-' -f1)
                end2=$(echo "${range2}" | cut -d'-' -f2)
                
                # Check if day2's range overlaps with day1's overnight end
                # day1 overnight: start1 to end1 (e.g., 23-6 means 23:00 to 05:59)
                # day2 early: start2 to end2 (e.g., 0-5 means 00:00 to 04:59)
                # Overlap if: day2 starts before day1's overnight ends
                if [ "${start2}" -lt "${end1}" ]; then
                    echo "${range1}|${range2}|${start2}-${end1}"
                    return 0
                fi
            done
        fi
    done
    
    return 1  # No overlap found
}

# Get inherited overnight restrictions from previous day
# Returns formatted string if inherited restrictions exist, empty string otherwise
get_inherited_restrictions() {
    local day_index="$1"
    local -n summary_ref="$2"  # Use different name to avoid circular reference
    
    # Get previous day index (wrapping around: Sunday (0) checks Saturday (6))
    local prev_day_index
    if [ "${day_index}" -eq 0 ]; then
        prev_day_index=6  # Sunday checks Saturday
    else
        prev_day_index=$((day_index - 1))
    fi
    
    # Check if previous day has restrictions
    if [ -z "${summary_ref[${prev_day_index}]}" ]; then
        return 1  # No previous day restrictions
    fi
    
    local prev_line="${summary_ref[${prev_day_index}]}"
    local prev_range
    prev_range=$(echo "${prev_line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check if previous day is skipped or has no restrictions
    if [ "${prev_range}" = "(no restrictions)" ] || [ -z "${prev_range}" ]; then
        return 1  # No restrictions to inherit
    fi
    
    # Check for overnight ranges in previous day (start > end)
    local IFS=','
    local inherited_ranges=()
    for range in ${prev_range}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local start_hour end_hour
        start_hour=$(echo "${range}" | cut -d'-' -f1)
        end_hour=$(echo "${range}" | cut -d'-' -f2)
        
        # If this is an overnight range (start > end), it extends into current day
        if [ "${start_hour}" -gt "${end_hour}" ]; then
            # Format the inherited portion: 0-end_hour on current day
            local inherited_start="0"
            local inherited_end="${end_hour}"
            local inherited_range="${inherited_start}-${inherited_end}"
            inherited_ranges+=("${inherited_range}")
        fi
    done
    
    # If we found inherited ranges, format them
    if [ ${#inherited_ranges[@]} -gt 0 ]; then
        local current_day_name="${DAY_NAMES[${day_index}]}"
        local formatted_ranges=()
        for inherited_range in "${inherited_ranges[@]}"; do
            local inherited_end
            inherited_end=$(echo "${inherited_range}" | cut -d'-' -f2)
            local start_12h end_12h
            start_12h=$(format_hour_12h "0")
            end_12h=$(format_hour_12h "${inherited_end}")
            formatted_ranges+=("${start_12h} → ${end_12h}")
        done
        
        # Join multiple inherited ranges with " AND "
        local result=""
        local first=true
        for formatted in "${formatted_ranges[@]}"; do
            if [ "${first}" = "true" ]; then
                result="${formatted}"
                first=false
            else
                result="${result} AND ${formatted}"
            fi
        done
        
        echo "${result} (inherited)"
        return 0
    fi
    
    return 1  # No inherited restrictions
}
