# Sleep Warning System - Implementation Plan

## High-Level Description

This project implements a systemd-based monitoring system that displays interactive warning popups when the system is being used during configurable restricted hours. The system is designed to work on any modern Linux distribution with systemd (including Steam OS, Ubuntu, Debian, Fedora, Arch, and others). It uses a bash script combined with systemd timers to check the current time every 10 minutes and display modal warning dialogs if usage occurs during user-defined restricted hours.

**Default restricted hours** (easily configurable):
- **Weekdays (Monday-Friday)**: Midnight (00:00) to 6:00 AM
- **Weekends (Saturday-Sunday)**: 1:00 AM to 6:00 AM

The restricted hours for each day of the week are easily configurable through a simple configuration file, allowing users to customize the warning schedule to their needs. The popup dialogs are modal and require user interaction before they can be dismissed, ensuring the user is aware of the late-night usage. The system runs as a user service (not system-wide) to ensure proper display access and user context.

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
   - Displays modal popup using `zenity` if conditions are met
   - Handles display environment detection

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
- [ ] Test minimum display time enforcement - NOT TESTED: Requires testing with wmctrl/xdotool on X11 systems
- [ ] Test minimum display time on Wayland - NOT TESTED: Window manager tools don't work on Wayland, needs fallback testing
- [ ] Consider using window manager tools to force popup on top if needed - IMPLEMENTED: wmctrl/xdotool used for window control, yad has --on-top flag

#### Checklist 1.5: Add Script Robustness
- [x] Add shebang line (`#!/bin/bash`)
- [x] Add error handling for missing dependencies
- [x] Add logging capability (optional, to syslog or file) - Uses logger command if available
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
- [ ] **CRITICAL**: Test popup with full-screen game/application running
- [ ] Verify popup appears on top of full-screen applications
- [ ] Verify popup can steal focus from full-screen applications

#### Checklist 4.2: Edge Case Testing
- [ ] Test at exact boundary times (00:00, 05:59, 06:00)
- [ ] Test on day transitions (Sunday to Monday, Friday to Saturday)
- [ ] Test with missing configuration file (should use defaults)
- [ ] Test with invalid configuration file (should handle gracefully)
- [ ] Test with malformed configuration entries
- [ ] Test with configuration file containing comments
- [ ] Test when DISPLAY is not set (should handle gracefully)
- [ ] Test when zenity is not available (should handle gracefully)
- [ ] Test with multiple user sessions (if applicable)
- [ ] Test on systems without GUI (should exit gracefully without errors)
- [ ] Test on different desktop environments if available (GNOME, KDE, XFCE)

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

### Phase 5: Documentation and Maintenance

#### Checklist 5.1: Documentation
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
- [ ] Document how to modify the warning message (with examples)
- [ ] Document how to change the check interval (if needed) (with warnings about impact)
- [ ] **Document how to update the system** (if updates are released)
- [ ] **Document how to report issues** (where to report, what information to include)
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

- **Steam OS** (Arch-based)
- **Ubuntu** (18.04 and later)
- **Debian** (8 and later)
- **Fedora**
- **Arch Linux**
- **openSUSE**
- **CentOS/RHEL** (7 and later)
- **Manjaro**
- **Pop!_OS**
- **Linux Mint**

### Desktop Environment Compatibility

The system requires a **graphical desktop environment** with GTK support:

- ✅ **GNOME** - Full support
- ✅ **KDE Plasma** - Full support (Steam OS uses KDE)
- ✅ **XFCE** - Full support
- ✅ **LXDE/LXQt** - Full support
- ✅ **MATE** - Full support
- ✅ **Cinnamon** - Full support
- ⚠️ **Tiling Window Managers** (i3, sway, etc.) - May work if GTK libraries are installed
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
- Check `$DISPLAY` environment variable
- If not set, use `loginctl` to find active user session
- Set DISPLAY before running zenity

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
- Whether the application uses exclusive full-screen mode (bypasses window manager)
- Whether the application uses borderless windowed mode (still managed by WM)
- Compositor settings and window manager policies

