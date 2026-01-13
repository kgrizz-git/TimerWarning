# Future Enhancements and Alternatives

This document outlines potential improvements and alternative approaches to enhance functionality, compatibility, and user experience for the Sleep Warning System. Each item is categorized as either **Complementary** (can be added to the current suite of scripts and files) or **Alternative Approach** (would require a different implementation strategy).

For the main implementation plan, see [linux-warning-system-plan.md](linux-warning-system-plan.md). For SteamOS Gaming Mode compatibility details, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md).

## Complementary Enhancements (Can Be Added to Current System)

These enhancements can be integrated into the existing bash script suite without requiring a complete redesign:

### 1. Enhanced Display Detection
- **Description**: Improve display detection for Wayland/gamescope with multiple fallback strategies
- **Implementation**: Add functions to detect `WAYLAND_DISPLAY`, gamescope compositor, and query Wayland sessions
- **Files Affected**: `sleep-warning.sh`
- **Priority**: High (required for SteamOS Gaming Mode compatibility)
- **Status**: Partially implemented, needs enhancement
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#display-detection-enhancements) for detailed implementation strategies

### 2. Dialog Tool Priority System
- **Description**: Implement intelligent dialog tool selection based on environment (prefer yad for Gaming Mode, kdialog for KDE)
- **Implementation**: Enhance `check_dialog_tool()` function with environment-aware selection
- **Files Affected**: `sleep-warning.sh`
- **Priority**: High (improves Gaming Mode compatibility)
- **Status**: Basic implementation exists, needs enhancement
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#dialog-tool-selection) for priority order and implementation details

### 3. Systemd Service Environment Detection
- **Description**: Detect Desktop Mode vs Gaming Mode and adjust behavior accordingly
- **Implementation**: Add environment detection function, configure service based on mode
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.service`
- **Priority**: Medium (improves compatibility)
- **Status**: Not implemented
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#systemd-service-robustness) for Gaming Mode considerations

### 4. Configurable Warning Messages
- **Description**: Allow users to customize warning message text per day or time range
- **Implementation**: Add `MESSAGE_*` configuration options, update `show_warning()` function
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Low (nice-to-have feature)
- **Status**: Not implemented

### 5. Escalating Warnings
- **Description**: Show progressively stronger warnings if user continues using system during restricted hours
- **Implementation**: Track warning count in temporary file, adjust message intensity
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

### 6. Warning Event Logging
- **Description**: Log each warning event with timestamp, window state, display environment, and dialog tool to a file for user review
- **Implementation**: 
  - Add file-based logging function, write to `~/.config/sleep-warning/warnings.log`
  - Log timestamp, window state (full-screen/exclusive/windowed), display environment (X11/Wayland), dialog tool used, popup success/failure
  - Include window state detection (using xdotool/wmctrl for X11, swaymsg for Wayland if available)
- **Files Affected**: `sleep-warning.sh`
- **Priority**: High (critical for troubleshooting Gaming Mode compatibility)
- **Status**: Not implemented
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#window-state-detection) for window state detection implementation

### 7. Temporary Disable via Config
- **Description**: Allow users to temporarily disable warnings via configuration file or command
- **Implementation**: Add `ENABLED=false` config option, check before showing warning
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`, `manage.sh`
- **Priority**: Medium (useful feature)
- **Status**: Not implemented

### 8. System Sleep/Hibernate Detection
- **Description**: Skip warnings if system was recently resumed from sleep (user may have just woken up)
- **Implementation**: Check system uptime or last resume time, skip warnings for configurable duration after resume
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

### 9. Audio Alerts
- **Description**: Add optional audio notification (beep, sound file) alongside visual popup
- **Implementation**: Use `paplay`, `aplay`, or `speaker-test` to play sound
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

### 10. Desktop Notification Fallback
- **Description**: Use desktop notification system (notify-send) as fallback if dialog tools fail
- **Implementation**: Add notify-send as last-resort fallback in `show_warning()` function
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Medium (improves compatibility)
- **Status**: Not implemented

### 11. Wayland-Specific Window Management
- **Description**: Implement Wayland-native window control using wlr-randr or similar tools
- **Implementation**: Add Wayland-specific functions for screen info and window positioning
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Medium (improves Wayland/gamescope compatibility)
- **Status**: Not implemented (requires research into Wayland protocols)
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md) for Wayland/gamescope considerations

### 12. Distribution-Specific Optimizations
- **Description**: Add optimizations for specific distributions (e.g., KDE-specific features on KDE systems)
- **Implementation**: Detect distribution/DE, apply appropriate optimizations
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

