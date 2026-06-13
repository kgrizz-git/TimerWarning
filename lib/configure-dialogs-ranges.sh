#!/bin/bash

###############################################################################
# Sleep Warning System - Time range management dialogs (configure wizard)
# Sourced by configure-dialogs.sh after list/entry/multi-column helpers
###############################################################################

# Add a time range via time picker; mutates ranges_array nameref.
# Returns 1 when caller should continue the manage_ranges loop (validation error).
_manage_ranges_add() {
    local display_day="$1"
    local -n _mra_ranges="$2"

    local new_range_input
    new_range_input=$(show_time_selection_dialog "Add Time Range - ${display_day}" "" "" "${display_day}")
    local add_exit=$?

    if [ ${add_exit} -ne 0 ] || [ -z "${new_range_input}" ]; then
        return 0
    fi

    if ! validate_time_range "${new_range_input}"; then
        show_error_dialog "Invalid Time Range" "The time range format is invalid. Please enter a valid range (e.g., 11:30pm-5:30am or 23:30-05:30)."
        return 1
    fi

    local normalized
    normalized=$(normalize_time_range "${new_range_input}")

    if ! validate_time_range "${normalized}"; then
        show_error_dialog "Invalid Time Range" "The time range could not be normalized. Please try again."
        return 1
    fi

    _mra_ranges+=("${normalized}")
    return 0
}