**Expected Behavior**:
- zenity dialogs typically appear over full-screen applications in most Linux environments
- However, exclusive full-screen games may block window manager dialogs
- Behavior may vary between different desktop environments
- Behavior should be tested with actual full-screen games on target systems

**Potential Solutions if Issues Arise**:
1. **Use `yad` instead of `zenity`**: `yad` offers `--on-top` flag for better control and works across multiple desktop environments
2. **Use `kdialog` for KDE**: Native KDE dialog tool may work better on KDE-based systems
3. **Window manager tools**: Use `wmctrl` or `xdotool` to force window raise/focus (requires X11, not Wayland)
4. **Alternative notification methods**: Consider desktop-specific notification systems or compositor overlays
5. **Test and document**: Identify which full-screen modes work on different desktop environments and document limitations

**Testing Priority**: This is a critical test case that should be verified early in development and tested on multiple desktop environments if possible.

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
   - Check for GUI environment (DISPLAY variable or active session)

3. **Fallback Options**: Consider implementing fallback dialog tools
   - Primary: `zenity` (GTK, works on most systems)
   - Fallback 1: `yad` (enhanced zenity alternative)
   - Fallback 2: `kdialog` (KDE-specific, better on KDE systems)
   - Fallback 3: `notify-send` (non-modal, last resort)

4. **Error Handling**: Gracefully handle missing dependencies
   - Log errors to systemd journal
   - Exit cleanly without breaking systemd service
   - Provide clear error messages for troubleshooting

5. **Distribution-Specific Notes**:
   - **Wayland vs X11**: Some window manager tools (wmctrl, xdotool) only work on X11
   - **Package Manager Differences**: Document installation commands for each major distribution
   - **Service Management**: All systemd-based systems use the same commands (`systemctl --user`)

## Future Enhancements (Optional)

- Different warning messages for weekdays vs weekends
- Different warning messages per day of week
- Escalating warnings (first warning, then stronger warning)
- Logging of warning events
- Ability to temporarily disable warnings (via config or command)
- Integration with system sleep/hibernate detection
- Multiple time ranges per day (e.g., 00:00-02:00 and 04:00-06:00) - IMPLEMENTED: Comma-separated ranges supported
- Configurable warning message text
- Configurable check interval (currently hardcoded to 10 minutes) - IMPLEMENTED: CHECK_INTERVAL configuration added
- Configurable popup size and position - IMPLEMENTED: POPUP_SIZE and POPUP_POSITION configuration added
- Configurable minimum display time (prevent closing/minimizing) - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME configuration added (0-300 seconds, uses wmctrl/xdotool on X11)
- Automatic fallback to alternative dialog tools if primary tool unavailable
- Wayland-specific window management support
- Distribution-specific optimizations (e.g., KDE-specific features on KDE systems)

## Distribution and Packaging Options

### Current Distribution Method

The project currently uses a traditional installation approach:
- Source code repository (Git)
- Installation script (`install.sh`) that copies files to system locations
- Manual installation via systemd user services
- Configuration via command-line scripts

### Alternative Distribution Options

#### Option 1: Single Executable Installer Script

**Description**: Bundle all files into a single self-extracting installer script that users can download and run.

**Advantages**:
- Single file to download
- Easy distribution (GitHub releases, direct download)
- No package manager required
- Works across all distributions
- Can include all dependencies bundled

**Implementation Approach**:
- Create a shell script that contains all project files as base64-encoded data
- Script extracts files to temporary directory
- Runs installation process
- Cleans up temporary files
- Can be made executable with `chmod +x`

**Example Structure**:
```bash
#!/bin/bash
# Self-extracting installer
# Contains: sleep-warning.sh, configure.sh, manage.sh, systemd files, etc.

# Extract embedded files
# Run install.sh
# Clean up
```

**Checklist**:
- [ ] Create self-extracting installer script template
- [ ] Add file embedding mechanism (base64 or here-document)
- [ ] Add extraction logic
- [ ] Integrate with existing install.sh
- [ ] Test on multiple distributions
- [ ] Create build script to generate installer
- [ ] Document usage and distribution

#### Option 2: Desktop GUI Application Wrapper

**Description**: Create a desktop application (using GTK, Qt, or Electron) that provides a GUI for configuration and management.

