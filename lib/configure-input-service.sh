#!/bin/bash

###############################################################################
# Sleep Warning System - Service Mode Configuration Module
#
# This module provides service mode configuration function for the configuration
# wizard, supporting both GUI (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - configure_service_mode() - Configure service mode (Desktop Mode vs Gaming Mode) (Enhancement #4)
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-ui.sh (for confirm_cancel)
# - display-detection.sh (for detect_system_mode)
# - service-config.sh (for get_current_service_mode, configure_service_for_mode)
#
# Note: This function is somewhat different from other input functions as it:
# - Sources additional modules dynamically
# - Performs system configuration (not just input collection)
# - May be better placed in configure-service.sh or service-config.sh in the future
###############################################################################

# Configure service mode (Desktop Mode vs Gaming Mode) - Enhancement #4
# Parameters:
#   $1: use_gui ("true" or "false")
# Returns: 0 on success, 1 on error, 2 if cancelled
# Side effects: Configures systemd service drop-in file for detected mode
configure_service_mode() {
    local use_gui="$1"
    
    # Source required modules
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local service_config_file="${script_dir}/service-config.sh"
    local display_detection_file="${script_dir}/display-detection.sh"
    
    if [ ! -f "${service_config_file}" ] || [ ! -f "${display_detection_file}" ]; then
        local error_msg="Service configuration modules not found.\n\nCannot configure service mode."
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Error" "${error_msg}" 500 200
        else
            echo "Error: ${error_msg}" >&2
        fi
        return 1
    fi
    
    # Source modules
    source "${display_detection_file}"
    source "${service_config_file}"
    
    # Detect current mode
    local detected_mode
    detected_mode=$(detect_system_mode)
    local current_mode
    current_mode=$(get_current_service_mode)
    
    # Build status message
    local status_msg="Current System Mode: ${detected_mode}"
    if [ "${detected_mode}" = "unknown" ]; then
        status_msg="${status_msg}\n(Warning: Could not detect system mode)"
    fi
    status_msg="${status_msg}\n\nCurrent Service Configuration: ${current_mode}"
    if [ "${current_mode}" = "none" ]; then
        status_msg="${status_msg}\n(Using default configuration)"
    fi
    
    if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
        # Show current status
        show_info_dialog "Service Mode Configuration" "${status_msg}" 500 250
        
        # Ask if user wants to reconfigure
        local reconfigure_msg="Do you want to reconfigure the service for the detected mode (${detected_mode})?"
        if [ "${detected_mode}" = "unknown" ]; then
            reconfigure_msg="Warning: Could not detect system mode.\n\nDo you want to configure the service anyway?"
        fi
        
        if ! show_question_dialog \
            "Reconfigure Service?" \
            "${reconfigure_msg}" \
            "Yes, Reconfigure" \
            "No, Cancel" \
            500 \
            250; then
            return 2  # User cancelled
        fi
    else
        # Text mode
        echo "" >&2
        echo "=== Service Mode Configuration ===" >&2
        echo "" >&2
        echo "${status_msg}" >&2
        echo "" >&2
        
        if [ "${detected_mode}" = "unknown" ]; then
            echo "Warning: Could not detect system mode." >&2
            echo "" >&2
            configure_read -p "Do you want to configure the service anyway? [y/N]: " answer
            case "${answer}" in
                [Yy]*) ;;
                *) return 2 ;;
            esac
        else
            configure_read -p "Reconfigure service for ${detected_mode} mode? [Y/n]: " answer
            case "${answer}" in
                [Nn]*) return 2 ;;
            esac
        fi
    fi
    
    # Configure service
    if [ "${detected_mode}" = "unknown" ]; then
        # Ask user to choose mode manually
        if [ "${use_gui}" = "true" ] && type show_list_dialog >/dev/null 2>&1; then
            local mode_choice
            mode_choice=$(show_list_dialog \
                "Select System Mode" \
                "Could not auto-detect system mode. Please select manually:" \
                500 \
                300 \
                "Desktop Mode (X11/KDE Plasma)" \
                "Gaming Mode (Wayland/gamescope)" \
                "Cancel")
            
            case "${mode_choice}" in
                "Desktop Mode (X11/KDE Plasma)")
                    detected_mode="desktop"
                    ;;
                "Gaming Mode (Wayland/gamescope)")
                    detected_mode="gaming"
                    ;;
                *)
                    return 2
                    ;;
            esac
        else
            # Text mode
            echo "" >&2
            echo "Could not auto-detect system mode. Please select:" >&2
            echo "  1) Desktop Mode (X11/KDE Plasma)" >&2
            echo "  2) Gaming Mode (Wayland/gamescope)" >&2
            echo "" >&2
            while true; do
                configure_read -p "Select option [1-2]: " choice
                case "${choice}" in
                    1)
                        detected_mode="desktop"
                        break
                        ;;
                    2)
                        detected_mode="gaming"
                        break
                        ;;
                    *)
                        echo "Invalid option. Please enter 1 or 2." >&2
                        ;;
                esac
            done
        fi
    fi
    
    # Configure service for selected mode
    if configure_service_for_mode "${detected_mode}"; then
        local success_msg="Service successfully configured for ${detected_mode} mode."
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Success" "${success_msg}" 500 200
        else
            echo "" >&2
            echo "✓ ${success_msg}" >&2
            echo "" >&2
        fi
        return 0
    else
        local error_msg="Failed to configure service for ${detected_mode} mode."
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Error" "${error_msg}" 500 200
        else
            echo "Error: ${error_msg}" >&2
        fi
        return 1
    fi
}

