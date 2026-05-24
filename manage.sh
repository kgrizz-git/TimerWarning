#!/bin/bash

###############################################################################
# Sleep Warning System - Management and Help Interface
#
# This script provides a comprehensive management interface for the sleep
# warning system, allowing users to view status, configure settings,
# disable/enable the service, view logs, and get help.
#
# Requirements:
# - bash
# - zenity (preferred) or fallback to text menu
# - systemd
#
# Usage:
#   ./manage.sh
#   sleep-warning-manage (after installation)
###############################################################################

# Determine script directory and library search paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"
INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning"

for _bootstrap_lib in \
    "${INSTALLED_LIB_DIR}/_bootstrap-bash4.sh" \
    "${SCRIPT_LIB_DIR}/_bootstrap-bash4.sh"; do
    if [ -f "${_bootstrap_lib}" ]; then
        # shellcheck disable=SC1090
        source "${_bootstrap_lib}"
        _bootstrap_bash4 "${BASH_SOURCE[0]}" "$@"
        break
    fi
done
unset _bootstrap_lib

# Load shared library loader helper
LIB_HELPER_PATH=""
for candidate in \
    "${INSTALLED_LIB_DIR}/library-loader.sh" \
    "${SCRIPT_LIB_DIR}/library-loader.sh"; do
    if [ -z "${LIB_HELPER_PATH}" ] && [ -f "${candidate}" ]; then
        LIB_HELPER_PATH="${candidate}"
    fi
done

if [ -z "${LIB_HELPER_PATH}" ]; then
    echo "Error: library loader helper not found. Please reinstall the Sleep Warning System." >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${LIB_HELPER_PATH}"
init_library_paths "${INSTALLED_LIB_DIR}" "${SCRIPT_LIB_DIR}"

SOURCE_LIB_DIR="$(detect_library_dir 2>/dev/null)"
if [ -z "${SOURCE_LIB_DIR}" ]; then
    SOURCE_LIB_DIR="${INSTALLED_LIB_DIR}"
fi

SCRIPT_NAME="sleep-warning-manage"
SERVICE_NAME="sleep-warning"
TIMER_NAME="${SERVICE_NAME}.timer"
SCRIPT_PATH="${HOME}/.local/bin/${SERVICE_NAME}.sh"
CONFIG_DIR="${HOME}/.config/sleep-warning"
# Enhancement #18: Config file is now in subdirectory
# Use new location, but check old location as fallback for backward compatibility
CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
CONFIG_FILE_OLD="${CONFIG_DIR}/sleep-warning.conf"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SYSTEMD_USER_DIR}/${SERVICE_NAME}.service"
TIMER_FILE="${SYSTEMD_USER_DIR}/${TIMER_NAME}"

# Source required library modules for time check
source_required_lib "config.sh" || exit 1
# Override CONFIG_FILE with fallback logic after sourcing config.sh
# (config.sh defines CONFIG_FILE, but we want fallback support during transition)
if [ ! -f "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE_OLD}" ]; then
    CONFIG_FILE="${CONFIG_FILE_OLD}"
fi
source_required_lib "logging.sh" || exit 1
source_optional_lib "pause-state.sh" || true
source_required_lib "time-validation.sh" || exit 1
# Source display detection and desktop environment for dialog tool selection
source_required_lib "display-detection.sh" || exit 1
source_required_lib "desktop-environment.sh" || exit 1
# Source configure modules for error message display
source_required_lib "configure-core.sh" || exit 1
source_required_lib "configure-time.sh" || exit 1
source_required_lib "configure-ui.sh" || exit 1
source_required_lib "configure-dialogs.sh" || exit 1
source_optional_lib "scheduler-platform.sh" || true
if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
    TIMER_FILE="${HOME}/Library/LaunchAgents/com.sleep-warning.plist"
    SERVICE_FILE="${TIMER_FILE}"
fi

