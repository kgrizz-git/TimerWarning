# Future Enhancements and Alternatives

This document outlines potential improvements and alternative approaches to enhance functionality, compatibility, and user experience for the Sleep Warning System. Each item is categorized as either **Complementary** (can be added to the current suite of scripts and files) or **Alternative Approach** (would require a different implementation strategy).

For the master plan and detailed checklists, see [linux-warning-system-plan.md](linux-warning-system-plan.md). For SteamOS Gaming Mode compatibility details, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md).

## Complementary Enhancements (Can Be Added to Current System)

These enhancements can be integrated into the existing bash script suite without requiring a complete redesign:

### 1. Enhanced Display Detection (Moved)
- **Status**: Moved to the Phase 1 detailed plan as a checklist in `dev-docs/plan-phase-1-setup-and-scripts.md`.
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#display-detection-enhancements) for detailed implementation strategies.

### 2. Dialog Tool Priority System (Partially Implemented)
- **Description**: Implement intelligent dialog tool selection preferring YAD's superior capabilities when available, with fallback to Zenity (most compatible) and KDialog (last resort)
- **Priority**: High (improves user experience and window management)
- **Status**: ✅ **Partially Implemented** - Environment-aware selection added for popup warnings. Current priority: YAD → Zenity → KDialog (except KDE: KDialog → YAD → Zenity). See [plan-phase-1-setup-and-scripts.md](plan-phase-1-setup-and-scripts.md#checklist-14c-dialog-tool-priority--notify-send-fallback).
- **Note**: Configuration wizard (`configure.sh`) currently uses Zenity only. See Enhancement #24 for unified implementation.
- **Details**: See also [enhancements/enhancement-02-dialog-tool-priority-system.md](enhancements/enhancement-02-dialog-tool-priority-system.md)

### 3. Enhanced Window Size Options and Display-Based Sizing
- **Description**: Add more predefined window size options and allow window sizes to be automatically calculated based on current display resolution
- **Priority**: Medium (improves usability and adaptability across different display configurations)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-03-enhanced-window-size-options.md](enhancements/enhancement-03-enhanced-window-size-options.md)

### 4. Systemd Service Environment Detection
- **Description**: Detect Desktop Mode vs Gaming Mode and adjust behavior accordingly
- **Priority**: Medium (improves compatibility)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-04-systemd-service-environment-detection.md](enhancements/enhancement-04-systemd-service-environment-detection.md)

### 5. Configurable Warning Messages
- **Description**: Allow users to customize warning message text per day or time range
- **Priority**: Low (nice-to-have feature)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-05-configurable-warning-messages.md](enhancements/enhancement-05-configurable-warning-messages.md)

### 6. Escalating Warnings
- **Description**: Show progressively stronger warnings if user continues using system during restricted hours
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-06-escalating-warnings.md](enhancements/enhancement-06-escalating-warnings.md)

### 7. Warning Event Logging (Implemented)
- **Description**: Log each warning event with timestamp, window state, display environment, and dialog tool to a file for user review
- **Priority**: High (critical for troubleshooting Gaming Mode compatibility)
- **Status**: ✅ **Implemented** - File-based logging to `~/.config/sleep-warning/warnings.log` with automatic rotation (10 MB limit, keeps last 1000 lines). Logs include timestamp, window state, window title, display environment, display ID, detection path, dialog tool used, popup size/position, and all popup events.
- **Details**: See [enhancements/enhancement-07-warning-event-logging.md](enhancements/enhancement-07-warning-event-logging.md)

### 8. Temporary Disable via Config
- **Description**: Allow users to temporarily disable warnings via configuration file or command
- **Priority**: Medium (useful feature)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-08-temporary-disable-via-config.md](enhancements/enhancement-08-temporary-disable-via-config.md)

### 9. System Sleep/Hibernate Detection
- **Description**: Skip warnings if system was recently resumed from sleep (user may have just woken up)
- **Priority**: High (prevents false warnings after system resume, improves user experience)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-09-system-sleep-hibernate-detection.md](enhancements/enhancement-09-system-sleep-hibernate-detection.md)

