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
#   - show_confirm_dialog()   - Yes/No after a list/time dialog (macOS z-order safe)
#   - show_entry_dialog()     - Text input (toolkit dispatch: configure-dialogs-dispatch.sh)
#   - show_list_dialog()      - Selection from list
#   - show_text_info_dialog() - Display text file/content
#
# Usage: Source this file after configure-core.sh and desktop-environment.sh
#   source lib/configure-core.sh
#   source lib/desktop-environment.sh
#   source lib/configure-dialogs.sh
###############################################################################

# Ensure Unicode / locale safety helpers are available.
# These prevent GUI dialog tools (especially yad/zenity) from crashing when the
# process locale is non-UTF-8 (e.g., LANG=C in some systemd environments).
if ! type dialog_safe_text >/dev/null 2>&1; then
    _DIALOGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck disable=SC1090
    if [ -f "${_DIALOGS_DIR}/unicode-dialog-safety.sh" ]; then
        source "${_DIALOGS_DIR}/unicode-dialog-safety.sh"
    fi
    unset _DIALOGS_DIR
fi

# Hard fallback: if helper failed to load for any reason, keep dialogs functional.
if ! type dialog_safe_text >/dev/null 2>&1; then
    dialog_safe_text() { printf '%s' "${1:-}"; }
fi

# Helper: sanitize a list of strings (items/options) for GUI tools.
_dialog_safe_array_items() {
    local out=()
    local v
    for v in "$@"; do
        out+=("$(dialog_safe_text "${v}")")
    done
    printf '%s\n' "${out[@]}"
}