# Check if any dialog tool is available (uses get_dialog_tool which respects user preference)
# This replaces the old has_zenity() function to support all dialog tools
has_zenity() {
    # Use has_dialog_tool if available, otherwise fallback to checking zenity directly
    if type has_dialog_tool >/dev/null 2>&1; then
        has_dialog_tool
    else
        # Fallback for backward compatibility
        command -v zenity >/dev/null 2>&1
    fi
}

# Check if GUI is available
has_gui() {
    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        command -v osascript >/dev/null 2>&1 && osascript -e 'return "ok"' >/dev/null 2>&1
        return $?
    fi
    [ -n "${DISPLAY}" ] || [ -S "/tmp/.X11-unix/X0" ] || command -v loginctl >/dev/null 2>&1
}

# Check if service is installed
is_installed() {
    if type scheduler_is_installed >/dev/null 2>&1; then
        scheduler_is_installed
        return $?
    fi
    [ -f "${SCRIPT_PATH}" ] && [ -f "${SERVICE_FILE}" ] && [ -f "${TIMER_FILE}" ]
}

# Show message (GUI or text)
# Uses dialog abstraction to respect user's DIALOG_TOOL preference
show_message() {
    local title="$1"
    local message="$2"
    local msg_type="${3:-info}"
    local use_gui="$4"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool 2>/dev/null; then
        # Use dialog abstraction functions which respect user preference
        case "${msg_type}" in
            error)
                show_info_dialog "${title}" "${message}" 500 200
                ;;
            warning)
                show_info_dialog "${title}" "${message}" 500 200
                ;;
            *)
                show_info_dialog "${title}" "${message}" 500 200
                ;;
        esac
    else
        echo ""
        echo "=== ${title} ==="
        echo "${message}"
        echo ""
    fi
}

# Show text info (for logs, config, etc.)
# Uses dialog abstraction to respect user's DIALOG_TOOL preference
show_text_info() {
    local title="$1"
    local content="$2"
    local use_gui="$3"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool 2>/dev/null; then
        # Use dialog abstraction function which respects user preference
        echo "${content}" | show_text_info_dialog "${title}" 700 500
    else
        echo ""
        echo "=== ${title} ==="
        echo "${content}"
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Get service status
get_service_status() {
    if ! is_installed; then
        echo "Not installed"
        return
    fi
    if type scheduler_status_lines >/dev/null 2>&1; then
        scheduler_status_lines
        return
    fi
    local enabled active
    enabled=$(systemctl --user is-enabled "${TIMER_NAME}" 2>/dev/null)
    active=$(systemctl --user is-active "${TIMER_NAME}" 2>/dev/null)
    echo "Enabled: ${enabled:-unknown}"
    echo "Active: ${active:-unknown}"
}

# View service status
view_status() {
    local use_gui="$1"
    
    local status
    status=$(get_service_status)
    
    show_message "Service Status" "${status}" "info" "${use_gui}"
}

# View current configuration
view_config() {
    local use_gui="$1"
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        show_message "Configuration" "Configuration file not found.\n\nLocation: ${CONFIG_FILE}\n\nUsing default values." "warning" "${use_gui}"
        return
    fi
    
    local config_content
    config_content=$(cat "${CONFIG_FILE}")
    
    show_text_info "Current Configuration" "${config_content}" "${use_gui}"
}

# Launch configuration wizard
launch_configure() {
    local use_gui="$1"
    
    local configure_script="${HOME}/.local/bin/${SERVICE_NAME}-configure"
    
    if [ ! -f "${configure_script}" ]; then
        show_message "Configuration Wizard" "Configuration script not found.\n\nLocation: ${configure_script}" "error" "${use_gui}"
        return 1
    fi
    
    if [ "${use_gui}" = "true" ] && has_gui; then
        "${configure_script}" &
    else
        "${configure_script}"
    fi
}

# Disable service
disable_service() {
    local use_gui="$1"
    
    if ! is_installed; then
        show_message "Disable Service" "Service is not installed." "error" "${use_gui}"
        return 1
    fi
    
    local message="This will temporarily disable the sleep warning system.\n\nYou can re-enable it later using this management interface.\n\nContinue?"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool 2>/dev/null; then
        # Use dialog abstraction function which respects user preference
        if ! show_question_dialog "Disable Service" "${message}" "Yes" "No" 600 400; then
            return 1
        fi
    else
        echo ""
        echo "${message}"
        read -p "Continue? [y/N]: " answer
        case "${answer}" in
            [Yy]*) ;;
            *) return 1 ;;
        esac
    fi
    
    if type scheduler_stop_and_disable >/dev/null 2>&1 && scheduler_is_darwin; then
        scheduler_stop_and_disable
    else
        systemctl --user stop "${TIMER_NAME}" 2>/dev/null
        systemctl --user disable "${TIMER_NAME}" 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        show_message "Disable Service" "Service disabled successfully.\n\nThe sleep warning system will no longer check for restricted hours." "info" "${use_gui}"
    else
        show_message "Disable Service" "Error: Failed to disable service." "error" "${use_gui}"
        return 1
    fi
}

