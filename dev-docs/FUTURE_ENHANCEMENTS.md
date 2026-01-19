# Future Enhancements and Alternatives

This document outlines potential improvements and alternative approaches to enhance functionality, compatibility, and user experience for the Sleep Warning System. Each item is categorized as either **Complementary** (can be added to the current suite of scripts and files) or **Alternative Approach** (would require a different implementation strategy).

For the master plan and detailed checklists, see [linux-warning-system-plan.md](linux-warning-system-plan.md). For SteamOS Gaming Mode compatibility details, see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md).

## Complementary Enhancements (Can Be Added to Current System)

These enhancements can be integrated into the existing bash script suite without requiring a complete redesign:

### 1. Enhanced Display Detection (Moved)
- **Status**: Moved to the Phase 1 detailed plan as a checklist in `dev-docs/plan-phase-1-setup-and-scripts.md`.
- **Related**: See [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#display-detection-enhancements) for detailed implementation strategies.

### 2. Dialog Tool Priority System
- **Description**: Implement intelligent dialog tool selection based on environment (prefer yad for Gaming Mode, kdialog for KDE)
- **Priority**: High (improves Gaming Mode compatibility)
- **Status**: ✅ **Implemented** - Environment-aware selection added (Wayland/gamescope: yad → kdialog → zenity; KDE: kdialog → yad → zenity; default: zenity → yad → kdialog). See [plan-phase-1-setup-and-scripts.md](plan-phase-1-setup-and-scripts.md#checklist-14c-dialog-tool-priority--notify-send-fallback).
- **Details**: See also [enhancements/enhancement-02-dialog-tool-priority-system.md](enhancements/enhancement-02-dialog-tool-priority-system.md)

### 2a. Extend Dialog Tool Priority System to Configuration Wizard
- **Description**: Extend environment-aware dialog tool selection to `configure.sh` for consistency with `sleep-warning.sh` and better Wayland/KDE support
- **Priority**: Medium (improves consistency and Wayland/KDE compatibility for configuration interface)
- **Status**: Not implemented
- **Details**: See [enhancements/enhancement-02a-extend-dialog-tool-priority-to-config-wizard.md](enhancements/enhancement-02a-extend-dialog-tool-priority-to-config-wizard.md)

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

### 7. Warning Event Logging
- **Description**: Log each warning event with timestamp, window state, display environment, and dialog tool to a file for user review
- **Priority**: High (critical for troubleshooting Gaming Mode compatibility)
- **Status**: Not implemented
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

### 11. Desktop Notification Fallback (Moved)
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

### 14. Immovable Popup Window
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

### 16. Visual Day/Time Configuration Grid
- **Description**: Provide a visual interface for configuring day/time restrictions, showing a summary grid of days and their configured time ranges, with easy access to edit any day. Implemented in two phases: Phase 1 provides visual summary and easy day-by-day editing, Phase 2 adds full interactive grid editing capabilities.
- **Priority**: Medium (significantly improves usability and reduces configuration errors)
- **Status**: Not implemented
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

### 19. Prevent configure.sh Execution During Restricted Hours
- **Description**: Prevent `configure.sh` from running during restricted hours (and optionally during additional configurable hours) to prevent users from circumventing restrictions by changing settings
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
4. File-Based Logging with Window State Information
5. ~~Immovable Popup Window~~ ✅ **IMPLEMENTED** (critical for minimum display time feature effectiveness)
6. System Sleep/Hibernate Detection (prevents false warnings after system resume)

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
15. Config File Locking During Restricted Hours
16. Prevent configure.sh During Restricted Hours
17. One-Time Pause Feature (5 or 10 minutes, available from popup)

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
