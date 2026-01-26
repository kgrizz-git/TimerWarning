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
# - sudo (only required if dependencies need to be installed - if all dependencies
#   are already installed, sudo is not needed)
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
LIB_DIR="${HOME}/.local/lib/sleep-warning"
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

# Function to display disclaimer and get user confirmation
show_disclaimer() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT - PLEASE READ CAREFULLY${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "This software is provided \"AS IS\", without warranty of any kind, express or"
    echo "implied, including but not limited to the warranties of merchantability,"
    echo "fitness for a particular purpose and noninfringement."
    echo ""
    echo "By installing this software, you acknowledge that:"
    echo "  • You use this software at your own risk"
    echo "  • The developers are not responsible for any errors, data loss, or system"
    echo "    instability resulting from the use of this software"
    echo "  • This software modifies systemd user services and system configuration"
    echo "  • Compatibility cannot be guaranteed for all systems"
    echo "  • Support is provided on a best-effort basis"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ "$AUTO_YES" = false ]; then
        echo -n "Do you agree to these terms and wish to continue? [y/N]: "
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                echo ""
                print_info "Continuing with installation..."
                ;;
            *)
                echo ""
                print_info "Installation cancelled by user"
                exit 0
                ;;
        esac
    else
        print_info "Auto-confirm mode: Proceeding with installation (--yes flag used)"
    fi
    echo ""
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
        PKG_INSTALL="apk add --non-interactive"
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
    
    # Check for at least one dialog tool (zenity is installed automatically if none found)
    # The system supports yad, zenity, or kdialog, but zenity is the default fallback
    if ! command_exists zenity; then
        missing_deps+=("zenity")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        return 1  # Dependencies missing
    fi
    
    return 0  # All dependencies present
}

