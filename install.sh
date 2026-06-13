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
# shellcheck source=lib/_bootstrap-bash4.sh
source "${SCRIPT_DIR}/lib/_bootstrap-bash4.sh"
_bootstrap_bash4 "${BASH_SOURCE[0]}" "$@"

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
RE_ENABLE_SCHEDULER=""   # "" = ask, "true" = re-enable, "false" = leave disabled

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        --yes)
            AUTO_YES=true
            ;;
        --force)
            FORCE_INSTALL=true
            ;;
        --re-enable)
            # Phase 3.4: explicit consent to re-enable a previously disabled scheduler
            RE_ENABLE_SCHEDULER="true"
            ;;
        --no-re-enable)
            # Phase 3.4: explicit decline — leave scheduler disabled on reinstall
            RE_ENABLE_SCHEDULER="false"
            ;;
        -h|--help)
            echo "Usage: $0 [--yes] [--force] [--re-enable|--no-re-enable]"
            echo "  --yes            Auto-confirm dependency installation"
            echo "  --force          Reinstall programs and scheduler files (existing"
            echo "                   sleep-warning.conf settings are preserved)"
            echo "  --re-enable      On reinstall: re-enable scheduler even if it was disabled"
            echo "  --no-re-enable   On reinstall: do not re-enable scheduler if it was disabled"
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

# Explain whether install/--force will touch the user's configuration file.
install_report_config_handling() {
    local new_config="${CONFIG_DIR}/config/sleep-warning.conf"
    local legacy_config="${CONFIG_DIR}/sleep-warning.conf"

    if [ -f "${new_config}" ]; then
        print_info "Configuration: keeping your existing settings at ${new_config}"
        print_info "  (--force reinstalls programs and scheduler files; it does not reset this file.)"
    elif [ -f "${legacy_config}" ]; then
        print_info "Configuration: keeping your existing settings at ${legacy_config}"
        print_info "  (will migrate to config/sleep-warning.conf if needed; settings are not reset.)"
    else
        print_info "Configuration: none found yet — a default sleep-warning.conf will be installed"
    fi
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
    echo "  - You use this software at your own risk"
    echo "  - The developers are not responsible for any errors, data loss, or system"
    echo "    instability resulting from the use of this software"
    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        echo "  - This software installs a LaunchAgent and configuration under your home directory"
    else
        echo "  - This software modifies systemd user services and system configuration"
    fi
    echo "  - Compatibility cannot be guaranteed for all systems"
    echo "  - Support is provided on a best-effort basis"
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

# Migrate legacy flat config path to config/ subdirectory (shared Linux + macOS).
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

main() {
    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/lib/install-darwin.sh"
        main_darwin "$@"
    else
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/lib/install-linux.sh"
        main_linux "$@"
    fi
}

# Run main function
main "$@"
