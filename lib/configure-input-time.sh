#!/bin/bash

###############################################################################
# Sleep Warning System - Time Range Input Collection Module
#
# This module provides time range input collection functions for the
# configuration wizard, supporting both GUI (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - get_day_hours() - Get time ranges for a day (complex with navigation)
# - get_check_interval() - Get check interval
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-ui.sh (for confirm_cancel, confirm_skip_day, show_help_dialog)
# - configure-time.sh (for format_ranges_human)
# - time-calculations.sh (for calculate_range_duration, calculate_total_day_duration)
###############################################################################

get_check_interval() {
    local use_gui="$1"
    local default_interval="10"
    
    # Try to get existing interval from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_interval
        existing_interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_interval}" ] && [[ "${existing_interval}" =~ ^[0-9]+$ ]]; then
            default_interval="${existing_interval}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local interval
            
            # Get interval using dialog tool
            interval=$(show_entry_dialog \
                "Sleep Warning Configuration" \
                "How often should the system check for restricted hours?\n\nEnter interval in minutes (${MIN_CHECK_INTERVAL}-${MAX_CHECK_INTERVAL}):" \
                "${default_interval}")
            local exit_code=$?
            
            # Check exit code - non-zero means Cancel was clicked
            if [ ${exit_code} -ne 0 ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                else
                    continue
                fi
            fi
            
            # Empty input - use default
            if [ -z "${interval}" ]; then
                echo "${default_interval}"
                return 0
            fi
            
            # Validate interval
            if ! [[ "${interval}" =~ ^[0-9]+$ ]] || [ "${interval}" -lt "${MIN_CHECK_INTERVAL}" ] || [ "${interval}" -gt "${MAX_CHECK_INTERVAL}" ]; then
                show_info_dialog \
                    "Invalid Interval" \
                    "Invalid interval. Please enter a number between ${MIN_CHECK_INTERVAL} and ${MAX_CHECK_INTERVAL} minutes."
                continue
            fi
            
            # Validate timing configuration (Enhancement #9)
            local current_min_display_time
            if [ -f "${CONFIG_FILE}" ]; then
                current_min_display_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
            fi
            if [ -z "${current_min_display_time}" ] || ! [[ "${current_min_display_time}" =~ ^[0-9]+$ ]]; then
                current_min_display_time=30  # Default
            fi
            
            if type validate_popup_timing_config >/dev/null 2>&1; then
                local validation_error
                validation_error=$(validate_popup_timing_config "${current_min_display_time}" "${interval}" 2>&1)
                if [ $? -ne 0 ]; then
                    show_error_dialog "Configuration Error" "${validation_error}"
                    continue
                fi
            fi
            
            echo "${interval}"
            return 0
        done
    else
        # Text mode
        while true; do
            read -p "Check interval in minutes (1-60) [${default_interval}]: " interval
            interval=${interval:-${default_interval}}
            
            if [[ "${interval}" =~ ^[0-9]+$ ]] && [ "${interval}" -ge "${MIN_CHECK_INTERVAL}" ] && [ "${interval}" -le "${MAX_CHECK_INTERVAL}" ]; then
                local current_min_display_time
                if [ -f "${CONFIG_FILE}" ]; then
                    current_min_display_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
                fi
                if [ -z "${current_min_display_time}" ] || ! [[ "${current_min_display_time}" =~ ^[0-9]+$ ]]; then
                    current_min_display_time=30  # Default
                fi
                
                if type validate_popup_timing_config >/dev/null 2>&1; then
                    local validation_error
                    validation_error=$(validate_popup_timing_config "${current_min_display_time}" "${interval}" 2>&1)
                    if [ $? -ne 0 ]; then
                        echo "" >&2
                        echo "ERROR: ${validation_error}" >&2
                        echo "" >&2
                        continue
                    fi
                fi
                
                echo "${interval}"
                return 0
            else
                echo "Invalid interval. Please enter a number between ${MIN_CHECK_INTERVAL} and ${MAX_CHECK_INTERVAL}." >&2
            fi
        done
    fi
}

get_day_hours() {
    local day_name="$1"
    local day_index="$2"
    local use_gui="$3"
    local allow_back="$4"
    local allow_cancel="$5"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local range_input
            range_input=$(show_time_selection_dialog "Sleep Warning Configuration - ${day_name}" "" "")
            local exit_code=$?
            
            if [ ${exit_code} -ne 0 ] || [ -z "${range_input}" ]; then
                local menu_options=("Skip this day")
                [ "${allow_back}" = "true" ] && menu_options+=("Go back to previous day")
                [ "${allow_cancel}" = "true" ] && menu_options+=("Cancel configuration")
                menu_options+=("Continue configuring")
                
                local choice
                choice=$(show_list_dialog "What would you like to do?" "You cancelled or left ${day_name} empty. What would you like to do?" 500 300 "${menu_options[@]}")
                
                case "${choice}" in
                    "Skip this day")
                        if confirm_skip_day "${day_name}" "${use_gui}"; then echo "skip"; return 0; fi
                        continue ;;
                    "Go back to previous day") echo "back"; return 2 ;;
                    "Cancel configuration")
                        if confirm_cancel "${use_gui}"; then echo "CANCELLED"; return 2; fi
                        continue ;;
                    *) continue ;;
                esac
            fi
            
            local normalized
            normalized=$(normalize_time_range "${range_input}")
            local preview
            preview=$(format_ranges_human "${normalized}" "${day_name}")
            
            if show_question_dialog "Confirm Time Range" "You selected: ${range_input}\n\nThis means:\n${preview}\n\nIs this correct?" "Yes" "No, Edit" 600 350; then
                echo "${normalized}"
                return 0
            fi
        done
    else
        # Text mode
        echo "" >&2
        echo "=== Configuring ${day_name} ===" >&2
        echo "Format options: 11:30pm-5:30am or 23:30-05:30" >&2
        
        while true; do
            local range_input
            read -p "Time range(s) for ${day_name} (or 's' to skip): " range_input
            
            case "${range_input}" in
                skip|s|S|"")
                    if confirm_skip_day "${day_name}" "${use_gui}"; then echo "skip"; return 0; fi
                    continue ;;
                back)
                    if [ "${allow_back}" = "true" ]; then echo "back"; return 2; fi
                    echo "Cannot go back." >&2; continue ;;
                cancel)
                    if [ "${allow_cancel}" = "true" ] && confirm_cancel "${use_gui}"; then echo "CANCELLED"; return 2; fi
                    continue ;;
                help) show_help_dialog "${use_gui}"; continue ;;
            esac
            
            if ! validate_time_range "${range_input}"; then
                echo "Error: Invalid format. Examples: 11pm-5am, 23:30-05:30, 0-5,22-23" >&2
                continue
            fi
            
            local normalized
            normalized=$(normalize_time_range "${range_input}")
            local preview
            preview=$(format_ranges_human "${normalized}" "${day_name}")
            
            echo "Preview: ${preview}" >&2
            read -p "Is this correct? [Y/n]: " confirm
            [[ "${confirm:-y}" =~ ^[yY] ]] && { echo "${normalized}"; return 0; }
        done
    fi
}
