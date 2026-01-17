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
- `small`: 300x150 pixels
- `medium`: 400x200 pixels (default)
- `large`: 500x250 pixels

**Custom Size Format**: `WIDTHxHEIGHT`
- Width: 200-2000 pixels
- Height: 100-2000 pixels

**Default**: `medium`

**Examples**:
```
POPUP_SIZE=medium      # Use medium size (400x200)
POPUP_SIZE=small       # Use small size (300x150)
POPUP_SIZE=large       # Use large size (500x250)
POPUP_SIZE=450x220     # Custom size: 450 pixels wide, 220 pixels tall
```

**Note**: Custom sizes outside the valid range (200-2000 width, 100-2000 height) will be reset to the default medium size.

### Popup Position

**Option**: `POPUP_POSITION`

**Description**: Position of the warning popup on the screen.

**Format**: One of the following position names:
- `center` (default)
- `top-left`
- `top-right`
- `bottom-left`
- `bottom-right`
- `top-center`
- `bottom-center`

**Default**: `center`

**Examples**:
```
POPUP_POSITION=center         # Center of screen (default)
POPUP_POSITION=top-left       # Top-left corner
POPUP_POSITION=bottom-right   # Bottom-right corner
POPUP_POSITION=top-center     # Top center of screen
```

**Note**: 
- Position control requires `yad` dialog tool or window manager tools (`wmctrl`/`xdotool`) for full functionality.
- `zenity` does not support position control and will always center the popup.
- Position control works best on X11; Wayland support is limited.

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

# Popup position: center, top-left, top-right, bottom-left, bottom-right, top-center, bottom-center
POPUP_POSITION=center

# Minimum display time: Time popup must be visible before it can be closed (in seconds, 0-300)
POPUP_MIN_DISPLAY_TIME=30

# Prevent window movement: Prevent popup from being moved during minimum display time (true/false)
POPUP_IMMOVABLE=true

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
POPUP_POSITION=bottom-right
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
6. **Review and Save** - Review your configuration and save changes

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
