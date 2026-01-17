### Phase 3: Installation and Deployment

#### Checklist 3.1: Create Automated Installation Script
- [x] Create `install.sh` script with shebang (`#!/bin/bash`) - IMPLEMENTED: Script created with proper shebang
- [x] Add script header comments explaining purpose and usage - IMPLEMENTED: Comprehensive header with usage examples
- [x] Implement distribution detection (Debian/Ubuntu, Fedora/RHEL, Arch/SteamOS, openSUSE, etc.) - IMPLEMENTED: Detects distribution via /etc/os-release
- [x] Implement package manager detection (apt, dnf/yum, pacman, zypper, apk) - IMPLEMENTED: Detects apt, dnf, yum, pacman, zypper, apk
- [x] Add function to check if command exists (`command -v`) - IMPLEMENTED: command_exists() function
- [x] Add function to check for required dependencies (systemd, bash, zenity) - IMPLEMENTED: check_dependencies() function
- [x] Add function to install zenity based on detected package manager - IMPLEMENTED: install_dependencies() function with package manager support
- [x] Add function to create necessary directories (`~/.local/bin`, `~/.config/sleep-warning`, `~/.config/systemd/user`) - IMPLEMENTED: create_directories() function
- [x] Add function to copy script to `~/.local/bin/sleep-warning.sh` - IMPLEMENTED: install_files() function
- [x] Add function to copy default config file to `~/.config/sleep-warning/sleep-warning.conf` (only if not exists) - IMPLEMENTED: Preserves existing config
- [x] Add function to copy systemd service file to `~/.config/systemd/user/sleep-warning.service` - IMPLEMENTED: install_files() function
- [x] Add function to copy systemd timer file to `~/.config/systemd/user/sleep-warning.timer` - IMPLEMENTED: generate_timer_file() function reads CHECK_INTERVAL from config and generates timer with correct OnCalendar value
- [x] Add function to copy configure.sh to `~/.local/bin/sleep-warning-configure` (or similar accessible name) - IMPLEMENTED: Copies as sleep-warning-configure
- [x] Add function to copy manage.sh to `~/.local/bin/sleep-warning-manage` (or similar accessible name) - IMPLEMENTED: Copies as sleep-warning-manage
- [x] Add function to set executable permissions on all scripts (`chmod +x`) - IMPLEMENTED: Sets permissions on all scripts
- [x] Add function to reload systemd user daemon - IMPLEMENTED: reload_systemd() function
- [x] Add function to enable and start systemd timer - IMPLEMENTED: enable_timer() function
- [x] Add function to verify installation (check timer status) - IMPLEMENTED: verify_installation() function
- [x] Add error handling for each step (exit on failure with clear message) - IMPLEMENTED: set -e and error checking throughout
- [x] Add colored output for success/error messages (optional, with fallback for non-color terminals) - IMPLEMENTED: Color support with fallback
- [x] Add confirmation prompt before installing dependencies (with --yes flag to skip) - IMPLEMENTED: --yes flag support
- [x] Add check to prevent re-installation over existing installation (with --force flag option) - IMPLEMENTED: check_existing_installation() with --force support
- [x] Add summary output showing what was installed and next steps - IMPLEMENTED: print_summary() function
- [x] Make install.sh executable (`chmod +x install.sh`) - IMPLEMENTED: Script is executable
- [ ] Test installation script on clean system - PENDING: Requires testing
- [ ] Test installation script with missing dependencies - PENDING: Requires testing
- [ ] Test installation script with existing installation - PENDING: Requires testing
- [ ] Test installation script on different distributions (if possible) - PENDING: Requires testing

#### Checklist 3.2: Create Uninstall Script
- [x] Create `uninstall.sh` script with shebang (`#!/bin/bash`) - IMPLEMENTED: Script created with proper shebang
- [x] Add script header comments explaining purpose and usage - IMPLEMENTED: Comprehensive header with usage examples
- [x] Add function to stop systemd timer - IMPLEMENTED: stop_timer() function
- [x] Add function to disable systemd timer - IMPLEMENTED: stop_timer() function handles both stop and disable
- [x] Add function to remove systemd service and timer files - IMPLEMENTED: remove_systemd_files() function
- [x] Add function to remove script from `~/.local/bin/` - IMPLEMENTED: remove_scripts() function
- [x] Add function to remove configure.sh from `~/.local/bin/` - IMPLEMENTED: remove_scripts() function removes all scripts
- [x] Add function to remove manage.sh from `~/.local/bin/` - IMPLEMENTED: remove_scripts() function removes all scripts
- [x] Add option to remove configuration file (with confirmation prompt) - IMPLEMENTED: remove_config() function with --remove-config flag
- [x] Add function to reload systemd user daemon after cleanup - IMPLEMENTED: reload_systemd() function
- [x] Add verification that files were removed - IMPLEMENTED: verify_removal() function
- [x] Add error handling for missing files (should not error, just skip) - IMPLEMENTED: Graceful handling with checks
- [x] Add summary output showing what was removed - IMPLEMENTED: print_summary() function
- [x] Make uninstall.sh executable (`chmod +x uninstall.sh`) - IMPLEMENTED: Script is executable
- [ ] Test uninstall script thoroughly - PENDING: Requires testing

#### Checklist 3.3: Manual Installation Instructions
- [ ] Create installation instructions document (INSTALLATION.md)
- [ ] Document system requirements and compatibility
- [ ] Document required dependencies (zenity, systemd, bash)
- [ ] Include automated installation instructions (using install.sh)
- [ ] Include manual installation steps for advanced users
- [ ] Include installation commands for multiple distributions (Debian/Ubuntu, Fedora, Arch, openSUSE)
- [ ] Document file placement locations
- [ ] Document configuration file location and format
- [ ] Create commands to enable and start the timer (for manual installation)
- [ ] Add verification steps
- [ ] Include instructions for customizing restricted hours
- [ ] Add troubleshooting section for common distribution-specific issues
- [ ] Document uninstall process (both automated and manual)

#### Checklist 3.4: Enable and Start Service (Manual Steps)
- [ ] Document reload systemd user daemon command (`systemctl --user daemon-reload`)
- [ ] Document enable timer command (`systemctl --user enable sleep-warning.timer`)
- [ ] Document start timer command (`systemctl --user start sleep-warning.timer`)
- [ ] Document verification command (`systemctl --user status sleep-warning.timer`)
- [ ] Document list timers command (`systemctl --user list-timers`)
