# Sleep Warning System - User Guide

This comprehensive guide covers everything you need to know about using the Sleep Warning System, from basic usage to advanced configuration and troubleshooting.

## Table of Contents

1. [Overview](#overview)
2. [Quick Reference](#quick-reference)
3. [Configuration Guide](#configuration-guide)
4. [Managing the Service](#managing-the-service)
5. [Understanding Logs](#understanding-logs)
6. [Common Use Cases](#common-use-cases)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Topics](#advanced-topics)

## Overview

### What Is the Sleep Warning System?

The Sleep Warning System is a background service that monitors your computer usage and displays warning popups when you're using your system during configured "restricted hours" (typically late night or early morning). It helps you maintain healthy sleep schedules by making you aware of late-night computer usage.

### How It Works

1. **Background Timer**: A systemd timer runs automatically and checks every 10 minutes (configurable)
2. **Time Check**: The system checks if the current time falls within your configured restricted hours
3. **Warning Display**: If you're using the computer during restricted hours, a modal popup appears
4. **User Interaction**: The popup requires acknowledgment and must remain visible for a minimum time (configurable)
5. **Auto-Close** (Optional): The popup automatically closes 10 seconds after minimum display time completes (enabled by default)
6. **Pause Feature** (Optional): Users can pause warning popups for 5 or 10 minutes once per day directly from the warning popup

### Key Concepts

- **Restricted Hours**: Time periods when warnings will appear (configured per day of week)
- **Check Interval**: How often the system checks for restricted hours (default: 10 minutes)
- **Minimum Display Time**: How long the popup must remain visible before it can be closed (default: 30 seconds)
- **Auto-Close**: Popup automatically closes 10 seconds after minimum display time completes (enabled by default)
- **Popup Behavior**: Modal, stays on top, optionally immovable during minimum display time
- **Pause Feature**: One-time pause option (5 or 10 minutes) available once per day from the warning popup

## Quick Reference

### Essential Commands

```bash
# Configuration
sleep-warning-configure          # Configure restricted hours and settings

# Status and Management
sleep-warning-status             # View current status and configuration
sleep-warning-manage              # Interactive management menu

# Service Control (direct commands)
systemctl --user status sleep-warning.timer    # Check timer status
systemctl --user stop sleep-warning.timer       # Stop temporarily
systemctl --user start sleep-warning.timer      # Start again
systemctl --user disable sleep-warning.timer    # Disable (won't start on boot)
systemctl --user enable sleep-warning.timer     # Enable (will start on boot)

# Logs
tail ~/.config/sleep-warning/warnings.log      # View user log file
journalctl --user -u sleep-warning.service      # View systemd journal

# Uninstall
sleep-warning-uninstall          # Remove the system
manual-uninstall-guide          # Manual uninstall instructions (always available)
```

### File Locations

- **Configuration**: `~/.config/sleep-warning/config/sleep-warning.conf` (older installs may have `~/.config/sleep-warning/sleep-warning.conf`)
- **User Log**: `~/.config/sleep-warning/warnings.log`
- **Main Script**: `~/.local/bin/sleep-warning.sh`
- **Service File**: `~/.config/systemd/user/sleep-warning.service`
- **Timer File**: `~/.config/systemd/user/sleep-warning.timer`

## Configuration Guide

### Using the Configuration Wizard

The easiest way to configure the system is using the interactive wizard:

```bash
sleep-warning-configure
```

**Menu Options:**
- Timer Settings - Configure check interval (1-60 minutes)
- Window Behavior - Configure popup size (including new xsmall, xlarge, max options and percentage-based sizing), position, minimum display time, immovable setting, and auto-close
- Weekdays/Weekends Configuration - Set restricted hours
- Visual Day/Time Grid - View and edit all days at once (recommended!)
- Security Settings - Configure blocking of configure.sh and manage.sh during restricted/lock hours
- Lock Hours Configuration - Configure additional hours when configuration/management is blocked
- Uninstall Protection - Configure protection mode for uninstall.sh during restricted hours
- Uninstall Lock Hours Configuration - Configure additional hours when difficult uninstall verification is required
- Enable pause and configure duration - Configure pause feature for warning popups
- Review and Save - Review your configuration before saving

The **Visual Day/Time Grid** shows all 7 days at once with time ranges in human-readable format and allows quick editing of any day.

For detailed information about the configuration wizard, see [CONFIGURATION.md](CONFIGURATION.md#editing-the-configuration-file).

### Manual Configuration

You can also edit the configuration file directly:

```bash
nano ~/.config/sleep-warning/config/sleep-warning.conf
```

**Configuration File Format:**

```
# Check interval (minutes)
CHECK_INTERVAL=10

# Popup size mode: fixed (pixels) or display-based (percentage of screen)
POPUP_SIZE_MODE=fixed
# Popup size: xsmall, small, medium, large, xlarge, max, or custom (WIDTHxHEIGHT or WIDTH%xHEIGHT%)
POPUP_SIZE=medium

# Popup position: center or top-left
POPUP_POSITION=center

# Minimum display time (seconds, 0-300)
POPUP_MIN_DISPLAY_TIME=30

# Prevent window movement (true/false)
POPUP_IMMOVABLE=true

# Auto-close popup window (true/false)
# Automatically closes popup 10 seconds after minimum display time completes
POPUP_AUTO_CLOSE=true

# Restricted hours (12h or 24h format: START-END)
SUNDAY=1:00am-5:00am
MONDAY=0:00-5:00
TUESDAY=0:00-5:00
WEDNESDAY=0:00-5:00
THURSDAY=0:00-5:00
FRIDAY=0:00-5:00
SATURDAY=1:00am-5:00am
```

**See [CONFIGURATION.md](CONFIGURATION.md) for complete configuration documentation.**

### Time Range Examples

**Single Range:**
```
MONDAY=11:30pm-5:30am # 11:30 PM to 5:30 AM (overnight)
TUESDAY=22:00-23:30    # 10:00 PM to 11:30 PM
```

**Multiple Ranges (comma-separated):**
```
MONDAY=0:00-5:00,22:00-23:00  # Midnight to 5:00 AM AND 10 PM to 11 PM
```

**Overnight Ranges (spans midnight):**
```
MONDAY=11:00pm-6:00am       # Monday 11:00 PM → Tuesday 6:00 AM
```

**No Restrictions:**
```
SUNDAY=           # Leave empty or omit the line
```

### Configuration Examples

For complete configuration examples including student schedules, work schedules, weekend-only restrictions, and multiple time ranges per day, see [CONFIGURATION.md](CONFIGURATION.md#configuration-examples-for-different-use-cases).

## Managing the Service

### Using the Management Menu

The easiest way to manage the service is using the interactive menu:

```bash
sleep-warning-manage
```

**Menu Options:**
- **View Service Status** - See if the service is running and enabled
- **View Current Configuration** - Display your current settings
- **Configure Restricted Hours** - Launch the configuration wizard
- **Temporarily Disable Service** - Stop warnings (can be re-enabled)
- **Re-enable Service** - Start warnings again
- **View Service Logs** - View systemd journal logs
- **View Pause Status** - View pause feature status (enabled/disabled, current pause state, duration)
- **Uninstall Information** - Display instructions on how to uninstall the system
- **Help and Information** - Get help and usage information

### Direct Service Control

**Check Status:**
```bash
systemctl --user status sleep-warning.timer
```

**Stop Temporarily:**
```bash
systemctl --user stop sleep-warning.timer
```
Warnings stop immediately but will resume on next boot.

**Disable (Stop and Prevent Auto-Start):**
```bash
systemctl --user disable sleep-warning.timer
systemctl --user stop sleep-warning.timer
```
Warnings stop immediately and won't start on boot.

**Re-enable:**
```bash
systemctl --user enable sleep-warning.timer
systemctl --user start sleep-warning.timer
```

**Reload Configuration:**
If you manually edited the configuration file and changed `CHECK_INTERVAL`, reload the timer:
```bash
systemctl --user daemon-reload
```

### Understanding Service States

**Active (running)**: Timer is running and checking for restricted hours
**Inactive (dead)**: Timer is stopped
**Enabled**: Timer will start automatically on boot/login
**Disabled**: Timer will not start automatically on boot/login

**Common States:**
- `active (waiting)` + `enabled` = ✅ Working correctly
- `inactive (dead)` + `enabled` = ⚠️ Stopped but will start on boot
- `inactive (dead)` + `disabled` = ❌ Not running and won't start on boot

## Understanding Logs

### Log File Locations

The system creates logs in two places:

1. **User Log File** (most useful for troubleshooting):
   ```
   ~/.config/sleep-warning/warnings.log
   ```

2. **Systemd Journal** (service execution logs):
   ```bash
   journalctl --user -u sleep-warning.service
   ```

### Viewing Logs

**View User Log File:**
```bash
# View last 20 lines
tail -n 20 ~/.config/sleep-warning/warnings.log

# Follow log in real-time
tail -f ~/.config/sleep-warning/warnings.log

# View entire log
cat ~/.config/sleep-warning/warnings.log
```

**View Systemd Journal:**
```bash
# Last 50 entries
journalctl --user -u sleep-warning.service -n 50

# Follow in real-time
journalctl --user -u sleep-warning.service -f

# All entries
journalctl --user -u sleep-warning.service
```

### Log File Format

**User Log File Format:**
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message
```

**Example Log Entries:**
```
[2024-01-15 02:30:15] [WARNING] Restricted time detected - Day: 1, Time: 0230, Range: 00:00-05:00, Display: x11, Display ID: :0
[2024-01-15 02:30:15] [INFO] Display environment: x11, Display ID: :0, Window state: fullscreen, Window title: Game Window
[2024-01-15 02:30:15] [INFO] Using dialog tool: zenity
[2024-01-15 02:30:15] [INFO] Popup displayed successfully (PID: 12345), Dialog tool: zenity, Size: medium, Position: center, Min display time: 30s
[2024-01-15 02:30:45] [INFO] Popup closed by user after minimum display time
```

**Log Levels:**
- `INFO` - Normal operation information
- `WARNING` - Warning messages (restricted hours detected, popup issues)
- `ERROR` - Error messages (missing dependencies, popup failures)

### What Information Is Logged?

**When Restricted Hours Are Detected:**
- Timestamp
- Day of week (0=Sunday, 6=Saturday)
- Current hour (0-23)
- Matched time range
- Display environment (x11, wayland, gamescope)
- Display ID

**When Popup Is Displayed:**
- Display environment type and ID
- Window state (fullscreen, maximized, windowed, unknown)
- Window title (active window when popup appears)
- Dialog tool used (zenity, yad, kdialog)
- Popup size and position
- Minimum display time setting
- Popup process ID (PID)

**When Popup Closes:**
- How popup was closed (user dismissal, timeout, error)
- Exit code (if applicable)
- Whether minimum display time was respected

**Errors and Warnings:**
- Missing dependencies
- Display detection failures
- Dialog tool failures
- Window management issues

### Window State Detection

The system detects the state of the active window when a warning is triggered. This helps troubleshoot why popups might not appear over certain applications.

**Detected Window States:**

**X11 (with xdotool/xprop):**
- `fullscreen` - Window is in fullscreen mode
- `maximized` - Window is maximized (but not fullscreen)
- `windowed` - Window is in normal windowed mode
- `windowed (detection limited)` - Window detected but state couldn't be determined

**Wayland:**
- `fullscreen` - Window is fullscreen (if detected via swaymsg)
- `fullscreen (gamescope)` - Running in gamescope compositor
- `windowed` - Window is in windowed mode (if detected)
- `unknown (wayland - limited detection)` - State couldn't be determined

**Gamescope (SteamOS Gaming Mode):**
- `fullscreen (gamescope)` - Detected gamescope session
- `unknown (gamescope)` - Gamescope detected but state unknown

**Why This Matters:**
- Fullscreen applications may block popups from appearing
- Window state is logged to help diagnose popup visibility issues
- Some window managers handle popups differently based on active window state

### Log Rotation

The user log file automatically rotates when it exceeds 10 MB:
- Log file is truncated to the last 1000 lines
- Old entries are preserved in the truncated file
- No manual intervention required

## Common Use Cases

This section provides guidance on configuring the system for different scenarios. For complete configuration examples with full file contents, see [CONFIGURATION.md](CONFIGURATION.md#configuration-examples-for-different-use-cases).

### Use Case 1: Student with Late Night Study Restrictions

**Goal**: Restrict computer usage after 11 PM on weekdays, but allow later on weekends.

**Approach**: Set weekdays to `23-6` (11 PM to 5:59 AM) and weekends to `1-8` (1 AM to 7:59 AM). Use a 15-minute check interval to reduce system load.

### Use Case 2: Early Morning Work Restrictions

**Goal**: Prevent very early morning usage (before 5 AM) on weekdays only.

**Approach**: Set weekdays to `0-5` (midnight to 4:59 AM), leave weekends unrestricted. Use a small popup in the corner with a shorter minimum display time.

### Use Case 3: Weekend-Only Restrictions

**Goal**: Only restrict usage on weekends, allow free use during weekdays.

**Approach**: Omit weekday restrictions, set weekends to `1-8` (1 AM to 7:59 AM). Use a larger popup with longer display time for weekend warnings.

### Use Case 4: Multiple Time Ranges Per Day

**Goal**: Restrict both late night (10 PM-midnight) and early morning (midnight-5 AM) on weekdays.

**Approach**: Use comma-separated ranges like `0-5,22-23` to create two restricted periods per day. Useful for enforcing both bedtime and wake-up time.

### Understanding Auto-Close Feature

The auto-close feature automatically dismisses warning popups 10 seconds after the minimum display time completes, providing a hands-free option for warning dismissal.

**How Auto-Close Works**:
- **Timing**: Auto-close happens 10 seconds after minimum display time completes (additional time, not total time)
- **Example 1**: If minimum display time is 30 seconds, popup auto-closes after 40 seconds total (30 + 10)
- **Example 2**: If minimum display time is 0 (disabled), popup auto-closes after 10 seconds
- **Fixed Delay**: The 10-second delay is fixed and cannot be configured

**Configuration**:
```
POPUP_AUTO_CLOSE=true   # Enable auto-close (default)
POPUP_AUTO_CLOSE=false  # Disable auto-close (user must close manually)
```

**Behavior**:
- **Enabled by default** - Auto-close is active unless you explicitly disable it
- **Respects minimum display time** - Auto-close only starts after minimum display time completes
- **Manual close cancels timer** - If you close the popup manually, the auto-close timer is automatically cancelled
- **Works on all platforms** - Uses process termination, so it works on X11, Wayland, and gamescope
- **Pause button integration** - Clicking pause closes the popup immediately (before auto-close timer starts)

**Use Cases**:
- **Hands-free operation**: Useful when you want popups to dismiss automatically without manual interaction
- **Reduced interruption**: Provides automatic dismissal after ensuring the warning has been visible for the required time
- **Accessibility**: Helpful for users who prefer automatic dismissal or have difficulty interacting with popups

**Disabling Auto-Close**:
If you prefer to manually close popups, you can disable auto-close:
1. Run `sleep-warning-configure`
2. Select option 2: **Window Behavior**
3. When prompted, choose `false` for auto-close
4. Save your configuration

**See [CONFIGURATION.md](CONFIGURATION.md#auto-close-popup-window) for complete auto-close configuration documentation.**

## Troubleshooting

### Problem: Popup Doesn't Appear

**Symptoms:**
- No popup during restricted hours
- System appears to be running (timer is active)

**Diagnosis Steps:**

1. **Check if it's during restricted hours:**
   ```bash
   sleep-warning-status
   ```
   Verify the current time falls within your configured restricted hours.

2. **Check timer status:**
   ```bash
   systemctl --user status sleep-warning.timer
   ```
   Should show `active (waiting)`.

3. **Check if dialog tool is installed:**
   ```bash
   which zenity
   which yad
   which kdialog
   ```
   At least one should be available.

4. **Check user log file:**
   ```bash
   tail ~/.config/sleep-warning/warnings.log
   ```
   Look for error messages or warnings.

5. **Check systemd journal:**
   ```bash
   journalctl --user -u sleep-warning.service -n 20
   ```
   Look for execution errors.

**Common Causes:**
- Not during restricted hours (check configuration)
- Timer not running (start with `systemctl --user start sleep-warning.timer`)
- No dialog tool installed (install at least one: yad preferred, zenity, or kdialog):
  - **yad** (preferred): `sudo apt install yad` (Ubuntu/Debian), `sudo dnf install yad` (Fedora), `sudo pacman -S yad` (Arch/SteamOS), `sudo zypper install yad` (openSUSE)
  - **zenity** (fallback): `sudo apt install zenity` (Ubuntu/Debian), `sudo dnf install zenity` (Fedora), `sudo pacman -S zenity` (Arch/SteamOS), `sudo zypper install zenity` (openSUSE)
  - **kdialog** (KDE systems): Usually pre-installed on KDE, or `sudo apt install kdialog` (Ubuntu/Debian), `sudo dnf install kdialog` (Fedora), `sudo pacman -S kdialog` (Arch/SteamOS)
- Display not available (not logged into graphical session)
- Full-screen application blocking popup (see "Popup Doesn't Appear Over Full-Screen Games")

### Problem: Popup Doesn't Stay on Top

**Symptoms:**
- Popup appears but gets hidden behind other windows
- Popup doesn't stay visible

**Solution:**
Install window management tools:
```bash
# Ubuntu/Debian
sudo apt install wmctrl xdotool

# Fedora
sudo dnf install wmctrl xdotool

# Arch/Steam OS
sudo pacman -S wmctrl xdotool
```

**Why This Happens:**
- Window management tools (`wmctrl` or `xdotool`) are required for stay-on-top functionality
- Without these tools, popups may appear but won't automatically stay on top
- The system works without these tools but with reduced window management capabilities

### Problem: Popup Doesn't Appear Over Full-Screen Games

**Symptoms:**
- Popup doesn't appear when playing full-screen games
- Works fine with windowed applications

**Possible Causes:**
- Exclusive full-screen games may block window manager dialogs
- Some games capture all input and prevent popups from appearing
- Window manager limitations with full-screen applications

**Solutions:**
1. **Try borderless windowed mode** in your game settings
2. **Check the log file** to see if the popup was attempted:
   ```bash
   tail ~/.config/sleep-warning/warnings.log
   ```
   Look for "Popup displayed successfully" entries.

3. **Verify window state detection:**
   Check the log for window state information. If it shows "fullscreen" or "exclusive", the popup may be blocked by the game.

**Limitations:**
- Some exclusive full-screen games cannot be overlaid by window manager dialogs
- This is a limitation of the windowing system, not the sleep warning system
- SteamOS Gaming Mode may have additional limitations (see SteamOS-specific documentation)

### Problem: Timer Not Starting on Boot

**Symptoms:**
- System works when manually started
- Doesn't start automatically after reboot

**Solution:**
1. **Check if timer is enabled:**
   ```bash
   systemctl --user is-enabled sleep-warning.timer
   ```
   Should return `enabled`.

2. **Enable the timer:**
   ```bash
   systemctl --user enable sleep-warning.timer
   ```

3. **Check user lingering (for systemd user services):**
   ```bash
   loginctl show-user $USER | grep Lingering
   ```
   Should show `Lingering=yes` for user services to start on boot.

4. **Enable lingering (if needed):**
   ```bash
   sudo loginctl enable-linger $USER
   ```

### Problem: Configuration Changes Not Taking Effect

**Symptoms:**
- Changed configuration but behavior hasn't changed
- New restricted hours not being enforced

**Solution:**
1. **Verify configuration file location:**
   ```bash
   cat ~/.config/sleep-warning/config/sleep-warning.conf
   ```
   Check that your changes are saved.

2. **Check if CHECK_INTERVAL changed:**
   If you changed `CHECK_INTERVAL`, reload the systemd timer:
   ```bash
   systemctl --user daemon-reload
   ```

3. **Wait for next check:**
   Changes take effect on the next check (within your configured interval, default 10 minutes).

4. **Manually trigger a check:**
   ```bash
   systemctl --user start sleep-warning.service
   ```
   This runs the check immediately (popup will only appear if during restricted hours).

### Problem: "Command Not Found" Errors

**Symptoms:**
- `sleep-warning-configure` not found
- `sleep-warning-status` not found
- Other commands not found

**Solution:**
1. **Restart your terminal** (PATH is updated in `~/.bashrc`)

2. **Or reload PATH:**
   ```bash
   source ~/.bashrc
   ```

3. **Or use full path:**
   ```bash
   ~/.local/bin/sleep-warning-configure
   ```

4. **Verify installation:**
   ```bash
   ls ~/.local/bin/sleep-warning-*
   ```
   Should show the installed scripts.

### Troubleshooting Decision Tree

```
Is popup appearing?
├─ No
│  ├─ Is it during restricted hours?
│  │  ├─ No → Normal behavior (no popup outside restricted hours)
│  │  └─ Yes → Continue
│  ├─ Is timer running?
│  │  ├─ No → Start timer: systemctl --user start sleep-warning.timer
│  │  └─ Yes → Continue
│  ├─ Is dialog tool installed?
│  │  ├─ No → Install: sudo apt install zenity
│  │  └─ Yes → Continue
│  ├─ Check log file for errors
│  └─ Check systemd journal for errors
│
└─ Yes, but...
   ├─ Doesn't stay on top
   │  └─ Install window tools: sudo apt install wmctrl xdotool
   ├─ Doesn't appear over full-screen games
   │  ├─ Try borderless windowed mode
   │  └─ Check log for window state (may be blocked by game)
   └─ Closes too quickly
      └─ Increase POPUP_MIN_DISPLAY_TIME in configuration
```

## Advanced Topics

### Manual Script Execution

You can run the main script manually for testing:

```bash
~/.local/bin/sleep-warning.sh
```

**Note**: The popup will only appear if:
1. Current time is within restricted hours, AND
2. A display is available (graphical session)

If conditions aren't met, the script exits silently (this is normal).

### Testing During Non-Restricted Hours

To test the popup during non-restricted hours, temporarily modify your configuration:

1. **Edit configuration:**
   ```bash
   nano ~/.config/sleep-warning/config/sleep-warning.conf
   ```

2. **Add a test range that includes current time:**
   ```
   MONDAY=14-15    # 2:00 PM to 2:59 PM (example)
   ```

3. **Run script manually:**
   ```bash
   ~/.local/bin/sleep-warning.sh
   ```

4. **Restore original configuration after testing**

### Customizing Warning Messages

Currently, warning messages are not customizable via configuration. The default message is:
```
"⚠️ Late Night Usage Detected

You are using your computer during restricted hours.
Please consider getting some rest."
```

Future versions may support custom messages per day or time range.

### Performance Considerations

**Check Interval Impact:**
- Shorter intervals (1-5 minutes) = More frequent checks = More system resource usage
- Longer intervals (15-60 minutes) = Less frequent checks = Less system resource usage
- Default (10 minutes) = Good balance

**Recommended Settings:**
- **High-performance systems**: 5-10 minutes
- **Standard systems**: 10-15 minutes
- **Low-resource systems**: 15-30 minutes

**Popup Display Impact:**
- Popups are lightweight (GTK dialogs)
- Minimal performance impact when displayed
- No impact when not displayed (during non-restricted hours)

### SteamOS Gaming Mode Compatibility

**Current Status**: ⚠️ Partially Compatible - Requires Testing

**Desktop Mode:**
- Uses X11 (KDE Plasma), enabling full window management features
- Limited testing indicates popups work with some full-screen games in Desktop Mode, but results vary by game
- Exclusive full-screen games may still block popups
- No guarantees can be made for all games

**Gaming Mode Known Limitations:**
- Display detection in gamescope (Wayland compositor) may be limited
- Exclusive full-screen games may block popups
- Window management tools don't work on Wayland
- Always-on-top behavior is best-effort on Wayland/gamescope and may not work
- If dialog popups fail, a non-modal notification fallback may be used (notify-send)

**For Best Results:**
- Use borderless windowed mode in games
- Install window management tools (may help on some systems)
- Check logs to diagnose issues

**See [../dev-docs/STEAMOS_GAMING_MODE.md](../dev-docs/STEAMOS_GAMING_MODE.md) for detailed Gaming Mode compatibility information.**

### Multiple User Sessions

The system runs as a user service, meaning:
- Each user has their own configuration
- Each user's timer runs independently
- Warnings appear only for the user whose session is active

**To configure for multiple users:**
1. Log in as each user
2. Run `sleep-warning-configure` for each user
3. Each user will have their own configuration file

### Backup and Restore Configuration

**Backup:**
```bash
cp ~/.config/sleep-warning/config/sleep-warning.conf ~/sleep-warning-backup.conf
```

**Restore:**
```bash
cp ~/sleep-warning-backup.conf ~/.config/sleep-warning/config/sleep-warning.conf
```

**Note**: After restoring, changes take effect on the next check (within configured interval).

### Uninstalling the System

#### Standard Uninstallation

To uninstall the Sleep Warning System, use the uninstall script:

```bash
sleep-warning-uninstall
```

or

```bash
~/.local/bin/sleep-warning-uninstall
```

**What the uninstall script does:**
- Stops and disables the systemd timer
- Removes the systemd service and timer files
- Removes the main script files
- Removes the configuration file and logs (with confirmation)
- Provides a summary of what was removed

**Note**: The uninstall script will ask for confirmation before removing configuration files and logs, so you can preserve your settings if desired.

#### Uninstall Protection During Restricted Hours

If you have enabled uninstall protection (`UNINSTALL_PROTECTION_MODE=difficult` in your configuration), the uninstall script will require verification when run during restricted hours or uninstall lock hours:

1. **Confirmation Phrase**: You must type the exact phrase: "I really mean it and want to uninstall this program now even though restrictions are running"
2. **Arithmetic Questions**: You must correctly answer 10 arithmetic questions written in word form

This verification process is designed to prevent impulsive uninstallation during restricted hours while still allowing legitimate uninstalls if you complete the verification.

**When Verification is Required**:
- During your configured restriction hours, OR
- During your configured uninstall lock hours (if any are set)

**If you are not in restriction hours or uninstall lock hours**, uninstallation works normally without verification.

**See [CONFIGURATION.md](CONFIGURATION.md#uninstall-protection-during-restricted-hours) and [CONFIGURATION.md](CONFIGURATION.md#additional-uninstall-lock-hours) for more information about uninstall protection and uninstall lock hours.**

#### Manual Uninstall Guide

If you need to uninstall the system during restricted hours and find the verification process too difficult, or if the uninstall script is not working, you can use the manual uninstall guide:

```bash
manual-uninstall-guide
```

or

```bash
~/.local/bin/manual-uninstall-guide
```

**What the manual uninstall guide provides:**
- Step-by-step instructions for manually uninstalling the system
- Commands to stop and disable the systemd timer
- List of all files and directories to remove
- Copy-paste ready commands for easy execution

**Important Notes:**
- The manual uninstall guide is **always accessible** - it is never blocked, even during restricted hours
- It provides instructions only - you must execute the commands yourself
- Use this guide if:
  - The uninstall script requires verification and you prefer manual steps
  - The uninstall script is not working or unavailable
  - You want to understand exactly what files are being removed

**The manual uninstall guide will show you:**
1. How to stop and disable the systemd timer
2. How to remove systemd service and timer files
3. How to remove configuration files and logs
4. How to remove installed script files
5. Exact file paths for your installation

## Additional Resources

- **[README.md](../README.md)** - Project overview and quick reference
- **[GETTING_STARTED.md](../GETTING_STARTED.md)** - Step-by-step installation guide
- **[CONFIGURATION.md](CONFIGURATION.md)** - Complete configuration reference
- **[../dev-docs/TECHNICAL_DETAILS.md](../dev-docs/TECHNICAL_DETAILS.md)** - Technical implementation details
- **[../dev-docs/STEAMOS_GAMING_MODE.md](../dev-docs/STEAMOS_GAMING_MODE.md)** - SteamOS Gaming Mode compatibility

## Getting Help

If you encounter issues not covered in this guide:

1. **Check the logs:**
   ```bash
   tail ~/.config/sleep-warning/warnings.log
   journalctl --user -u sleep-warning.service
   ```

2. **Use the management menu:**
   ```bash
   sleep-warning-manage
   ```

3. **Check the troubleshooting section** in this guide

4. **Review the README** for common issues

5. **Check GitHub Issues** (if applicable) for known issues and solutions

---

**Last Updated**: Based on current implementation as of documentation creation.
