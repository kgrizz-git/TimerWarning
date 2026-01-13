# Sleep Warning System - Implementation Plan

## High-Level Description

This project implements a systemd-based monitoring system that displays interactive warning popups when the system is being used during configurable restricted hours. **The system is designed with maximum compatibility as a core principle**, working on any modern Linux distribution with systemd (including Steam OS in both Desktop Mode and Gaming Mode, Ubuntu, Debian, Fedora, Arch, and others). It uses a bash script combined with systemd timers to check the current time every 10 minutes and display modal warning dialogs if usage occurs during user-defined restricted hours.

**Compatibility Focus**: Special attention has been given to ensuring the system works reliably on SteamOS in Gaming Mode, which presents unique challenges including Wayland compositor (gamescope) display detection, full-screen game overlay compatibility, and systemd user service persistence across mode transitions. The implementation includes robust fallback mechanisms and multiple detection strategies to maximize compatibility across all supported environments.

**Default restricted hours** (easily configurable):
- **Weekdays (Monday-Friday)**: Midnight (00:00) to 6:00 AM
- **Weekends (Saturday-Sunday)**: 1:00 AM to 6:00 AM

The restricted hours for each day of the week are easily configurable through a simple configuration file, allowing users to customize the warning schedule to their needs. The popup dialogs are modal and require user interaction before they can be dismissed, ensuring the user is aware of the late-night usage. The system runs as a user service (not system-wide) to ensure proper display access and user context.

## Disclaimer

**IMPORTANT - PLEASE READ CAREFULLY**

This software is provided "AS IS", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.

**User Responsibility**:
- Users are responsible for backing up important data before installing or using this software
- Users are responsible for ensuring system stability and compatibility before installation
- Users acknowledge that they use this software at their own risk
- The developers are not responsible for any errors, data loss, system instability, or adverse effects resulting from the use of this software
- The developers are not responsible for any consequences of missed warnings or system failures
- Users should test the software in a safe environment before relying on it for important use cases

**System Modifications**:
- This software modifies systemd user services and system configuration
- Improper installation or configuration may affect system behavior
- Users should understand systemd services and Linux system administration before installing
- Uninstallation should be performed using the provided uninstall script

**Compatibility**:
- While extensive testing is planned, compatibility cannot be guaranteed for all systems
- Some features may not work on all Linux distributions or desktop environments
- SteamOS Gaming Mode compatibility is actively being developed but may have limitations
- Users should verify compatibility with their specific system before installation

**Support**:
- Support is provided on a best-effort basis
- No guarantee is made regarding response time or resolution of issues
- Users are encouraged to review logs and documentation before requesting support

By installing or using this software, you acknowledge that you have read, understood, and agree to this disclaimer. If you do not agree, do not install or use this software.

## Architecture Overview

The solution consists of eight main components:

1. **Configuration File** (`sleep-warning.conf`):
   - Simple text-based configuration file
   - Defines restricted hours for each day of the week
   - Easy to edit and modify without changing script code
   - Located in user's config directory for easy access

2. **Bash Script** (`sleep-warning.sh`): 
   - Reads configuration file to determine restricted hours
   - Checks current day of week and time
   - Determines if current usage falls within restricted hours
   - Displays modal popup using `zenity` (with fallbacks to `yad` and `kdialog`) if conditions are met
   - Handles display environment detection with multiple fallback strategies (X11 DISPLAY, Wayland WAYLAND_DISPLAY, loginctl session detection, gamescope detection)
   - Includes SteamOS Gaming Mode compatibility features

3. **Systemd Service** (`sleep-warning.service`):
   - Defines the service that executes the bash script
   - Runs as a user service (not root)
   - Handles environment variables for display access

4. **Systemd Timer** (`sleep-warning.timer`):
   - Triggers the service every 10 minutes
   - Uses systemd's calendar-based timer functionality
   - Automatically starts on boot/login

5. **Installation Script** (`install.sh`):
   - Automated installation script for easy setup
   - Detects Linux distribution and package manager
   - Checks and installs required dependencies
   - Copies files to correct locations
   - Sets proper permissions
   - Enables and starts the systemd timer
   - Provides clear success/error feedback

6. **Uninstall Script** (`uninstall.sh`):
   - Removes installed files
   - Stops and disables systemd timer
   - Provides cleanup confirmation

7. **Interactive Configuration Script** (`configure.sh`):
   - Interactive wizard that walks users through setting restricted hours
   - Uses zenity dialogs for user-friendly GUI interface
   - Prompts for restricted hours for each day of the week
   - Validates input and provides helpful examples
   - Updates configuration file with user selections
   - Can be run anytime after installation to modify settings

8. **Management/Help Script** (`manage.sh`):
   - Provides information and management options for the sleep warning system
   - Displays current service status (enabled/disabled, active/inactive)
   - Explains how to temporarily disable the service
   - Explains how to re-enable the service
   - Explains how to uninstall the system
   - Provides quick access to view configuration
   - Provides quick access to run configuration wizard
   - Shows service logs and troubleshooting information

## Implementation Plan

### Phase 1: Project Setup and Script Development

#### Checklist 1.1: Create Project Structure
- [x] Create project directory structure
- [x] Create `sleep-warning.sh` script file
- [x] Create configuration file (`sleep-warning.conf`)
- [ ] Create systemd service directory (`~/.config/systemd/user/`) - NOTE: This is created during installation (Phase 3), not Phase 1
- [x] Create systemd service file (`sleep-warning.service`)
- [x] Create systemd timer file (`sleep-warning.timer`)
- [x] Create `configure.sh` script file (interactive configuration wizard)
- [x] Create `manage.sh` script file (management and help interface)

#### Checklist 1.2: Implement Configuration System
- [x] Design configuration file format (simple key-value or day-based format) - Day-based format chosen
- [x] Create default configuration file with example values
- [x] Implement configuration file parsing in script
- [x] Add validation for configuration values (hour ranges, format)
- [x] Add fallback to default values if config file missing or invalid
- [x] Add configurable check interval (frequency) - IMPLEMENTED: CHECK_INTERVAL setting (1-60 minutes)
- [x] Add configurable popup size - IMPLEMENTED: POPUP_SIZE setting (small/medium/large or custom WIDTHxHEIGHT)
- [x] Add configurable popup position - IMPLEMENTED: POPUP_POSITION setting (center, corners, top/bottom-center)
- [x] Add configurable minimum display time - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME setting (0-300 seconds, prevents closing/minimizing)
- [ ] Document configuration file format and options - NOTE: Only documented in code comments, needs separate documentation file

#### Checklist 1.3: Develop Bash Script Core Logic
- [x] Get current day of week (0=Sunday, 6=Saturday)
- [x] Get current hour (0-23 format)
- [x] Load restricted hours from configuration file for current day
- [x] Implement time range check using configured hours
- [x] Add logic to determine if warning should be shown
- [x] Handle edge cases (midnight crossover, multiple ranges per day) - FIXED: Multiple ranges per day (comma-separated) now fully implemented. Parsing and validation support comma-separated ranges. Midnight crossover is handled (single range works across midnight boundary if start < end).

#### Checklist 1.4: Implement Display and Popup Functionality
- [x] Detect DISPLAY environment variable
- [x] Fallback to finding active user session display if DISPLAY not set
- [x] Add loginctl-based session detection as fallback
- [ ] Add Wayland display detection (WAYLAND_DISPLAY environment variable)
- [ ] Add gamescope-specific display detection for SteamOS Gaming Mode
- [ ] Add active window state detection (full-screen, exclusive full-screen, windowed, borderless)
- [ ] Add window state logging (log window state when warning is triggered)
- [ ] Implement window state detection for X11 (using xdotool/wmctrl)
- [ ] Implement window state detection for Wayland (using swaymsg or similar, if available)
- [ ] Add graceful fallback when window state detection tools unavailable
- [x] Implement zenity popup command with modal flag
- [x] Add fallback detection for alternative dialog tools (yad, kdialog) if zenity unavailable
- [x] Add appropriate warning message text
- [x] Ensure popup requires user interaction (modal)
- [x] Add error handling for zenity not being available
- [x] Add graceful handling for systems without GUI (log error, exit silently)
- [x] Implement configurable popup size - IMPLEMENTED: Reads POPUP_SIZE from config, supports small/medium/large/custom
- [x] Implement configurable popup position - IMPLEMENTED: Reads POPUP_POSITION from config, calculates geometry for yad
- [x] Use configured size in popup display - IMPLEMENTED: All dialog tools use configured dimensions
- [x] Use configured position in popup display - IMPLEMENTED: yad uses --geometry, zenity centers (position not supported)
- [x] Implement minimum display time enforcement - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME prevents closing/minimizing for configured duration
- [x] Add window manager tool detection - IMPLEMENTED: Checks for wmctrl/xdotool for window control
- [x] Add window unclosable functionality - IMPLEMENTED: Uses wmctrl/xdotool to make window sticky and prevent closing
- [x] Add auto-reopen if closed prematurely - IMPLEMENTED: Reopens popup with countdown if closed during minimum display time
- [x] Add countdown message in popup - IMPLEMENTED: Shows remaining time before popup can be closed
- [ ] Test popup behavior with full-screen applications - NOT TESTED: Requires actual testing with full-screen games/applications
- [ ] Test popup behavior in SteamOS Gaming Mode with no game running
- [ ] Test popup behavior in SteamOS Gaming Mode with windowed games
- [ ] Test popup behavior in SteamOS Gaming Mode with full-screen games
- [ ] Test display detection in SteamOS Gaming Mode (gamescope/Wayland)
- [ ] Test systemd user services persistence across Desktop Mode ↔ Gaming Mode transitions
- [ ] Test minimum display time enforcement - NOT TESTED: Requires testing with wmctrl/xdotool on X11 systems
- [ ] Test minimum display time on Wayland - NOT TESTED: Window manager tools don't work on Wayland, needs fallback testing
- [ ] Consider using window manager tools to force popup on top if needed - IMPLEMENTED: wmctrl/xdotool used for window control, yad has --on-top flag

