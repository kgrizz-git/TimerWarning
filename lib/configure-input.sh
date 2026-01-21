#!/bin/bash

###############################################################################
# Sleep Warning System - User Input Collection Module
#
# This module provides all user input collection functions for the configuration
# wizard, supporting both GUI (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - get_hour_zenity()              - Get hour input using dialog tool (legacy name)
# - get_hour_text()                - Get hour input using text prompt
# - get_popup_size_config()        - Get popup size from user
# - get_min_display_time_config()  - Get minimum display time
# - get_popup_immovable_config()   - Get immovable setting
# - get_configure_block_enabled_config() - Get configure block enabled setting (Enhancement #19)
# - get_popup_position_config()    - Get popup position
# - get_check_interval()           - Get check interval
# - get_day_hours()                - Get time ranges for a day (complex with navigation)
#
# Note: Time calculation functions (calculate_range_duration, calculate_total_day_duration)
# have been moved to lib/time-calculations.sh
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-ui.sh (for confirm_cancel, confirm_skip_day, show_help_dialog)
# - configure-time.sh (for format_ranges_human)
# - time-calculations.sh (for calculate_range_duration, calculate_total_day_duration)
###############################################################################

# Get hour input using dialog tool (legacy name: get_hour_zenity)
get_hour_zenity() {
    local prompt="$1"
    local default="$2"
    
    local hour
    hour=$(show_entry_dialog \
        "Sleep Warning Configuration" \
        "${prompt}" \
        "${default}")
    
    if [ -z "${hour}" ]; then
        echo ""
        return 1
    fi
    
    # Validate hour
    if ! [[ "${hour}" =~ ^[0-9]+$ ]] || [ "${hour}" -lt 0 ] || [ "${hour}" -gt 23 ]; then
        show_info_dialog \
            "Invalid Hour" \
            "Invalid hour. Please enter a number between 0 and 23."
        echo ""
        return 1
    fi
    
    echo "${hour}"
    return 0
}

# Get hour input using text prompt
get_hour_text() {
    local prompt="$1"
    local default="$2"
    
    while true; do
        read -p "${prompt} [${default}]: " hour
        hour=${hour:-${default}}
        
        if [[ "${hour}" =~ ^[0-9]+$ ]] && [ "${hour}" -ge 0 ] && [ "${hour}" -le 23 ]; then
            echo "${hour}"
            return 0
        else
            echo "Invalid hour. Please enter a number between 0 and 23." >&2
        fi
    done
}

# Get popup size from user
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
                300 \
                "small" "medium" "large")
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
            
            # Valid selection
            echo "${size_result}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Size Options:" >&2
        echo "  1) small (400x250)" >&2
        echo "  2) medium (800x500)" >&2
        echo "  3) large (2000x1350)" >&2
        echo "" >&2
        while true; do
            read -p "Select size [1-3, default: ${default_size}]: " choice
            case "${choice}" in
                1|small) echo "small"; return 0 ;;
                2|medium) echo "medium"; return 0 ;;
                3|large) echo "large"; return 0 ;;
                "") echo "${default_size}"; return 0 ;;
                *) echo "Invalid choice. Please select 1, 2, or 3." >&2 ;;
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
                "Minimum time popup must be visible before it can be closed:\n\nEnter time in seconds (0-300):\n(0 = disabled, 30 = default)" \
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
            if ! [[ "${time}" =~ ^[0-9]+$ ]] || [ "${time}" -lt 0 ] || [ "${time}" -gt 300 ]; then
                show_info_dialog \
                    "Invalid Time" \
                    "Invalid time. Please enter a number between 0 and 300 seconds."
                continue
            fi
            
            echo "${time}"
            return 0
        done
    else
        # Text mode
        while true; do
            read -p "Minimum display time in seconds (0-300, 0=disabled) [${default_time}]: " time
            time=${time:-${default_time}}
            
            if [[ "${time}" =~ ^[0-9]+$ ]] && [ "${time}" -ge 0 ] && [ "${time}" -le 300 ]; then
                echo "${time}"
                return 0
            else
                echo "Invalid time. Please enter a number between 0 and 300." >&2
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

