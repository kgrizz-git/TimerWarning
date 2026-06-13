#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration Workflow Orchestration Module
#
# This module provides high-level workflow orchestration functions that coordinate
# the configuration process for different sections (weekdays, weekends, grid editing,
# and lock hours for configuration scripts).
#
# Functions:
# - configure_weekdays_section()      - Configure all weekdays (Monday-Friday)
# - configure_weekends_section()      - Configure weekend days (Saturday-Sunday)
# - configure_day_from_grid()         - Configure a day selected from visual grid (restricted hours and/or lock hours)
# - configure_lock_hours_section()    - Configure additional lock hours for configure.sh/manage.sh (Enhancement #19 Phase 2)
#
# Dependencies:
# - configure-core.sh (for DAY_NAMES, DAY_VARS, has_dialog_tool)
# - configure-dialogs.sh (for show_info_dialog)
# - configure-ui.sh (for ask_weekday_together, ask_weekend_together, ask_what_to_edit)
# - configure-input-time.sh (for get_day_hours)
###############################################################################

prompt_continue_day_flow() {
    local use_gui="$1"
    local next_label="$2"
    local section_label="$3"
    local prompt_text="Next up: ${next_label}. Continue configuring ${section_label}?"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        if type is_darwin >/dev/null 2>&1 && is_darwin; then
            local choice
            choice=$(show_list_dialog \
                "Continue Configuration?" \
                "${prompt_text}" \
                600 300 \
                "Yes, Continue" \
                "Return to Menu")
            local list_exit=$?
            if [ ${list_exit} -ne 0 ] || [ -z "${choice}" ]; then
                return 1
            fi
            [ "${choice}" = "Yes, Continue" ]
            return $?
        fi
        # Linux path unchanged
        show_question_dialog \
            "Continue Configuration?" \
            "${prompt_text}" \
            "Yes, Continue" \
            "Return to Menu" \
            600 \
            250
        return $?
    else
        # Text mode unchanged
        local answer
        configure_read -p "${prompt_text} [Y/n]: " answer
        case "${answer}" in
            [Nn]*) return 1 ;;
            *) return 0 ;;
        esac
    fi
}

