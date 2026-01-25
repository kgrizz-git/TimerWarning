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
# - get_security_settings_config() - Get combined security settings (script blocking & config locking)
# - get_config_lock_enabled_config() - Get config lock enabled setting (Enhancement #18)
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

# Get combined security settings (configure block and config file locking)
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - current_configure_block_enabled (current value)
#   $3 - current_config_lock_enabled (current value)
# Returns:
#   "configure_block|config_lock" - Both settings as pipe-separated values
#   "CANCELLED" - User cancelled the operation
# Exit Codes:
#   0 - Success (returns "true|true", "true|false", "false|true", or "false|false")
#   2 - User cancelled (returns "CANCELLED")
get_security_settings_config() {
    local use_gui="$1"
    local current_configure_block="${2:-false}"
    local current_config_lock="${3:-false}"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode - use a form dialog or multi-step dialog
        while true; do
            # First, ask about configure block
            local block_enabled_result
            block_enabled_result=$(show_list_dialog \
                "Sleep Warning Configuration - Security Settings" \
                "Block configure.sh and manage.sh during restricted hours?\n\nWhen enabled, the configuration and management scripts will be blocked from running during restricted hours to prevent circumventing restrictions.\n\nNote: This must be enabled for 'Additional Configuration Block Hours' to take effect.\n\nCurrent setting: ${current_configure_block}" \
                700 \
                400 \
                "true" "false")
            local exit_code=$?
            
            if [ ${exit_code} -ne 0 ] || [ -z "${block_enabled_result}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                else
                    continue
                fi
            fi
            
            # Then, ask about config file locking
            local lock_enabled_result
            lock_enabled_result=$(show_list_dialog \
                "Sleep Warning Configuration - Security Settings" \
                "Enable config file locking during restricted hours?\n\nWhen enabled, the config file and directory are made read-only during restricted hours and any configured lock hours to prevent users from circumventing restrictions by changing settings.\n\nNote: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week (> $(get_threshold_warn_description)) for safety.\n\nCurrent setting: ${current_config_lock}" \
                700 \
                450 \
                "true" "false")
            exit_code=$?
            
            if [ ${exit_code} -ne 0 ] || [ -z "${lock_enabled_result}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                else
                    continue
                fi
            fi
            
            # Return both values pipe-separated
            echo "${block_enabled_result}|${lock_enabled_result}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Security Settings Configuration" >&2
        echo "" >&2
        echo "1. Block configure.sh and manage.sh during restricted hours" >&2
        echo "   When enabled, configure.sh and manage.sh will be blocked from running" >&2
        echo "   during restricted hours to prevent circumventing restrictions." >&2
        echo "   Note: This must be enabled for 'Additional Configuration Block Hours' to take effect." >&2
        echo "" >&2
        echo "2. Config file locking during restricted hours" >&2
        echo "   When enabled, the config file and directory are made read-only during" >&2
        echo "   restricted hours and any configured lock hours to prevent users from" >&2
        echo "   circumventing restrictions by changing settings." >&2
        echo "" >&2
        echo "   This is a deterrence mechanism, not true security. A determined user" >&2
        echo "   can still bypass it by changing permissions or stopping the timer." >&2
        echo "" >&2
        echo "   Note: Automatically disabled if restrictions exceed 6720 minutes/week" >&2
        echo "   (> 16 hours/day) for safety." >&2
        echo "" >&2
        
        # Get configure block setting
        local block_enabled
        while true; do
            read -p "Block configure.sh and manage.sh during restricted hours? [y/n, default: ${current_configure_block}]: " choice >&2
            choice=${choice:-${current_configure_block}}
            case "${choice}" in
                y|Y|yes|YES|true|TRUE|1)
                    block_enabled="true"
                    break
                    ;;
                n|N|no|NO|false|FALSE|0)
                    block_enabled="false"
                    break
                    ;;
                "")
                    block_enabled="${current_configure_block}"
                    break
                    ;;
                *)
                    echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                    ;;
            esac
        done
        
        # Get config lock setting
        local lock_enabled
        while true; do
            read -p "Enable config file locking during restricted hours? [y/n, default: ${current_config_lock}]: " choice >&2
            choice=${choice:-${current_config_lock}}
            case "${choice}" in
                y|Y|yes|YES|true|TRUE|1)
                    lock_enabled="true"
                    break
                    ;;
                n|N|no|NO|false|FALSE|0)
                    lock_enabled="false"
                    break
                    ;;
                "")
                    lock_enabled="${current_config_lock}"
                    break
                    ;;
                *)
                    echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                    ;;
            esac
        done
        
        # Return both values pipe-separated
        echo "${block_enabled}|${lock_enabled}"
        return 0
    fi
}

