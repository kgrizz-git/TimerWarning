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

### 3. Enhanced Window Size Options and Display-Based Sizing
- **Description**: Add more predefined window size options and allow window sizes to be automatically calculated based on current display resolution
- **Implementation**: 
  - Add additional predefined size options (e.g., `xsmall`, `xlarge`, `xxlarge`) beyond current `small`, `medium`, `large`
  - Add display resolution detection function (using `xrandr` for X11, `wlr-randr` or `wayland-info` for Wayland)
  - Implement percentage-based sizing (e.g., `50%x30%` to use 50% of screen width and 30% of screen height)
  - Add resolution-aware predefined sizes that scale with display (e.g., `medium` could be 30% of screen width by 20% of screen height)
  - Update `configure.sh` to provide GUI/text options for selecting from expanded size list or entering custom dimensions
  - Add option in `configure.sh` to enable/disable display-based sizing
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Medium (improves usability and adaptability across different display configurations)
- **Status**: Not implemented
- **Current Implementation**:
  - Three predefined sizes: `small` (400x250), `medium` (800x500), `large` (2000x1350)
  - Custom sizes via `WIDTHxHEIGHT` format (200-2000 width, 100-2000 height)
  - Size configuration available in `configure.sh` "Window Behavior" section
- **Display Resolution Detection Considerations**:
  - **X11**: Can use `xrandr --query` to get screen resolution, supports multiple displays
  - **Wayland**: More complex - may need `wlr-randr`, `wayland-info`, or compositor-specific tools
  - **gamescope (SteamOS Gaming Mode)**: Resolution detection may be limited or require special handling
  - **Multi-monitor setups**: Should detect primary display or allow user to specify which display to use for sizing calculations
  - **Dynamic resolution changes**: May need to detect resolution at popup time rather than configuration time
- **Implementation Notes**:
  - Add `POPUP_SIZE_MODE` config option: `fixed` (current behavior) or `display-based` (percentage-based)
  - When `display-based` is enabled, predefined sizes could map to screen percentages:
    - `small`: 20% width × 15% height
    - `medium`: 30% width × 20% height  
    - `large`: 50% width × 35% height
  - Custom sizes in display-based mode could accept percentage format: `50%x30%`
  - Fallback to fixed pixel sizes if resolution detection fails
  - Cache detected resolution to avoid repeated queries (with refresh option)
  - Update `get_popup_dimensions()` function to handle percentage calculations
  - Add resolution detection function that works across X11/Wayland with appropriate fallbacks
- **User Experience Benefits**:
  - Better popup sizing on high-resolution displays (4K, ultrawide monitors)
  - Consistent visual appearance across different screen sizes
  - Easier configuration for users with multiple displays or changing resolutions
  - More intuitive sizing options (percentage-based feels more natural than pixel values)
- **Related**: Complements existing window size configuration, works with popup position feature