# Get configure block enabled setting from user
# This function prompts the user to enable or disable blocking of configure.sh and manage.sh
# during restricted hours. This is an opt-in security feature (Enhancement #19).
#
# Parameters:
#   $1 - use_gui (true/false) - Whether to use GUI dialogs or text prompts
#
# Returns:
#   "true" - User enabled blocking
#   "false" - User disabled blocking
#   "CANCELLED" - User cancelled the operation
#
# Exit Codes:
#   0 - Success (returns "true" or "false")
#   2 - User cancelled (returns "CANCELLED")
#
# Dependencies:
#   - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
#   - configure-dialogs.sh (for show_list_dialog)
#   - configure-ui.sh (for confirm_cancel)
#
# This is for Enhancement #19 (Prevent configure.sh and manage.sh Execution)
get_configure_block_enabled_config() {
    local use_gui="$1"
    local default_block_enabled="false"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_block_enabled
        existing_block_enabled=$(grep -E "^[[:space:]]*CONFIGURE_BLOCK_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_block_enabled}" ]; then
            if [ "${existing_block_enabled}" = "true" ] || [ "${existing_block_enabled}" = "1" ] || [ "${existing_block_enabled}" = "yes" ]; then
                default_block_enabled="true"
            elif [ "${existing_block_enabled}" = "false" ] || [ "${existing_block_enabled}" = "0" ] || [ "${existing_block_enabled}" = "no" ]; then
                default_block_enabled="false"
            fi
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local block_enabled
            local block_enabled_result
            block_enabled_result=$(show_list_dialog \
                "Sleep Warning Configuration - Block Configuration During Restricted Hours" \
                "Block configure.sh and manage.sh during restricted hours?\n\nWhen enabled, the configuration and management scripts will be blocked from running during restricted hours to prevent circumventing restrictions.\n\nNote: This must be enabled for 'Additional Configuration Block Hours' to take effect.\n\nCurrent setting: ${default_block_enabled}" \
                650 \
                400 \
                "true" "false")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${block_enabled_result}" ]; then
                block_enabled="${block_enabled_result}"
            else
                block_enabled=""
            fi
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${block_enabled}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${block_enabled}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Block Configuration During Restricted Hours - Configure Blocking:" >&2
        echo "  When enabled, configure.sh and manage.sh will be blocked from running" >&2
        echo "  during restricted hours to prevent circumventing restrictions." >&2
        echo "  Note: This must be enabled for 'Additional Configuration Block Hours' to take effect." >&2
        echo "" >&2
        while true; do
            read -p "Block configure.sh and manage.sh during restricted hours? [y/n, default: ${default_block_enabled}]: " choice
            choice=${choice:-${default_block_enabled}}
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
                    echo "${default_block_enabled}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                    ;;
            esac
        done
    fi
}

