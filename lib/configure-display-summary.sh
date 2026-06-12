#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration summary / review step
# Sourced by configure-display.sh
###############################################################################

show_summary() {
    local use_gui="$1"
    local check_interval="$2"
    local popup_size="$3"
    local popup_position="$4"
    local min_display_time="$5"
    local popup_immovable="$6"
    local popup_auto_close="$7"
    local configure_block_enabled="$8"
    local popup_size_mode="${9:-}"  # Enhancement #3: Optional size mode
    local popup_size_custom="${10:-}"  # Enhancement #3: Optional custom size
    local popup_size_custom_absolute="${11:-}"  # Enhancement #3: Optional custom absolute size
    # Note: summary_lines must be accessed from global scope to preserve sparse array indices
    # Passing sparse arrays as parameters re-indexes them from 0, causing display bugs

    if [ -n "${DEBUG_CONFIG_WRITE:-}" ]; then
        echo "DEBUG: show_summary DAY_NAMES=${DAY_NAMES[*]}" >&2
    fi
    
    # Build summary with human-readable time periods
    local summary="Configuration Summary:\n\n"
    summary="${summary}Popup display frequency: Every ${check_interval} minute(s)\n"
    
    # Format popup size display - show dimensions for all sizes (matching menu display)
    local popup_size_display
    popup_size_display="$(format_popup_size_display "${popup_size}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}" "x" "summary")"
    summary="${summary}Popup Size: ${popup_size_display}\n"
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
    if [ "${popup_auto_close}" = "true" ]; then
        if [ "${min_display_time}" -gt 0 ]; then
            summary="${summary}Auto-Close: Enabled (10s after min display time)\n"
        else
            summary="${summary}Auto-Close: Enabled (10s after popup appears)\n"
        fi
    else
        summary="${summary}Auto-Close: Disabled\n"
    fi
    if [ "${configure_block_enabled}" = "true" ]; then
        summary="${summary}Block Scripts During Restricted/Lock Hours: Enabled\n"
    else
        summary="${summary}Block Scripts During Restricted/Lock Hours: Disabled\n"
    fi

    # Pause settings (Enhancement #21) — globals from configure.sh session
    local summary_pause_enabled="${pause_enabled:-true}"
    local summary_pause_duration="${pause_duration:-5}"
    local summary_pause_cooldown="${pause_cooldown_hours:-24}"
    if [ "${summary_pause_enabled}" = "true" ]; then
        summary="${summary}Pause Feature: Enabled (${summary_pause_duration} min pause, ${summary_pause_cooldown} h between activations)\n"
    else
        summary="${summary}Pause Feature: Disabled\n"
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
                        summary="${summary}- ${day_name}: ${formatted}\n"
                    else
                        summary="${summary}- ${day_name}: No lock hours\n"
                    fi
                fi
            done
        else
            summary="${summary}- None configured\n"
        fi
    else
        summary="${summary}- None configured\n"
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
            # Extract range after the first colon; keep any further colons in HH:MM
            local range
            range=$(echo "${line}" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Check if this is a skipped day (no restrictions)
            if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                summary="${summary}- ${day_name}: [No restrictions]\n"
            else
                # Format to human-readable
                local formatted
                formatted=$(format_ranges_human "${range}" "${day_name}")
                summary="${summary}- ${day_name}: ${formatted}\n"
                
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
                    # Use -f2- to preserve full HH:MM-HH:MM range after first colon
                    prev_range=$(echo "${prev_line}" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
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
            summary="${summary}- ${day_name}: [No restrictions]\n"
        fi
    done
    
    # Add overlap warnings if any
    if [ ${#overlap_warnings[@]} -gt 0 ]; then
        summary="${summary}\nWARNING: OVERLAP DETECTED:\n"
        for warning in "${overlap_warnings[@]}"; do
            summary="${summary}- ${warning}\n"
        done
        summary="${summary}\n(Overlaps are harmless - only one warning shown)\n"
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        local summary_display
        summary_display=$(printf '%b' "${summary}")

        # macOS: one tkinter window with Yes, Save / Back (osascript after tkinter often fails silently)
        if type show_summary_save_dialog_darwin >/dev/null 2>&1; then
            show_summary_save_dialog_darwin \
                "Configuration Summary" \
                "${summary_display}" \
                700 \
                520
            return $?
        fi

        if type show_text_info_dialog >/dev/null 2>&1; then
            show_text_info_dialog \
                "Configuration Summary" \
                "${summary_display}" \
                700 \
                500
        else
            show_info_dialog \
                "Configuration Summary" \
                "${summary_display}" \
                700 \
                500
        fi

        show_question_dialog \
            "Save Configuration?" \
            "Save this configuration to disk?" \
            "Yes, Save" \
            "Back to Main Menu" \
            520 \
            220
        return $?
    else
        summary="${summary}\n"
        echo ""
        echo "=== Configuration Summary ==="
        echo ""
        echo "Popup display frequency: Every ${check_interval} minute(s)"
        
        # Format popup size display - show dimensions for all sizes (matching menu display)
        # Get size mode to determine format
        local size_mode="fixed"
        if [ -n "${popup_size_mode}" ]; then
            size_mode="${popup_size_mode}"
        elif [ -f "${CONFIG_FILE}" ]; then
            local existing_mode
            existing_mode=$(grep -E "^[[:space:]]*POPUP_SIZE_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
            if [ "${existing_mode}" = "display-based" ]; then
                size_mode="display-based"
            fi
        fi
        
        local popup_size_display="${popup_size}"
        
        # Show dimensions with percentage if in percentage mode (display-based)
        if [ "${size_mode}" = "display-based" ]; then
            case "${popup_size}" in
                xsmall) popup_size_display="${popup_size} [15%x15%]" ;;
                small) popup_size_display="${popup_size} [20%x20%]" ;;
                medium) popup_size_display="${popup_size} [30%x30%]" ;;
                large) popup_size_display="${popup_size} [50%x50%]" ;;
                xlarge) popup_size_display="${popup_size} [75%x75%]" ;;
                max) popup_size_display="${popup_size} [90%x90%]" ;;
                custom)
                    # Get custom size value
                    local custom_size=""
                    if [ -n "${popup_size_custom}" ]; then
                        custom_size="${popup_size_custom}"
                    elif [ -f "${CONFIG_FILE}" ]; then
                        custom_size=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
                    fi
                    if [ -n "${custom_size}" ]; then
                        popup_size_display="custom [${custom_size}]"
                    else
                        popup_size_display="custom [50%x50%]"
                    fi
                    ;;
                *)
                    # Custom pixel format or percentage format
                    if echo "${popup_size}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                        popup_size_display="${popup_size}"
                    elif echo "${popup_size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                        popup_size_display="${popup_size}px"
                    fi
                    ;;
            esac
        else
            # Fixed pixel mode - show absolute dimensions
            case "${popup_size}" in
                xsmall) popup_size_display="${popup_size} [384x216]" ;;
                small) popup_size_display="${popup_size} [400x250]" ;;
                medium) popup_size_display="${popup_size} [800x500]" ;;
                large) popup_size_display="${popup_size} [1230x720]" ;;
                xlarge) popup_size_display="${popup_size} [1845x1080]" ;;
                max) popup_size_display="${popup_size} [2214x1296]" ;;
                custom)
                    # Get custom absolute size value
                    local custom_absolute=""
                    if [ -n "${popup_size_custom_absolute}" ]; then
                        custom_absolute="${popup_size_custom_absolute}"
                    elif [ -f "${CONFIG_FILE}" ]; then
                        custom_absolute=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM_ABSOLUTE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
                    fi
                    if [ -n "${custom_absolute}" ] && echo "${custom_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
                        popup_size_display="custom [${custom_absolute}]"
                    else
                        # Fallback to custom size if absolute not available
                        local custom_size=""
                        if [ -n "${popup_size_custom}" ]; then
                            custom_size="${popup_size_custom}"
                        elif [ -f "${CONFIG_FILE}" ]; then
                            custom_size=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
                        fi
                        if [ -n "${custom_size}" ]; then
                            popup_size_display="custom [${custom_size}]"
                        else
                            popup_size_display="custom [1280x720]"
                        fi
                    fi
                    ;;
                *)
                    # Custom pixel format
                    if echo "${popup_size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                        popup_size_display="${popup_size}"
                    fi
                    ;;
            esac
        fi
        echo "Popup Size: ${popup_size_display}"
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
                # Extract range after the first colon; keep any further colons in HH:MM
                local range
                range=$(echo "${line}" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Check if this is a skipped day (no restrictions)
                if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                    echo "  - ${day_name}: [No restrictions]"
                else
                    # Format to human-readable
                    local formatted
                    formatted=$(format_ranges_human "${range}" "${day_name}")
                    echo "  - ${day_name}: ${formatted}"
                    
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
                        # Use -f2- to preserve full HH:MM-HH:MM range after first colon
                        prev_range=$(echo "${prev_line}" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        
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
                echo "  - ${day_name}: [No restrictions]"
            fi
        done
        
        # Show overlap warnings if any
        if [ ${#text_overlap_warnings[@]} -gt 0 ]; then
            echo ""
            echo "WARNING: OVERLAP DETECTED:"
            for warning in "${text_overlap_warnings[@]}"; do
                echo "  - ${warning}"
            done
            echo "  (Overlaps are harmless - only one warning shown)"
        fi
        
        echo ""
        configure_read -p "Save this configuration? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}
