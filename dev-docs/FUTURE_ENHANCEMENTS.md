# Future Enhancements and Alternatives

This document outlines potential improvements and alternative approaches to enhance functionality, compatibility, and user experience for the Sleep Warning System. Each item is categorized as either **Complementary** (can be added to the current suite of scripts and files) or **Alternative Approach** (would require a different implementation strategy).

For the main implementation plan, see [linux-warning-system-plan.md](linux-warning-system-plan.md). For SteamOS Gaming Mode compatibility details, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md).

## Complementary Enhancements (Can Be Added to Current System)

These enhancements can be integrated into the existing bash script suite without requiring a complete redesign:

### 1. Enhanced Display Detection (Moved)
- **Status**: Moved to `dev-docs/linux-warning-system-plan.md` as a detailed checklist.
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#display-detection-enhancements) for detailed implementation strategies.

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

### 14.5. Configure.sh GUI Window Behavior
- **Description**: Fix issue where `configure.sh` GUI windows (when run in GUI mode) can be mistaken for the warning popup and end up staying on top and being immovable. The actual warning popup should stay on top, not the configuration GUI windows.
- **Implementation**: 
  - Ensure `configure.sh` GUI windows (zenity dialogs) do not use stay-on-top or immovable window properties
  - Ensure warning popup windows have higher z-order priority than configuration GUI windows
  - Consider using different window properties or flags for configuration dialogs vs warning popups
  - May need to adjust window manager hints or properties to distinguish between configuration dialogs and warning popups
- **Files Affected**: `configure.sh`, `sleep-warning.sh`
- **Priority**: Medium (usability issue, can confuse users)
- **Status**: Not implemented
- **Current Issue**: When `configure.sh` is run in GUI mode, the zenity dialogs may be treated similarly to warning popups, causing them to stay on top and potentially be immovable, which interferes with the intended behavior where only the actual warning popup should have these properties.

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
- **Implementation Approach**: Add as new main menu option "5. Visual Day/Time Grid" (Option 1 - Non-breaking enhancement)
- **Implementation Plan**:
  - **Menu Integration**:
    - Add "5. Visual Day/Time Grid" option to `show_main_menu()` function (Review and Save moved to option 6)
    - Update menu handling in `main()` function to route option 5 to grid view
    - Maintain backward compatibility with existing menu options (1-5)
  - **Grid Display Function** (`show_visual_grid()`):
    - **GUI Mode** (zenity):
      - Use `zenity --list` with columns: "Status", "Day", "Time Ranges"
      - Status column: Use "✗" (X) for days with restrictions, blank/empty for days without restrictions
      - Day column: Full day name (Sunday, Monday, etc.)
      - Time Ranges column: Human-readable format using `format_ranges_human()` (e.g., "12:00 AM → 4:59 AM")
      - Display all 7 days in calendar order (Sunday-Saturday)
      - Add "Back to Menu" option at bottom of list
    - **Text Mode**:
      - Display formatted ASCII table with numbered options (1-7 for days, 0 for back)
      - Show status indicator (✗) before day name only if day has restrictions, otherwise leave blank
      - Display formatted time ranges using `format_ranges_human()`
      - Format: `[✗] 1. Sunday: 12:00 AM → 4:59 AM` or `1. Sunday: (no restrictions)`
      - Clear table borders and spacing for readability
  - **Day Selection and Editing** (`configure_day_from_grid()`):
    - Parse selected day from grid (day index 0-6)
    - Determine if selected day is weekday (1-5) or weekend (0, 6)
    - **For Weekdays** (Monday-Friday, indices 1-5):
      - Prompt: "Apply same times to all weekdays (Monday-Friday)?"
      - If yes: Use `get_day_hours("Weekdays (Monday-Friday)", ...)` and apply to all weekdays
      - If no: Use `get_day_hours()` for selected day only
    - **For Weekend Days** (Saturday-Sunday, indices 0, 6):
      - Prompt: "Apply same times to both weekend days (Saturday and Sunday)?"
      - If yes: Use `get_day_hours("Weekends (Saturday and Sunday)", ...)` and apply to both
      - If no: Use `get_day_hours()` for selected day only
    - Update `config_lines[]` and `summary_lines[]` arrays after editing
    - Return to grid view after each edit (refresh display)
  - **Grid Refresh**:
    - After each day edit, rebuild grid display using updated `summary_lines[]` array
    - Reuse `format_ranges_human()` to format time ranges for display
    - Maintain user's position in grid (if possible) or return to top
  - **Navigation Flow**:
    - Main Menu → Option 5 → Grid View → Select Day → Edit Dialog → Grid View (updated) → Loop or Back
    - Provide clear "Back to Main Menu" option from grid view
    - Allow multiple day edits in single session without returning to main menu
  - **Visual Indicators**:
    - **✗ (X mark)**: Day has restrictions configured (blocked times)
    - **Blank/Empty**: Day has no restrictions (unrestricted)
    - Use X to clearly indicate "blocked/restricted" (negative connotation)
    - Leave unrestricted days blank for cleaner, simpler display
    - Avoid checkmarks (✓) which might imply "allowed" when we mean "restricted"
  - **Function Reuse**:
    - Reuse `get_day_hours()` for all editing (no changes needed)
    - Reuse `format_ranges_human()` and `format_range_human()` for display
    - Reuse `ask_weekday_together()` and `ask_weekend_together()` for bulk prompts
    - Reuse `load_existing_config()` to populate initial grid data
    - Reuse existing `config_lines[]` and `summary_lines[]` array structure
  - **Error Handling**:
    - Handle cancellation gracefully (return to grid or main menu)
    - Validate day selection (ensure index is 0-6)
    - Handle empty/unconfigured days (show blank status with "(no restrictions)" text)
    - Preserve existing error handling from `get_day_hours()`
