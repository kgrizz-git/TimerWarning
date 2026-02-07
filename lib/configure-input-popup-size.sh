#!/bin/bash

###############################################################################
# Sleep Warning System - Popup Size Input Collection Module
#
# This module contains popup-size-related input collection functions extracted
# from `configure-input-popup.sh` to keep that file smaller and easier to
# maintain.
#
# IMPORTANT:
# - This module is intended to be sourced by `configure-input-popup.sh`.
# - It relies on dialog abstraction helpers from `configure-dialogs.sh`,
#   `confirm_cancel()` from `configure-ui.sh`, and may use `get_display_resolution`
#   when available.
# - It must preserve GUI/text flows and validation behavior.
###############################################################################

# Get popup size from user
# This is for Enhancement #3 (Enhanced Window Size Options)
get_popup_size_config() {
    local use_gui="$1"
    local size_mode_override="$2"
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
        # Determine current size mode so we can show percentage mappings
        # when the user is using display-based (percentage-based) sizing.
        local size_mode="fixed"
        if [ -n "${size_mode_override}" ]; then
            size_mode="${size_mode_override}"
        elif [ -f "${CONFIG_FILE}" ]; then
            local existing_mode
            existing_mode=$(grep -E "^[[:space:]]*POPUP_SIZE_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
            if [ "${existing_mode}" = "display-based" ]; then
                size_mode="display-based"
            fi
        fi

        # Build option labels; when in percentage-based (display-based) mode,
        # include the percentages directly in the list items so users can see
        # mappings at a glance in the wizard.
        local xsmall_label="xsmall"
        local small_label="small"
        local medium_label="medium"
        local large_label="large"
        local xlarge_label="xlarge"
        local max_label="max"

        if [ "${size_mode}" = "display-based" ]; then
            # These mappings must remain consistent with Enhancement #3,
            # CONFIGURATION.md, and get_popup_dimensions().
            # Use ASCII 'x' between width/height to avoid any dialog
            # tool / locale issues with the unicode multiplication sign.
            xsmall_label="xsmall (15%x15%)"
            small_label="small (20%x20%)"
            medium_label="medium (30%x30%)"
            large_label="large (50%x50%)"
            xlarge_label="xlarge (75%x75%)"
            max_label="max (90%x90%)"
        fi

        while true; do
            local prompt_text="Select popup size (current: ${default_size}):"

            local size_result
            size_result=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "${prompt_text}" \
                500 \
                400 \
                "${xsmall_label}" "${small_label}" "${medium_label}" "${large_label}" "${xlarge_label}" "${max_label}" "custom")
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
            
            # Normalize selection back to canonical size keys
            case "${size_result}" in
                xsmall* ) size_result="xsmall" ;;
                small*  ) size_result="small" ;;
                medium* ) size_result="medium" ;;
                large*  ) size_result="large" ;;
                xlarge* ) size_result="xlarge" ;;
                max*    ) size_result="max" ;;
            esac

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
        echo "  1) xsmall (15%x15% or 384x216)" >&2
        echo "  2) small (20%x20% or 400x250)" >&2
        echo "  3) medium (30%x30% or 800x500)" >&2
        echo "  4) large (50%x50% or 1230x720)" >&2
        echo "  5) xlarge (75%x75% or 1845x1080)" >&2
        echo "  6) max (90%x90% or 2214x1296)" >&2
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
                        "Minimum size is 384x216 pixels (matches xsmall size)."
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
                            "Size exceeds 95% of screen resolution (${screen_width}x${screen_height}).\n\nMaximum is 95% of screen to ensure buttons remain visible."
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
                        echo "Minimum size is 384x216 pixels (matches xsmall size)." >&2
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
                        echo "Size exceeds 95% of screen resolution (${screen_width}x${screen_height}). Maximum is 95% of screen to ensure buttons remain visible." >&2
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