# Enable service
enable_service() {
    local use_gui="$1"
    
    if ! is_installed; then
        show_message "Enable Service" "Service is not installed." "error" "${use_gui}"
        return 1
    fi
    
    local message="This will enable the sleep warning system.\n\nIt will start checking for restricted hours immediately.\n\nContinue?"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool 2>/dev/null; then
        # Use dialog abstraction function which respects user preference
        if ! show_question_dialog "Enable Service" "${message}" "Yes" "No" 600 400; then
            return 1
        fi
    else
        echo ""
        echo "${message}"
        read -p "Continue? [y/N]: " answer
        case "${answer}" in
            [Yy]*) ;;
            *) return 1 ;;
        esac
    fi
    
    if type scheduler_enable_start >/dev/null 2>&1 && scheduler_is_darwin; then
        scheduler_enable_start
    else
        systemctl --user daemon-reload 2>/dev/null
        systemctl --user enable "${TIMER_NAME}" 2>/dev/null
        systemctl --user start "${TIMER_NAME}" 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        show_message "Enable Service" "Service enabled successfully.\n\nThe sleep warning system is now active." "info" "${use_gui}"
    else
        show_message "Enable Service" "Error: Failed to enable service." "error" "${use_gui}"
        return 1
    fi
}

# View service logs
view_logs() {
    local use_gui="$1"
    
    if ! is_installed; then
        show_message "Service Logs" "Service is not installed." "error" "${use_gui}"
        return 1
    fi
    
    local logs
    logs=$(journalctl --user -u "${SERVICE_NAME}.service" -n 50 --no-pager 2>/dev/null)
    
    if [ -z "${logs}" ]; then
        logs="No logs found. The service may not have run yet."
    fi
    
    show_text_info "Service Logs (Last 50 entries)" "${logs}" "${use_gui}"
}

# Show file locations
show_file_locations() {
    local use_gui="$1"
    
    local locations="File Locations:\n\n"
    locations="${locations}Main Script: ${SCRIPT_PATH}\n"
    locations="${locations}Configuration: ${CONFIG_FILE}\n"
    locations="${locations}Service File: ${SERVICE_FILE}\n"
    locations="${locations}Timer File: ${TIMER_FILE}\n"
    locations="${locations}\n"
    locations="${locations}Configuration Wizard: ${HOME}/.local/bin/${SERVICE_NAME}-configure\n"
    locations="${locations}Management Script: ${HOME}/.local/bin/${SERVICE_NAME}-manage"
    
    show_message "File Locations" "${locations}" "info" "${use_gui}"
}

