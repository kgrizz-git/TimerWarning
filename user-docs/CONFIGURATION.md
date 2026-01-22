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
~/.config/sleep-warning/sleep-warning.conf
```

If the configuration file does not exist, the system will use default values. You can create the file manually or use the interactive configuration wizard (`configure.sh` or `sleep-warning-configure`).

## File Format

The configuration file uses a simple key-value format with comments. Lines starting with `#` are comments and are ignored. Empty lines are also ignored.

## Configuration Options

### Restricted Hours

**Format**: `DAY=START_HOUR-END_HOUR`

**Days**: `SUNDAY`, `MONDAY`, `TUESDAY`, `WEDNESDAY`, `THURSDAY`, `FRIDAY`, `SATURDAY`

**Hours**: 24-hour format (0-23)
- `0` = Midnight (12:00 AM)
- `12` = Noon (12:00 PM)
- `23` = 11:00 PM

**Examples**:
```
SUNDAY=1-5        # Sunday: 1:00 AM to 4:59 AM
MONDAY=0-5        # Monday: Midnight (00:00) to 4:59 AM
TUESDAY=0-5       # Tuesday: Midnight to 4:59 AM
WEDNESDAY=0-5     # Wednesday: Midnight to 4:59 AM
THURSDAY=0-5      # Thursday: Midnight to 4:59 AM
FRIDAY=0-5        # Friday: Midnight to 4:59 AM
SATURDAY=1-5      # Saturday: 1:00 AM to 4:59 AM
```

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

**24/7 Restriction Prevention (Safety Feature)**:
The configuration wizard includes a critical safety feature that prevents you from accidentally configuring restrictions for all 24 hours, 7 days a week, which would effectively lock you out of your computer.

**How It Works**:
- When you save your configuration, the system automatically checks the total restriction coverage across all 7 days
- If you configure restrictions for **all 24 hours, 7 days a week** (10080 minutes total), the configuration will be **blocked** and you'll see an error message
- If you configure restrictions for **more than 23 hours per day** (> 9660 minutes total), you'll see a **warning** and can choose to save anyway or modify your settings

**Why This Matters**:
- Configuring 24/7 restrictions would leave no unrestricted time to modify settings or use your computer
- The system prevents this accidental lockout scenario
- If you need very high restriction levels (> 23 hours/day), you can still save, but safety features will be automatically applied (see below)

**Examples**:
```
# This configuration would be BLOCKED (24/7 restrictions):
SUNDAY=0-12,12-0    # 24 hours
MONDAY=0-12,12-0    # 24 hours
TUESDAY=0-12,12-0   # 24 hours
WEDNESDAY=0-12,12-0 # 24 hours
THURSDAY=0-12,12-0  # 24 hours
FRIDAY=0-12,12-0    # 24 hours
SATURDAY=0-12,12-0  # 24 hours
# Total: 10080 minutes (24 hours × 7 days) - BLOCKED

# This configuration would show a WARNING (> 23 hours/day):
SUNDAY=0-23         # 23 hours (00:00-22:59)
MONDAY=0-23         # 23 hours
TUESDAY=0-23        # 23 hours
WEDNESDAY=0-23      # 23 hours
THURSDAY=0-23       # 23 hours
FRIDAY=0-23         # 23 hours
SATURDAY=0-23,23-0  # 24 hours (0-23 + 23-0)
# Total: 9661 minutes (> 23 hours/day) - WARNING shown

# This configuration is VALID (<= 23 hours/day):
SUNDAY=0-23         # 23 hours
MONDAY=0-23         # 23 hours
TUESDAY=0-23        # 23 hours
WEDNESDAY=0-23      # 23 hours
THURSDAY=0-23       # 23 hours
FRIDAY=0-23         # 23 hours
SATURDAY=0-23       # 23 hours
# Total: 9660 minutes (exactly 23 hours/day) - VALID, no warning
```

**Automatic Safety Overrides** (when high restrictions are detected):
If you configure restrictions for more than 23 hours per day and choose to save anyway, the system automatically applies safety measures:
- **Popup size restriction**: Popup size is limited to "small" or "medium" only (prevents overly intrusive popups when you have very limited unrestricted time)
- **Config locking disabled**: Config file locking features are automatically disabled (prevents locking yourself out during very limited unrestricted time)
- **Transparency**: The config file includes comments explaining why these safety features are disabled

**Note**: The validation correctly handles overlapping ranges (both within the same day and across day boundaries) to accurately calculate total restricted time. For example, if you have Monday "23-6" and Tuesday "0-5", the overlap at hours 0-5 is correctly detected and counted only once.

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