### 10. Audio Alerts
- **Description**: Add optional audio notification (beep, sound file) alongside visual popup
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-10-audio-alerts.md](enhancements/enhancement-10-audio-alerts.md)

### 11. Desktop Notification Fallback (Implemented)
- **Status**: ✅ **Implemented** - Fallback is now in `sleep-warning.sh` and tracked in [plan-phase-1-setup-and-scripts.md](plan-phase-1-setup-and-scripts.md#checklist-14c-dialog-tool-priority--notify-send-fallback).
- **Note**: Fallback is non-modal and best-effort; it is used only when dialog display fails.

### 12. Wayland-Specific Window Management
- **Description**: Implement Wayland-native window control using wlr-randr or similar tools
- **Priority**: Medium (improves Wayland/gamescope compatibility)
- **Status**: Not implemented (requires research into Wayland protocols)
- **Details**: See [enhancements/enhancement-12-wayland-specific-window-management.md](enhancements/enhancement-12-wayland-specific-window-management.md)

### 13. Distribution-Specific Optimizations
- **Description**: Add optimizations for specific distributions (e.g., KDE-specific features on KDE systems)
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-13-distribution-specific-optimizations.md](enhancements/enhancement-13-distribution-specific-optimizations.md)

### 13a. Single Executable Installer Script
- **Description**: Create a self-extracting installer script that bundles all project files into a single executable for easy distribution
- **Priority**: Medium (improves distribution ease, works across all distributions)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-13a-single-executable-installer.md](enhancements/enhancement-13a-single-executable-installer.md)

### 13b. Desktop GUI Application Wrapper
- **Description**: Create a native desktop application (GTK/Qt/Electron) that provides a GUI for configuration and management, replacing or complementing the command-line scripts
- **Priority**: Medium (significantly improves user experience, especially for non-technical users)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-13b-desktop-gui-application-wrapper.md](enhancements/enhancement-13b-desktop-gui-application-wrapper.md)

### 14. Immovable Popup Window (Implemented)
- **Description**: Prevent user from moving/dragging the popup window during the minimum display time countdown
- **Priority**: High (critical enhancement for minimum display time feature effectiveness)
- **Status**: ✅ **Implemented** - Uses Method 4 (monitor and restore position) to prevent window movement during minimum display time. `POPUP_IMMOVABLE` configuration option added (true/false). Works on X11 with wmctrl/xdotool, not available on Wayland.
- **Details**: See [enhancements/enhancement-14-immovable-popup-window.md](enhancements/enhancement-14-immovable-popup-window.md)

### 14b. Configure.sh GUI Window Behavior
- **Description**: Fix issue where `configure.sh` GUI windows (when run in GUI mode) can be mistaken for the warning popup and end up staying on top and being immovable. The actual warning popup should stay on top, not the configuration GUI windows.
- **Priority**: Medium (usability issue, can confuse users)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-14b-configure-gui-window-behavior.md](enhancements/enhancement-14b-configure-gui-window-behavior.md)

### 15. Auto-Close Popup Window
- **Description**: Automatically close the popup window after a pre-configured time period, providing users with a non-interactive option for warning dismissal
- **Priority**: Medium (useful feature for users who want automatic dismissal without manual interaction)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-15-auto-close-popup-window.md](enhancements/enhancement-15-auto-close-popup-window.md)

### 16. Visual Day/Time Configuration Grid (Mostly Implemented)
- **Description**: Provide a visual interface for configuring day/time restrictions, showing a summary grid of days and their configured time ranges, with easy access to edit any day. Implemented in two phases: Phase 1 provides visual summary and easy day-by-day editing, Phase 2 adds full interactive grid editing capabilities.
- **Priority**: Medium (significantly improves usability and reduces configuration errors)
- **Status**: ✅ **Mostly Implemented** - Phase 1 is complete: visual summary grid showing all days with time ranges in human-readable format, click-to-edit access for any day, visual indicators (✗) for restricted days, automatic grid refresh after edits. Phase 2 (interactive hour-by-hour grid editing with drag selection) is not yet implemented.
- **Details**: See [enhancements/enhancement-16-visual-day-time-configuration-grid.md](enhancements/enhancement-16-visual-day-time-configuration-grid.md)

