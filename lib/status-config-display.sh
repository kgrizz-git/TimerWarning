#!/bin/bash

###############################################################################
# Sleep Warning System - Status configuration display
# Sourced by status.sh (requires print_header, print_status, COLOR_*, CONFIG_FILE)
###############################################################################

# Format a 24-hour time string "HH[:MM]" to 12-hour format with AM/PM
format_hour_12h() {
    local time_str="$1"
    local hour minute

    if [[ "${time_str}" == *:* ]]; then
        hour="${time_str%%:*}"
        minute="${time_str##*:}"
    else
        hour="${time_str}"
        minute="0"
    fi

    # Basic numeric validation
    if ! [[ "${hour}" =~ ^[0-9]+$ ]] || ! [[ "${minute}" =~ ^[0-9]+$ ]]; then
        echo "${time_str}"
        return 0
    fi

    local display_hour="${hour}"
    local ampm="AM"

    if [ "${hour}" -ge 12 ]; then
        ampm="PM"
        if [ "${hour}" -gt 12 ]; then
            display_hour=$((hour - 12))
        fi
    fi

    if [ "${display_hour}" -eq 0 ]; then
        display_hour=12
    fi

    printf "%d:%02d %s" "${display_hour}" "${minute}" "${ampm}"
}

# Format a single range to human-readable format
format_range_human() {
    local range="$1"
    local day_name="$2"
    
    local start_raw end_raw
    start_raw=$(echo "${range}" | cut -d'-' -f1)
    end_raw=$(echo "${range}" | cut -d'-' -f2)
    
    local start_12h end_12h
    start_12h=$(format_hour_12h "${start_raw}")
    end_12h=$(format_hour_12h "${end_raw}")

    # Determine if this is an overnight range using HHMM-style comparison
    local overnight="false"

    # Parse start time
    local shour smin
    if [[ "${start_raw}" == *:* ]]; then
        shour="${start_raw%%:*}"
        smin="${start_raw##*:}"
    else
        shour="${start_raw}"
        smin="0"
    fi

    # Parse end time
    local ehour emin
    if [[ "${end_raw}" == *:* ]]; then
        ehour="${end_raw%%:*}"
        emin="${end_raw##*:}"
    else
        ehour="${end_raw}"
        emin="0"
    fi

    if [[ "${shour}" =~ ^[0-9]+$ ]] && [[ "${smin}" =~ ^[0-9]+$ ]] && \
       [[ "${ehour}" =~ ^[0-9]+$ ]] && [[ "${emin}" =~ ^[0-9]+$ ]]; then
        local shour_p ehour_p smin_p emin_p
        printf -v shour_p "%02d" "${shour}"
        printf -v ehour_p "%02d" "${ehour}"
        printf -v smin_p  "%02d" "${smin}"
        printf -v emin_p  "%02d" "${emin}"

        local start_total end_total
        start_total=$((10#${shour_p}${smin_p}))
        end_total=$((10#${ehour_p}${emin_p}))

        if [ "${start_total}" -gt "${end_total}" ]; then
            overnight="true"
        fi
    fi
    
    # Handle overnight ranges
    if [ "${overnight}" = "true" ]; then
        echo "${start_12h} → ${end_12h} (overnight)"
    else
        echo "${start_12h} → ${end_12h}"
    fi
}

# Format multiple ranges to human-readable format
format_ranges_human() {
    local ranges="$1"
    local day_name="$2"
    
    local IFS=','
    local formatted_ranges=()
    for range in ${ranges}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        formatted_ranges+=("$(format_range_human "${range}" "${day_name}")")
    done
    
    # Join with " AND "
    local result=""
    local first=true
    for formatted in "${formatted_ranges[@]}"; do
        if [ "${first}" = "true" ]; then
            result="${formatted}"
            first=false
        else
            result="${result} AND ${formatted}"
        fi
    done
    
    echo "${result}"
}
show_configuration() {
    print_header "CONFIGURATION"
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "  ${COLOR_YELLOW}No configuration file found${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run 'sleep-warning-configure' or './configure.sh' to create configuration${COLOR_RESET}"
        return 1
    fi
    
    # Read popup display frequency (Enhancement #30); fallback CHECK_INTERVAL for migration
    local popup_freq
    popup_freq=$(grep -E "^[[:space:]]*POPUP_DISPLAY_FREQUENCY=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${popup_freq}" ]; then
        popup_freq=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    fi
    if [ -z "${popup_freq}" ]; then
        popup_freq="10 (default)"
    else
        popup_freq="${popup_freq} minute(s)"
    fi
    print_status "Popup display frequency" "${popup_freq}"
    
    # Read popup size
    local popup_size
    popup_size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    # Format with dimensions if get_popup_dimensions function is available
    local display_size
    if [ -z "${popup_size}" ]; then
        popup_size="medium"
        if type get_popup_dimensions >/dev/null 2>&1; then
            local dimensions
            dimensions=$(get_popup_dimensions "${popup_size}")
            local width height
            width=$(echo "${dimensions}" | cut -d' ' -f1)
            height=$(echo "${dimensions}" | cut -d' ' -f2)
            display_size="medium (default) - ${width}x${height}"
        else
            display_size="medium (default)"
        fi
    else
        # Check if it's a custom size - if so, read the custom size value
        if [ "${popup_size}" = "custom" ]; then
            local custom_size
            custom_size=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
            if [ -n "${custom_size}" ]; then
                # Show custom size value (e.g., "95%x95%")
                if type get_popup_dimensions >/dev/null 2>&1; then
                    local dimensions
                    dimensions=$(get_popup_dimensions "${popup_size}")
                    local width height
                    width=$(echo "${dimensions}" | cut -d' ' -f1)
                    height=$(echo "${dimensions}" | cut -d' ' -f2)
                    display_size="custom ${custom_size} (${width}x${height})"
                else
                    display_size="custom ${custom_size}"
                fi
            else
                # Fallback if custom size not found
                if type get_popup_dimensions >/dev/null 2>&1; then
                    local dimensions
                    dimensions=$(get_popup_dimensions "${popup_size}")
                    local width height
                    width=$(echo "${dimensions}" | cut -d' ' -f1)
                    height=$(echo "${dimensions}" | cut -d' ' -f2)
                    display_size="custom (${width}x${height})"
                else
                    display_size="custom"
                fi
            fi
        elif type get_popup_dimensions >/dev/null 2>&1; then
            local dimensions
            dimensions=$(get_popup_dimensions "${popup_size}")
            local width height
            width=$(echo "${dimensions}" | cut -d' ' -f1)
            height=$(echo "${dimensions}" | cut -d' ' -f2)
            
            # Check if it's a custom size (already contains 'x')
            if echo "${popup_size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                display_size="${popup_size}"
            else
                display_size="${popup_size} (${width}x${height})"
            fi
        else
            display_size="${popup_size}"
        fi
    fi
    print_status "Popup Size" "${display_size}"
    
    # Read popup position
    local popup_position
    popup_position=$(grep -E "^[[:space:]]*POPUP_POSITION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${popup_position}" ]; then
        popup_position="center (default)"
    fi
    print_status "Popup Position" "${popup_position}"
    
    # Read minimum display time
    local min_display_time
    min_display_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${min_display_time}" ]; then
        min_display_time="30 seconds (default)"
    elif [ "${min_display_time}" -eq 0 ]; then
        min_display_time="Disabled"
    else
        min_display_time="${min_display_time} seconds"
    fi
    print_status "Min Display Time" "${min_display_time}"
    
    # Read popup immovable setting
    local popup_immovable
    popup_immovable=$(grep -E "^[[:space:]]*POPUP_IMMOVABLE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -z "${popup_immovable}" ]; then
        popup_immovable="true (default)"
    elif [ "${popup_immovable}" = "true" ] || [ "${popup_immovable}" = "1" ] || [ "${popup_immovable}" = "yes" ]; then
        popup_immovable="Enabled"
    else
        popup_immovable="Disabled"
    fi
    print_status "Prevent Window Movement" "${popup_immovable}"
    
    # Read configure block enabled setting (Enhancement #19)
    local configure_block_enabled
    configure_block_enabled=$(grep -E "^[[:space:]]*CONFIGURE_BLOCK_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -z "${configure_block_enabled}" ]; then
        configure_block_enabled="Disabled (default)"
    elif [ "${configure_block_enabled}" = "true" ] || [ "${configure_block_enabled}" = "1" ] || [ "${configure_block_enabled}" = "yes" ]; then
        configure_block_enabled="Enabled"
    else
        configure_block_enabled="Disabled"
    fi
    print_status "Block Scripts During Restricted Hours" "${configure_block_enabled}"
    
    # Read uninstall protection mode setting (Enhancement #26)
    local uninstall_protection_mode
    uninstall_protection_mode=$(grep -E "^[[:space:]]*UNINSTALL_PROTECTION_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -z "${uninstall_protection_mode}" ]; then
        uninstall_protection_mode="Difficult Uninstall (default)"
    elif [ "${uninstall_protection_mode}" = "difficult" ]; then
        uninstall_protection_mode="Difficult Uninstall (Enabled)"
    else
        uninstall_protection_mode="None"
    fi
    print_status "Uninstall Protection" "${uninstall_protection_mode}"
    
    # Read pause settings (Enhancement #21)
    local pause_enabled pause_duration pause_cooldown_hours
    if type get_pause_enabled >/dev/null 2>&1; then
        pause_enabled=$(get_pause_enabled)
        pause_duration=$(get_pause_duration)
        pause_cooldown_hours=$(get_pause_cooldown_hours)
    else
        pause_enabled=$(grep -E "^[[:space:]]*PAUSE_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        pause_duration=$(grep -E "^[[:space:]]*PAUSE_DURATION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        pause_cooldown_hours=$(grep -E "^[[:space:]]*PAUSE_COOLDOWN_HOURS=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    fi
    if [ -z "${pause_enabled}" ] || [ "${pause_enabled}" = "true" ] || [ "${pause_enabled}" = "1" ] || [ "${pause_enabled}" = "yes" ]; then
        print_status "Pause Feature" "Enabled"
    else
        print_status "Pause Feature" "Disabled"
    fi
    if [ -z "${pause_duration}" ]; then
        pause_duration="5"
    fi
    print_status "Pause Duration" "${pause_duration} minutes"
    if [ -z "${pause_cooldown_hours}" ]; then
        pause_cooldown_hours="24"
    fi
    print_status "Pause Cooldown" "${pause_cooldown_hours} hours"
    
    print_header "PAUSE STATUS"
    
    if type is_pause_active >/dev/null 2>&1 && type can_pause_now >/dev/null 2>&1; then
        if is_pause_active; then
            local pause_end_timestamp
            pause_end_timestamp=$(get_pause_end_timestamp)
            if [ -n "${pause_end_timestamp}" ]; then
                local pause_end_time
                pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
                print_status "Pause Status" "Active until ${pause_end_time}" "good"
            else
                print_status "Pause Status" "Active (end time unknown)" "warning"
            fi
        elif can_pause_now; then
            print_status "Pause Status" "Available" "good"
        elif [ "${pause_enabled}" = "true" ] || [ "${pause_enabled}" = "1" ] || [ "${pause_enabled}" = "yes" ] || [ -z "${pause_enabled}" ]; then
            local next_available_ts next_available_label
            next_available_ts=""
            if type get_next_pause_available_timestamp >/dev/null 2>&1; then
                next_available_ts=$(get_next_pause_available_timestamp)
            fi
            if [ -n "${next_available_ts}" ]; then
                next_available_label=$(date -d "@${next_available_ts}" +"%Y-%m-%d %H:%M" 2>/dev/null || date -r "${next_available_ts}" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
                print_status "Pause Status" "Cooldown until ${next_available_label}" "warning"
            else
                print_status "Pause Status" "Cooldown (not available yet)" "warning"
            fi
        else
            print_status "Pause Status" "Disabled" "warning"
        fi
        
        local last_pause_date last_pause_timestamp
        last_pause_date=$(get_last_pause_date)
        last_pause_timestamp=$(get_last_pause_timestamp)
        if [ -n "${last_pause_date}" ]; then
            print_status "Last Pause Date" "${last_pause_date}"
        else
            print_status "Last Pause Date" "Never used"
        fi
        if [ -n "${last_pause_timestamp}" ]; then
            local last_pause_time
            last_pause_time=$(date -d "@${last_pause_timestamp}" +"%Y-%m-%d %H:%M" 2>/dev/null || date -r "${last_pause_timestamp}" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
            print_status "Last Pause Started" "${last_pause_time}"
        fi
    else
        print_status "Pause Status" "Unable to check (pause-state.sh not available)" "warning"
    fi
    
    # Get dialog tool configuration (Enhancement #25)
    local configured_dialog_tool
    if type get_dialog_tool_config >/dev/null 2>&1; then
        configured_dialog_tool=$(get_dialog_tool_config)
    else
        # Fallback to manual parsing if function not available
        configured_dialog_tool=$(grep -E "^[[:space:]]*DIALOG_TOOL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -z "${configured_dialog_tool}" ]; then
            configured_dialog_tool="auto"
        fi
    fi
    
    # Detect and display dialog tool
    local dialog_tool
    local dialog_tool_status=""
    local dialog_tool_display=""
    
    if [ -n "${configured_dialog_tool}" ] && [ "${configured_dialog_tool}" != "auto" ]; then
        # User has manually selected a dialog tool
        if command -v "${configured_dialog_tool}" >/dev/null 2>&1; then
            dialog_tool="${configured_dialog_tool}"
            dialog_tool_display="${configured_dialog_tool} (user-selected)"
            dialog_tool_status="good"
        else
            # Selected tool not installed, will fall back to automatic
            dialog_tool_display="${configured_dialog_tool} (not installed, will use automatic)"
            dialog_tool_status="warning"
        fi
    else
        # Use automatic priority system (YAD → Zenity → KDialog)
        if type check_dialog_tool >/dev/null 2>&1; then
            # Use the function from desktop-environment.sh if available
            local env_type
            env_type=$(echo "${XDG_SESSION_TYPE:-x11}" | tr '[:upper:]' '[:lower:]')
            dialog_tool=$(check_dialog_tool "${env_type}")
        else
            # Fallback: check tools manually in priority order
            if command -v yad >/dev/null 2>&1; then
                dialog_tool="yad"
            elif command -v zenity >/dev/null 2>&1; then
                dialog_tool="zenity"
            elif command -v kdialog >/dev/null 2>&1; then
                dialog_tool="kdialog"
            fi
        fi
        
        if [ -n "${dialog_tool}" ]; then
            dialog_tool_display="${dialog_tool} (automatic selection)"
            dialog_tool_status="good"
        else
            dialog_tool_display="None available"
            dialog_tool_status="error"
        fi
    fi
    
    # Show installed tools for reference
    local installed_tools=()
    if command -v yad >/dev/null 2>&1; then
        installed_tools+=("yad")
    fi
    if command -v zenity >/dev/null 2>&1; then
        installed_tools+=("zenity")
    fi
    if command -v kdialog >/dev/null 2>&1; then
        installed_tools+=("kdialog")
    fi
    
    if [ ${#installed_tools[@]} -gt 0 ]; then
        local tools_list
        tools_list=$(IFS=', '; echo "${installed_tools[*]}")
        dialog_tool_display="${dialog_tool_display} [Installed: ${tools_list}]"
    fi
    
    print_status "Dialog Tool" "${dialog_tool_display}" "${dialog_tool_status}"

    if ! type is_darwin >/dev/null 2>&1 || ! is_darwin; then
        local gaming_exp_enabled="false"
        if type get_gaming_mode_experimental_enabled >/dev/null 2>&1; then
            gaming_exp_enabled=$(get_gaming_mode_experimental_enabled)
        fi
        if [ "${gaming_exp_enabled}" = "true" ]; then
            print_status "Experimental Gaming Mode" "Enabled (SteamOS gamescope overlay active when running)" "good"
        else
            print_status "Experimental Gaming Mode" "Disabled (Desktop Mode only)"
        fi
    fi
    
    # Read restricted hours
    print_header "RESTRICTED HOURS"
    
    local has_restrictions=false
    declare -a day_names=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
    declare -a day_vars=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")
    
    for i in {0..6}; do
        local day_name="${day_names[${i}]}"
        local day_var="${day_vars[${i}]}"
        local ranges
        ranges=$(grep -E "^[[:space:]]*${day_var}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        
        if [ -n "${ranges}" ]; then
            has_restrictions=true
            local formatted
            formatted=$(format_ranges_human "${ranges}" "${day_name}")
            printf "  ${COLOR_BOLD}%-12s${COLOR_RESET} %s\n" "${day_name}:" "${formatted}"
        fi
    done
    
    if [ "${has_restrictions}" = "false" ]; then
        echo -e "  ${COLOR_YELLOW}No restricted hours configured${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Run 'sleep-warning-configure' or './configure.sh' to set up restricted hours${COLOR_RESET}"
    fi
    
    # Read lock hours (Enhancement #19 Phase 2)
    print_header "LOCK HOURS (CONFIGURE/MANAGE SCRIPTS)"
    
    local has_lock_hours=false
    
    for i in {0..6}; do
        local day_name="${day_names[${i}]}"
        local day_var="${day_vars[${i}]}"
        local ranges
        ranges=$(grep -E "^[[:space:]]*CONFIG_LOCK_HOURS_${day_var}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        
        if [ -n "${ranges}" ]; then
            has_lock_hours=true
            local formatted
            formatted=$(format_ranges_human "${ranges}" "${day_name}")
            printf "  ${COLOR_BOLD}%-12s${COLOR_RESET} %s\n" "${day_name}:" "${formatted}"
        fi
    done
    
    if [ "${has_lock_hours}" = "false" ]; then
        echo -e "  ${COLOR_YELLOW}No lock hours configured${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Use 'sleep-warning-configure' Security/Lock Hours menus to set optional lock hours${COLOR_RESET}"
    fi
    
    echo ""
    
    # Read uninstall lock hours (Enhancement #26 Phase 2)
    print_header "UNINSTALL LOCK HOURS"
    
    local has_uninstall_lock_hours=false
    
    for i in {0..6}; do
        local day_name="${day_names[${i}]}"
        local day_var="${day_vars[${i}]}"
        local ranges
        ranges=$(grep -E "^[[:space:]]*UNINSTALL_LOCK_HOURS_${day_var}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        
        if [ -n "${ranges}" ]; then
            has_uninstall_lock_hours=true
            local formatted
            formatted=$(format_ranges_human "${ranges}" "${day_name}")
            printf "  ${COLOR_BOLD}%-12s${COLOR_RESET} %s\n" "${day_name}:" "${formatted}"
        fi
    done
    
    if [ "${has_uninstall_lock_hours}" = "false" ]; then
        echo -e "  ${COLOR_YELLOW}No uninstall lock hours configured${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}  → Use 'sleep-warning-configure' Uninstall Lock Hours menu to set optional uninstall lock hours${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}  → Note: Uninstall lock hours only take effect when Uninstall Protection is set to 'difficult'${COLOR_RESET}"
    fi
    
    # Check minute precision compatibility (Enhancement 16b); use run interval (Enhancement #30)
    if type check_minute_precision_compatibility >/dev/null 2>&1 && type get_timer_run_interval >/dev/null 2>&1; then
        local popup_freq_val run_interval
        popup_freq_val=$(grep -E "^[[:space:]]*POPUP_DISPLAY_FREQUENCY=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ -z "${popup_freq_val}" ] && popup_freq_val=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${popup_freq_val}" ]; then
            run_interval=$(get_timer_run_interval "${popup_freq_val}")
            local config_lines=()
            for day_var in SUNDAY MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY SATURDAY; do
                local line
                line=$(grep -E "^[[:space:]]*${day_var}=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
                [ -n "${line}" ] && config_lines+=("${line}")
            done
            
            local compatibility_warning
            compatibility_warning=$(check_minute_precision_compatibility "${run_interval}" "${config_lines[@]}")
            if [ $? -ne 0 ]; then
                echo ""
                echo -e "  ${COLOR_YELLOW}⚠️  TIMER INTERVAL WARNING:${COLOR_RESET}"
                echo -e "  ${COLOR_YELLOW}${compatibility_warning}${COLOR_RESET}"
            fi
        fi
    fi
}
