#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration Workflow Orchestration Module
#
# This module provides high-level workflow orchestration functions that coordinate
# the configuration process for different sections (weekdays, weekends, grid editing).
#
# Functions:
# - configure_weekdays_section()  - Configure all weekdays (Monday-Friday)
# - configure_weekends_section()  - Configure weekend days (Saturday-Sunday)
# - configure_day_from_grid()     - Configure a day selected from visual grid
#
# Dependencies:
# - configure-core.sh (for DAY_NAMES, DAY_VARS)
# - configure-ui.sh (for ask_weekday_together, ask_weekend_together)
# - configure-input.sh (for get_day_hours)
###############################################################################

configure_weekdays_section() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    
    # Ask if configure together or separately
    if ask_weekday_together "${use_gui}"; then
        # Configure all weekdays together
        local weekday_range
        weekday_range=$(get_day_hours "Weekdays (Monday-Friday)" 1 "${use_gui}" "false" "true")
        local exit_code=$?
        
        if [ "${weekday_range}" = "CANCELLED" ]; then
            return 2  # Cancelled
        elif [ "${weekday_range}" != "skip" ]; then
            # Apply to all weekdays (indices 1-5: Monday-Friday)
            for i in 1 2 3 4 5; do
                config_lines_ref[${i}]="${DAY_VARS[${i}]}=${weekday_range}"
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${weekday_range}"
            done
        else
            # Explicitly skipped - mark all weekdays as skipped (no restrictions)
            for i in 1 2 3 4 5; do
                config_lines_ref[${i}]="${DAY_VARS[${i}]}="
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
            done
        fi
        return 0
    else
        # Configure each weekday separately
        local i=1  # Start with Monday
        while [ "${i}" -le 5 ]; do  # Monday through Friday
            local allow_back="false"
            if [ "${i}" -gt 1 ]; then
                allow_back="true"  # Allow back from Tuesday onwards
            fi
            
            local range
            range=$(get_day_hours "${DAY_NAMES[${i}]}" "${i}" "${use_gui}" "${allow_back}" "true")
            local exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2  # Cancelled
            elif [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
                # User wants to go back
                if [ "${i}" -gt 1 ]; then
                    i=$((i - 1))  # Go back to previous day
                    # Remove previous day's entry if it was set
                    unset config_lines_ref[${i}]
                    unset summary_lines_ref[${i}]
                else
                    # Back from first day - return to main menu
                    return 0
                fi
                # Continue loop to re-prompt previous day
            elif [ "${range}" != "skip" ]; then
                config_lines_ref[${i}]="${DAY_VARS[${i}]}=${range}"
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${range}"
                i=$((i + 1))  # Move to next day
            else
                # Explicitly skipped - mark as skipped (no restrictions)
                config_lines_ref[${i}]="${DAY_VARS[${i}]}="
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
                i=$((i + 1))  # Skip this day, move to next
            fi
        done
        return 0
    fi
}

configure_weekends_section() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    
    # Ask if configure together or separately
    if ask_weekend_together "${use_gui}"; then
        # Configure both weekend days together
        local weekend_range
        weekend_range=$(get_day_hours "Weekends (Saturday and Sunday)" 6 "${use_gui}" "false" "true")
        local exit_code=$?
        
        if [ "${weekend_range}" = "CANCELLED" ]; then
            return 2  # Cancelled
        elif [ "${weekend_range}" != "skip" ]; then
            # Apply to both weekend days (Saturday=6, Sunday=0)
            config_lines_ref[6]="${DAY_VARS[6]}=${weekend_range}"
            summary_lines_ref[6]="${DAY_NAMES[6]}: ${weekend_range}"
            config_lines_ref[0]="${DAY_VARS[0]}=${weekend_range}"
            summary_lines_ref[0]="${DAY_NAMES[0]}: ${weekend_range}"
        else
            # Explicitly skipped - mark both weekend days as skipped (no restrictions)
            config_lines_ref[6]="${DAY_VARS[6]}="
            summary_lines_ref[6]="${DAY_NAMES[6]}: (no restrictions)"
            config_lines_ref[0]="${DAY_VARS[0]}="
            summary_lines_ref[0]="${DAY_NAMES[0]}: (no restrictions)"
        fi
        return 0
    else
        # Configure Saturday and Sunday separately
        local weekend_day=6  # Start with Saturday
        while true; do
            local allow_back="false"
            if [ "${weekend_day}" -eq 0 ]; then
                allow_back="true"  # Allow back from Sunday to Saturday
            fi
            
            local range
            range=$(get_day_hours "${DAY_NAMES[${weekend_day}]}" "${weekend_day}" "${use_gui}" "${allow_back}" "true")
            local exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2  # Cancelled
            elif [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
                # User wants to go back
                if [ "${weekend_day}" -eq 0 ]; then
                    weekend_day=6  # Go back to Saturday
                    # Remove Saturday's entry if it was set
                    unset config_lines_ref[6]
                    unset summary_lines_ref[6]
                else
                    # Back from Saturday - return to main menu
                    return 0
                fi
                # Continue loop to re-prompt previous day
            elif [ "${range}" != "skip" ]; then
                config_lines_ref[${weekend_day}]="${DAY_VARS[${weekend_day}]}=${range}"
                summary_lines_ref[${weekend_day}]="${DAY_NAMES[${weekend_day}]}: ${range}"
                if [ "${weekend_day}" -eq 6 ]; then
                    weekend_day=0  # Move to Sunday
                else
                    break  # Done with both weekend days
                fi
            else
                # Explicitly skipped - mark as skipped (no restrictions)
                config_lines_ref[${weekend_day}]="${DAY_VARS[${weekend_day}]}="
                summary_lines_ref[${weekend_day}]="${DAY_NAMES[${weekend_day}]}: (no restrictions)"
                if [ "${weekend_day}" -eq 6 ]; then
                    weekend_day=0  # Skip Saturday, move to Sunday
                else
                    break  # Done with both weekend days
                fi
            fi
        done
        return 0
    fi
}

