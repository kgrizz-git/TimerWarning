# Linux Sleep Warning System

A systemd-based monitoring system that displays interactive warning popups when your Linux system is being used during configurable restricted hours (e.g., late night/early morning).

## Features

- ⏰ **Configurable restricted hours** - Set different hours for each day of the week
- 🔔 **Modal warning popups** - Ensures you're aware of late-night usage
- 🚀 **Easy installation** - Automated installation script handles everything
- 🔄 **Auto-start on boot** - Runs automatically via systemd timer
- 🎮 **Full-screen compatible** - Works with games and full-screen applications
- 🐧 **Cross-distribution** - Works on any Linux distribution with systemd

## Quick Start

### Prerequisites

- Linux distribution with systemd (Ubuntu, Debian, Fedora, Arch, Steam OS, etc.)
- Graphical desktop environment (GNOME, KDE, XFCE, etc.)
- `zenity` (will be installed automatically if missing)

### Installation

1. Clone this repository:
```bash
git clone https://github.com/YOUR_USERNAME/LinuxTimerWarning.git
cd LinuxTimerWarning
```

2. Run the installation script:
```bash
./install.sh
```

That's it! The script will:
- Detect your Linux distribution
- Install required dependencies (zenity)
- Copy files to the correct locations
- Enable and start the service

### Default Configuration

By default, warnings are shown during:
- **Weekdays (Monday-Friday)**: Midnight (00:00) to 6:00 AM
- **Weekends (Saturday-Sunday)**: 1:00 AM to 6:00 AM

You can customize these hours by editing `~/.config/sleep-warning/sleep-warning.conf`.

## Configuration

Edit the configuration file at `~/.config/sleep-warning/sleep-warning.conf`:

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
```

## Usage

Once installed, the system runs automatically. The timer checks every 10 minutes and displays a warning popup if you're using the system during restricted hours.

### Manual Control

- **Check status**: `systemctl --user status sleep-warning.timer`
- **View logs**: `journalctl --user -u sleep-warning.service`
- **Stop temporarily**: `systemctl --user stop sleep-warning.timer`
- **Start again**: `systemctl --user start sleep-warning.timer`
- **Disable**: `systemctl --user disable sleep-warning.timer`

## Uninstallation

To remove the system:

```bash
./uninstall.sh
```

Or manually:
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

- **systemd** - Pre-installed on most modern Linux distributions
- **bash** - Pre-installed on all Linux systems
- **zenity** - GTK dialog tool (installed automatically by install script)

## Troubleshooting

### Popup doesn't appear
- Check if the timer is running: `systemctl --user status sleep-warning.timer`
- Check logs: `journalctl --user -u sleep-warning.service`
- Verify zenity is installed: `which zenity`

### Popup doesn't appear over full-screen games
- Some exclusive full-screen games may block window manager dialogs
- Try using borderless windowed mode in your game
- Behavior varies by desktop environment and window manager

### Timer not starting on boot
- Ensure the timer is enabled: `systemctl --user enable sleep-warning.timer`
- Check if user services are enabled: `loginctl show-user $USER | grep Lingering`

## Development

See `linux-warning-system-plan.md` for the complete implementation plan and architecture details.

## License

[Add your license here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