# Get uninstall protection mode configuration from user
# This function allows user to select protection mode for uninstall.sh during restricted hours
# This is for Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)
#
# Parameters:
#   $1 - use_gui (true/false)
#
# Returns:
#   "none" - No protection, uninstall works normally
#   "difficult" - Difficult uninstall, requires verification
#   "CANCELLED" - User cancelled
#
# Exit Codes:
#   0 - Success
#   2 - User cancelled
get_uninstall_protection_mode_config() {
    local use_gui="$1"
    local default_mode="none"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_mode
        existing_mode=$(grep -E "^[[:space:]]*UNINSTALL_PROTECTION_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_mode}" ]; then
            if [ "${existing_mode}" = "none" ] || [ "${existing_mode}" = "difficult" ]; then
                default_mode="${existing_mode}"
            fi
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local protection_mode
            local mode_result
            local mode_display
            if [ "${default_mode}" = "none" ]; then
                mode_display="No Protection"
            else
                mode_display="Difficult Uninstall (Recommended)"
            fi
            
            mode_result=$(show_list_dialog \
                "Sleep Warning Configuration - Uninstall Protection" \
                "Choose protection mode for uninstall.sh during restricted hours:\n\nCurrent setting: ${mode_display}\n\nOptions:\n• none - No protection, uninstall works normally during restricted hours\n• difficult - Difficult uninstall, requires confirmation phrase + 10 arithmetic questions\n\nDifficult mode allows legitimate uninstalls while deterring impulsive ones.\nIt requires significant effort and cognitive engagement.\n\nNote: Total block mode may be considered as future phase." \
                700 \
                500 \
                "none" "difficult")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${mode_result}" ]; then
                protection_mode="${mode_result}"
            else
                protection_mode=""
            fi
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${protection_mode}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${protection_mode}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Uninstall Protection Mode:" >&2
        echo "  Choose protection mode for uninstall.sh during restricted hours:" >&2
        echo "" >&2
        echo "  Options:" >&2
        echo "    1) none - No protection, uninstall works normally" >&2
        echo "    2) difficult - Difficult uninstall, requires verification (recommended)" >&2
        echo "" >&2
        echo "  Difficult mode requires:" >&2
        echo "    - Confirmation phrase" >&2
        echo "    - 10 arithmetic questions (written in word form)" >&2
        echo "" >&2
        echo "  Difficult mode allows legitimate uninstalls while deterring impulsive ones." >&2
        echo "  Note: Total block mode may be considered as future phase." >&2
        echo "" >&2
        while true; do
            local default_choice
            if [ "${default_mode}" = "none" ]; then
                default_choice="1"
            else
                default_choice="2"
            fi
            read -p "Select protection mode [1-2, default: ${default_choice}]: " choice
            choice=${choice:-${default_choice}}
            case "${choice}" in
                1|none|NONE)
                    echo "none"
                    return 0
                    ;;
                2|difficult|DIFFICULT)
                    echo "difficult"
                    return 0
                    ;;
                "")
                    echo "${default_mode}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please enter '1' for none or '2' for difficult." >&2
                    ;;
            esac
        done
    fi
}

# Get popup position from user
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

# Get check interval from user
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
            local tmpfile
            tmpfile=$(mktemp)
            
            # Get interval using dialog tool
            interval=$(show_entry_dialog \
                "Sleep Warning Configuration" \
                "How often should the system check for restricted hours?\n\nEnter interval in minutes (1-60):" \
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
            if ! [[ "${interval}" =~ ^[0-9]+$ ]] || [ "${interval}" -lt 1 ] || [ "${interval}" -gt 60 ]; then
                show_info_dialog \
                    "Invalid Interval" \
                    "Invalid interval. Please enter a number between 1 and 60 minutes."
                continue
            fi
            
            echo "${interval}"
            return 0
        done
    else
        # Text mode
        while true; do
            read -p "Check interval in minutes (1-60) [${default_interval}]: " interval
            interval=${interval:-${default_interval}}
            
            if [[ "${interval}" =~ ^[0-9]+$ ]] && [ "${interval}" -ge 1 ] && [ "${interval}" -le 60 ]; then
                echo "${interval}"
                return 0
            else
                echo "Invalid interval. Please enter a number between 1 and 60." >&2
            fi
        done
    fi
}