configure_weekdays_section() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    local weekday_range
    local day_var
    local allow_back
    local range
    local exit_code
    local i
    
    # Ask if configure together or separately
    if ask_weekday_together "${use_gui}"; then
        # Configure all weekdays together
        weekday_range=$(get_day_hours "Weekdays (Monday-Friday)" 1 "${use_gui}" "false" "true")
        exit_code=$?
        
        if [ "${weekday_range}" = "CANCELLED" ] || [ ${exit_code} -eq 2 ]; then
            return 2  # Cancelled
        fi

        # Apply to all weekdays (indices 1-5: Monday-Friday)
        for i in 1 2 3 4 5; do
            day_var="${DAY_VARS[${i}]}"
            if [ "${weekday_range}" != "skip" ]; then
                config_lines_ref[${i}]="${day_var}=${weekday_range}"
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${weekday_range}"
            else
                config_lines_ref[${i}]="${day_var}="
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
            fi
        done
        return 0
    else
        # Configure each weekday separately
        i=1  # Start with Monday
        while [ "${i}" -le 5 ]; do  # Monday through Friday
            # No previous weekday before Monday; hide "Go back to previous day" on first day
            allow_back="false"
            [ "${i}" -gt 1 ] && allow_back="true"
            
            range=$(get_day_hours "${DAY_NAMES[${i}]}" "${i}" "${use_gui}" "${allow_back}" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2  # Cancelled
            elif [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
                # User wants to go back — re-prompt previous day; keep loaded values intact
                if [ "${i}" -gt 1 ]; then
                    i=$((i - 1))  # Go back to previous day
                else
                    # Back from first day - return to main menu
                    return 0
                fi
                # Continue loop to re-prompt previous day
            else
                day_var="${DAY_VARS[${i}]}"
                if [ "${range}" != "skip" ]; then
                    config_lines_ref[${i}]="${day_var}=${range}"
                    summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${range}"
                else
                    # Explicitly skipped - mark as skipped (no restrictions)
                    config_lines_ref[${i}]="${day_var}="
                    summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
                fi
                i=$((i + 1))  # Move to next day
                if [ "${i}" -le 5 ] && ! prompt_continue_day_flow "${use_gui}" "${DAY_NAMES[${i}]}" "weekdays"; then
                    return 0
                fi
            fi
        done
        return 0
    fi
}

###############################################################################
# Additional Configuration Lock Hours (Enhancement #19 Phase 2)
###############################################################################

# Configure additional tighten-only lock hours for configure.sh/manage.sh
# This is separate from restricted hours and uses CONFIG_LOCK_HOURS_* variables.
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - lock_hours_lines_ref (name of array variable, passed by reference)
configure_lock_hours_section() {
    local use_gui="$1"
    local -n lock_hours_lines_ref="$2"  # Pass lock_hours_lines by reference
    local weekday_range
    local weekend_range
    local day_var
    local i
    local day_index
    local day_name
    local label
    local allow_back
    local existing_lock
    local range
    local exit_code
    
    # Show informational note about dependency
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog \
            "Additional Configuration Lock Hours" \
            "Additional Configuration Lock Hours\n\nConfigure additional hours when configuration changes are restricted to tighten-only.\n\nIMPORTANT: These additional lock hours only take effect when 'Configuration Lock (Tighten-Only)' (option 5) is enabled.\n\nIf 'Configuration Lock (Tighten-Only)' is disabled, these additional lock hours will have no effect." \
            600 \
            250
    else
        echo "" >&2
        echo "=== Additional Configuration Lock Hours ===" >&2
        echo "" >&2
        echo "Configure additional hours when configuration changes are restricted to tighten-only." >&2
        echo "" >&2
        echo "IMPORTANT: These additional lock hours only take effect when" >&2
        echo "'Configuration Lock (Tighten-Only)' (option 5) is enabled." >&2
        echo "" >&2
        echo "If 'Configuration Lock (Tighten-Only)' is disabled, these" >&2
        echo "additional lock hours will have no effect." >&2
        echo "" >&2
        configure_read -p "Press Enter to continue..."
    fi
    
    # Ask if same hours for all weekdays and/or both weekend days (main menu entry point)
    if ask_weekday_together "${use_gui}"; then
        weekday_range=$(get_day_hours "Weekdays (Monday-Friday) - Additional Block Hours" 1 "${use_gui}" "false" "true")
        if [ "${weekday_range}" = "CANCELLED" ]; then
            return 2
        fi
        for i in 1 2 3 4 5; do
            day_var="${DAY_VARS[${i}]}"
            if [ "${weekday_range}" != "skip" ]; then
                lock_hours_lines_ref[${i}]="CONFIG_LOCK_HOURS_${day_var}=${weekday_range}"
            else
                lock_hours_lines_ref[${i}]="CONFIG_LOCK_HOURS_${day_var}="
            fi
        done
        # Weekends
        if ask_weekend_together "${use_gui}"; then
            weekend_range=$(get_day_hours "Weekends (Saturday and Sunday) - Additional Block Hours" 6 "${use_gui}" "false" "true")
            if [ "${weekend_range}" = "CANCELLED" ]; then
                return 2
            fi
            for i in 6 0; do
                day_var="${DAY_VARS[${i}]}"
                if [ "${weekend_range}" != "skip" ]; then
                    lock_hours_lines_ref[${i}]="CONFIG_LOCK_HOURS_${day_var}=${weekend_range}"
                else
                    lock_hours_lines_ref[${i}]="CONFIG_LOCK_HOURS_${day_var}="
                fi
            done
        else
            for i in 6 0; do
                day_name="${DAY_NAMES[${i}]}"
                label="Additional Block Hours - ${day_name}"
                existing_lock=""
                [ -n "${lock_hours_lines_ref[${i}]+set}" ] && [ -n "${lock_hours_lines_ref[${i}]}" ] && existing_lock=$(echo "${lock_hours_lines_ref[${i}]}" | cut -d'=' -f2-)
                range=$(get_day_hours "${label}" "${i}" "${use_gui}" "false" "true" "${existing_lock}")
                if [ "${range}" = "CANCELLED" ]; then
                    return 2
                fi
                day_var="${DAY_VARS[${i}]}"
                if [ "${range}" != "skip" ]; then
                    lock_hours_lines_ref[${i}]="CONFIG_LOCK_HOURS_${day_var}=${range}"
                else
                    lock_hours_lines_ref[${i}]="CONFIG_LOCK_HOURS_${day_var}="
                fi
            done
        fi
        return 0
    fi
    
    if ask_weekend_together "${use_gui}"; then
        weekend_range=$(get_day_hours "Weekends (Saturday and Sunday) - Additional Block Hours" 6 "${use_gui}" "false" "true")
        if [ "${weekend_range}" = "CANCELLED" ]; then
            return 2
        fi
        for i in 6 0; do
            day_var="${DAY_VARS[${i}]}"
            if [ "${weekend_range}" != "skip" ]; then
                lock_hours_lines_ref[${i}]="CONFIG_LOCK_HOURS_${day_var}=${weekend_range}"
            else
                lock_hours_lines_ref[${i}]="CONFIG_LOCK_HOURS_${day_var}="
            fi
        done
        # Per-day for weekdays (1-5)
        day_index=1
        while [ "${day_index}" -le 5 ]; do
            day_name="${DAY_NAMES[${day_index}]}"
            label="Additional Block Hours - ${day_name}"
            allow_back="true"
            [ "${day_index}" -eq 1 ] && allow_back="false"
            existing_lock=""
            [ -n "${lock_hours_lines_ref[${day_index}]+set}" ] && [ -n "${lock_hours_lines_ref[${day_index}]}" ] && existing_lock=$(echo "${lock_hours_lines_ref[${day_index}]}" | cut -d'=' -f2-)
            range=$(get_day_hours "${label}" "${day_index}" "${use_gui}" "${allow_back}" "true" "${existing_lock}")
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            fi
            if [ "${range}" = "back" ]; then
                day_index=$((day_index - 1))
                continue
            fi
            day_var="${DAY_VARS[${day_index}]}"
            if [ "${range}" != "skip" ]; then
                lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}=${range}"
            else
                lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}="
            fi
            day_index=$((day_index + 1))
        done
        return 0
    fi
    
    # Per-day loop for all days (Sunday-Saturday, indices 0-6)
    day_index=0
    while [ "${day_index}" -le 6 ]; do
        day_name="${DAY_NAMES[${day_index}]}"
        label="Additional Block Hours - ${day_name}"
        allow_back="false"
        [ "${day_index}" -gt 0 ] && allow_back="true"
        existing_lock=""
        [ -n "${lock_hours_lines_ref[${day_index}]+set}" ] && [ -n "${lock_hours_lines_ref[${day_index}]}" ] && existing_lock=$(echo "${lock_hours_lines_ref[${day_index}]}" | cut -d'=' -f2-)
        range=$(get_day_hours "${label}" "${day_index}" "${use_gui}" "${allow_back}" "true" "${existing_lock}")
        exit_code=$?
        if [ "${range}" = "CANCELLED" ]; then
            return 2
        fi
        if [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
            if [ "${day_index}" -gt 0 ]; then
                day_index=$((day_index - 1))
                continue
            else
                return 0
            fi
        fi
        day_var="${DAY_VARS[${day_index}]}"
        if [ "${range}" != "skip" ]; then
            lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}=${range}"
        else
            lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}="
        fi
        day_index=$((day_index + 1))
    done
    return 0
}

