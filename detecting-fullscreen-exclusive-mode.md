# How to Detect Fullscreen Exclusive Mode on Linux

This document explains various methods to determine if a game or application is running in fullscreen exclusive mode on Linux systems.

## Overview

Fullscreen Exclusive (FSE) mode is when an application takes direct control of the display, bypassing the window manager. This is less common on Linux than on Windows, as many games use borderless windowed mode instead, which appears fullscreen but still goes through the window manager.

## Methods to Detect Fullscreen Exclusive Mode

### 1. Window Manager Tools (X11)

#### Using `xwininfo`

Get basic window information:
```bash
# Get window ID first (click on the window when prompted)
xwininfo

# Or find window by name
xwininfo -name "Game Name"

# Check if window is fullscreen
xwininfo -id <WINDOW_ID> | grep "Override redirect"
```

#### Using `xdotool`

List all windows and their states:
```bash
# List all windows with their properties
xdotool search --all --name ".*" getwindowname getwindowgeometry getwindowclassname

# Check if a specific window is fullscreen
xdotool getactivewindow getwindowgeometry
```

#### Using `wmctrl`

Check window states:
```bash
# List all windows with their states
wmctrl -lG

# Check if window is maximized/fullscreen
wmctrl -r "Game Name" -b add,fullscreen
```

### 2. X11 Window Properties

Check window properties directly:
```bash
# Get window ID
xwininfo | grep "Window id"

# Check _NET_WM_STATE property
xprop -id <WINDOW_ID> | grep _NET_WM_STATE

# Fullscreen windows typically have _NET_WM_STATE_FULLSCREEN
```

### 3. Wayland (GNOME/KDE)

On Wayland, detection is more limited due to security restrictions:

#### Using `swaymsg` (Sway/i3)
```bash
swaymsg -t get_tree | jq '.. | select(.type?) | select(.type=="con")'
```

#### GNOME/KDE
- Use `gdbus` or desktop-specific APIs
- Less straightforward than X11
- May require desktop environment specific tools

### 4. Practical Tests

These are the most reliable methods for end users:

#### Screen Capture Test
- Press `Print Screen` or use `gnome-screenshot`
- If the screenshot is black or doesn't capture the game content, it's likely exclusive fullscreen
- Borderless windowed mode typically allows normal screenshots

#### Alt+Tab Behavior
- In exclusive fullscreen mode, `Alt+Tab` may cause:
  - Noticeable delay
  - Screen flicker
  - Temporary black screen
- Borderless windowed mode usually has smoother transitions

#### Overlay Functionality
- Try Steam overlay (`Shift+Tab`) or Discord overlay
- If overlays fail to appear or function properly, the game might be in exclusive fullscreen
- Borderless windowed mode typically allows overlays

#### Window Manager Interaction
- Try to move or resize the window
- Exclusive fullscreen windows typically cannot be moved or resized
- Borderless windowed windows may still respond to window manager actions

### 5. Game/Application Settings

Check the game's display settings menu:
- **"Fullscreen"** = Often exclusive fullscreen
- **"Borderless Windowed"** or **"Windowed Fullscreen"** = Not exclusive (goes through window manager)
- **"Windowed"** = Not exclusive

### 6. Monitor Resolution Check

Check if the application changed the display resolution:
```bash
# Check current resolution before launching
xrandr

# Launch game, then check again
xrandr

# If resolution changed, likely exclusive fullscreen
# If resolution unchanged, likely borderless windowed
```

### 7. GPU/Display Tools

#### NVIDIA
```bash
# Check running processes using GPU
nvidia-smi
```

#### General Display Status
```bash
# Check display status
cat /sys/class/drm/card*/status
```

## Quick Command to Check Window State

Here's a simple script you can use to check the current active window:

```bash
#!/bin/bash
# Get active window info
WIN_ID=$(xdotool getactivewindow)
echo "Window ID: $WIN_ID"
echo "Geometry: $(xdotool getwindowgeometry $WIN_ID)"
echo "Window state: $(xprop -id $WIN_ID _NET_WM_STATE)"
```

Save this as `check-window-state.sh`, make it executable (`chmod +x check-window-state.sh`), and run it while the game is active.

## Summary

The most reliable methods for detecting fullscreen exclusive mode are:

1. **Practical tests** - Screenshot test, Alt+Tab behavior, overlay functionality
2. **Game settings** - Check the in-game display mode setting
3. **Window properties** - Use X11 tools to check window state properties
4. **Resolution changes** - Monitor if the display resolution changes when launching

## Notes

- True exclusive fullscreen is less common on Linux than on Windows
- Many games use borderless windowed mode, which appears fullscreen but isn't exclusive
- Exclusive fullscreen typically requires the application to bypass the window manager, which is more difficult on Linux
- Modern desktop environments and compositors may handle fullscreen differently
- Wayland has more restrictions than X11 for detecting window states

## Related Tools

Installation commands for useful tools:

```bash
# X11 tools
sudo apt install xdotool xwininfo wmctrl x11-utils  # Debian/Ubuntu
sudo pacman -S xdotool xorg-xwininfo wmctrl xorg-xprop  # Arch
sudo dnf install xdotool xorg-x11-utils wmctrl  # Fedora

# Wayland tools (Sway)
sudo apt install sway jq  # Debian/Ubuntu
sudo pacman -S sway jq  # Arch
```
