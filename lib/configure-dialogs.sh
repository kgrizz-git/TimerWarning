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
    # For now, assume first 2 arguments are column names (most common case)
    if [ $# -ge 2 ]; then
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
            local kdialog_args=("--title" "${title}" "--menu" "${text}")
            local i=0
            local num_data=${#data[@]}
            
            # Process data in chunks of num_columns
            while [ $i -lt $num_data ]; do
                local tag="${data[$i]}"
                local desc=""
                
                # Build description from remaining columns in this row
                if [ $num_columns -gt 1 ]; then
                    desc="${data[$((i + 1))]}"
                    # Add more columns if they exist (for future extensibility)
                    for j in $(seq 2 $((num_columns - 1))); do
                        if [ $((i + j)) -lt $num_data ]; then
                            desc="${desc} | ${data[$((i + j))]}"
                        fi
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