**Description**: Size of the warning popup dialog.

**Format**: 
- Predefined sizes: `small`, `medium`, `large`
- Custom size: `WIDTHxHEIGHT` (e.g., `450x220`)

**Predefined Sizes**:
- `small`: 400x250 pixels
- `medium`: 800x500 pixels (default)
- `large`: 2000x1350 pixels

**Custom Size Format**: `WIDTHxHEIGHT`
- Width: 200-2000 pixels
- Height: 100-2000 pixels

**Default**: `medium`

**Examples**:
```
POPUP_SIZE=medium      # Use medium size (800x500)
POPUP_SIZE=small       # Use small size (400x250)
POPUP_SIZE=large       # Use large size (2000x1350)
POPUP_SIZE=450x220     # Custom size: 450 pixels wide, 220 pixels tall
```

**Note**: Custom sizes outside the valid range (200-2000 width, 100-2000 height) will be reset to the default medium size.

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

### Block Scripts During Restricted Hours

**Option**: `CONFIGURE_BLOCK_ENABLED`

**Description**: When enabled, prevents `configure.sh` and `manage.sh` from running during restricted hours. This is a security feature that helps prevent circumventing restrictions by changing settings or disabling the system during restricted periods.

**Format**: `true` or `false`

**Default**: `false` (disabled - opt-in feature)

**Examples**:
```
CONFIGURE_BLOCK_ENABLED=true   # Enable blocking (recommended for self-control)
CONFIGURE_BLOCK_ENABLED=false  # Disable blocking (default)
```

**How It Works**:
- When enabled (`true`), the configuration wizard (`configure.sh`) and management interface (`manage.sh`) will check the current time at startup.
- If the current time falls within your configured restricted hours, these scripts will exit with a clear error message showing:
  - Current time (in 12-hour format)
  - Active restriction period
  - When restrictions end
- This prevents you from modifying settings or disabling the system during restricted hours.
- The uninstall script (`uninstall.sh`) is **never blocked** - you can always uninstall the system if needed.

**Important Notes**:
- This is an **opt-in feature** - it is disabled by default to avoid frustrating users.
- You can only enable/disable this feature when you are **not** in restricted hours.
- If you enable this feature and later need to change settings during restricted hours, you would need to wait until restrictions end or temporarily modify the config file directly.
- The blocking uses the same time checking logic as the main warning system for consistency.
- Overnight ranges (e.g., `23-6`) are handled correctly - if you're in the early morning portion of an overnight range, the scripts will be blocked.

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

### Additional Lock Hours for Blocking Scripts

**Option**: `CONFIG_LOCK_HOURS_DAYNAME`

**Description**: Additional hours for blocking `configure.sh` and `manage.sh` (separate from restriction hours). When `CONFIGURE_BLOCK_ENABLED=true`, these scripts are blocked during restriction hours OR lock hours (OR logic). This allows you to configure separate lock periods beyond your normal restriction hours.

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
- Use menu option 7: **Lock Hours Configuration** in the configuration wizard
- Configure lock hours per day, similar to restriction hours
- Lock hours are saved to the config file with the `CONFIG_LOCK_HOURS_DAYNAME` format

**Limitations**:
- Same limitations as `CONFIGURE_BLOCK_ENABLED` - can be bypassed by modifying system time or editing scripts directly
- Designed as a **self-control aid**, not a security measure against determined users with system access

### Uninstall Protection During Restricted Hours

**Option**: `UNINSTALL_PROTECTION_MODE`

**Description**: When enabled, requires a difficult verification process to uninstall the system during restricted hours. This is a security feature that helps prevent circumventing restrictions by uninstalling the system during restricted periods.

**Format**: `none` or `difficult`

**Default**: `none` (disabled - opt-in feature)

**Examples**:
```
UNINSTALL_PROTECTION_MODE=none      # No protection - uninstall works normally (default)
UNINSTALL_PROTECTION_MODE=difficult # Difficult uninstall - requires verification (recommended)
```

**How It Works**:
- When set to `difficult`, the uninstall script (`uninstall.sh`) will check the current time at startup.
- If the current time falls within your configured restricted hours, the script will require you to complete a verification process before allowing uninstallation:
  1. **Confirmation Phrase**: You must type the exact phrase: "I really mean it and want to uninstall this program now even though restrictions are running"
  2. **Arithmetic Questions**: You must correctly answer 10 arithmetic questions written in word form with step-by-step instructions (e.g., "Multiply 53 by 15, then add (31 minus 58), then add 147. What is the final result?")
