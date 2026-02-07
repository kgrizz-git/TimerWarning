#!/bin/bash

###############################################################################
# Sleep Warning System - Popup Settings Input Collection Module
#
# This module provides popup-related user input collection functions for the
# configuration wizard, supporting both GUI (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - get_popup_size_config()        - Get popup size from user
# - get_custom_popup_size_config() - Get custom popup size configuration (helper)
# - get_min_display_time_config()  - Get minimum display time
# - get_popup_immovable_config()   - Get immovable setting
# - get_popup_auto_close_config() - Get auto-close setting (Enhancement #15)
# - get_popup_size_mode_config()  - Get popup size mode (percentage-based / display-based vs fixed)
# - get_popup_position_config()   - Get popup position
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-ui.sh (for confirm_cancel)
# - display-detection.sh (for get_display_resolution - used in custom size validation)
###############################################################################

# Popup size input functions are sourced from a submodule to keep this file smaller.
_CONFIGURE_INPUT_POPUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
if [ -f "${_CONFIGURE_INPUT_POPUP_DIR}/configure-input-popup-size.sh" ]; then
    source "${_CONFIGURE_INPUT_POPUP_DIR}/configure-input-popup-size.sh"
fi
unset _CONFIGURE_INPUT_POPUP_DIR

# Get minimum display time from user
get_min_display_time_config() {
    local use_gui="$1"
    local default_time="30"
    
    # Try to get existing time from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_time
        existing_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_time}" ] && [[ "${existing_time}" =~ ^[0-9]+$ ]]; then
            default_time="${existing_time}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local time
            time=$(show_entry_dialog \
                "Sleep Warning Configuration" \
                "Minimum time popup must be visible before it can be closed:\n\nEnter time in seconds (${MIN_DISPLAY_TIME}-${MAX_DISPLAY_TIME}):\n(${MIN_DISPLAY_TIME} = disabled, 30 = default)" \
                "${default_time}")
            local exit_code=$?
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${time}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            # Validate time
            if ! [[ "${time}" =~ ^[0-9]+$ ]] || [ "${time}" -lt "${MIN_DISPLAY_TIME}" ] || [ "${time}" -gt "${MAX_DISPLAY_TIME}" ]; then
                show_info_dialog \
                    "Invalid Time" \
                    "Invalid time. Please enter a number between ${MIN_DISPLAY_TIME} and ${MAX_DISPLAY_TIME} seconds."
                continue
            fi
            
            # Validate timing configuration (Enhancement #9)
            # Check against current CHECK_INTERVAL
            local current_check_interval
            if [ -f "${CONFIG_FILE}" ]; then
                current_check_interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
            fi
            if [ -z "${current_check_interval}" ] || ! [[ "${current_check_interval}" =~ ^[0-9]+$ ]]; then
                current_check_interval=10  # Default
            fi
            
            if type validate_popup_timing_config >/dev/null 2>&1; then
                local validation_error
                validation_error=$(validate_popup_timing_config "${time}" "${current_check_interval}" 2>&1)
                if [ $? -ne 0 ]; then
                    # Hard error - block user from proceeding
                    show_error_dialog \
                        "Configuration Error" \
                        "${validation_error}"
                    continue  # Re-prompt
                fi
            fi
            
            echo "${time}"
            return 0
        done
    else
        # Text mode
        while true; do
            read -p "Minimum display time in seconds (${MIN_DISPLAY_TIME}-${MAX_DISPLAY_TIME}, ${MIN_DISPLAY_TIME}=disabled) [${default_time}]: " time
            time=${time:-${default_time}}
            
            if [[ "${time}" =~ ^[0-9]+$ ]] && [ "${time}" -ge "${MIN_DISPLAY_TIME}" ] && [ "${time}" -le "${MAX_DISPLAY_TIME}" ]; then
                # Validate timing configuration (Enhancement #9)
                # Check against current CHECK_INTERVAL
                local current_check_interval
                if [ -f "${CONFIG_FILE}" ]; then
                    current_check_interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
                fi
                if [ -z "${current_check_interval}" ] || ! [[ "${current_check_interval}" =~ ^[0-9]+$ ]]; then
                    current_check_interval=10  # Default
                fi
                
                if type validate_popup_timing_config >/dev/null 2>&1; then
                    local validation_error
                    validation_error=$(validate_popup_timing_config "${time}" "${current_check_interval}" 2>&1)
                    if [ $? -ne 0 ]; then
                        # Hard error - block user from proceeding
                        echo "" >&2
                        echo "ERROR: ${validation_error}" >&2
                        echo "" >&2
                        continue  # Re-prompt
                    fi
                fi
                
                echo "${time}"
                return 0
            else
                echo "Invalid time. Please enter a number between ${MIN_DISPLAY_TIME} and ${MAX_DISPLAY_TIME}." >&2
            fi
        done
    fi
}

