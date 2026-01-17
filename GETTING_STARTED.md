# Getting Started with Linux Sleep Warning System

This guide will help you get the Sleep Warning System up and running in just a few minutes. If you're new to Linux or systemd services, don't worry - we'll walk you through everything step by step.

## What Does This System Do?

The Sleep Warning System displays warning popups when you're using your computer during hours you've configured as "restricted" (typically late night or early morning). It helps you maintain healthy sleep schedules by making you aware of late-night computer usage.

**Key Features:**
- ⏰ Automatically checks every 10 minutes (configurable)
- 🔔 Shows modal popup warnings during restricted hours
- 🚀 Runs automatically in the background
- 🎮 Works with games and full-screen applications
- 📌 Popups stay visible for a minimum time (configurable)

## Before You Begin

### System Requirements

**Required:**
- Linux distribution with systemd (Ubuntu, Debian, Fedora, Arch, Steam OS, etc.)
- Graphical desktop environment (GNOME, KDE, XFCE, etc.)
- Terminal access

**Optional but Recommended:**
- Window management tools (`wmctrl` or `xdotool`) for enhanced features like keeping popups on top

### Check Your System

Open a terminal and verify you have systemd:
```bash
systemctl --version
```

If this command works, you're good to go! If not, your system may not use systemd (this system requires systemd).

## Installation Steps

### Step 1: Download the Project

Choose one of these methods:

**Option A: Clone with Git** (recommended for easy updates):
```bash
git clone https://github.com/YOUR_USERNAME/LinuxTimerWarning.git
cd LinuxTimerWarning
```

**Option B: Download ZIP file:**
1. Go to the GitHub repository
2. Click the green "Code" button, then select "Download ZIP"
3. Extract the ZIP file to a location of your choice
4. Open a terminal in the extracted `LinuxTimerWarning` directory

### Step 2: Run the Installation Script

**Important**: The installation script must be run from a terminal. If you're using a desktop file manager:
- **Recommended**: Right-click the `install.sh` file and select "Open in Terminal" or "Open Terminal Here"
- **Alternative**: Open a terminal manually, navigate to the project directory, then run the command below

Run the installation script:
```bash
./install.sh
```

