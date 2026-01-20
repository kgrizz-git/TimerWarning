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
# - get_popup_position_config()    - Get popup position
# - get_check_interval()           - Get check interval
# - get_day_hours()                - Get time ranges for a day (complex with navigation)
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-ui.sh (for confirm_cancel, confirm_skip_day, show_help_dialog)
# - configure-time.sh (for format_ranges_human)
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
