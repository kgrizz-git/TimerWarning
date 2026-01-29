#!/bin/bash

###############################################################################
# Sleep Warning System - Configure Dialogs Module
#
# This module provides tool-agnostic dialog functions that work with
# YAD, Zenity, or KDialog automatically based on what's available.
#
# Dependencies:
#   - configure-core.sh (for get_dialog_tool)
#   - desktop-environment.sh (for check_dialog_tool and detect_display_environment)
#
# Functions:
#   - show_info_dialog()      - Information message
#   - show_question_dialog()  - Yes/No question
#   - show_entry_dialog()     - Text input
#   - show_list_dialog()      - Selection from list
#   - show_text_info_dialog() - Display text file/content
#
# Usage: Source this file after configure-core.sh and desktop-environment.sh
#   source lib/configure-core.sh
#   source lib/desktop-environment.sh
#   source lib/configure-dialogs.sh
###############################################################################

# Show information dialog
show_info_dialog() {
    local title="$1"
    local text="$2"
    local width="${3:-500}"
    local height="${4:-200}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            # Use --fixed to enforce dimensions (prevents YAD from auto-resizing based on text)
            yad --info --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --fixed \
                --button="OK:0" 2>/dev/null
            ;;
        zenity)
            zenity --info --title="${title}" --text="${text}" \
                --width="${width}" 2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" --msgbox "${text}" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Show error dialog
show_error_dialog() {
    local title="$1"
    local text="$2"
    local width="${3:-600}"
    local height="${4:-300}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            # Use --fixed to enforce dimensions (prevents YAD from auto-resizing based on text)
            yad --error --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --fixed \
                --button="OK:0" 2>/dev/null
            ;;
        zenity)
            zenity --error --title="${title}" --text="${text}" \
                --width="${width}" 2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" --error "${text}" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Parse normalized time (HH:MM) to 12-hour format components
