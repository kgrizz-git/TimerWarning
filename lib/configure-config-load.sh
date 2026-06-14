#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration file load (configure wizard)
# Sourced by configure-config.sh
###############################################################################

# Load existing configuration from file
# This function populates global arrays and sets global variables
# Arrays must be declared as global in the caller before calling this function
load_existing_config() {
    # Initialize with defaults
    declare -g check_interval="10"
    declare -g popup_size="medium"
    declare -g popup_size_mode="fixed"  # Enhancement #3: Size mode (fixed or display-based)
    declare -g popup_size_custom="50%x50%"  # Enhancement #3: Custom size (percentage or pixel format)
    declare -g popup_size_custom_absolute="1280x720"  # Enhancement #3: Absolute fallback for custom size
    declare -g popup_position="center"
    declare -g min_display_time="30"
    declare -g popup_immovable="true"
    declare -g popup_auto_close="true"
    declare -g configure_block_enabled="false"
    declare -g uninstall_protection_mode="difficult"
    declare -g pause_enabled="true"
    declare -g pause_duration="5"
    declare -g pause_cooldown_hours="24"
    declare -g dialog_tool="auto"
    declare -g config_lock_enabled="false"
    
    # Clear existing arrays (they should already be declared as global by caller)
    config_lines=()
    summary_lines=()
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        # No config file, use defaults (already set above)
        return 0
    fi
    
    # Read popup display frequency (Enhancement #30); fallback to CHECK_INTERVAL for migration
    local existing_freq
    existing_freq=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_DISPLAY_FREQUENCY}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${existing_freq}" ] || ! [[ "${existing_freq}" =~ ^[0-9]+$ ]]; then
        existing_freq=$(grep -E "^[[:space:]]*${CONFIG_KEY_CHECK_INTERVAL}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    fi
    if [ -n "${existing_freq}" ] && [[ "${existing_freq}" =~ ^[0-9]+$ ]] && [ "${existing_freq}" -ge 1 ] && [ "${existing_freq}" -le 60 ]; then
        declare -g check_interval="${existing_freq}"
    fi
    
    # Read popup size
    local existing_size
    existing_size=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_SIZE}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_size}" ]; then
        declare -g popup_size="${existing_size}"
    fi
    
    # Read popup size mode (Enhancement #3)
    local existing_size_mode
    existing_size_mode=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_SIZE_MODE}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ "${existing_size_mode}" = "display-based" ]; then
        declare -g popup_size_mode="display-based"
    else
        # Default to fixed for backward compatibility
        declare -g popup_size_mode="fixed"
    fi
    
    # Read popup custom size (Enhancement #3)
    local existing_custom_size
    existing_custom_size=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_SIZE_CUSTOM}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_custom_size}" ]; then
        declare -g popup_size_custom="${existing_custom_size}"
    fi
    
    # Read popup custom size absolute fallback (Enhancement #3)
    local existing_custom_absolute
    existing_custom_absolute=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_SIZE_CUSTOM_ABSOLUTE}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_custom_absolute}" ] && echo "${existing_custom_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
        declare -g popup_size_custom_absolute="${existing_custom_absolute}"
    fi
    
    # Read popup position
    local existing_position
    existing_position=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_POSITION}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_position}" ]; then
        declare -g popup_position="${existing_position}"
    fi
    
    # Read minimum display time
    local existing_time
    existing_time=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_MIN_DISPLAY_TIME}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_time}" ] && [[ "${existing_time}" =~ ^[0-9]+$ ]] && [ "${existing_time}" -ge 0 ] && [ "${existing_time}" -le 300 ]; then
        declare -g min_display_time="${existing_time}"
    fi
    
    # Read popup immovable setting
    local existing_immovable
    existing_immovable=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_IMMOVABLE}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_immovable}" ]; then
        if [ "${existing_immovable}" = "true" ] || [ "${existing_immovable}" = "1" ] || [ "${existing_immovable}" = "yes" ]; then
            declare -g popup_immovable="true"
        elif [ "${existing_immovable}" = "false" ] || [ "${existing_immovable}" = "0" ] || [ "${existing_immovable}" = "no" ]; then
            declare -g popup_immovable="false"
        fi
    fi
    
    # Read popup auto-close setting (Enhancement #15)
    local existing_auto_close
    existing_auto_close=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_AUTO_CLOSE}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_auto_close}" ]; then
        if [ "${existing_auto_close}" = "true" ] || [ "${existing_auto_close}" = "1" ] || [ "${existing_auto_close}" = "yes" ]; then
            declare -g popup_auto_close="true"
        elif [ "${existing_auto_close}" = "false" ] || [ "${existing_auto_close}" = "0" ] || [ "${existing_auto_close}" = "no" ]; then
            declare -g popup_auto_close="false"
        fi
    fi
    
    # Read configure block enabled setting (Enhancement #19)
    local existing_block_enabled
    existing_block_enabled=$(grep -E "^[[:space:]]*${CONFIG_KEY_CONFIGURE_BLOCK_ENABLED}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_block_enabled}" ]; then
        if [ "${existing_block_enabled}" = "true" ] || [ "${existing_block_enabled}" = "1" ] || [ "${existing_block_enabled}" = "yes" ]; then
            declare -g configure_block_enabled="true"
        elif [ "${existing_block_enabled}" = "false" ] || [ "${existing_block_enabled}" = "0" ] || [ "${existing_block_enabled}" = "no" ]; then
            declare -g configure_block_enabled="false"
        fi
    fi
    
    # Read uninstall protection mode setting (Enhancement #26)
    local existing_protection_mode
    existing_protection_mode=$(grep -E "^[[:space:]]*${CONFIG_KEY_UNINSTALL_PROTECTION_MODE}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    # Check for legacy UNINSTALL_BLOCK_ENABLED for backward compatibility
    if [ -z "${existing_protection_mode}" ]; then
        local legacy_block_enabled
        legacy_block_enabled=$(grep -E "^[[:space:]]*${CONFIG_KEY_UNINSTALL_BLOCK_ENABLED}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ "${legacy_block_enabled}" = "true" ] || [ "${legacy_block_enabled}" = "1" ] || [ "${legacy_block_enabled}" = "yes" ]; then
            # Legacy setting found - map to "difficult" (total block not available in Phase 1)
            declare -g uninstall_protection_mode="difficult"
        fi
    elif [ "${existing_protection_mode}" = "none" ]; then
        declare -g uninstall_protection_mode="none"
    elif [ "${existing_protection_mode}" = "difficult" ]; then
        declare -g uninstall_protection_mode="difficult"
    fi
    # If invalid value, keep default "difficult" (already set above)
    
    # Read pause enabled setting (Enhancement #21)
    local existing_pause_enabled
    existing_pause_enabled=$(grep -E "^[[:space:]]*${CONFIG_KEY_PAUSE_ENABLED}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_pause_enabled}" ]; then
        if [ "${existing_pause_enabled}" = "true" ] || [ "${existing_pause_enabled}" = "1" ] || [ "${existing_pause_enabled}" = "yes" ]; then
            declare -g pause_enabled="true"
        elif [ "${existing_pause_enabled}" = "false" ] || [ "${existing_pause_enabled}" = "0" ] || [ "${existing_pause_enabled}" = "no" ]; then
            declare -g pause_enabled="false"
        fi
    fi
    
    # Read pause duration setting (Enhancement #21)
    local existing_pause_duration
    existing_pause_duration=$(grep -E "^[[:space:]]*${CONFIG_KEY_PAUSE_DURATION}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_pause_duration}" ] && [[ "${existing_pause_duration}" =~ ^[0-9]+$ ]]; then
        if type pause_is_valid_duration_minutes >/dev/null 2>&1; then
            if pause_is_valid_duration_minutes "${existing_pause_duration}"; then
                declare -g pause_duration="${existing_pause_duration}"
            fi
        elif [ "${existing_pause_duration}" -eq 5 ] || [ "${existing_pause_duration}" -eq 10 ]; then
            declare -g pause_duration="${existing_pause_duration}"
        fi
    fi

    local existing_pause_cooldown_hours
    existing_pause_cooldown_hours=$(grep -E "^[[:space:]]*${CONFIG_KEY_PAUSE_COOLDOWN_HOURS}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_pause_cooldown_hours}" ] && [[ "${existing_pause_cooldown_hours}" =~ ^[0-9]+$ ]]; then
        if type pause_is_valid_cooldown_hours >/dev/null 2>&1; then
            if pause_is_valid_cooldown_hours "${existing_pause_cooldown_hours}"; then
                declare -g pause_cooldown_hours="${existing_pause_cooldown_hours}"
            fi
        elif [ "${existing_pause_cooldown_hours}" -eq 6 ] || [ "${existing_pause_cooldown_hours}" -eq 8 ] || \
             [ "${existing_pause_cooldown_hours}" -eq 12 ] || [ "${existing_pause_cooldown_hours}" -eq 24 ]; then
            declare -g pause_cooldown_hours="${existing_pause_cooldown_hours}"
        fi
    fi
    
    # Read dialog tool setting (Enhancement #25)
    local existing_dialog_tool
    existing_dialog_tool=$(grep -E "^[[:space:]]*${CONFIG_KEY_DIALOG_TOOL}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_dialog_tool}" ]; then
        # Validate value
        case "${existing_dialog_tool}" in
            auto|zenity|yad|kdialog)
                declare -g dialog_tool="${existing_dialog_tool}"
                ;;
        esac
    fi
    # If empty or invalid, keep default "auto" (already set above)
    
    # Read config lock enabled setting (Enhancement #18)
    local existing_config_lock_enabled
    existing_config_lock_enabled=$(grep -E "^[[:space:]]*${CONFIG_KEY_CONFIG_LOCK_ENABLED}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_config_lock_enabled}" ]; then
        if [ "${existing_config_lock_enabled}" = "true" ] || [ "${existing_config_lock_enabled}" = "1" ] || [ "${existing_config_lock_enabled}" = "yes" ]; then
            declare -g config_lock_enabled="true"
        elif [ "${existing_config_lock_enabled}" = "false" ] || [ "${existing_config_lock_enabled}" = "0" ] || [ "${existing_config_lock_enabled}" = "no" ]; then
            declare -g config_lock_enabled="false"
        fi
    fi
    # If invalid, keep default "false" (already set above)
    
    # Load day configurations
    for i in 0 1 2 3 4 5 6; do
        local day_var="${DAY_VARS[${i}]}"
        local day_name="${DAY_NAMES[${i}]}"
        
        # Check if day line exists in config file (even if empty)
        local day_line_exists
        day_line_exists=$(grep -E "^[[:space:]]*${day_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | tail -n1)
        
        if [ -n "${day_line_exists}" ]; then
            # Day line exists - extract value (may be empty if explicitly skipped)
            local day_config
            day_config=$(echo "${day_line_exists}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ -n "${day_config}" ]; then
                # Has a value - configured with restrictions
                config_lines[${i}]="${day_var}=${day_config}"
                summary_lines[${i}]="${day_name}: ${day_config}"
            else
                # Line exists but is empty - explicitly skipped, no restrictions
                config_lines[${i}]="${day_var}="
                summary_lines[${i}]="${day_name}: (no restrictions)"
            fi
        fi
        # If day line doesn't exist, don't add to array (will use defaults)
    done
    
    # Load lock hours configurations (Enhancement #19 Phase 2)
    # Initialize lock_hours_lines array if not already declared
    if [ -z "${lock_hours_lines+set}" ]; then
        declare -g -a lock_hours_lines=()
    else
        # Clear existing array
        lock_hours_lines=()
    fi
    
    for i in 0 1 2 3 4 5 6; do
        local day_var="${DAY_VARS[${i}]}"
        local lock_var="${CONFIG_KEY_PREFIX_CONFIG_LOCK_HOURS}_${day_var}"
        
        # Check if lock hours line exists in config file (even if empty)
        local lock_line_exists
        lock_line_exists=$(grep -E "^[[:space:]]*${lock_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | tail -n1)
        
        if [ -n "${lock_line_exists}" ]; then
            # Lock hours line exists - extract value (may be empty if explicitly disabled)
            local lock_config
            lock_config=$(echo "${lock_line_exists}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ -n "${lock_config}" ]; then
                # Has a value - configured with lock hours
                lock_hours_lines[${i}]="${lock_var}=${lock_config}"
            else
                # Line exists but is empty - explicitly disabled, no lock hours
                lock_hours_lines[${i}]="${lock_var}="
            fi
        fi
        # If lock hours line doesn't exist, don't add to array (not configured)
    done
    
    # Load uninstall lock hours configurations (Enhancement #26 Phase 2)
    # Initialize uninstall_lock_hours_lines array if not already declared
    if [ -z "${uninstall_lock_hours_lines+set}" ]; then
        declare -g -a uninstall_lock_hours_lines=()
    else
        # Clear existing array
        uninstall_lock_hours_lines=()
    fi
    
    for i in 0 1 2 3 4 5 6; do
        local day_var="${DAY_VARS[${i}]}"
        local uninstall_lock_var="${CONFIG_KEY_PREFIX_UNINSTALL_LOCK_HOURS}_${day_var}"
        
        # Check if uninstall lock hours line exists in config file (even if empty)
        local uninstall_lock_line_exists
        uninstall_lock_line_exists=$(grep -E "^[[:space:]]*${uninstall_lock_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | tail -n1)
        
        if [ -n "${uninstall_lock_line_exists}" ]; then
            # Uninstall lock hours line exists - extract value (may be empty if explicitly disabled)
            local uninstall_lock_config
            uninstall_lock_config=$(echo "${uninstall_lock_line_exists}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ -n "${uninstall_lock_config}" ]; then
                # Has a value - configured with uninstall lock hours
                uninstall_lock_hours_lines[${i}]="${uninstall_lock_var}=${uninstall_lock_config}"
            else
                # Line exists but is empty - explicitly disabled, no uninstall lock hours
                uninstall_lock_hours_lines[${i}]="${uninstall_lock_var}="
            fi
        fi
        # If uninstall lock hours line doesn't exist, don't add to array (not configured)
    done
}
