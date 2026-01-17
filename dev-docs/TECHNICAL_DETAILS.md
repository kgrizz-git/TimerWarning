# Technical Implementation Details

This document provides detailed technical specifications for the Sleep Warning System implementation. For the implementation plan with checklists, see [linux-warning-system-plan.md](linux-warning-system-plan.md).

## Configuration File Format

The configuration file uses a simple day-based format that is easy to edit:

**Day-based format (implemented)**
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

The script:
- Reads configuration from `~/.config/sleep-warning/sleep-warning.conf`
- Falls back to defaults if file doesn't exist
- Validates hour ranges (0-23, start < end for normal ranges, start > end for overnight ranges)
- Supports comments (lines starting with #)
- Supports multiple time ranges per day (comma-separated, e.g., `0-5,22-23`)
- Supports overnight ranges that span midnight (e.g., `23-6` means 11 PM to 5:59 AM)

For complete configuration documentation including all options (CHECK_INTERVAL, POPUP_SIZE, POPUP_POSITION, POPUP_MIN_DISPLAY_TIME, POPUP_IMMOVABLE), see [user-docs/CONFIGURATION.md](../user-docs/CONFIGURATION.md).

## Time Checking Logic
- Use `date +%w` for day of week (0=Sunday, 6=Saturday)
- Use `date +%H` for hour (00-23)
- Read restricted hours from configuration file for current day
- Check if current hour falls within configured restricted range(s)

## Display Access

**Primary Detection**: Check `$DISPLAY` environment variable (X11)

**Wayland Detection**: Check `$WAYLAND_DISPLAY` environment variable (Wayland/gamescope)

**SteamOS Display Protocols**:
- **Desktop Mode**: Uses X11 (KDE Plasma runs on X11). Window manager tools (`wmctrl`/`xdotool`) work here, enabling full window control features.
- **Gaming Mode**: Uses Wayland (gamescope compositor). Window manager tools don't work here, limiting window control capabilities. For detailed information, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md).

**Fallback Detection**: Use `loginctl` to find active user session and extract display information

**Last Resort**: Try common display values (`:0`, `/tmp/.X11-unix/X0`)

Set appropriate display environment variable (DISPLAY or WAYLAND_DISPLAY) before running dialog tools. Handle both X11 and Wayland display protocols appropriately.

For detailed display detection strategies for SteamOS Gaming Mode, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#display-detection-enhancements).

## Modal Popup
- Use `zenity --warning --modal` to ensure user must interact
- Popup will block until user clicks OK/dismisses
- Supports configurable minimum display time (prevents closing/minimizing for set duration)

## Minimum Display Time Feature

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
- **Wayland Compatibility**: On Wayland, only countdown message is shown (no window control). For SteamOS Gaming Mode limitations, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#known-limitations).

**Testing Requirements**:
- Test on X11 systems with wmctrl/xdotool installed
- Test on Wayland systems (should fallback gracefully)
- Test with different window managers (GNOME, KDE, XFCE, etc.)
- Test auto-reopen functionality
- Test countdown accuracy
- Verify window stays on top during timeout

## Full-Screen Application Compatibility

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

**For detailed SteamOS Gaming Mode compatibility information**, including specific considerations, limitations, and solutions, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#full-screen-application-compatibility).

**Implemented Solutions**:
1. **Multi-tool support**: System supports zenity, yad, and kdialog with automatic detection
   - zenity: Primary choice, good cross-platform compatibility
   - yad: Alternative with `--on-top` flag and better positioning control
   - kdialog: KDE native tool (currently not preferred due to compatibility issues)
2. **Window manager tools**: Implemented using `wmctrl` or `xdotool` for stay-on-top functionality
   - Uses `xprop _NET_WM_STATE_ABOVE` for reliable on-top behavior
   - Confirmed working with zenity on KDE/KWin
   - Requires X11 (not available on Wayland/gamescope)
3. **Periodic enforcement**: Background process continuously reapplies stay-on-top settings

**Additional Solutions if Issues Arise**:
4. **Steam Overlay Integration**: Consider integrating with Steam overlay for Gaming Mode compatibility (see [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md))
5. **Alternative notification methods**: Consider desktop-specific notification systems or compositor overlays
6. **Wayland-specific protocols**: Use native Wayland protocols for notifications (requires different implementation approach)
7. **Test and document**: Identify which full-screen modes work on different desktop environments and document limitations

**Testing Priority**: This is a **CRITICAL** test case that must be verified early in development, with special emphasis on SteamOS Gaming Mode testing. Test on multiple desktop environments and both X11 and Wayland if possible.

## Timer Configuration
- Timer interval is configurable via `CHECK_INTERVAL` in the configuration file (1-60 minutes)
- Default interval: 10 minutes (`OnCalendar=*:0/10`)
- The timer file is automatically updated by `configure.sh` when `CHECK_INTERVAL` is changed
- Install script should read `CHECK_INTERVAL` from config (if exists) when creating the timer file
- Timer accuracy: `AccuracySec=1min` (can be adjusted)
- Format: `OnCalendar=*:0/N` where N is the check interval in minutes

## Interactive Configuration Script Details

The `configure.sh` script provides a user-friendly way to set up restricted hours without manually editing the configuration file.

**Implementation Approach:**
1. **GUI Interface**: Primary interface uses dialog tools (zenity/yad/kdialog) for dialogs
   - System automatically detects available dialog tool
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

## Management/Help Script Details

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

## Installation Script Details

The `install.sh` script automates the entire installation process, making it easy for users to set up the system with a single command.

**Key Features:**
1. **Distribution Detection**: Automatically detects the Linux distribution and package manager
   - Detects: Debian/Ubuntu (apt), Fedora/RHEL/CentOS (dnf/yum), Arch/SteamOS/Manjaro (pacman), openSUSE (zypper), Alpine (apk)
   - Provides clear error if distribution is not supported

2. **Dependency Management**:
   - Checks if systemd is available (required)
   - Checks if bash is available (required)
   - Checks if a dialog tool (zenity/yad/kdialog) is installed (required)
   - Offers to install zenity if no dialog tool is found (with user confirmation, or `--yes` flag to auto-confirm)
   - **Optional**: Users can manually install wmctrl and xdotool for enhanced window management features (stay-on-top, immovable windows)
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
   - Check for gamescope compositor (SteamOS Gaming Mode). For details, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md).

