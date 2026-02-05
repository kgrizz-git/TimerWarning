# Sleep Warning System - Log Reference

This document provides comprehensive information about the Sleep Warning System logs, including log file locations, formats, and how to interpret log entries.

**Related Documentation:**
- [USER_GUIDE.md](USER_GUIDE.md) - Complete user guide with troubleshooting
- [CONFIGURATION.md](CONFIGURATION.md) - Configuration file format and options
- [README.md](../README.md) - Project overview and quick start

## Log File Locations

The system creates logs in two places:

1. **User Log File** (most useful for troubleshooting):
   ```
   ~/.config/sleep-warning/warnings.log
   ```

2. **Systemd Journal** (service execution logs):
   ```bash
   journalctl --user -u sleep-warning.service
   ```

## Viewing Logs

### View User Log File

```bash
# View last 20 lines
tail -n 20 ~/.config/sleep-warning/warnings.log

# Follow log in real-time
tail -f ~/.config/sleep-warning/warnings.log

# View entire log
cat ~/.config/sleep-warning/warnings.log
```

### View Systemd Journal

```bash
# Last 50 entries
journalctl --user -u sleep-warning.service -n 50

# Follow in real-time
journalctl --user -u sleep-warning.service -f

# All entries
journalctl --user -u sleep-warning.service
```

## Log File Format

### User Log File Format

**Format:**
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

### Log Levels

- **`INFO`** - Normal operation information
- **`WARNING`** - Warning messages (restricted hours detected, popup issues)
- **`ERROR`** - Error messages (missing dependencies, popup failures)

## What Information Is Logged?

### When Restricted Hours Are Detected

The system logs the following information when restricted hours are detected:

- **Timestamp** - Exact date and time when restriction was detected
- **Day of week** - Numeric day (0=Sunday, 6=Saturday)
- **Current hour** - Hour in 24-hour format (0-23)
- **Matched time range** - The configured time range that matched (e.g., "00:00-05:00")
- **Display environment** - Type of display protocol (x11, wayland, gamescope)
- **Display ID** - Display identifier (e.g., ":0" for X11)

**Example:**
```
[2024-01-15 02:30:15] [WARNING] Restricted time detected - Day: 1, Time: 0230, Range: 00:00-05:00, Display: x11, Display ID: :0
```

### When Popup Is Displayed

When a warning popup is displayed, the system logs:

- **Display environment type and ID** - X11, Wayland, or gamescope with display identifier
- **Window state** - State of active window (fullscreen, maximized, windowed, unknown)
- **Window title** - Title of the active window when popup appears
- **Dialog tool used** - Which dialog tool was used (zenity, yad, kdialog)
- **Popup size and position** - Configured size (xsmall, small, medium, large, xlarge, max, or custom) and position (center, top-left)
- **Minimum display time setting** - How long popup must remain visible (in seconds)
- **Popup process ID (PID)** - Process ID of the popup dialog process

**Example:**
```
[2024-01-15 02:30:15] [INFO] Display environment: x11, Display ID: :0, Window state: fullscreen, Window title: Game Window
[2024-01-15 02:30:15] [INFO] Using dialog tool: zenity
[2024-01-15 02:30:15] [INFO] Popup displayed successfully (PID: 12345), Dialog tool: zenity, Size: medium, Position: center, Min display time: 30s
```

### When Popup Closes

When a popup closes, the system logs:

- **How popup was closed** - User dismissal, timeout, error, or auto-close
- **Exit code** - Process exit code (if applicable)
- **Whether minimum display time was respected** - Whether popup remained visible for required duration

**Example:**
```
[2024-01-15 02:30:45] [INFO] Popup closed by user after minimum display time
```

### Errors and Warnings

The system logs various errors and warnings:

- **Missing dependencies** - When required tools are not found (zenity, yad, kdialog, wmctrl, xdotool)
- **Display detection failures** - When display environment cannot be detected
- **Dialog tool failures** - When dialog tools fail to display popups
- **Window management issues** - When window management tools fail or are unavailable