# Function to check for optional dependencies
# Returns space-separated list of missing optional tools
check_optional_dependencies() {
    local missing_optional=()
    
    # Check yad (optional but recommended)
    if ! command_exists yad; then
        missing_optional+=("yad")
    fi
    
    # Check window management tools (optional but recommended)
    # We need at least one of wmctrl or xdotool
    if ! command_exists wmctrl && ! command_exists xdotool; then
        # Prefer wmctrl, but xdotool is also fine
        missing_optional+=("wmctrl")
    fi
    
    # Return as space-separated string
    if [ ${#missing_optional[@]} -gt 0 ]; then
        echo "${missing_optional[*]}"
    fi
}

# Function to check if sudo password is cached (non-interactive check)
check_sudo_access() {
    # Use sudo -n (non-interactive) to check if password is cached
    if sudo -n true 2>/dev/null; then
        return 0  # Sudo access available without password
    else
        return 1  # Sudo requires password
    fi
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
    else
        # In auto-yes mode, check if sudo password is cached
        if ! check_sudo_access; then
            print_warning "Sudo password is required for package installation"
            print_warning "Please ensure sudo password is cached (run 'sudo -v' first) or install dependencies manually"
            print_warning "For fully non-interactive installation, configure passwordless sudo or cache password first"
        fi
    fi
    
    print_info "Installing dependencies using $PKG_MANAGER..."
    
    # Set DEBIAN_FRONTEND=noninteractive for apt-based systems to prevent interactive prompts
    if [ "$PKG_MANAGER" = "apt" ]; then
        # Use DEBIAN_FRONTEND=noninteractive to prevent interactive prompts
        if ! DEBIAN_FRONTEND=noninteractive sudo $PKG_INSTALL "${deps[@]}"; then
            print_error "Failed to install dependencies"
            exit 1
        fi
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        # pacman needs sudo
        if ! sudo $PKG_INSTALL "${deps[@]}"; then
            print_error "Failed to install dependencies"
            exit 1
        fi
    else
        # Other package managers (dnf, yum, zypper, apk)
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

# Function to migrate config file to subdirectory (Enhancement #18)
# Migrates config from ~/.config/sleep-warning/sleep-warning.conf to
# ~/.config/sleep-warning/config/sleep-warning.conf
# Returns: 0 on success, 1 on error
migrate_config_to_subdirectory() {
    local old_config="${CONFIG_DIR}/sleep-warning.conf"
    local new_config="${CONFIG_DIR}/config/sleep-warning.conf"
    local backup_config="${CONFIG_DIR}/sleep-warning.conf.backup"
    
    # Check if old config exists
    if [ ! -f "$old_config" ]; then
        # No old config to migrate
        return 0
    fi
    
    # Check if new config already exists
    if [ -f "$new_config" ]; then
        # New config already exists, nothing to migrate
        print_info "Config file already in new location, skipping migration"
        return 0
    fi
    
    # Migration needed: old exists and new doesn't
    print_info "Migrating config file to subdirectory (Enhancement #18)..."
    
    # Create backup of old config
    if ! cp "$old_config" "$backup_config" 2>/dev/null; then
        print_warning "Failed to create backup of old config file"
        print_warning "Migration will continue, but backup was not created"
    else
        print_success "Backup created: $backup_config"
    fi
    
    # Ensure config subdirectory exists (should already exist from create_directories, but be safe)
    if ! mkdir -p "${CONFIG_DIR}/config" 2>/dev/null; then
        print_error "Failed to create config subdirectory"
        return 1
    fi
    
    # Copy old config to new location
    if ! cp "$old_config" "$new_config" 2>/dev/null; then
        print_error "Failed to copy config file to new location"
        return 1
    fi
    
    # Verify copy succeeded
    local verification_failed=false
    
    # Compare file sizes
    if command -v stat >/dev/null 2>&1; then
        local old_size new_size
        old_size=$(stat -c%s "$old_config" 2>/dev/null || stat -f '%z' "$old_config" 2>/dev/null)
        new_size=$(stat -c%s "$new_config" 2>/dev/null || stat -f '%z' "$new_config" 2>/dev/null)
        
        if [ -z "$old_size" ] || [ -z "$new_size" ] || [ "$old_size" -ne "$new_size" ]; then
            print_error "File size verification failed (old: ${old_size}, new: ${new_size})"
            verification_failed=true
        fi
    fi
    
    # Compare checksums if available (prefer sha256sum, fallback to md5sum)
    if [ "$verification_failed" = false ]; then
        if command -v sha256sum >/dev/null 2>&1; then
            local old_checksum new_checksum
            old_checksum=$(sha256sum "$old_config" 2>/dev/null | cut -d' ' -f1)
            new_checksum=$(sha256sum "$new_config" 2>/dev/null | cut -d' ' -f1)
            
            if [ -z "$old_checksum" ] || [ -z "$new_checksum" ] || [ "$old_checksum" != "$new_checksum" ]; then
                print_error "SHA256 checksum verification failed"
                verification_failed=true
            fi
        elif command -v md5sum >/dev/null 2>&1; then
            local old_checksum new_checksum
            old_checksum=$(md5sum "$old_config" 2>/dev/null | cut -d' ' -f1)
            new_checksum=$(md5sum "$new_config" 2>/dev/null | cut -d' ' -f1)
            
            if [ -z "$old_checksum" ] || [ -z "$new_checksum" ] || [ "$old_checksum" != "$new_checksum" ]; then
                print_error "MD5 checksum verification failed"
                verification_failed=true
            fi
        fi
    fi
    
    # Verify new file is readable
    if [ ! -r "$new_config" ]; then
        print_error "New config file is not readable"
        verification_failed=true
    fi
    
    # If verification failed, don't remove old config
    if [ "$verification_failed" = true ]; then
        print_error "Config file migration verification failed"
        print_warning "Old config file preserved at: $old_config"
        print_warning "New config file may be incomplete at: $new_config"
        # Remove the potentially incomplete new config
        rm -f "$new_config" 2>/dev/null
        return 1
    fi
    
    # Verification succeeded - remove old config
    if ! rm -f "$old_config" 2>/dev/null; then
        print_warning "Failed to remove old config file (migration succeeded but cleanup failed)"
        print_warning "Old config file still exists at: $old_config"
        print_warning "You can safely remove it manually"
        # Migration succeeded, just cleanup failed
        print_success "Config file migrated successfully (old file cleanup failed)"
        return 0
    fi
    
    print_success "Config file migrated successfully from $old_config to $new_config"
    if [ -f "$backup_config" ]; then
        print_info "Backup available at: $backup_config"
    fi
    
    return 0
}

# Function to create directories
create_directories() {
    print_info "Creating necessary directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "${CONFIG_DIR}/config"  # Create config subdirectory for Enhancement #18
    mkdir -p "$SYSTEMD_USER_DIR"
    
    print_success "Directories created"
    
    # Migration: Move config file to subdirectory if old location exists (Enhancement #18)
    migrate_config_to_subdirectory
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
    local new_config_file="$CONFIG_DIR/config/sleep-warning.conf"
    local old_config_file="$CONFIG_DIR/sleep-warning.conf"
    local config_file=""
    local default_interval=10

    # Prefer the new config location (Enhancement #18), but fall back to old location
    # for safety/backward-compatibility during upgrades or partial migrations.
    if [ -f "$new_config_file" ]; then
        config_file="$new_config_file"
    elif [ -f "$old_config_file" ]; then
        config_file="$old_config_file"
    fi

    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        local interval
        interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "$config_file" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        
        if [ -n "$interval" ] && [[ "$interval" =~ ^[0-9]+$ ]] && [ "$interval" -ge 1 ] && [ "$interval" -le 60 ]; then
            echo "$interval"
            return 0
        fi
    fi
    
    echo "$default_interval"
}

# Function to configure service for detected system mode (Enhancement #4)
configure_service_mode() {
    # Source service configuration module if available
    local service_config_file="${SCRIPT_DIR}/lib/service-config.sh"
    local display_detection_file="${SCRIPT_DIR}/lib/display-detection.sh"
    
    if [ ! -f "${service_config_file}" ] || [ ! -f "${display_detection_file}" ]; then
        print_info "Service configuration modules not found, skipping mode-specific configuration"
        return 0
    fi
    
    # Source required modules
    source "${display_detection_file}"
    source "${service_config_file}"
    
    # Detect system mode
    print_info "Detecting system mode (Desktop Mode vs Gaming Mode)..."
    local detected_mode
    detected_mode=$(detect_system_mode)
    
    if [ "${detected_mode}" = "unknown" ]; then
        print_warning "Could not detect system mode, service will use default configuration"
        print_warning "You can manually configure the service later using: sleep-warning-configure"
        return 0
    fi
    
    # Configure service for detected mode
    print_info "Configuring service for ${detected_mode} mode..."
    if configure_service_for_mode "${detected_mode}"; then
        print_success "Service configured for ${detected_mode} mode"
    else
        print_warning "Failed to configure service for ${detected_mode} mode"
        print_warning "Service will use default configuration (should still work)"
    fi
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
    
    # Create library directory
    mkdir -p "$LIB_DIR"
    print_success "Library directory created"
    
    # Copy library modules
    if [ -d "$SCRIPT_DIR/lib" ]; then
        cp "$SCRIPT_DIR/lib"/*.sh "$LIB_DIR/"
        chmod +x "$LIB_DIR"/*.sh
        print_success "Library modules installed (7 modules)"
    else
        print_error "Library directory not found"
        exit 1
    fi
    
    # Copy main script and update library paths to use installed location
    sed "s|LIB_DIR=\"\${SCRIPT_DIR}/lib\"|LIB_DIR=\"${LIB_DIR}\"|" "$SCRIPT_DIR/sleep-warning.sh" > "$INSTALL_DIR/sleep-warning.sh"
    chmod +x "$INSTALL_DIR/sleep-warning.sh"
    print_success "Main script installed"
    
    # Copy configure script and update library paths to use installed location
    if [ -f "$SCRIPT_DIR/configure.sh" ]; then
        sed "s|LIB_DIR=\"\${SCRIPT_DIR}/lib\"|LIB_DIR=\"${LIB_DIR}\"|" "$SCRIPT_DIR/configure.sh" > "$INSTALL_DIR/sleep-warning-configure"
        chmod +x "$INSTALL_DIR/sleep-warning-configure"
        print_success "Configuration wizard installed"
    fi
    
    # Copy manage script
    if [ -f "$SCRIPT_DIR/manage.sh" ]; then
        cp "$SCRIPT_DIR/manage.sh" "$INSTALL_DIR/sleep-warning-manage"
        chmod +x "$INSTALL_DIR/sleep-warning-manage"
        
        # Install manual uninstall guide script (Enhancement #26)
        if [ -f "$SCRIPT_DIR/manual-uninstall-guide.sh" ]; then
            cp "$SCRIPT_DIR/manual-uninstall-guide.sh" "$INSTALL_DIR/manual-uninstall-guide"
            chmod +x "$INSTALL_DIR/manual-uninstall-guide"
            print_success "Manual uninstall guide installed"
        fi
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
    local new_config="${CONFIG_DIR}/config/sleep-warning.conf"
    local old_config="${CONFIG_DIR}/sleep-warning.conf"

    # If an old-location config exists but the new one does not, try migration again
    # (should already have run in create_directories(), but be defensive).
    if [ -f "${old_config}" ] && [ ! -f "${new_config}" ]; then
        print_info "Existing config found in old location; attempting migration..."
        migrate_config_to_subdirectory || true
    fi

    if [ ! -f "${new_config}" ]; then
        if [ -f "$SCRIPT_DIR/sleep-warning.conf" ]; then
            # Install default config into the NEW location (Enhancement #18)
            cp "$SCRIPT_DIR/sleep-warning.conf" "${new_config}"
            print_success "Default configuration file installed"
        fi
    else
        print_info "Configuration file already exists, preserving existing configuration"
    fi
    
    # Copy service file
    cp "$SCRIPT_DIR/sleep-warning.service" "$SYSTEMD_USER_DIR/sleep-warning.service"
    print_success "Systemd service file installed"
    
    # Configure service for detected system mode (Enhancement #4)
    configure_service_mode
    
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
    echo "  • Configuration: ${CONFIG_DIR}/config/sleep-warning.conf"
    echo "  • Systemd service: $SYSTEMD_USER_DIR/sleep-warning.service"
    echo "  • Systemd timer: $SYSTEMD_USER_DIR/sleep-warning.timer"
    echo ""
    echo "Next steps:"
    echo "  1. Configure restricted hours (recommended):"
    echo -e "     ${BLUE}sleep-warning-configure${NC}"
    echo "     This will help you set up your restricted hours schedule."
    echo -e "     ${YELLOW}Note: If the command is not found, restart your terminal or run:${NC}"
    echo -e "     ${YELLOW}     source ~/.bashrc${NC}"
    echo ""
    echo "  2. Check system status:"
    echo -e "     ${BLUE}sleep-warning-status${NC}"
    echo ""
    echo "  3. Manage the system (start/stop/enable/disable):"
    echo -e "     ${BLUE}sleep-warning-manage${NC}"
    echo -e "     ${BLUE}manual-uninstall-guide${NC} (manual uninstallation instructions)"
    echo ""
    echo "  4. View logs:"
    echo -e "     ${BLUE}journalctl --user -u sleep-warning.service${NC}"
    echo ""
    echo "  5. To uninstall later:"
    echo -e "     ${BLUE}sleep-warning-uninstall${NC}"
    echo ""
    echo "The timer is now active and will check for restricted hours every $(get_check_interval) minutes."
    echo ""
    echo "Support Development:"
    echo "  If you find this software useful, consider supporting future development:"
    echo -e "  ${BLUE}https://www.paypal.com/donate/?business=FMVBCJ2CT7L7S&no_recurring=0&item_name=Making+software+I+hope+people+find+useful.+Thank+you+for+supporting+future+development.&currency_code=USD${NC}"
    echo "  (Donations are optional but greatly appreciated)"
    echo ""
}

# Main installation function
main() {
    echo -e "${BLUE}Sleep Warning System - Installation${NC}"
    
    # Show disclaimer and get user confirmation
    show_disclaimer
    
    # Detect distribution and package manager
    print_info "Detecting Linux distribution..."
    detect_distribution
    detect_package_manager
    print_success "Detected: $DISTRO_ID (using $PKG_MANAGER)"
    
    # Check for existing installation
    check_existing_installation
    
    # Check required dependencies
    print_info "Checking required dependencies..."
    if ! check_dependencies; then
        install_dependencies zenity
    else
        print_success "All required dependencies are installed"
    fi
    
    # Check optional dependencies
    print_info "Checking optional dependencies..."
    local missing_optional
    missing_optional=$(check_optional_dependencies)
    
    if [ -n "$missing_optional" ]; then
        print_info "Optional tools that enhance functionality:"
        for tool in $missing_optional; do
            case "$tool" in
                yad)
                    echo "  - yad: Enhanced dialog tool with better positioning and Wayland support"
                    ;;
                wmctrl)
                    echo "  - wmctrl or xdotool: Window management tools for stay-on-top and immovable windows"
                    ;;
            esac
        done
        
        if [ "$AUTO_YES" = false ]; then
            # Check if we're in a terminal - if not, skip optional installs
            if [ -t 0 ] && [ -t 1 ]; then
                echo -n "Install optional tools for enhanced features? (y/N): "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    # Install each missing optional tool
                    for tool in $missing_optional; do
                        install_dependencies "$tool"
                    done
                else
                    print_info "Skipping optional tools. You can install them later:"
                    for tool in $missing_optional; do
                        case "$tool" in
                            yad)
                                echo "  - yad: sudo $PKG_INSTALL yad"
                                ;;
                            wmctrl)
                                echo "  - wmctrl: sudo $PKG_INSTALL wmctrl"
                                ;;
                        esac
                    done
                fi
            else
                print_info "Not in a terminal - skipping optional tool installation"
                print_info "You can install them manually later if desired"
            fi
        else
            # Auto-yes mode: install optional tools automatically
            for tool in $missing_optional; do
                install_dependencies "$tool"
            done
        fi
    else
        print_success "All optional dependencies are installed"
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
