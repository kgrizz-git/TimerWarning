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

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

SCRIPT_NAME="sleep-warning-manage"
SERVICE_NAME="sleep-warning"
TIMER_NAME="${SERVICE_NAME}.timer"
SCRIPT_PATH="${HOME}/.local/bin/${SERVICE_NAME}.sh"
CONFIG_DIR="${HOME}/.config/sleep-warning"
CONFIG_FILE="${CONFIG_DIR}/sleep-warning.conf"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SYSTEMD_USER_DIR}/${SERVICE_NAME}.service"
TIMER_FILE="${SYSTEMD_USER_DIR}/${TIMER_NAME}"

# Source required library modules for time check
source "${LIB_DIR}/config.sh" 2>/dev/null || true
source "${LIB_DIR}/logging.sh" 2>/dev/null || true
source "${LIB_DIR}/time-validation.sh" 2>/dev/null || true
# Source configure modules for error message display
source "${LIB_DIR}/configure-core.sh" 2>/dev/null || true
source "${LIB_DIR}/configure-time.sh" 2>/dev/null || true
source "${LIB_DIR}/configure-ui.sh" 2>/dev/null || true
source "${LIB_DIR}/configure-dialogs.sh" 2>/dev/null || true

# Check if zenity is available
has_zenity() {
    command -v zenity >/dev/null 2>&1
}

# Check if GUI is available
has_gui() {
    [ -n "${DISPLAY}" ] || [ -S "/tmp/.X11-unix/X0" ] || command -v loginctl >/dev/null 2>&1
}

# Check if service is installed
is_installed() {
    [ -f "${SCRIPT_PATH}" ] && [ -f "${SERVICE_FILE}" ] && [ -f "${TIMER_FILE}" ]
}

# Show message (GUI or text)
show_message() {
    local title="$1"
    local message="$2"
    local msg_type="${3:-info}"
    local use_gui="$4"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        case "${msg_type}" in
            error)
                zenity --error --title="${title}" --text="${message}" --width=500 2>/dev/null
                ;;
            warning)
                zenity --warning --title="${title}" --text="${message}" --width=500 2>/dev/null
                ;;
            *)
                zenity --info --title="${title}" --text="${message}" --width=500 2>/dev/null
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
show_text_info() {
    local title="$1"
    local content="$2"
    local use_gui="$3"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        echo "${content}" | zenity --text-info \
            --title="${title}" \
            --width=700 \
            --height=500 \
            --font="monospace" \
            2>/dev/null
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
    
    local enabled active
    enabled=$(systemctl --user is-enabled "${TIMER_NAME}" 2>/dev/null)
    active=$(systemctl --user is-active "${TIMER_NAME}" 2>/dev/null)
    
    echo "Enabled: ${enabled:-unknown}"
    echo "Active: ${active:-unknown}"
    
    if [ "${active}" = "active" ]; then
        local next_trigger
        next_trigger=$(systemctl --user list-timers "${TIMER_NAME}" --no-pager --no-legend 2>/dev/null | awk '{print $1, $2, $3, $4, $5}')
        if [ -n "${next_trigger}" ]; then
            echo "Next trigger: ${next_trigger}"
        fi
    fi
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
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        if ! zenity --question --title="Disable Service" --text="${message}" 2>/dev/null; then
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
    
    systemctl --user stop "${TIMER_NAME}" 2>/dev/null
    systemctl --user disable "${TIMER_NAME}" 2>/dev/null
    
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
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        if ! zenity --question --title="Enable Service" --text="${message}" 2>/dev/null; then
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
    
    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable "${TIMER_NAME}" 2>/dev/null
    systemctl --user start "${TIMER_NAME}" 2>/dev/null
    
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
• Configurable restricted hours for each day of the week
• Automatic checks every 10 minutes
• Modal warning popups that require acknowledgment
• Easy configuration through interactive wizard
• Can be temporarily disabled without uninstalling

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

# Show disable instructions
show_disable_instructions() {
    local use_gui="$1"
    
    local instructions="How to Temporarily Disable the Service:

METHOD 1 - Using this Management Interface:
Select 'Disable Service' from the main menu.

METHOD 2 - Using Command Line:
Run these commands:
  systemctl --user stop sleep-warning.timer
  systemctl --user disable sleep-warning.timer

The service will stop checking for restricted hours immediately.
You can re-enable it anytime using this management interface."
    
    show_message "How to Disable Service" "${instructions}" "info" "${use_gui}"
}

# Show enable instructions
show_enable_instructions() {
    local use_gui="$1"
    
    local instructions="How to Re-enable the Service:

METHOD 1 - Using this Management Interface:
Select 'Enable Service' from the main menu.

METHOD 2 - Using Command Line:
Run these commands:
  systemctl --user enable sleep-warning.timer
  systemctl --user start sleep-warning.timer

The service will start checking for restricted hours immediately."
    
    show_message "How to Enable Service" "${instructions}" "info" "${use_gui}"
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
• Stop and disable the service
• Remove all installed files
• Optionally remove your configuration file

Your configuration will be preserved unless you choose to remove it."
    
    show_message "Uninstall Information" "${info}" "info" "${use_gui}"
}

# Main menu (GUI)
show_menu_gui() {
    local choice
    
    choice=$(zenity --list \
        --title="Sleep Warning System - Management" \
        --text="Select an option:" \
        --column="Option" \
        "View Service Status" \
        "View Current Configuration" \
        "Configure Restricted Hours" \
        "Temporarily Disable Service" \
        "Re-enable Service" \
        "View Service Logs" \
        "Show File Locations" \
        "How to Disable (Instructions)" \
        "How to Enable (Instructions)" \
        "Uninstall Information" \
        "Help and Information" \
        "Exit" \
        --width=400 \
        --height=400 \
        2>/dev/null)
    
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
        echo "7. Show File Locations"
        echo "8. How to Disable (Instructions)"
        echo "9. How to Enable (Instructions)"
        echo "10. Uninstall Information"
        echo "11. Help and Information"
        echo "12. Exit"
        echo ""
        read -p "Select an option [1-12]: " choice
        
        case "${choice}" in
            1|2|3|4|5|6|7|8|9|10|11|12)
                echo "${choice}"
                return 0
                ;;
            *)
                echo "Invalid option. Please select 1-12."
                ;;
        esac
    done
}

# Main function
main() {
    local use_gui="false"
    if has_gui && has_zenity; then
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
        
        if [ -z "${choice}" ] || [ "${choice}" = "Exit" ] || [ "${choice}" = "12" ]; then
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
            "Show File Locations"|7)
                show_file_locations "${use_gui}"
                ;;
            "How to Disable (Instructions)"|8)
                show_disable_instructions "${use_gui}"
                ;;
            "How to Enable (Instructions)"|9)
                show_enable_instructions "${use_gui}"
                ;;
            "Uninstall Information"|10)
                show_uninstall_info "${use_gui}"
                ;;
            "Help and Information"|11)
                show_help "${use_gui}"
                ;;
        esac
    done
}

# Run main function
main "$@"
