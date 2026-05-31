#!/bin/bash

###############################################################################
# Sleep Warning System - Configure Dialogs (Time Selection) Module
#
# This module contains the time-selection dialog helpers extracted from
# `configure-dialogs.sh` to keep that file smaller and easier to maintain.
#
# IMPORTANT:
# - This module is intended to be sourced by `configure-dialogs.sh`.
# - It relies on `dialog_safe_text`, `get_dialog_tool`, and (at runtime) may call
#   `show_entry_dialog` and `show_error_dialog` which are defined elsewhere.
###############################################################################

# GUI time picker minute quantum (restriction / lock / uninstall lock hours)
readonly TIME_PICKER_MINUTES=(00 15 30 45)

# Snap arbitrary minute (0-59) to nearest 15-min slot for combobox prefill when editing.
# Text-mode configs may use any minute; GUI edit prefill may round (e.g. :17 -> :15).
normalize_minute_for_picker() {
    local m=$((10#${1:-0}))
    if [ "${m}" -lt 0 ] || [ "${m}" -gt 59 ]; then
        echo "00"
        return 0
    fi
    printf "%02d" $(( (m + 7) / 15 * 15 % 60 ))
}

# Build YAD combobox value: ^DEFAULT!opt1!opt2!...
_yad_minute_cb_value() {
    local selected
    selected=$(normalize_minute_for_picker "${1:-0}")
    local out="^${selected}"
    local m
    for m in "${TIME_PICKER_MINUTES[@]}"; do
        out="${out}!${m}"
    done
    echo "${out}"
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
#   $4: day_name (optional) - when set, display "Day: ..." in the dialog so user sees which day is being set
#   $5: hint_text (optional) - e.g. "Press Cancel to skip this day."; when set, shown in the dialog
# Returns normalized time range string (HH:MM-HH:MM)
show_time_selection_dialog() {
    local title="$1"
    local start_time="$2"
    local end_time="$3"
    local day_name="${4:-}"
    local hint_text="${5:-}"

    title="$(dialog_safe_text "${title}")"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            show_time_selection_dialog_yad "${title}" "${start_time}" "${end_time}" "${day_name}" "${hint_text}"
            ;;
        zenity)
            show_time_selection_dialog_zenity "${title}" "${start_time}" "${end_time}" "${day_name}" "${hint_text}"
            ;;
        kdialog)
            show_time_selection_dialog_kdialog "${title}" "${start_time}" "${end_time}" "${day_name}" "${hint_text}"
            ;;
        *)
            # Fallback to entry dialog if no advanced tool
            show_entry_dialog "${title}" "Enter time range (e.g., 11:30pm-5:30am):" "${start_time}-${end_time}"
            ;;
    esac
}

# YAD implementation of time selection dialog
# $5: hint_text (optional) - e.g. "Press Cancel to skip this day."
show_time_selection_dialog_yad() {
    local title="$1"
    local start_time="${2:-}"
    local end_time="${3:-}"
    local day_name="${4:-}"
    local hint_text="${5:-}"

    title="$(dialog_safe_text "${title}")"
    
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
    sm=$(normalize_minute_for_picker "${sm}")
    em=$(normalize_minute_for_picker "${em}")
    
    local yad_fields=()
    local output_offset=0
    if [ -n "${hint_text}" ]; then
        hint_text="$(dialog_safe_text "${hint_text}")"
        yad_fields+=(--field="${hint_text}":LBL "")
        output_offset=$((output_offset + 1))
    fi
    if [ -n "${day_name}" ]; then
        day_name="$(dialog_safe_text "${day_name}")"
        yad_fields+=(--field="Day: ${day_name}":LBL "")
        output_offset=$((output_offset + 1))
    fi
    # Use combobox for hour (1-12) so both increment and decrement are clear; avoids spinbox wrap issues
    yad_fields+=(
        --field="Start Time:":LBL ""
        --field="Hour:CB" "^${sh}!1!2!3!4!5!6!7!8!9!10!11!12"
        --field="Minute:CB" "$(_yad_minute_cb_value "${sm}")"
        --field="AM/PM:CB" "^${sap}!AM!PM"
        --field="End Time:":LBL ""
        --field="Hour:CB" "^${eh}!1!2!3!4!5!6!7!8!9!10!11!12"
        --field="Minute:CB" "$(_yad_minute_cb_value "${em}")"
        --field="AM/PM:CB" "^${eap}!AM!PM"
    )
    
    local output
    output=$(yad --form --title="${title}" --separator="|" "${yad_fields[@]}" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "${output}" ]; then
        return 1
    fi
    
    # Parse output: indices depend on optional leading fields (hint, day)
    local start_h start_m start_ap end_h end_m end_ap
    start_h=$(echo "${output}" | cut -d'|' -f$((2 + output_offset)))
    start_m=$(echo "${output}" | cut -d'|' -f$((3 + output_offset)))
    start_ap=$(echo "${output}" | cut -d'|' -f$((4 + output_offset)))
    end_h=$(echo "${output}" | cut -d'|' -f$((6 + output_offset)))
    end_m=$(echo "${output}" | cut -d'|' -f$((7 + output_offset)))
    end_ap=$(echo "${output}" | cut -d'|' -f$((8 + output_offset)))
    
    # Normalize hour to 1-12 (wrap 13->1, 0->12) in case any tool returns out-of-range
    if [[ "${start_h}" =~ ^[0-9]+$ ]]; then
        [ "${start_h}" -lt 1 ] && start_h=12
        [ "${start_h}" -gt 12 ] && start_h=$(( (start_h - 1) % 12 + 1 ))
    fi
    if [[ "${end_h}" =~ ^[0-9]+$ ]]; then
        [ "${end_h}" -lt 1 ] && end_h=12
        [ "${end_h}" -gt 12 ] && end_h=$(( (end_h - 1) % 12 + 1 ))
    fi
    
    echo "${start_h}:${start_m}${start_ap}-${end_h}:${end_m}${end_ap}"
    return 0
}

