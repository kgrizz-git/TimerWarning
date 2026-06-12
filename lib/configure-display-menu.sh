#!/bin/bash

###############################################################################
# Sleep Warning System - Configure display menus (main + window behavior)
# Sourced by configure-display.sh
###############################################################################

# Show main navigation menu
# Parameters:
#   $1  - use_gui (true/false)
#   $2  - check_interval
#   $3  - popup_size
#   $4  - popup_position
#   $5  - min_display_time
#   $6  - popup_immovable
#   $7  - popup_auto_close
#   $8  - weekdays_status
#   $9  - weekends_status
#   $10 - configure_block_enabled
#   $11 - lock_hours_status (e.g., "[None]" or "[Configured]") - Enhancement #19 Phase 2
#   $12 - uninstall_protection_mode (e.g., "none" or "difficult") - Enhancement #26
#   $13 - uninstall_lock_hours_status (e.g., "[None]" or "[Configured]") - Enhancement #26 Phase 2
#   $14 - pause_enabled (e.g., "true" or "false") - Enhancement #21
#   $15 - pause_duration (e.g., "5") - Enhancement #21
#   $16 - pause_cooldown_hours (e.g., "6", "8", "12", or "24") - Enhancement #21
#   $17 - dialog_tool_status (e.g., " [Automatic]" or " [yad]") - Enhancement #25
#   $18 - config_lock_enabled (e.g., "true" or "false") - Enhancement #18
#   $19 - popup_size_mode (optional, e.g., "fixed" or "display-based") - Enhancement #3
#   $20 - popup_size_custom (optional, e.g., "95%x95%") - Enhancement #3
#   $21 - popup_size_custom_absolute (optional, e.g., "2432x1368") - Enhancement #3
#   $22 - service_mode_status (e.g., "[desktop]" or "[gaming]" or "[none]") - current service mode for option 12
show_main_menu() {
    local use_gui="$1"
    local check_interval="$2"
    local popup_size="$3"
    local popup_position="$4"
    local min_display_time="$5"
    local popup_immovable="$6"
    local popup_auto_close="$7"
    local weekdays_status="$8"
    local weekends_status="$9"
    local configure_block_enabled="${10}"
    local lock_hours_status="${11}"
    local uninstall_protection_mode="${12}"
    local uninstall_lock_hours_status="${13}"
    local pause_enabled="${14}"
    local pause_duration="${15}"
    local pause_cooldown_hours="${16}"
    local dialog_tool_status="${17}"
    local config_lock_enabled="${18}"
    local popup_size_mode="${19:-}"  # Enhancement #3: Optional size mode
    local popup_size_custom="${20:-}"  # Enhancement #3: Optional custom size
    local popup_size_custom_absolute="${21:-}"  # Enhancement #3: Optional custom absolute size
    local service_mode_status="${22:-[none]}"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        # Build window behavior description with all attributes
        # This is for Enhancement #3 (Enhanced Window Size Options)
        local window_desc="Size: $(format_popup_size_display "${popup_size}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}" "x" "menu")"
        
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
        if [ "${popup_auto_close}" = "true" ]; then
            window_desc="${window_desc}, Auto-close: 10s after min display time"
        else
            window_desc="${window_desc}, Auto-close: Off"
        fi
        
        # Build security settings status indicator (combined)
        # Ensure variables have defaults if not set
        local config_lock_val="${config_lock_enabled:-false}"
        local configure_block_val="${configure_block_enabled:-false}"
        
        local security_status=""
        if [ "${configure_block_val}" = "true" ] && [ "${config_lock_val}" = "true" ]; then
            security_status=" [Both Enabled]"
        elif [ "${configure_block_val}" = "true" ]; then
            security_status=" [Script Block: On, File Lock: Off]"
        elif [ "${config_lock_val}" = "true" ]; then
            security_status=" [Script Block: Off, File Lock: On]"
        else
            security_status=" [Both Disabled]"
        fi
        
        # Build lock hours status indicator (Phase 2)
        local lock_status_display=""
        if [ -n "${lock_hours_status}" ]; then
            lock_status_display=" ${lock_hours_status}"
        fi
        
        # Build uninstall protection status indicator (Enhancement #26)
        local uninstall_protection_status=""
        if [ "${uninstall_protection_mode}" = "difficult" ]; then
            uninstall_protection_status=" [Enabled]"
        else
            uninstall_protection_status=" [Disabled]"
        fi
        
        # Build uninstall lock hours status indicator (Enhancement #26 Phase 2)
        local uninstall_lock_status_display=""
        if [ -n "${uninstall_lock_hours_status}" ]; then
            uninstall_lock_status_display=" ${uninstall_lock_hours_status}"
        fi
        
        # Build pause settings status indicator (Enhancement #21)
        local pause_status=""
        if [ "${pause_enabled}" = "true" ]; then
            pause_status=" [Enabled, ${pause_duration} min, ${pause_cooldown_hours}h cooldown]"
        else
            pause_status=" [Disabled]"
        fi
        
        # Ensure all status variables are set (prevent empty values from causing misalignment)
        local safe_security_status="${security_status:- [Both Disabled]}"
        local safe_lock_status="${lock_status_display:-}"
        local safe_uninstall_protection="${uninstall_protection_status:- [Disabled]}"
        local safe_uninstall_lock="${uninstall_lock_status_display:-}"
        local safe_pause_status="${pause_status:- [Disabled]}"
        local safe_dialog_status="${dialog_tool_status:-}"
        local safe_weekdays="${weekdays_status:-}"
        local safe_weekends="${weekends_status:-}"
        
        local choice
        choice=$(show_multi_column_list_dialog \
            "Sleep Warning Configuration" \
            "Select a section to configure:" \
            700 \
            500 \
            1 \
            "Option" \
            "Description" \
            "1" "Popup display frequency [Every ${check_interval} min]" \
            "2" "Window Behavior [opens submenu]" \
            "3" "Weekdays Configuration ${safe_weekdays}" \
            "4" "Weekends Configuration ${safe_weekends}" \
            "5" "Configuration Lock (Tighten-Only) and Config File Locking${safe_security_status}" \
            "6" "Additional Configuration Lock Hours${safe_lock_status}" \
            "7" "Uninstall Protection${safe_uninstall_protection}" \
            "8" "Additional Uninstall Protection Hours${safe_uninstall_lock}" \
            "9" "View Weekly Hours Settings" \
            "10" "Enable pause, duration, and cooldown${safe_pause_status}" \
            "11" "Dialog Tool Selection ${safe_dialog_status}" \
            "12" "Service Mode Configuration ${service_mode_status}" \
            "13" "Review and Save")
        local exit_code=$?
        
        # Check if user cancelled (empty choice and non-zero exit)
        if [ ${exit_code} -ne 0 ] && [ -z "${choice}" ]; then
            exit_code=1
        elif [ -n "${choice}" ]; then
            exit_code=0
        fi
        
        if [ "${exit_code}" -ne 0 ]; then
            local cancel_action
            cancel_action=$(handle_main_menu_cancel_menu "${use_gui}" "You closed the configuration menu. What would you like to do?")
            local cancel_rc=$?
            if [ "${cancel_action}" = "CANCELLED" ] || [ ${cancel_rc} -eq 2 ]; then
                echo "CANCELLED"
                return 2
            fi
            return 1
        fi

        # OK with no selection: re-show menu (do not default to Review and Save)
        if [ -z "${choice}" ]; then
            return 1
        fi
        
        echo "${choice}"
        return 0
    else
        # Text mode
        echo "" >&2
        echo "=== Configuration Menu ===" >&2
        echo "" >&2
        # Build window behavior description with all attributes
        # This is for Enhancement #3 (Enhanced Window Size Options)
        local window_desc="Size: $(format_popup_size_display "${popup_size}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}" "×" "menu")"
        
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
        if [ "${popup_auto_close}" = "true" ]; then
            window_desc="${window_desc}, Auto-close: 10s after min display time"
        else
            window_desc="${window_desc}, Auto-close: Off"
        fi
        
        echo "1. Popup display frequency [Every ${check_interval} min]" >&2
        echo "   How often to show warning popups (1-60 minutes)" >&2
        echo "" >&2
        echo "2. Window Behavior [opens submenu for size, position, etc.]" >&2
        echo "   Configure popup size, position, display time, immovable, and auto-close" >&2
        echo "" >&2
        echo "3. Weekdays Configuration ${weekdays_status}" >&2
        echo "   Set restricted hours for Monday through Friday" >&2
        echo "" >&2
        echo "4. Weekends Configuration ${weekends_status}" >&2
        echo "   Set restricted hours for Saturday and Sunday" >&2
        echo "" >&2
        # Build security settings status indicator (combined)
        local config_lock_val="${config_lock_enabled:-false}"
        local configure_block_val="${configure_block_enabled:-false}"
        local security_status=""
        if [ "${configure_block_val}" = "true" ] && [ "${config_lock_val}" = "true" ]; then
            security_status=" [Both Enabled]"
        elif [ "${configure_block_val}" = "true" ]; then
            security_status=" [Script Block: On, File Lock: Off]"
        elif [ "${config_lock_val}" = "true" ]; then
            security_status=" [Script Block: Off, File Lock: On]"
        else
            security_status=" [Both Disabled]"
        fi
        local lock_status_display=""
        if [ -n "${lock_hours_status}" ]; then
            lock_status_display=" ${lock_hours_status}"
        fi
        echo "5. Configuration Lock (Tighten-Only) and Config File Locking${security_status}" >&2
        echo "   Restrict configure/manage to tighten-only edits, and lock the config file, during restricted hours" >&2
        echo "" >&2
        echo "6. Additional Configuration Lock Hours${lock_status_display}" >&2
        echo "   Configure additional hours when configuration changes are restricted to tighten-only" >&2
        echo "   (Only applies when Configuration Lock is enabled)" >&2
        echo "" >&2
        local uninstall_protection_status=""
        if [ "${uninstall_protection_mode}" = "difficult" ]; then
            uninstall_protection_status=" [Enabled]"
        else
            uninstall_protection_status=" [Disabled]"
        fi
        echo "7. Uninstall Protection${uninstall_protection_status}" >&2
        echo "   Configure protection mode for uninstall.sh during restricted hours" >&2
        echo "" >&2
        local uninstall_lock_status_display=""
        if [ -n "${uninstall_lock_hours_status}" ]; then
            uninstall_lock_status_display=" ${uninstall_lock_hours_status}"
        fi
        echo "8. Additional Uninstall Protection Hours${uninstall_lock_status_display}" >&2
        echo "   Configure additional hours when difficult uninstall verification is required" >&2
        echo "   (Only applies when Uninstall Protection is enabled)" >&2
        echo "" >&2
        echo "9. View Weekly Hours Settings" >&2
        echo "   View and edit all days in a visual grid format" >&2
        echo "" >&2
        local pause_status=""
        if [ "${pause_enabled}" = "true" ]; then
            pause_status=" [Enabled, ${pause_duration} min, ${pause_cooldown_hours}h cooldown]"
        else
            pause_status=" [Disabled]"
        fi
        echo "10. Enable pause, duration, and cooldown${pause_status}" >&2
        echo "   Configure pause for warning popups (duration and hours-between-pauses)" >&2
        echo "" >&2
        echo "11. Dialog Tool Selection ${dialog_tool_status}" >&2
        echo "   Select which dialog tool to use for popup windows" >&2
        echo "" >&2
        echo "12. Service Mode Configuration ${service_mode_status}" >&2
        echo "   Configure systemd service for Desktop Mode or Gaming Mode" >&2
        echo "" >&2
        echo "13. Review and Save" >&2
        echo "   Review your configuration and save changes" >&2
        echo "" >&2
        echo "To cancel and exit without saving, press Ctrl+C" >&2
        echo "" >&2
        
        while true; do
            # configure_read aborts on EOF instead of spinning (see configure-core.sh).
            configure_read -p "Select option [1-13]: " choice
            case "${choice}" in
                1|2|3|4|5|6|7|8|9|10|11|12|13)
                    echo "${choice}"
                    return 0
                    ;;
                *)
                    echo "Invalid option. Please enter 1-13." >&2
                    ;;
            esac
        done
    fi
}

