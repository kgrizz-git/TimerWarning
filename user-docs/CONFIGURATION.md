# Sleep Warning System - Configuration File Format

This document describes the configuration file format and all available options for the Sleep Warning System.

**Related Documentation:**
- [README.md](../README.md) - Project overview and quick start
- [GETTING_STARTED.md](../GETTING_STARTED.md) - Step-by-step installation guide
- [USER_GUIDE.md](USER_GUIDE.md) - Complete user guide with troubleshooting

## Installation and Configuration Order

**Important**: Both installation and configuration steps should be completed:

1. **Installation** (`./install.sh`): Sets up the system, installs files, and starts the timer
2. **Configuration** (`sleep-warning-configure` or `./configure.sh`): Customizes restricted hours and settings

**Recommended Order**: Install first, then configure. However, both scripts can be run in any order:
- If you install first, the default configuration will be used until you customize it
- If you configure first, your custom settings will be preserved during installation

Both steps are necessary for a complete setup.

## Configuration File Location

The configuration file is located at:
```
~/.config/sleep-warning/config/sleep-warning.conf
```

If the configuration file does not exist, the system will use default values. You can create the file manually or use the interactive configuration wizard (`configure.sh` or `sleep-warning-configure`).

**Migration note (Enhancement #18)**: Older versions used `~/.config/sleep-warning/sleep-warning.conf`. The installer migrates that file to the new location when upgrading.

## File Format

The configuration file uses a simple key-value format with comments. Lines starting with `#` are comments and are ignored. Empty lines are also ignored.

## Configuration Options

### Restricted Hours

**Format**: `DAY=START_TIME-END_TIME`

**Days**: `SUNDAY`, `MONDAY`, `TUESDAY`, `WEDNESDAY`, `THURSDAY`, `FRIDAY`, `SATURDAY`

**Time Formats**:
- **12-hour format** (e.g., `11:30pm-5:30am`): User-friendly format with AM/PM.
- **24-hour format** (e.g., `23:30-05:30`): Standard 24-hour time.
- **Minute precision**: Both formats support minutes (e.g., `:30`, `:15`).
- **Legacy format**: Hour-only 24-hour format (`23-5`) is still supported and automatically migrated to `23:00-05:00`.

**Examples**:
```
SUNDAY=1:00-5:00     # Sunday: 1:00 AM to 5:00 AM
MONDAY=11:30pm-5:30am # Monday: 11:30 PM to 5:30 AM (overnight)
TUESDAY=0:00-5:00    # Tuesday: Midnight to 5:00 AM
```

**Display Format Preference**:
You can choose your preferred time display format (12-hour or 24-hour) using the `TIME_DISPLAY_FORMAT` option.
- `TIME_DISPLAY_FORMAT=12hour` (Default)
- `TIME_DISPLAY_FORMAT=24hour`

**Timer Interval Considerations**:
When using minute precision (e.g., 11:30 PM), the system's `CHECK_INTERVAL` becomes important.
- If `CHECK_INTERVAL` is large (e.g., 60 minutes), a restriction starting at 11:30 PM might not trigger until 12:00 AM (the next timer check).
- For exact timing with minute-level restrictions, we recommend setting `CHECK_INTERVAL` to 15 or less.
- The configuration wizard and status check will warn you if your interval is too large for your configured minute precision.

**Multiple Ranges per Day**:
You can specify multiple time ranges for a single day by separating them with commas:
```
MONDAY=0-5,22-23  # Monday: Midnight to 4:59 AM AND 10:00 PM to 11:59 PM
```

**Overnight Ranges** (spans midnight):
You can specify time ranges that span midnight by using a start hour greater than the end hour:
```
MONDAY=23-6       # Monday: 11:00 PM to 6:00 AM (spans midnight)
TUESDAY=22-8      # Tuesday: 10:00 PM to 8:00 AM (overnight)
```

**Important - Understanding Overnight Ranges**:
When you specify an overnight range like `23-6` on Monday, it means:
- **Monday 11:00 PM → Tuesday 6:00 AM**

The range starts on the named day and continues into the next day. This is useful for restricting late-night usage that extends past midnight.

**Examples of Overnight Ranges**:
```
MONDAY=23-6       # Monday 11:00 PM → Tuesday 6:00 AM
TUESDAY=22-8      # Tuesday 10:00 PM → Wednesday 8:00 AM
WEDNESDAY=23-5    # Wednesday 11:00 PM → Thursday 5:00 AM
```

**Overlapping Ranges**:
If you set overlapping ranges, the system will detect and warn you. For example:
```
MONDAY=23-5       # Monday 11:00 PM → Tuesday 4:59 AM
TUESDAY=0-5       # Tuesday midnight → 4:59 AM
```

Both ranges cover Tuesday midnight to 4:59 AM. This is harmless (only one warning will be shown during the overlap), but redundant. The configuration wizard will warn you about overlaps when you save your settings.

**24/7 Restriction Prevention and Per-Day Cap (Safety Features)**:
The configuration wizard enforces safety limits so you cannot accidentally lock yourself out of your computer. See [SAFETY.md](../docs/SAFETY.md) for the full contract.

**Per-day 16-hour cap (primary rule)**:
On any single calendar day, each of these categories may cover **at most 16 hours** of merged time (overlapping intervals count once):

| Category | What counts toward the 16 h/day limit |
|----------|---------------------------------------|
| **Restriction** (popup hours) | That day's schedule, plus overnight carry from the prior day |
| **Configure block** | Config lock hours merged with restriction hours when configure blocking is enabled |
| **Uninstall block** | Uninstall lock hours merged with restriction hours when uninstall protection is enabled |

The three caps are **independent** — each may reach 16 hours on the same day as long as that category's merged total stays ≤ 16 hours.

**At save time**:
- If **any** day/category exceeds 16 hours → **blocked** (no "save anyway" override).
- If merged hours indicate **24/7 lockout** across the week → **blocked** (weekly backstop).
- At most **16 hours per day per category** is valid.

**Examples**:
```
# BLOCKED — 24/7 restrictions (weekly backstop):
SUNDAY=0-12,12-0    # 24 hours
MONDAY=0-12,12-0    # 24 hours
... (all days 24 h) ...
# Total: 10080 minutes — BLOCKED

# BLOCKED — more than 16 hours on one day (per-day cap):
SATURDAY=0-16,16-17 # 17 hours on Saturday — BLOCKED

# VALID — at most 16 hours per day per category:
SUNDAY=0-16         # 16 hours
MONDAY=0-16         # 16 hours
...
SATURDAY=0-16       # 16 hours
# Each day ≤ 16 h — VALID
```

**Runtime fallback**:
If an unsafe config is loaded outside the wizard, `sleep-warning` uses the built-in restriction hours for that run (weekdays midnight–4:59, weekends 1:00–4:59) and logs a warning. It does not rewrite configure-block or uninstall settings in the file. The check uses the same flags as the features (`true`/`1`/`yes` enable configure-block; a missing uninstall mode is `difficult`) and counts restriction days that are absent from the file, because those days still use the built-in hours.

**Important Notes**:
- The validation correctly handles overlapping ranges (both within the same day and across day boundaries) to accurately calculate merged coverage per day.
- The per-day cap applies to **each category independently** — restriction, configure-block, and uninstall-block are checked separately.
- If configure-block is on (`true`, `1`, or `yes`) and you configure restriction hours (8 h/day) plus config lock hours (16 h/day) on the same day, the configure-block category totals 24 h and is **blocked**. When the flag is off, only the extra lock hours count toward that category.

**Combining Multiple and Overnight Ranges**:
You can combine multiple ranges, including overnight ranges:
```
MONDAY=0-5,22-23  # Midnight to 4:59 AM AND 10 PM to 11:59 PM (same day)
TUESDAY=23-6       # Tuesday 11:00 PM → Wednesday 5:59 AM (overnight)
WEDNESDAY=0-5,22-6 # Midnight to 4:59 AM AND 10 PM to 5:59 AM (overnight)
```

**No Restrictions**:
To disable restrictions for a specific day, either omit the line or leave it empty:
```
SUNDAY=
# or simply don't include the line
```

**Default Values** (used if configuration file is missing):
- **Weekdays (Monday-Friday)**: `0-5` (Midnight to 4:59 AM)
- **Weekends (Saturday-Sunday)**: `1-5` (1:00 AM to 4:59 AM)

### Check Interval

**Option**: `CHECK_INTERVAL`

**Description**: How often the system checks for restricted hours (in minutes).

**Format**: Integer between 1 and 60

**Default**: `10` (checks every 10 minutes)

**Examples**:
```
CHECK_INTERVAL=10   # Check every 10 minutes
CHECK_INTERVAL=5    # Check every 5 minutes
CHECK_INTERVAL=15   # Check every 15 minutes
CHECK_INTERVAL=1    # Check every minute (not recommended for performance)
```

**Note**: The systemd timer is automatically updated when you change this value using the configuration wizard. If you edit the file manually, you may need to reload the systemd timer:
```bash
systemctl --user daemon-reload
```

### Popup Size

**Option**: `POPUP_SIZE`

**Description**: Size of the warning popup dialog. Supports both fixed pixel sizes and percentage-based sizing (shown as "percentage" in the configuration wizard; config file value: `display-based`).

**Size Mode**: `POPUP_SIZE_MODE`

**Description**: Determines how popup sizes are calculated.

**Options**:
- `fixed` (default): Uses absolute pixel values (backward compatible)
- `display-based` (shown as "percentage" in the wizard): Percentage-based sizing; calculates sizes as percentages of the current display resolution

**Format**: 
- Predefined sizes: `xsmall`, `small`, `medium`, `large`, `xlarge`, `max`
- Custom pixel size: `WIDTHxHEIGHT` (e.g., `1920x1080`)
- Custom percentage size: `WIDTH%xHEIGHT%` (e.g., `50%x50%`)

**Predefined Sizes**:

In **fixed mode** (absolute pixels):
- `xsmall`: 384×216 pixels
- `small`: 400×250 pixels
- `medium`: 800×500 pixels (default)
- `large`: 1230×720 pixels
- `xlarge`: 1845×1080 pixels (fixed mode) or 75% × 75% of screen (percentage mode)
- `max`: 2214×1296 pixels

In **percentage-based mode** (percentage of screen; config: `POPUP_SIZE_MODE=display-based`):
- `xsmall`: 15% × 15% of screen resolution
- `small`: 20% × 20% of screen resolution
- `medium`: 30% × 30% of screen resolution
- `large`: 50% × 50% of screen resolution
- `xlarge`: 75% × 75% of screen resolution
- `max`: 90% × 90% of screen resolution

**Custom Sizes**:

**Pixel Format** (`WIDTHxHEIGHT`):
- Minimum: 384×216 pixels (matches xsmall)
- Maximum: 95% of screen width/height (ensures buttons remain visible)
- Example: `POPUP_SIZE=1920x1080` (1920 pixels wide, 1080 pixels tall)

**Percentage Format** (`WIDTH%xHEIGHT%`):
- Range: 15% to 95% for both width and height (95% maximum ensures buttons remain visible)
- Minimum: 15% × 15% (matches xsmall)
- Maximum: 95% × 95% (prevents buttons from being hidden at full screen size)
- Example: `POPUP_SIZE=50%x50%` (50% of screen width, 50% of screen height)

**Examples**:

Fixed mode (default, backward compatible):
```
POPUP_SIZE_MODE=fixed
POPUP_SIZE=medium      # Use medium size (800x500 pixels)
POPUP_SIZE=xsmall      # Use xsmall size (384x216 pixels)
POPUP_SIZE=xlarge      # Use xlarge size (1845x1080 pixels in fixed mode, 75%×75% in percentage mode)
POPUP_SIZE=max         # Use max size (2214x1296 pixels)
POPUP_SIZE=1920x1080   # Custom pixel size
```

Display-based mode (scales with screen resolution):
```
POPUP_SIZE_MODE=display-based
POPUP_SIZE=medium      # 30% × 30% of screen (e.g., 768×432 on 2560×1440 display)
POPUP_SIZE=xsmall      # 15% × 15% of screen (e.g., 384×216 on 2560×1440 display)
POPUP_SIZE=xlarge      # 75% × 75% of screen (e.g., 1920×1080 on 2560×1440 display) or 1845×1080 in fixed mode
POPUP_SIZE=max         # 90% × 90% of screen (e.g., 2304×1296 on 2560×1440 display in percentage mode) or 2214×1296 in fixed mode
POPUP_SIZE=50%x50%     # Custom percentage size (50% of screen width and height)
POPUP_SIZE=75%x60%     # Custom percentage size (75% width, 60% height)
```

**Resolution Detection**:

The system automatically detects your display resolution using:
- **X11**: `xrandr` command
- **Wayland**: `wlr-randr`, `swaymsg`, or `wayland-info` commands
- **gamescope** (SteamOS): Environment variables `GAMESCOPE_WIDTH` and `GAMESCOPE_HEIGHT`

If resolution detection fails, the system falls back to fixed pixel values.

**Notes**:
- Custom pixel sizes below 384×216 will be clamped to the minimum (384×216)
- Custom percentage sizes below 15% will be clamped to 15%
- Custom percentage sizes above 95% will be clamped to 95% (ensures buttons remain visible)
- Custom pixel sizes exceeding 95% of screen dimensions will be clamped to 95% (ensures buttons remain visible)
- The system detects resolution fresh each time a popup is shown (no caching)
- On multi-monitor setups, the system uses the primary display for size calculations

### Popup Position

**Option**: `POPUP_POSITION`

**Description**: Position of the warning popup on the screen.

**Format**: One of the following position names:
- `center` (default)
- `top-left`

**Default**: `center`

**Examples**:
```
POPUP_POSITION=center         # Center of screen (default)
POPUP_POSITION=top-left       # Top-left corner with fixed margins
```

**Note**: 
- Position control works best with `yad` dialog tool (preferred) which supports native positioning.
- `zenity` and `kdialog` use post-creation repositioning for top-left (requires window manager tools).
- Position control works best on X11; Wayland support is limited.
- Only `center` and `top-left` positions are supported. Top-left positioning uses simple fixed margins and doesn't require window size calculations.

**Installing yad:**
- **Ubuntu/Debian/Linux Mint**: `sudo apt install yad`
- **Fedora/RHEL/CentOS**: `sudo dnf install yad`
- **Arch Linux/Steam OS/Manjaro**: `sudo pacman -S yad`
- **openSUSE**: `sudo zypper install yad`

### Minimum Display Time

**Option**: `POPUP_MIN_DISPLAY_TIME`

**Description**: Minimum time (in seconds) that the popup must remain visible before it can be closed by the user.

**Format**: Integer between 0 and 300

**Default**: `30` (30 seconds)

**Examples**:
```
POPUP_MIN_DISPLAY_TIME=0      # Disabled - popup can be closed immediately
POPUP_MIN_DISPLAY_TIME=30     # 30 seconds (default)
POPUP_MIN_DISPLAY_TIME=60     # 1 minute
POPUP_MIN_DISPLAY_TIME=120    # 2 minutes
POPUP_MIN_DISPLAY_TIME=300    # 5 minutes (maximum)
```

**How It Works**:
- When set to a value greater than 0, the popup will show a countdown message indicating how long it must remain visible.
- If the user tries to close the popup before the minimum time expires, it will automatically reopen with an updated countdown.
- Window manager tools (`wmctrl` or `xdotool`) are used to prevent closing/minimizing the popup during the minimum display time.
- **Limitation**: Full functionality requires X11 and window manager tools. On Wayland, the countdown still works, but the popup cannot be prevented from being closed.

**Note**: 
- Requires `wmctrl` or `xdotool` for full functionality (X11 only).
- On Wayland, the countdown message is shown, but window control is limited.
- Setting this to `0` disables the feature entirely.

### Prevent Window Movement

**Option**: `POPUP_IMMOVABLE`

**Description**: Prevents the popup window from being moved during the minimum display time by monitoring and restoring its position if moved.

**Format**: `true` or `false`

**Default**: `true`

**Examples**:
```
POPUP_IMMOVABLE=true   # Prevent window movement (default)
POPUP_IMMOVABLE=false  # Allow window movement
```

**How It Works**:
- When enabled (`true`), the system monitors the popup window's position every 200ms (5 times per second).
- If the window is moved, it is automatically restored to its original position.
- This ensures the popup remains visible and in place during the minimum display time countdown.
- Works in conjunction with `POPUP_MIN_DISPLAY_TIME` - if minimum display time is 0, this setting has no effect.

**Note**: 
- Requires `wmctrl` or `xdotool` for functionality (X11 only).
- On Wayland, this feature is not available due to security restrictions.
- The popup window will also stay on top of other windows automatically.
- Setting this to `false` allows users to move the popup window, which may be useful if it blocks important content.

### Auto-Close Popup Window

**Option**: `POPUP_AUTO_CLOSE`

**Description**: Automatically closes the popup window 10 seconds after the minimum display time completes. This provides a non-interactive option for warning dismissal, allowing the popup to close automatically after it has been visible for the required duration plus a short grace period.

**Format**: `true` or `false`

**Default**: `true` (enabled by default)

**Examples**:
```
POPUP_AUTO_CLOSE=true   # Enable auto-close (default)
POPUP_AUTO_CLOSE=false  # Disable auto-close (user must close manually)
```

**How It Works**:
- Auto-close happens **10 seconds after minimum display time completes** (additional time, not total time)
- If `POPUP_MIN_DISPLAY_TIME=30`, the popup will auto-close after 40 seconds total (30 seconds minimum display + 10 seconds auto-close delay)
- If `POPUP_MIN_DISPLAY_TIME=0` (disabled), the popup will auto-close after 10 seconds
- The auto-close delay is **fixed at 10 seconds** and cannot be configured
- If the user manually closes the popup before auto-close, the auto-close timer is automatically cancelled

**Behavior Examples**:
```
# Example 1: Minimum display time = 30 seconds, auto-close enabled
POPUP_MIN_DISPLAY_TIME=30
POPUP_AUTO_CLOSE=true
# Result: Popup must stay visible for 30 seconds, then auto-closes after 40 seconds total

# Example 2: Minimum display time = 0, auto-close enabled
POPUP_MIN_DISPLAY_TIME=0
POPUP_AUTO_CLOSE=true
# Result: Popup auto-closes after 10 seconds

# Example 3: Minimum display time = 60 seconds, auto-close disabled
POPUP_MIN_DISPLAY_TIME=60
POPUP_AUTO_CLOSE=false
# Result: Popup must stay visible for 60 seconds, then user must close manually
```

**Important Notes**:
- **Enabled by default** - Auto-close is active unless explicitly disabled
- **Works on all platforms** - Uses process termination (SIGTERM, then SIGKILL if needed), so it works on X11, Wayland, and gamescope
- **Respects minimum display time** - Auto-close only starts after minimum display time completes (if minimum display time > 0)
- **Manual close cancels timer** - If you close the popup manually before auto-close, the timer is automatically cancelled
- **Pause button integration** - If you click the pause button, the popup closes immediately (before auto-close timer starts)
- **Not configurable delay** - The 10-second delay is fixed and cannot be changed

**Use Cases**:
- **Hands-free operation**: Allows popups to dismiss automatically without manual interaction
- **Reduced interruption**: Provides automatic dismissal after ensuring the warning has been visible for the required time
- **Accessibility**: Useful for users who prefer automatic dismissal or have difficulty interacting with popups

**Configuration via Wizard**:
- Use menu option 2: **Window Behavior** (opens a submenu for size, position, min display time, immovable, auto-close) in the configuration wizard
- Auto-close is configured alongside immovable settings
- The wizard shows current minimum display time for reference when configuring auto-close

### Restrict Configuration Changes During Restricted Hours (Tighten-Only)

**Option**: `CONFIGURE_BLOCK_ENABLED`

**Description**: When enabled, `configure.sh` and `manage.sh` open in **tighten-only mode** during restricted hours: you can make restrictions stricter, but you cannot loosen, remove, or disable them until restricted hours end. This is a self-control aid that prevents circumventing restrictions by weakening settings during restricted periods. (Earlier versions blocked these scripts entirely; the current behavior is the less drastic tighten-only partial lock.)

**Format**: `true` or `false`

**Default**: `false` (disabled - opt-in feature)

**Examples**:
```
CONFIGURE_BLOCK_ENABLED=true   # Enable tighten-only lock (recommended for self-control)
CONFIGURE_BLOCK_ENABLED=false  # Disable (default)
```

**How It Works**:
- When enabled (`true`), the configuration wizard (`configure.sh`) and management interface (`manage.sh`) check the current time at startup.
- If the current time falls within your configured restricted hours (or any configured lock hours), the wizard opens in **tighten-only mode** with a banner explaining the limited mode.
- In tighten-only mode you **can**: make popups more frequent, lengthen minimum display time, add restriction ranges, enable lock/protection flags, and strengthen uninstall protection.
- You **cannot**: slow popups, shorten display time, remove/edit/clear ranges, disable lock/protection flags, weaken uninstall protection, or otherwise loosen the configuration.
- Disabling the service (`systemctl --user disable` / `launchctl bootout`) and the uninstall script (`uninstall.sh`) are **never blocked** - you can always disable or uninstall the system if needed.

**Important Notes**:
- This is an **opt-in feature** - it is disabled by default to avoid frustrating users.
- You can only enable/disable the feature itself when you are **not** in restricted hours (disabling it is a "loosen" change).
- If you are in restricted hours and need to *loosen* settings, wait until restrictions end. Tightening is always allowed.
- The lock uses the same time-checking logic as the main warning system for consistency.
- Overnight ranges (e.g., `23-6`) are handled correctly - if you're in the early-morning portion of an overnight range, tighten-only mode applies.

**Use Cases**:
- **Self-control**: Prevents you from easily disabling restrictions during restricted hours when willpower is low.
- **Accountability**: Makes it harder to circumvent restrictions without waiting for unrestricted time.
- **Security**: Adds an additional layer of protection against accidental or intentional configuration changes during restricted periods.

**Limitations**:
- This feature can be bypassed by:
  - Modifying system time (requires admin access)
  - Editing the scripts or configuration file directly
  - Removing the time check code from the scripts
- It is designed as a **self-control aid**, not a security measure against determined users with system access.

### Additional Configuration Lock Hours

**Option**: `CONFIG_LOCK_HOURS_DAYNAME`

**Description**: Additional hours that restrict `configure.sh` and `manage.sh` to tighten-only edits (separate from restriction hours). When `CONFIGURE_BLOCK_ENABLED=true`, the wizards are tighten-only during restriction hours OR lock hours (OR logic). This allows you to configure separate lock periods beyond your normal restriction hours.

**Used by multiple features**:
- When **`CONFIGURE_BLOCK_ENABLED=true`** (Enhancement #19), `configure.sh`/`manage.sh` are tighten-only during **restricted hours OR lock hours**.
- When **`CONFIG_LOCK_ENABLED=true`** (Enhancement #18), the **config file** is locked during **restricted hours OR lock hours**.

**Format**: `CONFIG_LOCK_HOURS_DAYNAME=START_HOUR-END_HOUR`

**Days**: `CONFIG_LOCK_HOURS_SUNDAY`, `CONFIG_LOCK_HOURS_MONDAY`, `CONFIG_LOCK_HOURS_TUESDAY`, `CONFIG_LOCK_HOURS_WEDNESDAY`, `CONFIG_LOCK_HOURS_THURSDAY`, `CONFIG_LOCK_HOURS_FRIDAY`, `CONFIG_LOCK_HOURS_SATURDAY`

**Hours**: 24-hour format (0-23), same as restriction hours

**Default**: No lock hours configured (empty or omitted)

**Examples**:
```
CONFIG_LOCK_HOURS_MONDAY=9-17        # Block during work hours (9 AM to 4:59 PM)
CONFIG_LOCK_HOURS_TUESDAY=0-5,22-23  # Block during early morning and late evening
CONFIG_LOCK_HOURS_WEDNESDAY=23-6     # Block overnight (11 PM to 5:59 AM)
```

**How It Works**:
- Lock hours are **separate** from restriction hours (the hours when warnings appear)
- When `CONFIGURE_BLOCK_ENABLED=true`, `configure.sh` and `manage.sh` are blocked during:
  - **Restriction hours** (when warnings appear), OR
  - **Lock hours** (additional configured hours)
- This allows you to block configuration changes during specific times (e.g., work hours) even if those times are not restricted hours
- Lock hours use the same format as restriction hours:
  - Single range: `9-17` (9 AM to 4:59 PM)
  - Multiple ranges: `0-5,22-23` (midnight to 4:59 AM AND 10 PM to 11:59 PM)
  - Overnight ranges: `23-6` (11 PM to 5:59 AM, spans midnight)

**Important Notes**:
- Lock hours **only apply** when `CONFIGURE_BLOCK_ENABLED=true`
- If `CONFIGURE_BLOCK_ENABLED=false`, lock hours have no effect
- Lock hours are independent of restriction hours - you can have different lock hours than restriction hours
- Lock hours use OR logic with restriction hours - if current time is in either restriction hours OR lock hours, scripts are blocked
- Overnight ranges (e.g., `23-6`) are handled correctly - if you're in the early morning portion of an overnight range, the scripts will be blocked
- Leave a day empty or omit it to have no lock hours for that day

**Use Cases**:
- **Work Hours Blocking**: Block configuration changes during work hours (9 AM - 5 PM) even if work hours are not restricted hours
- **Extended Protection**: Block configuration changes during additional hours beyond your normal restriction hours
- **Flexible Scheduling**: Have different lock hours than restriction hours (e.g., restrict late night but lock work hours)

**Configuration via Wizard**:
- Use menu option 6: **Additional Configuration Lock Hours** in the configuration wizard
- Configure lock hours per day, similar to restriction hours
- Lock hours are saved to the config file with the `CONFIG_LOCK_HOURS_DAYNAME` format

**Limitations**:
- Same limitations as `CONFIGURE_BLOCK_ENABLED` - can be bypassed by modifying system time or editing scripts directly
- Designed as a **self-control aid**, not a security measure against determined users with system access

### Config File Locking During Restricted Hours

**Option**: `CONFIG_LOCK_ENABLED`

**Description**: When enabled, the system makes the configuration directory and config file **read-only** during **restricted hours OR lock hours**. This is a deterrence feature to make it harder to change settings during times you’ve chosen to restrict.

**Format**: `true` or `false`

**Default**: `false` (disabled - opt-in feature)

**How It Works** (Enhancement #18):
- When active, `sleep-warning.sh` applies a directory/file permission lock:
  - Directory: `~/.config/sleep-warning/config` → typically `555` (no writes)
  - File: `~/.config/sleep-warning/config/sleep-warning.conf` → typically `444` (read-only)
- A marker file is used to restore the original permissions when unlocking:
  - `~/.config/sleep-warning/.config_locked`
- A snapshot may be used for self-healing if the file is deleted/modified while locked:
  - `~/.config/sleep-warning/.config_locked_snapshot`

**Safety**:
- If configure-block or restriction categories would exceed **16 hours on any calendar day**, the wizard **blocks** the save (see [SAFETY.md](../docs/SAFETY.md)). Config file locking may be unavailable during very high restriction levels.
- This safety mechanism is part of Enhancement #22 (Prevent 24/7 Restriction Configuration).

**Limitations**:
- This is **deterrence-only**. A determined user with sufficient access can still bypass it by:
  - Stopping the systemd timer/service
  - Changing file permissions manually (requires write access to parent directory)
  - Editing files outside the expected flow
- The lock applies to the config directory and file, but cannot prevent all bypass methods (e.g., directory-level operations if user has sufficient permissions).

**When Lock is Active**:
- The config file and directory become read-only during:
  - **Restricted hours** (your configured restriction periods)
  - **Lock hours** (if `CONFIG_LOCK_HOURS_*` are configured)
- During restricted or lock hours, `configure.sh` and **Configure** in `manage.sh` open in **tighten-only partial mode** (banner at start): you may make lockout stricter (more frequent popups, longer min display, add hours only, enable locks) but not remove hours or disable protections. `POPUP_AUTO_CLOSE` may be turned on or off. Other manage actions (disable service, status, logs) still work. See [docs/SAFETY.md](../docs/SAFETY.md) for the full matrix.
- The lock is automatically applied/removed by `sleep-warning.sh` on each timer tick

**Self-Healing**:
- The system includes a self-healing mechanism that:
  - Detects if permissions are manually changed and re-applies the lock
  - Can restore the config file from a snapshot if it's deleted (though directory lock makes this difficult)
  - Runs automatically on each timer tick

**Uninstall During Lock Hours**:
- The `uninstall.sh` script can always restore permissions and uninstall successfully, even during lock hours
- This ensures you can always uninstall the system if needed

### Uninstall Protection During Restricted Hours

**Option**: `UNINSTALL_PROTECTION_MODE`

**Description**: When enabled, requires a difficult verification process to uninstall the system during restricted hours. This is a security feature that helps prevent circumventing restrictions by uninstalling the system during restricted periods.

**Format**: `none` or `difficult`

**Default**: `difficult` (enabled by default)

**Examples**:
```
UNINSTALL_PROTECTION_MODE=none      # No protection - uninstall works normally
UNINSTALL_PROTECTION_MODE=difficult # Difficult uninstall - requires verification (default)
```

**How It Works**:
- When set to `difficult`, the uninstall script (`uninstall.sh`) will check the current time at startup.
- If the current time falls within your configured **restriction hours OR uninstall lock hours** (if configured), the script will require you to complete a verification process before allowing uninstallation:
  1. **Confirmation Phrase**: You must type the exact phrase: "I really mean it and want to uninstall this program now even though restrictions are running"
  2. **Arithmetic Questions**: You must correctly answer 5 arithmetic questions written in word form with step-by-step instructions (e.g., "Multiply 53 by 15, then add (31 minus 58), then add 147. What is the final result?"). You are allowed 3 wrong answers total across all questions.
- Questions are written in natural language to make copy-pasting into search engines or calculators more difficult.
- If you are **not** in restriction hours or uninstall lock hours, uninstallation works normally without verification.
- The verification process requires cognitive engagement and effort, making it difficult to uninstall impulsively during restricted hours.

**Important Notes**:
- ⚠️ **Enabled by default** - The "difficult" mode is enabled by default to help prevent circumventing restrictions. You can set it to `none` if you prefer no protection.
- ⚠️ **Lower Risk Option**: The "difficult" mode allows legitimate uninstalls while deterring impulsive ones. You can still uninstall if you complete the verification process.
- ⚠️ **Safety Mechanism**: A manual uninstall guide script (`manual-uninstall-guide`) is always available and provides step-by-step instructions for manual uninstallation, even during restricted hours. This script is never blocked.
- You can only change this setting when you are **not** in restricted hours (via the configuration wizard).
- The protection uses the same time checking logic as the main warning system for consistency.
- Overnight ranges (e.g., `23-6`) are handled correctly - if you're in the early morning portion of an overnight range, verification will be required.

**Use Cases**:
- **Self-control**: Prevents you from easily uninstalling the system during restricted hours when willpower is low.
- **Accountability**: Makes it harder to circumvent restrictions by removing the system without waiting for unrestricted time.
- **Security**: Adds an additional layer of protection against accidental or intentional uninstallation during restricted periods.

**Limitations**:
- This feature can be bypassed by:
  - Modifying system time (requires admin access)
  - Editing the scripts or configuration file directly
  - Using the manual uninstall guide script to perform manual uninstallation
  - Removing the time check code from the scripts
- It is designed as a **self-control aid**, not a security measure against determined users with system access.
- Determined users can still uninstall if they complete the verification process or use the manual uninstall guide.

**Manual Uninstall Guide**:
If you need to uninstall during restricted hours and find the verification process too difficult, you can use the manual uninstall guide script:
```bash
manual-uninstall-guide
```
This script provides step-by-step instructions for manually uninstalling the system and is always accessible, even during restricted hours.

### Additional Uninstall Lock Hours

**Option**: `UNINSTALL_LOCK_HOURS_DAYNAME`

**Description**: Configure additional hours (separate from restriction hours and configure.sh lock hours) during which difficult uninstall verification is required. This creates a dedicated schedule specifically for uninstall protection, independent of your main restriction hours.

**Format**: `UNINSTALL_LOCK_HOURS_DAYNAME=START_HOUR-END_HOUR`

**Default**: Not configured (no additional uninstall lock hours by default)

**Examples**:
```
UNINSTALL_LOCK_HOURS_MONDAY=9-17        # Require verification during work hours (9 AM to 4:59 PM)
UNINSTALL_LOCK_HOURS_TUESDAY=0-5,22-23   # Require verification during early morning and late evening
UNINSTALL_LOCK_HOURS_WEDNESDAY=23-6      # Require verification overnight (11 PM to 5:59 AM)
```

**How It Works**:
- When `UNINSTALL_PROTECTION_MODE=difficult` is enabled, difficult uninstall verification applies during **restriction hours OR uninstall lock hours** (OR logic).
- If the current time falls within either restriction hours or uninstall lock hours, the verification process is required.
- Uninstall lock hours are completely separate from:
  - Restriction hours (main schedule for warnings)
  - Configure.sh lock hours (hours when configure.sh/manage.sh are blocked)
- This allows you to configure different schedules for uninstall protection vs. other features.

**Important Notes**:
- ⚠️ **Requires `UNINSTALL_PROTECTION_MODE=difficult`** - Uninstall lock hours only take effect when uninstall protection is set to "difficult". If protection is set to "none", uninstall lock hours have no effect.
- ⚠️ **Increased Risk**: Additional uninstall lock hours increase the risk of preventing legitimate uninstall needs. Use with caution.
- ⚠️ **OR Logic**: Verification applies if current time is in restriction hours OR uninstall lock hours. This means verification can be required even outside your main restriction hours if uninstall lock hours are configured.
- You can configure uninstall lock hours per day (Sunday-Saturday) or leave days empty to have no uninstall lock hours for those days.
- Overnight ranges (e.g., `23-6`) are supported and handled correctly.
- Multiple ranges per day are supported (comma-separated, e.g., `9-17,20-22`).

**Configuration via Wizard**:
- Use menu option 8: **Additional Uninstall Protection Hours** in the configuration wizard
- Configure uninstall lock hours per day, similar to restriction hours
- Uninstall lock hours are saved to the config file with the `UNINSTALL_LOCK_HOURS_DAYNAME` format
- You can also edit uninstall lock hours from the View Weekly Hours Settings (option 9) by selecting a day and choosing "Uninstall Lock Hours" or "All"

**Use Cases**:
- **Extended Protection**: Add additional hours beyond your restriction hours when you want extra uninstall protection
- **Flexible Scheduling**: Configure different schedules for uninstall protection vs. warning popups
- **Targeted Protection**: Protect specific time periods (e.g., work hours) with uninstall verification even if those aren't your main restriction hours

**Limitations**:
- Same limitations as uninstall protection - can be bypassed by modifying system time, editing scripts, or using the manual uninstall guide
- Designed as a **self-control aid**, not a security measure against determined users with system access

### Pause Feature (One-Time Pause)

**Option**: `PAUSE_ENABLED` and `PAUSE_DURATION`

**Description**: Allows users to temporarily suppress warning popups for a short period (5 or 10 minutes) once per day, directly from the warning popup window. This provides flexibility for legitimate exceptions (e.g., finishing a task, handling an emergency) while maintaining overall restriction effectiveness.

**Format**:
- `PAUSE_ENABLED`: `true` or `false`
- `PAUSE_DURATION`: `5` or `10` (minutes)

**Default**: 
- `PAUSE_ENABLED=true` (enabled by default)
- `PAUSE_DURATION=5` (5 minutes)

**Examples**:
```
PAUSE_ENABLED=true        # Enable pause feature (default)
PAUSE_ENABLED=false       # Disable pause feature
PAUSE_DURATION=5          # 5 minute pause duration (default)
PAUSE_DURATION=10         # 10 minute pause duration
```

**How It Works**:
- When enabled, warning popups display a pause button (e.g., "Pause 5 min" or "Pause 10 min") directly in the popup window
- Users can click the pause button to activate the pause
- The popup closes immediately and a confirmation message appears showing when the pause expires
- Warning popups are suppressed during the pause period (5 or 10 minutes, depending on configuration)
- After the pause expires, warning popups resume normally
- **Once Per Day Limit**: The pause feature can only be used once per day (resets at midnight). This limit is always enforced and cannot be disabled.

**Important Notes**:
- **What Pause Affects**:
  - ✅ **Suppresses warning popups** - No popups shown during pause period
  - ❌ **Does NOT affect `configure.sh` tighten-only lock** - Configuration is still tighten-only during restricted hours if `CONFIGURE_BLOCK_ENABLED=true`
  - ❌ **Does NOT affect `uninstall.sh` protection** - Still requires verification during restricted hours if `UNINSTALL_PROTECTION_MODE=difficult`
  - ❌ **Does NOT release restrictions** - Restrictions are still active, only warnings are suppressed
- **Pause is a temporary "quiet period" for warnings only**, not a release of restrictions
- The once-per-day limit is **always enforced** and cannot be disabled
- Pause buttons are available even during minimum display time - clicking pause immediately closes the popup (bypasses minimum display time)

**Configuration via Wizard**:
- Use menu option 10: **Enable pause and configure duration** in the configuration wizard
- Configure pause enabled/disabled and duration (5 or 10 minutes)
- Settings are saved to the config file with the `PAUSE_ENABLED` and `PAUSE_DURATION` format

**Viewing Pause Status**:
- Check pause status: `sleep-warning-status` (shows pause configuration and current status)
- View pause details: `sleep-warning-manage` → Option 2 "View Pause Status"

**Use Cases**:
- **Legitimate Exceptions**: Finish a task or handle an emergency without constant popup interruptions
- **Flexibility**: Provides a controlled way to temporarily suppress warnings while maintaining restriction effectiveness
- **Self-Control Aid**: The once-per-day limit prevents overuse while allowing necessary exceptions

### Dialog Tool Selection

**Option**: `DIALOG_TOOL`

**Description**: Allows you to manually select which dialog tool (zenity, yad, or kdialog) to use for popup windows, overriding the automatic priority system. This gives you control over dialog tool selection when you have preferences or encounter issues with the automatic selection.

**Format**: `auto`, `zenity`, `yad`, or `kdialog`

**Default**: `auto` (uses automatic priority system: YAD → Zenity → KDialog)

**Examples**:
```
DIALOG_TOOL=auto      # Use automatic selection (recommended, default)
DIALOG_TOOL=yad       # Force use of yad (if installed)
DIALOG_TOOL=zenity    # Force use of zenity (if installed)
DIALOG_TOOL=kdialog   # Force use of kdialog (if installed)
```

**How It Works**:
- When set to `auto` (or not set), the system uses automatic priority selection:
  - **YAD** (preferred) - Best positioning, Wayland support, reliable sizing
  - **Zenity** (fallback) - Standard GTK dialog
  - **KDialog** (last resort) - KDE dialog
- When set to a specific tool (e.g., `yad`, `zenity`, `kdialog`):
  - The system will use that tool if it is installed
  - If the selected tool is not installed, the system will log a warning and automatically fall back to the automatic priority system
  - The system logs which tool was selected and why (user preference vs automatic)

**Important Notes**:
- **Automatic selection is recommended** - The automatic priority system (YAD → Zenity → KDialog) is designed to select the best available tool for your environment
- **Tool availability**: Only installed tools can be selected. If you select a tool that is not installed, the system will automatically fall back to the automatic priority system
- **Backward compatibility**: Existing configurations without `DIALOG_TOOL` will default to `auto` behavior
- **Tool capabilities**:
  - **YAD**: Best positioning support, native Wayland support, reliable window sizing (recommended if available)
  - **Zenity**: Standard GTK dialog, good compatibility, limited positioning support
  - **KDialog**: KDE integration, limited positioning and sizing support

**When to Use Manual Selection**:
- **Troubleshooting**: If you encounter issues with the automatically selected tool, you can test different tools to diagnose the problem
- **Preference**: If you have a specific preference for a particular dialog tool
- **Compatibility**: If you need to work around tool-specific bugs or limitations
- **Testing**: To verify that a specific tool works correctly in your environment

**Configuration via Wizard**:
- Use menu option 11: **Dialog Tool Selection** in the configuration wizard
- The wizard shows:
  - Current setting
  - Recommended tool (based on automatic priority)
  - List of installed tools with descriptions
  - Tool recommendations based on automatic priority system
- Only installed tools are shown in the selection list
- The wizard validates that the selected tool is installed before saving

**Viewing Current Selection**:
- Check dialog tool: `sleep-warning-status` (shows current selection and installed tools)
- The status display shows:
  - User-selected tool (if manually selected) or automatic selection
  - Warning if selected tool is not installed
  - List of all installed tools for reference

**Fallback Behavior**:
- If the selected tool becomes unavailable (e.g., uninstalled), the system automatically falls back to the automatic priority system
- A warning is logged when fallback occurs
- The system continues to work normally with the best available tool

### Experimental Gaming Mode Overlay

**Option**: `GAMING_MODE_EXPERIMENTAL_ENABLED`

**Purpose**: On Linux, route warning dialogs through gamescope's Xwayland overlay plane when you are in SteamOS Gaming Mode.

**Default**: `false` (Desktop Mode dialogs only)

**Valid Values**:
- `true` — enable the experimental overlay path
- `false` — keep normal desktop dialog routing

**Example**:
```
GAMING_MODE_EXPERIMENTAL_ENABLED=false
```

**How to Change**:
- Recommended: `sleep-warning-configure` → **Option 12: Service Mode Configuration**
- Manual: edit `~/.config/sleep-warning/config/sleep-warning.conf`

**Notes**:
- Off unless this key is `true`. An older `mode-gaming.conf` drop-in does not turn it on.
- Option 12 can turn it on or off during lock hours. It does not change restriction hours.
- If no usable display can be found, the warning tries `notify-send` instead of a modal dialog. Gaming Mode may not have a notification daemon.
- When the overlay path is active, zenity/yad warning dialogs request the full gamescope nested (`:0`) width (gamescope 3.16.x treats narrower `STEAM_OVERLAY` windows as non-interactive notifications). Desktop Mode sizes are unchanged. Click/touch and sharpness still need a Steam Deck retest after this sizing change.
- Not verified on a Steam Deck. See [../dev-docs/STEAMOS_GAMING_MODE.md](../dev-docs/STEAMOS_GAMING_MODE.md).

## Complete Configuration Example

Here is a complete example configuration file with all options:

```
# Sleep Warning Configuration
# Format: DAY=START_HOUR-END_HOUR
# Hours are in 24-hour format (0-23)
# Multiple ranges can be specified per day (comma-separated)
# Leave a day empty or omit it to have no restrictions for that day

# Check interval: How often to check for restricted hours (in minutes)
CHECK_INTERVAL=10

# Popup size mode: fixed (pixels) or percentage (percentage of screen; config value: display-based)
POPUP_SIZE_MODE=fixed
# Popup size: xsmall, small, medium, large, xlarge, max, or custom (WIDTHxHEIGHT or WIDTH%xHEIGHT%)
POPUP_SIZE=medium

# Popup position: center or top-left
POPUP_POSITION=center

# Minimum display time: Time popup must be visible before it can be closed (in seconds, 0-300)
POPUP_MIN_DISPLAY_TIME=30

# Prevent window movement: Prevent popup from being moved during minimum display time (true/false)
POPUP_IMMOVABLE=true

# Auto-close popup window: Automatically close popup 10 seconds after minimum display time completes (true/false)
# Auto-close happens 10 seconds after minimum display time completes (additional time, not total time)
# If minimum display time is 0, auto-close happens after 10 seconds
# Auto-close time is fixed at 10 seconds (not configurable)
POPUP_AUTO_CLOSE=true

# Restrict configuration changes during restricted hours: open configure.sh and manage.sh in tighten-only mode (true/false)
# Tighten-only = settings can be made stricter but not loosened/removed/disabled until restricted hours end
# This is an opt-in self-control feature - disabled by default
CONFIGURE_BLOCK_ENABLED=false

# Uninstall protection mode: Require verification to uninstall during restricted hours (none/difficult)
# none = No protection - uninstall works normally
# difficult = Difficult uninstall - requires confirmation phrase + 5 arithmetic questions, 3 wrong answers allowed (default)
# This security feature is enabled by default
UNINSTALL_PROTECTION_MODE=difficult

# Dialog tool selection: Which dialog tool to use for popup windows (auto/zenity/yad/kdialog)
# auto = Automatic selection (recommended, uses priority: YAD → Zenity → KDialog)
# zenity = Force use of zenity (if installed)
# yad = Force use of yad (if installed)
# kdialog = Force use of kdialog (if installed)
# If selected tool is not installed, system falls back to automatic selection
DIALOG_TOOL=auto

# Experimental SteamOS Gaming Mode overlay (true/false). Default false.
# Does not change restriction hours. Option 12 can toggle this during lock hours.
GAMING_MODE_EXPERIMENTAL_ENABLED=false

# Config file locking: Lock the configuration file during restricted hours (and lock hours) (true/false)
# This is an opt-in deterrence feature - disabled by default
# When enabled, the configuration file becomes read-only during restricted hours and configured lock hours
# This prevents users from modifying settings during restricted periods
# IMPORTANT: This is a deterrence feature only - it can be bypassed by determined users
# Config file locking is disabled automatically when per-day caps would be violated at runtime
# See "Configuration Lock (Tighten-Only) and Config File Locking" in the configuration wizard to enable/disable
CONFIG_LOCK_ENABLED=false

# Restricted hours for each day
SUNDAY=1-5
MONDAY=0-5
TUESDAY=0-5
WEDNESDAY=0-5
THURSDAY=0-5
FRIDAY=0-5
SATURDAY=1-5
```

## Configuration Examples for Different Use Cases

### Student Schedule (Late Night Study Restrictions)
```
CHECK_INTERVAL=15
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30

# Restrict late night usage on weekdays
MONDAY=23-6      # 11 PM to 5:59 AM
TUESDAY=23-6
WEDNESDAY=23-6
THURSDAY=23-6
FRIDAY=23-6

# More lenient on weekends
SATURDAY=1-6     # 1 AM to 5:59 AM (overnight)
SUNDAY=1-6
```

### Work Schedule (Early Morning Restrictions)
```
CHECK_INTERVAL=10
POPUP_SIZE=small
POPUP_POSITION=top-left
POPUP_MIN_DISPLAY_TIME=15

# Restrict very early morning usage
MONDAY=0-5       # Midnight to 4:59 AM
TUESDAY=0-5
WEDNESDAY=0-5
THURSDAY=0-5
FRIDAY=0-5

# No restrictions on weekends
# (omit SATURDAY and SUNDAY lines)
```

### Weekend-Only Restrictions
```
CHECK_INTERVAL=10
POPUP_SIZE=large
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=60

# No weekday restrictions
# (omit MONDAY through FRIDAY lines)

# Weekend restrictions
SATURDAY=1-8     # 1 AM to 7:59 AM (overnight)
SUNDAY=1-8
```

### Different Hours Per Day
```
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30

# Different restrictions for each day
SUNDAY=2-6       # Sunday: 2 AM to 5:59 AM (overnight)
MONDAY=0-5       # Monday: Midnight to 4:59 AM
TUESDAY=0-5      # Tuesday: Midnight to 4:59 AM
WEDNESDAY=0-5    # Wednesday: Midnight to 4:59 AM
THURSDAY=0-5     # Thursday: Midnight to 4:59 AM
FRIDAY=0-5       # Friday: Midnight to 4:59 AM
SATURDAY=1-7     # Saturday: 1 AM to 6:59 AM (overnight)
```

### Multiple Time Ranges Per Day
```
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_AUTO_CLOSE=true

# Multiple restricted periods per day
MONDAY=0-5,22-23    # Midnight to 4:59 AM AND 10 PM to 11:59 PM
TUESDAY=0-5,22-23
WEDNESDAY=0-5,22-23
THURSDAY=0-5,22-23
FRIDAY=0-5,22-23

# Single period on weekends
SATURDAY=1-5
SUNDAY=1-5
```

## Editing the Configuration File

### Method 1: Interactive Configuration Wizard (Recommended)

The easiest way to configure the system is using the interactive configuration wizard:

```bash
sleep-warning-configure
```

or

```bash
./configure.sh
```

The wizard will guide you through setting all configuration options with a user-friendly interface.

**Configuration Menu Options**:
1. **Timer Settings** - Configure how often the system checks for restricted hours
2. **Window Behavior** - Configure popup size, position, display time, and immovable settings
3. **Weekdays Configuration** - Set restricted hours for Monday through Friday
4. **Weekends Configuration** - Set restricted hours for Saturday and Sunday
5. **Visual Day/Time Grid** - View and edit all days in a visual grid format (see below)
6. **Configuration Lock (Tighten-Only) and Config File Locking** - Restrict configure.sh and manage.sh to tighten-only edits during restricted/lock hours, and lock the config file
7. **Lock Hours Configuration** - Configure additional hours when configuration/management is blocked (separate from restriction hours)
8. **Uninstall Protection** - Configure protection mode for uninstall.sh during restricted hours
9. **Uninstall Lock Hours Configuration** - Configure additional hours when difficult uninstall verification is required
10. **Enable pause and configure duration** - Configure pause feature for warning popups
11. **Dialog Tool Selection** - Select which dialog tool to use for popup windows
12. **Review and Save** - Review your configuration and save changes

**Visual Day/Time Grid**:
The View Weekly Hours Settings (option 9) provides a convenient way to see all days of the week and their configured time ranges at a glance. The grid displays:
- All 7 days (Sunday through Saturday) in a single view
- Four columns: Day, Restricted Hours, Lock Hours (configure.sh/manage.sh), and Uninstall Lock Hours
- You can select any day to edit its restricted hours, lock hours, uninstall lock hours, or all of them
- Current time ranges for each day in human-readable format (e.g., "12:00 AM → 4:59 AM")
- Visual indicators (✗) showing which days have restrictions configured
- Easy click-to-edit access for any day

You can select any day from the grid to edit its restricted hours. After editing, the grid automatically refreshes to show your updated configuration. This makes it easy to configure different hours for each day or quickly review your entire schedule.

**Command-line options**:
- `--text` or `--no-gui`: Force text mode (useful for SSH sessions or when GUI isn't working)
- `--gui`: Force GUI mode (requires zenity)
- `--help` or `-h`: Show help message

By default, the wizard uses GUI mode if zenity is available and a display is present. Use `--text` to force text mode when working over SSH or when the GUI environment isn't available.

### Method 2: Manual Editing

You can manually edit the configuration file using any text editor:

```bash
nano ~/.config/sleep-warning/config/sleep-warning.conf
# or
vim ~/.config/sleep-warning/config/sleep-warning.conf
# or use your preferred text editor
```

**Important Notes**:
- The configuration file is read every time the script runs (every check interval).
- Changes take effect on the next check (within the configured interval).
- If you change `CHECK_INTERVAL`, you may need to reload the systemd timer:
  ```bash
  systemctl --user daemon-reload
  ```

## Validation

The script automatically validates configuration values:

- **Hours**: Start times are 0–23. An end of `24:00` (or `24`) means the end of that calendar day. `00:00-24:00` is the full day and exceeds the 16 h cap.
- **Hour ranges**: A start earlier than the end stays on the same day. A start later than the end is an overnight range (for example `23-6`).
- **CHECK_INTERVAL**: Must be between 1 and 60
- **POPUP_SIZE**: Must be `xsmall`, `small`, `medium`, `large`, `xlarge`, `max`, `custom`, or match `WIDTHxHEIGHT` (pixel) or `WIDTH%xHEIGHT%` (percentage) format
- **POPUP_SIZE_MODE**: Must be `fixed` or `display-based` (default: `fixed`). The value `display-based` is shown as "percentage" in the configuration wizard.
- **POPUP_POSITION**: Must be one of the valid position names
- **POPUP_MIN_DISPLAY_TIME**: Must be between 0 and 300
- **Timing Configuration**: `POPUP_MIN_DISPLAY_TIME` (in seconds) must not exceed `CHECK_INTERVAL` (in minutes) × 60. If this conflict is detected, the configuration wizard will show an error and prevent saving until the conflict is resolved. You can either increase `CHECK_INTERVAL` or decrease `POPUP_MIN_DISPLAY_TIME` to fix the conflict.

Invalid values will be ignored and default values will be used instead. The script will log warnings for invalid configuration values.

## Troubleshooting

### Configuration Not Taking Effect

1. **Check file location**: Ensure the file is at `~/.config/sleep-warning/config/sleep-warning.conf`
2. **Check file permissions**: The file should be readable by your user
3. **Check syntax**: Ensure there are no syntax errors (missing `=`, invalid characters, etc.)
4. **Check logs**: View the log file at `~/.config/sleep-warning/warnings.log` for any errors
5. **Reload timer**: If you changed `CHECK_INTERVAL`, run:
   ```bash
   systemctl --user daemon-reload
   ```

### Viewing Current Configuration

You can view your current configuration using the management script:

```bash
sleep-warning-manage
```

Select "View Current Configuration" from the menu.

Or view it directly:

```bash
cat ~/.config/sleep-warning/config/sleep-warning.conf
```

## Additional Resources

- **Main Documentation**: See [README.md](../README.md) for general information
- **Technical Details**: See [../dev-docs/TECHNICAL_DETAILS.md](../dev-docs/TECHNICAL_DETAILS.md) for implementation details
- **SteamOS Gaming Mode**: See [../dev-docs/STEAMOS_GAMING_MODE.md](../dev-docs/STEAMOS_GAMING_MODE.md) for Gaming Mode compatibility information