**Advantages**:
- User-friendly graphical interface
- No command-line knowledge required
- Can be packaged as AppImage, Flatpak, or Snap
- Provides visual feedback and status
- Can include system tray integration

**Implementation Approach**:
- Use Python with GTK (PyGObject) or similar
- Create GUI windows for:
  - Configuration wizard (replaces configure.sh)
  - Management interface (replaces manage.sh)
  - Status display
  - Settings panel
- Backend still uses systemd services
- Can be packaged as AppImage or Flatpak

**Technologies**:
- **Python + GTK**: Lightweight, native Linux look
- **Electron**: Cross-platform, modern UI, larger size
- **Qt/QML**: Native, good performance, cross-platform

**Checklist**:
- [ ] Choose GUI framework (GTK/Qt/Electron)
- [ ] Design GUI mockups/wireframes
- [ ] Implement configuration GUI
- [ ] Implement management GUI
- [ ] Implement status display
- [ ] Integrate with systemd services
- [ ] Add system tray icon (optional)
- [ ] Create desktop entry file
- [ ] Package as AppImage/Flatpak/Snap
- [ ] Test on multiple desktop environments

#### Option 3: Flatpak Package

**Description**: Package the application as a Flatpak for easy distribution across Linux distributions.

**Advantages**:
- Works on any Linux distribution with Flatpak support
- Sandboxed execution
- Automatic dependency management
- Easy installation: `flatpak install sleep-warning`
- Centralized distribution (Flathub)

**Requirements**:
- Flatpak manifest file (`.flatpak.json` or `.yaml`)
- Application metadata
- Desktop entry file
- Icon files
- Build system setup

**Implementation Approach**:
- Create Flatpak manifest defining:
  - Runtime dependencies (systemd, bash, zenity)
  - Application files
  - Permissions (user service access)
- Build Flatpak package
- Submit to Flathub or host repository

**Checklist**:
- [ ] Create Flatpak manifest file
- [ ] Define runtime and SDK requirements
- [ ] Configure application permissions
- [ ] Create desktop entry and metadata
- [ ] Create application icons
- [ ] Build Flatpak package locally
- [ ] Test Flatpak installation and functionality
- [ ] Set up build automation (CI/CD)
- [ ] Submit to Flathub or create repository
- [ ] Document Flatpak installation process

#### Option 4: Snap Package

**Description**: Package the application as a Snap for Ubuntu and other Snap-supported distributions.

**Advantages**:
- Works on Ubuntu, Debian, Fedora, Arch (with snapd)
- Automatic updates
- Sandboxed execution
- Centralized distribution (Snap Store)

**Requirements**:
- Snapcraft YAML file (`snapcraft.yaml`)
- Application metadata
- Desktop entry file
- Icon files
- Build system setup

**Implementation Approach**:
- Create `snapcraft.yaml` defining:
  - Base and build packages
  - Application files and scripts
  - Plugs and slots for systemd access
  - Desktop integration
- Build Snap package
- Submit to Snap Store

**Checklist**:
- [ ] Create snapcraft.yaml file
- [ ] Define base and build requirements
- [ ] Configure plugs for systemd user services
- [ ] Create desktop entry and metadata
- [ ] Create application icons
- [ ] Build Snap package locally
- [ ] Test Snap installation and functionality
- [ ] Set up build automation (CI/CD)
- [ ] Submit to Snap Store
- [ ] Document Snap installation process

#### Option 5: Hybrid Approach (Recommended)

**Description**: Provide multiple distribution methods to suit different user preferences and technical levels.

**Distribution Methods**:
1. **Traditional**: Source code + install.sh (current method)
2. **Single Installer**: Self-extracting executable script
3. **GUI App**: Desktop application (AppImage or Flatpak)
4. **Package Manager**: Flatpak or Snap for easy installation

**Implementation Strategy**:
- Keep current installation method for advanced users
- Add single installer script for convenience
- Develop GUI application wrapper
- Package GUI app as Flatpak/Snap
- Provide clear documentation for each method

