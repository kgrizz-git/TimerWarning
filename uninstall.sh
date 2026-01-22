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
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Determine script directory and library path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"

# Determine which library directory to use for sourcing (project dir if available, otherwise installed location)
# IMPORTANT: Never change LIB_DIR itself - it must always point to the installed location for deletion
SOURCE_LIB_DIR="${LIB_DIR}"
if [ -d "${SCRIPT_LIB_DIR}" ]; then
    # Running from project directory - use project lib for sourcing
    SOURCE_LIB_DIR="${SCRIPT_LIB_DIR}"
fi

# Source library modules if available (for uninstall protection check)
# These are sourced with error suppression to allow uninstall even if some modules are missing
if [ -f "${SOURCE_LIB_DIR}/config.sh" ]; then
    source "${SOURCE_LIB_DIR}/config.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/logging.sh" ]; then
    source "${SOURCE_LIB_DIR}/logging.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/time-validation.sh" ]; then
    source "${SOURCE_LIB_DIR}/time-validation.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/configure-core.sh" ]; then
    source "${SOURCE_LIB_DIR}/configure-core.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/configure-dialogs.sh" ]; then
    source "${SOURCE_LIB_DIR}/configure-dialogs.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/configure-ui.sh" ]; then
    source "${SOURCE_LIB_DIR}/configure-ui.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/uninstall-verification.sh" ]; then
    source "${SOURCE_LIB_DIR}/uninstall-verification.sh" 2>/dev/null || true
fi

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

# Function to stop and disable timer
stop_timer() {
    print_info "Stopping systemd timer..."
    
    if systemctl --user is-active --quiet sleep-warning.timer 2>/dev/null; then
        if systemctl --user stop sleep-warning.timer; then
            print_success "Timer stopped"
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

# Function to remove configuration file
remove_config() {
    if [ "$REMOVE_CONFIG" = true ]; then
        if [ -f "$CONFIG_DIR/sleep-warning.conf" ]; then
            rm -f "$CONFIG_DIR/sleep-warning.conf"
            print_success "Configuration file removed"
            
            # Remove config directory if empty
            if [ -d "$CONFIG_DIR" ] && [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
                rmdir "$CONFIG_DIR" 2>/dev/null && print_success "Config directory removed" || true
            fi
        else
            print_info "Configuration file not found"
        fi
    else
        if [ -f "$CONFIG_DIR/sleep-warning.conf" ]; then
            echo ""
            echo -n "Remove configuration file? (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm -f "$CONFIG_DIR/sleep-warning.conf"
                print_success "Configuration file removed"
                
                # Remove config directory if empty
                if [ -d "$CONFIG_DIR" ] && [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
                    rmdir "$CONFIG_DIR" 2>/dev/null && print_success "Config directory removed" || true
                fi
            else
                print_info "Configuration file preserved"
            fi
        fi
    fi
}

# Function to reload systemd
reload_systemd() {
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
       [ -f "$INSTALL_DIR/sleep-warning-manage" ]; then
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
    echo "  • Scripts from $INSTALL_DIR"
    echo "  • Systemd service and timer files"
    if [ "$REMOVE_CONFIG" = true ] || [ -f "$CONFIG_DIR/sleep-warning.conf" ]; then
        echo "  • Configuration file"
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