configure_day_from_grid() {
    local day_index="$1"
    local use_gui="$2"
    local -n config_lines_ref="$3"  # Pass by reference
    local -n summary_lines_ref="$4"  # Pass by reference
    
    # Validate day index
    if [ "${day_index}" -lt 0 ] || [ "${day_index}" -gt 6 ]; then
        return 1
    fi
    
    local day_name="${DAY_NAMES[${day_index}]}"
    local range=""
    local exit_code=0
    
    # Determine if weekday or weekend
    if [ "${day_index}" -ge 1 ] && [ "${day_index}" -le 5 ]; then
        # Weekday (Monday-Friday, indices 1-5)
        if ask_weekday_together "${use_gui}"; then
            # Apply to all weekdays
            range=$(get_day_hours "Weekdays (Monday-Friday)" 1 "${use_gui}" "false" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            elif [ "${range}" != "skip" ]; then
                # Apply to all weekdays (indices 1-5)
                for i in 1 2 3 4 5; do
                    config_lines_ref[${i}]="${DAY_VARS[${i}]}=${range}"
                    summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${range}"
                done
            else
                # Explicitly skipped - mark all weekdays as skipped
                for i in 1 2 3 4 5; do
                    config_lines_ref[${i}]="${DAY_VARS[${i}]}="
                    summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
                done
            fi
        else
            # Edit single weekday
            range=$(get_day_hours "${day_name}" "${day_index}" "${use_gui}" "false" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            elif [ "${range}" != "skip" ]; then
                config_lines_ref[${day_index}]="${DAY_VARS[${day_index}]}=${range}"
                summary_lines_ref[${day_index}]="${day_name}: ${range}"
            else
                # Explicitly skipped
                config_lines_ref[${day_index}]="${DAY_VARS[${day_index}]}="
                summary_lines_ref[${day_index}]="${day_name}: (no restrictions)"
            fi
        fi
    elif [ "${day_index}" -eq 0 ] || [ "${day_index}" -eq 6 ]; then
        # Weekend day (Sunday=0, Saturday=6)
        if ask_weekend_together "${use_gui}"; then
            # Apply to both weekend days
            range=$(get_day_hours "Weekends (Saturday and Sunday)" 6 "${use_gui}" "false" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            elif [ "${range}" != "skip" ]; then
                # Apply to both weekend days
                config_lines_ref[6]="${DAY_VARS[6]}=${range}"
                summary_lines_ref[6]="${DAY_NAMES[6]}: ${range}"
                config_lines_ref[0]="${DAY_VARS[0]}=${range}"
                summary_lines_ref[0]="${DAY_NAMES[0]}: ${range}"
            else
                # Explicitly skipped - mark both weekend days as skipped
                config_lines_ref[6]="${DAY_VARS[6]}="
                summary_lines_ref[6]="${DAY_NAMES[6]}: (no restrictions)"
                config_lines_ref[0]="${DAY_VARS[0]}="
                summary_lines_ref[0]="${DAY_NAMES[0]}: (no restrictions)"
            fi
        else
            # Edit single weekend day
            range=$(get_day_hours "${day_name}" "${day_index}" "${use_gui}" "false" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            elif [ "${range}" != "skip" ]; then
                config_lines_ref[${day_index}]="${DAY_VARS[${day_index}]}=${range}"
                summary_lines_ref[${day_index}]="${day_name}: ${range}"
            else
                # Explicitly skipped
                config_lines_ref[${day_index}]="${DAY_VARS[${day_index}]}="
                summary_lines_ref[${day_index}]="${day_name}: (no restrictions)"
            fi
        fi
    fi
    
    return ${exit_code}
}
