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
    
    # Detect current mode and experimental toggle state
    local detected_mode
    detected_mode=$(detect_system_mode)
    local current_mode
    current_mode=$(get_current_service_mode)
    # A leftover gaming drop-in is not the overlay toggle. If the getter is
    # missing, stay off rather than treating the drop-in as enabled.
    local current_exp="${gaming_mode_experimental_enabled:-}"
    if [ -z "${current_exp}" ]; then
        if type get_gaming_mode_experimental_enabled >/dev/null 2>&1; then
            current_exp=$(get_gaming_mode_experimental_enabled)
        else
            current_exp="false"
        fi
    fi

    local exp_label="Disabled (Desktop Mode Only)"
    if [ "${current_exp}" = "true" ]; then
        exp_label="Enabled (Desktop + Experimental SteamOS Gaming Mode Overlay)"
    fi

    local selected_mode=""
    local opt_desktop="Desktop Mode Only (Default — Gaming Mode Overlay Disabled)"
    local opt_gaming="Enable Experimental Gaming Mode (Desktop + SteamOS Gaming Mode Overlay)"
    local opt_back="Back to Main Menu"

    if [ "${use_gui}" = "true" ] && type show_list_dialog >/dev/null 2>&1; then
        local prompt_msg="Detected System Environment: ${detected_mode}\nCurrent Service Drop-In: ${current_mode}\nExperimental Gaming Mode: ${exp_label}\n\nSelect Service / Experimental Gaming Mode setting:"
        local mode_choice
        mode_choice=$(show_list_dialog \
            "Service Mode & Experimental Gaming Mode" \
            "${prompt_msg}" \
            620 \
            340 \
            "${opt_desktop}" \
            "${opt_gaming}" \
            "${opt_back}")
        local dialog_rc=$?

        if [ ${dialog_rc} -ne 0 ] || [ -z "${mode_choice}" ]; then
            if type confirm_cancel >/dev/null 2>&1 && confirm_cancel "${use_gui}"; then
                return 2
            fi
            return 0
        fi

        # show_list_dialog returns dialog_safe_text output. In a non-UTF-8
        # locale the em dash in the desktop label becomes "-", so compare
        # against the same sanitized strings the dialog returns.
        local opt_desktop_match="${opt_desktop}"
        local opt_gaming_match="${opt_gaming}"
        local opt_back_match="${opt_back}"
        if type dialog_safe_text >/dev/null 2>&1; then
            opt_desktop_match="$(dialog_safe_text "${opt_desktop}")"
            opt_gaming_match="$(dialog_safe_text "${opt_gaming}")"
            opt_back_match="$(dialog_safe_text "${opt_back}")"
        fi

        case "${mode_choice}" in
            "${opt_desktop_match}")
                selected_mode="desktop"
                ;;
            "${opt_gaming_match}")
                selected_mode="gaming"
                ;;
            "${opt_back_match}")
                return 0
                ;;
            *)
                return 0
                ;;
        esac
    else
        # Text mode
        echo "" >&2
        echo "=== Service Mode & Experimental Gaming Mode ===" >&2
        echo "" >&2
        echo "Detected System Environment: ${detected_mode}" >&2
        echo "Current Service Drop-In:     ${current_mode}" >&2
        echo "Experimental Gaming Mode:    ${exp_label}" >&2
        echo "" >&2
        echo "  1) ${opt_desktop}" >&2
        echo "  2) ${opt_gaming}" >&2
        echo "  3) ${opt_back}" >&2
        echo "" >&2
        while true; do
            local choice=""
            if ! configure_read -p "Select option [1-3]: " choice; then
                return 2
            fi
            case "${choice}" in
                1)
                    selected_mode="desktop"
                    break
                    ;;
                2)
                    selected_mode="gaming"
                    break
                    ;;
                3|[Bb]*|[Cc]*)
                    return 0
                    ;;
                *)
                    echo "Invalid option. Please enter 1, 2, or 3." >&2
                    ;;
            esac
        done
    fi

    # Experimental Gaming Mode is display routing, not restriction strength.
    # Option 12 may enable or disable it during lock hours so a broken
    # gamescope overlay can be turned off without waiting for the lock window.

    local new_exp="false"
    if [ "${selected_mode}" = "gaming" ]; then
        new_exp="true"
    fi

    # Persist config toggle first so a write failure is caught before modifying the drop-in
    if type update_gaming_mode_config_in_place >/dev/null 2>&1; then
        if ! update_gaming_mode_config_in_place "${new_exp}"; then
            local save_err="Failed to save Experimental Gaming Mode setting to configuration file."
            if [ "${use_gui}" = "true" ] && type show_error_dialog >/dev/null 2>&1; then
                show_error_dialog "Error" "${save_err}"
            elif [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
                show_info_dialog "Error" "${save_err}" 500 200
            else
                echo "Error: ${save_err}" >&2
            fi
            return 1
        fi
    fi

    # Configure service drop-in for selected mode; roll back config toggle on failure
    if configure_service_for_mode "${selected_mode}"; then
        declare -g gaming_mode_experimental_enabled="${new_exp}"
        local success_msg="Service configured for ${selected_mode} mode (Experimental Gaming Mode: ${gaming_mode_experimental_enabled})."
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Success" "${success_msg}" 520 200
        else
            echo "" >&2
            echo "✓ ${success_msg}" >&2
            echo "" >&2
        fi
        return 0
    else
        if type update_gaming_mode_config_in_place >/dev/null 2>&1; then
            update_gaming_mode_config_in_place "${current_exp}" || true
        fi
        local error_msg="Failed to configure service for ${selected_mode} mode."
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Error" "${error_msg}" 500 200
        else
            echo "Error: ${error_msg}" >&2
        fi
        return 1
    fi
}