#### Checklist 1.5: Add Script Robustness
- [x] Add shebang line (`#!/bin/bash`)
- [x] Add error handling for missing dependencies
- [x] Add logging capability (optional, to syslog or file) - Uses logger command if available
- [ ] Add file-based logging to `~/.config/sleep-warning/warnings.log` for user-accessible logs
- [ ] Log window state information (full-screen, exclusive, windowed, etc.) when warnings are triggered
- [ ] Log display environment information (X11/Wayland, display identifier) when warnings are triggered
- [ ] Log dialog tool used (zenity/yad/kdialog) for troubleshooting
- [ ] Log popup success/failure status
- [ ] Add log rotation or size limits to prevent log file from growing too large
- [x] Add script header comments explaining purpose
- [x] Make script executable (`chmod +x`)

#### Checklist 1.6: Create Interactive Configuration Script
- [x] Create `configure.sh` script with shebang (`#!/bin/bash`)
- [x] Add script header comments explaining purpose and usage
- [x] Implement GUI-based interactive wizard using zenity dialogs
- [x] Create welcome/information dialog explaining the configuration process
- [x] Implement day-by-day configuration prompts (Sunday through Saturday)
- [x] For each day, prompt for start hour (0-23)
- [x] For each day, prompt for end hour (0-23)
- [x] Add input validation (hours must be 0-23, start < end)
- [x] Add option to skip a day (no restrictions for that day)
- [x] Add option to use same settings for all weekdays
- [x] Add option to use same settings for both weekend days
- [x] Add prompt for check interval (frequency) configuration - IMPLEMENTED: Prompts for CHECK_INTERVAL (1-60 minutes)
- [x] Add prompt for popup size configuration - IMPLEMENTED: Prompts for POPUP_SIZE (small/medium/large)
- [x] Add prompt for popup position configuration - IMPLEMENTED: Prompts for POPUP_POSITION (center, corners, etc.)
- [x] Add prompt for minimum display time configuration - IMPLEMENTED: Prompts for POPUP_MIN_DISPLAY_TIME (0-300 seconds)
- [x] Display summary of configured hours before saving
- [x] Display summary including interval, size, and position - IMPLEMENTED: Summary shows all configuration options including minimum display time
- [x] Add confirmation dialog before writing to config file
- [x] Implement config file writing with proper format
- [x] Write check interval to config file - IMPLEMENTED: CHECK_INTERVAL saved to config
- [x] Write popup size to config file - IMPLEMENTED: POPUP_SIZE saved to config
- [x] Write popup position to config file - IMPLEMENTED: POPUP_POSITION saved to config
- [x] Write minimum display time to config file - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME saved to config
- [x] Preserve existing config file comments if present - FIXED: Script now extracts and preserves user comments from existing config file. Comments are preserved in a dedicated section (may change position but are not lost).
- [x] Add error handling for missing zenity (fallback to text prompts)
- [x] Add graceful handling for systems without GUI
- [ ] Test configuration script with various input scenarios - NOT TESTED: Requires actual testing with different inputs
- [x] Make configure.sh executable (`chmod +x configure.sh`)

#### Checklist 1.7: Create Management/Help Script
- [x] Create `manage.sh` script with shebang (`#!/bin/bash`)
- [x] Add script header comments explaining purpose and usage
- [x] Implement main menu using zenity (or text menu if GUI unavailable)
- [x] Add function to check if service is installed
- [x] Add function to display current service status (enabled/disabled, active/inactive)
- [x] Add function to display current timer status and next trigger time
- [x] Add function to show current configuration file contents
- [x] Add function to explain how to temporarily disable the service
- [x] Add function to explain how to re-enable the service
- [x] Add function to provide quick disable command (with confirmation)
- [x] Add function to provide quick enable command (with confirmation)
- [x] Add function to launch configuration wizard (`configure.sh`)
- [x] Add function to display service logs (using journalctl)
- [x] Add function to explain uninstall process
- [x] Add function to show file locations (config, script, systemd units)
- [x] Add function to display help/information about the system
- [x] Add error handling for missing dependencies
- [x] Add graceful handling for systems without GUI (text-based menu)
- [ ] Test management script thoroughly - NOT TESTED: Requires actual testing of all menu functions
- [x] Make manage.sh executable (`chmod +x manage.sh`)

### Phase 2: Systemd Integration

#### Checklist 2.1: Create Systemd Service File
- [ ] Define service unit with appropriate description
- [ ] Set Type=oneshot (runs once per trigger)
- [ ] Configure to run as user (not root)
- [ ] Set environment variables for display access
- [ ] Point ExecStart to script location
- [ ] Add appropriate user/group settings

#### Checklist 2.2: Create Systemd Timer File
- [ ] Define timer unit with appropriate description
- [ ] Set OnCalendar to trigger every 10 minutes (`*:0/10`)
- [ ] Configure to start on boot/login (WantedBy)
- [ ] Link timer to service file
- [ ] Set appropriate accuracy settings

#### Checklist 2.3: Test Systemd Integration
- [ ] Test service manually (`systemctl --user start sleep-warning.service`)
- [ ] Test timer activation (`systemctl --user start sleep-warning.timer`)
- [ ] Verify timer status (`systemctl --user status sleep-warning.timer`)
- [ ] Check timer list (`systemctl --user list-timers`)
- [ ] Verify service runs correctly when triggered

### Phase 3: Installation and Deployment

#### Checklist 3.1: Create Automated Installation Script
- [ ] Create `install.sh` script with shebang (`#!/bin/bash`)
- [ ] Add script header comments explaining purpose and usage
- [ ] Implement distribution detection (Debian/Ubuntu, Fedora/RHEL, Arch/SteamOS, openSUSE, etc.)
- [ ] Implement package manager detection (apt, dnf/yum, pacman, zypper, apk)
- [ ] Add function to check if command exists (`command -v`)
- [ ] Add function to check for required dependencies (systemd, bash, zenity)
- [ ] Add function to install zenity based on detected package manager
- [ ] Add function to create necessary directories (`~/.local/bin`, `~/.config/sleep-warning`, `~/.config/systemd/user`)
- [ ] Add function to copy script to `~/.local/bin/sleep-warning.sh`
- [ ] Add function to copy default config file to `~/.config/sleep-warning/sleep-warning.conf` (only if not exists)
- [ ] Add function to copy systemd service file to `~/.config/systemd/user/sleep-warning.service`
- [ ] Add function to copy systemd timer file to `~/.config/systemd/user/sleep-warning.timer`
- [ ] Add function to copy configure.sh to `~/.local/bin/sleep-warning-configure` (or similar accessible name)
- [ ] Add function to copy manage.sh to `~/.local/bin/sleep-warning-manage` (or similar accessible name)
- [ ] Add function to set executable permissions on all scripts (`chmod +x`)
- [ ] Add function to reload systemd user daemon
- [ ] Add function to enable and start systemd timer
- [ ] Add function to verify installation (check timer status)
- [ ] Add error handling for each step (exit on failure with clear message)
- [ ] Add colored output for success/error messages (optional, with fallback for non-color terminals)
- [ ] Add confirmation prompt before installing dependencies (with --yes flag to skip)
- [ ] Add check to prevent re-installation over existing installation (with --force flag option)
- [ ] Add summary output showing what was installed and next steps
- [ ] Make install.sh executable (`chmod +x install.sh`)
- [ ] Test installation script on clean system
- [ ] Test installation script with missing dependencies
- [ ] Test installation script with existing installation
- [ ] Test installation script on different distributions (if possible)

