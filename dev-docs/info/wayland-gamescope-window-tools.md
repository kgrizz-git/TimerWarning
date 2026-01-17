# Wayland, Gamescope, and Window Manager Tools

This document explains what Wayland and gamescope are, and what the lack of window manager tools means for the Sleep Warning System project.

## What is Wayland?

**Wayland** is a modern display server protocol for Linux that serves as a replacement for the older X11 (X Window System) protocol. It was designed to address many of X11's limitations and security concerns.

### Key Characteristics

1. **Display Server Protocol**: Wayland defines how applications communicate with the display server to create windows, handle input, and render graphics.

2. **Compositor-Based Architecture**: Unlike X11, where the window manager and compositor are separate, Wayland combines them into a single "compositor" that manages both window management and rendering.

3. **Security Improvements**: 
   - Applications cannot spy on each other's windows
   - Better isolation between processes
   - Reduced attack surface compared to X11

4. **Performance Benefits**:
   - Simpler architecture reduces overhead
   - Lower latency for input and rendering
   - Better frame pacing for games and multimedia

5. **Modern Design**: Built from the ground up for modern graphics hardware and use cases, rather than adapting legacy X11 concepts.

### Environment Variables

- **X11**: Uses `DISPLAY` environment variable (e.g., `:0`, `:1`)
- **Wayland**: Uses `WAYLAND_DISPLAY` environment variable (e.g., `wayland-0`, `wayland-1`)

### Adoption Status

Many modern Linux distributions are transitioning to Wayland:
- **GNOME**: Default on Wayland since GNOME 3.22+
- **KDE Plasma**: Supports Wayland (though X11 is still default on many systems)
- **SteamOS**: Uses Wayland (gamescope) in Gaming Mode, X11 in Desktop Mode
- **Sway/i3**: Wayland-native window managers

## What is Gamescope?

**Gamescope** is a Wayland compositor developed by Valve specifically for gaming. It's designed to provide optimal gaming performance and features.

### Key Characteristics

1. **Gaming-Optimized**: Built with gaming use cases in mind, prioritizing low latency and smooth frame pacing.

2. **Advanced Features**:
   - **FSR (FidelityFX Super Resolution)**: Upscaling technology for better performance
   - **Frame rate limiting**: Control game frame rates
   - **Scaling and filtering**: High-quality image scaling
   - **Input handling**: Optimized input processing for gaming

3. **SteamOS Integration**: 
   - Used as the compositor in SteamOS Gaming Mode
   - Handles full-screen game rendering
   - Manages the gaming environment

4. **Wayland-Based**: Built on Wayland protocols, so it inherits Wayland's security and architecture benefits.

### Usage Context

- **SteamOS Desktop Mode**: Uses X11 (KDE Plasma runs on X11)
- **SteamOS Gaming Mode**: Uses Wayland (gamescope compositor)
- **Other Systems**: Can be installed and used on other Linux distributions for gaming

## Window Manager Tools

### What Are Window Manager Tools?

Window manager tools are command-line utilities that allow programs to interact with and control windows managed by the display server. Common examples include:

- **`wmctrl`**: Window Manager Control - manipulate windows, get window information
- **`xdotool`**: X11 automation tool - simulate input, control windows, query window properties
- **`xwininfo`**: Display window information
- **`xprop`**: Display window properties

### What They Can Do

These tools enable features like:

1. **Window Control**:
   - Move and resize windows
   - Minimize, maximize, close windows
   - Focus windows
   - Get window geometry and properties

2. **Window State Management**:
   - Make windows stay on top
   - Make windows sticky (visible on all desktops)
   - Prevent windows from being closed
   - Set window decorations

3. **Window Information**:
   - Get active window ID
   - Get window title and class
   - Get window state (fullscreen, maximized, etc.)
   - Get window position and size

### Example Usage

```bash
# Make a window stay on top (X11)
wmctrl -r "Window Title" -b add,above

# Get active window information (X11)
xdotool getactivewindow getwindowgeometry

# Prevent window from being closed (X11)
xprop -id $(xdotool getactivewindow) -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_STAYS_ON_TOP
```

## The Problem: Window Manager Tools Don't Work on Wayland

