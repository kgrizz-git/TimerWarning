# Technical Implementation Details

This document provides detailed technical specifications for the Sleep Warning System implementation. For the master plan and detailed checklists, see [linux-warning-system-plan.md](linux-warning-system-plan.md) and the phase plans linked from it.

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
  - `popup-display.sh` - Warning popup display
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
- Reads configuration from `~/.config/sleep-warning/config/sleep-warning.conf` (Enhancement #18)
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
- Uses dialog tools (YAD preferred, Zenity/KDialog fallback) with `--modal` flag to ensure user must interact
- Popup will block until user clicks OK/dismisses
- Supports configurable minimum display time (prevents closing/minimizing for set duration)
- Dialog tool priority: YAD → Zenity → KDialog (unified across all environments)

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

## 24/7 Restriction Prevention

The configuration wizard includes a critical safety feature that prevents users from accidentally configuring restrictions for all 24 hours, 7 days a week, which would effectively lock them out of their computer.

### Overview

**Purpose**: Detect and prevent dangerous restriction configurations that would leave no unrestricted time for the user to modify settings or use their computer.

**Implementation**: Validation runs automatically when the user attempts to save their configuration (in `configure.sh`, case 6: "Review and Save"), after the summary is confirmed but before writing to the config file.

### Validation Algorithm

The validation uses a **holistic time coverage analysis** that evaluates all 7 days together:

1. **Unified Timeline Mapping**: All time ranges are converted to a unified weekly timeline (minutes 0-10079)
   - Day 0 (Sunday): minutes 0-1439
   - Day 1 (Monday): minutes 1440-2879
   - Day 2 (Tuesday): minutes 2880-4319
   - Day 3 (Wednesday): minutes 4320-5759
   - Day 4 (Thursday): minutes 5760-7199
   - Day 5 (Friday): minutes 7200-8639
   - Day 6 (Saturday): minutes 8640-10079

2. **Overnight Range Handling**: Overnight ranges (start hour > end hour, e.g., "23-6") are split into two segments:
   - Segment 1: [start_hour×60, 1440) on current day
   - Segment 2: [0, end_hour×60) on next day
   - Handles wrap-around: Saturday overnight ranges wrap to Sunday

3. **Overlap Detection and Merging**: **Critical** - The system detects and merges overlapping intervals:
   - **Within-day overlaps**: Multiple ranges on the same day (e.g., "0-10,9-23" overlaps at hours 9-10)
   - **Cross-day overlaps**: Overnight ranges overlapping with next day's ranges (e.g., Monday "23-6" and Tuesday "0-5" overlap at hours 0-5)
   - All overlapping intervals are merged to avoid double-counting restricted minutes

4. **Total Calculation**: After merging, total restricted minutes are calculated from all merged intervals

5. **Threshold Comparison**: Total is compared against two thresholds:
   - **THRESHOLD_BLOCK = 10080 minutes** (7 days × 24 hours × 60 minutes)
     - If total >= 10080: Configuration is **blocked** (24/7 detected)
   - **THRESHOLD_WARN = 6720 minutes** (7 days × 16 hours × 60 minutes)
     - If total > 6720 but < 10080: **Warning** shown (high restriction level)
     - If total <= 6720: Configuration is **valid** (proceeds normally)

### Time Range Semantics

**Important**: Hour ranges use **inclusive start, exclusive end** semantics:
- "0-23" covers hours 0-22 (23 hours total: 00:00-22:59)
- "0-5" covers hours 0-4 (5 hours total: 00:00-04:59)
- To cover all 24 hours, use combination like "0-12,12-0" (12 hours + 12 hours = 24 hours)

### Validation Results

The validation function (`check_restriction_coverage()` in `lib/configure-validation.sh`) returns one of three results:

1. **"block"** (24/7 detected, >= 10080 minutes):
   - Error dialog shown: "ERROR: 24/7 Restrictions Detected"
   - Configuration is **blocked from saving**
   - User must modify settings to reduce restriction level
   - Prevents accidental lockout

2. **"warn"** (High restriction level, > 6720 but < 10080 minutes):
   - Warning dialog shown: "Warning: Very High Restriction Level"
   - User can confirm to save anyway or modify settings
   - **Automatic safety overrides applied** if user confirms:
     - Popup size restricted to "small" or "medium" only (if "large" or "fullscreen" was selected)
     - Config locking features automatically disabled (if implemented)
     - Configure.sh blocking automatically disabled (if implemented)
   - Config file includes comments explaining why safety features are disabled

3. **"ok"** (Valid configuration, <= 6720 minutes):
   - Configuration proceeds normally
   - No warnings or restrictions

### Implementation Details

**Module**: `lib/configure-validation.sh`
- `check_restriction_coverage()`: Main validation function
- `merge_overlapping_intervals()`: Interval merging algorithm

**Integration**: Validation is called in `configure.sh` (case 6: "Review and Save") after `show_summary()` confirms but before `write_config()` is called.

**Dialog Functions**: Error and warning dialogs are in `lib/configure-ui.sh`:
- `show_24_7_error()`: Error dialog for 24/7 restrictions
- `show_high_restriction_warning()`: Warning dialog for high restriction levels

**Performance**: 
- Time complexity: O(n log n) where n = total number of time ranges
- Runs once per configuration save (not continuously)
- Minimal memory and CPU overhead

### Edge Cases Handled

- **Empty days**: Counted as 0 restricted minutes
- **Explicitly skipped days**: Days with empty string "" are counted as 0 restricted minutes
- **Multiple ranges per day**: All ranges are processed and merged correctly
- **Overnight ranges**: Correctly split and mapped to unified timeline
- **Week wrap-around**: Saturday overnight ranges correctly wrap to Sunday
- **Boundary cases**: 
  - Exactly 6720 minutes (16 hours/day): returns "ok" (no warning)
  - Exactly 10080 minutes (24/7): returns "block" (prevents saving)
- **Invalid ranges**: Skipped silently (should be caught by format validation first)

### Safety Features

When high restrictions (> 6720 minutes) are detected and user confirms:
- **Popup size restriction**: Automatically limits popup size to "small" or "medium" only
  - Prevents overly intrusive popups when user has very limited unrestricted time
  - Config file comment explains: "POPUP_SIZE has been restricted to small/medium only because restrictions exceed 16 hours/day"
- **Config locking disabled**: Automatically disables config file locking features (if implemented)
  - Prevents users from locking themselves out during very limited unrestricted time
  - Config file comment explains: "CONFIG_LOCK_ENABLED and CONFIGURE_BLOCK_ENABLED are disabled because restrictions exceed 16 hours/day"
- **Transparency**: Config file comments clearly explain why safety features are disabled

### Related Enhancements

- **Enhancement #18 (Config File Locking)**: Automatically disabled if restrictions > 6720 minutes
- **Enhancement #19 (Prevent configure.sh Execution)**: Automatically disabled if restrictions > 6720 minutes
- **Enhancement #20 (Additional Hours for Config Locking)**: Automatically cleared if restrictions > 6720 minutes
- **Enhancement #03 (Enhanced Window Size Options)**: Popup size automatically restricted to small/medium only if restrictions > 6720 minutes

For detailed implementation notes, see [enhancements/enhancement-22-prevent-24-7-restriction-configuration.md](enhancements/enhancement-22-prevent-24-7-restriction-configuration.md).

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
   - Gaming Mode: Sets `WAYLAND_DISPLAY` and `GAMESCOPE_SESSION` environment variables
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
- Sets `Environment=WAYLAND_DISPLAY=wayland-0` (or detected value)
- Sets `Environment=GAMESCOPE_SESSION=1`
- Ensures Wayland display is available to the service

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