# Edit an existing range; mutates ranges_array nameref.
# Returns 1 when caller should continue the manage_ranges loop.
_manage_ranges_edit() {
    local display_day="$1"
    local -n _mre_ranges="$2"

    if [ ${#_mre_ranges[@]} -eq 0 ]; then
        show_info_dialog "No Ranges" "There are no ranges to edit. Please add a range first."
        return 1
    fi

    local range_items=()
    local idx=0
    local range formatted
    for range in "${_mre_ranges[@]}"; do
        formatted=$(format_range_human "${range}" "${display_day}")
        range_items+=("Range $((idx + 1))" "${formatted}")
        idx=$((idx + 1))
    done

    local selected_range_label
    selected_range_label=$(show_multi_column_list_dialog \
        "Select Range to Edit - ${display_day}" \
        "Select a range to edit:" \
        500 300 \
        1 \
        "Range" "Time Range" \
        "${range_items[@]}")

    if [ -z "${selected_range_label}" ]; then
        return 0
    fi

    local range_idx
    range_idx=$(echo "${selected_range_label}" | sed 's/Range //')
    range_idx=$((range_idx - 1))

    if [ ${range_idx} -lt 0 ] || [ ${range_idx} -ge ${#_mre_ranges[@]} ]; then
        return 0
    fi

    local range_to_edit="${_mre_ranges[${range_idx}]}"
    local start_part end_part
    start_part=$(echo "${range_to_edit}" | cut -d'-' -f1)
    end_part=$(echo "${range_to_edit}" | cut -d'-' -f2)

    local edited_range_input
    edited_range_input=$(show_time_selection_dialog "Edit Time Range - ${display_day}" "${start_part}" "${end_part}" "${display_day}")
    local edit_exit=$?

    if [ ${edit_exit} -ne 0 ] || [ -z "${edited_range_input}" ]; then
        return 0
    fi

    if ! validate_time_range "${edited_range_input}"; then
        show_error_dialog "Invalid Time Range" "The time range format is invalid. Please enter a valid range."
        return 1
    fi

    local normalized
    normalized=$(normalize_time_range "${edited_range_input}")

    if ! validate_time_range "${normalized}"; then
        show_error_dialog "Invalid Time Range" "The time range could not be normalized. Please try again."
        return 1
    fi

    _mre_ranges[${range_idx}]="${normalized}"
    return 0
}

# Remove a range after confirmation; mutates ranges_array nameref.
_manage_ranges_delete() {
    local display_day="$1"
    local -n _mrd_ranges="$2"

    if [ ${#_mrd_ranges[@]} -eq 0 ]; then
        show_info_dialog "No Ranges" "There are no ranges to remove."
        return 1
    fi

    local range_items=()
    local idx=0
    local range formatted
    for range in "${_mrd_ranges[@]}"; do
        formatted=$(format_range_human "${range}" "${display_day}")
        range_items+=("Range $((idx + 1))" "${formatted}")
        idx=$((idx + 1))
    done

    local selected_range_label
    selected_range_label=$(show_multi_column_list_dialog \
        "Select Range to Remove - ${display_day}" \
        "Select a range to remove:" \
        500 300 \
        1 \
        "Range" "Time Range" \
        "${range_items[@]}")

    if [ -z "${selected_range_label}" ]; then
        return 0
    fi

    local range_idx
    range_idx=$(echo "${selected_range_label}" | sed 's/Range //')
    range_idx=$((range_idx - 1))

    if [ ${range_idx} -lt 0 ] || [ ${range_idx} -ge ${#_mrd_ranges[@]} ]; then
        return 0
    fi

    local range_to_remove="${_mrd_ranges[${range_idx}]}"
    local formatted_remove
    formatted_remove=$(format_range_human "${range_to_remove}" "${display_day}")

    if ! show_confirm_dialog "Confirm Removal" "Remove this range?\n\n${formatted_remove}" "Yes, Remove" "Cancel" 500 200; then
        return 0
    fi

    local new_array=()
    local i=0
    for range in "${_mrd_ranges[@]}"; do
        if [ ${i} -ne ${range_idx} ]; then
            new_array+=("${range}")
        fi
        i=$((i + 1))
    done
    _mrd_ranges=("${new_array[@]}")
    return 0
}

# Manage multiple time ranges for a day (Phase 2 - Enhancement #16c)
# Parameters:
#   $1: day_name (e.g., "Monday" or "Additional Block Hours - Monday")
#   $2: existing_ranges (comma-separated normalized ranges, e.g., "00:00-05:00,23:00-05:00" or empty)
# Returns: comma-separated normalized ranges string, or empty string on cancel
manage_ranges_dialog() {
    local day_name="$1"
    local existing_ranges="${2:-}"
    
    # Derive short day name and title context for clear UI (Enhancement #16c – display day for which time is being set)
    local display_day="${day_name}"
    if [[ "${day_name}" = *" - "* ]]; then
        display_day="${day_name##* - }"
    fi
    local title_context="Time ranges"
    if [[ "${day_name}" = "Additional Block Hours - "* ]]; then
        title_context="Additional block hours"
    elif [[ "${day_name}" = "Uninstall Lock Hours - "* ]]; then
        title_context="Uninstall lock hours"
    fi
    
    # Parse existing ranges into array
    local ranges_array=()
    if [ -n "${existing_ranges}" ]; then
        local old_ifs="${IFS-}"
        IFS=','
        for range in ${existing_ranges}; do
            range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "${range}" ]; then
                ranges_array+=("${range}")
            fi
        done
        IFS="${old_ifs-$' \t\n'}"
    fi
    
    # Main loop: show list and handle actions
    while true; do
        # Build list items for display
        local list_items=()
        local i=0
        for range in "${ranges_array[@]}"; do
            local formatted
            formatted=$(format_range_human "${range}" "${display_day}")
            list_items+=("Range $((i + 1))" "${formatted}")
            i=$((i + 1))
        done
        
        # Build dialog text (show day clearly – Enhancement #16c)
        local dialog_text="${title_context} for ${display_day}:"
        if [ ${#ranges_array[@]} -eq 0 ]; then
            dialog_text="${dialog_text}\n\nNo ranges configured yet."
        fi
        dialog_text="${dialog_text}\n\nPress Cancel to skip this day."
        
        # Show action selection dialog (Add/Remove with +/− for visibility)
        local actions=("Add range (+)" "Edit range" "Remove range (−)" "Done" "Cancel")
        if type configure_partial_lock_mode_enabled >/dev/null 2>&1 && configure_partial_lock_mode_enabled; then
            actions=("Add range (+)" "Done" "Cancel")
        fi
        local action
        action=$(show_list_dialog "${title_context} – ${display_day}" "${dialog_text}" 600 400 "${actions[@]}")
        local action_exit=$?
        
        if [ ${action_exit} -ne 0 ] || [ -z "${action}" ]; then
            # User cancelled - return empty to indicate cancellation
            return 1
        fi
        
        case "${action}" in
            "Add range (+)")
                _manage_ranges_add "${display_day}" ranges_array || continue
                ;;
            "Edit range")
                _manage_ranges_edit "${display_day}" ranges_array || continue
                ;;
            "Remove range (−)")
                _manage_ranges_delete "${display_day}" ranges_array || continue
                ;;
            "Done")
                # Join ranges and return
                if [ ${#ranges_array[@]} -eq 0 ]; then
                    echo ""
                    return 0
                fi
                
                local result=""
                local first=true
                for r in "${ranges_array[@]}"; do
                    if [ "${first}" = "true" ]; then
                        result="${r}"
                        first=false
                    else
                        result="${result},${r}"
                    fi
                done
                echo "${result}"
                return 0
                ;;
                
            "Cancel")
                # Return empty to indicate cancellation
                return 1
                ;;
        esac
    done
}
