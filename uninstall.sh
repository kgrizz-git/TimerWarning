#!/bin/bash

###############################################################################
# Sleep Warning System - Uninstallation Script
#
# This script removes the Sleep Warning System from your system.
# It stops and disables the systemd timer, removes all installed files,
# and optionally removes the configuration file.
#
# Requirements:
# - bash
# - systemd (for user services)
#
# Usage:
#   ./uninstall.sh              # Uninstall (prompts about config file)
#   ./uninstall.sh --remove-config  # Uninstall including config file
#
# Output:
# - Removes all installed files
# - Stops and disables systemd timer
# - Provides uninstallation summary
#
# Note: If UNINSTALL_PROTECTION_MODE=difficult is enabled and current time
# is within restricted hours, this script will require verification
# (confirmation phrase + 10 algebra questions) before proceeding.
# This is Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)
###############################################################################


# Script configuration
INSTALL_DIR="${HOME}/.local/bin"
LIB_DIR="${HOME}/.local/lib/sleep-warning"
CONFIG_DIR="${HOME}/.config/sleep-warning"
# Enhancement #18: Config file is now in subdirectory (but we handle both old and new locations)
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Determine script directory and library search paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"
INSTALLED_LIB_DIR="${LIB_DIR}"

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

# Source library modules if available (for uninstall protection check)
# These are sourced with error suppression to allow uninstall even if some modules are missing
source_optional_lib "config.sh" || true
source_optional_lib "logging.sh" || true
source_optional_lib "time-validation.sh" || true

# Source display detection and desktop environment for dialog tool selection
source_optional_lib "display-detection.sh" || true
source_optional_lib "desktop-environment.sh" || true
source_optional_lib "configure-core.sh" || true
source_optional_lib "configure-dialogs.sh" || true
source_optional_lib "configure-ui.sh" || true
source_optional_lib "uninstall-verification.sh" || true
source_optional_lib "scheduler-platform.sh" || true

# Enable exit on error after library sourcing (for backward compatibility, libraries may not exist)
set -e