# Get config lock enabled setting from user
# Parameters:
#   $1 - use_gui (true/false)
# Returns:
#   "true" - User enabled config file locking
#   "false" - User disabled config file locking
#   "CANCELLED" - User cancelled the operation
# Exit Codes:
#   0 - Success (returns "true" or "false")
#   2 - User cancelled (returns "CANCELLED")
get_config_lock_enabled_config() {
    local use_gui="$1"
    local default_lock_enabled="false"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_lock_enabled
        existing_lock_enabled=$(grep -E "^[[:space:]]*CONFIG_LOCK_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_lock_enabled}" ]; then
            if [ "${existing_lock_enabled}" = "true" ] || [ "${existing_lock_enabled}" = "1" ] || [ "${existing_lock_enabled}" = "yes" ]; then
                default_lock_enabled="true"
            elif [ "${existing_lock_enabled}" = "false" ] || [ "${existing_lock_enabled}" = "0" ] || [ "${existing_lock_enabled}" = "no" ]; then
                default_lock_enabled="false"
            fi
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local lock_enabled
            local lock_enabled_result
            lock_enabled_result=$(show_list_dialog \
                "Sleep Warning Configuration - Config File Locking" \
                "Enable config file locking during restricted hours?\n\nWhen enabled, the config file and directory are made read-only during restricted hours and any configured lock hours to prevent users from circumventing restrictions by changing settings.\n\nNote: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week (> $(get_threshold_warn_description)) for safety.\n\nCurrent setting: ${default_lock_enabled}" \
                700 \
                450 \
                "true" "false")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${lock_enabled_result}" ]; then
                lock_enabled="${lock_enabled_result}"
            else
                lock_enabled=""
            fi
            
            # User cancelled
            if [ ${exit_code} -ne 0 ] || [ -z "${lock_enabled}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            # Validate result
            if [ "${lock_enabled}" = "true" ] || [ "${lock_enabled}" = "false" ]; then
                echo "${lock_enabled}"
                return 0
            else
                # Invalid result (shouldn't happen, but handle gracefully)
                continue
            fi
        done
    else
        # Text mode
        while true; do
            echo "" >&2
            echo "Config File Locking (Enhancement #18)" >&2
            echo "" >&2
            echo "When enabled, the config file and directory are made read-only during" >&2
            echo "restricted hours and any configured lock hours to prevent users from" >&2
            echo "circumventing restrictions by changing settings." >&2
            echo "" >&2
            echo "This is a deterrence mechanism, not true security. A determined user" >&2
            echo "can still bypass it by changing permissions or stopping the timer." >&2
            echo "" >&2
            echo "Note: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week" >&2
            echo "(> $(get_threshold_warn_description)) for safety." >&2
            echo "" >&2
            echo "Current setting: ${default_lock_enabled}" >&2
            echo "" >&2
            read -p "Enable config file locking? [true/false]: " lock_enabled >&2
            
            # Handle cancellation (Ctrl+C or empty input)
            if [ -z "${lock_enabled}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                else
                    continue
                fi
            fi
            
            # Normalize input
            lock_enabled=$(echo "${lock_enabled}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
            
            # Validate and return
            if [ "${lock_enabled}" = "true" ] || [ "${lock_enabled}" = "1" ] || [ "${lock_enabled}" = "yes" ]; then
                echo "true"
                return 0
            elif [ "${lock_enabled}" = "false" ] || [ "${lock_enabled}" = "0" ] || [ "${lock_enabled}" = "no" ]; then
                echo "false"
                return 0
            else
                echo "Invalid input. Please enter 'true' or 'false'." >&2
                continue
            fi
        done
    fi
}

# Get pause enabled setting from user
# This function prompts the user to enable or disable the pause feature
# This is for Enhancement #21 (One-Time Pause Feature)
#
# Parameters:
#   $1 - use_gui (true/false) - Whether to use GUI dialogs or text prompts
#
# Returns:
#   "true" - User enabled pause feature
#   "false" - User disabled pause feature
#   "CANCELLED" - User cancelled the operation
#
# Exit Codes:
#   0 - Success (returns "true" or "false")
#   2 - User cancelled (returns "CANCELLED")
get_pause_enabled_config() {
    local use_gui="$1"
    local default_enabled="true"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_enabled
        existing_enabled=$(grep -E "^[[:space:]]*PAUSE_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_enabled}" ]; then
            if [ "${existing_enabled}" = "true" ] || [ "${existing_enabled}" = "1" ] || [ "${existing_enabled}" = "yes" ]; then
                default_enabled="true"
            elif [ "${existing_enabled}" = "false" ] || [ "${existing_enabled}" = "0" ] || [ "${existing_enabled}" = "no" ]; then
                default_enabled="false"
            fi
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local pause_enabled
            local enabled_result
            enabled_result=$(show_list_dialog \
                "Sleep Warning Configuration - Pause Feature" \
                "Enable pause feature for warning popups?\n\nWhen enabled, users can pause warning popups for a short period (5 or 10 minutes) directly from the warning popup window.\n\nNote: Pause only suppresses warning popups, not restrictions. configure.sh blocking and uninstall.sh protection still apply during pause.\n\nCurrent setting: ${default_enabled}" \
                650 \
                400 \
                "true" "false")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${enabled_result}" ]; then
                pause_enabled="${enabled_result}"
            else
                pause_enabled=""
            fi
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${pause_enabled}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${pause_enabled}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Pause Feature - Enable/Disable:" >&2
        echo "  When enabled, users can pause warning popups for a short period" >&2
        echo "  (5 or 10 minutes) directly from the warning popup window." >&2
        echo "  Note: Pause only suppresses warning popups, not restrictions." >&2
        echo "" >&2
        while true; do
            read -p "Enable pause feature? [y/n, default: ${default_enabled}]: " choice
            choice=${choice:-${default_enabled}}
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
                    echo "${default_enabled}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                    ;;
            esac
        done
    fi
}

# Get pause duration configuration from user
# This function allows user to select pause duration (5 or 10 minutes)
# This is for Enhancement #21 (One-Time Pause Feature)
#
# Parameters:
#   $1 - use_gui (true/false)
#
# Returns:
#   "5" - 5 minute pause duration
#   "10" - 10 minute pause duration
#   "CANCELLED" - User cancelled
#
# Exit Codes:
#   0 - Success
#   2 - User cancelled
get_pause_duration_config() {
    local use_gui="$1"
    local default_duration="5"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_duration
        existing_duration=$(grep -E "^[[:space:]]*PAUSE_DURATION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_duration}" ] && [[ "${existing_duration}" =~ ^[0-9]+$ ]]; then
            if [ "${existing_duration}" -eq 5 ] || [ "${existing_duration}" -eq 10 ]; then
                default_duration="${existing_duration}"
            fi
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local pause_duration
            local duration_result
            duration_result=$(show_list_dialog \
                "Sleep Warning Configuration - Pause Duration" \
                "Select pause duration:\n\nCurrent setting: ${default_duration} minutes\n\nOptions:\n• 5 minutes - Shorter pause period\n• 10 minutes - Longer pause period\n\nThe selected duration determines how long warning popups are paused when user clicks pause button." \
                600 \
                350 \
                "5" "10")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${duration_result}" ]; then
                pause_duration="${duration_result}"
            else
                pause_duration=""
            fi
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${pause_duration}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${pause_duration}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Pause Duration:" >&2
        echo "  Select how long warning popups are paused when user clicks pause button." >&2
        echo "" >&2
        while true; do
            read -p "Pause duration (5 or 10 minutes) [default: ${default_duration}]: " choice
            choice=${choice:-${default_duration}}
            case "${choice}" in
                5|10)
                    echo "${choice}"
                    return 0
                    ;;
                "")
                    echo "${default_duration}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please enter '5' or '10'." >&2
                    ;;
            esac
        done
    fi
}

# Get pause once per day setting from user
# This function prompts the user to enable or disable once-per-day limit for pause
# This is for Enhancement #21 (One-Time Pause Feature)
#
# Parameters:
#   $1 - use_gui (true/false) - Whether to use GUI dialogs or text prompts
#
# Returns:
#   "true" - User enabled once-per-day limit
#   "false" - User disabled once-per-day limit
#   "CANCELLED" - User cancelled the operation
#
# Exit Codes:
#   0 - Success (returns "true" or "false")
#   2 - User cancelled (returns "CANCELLED")
get_pause_once_per_day_config() {
    local use_gui="$1"
    local default_once_per_day="true"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_once_per_day
        existing_once_per_day=$(grep -E "^[[:space:]]*PAUSE_ONCE_PER_DAY=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_once_per_day}" ]; then
            if [ "${existing_once_per_day}" = "true" ] || [ "${existing_once_per_day}" = "1" ] || [ "${existing_once_per_day}" = "yes" ]; then
                default_once_per_day="true"
            elif [ "${existing_once_per_day}" = "false" ] || [ "${existing_once_per_day}" = "0" ] || [ "${existing_once_per_day}" = "no" ]; then
                default_once_per_day="false"
            fi
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local pause_once_per_day
            local once_per_day_result
            once_per_day_result=$(show_list_dialog \
                "Sleep Warning Configuration - Pause Once Per Day" \
                "Limit pause to once per day?\n\nWhen enabled, users can only use pause once per day (resets at midnight).\nWhen disabled, users can pause multiple times per day.\n\nCurrent setting: ${default_once_per_day}" \
                650 \
                350 \
                "true" "false")
            local exit_code=$?
            
            if [ ${exit_code} -eq 0 ] && [ -n "${once_per_day_result}" ]; then
                pause_once_per_day="${once_per_day_result}"
            else
                pause_once_per_day=""
            fi
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${pause_once_per_day}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${pause_once_per_day}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Pause Once Per Day Limit:" >&2
        echo "  When enabled, users can only use pause once per day (resets at midnight)." >&2
        echo "  When disabled, users can pause multiple times per day." >&2
        echo "" >&2
        while true; do
            read -p "Limit pause to once per day? [y/n, default: ${default_once_per_day}]: " choice
            choice=${choice:-${default_once_per_day}}
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
                    echo "${default_once_per_day}"
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

# Get dialog tool selection from user
# Returns: "auto", "zenity", "yad", "kdialog", or "CANCELLED"
# Exit Codes:
#   0 - Success (returns tool name or "auto")
#   1 - User wants to retry/re-prompt (invalid selection, tool unavailable)
#   2 - User cancelled (confirmed cancellation)
# This is for Enhancement #25 (User-Selectable Dialog Tool)
get_dialog_tool_selection() {
    local use_gui="$1"
    
    # Get current setting from config file (using function from config.sh)
    # Note: configure-input.sh is sourced by configure.sh, which sources config.sh
    # If config.sh is not available, fall back to "auto"
    local current_setting
    if type get_dialog_tool_config >/dev/null 2>&1; then
        current_setting=$(get_dialog_tool_config 2>/dev/null || echo "auto")
    else
        # Fallback if config.sh not sourced (should not happen in normal operation)
        current_setting="auto"
    fi
    
    # Detect which tool would be automatically selected (for recommendation)
    # This shows the user what tool the automatic priority system would choose
    local recommended_tool=""
    local env_type
    if type detect_display_environment >/dev/null 2>&1; then
        env_type=$(detect_display_environment 2>/dev/null || echo "x11")
    else
        env_type="x11"
    fi
    
    if type check_dialog_tool >/dev/null 2>&1; then
        # Get the tool that would be automatically selected (no user preference)
        recommended_tool=$(check_dialog_tool "${env_type}" "" 2>/dev/null || echo "")
    else
        # Fallback: check tools manually in priority order
        if command -v yad >/dev/null 2>&1; then
            recommended_tool="yad"
        elif command -v zenity >/dev/null 2>&1; then
            recommended_tool="zenity"
        elif command -v kdialog >/dev/null 2>&1; then
            recommended_tool="kdialog"
        fi
    fi
    
    # Detect installed tools
    local installed_tools=()
    local tool_descriptions=()
    
    # Always include "auto" option
    installed_tools+=("auto")
    if [ -n "${recommended_tool}" ]; then
        tool_descriptions+=("Automatic (recommended) - Will use: ${recommended_tool} (priority: YAD → Zenity → KDialog)")
    else
        tool_descriptions+=("Automatic (recommended) - Uses priority: YAD → Zenity → KDialog")
    fi
    
    # Check for installed tools
    if command -v yad >/dev/null 2>&1; then
        installed_tools+=("yad")
        if [ "${recommended_tool}" = "yad" ]; then
            tool_descriptions+=("yad - Enhanced GTK dialog (best positioning, Wayland support) [Recommended by automatic priority]")
        else
            tool_descriptions+=("yad - Enhanced GTK dialog (best positioning, Wayland support)")
        fi
    fi
    if command -v zenity >/dev/null 2>&1; then
        installed_tools+=("zenity")
        if [ "${recommended_tool}" = "zenity" ]; then
            tool_descriptions+=("zenity - Standard GTK dialog (fallback) [Recommended by automatic priority]")
        else
            tool_descriptions+=("zenity - Standard GTK dialog (fallback)")
        fi
    fi
    if command -v kdialog >/dev/null 2>&1; then
        installed_tools+=("kdialog")
        if [ "${recommended_tool}" = "kdialog" ]; then
            tool_descriptions+=("kdialog - KDE dialog (KDE integration) [Recommended by automatic priority]")
        else
            tool_descriptions+=("kdialog - KDE dialog (KDE integration)")
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode - use list dialog
        local current_index=0
        local i=0
        for tool in "${installed_tools[@]}"; do
            if [ "${tool}" = "${current_setting}" ]; then
                current_index=${i}
                break
            fi
            i=$((i + 1))
        done
        
        # Build dialog message with recommendation
        local dialog_msg="Select which dialog tool to use for popup windows:\n\n"
        dialog_msg="${dialog_msg}Current setting: ${current_setting}\n"
        if [ -n "${recommended_tool}" ]; then
            dialog_msg="${dialog_msg}Recommended: ${recommended_tool} (selected by automatic priority system)\n"
        fi
        dialog_msg="${dialog_msg}\nNote: If you don't make a selection or cancel, the system will use 'Automatic' mode, which will select ${recommended_tool:-"the best available tool"} based on priority (YAD → Zenity → KDialog).\n\n"
        dialog_msg="${dialog_msg}Only installed tools are shown. If you select a tool that becomes unavailable, the system will automatically fall back to the priority system."
        
        local choice
        choice=$(show_list_dialog \
            "Dialog Tool Selection" \
            "${dialog_msg}" \
            650 \
            450 \
            "${tool_descriptions[@]}")
        local exit_code=$?
        
        if [ ${exit_code} -ne 0 ] || [ -z "${choice}" ]; then
            # User cancelled or didn't make a selection
            # Ask if they want to cancel configuration entirely, or use default "auto"
            if confirm_cancel "${use_gui}"; then
                # User confirmed cancellation - exit configuration
                echo "CANCELLED"
                return 2
            else
                # User wants to continue - use "auto" as default and return to menu
                # This makes it clear that automatic priority will be used if no selection is made
                echo "auto"
                return 0
            fi
        fi
        
        # Extract tool name from description (first word before " - ")
        local selected_tool
        selected_tool=$(echo "${choice}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
        
        # Validate selection
        case "${selected_tool}" in
            automatic|auto)
                echo "auto"
                return 0
                ;;
            yad|zenity|kdialog)
                # Verify tool is still installed
                if command -v "${selected_tool}" >/dev/null 2>&1; then
                    echo "${selected_tool}"
                    return 0
                else
                    # Tool was uninstalled - show warning and re-prompt
                    show_info_dialog \
                        "Tool Not Available" \
                        "The selected tool '${selected_tool}' is not installed.\n\nPlease select another option." \
                        500 \
                        200
                    return 1  # Re-prompt
                fi
                ;;
            *)
                echo "auto"  # Default fallback
                return 0
                ;;
        esac
    else
        # Text mode
        echo "" >&2
        echo "=== Dialog Tool Selection ===" >&2
        echo "" >&2
        echo "Current setting: ${current_setting}" >&2
        if [ -n "${recommended_tool}" ]; then
            echo "Recommended: ${recommended_tool} (selected by automatic priority system)" >&2
        fi
        echo "" >&2
        echo "Note: If you don't make a selection, the system will use 'Automatic' mode," >&2
        echo "      which will select ${recommended_tool:-"the best available tool"} based on priority (YAD → Zenity → KDialog)." >&2
        echo "" >&2
        echo "Select dialog tool:" >&2
        local i=1
        for tool in "${installed_tools[@]}"; do
            local desc="${tool_descriptions[$((i-1))]}"
            echo "  ${i}) ${desc}" >&2
            i=$((i + 1))
        done
        echo "" >&2
        
        while true; do
            read -p "Select option [1-${#installed_tools[@]}, Enter for Automatic]: " choice >&2
            # If user just presses Enter, default to "auto"
            if [ -z "${choice}" ]; then
                echo "auto"
                return 0
            fi
            if [ "${choice}" -ge 1 ] && [ "${choice}" -le ${#installed_tools[@]} ]; then
                local selected_tool="${installed_tools[$((choice-1))]}"
                
                # Validate tool is installed (if not "auto")
                if [ "${selected_tool}" != "auto" ] && ! command -v "${selected_tool}" >/dev/null 2>&1; then
                    echo "Error: Tool '${selected_tool}' is not installed. Please select another option." >&2
                    continue
                fi
                
                echo "${selected_tool}"
                return 0
            else
                echo "Invalid option. Please enter 1-${#installed_tools[@]}." >&2
            fi
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

# Configure service mode (Desktop Mode vs Gaming Mode) - Enhancement #4
# Parameters:
#   $1: use_gui ("true" or "false")
# Returns: 0 on success, 1 on error, 2 if cancelled
# Side effects: Configures systemd service drop-in file for detected mode
configure_service_mode() {
    local use_gui="$1"
    
    # Source required modules
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local service_config_file="${script_dir}/service-config.sh"
    local display_detection_file="${script_dir}/display-detection.sh"
    
    if [ ! -f "${service_config_file}" ] || [ ! -f "${display_detection_file}" ]; then
        local error_msg="Service configuration modules not found.\n\nCannot configure service mode."
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Error" "${error_msg}" 500 200
        else
            echo "Error: ${error_msg}" >&2
        fi
        return 1
    fi
    
    # Source modules
    source "${display_detection_file}"
    source "${service_config_file}"
    
    # Detect current mode
    local detected_mode
    detected_mode=$(detect_system_mode)
    local current_mode
    current_mode=$(get_current_service_mode)
    
    # Build status message
    local status_msg="Current System Mode: ${detected_mode}"
    if [ "${detected_mode}" = "unknown" ]; then
        status_msg="${status_msg}\n(Warning: Could not detect system mode)"
    fi
    status_msg="${status_msg}\n\nCurrent Service Configuration: ${current_mode}"
    if [ "${current_mode}" = "none" ]; then
        status_msg="${status_msg}\n(Using default configuration)"
    fi
    
    if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
        # Show current status
        show_info_dialog "Service Mode Configuration" "${status_msg}" 500 250
        
        # Ask if user wants to reconfigure
        local reconfigure_msg="Do you want to reconfigure the service for the detected mode (${detected_mode})?"
        if [ "${detected_mode}" = "unknown" ]; then
            reconfigure_msg="Warning: Could not detect system mode.\n\nDo you want to configure the service anyway?"
        fi
        
        if ! show_question_dialog \
            "Reconfigure Service?" \
            "${reconfigure_msg}" \
            "Yes, Reconfigure" \
            "No, Cancel" \
            500 \
            250; then
            return 2  # User cancelled
        fi
    else
        # Text mode
        echo "" >&2
        echo "=== Service Mode Configuration ===" >&2
        echo "" >&2
        echo "${status_msg}" >&2
        echo "" >&2
        
        if [ "${detected_mode}" = "unknown" ]; then
            echo "Warning: Could not detect system mode." >&2
            echo "" >&2
            read -p "Do you want to configure the service anyway? [y/N]: " answer
            case "${answer}" in
                [Yy]*) ;;
                *) return 2 ;;
            esac
        else
            read -p "Reconfigure service for ${detected_mode} mode? [Y/n]: " answer
            case "${answer}" in
                [Nn]*) return 2 ;;
            esac
        fi
    fi
    
    # Configure service
    if [ "${detected_mode}" = "unknown" ]; then
        # Ask user to choose mode manually
        if [ "${use_gui}" = "true" ] && type show_list_dialog >/dev/null 2>&1; then
            local mode_choice
            mode_choice=$(show_list_dialog \
                "Select System Mode" \
                "Could not auto-detect system mode. Please select manually:" \
                500 \
                300 \
                "Desktop Mode (X11/KDE Plasma)" \
                "Gaming Mode (Wayland/gamescope)" \
                "Cancel")
            
            case "${mode_choice}" in
                "Desktop Mode (X11/KDE Plasma)")
                    detected_mode="desktop"
                    ;;
                "Gaming Mode (Wayland/gamescope)")
                    detected_mode="gaming"
                    ;;
                *)
                    return 2
                    ;;
            esac
        else
            # Text mode
            echo "" >&2
            echo "Could not auto-detect system mode. Please select:" >&2
            echo "  1) Desktop Mode (X11/KDE Plasma)" >&2
            echo "  2) Gaming Mode (Wayland/gamescope)" >&2
            echo "" >&2
            while true; do
                read -p "Select option [1-2]: " choice
                case "${choice}" in
                    1)
                        detected_mode="desktop"
                        break
                        ;;
                    2)
                        detected_mode="gaming"
                        break
                        ;;
                    *)
                        echo "Invalid option. Please enter 1 or 2." >&2
                        ;;
                esac
            done
        fi
    fi
    
    # Configure service for selected mode
    if configure_service_for_mode "${detected_mode}"; then
        local success_msg="Service successfully configured for ${detected_mode} mode."
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Success" "${success_msg}" 500 200
        else
            echo "" >&2
            echo "✓ ${success_msg}" >&2
            echo "" >&2
        fi
        return 0
    else
        local error_msg="Failed to configure service for ${detected_mode} mode."
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Error" "${error_msg}" 500 200
        else
            echo "Error: ${error_msg}" >&2
        fi
        return 1
    fi
}
