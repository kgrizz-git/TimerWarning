#!/bin/bash

###############################################################################
# Sleep Warning System - Installation Script
#
# This script automates the installation of the Sleep Warning System.
# It detects the Linux distribution, installs dependencies, copies files
# to appropriate locations, and sets up the systemd timer.
#
# IMPORTANT: Both installation and configuration steps should be completed:
#   1. Install (this script): Sets up the system and starts the timer
#   2. Configure (sleep-warning-configure): Customizes restricted hours
#
# Recommended order: Install first, then configure. However, both scripts
# can be run in any order - if you configure first, your settings will be
# preserved during installation.
#
# Requirements:
# - bash
# - systemd (for user services)
# - sudo (for installing dependencies)
#
# Usage:
#   ./install.sh              # Interactive installation
#   ./install.sh --yes        # Auto-confirm dependency installation
#   ./install.sh --force      # Force reinstallation over existing installation
#
# Output:
# - Installs all necessary files
# - Sets up systemd timer
# - Provides installation summary and next steps
###############################################################################

set -e  # Exit on error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/sleep-warning"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

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
AUTO_YES=false
FORCE_INSTALL=false

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        --yes)
            AUTO_YES=true
            ;;
        --force)
            FORCE_INSTALL=true
            ;;
        -h|--help)
            echo "Usage: $0 [--yes] [--force]"
            echo "  --yes    Auto-confirm dependency installation"
            echo "  --force  Force reinstallation over existing installation"
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect Linux distribution
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID}"
        DISTRO_ID_LIKE="${ID_LIKE}"
    else
        print_error "Cannot detect Linux distribution (no /etc/os-release)"
        exit 1
    fi
}

# Function to detect package manager
detect_package_manager() {
    if command_exists apt-get; then
        PKG_MANAGER="apt"
        PKG_INSTALL="apt-get install -y"
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
    elif command_exists yum; then
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
    elif command_exists pacman; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
    elif command_exists zypper; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="zypper install -y"
    elif command_exists apk; then
        PKG_MANAGER="apk"
        PKG_INSTALL="apk add"
    else
        print_error "Cannot detect package manager"
        exit 1
    fi
}

# Function to check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check systemd
    if ! command_exists systemctl; then
        print_error "systemd is required but not found"
        exit 1
    fi
    
    # Check bash
    if ! command_exists bash; then
        print_error "bash is required but not found"
        exit 1
    fi
    
    # Check zenity
    if ! command_exists zenity; then
        missing_deps+=("zenity")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        return 1  # Dependencies missing
    fi
    
    return 0  # All dependencies present
}

