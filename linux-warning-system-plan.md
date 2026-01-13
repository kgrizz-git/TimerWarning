# Sleep Warning System - Implementation Plan

## High-Level Description

This project implements a systemd-based monitoring system that displays interactive warning popups when the system is being used during configurable restricted hours. The system is designed to work on any modern Linux distribution with systemd (including Steam OS, Ubuntu, Debian, Fedora, Arch, and others). It uses a bash script combined with systemd timers to check the current time every 10 minutes and display modal warning dialogs if usage occurs during user-defined restricted hours.

**Default restricted hours** (easily configurable):
- **Weekdays (Monday-Friday)**: Midnight (00:00) to 6:00 AM
- **Weekends (Saturday-Sunday)**: 1:00 AM to 6:00 AM

The restricted hours for each day of the week are easily configurable through a simple configuration file, allowing users to customize the warning schedule to their needs. The popup dialogs are modal and require user interaction before they can be dismissed, ensuring the user is aware of the late-night usage. The system runs as a user service (not system-wide) to ensure proper display access and user context.

## Architecture Overview

The solution consists of six main components:

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

## Implementation Plan

### Phase 1: Project Setup and Script Development

#### Checklist 1.1: Create Project Structure
- [ ] Create project directory structure
- [ ] Create `sleep-warning.sh` script file
- [ ] Create configuration file (`sleep-warning.conf`)
- [ ] Create systemd service directory (`~/.config/systemd/user/`)
- [ ] Create systemd service file (`sleep-warning.service`)
- [ ] Create systemd timer file (`sleep-warning.timer`)

#### Checklist 1.2: Implement Configuration System
- [ ] Design configuration file format (simple key-value or day-based format)
- [ ] Create default configuration file with example values
- [ ] Implement configuration file parsing in script
- [ ] Add validation for configuration values (hour ranges, format)
- [ ] Add fallback to default values if config file missing or invalid
- [ ] Document configuration file format and options

#### Checklist 1.3: Develop Bash Script Core Logic
- [ ] Get current day of week (0=Sunday, 6=Saturday)
- [ ] Get current hour (0-23 format)
- [ ] Load restricted hours from configuration file for current day
- [ ] Implement time range check using configured hours
- [ ] Add logic to determine if warning should be shown
- [ ] Handle edge cases (midnight crossover, multiple ranges per day)

#### Checklist 1.4: Implement Display and Popup Functionality
- [ ] Detect DISPLAY environment variable
- [ ] Fallback to finding active user session display if DISPLAY not set
- [ ] Implement zenity popup command with modal flag
- [ ] Add fallback detection for alternative dialog tools (yad, kdialog) if zenity unavailable
- [ ] Add appropriate warning message text
- [ ] Ensure popup requires user interaction (modal)
- [ ] Add error handling for zenity not being available
- [ ] Add graceful handling for systems without GUI (log error, exit silently)
- [ ] Test popup behavior with full-screen applications
- [ ] Consider using window manager tools to force popup on top if needed

#### Checklist 1.5: Add Script Robustness
- [ ] Add shebang line (`#!/bin/bash`)
- [ ] Add error handling for missing dependencies
- [ ] Add logging capability (optional, to syslog or file)
- [ ] Add script header comments explaining purpose
- [ ] Make script executable (`chmod +x`)

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
- [ ] Add function to set executable permissions on script (`chmod +x`)
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

#### Checklist 4.4: System Integration Testing
- [ ] Verify timer persists across reboots
- [ ] Verify timer works after user login
- [ ] Test behavior when system is suspended/resumed
- [ ] Verify no performance impact from 10-minute checks
- [ ] Check systemd logs for any errors

### Phase 5: Documentation and Maintenance

#### Checklist 5.1: Documentation
- [ ] Create comprehensive README.md with project overview
- [ ] Document quick start/installation (using install.sh)
- [ ] Document script purpose and usage
- [ ] Document system requirements and compatibility
- [ ] Document supported Linux distributions
- [ ] Document desktop environment compatibility
- [ ] Document systemd service and timer configuration
- [ ] Document automated installation process (install.sh)
- [ ] Document uninstall process (uninstall.sh)
- [ ] Document manual installation steps for advanced users
- [ ] Document installation steps for multiple distributions
- [ ] Document dependency installation for each major distribution
- [ ] **Document configuration file format and location**
- [ ] **Document how to customize restricted hours (with examples)**
- [ ] Document how to disable/stop the service
- [ ] Document how to view service status and logs
- [ ] Document troubleshooting steps
- [ ] Document distribution-specific troubleshooting
- [ ] Include example configuration file with comments
- [ ] Add portability notes and known limitations
- [ ] Add FAQ section for common questions
- [ ] Include screenshots or examples of the warning popup (if applicable)

#### Checklist 5.2: Maintenance Considerations
- [ ] Document how to view timer status
- [ ] Document how to view service logs
- [ ] Document how to modify the warning message
- [ ] Document how to change the check interval (if needed)

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
├── README.md                     # Project documentation and usage
└── LICENSE                       # License file (if applicable)
```

### Installed File Structure (After Installation)
```
~/
├── .local/
│   └── bin/
│       └── sleep-warning.sh          # Main script (installed by install.sh)
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
  - Installation: `sudo apt install wmctrl` (Debian/Ubuntu) or equivalent for other distros

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
   - Copies default config to `~/.config/sleep-warning/sleep-warning.conf` (only if file doesn't exist, to preserve user customizations)
   - Copies systemd service and timer files to `~/.config/systemd/user/`
   - Sets executable permissions on the script

4. **Service Activation**:
   - Reloads systemd user daemon
   - Enables timer to start on boot
   - Starts timer immediately
   - Verifies timer is active and scheduled

5. **User Experience**:
   - Provides colored output for success/error messages (with fallback for non-color terminals)
   - Shows progress during installation
   - Provides summary of what was installed
   - Shows next steps and how to customize configuration
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
3. Removes the script from `~/.local/bin/`
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
- Multiple time ranges per day (e.g., 00:00-02:00 and 04:00-06:00)
- Configurable warning message text
- Configurable check interval (currently hardcoded to 10 minutes)
- Automatic fallback to alternative dialog tools if primary tool unavailable
- Wayland-specific window management support
- Distribution-specific optimizations (e.g., KDE-specific features on KDE systems)