# Returns: hour minute ampm (e.g., "11 30 PM")
parse_normalized_time_to_12h() {
    local normalized_time="$1"  # Format: HH:MM (24-hour)
    
    if [ -z "${normalized_time}" ]; then
        echo "11 00 PM"
        return 0
    fi
    
    local hour minute
    if [[ "${normalized_time}" =~ : ]]; then
        hour=$(echo "${normalized_time}" | cut -d':' -f1)
        minute=$(echo "${normalized_time}" | cut -d':' -f2)
    else
        hour="${normalized_time}"
        minute=0
    fi
    
    # Remove leading zeros for hour comparison
    hour=$((10#${hour}))
    minute=$((10#${minute}))
    
    # Convert to 12-hour format
    local h12="${hour}"
    local ampm="AM"
    
    if [ "${hour}" -ge 12 ]; then
        ampm="PM"
        if [ "${hour}" -gt 12 ]; then
            h12=$((hour - 12))
        fi
    fi
    
    if [ "${h12}" -eq 0 ]; then
        h12=12
    fi
    
    printf "%d %02d %s" "${h12}" "${minute}" "${ampm}"
}

# Show time selection dialog with spinboxes/comboboxes
# Parameters:
#   $1: title
#   $2: start_time (optional, format: HH:MM or empty for defaults)
#   $3: end_time (optional, format: HH:MM or empty for defaults)
# Returns normalized time range string (HH:MM-HH:MM)
show_time_selection_dialog() {
    local title="$1"
    local start_time="$2"
    local end_time="$3"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            show_time_selection_dialog_yad "${title}" "${start_time}" "${end_time}"
            ;;
        zenity)
            show_time_selection_dialog_zenity "${title}" "${start_time}" "${end_time}"
            ;;
        kdialog)
            show_time_selection_dialog_kdialog "${title}" "${start_time}" "${end_time}"
            ;;
        *)
            # Fallback to entry dialog if no advanced tool
            show_entry_dialog "${title}" "Enter time range (e.g., 11:30pm-5:30am):" "${start_time}-${end_time}"
            ;;
    esac
}

# YAD implementation of time selection dialog
show_time_selection_dialog_yad() {
    local title="$1"
    local start_time="${2:-}"
    local end_time="${3:-}"
    
    # Parse pre-filled values or use defaults
    local start_data end_data
    if [ -n "${start_time}" ]; then
        start_data=$(parse_normalized_time_to_12h "${start_time}")
    else
        start_data="11 00 PM"
    fi
    
    if [ -n "${end_time}" ]; then
        end_data=$(parse_normalized_time_to_12h "${end_time}")
    else
        end_data="5 00 AM"
    fi
    
    # Extract components
    local sh sm sap eh em eap
    sh=$(echo "${start_data}" | cut -d' ' -f1)
    sm=$(echo "${start_data}" | cut -d' ' -f2)
    sap=$(echo "${start_data}" | cut -d' ' -f3)
    eh=$(echo "${end_data}" | cut -d' ' -f1)
    em=$(echo "${end_data}" | cut -d' ' -f2)
    eap=$(echo "${end_data}" | cut -d' ' -f3)
    
    local output
    output=$(yad --form --title="${title}" \
        --separator="|" \
        --field="Start Time:":LBL "" \
        --field="Hour:NUM" "${sh}!1..12!1!0" \
        --field="Minute:CB" "^${sm}!00!30" \
        --field="AM/PM:CB" "^${sap}!AM!PM" \
        --field="End Time:":LBL "" \
        --field="Hour:NUM" "${eh}!1..12!1!0" \
        --field="Minute:CB" "^${em}!00!30" \
        --field="AM/PM:CB" "^${eap}!AM!PM" \
        2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "${output}" ]; then
        return 1
    fi
    
    # Parse output: |sh|sm|sap||eh|em|eap|
    # Note: LBL fields also produce a separator
    local start_h start_m start_ap end_h end_m end_ap
    start_h=$(echo "${output}" | cut -d'|' -f2)
    start_m=$(echo "${output}" | cut -d'|' -f3)
    start_ap=$(echo "${output}" | cut -d'|' -f4)
    end_h=$(echo "${output}" | cut -d'|' -f6)
    end_m=$(echo "${output}" | cut -d'|' -f7)
    end_ap=$(echo "${output}" | cut -d'|' -f8)
    
    echo "${start_h}:${start_m}${start_ap}-${end_h}:${end_m}${end_ap}"
    return 0
}

# Zenity implementation of time selection dialog
show_time_selection_dialog_zenity() {
    local title="$1"
    local start_time="${2:-}"
    local end_time="${3:-}"
    
    # Parse pre-filled values or use defaults
    local start_data end_data
    if [ -n "${start_time}" ]; then
        start_data=$(parse_normalized_time_to_12h "${start_time}")
    else
        start_data="11 00 PM"
    fi
    
    if [ -n "${end_time}" ]; then
        end_data=$(parse_normalized_time_to_12h "${end_time}")
    else
        end_data="5 00 AM"
    fi
    
    # Extract components
    local sh sm sap eh em eap
    sh=$(echo "${start_data}" | cut -d' ' -f1)
    sm=$(echo "${start_data}" | cut -d' ' -f2)
    sap=$(echo "${start_data}" | cut -d' ' -f3)
    eh=$(echo "${end_data}" | cut -d' ' -f1)
    em=$(echo "${end_data}" | cut -d' ' -f2)
    eap=$(echo "${end_data}" | cut -d' ' -f3)
    
    local output
    output=$(zenity --forms --title="${title}" \
        --text="Configure time range:" \
        --add-entry="Start Hour (1-12)" --entry-text="${sh}" \
        --add-combo="Start Minute" --combo-values="00|30" --set "${sm}" \
        --add-combo="Start AM/PM" --combo-values="AM|PM" --set "${sap}" \
        --add-entry="End Hour (1-12)" --entry-text="${eh}" \
        --add-combo="End Minute" --combo-values="00|30" --set "${em}" \
        --add-combo="End AM/PM" --combo-values="AM|PM" --set "${eap}" \
        2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "${output}" ]; then
        return 1
    fi
    
    local start_h start_m start_ap end_h end_m end_ap
    start_h=$(echo "${output}" | cut -d'|' -f1)
    start_m=$(echo "${output}" | cut -d'|' -f2)
    start_ap=$(echo "${output}" | cut -d'|' -f3)
    end_h=$(echo "${output}" | cut -d'|' -f4)
    end_m=$(echo "${output}" | cut -d'|' -f5)
    end_ap=$(echo "${output}" | cut -d'|' -f6)
    
    # Basic validation for zenity text entries
    if ! [[ "${start_h}" =~ ^[0-9]+$ ]] || [ "${start_h}" -lt 1 ] || [ "${start_h}" -gt 12 ] || \
       ! [[ "${end_h}" =~ ^[0-9]+$ ]] || [ "${end_h}" -lt 1 ] || [ "${end_h}" -gt 12 ]; then
        show_error_dialog "Invalid Input" "Hours must be between 1 and 12."
        return 1
    fi
    
    echo "${start_h}:${start_m}${start_ap}-${end_h}:${end_m}${end_ap}"
    return 0
}

# KDialog implementation of time selection dialog
show_time_selection_dialog_kdialog() {
    local title="$1"
    local start_time="${2:-}"
    local end_time="${3:-}"
    
    # Parse pre-filled values or use defaults
    local start_data end_data
    if [ -n "${start_time}" ]; then
        start_data=$(parse_normalized_time_to_12h "${start_time}")
    else
        start_data="11 00 PM"
    fi
    
    if [ -n "${end_time}" ]; then
        end_data=$(parse_normalized_time_to_12h "${end_time}")
    else
        end_data="5 00 AM"
    fi
    
    # Extract components
    local sh sm sap eh em eap
    sh=$(echo "${start_data}" | cut -d' ' -f1)
    sm=$(echo "${start_data}" | cut -d' ' -f2)
    sap=$(echo "${start_data}" | cut -d' ' -f3)
    eh=$(echo "${end_data}" | cut -d' ' -f1)
    em=$(echo "${end_data}" | cut -d' ' -f2)
    eap=$(echo "${end_data}" | cut -d' ' -f3)
    
    sh=$(kdialog --title "${title}" --combobox "Start Hour:" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" --default "${sh}") || return 1
    sm=$(kdialog --title "${title}" --combobox "Start Minute:" "00" "30" --default "${sm}") || return 1
    sap=$(kdialog --title "${title}" --combobox "Start AM/PM:" "AM" "PM" --default "${sap}") || return 1
    
    eh=$(kdialog --title "${title}" --combobox "End Hour:" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" --default "${eh}") || return 1
    em=$(kdialog --title "${title}" --combobox "End Minute:" "00" "30" --default "${em}") || return 1
    eap=$(kdialog --title "${title}" --combobox "End AM/PM:" "AM" "PM" --default "${eap}") || return 1
    
    echo "${sh}:${sm}${sap}-${eh}:${em}${eap}"
    return 0
}

# Show yes/no question dialog
show_question_dialog() {
    local title="$1"
    local text="$2"
    local ok_label="${3:-Yes}"
    local cancel_label="${4:-No}"
    local width="${5:-600}"
    local height="${6:-400}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            # Use --fixed to enforce dimensions (prevents YAD from auto-resizing based on text)
            yad --question --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --fixed \
                --button="${ok_label}:0" --button="${cancel_label}:1" \
                2>/dev/null
            ;;
        zenity)
            zenity --question --title="${title}" --text="${text}" \
                --width="${width}" \
                --ok-label="${ok_label}" --cancel-label="${cancel_label}" \
                2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" --yesno "${text}" \
                --yes-label "${ok_label}" --no-label "${cancel_label}" \
                2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Show text entry dialog
# Optional 4th parameter: extra_button_label (for Help button support)
# Returns: entry text on success, "EXTRA_BUTTON:<label>" if extra button clicked, empty on cancel
show_entry_dialog() {
    local title="$1"
    local text="$2"
    local default_value="${3:-}"
    local extra_button="${4:-}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            if [ -n "${extra_button}" ]; then
                # YAD supports --extra-button
                local result
                result=$(yad --entry --title="${title}" --text="${text}" \
                    --entry-text="${default_value}" \
                    --extra-button="${extra_button}" \
                    --button="OK:0" --button="Cancel:1" \
                    2>/dev/null)
                local exit_code=$?
                # YAD returns button label on extra button click
                if [ ${exit_code} -eq 1 ] && [ "${result}" = "${extra_button}" ]; then
                    echo "EXTRA_BUTTON:${extra_button}"
                    return 1
                elif [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
                    # YAD may append button text, extract just the entry value
                    echo "${result%%|*}"
                    return 0
                else
                    return 1
                fi
            else
                local result
                result=$(yad --entry --title="${title}" --text="${text}" \
                    --entry-text="${default_value}" \
                    --button="OK:0" --button="Cancel:1" \
                    2>/dev/null)
                local exit_code=$?
                if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
                    # YAD may append button text, extract just the entry value
                    echo "${result%%|*}"
                fi
                return ${exit_code}
            fi
            ;;
        zenity)
            if [ -n "${extra_button}" ]; then
                # Zenity supports --extra-button
                local tmpfile
                tmpfile=$(mktemp)
                zenity --entry --title="${title}" --text="${text}" \
                    --entry-text="${default_value}" \
                    --extra-button="${extra_button}" \
                    > "${tmpfile}" 2>/dev/null
                local exit_code=$?
                local result=$(cat "${tmpfile}" 2>/dev/null)
                rm -f "${tmpfile}"
                # Zenity returns button label in result on extra button click
                if [ ${exit_code} -eq 1 ] && [ "${result}" = "${extra_button}" ]; then
                    echo "EXTRA_BUTTON:${extra_button}"
                    return 1
                elif [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
                    echo "${result}"
                    return 0
                else
                    return 1
                fi
            else
                zenity --entry --title="${title}" --text="${text}" \
                    --entry-text="${default_value}" 2>/dev/null
            fi
            ;;
        kdialog)
            # KDialog doesn't support extra buttons, so ignore extra_button parameter
            kdialog --title "${title}" --inputbox "${text}" "${default_value}" \
                2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Show list selection dialog
show_list_dialog() {
    local title="$1"
    local text="$2"
    local width="${3:-500}"
    local height="${4:-350}"
    shift 4
    local items=("$@")
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            # YAD uses --list with column format
            # Use --fixed to enforce dimensions (prevents YAD from auto-resizing based on text)
            # Convert items array to column format
            local yad_args=()
            for item in "${items[@]}"; do
                yad_args+=("${item}")
            done
            local result
            result=$(yad --list --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --fixed \
                --column="Option" "${yad_args[@]}" \
                --print-column=1 \
                --separator="" \
                2>/dev/null)
            local exit_code=$?
            # YAD may still return pipe-separated values, extract first part
            if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
                echo "${result%%|*}"
            else
                echo "${result}"
            fi
            return ${exit_code}
            ;;
        zenity)
            # Zenity expects: --column="Name" item1 item2 item3
            zenity --list --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --column="Option" "${items[@]}" 2>/dev/null
            ;;
        kdialog)
            # KDialog uses --menu format: tag1 "item1" tag2 "item2"
            # kdialog doesn't support size parameters - always auto-sizes
            local kdialog_args=()
            local tag=1
            for item in "${items[@]}"; do
                kdialog_args+=("${tag}" "${item}")
                ((tag++))
            done
            local result
            result=$(kdialog --title "${title}" --menu "${text}" \
                "${kdialog_args[@]}" 2>/dev/null)
            # Convert tag back to item
            if [ -n "${result}" ]; then
                echo "${items[$((result - 1))]}"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Show text information dialog (for help, summaries, etc.)
show_text_info_dialog() {
    local title="$1"
    local text="$2"
    local width="${3:-600}"
    local height="${4:-500}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            # Use --fixed to enforce dimensions (prevents YAD from auto-resizing based on text)
            echo "${text}" | yad --text-info --title="${title}" \
                --width="${width}" --height="${height}" \
                --fixed \
                --button="Close:0" 2>/dev/null
            ;;
        zenity)
            echo "${text}" | zenity --text-info --title="${title}" \
                --width="${width}" --height="${height}" \
                --font="monospace" 2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" --textbox /dev/stdin \
                "${width}" "${height}" <<< "${text}" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Show multi-column list selection dialog
# Parameters:
#   $1: title
#   $2: text/prompt
#   $3: width
#   $4: height
#   $5: print_column (which column to return, 1-based, default: 1)
#   $6: column1_name
#   $7: column2_name
#   ... (additional column names)
#   Then: alternating column values (col1_row1, col2_row1, col1_row2, col2_row2, ...)
# Returns: value from the specified print_column of selected row, or empty on cancel
show_multi_column_list_dialog() {
    local title="$1"
    local text="$2"
    local width="$3"
    local height="$4"
    local print_column="${5:-1}"
    shift 5
    
    # Extract column names (until we hit data)
    local column_names=()
    local num_columns=0
    local data_start=0
    
    # Count columns by finding where data starts (first non-option-looking argument)
    # Column names are the arguments before data starts
    # Support 1, 2, 3, or 4 columns
    # Improved detection: Column names are typically short labels (single words or short phrases)
    # Data typically contains numbers, parentheses, colons, slashes, or is longer descriptive text
    # Strategy: Column names are usually single words (no spaces) or very short (<=10 chars with spaces)
    #           Data items are longer, contain numbers/special chars, or are descriptive phrases
    
    # Helper function to check if argument looks like a column name
    is_likely_column_name() {
        local arg="$1"
        # Single letter is always a column name
        [[ "${arg}" =~ ^[A-Za-z]$ ]] && return 0
        # Single word (no spaces) and reasonable length (<=12 chars) - likely column name
        [[ ! "${arg}" =~ \  ]] && [[ "${arg}" =~ ^[A-Za-z]+$ ]] && [ ${#arg} -le 12 ] && return 0
        # Short phrase (letters/spaces only, reasonable length) - likely column name
        # This must allow multi-word headers like "Restricted Hours" / "Config Lock Hours".
        [[ "${arg}" =~ ^[A-Za-z][A-Za-z\ ]*[A-Za-z]$ ]] && [ ${#arg} -le 40 ] && return 0
        # Otherwise, likely data
        return 1
    }
    
    if [ $# -ge 4 ]; then
        # Check if 4th argument looks like a column name (not data)
        local fourth_arg="$4"
        if is_likely_column_name "${fourth_arg}"; then
            # Likely a column name - assume 4 columns
            column_names=("$1" "$2" "$3" "$4")
            num_columns=4
            shift 4
        elif [ $# -ge 3 ]; then
            # Check if 3rd argument looks like a column name (not data)
            local third_arg="$3"
            if is_likely_column_name "${third_arg}"; then
                # Likely a column name - assume 3 columns
                column_names=("$1" "$2" "$3")
                num_columns=3
                shift 3
            else
                # Contains numbers, special chars, or too long - likely data - assume 2 columns
                column_names=("$1" "$2")
                num_columns=2
                shift 2
            fi
        else
            # Likely data - assume 2 columns
            column_names=("$1" "$2")
            num_columns=2
            shift 2
        fi
    elif [ $# -ge 3 ]; then
        # Check if 3rd argument looks like a column name (not data)
        local third_arg="$3"
        if is_likely_column_name "${third_arg}"; then
            # Likely a column name - assume 3 columns
            column_names=("$1" "$2" "$3")
            num_columns=3
            shift 3
        else
            # Contains numbers, special chars, or too long - likely data - assume 2 columns
            column_names=("$1" "$2")
            num_columns=2
            shift 2
        fi
    elif [ $# -ge 2 ]; then
        column_names=("$1" "$2")
        num_columns=2
        shift 2
    else
        # Fallback: assume single column if only one name provided
        column_names=("$1")
        num_columns=1
        shift 1
    fi
    
    # Remaining arguments are data (alternating: col1_row1, col2_row1, col1_row2, col2_row2, ...)
    local data=("$@")
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            # YAD uses same format as Zenity: --column flags + flat data array
            # YAD uses pipe (|) as default separator, so we need to handle it
            # Use --fixed to enforce dimensions (prevents YAD from auto-resizing based on text)
            local yad_args=("--list" "--title=${title}" "--text=${text}" \
                "--width=${width}" "--height=${height}" \
                "--fixed" \
                "--print-column=${print_column}" \
                "--separator=")
            
            # Add column definitions
            for col_name in "${column_names[@]}"; do
                yad_args+=("--column=${col_name}")
            done
            
            # Add data (already in correct alternating format)
            yad_args+=("${data[@]}")
            
            local result
            result=$(yad "${yad_args[@]}" 2>/dev/null)
            local exit_code=$?
            
            # YAD may still return pipe-separated values even with --separator=""
            # Extract just the first column if multiple columns are returned
            if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
                # If result contains pipe, take only the part before the first pipe
                echo "${result%%|*}"
            else
                echo "${result}"
            fi
            return ${exit_code}
            ;;
        zenity)
            # Zenity uses same format: --column flags + flat data array
            local zenity_args=("--list" "--title=${title}" "--text=${text}" \
                "--width=${width}" "--height=${height}" \
                "--print-column=${print_column}")
            
            # Add column definitions
            for col_name in "${column_names[@]}"; do
                zenity_args+=("--column=${col_name}")
            done
            
            # Add data (already in correct alternating format)
            zenity_args+=("${data[@]}")
            
            zenity "${zenity_args[@]}" 2>/dev/null
            ;;
        kdialog)
            # KDialog uses --menu with tag/item pairs
            # For multi-column: use first column as tag, concatenate others as description
            # Include column headers in the text parameter since kdialog --menu doesn't support column headers
            local header_text="${text}"
            if [ ${num_columns} -gt 1 ]; then
                # Build column header line
                local header_line=""
                for col_idx in $(seq 0 $((num_columns - 1))); do
                    if [ ${col_idx} -gt 0 ]; then
                        header_line="${header_line} | "
                    fi
                    header_line="${header_line}${column_names[${col_idx}]}"
                done
                # Append header line to text (use $'\n' for newline in bash)
                header_text="${text}"$'\n\n'"Columns: ${header_line}"
            fi
            local kdialog_args=("--title" "${title}" "--menu" "${header_text}")
            local i=0
            local num_data=${#data[@]}
            
            # Process data in chunks of num_columns
            while [ $i -lt $num_data ]; do
                local tag="${data[$i]}"
                local desc=""
                
                # Build description from all columns in this row (including Day column)
                # Format: "Day | value | value | value" (column headers are shown in text parameter above)
                if [ ${num_columns} -gt 1 ]; then
                    local col_idx=0
                    while [ ${col_idx} -lt ${num_columns} ] && [ $((i + col_idx)) -lt ${num_data} ]; do
                        if [ ${col_idx} -gt 0 ]; then
                            desc="${desc} | "
                        fi
                        desc="${desc}${data[$((i + col_idx))]}"
                        col_idx=$((col_idx + 1))
                    done
                else
                    desc="${tag}"
                fi
                
                kdialog_args+=("${tag}" "${desc}")
                i=$((i + num_columns))
            done
            
            kdialog "${kdialog_args[@]}" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Manage multiple time ranges for a day (Phase 2 - Enhancement #16c)
# Parameters:
#   $1: day_name (e.g., "Monday")
#   $2: existing_ranges (comma-separated normalized ranges, e.g., "00:00-05:00,23:00-05:00" or empty)
# Returns: comma-separated normalized ranges string, or empty string on cancel
manage_ranges_dialog() {
    local day_name="$1"
    local existing_ranges="${2:-}"
    
    # Parse existing ranges into array
    local ranges_array=()
    if [ -n "${existing_ranges}" ]; then
        local old_ifs="${IFS}"
        IFS=','
        for range in ${existing_ranges}; do
            range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "${range}" ]; then
                ranges_array+=("${range}")
            fi
        done
        IFS="${old_ifs}"
    fi
    
    # Main loop: show list and handle actions
    while true; do
        # Build list items for display
        local list_items=()
        local i=0
        for range in "${ranges_array[@]}"; do
            local formatted
            formatted=$(format_range_human "${range}" "${day_name}")
            list_items+=("Range $((i + 1))" "${formatted}")
            i=$((i + 1))
        done
        
        # Build dialog text
        local dialog_text="Time ranges for ${day_name}:"
        if [ ${#ranges_array[@]} -eq 0 ]; then
            dialog_text="${dialog_text}\n\nNo ranges configured yet."
        fi
        
        # Show action selection dialog
        local actions=("Add range" "Edit range" "Remove range" "Done" "Cancel")
        local action
        action=$(show_list_dialog "Manage Time Ranges - ${day_name}" "${dialog_text}" 600 400 "${actions[@]}")
        local action_exit=$?
        
        if [ ${action_exit} -ne 0 ] || [ -z "${action}" ]; then
            # User cancelled - return empty to indicate cancellation
            return 1
        fi
        
        case "${action}" in
            "Add range")
                # Add a new range
                local new_range_input
                new_range_input=$(show_time_selection_dialog "Add Time Range - ${day_name}" "" "")
                local add_exit=$?
                
                if [ ${add_exit} -eq 0 ] && [ -n "${new_range_input}" ]; then
                    # Validate and normalize
                    if ! validate_time_range "${new_range_input}"; then
                        show_error_dialog "Invalid Time Range" "The time range format is invalid. Please enter a valid range (e.g., 11:30pm-5:30am or 23:30-05:30)."
                        continue
                    fi
                    
                    local normalized
                    normalized=$(normalize_time_range "${new_range_input}")
                    
                    if ! validate_time_range "${normalized}"; then
                        show_error_dialog "Invalid Time Range" "The time range could not be normalized. Please try again."
                        continue
                    fi
                    
                    # Add to array
                    ranges_array+=("${normalized}")
                fi
                ;;
                
            "Edit range")
                if [ ${#ranges_array[@]} -eq 0 ]; then
                    show_info_dialog "No Ranges" "There are no ranges to edit. Please add a range first."
                    continue
                fi
                
                # Show range selection dialog
                local range_items=()
                local idx=0
                for range in "${ranges_array[@]}"; do
                    local formatted
                    formatted=$(format_range_human "${range}" "${day_name}")
                    range_items+=("Range $((idx + 1))" "${formatted}")
                    idx=$((idx + 1))
                done
                
                local selected_range_label
                selected_range_label=$(show_multi_column_list_dialog \
                    "Select Range to Edit - ${day_name}" \
                    "Select a range to edit:" \
                    500 300 \
                    1 \
                    "Range" "Time Range" \
                    "${range_items[@]}")
                
                if [ -z "${selected_range_label}" ]; then
                    continue
                fi
                
                # Extract index from "Range N"
                local range_idx
                range_idx=$(echo "${selected_range_label}" | sed 's/Range //')
                range_idx=$((range_idx - 1))
                
                if [ ${range_idx} -ge 0 ] && [ ${range_idx} -lt ${#ranges_array[@]} ]; then
                    local range_to_edit="${ranges_array[${range_idx}]}"
                    
                    # Parse range to extract start and end times
                    local start_part end_part
                    start_part=$(echo "${range_to_edit}" | cut -d'-' -f1)
                    end_part=$(echo "${range_to_edit}" | cut -d'-' -f2)
                    
                    # Edit the range
                    local edited_range_input
                    edited_range_input=$(show_time_selection_dialog "Edit Time Range - ${day_name}" "${start_part}" "${end_part}")
                    local edit_exit=$?
                    
                    if [ ${edit_exit} -eq 0 ] && [ -n "${edited_range_input}" ]; then
                        # Validate and normalize
                        if ! validate_time_range "${edited_range_input}"; then
                            show_error_dialog "Invalid Time Range" "The time range format is invalid. Please enter a valid range."
                            continue
                        fi
                        
                        local normalized
                        normalized=$(normalize_time_range "${edited_range_input}")
                        
                        if ! validate_time_range "${normalized}"; then
                            show_error_dialog "Invalid Time Range" "The time range could not be normalized. Please try again."
                            continue
                        fi
                        
                        # Replace in array
                        ranges_array[${range_idx}]="${normalized}"
                    fi
                fi
                ;;
                
            "Remove range")
                if [ ${#ranges_array[@]} -eq 0 ]; then
                    show_info_dialog "No Ranges" "There are no ranges to remove."
                    continue
                fi
                
                # Show range selection dialog
                local range_items=()
                local idx=0
                for range in "${ranges_array[@]}"; do
                    local formatted
                    formatted=$(format_range_human "${range}" "${day_name}")
                    range_items+=("Range $((idx + 1))" "${formatted}")
                    idx=$((idx + 1))
                done
                
                local selected_range_label
                selected_range_label=$(show_multi_column_list_dialog \
                    "Select Range to Remove - ${day_name}" \
                    "Select a range to remove:" \
                    500 300 \
                    1 \
                    "Range" "Time Range" \
                    "${range_items[@]}")
                
                if [ -z "${selected_range_label}" ]; then
                    continue
                fi
                
                # Extract index from "Range N"
                local range_idx
                range_idx=$(echo "${selected_range_label}" | sed 's/Range //')
                range_idx=$((range_idx - 1))
                
                if [ ${range_idx} -ge 0 ] && [ ${range_idx} -lt ${#ranges_array[@]} ]; then
                    local range_to_remove="${ranges_array[${range_idx}]}"
                    local formatted_remove
                    formatted_remove=$(format_range_human "${range_to_remove}" "${day_name}")
                    
                    # Confirm removal
                    if show_question_dialog "Confirm Removal" "Remove this range?\n\n${formatted_remove}" "Yes, Remove" "Cancel" 500 200; then
                        # Remove from array (create new array without this element)
                        local new_array=()
                        local i=0
                        for r in "${ranges_array[@]}"; do
                            if [ ${i} -ne ${range_idx} ]; then
                                new_array+=("${r}")
                            fi
                            i=$((i + 1))
                        done
                        ranges_array=("${new_array[@]}")
                    fi
                fi
                ;;
                
            "Done")
                # Join ranges and return
                if [ ${#ranges_array[@]} -eq 0 ]; then
                    echo ""
                    return 0
                fi
                
                local result=""
                local first=true
                for r in "${ranges_array[@]}"; do
                    if [ "${first}" = "true" ]; then
                        result="${r}"
                        first=false
                    else
                        result="${result},${r}"
                    fi
                done
                echo "${result}"
                return 0
                ;;
                
            "Cancel")
                # Return empty to indicate cancellation
                return 1
                ;;
        esac
    done
}
