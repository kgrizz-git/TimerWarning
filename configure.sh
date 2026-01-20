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
    
    # Show welcome
    show_welcome "${use_gui}"
    
    # Declare global arrays and variables BEFORE calling load_existing_config()
    # This ensures they exist in the parent shell
    declare -g -a config_lines=()
    declare -g -a summary_lines=()
    declare -g check_interval popup_size popup_position min_display_time popup_immovable
    
    # Load existing configuration
    # Function sets global variables and populates global arrays directly
    load_existing_config
    
    # Main configuration loop
    while true; do
        # Get section status indicators
        local status_data
        status_data=$(get_section_status)
        local weekdays_status weekends_status
        IFS='|' read -r weekdays_status weekends_status <<< "${status_data}"
        
        # Show main menu
        local menu_choice
        menu_choice=$(show_main_menu "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${weekdays_status}" "${weekends_status}")
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
                    show_visual_grid "${use_gui}" config_lines summary_lines
                    local grid_exit=$?
                    
                    if [ "${grid_exit}" -ne 0 ] || [ "${grid_result_var}" = "BACK" ]; then
                        # User wants to go back to main menu
                        break
                    fi
                    
                    # grid_result_var contains the day index (0-6) or "BACK"
                    local day_index="${grid_result_var}"
                    
                    # Configure the selected day
                    configure_day_from_grid "${day_index}" "${use_gui}" config_lines summary_lines
                    local config_exit=$?
                    
                    if [ "${config_exit}" -eq 2 ]; then
                        # User cancelled configuration
                        break
                    fi
                    
                    # Grid will refresh automatically on next loop iteration
                done
                ;;
            6)
                # Review and Save
                # Note: summary_lines is accessed globally by show_summary to preserve sparse array indices
                if show_summary "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}"; then
                    # Validate restriction coverage before saving
                    local validation_result
                    validation_result=$(check_restriction_coverage "${config_lines[@]}")
                    
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
                            if [ "${popup_size}" = "large" ] || [ "${popup_size}" = "fullscreen" ]; then
                                popup_size="medium"
                            fi
                            # Future: disable CONFIG_LOCK_ENABLED, CONFIGURE_BLOCK_ENABLED if implemented
                            ;;
                        # "ok" - proceed normally with saving
                    esac
                    
                    # Write configuration (with possibly modified popup_size after safety overrides)
                    if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${config_lines[@]}"; then
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