# Get popup immovable setting from user
get_popup_immovable_config() {
    local use_gui="$1"
    local default_immovable="true"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_immovable
        existing_immovable=$(grep -E "^[[:space:]]*POPUP_IMMOVABLE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_immovable}" ]; then
            if [ "${existing_immovable}" = "true" ] || [ "${existing_immovable}" = "1" ] || [ "${existing_immovable}" = "yes" ]; then
                default_immovable="true"
            elif [ "${existing_immovable}" = "false" ] || [ "${existing_immovable}" = "0" ] || [ "${existing_immovable}" = "no" ]; then
                default_immovable="false"
            fi
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local immovable
            local tmpfile
            tmpfile=$(mktemp)
            
            local immovable_result
            immovable_result=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "Prevent popup window from being moved during minimum display time?\n(Current: ${default_immovable})" \
                600 \
                300 \
                "true" "false")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${immovable_result}" ]; then
                immovable="${immovable_result}"
            else
                immovable=""
            fi
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${immovable}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${immovable}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Immovable Setting:" >&2
        echo "  Prevents the popup window from being moved during minimum display time" >&2
        echo "  by monitoring and restoring its position if moved." >&2
        echo "" >&2
        while true; do
            read -p "Prevent window movement? [y/n, default: ${default_immovable}]: " choice
            choice=${choice:-${default_immovable}}
            case "${choice}" in
                y|Y|yes|YES|true|TRUE|1)
                    echo "true"
                    return 0
                    ;;
                n|N|no|NO|false|FALSE|0)
                    echo "false"
                    return 0
                    ;;
                "")
                    echo "${default_immovable}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                    ;;
            esac
        done
    fi
}

get_popup_auto_close_config() {
    local use_gui="$1"
    local default_auto_close="true"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_auto_close
        existing_auto_close=$(grep -E "^[[:space:]]*POPUP_AUTO_CLOSE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_auto_close}" ]; then
            if [ "${existing_auto_close}" = "true" ] || [ "${existing_auto_close}" = "1" ] || [ "${existing_auto_close}" = "yes" ]; then
                default_auto_close="true"
            elif [ "${existing_auto_close}" = "false" ] || [ "${existing_auto_close}" = "0" ] || [ "${existing_auto_close}" = "no" ]; then
                default_auto_close="false"
            fi
        fi
    fi
    
    # Get minimum display time for reference
    local min_display_time="0"
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_time
        existing_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_time}" ] && [[ "${existing_time}" =~ ^[0-9]+$ ]] && [ "${existing_time}" -ge "${MIN_DISPLAY_TIME}" ] && [ "${existing_time}" -le "${MAX_DISPLAY_TIME}" ]; then
            min_display_time="${existing_time}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local auto_close
            local message
            if [ "${min_display_time}" -gt 0 ]; then
                message="Automatically close popup window 10 seconds after minimum display time completes?\n\nCurrent minimum display time: ${min_display_time} seconds\nAuto-close will happen after ${min_display_time} + 10 = $((min_display_time + 10)) seconds total\n\n(Current setting: ${default_auto_close})"
            else
                message="Automatically close popup window 10 seconds after it appears?\n\nCurrent minimum display time: 0 seconds (disabled)\nAuto-close will happen after 10 seconds\n\n(Current setting: ${default_auto_close})"
            fi
            
            local auto_close_result
            auto_close_result=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "${message}" \
                600 \
                350 \
                "true" "false")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${auto_close_result}" ]; then
                auto_close="${auto_close_result}"
            else
                auto_close=""
            fi
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${auto_close}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${auto_close}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Auto-Close Setting:" >&2
        echo "  Automatically closes the popup window 10 seconds after minimum display time completes" >&2
        if [ "${min_display_time}" -gt 0 ]; then
            echo "  Current minimum display time: ${min_display_time} seconds" >&2
            echo "  Auto-close will happen after ${min_display_time} + 10 = $((min_display_time + 10)) seconds total" >&2
        else
            echo "  Current minimum display time: 0 seconds (disabled)" >&2
            echo "  Auto-close will happen after 10 seconds" >&2
        fi
        echo "" >&2
        while true; do
            read -p "Enable auto-close? [y/n, default: ${default_auto_close}]: " choice
            choice=${choice:-${default_auto_close}}
            case "${choice}" in
                y|Y|yes|YES|true|TRUE|1)
                    echo "true"
                    return 0
                    ;;
                n|N|no|NO|false|FALSE|0)
                    echo "false"
                    return 0
                    ;;
                "")
                    echo "${default_auto_close}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                    ;;
            esac
        done
    fi
}

