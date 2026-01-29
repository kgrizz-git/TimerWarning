#!/bin/bash

###############################################################################
# Sleep Warning System - Time Parsing and Conversion Module
#
# This module provides core functions for parsing, normalizing, and converting
# time formats (12-hour and 24-hour) with minute precision.
#
# Functions:
# - normalize_time_input()         - Normalize time input string
# - detect_time_format()           - Detect if input is 12h or 24h format
# - parse_single_time()            - Parse a single time value
# - parse_time_range()             - Parse a time range string
# - 12hour_to_24hour()             - Convert 12h to 24h format
# - 24hour_to_12hour()             - Convert 24h to 12h format
# - convert_time_range_to_24hour() - Convert any range to 24h format
# - normalize_time_range()         - Normalize range to HH:MM-HH:MM
###############################################################################

# Normalize time input string (remove extra spaces, handle case-insensitive AM/PM)
normalize_time_input() {
    local input="$1"
    # Remove all spaces and convert to lowercase
    echo "${input}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}

# Detect if input is 12h or 24h format
# Returns "12hour" or "24hour"
detect_time_format() {
    local input
    input=$(normalize_time_input "$1")
    
    if [[ "${input}" =~ am|pm ]]; then
        echo "12hour"
    else
        echo "24hour"
    fi
}

# Parse a single time value (e.g., "11:30pm" or "23:30")
# Outputs: hour minute is_pm (0 for AM, 1 for PM)
parse_single_time() {
    local input
    input=$(normalize_time_input "$1")
    local format
    format=$(detect_time_format "${input}")
    
    local hour=0
    local minute=0
    local is_pm=0
    
    if [ "${format}" = "12hour" ]; then
        # Handle 12-hour format
        if [[ "${input}" =~ pm$ ]]; then
            is_pm=1
        fi
        
        # Remove am/pm for numeric parsing
        local numeric_part
        numeric_part=$(echo "${input}" | sed 's/[ap]m$//')
        
        if [[ "${numeric_part}" =~ : ]]; then
            hour=$(echo "${numeric_part}" | cut -d':' -f1)
            minute=$(echo "${numeric_part}" | cut -d':' -f2)
        else
            hour="${numeric_part}"
            minute=0
        fi
    else
        # Handle 24-hour format
        if [[ "${input}" =~ : ]]; then
            # Use input directly since numeric_part is not set for 24h format
            hour=$(echo "${input}" | cut -d':' -f1)
            minute=$(echo "${input}" | cut -d':' -f2)
        else
            hour="${input}"
            minute=0
        fi
    fi
    
    # Basic validation of numeric parts
    if ! [[ "${hour}" =~ ^[0-9]+$ ]] || ! [[ "${minute}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    echo "${hour} ${minute} ${is_pm}"
    return 0
}

# Convert 12h to 24h format
# Parameters: hour (1-12), minute (0-59), is_pm (0 or 1)
12hour_to_24hour() {
    local hour="$1"
    local minute="$2"
    local is_pm="$3"
    
    local h24="${hour}"
    
    if [ "${is_pm}" -eq 1 ]; then
        if [ "${hour}" -lt 12 ]; then
            h24=$((hour + 12))
        fi
    else
        if [ "${hour}" -eq 12 ]; then
            h24=0
        fi
    fi
    
    printf "%02d:%02d" "${h24}" "${minute}"
}

# Convert 24h to 12h format
# Parameters: hour (0-23), minute (0-59)
24hour_to_12hour() {
    local hour="$1"
    local minute="$2"
    
    local h12="${hour}"
    local ampm="am"
    
    if [ "${hour}" -ge 12 ]; then
        ampm="pm"
        if [ "${hour}" -gt 12 ]; then
            h12=$((hour - 12))
        fi
    fi
    
    if [ "${h12}" -eq 0 ]; then
        h12=12
    fi
    
    printf "%d:%02d%s" "${h12}" "${minute}" "${ampm}"
}

# Parse a time range string (e.g., "11:30pm-5:30am")
# Returns start_h start_m start_pm end_h end_m end_pm
parse_time_range() {
    local input
    input=$(normalize_time_input "$1")
    
    local start_str="${input%%-*}"
    local end_str="${input##*-}"
    
    if [ "${start_str}" = "${end_str}" ]; then return 1; fi
    
    local start_data end_data
    if ! start_data=$(parse_single_time "${start_str}"); then return 1; fi
    if ! end_data=$(parse_single_time "${end_str}"); then return 1; fi
    
    echo "${start_data} ${end_data}"
    return 0
}

# Convert any range to 24h format HH:MM-HH:MM
convert_time_range_to_24hour() {
    local input="$1"
    local range_data
    if ! range_data=$(parse_time_range "${input}"); then
        return 1
    fi
    
    # Use array to avoid read -r issues with multiple variables
    # Ensure space-splitting regardless of global IFS
    local old_ifs="${IFS}"
    IFS=' '
    local data_arr=(${range_data})
    IFS="${old_ifs}"
    
    if [ ${#data_arr[@]} -ne 6 ]; then return 1; fi
    
    local start_h=${data_arr[0]}
    local start_m=${data_arr[1]}
    local start_pm=${data_arr[2]}
    local end_h=${data_arr[3]}
    local end_m=${data_arr[4]}
    local end_pm=${data_arr[5]}
    
    local start_24 end_24
    start_24=$(12hour_to_24hour "${start_h}" "${start_m}" "${start_pm}")
    end_24=$(12hour_to_24hour "${end_h}" "${end_m}" "${end_pm}")
    
    echo "${start_24}-${end_24}"
}

# Normalize range to HH:MM-HH:MM (handles multiple comma-separated ranges)
normalize_time_range() {
    local input="$1"
    local old_ifs="${IFS}"
    local normalized_ranges=()
    
    IFS=','
    for range in ${input}; do
        IFS="${old_ifs}"
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "${range}" ]; then
            local norm
            if norm=$(convert_time_range_to_24hour "${range}"); then
                normalized_ranges+=("${norm}")
            else
                # Fallback for legacy HH-HH
                local start_part="${range%%-*}"
                local end_part="${range##*-}"
                
                local start_norm end_norm
                if [[ "${start_part}" =~ ^[0-9]+$ ]]; then 
                    start_norm=$(printf "%02d:00" "${start_part}")
                elif [[ "${start_part}" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
                    local h=$(echo "${start_part}" | cut -d':' -f1)
                    local m=$(echo "${start_part}" | cut -d':' -f2)
                    start_norm=$(printf "%02d:%02d" "${h}" "${m}")
                else
                    start_norm="${start_part}"
                fi
                
                if [[ "${end_part}" =~ ^[0-9]+$ ]]; then 
                    end_norm=$(printf "%02d:00" "${end_part}")
                elif [[ "${end_part}" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
                    local h=$(echo "${end_part}" | cut -d':' -f1)
                    local m=$(echo "${end_part}" | cut -d':' -f2)
                    end_norm=$(printf "%02d:%02d" "${h}" "${m}")
                else
                    end_norm="${end_part}"
                fi
                
                normalized_ranges+=("${start_norm}-${end_norm}")
            fi
        fi
        IFS=','
    done
    IFS="${old_ifs}"
    
    local result=""
    local first=true
    for r in "${normalized_ranges[@]}"; do
        if [ "${first}" = "true" ]; then
            result="${r}"
            first=false
        else
            result="${result},${r}"
        fi
    done
    echo "${result}"
}
