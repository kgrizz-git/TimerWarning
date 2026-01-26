#!/bin/bash

###############################################################################
# Sleep Warning System - Interactive Configuration Wizard
#
# This script provides a user-friendly GUI interface for configuring restricted
# hours for the sleep warning system. It walks users through setting up
# restricted hours for each day of the week.
#
# Requirements:
# - bash
# - yad, zenity, or kdialog (for GUI mode) or fallback to text prompts
#
# Usage:
#   ./configure.sh [OPTIONS]
#   sleep-warning-configure [OPTIONS] (after installation)
#
# Options:
#   --text, --no-gui    Force text mode (disable GUI)
#   --gui               Force GUI mode (requires yad, zenity, or kdialog)
#   --help, -h          Show help message
#
# By default, GUI mode is used if a dialog tool (yad/zenity/kdialog) is available and a display is present.
#
# Output:
# - Updates ~/.config/sleep-warning/config/sleep-warning.conf with user selections (Enhancement #18)
###############################################################################

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source library modules in dependency order
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/config.sh" || exit 1
source "${LIB_DIR}/logging.sh" || exit 1
source "${LIB_DIR}/time-validation.sh" || exit 1
source "${LIB_DIR}/config-locking.sh" || exit 1  # Enhancement #18: Config file locking
source "${LIB_DIR}/display-detection.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/configure-dialogs.sh" || exit 1
source "${LIB_DIR}/configure-config.sh" || exit 1
source "${LIB_DIR}/configure-validation.sh" || exit 1
source "${LIB_DIR}/configure-time.sh" || exit 1
source "${LIB_DIR}/time-calculations.sh" || exit 1
source "${LIB_DIR}/configure-ui.sh" || exit 1
source "${LIB_DIR}/configure-input-basic.sh" || exit 1
source "${LIB_DIR}/configure-input-popup.sh" || exit 1
source "${LIB_DIR}/configure-input-features.sh" || exit 1
source "${LIB_DIR}/configure-input-time.sh" || exit 1
source "${LIB_DIR}/configure-input-service.sh" || exit 1
source "${LIB_DIR}/configure-display.sh" || exit 1
source "${LIB_DIR}/configure-workflow.sh" || exit 1