# Colors for output (with fallback for non-color terminals)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Flags
REMOVE_CONFIG=false

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        --remove-config)
            REMOVE_CONFIG=true
            ;;
        -h|--help)
            echo "Usage: $0 [--remove-config]"
            echo "  --remove-config  Also remove configuration file"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $arg${NC}" >&2
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Function to restore config file permissions (Enhancement #18)
# This ensures config file and directory are writable before uninstall
restore_config_permissions() {
    local config_dir_locked="${CONFIG_DIR}/config"
    local config_file="${config_dir_locked}/sleep-warning.conf"
    local marker_file="${CONFIG_DIR}/.config_locked"
    local snapshot_file="${CONFIG_DIR}/.config_locked_snapshot"

    # Uninstall must be able to remove config files even if they are locked.
    # Best-effort approach:
    # - Make marker/snapshot writable (if present)
    # - Restore directory/file permissions (prefer stored modes if marker exists)
    # - Remove marker/snapshot to prevent re-lock artifacts
    #
    # IMPORTANT: For uninstall purposes, we only need the config to be deletable.
    # If the marker is missing/corrupt, safe defaults are sufficient.
    print_info "Ensuring config file permissions are writable (Enhancement #18)..."

    # Always try to make marker/snapshot writable first (ignore errors)
    chmod 644 "${marker_file}" 2>/dev/null || true
    chmod 644 "${snapshot_file}" 2>/dev/null || true

    local dir_mode="755"
    local file_mode="644"

    # If marker exists, try to restore the original modes for completeness
    if [ -f "${marker_file}" ]; then
        local marker_content
        marker_content=$(cat "${marker_file}" 2>/dev/null)

        if echo "${marker_content}" | grep -q "DIR_MODE="; then
            dir_mode=$(echo "${marker_content}" | sed -n 's/.*DIR_MODE=\([0-7]\{3,4\}\).*/\1/p' 2>/dev/null || echo "755")
        fi
        if echo "${marker_content}" | grep -q "FILE_MODE="; then
            file_mode=$(echo "${marker_content}" | sed -n 's/.*FILE_MODE=\([0-7]\{3,4\}\).*/\1/p' 2>/dev/null || echo "644")
        fi
    fi

    # Validate modes (fallback to safe defaults)
    if ! [[ "${dir_mode}" =~ ^[0-7]{3,4}$ ]]; then
        dir_mode="755"
    fi
    if ! [[ "${file_mode}" =~ ^[0-7]{3,4}$ ]]; then
        file_mode="644"
    fi

    # Restore directory/file permissions (ignore errors)
    if [ -d "${config_dir_locked}" ]; then
        chmod "${dir_mode}" "${config_dir_locked}" 2>/dev/null || chmod 755 "${config_dir_locked}" 2>/dev/null || true
    fi
    if [ -f "${config_file}" ]; then
        chmod "${file_mode}" "${config_file}" 2>/dev/null || chmod 644 "${config_file}" 2>/dev/null || true
    fi

    # Remove marker and snapshot files (ignore errors)
    rm -f "${marker_file}" 2>/dev/null || true
    rm -f "${snapshot_file}" 2>/dev/null || true

    print_success "Config file permissions ensured writable"
}

# Function to stop and disable timer
stop_timer() {
    if type scheduler_stop_and_disable >/dev/null 2>&1 && scheduler_is_darwin; then
        print_info "Stopping LaunchAgent..."
        scheduler_stop_and_disable
        print_success "LaunchAgent stopped"
        return 0
    fi
    print_info "Stopping systemd timer..."
    
    if systemctl --user is-active --quiet sleep-warning.timer 2>/dev/null; then
        if systemctl --user stop sleep-warning.timer; then
            print_success "Timer stopped"
            sleep 2
        else
            print_warning "Failed to stop timer (may not be running)"
        fi
    else
        print_info "Timer is not running"
    fi
    
    if systemctl --user is-enabled --quiet sleep-warning.timer 2>/dev/null; then
        if systemctl --user disable sleep-warning.timer; then
            print_success "Timer disabled"
        else
            print_warning "Failed to disable timer"
        fi
    else
        print_info "Timer is not enabled"
    fi
}

# Function to remove systemd files
remove_systemd_files() {
    if type scheduler_remove_files >/dev/null 2>&1 && scheduler_is_darwin; then
        print_info "Removing LaunchAgent plist..."
        scheduler_remove_files
        print_success "LaunchAgent removed"
        return 0
    fi
    print_info "Removing systemd service and timer files..."
    
    local removed=false
    
    if [ -f "$SYSTEMD_USER_DIR/sleep-warning.service" ]; then
        rm -f "$SYSTEMD_USER_DIR/sleep-warning.service"
        print_success "Service file removed"
        removed=true
    fi
    
    if [ -f "$SYSTEMD_USER_DIR/sleep-warning.timer" ]; then
        rm -f "$SYSTEMD_USER_DIR/sleep-warning.timer"
        print_success "Timer file removed"
        removed=true
    fi
    
    if [ "$removed" = false ]; then
        print_info "No systemd files found to remove"
    fi
}

# Function to remove scripts
remove_scripts() {
    print_info "Removing scripts..."
    
    local removed=false
    
    if [ -f "$INSTALL_DIR/sleep-warning.sh" ]; then
        rm -f "$INSTALL_DIR/sleep-warning.sh"
        print_success "Main script removed"
        removed=true
    fi
    
    if [ -f "$INSTALL_DIR/sleep-warning-configure" ]; then
        rm -f "$INSTALL_DIR/sleep-warning-configure"
        print_success "Configuration wizard removed"
        removed=true
    fi
    
    if [ -f "$INSTALL_DIR/sleep-warning-manage" ]; then
        rm -f "$INSTALL_DIR/sleep-warning-manage"
        print_success "Management script removed"
        removed=true
    fi

    if [ -f "$INSTALL_DIR/sleep-warning-status" ]; then
        rm -f "$INSTALL_DIR/sleep-warning-status"
        print_success "Status script removed"
        removed=true
    fi

    if [ -f "$INSTALL_DIR/sleep-warning-uninstall" ]; then
        rm -f "$INSTALL_DIR/sleep-warning-uninstall"
        print_success "Uninstall helper script removed"
        removed=true
    fi

    if [ -f "$INSTALL_DIR/manual-uninstall-guide" ]; then
        rm -f "$INSTALL_DIR/manual-uninstall-guide"
        print_success "Manual uninstall guide script removed"
        removed=true
    fi
    
    # Remove library directory and modules
    if [ -d "$LIB_DIR" ]; then
        rm -rf "$LIB_DIR"
        print_success "Library modules removed"
        removed=true
    fi
    
    if [ "$removed" = false ]; then
        print_info "No scripts found to remove"
    fi
}

# Function to remove ancillary log/state files (warnings.log, pause state, last uptime, popup PID)
remove_ancillary_files() {
    print_info "Removing ancillary log/state files..."

    local removed=false

    # Use configured paths when available, fall back to defaults under CONFIG_DIR
    local log_file="${LOG_FILE:-${CONFIG_DIR}/warnings.log}"
    local pause_file="${PAUSE_STATE_FILE:-${CONFIG_DIR}/.pause_state}"
    local uptime_file="${LAST_UPTIME_FILE:-${CONFIG_DIR}/.last_uptime}"
    local popup_pid_file="${POPUP_PID_FILE:-${CONFIG_DIR}/.popup_pid}"

    if [ -f "${log_file}" ]; then
        rm -f "${log_file}"
        print_success "Log file removed: ${log_file}"
        removed=true
    fi

    if [ -f "${pause_file}" ]; then
        rm -f "${pause_file}"
        print_success "Pause state file removed: ${pause_file}"
        removed=true
    fi

    if [ -f "${uptime_file}" ]; then
        rm -f "${uptime_file}"
        print_success "Last uptime file removed: ${uptime_file}"
        removed=true
    fi

    if [ -f "${popup_pid_file}" ]; then
        rm -f "${popup_pid_file}"
        print_success "Popup PID file removed: ${popup_pid_file}"
        removed=true
    fi

    if [ "${removed}" = false ]; then
        print_info "No ancillary log/state files found to remove"
    fi
}

# Function to remove configuration file
remove_config() {
    # Enhancement #18: Config file is now in subdirectory
    local config_file="${CONFIG_DIR}/config/sleep-warning.conf"
    local old_config_file="${CONFIG_DIR}/sleep-warning.conf"

    # Always remove ancillary log/state files during uninstall
    remove_ancillary_files
    
    if [ "$REMOVE_CONFIG" = true ]; then
        # Remove new location
        if [ -f "${config_file}" ]; then
            rm -f "${config_file}"
            print_success "Configuration file removed"
        fi
        # Remove old location (if migration didn't happen)
        if [ -f "${old_config_file}" ]; then
            rm -f "${old_config_file}"
            print_success "Old configuration file removed"
        fi
        
        # Remove config subdirectory if empty
        if [ -d "${CONFIG_DIR}/config" ] && [ -z "$(ls -A "${CONFIG_DIR}/config" 2>/dev/null)" ]; then
            rmdir "${CONFIG_DIR}/config" 2>/dev/null && print_success "Config subdirectory removed" || true
        fi
        
        # Remove config directory if empty
        if [ -d "$CONFIG_DIR" ] && [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
            rmdir "$CONFIG_DIR" 2>/dev/null && print_success "Config directory removed" || true
        fi
        
        if [ ! -f "${config_file}" ] && [ ! -f "${old_config_file}" ]; then
            print_info "Configuration file not found"
        fi
    else
        if [ -f "${config_file}" ] || [ -f "${old_config_file}" ]; then
            echo ""
            echo -n "Remove configuration file? (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                if [ -f "${config_file}" ]; then
                    rm -f "${config_file}"
                    print_success "Configuration file removed"
                fi
                if [ -f "${old_config_file}" ]; then
                    rm -f "${old_config_file}"
                    print_success "Old configuration file removed"
                fi
                
                # Remove config subdirectory if empty
                if [ -d "${CONFIG_DIR}/config" ] && [ -z "$(ls -A "${CONFIG_DIR}/config" 2>/dev/null)" ]; then
                    rmdir "${CONFIG_DIR}/config" 2>/dev/null && print_success "Config subdirectory removed" || true
                fi
                
                # Remove config directory if empty
                if [ -d "$CONFIG_DIR" ] && [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
                    rmdir "$CONFIG_DIR" 2>/dev/null && print_success "Config directory removed" || true
                fi
            else
                print_info "Configuration file preserved"
            fi
        else
            print_info "Configuration file not found"
        fi
    fi
}

# Function to reload systemd
reload_systemd() {
    if type scheduler_is_darwin >/dev/null 2>&1 && scheduler_is_darwin; then
        print_info "LaunchAgent removed (no daemon reload needed on macOS)"
        return 0
    fi
    print_info "Reloading systemd user daemon..."
    
    if systemctl --user daemon-reload; then
        print_success "Systemd daemon reloaded"
    else
        print_warning "Failed to reload systemd daemon (may not be necessary)"
    fi
}

# Function to verify removal
verify_removal() {
    print_info "Verifying removal..."
    
    local still_installed=false
    
    if [ -f "$INSTALL_DIR/sleep-warning.sh" ] || \
       [ -f "$INSTALL_DIR/sleep-warning-configure" ] || \
       [ -f "$INSTALL_DIR/sleep-warning-manage" ] || \
       [ -f "$INSTALL_DIR/sleep-warning-status" ] || \
       [ -f "$INSTALL_DIR/sleep-warning-uninstall" ] || \
       [ -f "$INSTALL_DIR/manual-uninstall-guide" ]; then
        still_installed=true
        print_warning "Some scripts are still present"
    fi
    
    if [ -f "$SYSTEMD_USER_DIR/sleep-warning.service" ] || \
       [ -f "$SYSTEMD_USER_DIR/sleep-warning.timer" ]; then
        still_installed=true
        print_warning "Some systemd files are still present"
    fi
    
    if [ "$still_installed" = false ]; then
        print_success "All files removed successfully"
    fi
}

# Function to print uninstallation summary
print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Sleep Warning System Uninstallation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Removed:"
    echo "  - Scripts from $INSTALL_DIR"
    echo "  - Systemd service and timer files"
    if [ "$REMOVE_CONFIG" = true ] || [ -f "$CONFIG_DIR/sleep-warning.conf" ]; then
        echo "  - Configuration file"
    fi
    echo ""
    echo "The Sleep Warning System has been completely removed from your system."
    echo ""
}

# Main uninstallation function
main() {
    echo -e "${BLUE}Sleep Warning System - Uninstallation${NC}"
    echo ""
    
    # Check if uninstall protection is enabled and we're in restricted hours
    # This check must happen BEFORE any other operations
    # Use error suppression to ensure script continues even if protection check fails
    local protection_mode="none"
    if type check_uninstall_protection_time >/dev/null 2>&1; then
        protection_mode=$(check_uninstall_protection_time 2>/dev/null || echo "none")
    fi
    
    if [ "${protection_mode}" = "difficult" ]; then
        # Determine GUI mode - use GUI if DISPLAY is set and dialog tool is available
        # This provides a better user experience with dialog windows for verification
        local use_gui="false"
        if [ -n "${DISPLAY}" ] && type has_dialog_tool >/dev/null 2>&1 && has_dialog_tool 2>/dev/null; then
            use_gui="true"
        fi
        
        # Require verification
        if type verify_uninstall_during_restrictions >/dev/null 2>&1; then
            if ! verify_uninstall_during_restrictions "${use_gui}" 2>/dev/null; then
                local exit_code=$?
                if [ ${exit_code} -eq 2 ]; then
                    # User cancelled
                    print_info "Uninstall cancelled by user."
                    exit 0
                else
                    # Verification failed
                    print_error "Uninstall verification failed. Uninstall cancelled."
                    exit 1
                fi
            fi
        else
            # Verification module not available - show warning but allow (shouldn't happen in normal install)
            # This handles backward compatibility with older installations
            print_warning "Uninstall verification module not available. Proceeding without verification."
        fi
    fi
    
    # Check if installed
    if [ ! -f "$INSTALL_DIR/sleep-warning.sh" ] && \
       [ ! -f "$SYSTEMD_USER_DIR/sleep-warning.service" ]; then
        print_warning "Sleep Warning System does not appear to be installed"
        exit 0
    fi
    
    # Stop and disable timer
    stop_timer

    # Ensure config file/directory are writable before attempting removal
    # (Timer is stopped to prevent immediate re-locking)
    restore_config_permissions
    
    # Remove systemd files
    remove_systemd_files
    
    # Remove scripts
    remove_scripts
    
    # Remove configuration file
    remove_config
    
    # Reload systemd
    reload_systemd
    
    # Verify removal
    verify_removal
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