### 16b. 12-Hour Format Time Input and GUI Spinbox Widgets
- **Description**: Add support for 12-hour format time entry (e.g., "11pm-5am") in addition to 24-hour format, and provide GUI spinbox widgets for easier time selection with AM/PM toggle
- **Priority**: Medium (improves usability, especially for users more familiar with 12-hour format)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-16b-12-hour-format-time-input.md](enhancements/enhancement-16b-12-hour-format-time-input.md)

### 17. Multi-Display Popup Support
- **Description**: Display warning popups on all available displays/monitors simultaneously, ensuring warnings are visible regardless of which screen the user is actively viewing
- **Priority**: Medium (useful for multi-monitor setups, improves visibility)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-17-multi-display-popup-support.md](enhancements/enhancement-17-multi-display-popup-support.md)

### 18. Config File Locking During Restricted Hours
- **Description**: Prevent modification of the configuration file during restricted hours (and optionally during additional configurable hours) to prevent users from circumventing restrictions by changing settings
- **Priority**: Medium (security/self-control feature, but may be too restrictive for some users)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-18-config-file-locking.md](enhancements/enhancement-18-config-file-locking.md)

### 19. Prevent configure.sh and manage.sh Execution During Restricted Hours
- **Description**: Prevent `configure.sh` and `manage.sh` from running during restricted hours (and optionally during additional configurable hours) to prevent users from circumventing restrictions by changing settings or disabling the system
- **Priority**: Medium (security/self-control feature, complements config file locking)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-19-prevent-configure-execution.md](enhancements/enhancement-19-prevent-configure-execution.md)

### 20. Additional Hours for Config Locking and configure.sh Blocking
- **Description**: Allow users to configure additional time ranges (separate from restriction hours) during which config file locking and configure.sh blocking are active. This allows users to lock configuration during specific hours even if those hours are not restricted (e.g., lock config during work hours to prevent distraction-related changes)
- **Priority**: Low (nice-to-have feature, adds complexity)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-20-additional-hours-config-locking.md](enhancements/enhancement-20-additional-hours-config-locking.md)

### 21. One-Time Pause Feature (5 or 10 Minutes)
- **Description**: Allow users to pause restrictions for a short period (5 or 10 minutes) once per day, with the pause option available directly from the warning popup. This provides users with flexibility for legitimate exceptions (e.g., finishing a task, handling an emergency) while maintaining overall restriction effectiveness
- **Priority**: Medium (improves user experience and flexibility while maintaining restriction effectiveness)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-21-one-time-pause-feature.md](enhancements/enhancement-21-one-time-pause-feature.md)

### 22. Prevent 24/7 Restriction Configuration (Mostly Implemented)
- **Description**: Add validation in `configure.sh` to detect and prevent users from configuring restricted hours that cover 24 hours a day, 7 days a week. This prevents users from accidentally locking themselves out of their computer. The validation must evaluate the entire configuration holistically (not just individual days) to account for overnight time ranges that span multiple days. If 24/7 restrictions are detected, show a prominent warning popup and automatically disable config file locking (if implemented) and ensure configure.sh is not blocked during restricted hours.
- **Priority**: High (critical safety feature to prevent accidental lockout)
- **Status**: ✅ **Mostly Implemented** - Core validation logic implemented to detect and prevent 24/7 restriction configuration. Validation evaluates entire configuration holistically and shows warning popup when detected. **Note**: Revisit when Enhancement #18 (Config File Locking) and/or Enhancement #19 (Prevent configure.sh and manage.sh Execution During Restricted Hours) are implemented to ensure proper integration with those features.
- **Details**: See [enhancements/enhancement-22-prevent-24-7-restriction-configuration.md](enhancements/enhancement-22-prevent-24-7-restriction-configuration.md)

### 22a. Fix Validation Edge Cases in 24/7 Restriction Detection
- **Description**: Address edge cases and potential bugs identified in code review of Enhancement 22. Fixes include: handling `start_hour == end_hour` cases explicitly (consistent with time validation), ensuring validation works correctly with sparse array indices by parsing day names from config lines, and improving IFS handling robustness. These fixes ensure the validation logic is more robust and handles all edge cases correctly.
- **Priority**: Medium (improves robustness and correctness of critical safety feature)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-22a-fix-validation-edge-cases.md](enhancements/enhancement-22a-fix-validation-edge-cases.md)