- Questions are written in natural language to make copy-pasting into search engines or calculators more difficult.
- If you are **not** in restricted hours, uninstallation works normally without verification.
- The verification process requires cognitive engagement and effort, making it difficult to uninstall impulsively during restricted hours.

**Important Notes**:
- ⚠️ **This is an opt-in feature** - it is disabled by default (`none`) to avoid frustrating users.
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
  - ❌ **Does NOT affect `configure.sh` blocking** - Still blocked during restricted hours if `CONFIGURE_BLOCK_ENABLED=true`
  - ❌ **Does NOT affect `uninstall.sh` protection** - Still requires verification during restricted hours if `UNINSTALL_PROTECTION_MODE=difficult`
  - ❌ **Does NOT release restrictions** - Restrictions are still active, only warnings are suppressed
- **Pause is a temporary "quiet period" for warnings only**, not a release of restrictions
- The once-per-day limit is **always enforced** and cannot be disabled
- Pause buttons are available even during minimum display time - clicking pause immediately closes the popup (bypasses minimum display time)

**Configuration via Wizard**:
- Use menu option 9: **Enable pause and configure duration** in the configuration wizard
- Configure pause enabled/disabled and duration (5 or 10 minutes)
- Settings are saved to the config file with the `PAUSE_ENABLED` and `PAUSE_DURATION` format

**Viewing Pause Status**:
- Check pause status: `sleep-warning-status` (shows pause configuration and current status)
- View pause details: `sleep-warning-manage` → Option 2 "View Pause Status"

**Use Cases**:
- **Legitimate Exceptions**: Finish a task or handle an emergency without constant popup interruptions
- **Flexibility**: Provides a controlled way to temporarily suppress warnings while maintaining restriction effectiveness
- **Self-Control Aid**: The once-per-day limit prevents overuse while allowing necessary exceptions

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

# Popup size: small, medium, large, or custom WIDTHxHEIGHT
POPUP_SIZE=medium

# Popup position: center or top-left
POPUP_POSITION=center

# Minimum display time: Time popup must be visible before it can be closed (in seconds, 0-300)
POPUP_MIN_DISPLAY_TIME=30

# Prevent window movement: Prevent popup from being moved during minimum display time (true/false)
POPUP_IMMOVABLE=true

# Block scripts during restricted hours: Prevent configure.sh and manage.sh from running during restricted hours (true/false)
# This is an opt-in security feature - disabled by default
CONFIGURE_BLOCK_ENABLED=false

# Uninstall protection mode: Require verification to uninstall during restricted hours (none/difficult)
# none = No protection - uninstall works normally (default)
# difficult = Difficult uninstall - requires confirmation phrase + 10 arithmetic questions (recommended)
# This is an opt-in security feature - disabled by default
UNINSTALL_PROTECTION_MODE=none

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
6. **Security Settings** - Configure blocking of configure.sh and manage.sh during restricted/lock hours
7. **Lock Hours Configuration** - Configure additional hours when configuration/management is blocked (separate from restriction hours)
8. **Uninstall Protection** - Configure protection mode for uninstall.sh during restricted hours
9. **Review and Save** - Review your configuration and save changes

**Visual Day/Time Grid**:
The grid view (option 5) provides a convenient way to see all days of the week and their configured time ranges at a glance. The grid displays:
- All 7 days (Sunday through Saturday) in a single view
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
nano ~/.config/sleep-warning/sleep-warning.conf
# or
vim ~/.config/sleep-warning/sleep-warning.conf
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

- **Hours**: Must be integers between 0 and 23
- **Hour ranges**: Start hour must be less than end hour
- **CHECK_INTERVAL**: Must be between 1 and 60
- **POPUP_SIZE**: Must be `small`, `medium`, `large`, or match `WIDTHxHEIGHT` format
- **POPUP_POSITION**: Must be one of the valid position names
- **POPUP_MIN_DISPLAY_TIME**: Must be between 0 and 300

Invalid values will be ignored and default values will be used instead. The script will log warnings for invalid configuration values.

## Troubleshooting

### Configuration Not Taking Effect

1. **Check file location**: Ensure the file is at `~/.config/sleep-warning/sleep-warning.conf`
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
cat ~/.config/sleep-warning/sleep-warning.conf
```

## Additional Resources

- **Main Documentation**: See [README.md](../README.md) for general information
- **Technical Details**: See [../dev-docs/TECHNICAL_DETAILS.md](../dev-docs/TECHNICAL_DETAILS.md) for implementation details
- **SteamOS Gaming Mode**: See [../dev-docs/STEAMOS_GAMING_MODE.md](../dev-docs/STEAMOS_GAMING_MODE.md) for Gaming Mode compatibility information
