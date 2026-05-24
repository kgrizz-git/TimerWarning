### Phase 1: Project Setup and Script Development

#### Checklist 1.1: Create Project Structure
- [x] Create project directory structure
- [x] Create `sleep-warning.sh` script file
- [x] Create configuration file (`sleep-warning.conf`)
- [ ] Create systemd service directory (`~/.config/systemd/user/`) - NOTE: This is created during installation (Phase 3), not Phase 1
- [x] Create systemd service file (`sleep-warning.service`)
- [x] Create systemd timer file (`sleep-warning.timer`)
- [x] Create `configure.sh` script file (interactive configuration wizard)
- [x] Create `manage.sh` script file (management and help interface)

#### Checklist 1.2: Implement Configuration System
- [x] Design configuration file format (simple key-value or day-based format) - Day-based format chosen
- [x] Create default configuration file with example values
- [x] Implement configuration file parsing in script
- [x] Add validation for configuration values (hour ranges, format)
- [x] Add fallback to default values if config file missing or invalid
- [x] Add configurable check interval (frequency) - IMPLEMENTED: CHECK_INTERVAL setting (1-60 minutes)
- [x] Add configurable popup size - IMPLEMENTED: POPUP_SIZE setting (small/medium/large or custom WIDTHxHEIGHT)
- [x] Add configurable popup position - IMPLEMENTED: POPUP_POSITION setting (center, corners, top/bottom-center)
- [x] Add configurable minimum display time - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME setting (0-300 seconds, prevents closing/minimizing)
- [x] Add configurable immovable window setting - IMPLEMENTED: POPUP_IMMOVABLE setting (true/false, prevents window movement during minimum display time)
- [x] Document configuration file format and options - IMPLEMENTED: Created ../user-docs/CONFIGURATION.md with comprehensive documentation

#### Checklist 1.3: Develop Bash Script Core Logic
- [x] Get current day of week (0=Sunday, 6=Saturday)
- [x] Get current hour (0-23 format)
- [x] Load restricted hours from configuration file for current day
- [x] Implement time range check using configured hours
- [x] Add logic to determine if warning should be shown
- [x] Handle edge cases (midnight crossover, multiple ranges per day) - FIXED: Multiple ranges per day (comma-separated) now fully implemented. Parsing and validation support comma-separated ranges. Midnight crossover is handled (single range works across midnight boundary if start < end).

