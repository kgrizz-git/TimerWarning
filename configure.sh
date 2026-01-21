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
# - Updates ~/.config/sleep-warning/sleep-warning.conf with user selections
###############################################################################

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source library modules in dependency order
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/config.sh" || exit 1
source "${LIB_DIR}/logging.sh" || exit 1
source "${LIB_DIR}/time-validation.sh" || exit 1
source "${LIB_DIR}/display-detection.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/configure-dialogs.sh" || exit 1
source "${LIB_DIR}/configure-config.sh" || exit 1
source "${LIB_DIR}/configure-validation.sh" || exit 1
source "${LIB_DIR}/configure-time.sh" || exit 1
source "${LIB_DIR}/configure-ui.sh" || exit 1
source "${LIB_DIR}/configure-input.sh" || exit 1
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
    
    # Check if configuration is locked due to restricted hours
    if ! check_config_lock_time; then
        # Configuration is locked - show error and exit
        show_config_locked_error "${use_gui}" "Configuration"
        exit 1
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
    declare -g check_interval popup_size popup_position min_display_time popup_immovable configure_block_enabled uninstall_protection_mode
    
    # Load existing configuration
    # Function sets global variables and populates global arrays directly
    load_existing_config
    
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
        
        # Show main menu
        local menu_choice
        menu_choice=$(show_main_menu "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${weekdays_status}" "${weekends_status}" "${configure_block_enabled}" "${lock_hours_status}" "${uninstall_protection_mode}")
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
                local new_size
                new_size=$(get_popup_size_config "${use_gui}")
                if [ "${new_size}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    popup_size="${new_size}"
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
                # Visual Day/Time Grid
                # Use global variable to store result (avoid subshell issue with namerefs)
                declare -g grid_result_var=""
                while true; do
                    grid_result_var=""
                    show_visual_grid "${use_gui}" config_lines summary_lines lock_hours_lines
                    local grid_exit=$?
                    
                    if [ "${grid_exit}" -ne 0 ] || [ "${grid_result_var}" = "BACK" ]; then
                        # User wants to go back to main menu
                        break
                    fi
                    
                    # grid_result_var contains the day index (0-6) or "BACK"
                    local day_index="${grid_result_var}"
                    
                    # Configure the selected day (restricted hours and/or lock hours)
                    configure_day_from_grid "${day_index}" "${use_gui}" config_lines summary_lines lock_hours_lines
                    local config_exit=$?
                    
                    if [ "${config_exit}" -eq 2 ]; then
                        # User cancelled configuration
                        break
                    fi
                    
                    # Grid will refresh automatically on next loop iteration
                done
                ;;
            6)
                # Block Configuration During Restricted Hours (configure blocking during restricted/lock hours)
                local new_block_enabled
                new_block_enabled=$(get_configure_block_enabled_config "${use_gui}")
                if [ "${new_block_enabled}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    configure_block_enabled="${new_block_enabled}"
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
                # Review and Save
                # Note: summary_lines is accessed globally by show_summary to preserve sparse array indices
                if show_summary "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${configure_block_enabled}"; then
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
                            # Safety override 1: Restrict popup size to small/medium only
                            # This prevents overly intrusive popups when user has very limited unrestricted time
                            local original_popup_size="${popup_size}"
                            if [ "${popup_size}" = "large" ] || [ "${popup_size}" = "fullscreen" ]; then
                                popup_size="medium"
                                popup_size_overridden="true"
                            fi
                            
                            # Safety override 2: Disable configure.sh blocking (Enhancement #19)
                            # This prevents accidental lockout when user has very limited unrestricted time
                            # Conditional check: Only disable if the feature is enabled (not empty and not already false)
                            # Note: CONFIG_LOCK_ENABLED (Enhancement #18) is not yet implemented, so we skip it
                            local original_configure_block="${configure_block_enabled}"
                            if [ -n "${configure_block_enabled}" ] && [ "${configure_block_enabled}" != "false" ]; then
                                configure_block_enabled="false"
                                configure_block_overridden="true"
                            fi
                            
                            # Future: When Enhancement #18 (Config File Locking) is implemented, also disable:
                            # - CONFIG_LOCK_ENABLED (set to false)
                            # - CONFIG_LOCK_ADDITIONAL_HOURS (clear/empty)
                            # Use feature detection: check if variables/functions exist before trying to disable
                            ;;
                        # "ok" - proceed normally with saving (no overrides)
                    esac
                    
                    # Write configuration (with possibly modified values after safety overrides)
                    # Pass both restriction config_lines and lock_hours_lines (Phase 2),
                    # followed by optional safety override flags so write_config can add comments.
                    if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${configure_block_enabled}" "${uninstall_protection_mode}" "${config_lines[@]}" "${lock_hours_lines[@]}" "${popup_size_overridden}" "${configure_block_overridden}"; then
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
