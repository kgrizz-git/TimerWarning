#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration File Operations Module
#
# This module handles all configuration file operations including reading,
# writing, and preserving user customizations. It also manages systemd timer
# file updates.
#
# Functions:
# - load_existing_config()   - Load configuration from file
# - write_config()           - Write configuration file
# - update_timer_file()      - Update systemd timer file with new interval
#
# Dependencies:
# - configure-core.sh (for CONFIG_DIR, CONFIG_FILE, TIMER_FILE, SERVICE_NAME,
#                      DAY_NAMES, DAY_VARS, minutes_to_oncalendar)
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
    declare -g dialog_tool="auto"
    declare -g config_lock_enabled="false"
    
    # Clear existing arrays (they should already be declared as global by caller)
    config_lines=()
    summary_lines=()
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        # No config file, use defaults (already set above)
        return 0
    fi
    
    # Read check interval
    local existing_interval
    existing_interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_interval}" ] && [[ "${existing_interval}" =~ ^[0-9]+$ ]] && [ "${existing_interval}" -ge 1 ] && [ "${existing_interval}" -le 60 ]; then
        declare -g check_interval="${existing_interval}"
    fi
    
    # Read popup size
    local existing_size
    existing_size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_size}" ]; then
        declare -g popup_size="${existing_size}"
    fi
    
    # Read popup size mode (Enhancement #3)
    local existing_size_mode
    existing_size_mode=$(grep -E "^[[:space:]]*POPUP_SIZE_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ "${existing_size_mode}" = "display-based" ]; then
        declare -g popup_size_mode="display-based"
    else
        # Default to fixed for backward compatibility
        declare -g popup_size_mode="fixed"
    fi
    
    # Read popup custom size (Enhancement #3)
    local existing_custom_size
    existing_custom_size=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_custom_size}" ]; then
        declare -g popup_size_custom="${existing_custom_size}"
    fi
    
    # Read popup custom size absolute fallback (Enhancement #3)
    local existing_custom_absolute
    existing_custom_absolute=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM_ABSOLUTE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_custom_absolute}" ] && echo "${existing_custom_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
        declare -g popup_size_custom_absolute="${existing_custom_absolute}"
    fi
    
    # Read popup position
    local existing_position
    existing_position=$(grep -E "^[[:space:]]*POPUP_POSITION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_position}" ]; then
        declare -g popup_position="${existing_position}"
    fi
    
    # Read minimum display time
    local existing_time
    existing_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_time}" ] && [[ "${existing_time}" =~ ^[0-9]+$ ]] && [ "${existing_time}" -ge 0 ] && [ "${existing_time}" -le 300 ]; then
        declare -g min_display_time="${existing_time}"
    fi
    
    # Read popup immovable setting
    local existing_immovable
    existing_immovable=$(grep -E "^[[:space:]]*POPUP_IMMOVABLE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_immovable}" ]; then
        if [ "${existing_immovable}" = "true" ] || [ "${existing_immovable}" = "1" ] || [ "${existing_immovable}" = "yes" ]; then
            declare -g popup_immovable="true"
        elif [ "${existing_immovable}" = "false" ] || [ "${existing_immovable}" = "0" ] || [ "${existing_immovable}" = "no" ]; then
            declare -g popup_immovable="false"
        fi
    fi
    
    # Read popup auto-close setting (Enhancement #15)
    local existing_auto_close
    existing_auto_close=$(grep -E "^[[:space:]]*POPUP_AUTO_CLOSE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_auto_close}" ]; then
        if [ "${existing_auto_close}" = "true" ] || [ "${existing_auto_close}" = "1" ] || [ "${existing_auto_close}" = "yes" ]; then
            declare -g popup_auto_close="true"
        elif [ "${existing_auto_close}" = "false" ] || [ "${existing_auto_close}" = "0" ] || [ "${existing_auto_close}" = "no" ]; then
            declare -g popup_auto_close="false"
        fi
    fi
    
    # Read configure block enabled setting (Enhancement #19)
    local existing_block_enabled
    existing_block_enabled=$(grep -E "^[[:space:]]*CONFIGURE_BLOCK_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_block_enabled}" ]; then
        if [ "${existing_block_enabled}" = "true" ] || [ "${existing_block_enabled}" = "1" ] || [ "${existing_block_enabled}" = "yes" ]; then
            declare -g configure_block_enabled="true"
        elif [ "${existing_block_enabled}" = "false" ] || [ "${existing_block_enabled}" = "0" ] || [ "${existing_block_enabled}" = "no" ]; then
            declare -g configure_block_enabled="false"
        fi
    fi
    
    # Read uninstall protection mode setting (Enhancement #26)
    local existing_protection_mode
    existing_protection_mode=$(grep -E "^[[:space:]]*UNINSTALL_PROTECTION_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    # Check for legacy UNINSTALL_BLOCK_ENABLED for backward compatibility
    if [ -z "${existing_protection_mode}" ]; then
        local legacy_block_enabled
        legacy_block_enabled=$(grep -E "^[[:space:]]*UNINSTALL_BLOCK_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
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
    existing_pause_enabled=$(grep -E "^[[:space:]]*PAUSE_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_pause_enabled}" ]; then
        if [ "${existing_pause_enabled}" = "true" ] || [ "${existing_pause_enabled}" = "1" ] || [ "${existing_pause_enabled}" = "yes" ]; then
            declare -g pause_enabled="true"
        elif [ "${existing_pause_enabled}" = "false" ] || [ "${existing_pause_enabled}" = "0" ] || [ "${existing_pause_enabled}" = "no" ]; then
            declare -g pause_enabled="false"
        fi
    fi
    
    # Read pause duration setting (Enhancement #21)
    local existing_pause_duration
    existing_pause_duration=$(grep -E "^[[:space:]]*PAUSE_DURATION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_pause_duration}" ] && [[ "${existing_pause_duration}" =~ ^[0-9]+$ ]]; then
        if [ "${existing_pause_duration}" -eq 5 ] || [ "${existing_pause_duration}" -eq 10 ]; then
            declare -g pause_duration="${existing_pause_duration}"
        fi
    fi
    
    # Read dialog tool setting (Enhancement #25)
    local existing_dialog_tool
    existing_dialog_tool=$(grep -E "^[[:space:]]*DIALOG_TOOL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
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
    existing_config_lock_enabled=$(grep -E "^[[:space:]]*CONFIG_LOCK_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
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
        day_line_exists=$(grep -E "^[[:space:]]*${day_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
        
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
        local lock_var="CONFIG_LOCK_HOURS_${day_var}"
        
        # Check if lock hours line exists in config file (even if empty)
        local lock_line_exists
        lock_line_exists=$(grep -E "^[[:space:]]*${lock_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
        
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
        local uninstall_lock_var="UNINSTALL_LOCK_HOURS_${day_var}"
        
        # Check if uninstall lock hours line exists in config file (even if empty)
        local uninstall_lock_line_exists
        uninstall_lock_line_exists=$(grep -E "^[[:space:]]*${uninstall_lock_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
        
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

# Update systemd timer file with new interval
update_timer_file() {
    local interval="$1"
    
    # Check if timer file exists
    if [ ! -f "${TIMER_FILE}" ]; then
        # Timer not installed yet, skip
        return 0
    fi
    
    # Convert interval to OnCalendar format
    local oncalendar
    oncalendar=$(minutes_to_oncalendar "${interval}")
    
    # Create backup of timer file
    local backup_file="${TIMER_FILE}.bak"
    cp "${TIMER_FILE}" "${backup_file}" 2>/dev/null
    
    # Update timer file
    local temp_file
    temp_file=$(mktemp)
    
    {
        echo "[Unit]"
        echo "Description=Sleep Warning System Timer - Triggers warning check every ${interval} minutes"
        echo "Documentation=man:systemd.timer(5)"
        echo "Requires=${SERVICE_NAME}.service"
        echo ""
        echo "[Timer]"
        echo "# Run every ${interval} minutes"
        echo "OnCalendar=${oncalendar}"
        echo "# Start immediately if missed"
        echo "Persistent=true"
        echo "# Timer accuracy (can be adjusted)"
        echo "AccuracySec=1min"
        echo ""
        echo "[Install]"
        echo "WantedBy=timers.target"
    } > "${temp_file}"
    
    # Replace timer file
    if mv "${temp_file}" "${TIMER_FILE}" 2>/dev/null; then
        # Always reload systemd daemon to pick up timer file changes
        systemctl --user daemon-reload >/dev/null 2>&1
        
        # Restart timer if it's active to pick up the new schedule
        if systemctl --user is-active "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
            systemctl --user restart "${SERVICE_NAME}.timer" >/dev/null 2>&1
        fi
        rm -f "${backup_file}" 2>/dev/null
        return 0
    else
        # Restore backup on failure
        mv "${backup_file}" "${TIMER_FILE}" 2>/dev/null
        return 1
    fi
}

# Write configuration file
# Parameters:
#   $1-$7: Standard configuration parameters (check_interval, popup_size, popup_position, min_display_time, popup_immovable, popup_auto_close, configure_block_enabled)
#   $8: Uninstall protection mode (uninstall_protection_mode)
#   $9-$10: Pause settings (pause_enabled, pause_duration) - Enhancement #21
#   $11: Dialog tool (dialog_tool) - Enhancement #25
#   $12: Config lock enabled (config_lock_enabled) - Enhancement #18
#   $13: Popup size mode (popup_size_mode) - Enhancement #3: fixed or display-based
#   $14: Popup custom size (popup_size_custom) - Enhancement #3: Custom size (percentage or pixel format)
#   $15: Popup custom size absolute (popup_size_custom_absolute) - Enhancement #3: Absolute fallback
#   $16+: config_lines array (7 day configurations: Sunday-Saturday)
#   After config_lines: lock_hours_lines array (optional, Enhancement #19 Phase 2)
#   After lock_hours_lines: uninstall_lock_hours_lines array (optional, Enhancement #26 Phase 2)
#   Optional (if override flags present, last 4 arguments): 
#     Fourth-to-last: popup_size_overridden ("true" if popup_size was restricted due to high restrictions)
#     Third-to-last: configure_block_overridden ("true" if configure_block_enabled was disabled due to high restrictions)
#     Second-to-last: lock_hours_cleared ("true" if lock_hours_lines were cleared due to high restrictions)
#     Last: uninstall_lock_hours_cleared ("true" if uninstall_lock_hours_lines were cleared due to high restrictions)
# Note: lock_hours_lines is detected by checking for "CONFIG_LOCK_HOURS_" prefix in arguments
# Note: uninstall_lock_hours_lines is detected by checking for "UNINSTALL_LOCK_HOURS_" prefix in arguments
# Note: If pause settings are not provided (for backward compatibility), defaults will be used
_write_config_header() {
    local check_interval="$1"
    local popup_size="$2"
    local popup_position="$3"
    local min_display_time="$4"
    local popup_immovable="$5"
    local popup_auto_close="$6"
    local configure_block_enabled="$7"
    local uninstall_protection_mode="$8"
    local pause_enabled="$9"
    local pause_duration="${10}"
    local dialog_tool="${11}"
    local config_lock_enabled="${12}"
    local popup_size_mode="${13}"
    local popup_size_custom="${14}"
    local popup_size_custom_absolute="${15}"
    local popup_size_overridden="${16}"
    local configure_block_overridden="${17}"

    # Standard header
    echo "# Sleep Warning Configuration"
    echo "# Format: DAY=START_HOUR-END_HOUR"
    echo "# Hours are in 24-hour format (0-23)"
    echo "# Multiple ranges can be specified per day (comma-separated)"
    echo "# Leave a day empty or omit it to have no restrictions for that day"
    echo "#"
    echo "# CHECK_INTERVAL: How often to check for restricted hours (in minutes)"
    echo "# Default: 10 minutes"
    echo "# Minimum: 1 minute"
    echo "# Maximum: 60 minutes"
    echo "CHECK_INTERVAL=${check_interval}"
    echo "#"
    echo "# POPUP_SIZE: Size of warning popup (xsmall, small, medium, large, xlarge, max, custom, or custom WIDTHxHEIGHT/WIDTH%xHEIGHT%)"
    echo "# Default: medium"
    echo "# Enhancement #3: New sizes available: xsmall, xlarge, max. Custom sizes support percentage format (WIDTH%xHEIGHT%)"
    echo "POPUP_SIZE=${popup_size}"
    # Add comment if popup size was restricted due to high restrictions
    if [ "${popup_size_overridden}" = "true" ]; then
        echo "# POPUP_SIZE has been restricted to xsmall/small/medium only because restrictions exceed 16 hours/day."
        echo "# This prevents overly intrusive popups when user has very limited unrestricted time."
    fi
    echo "#"
    echo "# POPUP_SIZE_MODE: Window size calculation mode (Enhancement #3)"
    echo "# Options: fixed (absolute pixel sizes) or display-based (percentage-based)"
    echo "# Default: fixed (for backward compatibility)"
    echo "POPUP_SIZE_MODE=${popup_size_mode}"
    echo "#"
    echo "# POPUP_SIZE_CUSTOM: Custom size configuration (Enhancement #3)"
    echo "# Format: PERCENT%xPERCENT% (e.g., 50%x50%) or WIDTHxHEIGHT (absolute pixels)"
    echo "# If percentage format, used in display-based mode; if pixel format, used as absolute fallback"
    echo "# Default: 50%x50%"
    echo "POPUP_SIZE_CUSTOM=${popup_size_custom}"
    echo "#"
    echo "# POPUP_SIZE_CUSTOM_ABSOLUTE: Absolute pixel fallback for custom size (Enhancement #3)"
    echo "# Used when resolution cannot be detected and custom size is percentage-based"
    echo "# Default: 1280x720 (50% of 2560x1440)"
    echo "POPUP_SIZE_CUSTOM_ABSOLUTE=${popup_size_custom_absolute}"
    echo "#"
    echo "# POPUP_POSITION: Position of warning popup on screen"
    echo "# Default: center"
    echo "POPUP_POSITION=${popup_position}"
    echo "#"
    echo "# POPUP_MIN_DISPLAY_TIME: Minimum time popup must be visible before it can be closed (in seconds)"
    echo "# Default: 30 seconds"
    echo "POPUP_MIN_DISPLAY_TIME=${min_display_time}"
    echo "#"
    echo "# POPUP_IMMOVABLE: Prevent popup window from being moved during minimum display time"
    echo "# Default: true"
    echo "POPUP_IMMOVABLE=${popup_immovable}"
    echo "#"
    echo "# POPUP_AUTO_CLOSE: Automatically close popup window 10 seconds after minimum display time completes"
    echo "# Default: true (enabled by default)"
    echo "# Options: true, false"
    echo "# Auto-close happens 10 seconds after minimum display time completes (additional time, not total time)"
    echo "# If minimum display time is 0, auto-close happens after 10 seconds"
    echo "# Auto-close time is fixed at 10 seconds (not configurable)"
    echo "# This is Enhancement #15 (Auto-Close Popup Window)"
    echo "POPUP_AUTO_CLOSE=${popup_auto_close}"
    echo "#"
    echo "# CONFIGURE_BLOCK_ENABLED: Prevent configure.sh and manage.sh from running during restricted hours"
    echo "# Default: false (opt-in feature)"
    echo "# When enabled, configuration and management scripts are blocked during restricted hours"
    echo "# to prevent users from circumventing restrictions by changing settings"
    echo "# This is Enhancement #19 (Prevent configure.sh and manage.sh Execution)"
    echo "CONFIGURE_BLOCK_ENABLED=${configure_block_enabled}"
    # Add comment if configure block was disabled due to high restrictions
    if [ "${configure_block_overridden}" = "true" ]; then
        echo "# CONFIGURE_BLOCK_ENABLED has been disabled because restrictions exceed 16 hours/day."
        echo "# This prevents accidental lockout when user has very limited unrestricted time."
    fi
    echo "#"
    echo "# UNINSTALL_PROTECTION_MODE: Protection mode for uninstall.sh during restricted hours"
    echo "# Default: difficult"
    echo "# Options:"
    echo "#   none - No protection, uninstall works normally during restricted hours"
    echo "#   difficult - Difficult uninstall, requires confirmation phrase + 10 arithmetic questions"
    echo "# When enabled, uninstall.sh requires verification during restricted hours to prevent"
    echo "# users from circumventing restrictions by uninstalling the system."
    echo "# This is Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)"
    echo "# Note: Total block mode may be considered as future phase"
    echo "UNINSTALL_PROTECTION_MODE=${uninstall_protection_mode}"
    echo "#"
    echo "# PAUSE_ENABLED: Enable/disable pause feature for warning popups"
    echo "# Default: true"
    echo "# When enabled, users can pause warning popups for a short period (5 or 10 minutes)"
    echo "# directly from the warning popup window. Pause only suppresses popups, not restrictions."
    echo "# This is Enhancement #21 (One-Time Pause Feature)"
    echo "PAUSE_ENABLED=${pause_enabled}"
    echo "#"
    echo "# PAUSE_DURATION: Duration of pause in minutes (5 or 10)"
    echo "# Default: 5 minutes"
    echo "# This controls how long warning popups are paused when user clicks pause button"
    echo "# This is Enhancement #21 (One-Time Pause Feature)"
    echo "# Note: Pause is ALWAYS limited to once per day (not configurable)"
    echo "PAUSE_DURATION=${pause_duration}"
    echo "#"
    echo "# DIALOG_TOOL: Dialog tool selection for popup windows"
    echo "# Default: auto (uses automatic priority: YAD → Zenity → KDialog)"
    echo "# Options:"
    echo "#   auto - Automatic selection (recommended, uses priority system)"
    echo "#   zenity - Force use of zenity (if installed)"
    echo "#   yad - Force use of yad (if installed)"
    echo "#   kdialog - Force use of kdialog (if installed)"
    echo "# If selected tool is not installed, system falls back to automatic selection"
    echo "# This is Enhancement #25 (User-Selectable Dialog Tool)"
    echo "DIALOG_TOOL=${dialog_tool}"
    echo "#"
    echo "# CONFIG_LOCK_ENABLED: Enable/disable config file locking during restricted hours"
    echo "# Default: false (opt-in feature)"
    echo "# When enabled, the config file and directory are made read-only during restricted hours"
    echo "# and any configured lock hours to prevent users from circumventing restrictions"
    echo "# by changing settings. This is a deterrence mechanism, not true security."
    echo "# This is Enhancement #18 (Config File Locking During Restricted Hours)"
    echo "# Note: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week (> $(get_threshold_warn_description)) (Enhancement #22)"
    echo "CONFIG_LOCK_ENABLED=${config_lock_enabled}"
    echo "#"
    echo "# This file was generated by the configuration wizard on $(date)"

    echo ""
}

_write_restrictions_section() {
    local -n config_lines_ref="$1"

    # Write configuration lines in calendar order (Sun-Sat, indices 0-6)
    for day_index in 0 1 2 3 4 5 6; do
        if [ -n "${config_lines_ref[${day_index}]}" ]; then
            # Write the line (includes empty values for explicitly skipped days)
            echo "${config_lines_ref[${day_index}]}"
        fi
    done
}

_write_lock_hours_section() {
    local -n lock_hours_lines_ref="$1"
    local lock_hours_cleared="$2"

    # Only write section header if there are any lock hours configured
    local has_lock_hours=false
    for day_index in 0 1 2 3 4 5 6; do
        if [ -n "${lock_hours_lines_ref[${day_index}]}" ]; then
            has_lock_hours=true
            break
        fi
    done

    if [ "${has_lock_hours}" = "true" ]; then
        echo ""
        echo "# CONFIG_LOCK_HOURS: Additional hours for blocking configure.sh and manage.sh (separate from restriction hours)"
        echo "# Format: CONFIG_LOCK_HOURS_DAYNAME=START_HOUR-END_HOUR"
        echo "# Hours are in 24-hour format (0-23)"
        echo "# Multiple ranges can be specified per day (comma-separated)"
        echo "# Overnight ranges are supported (e.g., 23-6 spans midnight)"
        echo "# Leave a day empty or omit it to have no lock hours for that day"
        echo "# When CONFIGURE_BLOCK_ENABLED=true, scripts are blocked during restriction hours OR lock hours"
        echo "# This is Enhancement #19 Phase 2 (Additional Configurable Lock Hours)"
        # Add comment if lock hours were cleared due to high restrictions
        if [ "${lock_hours_cleared}" = "true" ]; then
            echo "# CONFIG_LOCK_HOURS have been cleared because combined restrictions exceed 16 hours/day."
            echo "# This prevents accidental lockout when user has very limited unrestricted time."
        fi

        # Write lock hours lines in calendar order (Sun-Sat, indices 0-6)
        for day_index in 0 1 2 3 4 5 6; do
            if [ -n "${lock_hours_lines_ref[${day_index}]}" ]; then
                # Write the line (includes empty values for explicitly disabled days)
                echo "${lock_hours_lines_ref[${day_index}]}"
            fi
        done
    fi
}

_write_uninstall_lock_hours_section() {
    local -n uninstall_lock_hours_lines_ref="$1"
    local uninstall_lock_hours_cleared="$2"

    # Only write section header if there are any uninstall lock hours configured
    local has_uninstall_lock_hours=false
    for day_index in 0 1 2 3 4 5 6; do
        if [ -n "${uninstall_lock_hours_lines_ref[${day_index}]}" ]; then
            has_uninstall_lock_hours=true
            break
        fi
    done

    if [ "${has_uninstall_lock_hours}" = "true" ]; then
        echo ""
        echo "# UNINSTALL_LOCK_HOURS: Additional hours for difficult uninstall verification (separate from restriction hours and configure.sh lock hours)"
        echo "# Format: UNINSTALL_LOCK_HOURS_DAYNAME=START_HOUR-END_HOUR"
        echo "# Hours are in 24-hour format (0-23)"
        echo "# Multiple ranges can be specified per day (comma-separated)"
        echo "# Overnight ranges are supported (e.g., 23-6 spans midnight)"
        echo "# Leave a day empty or omit it to have no uninstall lock hours for that day"
        echo "# When UNINSTALL_PROTECTION_MODE=difficult, difficult uninstall verification applies during restriction hours OR uninstall lock hours"
        echo "# This is Enhancement #26 Phase 2 (Additional Uninstall Lock Hours)"
        echo "# WARNING: Additional uninstall lock hours increase the risk of preventing legitimate uninstall needs"
        # Add comment if uninstall lock hours were cleared due to high restrictions
        if [ "${uninstall_lock_hours_cleared}" = "true" ]; then
            echo "# UNINSTALL_LOCK_HOURS have been cleared because combined restrictions exceed 16 hours/day."
            echo "# This prevents accidental lockout when user has very limited unrestricted time."
        fi

        # Write uninstall lock hours lines in calendar order (Sun-Sat, indices 0-6)
        for day_index in 0 1 2 3 4 5 6; do
            if [ -n "${uninstall_lock_hours_lines_ref[${day_index}]}" ]; then
                # Write the line (includes empty values for explicitly disabled days)
                echo "${uninstall_lock_hours_lines_ref[${day_index}]}"
            fi
        done
    fi
}

write_config() {
    local check_interval="$1"
    local popup_size="$2"
    local popup_position="$3"
    local min_display_time="$4"
    local popup_immovable="$5"
    local popup_auto_close="$6"
    local configure_block_enabled="$7"
    local uninstall_protection_mode="$8"
    local pause_enabled="${9:-true}"
    local pause_duration="${10:-5}"
    local dialog_tool="${11:-auto}"
    local config_lock_enabled="${12:-false}"
    local popup_size_mode="${13:-fixed}"  # Enhancement #3: Size mode (fixed or display-based)
    local popup_size_custom="${14:-50%x50%}"  # Enhancement #3: Custom size
    local popup_size_custom_absolute="${15:-1280x720}"  # Enhancement #3: Absolute fallback
    shift 15
    
    # Extract config_lines array, optional lock_hours_lines array, optional uninstall_lock_hours_lines array, and optional override flags
    # config_lines values are always "DAYVAR=RANGE" format (e.g., "MONDAY=0-5")
    # lock_hours_lines values are always "CONFIG_LOCK_HOURS_DAYNAME=RANGE" format (e.g., "CONFIG_LOCK_HOURS_MONDAY=9-17")
    # uninstall_lock_hours_lines values are always "UNINSTALL_LOCK_HOURS_DAYNAME=RANGE" format (e.g., "UNINSTALL_LOCK_HOURS_MONDAY=9-17")
    # Override flags are always "true" or empty string, and never contain "="
    local popup_size_overridden=""
    local configure_block_overridden=""
    local lock_hours_cleared=""
    local uninstall_lock_hours_cleared=""
    local config_lines=()
    local lock_hours_lines=()
    local uninstall_lock_hours_lines=()
    local all_args=("$@")
    local arg_count=${#all_args[@]}
    
    # Find where lock_hours_lines start (first argument with "CONFIG_LOCK_HOURS_" prefix)
    local lock_hours_start=-1
    # Find where uninstall_lock_hours_lines start (first argument with "UNINSTALL_LOCK_HOURS_" prefix)
    local uninstall_lock_hours_start=-1
    local override_flags_start=-1
    
    for i in "${!all_args[@]}"; do
        if [[ "${all_args[${i}]}" =~ ^CONFIG_LOCK_HOURS_ ]]; then
            if [ ${lock_hours_start} -eq -1 ]; then
                lock_hours_start=${i}
            fi
        elif [[ "${all_args[${i}]}" =~ ^UNINSTALL_LOCK_HOURS_ ]]; then
            if [ ${uninstall_lock_hours_start} -eq -1 ]; then
                uninstall_lock_hours_start=${i}
            fi
        fi
    done
    
    # Find where override flags start (last 2-4 arguments that are "true" or empty and don't contain "=")
    # Check for 4 flags first (new format), then fall back to 2 flags (old format for backward compatibility)
    if [ $arg_count -ge 4 ]; then
        local fourth_to_last="${all_args[$((arg_count - 4))]}"
        local third_to_last="${all_args[$((arg_count - 3))]}"
        local second_to_last="${all_args[$((arg_count - 2))]}"
        local last="${all_args[$((arg_count - 1))]}"
        
        if ([ -z "${fourth_to_last}" ] || [ "${fourth_to_last}" = "true" ]) && \
           ([ -z "${third_to_last}" ] || [ "${third_to_last}" = "true" ]) && \
           ([ -z "${second_to_last}" ] || [ "${second_to_last}" = "true" ]) && \
           ([ -z "${last}" ] || [ "${last}" = "true" ]) && \
           [[ ! "${fourth_to_last}" =~ = ]] && [[ ! "${third_to_last}" =~ = ]] && \
           [[ ! "${second_to_last}" =~ = ]] && [[ ! "${last}" =~ = ]]; then
            override_flags_start=$((arg_count - 4))
        elif [ $arg_count -ge 2 ]; then
            # Fall back to 2 flags (backward compatibility)
            if ([ -z "${second_to_last}" ] || [ "${second_to_last}" = "true" ]) && \
               ([ -z "${last}" ] || [ "${last}" = "true" ]) && \
               [[ ! "${second_to_last}" =~ = ]] && [[ ! "${last}" =~ = ]]; then
                override_flags_start=$((arg_count - 2))
            fi
        fi
    elif [ $arg_count -ge 2 ]; then
        # Only 2-3 arguments, check for 2 flags (backward compatibility)
        local second_to_last="${all_args[$((arg_count - 2))]}"
        local last="${all_args[$((arg_count - 1))]}"
        
        if ([ -z "${second_to_last}" ] || [ "${second_to_last}" = "true" ]) && \
           ([ -z "${last}" ] || [ "${last}" = "true" ]) && \
           [[ ! "${second_to_last}" =~ = ]] && [[ ! "${last}" =~ = ]]; then
            override_flags_start=$((arg_count - 2))
        fi
    fi
    
    # Extract arrays based on detected boundaries
    # Order: config_lines, lock_hours_lines, uninstall_lock_hours_lines, override_flags
    if [ ${lock_hours_start} -ge 0 ]; then
        # Lock hours present
        config_lines=("${all_args[@]:0:${lock_hours_start}}")
        
        if [ ${uninstall_lock_hours_start} -ge 0 ] && [ ${uninstall_lock_hours_start} -gt ${lock_hours_start} ]; then
            # Both lock hours and uninstall lock hours present
            lock_hours_lines=("${all_args[@]:${lock_hours_start}:$((uninstall_lock_hours_start - lock_hours_start))}")
            
            if [ ${override_flags_start} -ge 0 ] && [ ${override_flags_start} -gt ${uninstall_lock_hours_start} ]; then
                # Override flags present after uninstall lock hours
                uninstall_lock_hours_lines=("${all_args[@]:${uninstall_lock_hours_start}:$((override_flags_start - uninstall_lock_hours_start))}")
                # Extract override flags (handle both 2-flag and 4-flag formats)
                if [ $((arg_count - override_flags_start)) -eq 4 ]; then
                    popup_size_overridden="${all_args[$((arg_count - 4))]}"
                    configure_block_overridden="${all_args[$((arg_count - 3))]}"
                    lock_hours_cleared="${all_args[$((arg_count - 2))]}"
                    uninstall_lock_hours_cleared="${all_args[$((arg_count - 1))]}"
                else
                    # Backward compatibility: 2 flags
                    popup_size_overridden="${all_args[$((arg_count - 2))]}"
                    configure_block_overridden="${all_args[$((arg_count - 1))]}"
                fi
            else
                # No override flags, uninstall lock hours go to end
                uninstall_lock_hours_lines=("${all_args[@]:${uninstall_lock_hours_start}}")
            fi
        else
            # Only lock hours, no uninstall lock hours
            if [ ${override_flags_start} -ge 0 ] && [ ${override_flags_start} -gt ${lock_hours_start} ]; then
                # Override flags present after lock hours
                lock_hours_lines=("${all_args[@]:${lock_hours_start}:$((override_flags_start - lock_hours_start))}")
                # Extract override flags (handle both 2-flag and 4-flag formats)
                if [ $((arg_count - override_flags_start)) -eq 4 ]; then
                    popup_size_overridden="${all_args[$((arg_count - 4))]}"
                    configure_block_overridden="${all_args[$((arg_count - 3))]}"
                    lock_hours_cleared="${all_args[$((arg_count - 2))]}"
                    uninstall_lock_hours_cleared="${all_args[$((arg_count - 1))]}"
                else
                    # Backward compatibility: 2 flags
                    popup_size_overridden="${all_args[$((arg_count - 2))]}"
                    configure_block_overridden="${all_args[$((arg_count - 1))]}"
                fi
            else
                # No override flags, lock hours go to end
                lock_hours_lines=("${all_args[@]:${lock_hours_start}}")
            fi
        fi
    elif [ ${uninstall_lock_hours_start} -ge 0 ]; then
        # Only uninstall lock hours, no lock hours
        config_lines=("${all_args[@]:0:${uninstall_lock_hours_start}}")
        
            if [ ${override_flags_start} -ge 0 ] && [ ${override_flags_start} -gt ${uninstall_lock_hours_start} ]; then
                # Override flags present after uninstall lock hours
                uninstall_lock_hours_lines=("${all_args[@]:${uninstall_lock_hours_start}:$((override_flags_start - uninstall_lock_hours_start))}")
                # Extract override flags (handle both 2-flag and 4-flag formats)
                local flags_count=$((arg_count - override_flags_start))
                if [ ${flags_count} -ge 4 ]; then
                    popup_size_overridden="${all_args[$((arg_count - 4))]}"
                    configure_block_overridden="${all_args[$((arg_count - 3))]}"
                    lock_hours_cleared="${all_args[$((arg_count - 2))]}"
                    uninstall_lock_hours_cleared="${all_args[$((arg_count - 1))]}"
                else
                    popup_size_overridden="${all_args[$((arg_count - 2))]}"
                    configure_block_overridden="${all_args[$((arg_count - 1))]}"
                fi
        else
            # No override flags, uninstall lock hours go to end
            uninstall_lock_hours_lines=("${all_args[@]:${uninstall_lock_hours_start}}")
        fi
    else
        # No lock hours or uninstall lock hours
        if [ ${override_flags_start} -ge 0 ]; then
            # Override flags present
            config_lines=("${all_args[@]:0:${override_flags_start}}")
            # Extract override flags (handle both 2-flag and 4-flag formats)
            local flags_count=$((arg_count - override_flags_start))
            if [ ${flags_count} -ge 4 ]; then
                popup_size_overridden="${all_args[$((arg_count - 4))]}"
                configure_block_overridden="${all_args[$((arg_count - 3))]}"
                lock_hours_cleared="${all_args[$((arg_count - 2))]}"
                uninstall_lock_hours_cleared="${all_args[$((arg_count - 1))]}"
            else
                popup_size_overridden="${all_args[$((arg_count - 2))]}"
                configure_block_overridden="${all_args[$((arg_count - 1))]}"
            fi
        else
            # No override flags, all are config_lines
            config_lines=("${all_args[@]}")
        fi
    fi
    
    # Create config directory if it doesn't exist
    # Enhancement #18: Config file is now in subdirectory
    mkdir -p "${CONFIG_DIR}/config"
    
    # Extract user comments from existing file
    # User comments are no longer preserved to prevent config file growth
    
    # Create temporary file for atomic write
    local temp_file
    temp_file=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX" 2>/dev/null || echo "${CONFIG_FILE}.tmp")
    
    # Write configuration file to temp file
    {
        _write_config_header \
            "${check_interval}" \
            "${popup_size}" \
            "${popup_position}" \
            "${min_display_time}" \
            "${popup_immovable}" \
            "${popup_auto_close}" \
            "${configure_block_enabled}" \
            "${uninstall_protection_mode}" \
            "${pause_enabled}" \
            "${pause_duration}" \
            "${dialog_tool}" \
            "${config_lock_enabled}" \
            "${popup_size_mode}" \
            "${popup_size_custom}" \
            "${popup_size_custom_absolute}" \
            "${popup_size_overridden}" \
            "${configure_block_overridden}"

        _write_restrictions_section config_lines
        _write_lock_hours_section lock_hours_lines "${lock_hours_cleared}"
        _write_uninstall_lock_hours_section uninstall_lock_hours_lines "${uninstall_lock_hours_cleared}"
    } > "${temp_file}"
    
    # Check if write to temp file succeeded
    if [ $? -ne 0 ]; then
        # Write failed, clean up temp file
        rm -f "${temp_file}" 2>/dev/null
        return 1
    fi
    
    # Atomically replace config file with temp file
    if mv "${temp_file}" "${CONFIG_FILE}" 2>/dev/null; then
        return 0
    else
        # Move failed, clean up temp file
        rm -f "${temp_file}" 2>/dev/null
        return 1
    fi
}
