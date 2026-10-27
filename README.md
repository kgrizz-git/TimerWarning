<p align="center">
  <img src="assets/icon.svg" alt="TimerWarning icon: a crescent moon with a clock" width="128" height="128">
</p>

# TimerWarning (Sleep Warning System for SteamOS, Linux & macOS)

[![Security](https://github.com/kgrizz-git/TimerWarning/actions/workflows/security.yml/badge.svg?branch=main)](https://github.com/kgrizz-git/TimerWarning/actions/workflows/security.yml)
[![License: Apache 2.0 + Commons Clause](https://img.shields.io/badge/license-Apache%202.0%20%2B%20Commons%20Clause-blue)](LICENSE)
[![Platforms: SteamOS | Linux | macOS](https://img.shields.io/badge/platforms-SteamOS%20%7C%20Linux%20%7C%20macOS-lightgrey)](user-docs/MACOS.md)
[![Shell: Bash 4+](https://img.shields.io/badge/shell-bash%204%2B-4EAA25?logo=gnubash&logoColor=white)](dev-docs/development/testing.md)
[![ShellCheck](https://img.shields.io/badge/lint-ShellCheck-informational)](dev-docs/development/security-scanning.md)

A monitoring system that displays interactive warning popups when your computer is used during configurable restricted hours (e.g., late night/early morning). It works on Steam Deck. **Linux and SteamOS:** systemd timer. **macOS:** LaunchAgent — see [user-docs/MACOS.md](user-docs/MACOS.md).

## 🛡️ Safety first

Safety is the top priority. A popup that can interrupt your computer use has to be easy to stop, so unless the code is modified, the safeguards are built in and cannot be configured away. No category of restriction can cover more than 16 hours of any day, every popup has a finite lifetime, and there is always a documented way to turn the whole system off.

| Audience | Start here |
|----------|------------|
| **Everyone** | [**docs/SAFETY.md**](docs/SAFETY.md) — no 24/7 warnings, popups must end, emergency stop |
| **Developers / agents** | [AGENTS.md](AGENTS.md) → [dev-docs/CONTRIBUTING.md](dev-docs/CONTRIBUTING.md) |
| **macOS users** | [user-docs/MACOS.md](user-docs/MACOS.md) (troubleshooting + `launchctl bootout` / `killall osascript`) |

If you have not modified the code, you do not need to do anything special: the configure wizard enforces these limits for you. If a popup ever will not dismiss, the emergency steps in **docs/SAFETY.md** turn the system off. If you change the code, read that file first.

## ⚠️ Disclaimer

**IMPORTANT - PLEASE READ CAREFULLY**

This software is provided "AS IS", without warranty of any kind, express or implied. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability arising from the use of this software.

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
- SteamOS Desktop Mode is supported. Gaming Mode overlay support is experimental and off by default (`GAMING_MODE_EXPERIMENTAL_ENABLED=false`). A Steam Deck check on 2026-10-19 showed the popup over a fullscreen game, and a 2026-10-20 check showed click and Enter reaching the dialog without Enter also firing into Steam. Still unchecked: pause-enabled buttons, touch, countdown input, the Quick Access Menu after the popup closes, forced timeout, and docked versus undocked. Some fullscreen games can still hide the popup.
- On Wayland/gamescope, always-on-top behavior is best-effort and full-screen games may block popups

**Support:**
- Provided on a best-effort basis with no guarantees
- Please review logs and documentation before requesting help

**By installing or using this software, you acknowledge that you have read, understood, and agree to this disclaimer. If you do not agree, do not install or use this software.**

## Features

- ⏰ **Configurable restricted hours** - Set different hours for each day of the week
- 🔔 **Modal warning popups** - Ensures you're aware of late-night usage
- 🚀 **Easy installation** - Automated installation script handles everything
- 🔄 **Auto-start on boot** - Runs automatically via systemd timer
- 🎮 **Desktop and experimental Gaming Mode** - Desktop Mode is supported. Gaming Mode is experimental, off by default, and partially checked on a Steam Deck (2026-10-19 and 2026-10-20)
- 🐧 **Cross-distribution** - Works on Linux with systemd, and on macOS with a user LaunchAgent
- 🔒 **Minimum display time** - Ensures warnings are visible for a set duration
- 📌 **Immovable windows** - Prevents popup from being moved during countdown (optional)
- ⬆️ **Always on top** - Popup windows automatically stay above other windows
- ⏸️ **Pause** - Suppress warnings for 1, 2, 3, 5, 10, or 15 minutes (default 5), then wait 6, 8, 12, or 24 hours (default 24) before another pause

## Support Development

If you find this software useful and would like to support future development, donations are greatly appreciated (but completely optional). Your support helps maintain and improve the project.

[Donate via PayPal](https://www.paypal.com/donate/?business=FMVBCJ2CT7L7S&no_recurring=0&item_name=Making+software+I+hope+people+find+useful.+Thank+you+for+supporting+future+development.&currency_code=USD)

Thank you for using TimerWarning!

## Quick Start

### Prerequisites

- Linux distribution with systemd (Ubuntu, Debian, Fedora, Arch, Steam OS, etc.)
- Graphical desktop environment (GNOME, KDE, XFCE, etc.)
- Dialog tool: `yad` (preferred), `zenity`, or `kdialog` (zenity will be installed automatically if missing)
- **Optional but recommended**: `wmctrl` or `xdotool` for enhanced window management features (stay-on-top, immovable windows)

### Installation

**Important**: Both installation and configuration steps should be completed. The recommended order is to install first, then configure, but both scripts can be run in any order.

**Note**: The installation script requires a terminal to run properly. If you're using a desktop file manager:
- **Recommended**: Right-click the `install.sh` file and select "Open in Terminal" or "Open Terminal Here"
- **Alternative**: Open a terminal manually, navigate to the project directory, then run `./install.sh`
- **Auto-confirm mode**: If you must run from desktop, use `./install.sh --yes` to skip prompts (requires zenity to be already installed)

**Sudo Requirements**: 
- **Sudo is only needed if dependencies need to be installed**. If all required dependencies (zenity, yad, wmctrl/xdotool) are already installed, the installation script will not require sudo privileges.
- For **non-interactive installation** (`./install.sh --yes`), ensure sudo password is cached (run `sudo -v` first) or configure passwordless sudo if all dependencies need to be installed.

1. **Download the project** (choose one method):

   **Option A: Clone with Git** (recommended for easy updates):
   ```bash
   git clone https://github.com/kgrizz-git/TimerWarning.git
   cd TimerWarning
   ```
   *Note: With Git, you can easily update to newer versions later by running `git pull` in the repository directory.*

   **Option B: Download ZIP file**:
   - Go to the GitHub repository: https://github.com/kgrizz-git/TimerWarning
   - Click the green "Code" button, then select "Download ZIP"
   - Extract the ZIP file to a location of your choice
   - Open a terminal in the extracted `TimerWarning` directory

2. **Install the system** (recommended first step):
```bash
./install.sh
```

The installation script will:
- Detect your Linux distribution
- Install required dependencies (zenity for dialog popups)
- Offer to install optional tools (yad preferred, wmctrl, xdotool) for enhanced features
- Copy files to the correct locations
- Enable and start the service

**Optional: Install enhanced tools**

The installation script will automatically offer to install optional tools (`yad`, `wmctrl`, `xdotool`) for enhanced features. See [GETTING_STARTED.md](GETTING_STARTED.md#step-3-install-optional-tools-recommended) for manual installation commands if needed.

These tools enable:
- Better popup positioning (`yad`)
- Popups to stay on top of other windows (`wmctrl`/`xdotool`)
- Immovable popup windows during minimum display time (`wmctrl`/`xdotool`)

The system works without these tools, but with reduced window management capabilities. If dialog tools fail entirely, a non-modal notification fallback (notify-send) is used when available.

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
- `--gui`: Force GUI mode (requires yad, zenity, or kdialog)
- `--help` or `-h`: Show help message

By default, the wizard uses GUI mode if a dialog tool (yad/zenity/kdialog) is available and a display is present. The system prefers YAD when available for better features.

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

You can customize these hours using the configuration wizard (`sleep-warning-configure`) or by editing `~/.config/sleep-warning/config/sleep-warning.conf` manually.

## Configuration

You can configure restricted hours using the interactive wizard:

```bash
sleep-warning-configure
```

The configuration wizard provides options for timer settings, window behavior, and day-by-day hour configuration. The **Visual Day/Time Grid** is particularly useful for seeing your entire schedule at once and making quick edits.

Or edit the configuration file directly at `~/.config/sleep-warning/config/sleep-warning.conf`:

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
- **Stop now**: `systemctl --user stop sleep-warning.timer`
- **Stay stopped after login/boot**: `systemctl --user disable sleep-warning.timer`
- **Turn scheduling back on**: `systemctl --user enable --now sleep-warning.timer`

For complete service management documentation, see [user-docs/USER_GUIDE.md](user-docs/USER_GUIDE.md#managing-the-service).

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

### macOS

- ✅ **macOS 13 (Ventura)** and later (Apple Silicon and Intel)
- Uses a per-user **LaunchAgent** and **osascript** dialogs (not systemd/GTK)
- See [user-docs/MACOS.md](user-docs/MACOS.md) for install, safety guardrails, and troubleshooting

### Linux Distributions
- ✅ Steam OS (Arch-based)
  - **Desktop Mode**: Supported on SteamOS Desktop Mode (KDE on X11). Popups work with some full-screen games; results vary by game, and exclusive full-screen games may still cover them.
  - **Gaming Mode (Experimental)**: Off by default (`GAMING_MODE_EXPERIMENTAL_ENABLED=false`). Option 12 in `sleep-warning-configure` routes dialogs through `gamescope`'s Xwayland overlay plane (`:0`) with `STEAM_OVERLAY=1` / `STEAM_INPUT_FOCUS=1` and forced auto-close. Deck results: visible on 2026-10-19; click and Enter reached the dialog on 2026-10-20, and Enter did not also fire into Steam. Still unchecked: pause-enabled buttons, touch, countdown input, the Quick Access Menu after close, forced timeout, and docked versus undocked. See [dev-docs/STEAMOS_GAMING_MODE.md](dev-docs/STEAMOS_GAMING_MODE.md).
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
- **Dialog tool** - At least one of (priority order: YAD → Zenity → KDialog):
  - **yad** - Enhanced GTK dialog tool (preferred) - Better positioning, reliable sizing, improved window management
    - **Installation**: `sudo apt install yad` (Ubuntu/Debian), `sudo dnf install yad` (Fedora), `sudo pacman -S yad` (Arch/SteamOS), `sudo zypper install yad` (openSUSE)
  - **zenity** - GTK dialog tool (fallback, installed automatically by install script)
    - **Installation**: `sudo apt install zenity` (Ubuntu/Debian), `sudo dnf install zenity` (Fedora), `sudo pacman -S zenity` (Arch/SteamOS), `sudo zypper install zenity` (openSUSE)
  - **kdialog** - KDE dialog tool (last resort, native on KDE systems)

The system automatically detects which dialog tool is available and uses them in priority order (YAD → Zenity → KDialog) across all environments. This unified priority ensures consistent behavior regardless of desktop environment.

### Optional (Recommended for Enhanced Features)
- **yad** - Enhanced GTK dialog tool with better positioning and Wayland support
  - **Installation**: `sudo apt install yad` (Ubuntu/Debian), `sudo dnf install yad` (Fedora), `sudo pacman -S yad` (Arch/SteamOS), `sudo zypper install yad` (openSUSE)
  - Required for popup position control (`POPUP_POSITION` configuration)
  - Preferred for SteamOS Gaming Mode
  - Better Wayland compatibility than zenity
- **wmctrl** - X11 window manager control tool
- **xdotool** - X11 automation tool

**yad benefits** (preferred dialog tool):
- Native popup positioning control (required for position configuration)
- Reliable window sizing
- Improved Wayland support
- Enhanced window management options
- Better overall dialog capabilities

**Note**: The system uses a unified priority (YAD → Zenity → KDialog) across all environments. YAD is preferred when available for its superior technical capabilities.

**Window management tools (wmctrl/xdotool) enable:**
- Always-on-top popup windows
- Immovable popup windows during minimum display time
- Better window state detection

Without these tools, popups will still appear but may not stay on top of other windows or support position control.

## Troubleshooting

### Common Issues

**Popup doesn't appear**:
- Check if timer is running: `systemctl --user status sleep-warning.timer`
- Verify it's during restricted hours: `sleep-warning-status`
- Check logs: `tail ~/.config/sleep-warning/warnings.log`
- Verify dialog tool installed: `which yad` or `which zenity` or `which kdialog`

**Popup doesn't stay on top**:
- Install window management tools: `sudo apt install wmctrl xdotool` (Ubuntu/Debian) or equivalent
- These tools are required for stay-on-top functionality

**Popup doesn't appear over full-screen games**:
- Some exclusive full-screen games may block window manager dialogs
- Try borderless windowed mode in your game settings

**Timer not starting on boot**:
- Ensure timer is enabled: `systemctl --user enable sleep-warning.timer`
- Check user lingering: `loginctl show-user $USER | grep Lingering`

For detailed troubleshooting with diagnosis steps and decision trees, see [user-docs/USER_GUIDE.md](user-docs/USER_GUIDE.md#troubleshooting).

## License

Copyright (c) 2026 kgrizz-git

TimerWarning is source-available under the [Apache License 2.0](LICENSE) with the [Commons Clause License Condition v1.0](LICENSE). The combination is not an OSI open-source license.

You may use, modify, and redistribute this software, including for a company's own internal use, if you follow [`LICENSE`](LICENSE). You may not Sell it. The Commons Clause defines Sell as providing the software to third parties, for a fee or other consideration (including fees for hosting or consulting/support services related to the software), as a product or service whose value derives, entirely or substantially, from the functionality of the software.

Keep this copyright notice, the Commons Clause, and the Apache License with every copy. Installation copies `LICENSE` to `~/.local/lib/sleep-warning/LICENSE`. The software is provided as-is, without warranty. [`LICENSE`](LICENSE) is the full terms.

