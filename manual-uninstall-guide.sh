#!/bin/bash

###############################################################################
# Sleep Warning System - Manual Uninstallation Guide
#
# This script provides step-by-step instructions for manually uninstalling
# the Sleep Warning System. This guide is always accessible, even during
# restricted hours when uninstall.sh may be blocked.
#
# This script is a safety mechanism for Enhancement #26 (Prevent uninstall.sh
# Execution During Restricted Hours). It provides users with instructions
# for manual uninstallation when automated uninstall is blocked.
#
# Requirements:
# - bash
# - systemd (for user services)
#
# Usage:
#   ./manual-uninstall-guide.sh              # Show instructions
#   manual-uninstall-guide                   # After installation
#
# Output:
# - Displays step-by-step manual uninstallation instructions
# - Provides copy-paste ready commands
# - Lists all files and directories to remove
###############################################################################

# Script configuration
INSTALL_DIR="${HOME}/.local/bin"
LIB_DIR="${HOME}/.local/lib/sleep-warning"
CONFIG_DIR="${HOME}/.config/sleep-warning"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Colors for output (with fallback for non-color terminals)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Function to print colored messages
print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

print_step() {
    echo -e "${GREEN}→${NC} $1"
}

print_command() {
    echo -e "  ${YELLOW}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Function to show instructions in GUI mode
show_gui_instructions() {
    # Check for dialog tools
    if command -v yad >/dev/null 2>&1; then
        local instructions
        instructions=$(cat <<'EOF'
Manual Uninstallation Guide for Sleep Warning System

This guide provides step-by-step instructions for manually removing the Sleep Warning System from your system.

STEP 1: Stop and Disable Timer
Run these commands:
  systemctl --user stop sleep-warning.timer
  systemctl --user disable sleep-warning.timer

STEP 2: Remove Systemd Files
Remove these files:
  ~/.config/systemd/user/sleep-warning.service
  ~/.config/systemd/user/sleep-warning.timer

STEP 3: Remove Scripts
Remove these files/directories:
  ~/.local/bin/sleep-warning.sh
  ~/.local/bin/sleep-warning-configure
  ~/.local/bin/sleep-warning-manage
  ~/.local/lib/sleep-warning/ (entire directory)

STEP 4: Remove Configuration (Optional)
Remove configuration file:
  ~/.config/sleep-warning/sleep-warning.conf
  ~/.config/sleep-warning/warnings.log

STEP 5: Reload Systemd
Run this command:
  systemctl --user daemon-reload

After completing these steps, the Sleep Warning System will be completely removed from your system.
EOF
)
        yad --text-info \
            --title="Manual Uninstallation Guide" \
            --width=700 \
            --height=600 \
            --button="Close:0" \
            --wrap \
            <<< "${instructions}"
    elif command -v zenity >/dev/null 2>&1; then
        local instructions
        instructions=$(cat <<'EOF'
Manual Uninstallation Guide for Sleep Warning System

This guide provides step-by-step instructions for manually removing the Sleep Warning System from your system.

STEP 1: Stop and Disable Timer
Run these commands:
  systemctl --user stop sleep-warning.timer
  systemctl --user disable sleep-warning.timer

STEP 2: Remove Systemd Files
Remove these files:
  ~/.config/systemd/user/sleep-warning.service
  ~/.config/systemd/user/sleep-warning.timer

STEP 3: Remove Scripts
Remove these files/directories:
  ~/.local/bin/sleep-warning.sh
  ~/.local/bin/sleep-warning-configure
  ~/.local/bin/sleep-warning-manage
  ~/.local/lib/sleep-warning/ (entire directory)

STEP 4: Remove Configuration (Optional)
Remove configuration file:
  ~/.config/sleep-warning/sleep-warning.conf
  ~/.config/sleep-warning/warnings.log

STEP 5: Reload Systemd
Run this command:
  systemctl --user daemon-reload

After completing these steps, the Sleep Warning System will be completely removed from your system.
EOF
)
        zenity --text-info \
            --title="Manual Uninstallation Guide" \
            --width=700 \
            --height=600 \
            <<< "${instructions}"
    elif command -v kdialog >/dev/null 2>&1; then
        local instructions
        instructions=$(cat <<'EOF'
Manual Uninstallation Guide for Sleep Warning System

This guide provides step-by-step instructions for manually removing the Sleep Warning System from your system.

STEP 1: Stop and Disable Timer
Run these commands:
  systemctl --user stop sleep-warning.timer
  systemctl --user disable sleep-warning.timer

STEP 2: Remove Systemd Files
Remove these files:
  ~/.config/systemd/user/sleep-warning.service
  ~/.config/systemd/user/sleep-warning.timer

STEP 3: Remove Scripts
Remove these files/directories:
  ~/.local/bin/sleep-warning.sh
  ~/.local/bin/sleep-warning-configure
  ~/.local/bin/sleep-warning-manage
  ~/.local/lib/sleep-warning/ (entire directory)

STEP 4: Remove Configuration (Optional)
Remove configuration file:
  ~/.config/sleep-warning/sleep-warning.conf
  ~/.config/sleep-warning/warnings.log

STEP 5: Reload Systemd
Run this command:
  systemctl --user daemon-reload

After completing these steps, the Sleep Warning System will be completely removed from your system.
EOF
)
        kdialog --textbox /dev/stdin 700 600 <<< "${instructions}"
    else
        # Fallback to text mode
        show_text_instructions
    fi
}

# Function to show instructions in text mode
show_text_instructions() {
    echo ""
    print_header "═══════════════════════════════════════════════════════════"
    print_header "  Manual Uninstallation Guide - Sleep Warning System"
    print_header "═══════════════════════════════════════════════════════════"
    echo ""
    
    print_info "This guide provides step-by-step instructions for manually removing"
    print_info "the Sleep Warning System from your system."
    echo ""
    
    print_header "STEP 1: Stop and Disable Timer"
    print_step "Stop the systemd timer:"
    print_command "systemctl --user stop sleep-warning.timer"
    echo ""
    print_step "Disable the systemd timer:"
    print_command "systemctl --user disable sleep-warning.timer"
    echo ""
    
    print_header "STEP 2: Remove Systemd Files"
    print_step "Remove the service file:"
    print_command "rm -f ${SYSTEMD_USER_DIR}/sleep-warning.service"
    echo ""
    print_step "Remove the timer file:"
    print_command "rm -f ${SYSTEMD_USER_DIR}/sleep-warning.timer"
    echo ""
    
    print_header "STEP 3: Remove Scripts"
    print_step "Remove the main script:"
    print_command "rm -f ${INSTALL_DIR}/sleep-warning.sh"
    echo ""
    print_step "Remove the configuration wizard:"
    print_command "rm -f ${INSTALL_DIR}/sleep-warning-configure"
    echo ""
    print_step "Remove the management script:"
    print_command "rm -f ${INSTALL_DIR}/sleep-warning-manage"
    echo ""
    print_step "Remove the library directory:"
    print_command "rm -rf ${LIB_DIR}"
    echo ""
    
    print_header "STEP 4: Remove Configuration (Optional)"
    print_warning "This step is optional. You can keep your configuration file if you"
    print_warning "plan to reinstall later."
    echo ""
    print_step "Remove the configuration file:"
    print_command "rm -f ${CONFIG_DIR}/sleep-warning.conf"
    echo ""
    print_step "Remove the log file:"
    print_command "rm -f ${CONFIG_DIR}/warnings.log"
    echo ""
    print_step "Remove the config directory (if empty):"
    print_command "rmdir ${CONFIG_DIR} 2>/dev/null || true"
    echo ""
    
    print_header "STEP 5: Reload Systemd"
    print_step "Reload the systemd user daemon:"
    print_command "systemctl --user daemon-reload"
    echo ""
    
    print_header "Verification"
    print_step "Verify removal by checking if files still exist:"
    print_command "ls -la ${INSTALL_DIR}/sleep-warning* 2>/dev/null || echo 'Scripts removed'"
    print_command "ls -la ${SYSTEMD_USER_DIR}/sleep-warning* 2>/dev/null || echo 'Systemd files removed'"
    print_command "ls -la ${LIB_DIR} 2>/dev/null || echo 'Library directory removed'"
    echo ""
    
    print_header "═══════════════════════════════════════════════════════════"
    print_info "After completing these steps, the Sleep Warning System will be"
    print_info "completely removed from your system."
    print_header "═══════════════════════════════════════════════════════════"
    echo ""
}

# Main function
main() {
    # Check if GUI is available
    if [ -n "${DISPLAY}" ] && (command -v yad >/dev/null 2>&1 || \
                               command -v zenity >/dev/null 2>&1 || \
                               command -v kdialog >/dev/null 2>&1); then
        show_gui_instructions
    else
        show_text_instructions
    fi
}

# Run main function
main "$@"