# Main function
main() {
    local use_gui="false"
    local force_text=false
    local force_gui=false
    
    # Parse command-line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --text|--no-gui)
                force_text=true
                shift
                ;;
            --gui)
                force_gui=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --text, --no-gui    Force text mode (disable GUI)"
                echo "  --gui               Force GUI mode (requires yad, zenity, or kdialog)"
                echo "  --help, -h          Show this help message"
                echo ""
                echo "By default, GUI mode is used if a dialog tool (yad/zenity/kdialog) is available and a display is present."
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
    done
    
    # Determine GUI mode
    if [ "${force_text}" = "true" ]; then
        use_gui="false"
    elif [ "${force_gui}" = "true" ]; then
        if has_dialog_tool; then
            use_gui="true"
        else
            echo "Error: --gui flag specified but no dialog tool (yad/zenity/kdialog) is available." >&2
            echo "Please install yad, zenity, or kdialog, or use --text mode." >&2
            exit 1
        fi
    else
        # Auto-detect: use GUI if available
        if has_gui && has_dialog_tool; then
            use_gui="true"
        fi
    fi
    
    # Check if configuration script execution is locked due to restricted hours (Enhancement #19)
    if ! check_config_lock_time; then
        # Configuration script execution is locked - show error and exit
        show_config_locked_error "${use_gui}" "Configuration"
        exit 1
    fi
    
    # Check if config file is locked (Enhancement #18)
    # This is separate from script execution blocking - checks if file itself is locked
    if type is_config_lock_active >/dev/null 2>&1; then
        if is_config_lock_active 2>/dev/null; then
            # Config file is locked - show error and exit
            if type show_config_file_locked_error >/dev/null 2>&1; then
                show_config_file_locked_error "${use_gui}"
            else
                # Fallback error message if function not available
                if [ "${use_gui}" = "true" ]; then
                    if command -v zenity >/dev/null 2>&1; then
                        zenity --error --title="Configuration File Locked" --text="Configuration file is locked during restricted hours. Please try again after restrictions end." 2>/dev/null
                    elif command -v yad >/dev/null 2>&1; then
                        yad --error --title="Configuration File Locked" --text="Configuration file is locked during restricted hours. Please try again after restrictions end." 2>/dev/null
                    fi
                else
                    echo "ERROR: Configuration file is locked during restricted hours. Please try again after restrictions end." >&2
                fi
            fi
            exit 1
        fi
    fi
    
    # Show welcome
    show_welcome "${use_gui}"
    
    # Declare global arrays and variables BEFORE calling load_existing_config()
    # This ensures they exist in the parent shell
    declare -g -a config_lines=()
    declare -g -a summary_lines=()
    # Lock hours lines (Enhancement #19 Phase 2 - Additional Configurable Lock Hours)
    # This is a sparse array indexed 0-6 (Sunday-Saturday) with entries like:
    #   CONFIG_LOCK_HOURS_MONDAY=9-17
    declare -g -a lock_hours_lines=()
    # Uninstall lock hours lines (Enhancement #26 Phase 2 - Additional Uninstall Lock Hours)
    # This is a sparse array indexed 0-6 (Sunday-Saturday) with entries like:
    #   UNINSTALL_LOCK_HOURS_MONDAY=9-17
    declare -g -a uninstall_lock_hours_lines=()
    declare -g check_interval popup_size popup_size_mode popup_size_custom popup_size_custom_absolute popup_position min_display_time popup_immovable popup_auto_close configure_block_enabled uninstall_protection_mode pause_enabled pause_duration dialog_tool config_lock_enabled
    
    # Load existing configuration
    # Function sets global variables and populates global arrays directly
    load_existing_config
    
    # Ensure dialog_tool is initialized (set by load_existing_config(), but provide fallback)
    dialog_tool="${dialog_tool:-auto}"
    
    # Main configuration loop
    while true; do
        # Get section status indicators for restricted hours
        local status_data
        status_data=$(get_section_status)
        local weekdays_status weekends_status
        IFS='|' read -r weekdays_status weekends_status <<< "${status_data}"
        
        # Determine lock hours status for display in main menu (Phase 2)
        # If any day has lock hours configured, show as "Configured"
        # Note: Must check if the VALUE after = is non-empty, not just if the array element exists
        # (Empty values like "CONFIG_LOCK_HOURS_MONDAY=" should not count as configured)
        local lock_hours_status="(None)"
        local i
        for i in 0 1 2 3 4 5 6; do
            if [ -n "${lock_hours_lines[${i}]:-}" ]; then
                # Extract the value after the = sign
                local lock_value
                lock_value=$(echo "${lock_hours_lines[${i}]}" | cut -d'=' -f2- | tr -d '[:space:]')
                if [ -n "${lock_value}" ]; then
                    lock_hours_status="(Configured)"
                    break
                fi
            fi
        done
        
        # Determine uninstall lock hours status for display in main menu (Enhancement #26 Phase 2)
        # If any day has uninstall lock hours configured, show as "Configured"
        local uninstall_lock_hours_status="(None)"
        for i in 0 1 2 3 4 5 6; do
            if [ -n "${uninstall_lock_hours_lines[${i}]:-}" ]; then
                # Extract the value after the = sign
                local uninstall_lock_value
                uninstall_lock_value=$(echo "${uninstall_lock_hours_lines[${i}]}" | cut -d'=' -f2- | tr -d '[:space:]')
                if [ -n "${uninstall_lock_value}" ]; then
                    uninstall_lock_hours_status="(Configured)"
                    break
                fi
            fi
        done
        
        # Calculate dialog tool status for menu display
        local dialog_tool_status=""
        local current_dialog_tool
        if type get_dialog_tool_config >/dev/null 2>&1; then
            current_dialog_tool=$(get_dialog_tool_config 2>/dev/null || echo "auto")
        else
            # Fallback to variable (should be set from load_existing_config())
            current_dialog_tool="${dialog_tool:-auto}"
        fi
        
        if [ "${current_dialog_tool}" = "auto" ]; then
            dialog_tool_status="(Automatic)"
        else
            # Check if selected tool is installed
            if command -v "${current_dialog_tool}" >/dev/null 2>&1; then
                dialog_tool_status="(${current_dialog_tool})"
            else
                dialog_tool_status="(${current_dialog_tool} - not installed)"
            fi
        fi
        
        # Show main menu
        local menu_choice
        menu_choice=$(show_main_menu "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${popup_auto_close}" "${weekdays_status}" "${weekends_status}" "${configure_block_enabled}" "${lock_hours_status}" "${uninstall_protection_mode}" "${uninstall_lock_hours_status}" "${pause_enabled}" "${pause_duration}" "${dialog_tool_status}" "${config_lock_enabled}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}")
        local menu_exit=$?
        
        if [ "${menu_exit}" -eq 2 ] || [ "${menu_choice}" = "CANCELLED" ]; then
            # User cancelled
            exit 0
        fi
        
        if [ "${menu_exit}" -ne 0 ]; then
            continue  # Show menu again
        fi
        
        # Handle menu choice
        case "${menu_choice}" in
            1)
                # Timer Settings
                local new_interval
                new_interval=$(get_check_interval "${use_gui}")
                if [ "${new_interval}" = "CANCELLED" ]; then
                    # User already confirmed cancellation in get_check_interval
                    exit 0
                else
                    check_interval="${new_interval}"
                fi
                ;;
            2)
                # Window Behavior
                # This is for Enhancement #3 (Enhanced Window Size Options)
                
                # Get size mode (fixed or display-based)
                local new_size_mode
                new_size_mode=$(get_popup_size_mode_config "${use_gui}")
                if [ "${new_size_mode}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    popup_size_mode="${new_size_mode}"
                fi
                
                # Get popup size
                local new_size
                new_size=$(get_popup_size_config "${use_gui}")
                if [ "${new_size}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    # Check if the result contains custom dimensions (format: "custom|95%x95%")
                    if echo "${new_size}" | grep -qE '^custom\|'; then
                        # Extract the size type and custom dimensions
                        popup_size="custom"
                        popup_size_custom=$(echo "${new_size}" | cut -d'|' -f2)
                        
                        # If it's a percentage format, we need an absolute fallback
                        if echo "${popup_size_custom}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                            # Calculate absolute fallback from percentage (based on 2560×1440)
                            local width_percent height_percent
                            width_percent=$(echo "${popup_size_custom}" | cut -d'x' -f1 | tr -d '%')
                            height_percent=$(echo "${popup_size_custom}" | cut -d'x' -f2 | tr -d '%')
                            popup_size_custom_absolute="$((2560 * width_percent / 100))x$((1440 * height_percent / 100))"
                        else
                            # It's already a pixel format, use it as both custom and absolute
                            popup_size_custom_absolute="${popup_size_custom}"
                        fi
                    else
                        # Regular size (not custom)
                        popup_size="${new_size}"
                    fi
                fi
                
                local new_position
                new_position=$(get_popup_position_config "${use_gui}")
                if [ "${new_position}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    popup_position="${new_position}"
                fi
                
                local new_time
                new_time=$(get_min_display_time_config "${use_gui}")
                if [ "${new_time}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    min_display_time="${new_time}"
                fi
                
                local new_immovable
                new_immovable=$(get_popup_immovable_config "${use_gui}")
                if [ "${new_immovable}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    popup_immovable="${new_immovable}"
                fi
                
                local new_auto_close
                new_auto_close=$(get_popup_auto_close_config "${use_gui}")
                if [ "${new_auto_close}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    popup_auto_close="${new_auto_close}"
                fi
                ;;
            3)
                # Weekdays Configuration
                configure_weekdays_section "${use_gui}" config_lines summary_lines
                local weekdays_exit=$?
                if [ "${weekdays_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                ;;
            4)
                # Weekends Configuration
                configure_weekends_section "${use_gui}" config_lines summary_lines
                local weekends_exit=$?
                if [ "${weekends_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                ;;
            5)
                # View Weekly Hours Settings
                # Use global variable to store result (avoid subshell issue with namerefs)
                declare -g grid_result_var=""
                while true; do
                    grid_result_var=""
                    show_visual_grid "${use_gui}" config_lines summary_lines lock_hours_lines uninstall_lock_hours_lines
                    local grid_exit=$?
                    
                    if [ "${grid_exit}" -ne 0 ] || [ "${grid_result_var}" = "BACK" ]; then
                        # User wants to go back to main menu
                        break
                    fi
                    
                    # grid_result_var contains the day index (0-6) or "BACK"
                    local day_index="${grid_result_var}"
                    
                    # Configure the selected day (restricted hours, lock hours, and/or uninstall lock hours)
                    configure_day_from_grid "${day_index}" "${use_gui}" config_lines summary_lines lock_hours_lines uninstall_lock_hours_lines
                    local config_exit=$?
                    
                    if [ "${config_exit}" -eq 2 ]; then
                        # User cancelled configuration
                        break
                    fi
                    
                    # Grid will refresh automatically on next loop iteration
                done
                ;;
            6)
                # Security Settings (Script Blocking & Config File Locking)
                local security_result
                security_result=$(get_security_settings_config "${use_gui}" "${configure_block_enabled}" "${config_lock_enabled}")
                if [ "${security_result}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    # Parse pipe-separated result: "configure_block|config_lock"
                    configure_block_enabled=$(echo "${security_result}" | cut -d'|' -f1)
                    config_lock_enabled=$(echo "${security_result}" | cut -d'|' -f2)
                fi
                ;;
            7)
                # Additional Configuration Block Hours (Enhancement #19 Phase 2)
                # Configure additional hours when configure.sh/manage.sh are blocked,
                # separate from restricted hours.
                configure_lock_hours_section "${use_gui}" lock_hours_lines
                local lock_exit=$?
                if [ "${lock_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                ;;
            8)
                # Uninstall Protection Configuration (Enhancement #26)
                local new_protection_mode
                new_protection_mode=$(get_uninstall_protection_mode_config "${use_gui}")
                if [ "${new_protection_mode}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    uninstall_protection_mode="${new_protection_mode}"
                fi
                ;;
            9)
                # Uninstall Lock Hours Configuration (Enhancement #26 Phase 2)
                # Configure additional hours when difficult uninstall verification is required,
                # separate from restriction hours and configure.sh lock hours.
                configure_uninstall_lock_hours_section "${use_gui}" uninstall_lock_hours_lines
                local uninstall_lock_exit=$?
                if [ "${uninstall_lock_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                ;;
            10)
                # Pause Settings Configuration (Enhancement #21)
                local new_pause_enabled
                new_pause_enabled=$(get_pause_enabled_config "${use_gui}")
                if [ "${new_pause_enabled}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    pause_enabled="${new_pause_enabled}"
                fi
                
                local new_pause_duration
                new_pause_duration=$(get_pause_duration_config "${use_gui}")
                if [ "${new_pause_duration}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    pause_duration="${new_pause_duration}"
                fi
                ;;
            11)
                # Dialog Tool Selection (Enhancement #25)
                local new_dialog_tool
                new_dialog_tool=$(get_dialog_tool_selection "${use_gui}")
                local selection_exit=$?
                
                if [ ${selection_exit} -eq 2 ]; then
                    # User confirmed cancellation - exit configuration
                    exit 0
                elif [ ${selection_exit} -eq 0 ]; then
                    # Valid selection made (including "auto" if user cancelled without confirming)
                    dialog_tool="${new_dialog_tool}"
                fi
                # If exit code is 1, function will have already re-prompted, so we continue the loop
                ;;
            12)
                # Service Mode Configuration (Enhancement #4)
                configure_service_mode "${use_gui}"
                local service_mode_exit=$?
                if [ "${service_mode_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                # Continue loop (service mode configuration doesn't affect other settings)
                ;;
            13)
                # Review and Save
                # Note: summary_lines is accessed globally by show_summary to preserve sparse array indices
                if show_summary "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${popup_auto_close}" "${configure_block_enabled}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}"; then
                    # Validate restriction coverage before saving
                    local validation_result
                    validation_result=$(check_restriction_coverage "${config_lines[@]}")
                    
                    # Track whether safety overrides were applied (for config file comments)
                    local popup_size_overridden=""
                    local configure_block_overridden=""
                    
                    case "${validation_result}" in
                        "block")
                            # 24/7 restrictions detected - show error and block saving
                            show_24_7_error "${use_gui}"
                            continue  # Return to menu, don't call write_config
                            ;;
                        "warn")
                            # High restrictions detected - show warning and get confirmation
                            if ! show_high_restriction_warning "${use_gui}"; then
                                # User cancelled - return to menu
                                continue
                            fi
                            # User confirmed - apply safety overrides before saving
                            # Safety override 1: Restrict popup size to xsmall/small/medium only (Enhancement #3)
                            # This prevents overly intrusive popups when user has very limited unrestricted time
                            local original_popup_size="${popup_size}"
                            if [ "${popup_size}" = "large" ] || [ "${popup_size}" = "xlarge" ] || [ "${popup_size}" = "max" ] || [ "${popup_size}" = "fullscreen" ]; then
                                popup_size="medium"
                                popup_size_overridden="true"
                            elif [ "${popup_size}" = "custom" ]; then
                                # Check if custom size exceeds medium - if so, clamp to medium
                                # For now, we'll change to medium if custom is selected (can be enhanced later to check actual dimensions)
                                popup_size="medium"
                                popup_size_overridden="true"
                            fi
                            
                            # Safety override 2: Disable configure.sh blocking (Enhancement #19)
                            # This prevents accidental lockout when user has very limited unrestricted time
                            # Conditional check: Only disable if the feature is enabled (not empty and not already false)
                            local original_configure_block="${configure_block_enabled}"
                            if [ -n "${configure_block_enabled}" ] && [ "${configure_block_enabled}" != "false" ]; then
                                configure_block_enabled="false"
                                configure_block_overridden="true"
                            fi
                            
                            # Safety override 3: Disable config file locking (Enhancement #18)
                            # This prevents accidental lockout when user has very limited unrestricted time
                            # Conditional check: Only disable if the feature is enabled (not empty and not already false)
                            if [ -n "${config_lock_enabled}" ] && [ "${config_lock_enabled}" != "false" ]; then
                                config_lock_enabled="false"
                                # Note: Enhancement #22 integration - automatically disable if restrictions > 6720 minutes
                                # This is a safety measure to prevent lockout scenarios
                            fi
                            ;;
                        # "ok" - proceed normally with saving (no overrides)
                    esac
                    
                    # Write configuration (with possibly modified values after safety overrides)
                    # Pass restriction config_lines, lock_hours_lines (Phase 2), and uninstall_lock_hours_lines (Enhancement #26 Phase 2),
                    # followed by optional safety override flags so write_config can add comments.
                    # Enhancement #3: Include popup_size_mode, popup_size_custom, and popup_size_custom_absolute
                    if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${popup_auto_close}" "${configure_block_enabled}" "${uninstall_protection_mode}" "${pause_enabled}" "${pause_duration}" "${dialog_tool}" "${config_lock_enabled}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}" "${config_lines[@]}" "${lock_hours_lines[@]}" "${uninstall_lock_hours_lines[@]}" "${popup_size_overridden}" "${configure_block_overridden}"; then
                        # Update timer file if it exists
                        if [ -f "${TIMER_FILE}" ]; then
                            if update_timer_file "${check_interval}"; then
                                show_success "${use_gui}" "${check_interval}"
                            else
                                local warning_msg="Configuration saved, but failed to update timer file.\n\nYou may need to manually update:\n${TIMER_FILE}\n\nThen run:\nsystemctl --user daemon-reload\nsystemctl --user restart ${SERVICE_NAME}.timer"
                                if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                                    show_info_dialog "Warning" "${warning_msg}" 600 300
                                else
                                    echo "${warning_msg}" >&2
                                fi
                            fi
                        else
                            show_success "${use_gui}" "${check_interval}"
                        fi
                        exit 0
                    else
                        local error_msg="Error: Failed to write configuration file.\n\nPlease check permissions for:\n${CONFIG_DIR}"
                        if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                            show_info_dialog "Error" "${error_msg}" 600 250
                        else
                            echo "${error_msg}" >&2
                        fi
                        # Return to menu instead of exiting on error
                    fi
                fi
                # User didn't confirm, return to menu
                ;;
        esac
    done
}

# Run main function
main "$@"