- **Technical Considerations**:
  - **Minimal Code Changes**: Only add new functions, no modifications to existing functions
  - **Array Management**: Use existing `config_lines[]` and `summary_lines[]` arrays (passed by reference)
  - **Configuration Format**: No changes to config file format required
  - **Backward Compatibility**: Existing menu options (1-5) remain unchanged
  - **GUI/Text Mode**: Support both modes using existing `use_gui` detection
  - **Function Structure**:
    - `show_visual_grid()`: Main grid display function (GUI and text modes)
    - `configure_day_from_grid()`: Handle day selection and editing logic
    - Both functions accept `use_gui`, `config_lines_ref`, `summary_lines_ref` parameters
- **User Experience**:
  - **Visual Overview**: User can see all days and their restrictions at a glance
  - **Easy Access**: Click any day to edit it immediately (no sequential navigation)
  - **Bulk Operations**: Prompts for weekday/weekend bulk apply when editing those days
  - **Familiar Editing**: Uses existing time range input method (no learning curve)
  - **Quick Iteration**: Edit multiple days in sequence without returning to main menu
  - **Clear Status**: Visual indicator (✗) makes restricted days immediately obvious; unrestricted days are blank
- **User Experience Benefits**:
  - **Visual Clarity**: Immediately see which days have restrictions and what they are
  - **Easy Navigation**: Click any day to edit without going through sequential wizard
  - **Quick Overview**: See entire week's configuration at once
  - **Familiar Editing**: Uses existing time range input method (no learning curve)
  - **Pattern Recognition**: Easily see patterns across days (e.g., all weekdays same)
- **Limitations**:
  - Time ranges still entered via text input (not visual grid editing)
  - No drag-to-select hour ranges
  - No visual hour-by-hour grid display
  - No bulk copy/paste between days (except weekday/weekend prompts)
  - Grid shows summary only, not individual hour blocks