3. **Fallback Options**: Implement comprehensive fallback dialog tools
   - Primary: `zenity` (GTK, works on most systems)
   - Fallback 1: `yad` (enhanced zenity alternative, better Wayland support, preferred for Gaming Mode)
   - Fallback 2: `kdialog` (KDE-specific, better on KDE systems like SteamOS Desktop Mode)
   - Fallback 3: `notify-send` (non-modal, last resort)
   - Environment-aware selection: Prefer yad for Gaming Mode, kdialog for KDE systems

   For detailed dialog tool selection strategies for SteamOS Gaming Mode, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#dialog-tool-selection).

4. **Display Protocol Support**: Support both X11 and Wayland
   - **X11**: Check `$DISPLAY` environment variable, validate format, and verify accessibility when tools are available
   - **Wayland**: Check `$WAYLAND_DISPLAY` with `XDG_RUNTIME_DIR` socket validation, detect gamescope compositor
   - **Wayland helpers**: If env vars are missing, attempt helper checks (`swaymsg`, `wlr-randr`, `wayland-info`) against available Wayland sockets before falling back to `loginctl`
   - **Fallback**: Use `loginctl` to find active sessions and extract display information
   - **Multi-protocol**: Try X11 first, then Wayland, then fallbacks
   - **Wayland/gamescope popup behavior**:
     - Dialogs may not stay on top of full-screen applications
     - Window manager tools (wmctrl/xdotool) are unavailable, so on-top enforcement is best-effort
     - Planned fallback: `notify-send` (non-modal) with explicit logging when dialogs fail

   For detailed display detection strategies, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#display-detection-enhancements).

5. **Error Handling**: Gracefully handle missing dependencies
   - Log errors to systemd journal
   - Exit cleanly without breaking systemd service
   - Provide clear error messages for troubleshooting
   - Handle both X11 and Wayland display detection failures gracefully

6. **Distribution-Specific Notes**:
   - **Wayland vs X11**: Some window manager tools (wmctrl, xdotool) only work on X11, not Wayland/gamescope
   - **SteamOS Display Protocols**:
     - **Desktop Mode**: Uses X11 (KDE Plasma). Window manager tools work, enabling full window control features.
     - **Gaming Mode**: Uses Wayland (gamescope). Window manager tools don't work, limiting window control to informational features only.
     - Requires special display detection for Gaming Mode. See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md) for details.
   - **Package Manager Differences**: Document installation commands for each major distribution
   - **Service Management**: All systemd-based systems use the same commands (`systemctl --user`)
   - **Desktop vs Gaming Mode**: Services must persist across mode transitions on SteamOS. See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#systemd-service-robustness).