configure_weekends_section() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    local weekend_range
    local exit_code
    local weekend_day
    local allow_back
    local range
    local day_var
    
    # Ask if configure together or separately
    if ask_weekend_together "${use_gui}"; then
        # Configure both weekend days together
        weekend_range=$(get_day_hours "Weekends (Saturday and Sunday)" 6 "${use_gui}" "false" "true")
        exit_code=$?
        
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
        weekend_day=6  # Start with Saturday
        while true; do
            # No previous day before Saturday; hide "Go back to previous day" on first day
            allow_back="false"
            [ "${weekend_day}" -eq 0 ] && allow_back="true"
            
            range=$(get_day_hours "${DAY_NAMES[${weekend_day}]}" "${weekend_day}" "${use_gui}" "${allow_back}" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2  # Cancelled
            elif [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
                # User wants to go back — re-prompt previous day; keep loaded values intact
                if [ "${weekend_day}" -eq 0 ]; then
                    weekend_day=6  # Go back to Saturday
                else
                    # Back from Saturday - return to main menu
                    return 0
                fi
                # Continue loop to re-prompt previous day
            else
                day_var="${DAY_VARS[${weekend_day}]}"
                if [ "${range}" != "skip" ]; then
                    config_lines_ref[${weekend_day}]="${day_var}=${range}"
                    summary_lines_ref[${weekend_day}]="${DAY_NAMES[${weekend_day}]}: ${range}"
                else
                    # Explicitly skipped - mark as skipped (no restrictions)
                    config_lines_ref[${weekend_day}]="${day_var}="
                    summary_lines_ref[${weekend_day}]="${DAY_NAMES[${weekend_day}]}: (no restrictions)"
                fi

                if [ "${weekend_day}" -eq 6 ]; then
                    if ! prompt_continue_day_flow "${use_gui}" "${DAY_NAMES[0]}" "weekend days"; then
                        return 0
                    fi
                    weekend_day=0  # Move to/skip to Sunday
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
    local -n lock_hours_lines_ref="$5"  # Pass by reference (Enhancement #19 Phase 2 - lock hours)
    local -n uninstall_lock_hours_lines_ref="$6"  # Pass by reference (Enhancement #26 Phase 2 - uninstall lock hours)
    
    # Validate day index
    if [ "${day_index}" -lt 0 ] || [ "${day_index}" -gt 6 ]; then
        return 1
    fi
    
    local day_name="${DAY_NAMES[${day_index}]}"
    local range=""
    local lock_range=""
    local uninstall_lock_range=""
    local exit_code=0
    
    # Ask what to edit (restricted hours, lock hours, uninstall lock hours, or all)
    local edit_choice
    edit_choice=$(ask_what_to_edit "${day_name}" "${use_gui}")
    local choice_exit=$?
    
    if [ ${choice_exit} -eq 2 ] || [ "${edit_choice}" = "CANCELLED" ]; then
        return 2  # User cancelled
    elif [ ${choice_exit} -ne 0 ]; then
        # Error occurred (user cancelled dialog but chose to continue) - return to grid
        return 0
    fi
    
    # Determine if weekday or weekend (for restricted hours editing)
    local is_weekday=false
    local is_weekend=false
    if [ "${day_index}" -ge 1 ] && [ "${day_index}" -le 5 ]; then
        is_weekday=true
    elif [ "${day_index}" -eq 0 ] || [ "${day_index}" -eq 6 ]; then
        is_weekend=true
    fi
    
    # Edit restricted hours if requested (grid click: only set the clicked day, no weekday/weekend bulk prompt)
    if [ "${edit_choice}" = "restricted" ] || [ "${edit_choice}" = "both" ] || [ "${edit_choice}" = "all" ]; then
        local existing_range=""
        if [ -n "${config_lines_ref[${day_index}]+set}" ] && [ -n "${config_lines_ref[${day_index}]}" ]; then
            local config_line="${config_lines_ref[${day_index}]}"
            existing_range=$(echo "${config_line}" | cut -d'=' -f2-)
        fi
        range=$(get_day_hours "${day_name}" "${day_index}" "${use_gui}" "false" "true" "${existing_range}")
        exit_code=$?

        if [ "${range}" = "CANCELLED" ]; then
            return 2
        fi

        local day_var="${DAY_VARS[${day_index}]}"
        if [ "${range}" != "skip" ]; then
            config_lines_ref[${day_index}]="${day_var}=${range}"
            summary_lines_ref[${day_index}]="${day_name}: ${range}"
        else
            config_lines_ref[${day_index}]="${day_var}="
            summary_lines_ref[${day_index}]="${day_name}: (no restrictions)"
        fi

        if [ ${exit_code} -eq 2 ]; then
            return 2  # User cancelled
        fi
    fi
    
    # Edit lock hours if requested
    if [ "${edit_choice}" = "lock" ] || [ "${edit_choice}" = "both" ] || [ "${edit_choice}" = "all" ]; then
        # Build friendly label to differentiate from restriction hours
        local label="Additional Block Hours - ${day_name}"
        local existing_lock=""
        [ -n "${lock_hours_lines_ref[${day_index}]+set}" ] && [ -n "${lock_hours_lines_ref[${day_index}]}" ] && existing_lock=$(echo "${lock_hours_lines_ref[${day_index}]}" | cut -d'=' -f2-)
        # Reuse get_day_hours for consistent validation and UX (pass existing for multi-range manage dialog)
        lock_range=$(get_day_hours "${label}" "${day_index}" "${use_gui}" "false" "true" "${existing_lock}")
        exit_code=$?
        
        if [ "${lock_range}" = "CANCELLED" ]; then
            return 2
        elif [ "${lock_range}" != "skip" ]; then
            # User configured lock hours for this day
            local day_var="${DAY_VARS[${day_index}]}"
            lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}=${lock_range}"
        else
            # Explicitly skipped - mark as no lock hours for this day
            local day_var="${DAY_VARS[${day_index}]}"
            lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}="
        fi
        
        if [ ${exit_code} -eq 2 ]; then
            return 2  # User cancelled
        fi
    fi
    
    # Edit uninstall lock hours if requested
    if [ "${edit_choice}" = "uninstall_lock" ] || [ "${edit_choice}" = "all" ]; then
        # Build friendly label to differentiate from restriction hours and configure.sh lock hours
        local label="Uninstall Lock Hours - ${day_name}"
        local existing_uninstall=""
        [ -n "${uninstall_lock_hours_lines_ref[${day_index}]+set}" ] && [ -n "${uninstall_lock_hours_lines_ref[${day_index}]}" ] && existing_uninstall=$(echo "${uninstall_lock_hours_lines_ref[${day_index}]}" | cut -d'=' -f2-)
        # Reuse get_day_hours for consistent validation and UX (pass existing for multi-range manage dialog)
        uninstall_lock_range=$(get_day_hours "${label}" "${day_index}" "${use_gui}" "false" "true" "${existing_uninstall}")
        exit_code=$?
        
        if [ "${uninstall_lock_range}" = "CANCELLED" ]; then
            return 2
        elif [ "${uninstall_lock_range}" != "skip" ]; then
            # User configured uninstall lock hours for this day
            local day_var="${DAY_VARS[${day_index}]}"
            uninstall_lock_hours_lines_ref[${day_index}]="UNINSTALL_LOCK_HOURS_${day_var}=${uninstall_lock_range}"
        else
            # Explicitly skipped - mark as no uninstall lock hours for this day
            local day_var="${DAY_VARS[${day_index}]}"
            uninstall_lock_hours_lines_ref[${day_index}]="UNINSTALL_LOCK_HOURS_${day_var}="
        fi
        
        if [ ${exit_code} -eq 2 ]; then
            return 2  # User cancelled
        fi
    fi
    
    return ${exit_code}
}