# Show help information
show_help() {
    local use_gui="$1"
    
    local help_text="Sleep Warning System - Help

OVERVIEW:
The Sleep Warning System displays warning popups when you use your computer
during configured restricted hours, helping you maintain healthy sleep schedules.

KEY FEATURES:
- Configurable restricted hours for each day of the week
- Automatic checks every 10 minutes
- Modal warning popups that require acknowledgment
- Easy configuration through interactive wizard
- Can be temporarily disabled without uninstalling

COMMON TASKS:

1. Configure Restricted Hours:
   Run: sleep-warning-configure
   Or use this management interface

2. Temporarily Disable:
   Use this management interface, or run:
   systemctl --user stop sleep-warning.timer
   systemctl --user disable sleep-warning.timer

3. Re-enable:
   Use this management interface, or run:
   systemctl --user enable sleep-warning.timer
   systemctl --user start sleep-warning.timer

4. View Status:
   systemctl --user status sleep-warning.timer

5. View Logs:
   journalctl --user -u sleep-warning.service -f

6. Uninstall:
   Run uninstall.sh from the source directory

For more information, see the README.md file."
    
    show_text_info "Help and Information" "${help_text}" "${use_gui}"
}

# View pause status
view_pause_status() {
    local use_gui="$1"
    
    # Check if pause state functions are available
    if ! type is_pause_active >/dev/null 2>&1 || ! type can_pause_today >/dev/null 2>&1; then
        show_message "Pause Status" "Pause status functions are not available.\n\nThis feature requires pause-state.sh library." "warning" "${use_gui}"
        return 1
    fi
    
    local status_text="Pause Feature Status\n\n"
    
    # Check if pause is enabled
    local pause_enabled
    pause_enabled=$(grep -E "^[[:space:]]*PAUSE_ENABLED=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -z "${pause_enabled}" ] || [ "${pause_enabled}" = "true" ] || [ "${pause_enabled}" = "1" ] || [ "${pause_enabled}" = "yes" ]; then
        status_text="${status_text}Feature: Enabled\n"
    else
        status_text="${status_text}Feature: Disabled\n"
    fi
    
    # Get pause duration
    local pause_duration
    pause_duration=$(grep -E "^[[:space:]]*PAUSE_DURATION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "${pause_duration}" ]; then
        pause_duration="5"
    fi
    status_text="${status_text}Duration: ${pause_duration} minutes\n"
    
    # Note: Once-per-day limit is ALWAYS enforced (not configurable)
    status_text="${status_text}Once Per Day: Always Enabled (not configurable)\n"
    status_text="${status_text}\n"
    
    # Check if pause is currently active
    if is_pause_active; then
        local pause_end_timestamp
        pause_end_timestamp=$(get_pause_end_timestamp)
        if [ -n "${pause_end_timestamp}" ]; then
            local pause_end_time
            pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
            status_text="${status_text}Current Status: ACTIVE\n"
            status_text="${status_text}Pause expires at: ${pause_end_time}\n"
        else
            status_text="${status_text}Current Status: ACTIVE (end time unknown)\n"
        fi
    else
        status_text="${status_text}Current Status: Not active\n"
    fi
    
    # Display last pause date
    local last_pause_date
    last_pause_date=$(get_last_pause_date)
    if [ -n "${last_pause_date}" ]; then
        status_text="${status_text}Last Pause Date: ${last_pause_date}\n"
    else
        status_text="${status_text}Last Pause Date: Never used\n"
    fi
    
    # Display whether pause is available today
    if can_pause_today; then
        status_text="${status_text}Pause Available Today: Yes\n"
    else
        status_text="${status_text}Pause Available Today: No\n"
        if [ "${pause_enabled}" != "true" ] && [ "${pause_enabled}" != "1" ] && [ "${pause_enabled}" != "yes" ]; then
            status_text="${status_text}  (Pause feature is disabled)\n"
        else
            status_text="${status_text}  (Already used today or once-per-day limit enabled)\n"
        fi
    fi
    
    status_text="${status_text}\n"
    status_text="${status_text}Note: Pause only suppresses warning popups.\n"
    status_text="${status_text}Restrictions (configure.sh blocking, uninstall.sh protection) still apply during pause."
    
    show_message "Pause Status" "${status_text}" "info" "${use_gui}"
}

# Show uninstall information
show_uninstall_info() {
    local use_gui="$1"
    
    local info="How to Uninstall:

To completely remove the Sleep Warning System:

1. Navigate to the source directory where you cloned/downloaded the project

2. Run the uninstall script:
   ./uninstall.sh

This will:
- Stop and disable the service
- Remove all installed files
- Optionally remove your configuration file

Your configuration will be preserved unless you choose to remove it."
    
    show_message "Uninstall Information" "${info}" "info" "${use_gui}"
}

# Main menu (GUI)
# Uses dialog abstraction to respect user's DIALOG_TOOL preference
show_menu_gui() {
    local choice
    
    # Use dialog abstraction function which respects user preference
    choice=$(show_list_dialog \
        "Sleep Warning System - Management" \
        "Select an option:" \
        "View Service Status" \
        "View Current Configuration" \
        "Configure Restricted Hours" \
        "Temporarily Disable Service" \
        "Re-enable Service" \
        "View Service Logs" \
        "View Pause Status" \
        "Uninstall Information" \
        "Help and Information" \
        "Exit" \
        400 \
        400)
    
    if [ -z "${choice}" ]; then
        return 1
    fi
    
    echo "${choice}"
    return 0
}

# Main menu (text)
show_menu_text() {
    while true; do
        echo ""
        echo "=== Sleep Warning System - Management ==="
        echo ""
        echo "1. View Service Status"
        echo "2. View Current Configuration"
        echo "3. Configure Restricted Hours"
        echo "4. Temporarily Disable Service"
        echo "5. Re-enable Service"
        echo "6. View Service Logs"
        echo "7. View Pause Status"
        echo "8. Uninstall Information"
        echo "9. Help and Information"
        echo "10. Exit"
        echo ""
        read -p "Select an option [1-10]: " choice
        
        case "${choice}" in
            1|2|3|4|5|6|7|8|9|10)
                echo "${choice}"
                return 0
                ;;
            *)
                echo "Invalid option. Please select 1-10."
                ;;
        esac
    done
}