**Example:**
```
[2024-01-15 02:30:15] [ERROR] Dialog tool not found: zenity, yad, kdialog
[2024-01-15 02:30:15] [WARNING] Window manager tools not available (wmctrl/xdotool) - limited window control
```

## Window State Detection

The system detects the state of the active window when a warning is triggered. This helps troubleshoot why popups might not appear over certain applications.

### Detected Window States

#### X11 (with xdotool/xprop)

- **`fullscreen`** - Window is in fullscreen mode
- **`maximized`** - Window is maximized (but not fullscreen)
- **`windowed`** - Window is in normal windowed mode
- **`windowed (detection limited)`** - Window detected but state couldn't be determined

#### Wayland

- **`fullscreen`** - Window is fullscreen (if detected via swaymsg)
- **`fullscreen (gamescope)`** - Running in gamescope compositor
- **`windowed`** - Window is in windowed mode (if detected)
- **`unknown (wayland - limited detection)`** - State couldn't be determined

#### Gamescope (SteamOS Gaming Mode)

- **`fullscreen (gamescope)`** - Detected gamescope session
- **`unknown (gamescope)`** - Gamescope detected but state unknown

### Why This Matters

- **Fullscreen applications** may block popups from appearing
- **Window state** is logged to help diagnose popup visibility issues
- **Some window managers** handle popups differently based on active window state

**Example:**
```
[2024-01-15 02:30:15] [INFO] Display environment: x11, Display ID: :0, Window state: fullscreen, Window title: Game Window
```

This log entry indicates that the active window was in fullscreen mode when the popup was triggered, which may explain why the popup didn't appear over the game.

## Log Rotation

The user log file automatically rotates when it exceeds 10 MB:

- **Log file is truncated** to the last 1000 lines
- **Old entries are preserved** in the truncated file
- **No manual intervention required** - rotation happens automatically

**Note**: Log rotation preserves recent entries, so you can always see the most recent log activity even after rotation occurs.

## Troubleshooting with Logs

### Common Log Patterns

#### Popup Not Appearing

If popups aren't appearing, check logs for:

1. **Restricted time detection:**
   ```
   [WARNING] Restricted time detected - Day: X, Time: XXXX, Range: ...
   ```
   If this entry is missing, restrictions may not be configured correctly.

2. **Dialog tool availability:**
   ```
   [INFO] Using dialog tool: zenity
   ```
   If this entry is missing or shows an error, dialog tools may not be installed.

3. **Display detection:**
   ```
   [INFO] Display environment: x11, Display ID: :0
   ```
   If display environment is "unknown" or missing, display detection may have failed.

4. **Window state:**
   ```
   [INFO] Window state: fullscreen
   ```
   If window state is "fullscreen", the application may be blocking popups.

#### Configuration Issues

If configuration changes aren't taking effect:

1. **Check for config file errors:**
   ```
   [ERROR] Failed to read config file: ...
   ```
   Indicates configuration file parsing errors.

2. **Check for invalid values:**
   ```
   [WARNING] Invalid configuration value: POPUP_SIZE=invalid, using default: medium
   ```
   Indicates invalid configuration values that were replaced with defaults.

#### Service Issues

If the service isn't running:

1. **Check systemd journal:**
   ```bash
   journalctl --user -u sleep-warning.service -n 50
   ```
   Look for service start/stop messages and errors.

2. **Check timer status:**
   ```bash
   systemctl --user status sleep-warning.timer
   ```
   Verify timer is active and scheduled correctly.

## Additional Resources

- **[USER_GUIDE.md](USER_GUIDE.md)** - Complete user guide with troubleshooting
- **[CONFIGURATION.md](CONFIGURATION.md)** - Configuration file format and options
- **[README.md](../README.md)** - Project overview and quick start
