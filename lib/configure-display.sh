#!/bin/bash

###############################################################################
# Sleep Warning System - Complex Display Functions Module
#
# This module provides complex display functions including menus, grids, and
# summary views for the configuration wizard.
#
# Functions:
# - get_section_status()  - Get status indicators for menu display
# - show_main_menu()      - Show main navigation menu
# - show_visual_grid()    - Display visual day/time grid for editing (restricted hours and lock hours)
# - show_summary()        - Show configuration summary with overlap detection
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, DAY_NAMES, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-time.sh (for format_ranges_human, detect_overlaps, get_inherited_restrictions)
# - configure-ui.sh (for confirm_cancel)
###############################################################################

get_section_status() {
    # Access global config_lines array directly
    local weekdays_status="(not configured)"
    local weekends_status="(not configured)"
    
    # Check weekdays (indices 1-5: Monday-Friday)
    local has_weekdays=false
    for i in 1 2 3 4 5; do
        if [ -n "${config_lines[${i}]}" ]; then
            has_weekdays=true
            break
        fi
    done
    
    if [ "${has_weekdays}" = "true" ]; then
        weekdays_status="✓"
    fi
    
    # Check weekends (indices 0, 6: Sunday, Saturday)
    local has_weekends=false
    for i in 0 6; do
        if [ -n "${config_lines[${i}]}" ]; then
            has_weekends=true
            break
        fi
    done
    
    if [ "${has_weekends}" = "true" ]; then
        weekends_status="✓"
    fi
    
    echo "${weekdays_status}|${weekends_status}"
}