# Function to install dependencies
install_dependencies() {
    local deps=("$@")
    
    if [ ${#deps[@]} -eq 0 ]; then
        return 0
    fi
    
    print_info "The following dependencies need to be installed: ${deps[*]}"
    
    if [ "$AUTO_YES" = false ]; then
        # Check if we're in a terminal - if not, we can't prompt interactively
        if [ ! -t 0 ] || [ ! -t 1 ]; then
            print_error "Cannot prompt for input: not running in a terminal"
            print_error "Please run this script from a terminal, or use: $0 --yes"
            exit 1
        fi
        
        echo -n "Install these dependencies now? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled"
            exit 1
        fi
    fi
    
    print_info "Installing dependencies using $PKG_MANAGER..."
    
    if [ "$PKG_MANAGER" = "pacman" ]; then
        # pacman needs sudo
        if ! sudo $PKG_INSTALL "${deps[@]}"; then
            print_error "Failed to install dependencies"
            exit 1
        fi
    else
        # Other package managers
        if ! sudo $PKG_INSTALL "${deps[@]}"; then
            print_error "Failed to install dependencies"
            exit 1
        fi
    fi
    
    print_success "Dependencies installed successfully"
}

# Function to check if already installed
check_existing_installation() {
    local installed=false
    
    if [ -f "$INSTALL_DIR/sleep-warning.sh" ] || \
       [ -f "$SYSTEMD_USER_DIR/sleep-warning.service" ] || \
       [ -f "$SYSTEMD_USER_DIR/sleep-warning.timer" ]; then
        installed=true
    fi
    
    if [ "$installed" = true ] && [ "$FORCE_INSTALL" = false ]; then
        print_warning "Sleep Warning System appears to be already installed"
        echo "Use --force to reinstall over existing installation"
        exit 1
    fi
    
    if [ "$installed" = true ] && [ "$FORCE_INSTALL" = true ]; then
        print_warning "Force reinstalling over existing installation"
    fi
}

# Function to create directories
create_directories() {
    print_info "Creating necessary directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$SYSTEMD_USER_DIR"
    
    print_success "Directories created"
}

# Function to ensure ~/.local/bin is in PATH
ensure_path_setup() {
    local local_bin_path="$HOME/.local/bin"
    local bashrc="$HOME/.bashrc"
    local profile="$HOME/.profile"
    local path_export='export PATH="$HOME/.local/bin:$PATH"'
    
    # Check if already in PATH
    if echo "$PATH" | grep -q "$local_bin_path"; then
        print_info "~/.local/bin is already in PATH"
        return 0
    fi
    
    # Try to add to .bashrc first (most common)
    if [ -f "$bashrc" ]; then
        if ! grep -q '\.local/bin' "$bashrc" 2>/dev/null; then
            echo "" >> "$bashrc"
            echo "# Added by Sleep Warning System installer" >> "$bashrc"
            echo "$path_export" >> "$bashrc"
            print_success "Added ~/.local/bin to PATH in ~/.bashrc"
            return 0
        fi
    fi
    
    # Fallback to .profile if .bashrc doesn't exist or already has it
    if [ -f "$profile" ]; then
        if ! grep -q '\.local/bin' "$profile" 2>/dev/null; then
            echo "" >> "$profile"
            echo "# Added by Sleep Warning System installer" >> "$profile"
            echo "$path_export" >> "$profile"
            print_success "Added ~/.local/bin to PATH in ~/.profile"
            return 0
        fi
    fi
    
    # If neither file exists, create .bashrc
    if [ ! -f "$bashrc" ] && [ ! -f "$profile" ]; then
        echo "$path_export" >> "$bashrc"
        print_success "Created ~/.bashrc and added ~/.local/bin to PATH"
        return 0
    fi
    
    print_info "~/.local/bin PATH entry already exists in shell config"
}

# Function to read CHECK_INTERVAL from config file
get_check_interval() {
    local config_file="$CONFIG_DIR/sleep-warning.conf"
    local default_interval=10
    
    if [ -f "$config_file" ]; then
        local interval
        interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "$config_file" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        
        if [ -n "$interval" ] && [[ "$interval" =~ ^[0-9]+$ ]] && [ "$interval" -ge 1 ] && [ "$interval" -le 60 ]; then
            echo "$interval"
            return 0
        fi
    fi
    
    echo "$default_interval"
}

# Function to generate timer file with correct interval
generate_timer_file() {
    local interval
    interval=$(get_check_interval)
    
    local timer_file="$SYSTEMD_USER_DIR/sleep-warning.timer"
    
    cat > "$timer_file" <<EOF
[Unit]
Description=Sleep Warning System Timer - Triggers warning check every $interval minutes
Documentation=man:systemd.timer(5)
Requires=sleep-warning.service

[Timer]
# Run every $interval minutes
# Note: The actual interval can be configured via CHECK_INTERVAL in the config file.
# The configure.sh script will update this OnCalendar value when CHECK_INTERVAL is changed.
# Format: OnCalendar=*:0/N where N is the check interval in minutes
OnCalendar=*:0/$interval

# Start immediately if missed (e.g., after system boot or resume from suspend)
Persistent=true

# Timer accuracy (can be adjusted if needed)
# 1 minute accuracy means the timer may fire up to 1 minute early or late
AccuracySec=1min

[Install]
# Enable timer to start automatically on boot/login
WantedBy=timers.target
EOF
    
    print_success "Timer file generated with interval: $interval minutes"
}

# Function to install files
install_files() {
    print_info "Installing files..."
    
    # Copy main script
    cp "$SCRIPT_DIR/sleep-warning.sh" "$INSTALL_DIR/sleep-warning.sh"
    chmod +x "$INSTALL_DIR/sleep-warning.sh"
    print_success "Main script installed"
    
    # Copy configure script
    if [ -f "$SCRIPT_DIR/configure.sh" ]; then
        cp "$SCRIPT_DIR/configure.sh" "$INSTALL_DIR/sleep-warning-configure"
        chmod +x "$INSTALL_DIR/sleep-warning-configure"
        print_success "Configuration wizard installed"
    fi
    
    # Copy manage script
    if [ -f "$SCRIPT_DIR/manage.sh" ]; then
        cp "$SCRIPT_DIR/manage.sh" "$INSTALL_DIR/sleep-warning-manage"
        chmod +x "$INSTALL_DIR/sleep-warning-manage"
        print_success "Management script installed"
    fi
    
    # Copy status script
    if [ -f "$SCRIPT_DIR/status.sh" ]; then
        cp "$SCRIPT_DIR/status.sh" "$INSTALL_DIR/sleep-warning-status"
        chmod +x "$INSTALL_DIR/sleep-warning-status"
        print_success "Status script installed"
    fi
    
    # Copy uninstall script
    if [ -f "$SCRIPT_DIR/uninstall.sh" ]; then
        cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/sleep-warning-uninstall"
        chmod +x "$INSTALL_DIR/sleep-warning-uninstall"
        print_success "Uninstall script installed"
    fi
    
    # Copy config file (only if doesn't exist, to preserve user customizations)
    if [ ! -f "$CONFIG_DIR/sleep-warning.conf" ]; then
        if [ -f "$SCRIPT_DIR/sleep-warning.conf" ]; then
            cp "$SCRIPT_DIR/sleep-warning.conf" "$CONFIG_DIR/sleep-warning.conf"
            print_success "Default configuration file installed"
        fi
    else
        print_info "Configuration file already exists, preserving existing configuration"
    fi
    
    # Copy service file
    cp "$SCRIPT_DIR/sleep-warning.service" "$SYSTEMD_USER_DIR/sleep-warning.service"
    print_success "Systemd service file installed"
    
    # Generate timer file with correct interval
    generate_timer_file
    
    print_success "All files installed"
}

# Function to reload systemd
reload_systemd() {
    print_info "Reloading systemd user daemon..."
    
    if systemctl --user daemon-reload; then
        print_success "Systemd daemon reloaded"
    else
        print_error "Failed to reload systemd daemon"
        exit 1
    fi
}

# Function to enable and start timer
enable_timer() {
    print_info "Enabling and starting systemd timer..."
    
    if systemctl --user enable sleep-warning.timer; then
        print_success "Timer enabled"
    else
        print_error "Failed to enable timer"
        exit 1
    fi
    
    if systemctl --user start sleep-warning.timer; then
        print_success "Timer started"
    else
        print_error "Failed to start timer"
        exit 1
    fi
}

# Function to verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    if systemctl --user is-active --quiet sleep-warning.timer; then
        print_success "Timer is active"
    else
        print_warning "Timer is not active (may need to check status)"
    fi
    
    local next_trigger
    next_trigger=$(systemctl --user list-timers sleep-warning.timer --no-pager 2>/dev/null | grep sleep-warning.timer | awk '{print $1, $2, $3}')
    
    if [ -n "$next_trigger" ]; then
        print_success "Next trigger scheduled: $next_trigger"
    fi
}

# Function to print installation summary
print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Sleep Warning System Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Installed files:"
    echo "  • Main script: $INSTALL_DIR/sleep-warning.sh"
    echo "  • Configuration: $CONFIG_DIR/sleep-warning.conf"
    echo "  • Systemd service: $SYSTEMD_USER_DIR/sleep-warning.service"
    echo "  • Systemd timer: $SYSTEMD_USER_DIR/sleep-warning.timer"
    echo ""
    echo "Next steps:"
    echo "  1. Configure restricted hours (recommended):"
    echo "     ${BLUE}sleep-warning-configure${NC}"
    echo "     This will help you set up your restricted hours schedule."
    echo "     ${YELLOW}Note: If the command is not found, restart your terminal or run:${NC}"
    echo "     ${YELLOW}     source ~/.bashrc${NC}"
    echo ""
    echo "  2. Check system status:"
    echo "     ${BLUE}sleep-warning-status${NC}"
    echo ""
    echo "  3. Manage the system (start/stop/enable/disable):"
    echo "     ${BLUE}sleep-warning-manage${NC}"
    echo ""
    echo "  4. View logs:"
    echo "     ${BLUE}journalctl --user -u sleep-warning.service${NC}"
    echo ""
    echo "  5. To uninstall later:"
    echo "     ${BLUE}sleep-warning-uninstall${NC}"
    echo ""
    echo "The timer is now active and will check for restricted hours every $(get_check_interval) minutes."
    echo ""
}

# Main installation function
main() {
    echo -e "${BLUE}Sleep Warning System - Installation${NC}"
    echo ""
    
    # Detect distribution and package manager
    print_info "Detecting Linux distribution..."
    detect_distribution
    detect_package_manager
    print_success "Detected: $DISTRO_ID (using $PKG_MANAGER)"
    
    # Check for existing installation
    check_existing_installation
    
    # Check dependencies
    print_info "Checking dependencies..."
    if ! check_dependencies; then
        install_dependencies zenity
    else
        print_success "All dependencies are installed"
    fi
    
    # Create directories
    create_directories
    
    # Ensure ~/.local/bin is in PATH
    ensure_path_setup
    
    # Install files
    install_files
    
    # Reload systemd
    reload_systemd
    
    # Enable and start timer
    enable_timer
    
    # Verify installation
    verify_installation
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
