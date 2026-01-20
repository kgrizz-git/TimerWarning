#!/bin/bash

###############################################################################
# Sleep Warning System - Main Script
#
# This script checks if the current time falls within user-defined restricted
# hours and displays a modal warning popup if usage is detected during those
# hours. It is designed to help users maintain healthy sleep schedules.
#
# Requirements:
# - bash
# - zenity (or yad/kdialog as fallback)
# - systemd (for timer integration)
# - Graphical desktop environment
#
# Configuration:
# - Reads from ~/.config/sleep-warning/sleep-warning.conf
# - Falls back to default values if config file missing
#
# Usage:
# - Typically run by systemd timer every 10 minutes
# - Can also be run manually for testing
#
# Output:
# - Displays modal warning dialog during restricted hours
# - Exits silently during non-restricted hours or if GUI unavailable
###############################################################################

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source library modules in dependency order
source "${LIB_DIR}/config.sh" || exit 1
source "${LIB_DIR}/logging.sh" || exit 1
source "${LIB_DIR}/display-detection.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/window-management.sh" || exit 1
source "${LIB_DIR}/time-validation.sh" || exit 1
source "${LIB_DIR}/popup-display.sh" || exit 1

# Main function
main() {
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    
    # Get current hour (0-23)
    local current_hour
    current_hour=$(date +%H)
    # Remove leading zero if present
    current_hour=$((10#${current_hour}))
    
    # Parse configuration for current day
    local restricted_range
    restricted_range=$(parse_config "${current_day}")
    
    # Check if current hour is within restricted range for current day
    local is_restricted=false
    local matched_range="${restricted_range}"
    
    if is_restricted_hour "${current_hour}" "${restricted_range}"; then
        is_restricted=true
    elif [ -z "${restricted_range}" ]; then
        # Current day is empty/skipped (no restrictions for this day)
        # Check if previous day has an overnight range that extends into current day
        # Calculate previous day (handle wrap-around: Sunday (0) -> Saturday (6))
        local prev_day
        if [ "${current_day}" -eq 0 ]; then
            prev_day=6  # Sunday -> Saturday
        else
            prev_day=$((current_day - 1))
        fi
        
        # Get previous day's configuration
        local prev_day_range
        prev_day_range=$(parse_config "${prev_day}")
        
        # Check if previous day has overnight ranges that extend into current day
        if [ -n "${prev_day_range}" ]; then
            # Check each range in previous day's configuration
            local IFS=','
            for range in ${prev_day_range}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_hour end_hour
                start_hour=$(echo "${range}" | cut -d'-' -f1)
                end_hour=$(echo "${range}" | cut -d'-' -f2)
                
                # Check if this is an overnight range (start > end) that extends into current day
                if [ "${start_hour}" -gt "${end_hour}" ]; then
                    # Overnight range: check if current hour falls within the end portion (before end_hour)
                    # Example: prev_day has 23-5, current hour is 2, then 2 < 5, so it's restricted
                    # Example: prev_day has 23-5, current hour is 23, then 23 >= 23, but wait...
                    # Actually, for overnight range 23-5 on previous day:
                    # - Previous day 23:00-23:59 is restricted (part of previous day)
                    # - Current day 00:00-04:59 is restricted (extends into current day)
                    # - Current day 05:00+ is NOT restricted
                    # So we only check: current_hour < end_hour
                    if [ "${current_hour}" -lt "${end_hour}" ]; then
                        is_restricted=true
                        matched_range="${range} (from previous day)"
                        break
                    fi
                fi
            done
        fi
    fi
    
    if [ "${is_restricted}" = "true" ]; then
        log_message "info" "Restricted hour detected: Day ${current_day}, Hour ${current_hour}, Range ${matched_range}"
        
        # Get display environment info for logging
        local env_type display_id
        env_type=$(detect_display_environment)
        display_id=$(get_display_identifier "${env_type}")
        
        # Log warning trigger with full context
        log_to_file "WARNING" "Restricted hour detected - Day: ${current_day}, Hour: ${current_hour}, Range: ${matched_range}, Display: ${env_type}, Display ID: ${display_id}"
        
        show_warning
    else
        # Not a restricted hour, exit silently
        exit 0
    fi
}

# Run main function
main "$@"