get_popup_size_mode_config() {
    local use_gui="$1"
    local default_mode="fixed"
    
    # Try to get existing mode from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_mode
        existing_mode=$(grep -E "^[[:space:]]*POPUP_SIZE_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ "${existing_mode}" = "display-based" ]; then
            default_mode="display-based"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local mode_result
            mode_result=$(show_list_dialog \
                "Sleep Warning Configuration - Size Mode" \
                "Select window size calculation mode:\n\nCurrent: ${default_mode}\n\n- fixed: Use absolute pixel sizes (backward compatible)\n- display-based: Percentage-based sizing (calculates sizes as percentage of screen resolution)\n\nNote: Percentage-based (display-based) mode adapts to different screen sizes automatically." \
                600 \
                350 \
                "fixed (Absolute Pixels)" "display-based (Percentage of Screen)")
            local exit_code=$?
            
            if [ ${exit_code} -ne 0 ] || [ -z "${mode_result}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                else
                    continue
                fi
            fi
            
            # Extract mode from result
            if echo "${mode_result}" | grep -q "fixed"; then
                echo "fixed"
                return 0
            elif echo "${mode_result}" | grep -q "display-based"; then
                echo "display-based"
                return 0
            else
                continue
            fi
        done
    else
        # Text mode
        echo "" >&2
        echo "Window Size Calculation Mode:" >&2
        echo "  Current: ${default_mode}" >&2
        echo "" >&2
        echo "Options:" >&2
        echo "  1) fixed - Use absolute pixel sizes (backward compatible)" >&2
        echo "  2) display-based - Percentage-based sizing (calculates sizes as percentage of screen resolution)" >&2
        echo "" >&2
        echo "Note: Percentage-based (display-based) mode adapts to different screen sizes automatically." >&2
        echo "" >&2
        
        while true; do
            local default_choice
            if [ "${default_mode}" = "fixed" ]; then
                default_choice="1"
            else
                default_choice="2"
            fi
            read -p "Select mode [1-2, default: ${default_choice}]: " choice
            choice=${choice:-${default_choice}}
            case "${choice}" in
                1|fixed)
                    echo "fixed"
                    return 0
                    ;;
                2|display-based)
                    echo "display-based"
                    return 0
                    ;;
                "")
                    echo "${default_mode}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please select 1 or 2." >&2
                    ;;
            esac
        done
    fi
}

get_popup_position_config() {
    local use_gui="$1"
    local default_position="center"
    
    # Try to get existing position from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_position
        existing_position=$(grep -E "^[[:space:]]*POPUP_POSITION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_position}" ]; then
            default_position="${existing_position}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local position
            local tmpfile
            tmpfile=$(mktemp)
            
            local position_result
            position_result=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "Select popup position on screen:\n(Current: ${default_position})" \
                500 \
                300 \
                "center" "top-left")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${position_result}" ]; then
                position="${position_result}"
            else
                position=""
            fi
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${position}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${position}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Position Options:" >&2
        echo "  1) center" >&2
        echo "  2) top-left" >&2
        echo "" >&2
        while true; do
            read -p "Select position [1-2, default: ${default_position}]: " choice
            case "${choice}" in
                1|center) echo "center"; return 0 ;;
                2|top-left) echo "top-left"; return 0 ;;
                "") echo "${default_position}"; return 0 ;;
                *) echo "Invalid choice. Please select 1-2." >&2 ;;
            esac
        done
    fi
}

