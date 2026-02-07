#!/bin/bash

###############################################################################
# Sleep Warning System - Feature Toggle Input Collection Module
#
# This module provides feature toggle and security settings user input
# collection functions for the configuration wizard, supporting both GUI
# (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - get_configure_block_enabled_config() - Get configure block enabled setting (Enhancement #19)
# - get_security_settings_config() - Get combined security settings (script blocking & config locking)
# - get_config_lock_enabled_config() - Get config lock enabled setting (Enhancement #18)
# - get_pause_enabled_config() - Get pause enabled setting
# - get_pause_duration_config() - Get pause duration
# - get_pause_once_per_day_config() - Get pause once per day setting
# - get_uninstall_protection_mode_config() - Get uninstall protection mode
# - get_dialog_tool_selection() - Get dialog tool selection (Enhancement #25)
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-ui.sh (for confirm_cancel)
###############################################################################

###############################################################################
# Internal helpers
###############################################################################

# Read a boolean-like config value from CONFIG_FILE and normalize it to "true" or
# "false". If the key is not present (or doesn't parse), returns the provided
# default ("true" or "false").
#
# Args:
# - $1: config key (e.g. "CONFIG_LOCK_ENABLED")
# - $2: default value ("true" or "false")
_get_existing_bool_setting_from_config() {
    local key="$1"
    local default_value="$2"

    if [ -z "${key}" ]; then
        echo "${default_value}"
        return 0
    fi

    if [ -f "${CONFIG_FILE}" ]; then
        local existing_value
        existing_value=$(grep -E "^[[:space:]]*${key}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_value}" ]; then
            if [ "${existing_value}" = "true" ] || [ "${existing_value}" = "1" ] || [ "${existing_value}" = "yes" ]; then
                echo "true"
                return 0
            elif [ "${existing_value}" = "false" ] || [ "${existing_value}" = "0" ] || [ "${existing_value}" = "no" ]; then
                echo "false"
                return 0
            fi
        fi
    fi

    echo "${default_value}"
    return 0
}

# Standard GUI prompt for a "true/false" setting using show_list_dialog.
# Behavior is intentionally strict: it only accepts a selection when the dialog
# returns exit code 0 AND a non-empty selection (matching existing call sites).
#
# Args:
# - $1: use_gui ("true"/"false") (passed through to confirm_cancel)
# - $2: title
# - $3: message
# - $4: width
# - $5: height
_prompt_bool_setting_gui_strict() {
    local use_gui="$1"
    local title="$2"
    local message="$3"
    local width="$4"
    local height="$5"

    while true; do
        local result
        result=$(show_list_dialog "${title}" "${message}" "${width}" "${height}" "true" "false")
        local exit_code=$?

        if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
            echo "${result}"
            return 0
        fi

        if confirm_cancel "${use_gui}"; then
            echo "CANCELLED"
            return 2
        fi
    done
}

get_configure_block_enabled_config() {
    local use_gui="$1"
    local default_block_enabled
    default_block_enabled="$(_get_existing_bool_setting_from_config "CONFIGURE_BLOCK_ENABLED" "false")"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        _prompt_bool_setting_gui_strict \
            "${use_gui}" \
            "Sleep Warning Configuration - Block Configuration During Restricted Hours" \
            "Block configure.sh and manage.sh during restricted hours?\n\nWhen enabled, the configuration and management scripts will be blocked from running during restricted hours to prevent circumventing restrictions.\n\nNote: This must be enabled for 'Additional Configuration Block Hours' to take effect.\n\nCurrent setting: ${default_block_enabled}" \
            650 \
            400
        return $?
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

get_config_lock_enabled_config() {
    local use_gui="$1"
    local default_lock_enabled
    default_lock_enabled="$(_get_existing_bool_setting_from_config "CONFIG_LOCK_ENABLED" "false")"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        _prompt_bool_setting_gui_strict \
            "${use_gui}" \
            "Sleep Warning Configuration - Config File Locking" \
            "Enable config file locking during restricted hours?\n\nWhen enabled, the config file and directory are made read-only during restricted hours and any configured lock hours to prevent users from circumventing restrictions by changing settings.\n\nNote: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week (> $(get_threshold_warn_description)) for safety.\n\nCurrent setting: ${default_lock_enabled}" \
            700 \
            450
        return $?
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
                "Select pause duration:\n\nCurrent setting: ${default_duration} minutes\n\nOptions:\n- 5 minutes - Shorter pause period\n- 10 minutes - Longer pause period\n\nThe selected duration determines how long warning popups are paused when user clicks pause button." \
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
            
            # Call dialog and capture result (and exit code for reference)
            local temp_result
            temp_result=$(show_list_dialog \
                "Sleep Warning Configuration - Uninstall Protection" \
                "Choose protection mode for uninstall.sh during restricted hours:\n\nCurrent setting: ${mode_display}\n\nOptions:\n- none - No protection, uninstall works normally during restricted hours\n- difficult - Difficult uninstall, requires confirmation phrase + 10 arithmetic questions\n\nDifficult mode allows legitimate uninstalls while deterring impulsive ones.\nIt requires significant effort and cognitive engagement.\n\nNote: Total block mode may be considered as future phase." \
                700 \
                500 \
                "none" "difficult")
            local exit_code=$?
            mode_result="${temp_result}"
            
            # Trim whitespace and newlines from result (only if result exists)
            if [ -n "${mode_result}" ]; then
                mode_result=$(printf '%s' "${mode_result}" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi
            
            # Normalize to lowercase for comparison (dialog may return different casing)
            local mode_result_lower
            mode_result_lower=$(echo "${mode_result}" | tr '[:upper:]' '[:lower:]')
            
            # If we have a valid selection, accept it regardless of exit code (some dialog tools
            # return non-zero even on OK). Only treat as cancel when result is empty or invalid.
            if [ "${mode_result_lower}" = "none" ] || [ "${mode_result_lower}" = "difficult" ]; then
                protection_mode="${mode_result_lower}"
                echo "${protection_mode}"
                return 0
            fi
            
            # No valid result: user cancelled or dialog returned empty. Ask if they want to
            # cancel the whole configuration or try again.
            if confirm_cancel "${use_gui}"; then
                echo "CANCELLED"
                return 2  # Special return code for cancellation
            else
                continue  # User wants to continue, re-prompt
            fi
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

get_dialog_tool_selection() {
    local use_gui="$1"
    
    # Get current setting from config file (using function from config.sh)
    # Note: configure-input-features.sh is sourced by configure.sh, which sources config.sh
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

