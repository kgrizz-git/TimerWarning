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

    title="$(dialog_safe_text "${title}")"
    
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
    
    sh=$(kdialog --title "${title}" --combobox "Start Hour:" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" --default "${sh}") || return 1
    sm=$(kdialog --title "${title}" --combobox "Start Minute:" "00" "30" --default "${sm}") || return 1
    sap=$(kdialog --title "${title}" --combobox "Start AM/PM:" "AM" "PM" --default "${sap}") || return 1
    
    eh=$(kdialog --title "${title}" --combobox "End Hour:" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" --default "${eh}") || return 1
    em=$(kdialog --title "${title}" --combobox "End Minute:" "00" "30" --default "${em}") || return 1
    eap=$(kdialog --title "${title}" --combobox "End AM/PM:" "AM" "PM" --default "${eap}") || return 1
    
    echo "${sh}:${sm}${sap}-${eh}:${em}${eap}"
    return 0
}