# Show information dialog
show_info_dialog() {
    local title="$1"
    local text="$2"
    local width="${3:-500}"
    local height="${4:-200}"

    title="$(dialog_safe_text "${title}")"
    text="$(dialog_safe_text "${text}")"
    
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

    title="$(dialog_safe_text "${title}")"
    text="$(dialog_safe_text "${text}")"
    
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

## Time-selection dialogs are sourced from a submodule to keep this file smaller.
_CONFIGURE_DIALOGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
if [ -f "${_CONFIGURE_DIALOGS_DIR}/configure-dialogs-time.sh" ]; then
    source "${_CONFIGURE_DIALOGS_DIR}/configure-dialogs-time.sh"
fi
# shellcheck disable=SC1090
if [ -f "${_CONFIGURE_DIALOGS_DIR}/configure-dialogs-dispatch.sh" ]; then
    source "${_CONFIGURE_DIALOGS_DIR}/configure-dialogs-dispatch.sh"
fi
unset _CONFIGURE_DIALOGS_DIR

# Show yes/no question dialog
show_question_dialog() {
    local title="$1"
    local text="$2"
    local ok_label="${3:-Yes}"
    local cancel_label="${4:-No}"
    local width="${5:-600}"
    local height="${6:-400}"

    title="$(dialog_safe_text "${title}")"
    text="$(dialog_safe_text "${text}")"
    ok_label="$(dialog_safe_text "${ok_label}")"
    cancel_label="$(dialog_safe_text "${cancel_label}")"
    
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

# Show a yes/no confirmation dialog that stays in front on macOS.
#
# On macOS 13+, osascript `display alert` (used by show_question_dialog) often
# opens BEHIND the terminal after a `choose from list` or tkinter dialog closes.
# Call this instead of show_question_dialog whenever the user just dismissed a
# list or time picker and must confirm the next action (e.g. remove a range).
#
# Parameters: title, message, yes_label, no_label, [width], [height]
# Returns 0 if user chose yes_label, 1 otherwise.
show_confirm_dialog() {
    show_question_dialog "$@"
}

# Show text entry dialog
# Optional 4th parameter: extra_button_label (for Help button support)
# Returns: entry text on success, "EXTRA_BUTTON:<label>" if extra button clicked, empty on cancel
show_entry_dialog() {
    local title="$1"
    local text="$2"
    local default_value="${3:-}"
    local extra_button="${4:-}"

    title="$(dialog_safe_text "${title}")"
    text="$(dialog_safe_text "${text}")"
    # Default value is displayed to the user; sanitize only for GUI safety.
    default_value="$(dialog_safe_text "${default_value}")"
    extra_button="$(dialog_safe_text "${extra_button}")"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            _show_entry_yad "${title}" "${text}" "${default_value}" "${extra_button}"
            return $?
            ;;
        zenity)
            _show_entry_zenity "${title}" "${text}" "${default_value}" "${extra_button}"
            return $?
            ;;
        kdialog)
            _show_entry_kdialog "${title}" "${text}" "${default_value}"
            return $?
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

    # Must run in this shell (not only inside $(dialog_safe_text) subshells) so
    # LC_ALL / DIALOG_UTF8_CONFIRMED persist for the yad/zenity child process.
    if type dialog_prepare_utf8_locale >/dev/null 2>&1; then
        dialog_prepare_utf8_locale
    fi

    title="$(dialog_safe_text "${title}")"
    text="$(dialog_safe_text "${text}")"
    if [ ${#items[@]} -gt 0 ]; then
        mapfile -t items < <(_dialog_safe_array_items "${items[@]}")
    fi
    
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
            # Inherit LC_ALL from parent-shell prepare above; do not invent C.UTF-8.
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
            local result
            result=$(zenity --list --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --column="Option" "${items[@]}" 2>/dev/null)
            local exit_code=$?
            if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
                # Trim whitespace and newlines
                result=$(echo "${result}" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [ -n "${result}" ]; then
                    echo "${result}"
                fi
            fi
            return ${exit_code}
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
            local exit_code=$?
            # Convert tag back to item
            if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
                # Trim whitespace and newlines from tag
                result=$(echo "${result}" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [ -n "${result}" ] && [[ "${result}" =~ ^[0-9]+$ ]]; then
                    local item_index=$((result - 1))
                    if [ ${item_index} -ge 0 ] && [ ${item_index} -lt ${#items[@]} ]; then
                        echo "${items[${item_index}]}"
                        return 0
                    fi
                fi
                # If we get here, tag conversion failed - treat as cancellation
                return 1
            fi
            return ${exit_code}
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

    title="$(dialog_safe_text "${title}")"
    text="$(dialog_safe_text "${text}")"
    
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
        _dialog_is_likely_column_name "$1"
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

    # Must run in this shell before $(dialog_safe_text) so locale exports stick
    # for the eventual yad/zenity invocation (subshells cannot export upward).
    if type dialog_prepare_utf8_locale >/dev/null 2>&1; then
        dialog_prepare_utf8_locale
    fi

    # Sanitize all user-visible strings for GUI safety under non-UTF locales.
    title="$(dialog_safe_text "${title}")"
    text="$(dialog_safe_text "${text}")"
    local _i
    for _i in "${!column_names[@]}"; do
        column_names[${_i}]="$(dialog_safe_text "${column_names[${_i}]}")"
    done
    for _i in "${!data[@]}"; do
        data[${_i}]="$(dialog_safe_text "${data[${_i}]}")"
    done
    unset _i
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            _show_multi_column_list_yad "${title}" "${text}" "${width}" "${height}" \
                "${print_column}" column_names data
            return $?
            ;;
        zenity)
            _show_multi_column_list_zenity "${title}" "${text}" "${width}" "${height}" \
                "${print_column}" column_names data
            return $?
            ;;
        kdialog)
            _show_multi_column_list_kdialog "${title}" "${text}" "${width}" "${height}" \
                "${print_column}" column_names data
            return $?
            ;;
        *)
            return 1
            ;;
    esac
}


# Range add/edit/delete helpers and manage_ranges_dialog
_CONFIGURE_DIALOGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
if [ -f "${_CONFIGURE_DIALOGS_DIR}/configure-dialogs-ranges.sh" ]; then
    source "${_CONFIGURE_DIALOGS_DIR}/configure-dialogs-ranges.sh"
fi
unset _CONFIGURE_DIALOGS_DIR