# Show main navigation menu
# Parameters:
#   $1  - use_gui (true/false)
#   $2  - check_interval
#   $3  - popup_size
#   $4  - popup_position
#   $5  - min_display_time
#   $6  - popup_immovable
#   $7  - weekdays_status
#   $8  - weekends_status
#   $9  - configure_block_enabled
#   $10 - lock_hours_status (e.g., "(None)" or "(Configured)") - Enhancement #19 Phase 2
#   $11 - uninstall_protection_mode (e.g., "none" or "difficult") - Enhancement #26
show_main_menu() {
    local use_gui="$1"
    local check_interval="$2"
    local popup_size="$3"
    local popup_position="$4"
    local min_display_time="$5"
    local popup_immovable="$6"
    local weekdays_status="$7"
    local weekends_status="$8"
    local configure_block_enabled="$9"
    local lock_hours_status="${10}"
    local uninstall_protection_mode="${11}"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        local tmpfile
        tmpfile=$(mktemp)
        
        # Build window behavior description with all attributes
        local window_desc="Size: ${popup_size}"
        if [ "${popup_size}" = "small" ]; then
            window_desc="${window_desc} (400x250)"
        elif [ "${popup_size}" = "medium" ]; then
            window_desc="${window_desc} (800x500)"
        elif [ "${popup_size}" = "large" ]; then
            window_desc="${window_desc} (2000x1350)"
        fi
        window_desc="${window_desc}, Position: ${popup_position}"
        if [ "${min_display_time}" -gt 0 ]; then
            window_desc="${window_desc}, Min Display: ${min_display_time}s"
        else
            window_desc="${window_desc}, Min Display: Disabled"
        fi
        if [ "${popup_immovable}" = "true" ]; then
            window_desc="${window_desc}, Immovable: On"
        else
            window_desc="${window_desc}, Immovable: Off"
        fi
        
        # Build security settings status indicator
        local security_status=""
        if [ "${configure_block_enabled}" = "true" ]; then
            security_status=" (Enabled)"
        else
            security_status=" (Disabled)"
        fi
        
        # Build lock hours status indicator (Phase 2)
        local lock_status_display=""
        if [ -n "${lock_hours_status}" ]; then
            lock_status_display=" ${lock_hours_status}"
        fi
        
        # Build uninstall protection status indicator (Enhancement #26)
        local uninstall_protection_status=""
        if [ "${uninstall_protection_mode}" = "difficult" ]; then
            uninstall_protection_status=" (Enabled)"
        else
            uninstall_protection_status=" (Disabled)"
        fi
        
        local choice
        choice=$(show_multi_column_list_dialog \
            "Sleep Warning Configuration" \
            "Select a section to configure:" \
            700 \
            450 \
            1 \
            "Option" \
            "Description" \
            "1" "Timer Settings (Check Interval: ${check_interval} min)" \
            "2" "Window Behavior (${window_desc})" \
            "3" "Weekdays Configuration ${weekdays_status}" \
            "4" "Weekends Configuration ${weekends_status}" \
            "5" "Visual Day/Time Grid" \
            "6" "Block Configuration During Restricted Hours${security_status}" \
            "7" "Additional Configuration Block Hours${lock_status_display}" \
            "8" "Uninstall Protection${uninstall_protection_status}" \
            "9" "Review and Save")
        local exit_code=$?
        
        # Check if user cancelled (empty choice and non-zero exit)
        if [ ${exit_code} -ne 0 ] && [ -z "${choice}" ]; then
            exit_code=1
        elif [ -n "${choice}" ]; then
            exit_code=0
        fi
        
        if [ "${exit_code}" -ne 0 ]; then
            # User cancelled - ask if they want to cancel whole config
            if confirm_cancel "${use_gui}"; then
                echo "CANCELLED"
                return 2
            else
                return 1  # Return to show menu again
            fi
        fi
        
        # If OK was clicked but no item selected, default to "Review and Save" (option 9)
        if [ -z "${choice}" ]; then
            choice="9"
        fi
        
        echo "${choice}"
        return 0
    else
        # Text mode
        echo "" >&2
        echo "=== Configuration Menu ===" >&2
        echo "" >&2
        # Build window behavior description with all attributes
        local window_desc="Size: ${popup_size}"
        if [ "${popup_size}" = "small" ]; then
            window_desc="${window_desc} (400x250)"
        elif [ "${popup_size}" = "medium" ]; then
            window_desc="${window_desc} (800x500)"
        elif [ "${popup_size}" = "large" ]; then
            window_desc="${window_desc} (2000x1350)"
        fi
        window_desc="${window_desc}, Position: ${popup_position}"
        if [ "${min_display_time}" -gt 0 ]; then
            window_desc="${window_desc}, Min Display: ${min_display_time}s"
        else
            window_desc="${window_desc}, Min Display: Disabled"
        fi
        if [ "${popup_immovable}" = "true" ]; then
            window_desc="${window_desc}, Immovable: On"
        else
            window_desc="${window_desc}, Immovable: Off"
        fi
        
        echo "1. Timer Settings (Check Interval: ${check_interval} min)" >&2
        echo "   Configure how often the system checks for restricted hours" >&2
        echo "" >&2
        echo "2. Window Behavior (${window_desc})" >&2
        echo "   Configure popup size, position, display time, and immovable settings" >&2
        echo "" >&2
        echo "3. Weekdays Configuration ${weekdays_status}" >&2
        echo "   Set restricted hours for Monday through Friday" >&2
        echo "" >&2
        echo "4. Weekends Configuration ${weekends_status}" >&2
        echo "   Set restricted hours for Saturday and Sunday" >&2
        echo "" >&2
        echo "5. Visual Day/Time Grid" >&2
        echo "   View and edit all days in a visual grid format" >&2
        echo "" >&2
        # Build security settings status indicator
        local security_status=""
        if [ "${configure_block_enabled}" = "true" ]; then
            security_status=" (Enabled)"
        else
            security_status=" (Disabled)"
        fi
        # Build lock hours status indicator (Phase 2)
        local lock_status_display=""
        if [ -n "${lock_hours_status}" ]; then
            lock_status_display=" ${lock_hours_status}"
        fi
        echo "6. Block Configuration During Restricted Hours${security_status}" >&2
        echo "   Enable/disable blocking of configure.sh and manage.sh during restricted hours" >&2
        echo "   (Must be enabled for Additional Configuration Block Hours to take effect)" >&2
        echo "" >&2
        echo "7. Additional Configuration Block Hours${lock_status_display}" >&2
        echo "   Configure additional hours when configuration/management is blocked" >&2
        echo "   (Only applies when Block Configuration During Restricted Hours is enabled)" >&2
        echo "" >&2
        # Build uninstall protection status indicator (Enhancement #26)
        local uninstall_protection_status=""
        if [ "${uninstall_protection_mode}" = "difficult" ]; then
            uninstall_protection_status=" (Enabled)"
        else
            uninstall_protection_status=" (Disabled)"
        fi
        echo "8. Uninstall Protection${uninstall_protection_status}" >&2
        echo "   Configure protection mode for uninstall.sh during restricted hours" >&2
        echo "" >&2
        echo "9. Review and Save" >&2
        echo "   Review your configuration and save changes" >&2
        echo "" >&2
        echo "To cancel and exit without saving, press Ctrl+C" >&2
        echo "" >&2
        
        while true; do
            read -p "Select option [1-9]: " choice >&2
            case "${choice}" in
                1|2|3|4|5|6|7|8|9)
                    echo "${choice}"
                    return 0
                    ;;
                *)
                    echo "Invalid option. Please enter 1-9." >&2
                    ;;
            esac
        done
    fi
}