### 4. Systemd Service Environment Detection
- **Description**: Detect Desktop Mode vs Gaming Mode and adjust behavior accordingly
- **Implementation**: Add environment detection function, configure service based on mode
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.service`
- **Priority**: Medium (improves compatibility)
- **Status**: Not implemented
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#systemd-service-robustness) for Gaming Mode considerations

### 5. Configurable Warning Messages
- **Description**: Allow users to customize warning message text per day or time range
- **Implementation**: Add `MESSAGE_*` configuration options, update `show_warning()` function
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Low (nice-to-have feature)
- **Status**: Not implemented

### 6. Escalating Warnings
- **Description**: Show progressively stronger warnings if user continues using system during restricted hours
- **Implementation**: 
  - Track warning count in temporary file, adjust message intensity
  - **Window Size Escalation**: Progressively increase popup window size with each warning
    - Start with user's configured size (small, medium, large, or custom)
    - Escalate to next larger predefined size with each warning: `small` → `medium` → `large`
    - If user starts with `medium`, escalation goes: `medium` → `large`
    - If user starts with `large` or custom size, escalation should max out at `large` (the largest predefined option) or custom, if larger
    - Maximum size may be system-dependent (limited by display resolution), but should not exceed the `large` predefined size (or custom, if larger)
    - Reset escalation level when user stops using system during restricted hours (e.g., after configurable timeout period)
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented
- **Implementation Notes**:
  - Store warning count and escalation level in temporary file (e.g., `~/.config/sleep-warning/.warning_count`)
  - Map predefined sizes to escalation order: `small` (400x250) → `medium` (800x500) → `large` (2000x1350)
  - Maximum escalation should cap at `large` predefined size, regardless of system capabilities
  - For custom sizes, calculate escalation: increase by configurable percentage (e.g., 25% per warning) up to `large` size dimensions
  - System-dependent maximums (e.g., display resolution limits) should be respected, but escalation should not attempt to exceed `large` size
  - Reset escalation when user exits restricted hours or after configurable cooldown period
  - Combine with message intensity changes for maximum effect
  - Consider making escalation optional via config option: `ESCALATING_WARNINGS=true/false`

### 7. Warning Event Logging
- **Description**: Log each warning event with timestamp, window state, display environment, and dialog tool to a file for user review
- **Implementation**: 
  - Add file-based logging function, write to `~/.config/sleep-warning/warnings.log`
  - Log timestamp, window state (full-screen/exclusive/windowed), display environment (X11/Wayland), dialog tool used, popup success/failure
  - Include window state detection (using xdotool/wmctrl for X11, swaymsg for Wayland if available)
- **Files Affected**: `sleep-warning.sh`
- **Priority**: High (critical for troubleshooting Gaming Mode compatibility)
- **Status**: Not implemented
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#window-state-detection) for window state detection implementation

### 8. Temporary Disable via Config
- **Description**: Allow users to temporarily disable warnings via configuration file or command
- **Implementation**: Add `ENABLED=false` config option, check before showing warning
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`, `manage.sh`
- **Priority**: Medium (useful feature)
- **Status**: Not implemented

### 9. System Sleep/Hibernate Detection
- **Description**: Skip warnings if system was recently resumed from sleep (user may have just woken up)
- **Implementation**: Check system uptime or last resume time, skip warnings for configurable duration after resume
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

### 10. Audio Alerts
- **Description**: Add optional audio notification (beep, sound file) alongside visual popup
- **Implementation**: Use `paplay`, `aplay`, or `speaker-test` to play sound
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

### 11. Desktop Notification Fallback
- **Description**: Use desktop notification system (notify-send) as fallback if dialog tools fail
- **Implementation**: Add notify-send as last-resort fallback in `show_warning()` function
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Medium (improves compatibility)
- **Status**: Not implemented

### 12. Wayland-Specific Window Management
- **Description**: Implement Wayland-native window control using wlr-randr or similar tools
- **Implementation**: Add Wayland-specific functions for screen info and window positioning
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Medium (improves Wayland/gamescope compatibility)
- **Status**: Not implemented (requires research into Wayland protocols)
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md) for Wayland/gamescope considerations