# Show Window Behavior submenu (size, position, min display time, immovable, auto-close, Back).
# Shows current value next to each option (from memory when valid, otherwise from config).
# Parameters: $1=use_gui, $2=popup_size, $3=popup_size_mode, $4=popup_size_custom,
#   $5=popup_size_custom_absolute, $6=popup_position, $7=min_display_time,
#   $8=popup_immovable, $9=popup_auto_close. Empty params are filled from CONFIG_FILE when available.
# Returns: stdout = "1"-"6"; return 0 = valid choice; return 1 = Back/cancel; return 2 = CANCELLED (exit config).
show_window_behavior_submenu() {
    local use_gui="$1"
    local popup_size="${2:-}"
    local popup_size_mode="${3:-}"
    local popup_size_custom="${4:-}"
    local popup_size_custom_absolute="${5:-}"
    local popup_position="${6:-}"
    local min_display_time="${7:-}"
    local popup_immovable="${8:-}"
    local popup_auto_close="${9:-}"

    # Fallback to config file when params are empty (tests only; wizard passes memory values).
    if [ "${CONFIGURE_ALLOW_DISK_FALLBACK:-}" = "1" ] && [ -f "${CONFIG_FILE}" ]; then
        [ -z "${popup_size}" ] && popup_size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ -z "${popup_size_mode}" ] && popup_size_mode=$(grep -E "^[[:space:]]*POPUP_SIZE_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        [ -z "${popup_size_custom}" ] && popup_size_custom=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ -z "${popup_size_custom_absolute}" ] && popup_size_custom_absolute=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM_ABSOLUTE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ -z "${popup_position}" ] && popup_position=$(grep -E "^[[:space:]]*POPUP_POSITION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ -z "${min_display_time}" ] && min_display_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ -z "${popup_immovable}" ] && popup_immovable=$(grep -E "^[[:space:]]*POPUP_IMMOVABLE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        [ -z "${popup_auto_close}" ] && popup_auto_close=$(grep -E "^[[:space:]]*POPUP_AUTO_CLOSE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    fi
    # Defaults when still empty
    [ -z "${popup_size}" ] && popup_size="medium"
    [ -z "${popup_size_mode}" ] && popup_size_mode="fixed"
    [ -z "${popup_position}" ] && popup_position="center"
    [[ ! "${min_display_time}" =~ ^[0-9]+$ ]] && min_display_time="0"
    [ "${popup_immovable}" != "true" ] && popup_immovable="false"
    [ "${popup_auto_close}" != "true" ] && popup_auto_close="false"

    # Build description strings with current values
    local size_display
    size_display=$(format_popup_size_display "${popup_size}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}" "x" "menu")
    local desc_1="Popup size — ${size_display}"
    local pos_display="${popup_position}"
    case "${popup_position}" in
        center) pos_display="Center" ;;
        top-left) pos_display="Top-left" ;;
    esac
    local desc_2="Position — ${pos_display}"
    local desc_3
    if [ "${min_display_time}" -eq 0 ] 2>/dev/null; then
        desc_3="Min display time — Disabled"
    else
        desc_3="Min display time — ${min_display_time}s"
    fi
    local desc_4="Immovable — $([ "${popup_immovable}" = "true" ] && echo "On" || echo "Off")"
    if type is_darwin >/dev/null 2>&1 && is_darwin; then
        desc_4="${desc_4} (Linux only)"
    fi
    local desc_5="Auto-close — $([ "${popup_auto_close}" = "true" ] && echo "On" || echo "Off")"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        local choice
        choice=$(show_multi_column_list_dialog \
            "Window Behavior" \
            "Select an option to configure:" \
            500 \
            320 \
            1 \
            "Option" "Description" \
            "1" "${desc_1}" \
            "2" "${desc_2}" \
            "3" "${desc_3}" \
            "4" "${desc_4}" \
            "5" "${desc_5}" \
            "6" "Back to main menu")
        local exit_code=$?
        if [ ${exit_code} -ne 0 ] || [ -z "${choice}" ]; then
            return 1
        fi
        if [ "${choice}" = "6" ]; then
            return 1
        fi
        echo "${choice}"
        return 0
    else
        echo "" >&2
        echo "=== Window Behavior ===" >&2
        echo "1. ${desc_1}" >&2
        echo "2. ${desc_2}" >&2
        echo "3. ${desc_3}" >&2
        echo "4. ${desc_4}" >&2
        echo "5. ${desc_5}" >&2
        echo "6. Back to main menu" >&2
        echo "" >&2
        while true; do
            configure_read -p "Select option [1-6]: " choice
            case "${choice}" in
                1|2|3|4|5)
                    echo "${choice}"
                    return 0
                    ;;
                6)
                    return 1
                    ;;
                *)
                    echo "Invalid option. Please enter 1-6." >&2
                    ;;
            esac
        done
    fi
}