#### Checklist 1.4: Implement Display and Popup Functionality
- [x] Detect DISPLAY environment variable
- [x] Fallback to finding active user session display if DISPLAY not set
- [x] Add loginctl-based session detection as fallback
- [x] Add Wayland display detection (WAYLAND_DISPLAY environment variable) - IMPLEMENTED: detect_display_environment() and get_display_identifier() functions
- [x] Add gamescope-specific display detection for SteamOS Gaming Mode - IMPLEMENTED: Detects gamescope via process check and environment variables
- [x] Add active window state detection (full-screen, exclusive full-screen, windowed, borderless) - IMPLEMENTED: detect_window_state() function with X11 and Wayland support
- [x] Add window state logging (log window state when warning is triggered) - IMPLEMENTED: Logs window state and title to warnings.log
- [x] Implement window state detection for X11 (using xdotool/wmctrl) - IMPLEMENTED: detect_window_state_x11() uses xdotool and xprop
- [x] Implement window state detection for Wayland (using swaymsg or similar, if available) - IMPLEMENTED: detect_window_state_wayland() with swaymsg support and gamescope detection
- [x] Add graceful fallback when window state detection tools unavailable - IMPLEMENTED: Returns "unknown" state when tools unavailable
- [x] Implement zenity popup command with modal flag
- [x] Add fallback detection for alternative dialog tools (yad, kdialog) if zenity unavailable
- [x] Add appropriate warning message text
- [x] Ensure popup requires user interaction (modal)
- [x] Add error handling for zenity not being available
- [x] Add graceful handling for systems without GUI (log error, exit silently)
- [x] Implement configurable popup size - IMPLEMENTED: Reads POPUP_SIZE from config, supports small/medium/large/custom
- [x] Implement configurable popup position - IMPLEMENTED: Reads POPUP_POSITION from config, calculates geometry for yad
- [x] Use configured size in popup display - IMPLEMENTED: All dialog tools use configured dimensions
- [x] Use configured position in popup display - IMPLEMENTED: yad uses --geometry, zenity centers (position not supported)
- [x] Implement minimum display time enforcement - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME prevents closing/minimizing for configured duration
- [x] Add window manager tool detection - IMPLEMENTED: Checks for wmctrl/xdotool for window control
- [x] Add window unclosable functionality - IMPLEMENTED: Uses wmctrl/xdotool to make window sticky and prevent closing
- [x] Add auto-reopen if closed prematurely - IMPLEMENTED: Reopens popup with countdown if closed during minimum display time
- [x] Add countdown message in popup - IMPLEMENTED: Shows remaining time before popup can be closed
- [x] Test popup behavior with full-screen applications - PARTIALLY TESTED: Basic popup functionality verified (log shows successful popup display). Full-screen application testing requires running full-screen games/applications
- [ ] Test popup behavior in SteamOS Gaming Mode with no game running - NOT TESTED: Requires SteamOS Gaming Mode environment
- [ ] Test popup behavior in SteamOS Gaming Mode with windowed games - NOT TESTED: Requires SteamOS Gaming Mode environment
- [ ] Test popup behavior in SteamOS Gaming Mode with full-screen games - NOT TESTED: Requires SteamOS Gaming Mode environment
- [ ] Test display detection in SteamOS Gaming Mode (gamescope/Wayland) - NOT TESTED: Requires SteamOS Gaming Mode environment
- [ ] Test systemd user services persistence across Desktop Mode ↔ Gaming Mode transitions - NOT TESTED: Requires SteamOS Gaming Mode environment
- [x] Test minimum display time enforcement - PARTIALLY TESTED: Log shows popup displayed with minimum display time and closed after timeout. Full testing requires wmctrl/xdotool verification on X11 systems
- [ ] Test minimum display time on Wayland - NOT TESTED: Window manager tools don't work on Wayland, needs fallback testing
- [x] Consider using window manager tools to force popup on top if needed - IMPLEMENTED AND TESTED: keep_window_on_top() function uses wmctrl/xdotool for window control, yad has --on-top flag. Window automatically stays on top of other windows. Uses xprop _NET_WM_STATE_ABOVE for reliable cross-environment compatibility. Confirmed working with zenity on KDE.
- [x] Implement immovable popup window feature - IMPLEMENTED: Uses Method 4 (monitor and restore position) to prevent window movement during minimum display time. POPUP_IMMOVABLE configuration option added (true/false). See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#13-immovable-popup-window) for implementation details and testing results. Works on X11 with wmctrl/xdotool, not available on Wayland.

#### Checklist 1.4a: Enhanced Display Detection (Wayland/gamescope)
- [x] **Define detection priority order**
  - [x] X11: `DISPLAY` if present and valid
  - [x] Wayland: `WAYLAND_DISPLAY` if present and valid
  - [x] `loginctl` session discovery fallback
  - [x] gamescope-specific detection fallback
- [x] **Specify X11 detection behavior**
  - [x] Validate `DISPLAY` format (e.g., `:0`, `:1`)
  - [x] Confirm display accessibility (document expected tools like `xdpyinfo`/`xset`)
  - [x] Define fallback behavior if X11 tools are missing
- [x] **Specify Wayland detection behavior**
  - [x] Require `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY`
  - [x] Document compositor helpers (e.g., `swaymsg`, `wlr-randr`) and when used
  - [x] Define fallback when Wayland socket is not accessible