### 13. Distribution-Specific Optimizations
- **Description**: Add optimizations for specific distributions (e.g., KDE-specific features on KDE systems)
- **Implementation**: Detect distribution/DE, apply appropriate optimizations
- **Files Affected**: `sleep-warning.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented

### 14. Immovable Popup Window
- **Description**: Prevent user from moving/dragging the popup window during the minimum display time countdown
- **Implementation**: 
  - **X11 Approach**: Use `xprop` to set `_NET_WM_ALLOWED_ACTIONS` property, removing `_NET_WM_ACTION_MOVE` action
  - **Alternative X11**: Use `xdotool` or `wmctrl` to set window properties that prevent movement
  - **Window Manager Hints**: Set window gravity and type hints via xprop after window creation
  - **Fallback**: Monitor window position and restore if moved (less elegant but more compatible)
- **Files Affected**: `sleep-warning.sh` (enhance `make_window_unclosable()` function)
- **Priority**: High (critical enhancement for minimum display time feature effectiveness)
- **Status**: ✅ **Implemented** - Uses Method 4 (monitor and restore position) to prevent window movement during minimum display time. `POPUP_IMMOVABLE` configuration option added (true/false). Works on X11 with wmctrl/xdotool, not available on Wayland.
- **Distribution Options**: Current implementation works with traditional installation method. For future GUI application wrapper (see [DISTRIBUTION_OPTIONS.md](DISTRIBUTION_OPTIONS.md)), this feature would be accessible via GUI configuration interface. Flatpak/Snap packaging would require appropriate permissions for window management tools (xdotool/wmctrl).
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

### 15. Auto-Close Popup Window
- **Description**: Automatically close the popup window after a pre-configured time period, providing users with a non-interactive option for warning dismissal
- **Implementation**: 
  - Add configuration option to enable/disable auto-close: `POPUP_AUTO_CLOSE=true/false`
  - Add configuration option for auto-close timeout: `POPUP_AUTO_CLOSE_TIME=<seconds>` or allow it to use the minimum display time value
  - Implement timer mechanism that closes the window after the configured duration
  - Support two modes:
    - **Mode 1**: Use minimum display time as auto-close time (single variable controls both)
    - **Mode 2**: Separate auto-close time independent of minimum display time (allows window to stay open longer than minimum but still auto-close)
  - Close window using appropriate method for dialog tool (send close signal, kill process, or use tool-specific close command)
  - Ensure auto-close respects minimum display time (auto-close time should be >= minimum display time if both are enabled)
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Medium (useful feature for users who want automatic dismissal without manual interaction)
- **Status**: Not implemented
- **Implementation Notes**:
  - Add `POPUP_AUTO_CLOSE` config option: `false` (default, current behavior) or `true` (enable auto-close)
  - Add `POPUP_AUTO_CLOSE_TIME` config option: 
    - `0` or `auto` = use minimum display time value
    - Positive integer = seconds until auto-close (must be >= minimum display time if both are enabled)
  - When auto-close is enabled, start background timer after window is displayed
  - Use `sleep` command or background process to track time
  - Close window using appropriate method:
    - For `zenity`: May need to find and kill the process
    - For `yad`: May support timeout parameter or need process termination
    - For `kdialog`: May need process termination
    - For `dialog`: May need process termination
  - Ensure auto-close doesn't interfere with minimum display time enforcement
  - If user manually closes window before auto-close time, cancel the auto-close timer
  - Consider showing countdown in window message if visual countdown feature is implemented
  - Log auto-close events if logging is enabled
- **User Experience Benefits**:
  - Provides automatic dismissal option for users who don't want to manually close warnings
  - Can be set to same as minimum display time for consistent behavior
  - Can be set longer than minimum display time to ensure warning is seen but still auto-dismisses
  - Reduces need for user interaction while still ensuring warning visibility
- **Related**: Complements minimum display time feature (#14 Immovable Popup Window), could work with visual countdown timer enhancement

### 16. Visual Day/Time Configuration Grid
- **Description**: Provide a visual interface for configuring day/time restrictions, showing a summary grid of days and their configured time ranges, with easy access to edit any day. Implemented in two phases: Phase 1 provides visual summary and easy day-by-day editing, Phase 2 adds full interactive grid editing capabilities.
- **Files Affected**: `configure.sh`, `sleep-warning.conf` (read/write), potentially new `configure-grid.sh` script
- **Priority**: Medium (significantly improves usability and reduces configuration errors)
- **Status**: Not implemented
- **Current Implementation**:
  - Text-based configuration via `configure.sh` wizard
  - Manual entry of time ranges in format: `DAY=START_HOUR-END_HOUR`
  - Supports single ranges, multiple ranges (comma-separated), and overnight ranges
  - Configuration stored in `~/.config/sleep-warning/sleep-warning.conf`

#### Phase 1: Visual Summary and Easy Day Access (Simpler Implementation)
- **Description**: Display a visual summary grid showing all days and their configured time ranges, with clickable day entries that open the existing configuration dialog. Provides visual overview without requiring complex grid editing implementation.
- **Priority**: Medium-High (easier to implement, provides immediate usability improvement)
- **Status**: Not implemented
- **Implementation**: 
  - Create visual summary grid/table showing days (Sunday-Saturday) as rows
  - Display configured time ranges for each day in human-readable format (e.g., "12:00 AM - 5:59 AM")
  - Show visual indicators for days with restrictions (colored/shaded) vs. days without restrictions
  - Make each day row clickable/selectable to edit that day's configuration
  - When user clicks a weekday, ask if they want to apply same times to all weekdays
  - When user clicks a weekend day, ask if they want to apply same times to both weekend days
  - Use existing `get_day_hours()` function for editing (no changes needed to editing logic)
  - Display summary in both GUI (yad/zenity list/table) and text mode (formatted table)
  - Update summary display after each day is edited
- **Implementation Approaches**:
  - **GUI Mode**: Use `yad --list` or `zenity --list` to display days and time ranges in table format
  - **Text Mode**: Display formatted ASCII table with numbered options, allow selection via menu
  - Clicking/selecting a day opens existing configuration dialog for that day
- **User Experience**:
  - **Visual Overview**: User can see all days and their restrictions at a glance
  - **Easy Access**: Click any day to edit it immediately
  - **Bulk Operations**: Still prompts for weekday/weekend bulk apply when editing those days
  - **No Grid Editing**: Time ranges still entered via existing text input (no complex grid widget needed)
- **Technical Considerations**:
  - Reuse existing `get_day_hours()` function from `configure.sh`
  - Parse current configuration to build summary display
  - Format time ranges using existing `format_range_human()` function (if available)
  - Minimal changes to existing codebase
  - Works with current configuration file format (no changes needed)
- **User Experience Benefits**:
  - **Visual Clarity**: Immediately see which days have restrictions and what they are
  - **Easy Navigation**: Click any day to edit without going through sequential wizard
  - **Quick Overview**: See entire week's configuration at once
  - **Familiar Editing**: Uses existing time range input method (no learning curve)
- **Limitations**:
  - Time ranges still entered via text input (not visual grid editing)
  - No drag-to-select hour ranges
  - No visual hour-by-hour grid display
  - No bulk copy/paste between days (except weekday/weekend prompts)

#### Phase 2: Full Interactive Grid Editing (Advanced Implementation)
- **Description**: Extend Phase 1 with full interactive grid editing, allowing users to click/toggle individual hours directly in the grid, with drag selection, visual feedback, and advanced bulk operations.
- **Priority**: Medium (builds on Phase 1, more complex but provides maximum usability)
- **Status**: Not implemented (depends on Phase 1 completion)
- **Implementation**: 
  - Extend Phase 1 grid to show hours (0-23) as columns
  - Display blocked time slots with visual indicators (colored cells, checkmarks, or shading)
  - Allow users to click/toggle individual hour cells to block/unblock specific times
  - Support range selection (click and drag to select multiple consecutive hours)
  - Support multiple time ranges per day (show all blocked periods visually)
  - Handle overnight ranges visually (e.g., highlight that 23-6 spans midnight)
  - Provide advanced bulk operations (e.g., "Block all weekdays 0-5", "Copy Monday to all weekdays")
  - Export changes back to configuration file format (`DAY=START_HOUR-END_HOUR`)
- **Implementation Approaches**:
  - **Option 1: GUI Grid with yad/zenity** (Recommended for bash-based implementation):
    - Use `yad` with `--form` or custom dialog to create grid interface
    - Create 7×24 grid (7 days × 24 hours) with checkboxes or toggle buttons
    - Use `yad --list` with custom columns or `yad --form` with grid layout
    - Parse grid selections and convert to configuration format
    - May require multiple dialog windows (one per day) or single large grid
    - **Limitations**: yad/zenity may not support full grid editing, may need workarounds
  - **Option 2: Text-Based Grid with dialog/whiptail**:
    - Use `dialog --checklist` or `dialog --form` to create text-based grid
    - Display ASCII grid in terminal with checkboxes for each hour
    - Navigate with arrow keys, toggle with spacebar
    - Less visually appealing but works in all terminal environments
  - **Option 3: Web-Based Grid Interface** (Alternative Approach):
    - Create lightweight web server (Python Flask, Node.js) for configuration
    - HTML/CSS/JavaScript grid interface with interactive cells
    - Access via localhost in web browser
    - More flexible and visually appealing, but requires web server
    - See Alternative Approach #5 (Web-Based Configuration Interface)
  - **Option 4: Native Desktop Application** (Alternative Approach):
    - Part of GUI application wrapper (GTK/Qt/Electron)
    - Full-featured grid widget with drag selection, visual feedback
    - Best user experience but requires different technology stack
    - See Alternative Approach #3 (Native Desktop Application)
- **Implementation Notes**:
  - **Grid Layout**:
    - Rows: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday (7 rows)
    - Columns: 0, 1, 2, ..., 23 (24 columns for 24-hour format)
    - Each cell represents one hour on one day
    - Visual indicators: blocked cells (red/shaded), unblocked cells (green/white)
  - **Interaction Methods**:
    - **Single click/toggle**: Block/unblock individual hour
    - **Range selection**: Click start hour, drag to end hour (or Shift+click end)
    - **Bulk operations**: Select day row header to select all hours, or use context menu
    - **Copy/paste**: Copy one day's pattern to other days
  - **Overnight Range Handling**:
    - Visual indication when range spans midnight (e.g., highlight both 23 on Monday and 0-6 on Tuesday)
    - Option to show overnight ranges as single visual block across day boundary
    - Warning/confirmation when creating overnight ranges
  - **Multiple Ranges per Day**:
    - Display all blocked periods for each day (may have multiple separate blocks)
    - Allow editing each range independently
    - Visual separation between different ranges on same day
  - **Configuration Conversion**:
    - Parse existing `DAY=START_HOUR-END_HOUR` format into grid representation
    - Convert grid selections back to configuration format
    - Handle edge cases: multiple ranges, overnight ranges, empty days
    - Validate configuration before saving (check for overlaps, invalid ranges)
  - **User Experience Features**:
    - **Preview**: Show current configuration in grid before editing
    - **Undo/Redo**: Allow users to undo changes
    - **Presets**: Quick templates (e.g., "Weekdays 0-5", "Weekends 1-6", "All days 23-6")
    - **Validation**: Warn about overlapping ranges, invalid configurations
    - **Export/Import**: Save/load configuration profiles
    - **Help/Tooltips**: Explain overnight ranges, multiple ranges, etc.
  - **Technical Considerations**:
    - Grid size: 7 days × 24 hours = 168 cells (manageable for GUI)
    - For text-based interface, may need scrolling or pagination
    - For GUI, ensure grid is readable and not too cramped
    - Consider hour labels (0-23 vs 12 AM - 11 PM) - allow user preference
    - Support 12-hour format display option (with 24-hour format storage)
  - **User Experience Benefits** (Phase 2):
    - **Visual Clarity**: Immediately see which hours are blocked on which days
    - **Easier Configuration**: No need to remember format syntax (`0-5,22-23`)
    - **Error Prevention**: Visual feedback prevents invalid configurations
    - **Quick Editing**: Click to toggle hours instead of typing ranges
    - **Pattern Recognition**: Easily see patterns across days (e.g., all weekdays same)
    - **Bulk Operations**: Quickly copy patterns from one day to others
    - **Intuitive**: More natural than text-based range entry
  - **Compatibility Considerations** (Phase 2):
    - **GUI Tools**: Requires yad, zenity, or kdialog for GUI implementation
    - **Text Mode**: Falls back to current text-based wizard if GUI tools unavailable
    - **Terminal Size**: Text-based grid needs adequate terminal size
    - **Accessibility**: Grid interface should support keyboard navigation

- **Related**: 
  - Complements existing configuration system (#5 Configurable Warning Messages)
  - Could be part of Native Desktop Application (Alternative Approach #3)
  - Could use Web-Based Configuration Interface (Alternative Approach #5)
  - Works with current day/time restriction format (no config file format changes needed)
  - Phase 1 can be implemented independently and provides immediate usability improvement
  - Phase 2 builds on Phase 1 foundation for full interactive grid editing

### 17. Multi-Display Popup Support
- **Description**: Display warning popups on all available displays/monitors simultaneously, ensuring warnings are visible regardless of which screen the user is actively viewing
- **Implementation**: 
  - Detect all available displays (primary and secondary monitors)
  - Spawn separate popup instance for each detected display
  - Position each popup appropriately on its respective display (center, or configured position)
  - Handle display-specific positioning and sizing
  - Manage multiple popup processes (one per display)
  - Ensure all popups can be dismissed independently or together
  - Handle minimum display time enforcement across all popups
  - Support immovable window feature on all displays
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Medium (useful for multi-monitor setups, improves visibility)
- **Status**: Not implemented
- **Current Implementation**:
  - Single popup displayed on primary or detected display
  - Uses `DISPLAY` environment variable (X11) or `WAYLAND_DISPLAY` (Wayland)
  - Popup positioned using configured `POPUP_POSITION` setting
  - Window positioning tools (wmctrl/xdotool) work on X11 only
- **Implementation Approaches**:
  - **X11 Multi-Monitor Detection**:
    - Use `xrandr --query` to list all connected displays
    - Parse output to identify active displays (e.g., `HDMI-1`, `DP-1`, `eDP-1`)
    - Get display geometry (resolution, position) for each monitor
    - Set `DISPLAY` environment variable to target specific display (may need X server configuration)
    - Spawn popup process for each display with appropriate `DISPLAY` value
  - **Wayland Multi-Monitor Detection**:
    - Use `wlr-randr` (for wlroots-based compositors) to list displays
    - Use `wayland-info` or compositor-specific tools if available
    - Query display information via Wayland protocols (requires compositor support)
    - May need compositor-specific solutions (gamescope, sway, GNOME, KDE)
    - **Limitations**: Wayland security model may prevent multi-display control
  - **Hybrid Approach**:
    - Detect display environment (X11 vs Wayland)
    - Use appropriate detection method for each protocol
    - Fallback to single display if multi-monitor detection fails
- **Implementation Notes**:
  - **Display Detection**:
    - **X11**: `xrandr --query` lists all connected displays with their status (connected, disconnected, active)
    - Parse `xrandr` output to identify active displays and their geometry
    - Example: `xrandr --query | grep " connected" | awk '{print $1}'`
    - Get display resolution and position: `xrandr --query | grep -A1 " connected" | grep -E "[0-9]+x[0-9]+"`
    - **Wayland**: More complex, requires compositor-specific tools
      - `wlr-randr` for wlroots-based compositors (sway, river, etc.)
      - `gnome-randr` or `gsettings` for GNOME
      - `kscreen-doctor` for KDE Plasma
      - May need to query Wayland protocols directly (complex)
  - **Multi-Popup Management**:
    - Spawn background process for each display
    - Track popup PIDs for each display
    - Ensure all popups are closed when user dismisses (or allow independent dismissal)
    - Handle minimum display time across all popups (all must remain visible for configured duration)
    - Coordinate immovable window feature across all displays
  - **Display-Specific Configuration**:
    - Allow per-display positioning (e.g., center on all, or specific position per display)
    - Handle different display resolutions (popup size may need adjustment per display)
    - Consider display scaling (high-DPI displays may need different sizing)
  - **Process Management**:
    - Use `DISPLAY=:0.1` or similar for X11 secondary displays (if X server configured for multi-display)
    - For X11, may need to use `--display` flag if dialog tool supports it
    - For Wayland, may need compositor-specific environment variables
    - Track all popup processes to ensure cleanup on exit
  - **User Experience**:
    - **Option 1**: All popups must be dismissed (user closes all to proceed)
    - **Option 2**: Dismissing one closes all (coordinated dismissal)
    - **Option 3**: Independent dismissal (user can close individual popups)
    - Configuration option: `MULTI_DISPLAY_MODE=single|all|independent`
    - Default: `all` (show on all displays, all must be dismissed)
  - **Edge Cases**:
    - Handle displays being disconnected during popup display
    - Handle displays being added during popup display (may need to spawn additional popup)
    - Handle display resolution changes
    - Handle display reordering (primary display changes)
    - Graceful fallback if multi-display detection fails (show on primary display only)
- **Technical Considerations**:
  - **X11 Multi-Display Setup**:
    - X server must be configured for multi-display (Xinerama, XRandR, or separate X servers)
    - Most modern X11 setups use XRandR extension (standard)
    - May need to set `DISPLAY` per popup process
    - Some dialog tools may not support `--display` flag
  - **Wayland Multi-Display**:
    - Wayland compositors handle multi-display natively
    - Detection and control more complex than X11
    - May require compositor-specific APIs or tools
    - gamescope (SteamOS Gaming Mode) may have limited multi-display support
  - **Performance**:
    - Multiple popup processes may have minimal performance impact
    - Consider process overhead (7 displays = 7 popup processes)
    - Ensure efficient display detection (cache results if possible)
  - **Compatibility**:
    - **X11**: Feasible with xrandr (standard on most X11 systems)
    - **Wayland**: Feasibility varies by compositor (may require research per compositor)
    - **gamescope**: May not support multi-display (SteamOS Gaming Mode typically single display)
    - **Fallback**: Always fallback to single display if multi-display detection fails
- **Configuration Options**:
  - `MULTI_DISPLAY_ENABLED=true/false` - Enable/disable multi-display popups (default: `false`)
  - `MULTI_DISPLAY_MODE=single|all|independent` - Dismissal behavior (default: `all`)
  - `MULTI_DISPLAY_POSITION=center|inherit` - Position on each display (default: `center`, uses `POPUP_POSITION` if `inherit`)
- **User Experience Benefits**:
  - **Visibility**: Warnings appear on all screens, ensuring user sees them regardless of active display
  - **Multi-Monitor Workflows**: Users with multiple monitors don't miss warnings on secondary displays
  - **Gaming Setups**: Gamers with multiple monitors see warnings on all screens
  - **Productivity**: Users working across multiple displays are always notified
- **Compatibility Assessment**:
  - **X11**: ✅ **Feasible** - xrandr provides reliable multi-display detection and control
  - **Wayland**: ⚠️ **Partially Feasible** - Depends on compositor, may require compositor-specific tools
  - **gamescope (SteamOS Gaming Mode)**: ❌ **Not Feasible** - Typically single display, limited multi-display support
  - **Fallback Strategy**: Always fallback to single display if multi-display detection fails or is unavailable
- **Related**: 
  - Complements popup positioning feature (#3 Enhanced Window Size Options)
  - Works with minimum display time feature (#14 Immovable Popup Window)
  - May require enhanced display detection (#1 Enhanced Display Detection)
  - Could benefit from Wayland-specific window management (#12 Wayland-Specific Window Management)
- **Implementation**: 
  - Create grid visualization with days (Sunday-Saturday) as rows and hours (0-23) as columns
  - Display blocked time slots with visual indicators (colored cells, checkmarks, or shading)
  - Allow users to click/toggle individual hour cells to block/unblock specific times
  - Support range selection (click and drag to select multiple consecutive hours)
  - Display current configuration visually before editing
  - Support multiple time ranges per day (show all blocked periods)
  - Handle overnight ranges visually (e.g., highlight that 23-6 spans midnight)
  - Provide bulk operations (e.g., "Block all weekdays 0-5", "Copy Monday to all weekdays")
  - Export changes back to configuration file format (`DAY=START_HOUR-END_HOUR`)
- **Files Affected**: `configure.sh`, `sleep-warning.conf` (read/write), potentially new `configure-grid.sh` script
- **Priority**: Medium (significantly improves usability and reduces configuration errors)
- **Status**: Not implemented
- **Current Implementation**:
  - Text-based configuration via `configure.sh` wizard
  - Manual entry of time ranges in format: `DAY=START_HOUR-END_HOUR`
  - Supports single ranges, multiple ranges (comma-separated), and overnight ranges
  - Configuration stored in `~/.config/sleep-warning/sleep-warning.conf`
- **Implementation Approaches**:
  - **Option 1: GUI Grid with yad/zenity** (Recommended for bash-based implementation):
    - Use `yad` with `--form` or custom dialog to create grid interface
    - Create 7×24 grid (7 days × 24 hours) with checkboxes or toggle buttons
    - Use `yad --list` with custom columns or `yad --form` with grid layout
    - Parse grid selections and convert to configuration format
    - May require multiple dialog windows (one per day) or single large grid
    - **Limitations**: yad/zenity may not support full grid editing, may need workarounds
  - **Option 2: Text-Based Grid with dialog/whiptail**:
    - Use `dialog --checklist` or `dialog --form` to create text-based grid
    - Display ASCII grid in terminal with checkboxes for each hour
    - Navigate with arrow keys, toggle with spacebar
    - Less visually appealing but works in all terminal environments
  - **Option 3: Web-Based Grid Interface** (Alternative Approach):
    - Create lightweight web server (Python Flask, Node.js) for configuration
    - HTML/CSS/JavaScript grid interface with interactive cells
    - Access via localhost in web browser
    - More flexible and visually appealing, but requires web server
    - See Alternative Approach #5 (Web-Based Configuration Interface)
  - **Option 4: Native Desktop Application** (Alternative Approach):
    - Part of GUI application wrapper (GTK/Qt/Electron)
    - Full-featured grid widget with drag selection, visual feedback
    - Best user experience but requires different technology stack
    - See Alternative Approach #3 (Native Desktop Application)
- **Implementation Notes**:
  - **Grid Layout**:
    - Rows: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday (7 rows)
    - Columns: 0, 1, 2, ..., 23 (24 columns for 24-hour format)
    - Each cell represents one hour on one day
    - Visual indicators: blocked cells (red/shaded), unblocked cells (green/white)
  - **Interaction Methods**:
    - **Single click/toggle**: Block/unblock individual hour
    - **Range selection**: Click start hour, drag to end hour (or Shift+click end)
    - **Bulk operations**: Select day row header to select all hours, or use context menu
    - **Copy/paste**: Copy one day's pattern to other days
  - **Overnight Range Handling**:
    - Visual indication when range spans midnight (e.g., highlight both 23 on Monday and 0-6 on Tuesday)
    - Option to show overnight ranges as single visual block across day boundary
    - Warning/confirmation when creating overnight ranges
  - **Multiple Ranges per Day**:
    - Display all blocked periods for each day (may have multiple separate blocks)
    - Allow editing each range independently
    - Visual separation between different ranges on same day
  - **Configuration Conversion**:
    - Parse existing `DAY=START_HOUR-END_HOUR` format into grid representation
    - Convert grid selections back to configuration format
    - Handle edge cases: multiple ranges, overnight ranges, empty days
    - Validate configuration before saving (check for overlaps, invalid ranges)
  - **User Experience Features**:
    - **Preview**: Show current configuration in grid before editing
    - **Undo/Redo**: Allow users to undo changes
    - **Presets**: Quick templates (e.g., "Weekdays 0-5", "Weekends 1-6", "All days 23-6")
    - **Validation**: Warn about overlapping ranges, invalid configurations
    - **Export/Import**: Save/load configuration profiles
    - **Help/Tooltips**: Explain overnight ranges, multiple ranges, etc.
  - **Technical Considerations**:
    - Grid size: 7 days × 24 hours = 168 cells (manageable for GUI)
    - For text-based interface, may need scrolling or pagination
    - For GUI, ensure grid is readable and not too cramped
    - Consider hour labels (0-23 vs 12 AM - 11 PM) - allow user preference
    - Support 12-hour format display option (with 24-hour format storage)
- **User Experience Benefits**:
  - **Visual Clarity**: Immediately see which hours are blocked on which days
  - **Easier Configuration**: No need to remember format syntax (`0-5,22-23`)
  - **Error Prevention**: Visual feedback prevents invalid configurations
  - **Quick Editing**: Click to toggle hours instead of typing ranges
  - **Pattern Recognition**: Easily see patterns across days (e.g., all weekdays same)
  - **Bulk Operations**: Quickly copy patterns from one day to others
  - **Intuitive**: More natural than text-based range entry
- **Compatibility Considerations**:
  - **GUI Tools**: Requires yad, zenity, or kdialog for GUI implementation
  - **Text Mode**: Falls back to current text-based wizard if GUI tools unavailable
  - **Terminal Size**: Text-based grid needs adequate terminal size
  - **Accessibility**: Grid interface should support keyboard navigation
- **Related**: 
  - Complements existing configuration system (#5 Configurable Warning Messages)
  - Could be part of Native Desktop Application (Alternative Approach #3)
  - Could use Web-Based Configuration Interface (Alternative Approach #5)
  - Works with current day/time restriction format (no config file format changes needed)

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
5. ~~Immovable Popup Window~~ ✅ **IMPLEMENTED** (critical for minimum display time feature effectiveness)

**Medium Priority (Improves Compatibility/Usability)**:
6. Steam Overlay Integration (Alternative, but best solution for SteamOS Gaming Mode full-screen games)
7. Systemd Service Environment Detection
8. Desktop Notification Fallback
9. Wayland-Specific Window Management
10. Temporary Disable via Config
11. Enhanced Window Size Options and Display-Based Sizing
12. Auto-Close Popup Window
13. Visual Day/Time Configuration Grid
14. Multi-Display Popup Support

**Low Priority (Nice-to-Have Enhancements)**:
14. Configurable Warning Messages
15. Escalating Warnings
16. Audio Alerts
17. Distribution-Specific Optimizations
18. Wayland support for minimum display time (would require different approach)
19. More robust window control (prevent all close methods, not just window manager)
20. Visual countdown timer in popup (instead of just text)
21. Configurable auto-reopen behavior

## Implementation Notes

- **Complementary enhancements** can be added incrementally without breaking existing functionality
- **Alternative approaches** should be evaluated carefully as they may require significant development effort
- **Steam Overlay Integration** is the most promising solution for full Gaming Mode compatibility but requires the most development effort. See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#path-to-maximum-effectiveness) for detailed effectiveness analysis.
- All enhancements should maintain backward compatibility with existing configurations
- Testing should be performed for each enhancement, especially Gaming Mode compatibility. See [linux-warning-system-plan.md](linux-warning-system-plan.md#phase-4-testing-and-validation) for testing checklists.
