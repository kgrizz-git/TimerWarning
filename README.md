# Linux Sleep Warning System

A systemd-based monitoring system that displays interactive warning popups when your Linux system is being used during configurable restricted hours (e.g., late night/early morning).

## Features

- ⏰ **Configurable restricted hours** - Set different hours for each day of the week
- 🔔 **Modal warning popups** - Ensures you're aware of late-night usage
- 🚀 **Easy installation** - Automated installation script handles everything
- 🔄 **Auto-start on boot** - Runs automatically via systemd timer
- 🎮 **Full-screen compatible** - Works with games and full-screen applications
- 🐧 **Cross-distribution** - Works on any Linux distribution with systemd
- 🔒 **Minimum display time** - Ensures warnings are visible for a set duration
- 📌 **Immovable windows** - Prevents popup from being moved during countdown (optional)
- ⬆️ **Always on top** - Popup windows automatically stay above other windows

## Quick Start

### Prerequisites

- Linux distribution with systemd (Ubuntu, Debian, Fedora, Arch, Steam OS, etc.)
- Graphical desktop environment (GNOME, KDE, XFCE, etc.)
- Dialog tool: `zenity`, `yad`, or `kdialog` (zenity will be installed automatically if missing)
- **Optional but recommended**: `wmctrl` or `xdotool` for enhanced window management features (stay-on-top, immovable windows)

### Installation

**Important**: Both installation and configuration steps should be completed. The recommended order is to install first, then configure, but both scripts can be run in any order.

**Note**: The installation script requires a terminal to run properly. If you're using a desktop file manager:
- **Recommended**: Right-click the `install.sh` file and select "Open in Terminal" or "Open Terminal Here"
- **Alternative**: Open a terminal manually, navigate to the project directory, then run `./install.sh`
- **Auto-confirm mode**: If you must run from desktop, use `./install.sh --yes` to skip prompts (requires zenity to be already installed)

1. **Download the project** (choose one method):

   **Option A: Clone with Git** (recommended for easy updates):
   ```bash
   git clone https://github.com/YOUR_USERNAME/LinuxTimerWarning.git
   cd LinuxTimerWarning
   ```
   *Note: With Git, you can easily update to newer versions later by running `git pull` in the repository directory.*

   **Option B: Download ZIP file**:
   - Go to the GitHub repository: https://github.com/YOUR_USERNAME/LinuxTimerWarning
   - Click the green "Code" button, then select "Download ZIP"
   - Extract the ZIP file to a location of your choice
   - Open a terminal in the extracted `LinuxTimerWarning` directory

2. **Install the system** (recommended first step):
```bash
./install.sh
```

The installation script will:
- Detect your Linux distribution
- Install required dependencies (zenity for dialog popups)
- Copy files to the correct locations
- Enable and start the service

**Optional: Install window management tools for enhanced features**

For the best experience with stay-on-top and immovable window features, install window management tools:

```bash
# Ubuntu/Debian
sudo apt install wmctrl xdotool

# Fedora
sudo dnf install wmctrl xdotool

# Arch/Steam OS
sudo pacman -S wmctrl xdotool
```

These tools enable:
- Keeping popups always on top of other windows
- Preventing popups from being moved during the minimum display time
- Better window state detection

The system works without these tools, but with reduced window management capabilities.

3. **Configure restricted hours** (recommended second step):
```bash
sleep-warning-configure
```

Or if running from the source directory:
```bash
./configure.sh
```

The configuration wizard will help you set up your restricted hours schedule.

**Note**: If you get "command not found" when running `sleep-warning-configure`, you may need to:
- Restart your terminal (to reload PATH), or
- Run `source ~/.bashrc` in your current terminal, or
- Use the full path: `~/.local/bin/sleep-warning-configure`

The install script adds `~/.local/bin` to your PATH in `~/.bashrc`, but existing terminal sessions need to be restarted or reloaded to pick up the change.

**Note**: Both steps can be run in any order:
- **Install → Configure** (recommended): System is set up first, then customized
- **Configure → Install**: Custom settings are created first, then system is installed (settings are preserved)

### Default Configuration

By default, warnings are shown during:
- **Weekdays (Monday-Friday)**: Midnight (00:00) to 6:00 AM
- **Weekends (Saturday-Sunday)**: 1:00 AM to 6:00 AM

You can customize these hours using the configuration wizard (`sleep-warning-configure`) or by editing `~/.config/sleep-warning/sleep-warning.conf` manually.

## Configuration

You can configure restricted hours using the interactive wizard:

```bash
sleep-warning-configure
```

Or edit the configuration file at `~/.config/sleep-warning/sleep-warning.conf`:

```
# Sleep Warning Configuration
# Format: DAY=START_HOUR-END_HOUR
# Hours are in 24-hour format (0-23)

SUNDAY=1-5
MONDAY=0-5
TUESDAY=0-5
WEDNESDAY=0-5
THURSDAY=0-5
FRIDAY=0-5
SATURDAY=1-5

# Optional: Minimum time popup must be visible (in seconds, 0-300)
POPUP_MIN_DISPLAY_TIME=30

# Optional: Prevent window movement during minimum display time (true/false)
POPUP_IMMOVABLE=true
```

See [user-docs/CONFIGURATION.md](user-docs/CONFIGURATION.md) for complete configuration options including popup size, position, and advanced settings.

### Time Range Options

**Single Range**: One time period per day
- `0-5` = Midnight (00:00) to 5:59 AM
- `22-23` = 10:00 PM to 11:59 PM

**Multiple Ranges**: Multiple time periods per day (comma-separated)
- `0-5,22-23` = Midnight to 5:59 AM AND 10 PM to 11:59 PM
- Useful for restricting both late night and early morning usage

