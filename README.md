# Linux Sleep Warning System

A systemd-based monitoring system that displays interactive warning popups when your Linux system is being used during configurable restricted hours (e.g., late night/early morning).

## ⚠️ Disclaimer

**IMPORTANT - PLEASE READ CAREFULLY**

This software is provided "AS IS", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.

**User Responsibility:**
- Users are responsible for backing up important data before installing or using this software
- Users acknowledge that they use this software at their own risk
- The developers are not responsible for any errors, data loss, system instability, or adverse effects resulting from the use of this software

**System Modifications:**
- This software modifies systemd user services and system configuration
- Improper installation or configuration may affect system behavior
- Uninstallation should be performed using the provided uninstall script

**Compatibility:**
- Compatibility cannot be guaranteed for all systems
- Some features may not work on all Linux distributions or desktop environments
- SteamOS Gaming Mode compatibility is actively being developed but may have limitations

**Support:**
- Support is provided on a best-effort basis
- No guarantee is made regarding response time or resolution of issues
- Users are encouraged to review logs and documentation before requesting support

**By installing or using this software, you acknowledge that you have read, understood, and agree to this disclaimer. If you do not agree, do not install or use this software.**

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

For the best experience with stay-on-top and immovable window features, install window management tools. See [GETTING_STARTED.md](GETTING_STARTED.md#step-3-install-optional-window-management-tools-recommended) for installation commands for your distribution.

These tools enable popups to stay on top and remain immovable during the minimum display time. The system works without them, but with reduced window management capabilities.

3. **Configure restricted hours** (recommended second step):
```bash
sleep-warning-configure
```

Or if running from the source directory:
```bash
./configure.sh
```

The configuration wizard will help you set up your restricted hours schedule.

**Command-line options**:
- `--text` or `--no-gui`: Force text mode (useful for SSH sessions or when GUI isn't working)
- `--gui`: Force GUI mode (requires zenity)
- `--help` or `-h`: Show help message

By default, the wizard uses GUI mode if zenity is available and a display is present.

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

The configuration wizard provides options for timer settings, window behavior, and day-by-day hour configuration. The **Visual Day/Time Grid** is particularly useful for seeing your entire schedule at once and making quick edits.

Or edit the configuration file directly at `~/.config/sleep-warning/sleep-warning.conf`:

```
# Format: DAY=START_HOUR-END_HOUR (24-hour format, 0-23)
SUNDAY=1-5
MONDAY=0-5
# ... etc
```

**Time Range Options**:
- **Single range**: `0-5` = Midnight to 4:59 AM
- **Multiple ranges**: `0-5,22-23` = Midnight to 4:59 AM AND 10 PM to 11:59 PM (comma-separated)
- **Overnight ranges**: `23-6` = 11:00 PM to 5:59 AM (spans midnight to next day)

**Note**: Overnight ranges span from the named day into the next day. For example, `MONDAY=23-6` means Monday 11:00 PM → Tuesday 5:59 AM.

See [user-docs/CONFIGURATION.md](user-docs/CONFIGURATION.md) for complete configuration options, detailed examples, and all available settings (popup size, position, minimum display time, etc.).

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

This provides an interactive menu for service management, configuration viewing, and troubleshooting.

**Quick Commands**:
- **Check status**: `systemctl --user status sleep-warning.timer`
- **Stop temporarily**: `systemctl --user stop sleep-warning.timer`
- **Start again**: `systemctl --user start sleep-warning.timer`
- **Disable**: `systemctl --user disable sleep-warning.timer`

For complete service management documentation, see [USER_GUIDE.md](USER_GUIDE.md#managing-the-service).

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

### Common Issues

**Popup doesn't appear**:
- Check if timer is running: `systemctl --user status sleep-warning.timer`
- Verify it's during restricted hours: `sleep-warning-status`
- Check logs: `tail ~/.config/sleep-warning/warnings.log`
- Verify dialog tool installed: `which zenity`

**Popup doesn't stay on top**:
- Install window management tools: `sudo apt install wmctrl xdotool` (Ubuntu/Debian) or equivalent
- These tools are required for stay-on-top functionality

**Popup doesn't appear over full-screen games**:
- Some exclusive full-screen games may block window manager dialogs
- Try borderless windowed mode in your game settings

**Timer not starting on boot**:
- Ensure timer is enabled: `systemctl --user enable sleep-warning.timer`
- Check user lingering: `loginctl show-user $USER | grep Lingering`

For detailed troubleshooting with diagnosis steps and decision trees, see [USER_GUIDE.md](USER_GUIDE.md#troubleshooting).

## Development

See `dev-docs/linux-warning-system-plan.md` for the complete implementation plan and architecture details.

## License

[TO BE ADDED]

