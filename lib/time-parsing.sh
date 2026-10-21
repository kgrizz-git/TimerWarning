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
# - parse_time_token_to_24h_hm()   - Parse one time token to 24h hour + minute
# - convert_time_range_to_24hour() - Convert any range to 24h format
# - normalize_time_range()         - Normalize range to HH:MM-HH:MM
# - range_endpoint_to_day_minutes()- Parse HH or HH:MM endpoint to minutes (0-1439)
# - range_is_overnight()           - True when start > end (minute precision)
# - range_overnight_tail_active_for_hour() - Prev-day overnight carry (hour API)
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
    
    if [ "$((10#${hour}))" -ge 12 ]; then
        ampm="pm"
        if [ "$((10#${hour}))" -gt 12 ]; then
            h12=$((10#${hour} - 12))
        fi
    fi

    if [ "$((10#${h12}))" -eq 0 ]; then
        h12=12
    fi

    printf "%d:%02d%s" "$((10#${h12}))" "$((10#${minute}))" "${ampm}"
}

# Split "hour minute" output from parse_time_token_to_24h_hm (IFS-safe; use instead of read).
# Outputs: hour minute on stdout. Returns 1 if parts are empty or non-numeric.
_split_24h_hm_parts() {
    local parts="$1"
    local h m

    if [[ "${parts}" == *" "* ]]; then
        h="${parts%% *}"
        m="${parts#* }"
    else
        h="${parts}"
        m=0
    fi

    if ! [[ "${h}" =~ ^[0-9]+$ ]] || ! [[ "${m}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    echo "${h} ${m}"
    return 0
}

# Parse one time token (12h or 24h) into 24-hour hour and minute integers.
# Outputs: hour minute (space-separated). Returns 1 on failure.
parse_time_token_to_24h_hm() {
    local input="$1"
    if [ -z "${input}" ]; then
        return 1
    fi

    local format
    format=$(detect_time_format "${input}")

    if [ "${format}" = "12hour" ]; then
        local data h m is_pm h24
        if ! data=$(parse_single_time "${input}"); then
            return 1
        fi
        h="${data%% *}"
        data="${data#* }"
        m="${data%% *}"
        is_pm="${data##* }"
        h24=$(12hour_to_24hour "${h}" "${m}" "${is_pm}")
        h="${h24%%:*}"
        m="${h24##*:}"
        echo "${h} ${m}"
        return 0
    fi

    local norm h m
    norm=$(normalize_time_input "${input}")
    if [[ "${norm}" =~ : ]]; then
        h="${norm%%:*}"
        m="${norm##*:}"
    else
        h="${norm}"
        m=0
    fi

    if ! [[ "${h}" =~ ^[0-9]+$ ]] || ! [[ "${m}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    echo "${h} ${m}"
    return 0
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
# When input has no am/pm (e.g. "12:00-12:30"), it is 24h: 12 = noon, 0 = midnight.
# Do not pass 24h values through 12hour_to_24hour or 12:00 becomes 00:00.
convert_time_range_to_24hour() {
    local input="$1"
    local norm_input
    norm_input=$(normalize_time_input "${input}")
    local format
    format=$(detect_time_format "${norm_input}")
    
    if [ "${format}" = "24hour" ]; then
        # Already 24h (no am/pm): parse and format as HH:MM-HH:MM
        local start_str="${norm_input%%-*}"
        local end_str="${norm_input##*-}"
        local start_h start_m end_h end_m
        if [[ "${start_str}" =~ : ]]; then
            start_h=$(echo "${start_str}" | cut -d':' -f1)
            start_m=$(echo "${start_str}" | cut -d':' -f2)
        else
            start_h="${start_str}"
            start_m=0
        fi
        if [[ "${end_str}" =~ : ]]; then
            end_h=$(echo "${end_str}" | cut -d':' -f1)
            end_m=$(echo "${end_str}" | cut -d':' -f2)
        else
            end_h="${end_str}"
            end_m=0
        fi
        # Ensure numeric and within valid bounds (use 10# to avoid octal trap)
        if ! [[ "${start_h}" =~ ^[0-9]+$ ]] || ! [[ "${start_m}" =~ ^[0-9]+$ ]] ||
           ! [[ "${end_h}" =~ ^[0-9]+$ ]]   || ! [[ "${end_m}" =~ ^[0-9]+$ ]]; then
            return 1
        fi
        if [ "$(( 10#${start_h} ))" -gt 23 ] || [ "$(( 10#${start_m} ))" -gt 59 ] || \
           [ "$(( 10#${end_h} ))"   -gt 23 ] || [ "$(( 10#${end_m} ))"   -gt 59 ]; then
            return 1  # Reject hours > 23 or minutes > 59
        fi
        # 10# so a leading zero (08) is not read as an octal printf argument.
        printf "%02d:%02d-%02d:%02d" \
            "$((10#${start_h}))" "$((10#${start_m}))" \
            "$((10#${end_h}))" "$((10#${end_m}))"
        return 0
    fi
    
    # 12-hour format: parse and convert via 12hour_to_24hour
    local range_data
    if ! range_data=$(parse_time_range "${input}"); then
        return 1
    fi
    
    local old_ifs="${IFS-}"
    IFS=' '
    local data_arr=(${range_data})
    IFS="${old_ifs-$' \t\n'}"
    
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
    local old_ifs="${IFS-}"
    local normalized_ranges=()
    
    IFS=','
    for range in ${input}; do
        IFS="${old_ifs-$' \t\n'}"
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
                    start_norm=$(printf "%02d:00" "$((10#${start_part}))")
                elif start_norm=$(parse_time_token_to_24h_hm "${start_part}"); then
                    local sh sm _hm
                    if _hm=$(_split_24h_hm_parts "${start_norm}"); then
                        sh="${_hm%% *}"
                        sm="${_hm#* }"
                        start_norm=$(printf "%02d:%02d" "$((10#${sh}))" "$((10#${sm}))")
                    else
                        start_norm="${start_part}"
                    fi
                elif [[ "${start_part}" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
                    local h m
                    h=$(echo "${start_part}" | cut -d':' -f1)
                    m=$(echo "${start_part}" | cut -d':' -f2)
                    start_norm=$(printf "%02d:%02d" "$((10#${h}))" "$((10#${m}))")
                else
                    start_norm="${start_part}"
                fi

                if [[ "${end_part}" =~ ^[0-9]+$ ]]; then
                    end_norm=$(printf "%02d:00" "$((10#${end_part}))")
                elif end_norm=$(parse_time_token_to_24h_hm "${end_part}"); then
                    local eh em _hm
                    if _hm=$(_split_24h_hm_parts "${end_norm}"); then
                        eh="${_hm%% *}"
                        em="${_hm#* }"
                        end_norm=$(printf "%02d:%02d" "$((10#${eh}))" "$((10#${em}))")
                    else
                        end_norm="${end_part}"
                    fi
                elif [[ "${end_part}" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
                    local h m
                    h=$(echo "${end_part}" | cut -d':' -f1)
                    m=$(echo "${end_part}" | cut -d':' -f2)
                    end_norm=$(printf "%02d:%02d" "$((10#${h}))" "$((10#${m}))")
                else
                    end_norm="${end_part}"
                fi
                
                normalized_ranges+=("${start_norm}-${end_norm}")
            fi
        fi
        IFS=','
    done
    IFS="${old_ifs-$' \t\n'}"
    
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

# Convert one range endpoint (HH or HH:MM) to minutes from midnight (0-1439).
# Prints minutes on stdout; returns 1 if invalid.
range_endpoint_to_day_minutes() {
    local part="$1"
    local minutes_per_hour="${MINUTES_PER_HOUR:-60}"

    part=$(echo "${part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "${part}" ] && return 1

    if [[ "${part}" =~ : ]]; then
        local h m
        h=$(echo "${part}" | cut -d: -f1)
        m=$(echo "${part}" | cut -d: -f2)
        if ! [[ "${h}" =~ ^[0-9]+$ ]] || ! [[ "${m}" =~ ^[0-9]+$ ]]; then
            return 1
        fi
        h=$((10#${h}))
        m=$((10#${m}))
        if [ "${h}" -lt 0 ] || [ "${h}" -gt 23 ] || [ "${m}" -lt 0 ] || [ "${m}" -gt 59 ]; then
            return 1
        fi
        echo $((h * minutes_per_hour + m))
        return 0
    fi

    if ! [[ "${part}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    local h=$((10#${part}))
    if [ "${h}" -lt 0 ] || [ "${h}" -gt 23 ]; then
        return 1
    fi
    echo $((h * minutes_per_hour))
    return 0
}

# True when range crosses midnight (start minute > end minute).
range_is_overnight() {
    local start_part="$1"
    local end_part="$2"
    local start_m end_m

    start_m=$(range_endpoint_to_day_minutes "${start_part}") || return 1
    end_m=$(range_endpoint_to_day_minutes "${end_part}") || return 1
    [ "${start_m}" -gt "${end_m}" ]
}

# For hour-granular callers: true if current hour overlaps the morning tail of an
# overnight range from the previous day (e.g. Monday 23:00-05:30, now Tuesday 03:xx).
range_overnight_tail_active_for_hour() {
    local current_hour="$1"
    local start_part="$2"
    local end_part="$3"
    local start_m end_m hour_start

    range_is_overnight "${start_part}" "${end_part}" || return 1
    end_m=$(range_endpoint_to_day_minutes "${end_part}") || return 1
    hour_start=$((10#${current_hour} * 60))
    [ "${hour_start}" -lt "${end_m}" ]
}