# Configure additional uninstall lock hours for uninstall.sh
# This is separate from restriction hours and configure.sh lock hours, used for uninstall protection.
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - uninstall_lock_hours_lines_ref (name of array variable, passed by reference)
configure_uninstall_lock_hours_section() {
    local use_gui="$1"
    local -n uninstall_lock_hours_lines_ref="$2"  # Pass uninstall_lock_hours_lines by reference
    local weekday_range
    local weekend_range
    local i
    local day_index
    local day_name
    local label
    local allow_back
    local existing_uninstall
    local uninstall_lock_range
    local day_var
    local exit_code
    
    # Show informational note about dependency
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog \
            "Additional Uninstall Lock Hours" \
            "Additional Uninstall Lock Hours\n\nConfigure additional hours when difficult uninstall verification is required.\n\nIMPORTANT: These additional uninstall lock hours only take effect when 'Uninstall Protection' (option 8) is set to 'difficult'.\n\nIf 'Uninstall Protection' is set to 'none', these additional uninstall lock hours will have no effect.\n\nWARNING: Additional uninstall lock hours increase the risk of preventing legitimate uninstall needs." \
            600 \
            300
    else
        echo "" >&2
        echo "=== Additional Uninstall Lock Hours ===" >&2
        echo "" >&2
        echo "Configure additional hours when difficult uninstall verification is required." >&2
        echo "" >&2
        echo "IMPORTANT: These additional uninstall lock hours only take effect when" >&2
        echo "'Uninstall Protection' (option 8) is set to 'difficult'." >&2
        echo "" >&2
        echo "If 'Uninstall Protection' is set to 'none', these additional uninstall" >&2
        echo "lock hours will have no effect." >&2
        echo "" >&2
        echo "WARNING: Additional uninstall lock hours increase the risk of preventing" >&2
        echo "legitimate uninstall needs." >&2
        echo "" >&2
        configure_read -p "Press Enter to continue..."
    fi
    
    # Ask if same hours for all weekdays and/or both weekend days (main menu entry point)
    if ask_weekday_together "${use_gui}"; then
        weekday_range=$(get_day_hours "Weekdays (Monday-Friday) - Uninstall Lock Hours" 1 "${use_gui}" "false" "true")
        if [ "${weekday_range}" = "CANCELLED" ]; then
            return 2
        fi
        for i in 1 2 3 4 5; do
            day_var="${DAY_VARS[${i}]}"
            if [ "${weekday_range}" != "skip" ]; then
                uninstall_lock_hours_lines_ref[${i}]="UNINSTALL_LOCK_HOURS_${day_var}=${weekday_range}"
            else
                uninstall_lock_hours_lines_ref[${i}]="UNINSTALL_LOCK_HOURS_${day_var}="
            fi
        done
        if ask_weekend_together "${use_gui}"; then
            weekend_range=$(get_day_hours "Weekends (Saturday and Sunday) - Uninstall Lock Hours" 6 "${use_gui}" "false" "true")
            if [ "${weekend_range}" = "CANCELLED" ]; then
                return 2
            fi
            for i in 6 0; do
                day_var="${DAY_VARS[${i}]}"
                if [ "${weekend_range}" != "skip" ]; then
                    uninstall_lock_hours_lines_ref[${i}]="UNINSTALL_LOCK_HOURS_${day_var}=${weekend_range}"
                else
                    uninstall_lock_hours_lines_ref[${i}]="UNINSTALL_LOCK_HOURS_${day_var}="
                fi
            done
        else
            for i in 6 0; do
                day_name="${DAY_NAMES[${i}]}"
                label="Uninstall Lock Hours - ${day_name}"
                existing_uninstall=""
                [ -n "${uninstall_lock_hours_lines_ref[${i}]+set}" ] && [ -n "${uninstall_lock_hours_lines_ref[${i}]}" ] && existing_uninstall=$(echo "${uninstall_lock_hours_lines_ref[${i}]}" | cut -d'=' -f2-)
                uninstall_lock_range=$(get_day_hours "${label}" "${i}" "${use_gui}" "false" "true" "${existing_uninstall}")
                if [ "${uninstall_lock_range}" = "CANCELLED" ]; then
                    return 2
                fi
                day_var="${DAY_VARS[${i}]}"
                if [ "${uninstall_lock_range}" != "skip" ]; then
                    uninstall_lock_hours_lines_ref[${i}]="UNINSTALL_LOCK_HOURS_${day_var}=${uninstall_lock_range}"
                else
                    uninstall_lock_hours_lines_ref[${i}]="UNINSTALL_LOCK_HOURS_${day_var}="
                fi
            done
        fi
        return 0
    fi
    
    if ask_weekend_together "${use_gui}"; then
        weekend_range=$(get_day_hours "Weekends (Saturday and Sunday) - Uninstall Lock Hours" 6 "${use_gui}" "false" "true")
        if [ "${weekend_range}" = "CANCELLED" ]; then
            return 2
        fi
        for i in 6 0; do
            day_var="${DAY_VARS[${i}]}"
            if [ "${weekend_range}" != "skip" ]; then
                uninstall_lock_hours_lines_ref[${i}]="UNINSTALL_LOCK_HOURS_${day_var}=${weekend_range}"
            else
                uninstall_lock_hours_lines_ref[${i}]="UNINSTALL_LOCK_HOURS_${day_var}="
            fi
        done
        day_index=1
        while [ "${day_index}" -le 5 ]; do
            day_name="${DAY_NAMES[${day_index}]}"
            label="Uninstall Lock Hours - ${day_name}"
            allow_back="true"
            [ "${day_index}" -eq 1 ] && allow_back="false"
            existing_uninstall=""
            [ -n "${uninstall_lock_hours_lines_ref[${day_index}]+set}" ] && [ -n "${uninstall_lock_hours_lines_ref[${day_index}]}" ] && existing_uninstall=$(echo "${uninstall_lock_hours_lines_ref[${day_index}]}" | cut -d'=' -f2-)
            uninstall_lock_range=$(get_day_hours "${label}" "${day_index}" "${use_gui}" "${allow_back}" "true" "${existing_uninstall}")
            if [ "${uninstall_lock_range}" = "CANCELLED" ]; then
                return 2
            fi
            if [ "${uninstall_lock_range}" = "back" ]; then
                day_index=$((day_index - 1))
                continue
            fi
            day_var="${DAY_VARS[${day_index}]}"
            if [ "${uninstall_lock_range}" != "skip" ]; then
                uninstall_lock_hours_lines_ref[${day_index}]="UNINSTALL_LOCK_HOURS_${day_var}=${uninstall_lock_range}"
            else
                uninstall_lock_hours_lines_ref[${day_index}]="UNINSTALL_LOCK_HOURS_${day_var}="
            fi
            day_index=$((day_index + 1))
        done
        return 0
    fi
    
    # Per-day loop for all days (Sunday-Saturday, indices 0-6)
    day_index=0
    while [ "${day_index}" -le 6 ]; do
        day_name="${DAY_NAMES[${day_index}]}"
        day_var="${DAY_VARS[${day_index}]}"
        label="Uninstall Lock Hours - ${day_name}"
        existing_uninstall=""
        [ -n "${uninstall_lock_hours_lines_ref[${day_index}]+set}" ] && [ -n "${uninstall_lock_hours_lines_ref[${day_index}]}" ] && existing_uninstall=$(echo "${uninstall_lock_hours_lines_ref[${day_index}]}" | cut -d'=' -f2-)
        uninstall_lock_range=$(get_day_hours "${label}" "${day_index}" "${use_gui}" "false" "true" "${existing_uninstall}")
        exit_code=$?
        if [ "${uninstall_lock_range}" = "CANCELLED" ]; then
            return 2
        fi
        if [ "${uninstall_lock_range}" != "skip" ]; then
            uninstall_lock_hours_lines_ref[${day_index}]="UNINSTALL_LOCK_HOURS_${day_var}=${uninstall_lock_range}"
        else
            uninstall_lock_hours_lines_ref[${day_index}]="UNINSTALL_LOCK_HOURS_${day_var}="
        fi
        if [ ${exit_code} -eq 2 ]; then
            return 2
        fi
        day_index=$((day_index + 1))
    done
    return 0
}