### 23. Display Restricted Times/Days in Popup
- **Description**: Enhance the warning popup to display the configured restricted hours and days, showing users exactly when restrictions are active. This provides transparency and helps users understand why they're seeing the warning. The popup should show the current day's restricted hours in a clear, readable format (12-hour format with AM/PM), and optionally show all days' restrictions or a summary.
- **Priority**: Medium (improves user experience and transparency)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-23-display-restricted-times-in-popup.md](enhancements/enhancement-23-display-restricted-times-in-popup.md)

### 24. Unified Dialog Tool Priority (YAD → Zenity → KDialog) (Mostly Implemented)
- **Description**: Standardize dialog tool selection across both `sleep-warning.sh` (popup warnings) and `configure.sh` (configuration wizard) to **always** prefer **YAD → Zenity → KDialog** in all environments, including KDE. YAD provides superior window positioning, size control, and management capabilities. Create abstraction layer for configure wizard to support all three tools seamlessly. YAD's technical advantages (native positioning, reliable sizing) take precedence over visual consistency considerations. **Positioning Simplification**: As part of this enhancement, popup positioning options will be simplified to only **center** and **top-left**. This simplification reduces complexity in position calculations (top-left requires no window size knowledge, only simple margins) and eliminates edge cases with other corner positions.
- **Priority**: Medium (improves user experience, unifies implementation, leverages YAD's capabilities when available)
- **Status**: ✅ **Mostly Implemented** - Core implementation complete: `lib/configure-dialogs.sh` provides tool-agnostic dialog functions (show_info_dialog, show_question_dialog, show_entry_dialog, show_list_dialog, show_text_info_dialog, show_multi_column_list_dialog) that automatically use YAD → Zenity → KDialog priority via `get_dialog_tool()`. All configure modules (`lib/configure-ui.sh`, `lib/configure-input.sh`, `lib/configure-display.sh`) have been updated to use the abstraction layer. Positioning has been simplified to center/top-left only in `lib/window-management.sh` and `lib/popup-display.sh`. Unified priority implemented in `lib/desktop-environment.sh` (removed environment-specific branching). `has_zenity()` function remains for backward compatibility but all active code uses `has_dialog_tool()`. Status script enhanced to display dialog tool information. Documentation updated across all user and technical docs.
- **Benefits**: Native positioning with YAD (no post-creation hacks), reliable sizing, consistent behavior across all dialogs and environments, simpler codebase (no environment-specific branching), simplified positioning logic (center/top-left only reduces complexity)
- **Details**: See [enhancements/enhancement-24-unified-dialog-priority-yad-first.md](enhancements/enhancement-24-unified-dialog-priority-yad-first.md)

### 25. User-Selectable Dialog Tool
- **Description**: Allow users to manually choose which dialog tool (zenity, yad, or kdialog) to use from a list of installed tools, overriding the automatic priority system. This gives users control over dialog tool selection when they have preferences or encounter issues with the automatic selection.
- **Priority**: Medium (improves user control and troubleshooting flexibility)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-25-user-selectable-dialog-tool.md](enhancements/enhancement-25-user-selectable-dialog-tool.md)

## Alternative Approaches (Require Different Implementation)

These approaches would require significant changes to the architecture or a completely different implementation strategy:

### 1. Steam Overlay Integration
- **Description**: Integrate with Steam Overlay API to display warnings within Steam's native overlay system
- **Priority**: Medium (best solution for SteamOS Gaming Mode full-screen games, but requires significant development effort)
- **Status**: Not implemented
- **Details**: See [enhancements/alternative-01-steam-overlay-integration.md](enhancements/alternative-01-steam-overlay-integration.md)

### 2. Custom Wayland Protocol Implementation
- **Description**: Develop custom Wayland protocol for notifications compatible with gamescope
- **Priority**: Low (very complex, limited benefit over simpler solutions, Steam Overlay achieves similar goals more easily)
- **Status**: Not implemented
- **Details**: See [enhancements/alternative-02-custom-wayland-protocol.md](enhancements/alternative-02-custom-wayland-protocol.md)

