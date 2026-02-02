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
# - get_popup_size_mode_config()  - Get popup size mode (display-based vs fixed)
# - get_popup_position_config()   - Get popup position
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-ui.sh (for confirm_cancel)
# - display-detection.sh (for get_display_resolution - used in custom size validation)
###############################################################################

# Get popup size from user
# This is for Enhancement #3 (Enhanced Window Size Options)
get_popup_size_config() {
    local use_gui="$1"
    local default_size="medium"
    
    # Try to get existing size from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_size
        existing_size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_size}" ]; then
            default_size="${existing_size}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local size_result
            size_result=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "Select popup size (current: ${default_size}):" \
                500 \
                400 \
                "xsmall" "small" "medium" "large" "xlarge" "max" "custom")
            local exit_code=$?
            
            # User cancelled
            if [ ${exit_code} -ne 0 ] || [ -z "${size_result}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            # If "custom" selected, get custom size configuration
            if [ "${size_result}" = "custom" ]; then
                local custom_result
                custom_result=$(get_custom_popup_size_config "${use_gui}")
                local custom_exit=$?
                
                if [ ${custom_exit} -eq 2 ]; then
                    # User cancelled custom size configuration
                    if confirm_cancel "${use_gui}"; then
                        echo "CANCELLED"
                        return 2
                    else
                        continue  # Re-prompt for size selection
                    fi
                elif [ ${custom_exit} -eq 0 ] && [ -n "${custom_result}" ]; then
                    # Custom size configured successfully
                    # Return both "custom" and the dimensions, separated by | for parsing
                    # This ensures the dimensions persist even if CUSTOM_POPUP_SIZE_CONFIG doesn't
                    echo "custom|${custom_result}"
                    return 0
                else
                    # Error in custom size configuration, re-prompt
                    continue
                fi
            else
                # Valid predefined size selection
                echo "${size_result}"
                return 0
            fi
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Size Options:" >&2
        echo "  1) xsmall (15%×15% or 384×216)" >&2
        echo "  2) small (20%×20% or 400×250)" >&2
        echo "  3) medium (30%×30% or 800×500)" >&2
        echo "  4) large (50%×50% or 1230×720)" >&2
        echo "  5) xlarge (75%×75% or 1845×1080)" >&2
        echo "  6) max (90%×90% or 2214×1296)" >&2
        echo "  7) custom (user-configurable)" >&2
        echo "" >&2
        while true; do
            read -p "Select size [1-7, default: ${default_size}]: " choice
            case "${choice}" in
                1|xsmall) echo "xsmall"; return 0 ;;
                2|small) echo "small"; return 0 ;;
                3|medium) echo "medium"; return 0 ;;
                4|large) echo "large"; return 0 ;;
                5|xlarge) echo "xlarge"; return 0 ;;
                6|max) echo "max"; return 0 ;;
                7|custom)
                    local custom_result
                    custom_result=$(get_custom_popup_size_config "${use_gui}")
                    local custom_exit=$?
                    
                    if [ ${custom_exit} -eq 2 ]; then
                        # User cancelled, re-prompt
                        continue
                    elif [ ${custom_exit} -eq 0 ] && [ -n "${custom_result}" ]; then
                        # Return both "custom" and the dimensions, separated by | for parsing
                        echo "custom|${custom_result}"
                        return 0
                    else
                        # Error, re-prompt
                        continue
                    fi
                    ;;
                "") echo "${default_size}"; return 0 ;;
                *) echo "Invalid choice. Please select 1-7." >&2 ;;
            esac
        done
    fi
}