# Zenity implementation of time selection dialog
# $5: hint_text (optional) - e.g. "Press Cancel to skip this day."
show_time_selection_dialog_zenity() {
    local title="$1"
    local start_time="${2:-}"
    local end_time="${3:-}"
    local day_name="${4:-}"
    local hint_text="${5:-}"

    title="$(dialog_safe_text "${title}")"
    
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
    sm=$(normalize_minute_for_picker "${sm}")
    em=$(normalize_minute_for_picker "${em}")
    
    local text_prompt="Configure time range:"
    if [ -n "${day_name}" ]; then
        day_name="$(dialog_safe_text "${day_name}")"
        text_prompt="Configure time range for ${day_name}:"
    fi
    if [ -n "${hint_text}" ]; then
        hint_text="$(dialog_safe_text "${hint_text}")"
        text_prompt="${text_prompt}\n\n${hint_text}"
    fi
    local output
    output=$(zenity --forms --title="${title}" \
        --text="${text_prompt}" \
        --add-entry="Start Hour (1-12)" --entry-text="${sh}" \
        --add-combo="Start Minute" --combo-values="00|15|30|45" --set "${sm}" \
        --add-combo="Start AM/PM" --combo-values="AM|PM" --set "${sap}" \
        --add-entry="End Hour (1-12)" --entry-text="${eh}" \
        --add-combo="End Minute" --combo-values="00|15|30|45" --set "${em}" \
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
    
    # Normalize hour to 1-12 (wrap 13->1, 0->12); reject non-numeric
    if ! [[ "${start_h}" =~ ^[0-9]+$ ]] || ! [[ "${end_h}" =~ ^[0-9]+$ ]]; then
        show_error_dialog "Invalid Input" "Hours must be numbers between 1 and 12."
        return 1
    fi
    [ "${start_h}" -lt 1 ] && start_h=12
    [ "${start_h}" -gt 12 ] && start_h=$(( (start_h - 1) % 12 + 1 ))
    [ "${end_h}" -lt 1 ] && end_h=12
    [ "${end_h}" -gt 12 ] && end_h=$(( (end_h - 1) % 12 + 1 ))
    
    echo "${start_h}:${start_m}${start_ap}-${end_h}:${end_m}${end_ap}"
    return 0
}

# KDialog implementation of time selection dialog (title already includes day when passed by caller)
# $5: hint_text (optional) - e.g. "Press Cancel to skip this day."
show_time_selection_dialog_kdialog() {
    local title="$1"
    local start_time="${2:-}"
    local end_time="${3:-}"
    local _day_name="${4:-}"
    local hint_text="${5:-}"

    title="$(dialog_safe_text "${title}")"
    if [ -n "${hint_text}" ]; then
        hint_text="$(dialog_safe_text "${hint_text}")"
        title="${title} — ${hint_text}"
    fi
    
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
    sm=$(normalize_minute_for_picker "${sm}")
    em=$(normalize_minute_for_picker "${em}")
    
    sh=$(kdialog --title "${title}" --combobox "Start Hour:" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" --default "${sh}") || return 1
    sm=$(kdialog --title "${title}" --combobox "Start Minute:" "00" "15" "30" "45" --default "${sm}") || return 1
    sap=$(kdialog --title "${title}" --combobox "Start AM/PM:" "AM" "PM" --default "${sap}") || return 1
    
    eh=$(kdialog --title "${title}" --combobox "End Hour:" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" --default "${eh}") || return 1
    em=$(kdialog --title "${title}" --combobox "End Minute:" "00" "15" "30" "45" --default "${em}") || return 1
    eap=$(kdialog --title "${title}" --combobox "End AM/PM:" "AM" "PM" --default "${eap}") || return 1
    
    echo "${sh}:${sm}${sap}-${eh}:${em}${eap}"
    return 0
}

