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
# - extract_user_comments()  - Preserve user comments when rewriting
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
    declare -g popup_position="center"
    declare -g min_display_time="30"
    declare -g popup_immovable="true"
    
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

# Extract user comments from existing config file
extract_user_comments() {
    local existing_file="$1"
    local user_comments=()
    
    if [ ! -f "${existing_file}" ]; then
        return 0
    fi
    
    # Standard header patterns to skip
    local skip_patterns=(
        "^# Sleep Warning Configuration"
        "^# Format:"
        "^# Hours are in 24-hour format"
        "^# Multiple ranges can be specified"
        "^# Leave a day empty"
        "^# CHECK_INTERVAL:"
        "^# POPUP_SIZE:"
        "^# POPUP_POSITION:"
        "^# POPUP_MIN_DISPLAY_TIME:"
        "^# Default:"
        "^# Minimum:"
        "^# Maximum:"
        "^# Options:"
        "^# Note:"
        "^CHECK_INTERVAL="
        "^POPUP_SIZE="
        "^POPUP_POSITION="
        "^POPUP_MIN_DISPLAY_TIME="
        "^# This file was generated"
        "^# *$"  # Empty comment lines
    )
    
    # Read existing file line by line
    while IFS= read -r line; do
        # Only process comment lines
        if [[ "${line}" =~ ^[[:space:]]*# ]]; then
            local should_skip=0
            
            # Check if this is a standard header line
            for pattern in "${skip_patterns[@]}"; do
                if [[ "${line}" =~ ${pattern} ]]; then
                    should_skip=1
                    break
                fi
            done
            
            # If not a standard header line, preserve it
            if [ "${should_skip}" -eq 0 ]; then
                user_comments+=("${line}")
            fi
        fi
    done < "${existing_file}"
    
    # Print user comments (one per line, separated by newlines for array)
    if [ ${#user_comments[@]} -gt 0 ]; then
        printf '%s\n' "${user_comments[@]}"
    fi
}

# Write configuration file
write_config() {
    local check_interval="$1"
    local popup_size="$2"
    local popup_position="$3"
    local min_display_time="$4"
    local popup_immovable="$5"
    shift 5
    local config_lines=("$@")
    
    # Create config directory if it doesn't exist
    mkdir -p "${CONFIG_DIR}"
    
    # Extract user comments from existing file
    local user_comments
    user_comments=$(extract_user_comments "${CONFIG_FILE}")
    
    # Write configuration file
    {
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
        echo "# POPUP_SIZE: Size of warning popup (small, medium, large, or custom WIDTHxHEIGHT)"
        echo "# Default: medium"
        echo "POPUP_SIZE=${popup_size}"
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
        echo "# This file was generated by the configuration wizard on $(date)"
        
        # Preserve user comments if any
        if [ -n "${user_comments}" ]; then
            echo ""
            echo "# User comments (preserved from previous configuration):"
            echo "${user_comments}"
        fi
        
        echo ""
        
        # Write configuration lines in calendar order (Sun-Sat, indices 0-6)
        for day_index in 0 1 2 3 4 5 6; do
            if [ -n "${config_lines[${day_index}]}" ]; then
                # Write the line (includes empty values for explicitly skipped days)
                echo "${config_lines[${day_index}]}"
            fi
        done
    } > "${CONFIG_FILE}"
    
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}