# Get custom popup size configuration from user
# This is a helper function for get_popup_size_config()
# Returns: Custom size string (e.g., "50%x50%" or "1280x720") on success, "CANCELLED" on cancellation, empty on error
# Exit code: 0 on success, 2 on cancellation, 1 on error
# This is for Enhancement #3 (Enhanced Window Size Options)
# Note: This function stores the custom size in global variable CUSTOM_POPUP_SIZE_CONFIG for configure.sh to retrieve
get_custom_popup_size_config() {
    local use_gui="$1"
    local size_mode
    local default_custom="50%x50%"
    local default_absolute="1280x720"
    
    # Get current size mode
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_mode
        existing_mode=$(grep -E "^[[:space:]]*POPUP_SIZE_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ "${existing_mode}" = "display-based" ]; then
            size_mode="display-based"
        else
            size_mode="fixed"
        fi
    else
        size_mode="fixed"
    fi
    
    # Get existing custom size if available
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_custom
        existing_custom=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_custom}" ]; then
            default_custom="${existing_custom}"
        fi
        
        local existing_absolute
        existing_absolute=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM_ABSOLUTE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_absolute}" ] && echo "${existing_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
            default_absolute="${existing_absolute}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode - two-step process: first ask format, then ask for dimensions
        while true; do
            # Step 1: Ask format (pixel vs percentage)
            local format_result
            format_result=$(show_list_dialog \
                "Sleep Warning Configuration - Custom Size Format" \
                "Select format for custom size:\n\nCurrent mode: ${size_mode}\n\n- Percentage: Use percentage of screen (e.g., 50%x50%)\n- Pixel: Use absolute pixel dimensions (e.g., 1280x720)" \
                600 \
                350 \
                "Percentage (e.g., 50%x50%)" "Pixel (e.g., 1280x720)")
            local format_exit=$?
            
            if [ ${format_exit} -ne 0 ] || [ -z "${format_result}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                else
                    continue
                fi
            fi
            
            # Step 2: Ask for dimensions
            local dimensions
            local prompt_text
            if echo "${format_result}" | grep -q "Percentage"; then
                prompt_text="Enter custom size as percentage:\n\nFormat: WIDTH%xHEIGHT%\nRange: 15-95% for both dimensions (95% max ensures buttons remain visible)\nExample: 50%x50%\n\nCurrent: ${default_custom}"
                dimensions=$(show_entry_dialog \
                    "Sleep Warning Configuration - Custom Size (Percentage)" \
                    "${prompt_text}" \
                    "${default_custom}")
            else
                prompt_text="Enter custom size as pixels:\n\nFormat: WIDTHxHEIGHT\nMinimum: 384x216 (matches xsmall)\nMaximum: 95% of screen (ensures buttons remain visible)\nExample: 1280x720\n\nCurrent: ${default_absolute}"
                dimensions=$(show_entry_dialog \
                    "Sleep Warning Configuration - Custom Size (Pixel)" \
                    "${prompt_text}" \
                    "${default_absolute}")
            fi
            local dim_exit=$?
            
            if [ ${dim_exit} -ne 0 ] || [ -z "${dimensions}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                else
                    continue
                fi
            fi
            
            # Validate input
            if echo "${format_result}" | grep -q "Percentage"; then
                # Validate percentage format
                if ! echo "${dimensions}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                    show_info_dialog \
                        "Invalid Format" \
                        "Invalid percentage format. Use: WIDTH%xHEIGHT%\n\nExample: 50%x50%"
                    continue
                fi
                
                local width_percent height_percent
                width_percent=$(echo "${dimensions}" | cut -d'x' -f1 | tr -d '%')
                height_percent=$(echo "${dimensions}" | cut -d'x' -f2 | tr -d '%')
                
                # Validate range (15-95%) - 95% maximum ensures buttons remain visible
                if [ "${width_percent}" -lt 15 ] || [ "${width_percent}" -gt 95 ] || \
                   [ "${height_percent}" -lt 15 ] || [ "${height_percent}" -gt 95 ]; then
                    show_info_dialog \
                        "Invalid Range" \
                        "Percentage values must be between 15% and 95%.\n\nMinimum matches xsmall size (15%).\nMaximum is 95% to ensure buttons remain visible."
                    continue
                fi
            else
                # Validate pixel format
                if ! echo "${dimensions}" | grep -qE '^[0-9]+x[0-9]+$'; then
                    show_info_dialog \
                        "Invalid Format" \
                        "Invalid pixel format. Use: WIDTHxHEIGHT\n\nExample: 1280x720"
                    continue
                fi
                
                local width height
                width=$(echo "${dimensions}" | cut -d'x' -f1)
                height=$(echo "${dimensions}" | cut -d'x' -f2)
                
                # Validate minimum (384x216 matches xsmall)
                if [ "${width}" -lt 384 ] || [ "${height}" -lt 216 ]; then
                    show_info_dialog \
                        "Invalid Size" \
                        "Minimum size is 384×216 pixels (matches xsmall size)."
                    continue
                fi
                
                # Validate maximum (95% of screen) - try to detect resolution (95% max ensures buttons remain visible)
                local resolution
                if type get_display_resolution >/dev/null 2>&1; then
                    resolution=$(get_display_resolution 2>/dev/null)
                fi
                
                if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                    local screen_width screen_height
                    screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                    screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                    
                    local max_width max_height
                    max_width=$((screen_width * 95 / 100))
                    max_height=$((screen_height * 95 / 100))
                    if [ "${width}" -gt "${max_width}" ] || [ "${height}" -gt "${max_height}" ]; then
                        show_info_dialog \
                            "Invalid Size" \
                            "Size exceeds 95% of screen resolution (${screen_width}×${screen_height}).\n\nMaximum is 95% of screen to ensure buttons remain visible."
                        continue
                    fi
                fi
            fi
            
            # Valid input - store in global variable and return the dimensions
            declare -g CUSTOM_POPUP_SIZE_CONFIG="${dimensions}"
            echo "${dimensions}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Custom Popup Size Configuration:" >&2
        echo "  Current mode: ${size_mode}" >&2
        echo "" >&2
        echo "Format options:" >&2
        echo "  1) Percentage (e.g., 50%x50%)" >&2
        echo "  2) Pixel (e.g., 1280x720)" >&2
        echo "" >&2
        
        while true; do
            read -p "Select format [1-2]: " format_choice
            case "${format_choice}" in
                1)
                    echo "" >&2
                    echo "Enter custom size as percentage:" >&2
                    echo "  Format: WIDTH%xHEIGHT%" >&2
                    echo "  Range: 15-95% for both dimensions (95% max ensures buttons remain visible)" >&2
                    echo "  Example: 50%x50%" >&2
                    echo "" >&2
                    read -p "Custom size [${default_custom}]: " dimensions
                    dimensions=${dimensions:-${default_custom}}
                    
                    # Validate percentage format
                    if ! echo "${dimensions}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                        echo "Invalid format. Use: WIDTH%xHEIGHT% (e.g., 50%x50%)" >&2
                        continue
                    fi
                    
                    local width_percent height_percent
                    width_percent=$(echo "${dimensions}" | cut -d'x' -f1 | tr -d '%')
                    height_percent=$(echo "${dimensions}" | cut -d'x' -f2 | tr -d '%')
                    
                    # Validate range
                    if [ "${width_percent}" -lt 15 ] || [ "${width_percent}" -gt 100 ] || \
                       [ "${height_percent}" -lt 15 ] || [ "${height_percent}" -gt 100 ]; then
                        echo "Percentage values must be between 15% and 95% (95% max ensures buttons remain visible)." >&2
                        continue
                    fi
                    
                    # Store in global variable and return the dimensions
                    declare -g CUSTOM_POPUP_SIZE_CONFIG="${dimensions}"
                    echo "${dimensions}"
                    return 0
                    ;;
                2)
                    echo "" >&2
                    echo "Enter custom size as pixels:" >&2
                    echo "  Format: WIDTHxHEIGHT" >&2
                    echo "  Minimum: 384x216 (matches xsmall)" >&2
                    echo "  Maximum: 95% of screen (ensures buttons remain visible)" >&2
                    echo "  Example: 1280x720" >&2
                    echo "" >&2
                    read -p "Custom size [${default_absolute}]: " dimensions
                    dimensions=${dimensions:-${default_absolute}}
                    
                    # Validate pixel format
                    if ! echo "${dimensions}" | grep -qE '^[0-9]+x[0-9]+$'; then
                        echo "Invalid format. Use: WIDTHxHEIGHT (e.g., 1280x720)" >&2
                        continue
                    fi
                    
                    local width height
                    width=$(echo "${dimensions}" | cut -d'x' -f1)
                    height=$(echo "${dimensions}" | cut -d'x' -f2)
                    
                    # Validate minimum
                    if [ "${width}" -lt 384 ] || [ "${height}" -lt 216 ]; then
                        echo "Minimum size is 384×216 pixels (matches xsmall size)." >&2
                        continue
                    fi
                    
                    # Validate maximum (if resolution can be detected)
                    local resolution
                    if type get_display_resolution >/dev/null 2>&1; then
                        resolution=$(get_display_resolution 2>/dev/null)
                    fi
                    
                    if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                        local screen_width screen_height
                        screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                        screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                        
                        if [ "${width}" -gt "${screen_width}" ] || [ "${height}" -gt "${screen_height}" ]; then
                            echo "Size exceeds 95% of screen resolution (${screen_width}×${screen_height}). Maximum is 95% of screen to ensure buttons remain visible." >&2
                            continue
                        fi
                    fi
                    
                    # Store in global variable and return the dimensions
                    declare -g CUSTOM_POPUP_SIZE_CONFIG="${dimensions}"
                    echo "${dimensions}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please select 1 or 2." >&2
                    ;;
            esac
        done
    fi
}

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
                "Select window size calculation mode:\n\nCurrent: ${default_mode}\n\n- fixed: Use absolute pixel sizes (backward compatible)\n- display-based: Calculate sizes as percentage of screen resolution\n\nNote: display-based mode adapts to different screen sizes automatically." \
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
        echo "  2) display-based - Calculate sizes as percentage of screen resolution" >&2
        echo "" >&2
        echo "Note: display-based mode adapts to different screen sizes automatically." >&2
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

