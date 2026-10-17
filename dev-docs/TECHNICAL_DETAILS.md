# Technical Implementation Details

This document provides detailed technical specifications for the Sleep Warning System implementation. For the master plan and detailed checklists, see [linux-warning-system-plan.md](plans/master/linux-warning-system-plan.md) and the [phase plans](plans/phases/) linked from it.

## Code Architecture

The Sleep Warning System uses a **modular architecture** for improved maintainability and testability:

- **Main Script**: `sleep-warning.sh` (~128 lines) - Streamlined entry point
- **Library Modules**: 7 core modules plus additional enhancement modules in `lib/` directory (~1500 lines total)
  - `config.sh` - Configuration management
  - `logging.sh` - Logging functions
  - `display-detection.sh` - Display environment detection and system mode detection (Enhancement #4)
  - `desktop-environment.sh` - Desktop/dialog tool detection
  - `window-management.sh` - Window manipulation
  - `time-validation.sh` - Time range validation
- `lib/time-parsing.sh` - Time format parsing and conversion (Enhancement 16b)
  - `popup-display.sh` - Warning popup display
  - `sleep-detection.sh` - Sleep/hibernate detection and popup queue management (Enhancement #9)
  - `uninstall-verification.sh` - Uninstall protection verification (Enhancement #26)
  - `service-config.sh` - Systemd service configuration for Desktop/Gaming Mode (Enhancement #4)

**Benefits**:
- Clear separation of concerns
- Individual modules can be tested in isolation
- Easier to understand and maintain
- Explicit dependency management
- 92% reduction in main script size (from 1667 to 128 lines)

**For detailed module documentation**, including dependencies, function lists, and development guidelines, see [completed-plans/plan-modular-architecture-sleep-warning.md](completed-plans/plan-modular-architecture-sleep-warning.md).

### Configuration Wizard Architecture

The Configuration Wizard (`configure.sh`) also uses a **modular architecture** for improved maintainability:

- **Main Script**: `configure.sh` (~268 lines) - Streamlined entry point
- **Library Modules**: 7 core modules plus additional enhancement modules in `lib/` directory (~2,469 lines total)
  - `configure-core.sh` - Core utilities and constants
  - `configure-config.sh` - Configuration file operations
  - `configure-time.sh` - Time formatting and validation
  - `configure-ui.sh` - Basic UI dialogs
  - `configure-input.sh` - User input collection
  - `configure-display.sh` - Complex displays (grids, menus)
  - `configure-workflow.sh` - Section orchestration
  - `configure-dialogs.sh` - Dialog abstraction layer (tool-agnostic interface)
  - `configure-validation.sh` - 24/7 restriction validation and overlap detection

**Benefits**:
- Clear separation of concerns for configuration logic
- Individual modules can be tested in isolation
- Reusable components for other management scripts
- Explicit dependency management
- 90% reduction in main script size (from 2,588 to 268 lines)

**For detailed configure module documentation**, including dependencies, function lists, and development guidelines, see [completed-plans/plan-modular-architecture-configure.md](completed-plans/plan-modular-architecture-configure.md).

## Configuration File Format

The configuration file uses a simple day-based format that is easy to edit:

**Day-based format (implemented)**
```
# Sleep Warning Configuration
# Format: DAY=START_TIME-END_TIME
# Supports 12h (11:30pm) and 24h (23:30) formats
# Multiple ranges can be specified per day (comma-separated)

SUNDAY=1:00am-5:00am
MONDAY=0:00-5:00
```

The script:
- Reads configuration from `~/.config/sleep-warning/config/sleep-warning.conf` (Enhancement #18)
- Falls back to defaults if file doesn't exist
- Validates time ranges (0-23:59, handles both formats)
- Supports comments (lines starting with #)
- Supports multiple time ranges per day (comma-separated, e.g., `0-5,11pm-12am`)
- Supports overnight ranges that span midnight (e.g., `23:30-6:30` means 11:30 PM to 6:29 AM)
- Automatically migrates legacy `HH-HH` format to `HH:MM-HH:MM`

For complete configuration documentation including all options (CHECK_INTERVAL, POPUP_SIZE, POPUP_POSITION, POPUP_MIN_DISPLAY_TIME, POPUP_IMMOVABLE, POPUP_AUTO_CLOSE), see [user-docs/CONFIGURATION.md](../user-docs/CONFIGURATION.md).

## Time Checking Logic
- Use `date +%w` for day of week (0=Sunday, 6=Saturday)
- Use `get_current_time()` to get time in HHMM format (0000-2359)
- Read restricted hours from configuration file for current day
- Check if current time falls within configured restricted range(s) using `is_restricted_time()`
- Handles minute-level precision and 12h/24h format normalization

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
- Uses dialog tools (YAD preferred, Zenity/KDialog fallback) with `--modal` flag to ensure user must interact
- Popup will block until user clicks OK/dismisses
- Supports configurable minimum display time (prevents closing/minimizing for set duration)
- Dialog tool priority: YAD → Zenity → KDialog (unified across all environments)

### Locale / Unicode considerations (non-UTF-8)

Some environments (notably systemd user services) can run with a non-UTF locale (e.g. `LANG=C`). GTK dialog tools (`yad` / `zenity`) may exit immediately if passed UTF‑8 text under a non‑UTF locale (e.g. “Invalid byte sequence in conversion input”).

**Current behavior**:
- The project attempts to switch to a UTF‑8 locale when available.
- If UTF‑8 cannot be confirmed, user-visible GUI dialog strings are sanitized to **ASCII-only** before being passed to `yad`/`zenity`/`kdialog` to avoid crashes.
- Console-only output may display Unicode separators/arrows as garbled text under non‑UTF locales, but does not affect GUI dialog safety.

## Dialog Tool Selection

**Automatic Priority System**:
The system uses a unified priority system across all environments (including KDE):
1. **YAD** (preferred) - Native positioning, reliable sizing, better window management, Wayland support
2. **Zenity** (fallback) - Standard GTK dialog, pre-installed on most systems, good compatibility
3. **KDialog** (last resort) - KDE native tool, provides KDE integration when needed

**User-Selectable Dialog Tool** (Enhancement #25):
Users can manually override the automatic priority system by setting `DIALOG_TOOL` in the configuration file:
- **Configuration Option**: `DIALOG_TOOL=auto|zenity|yad|kdialog`
- **Default**: `auto` (uses automatic priority system)
- **Implementation**:
  - `get_dialog_tool_config()` in `lib/config.sh` reads the user preference from config file
  - `check_dialog_tool()` in `lib/desktop-environment.sh` accepts optional `user_preference` parameter
  - If user preference is set and tool is installed, that tool is used
  - If user preference is set but tool is not installed, system falls back to automatic priority with warning logged
  - If user preference is `auto` or not set, automatic priority system is used
- **Backward Compatibility**: All existing callers of `check_dialog_tool()` continue to work without modification (optional second parameter)
- **Configuration Wizard**: Menu option 11 allows users to select dialog tool interactively, showing:
  - Current setting
  - Recommended tool (based on automatic priority)
  - List of installed tools with descriptions
  - Validation that selected tool is installed
- **Status Display**: `status.sh` shows current dialog tool selection (user-selected or automatic) and lists installed tools

**Tool Capabilities**:
- **YAD**: Best positioning support (native `--geometry` flag), native Wayland support, reliable window sizing, superior window management
- **Zenity**: Standard GTK dialog, good compatibility, limited positioning support (post-creation repositioning only)
- **KDialog**: KDE integration, limited positioning and sizing support (post-creation repositioning only)

**Use Cases for Manual Selection**:
- Troubleshooting issues with automatically selected tool
- Testing different tools to diagnose problems
- Working around tool-specific bugs or limitations
- Personal preference for specific tool

**Fallback Behavior**:
- If user-selected tool becomes unavailable (e.g., uninstalled), system automatically falls back to automatic priority
- Warning is logged when fallback occurs
- System continues to work normally with best available tool

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
   - **Timing Accuracy**: Uses wall-clock time tracking (Unix timestamps) instead of sleep iterations to prevent drift accumulation
     - Records start timestamp when countdown begins
     - Calculates elapsed time from actual wall-clock time each iteration
     - Prevents timing drift that could occur if `sleep 1` takes longer than 1 second due to system load
     - Ensures accurate countdown completion even under high system load
   - **Update Frequency**:
     - For `POPUP_MIN_DISPLAY_TIME ≤ 30 seconds`: Updates every 10 seconds
     - For `POPUP_MIN_DISPLAY_TIME > 30 seconds`: Updates at 75%, 50%, 25%, and 0% remaining
   - **Threshold Tracking**: Uses threshold crossing detection (not exact matches) to handle wall-clock time updates correctly

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

## Auto-Close Popup Window Feature (Enhancement #15)

**Description**: Automatically closes the popup window 10 seconds after the minimum display time completes, providing a non-interactive option for warning dismissal.

**Configuration**:
- Setting: `POPUP_AUTO_CLOSE` in config file
- Values: `true` or `false` (default: `true` - enabled by default)
- Configurable via configuration wizard (Window Behavior menu option)

**Implementation Summary**:
- Uses process termination (SIGTERM, then SIGKILL if needed) to close popup after fixed 10-second delay
- Timer starts after minimum display time completes (or immediately if minimum display time is 0)
- Works on all platforms (X11, Wayland, gamescope) since it uses process termination rather than window management tools
- Integrates with minimum display time and pause button features
- Auto-close delay is fixed at 10 seconds and cannot be configured

**For detailed implementation information**, including timer mechanism, process termination methods, platform compatibility, logging, limitations, and testing requirements, see [enhancements/enhancement-15-auto-close-popup-window.md](enhancements/enhancement-15-auto-close-popup-window.md).

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

**SteamOS Desktop Mode Testing**:
- Limited testing indicates popups work with some full-screen games in SteamOS Desktop Mode (X11 environment)
- Results vary by game - some full-screen games allow popups to appear, while exclusive full-screen games may still block them
- No guarantees can be made for all games, as behavior depends on individual game implementation

**For detailed SteamOS Gaming Mode compatibility information**, including specific considerations, limitations, and solutions, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#full-screen-application-compatibility).

**Implemented Solutions**:
1. **Multi-tool support**: System supports yad, zenity, and kdialog with unified priority (YAD → Zenity → KDialog)
   - **YAD**: Preferred choice - native positioning, reliable sizing, better window management
   - **Zenity**: Reliable fallback - pre-installed on most systems, good cross-platform compatibility
   - **KDialog**: Last resort - KDE native tool, provides KDE integration when needed
   - **Unified Priority**: Same priority across all environments (including KDE) - technical advantages take precedence
2. **Window manager tools**: Implemented using `wmctrl` or `xdotool` for stay-on-top functionality
   - Uses `xprop _NET_WM_STATE_ABOVE` for reliable on-top behavior
   - Confirmed working with all dialog tools on KDE/KWin
   - Requires X11 (not available on Wayland/gamescope)
3. **Periodic enforcement**: Background process continuously reapplies stay-on-top settings
4. **Positioning Simplification**: Only `center` and `top-left` positions supported
   - Center: Default fallback, works with all tools
   - Top-left: Simple fixed margins, no window size calculations required

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
1. **GUI Interface**: Primary interface uses dialog abstraction layer (yad/zenity/kdialog) for dialogs
   - System automatically detects available dialog tool using unified priority (YAD → Zenity → KDialog)
   - Dialog abstraction functions in `lib/configure-dialogs.sh` provide tool-agnostic interface
   - Welcome dialog explaining the process
   - Day-by-day hour selection dialogs
   - Summary dialog showing all configured hours
   - Confirmation dialog before saving
   - Multi-column list dialogs for menus and visual grid

2. **Input Collection**:
   - For each day (Sunday through Saturday), prompt for:
     - Start hour (0-23) using dialog abstraction functions (`show_entry_dialog`)
     - End hour (0-23) using dialog abstraction functions
   - Provide option to skip day (no restrictions)
   - Provide option to apply weekday settings to all weekdays at once
   - Provide option to apply weekend settings to both weekend days at once

3. **Validation**:
   - Ensure hours are in range 0-23
   - Ensure start hour < end hour (for normal ranges)
   - Validate overnight ranges (start > end)
   - Provide clear error messages for invalid input
   - Allow user to correct mistakes
   - **24/7 Restriction Prevention**: Validates total restriction coverage to prevent accidental lockout (see section below)

4. **Config File Writing**:
   - Write in the day-based format: `DAY=START_HOUR-END_HOUR`
   - Preserve existing comments if config file exists
   - Create backup of existing config before overwriting (optional)
   - Write to `~/.config/sleep-warning/config/sleep-warning.conf` (Enhancement #18)

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

## Restriction validation (per-day cap + weekly backstop)

The configuration wizard enforces the safety contract in [docs/SAFETY.md](../../docs/SAFETY.md).

**Primary enforcer — per-day cap** (`lib/daily-caps.sh`, `check_daily_caps`):
- On each calendar day, **restriction**, **configure-block**, and **uninstall-block** categories are checked independently.
- Merged coverage per category must be ≤ 960 minutes (16 hours) per calendar day.
- Violations **hard-block** save in the wizard; there is no override.

**Defense in depth — weekly 24/7 backstop** (`lib/configure-validation.sh`, `check_restriction_coverage`):
- Blocks saves when merged weekly totals indicate effective 24/7 lockout (≥ 10080 minutes across merged hour types).
- May warn on high weekly totals between thresholds; the **per-day cap** is authoritative for any single calendar day.

**Implementation summary**:
- Validation runs when the user attempts to save (configure wizard review/save path).
- Holistic merge across restriction, config lock, and uninstall lock hours; overnight and cross-day overlaps deduplicated.
- Handles integer-hour (`7-23`) and `HH:MM` (`07:00-23:00`) formats consistently.

**For historical enhancement context**, see [enhancements/enhancement-22-prevent-24-7-restriction-configuration.md](enhancements/enhancement-22-prevent-24-7-restriction-configuration.md).

## Config File Locking (Enhancement #18)

Config file locking is a deterrence feature that makes the configuration file and directory read-only during restricted hours and configured lock hours. This prevents users from easily modifying settings during times they've chosen to restrict.

**Implementation Summary**:
- **Option A (Dedicated Config Directory)**: Locks both config directory (`chmod 555`) and config file (`chmod 444`) for stronger deterrence
- **Module**: `lib/config-locking.sh` with functions for lock state management, permission storage/restoration, and self-healing
- **Self-Healing**: Runs on every timer tick to detect and restore tampering (config file deletion, permission changes)
- **Integration**: Applied in `sleep-warning.sh` before restriction checking; checked in `configure.sh` before allowing edits; bypassed in `uninstall.sh` for safety
- **Migration**: Automatically migrates config from `~/.config/sleep-warning/sleep-warning.conf` to `~/.config/sleep-warning/config/sleep-warning.conf` during installation
- **Safety Features**: Automatically disabled if per-day caps would be violated at runtime; uninstall script always works even during lock hours
- **Limitations**: Deterrence-only feature; can be bypassed by stopping timer or changing permissions manually

**For detailed implementation information**, including architecture, lock mechanism, lock state management, self-healing mechanism, integration points, migration process, safety features, edge cases, limitations, and testing, see [enhancements/enhancement-18-config-file-locking.md](enhancements/enhancement-18-config-file-locking.md).

## Management/Help Script Details

The `manage.sh` script provides a central interface for managing and understanding the sleep warning system.

**Implementation Approach:**
1. **Main Menu**: Use multi-column list dialog abstraction or text menu for options
   - Each option launches a specific function
   - Menu should be easy to navigate

2. **Service Status Function**:
   - Check if timer is enabled: `systemctl --user is-enabled sleep-warning.timer`
   - Check if timer is active: `systemctl --user is-active sleep-warning.timer`
   - Get next trigger: `systemctl --user list-timers sleep-warning.timer`
   - Display in user-friendly format

3. **Configuration View Function**:
   - Read and display `~/.config/sleep-warning/config/sleep-warning.conf`
   - Format nicely for display
   - Show in text info dialog abstraction or `less` for text mode

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
   - Copies default config to `~/.config/sleep-warning/config/sleep-warning.conf` (only if file doesn't exist, to preserve user customizations)
   - Copies systemd service and timer files to `~/.config/systemd/user/`
   - Sets executable permissions on all scripts

4. **Service Activation**:
   - Reloads systemd user daemon
   - Enables timer to start on boot
   - Starts timer immediately
   - Verifies timer is active and scheduled

5. **Mode-Specific Service Configuration** (Enhancement #4):
   - Automatically detects system mode (Desktop Mode vs Gaming Mode)
   - Creates systemd drop-in files for mode-specific environment variables
   - Desktop Mode: Sets `DISPLAY` environment variable
   - Gaming Mode: Sets `DISPLAY=:0` and `WAYLAND_DISPLAY`
   - Service works without mode-specific configuration (backward compatible)
   - Users can manually reconfigure via `sleep-warning-configure` (option 12)
   - For details, see [enhancements/enhancement-04-systemd-service-environment-detection.md](enhancements/enhancement-04-systemd-service-environment-detection.md)

6. **User Experience**:
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
8. **Pause Status**: Shows pause feature status (enabled/disabled, current pause state, duration)
9. **Uninstall Information**: Explains uninstall process
10. **Help and Information**: Provides overview and usage information
11. **GUI and Text Modes**: Works with GUI (zenity/yad/kdialog) or text menu

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
- View pause status
- Uninstall information
- Help and information
- Exit

## Systemd Service Environment Detection (Enhancement #4)

### Overview

The system automatically detects whether it's running in **Desktop Mode** (X11/KDE Plasma) or **Gaming Mode** (Wayland/gamescope) and configures the systemd service accordingly. This ensures optimal service configuration, environment variable setup, and dependency management for each mode.

### Implementation Approach

**Drop-in File Approach**: The system uses systemd drop-in files (`.d/` directory) to configure mode-specific environment variables without modifying the base service file. This is non-destructive and allows easy mode switching.

**Location**: Drop-in files are created in `~/.config/systemd/user/sleep-warning.service.d/`
- `mode-desktop.conf` - Desktop Mode configuration
- `mode-gaming.conf` - Gaming Mode configuration

### Mode Detection

The system uses `detect_system_mode()` function in `lib/display-detection.sh` to determine the current mode:

1. **Primary Detection**: Checks for gamescope process (strongest indicator of Gaming Mode)
2. **Secondary Detection**: Uses display environment detection (`detect_display_environment()`)
   - X11 detected → Desktop Mode
   - Wayland/gamescope detected → Gaming Mode
3. **Fallback**: Uses `loginctl` session type if display detection is unavailable

**Returns**: `"desktop"`, `"gaming"`, or `"unknown"` (with fallback behavior)

### Service Configuration

**Desktop Mode Configuration**:
- Sets `Environment=DISPLAY=:0` (or detected display value)
- Ensures X11 display is available to the service

**Gaming Mode Configuration**:
- Sets `Environment=DISPLAY=:0` (gamescope overlay Xwayland)
- Sets `Environment=WAYLAND_DISPLAY` to the detected Wayland socket
- Does not set `GAMESCOPE_SESSION`. Session detection uses the live desktop name or the `gamescope` process

### Integration Points

1. **Installation** (`install.sh`):
   - Automatically detects mode during installation
   - Creates appropriate drop-in file
   - Logs detected mode in installation summary

2. **Configuration** (`configure.sh`):
   - Menu option 12: "Service Mode Configuration"
   - Allows manual reconfiguration if mode changes
   - Shows current detected mode and service configuration status

3. **Service Startup** (`sleep-warning.sh`):
   - Logs detected mode at startup
   - Includes mode information in warning trigger logs

### Backward Compatibility

- Service works without mode-specific configuration (uses environment inheritance)
- Existing installations continue to work
- Script's internal display detection still functions independently
- Drop-in files are optional enhancements, not requirements

### Functions

**Mode Detection** (`lib/display-detection.sh`):
- `detect_system_mode()` - Detects Desktop Mode vs Gaming Mode
- `get_mode_display_identifier()` - Gets display identifier for detected mode

**Service Configuration** (`lib/service-config.sh`):
- `configure_service_for_mode()` - Main configuration function
- `create_service_dropin()` - Creates mode-specific drop-in files
- `remove_service_dropin()` - Removes drop-in files
- `get_current_service_mode()` - Gets current service configuration
- `get_service_dropin_path()` - Gets drop-in directory path

### Error Handling

- **Unknown Mode**: Service uses default configuration (backward compatible)
- **Permission Errors**: Function logic verified even if file writes fail
- **Mode Transitions**: Users can manually reconfigure via `sleep-warning-configure`
- **Non-SteamOS Systems**: Mode detection works on any Linux system (may return "unknown")

### Testing

Automated test suite: `tests/test-mode-detection.sh` (15 tests, all passing)
- Module existence and function existence
- Syntax validation
- Mode detection logic
- Service configuration operations
- Error handling

For detailed implementation information, see [enhancements/enhancement-04-systemd-service-environment-detection.md](enhancements/enhancement-04-systemd-service-environment-detection.md).

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

3. **Fallback Options**: Implement comprehensive fallback dialog tools with unified priority
   - **Primary**: `yad` (enhanced GTK dialog, native positioning, reliable sizing, better window management)
   - **Fallback 1**: `zenity` (GTK, works on most systems, pre-installed on SteamOS)
   - **Fallback 2**: `kdialog` (KDE-specific, provides KDE integration when needed)
   - **Fallback 3**: `notify-send` (non-modal, last resort)
   - **Unified Priority**: YAD → Zenity → KDialog across all environments (including KDE)
   - Technical advantages of YAD take precedence over visual consistency considerations

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