### Why They Don't Work

1. **Architectural Differences**: 
   - X11 allows applications to query and control other applications' windows
   - Wayland's security model prevents applications from accessing other applications' windows
   - This is by design - it's a security feature, not a bug

2. **No Direct Equivalent**: 
   - Wayland doesn't provide the same level of window control APIs
   - Each Wayland compositor may have different capabilities
   - No standardized tool like `wmctrl` or `xdotool` exists for Wayland

3. **Compositor-Specific**: 
   - Some compositors (like Sway) have their own tools (`swaymsg`)
   - These are compositor-specific and not universal
   - Gamescope doesn't provide similar tools

### What This Means for Our Project

The Sleep Warning System relies on window manager tools for several features:

#### 1. **Minimum Display Time Enforcement**

**What We Want to Do**:
- Force the warning popup to stay visible for a minimum duration (e.g., 30 seconds)
- Prevent users from closing the popup during this time
- Make the popup stay on top of all other windows

**On X11 (Desktop Mode)**:
- ✅ Can use `wmctrl` or `xdotool` to:
  - Make window stay on top
  - Prevent window from being closed
  - Monitor if window is closed and reopen it
- ✅ Full enforcement capability

**On Wayland/Gamescope (Gaming Mode)**:
- ❌ Cannot use `wmctrl` or `xdotool` (they don't work on Wayland)
- ❌ Cannot force window to stay on top (compositor-dependent, best-effort only)
- ❌ Cannot prevent window from being closed
- ⚠️ Can only show countdown message (informational only)
- ⚠️ Limited to dialog tool's native capabilities (e.g., `yad --on-top` flag)

**Impact**: Minimum display time feature has **~30% effectiveness** in Gaming Mode (informational value only, no enforcement).

#### 2. **Window State Detection**

**What We Want to Do**:
- Detect if a game is running in fullscreen mode
- Detect if a game is in exclusive fullscreen mode
- Log window state for troubleshooting

**On X11 (Desktop Mode)**:
- ✅ Can use `xdotool` to query window properties
- ✅ Can use `xprop` to check `_NET_WM_STATE` properties
- ✅ Can detect fullscreen, maximized, and other window states
- ✅ Can get window title and application name

**On Wayland/Gamescope (Gaming Mode)**:
- ❌ Cannot use `xdotool` or `xprop` (X11-only tools)
- ❌ Limited window state detection capabilities
- ⚠️ Can only detect basic information if compositor provides it
- ⚠️ Cannot reliably detect exclusive fullscreen mode
- ⚠️ Must log that detection is limited on Wayland

**Impact**: Window state detection is **limited** in Gaming Mode, making troubleshooting more difficult.

#### 3. **Popup Visibility Over Full-Screen Games**

**What We Want to Do**:
- Ensure warning popups appear over full-screen games
- Force popups to stay on top
- Ensure popups are visible even when games are running

**On X11 (Desktop Mode)**:
- ✅ Can use window manager tools to force windows on top
- ✅ Can use `xprop` to set `_NET_WM_STATE_ABOVE` property
- ✅ Better control over window stacking

**On Wayland/Gamescope (Gaming Mode)**:
- ⚠️ Depends on dialog tool's native capabilities
- ⚠️ `yad --on-top` flag provides best-effort support
- ⚠️ Exclusive full-screen games may still block dialogs
- ❌ Cannot force window stacking like on X11

**Impact**: Popup visibility over full-screen games is **variable** in Gaming Mode, especially for exclusive full-screen games.

## Practical Implications for Our Project

### Feature Limitations

| Feature | X11 (Desktop Mode) | Wayland/Gamescope (Gaming Mode) |
|---------|-------------------|--------------------------------|
| **Minimum Display Time** | ✅ Full enforcement | ⚠️ Informational only (~30%) |
| **Window State Detection** | ✅ Full detection | ⚠️ Limited detection |
| **Stay on Top** | ✅ Reliable | ⚠️ Best-effort only |
| **Prevent Closing** | ✅ Possible | ❌ Not possible |
| **Window Information** | ✅ Full access | ⚠️ Limited access |

### Effectiveness Impact

Based on our effectiveness assessment:

- **Desktop Mode (X11)**: ~95% effectiveness for most features
- **Gaming Mode (Wayland/Gamescope)**: ~68% overall effectiveness
  - Windowed games: ~85% effectiveness
  - Borderless windowed: ~75% effectiveness
  - Full-screen (non-exclusive): ~60% effectiveness
  - Exclusive full-screen: ~30% effectiveness

### Workarounds and Solutions

#### 1. **Dialog Tool Selection**

We prioritize dialog tools that work better on Wayland:
- **`yad`**: Better Wayland support, `--on-top` flag
- **`kdialog`**: KDE native, may work better on SteamOS
- **`zenity`**: Fallback option

#### 2. **Informational Fallback**

When window control isn't possible:
- Show countdown message in popup text
- Log limitations to help with troubleshooting
- Accept that enforcement is limited on Wayland

#### 3. **Steam Overlay Integration** (Future Enhancement)

For maximum effectiveness in Gaming Mode:
- Use Steam Overlay API to display warnings
- Works over exclusive full-screen games
- Native Steam integration
- Requires C/C++ plugin using Steamworks SDK

See [FUTURE_ENHANCEMENTS.md](../FUTURE_ENHANCEMENTS.md) for details.

#### 4. **Graceful Degradation**

The system:
- Detects available tools and capabilities
- Uses best available option for each environment
- Logs what tools/methods are used
- Falls back gracefully when tools unavailable

## Technical Details

### Display Detection

Our implementation detects the display environment:

```bash
# X11 detection
if [ -n "$DISPLAY" ]; then
    # X11 environment
    export DISPLAY
fi

# Wayland detection
if [ -n "$WAYLAND_DISPLAY" ]; then
    # Wayland environment
    export WAYLAND_DISPLAY
fi

# Gamescope detection
if pgrep -x gamescope > /dev/null; then
    # Gamescope compositor detected
fi
```

### Tool Availability Check

```bash
# Check for X11 tools (only work on X11)
if command -v wmctrl > /dev/null && [ -n "$DISPLAY" ]; then
    # Can use window manager tools
    USE_WM_TOOLS=true
else
    # Cannot use window manager tools
    USE_WM_TOOLS=false
fi
```

### Dialog Tool Priority

```bash
# Priority order for Gaming Mode (Wayland)
if command -v yad > /dev/null; then
    DIALOG_TOOL="yad"
elif command -v kdialog > /dev/null; then
    DIALOG_TOOL="kdialog"
elif command -v zenity > /dev/null; then
    DIALOG_TOOL="zenity"
fi
```

## Summary

### Wayland
- Modern display server protocol replacing X11
- Better security and performance
- Used by many modern Linux distributions
- Uses `WAYLAND_DISPLAY` environment variable

### Gamescope
- Wayland compositor developed by Valve
- Optimized for gaming performance
- Used in SteamOS Gaming Mode
- Provides gaming-specific features (FSR, frame limiting, etc.)

### Window Manager Tools Limitation
- **X11 tools** (`wmctrl`, `xdotool`) don't work on Wayland
- This is a **fundamental architectural limitation**, not a bug
- Wayland's security model prevents cross-application window control
- No universal equivalent tools exist for Wayland

### Impact on Our Project
- **Minimum display time**: Limited to informational value on Wayland (~30% effectiveness)
- **Window state detection**: Limited capabilities on Wayland
- **Popup visibility**: Variable, especially over exclusive full-screen games
- **Overall effectiveness**: ~68% in Gaming Mode vs ~95% in Desktop Mode

### Solutions
- Use environment-aware dialog tool selection
- Implement graceful degradation
- Log limitations for troubleshooting
- Consider Steam Overlay integration for maximum effectiveness

## Related Documentation

- [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md) - Detailed Gaming Mode compatibility information
- [TECHNICAL_DETAILS.md](../TECHNICAL_DETAILS.md) - Technical implementation details
- [detecting-fullscreen-exclusive-mode.md](detecting-fullscreen-exclusive-mode.md) - Methods for detecting fullscreen modes
- [FUTURE_ENHANCEMENTS.md](../FUTURE_ENHANCEMENTS.md) - Future improvements including Steam Overlay integration
