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
# - time-parsing.sh (for format conversions)
###############################################################################

# Source time-parsing.sh if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/time-parsing.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/time-parsing.sh"
fi

# Format a single range to human-readable format
format_range_human() {
    local range="$1"
    local day_name="$2"
    
    # Handle empty or invalid ranges (e.g., skipped days)
    if [ -z "${range}" ] || [ "${range}" = "(no restrictions)" ]; then
        echo "(no restrictions)"
        return 0
    fi
    
    # Normalize range to HH:MM-HH:MM if normalization helpers are available.
    # This allows format_range_human to accept legacy HH-HH as well as new
    # 12‑hour inputs like "11pm-5am" that may still exist in older configs.
    if type normalize_time_range >/dev/null 2>&1; then
        local norm
        norm=$(normalize_time_range "${range}")
        if [ -n "${norm}" ]; then
            # normalize_time_range always returns one or more comma-separated
            # ranges; format_range_human only handles a single range, so use
            # the first one if multiple are present.
            range="${norm%%,*}"
        fi
    fi
    
    # Extract start and end times (handles HH:MM-HH:MM, HH-HH, and 12h with am/pm)
    local start_str end_str
    start_str=$(echo "${range}" | cut -d'-' -f1)
    end_str=$(echo "${range}" | cut -d'-' -f2)

    local start_h start_m end_h end_m
    if type parse_time_token_to_24h_hm >/dev/null 2>&1; then
        local start_parts end_parts
        if ! start_parts=$(parse_time_token_to_24h_hm "${start_str}") ||
           ! end_parts=$(parse_time_token_to_24h_hm "${end_str}"); then
            echo "${range}"
            return 0
        fi
        local _hm
        if type _split_24h_hm_parts >/dev/null 2>&1; then
            _hm=$(_split_24h_hm_parts "${start_parts}") || { echo "${range}"; return 0; }
            start_h="${_hm%% *}"
            start_m="${_hm#* }"
            _hm=$(_split_24h_hm_parts "${end_parts}") || { echo "${range}"; return 0; }
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
    else
        if [[ "${start_str}" =~ : ]]; then
            start_h=$(echo "${start_str}" | cut -d':' -f1)
            start_m=$(echo "${start_str}" | cut -d':' -f2 | sed 's/[ap]m$//')
        else
            start_h="${start_str}"
            start_m=0
        fi

        if [[ "${end_str}" =~ : ]]; then
            end_h=$(echo "${end_str}" | cut -d':' -f1)
            end_m=$(echo "${end_str}" | cut -d':' -f2 | sed 's/[ap]m$//')
        else
            end_h="${end_str}"
            end_m=0
        fi
    fi
    
    # Get display format preference
    local display_format
    display_format=$(get_time_display_format)
    
    local start_display end_display
    if [ "${display_format}" = "24hour" ]; then
        start_display=$(printf "%02d:%02d" "$((10#${start_h}))" "$((10#${start_m}))")
        end_display=$(printf "%02d:%02d" "$((10#${end_h}))" "$((10#${end_m}))")
    else
        start_display=$(24hour_to_12hour "${start_h}" "${start_m}")
        end_display=$(24hour_to_12hour "${end_h}" "${end_m}")
    fi
    
    # Handle overnight ranges
    if [ "$((10#${start_h}))" -gt "$((10#${end_h}))" ] ||
       { [ "$((10#${start_h}))" -eq "$((10#${end_h}))" ] && [ "$((10#${start_m}))" -gt "$((10#${end_m}))" ]; }; then
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
        echo "${start_display} -> ${end_display} (${next_day})"
    else
        echo "${start_display} -> ${end_display}"
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
        local start1_raw end1_raw
        start1_raw=$(echo "${range1}" | cut -d'-' -f1)
        end1_raw=$(echo "${range1}" | cut -d'-' -f2)
        
        # Support both HH and HH:MM by converting to integer hours for comparison
        local start1 end1
        if [[ "${start1_raw}" =~ : ]]; then
            start1=$(echo "${start1_raw}" | cut -d':' -f1)
        else
            start1="${start1_raw}"
        fi
        if [[ "${end1_raw}" =~ : ]]; then
            end1=$(echo "${end1_raw}" | cut -d':' -f1)
        else
            end1="${end1_raw}"
        fi
        
        # If day1 has overnight range (start > end)
        if [ "${start1}" -gt "${end1}" ]; then
            # Check if day2 has early morning range that overlaps
            for range2 in ${day2_ranges}; do
                range2=$(echo "${range2}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start2_raw end2_raw
                start2_raw=$(echo "${range2}" | cut -d'-' -f1)
                end2_raw=$(echo "${range2}" | cut -d'-' -f2)
                
                local start2 end2
                if [[ "${start2_raw}" =~ : ]]; then
                    start2=$(echo "${start2_raw}" | cut -d':' -f1)
                else
                    start2="${start2_raw}"
                fi
                if [[ "${end2_raw}" =~ : ]]; then
                    end2=$(echo "${end2_raw}" | cut -d':' -f1)
                else
                    end2="${end2_raw}"
                fi
                
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
    # Extract range after the first colon; keep any further colons in HH:MM segments
    prev_range=$(echo "${prev_line}" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check if previous day is skipped or has no restrictions
    if [ "${prev_range}" = "(no restrictions)" ] || [ -z "${prev_range}" ]; then
        return 1  # No restrictions to inherit
    fi
    
    # Check for overnight ranges in previous day (start > end)
    local IFS=','
    local inherited_ranges=()
    for range in ${prev_range}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Support both HH-HH and HH:MM-HH:MM by converting to HHMM integers
        local start_part end_part
        start_part=$(echo "${range}" | cut -d'-' -f1)
        end_part=$(echo "${range}" | cut -d'-' -f2)
        
        local start_hour start_minute end_hour end_minute
        if [[ "${start_part}" =~ : ]]; then
            start_hour=$(echo "${start_part}" | cut -d':' -f1)
            start_minute=$(echo "${start_part}" | cut -d':' -f2)
        else
            start_hour="${start_part}"
            start_minute=0
        fi
        if [[ "${end_part}" =~ : ]]; then
            end_hour=$(echo "${end_part}" | cut -d':' -f1)
            end_minute=$(echo "${end_part}" | cut -d':' -f2)
        else
            end_hour="${end_part}"
            end_minute=0
        fi
        
        local start_time end_time
        start_time=$(printf "%02d%02d" "${start_hour}" "${start_minute}")
        end_time=$(printf "%02d%02d" "${end_hour}" "${end_minute}")
        
        # If this is an overnight range (start > end), it extends into current day
        if [ "${start_time}" -gt "${end_time}" ]; then
            # Format the inherited portion: 0-end_hour on current day
            local inherited_start="0:00"
            local inherited_end
            if [[ "${range}" =~ : ]]; then
                inherited_end=$(echo "${range}" | cut -d'-' -f2)
            else
                inherited_end=$(printf "%02d:00" "${end_hour}")
            fi
            local inherited_range="${inherited_start}-${inherited_end}"
            inherited_ranges+=("${inherited_range}")
        fi
    done
    
    # If we found inherited ranges, format them
    if [ ${#inherited_ranges[@]} -gt 0 ]; then
        local current_day_name="${DAY_NAMES[${day_index}]}"
        local formatted_ranges=()
        for inherited_range in "${inherited_ranges[@]}"; do
            local formatted
            formatted=$(format_range_human "${inherited_range}" "${current_day_name}")
            formatted_ranges+=("${formatted}")
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