#### Checklist 3.2: Create Uninstall Script
- [ ] Create `uninstall.sh` script with shebang (`#!/bin/bash`)
- [ ] Add script header comments explaining purpose and usage
- [ ] Add function to stop systemd timer
- [ ] Add function to disable systemd timer
- [ ] Add function to remove systemd service and timer files
- [ ] Add function to remove script from `~/.local/bin/`
- [ ] Add function to remove configure.sh from `~/.local/bin/`
- [ ] Add function to remove manage.sh from `~/.local/bin/`
- [ ] Add option to remove configuration file (with confirmation prompt)
- [ ] Add function to reload systemd user daemon after cleanup
- [ ] Add verification that files were removed
- [ ] Add error handling for missing files (should not error, just skip)
- [ ] Add summary output showing what was removed
- [ ] Make uninstall.sh executable (`chmod +x uninstall.sh`)
- [ ] Test uninstall script thoroughly

#### Checklist 3.3: Manual Installation Instructions
- [ ] Create installation instructions document (README.md or INSTALL.md)
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

### Phase 4: Testing and Validation

#### Checklist 4.1: Functional Testing
- [ ] Test script with default configuration
- [ ] Test script manually during weekday restricted hours (00:00-05:59)
- [ ] Test script manually during weekend restricted hours (01:00-05:59)
- [ ] Test script during non-restricted hours (should not show popup)
- [ ] Test with custom configuration file (different hours)
- [ ] Test configuration file parsing and validation
- [ ] Verify popup appears and is modal (blocks interaction)
- [ ] Verify popup can be dismissed by user
- [ ] Test timer triggers every 10 minutes correctly
- [ ] Test minimum display time enforcement - NOT TESTED: Requires testing with wmctrl/xdotool on X11 systems
- [ ] Test minimum display time on Wayland - NOT TESTED: Window manager tools don't work on Wayland, needs fallback testing
- [ ] Test auto-reopen functionality - NOT TESTED: Verify popup reopens correctly when closed prematurely
- [ ] Test countdown accuracy - NOT TESTED: Verify countdown updates correctly
- [ ] Test graceful fallback without window tools - NOT TESTED: Verify countdown still works without wmctrl/xdotool
- [ ] **CRITICAL**: Test popup with full-screen game/application running
- [ ] Verify popup appears on top of full-screen applications
- [ ] Verify popup can steal focus from full-screen applications
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test systemd user services start automatically in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test display detection works with gamescope (Wayland compositor)
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with no game running in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with windowed game in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with full-screen game in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with exclusive full-screen game in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with borderless windowed game in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test with Steam games (native and Proton)
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test with non-Steam games added to library
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test timer persistence when switching between Desktop Mode and Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test service status after reboot into Gaming Mode

#### Checklist 4.2: Edge Case Testing
- [ ] Test at exact boundary times (00:00, 05:59, 06:00)
- [ ] Test on day transitions (Sunday to Monday, Friday to Saturday)
- [ ] Test with missing configuration file (should use defaults)
- [ ] Test with invalid configuration file (should handle gracefully)
- [ ] Test with malformed configuration entries
- [ ] Test with configuration file containing comments
- [ ] Test when DISPLAY is not set (should handle gracefully)
- [ ] Test when WAYLAND_DISPLAY is not set (should handle gracefully)
- [ ] Test when neither DISPLAY nor WAYLAND_DISPLAY is set (should use loginctl fallback)
- [ ] Test when zenity is not available (should handle gracefully)
- [ ] Test when all dialog tools unavailable (zenity, yad, kdialog) - should log error and exit gracefully
- [ ] Test with multiple user sessions (if applicable)
- [ ] Test on systems without GUI (should exit gracefully without errors)
- [ ] Test on different desktop environments if available (GNOME, KDE, XFCE)
- [ ] Test minimum display time with different window managers - NOT TESTED: Test on GNOME, KDE, XFCE, etc.
- [ ] Test window stays on top during timeout - NOT TESTED: Verify window manager tools work correctly
- [ ] **SteamOS Gaming Mode**: Test when gamescope compositor is active (Wayland)
- [ ] **SteamOS Gaming Mode**: Test display detection when switching from Desktop Mode to Gaming Mode
- [ ] **SteamOS Gaming Mode**: Test display detection when switching from Gaming Mode to Desktop Mode
- [ ] **SteamOS Gaming Mode**: Test when on-screen keyboard is active (may affect dialog input)
- [ ] **SteamOS Gaming Mode**: Test with different game rendering technologies (Vulkan, DirectX via Proton)
- [ ] **SteamOS Gaming Mode**: Test under heavy system load (game running, high CPU/GPU usage)