**What the installation script does:**
1. Detects your Linux distribution
2. Checks for required dependencies (zenity for dialog popups)
3. Offers to install missing dependencies (you'll be prompted):
   - **zenity** (required) - Will be installed automatically if missing
   - **yad** (optional) - Enhanced dialog tool with better positioning
   - **wmctrl** and **xdotool** (optional) - Window management tools for enhanced features
4. Copies files to the correct locations:
   - Main script: `~/.local/bin/sleep-warning.sh`
   - Configuration wizard: `~/.local/bin/sleep-warning-configure`
   - Management script: `~/.local/bin/sleep-warning-manage`
   - Status script: `~/.local/bin/sleep-warning-status`
   - Systemd service files: `~/.config/systemd/user/`
5. Sets up the systemd timer
6. Enables and starts the service

**Manual Installation (if needed):**

If the automatic installation doesn't work or you prefer to install manually, here are the commands for **zenity** (required):

**Ubuntu/Debian/Linux Mint:**
```bash
sudo apt install zenity
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install zenity
```

**Arch Linux/Steam OS/Manjaro:**
```bash
sudo pacman -S zenity
```

**openSUSE:**
```bash
sudo zypper install zenity
```

**If you get a permission error:**
```bash
chmod +x install.sh
./install.sh
```

**Auto-confirm mode** (skip prompts):
```bash
./install.sh --yes
```

**Note**: After installation, you may need to restart your terminal or run `source ~/.bashrc` for the new commands to be available in your PATH.

### Step 3: Install Optional Tools (Recommended)

**Note**: The installation script will automatically offer to install these optional tools during installation. You can install them manually if you prefer or if the automatic installation was skipped.

For the best experience with popups staying on top and immovable windows, install window management tools:

**Ubuntu/Debian/Linux Mint:**
```bash
sudo apt install wmctrl xdotool
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install wmctrl xdotool
```

**Arch Linux/Steam OS/Manjaro:**
```bash
sudo pacman -S wmctrl xdotool
```

**openSUSE:**
```bash
sudo zypper install wmctrl xdotool
```

These tools enable:
- Popups to stay on top of other windows
- Popups to remain immovable during the minimum display time
- Better window state detection

**Note**: The system works without these tools, but with reduced window management capabilities.

**Optional: Install yad for Enhanced Dialog Features**

**Note**: The installation script will automatically offer to install `yad` during installation if it's not already installed.

For better popup positioning and improved Wayland/Gaming Mode support, you can install `yad` (an enhanced alternative to zenity):

**Ubuntu/Debian/Linux Mint:**
```bash
sudo apt install yad
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install yad
```

**Arch Linux/Steam OS/Manjaro:**
```bash
sudo pacman -S yad
```

**openSUSE:**
```bash
sudo zypper install yad
```

**Benefits of yad:**
- Better popup positioning control (required for `POPUP_POSITION` configuration)
- Improved Wayland support
- Preferred for SteamOS Gaming Mode
- Enhanced window control options

**Note**: `yad` is optional - the system works with `zenity` (installed automatically), but `yad` provides additional features.

### Step 4: Configure Your Restricted Hours

After installation, configure when you want warnings to appear:

```bash
sleep-warning-configure
```

**If the command isn't found:**
- Restart your terminal, or
- Run `source ~/.bashrc`, or
- Use the full path: `~/.local/bin/sleep-warning-configure`

**Or run from the source directory:**
```bash
./configure.sh
```

**The configuration wizard will guide you through:**
- Timer settings (check interval)
- Window behavior (popup size, position, display time)
- Weekday and weekend hour configuration
- Visual Day/Time Grid (recommended for seeing all days at once)

**Default Configuration:**
- **Weekdays (Monday-Friday)**: Midnight (00:00) to 6:00 AM
- **Weekends (Saturday-Sunday)**: 1:00 AM to 6:00 AM

You can customize these to match your schedule. For complete configuration options and examples, see [user-docs/CONFIGURATION.md](user-docs/CONFIGURATION.md).

**Command-line options:**
- `--text` or `--no-gui`: Force text mode (useful for SSH sessions)
- `--gui`: Force GUI mode (requires zenity)
- `--help` or `-h`: Show help message

### Step 5: Verify Installation

Check that everything is working:

```bash
sleep-warning-status
```

This displays:
- Installation status
- Service status (enabled, running, next check time)
- Current configuration (check interval, popup settings, restricted hours)
- Quick reference commands

**Expected output:**
- ✅ Service files installed
- ✅ Timer enabled and active
- ✅ Next check time displayed
- ✅ Your configured restricted hours shown

## Testing the System

### Quick Test (Manual Trigger)

To test if the popup works, you can manually trigger the script:

```bash
sleep-warning.sh
```

**Note**: The popup will only appear if:
1. The current time falls within your configured restricted hours, AND
2. A display is available (you're logged into a graphical session)

If it's not during restricted hours, the script will exit silently (this is normal).

### Test During Restricted Hours

To test during restricted hours, you can temporarily change your system time (requires root):

```bash
# WARNING: This changes your system time - only do this for testing!
sudo date -s "02:00:00"  # Set to 2:00 AM
sleep-warning.sh         # Run the script
sudo ntpdate -s time.nist.gov  # Restore correct time (or reboot)
```

**Better approach**: Configure a test time range that includes the current time, then reconfigure after testing.

## What Happens Next?

Once installed and configured:

1. **The system runs automatically** - No need to start it manually
2. **Checks every 10 minutes** (or your configured interval) - The timer runs in the background
3. **Shows popup during restricted hours** - If you're using the computer during restricted hours, a warning popup appears
4. **Popup behavior**:
   - Modal (blocks interaction until dismissed)
   - Stays on top of other windows
   - Must remain visible for minimum display time (default: 30 seconds)
   - Can be moved (unless immovable feature is enabled)

## Common First-Time Questions

### "I don't see any popups"

**Quick checks:**
1. Is it during your configured restricted hours? Check with `sleep-warning-status`
2. Is the timer running? Check with `systemctl --user status sleep-warning.timer`
3. Is a dialog tool installed? Check with `which zenity`
4. Check the logs: `tail ~/.config/sleep-warning/warnings.log`

For detailed troubleshooting, see [user-docs/USER_GUIDE.md](user-docs/USER_GUIDE.md#troubleshooting).

### "The popup doesn't stay on top"

Install window management tools (see Step 3 above). For installation commands, see [GETTING_STARTED.md](GETTING_STARTED.md#step-3-install-optional-window-management-tools-recommended).

### "I want to temporarily disable warnings"

**Quick method** (use management menu):
```bash
sleep-warning-manage
```
Select "Disable Service" from the menu.

**Command-line method**:
```bash
systemctl --user stop sleep-warning.timer        # Stop temporarily
systemctl --user disable sleep-warning.timer    # Disable (won't start on boot)
```

For complete service management options, see [user-docs/USER_GUIDE.md](user-docs/USER_GUIDE.md#managing-the-service).

### "How do I change my restricted hours?"

Run the configuration wizard again:
```bash
sleep-warning-configure
```

Your existing settings will be loaded, and you can modify them.

### "How do I uninstall?"

```bash
sleep-warning-uninstall
```

Or from the source directory:
```bash
./uninstall.sh
```

**Options:**
- `sleep-warning-uninstall` - Removes system files (prompts about config file)
- `sleep-warning-uninstall --remove-config` - Removes everything including configuration

## Next Steps

Now that you have the system installed and configured:

1. **Customize your schedule** - Use `sleep-warning-configure` to adjust restricted hours
2. **Explore the management menu** - Run `sleep-warning-manage` to see all available options
3. **Check the status** - Use `sleep-warning-status` to verify everything is working
4. **Read the full documentation**:
   - [README.md](README.md) - Overview and features
   - [user-docs/CONFIGURATION.md](user-docs/CONFIGURATION.md) - Complete configuration guide
   - [user-docs/USER_GUIDE.md](user-docs/USER_GUIDE.md) - Detailed user guide

## Getting Help

### View Logs

**User log file** (most useful for troubleshooting):
```bash
tail ~/.config/sleep-warning/warnings.log
```

**Systemd journal** (service logs):
```bash
journalctl --user -u sleep-warning.service
```

### Management Menu

For an interactive menu with all options:
```bash
sleep-warning-manage
```

This provides:
- Service status
- Start/stop controls
- Enable/disable controls
- Log viewing
- Help and information

### Troubleshooting

See the [Troubleshooting section in README.md](README.md#troubleshooting) for common issues and solutions.

## Summary

You've successfully:
- ✅ Installed the Sleep Warning System
- ✅ Configured your restricted hours
- ✅ Verified the installation
- ✅ Learned how to manage the system

The system is now running automatically in the background. It will check every 10 minutes (or your configured interval) and display warning popups during your restricted hours.

**Remember**: Both installation and configuration are required. If you only installed but didn't configure, the system will use default restricted hours (weekdays: 0-5, weekends: 1-5).

Enjoy better sleep! 😴