show_visual_grid() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    local -n lock_hours_lines_ref="$4"  # Pass by reference (Enhancement #19 Phase 2 - lock hours)
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            # Build grid data for multi-column list
            # Store day names, restricted hours, and lock hours separately for alternating format
            local day_names=()
            local restricted_hours_list=()
            local lock_hours_list=()
            
            for day_index in 0 1 2 3 4 5 6; do
                local day_name="${DAY_NAMES[${day_index}]}"
                local restricted_hours=""
                local lock_hours=""
                
                # Get restricted hours
                if [ -n "${summary_lines_ref[${day_index}]}" ]; then
                    # Day has configuration (may be restricted or explicitly skipped)
                    local line="${summary_lines_ref[${day_index}]}"
                    local range
                    range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                        # No explicit restrictions - check for inherited overnight restrictions
                        local inherited
                        inherited=$(get_inherited_restrictions "${day_index}" summary_lines_ref)
                        if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                            restricted_hours="${inherited}"
                        else
                            restricted_hours="(no restrictions)"
                        fi
                    else
                        # Has restrictions - show formatted time ranges
                        restricted_hours=$(format_ranges_human "${range}" "${day_name}")
                    fi
                else
                    # Day has no configuration - check for inherited overnight restrictions
                    local inherited
                    inherited=$(get_inherited_restrictions "${day_index}" summary_lines_ref)
                    if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                        restricted_hours="${inherited}"
                    else
                        restricted_hours="(no restrictions)"
                    fi
                fi
                
                # Get lock hours (Enhancement #19 Phase 2)
                if [ -n "${lock_hours_lines_ref[${day_index}]:-}" ]; then
                    # Lock hours line exists - extract value
                    local lock_entry="${lock_hours_lines_ref[${day_index}]}"
                    local lock_range
                    lock_range=$(echo "${lock_entry}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    if [ -n "${lock_range}" ]; then
                        # Has lock hours - show formatted time ranges
                        lock_hours=$(format_ranges_human "${lock_range}" "${day_name}")
                    else
                        # Explicitly disabled (empty value)
                        lock_hours="(no lock hours)"
                    fi
                else
                    # No lock hours configured
                    lock_hours="(no lock hours)"
                fi
                
                # Store separately
                day_names+=("${day_name}")
                restricted_hours_list+=("${restricted_hours}")
                lock_hours_list+=("${lock_hours}")
            done
            
            # Add "Back to Menu" option
            # Note: Use plain text for display (YAD interprets << as Pango markup)
            day_names+=("[Back]")
            restricted_hours_list+=("Return to Main Menu")
            lock_hours_list+=("")
            
            # Build data array in alternating format for multi-column dialog
            # Format: col1_row1, col2_row1, col3_row1, col1_row2, col2_row2, col3_row2, ...
            local grid_data=()
            for i in "${!day_names[@]}"; do
                grid_data+=("${day_names[${i}]}")
                grid_data+=("${restricted_hours_list[${i}]}")
                grid_data+=("${lock_hours_list[${i}]}")
            done
            
            # Debug: Log what we're sending to dialog (if DEBUG_GRID is set)
            if [ -n "${DEBUG_GRID:-}" ]; then
                echo "DEBUG: Grid data array (alternating Day, Restricted Hours, Lock Hours):" >&2
                for i in "${!grid_data[@]}"; do
                    echo "  [${i}]: '${grid_data[${i}]}'" >&2
                done
            fi
            
            # Use multi-column abstraction function
            local selected
            selected=$(show_multi_column_list_dialog \
                "Visual Day/Time Grid" \
                "Select a day to edit its restricted hours or lock hours:" \
                1000 \
                500 \
                1 \
                "Day" \
                "Restricted Hours" \
                "Lock Hours" \
                "${grid_data[@]}")
            local exit_code=$?
            
            # Check if user cancelled (empty choice and non-zero exit)
            if [ ${exit_code} -ne 0 ] && [ -z "${selected}" ]; then
                exit_code=1
            elif [ -n "${selected}" ]; then
                exit_code=0
            fi
            
            if [ -n "${DEBUG_GRID:-}" ]; then
                echo "DEBUG: dialog exit code: ${exit_code}" >&2
                echo "DEBUG: Selected value: '${selected}'" >&2
            fi
            
            if [ "${exit_code}" -ne 0 ] || [ -z "${selected}" ]; then
                # User cancelled - return to main menu
                declare -g grid_result_var="BACK"
                return 0
            fi
            
            # Extract day name from selection
            # With --print-column=1, we get just the Day column (first column)
            local selected_day
            selected_day=$(echo "${selected}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Check if "Back to Menu" was selected
            if [ "${selected_day}" = "[Back]" ]; then
                declare -g grid_result_var="BACK"
                return 0
            fi
            
            # Find day index
            local day_index=-1
            for i in 0 1 2 3 4 5 6; do
                if [ "${DAY_NAMES[${i}]}" = "${selected_day}" ]; then
                    day_index=${i}
                    break
                fi
            done
            
            if [ "${day_index}" -lt 0 ]; then
                # Invalid selection
                show_info_dialog \
                    "Invalid Selection" \
                    "Invalid day selection." \
                    400 \
                    150
                continue
            fi
            
            # Store day index in global variable
            declare -g grid_result_var="${day_index}"
            return 0
        done
    else
        # Text mode
        while true; do
            echo ""
            echo "=== Visual Day/Time Grid ==="
            echo ""
            echo "Select a day to edit its restricted hours or lock hours:"
            echo ""
            
            # Display grid with tab-separated table format
            # Header
            printf "%-3s\t%-9s\t%-30s\t%s\n" "#" "Day" "Restricted Hours" "Lock Hours"
            printf "%-3s\t%-9s\t%-30s\t%s\n" "---" "---" "----------------" "----------"
            
            for day_index in 0 1 2 3 4 5 6; do
                local day_name="${DAY_NAMES[${day_index}]}"
                local restricted_hours=""
                local lock_hours=""
                
                # Get restricted hours
                if [ -n "${summary_lines_ref[${day_index}]}" ]; then
                    # Day has configuration
                    local line="${summary_lines_ref[${day_index}]}"
                    local range
                    range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                        # No explicit restrictions - check for inherited overnight restrictions
                        local inherited
                        inherited=$(get_inherited_restrictions "${day_index}" summary_lines_ref)
                        if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                            restricted_hours="${inherited}"
                        else
                            restricted_hours="(no restrictions)"
                        fi
                    else
                        # Has restrictions - show formatted time ranges
                        restricted_hours=$(format_ranges_human "${range}" "${day_name}")
                    fi
                else
                    # Day has no configuration - check for inherited overnight restrictions
                    local inherited
                    inherited=$(get_inherited_restrictions "${day_index}" summary_lines_ref)
                    if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                        restricted_hours="${inherited}"
                    else
                        restricted_hours="(no restrictions)"
                    fi
                fi
                
                # Get lock hours (Enhancement #19 Phase 2)
                if [ -n "${lock_hours_lines_ref[${day_index}]:-}" ]; then
                    # Lock hours line exists - extract value
                    local lock_entry="${lock_hours_lines_ref[${day_index}]}"
                    local lock_range
                    lock_range=$(echo "${lock_entry}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    if [ -n "${lock_range}" ]; then
                        # Has lock hours - show formatted time ranges
                        lock_hours=$(format_ranges_human "${lock_range}" "${day_name}")
                    else
                        # Explicitly disabled (empty value)
                        lock_hours="(no lock hours)"
                    fi
                else
                    # No lock hours configured
                    lock_hours="(no lock hours)"
                fi
                
                # Display as table: number, day name, restricted hours, lock hours
                printf "%d.\t%-9s\t%-30s\t%s\n" $((day_index + 1)) "${day_name}:" "${restricted_hours}" "${lock_hours}"
            done
            
            echo ""
            echo "0. Back to Main Menu"
            echo ""
            
            while true; do
                read -p "Select option [0-7]: " choice
                    case "${choice}" in
                    0)
                        declare -g grid_result_var="BACK"
                        return 0
                        ;;
                    1|2|3|4|5|6|7)
                        # Convert to day index (1-7 -> 0-6)
                        local day_index=$((choice - 1))
                        declare -g grid_result_var="${day_index}"
                        return 0
                        ;;
                    *)
                        echo "Invalid option. Please enter 0-7." >&2
                        ;;
                    esac
            done
        done
    fi
}