**Overnight Ranges**: Time periods that span midnight (start hour > end hour)
- `23-6` = 11:00 PM to 6:00 AM (spans midnight to next day)
- `22-8` = 10:00 PM to 8:00 AM (overnight)

**Important - Overnight Range Behavior**:
When you specify an overnight range like `23-6` on Monday, it means:
- **Monday 11:00 PM → Tuesday 6:00 AM**

The range spans from the named day into the next day. If you also set `TUESDAY=0-5`, both ranges will cover Tuesday midnight to 5:59 AM. This is harmless (only one warning will be shown), but redundant.

**Examples**:
```
MONDAY=0-5,22-23    # Midnight to 5:59 AM AND 10 PM to 11:59 PM (same day)
TUESDAY=23-6        # Tuesday 11:00 PM → Wednesday 6:00 AM (overnight)
WEDNESDAY=0-5       # Midnight to 5:59 AM only (same day)
THURSDAY=23-5       # Thursday 11:00 PM → Friday 5:00 AM (overnight)
```

**Overlapping Ranges**:
If you set overlapping ranges (e.g., `MONDAY=23-5` and `TUESDAY=0-5`), both will cover Tuesday midnight to 5:59 AM. The system will only show one warning during the overlap period, so this is harmless but redundant. The configuration wizard will warn you about overlaps when you save your settings.

## Usage

Once installed, the system runs automatically. The timer checks every 10 minutes by default and displays a warning popup if you're using the system during restricted hours. This frequency can be configured with the configuration wizard (run sleep-warning-configure in the terminal or ./configure.sh in the source directory) or by manually editing `CHECK_INTERVAL` in the configuration file.

### Check Status

View the current status and configuration:

```bash
sleep-warning-status
```

This displays:
- Installation status (service and timer files)
- Service status (enabled, running, next check time)
- Current configuration (check interval, popup settings, restricted hours)
- Quick reference commands

### Manual Control

**Interactive Management Menu** (recommended):
```bash
sleep-warning-manage
```

This provides an interactive menu to:
- View service status
- Start/stop the timer
- Enable/disable the timer
- View logs
- Get help and information

**Direct systemctl commands**:
- **Check status**: `systemctl --user status sleep-warning.timer`
- **View logs**: `journalctl --user -u sleep-warning.service`
- **Stop temporarily**: `systemctl --user stop sleep-warning.timer`
- **Start again**: `systemctl --user start sleep-warning.timer`
- **Disable**: `systemctl --user disable sleep-warning.timer`

## Uninstallation

To remove the system:

```bash
sleep-warning-uninstall
```

Or from the source directory:
```bash
./uninstall.sh
```

**Options**:
- `sleep-warning-uninstall` - Uninstalls the system (prompts about config file)
- `sleep-warning-uninstall --remove-config` - Uninstalls including configuration file

**Manual uninstallation**:
```bash
systemctl --user stop sleep-warning.timer
systemctl --user disable sleep-warning.timer
rm ~/.local/bin/sleep-warning.sh
rm ~/.config/systemd/user/sleep-warning.service
rm ~/.config/systemd/user/sleep-warning.timer
systemctl --user daemon-reload
```

## Supported Systems

### Linux Distributions
- ✅ Steam OS (Arch-based)
- ✅ Ubuntu (18.04+)
- ✅ Debian (8+)
- ✅ Fedora
- ✅ Arch Linux / Manjaro
- ✅ openSUSE
- ✅ CentOS/RHEL (7+)
- ✅ Pop!_OS
- ✅ Linux Mint

### Desktop Environments
- ✅ GNOME
- ✅ KDE Plasma (Steam OS uses KDE)
- ✅ XFCE
- ✅ LXDE/LXQt
- ✅ MATE
- ✅ Cinnamon

## Requirements

### Required
- **systemd** - Pre-installed on most modern Linux distributions
- **bash** - Pre-installed on all Linux systems
- **Dialog tool** - At least one of:
  - **zenity** - GTK dialog tool (installed automatically by install script) - **Primary choice**
  - **yad** - Enhanced GTK dialog tool (alternative)
  - **kdialog** - KDE dialog tool (alternative, native on KDE systems)

The system automatically detects which dialog tool is available and uses the most appropriate one for your desktop environment.

### Optional (Recommended for Enhanced Features)
- **wmctrl** - X11 window manager control tool
- **xdotool** - X11 automation tool

These tools enable advanced window management features:
- Always-on-top popup windows
- Immovable popup windows during minimum display time
- Better window state detection

Without these tools, popups will still appear but may not stay on top of other windows.

## Troubleshooting

### Popup doesn't appear
- Check if the timer is running: `systemctl --user status sleep-warning.timer`
- Check logs: `journalctl --user -u sleep-warning.service`
- Verify a dialog tool is installed: `which zenity` or `which yad` or `which kdialog`
- Check the warning log: `tail ~/.config/sleep-warning/warnings.log`

### Popup doesn't appear over full-screen games
- Some exclusive full-screen games may block window manager dialogs
- Try using borderless windowed mode in your game
- Behavior varies by desktop environment and window manager

### Popup doesn't stay on top
- Install window management tools: `sudo apt install wmctrl xdotool` (Ubuntu/Debian) or equivalent for your distribution
- The system requires `wmctrl` or `xdotool` for stay-on-top functionality
- Check if tools are detected: Run the script and check `~/.config/sleep-warning/warnings.log`

### Timer not starting on boot
- Ensure the timer is enabled: `systemctl --user enable sleep-warning.timer`
- Check if user services are enabled: `loginctl show-user $USER | grep Lingering`

## Development

See `dev-docs/linux-warning-system-plan.md` for the complete implementation plan and architecture details.

## License

[TO BE ADDED]