#### Checklist 4.3: Installation and Uninstall Testing
- [ ] Test install.sh on clean system (no previous installation)
- [ ] Test install.sh with missing zenity dependency (should offer to install)
- [ ] Test install.sh with --yes flag (auto-confirm dependency installation)
- [ ] Test install.sh with existing installation (should warn, --force should reinstall)
- [ ] Test install.sh on different distributions (if possible: Ubuntu, Fedora, Arch, openSUSE)
- [ ] Test install.sh preserves existing config file (doesn't overwrite)
- [ ] Test install.sh creates config file if missing
- [ ] Verify install.sh sets correct permissions on script
- [ ] Verify install.sh enables and starts timer correctly
- [ ] Test uninstall.sh removes all files correctly
- [ ] Test uninstall.sh stops and disables timer correctly
- [ ] Test uninstall.sh --remove-config removes config file
- [ ] Test uninstall.sh without --remove-config preserves config file
- [ ] Test installation after uninstall (should work cleanly)
- [ ] Verify install.sh error handling (missing directories, permission errors, etc.)
- [ ] Test install.sh on system without GUI (should handle gracefully)
- [ ] Test configure.sh interactive wizard with various inputs
- [ ] Test configure.sh validation and error handling
- [ ] Test configure.sh on system without GUI (should fallback to text prompts)
- [ ] Test manage.sh menu and all functions
- [ ] Test manage.sh disable/enable functionality
- [ ] Test manage.sh on system without GUI (should use text menu)

#### Checklist 4.4: System Integration Testing
- [ ] Verify timer persists across reboots
- [ ] Verify timer works after user login
- [ ] Test behavior when system is suspended/resumed
- [ ] Verify no performance impact from 10-minute checks
- [ ] Check systemd logs for any errors
- [ ] **SteamOS Gaming Mode**: Verify timer persists when booting directly into Gaming Mode
- [ ] **SteamOS Gaming Mode**: Verify timer persists when booting into Desktop Mode then switching to Gaming Mode
- [ ] **SteamOS Gaming Mode**: Verify timer persists when switching from Gaming Mode to Desktop Mode
- [ ] **SteamOS Gaming Mode**: Test service status after system suspend/resume in Gaming Mode
- [ ] **SteamOS Gaming Mode**: Verify no performance impact during gameplay (check CPU/GPU usage during timer trigger)
- [ ] **SteamOS Gaming Mode**: Test with different SteamOS versions (if available) to ensure compatibility

### Phase 5: Documentation and Maintenance

#### Checklist 5.1: Documentation
- [ ] Add disclaimer section to README.md (prominently placed, user must acknowledge)
- [ ] Add disclaimer to installation script (display before installation)
- [ ] Add disclaimer to uninstall script (if applicable)
- [ ] Ensure disclaimer is visible in all user-facing documentation
- [ ] Create comprehensive README.md with project overview
- [ ] **Create GETTING_STARTED.md** - Simple step-by-step guide for first-time users
- [ ] **Create USER_GUIDE.md** - Detailed end-user documentation with examples
- [ ] Document quick start/installation (using install.sh)
- [ ] Document script purpose and usage (in plain language for non-technical users)
- [ ] Document system requirements and compatibility
- [ ] Document supported Linux distributions
- [ ] Document desktop environment compatibility
- [ ] Document systemd service and timer configuration (technical details)
- [ ] Document automated installation process (install.sh) with step-by-step instructions
- [ ] Document uninstall process (uninstall.sh) with step-by-step instructions
- [ ] Document manual installation steps for advanced users
- [ ] Document installation steps for multiple distributions
- [ ] Document dependency installation for each major distribution
- [ ] **Document configuration file format and location** (with clear examples)
- [ ] **Document how to customize restricted hours (with examples)** - Multiple examples for different use cases
- [ ] **Document interactive configuration script (configure.sh)** - Step-by-step walkthrough with screenshots
- [ ] **Document management/help script (manage.sh)** - Complete guide to all features
- [ ] Document how to disable/stop the service (with clear explanations of what this means)
- [ ] Document how to re-enable the service
- [ ] Document how to view service status and logs (with interpretation guide)
- [ ] **Document log file locations** - Clearly explain where logs are stored:
  - Systemd journal: `journalctl --user -u sleep-warning.service`
  - User log file: `~/.config/sleep-warning/warnings.log`
- [ ] **Document log file format** - Explain what information is logged (window state, display environment, dialog tool, etc.)
- [ ] **Document how to view and interpret logs** - Step-by-step guide for users
- [ ] **Document window state logging** - Explain what window states are detected and logged
- [ ] **Document troubleshooting using logs** - How to use logs to diagnose issues
- [ ] Document minimum display time feature in user documentation
- [ ] Document wmctrl/xdotool as optional dependencies
- [ ] Document X11 vs Wayland limitations for minimum display time feature
- [ ] Add troubleshooting section for minimum display time issues
- [ ] Document troubleshooting steps (organized by problem type)
- [ ] Document distribution-specific troubleshooting
- [ ] Include example configuration file with extensive comments
- [ ] **Include multiple configuration examples** (different schedules, use cases)
- [ ] **Create visual guides** - Screenshots or diagrams showing:
  - Installation process
  - Configuration wizard interface
  - Management menu interface
  - Warning popup appearance
- [ ] **Add common use case examples**:
  - Student schedule (late night study restrictions)
  - Work schedule (early morning restrictions)
  - Weekend-only restrictions
  - Different hours per day
- [ ] **Add "What happens when..." section** explaining:
  - What happens during restricted hours
  - What happens during non-restricted hours
  - What happens when you dismiss the popup
  - What happens after reboot
- [ ] Add portability notes and known limitations (clearly marked for users)
- [ ] Add FAQ section for common questions (with answers in plain language)
- [ ] **Add glossary** - Define technical terms (systemd, timer, service, etc.) in user-friendly language
- [ ] **Add accessibility notes** - How to use with screen readers, keyboard navigation, etc.
- [ ] **Include troubleshooting decision tree** - "If X happens, try Y"
- [ ] **Document error messages** - What they mean and how to fix them
- [ ] **Add "Quick Reference" section** - Common commands and actions in one place
- [ ] **Ensure documentation is organized** - Clear sections, table of contents, easy navigation
- [ ] **Test documentation** - Have non-technical users follow instructions and provide feedback

#### Checklist 5.2: Maintenance Considerations
- [ ] Document how to view timer status (with examples of what output means)
- [ ] Document how to view service logs (with examples of normal vs. error logs)
- [ ] Document how to view user log file (`~/.config/sleep-warning/warnings.log`)
- [ ] Document log file location and how to access it
- [ ] Document what information is logged (window state, display environment, dialog tool, timestamps)
- [ ] Document how to interpret log entries (what different window states mean)
- [ ] Document how to use logs for troubleshooting (identifying why popups didn't appear)
- [ ] Document log file rotation or cleanup (if implemented)
- [ ] Document how to modify the warning message (with examples)
- [ ] Document how to change the check interval (if needed) (with warnings about impact)
- [ ] **Document how to update the system** (if updates are released)
- [ ] **Document how to report issues** (where to report, what information to include - emphasize including log file contents)
- [ ] **Document how to get help** (community resources, support channels)

#### Checklist 5.3: End-User Accessibility
- [ ] **Write documentation in plain language** - Avoid jargon, explain technical terms
- [ ] **Use clear headings and structure** - Easy to scan and find information
- [ ] **Include visual aids** - Screenshots, diagrams, flowcharts where helpful
- [ ] **Provide multiple entry points** - Quick start for beginners, detailed docs for advanced
- [ ] **Include "Before You Begin" section** - Prerequisites, what you need to know
- [ ] **Add "Common Tasks" quick reference** - Most frequent operations in one place
- [ ] **Ensure scripts provide helpful error messages** - Clear, actionable, non-technical language
- [ ] **Add inline help in scripts** - Help text, usage information, examples
- [ ] **Test with users of varying technical levels** - Ensure documentation is accessible to all
- [ ] **Provide both GUI and CLI instructions** - Support different user preferences
- [ ] **Include "I just want to..." sections** - Quick answers to common goals

## File Structure

### Repository Structure (Source Code)
```
LinuxTimerWarning/
├── sleep-warning.sh              # Main script
├── sleep-warning.conf            # Default configuration file
├── sleep-warning.service         # Systemd service unit
├── sleep-warning.timer           # Systemd timer unit
├── install.sh                    # Automated installation script
├── uninstall.sh                  # Uninstallation script
├── configure.sh                  # Interactive configuration wizard
├── manage.sh                     # Management and help interface
├── README.md                     # Project documentation and usage
├── GETTING_STARTED.md            # Simple step-by-step guide for first-time users
├── USER_GUIDE.md                 # Detailed end-user documentation with examples
└── LICENSE                       # License file (if applicable)
```

### Installed File Structure (After Installation)
```
~/
├── .local/
│   └── bin/
│       ├── sleep-warning.sh           # Main script (installed by install.sh)
│       ├── sleep-warning-configure    # Configuration wizard (installed by install.sh)
│       └── sleep-warning-manage       # Management/help script (installed by install.sh)
└── .config/
    ├── sleep-warning/
    │   └── sleep-warning.conf         # Configuration file (installed by install.sh)
    └── systemd/
        └── user/
            ├── sleep-warning.service  # Systemd service unit (installed by install.sh)
            └── sleep-warning.timer    # Systemd timer unit (installed by install.sh)
```

## System Requirements and Compatibility

### Supported Linux Distributions

This system is designed to work on **any Linux distribution that uses systemd** as its init system, including but not limited to:

- **Steam OS** (Arch-based) - **Special Focus**: Maximum compatibility with both Desktop Mode and Gaming Mode
- **Ubuntu** (18.04 and later)
- **Debian** (8 and later)
- **Fedora**
- **Arch Linux**
- **openSUSE**
- **CentOS/RHEL** (7 and later)
- **Manjaro**
- **Pop!_OS**
- **Linux Mint**

**Note**: Special emphasis has been placed on ensuring compatibility with SteamOS in Gaming Mode, which presents unique challenges due to the gamescope Wayland compositor and full-screen gaming environment. See the "SteamOS Gaming Mode Compatibility" section for detailed information.

### Desktop Environment Compatibility

The system requires a **graphical desktop environment** with GTK support:

- ✅ **GNOME** - Full support
- ✅ **KDE Plasma** - Full support (Steam OS Desktop Mode uses KDE)
- ✅ **XFCE** - Full support
- ✅ **LXDE/LXQt** - Full support
- ✅ **MATE** - Full support
- ✅ **Cinnamon** - Full support
- ⚠️ **Tiling Window Managers** (i3, sway, etc.) - May work if GTK libraries are installed
- ⚠️ **SteamOS Gaming Mode** (gamescope/Wayland) - Partial support, requires testing (see SteamOS Gaming Mode Compatibility section)
- ❌ **Headless/Server Systems** - Not supported (no GUI)

### Not Compatible With

- Systems without systemd (Devuan, Void Linux with runit, Alpine with OpenRC, etc.)
- Systems without a graphical desktop environment
- Systems without GTK libraries installed

## Dependencies

### Required Dependencies

- **systemd**: System and service manager
  - Pre-installed on most modern Linux distributions
  - Required for user services and timers
  - Check availability: `systemctl --version`

- **bash**: Shell interpreter
  - Pre-installed on all Linux systems
  - Check availability: `bash --version`

- **zenity**: GTK dialog tool for displaying popups
  - May need to be installed depending on distribution
  - Check availability: `which zenity` or `zenity --version`
  
  **Installation commands by distribution:**
  - **Debian/Ubuntu/Linux Mint**: `sudo apt install zenity`
  - **Fedora/RHEL/CentOS**: `sudo dnf install zenity` (or `sudo yum install zenity` on older versions)
  - **Arch Linux/Steam OS/Manjaro**: `sudo pacman -S zenity`
  - **openSUSE**: `sudo zypper install zenity`
  - **Alpine Linux**: `sudo apk add zenity` (if using systemd)

### Optional Dependencies (for enhanced functionality)

- **yad**: Alternative to zenity with better window control options
  - Can be used as a fallback if zenity has issues with full-screen applications
  - Installation: Same package manager commands as zenity (replace `zenity` with `yad`)

- **wmctrl** or **xdotool**: Window manager control tools
  - Useful for forcing popups to appear on top of full-screen applications
  - **Required for minimum display time feature** (prevents closing/minimizing popup)
  - Only works on X11 (not Wayland)
  - Installation: `sudo apt install wmctrl` (Debian/Ubuntu) or `sudo apt install xdotool` or equivalent for other distros
  - Note: These are optional but recommended for full functionality of minimum display time feature

## Key Implementation Details

### Configuration File Format

The configuration file should be simple and easy to edit. Suggested format:

**Option 1: Day-based format (recommended)**
```
# Sleep Warning Configuration
# Format: DAY=START_HOUR-END_HOUR
# Hours are in 24-hour format (0-23)
# Multiple ranges can be specified per day (comma-separated)

SUNDAY=1-5
MONDAY=0-5
TUESDAY=0-5
WEDNESDAY=0-5
THURSDAY=0-5
FRIDAY=0-5
SATURDAY=1-5
```

**Option 2: Simple key-value format**
```
WEEKDAY_START=0
WEEKDAY_END=5
WEEKEND_START=1
WEEKEND_END=5
```

The script should:
- Read configuration from `~/.config/sleep-warning/sleep-warning.conf`
- Fall back to defaults if file doesn't exist
- Validate hour ranges (0-23, start < end)
- Support comments (lines starting with #)

### Time Checking Logic
- Use `date +%w` for day of week (0=Sunday, 6=Saturday)
- Use `date +%H` for hour (00-23)
- Read restricted hours from configuration file for current day
- Check if current hour falls within configured restricted range(s)

### Display Access
- **Primary Detection**: Check `$DISPLAY` environment variable (X11)
- **Wayland Detection**: Check `$WAYLAND_DISPLAY` environment variable (Wayland/gamescope)
- **SteamOS Gaming Mode**: Detect gamescope compositor and use appropriate display identifier
- **Fallback Detection**: Use `loginctl` to find active user session and extract display information
- **Last Resort**: Try common display values (`:0`, `/tmp/.X11-unix/X0`)
- Set appropriate display environment variable (DISPLAY or WAYLAND_DISPLAY) before running dialog tools
- Handle both X11 and Wayland display protocols appropriately

### Modal Popup
- Use `zenity --warning --modal` to ensure user must interact
- Popup will block until user clicks OK/dismisses
- Supports configurable minimum display time (prevents closing/minimizing for set duration)

### Minimum Display Time Feature

**Description**: The popup can be configured to remain visible for a minimum duration before it can be closed, ensuring users see the warning message.

**Configuration**:
- Setting: `POPUP_MIN_DISPLAY_TIME` in config file
- Range: 0-300 seconds (0 = disabled, default = 30 seconds)
- Configurable via configuration wizard

**Implementation**:
1. **Window Manager Tools**: Uses `wmctrl` or `xdotool` to:
   - Make window sticky (stays on all desktops)
   - Keep window on top
   - Attempt to prevent closing during timeout period

2. **Auto-Reopen Mechanism**: 
   - Monitors if popup is closed prematurely
   - Automatically reopens popup if closed during minimum display time
   - Updates countdown message with remaining time

3. **Countdown Display**:
   - Shows remaining seconds in popup message
   - Updates dynamically if popup is reopened

4. **Graceful Fallback**:
   - If window manager tools unavailable, still shows countdown message
   - Less enforcement without tools, but still informative

**Limitations**:
- **X11 Only**: Window manager tools (`wmctrl`/`xdotool`) only work on X11, not Wayland
- **Optional Dependency**: Requires `wmctrl` or `xdotool` for full functionality (installed separately)
- **Window Manager Dependent**: Effectiveness varies by window manager
- **Not 100% Secure**: Determined users could still force-close via system tools (kill process, etc.)
- **Wayland Compatibility**: On Wayland, only countdown message is shown (no window control)

**Testing Requirements**:
- Test on X11 systems with wmctrl/xdotool installed
- Test on Wayland systems (should fallback gracefully)
- Test with different window managers (GNOME, KDE, XFCE, etc.)
- Test auto-reopen functionality
- Test countdown accuracy
- Verify window stays on top during timeout

### Full-Screen Application Compatibility

**Important Consideration**: The behavior of zenity popups with full-screen applications (especially games) can vary depending on:
- Desktop environment and window manager (GNOME, KDE, XFCE, etc.)
- Display protocol (X11 vs Wayland/gamescope)
- Whether the application uses exclusive full-screen mode (bypasses window manager)
- Whether the application uses borderless windowed mode (still managed by WM)
- Compositor settings and window manager policies

**Expected Behavior**:
- zenity dialogs typically appear over full-screen applications in most Linux environments (X11)
- On Wayland/gamescope (SteamOS Gaming Mode), behavior may differ significantly
- Exclusive full-screen games may block window manager dialogs on both X11 and Wayland
- Behavior varies between different desktop environments and compositors
- Behavior should be tested with actual full-screen games on target systems, especially SteamOS Gaming Mode

**SteamOS Gaming Mode Specific Considerations**:
- **gamescope Compositor**: Uses Wayland protocol, not X11
- **Full-Screen Games**: May use exclusive full-screen mode that bypasses compositor
- **Steam Overlay**: Native Steam overlay may be more reliable than external dialogs
- **Window Manager Tools**: `wmctrl`/`xdotool` do not work on Wayland/gamescope
- **Dialog Tool Limitations**: zenity dialogs may not receive keyboard input from Steam Deck's on-screen keyboard in Gaming Mode (known issue: https://github.com/ValveSoftware/SteamOS/issues/1039)

**Potential Solutions if Issues Arise**:
1. **Use `yad` instead of `zenity`**: `yad` offers `--on-top` flag for better control and works across multiple desktop environments
2. **Use `kdialog` for KDE**: Native KDE dialog tool may work better on KDE-based systems (SteamOS uses KDE in Desktop Mode)
3. **Window manager tools**: Use `wmctrl` or `xdotool` to force window raise/focus (requires X11, not Wayland/gamescope)
4. **Steam Overlay Integration**: Consider integrating with Steam overlay for Gaming Mode compatibility (see Future Enhancements section)
5. **Alternative notification methods**: Consider desktop-specific notification systems or compositor overlays
6. **Wayland-specific protocols**: Use native Wayland protocols for notifications (requires different implementation approach)
7. **Test and document**: Identify which full-screen modes work on different desktop environments and document limitations

**Testing Priority**: This is a **CRITICAL** test case that must be verified early in development, with special emphasis on SteamOS Gaming Mode testing. Test on multiple desktop environments and both X11 and Wayland if possible.

### Timer Configuration
- Use `OnCalendar=*:0/10` to run every 10 minutes
- Timer accuracy: `AccuracySec=1min` (can be adjusted)

### Interactive Configuration Script Details

The `configure.sh` script provides a user-friendly way to set up restricted hours without manually editing the configuration file.

**Implementation Approach:**
1. **GUI Interface**: Primary interface uses `zenity` for dialogs
   - Welcome dialog explaining the process
   - Day-by-day hour selection dialogs
   - Summary dialog showing all configured hours
   - Confirmation dialog before saving

2. **Input Collection**:
   - For each day (Sunday through Saturday), prompt for:
     - Start hour (0-23) using `zenity --entry` or `zenity --scale`
     - End hour (0-23) using `zenity --entry` or `zenity --scale`
   - Provide option to skip day (no restrictions)
   - Provide option to apply weekday settings to all weekdays at once
   - Provide option to apply weekend settings to both weekend days at once

3. **Validation**:
   - Ensure hours are in range 0-23
   - Ensure start hour < end hour
   - Provide clear error messages for invalid input
   - Allow user to correct mistakes

4. **Config File Writing**:
   - Write in the day-based format: `DAY=START_HOUR-END_HOUR`
   - Preserve existing comments if config file exists
   - Create backup of existing config before overwriting (optional)
   - Write to `~/.config/sleep-warning/sleep-warning.conf`

5. **Fallback Support**:
   - If `zenity` unavailable, use text-based prompts
   - Use `read` command for text input
   - Provide clear text instructions

**Example Flow:**
1. Welcome dialog: "This wizard will help you configure restricted hours..."
2. Ask: "Configure all weekdays together? (Yes/No)"
3. If Yes: Prompt once for weekday hours, apply to Mon-Fri
4. If No: Prompt for each weekday individually
5. Ask: "Configure both weekend days together? (Yes/No)"
6. If Yes: Prompt once for weekend hours, apply to Sat-Sun
7. If No: Prompt for Saturday and Sunday separately
8. Show summary: "Your configuration: Monday-Friday: 0-5, Saturday-Sunday: 1-5"
9. Confirm: "Save this configuration? (Yes/No)"
10. Write to config file

### Management/Help Script Details

The `manage.sh` script provides a central interface for managing and understanding the sleep warning system.

**Implementation Approach:**
1. **Main Menu**: Use `zenity --list` or text menu for options
   - Each option launches a specific function
   - Menu should be easy to navigate

2. **Service Status Function**:
   - Check if timer is enabled: `systemctl --user is-enabled sleep-warning.timer`
   - Check if timer is active: `systemctl --user is-active sleep-warning.timer`
   - Get next trigger: `systemctl --user list-timers sleep-warning.timer`
   - Display in user-friendly format

3. **Configuration View Function**:
   - Read and display `~/.config/sleep-warning/sleep-warning.conf`
   - Format nicely for display
   - Show in `zenity --text-info` dialog or `less` for text mode

4. **Disable/Enable Functions**:
   - **Disable**: `systemctl --user stop sleep-warning.timer && systemctl --user disable sleep-warning.timer`
   - **Enable**: `systemctl --user enable sleep-warning.timer && systemctl --user start sleep-warning.timer`
   - Show confirmation dialog before executing
   - Display success/error messages
   - Explain what disable/enable means

5. **Information Functions**:
   - **How to Disable**: Show instructions: "To temporarily disable, run: systemctl --user stop sleep-warning.timer && systemctl --user disable sleep-warning.timer"
   - **How to Enable**: Show instructions: "To re-enable, run: systemctl --user enable sleep-warning.timer && systemctl --user start sleep-warning.timer"
   - **How to Uninstall**: Show instructions: "Run: sleep-warning-manage and select uninstall, or run: uninstall.sh from source directory"
   - **File Locations**: List all installed files and their purposes

6. **Logs Viewer Function**:
   - Run: `journalctl --user -u sleep-warning.service -n 50 --no-pager`
   - Display in `zenity --text-info` or `less` for text mode
   - Show recent entries (last 50 lines)

7. **Launch Configuration Wizard**:
   - Execute: `sleep-warning-configure` or `~/.local/bin/sleep-warning-configure`
   - Handle errors gracefully if script not found

8. **Help/Information Function**:
   - Display overview of what the system does
   - Explain how it works
   - Show usage examples
   - Provide links to documentation

**Menu Structure:**
```
Main Menu:
1. View Service Status
2. View Current Configuration
3. Configure Restricted Hours (Launch Wizard)
4. Temporarily Disable Service
5. Re-enable Service
6. View Service Logs
7. Show File Locations
8. Show Help/Information
9. Exit
```

**Text Mode Fallback:**
- If GUI unavailable, use `select` command for menu
- Use `echo` and `read` for information display
- Use `less` or `cat` for viewing files/logs

### Installation Script Details

The `install.sh` script automates the entire installation process, making it easy for users to set up the system with a single command.

**Key Features:**
1. **Distribution Detection**: Automatically detects the Linux distribution and package manager
   - Detects: Debian/Ubuntu (apt), Fedora/RHEL/CentOS (dnf/yum), Arch/SteamOS/Manjaro (pacman), openSUSE (zypper), Alpine (apk)
   - Provides clear error if distribution is not supported

2. **Dependency Management**:
   - Checks if systemd is available (required)
   - Checks if bash is available (required)
   - Checks if zenity is installed (required)
   - Offers to install zenity if missing (with user confirmation, or `--yes` flag to auto-confirm)
   - Provides clear error messages if dependencies cannot be installed

3. **File Installation**:
   - Creates necessary directories if they don't exist
   - Copies script to `~/.local/bin/sleep-warning.sh`
   - Copies configure.sh to `~/.local/bin/sleep-warning-configure` (or similar accessible name)
   - Copies manage.sh to `~/.local/bin/sleep-warning-manage` (or similar accessible name)
   - Copies default config to `~/.config/sleep-warning/sleep-warning.conf` (only if file doesn't exist, to preserve user customizations)
   - Copies systemd service and timer files to `~/.config/systemd/user/`
   - Sets executable permissions on all scripts

4. **Service Activation**:
   - Reloads systemd user daemon
   - Enables timer to start on boot
   - Starts timer immediately
   - Verifies timer is active and scheduled

5. **User Experience**:
   - Provides colored output for success/error messages (with fallback for non-color terminals)
   - Shows progress during installation
   - Provides summary of what was installed
   - Shows next steps including how to run configuration wizard (`sleep-warning-configure`)
   - Shows how to access management interface (`sleep-warning-manage`)
   - Shows how to customize configuration manually (if preferred)
   - Handles errors gracefully with clear messages

6. **Safety Features**:
   - Checks if already installed (warns user, with `--force` flag to reinstall)
   - Preserves existing configuration file
   - Validates each step before proceeding
   - Provides rollback information if installation fails

**Usage:**
```bash
# Basic installation (will prompt for dependency installation)
./install.sh

# Automatic installation (auto-confirms dependency installation)
./install.sh --yes

# Force reinstallation (overwrites existing installation)
./install.sh --force
```

**Uninstall Script Details:**

The `uninstall.sh` script provides a clean way to remove the system.

**Key Features:**
1. Stops and disables the systemd timer
2. Removes systemd service and timer files
3. Removes all scripts from `~/.local/bin/` (main script, configure, manage)
4. Optionally removes configuration file (with confirmation)
5. Reloads systemd user daemon
6. Provides summary of what was removed

**Usage:**
```bash
# Uninstall (will prompt about config file)
./uninstall.sh

# Uninstall including config file
./uninstall.sh --remove-config
```

**Interactive Configuration Script Details:**

The `configure.sh` script provides a user-friendly GUI wizard for configuring restricted hours.

**Key Features:**
1. **Interactive GUI**: Uses zenity dialogs for easy-to-use interface
2. **Day-by-Day Configuration**: Walks through each day of the week (Sunday-Saturday)
3. **Input Validation**: Validates hour ranges (0-23, start < end)
4. **Convenience Options**: 
   - Apply same settings to all weekdays
   - Apply same settings to both weekend days
   - Skip days (no restrictions)
5. **Summary and Confirmation**: Shows configured hours before saving
6. **Fallback Support**: Falls back to text prompts if GUI unavailable
7. **Preserves Comments**: Maintains existing comments in config file

**Usage:**
```bash
# Run configuration wizard
sleep-warning-configure

# Or from source directory
./configure.sh
```

**Management/Help Script Details:**

The `manage.sh` script provides a comprehensive management interface and help system.

**Key Features:**
1. **Service Status**: Shows if service is enabled/disabled and active/inactive
2. **Timer Information**: Displays timer status and next trigger time
3. **Configuration View**: Shows current configuration file contents
4. **Disable/Enable Instructions**: Explains how to temporarily disable or re-enable
5. **Quick Actions**: Provides one-click disable/enable with confirmation
6. **Configuration Access**: Quick launch of configuration wizard
7. **Logs Viewer**: Displays recent service logs for troubleshooting
8. **Uninstall Information**: Explains uninstall process
9. **File Locations**: Shows where all files are installed
10. **Help and Information**: Provides overview and usage information
11. **GUI and Text Modes**: Works with GUI (zenity) or text menu

**Usage:**
```bash
# Run management interface
sleep-warning-manage

# Or from source directory
./manage.sh
```

**Menu Options:**
- View service status
- View current configuration
- Configure restricted hours (launches configure.sh)
- Temporarily disable service
- Re-enable service
- View service logs
- Show file locations
- Show help/information
- Exit

## Testing Strategy

1. **Manual Script Testing**: Run script directly to verify logic
2. **Time Manipulation**: Use `date` command or system time changes to test different scenarios
3. **Timer Testing**: Use `systemctl --user list-timers` to verify scheduling
4. **Log Monitoring**: Check `journalctl --user -u sleep-warning.service` for errors
5. **Multi-Distribution Testing**: Test on different Linux distributions if possible (or document known compatibility)
6. **Desktop Environment Testing**: Test on different desktop environments (GNOME, KDE, XFCE) if available
7. **SteamOS Gaming Mode Testing**: **CRITICAL** - Extensive testing required for:
   - Systemd user services in Gaming Mode
   - Display detection with gamescope (Wayland)
   - Popup appearance with various game states (no game, windowed, full-screen, exclusive full-screen)
   - Timer persistence across Desktop Mode ↔ Gaming Mode transitions
   - Performance impact during gameplay
   - Compatibility with different game types (Steam native, Proton, non-Steam)
8. **Display Protocol Testing**: Test on both X11 and Wayland environments
9. **Edge Case Testing**: Test boundary conditions, missing dependencies, invalid configurations
10. **Cross-Mode Testing**: Test behavior when switching between different modes (Desktop/Gaming, X11/Wayland)

## Portability Considerations

### Cross-Distribution Compatibility

The implementation should follow these principles to ensure maximum portability:

1. **Use Standard Paths**: Follow XDG Base Directory Specification
   - Config: `~/.config/sleep-warning/`
   - Binaries: `~/.local/bin/`
   - Systemd units: `~/.config/systemd/user/`

2. **Dependency Detection**: Script should check for required tools and provide helpful error messages
   - Check for `zenity` availability
   - Check for `systemd` availability
   - Check for GUI environment (DISPLAY variable, WAYLAND_DISPLAY variable, or active session)
   - Check for gamescope compositor (SteamOS Gaming Mode)

3. **Fallback Options**: Implement comprehensive fallback dialog tools
   - Primary: `zenity` (GTK, works on most systems)
   - Fallback 1: `yad` (enhanced zenity alternative, better Wayland support, preferred for Gaming Mode)
   - Fallback 2: `kdialog` (KDE-specific, better on KDE systems like SteamOS Desktop Mode)
   - Fallback 3: `notify-send` (non-modal, last resort)
   - Environment-aware selection: Prefer yad for Gaming Mode, kdialog for KDE systems

4. **Display Protocol Support**: Support both X11 and Wayland
   - **X11**: Check `$DISPLAY` environment variable, use X11 tools (xrandr, xdpyinfo)
   - **Wayland**: Check `$WAYLAND_DISPLAY` environment variable, detect gamescope compositor
   - **Fallback**: Use `loginctl` to find active sessions and extract display information
   - **Multi-protocol**: Try X11 first, then Wayland, then fallbacks

5. **Error Handling**: Gracefully handle missing dependencies
   - Log errors to systemd journal
   - Exit cleanly without breaking systemd service
   - Provide clear error messages for troubleshooting
   - Handle both X11 and Wayland display detection failures gracefully

6. **Distribution-Specific Notes**:
   - **Wayland vs X11**: Some window manager tools (wmctrl, xdotool) only work on X11, not Wayland/gamescope
   - **SteamOS Gaming Mode**: Uses gamescope (Wayland), requires special display detection
   - **Package Manager Differences**: Document installation commands for each major distribution
   - **Service Management**: All systemd-based systems use the same commands (`systemctl --user`)
   - **Desktop vs Gaming Mode**: Services must persist across mode transitions on SteamOS

## SteamOS Gaming Mode Compatibility

### Overview

SteamOS Gaming Mode presents unique challenges for systemd-based warning systems due to its use of the gamescope Wayland compositor, focus on full-screen gaming experiences, and different environment setup compared to traditional desktop environments. This section outlines the compatibility considerations, implementation strategies, and testing requirements specific to SteamOS Gaming Mode.

### Key Challenges

1. **Display Environment Detection**
   - Gaming Mode uses gamescope (Wayland compositor), not X11
   - `DISPLAY` environment variable may not be set (Wayland uses `WAYLAND_DISPLAY`)
   - Traditional X11 detection methods may fail
   - Need to detect gamescope-specific display identifiers

2. **Systemd User Services**
   - User services should work in Gaming Mode, but need verification
   - Services must persist across Desktop Mode ↔ Gaming Mode transitions
   - Services must start automatically when booting directly into Gaming Mode

3. **GUI Dialog Compatibility**
   - zenity/yad/kdialog may not appear over exclusive full-screen games
   - Dialogs may not receive keyboard input from Steam Deck's on-screen keyboard
   - Window manager tools (wmctrl/xdotool) don't work on Wayland/gamescope
   - Full-screen games may block compositor-level dialogs

4. **Performance Considerations**
   - Timer checks should not impact game performance
   - Dialog display should not cause frame drops or stuttering
   - System should handle high CPU/GPU load scenarios gracefully

### Implementation Strategies

#### Display Detection Enhancements

**Current Implementation**:
- Checks `$DISPLAY` (X11)
- Falls back to `loginctl` session detection
- Tries common X11 display values

**Required Enhancements for Gaming Mode**:
- [ ] Detect `$WAYLAND_DISPLAY` environment variable
- [ ] Detect gamescope compositor (check for gamescope process or environment)
- [ ] Use `loginctl` to find Wayland sessions
- [ ] Query gamescope-specific display information if available
- [ ] Implement multi-protocol display detection (try X11, then Wayland, then fallbacks)
- [ ] Log display environment information (X11/Wayland, display identifier) to log file

#### Window State Detection

**Purpose**: Detect and log the state of the active window to help troubleshoot popup visibility issues, especially in Gaming Mode.

**Required Implementation**:
- [ ] Detect active window state (full-screen, exclusive full-screen, windowed, borderless windowed)
- [ ] For X11: Use `xdotool` or `wmctrl` to query window state
  - Check if window is full-screen
  - Check if window is maximized
  - Check if window is in exclusive full-screen mode (if detectable)
  - Get window title/application name if available
- [ ] For Wayland: Use `swaymsg` (if Sway/sway-based) or other Wayland tools if available
  - Note: Limited window state detection on Wayland/gamescope
  - Log that detection is limited on Wayland
- [ ] Log window state information when warning is triggered
- [ ] Include window state in log file entries (`~/.config/sleep-warning/warnings.log`)
- [ ] Add graceful fallback when window state detection tools unavailable
- [ ] Log window title/application name if available (for troubleshooting)

**Log Format**:
```
[YYYY-MM-DD HH:MM:SS] WARNING_TRIGGERED | Window State: <state> | Display: <X11/Wayland> | Dialog Tool: <tool> | Popup Success: <yes/no> | Window Title: <title>
```

**Window States to Detect**:
- `windowed` - Normal windowed mode
- `borderless_windowed` - Borderless windowed mode
- `fullscreen` - Full-screen (non-exclusive, compositor-managed)
- `exclusive_fullscreen` - Exclusive full-screen (bypasses compositor)
- `unknown` - Cannot determine (fallback when detection unavailable)
- `no_window` - No active window detected

**Log File Location**: `~/.config/sleep-warning/warnings.log`

#### Dialog Tool Selection

**Priority Order for Gaming Mode**:
1. **yad** (if available): Better Wayland support, `--on-top` flag, more reliable over full-screen
2. **kdialog** (if available): Native KDE tool, may work better on SteamOS (KDE-based in Desktop Mode)
3. **zenity** (fallback): Standard GTK dialog, may have limitations in Gaming Mode

**Implementation**:
- [ ] Detect available dialog tools in priority order
- [ ] Prefer yad for Gaming Mode if detected
- [ ] Use kdialog as second choice (especially on SteamOS)
- [ ] Fall back to zenity if others unavailable
- [ ] Log which tool is used for troubleshooting

#### Systemd Service Robustness

**Required Enhancements**:
- [ ] Ensure service starts in Gaming Mode (test after boot)
- [ ] Verify service persists across mode transitions
- [ ] Add service dependencies if needed (e.g., graphical-session.target)
- [ ] Test service status in both Desktop and Gaming Modes
- [ ] Document any Gaming Mode-specific service configuration

### Testing Requirements

See **Checklist 4.1**, **4.2**, and **4.4** for comprehensive SteamOS Gaming Mode testing requirements. Key test scenarios include:

- Systemd user services in Gaming Mode
- Display detection with gamescope
- Popup appearance with various game states
- Timer persistence across mode transitions
- Performance impact during gameplay

### Known Limitations

1. **Exclusive Full-Screen Games**: May block dialog popups entirely
   - **Workaround**: Use borderless windowed mode in games
   - **Future Solution**: Steam Overlay integration (see Future Enhancements)
   - **Logging**: Window state detection will log when exclusive full-screen is detected to help diagnose issues

2. **On-Screen Keyboard**: zenity dialogs may not receive input from Steam Deck keyboard overlay
   - **Reference**: https://github.com/ValveSoftware/SteamOS/issues/1039
   - **Workaround**: Use yad or kdialog if available
   - **Future Solution**: Steam Overlay integration
   - **Logging**: Dialog tool used is logged to help identify when zenity issues occur

3. **Window Manager Tools**: wmctrl/xdotool don't work on Wayland/gamescope
   - **Impact**: Minimum display time feature has limited enforcement in Gaming Mode
   - **Impact**: Window state detection is limited on Wayland/gamescope
   - **Workaround**: Countdown message still shown, but window control unavailable
   - **Logging**: Logs will indicate when window state detection is unavailable (Wayland limitation)

4. **Dialog Visibility**: May vary by game type, rendering technology, and full-screen mode
   - **Testing Required**: Extensive testing with different games and configurations
   - **Documentation**: Document known working/not-working scenarios
   - **Logging**: Window state and popup success/failure are logged to help identify patterns

### Compatibility Status

**Current Status**: ⚠️ **Partially Compatible - Requires Testing**

- ✅ Systemd user services: Should work (needs verification)
- ⚠️ Display detection: Needs Wayland/gamescope support (implementation required)
- ⚠️ Dialog popups: May work but needs extensive testing
- ❌ Window manager tools: Not compatible (Wayland limitation)
- ⚠️ Full-screen games: Unknown compatibility (critical testing required)

**Target Status**: ✅ **Fully Compatible** (after implementation and testing)

## Future Enhancements and Alternatives

This section outlines potential improvements and alternative approaches to enhance functionality, compatibility, and user experience. Each item is categorized as either **Complementary** (can be added to the current suite of scripts and files) or **Alternative Approach** (would require a different implementation strategy).

### Complementary Enhancements (Can Be Added to Current System)

These enhancements can be integrated into the existing bash script suite without requiring a complete redesign:

#### 1. Enhanced Display Detection
- **Description**: Improve display detection for Wayland/gamescope with multiple fallback strategies
- **Implementation**: Add functions to detect `WAYLAND_DISPLAY`, gamescope compositor, and query Wayland sessions
- **Files Affected**: `sleep-warning.sh`
- **Priority**: High (required for SteamOS Gaming Mode compatibility)
- **Status**: Partially implemented, needs enhancement

#### 2. Dialog Tool Priority System
- **Description**: Implement intelligent dialog tool selection based on environment (prefer yad for Gaming Mode, kdialog for KDE)
- **Implementation**: Enhance `check_dialog_tool()` function with environment-aware selection
- **Files Affected**: `sleep-warning.sh`
- **Priority**: High (improves Gaming Mode compatibility)
- **Status**: Basic implementation exists, needs enhancement

#### 3. Systemd Service Environment Detection
- **Description**: Detect Desktop Mode vs Gaming Mode and adjust behavior accordingly
- **Implementation**: Add environment detection function, configure service based on mode
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.service`
- **Priority**: Medium (improves compatibility)
- **Status**: Not implemented

#### 4. Configurable Warning Messages
- **Description**: Allow users to customize warning message text per day or time range
- **Implementation**: Add `MESSAGE_*` configuration options, update `show_warning()` function
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Low (nice-to-have feature)
- **Status**: Not implemented

#### 5. Escalating Warnings
- **Description**: Show progressively stronger warnings if user continues using system during restricted hours
- **Implementation**: Track warning count in temporary file, adjust message intensity
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

#### 6. Warning Event Logging
- **Description**: Log each warning event with timestamp, window state, display environment, and dialog tool to a file for user review
- **Implementation**: 
  - Add file-based logging function, write to `~/.config/sleep-warning/warnings.log`
  - Log timestamp, window state (full-screen/exclusive/windowed), display environment (X11/Wayland), dialog tool used, popup success/failure
  - Include window state detection (using xdotool/wmctrl for X11, swaymsg for Wayland if available)
- **Files Affected**: `sleep-warning.sh`
- **Priority**: High (critical for troubleshooting Gaming Mode compatibility)
- **Status**: Not implemented

#### 7. Temporary Disable via Config
- **Description**: Allow users to temporarily disable warnings via configuration file or command
- **Implementation**: Add `ENABLED=false` config option, check before showing warning
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`, `manage.sh`
- **Priority**: Medium (useful feature)
- **Status**: Not implemented

#### 8. System Sleep/Hibernate Detection
- **Description**: Skip warnings if system was recently resumed from sleep (user may have just woken up)
- **Implementation**: Check system uptime or last resume time, skip warnings for configurable duration after resume
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

#### 9. Audio Alerts
- **Description**: Add optional audio notification (beep, sound file) alongside visual popup
- **Implementation**: Use `paplay`, `aplay`, or `speaker-test` to play sound
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

#### 10. Desktop Notification Fallback
- **Description**: Use desktop notification system (notify-send) as fallback if dialog tools fail
- **Implementation**: Add notify-send as last-resort fallback in `show_warning()` function
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Medium (improves compatibility)
- **Status**: Not implemented

#### 11. Wayland-Specific Window Management
- **Description**: Implement Wayland-native window control using wlr-randr or similar tools
- **Implementation**: Add Wayland-specific functions for screen info and window positioning
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Medium (improves Wayland/gamescope compatibility)
- **Status**: Not implemented (requires research into Wayland protocols)

#### 12. Distribution-Specific Optimizations
- **Description**: Add optimizations for specific distributions (e.g., KDE-specific features on KDE systems)
- **Implementation**: Detect distribution/DE, apply appropriate optimizations
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

### Alternative Approaches (Require Different Implementation)

These approaches would require significant changes to the architecture or a completely different implementation strategy:

#### 1. Steam Overlay Integration
- **Description**: Integrate with Steam Overlay API to display warnings within Steam's native overlay system
- **Why Alternative**: Requires Steamworks SDK, C/C++ development, different architecture
- **Advantages**: 
  - Guaranteed to work over full-screen games in Gaming Mode
  - Native Steam integration
  - Better user experience for Steam users
- **Disadvantages**:
  - Only works with Steam games
  - Requires Steam to be running
  - Significant development effort
  - Different technology stack (C/C++ vs bash)
- **Implementation Approach**:
  - Develop C/C++ plugin using Steamworks SDK
  - Create overlay notification system
  - Integrate with existing systemd service (call plugin from bash script)
- **Complementary Option**: Could be developed alongside current system as optional enhancement
- **Priority**: High (best solution for SteamOS Gaming Mode full-screen games)
- **Status**: Not implemented

#### 2. Custom Wayland Protocol Implementation
- **Description**: Develop custom Wayland protocol for notifications compatible with gamescope
- **Why Alternative**: Requires deep Wayland protocol knowledge, C development, compositor integration
- **Advantages**:
  - Native Wayland support
  - Works with gamescope
  - Full control over notification behavior
- **Disadvantages**:
  - Very complex implementation
  - Requires compositor modifications or extensions
  - May not work with all compositors
- **Implementation Approach**:
  - Develop Wayland protocol extension
  - Create compositor plugin or modification
  - Integrate with existing system
- **Complementary Option**: Could be developed as optional enhancement
- **Priority**: Low (very complex, limited benefit over simpler solutions)
- **Status**: Not implemented

#### 3. Native Desktop Application (GUI Wrapper)
- **Description**: Create full desktop application (GTK/Qt/Electron) to replace bash scripts
- **Why Alternative**: Different technology stack, different architecture, different distribution method
- **Advantages**:
  - Better user experience
  - Native GUI for configuration
  - Can be packaged as AppImage/Flatpak/Snap
  - System tray integration possible
- **Disadvantages**:
  - Requires GUI framework knowledge
  - Larger codebase
  - Different maintenance requirements
  - May not work in Gaming Mode (needs desktop environment)
- **Implementation Approach**:
  - Develop GUI application (Python+GTK, Qt, or Electron)
  - Replace configure.sh and manage.sh with GUI
  - Keep systemd service integration
- **Complementary Option**: Could be developed alongside bash scripts as alternative interface
- **Priority**: Medium (improves user experience but not Gaming Mode compatibility)
- **Status**: Not implemented (see Distribution Options section for details)

#### 4. Systemd Timer Alternative (Cron-based)
- **Description**: Use cron instead of systemd timers for scheduling
- **Why Alternative**: Different scheduling system, different architecture
- **Advantages**:
  - Works on systems without systemd
  - More traditional approach
- **Disadvantages**:
  - Less reliable than systemd timers
  - Doesn't solve Gaming Mode compatibility issues
  - Different service management
- **Implementation Approach**:
  - Create cron job instead of systemd timer
  - Modify installation script
  - Different service management
- **Complementary Option**: Could be developed as alternative for non-systemd systems
- **Priority**: Low (systemd is standard, limited benefit)
- **Status**: Not implemented

#### 5. Web-Based Configuration Interface
- **Description**: Create web server for configuration and management
- **Why Alternative**: Different architecture, requires web server, different access method
- **Advantages**:
  - Access from any device
  - Modern interface
  - Remote configuration possible
- **Disadvantages**:
  - Security concerns (local web server)
  - Additional dependencies
  - Doesn't solve Gaming Mode compatibility
  - Overkill for simple configuration
- **Implementation Approach**:
  - Develop lightweight web server (Python Flask, Node.js, etc.)
  - Create web interface
  - Integrate with existing system
- **Complementary Option**: Could be developed as optional enhancement
- **Priority**: Very Low (unnecessary complexity)
- **Status**: Not implemented

### Recommended Implementation Priority

**High Priority (Required for Gaming Mode Compatibility)**:
1. Enhanced Display Detection (Wayland/gamescope)
2. Dialog Tool Priority System
3. Window State Detection and Logging (critical for troubleshooting)
4. File-Based Logging with Window State Information
5. Steam Overlay Integration (Alternative, but best solution)

**Medium Priority (Improves Compatibility/Usability)**:
6. Systemd Service Environment Detection
7. Desktop Notification Fallback
8. Wayland-Specific Window Management
9. Temporary Disable via Config

**Low Priority (Nice-to-Have Enhancements)**:
10. Configurable Warning Messages
11. Escalating Warnings
12. Audio Alerts
13. Distribution-Specific Optimizations
14. Wayland support for minimum display time (would require different approach)
15. More robust window control (prevent all close methods, not just window manager)
16. Visual countdown timer in popup (instead of just text)
17. Configurable auto-reopen behavior

### Implementation Notes

- **Complementary enhancements** can be added incrementally without breaking existing functionality
- **Alternative approaches** should be evaluated carefully as they may require significant development effort
- **Steam Overlay Integration** is the most promising solution for full Gaming Mode compatibility but requires the most development effort
- All enhancements should maintain backward compatibility with existing configurations
- Testing should be performed for each enhancement, especially Gaming Mode compatibility

**Note**: For information about distribution and packaging options, see `DISTRIBUTION_OPTIONS.md`.