show_summary() {
    local use_gui="$1"
    local check_interval="$2"
    local popup_size="$3"
    local popup_position="$4"
    local min_display_time="$5"
    local popup_immovable="$6"
    local configure_block_enabled="$7"
    # Note: summary_lines must be accessed from global scope to preserve sparse array indices
    # Passing sparse arrays as parameters re-indexes them from 0, causing display bugs
    
    # Build summary with human-readable time periods
    local summary="Configuration Summary:\n\n"
    summary="${summary}Check Interval: Every ${check_interval} minute(s)\n"
    summary="${summary}Popup Size: ${popup_size}\n"
    summary="${summary}Popup Position: ${popup_position}\n"
    if [ "${min_display_time}" -eq 0 ]; then
        summary="${summary}Minimum Display Time: Disabled\n"
    else
        summary="${summary}Minimum Display Time: ${min_display_time} seconds\n"
    fi
    if [ "${popup_immovable}" = "true" ]; then
        summary="${summary}Prevent Window Movement: Enabled\n"
    else
        summary="${summary}Prevent Window Movement: Disabled\n"
    fi
    if [ "${configure_block_enabled}" = "true" ]; then
        summary="${summary}Block Scripts During Restricted/Lock Hours: Enabled\n"
    else
        summary="${summary}Block Scripts During Restricted/Lock Hours: Disabled\n"
    fi
    
    # Lock hours summary (Enhancement #19 Phase 2)
    # Uses global lock_hours_lines array if available; if not present, shows "None configured".
    summary="${summary}\nLock Hours (configure.sh/manage.sh):\n"
    local has_lock_hours=false
    if declare -p lock_hours_lines >/dev/null 2>&1; then
        local day_index
        for day_index in 0 1 2 3 4 5 6; do
            if [ -n "${lock_hours_lines[${day_index}]:-}" ]; then
                has_lock_hours=true
                break
            fi
        done
        
        if [ "${has_lock_hours}" = "true" ]; then
            local day_index
            for day_index in 0 1 2 3 4 5 6; do
                local lock_entry="${lock_hours_lines[${day_index}]:-}"
                local day_name="${DAY_NAMES[${day_index}]}"
                if [ -n "${lock_entry}" ]; then
                    # Extract range part after '=' (may be empty for explicitly disabled)
                    local ranges
                    ranges=$(echo "${lock_entry}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [ -n "${ranges}" ]; then
                        local formatted
                        formatted=$(format_ranges_human "${ranges}" "${day_name}")
                        summary="${summary}• ${day_name}: ${formatted}\n"
                    else
                        summary="${summary}• ${day_name}: No lock hours\n"
                    fi
                fi
            done
        else
            summary="${summary}• None configured\n"
        fi
    else
        summary="${summary}• None configured\n"
    fi
    
    summary="${summary}\nRestricted Hours:\n"
    
    # Check for overlaps and format times
    local overlap_warnings=()
    
    # Iterate through all days in calendar order (Sun-Sat, indices 0-6)
    for day_index in 0 1 2 3 4 5 6; do
        local day_name="${DAY_NAMES[${day_index}]}"
        
        if [ -n "${summary_lines[${day_index}]}" ]; then
            # Day has restrictions configured (or explicitly skipped)
            local line="${summary_lines[${day_index}]}"
            # Extract day name and range
            local range
            range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Check if this is a skipped day (no restrictions)
            if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                summary="${summary}• ${day_name}: No restrictions\n"
            else
                # Format to human-readable
                local formatted
                formatted=$(format_ranges_human "${range}" "${day_name}")
                summary="${summary}• ${day_name}: ${formatted}\n"
                
                # Check for overlaps with previous calendar day
                local prev_day_index
                if [ "${day_index}" -eq 0 ]; then
                    # Sunday (0) - check overlap with Saturday (6)
                    prev_day_index=6
                else
                    prev_day_index=$((day_index - 1))
                fi
                
                if [ -n "${summary_lines[${prev_day_index}]}" ]; then
                    local prev_line="${summary_lines[${prev_day_index}]}"
                    local prev_day_name prev_range
                    prev_day_name=$(echo "${prev_line}" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    prev_range=$(echo "${prev_line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    # Only check overlaps if previous day is not skipped
                    if [ "${prev_range}" != "(no restrictions)" ] && [ -n "${prev_range}" ]; then
                        local overlap
                        overlap=$(detect_overlaps "${prev_day_index}" "${prev_range}" "${day_index}" "${range}")
                        if [ $? -eq 0 ]; then
                            local range1 range2 overlap_hours
                            range1=$(echo "${overlap}" | cut -d'|' -f1)
                            range2=$(echo "${overlap}" | cut -d'|' -f2)
                            overlap_hours=$(echo "${overlap}" | cut -d'|' -f3)
                            overlap_warnings+=("${prev_day_name} ${range1} and ${day_name} ${range2} both cover ${overlap_hours}")
                        fi
                    fi
                fi
            fi
        else
            # Day has no restrictions configured
            summary="${summary}• ${day_name}: No restrictions\n"
        fi
    done
    
    # Add overlap warnings if any
    if [ ${#overlap_warnings[@]} -gt 0 ]; then
        summary="${summary}\n⚠️  OVERLAP WARNING:\n"
        for warning in "${overlap_warnings[@]}"; do
            summary="${summary}• ${warning}\n"
        done
        summary="${summary}\n(Overlaps are harmless - only one warning shown)\n"
    fi
    
    summary="${summary}\n\nSave this configuration?"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Sleep Warning Configuration" \
            "${summary}" \
            "Yes, Save" \
            "Cancel" \
            700 \
            500
        return $?
    else
        echo ""
        echo "=== Configuration Summary ==="
        echo ""
        echo "Check Interval: Every ${check_interval} minute(s)"
        echo "Popup Size: ${popup_size}"
        echo "Popup Position: ${popup_position}"
        if [ "${min_display_time}" -eq 0 ]; then
            echo "Minimum Display Time: Disabled"
        else
            echo "Minimum Display Time: ${min_display_time} seconds"
        fi
        if [ "${popup_immovable}" = "true" ]; then
            echo "Prevent Window Movement: Enabled"
        else
            echo "Prevent Window Movement: Disabled"
        fi
        if [ "${configure_block_enabled}" = "true" ]; then
            echo "Block Scripts During Restricted Hours: Enabled"
        else
            echo "Block Scripts During Restricted Hours: Disabled"
        fi
        echo ""
        echo "Restricted Hours:"
        
        # Show human-readable times and check for overlaps
        local text_overlap_warnings=()
        
        # Iterate through all days in calendar order (Sun-Sat, indices 0-6)
        for day_index in 0 1 2 3 4 5 6; do
            local day_name="${DAY_NAMES[${day_index}]}"
            
            if [ -n "${summary_lines[${day_index}]}" ]; then
                # Day has restrictions configured (or explicitly skipped)
                local line="${summary_lines[${day_index}]}"
                # Extract range
                local range
                range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Check if this is a skipped day (no restrictions)
                if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                    echo "  • ${day_name}: No restrictions"
                else
                    # Format to human-readable
                    local formatted
                    formatted=$(format_ranges_human "${range}" "${day_name}")
                    echo "  • ${day_name}: ${formatted}"
                    
                    # Check for overlaps with previous calendar day
                    local prev_day_index
                    if [ "${day_index}" -eq 0 ]; then
                        # Sunday (0) - check overlap with Saturday (6)
                        prev_day_index=6
                    else
                        prev_day_index=$((day_index - 1))
                    fi
                    
                    if [ -n "${summary_lines[${prev_day_index}]}" ]; then
                        local prev_line="${summary_lines[${prev_day_index}]}"
                        local prev_day_name prev_range
                        prev_day_name=$(echo "${prev_line}" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        prev_range=$(echo "${prev_line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        
                        # Only check overlaps if previous day is not skipped
                        if [ "${prev_range}" != "(no restrictions)" ] && [ -n "${prev_range}" ]; then
                            local overlap
                            overlap=$(detect_overlaps "${prev_day_index}" "${prev_range}" "${day_index}" "${range}")
                            if [ $? -eq 0 ]; then
                                local range1 range2 overlap_hours
                                range1=$(echo "${overlap}" | cut -d'|' -f1)
                                range2=$(echo "${overlap}" | cut -d'|' -f2)
                                overlap_hours=$(echo "${overlap}" | cut -d'|' -f3)
                                text_overlap_warnings+=("${prev_day_name} ${range1} and ${day_name} ${range2} both cover ${overlap_hours}")
                            fi
                        fi
                    fi
                fi
            else
                # Day has no restrictions configured
                echo "  • ${day_name}: No restrictions"
            fi
        done
        
        # Show overlap warnings if any
        if [ ${#text_overlap_warnings[@]} -gt 0 ]; then
            echo ""
            echo "⚠️  OVERLAP WARNING:"
            for warning in "${text_overlap_warnings[@]}"; do
                echo "  • ${warning}"
            done
            echo "  (Overlaps are harmless - only one warning shown)"
        fi
        
        echo ""
        read -p "Save this configuration? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}