# Main function
main() {
    local use_gui="false"
    # Use has_dialog_tool instead of has_zenity to support all dialog tools
    if has_gui && has_dialog_tool 2>/dev/null; then
        use_gui="true"
    fi
    
    # Check if configuration is locked due to restricted hours
    if ! check_config_lock_time 2>/dev/null; then
        # Configuration is locked - show error and exit
        show_config_locked_error "${use_gui}" "Management interface"
        exit 1
    fi
    
    # Check if installed
    if ! is_installed; then
        show_message "Not Installed" "The Sleep Warning System is not installed.\n\nPlease run install.sh to install it first." "error" "${use_gui}"
        exit 1
    fi
    
    # Main loop
    while true; do
        local choice
        
        if [ "${use_gui}" = "true" ]; then
            choice=$(show_menu_gui)
        else
            choice=$(show_menu_text)
        fi
        
        if [ -z "${choice}" ] || [ "${choice}" = "Exit" ] || [ "${choice}" = "10" ]; then
            break
        fi
        
        case "${choice}" in
            "View Service Status"|1)
                view_status "${use_gui}"
                ;;
            "View Current Configuration"|2)
                view_config "${use_gui}"
                ;;
            "Configure Restricted Hours"|3)
                launch_configure "${use_gui}"
                ;;
            "Temporarily Disable Service"|4)
                disable_service "${use_gui}"
                ;;
            "Re-enable Service"|5)
                enable_service "${use_gui}"
                ;;
            "View Service Logs"|6)
                view_logs "${use_gui}"
                ;;
            "View Pause Status"|7)
                view_pause_status "${use_gui}"
                ;;
            "Uninstall Information"|8)
                show_uninstall_info "${use_gui}"
                ;;
            "Help and Information"|9)
                show_help "${use_gui}"
                ;;
        esac
    done
}

# Run main function
main "$@"