- [x] **Specify gamescope detection behavior**
  - [x] Detect gamescope process (`pgrep gamescope`)
  - [x] Capture gamescope-related environment variables (when present)
  - [x] Define display selection priority when gamescope is active
- [x] **Logging requirements**
  - [x] Log selected display type (X11/Wayland/gamescope)
  - [x] Log selected display identifier
  - [x] Log fallback path taken (if any)
  - [x] Log failure reason when no display is available
- [x] **Failure handling**
  - [x] Define "no display" behavior (silent exit + log)
  - [x] Define partial detection behavior (warn + continue)
- [x] **Documentation linkage**
  - [x] Reference [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#display-detection-enhancements) for detailed strategy
- [ ] **Manual testing checklist**
  - [ ] Desktop Mode (X11): `DISPLAY` set, popup appears
  - [ ] Desktop Mode (Wayland): `WAYLAND_DISPLAY` set, popup appears
  - [ ] Gaming Mode: gamescope detected, popup appears (no game)
  - [ ] Gaming Mode: gamescope detected, popup appears (windowed game)
  - [ ] Gaming Mode: gamescope detected, popup appears (full-screen game)
  - [ ] No display vars: `loginctl` fallback finds active session
  - [ ] Failure case: no active session -> log "no display"

#### Checklist 1.4b: Wayland/gamescope Popup Behavior
- [x] **Define popup behavior expectations on Wayland/gamescope**
  - [x] Modal warning should appear when possible
  - [x] Document focus/always-on-top limitations
  - [x] Define acceptable degradation (visible but not guaranteed on top)
- [x] **Dialog tool behavior guidance**
  - [x] Prefer `yad` for Wayland/gamescope if available
  - [x] Document limitations of `zenity`/`kdialog` on Wayland
- [x] **Fallbacks when dialogs fail**
  - [x] Define `notify-send` fallback behavior (if dialogs fail)
  - [x] Define logging for fallback activation
- [x] **Logging requirements**
  - [x] Log dialog tool used
  - [x] Log any Wayland-specific limitations encountered
  - [x] Log if on-top enforcement is unavailable
- [ ] **Manual testing checklist**
  - [ ] Wayland Desktop: popup appears and is dismissible
  - [ ] Gaming Mode (no game): popup appears
  - [ ] Gaming Mode (windowed game): popup appears
  - [ ] Gaming Mode (full-screen game): record whether popup appears on top

#### Checklist 1.4c: Dialog Tool Priority + Notify-Send Fallback
- [x] **Dialog tool priority system**
  - [x] Define environment-aware priority rules (gamescope/Wayland/KDE/Desktop)
  - [x] Implement selection order:
    - [x] Wayland/gamescope: `yad` → `kdialog` → `zenity`
    - [x] KDE: `kdialog` → `yad` → `zenity`
    - [x] Default: `zenity` → `yad` → `kdialog`
  - [x] Log selected tool + environment
  - [x] Document behavior and limitations
- [x] **Notify-send fallback**
  - [x] Add fallback in `show_warning()` when dialog tool fails
  - [x] Log fallback usage and errors
  - [x] Document that fallback is non-modal and best-effort
- [ ] **Manual testing checklist**
  - [ ] Wayland/gamescope: verify tool selection order in logs
  - [ ] Dialog failure: verify notify-send fallback and log entry

#### Checklist 1.5: Add Script Robustness
- [x] Add shebang line (`#!/bin/bash`)
- [x] Add error handling for missing dependencies
- [x] Add logging capability (optional, to syslog or file) - Uses logger command if available
- [x] Add file-based logging to `~/.config/sleep-warning/warnings.log` for user-accessible logs - IMPLEMENTED: log_to_file() function with timestamp and log level
- [x] Log window state information (full-screen, exclusive, windowed, etc.) when warnings are triggered - IMPLEMENTED: Logs window state and title in show_warning()
- [x] Log display environment information (X11/Wayland, display identifier) when warnings are triggered - IMPLEMENTED: Logs display environment type and display ID
- [x] Log dialog tool used (zenity/yad/kdialog) for troubleshooting - IMPLEMENTED: Logs dialog tool selection
- [x] Log popup success/failure status - IMPLEMENTED: Logs popup PID, exit codes, and status
- [x] Add log rotation or size limits to prevent log file from growing too large - IMPLEMENTED: Automatic rotation at 10MB, keeps last 1000 lines
- [x] Add script header comments explaining purpose
- [x] Make script executable (`chmod +x`)
- [x] Basic functionality testing - TESTED: Script syntax validated, dependencies verified (zenity, xdotool available), logging functionality confirmed (log file created with entries), popup display verified (log shows successful popup execution)

#### Checklist 1.6: Create Interactive Configuration Script
- [x] Create `configure.sh` script with shebang (`#!/bin/bash`)
- [x] Add script header comments explaining purpose and usage
- [x] Implement GUI-based interactive wizard using zenity dialogs
- [x] Create welcome/information dialog explaining the configuration process
- [x] Implement day-by-day configuration prompts (Sunday through Saturday)
- [x] For each day, prompt for start hour (0-23)
- [x] For each day, prompt for end hour (0-23)
- [x] Add input validation (hours must be 0-23, start < end)
- [x] Add option to skip a day (no restrictions for that day)
- [x] Add option to use same settings for all weekdays
- [x] Add option to use same settings for both weekend days
- [x] Add prompt for check interval (frequency) configuration - IMPLEMENTED: Prompts for CHECK_INTERVAL (1-60 minutes) with cancellation confirmation
- [x] Add prompt for popup size configuration - IMPLEMENTED: Prompts for POPUP_SIZE (small/medium/large) with cancellation confirmation
- [x] Add prompt for popup position configuration - IMPLEMENTED: Prompts for POPUP_POSITION (center, corners, etc.) with cancellation confirmation
- [x] Add prompt for minimum display time configuration - IMPLEMENTED: Prompts for POPUP_MIN_DISPLAY_TIME (0-300 seconds) with cancellation confirmation
- [x] Add prompt for immovable window configuration - IMPLEMENTED: Prompts for POPUP_IMMOVABLE (true/false) in configure.sh with cancellation confirmation
- [x] Display summary of configured hours before saving
- [x] Display summary including interval, size, and position - IMPLEMENTED: Summary shows all configuration options including minimum display time and immovable window setting
- [x] Add confirmation dialog before writing to config file
- [x] Implement config file writing with proper format
- [x] Write check interval to config file - IMPLEMENTED: CHECK_INTERVAL saved to config
- [x] Write popup size to config file - IMPLEMENTED: POPUP_SIZE saved to config
- [x] Write popup position to config file - IMPLEMENTED: POPUP_POSITION saved to config
- [x] Write minimum display time to config file - IMPLEMENTED: POPUP_MIN_DISPLAY_TIME saved to config
- [x] Write immovable window setting to config file - IMPLEMENTED: POPUP_IMMOVABLE saved to config
- [x] Preserve existing config file comments if present - FIXED: Script now extracts and preserves user comments from existing config file. Comments are preserved in a dedicated section (may change position but are not lost).
- [x] Add error handling for missing zenity (fallback to text prompts)
- [x] Add graceful handling for systems without GUI
- [x] Test configuration script with various input scenarios - PARTIALLY TESTED: Script syntax validated, basic execution verified. Full interactive testing requires GUI and user interaction
- [x] Make configure.sh executable (`chmod +x configure.sh`)

#### Checklist 1.8: Improve Time Configuration Clarity and User Experience

**Current Issues Identified**:
- Configuration wizard asks for start hour separately, then asks for range (redundant and confusing)
- Overnight range behavior not clearly explained (23-5 on Monday = Monday 11 PM to Tuesday 5 AM)
- Overlapping ranges not detected or explained (Monday 23-5 and Tuesday 23-5 both cover Tuesday midnight-5am)
- Summary doesn't show actual time periods or highlight overlaps

**Improvements Needed**:

- [x] **Fix redundant input prompts** - IMPLEMENTED: Removed separate start hour prompt, uses single unified input field for time ranges only. Removed unused start_hour variable from get_day_hours() function. Streamlined input to one prompt per day.
  - [x] Remove separate start hour prompt (currently asks for start hour, then range - redundant)
  - [x] Use single unified input field for time ranges only
  - [x] Remove unused start_hour variable from get_day_hours() function
  - [x] Streamline input to one prompt per day

- [x] **Clarify overnight range behavior in configuration wizard** - IMPLEMENTED: Added clear explanations in prompts and welcome message. Shows examples like "23-6 on Monday = Monday 11:00 PM → Tuesday 6:00 AM". Displays formatted time periods before confirmation.
  - [x] Explain that 23-5 on Monday means Monday 11 PM to Tuesday 5 AM (spans midnight)
  - [x] Show clear examples of what overnight ranges mean for each day
  - [x] Add visual/textual explanation showing the actual time periods being restricted
  - [x] Display example: "23-5 on Monday = Monday 11:00 PM → Tuesday 5:00 AM"

- [x] **Add overlap detection and warnings** - IMPLEMENTED: detect_overlaps() function detects when overnight ranges overlap with next day's ranges. Warns user in summary display. Explains that overlapping ranges are redundant but harmless. Allows user to proceed with warning.
  - [x] Detect when overnight ranges overlap with next day's ranges
  - [x] Warn user if Monday 23-5 and Tuesday 0-5 both cover Tuesday midnight-5am
  - [x] Warn user if Monday 23-5 and Tuesday 23-5 both cover Tuesday midnight-5am
  - [x] Explain that overlapping ranges are redundant but harmless (only one warning shown)
  - [x] Suggest consolidating overlapping ranges (e.g., "Consider using Monday 23-5 only")
  - [x] Allow user to proceed with warning (some users may want explicit coverage per day)

- [x] **Improve summary display** - IMPLEMENTED: format_ranges_human() and format_range_human() functions show actual time periods in human-readable format (12-hour with AM/PM). Highlights overlapping periods if detected. Shows which hours are covered by which day's configuration. Displays in both 24-hour input and 12-hour formatted output.
  - [x] Show actual time periods in human-readable format
    - Example: "Monday: 11:00 PM - 5:00 AM (Tuesday)" for 23-5
    - Example: "Monday: 12:00 AM - 5:59 AM" for 0-5
  - [x] Highlight overlapping periods if detected
  - [x] Show which hours are covered by which day's configuration
  - [x] Display in both 24-hour and 12-hour format for clarity
  - [x] Add note explaining overnight ranges span to next day

- [x] **Add real-time preview/validation** - IMPLEMENTED: Shows preview of formatted time periods before confirmation in both GUI and text modes. Validates ranges immediately and shows errors clearly. Displays formatted time periods before confirmation.
  - [x] Show preview of what time periods will be restricted as user types
  - [x] Validate ranges immediately and show errors clearly
  - [x] Display formatted time periods before confirmation

- [x] **Add help/explanation dialog** - IMPLEMENTED: show_help_dialog() function provides comprehensive help with "What do overnight ranges mean?" section, "Understanding overlapping ranges" explanation, and examples section. Help accessible from configuration wizard via "Help" button (GUI) or "help" command (text mode).
  - [x] Create "What do overnight ranges mean?" help section
  - [x] Create "Understanding overlapping ranges" explanation
  - [x] Add "Examples" section showing common scenarios:
    - Single period: "0-5 = midnight to 5:59 AM"
    - Overnight: "23-6 = 11 PM to 6 AM (spans midnight)"
    - Multiple periods: "0-5,22-23 = midnight-5:59 AM AND 10 PM-11:59 PM"
    - Overlap scenario: "Monday 23-5 and Tuesday 23-5 both cover Tuesday midnight-5am"
  - [x] Make help accessible from configuration wizard (help button or menu option)

- [x] **Add navigation controls** - IMPLEMENTED: Full navigation support with menu-driven interface. Cancel with confirmation at any time, back navigation between days, section jumping, and skip option all implemented.
  - [x] Allow user to cancel configuration at any time (not just at summary)
  - [x] Add "Cancel" button/option to every prompt/dialog
  - [x] Confirm before cancelling if any changes have been made
  - [x] Add "Back" button/option to go to previous day's configuration (works in both GUI and text modes)
  - [x] Add "Skip" option to skip current day and move to next
  - [x] Allow jumping between sections (Timer Settings, Window Behavior, Weekdays, Weekends) via main menu
  - [ ] Show progress indicator (e.g., "Day 3 of 7: Wednesday") - Future enhancement

- [x] **Update documentation to clarify behavior** - IMPLEMENTED: Updated README.md and ../user-docs/CONFIGURATION.md with overnight range behavior, overlap behavior, and examples. Updated configure.sh welcome message with clear explanations.
  - [x] Document that overnight ranges span to next day
  - [x] Document overlap behavior (both ranges apply, but only one warning shown per check)
  - [x] Add examples showing:
    - Monday 23-5 covers Monday 11 PM to Tuesday 5 AM
    - Tuesday 23-5 covers Tuesday 11 PM to Wednesday 5 AM
    - If both set, Tuesday midnight-5am is covered by Monday's range
  - [x] Clarify in README.md, ../user-docs/CONFIGURATION.md, and configure.sh welcome message
  - [ ] Add FAQ section addressing common confusion points
  - [x] Document navigation features (cancel, back, skip)

- [ ] **Add restore to default configuration option**
  - [ ] Add option in configure.sh to restore default configuration values (via GUI and via text)
  - [ ] Add option in manage.sh to restore default configuration
  - [ ] Show confirmation dialog before restoring (warn that current settings will be lost)
  - [ ] Restore default restricted hours (weekdays: 0-5, weekends: 1-5)
  - [ ] Restore default CHECK_INTERVAL (10 minutes)
  - [ ] Restore default POPUP_SIZE (medium)
  - [ ] Restore default POPUP_POSITION (center)
  - [ ] Restore default POPUP_MIN_DISPLAY_TIME (30 seconds)
  - [ ] Restore default POPUP_IMMOVABLE (true)
  - [ ] Preserve user comments if possible (or ask if user wants to keep comments)
  - [ ] Show summary of restored defaults before final confirmation
  - [ ] Update timer file if CHECK_INTERVAL is restored

#### Checklist 1.7: Create Management/Help Script
- [x] Create `manage.sh` script with shebang (`#!/bin/bash`)
- [x] Add script header comments explaining purpose and usage
- [x] Implement main menu using zenity (or text menu if GUI unavailable)
- [x] Add function to check if service is installed
- [x] Add function to display current service status (enabled/disabled, active/inactive)
- [x] Add function to display current timer status and next trigger time
- [x] Add function to show current configuration file contents
- [x] Add function to explain how to temporarily disable the service
- [x] Add function to explain how to re-enable the service
- [x] Add function to provide quick disable command (with confirmation)
- [x] Add function to provide quick enable command (with confirmation)
- [x] Add function to launch configuration wizard (`configure.sh`)
- [x] Add function to display service logs (using journalctl)
- [x] Add function to explain uninstall process
- [x] Add function to show file locations (config, script, systemd units)
- [x] Add function to display help/information about the system
- [x] Add error handling for missing dependencies
- [x] Add graceful handling for systems without GUI (text-based menu)
- [x] Test management script thoroughly - PARTIALLY TESTED: Script syntax validated, basic execution verified. Full interactive menu testing requires GUI and user interaction
- [x] Make manage.sh executable (`chmod +x manage.sh`)