# Get hour range for a day (with navigation support)
get_day_hours() {
    local day_name="$1"
    local day_index="$2"
    local use_gui="$3"
    local allow_back="$4"  # true/false - whether back button should be shown
    local allow_cancel="$5"  # true/false - whether cancel should be available
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            # Build prompt text with examples
            local prompt_text="Configure restricted hours for ${day_name}:\n\n"
            prompt_text="${prompt_text}24-HOUR FORMAT:\n"
            prompt_text="${prompt_text}• Hours use 24-hour format (0-23)\n"
            prompt_text="${prompt_text}• 0 = midnight (12:00 AM)\n"
            prompt_text="${prompt_text}• 12 = noon (12:00 PM)\n"
            prompt_text="${prompt_text}• 22 = 10:00 PM\n"
            prompt_text="${prompt_text}• 23 = 11:00 PM\n\n"
            prompt_text="${prompt_text}Format options:\n"
            prompt_text="${prompt_text}• Single: 0-5 (midnight to 4:59 AM)\n"
            prompt_text="${prompt_text}• Multiple: 0-5,22-23 (two periods)\n"
            prompt_text="${prompt_text}• Overnight: 23-6 (11 PM to 5:59 AM, spans to next day)\n\n"
            prompt_text="${prompt_text}IMPORTANT: Overnight ranges like '23-6' on ${day_name} mean:\n"
            prompt_text="${prompt_text}${day_name} 11:00 PM → Next day 6:00 AM\n\n"
            prompt_text="${prompt_text}(Leave empty to skip this day)"
            
            # Ask for time range (supports single range, multiple ranges, or overnight)
            local range_input
            range_input=$(show_entry_dialog \
                "Sleep Warning Configuration - ${day_name}" \
                "${prompt_text}" \
                "" \
                "Help")
            local exit_code=$?
            
            # Handle extra button (Help)
            if [ ${exit_code} -ne 0 ] && echo "${range_input}" | grep -q "^EXTRA_BUTTON:Help$"; then
                show_help_dialog "${use_gui}"
                continue
            fi
            
            # Handle cancel/empty
            if [ "${exit_code}" -ne 0 ] || [ -z "${range_input}" ]; then
                # User cancelled or left empty - show options menu
                local tmpfile
                tmpfile=$(mktemp)
                
                local menu_options=("Skip this day")
                if [ "${allow_back}" = "true" ]; then
                    menu_options+=("Go back to previous day")
                fi
                if [ "${allow_cancel}" = "true" ]; then
                    menu_options+=("Cancel configuration")
                fi
                menu_options+=("Continue configuring")
                
                local choice
                choice=$(show_list_dialog \
                    "What would you like to do?" \
                    "You cancelled or left ${day_name} empty. What would you like to do?" \
                    500 \
                    300 \
                    "${menu_options[@]}")
                local menu_exit=$?
                
                if [ "${menu_exit}" -ne 0 ] || [ -z "${choice}" ]; then
                    # User cancelled the menu - treat as cancel whole config
                    if confirm_cancel "${use_gui}"; then
                        echo "CANCELLED"
                        return 2
                    else
                        continue
                    fi
                fi
                
                case "${choice}" in
                    "Skip this day")
                        if confirm_skip_day "${day_name}" "${use_gui}"; then
                            echo "skip"
                            return 0
                        else
                            continue
                        fi
                        ;;
                    "Go back to previous day")
                        if [ "${allow_back}" = "true" ]; then
                            echo "back"
                            return 2
                        fi
                        continue
                        ;;
                    "Cancel configuration")
                        if [ "${allow_cancel}" = "true" ]; then
                            if confirm_cancel "${use_gui}"; then
                                echo "CANCELLED"
                                return 2
                            else
                                continue
                            fi
                        fi
                        continue
                        ;;
                    "Continue configuring")
                        continue
                        ;;
                    *)
                        continue
                        ;;
                esac
            fi
            
            # Validate the input (could be single range, multiple ranges, or overnight)
            # Check if it's a valid format
            if ! echo "${range_input}" | grep -qE '^([0-9]+-[0-9]+)(,[0-9]+-[0-9]+)*$'; then
                show_info_dialog \
                    "Invalid Format" \
                    "Invalid format. Use: START-END or START-END,START-END\n\nExamples:\n• 0-5 (midnight to 4:59 AM)\n• 0-5,22-23 (two periods)\n• 23-6 (11 PM to 5:59 AM, overnight)" \
                    550 \
                    280
                continue
            fi
            
            # Validate each range in the input
            local IFS=','
            local valid=true
            for range in ${range_input}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_hour end_hour
                start_hour=$(echo "${range}" | cut -d'-' -f1)
                end_hour=$(echo "${range}" | cut -d'-' -f2)
                
                # Validate hour values
                if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ] || \
                   [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
                    valid=false
                    break
                fi
                
                # Start and end cannot be equal
                if [ "${start_hour}" -eq "${end_hour}" ]; then
                    valid=false
                    break
                fi
            done
            
            if [ "${valid}" = "false" ]; then
                show_info_dialog \
                    "Invalid Hour Values" \
                    "Invalid hour values. Hours must be 0-23, and start cannot equal end."
                continue
            fi
            
            # Check if single interval is over 12 hours and show warning
            # Count commas to determine if it's a single range
            local comma_count
            comma_count=$(echo "${range_input}" | tr -cd ',' | wc -c)
            if [ "${comma_count}" -eq 0 ]; then
                # Single range - check duration
                local range_duration
                range_duration=$(calculate_range_duration "${range_input}")
                if [ "${range_duration}" -gt 12 ]; then
                    # Show eye-catching warning
                    local warning_msg="⚠️  WARNING: LONG TIME RANGE ⚠️\n\n"
                    warning_msg="${warning_msg}You entered a single interval of ${range_duration} hours.\n\n"
                    warning_msg="${warning_msg}This is a very long restriction period. Are you sure this is what you want?\n\n"
                    warning_msg="${warning_msg}If you meant to have multiple shorter periods, use comma-separated ranges.\n"
                    warning_msg="${warning_msg}Example: 0-5,22-23 (instead of 0-23)"
                    
                    if ! show_question_dialog \
                        "⚠️  Long Time Range Warning" \
                        "${warning_msg}" \
                        "Yes, Continue" \
                        "No, Let Me Edit" \
                        650 \
                        400; then
                        # User wants to edit
                        continue
                    fi
                fi
            fi
            
            # Check if total duration for the day (including overnight from previous day) is over 12 hours
            local total_duration
            total_duration=$(calculate_total_day_duration "${day_index}" "${range_input}")
            if [ "${total_duration}" -gt 12 ]; then
                # Show warning about total duration
                local total_warning_msg="⚠️  WARNING: TOTAL RESTRICTIONS EXCEED 12 HOURS ⚠️\n\n"
                total_warning_msg="${total_warning_msg}The total restricted hours for this day is ${total_duration} hours.\n\n"
                total_warning_msg="${total_warning_msg}This includes:\n"
                total_warning_msg="${total_warning_msg}• Your entered ranges for ${day_name}\n"
                
                # Check if previous day has overnight ranges
                local prev_day_index
                if [ "${day_index}" -eq 0 ]; then
                    prev_day_index=6  # Sunday -> Saturday
                else
                    prev_day_index=$((day_index - 1))
                fi
                
                local prev_day_ranges=""
                if type parse_config >/dev/null 2>&1; then
                    prev_day_ranges=$(parse_config "${prev_day_index}" 2>/dev/null || echo "")
                fi
                
                local has_overnight=false
                if [ -n "${prev_day_ranges}" ]; then
                    local IFS=','
                    for range in ${prev_day_ranges}; do
                        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        if [ -n "${range}" ]; then
                            local start_hour end_hour
                            start_hour=$(echo "${range}" | cut -d'-' -f1)
                            end_hour=$(echo "${range}" | cut -d'-' -f2)
                            if [ "${start_hour}" -gt "${end_hour}" ]; then
                                has_overnight=true
                                break
                            fi
                        fi
                    done
                fi
                
                if [ "${has_overnight}" = "true" ]; then
                    # Use DAY_NAMES array if available, otherwise fallback to case statement
                    local prev_day_name
                    if [ -n "${DAY_NAMES[${prev_day_index}]:-}" ]; then
                        prev_day_name="${DAY_NAMES[${prev_day_index}]}"
                    else
                        case "${prev_day_index}" in
                            0) prev_day_name="Sunday" ;;
                            1) prev_day_name="Monday" ;;
                            2) prev_day_name="Tuesday" ;;
                            3) prev_day_name="Wednesday" ;;
                            4) prev_day_name="Thursday" ;;
                            5) prev_day_name="Friday" ;;
                            6) prev_day_name="Saturday" ;;
                        esac
                    fi
                    total_warning_msg="${total_warning_msg}• Overnight ranges from ${prev_day_name} that extend into ${day_name}\n"
                fi
                
                total_warning_msg="${total_warning_msg}\nThis is a very long restriction period. Are you sure this is what you want?"
                
                if ! show_question_dialog \
                    "⚠️  Total Restrictions Warning" \
                    "${total_warning_msg}" \
                    "Yes, Continue" \
                    "No, Let Me Edit" \
                    650 \
                    450; then
                    # User wants to edit
                    continue
                fi
            fi
            
            # Show preview of what will be restricted
            local preview
            preview=$(format_ranges_human "${range_input}" "${day_name}")
            if show_question_dialog \
                "Confirm Time Range" \
                "You entered: ${range_input}\n\nThis means:\n${preview}\n\nIs this correct?" \
                "Yes" \
                "No, Edit" \
                600 \
                350; then
                echo "${range_input}"
                return 0
            fi
            # User wants to edit, continue loop
        done
    else
        # Text mode
        echo "" >&2
        echo "=== Configuring ${day_name} ===" >&2
        echo "" >&2
        echo "24-HOUR FORMAT:" >&2
        echo "  • Hours use 24-hour format (0-23)" >&2
        echo "  • 0 = midnight (12:00 AM)" >&2
        echo "  • 12 = noon (12:00 PM)" >&2
        echo "  • 22 = 10:00 PM" >&2
        echo "  • 23 = 11:00 PM" >&2
        echo "" >&2
        echo "IMPORTANT - Overnight ranges:" >&2
        echo "  If you enter '23-6' on ${day_name}, it means:" >&2
        echo "  ${day_name} 11:00 PM → Next day 5:59 AM" >&2
        echo "" >&2
        echo "Format options:" >&2
        echo "  • Single: 0-5 (midnight to 4:59 AM)" >&2
        echo "  • Multiple: 0-5,22-23 (two periods)" >&2
        echo "  • Overnight: 23-6 (11 PM to 5:59 AM, spans to next day)" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  • Enter time range(s) to configure" >&2
        echo "  • Press Enter or type 's' to skip this day" >&2
        if [ "${allow_back}" = "true" ]; then
            echo "  • Type 'back' to go to previous day" >&2
        fi
        if [ "${allow_cancel}" = "true" ]; then
            echo "  • Type 'cancel' to exit without saving" >&2
        fi
        echo "  • Type 'help' for detailed help" >&2
        echo "" >&2
        
        while true; do
            local range_input
            read -p "Time range(s) for ${day_name} (or 's' to skip): " range_input
            
            # Handle special commands
            case "${range_input}" in
                skip|s|S|"")
                    if confirm_skip_day "${day_name}" "${use_gui}"; then
                        echo "skip"
                        return 0
                    else
                        # User wants to continue configuring this day
                        continue
                    fi
                    ;;
                back)
                    if [ "${allow_back}" = "true" ]; then
                        echo "back"
                        return 2  # Special return code for back
                    else
                        echo "Cannot go back from here." >&2
                        continue
                    fi
                    ;;
                cancel)
                    if [ "${allow_cancel}" = "true" ]; then
                        if confirm_cancel "${use_gui}"; then
                            echo "CANCELLED"
                            return 2  # Special return code for cancellation
                        else
                            # User wants to continue
                            continue
                        fi
                    else
                        echo "Type 'skip' to skip this day." >&2
                        continue
                    fi
                    ;;
                help)
                    show_help_dialog "${use_gui}"
                    continue
                    ;;
            esac
            
            # Validate the input format
            if ! echo "${range_input}" | grep -qE '^([0-9]+-[0-9]+)(,[0-9]+-[0-9]+)*$'; then
                echo "Error: Invalid format. Use: START-END or START-END,START-END" >&2
                echo "Examples: 0-5 or 0-5,22-23 or 23-6" >&2
                continue
            fi
            
            # Validate each range
            local IFS=','
            local valid=true
            for range in ${range_input}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_hour end_hour
                start_hour=$(echo "${range}" | cut -d'-' -f1)
                end_hour=$(echo "${range}" | cut -d'-' -f2)
                
                # Validate hour values
                if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ] || \
                   [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
                    valid=false
                    break
                fi
                
                # Start and end cannot be equal
                if [ "${start_hour}" -eq "${end_hour}" ]; then
                    valid=false
                    break
                fi
            done
            
            if [ "${valid}" = "false" ]; then
                echo "Error: Invalid hour values. Hours must be 0-23, and start cannot equal end." >&2
                continue
            fi
            
            # Check if single interval is over 12 hours and show warning
            # Count commas to determine if it's a single range
            local comma_count
            comma_count=$(echo "${range_input}" | tr -cd ',' | wc -c)
            if [ "${comma_count}" -eq 0 ]; then
                # Single range - check duration
                local range_duration
                range_duration=$(calculate_range_duration "${range_input}")
                if [ "${range_duration}" -gt 12 ]; then
                    # Show eye-catching warning
                    echo "" >&2
                    echo "⚠️  ⚠️  ⚠️  WARNING: LONG TIME RANGE ⚠️  ⚠️  ⚠️" >&2
                    echo "" >&2
                    echo "You entered a single interval of ${range_duration} hours." >&2
                    echo "" >&2
                    echo "This is a very long restriction period. Are you sure this is what you want?" >&2
                    echo "" >&2
                    echo "If you meant to have multiple shorter periods, use comma-separated ranges." >&2
                    echo "Example: 0-5,22-23 (instead of 0-23)" >&2
                    echo "" >&2
                    read -p "Continue with this long range? [y/N]: " warning_confirm
                    case "${warning_confirm}" in
                        [Yy]*)
                            # User confirmed, continue to normal confirmation
                            ;;
                        *)
                            echo "Please re-enter the time range." >&2
                            continue
                            ;;
                    esac
                fi
            fi
            
            # Check if total duration for the day (including overnight from previous day) is over 12 hours
            local total_duration
            total_duration=$(calculate_total_day_duration "${day_index}" "${range_input}")
            if [ "${total_duration}" -gt 12 ]; then
                # Show warning about total duration
                echo "" >&2
                echo "⚠️  ⚠️  ⚠️  WARNING: TOTAL RESTRICTIONS EXCEED 12 HOURS ⚠️  ⚠️  ⚠️" >&2
                echo "" >&2
                echo "The total restricted hours for this day is ${total_duration} hours." >&2
                echo "" >&2
                echo "This includes:" >&2
                echo "• Your entered ranges for ${day_name}" >&2
                
                # Check if previous day has overnight ranges
                local prev_day_index
                if [ "${day_index}" -eq 0 ]; then
                    prev_day_index=6  # Sunday -> Saturday
                else
                    prev_day_index=$((day_index - 1))
                fi
                
                local prev_day_ranges=""
                if type parse_config >/dev/null 2>&1; then
                    prev_day_ranges=$(parse_config "${prev_day_index}" 2>/dev/null || echo "")
                fi
                
                local has_overnight=false
                if [ -n "${prev_day_ranges}" ]; then
                    local IFS=','
                    for range in ${prev_day_ranges}; do
                        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        if [ -n "${range}" ]; then
                            local start_hour end_hour
                            start_hour=$(echo "${range}" | cut -d'-' -f1)
                            end_hour=$(echo "${range}" | cut -d'-' -f2)
                            if [ "${start_hour}" -gt "${end_hour}" ]; then
                                has_overnight=true
                                break
                            fi
                        fi
                    done
                fi
                
                if [ "${has_overnight}" = "true" ]; then
                    # Use DAY_NAMES array if available, otherwise fallback to case statement
                    local prev_day_name
                    if [ -n "${DAY_NAMES[${prev_day_index}]:-}" ]; then
                        prev_day_name="${DAY_NAMES[${prev_day_index}]}"
                    else
                        case "${prev_day_index}" in
                            0) prev_day_name="Sunday" ;;
                            1) prev_day_name="Monday" ;;
                            2) prev_day_name="Tuesday" ;;
                            3) prev_day_name="Wednesday" ;;
                            4) prev_day_name="Thursday" ;;
                            5) prev_day_name="Friday" ;;
                            6) prev_day_name="Saturday" ;;
                        esac
                    fi
                    echo "• Overnight ranges from ${prev_day_name} that extend into ${day_name}" >&2
                fi
                
                echo "" >&2
                echo "This is a very long restriction period. Are you sure this is what you want?" >&2
                echo "" >&2
                read -p "Continue with this total restriction? [y/N]: " total_warning_confirm
                case "${total_warning_confirm}" in
                    [Yy]*)
                        # User confirmed, continue to normal confirmation
                        ;;
                    *)
                        echo "Please re-enter the time range." >&2
                        continue
                        ;;
                esac
            fi
            
            # Show preview
            local preview
            preview=$(format_ranges_human "${range_input}" "${day_name}")
            echo "" >&2
            echo "Preview: ${preview}" >&2
            echo "" >&2
            read -p "Is this correct? [Y/n]: " confirm
            case "${confirm}" in
                [Nn]*)
                    echo "Please re-enter the time range." >&2
                    continue
                    ;;
                *)
                    echo "${range_input}"
                    return 0
                    ;;
            esac
        done
    fi
}