### 13. Immovable Popup Window
- **Description**: Prevent user from moving/dragging the popup window during the minimum display time countdown
- **Implementation**: 
  - **X11 Approach**: Use `xprop` to set `_NET_WM_ALLOWED_ACTIONS` property, removing `_NET_WM_ACTION_MOVE` action
  - **Alternative X11**: Use `xdotool` or `wmctrl` to set window properties that prevent movement
  - **Window Manager Hints**: Set window gravity and type hints via xprop after window creation
  - **Fallback**: Monitor window position and restore if moved (less elegant but more compatible)
- **Files Affected**: `sleep-warning.sh` (enhance `make_window_unclosable()` function)
- **Priority**: High (critical enhancement for minimum display time feature effectiveness)
- **Status**: Not implemented
- **Testing Results**:
  - Method 1 (xprop _NET_WM_ALLOWED_ACTIONS): Failed to set property (window manager may not support this)
  - Method 2 (xdotool/wmctrl properties): Applied but limited effect
  - Method 3 (Window Manager Hints): Applied but effectiveness varies by window manager
  - Method 4 (Monitor and Restore Position): **Tested and confirmed working** - This fallback method successfully prevents window movement by monitoring position and restoring it if moved
- **Compatibility Assessment**:
  - **X11**: Partially feasible
    - Can use `xprop -id <window_id> -f _NET_WM_ALLOWED_ACTIONS 32a -set _NET_WM_ALLOWED_ACTIONS _NET_WM_ACTION_CLOSE _NET_WM_ACTION_RESIZE` to remove MOVE action
    - Not all window managers honor `_NET_WM_ALLOWED_ACTIONS` hints (compliance varies)
    - Some users may have custom keybindings (Alt+drag, Super+drag) that bypass window manager controls
    - `override_redirect` flag would prevent movement but also removes decorations and may cause UX issues
  - **Wayland**: Not feasible
    - Wayland's security model prevents applications from controlling other windows' properties
    - Would require compositor-specific solutions (gamescope, sway, etc.)
    - gamescope (SteamOS Gaming Mode) likely won't support this
    - Would need Wayland protocol extensions or compositor modifications
  - **Toolkit Limitations**:
    - `zenity`/`yad`/`kdialog` are GTK-based but don't expose window property APIs directly
    - Must use external tools (`xprop`, `xdotool`) after window creation
    - Window must be created first, then properties modified (timing-sensitive)
  - **User Experience Considerations**:
    - Preventing window movement may frustrate users if popup blocks important content
    - Some window managers may ignore hints, leading to inconsistent behavior
    - Users with accessibility needs may require window movement
  - **Recommended Approach**:
    - Implement for X11 only (skip Wayland)
    - **Primary method**: Monitor window position and restore if moved (tested and confirmed working)
    - Secondary attempt: Use `xprop` to set `_NET_WM_ALLOWED_ACTIONS` to remove MOVE action (fallback if window manager supports it)
    - Make it optional/configurable (allow users to disable if causing issues)
    - Test across multiple window managers (GNOME, KDE, XFCE, i3, etc.)
    - Document limitations clearly (not all window managers support this)
- **Research Findings**:
  - EWMH (Extended Window Manager Hints) standard provides `_NET_WM_ALLOWED_ACTIONS` property
  - Can remove `_NET_WM_ACTION_MOVE` from allowed actions list
  - Window manager compliance varies: GNOME/KDE generally honor it, tiling WMs may ignore it
  - `override_redirect` would work but removes window decorations and may cause issues
  - Window gravity hints (`Gdk.Gravity.STATIC`) may help but not guaranteed
  - Some window managers allow disabling move shortcuts in settings (user-level, not app-level)
- **Implementation Notes**:
  - Must find window ID after popup is created (use `xdotool search --name` or `wmctrl -l`)
  - Set properties immediately after window appears (may need small delay)
  - Restore original properties after minimum display time expires
  - Consider making it a separate config option: `POPUP_IMMOVABLE=true/false`
  - Log attempts to set immovable property and whether it succeeded