**Checklist**:
- [ ] Maintain current installation method
- [ ] Implement single installer script (Option 1)
- [ ] Develop GUI application (Option 2)
- [ ] Package GUI as Flatpak (Option 3)
- [ ] Package GUI as Snap (Option 4)
- [ ] Create unified documentation covering all methods
- [ ] Set up automated builds for all packages
- [ ] Create release process for all distribution formats

### Recommendations

**For End-User Ease**: 
- **Priority 1**: Single executable installer script (Option 1) - Easiest to implement, works everywhere
- **Priority 2**: GUI application wrapper (Option 2) - Best user experience, can be packaged

**For Distribution**:
- **Priority 1**: Flatpak (Option 3) - Best cross-distribution support, modern packaging
- **Priority 2**: Snap (Option 4) - Good for Ubuntu users, automatic updates

**For Maximum Compatibility**:
- Provide all methods: Traditional install, single installer, GUI app, and packaged versions
- Let users choose based on their technical level and distribution preferences

## Minimum Display Time Feature - Implementation Status

### Completed Tasks

#### Configuration System (Checklist 1.2)
- [x] Add configurable minimum display time - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME setting (0-300 seconds, prevents closing/minimizing)

#### Display and Popup Functionality (Checklist 1.4)
- [x] Implement minimum display time enforcement - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME prevents closing/minimizing for configured duration
- [x] Add window manager tool detection - IMPLEMENTED: Checks for wmctrl/xdotool for window control
- [x] Add window unclosable functionality - IMPLEMENTED: Uses wmctrl/xdotool to make window sticky and prevent closing
- [x] Add auto-reopen if closed prematurely - IMPLEMENTED: Reopens popup with countdown if closed during minimum display time
- [x] Add countdown message in popup - IMPLEMENTED: Shows remaining time before popup can be closed
- [x] Consider using window manager tools to force popup on top if needed - IMPLEMENTED: wmctrl/xdotool used for window control, yad has --on-top flag

#### Interactive Configuration Script (Checklist 1.6)
- [x] Add prompt for minimum display time configuration - IMPLEMENTED: Prompts for POPUP_MIN_DISPLAY_TIME (0-300 seconds)
- [x] Display summary including interval, size, and position - IMPLEMENTED: Summary shows all configuration options including minimum display time
- [x] Write minimum display time to config file - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME saved to config

#### Code Implementation
- [x] Add `get_min_display_time()` function - Reads POPUP_MIN_DISPLAY_TIME from config
- [x] Add `check_window_tools()` function - Detects wmctrl/xdotool availability
- [x] Add `make_window_unclosable()` function - Uses window manager tools to prevent closing
- [x] Add `reenable_window_closing()` function - Re-enables closing after timeout
- [x] Integrate minimum display time into `show_warning()` function
- [x] Add countdown message to popup text
- [x] Implement monitoring and auto-reopen logic
- [x] Add graceful fallback when window tools unavailable

### Remaining Tasks

#### Testing (Not Yet Completed)
- [ ] Test minimum display time enforcement - NOT TESTED: Requires testing with wmctrl/xdotool on X11 systems
- [ ] Test minimum display time on Wayland - NOT TESTED: Window manager tools don't work on Wayland, needs fallback testing
- [ ] Test auto-reopen functionality - NOT TESTED: Verify popup reopens correctly when closed prematurely
- [ ] Test countdown accuracy - NOT TESTED: Verify countdown updates correctly
- [ ] Test with different window managers - NOT TESTED: Test on GNOME, KDE, XFCE, etc.
- [ ] Test window stays on top during timeout - NOT TESTED: Verify window manager tools work correctly
- [ ] Test graceful fallback without window tools - NOT TESTED: Verify countdown still works without wmctrl/xdotool

#### Documentation (Not Yet Completed)
- [ ] Document minimum display time feature in user documentation
- [ ] Document wmctrl/xdotool as optional dependencies
- [ ] Document X11 vs Wayland limitations
- [ ] Document configuration options in README
- [ ] Add troubleshooting section for minimum display time issues

#### Future Enhancements (Optional)
- [ ] Wayland support for minimum display time (would require different approach)
- [ ] More robust window control (prevent all close methods, not just window manager)
- [ ] Visual countdown timer in popup (instead of just text)
- [ ] Configurable auto-reopen behavior