- **Selected Implementation Choices**:
  - **Menu Integration**: Option 1 - Add as new menu option "5. Visual Day/Time Grid" (non-breaking, Review and Save moved to option 6)
  - **Visual Indicators**: ✗ (X) for restricted days, blank for unrestricted days (cleaner display, negative connotation for blocked times)
  - **Display Format**: Three-column table (Status, Day, Time Ranges) in GUI mode; numbered list in text mode
  - **Editing Flow**: Reuse existing `get_day_hours()` function with bulk apply prompts for weekdays/weekends
  - **Grid Refresh**: Update grid display after each edit to show current state
  - **Navigation**: Loop in grid view allowing multiple edits, clear "Back to Menu" option
  - **Function Structure**: Two new functions (`show_visual_grid()`, `configure_day_from_grid()`) with minimal code changes

- **Implementation Checklist**:
  - [x] Add "5. Visual Day/Time Grid" option to `show_main_menu()` function (GUI and text modes, Review and Save moved to option 6)
  - [x] Update menu handling in `main()` function to route option 5 to grid view
  - [x] Create `show_visual_grid()` function:
    - [x] GUI mode: Use `zenity --list` with Status (✗ or blank), Day, Time Ranges columns
    - [x] Text mode: Display numbered ASCII table with status indicators
    - [x] Format time ranges using `format_ranges_human()` function
    - [x] Handle "Back to Menu" option
  - [x] Create `configure_day_from_grid()` function:
    - [x] Parse selected day index (0-6)
    - [x] Detect weekday vs. weekend day
    - [x] Prompt for bulk apply (weekdays or weekends) using existing functions
    - [x] Call `get_day_hours()` with appropriate parameters
    - [x] Update `config_lines[]` and `summary_lines[]` arrays
    - [x] Return updated arrays to caller
  - [x] Implement grid refresh logic (rebuild display after edits)
  - [x] Add navigation loop in grid view (allow multiple edits without returning to main menu)
  - [ ] Update documentation if needed
  - [X] Test GUI mode with zenity
  - [x] Test text mode with terminal (test framework: 10 tests, all use --text mode)
  - [x] Test weekday bulk apply functionality (test 3: --text, config + status.sh verified)
  - [x] Test weekend bulk apply functionality (test 4: --text, config verified)
  - [x] Test individual day editing (test 9: --text, UX improvement verified - Enter/'s' to skip)
  - [X] Test cancellation handling (return to grid or main menu) - COMPLEX, low priority
  - [x] Test with empty/unconfigured days (test 7: --text, grid display verified)
  - [x] Test with days that have multiple time ranges (test 5: --text, config + status.sh verified)
  - [x] Test with overnight ranges (test 6: --text, config + status.sh verified)
  - [x] Verify backward compatibility (test 10: --text, all menu options 1-6 work)
  
  **Test Framework Status:**
  - Test framework: `tests/test-configure-comprehensive.sh` (bash runner) + `tests/test-configure-comprehensive.exp` (expect automation)
  - Run individual tests: `./tests/test-configure-comprehensive.sh 1 2 3` or all: `./tests/test-configure-comprehensive.sh 1 2 3 4 5 6 7 8 9 10`
  - All tests verify both config file contents AND status.sh output
  
  **Test Coverage (10 tests, all passing, all run in --text mode):**
  - Test 1 (Timer Settings): ✅ Config file persistence verified
  - Test 2 (Window Behavior): ✅ Config file persistence verified (all 4 window settings)
  - Test 3 (Weekday Bulk Apply): ✅ Config file + status.sh verified
  - Test 4 (Weekend Bulk Apply): ✅ Config file verified
  - Test 5 (Multiple Time Ranges): ✅ Config file + status.sh verified (comma-separated ranges work)
  - Test 6 (Overnight Ranges): ✅ Config file + status.sh verified (midnight-spanning display correct)
  - Test 7 (Empty Config Grid): ✅ Grid display verified (shows "no restrictions" correctly)
  - Test 8 (Config Persistence): ✅ Config file + status.sh verified (full integration test)
  - Test 9 (Skip UX Improvement): ✅ Code inspection verified (Enter/'s'/S' all work to skip days)
  - Test 10 (Backward Compatibility): ✅ Config file verified (all menu options 1-6 functional)
  
  **Bugs Fixed in configure.sh:**
  - Fixed prompt text going to stdout instead of stderr in `get_popup_size_config()`, `get_popup_position_config()`, `get_popup_immovable_config()`, `get_day_hours()`, and `confirm_skip_day()` - these prompts were being captured in config values
  - **CRITICAL**: Fixed sparse array re-indexing bug in `show_summary()` - when passing `summary_lines` array as parameters, bash re-indexed it from 0, causing wrong days to display (e.g., Monday shown as Sunday, Friday shown as empty)
  
  **UX Improvements:**
  - Changed skip prompt to accept Enter, 's', or 'S' in addition to 'skip' for easier use

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

### 16.5. 12-Hour Format Time Input and GUI Spinbox Widgets
- **Description**: Add support for 12-hour format time entry (e.g., "11pm-5am") in addition to 24-hour format, and provide GUI spinbox widgets for easier time selection with AM/PM toggle
- **Files Affected**: `configure.sh`, `sleep-warning.conf` (read/write, but format conversion only)
- **Priority**: Medium (improves usability, especially for users more familiar with 12-hour format)
- **Status**: Not implemented
- **Current Implementation**:
  - Time ranges entered in 24-hour format only: `DAY=START_HOUR-END_HOUR` (e.g., `SUNDAY=23-5`)
  - Text-based input via `get_day_hours()` function
  - GUI mode uses text entry fields (zenity/yad text input)
  - Configuration stored in 24-hour format internally
- **Implementation Approaches**:
  - **Option 1: Dual Format Support (Text Input)**:
    - Accept both 24-hour format (`23-5`) and 12-hour format (`11pm-5am`, `11PM-5AM`, `11:00pm-5:00am`)
    - Parse input to detect format automatically
    - Convert 12-hour format to 24-hour format for internal storage
    - Support common variations: `11pm`, `11PM`, `11:00pm`, `11:00 PM`, `11 pm`
    - Handle midnight/noon edge cases: `12am` = `0`, `12pm` = `12`
    - Display format preference: Allow user to choose display format (12-hour vs 24-hour) while storing in 24-hour format
  - **Option 2: GUI Spinbox Widgets** (Recommended for GUI mode):
    - **zenity/yad Implementation**:
      - Use `yad --form` with spinbox widgets for hour selection (1-12) and AM/PM toggle
      - Use `zenity --forms` with entry fields and separate AM/PM dropdown/radio buttons
      - Create custom dialog with hour/minute spinboxes and AM/PM selector
      - **Limitations**: zenity may not support native spinboxes, may need workarounds with entry fields
      - **yad Advantages**: Better widget support, can use `--field` with spinbox type
    - **kdialog Implementation**:
      - Use `kdialog --combobox` or custom Qt widgets for time selection
      - Better widget support than zenity for spinboxes
    - **Text Mode Fallback**:
      - Keep current text-based input for terminal mode
      - Optionally add 12-hour format parsing support
  - **Option 3: Hybrid Approach** (Recommended):
    - **GUI Mode**: Use spinbox widgets (yad preferred, zenity fallback) with hour (1-12), minute (0-59), and AM/PM selector
    - **Text Mode**: Accept both 24-hour and 12-hour format text input
    - **Internal Storage**: Always store in 24-hour format (no config file format changes)
    - **Display**: Show times in user's preferred format (12-hour or 24-hour) in summaries and status
- **Implementation Notes**:
  - **Format Parsing**:
    - Create `parse_time_input()` function to detect and parse both formats
    - Support formats: `23`, `23-5`, `11pm`, `11pm-5am`, `11:00pm-5:00am`, `11 PM - 5 AM`
    - Handle case-insensitive parsing (`pm`, `PM`, `Pm`)
    - Validate input ranges (1-12 for 12-hour, 0-23 for 24-hour)
    - Convert to 24-hour format: `12am` → `0`, `1am-11am` → `1-11`, `12pm` → `12`, `1pm-11pm` → `13-23`
  - **GUI Spinbox Implementation**:
    - **yad (Preferred)**:
      - Use `yad --form --field="Start Hour:NUM" --field="Start AM/PM:CB" --field="End Hour:NUM" --field="End AM/PM:CB"`
      - Hour spinbox: `1..12` range
      - AM/PM combobox: `AM!PM` options
      - Parse selected values and convert to 24-hour format
    - **zenity (Fallback)**:
      - Use `zenity --forms` with entry fields for hour and separate radio buttons or combobox for AM/PM
      - Less elegant but functional
      - May need multiple dialogs or custom layout
    - **kdialog (KDE)**:
      - Use `kdialog --combobox` or Qt widgets if available
      - Better widget support than zenity
  - **Overnight Range Handling**:
    - For 12-hour format, handle overnight ranges: `11pm-5am` should be recognized as spanning midnight
    - Visual indication in GUI: Show that range crosses midnight
    - Validation: Ensure end time is after start time (or handle overnight explicitly)
  - **Configuration Format**:
    - **No changes to config file format**: Continue storing in 24-hour format (`DAY=23-5`)
    - **Display Format**: Add `TIME_DISPLAY_FORMAT=12hour|24hour` config option (default: `24hour`)
    - **Input Format**: Accept both formats during configuration, convert to 24-hour for storage
  - **User Experience**:
    - **GUI Mode**: Spinbox widgets provide intuitive time selection (click up/down arrows, toggle AM/PM)
    - **Text Mode**: Accept natural formats (`11pm-5am`, `23-5`, `11:00pm-5:00am`)
    - **Display Preference**: Show times in user's preferred format in summaries, status, and grid views
    - **Format Detection**: Automatically detect format from input (no need to specify format)
  - **Backward Compatibility**:
    - Existing 24-hour format configurations continue to work
    - New 12-hour format input is converted to 24-hour for storage
    - No migration needed for existing config files
- **User Experience Benefits**:
  - **Familiar Format**: Users more comfortable with 12-hour format can use natural time entry
  - **Easier Input**: Spinbox widgets eliminate typing errors and provide visual feedback
  - **Intuitive Selection**: Click to adjust hours, toggle AM/PM instead of calculating 24-hour equivalents
  - **Reduced Errors**: GUI widgets prevent invalid time entries (e.g., hour 13-23 in 12-hour format)
  - **Flexibility**: Support both formats based on user preference
- **Technical Considerations**:
  - **GUI Tool Support**: yad has better spinbox support than zenity
  - **Text Mode**: Can be enhanced with format parsing without GUI dependencies
  - **Validation**: Need robust parsing to handle various 12-hour format variations
  - **Edge Cases**: Handle midnight (`12am`), noon (`12pm`), and overnight ranges correctly
  - **Display Format**: Consider adding user preference for display format (12-hour vs 24-hour) in summaries
- **Implementation Checklist**:
  - [ ] Create `parse_time_input()` function to detect and parse both 12-hour and 24-hour formats
  - [ ] Add format conversion functions (`12hour_to_24hour()`, `24hour_to_12hour()`)
  - [ ] Update `get_day_hours()` to accept both formats in text mode
  - [ ] Create GUI spinbox dialog function for time selection (yad preferred, zenity fallback)
  - [ ] Integrate spinbox widgets into `get_day_hours()` GUI mode
  - [ ] Add `TIME_DISPLAY_FORMAT` config option for user preference
  - [ ] Update `format_ranges_human()` to respect display format preference
  - [ ] Update status.sh and grid display to show times in preferred format
  - [ ] Test format parsing with various input formats
  - [ ] Test overnight range handling in 12-hour format
  - [ ] Test GUI spinbox widgets in yad, zenity, and kdialog
  - [ ] Verify backward compatibility with existing 24-hour format configs
- **Related**: 
  - Complements Visual Day/Time Configuration Grid (#16) - spinbox widgets would enhance grid editing
  - Works with existing time range configuration system
  - Could be integrated into Phase 2 of Visual Day/Time Configuration Grid (interactive grid editing)

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