- **Related**: Complements minimum display time feature (#15 in current implementation)

## Alternative Approaches (Require Different Implementation)

These approaches would require significant changes to the architecture or a completely different implementation strategy:

### 1. Steam Overlay Integration
- **Description**: Integrate with Steam Overlay API to display warnings within Steam's native overlay system
- **Why Alternative**: Requires Steamworks SDK, C/C++ development, different architecture
- **Advantages**: 
  - Guaranteed to work over full-screen games in Gaming Mode
  - Native Steam integration
  - Better user experience for Steam users
- **Disadvantages**:
  - Only works with Steam games
  - Requires Steam to be running
  - Significant development effort
  - Different technology stack (C/C++ vs bash)
- **Implementation Approach**:
  - Develop C/C++ plugin using Steamworks SDK
  - Create overlay notification system
  - Integrate with existing systemd service (call plugin from bash script)
- **Complementary Option**: Could be developed alongside current system as optional enhancement
- **Priority**: Medium (best solution for SteamOS Gaming Mode full-screen games, but requires significant development effort)
- **Status**: Not implemented
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#path-to-maximum-effectiveness) for effectiveness analysis

### 2. Custom Wayland Protocol Implementation
- **Description**: Develop custom Wayland protocol for notifications compatible with gamescope
- **Why Alternative**: Requires deep Wayland protocol knowledge, C development, compositor integration
- **Advantages**:
  - Native Wayland support
  - Works with gamescope
  - Full control over notification behavior
- **Disadvantages**:
  - Very complex implementation
  - Requires compositor modifications or extensions
  - May not work with all compositors
- **Implementation Approach**:
  - Develop Wayland protocol extension
  - Create compositor plugin or modification
  - Integrate with existing system
- **Complementary Option**: Could be developed as optional enhancement
- **Priority**: Low (very complex, limited benefit over simpler solutions)
- **Status**: Not implemented

### 3. Native Desktop Application (GUI Wrapper)
- **Description**: Create full desktop application (GTK/Qt/Electron) to replace bash scripts
- **Why Alternative**: Different technology stack, different architecture, different distribution method
- **Advantages**:
  - Better user experience
  - Native GUI for configuration
  - Can be packaged as AppImage/Flatpak/Snap
  - System tray integration possible
- **Disadvantages**:
  - Requires GUI framework knowledge
  - Larger codebase
  - Different maintenance requirements
  - May not work in Gaming Mode (needs desktop environment)
- **Implementation Approach**:
  - Develop GUI application (Python+GTK, Qt, or Electron)
  - Replace configure.sh and manage.sh with GUI
  - Keep systemd service integration
- **Complementary Option**: Could be developed alongside bash scripts as alternative interface
- **Priority**: Medium (improves user experience but not Gaming Mode compatibility)
- **Status**: Not implemented
- **Related**: See [DISTRIBUTION_OPTIONS.md](DISTRIBUTION_OPTIONS.md) for packaging options

### 4. Systemd Timer Alternative (Cron-based)
- **Description**: Use cron instead of systemd timers for scheduling
- **Why Alternative**: Different scheduling system, different architecture
- **Advantages**:
  - Works on systems without systemd
  - More traditional approach
- **Disadvantages**:
  - Less reliable than systemd timers
  - Doesn't solve Gaming Mode compatibility issues
  - Different service management
- **Implementation Approach**:
  - Create cron job instead of systemd timer
  - Modify installation script
  - Different service management
- **Complementary Option**: Could be developed as alternative for non-systemd systems
- **Priority**: Low (systemd is standard, limited benefit)
- **Status**: Not implemented

### 5. Web-Based Configuration Interface
- **Description**: Create web server for configuration and management
- **Why Alternative**: Different architecture, requires web server, different access method
- **Advantages**:
  - Access from any device
  - Modern interface
  - Remote configuration possible
- **Disadvantages**:
  - Security concerns (local web server)
  - Additional dependencies
  - Doesn't solve Gaming Mode compatibility
  - Overkill for simple configuration
- **Implementation Approach**:
  - Develop lightweight web server (Python Flask, Node.js, etc.)
  - Create web interface
  - Integrate with existing system
- **Complementary Option**: Could be developed as optional enhancement
- **Priority**: Very Low (unnecessary complexity)
- **Status**: Not implemented

## Recommended Implementation Priority

**High Priority (Required for Gaming Mode Compatibility)**:
1. Enhanced Display Detection (Wayland/gamescope)
2. Dialog Tool Priority System
3. Window State Detection and Logging (critical for troubleshooting)
4. File-Based Logging with Window State Information
5. Immovable Popup Window (critical for minimum display time feature effectiveness)

**Medium Priority (Improves Compatibility/Usability)**:
6. Steam Overlay Integration (Alternative, but best solution for SteamOS Gaming Mode full-screen games)
7. Systemd Service Environment Detection
8. Desktop Notification Fallback
9. Wayland-Specific Window Management
10. Temporary Disable via Config

**Low Priority (Nice-to-Have Enhancements)**:
10. Configurable Warning Messages
11. Escalating Warnings
12. Audio Alerts
13. Distribution-Specific Optimizations
14. Wayland support for minimum display time (would require different approach)
15. More robust window control (prevent all close methods, not just window manager)
16. Visual countdown timer in popup (instead of just text)
17. Configurable auto-reopen behavior

## Implementation Notes

- **Complementary enhancements** can be added incrementally without breaking existing functionality
- **Alternative approaches** should be evaluated carefully as they may require significant development effort
- **Steam Overlay Integration** is the most promising solution for full Gaming Mode compatibility but requires the most development effort. See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#path-to-maximum-effectiveness) for detailed effectiveness analysis.
- All enhancements should maintain backward compatibility with existing configurations
- Testing should be performed for each enhancement, especially Gaming Mode compatibility. See [linux-warning-system-plan.md](linux-warning-system-plan.md#phase-4-testing-and-validation) for testing checklists.