### 3. Native Desktop Application (GUI Wrapper)
- **Description**: Create full desktop application (GTK/Qt/Electron) to replace bash scripts
- **Priority**: Medium (improves user experience but not Gaming Mode compatibility)
- **Status**: Not implemented
- **Details**: See [enhancements/alternative-03-native-desktop-application.md](enhancements/alternative-03-native-desktop-application.md)

### 4. Systemd Timer Alternative (Cron-based)
- **Description**: Use cron instead of systemd timers for scheduling
- **Priority**: Low (systemd is standard, limited benefit)
- **Status**: Not implemented
- **Details**: See [enhancements/alternative-04-systemd-timer-alternative.md](enhancements/alternative-04-systemd-timer-alternative.md)

### 5. Web-Based Configuration Interface
- **Description**: Create web server for configuration and management
- **Priority**: Very Low (unnecessary complexity)
- **Status**: Not implemented
- **Details**: See [enhancements/alternative-05-web-based-configuration-interface.md](enhancements/alternative-05-web-based-configuration-interface.md)

## Recommended Implementation Priority

**High Priority (Required for Gaming Mode Compatibility)**:
1. Enhanced Display Detection (Wayland/gamescope)
2. Dialog Tool Priority System
3. Window State Detection and Logging (critical for troubleshooting)
4. ~~File-Based Logging with Window State Information~~ ✅ **IMPLEMENTED** (comprehensive logging to warnings.log with rotation)
5. ~~Immovable Popup Window~~ ✅ **IMPLEMENTED** (critical for minimum display time feature effectiveness)
6. System Sleep/Hibernate Detection (prevents false warnings after system resume)
7. ~~Prevent 24/7 Restriction Configuration~~ ✅ **MOSTLY IMPLEMENTED** (core validation complete, revisit when #18 and/or #19 are implemented) (critical safety feature to prevent accidental lockout)

**Medium Priority (Improves Compatibility/Usability)**:
6. Unified Dialog Tool Priority (YAD → Zenity → KDialog) - ⚠️ **Partially Implemented** (infrastructure in place, some legacy calls remain)
7. Steam Overlay Integration (Alternative, but best solution for SteamOS Gaming Mode full-screen games)
8. Systemd Service Environment Detection
9. ~~Desktop Notification Fallback~~ ✅ **IMPLEMENTED**
10. Wayland-Specific Window Management
11. Temporary Disable via Config
12. Enhanced Window Size Options and Display-Based Sizing
13. Auto-Close Popup Window
14. ~~Visual Day/Time Configuration Grid~~ ✅ **Mostly Implemented** (Phase 1 complete, Phase 2 pending)
15. Multi-Display Popup Support
16. Config File Locking During Restricted Hours
17. Prevent configure.sh and manage.sh During Restricted Hours
18. One-Time Pause Feature (5 or 10 minutes, available from popup)
19. Display Restricted Times/Days in Popup

**Low Priority (Nice-to-Have Enhancements)**:
14. Configurable Warning Messages
15. Escalating Warnings
16. Audio Alerts
17. Distribution-Specific Optimizations
18. Wayland support for minimum display time (would require different approach)
19. More robust window control (prevent all close methods, not just window manager)
20. Visual countdown timer in popup (instead of just text)
21. Configurable auto-reopen behavior
22. Additional Hours for Config Locking and configure.sh Blocking

## Implementation Notes

- **Complementary enhancements** can be added incrementally without breaking existing functionality
- **Alternative approaches** should be evaluated carefully as they may require significant development effort
- **Steam Overlay Integration** is the most promising solution for full Gaming Mode compatibility but requires the most development effort. See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#path-to-maximum-effectiveness) for detailed effectiveness analysis.
- All enhancements should maintain backward compatibility with existing configurations
- Testing should be performed for each enhancement, especially Gaming Mode compatibility. See [plan-phase-4-testing.md](plan-phase-4-testing.md#phase-4-testing-and-validation) for testing checklists.
