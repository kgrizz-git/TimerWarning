# Sleep Warning System - Implementation Plan

**Related Documents**:
- [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md) - Detailed technical specifications and implementation details
- [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md) - SteamOS Gaming Mode compatibility and effectiveness assessment
- [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) - Future enhancements and alternative approaches
- [info/DISTRIBUTION_OPTIONS.md](info/DISTRIBUTION_OPTIONS.md) - Distribution and packaging options

## High-Level Description

This project implements a systemd-based monitoring system that displays interactive warning popups when the system is being used during configurable restricted hours. **The system is designed with maximum compatibility as a core principle**, working on any modern Linux distribution with systemd (including Steam OS in both Desktop Mode and Gaming Mode, Ubuntu, Debian, Fedora, Arch, and others). It uses a bash script combined with systemd timers to check the current time every 10 minutes and display modal warning dialogs if usage occurs during user-defined restricted hours.

**Compatibility Focus**: Special attention has been given to ensuring the system works reliably on SteamOS in Gaming Mode, which presents unique challenges including Wayland compositor (gamescope) display detection, full-screen game overlay compatibility, and systemd user service persistence across mode transitions. The implementation includes robust fallback mechanisms and multiple detection strategies to maximize compatibility across all supported environments.

**Default restricted hours** (easily configurable):
- **Weekdays (Monday-Friday)**: Midnight (00:00) to 6:00 AM
- **Weekends (Saturday-Sunday)**: 1:00 AM to 6:00 AM

The restricted hours for each day of the week are easily configurable through a simple configuration file, allowing users to customize the warning schedule to their needs. The popup dialogs are modal and require user interaction before they can be dismissed, ensuring the user is aware of the late-night usage. The system runs as a user service (not system-wide) to ensure proper display access and user context.

## Architecture Overview

The solution consists of eight main components:

1. **Configuration File** (`sleep-warning.conf`):
   - Simple text-based configuration file
   - Defines restricted hours for each day of the week
   - Easy to edit and modify without changing script code
   - Located in user's config directory for easy access

2. **Bash Script** (`sleep-warning.sh`): 
   - Modular architecture with 7 library modules in `lib/` directory
   - Reads configuration file to determine restricted hours
   - Checks current day of week and time
   - Determines if current usage falls within restricted hours
   - Displays modal popup using `zenity` (with fallbacks to `yad` and `kdialog`) if conditions are met
   - Handles display environment detection with multiple fallback strategies (X11 DISPLAY, Wayland WAYLAND_DISPLAY, loginctl session detection, gamescope detection)
   - Includes SteamOS Gaming Mode compatibility features

3. **Systemd Service** (`sleep-warning.service`):
   - Defines the service that executes the bash script
   - Runs as a user service (not root)
   - Handles environment variables for display access

4. **Systemd Timer** (`sleep-warning.timer`):
   - Triggers the service every 10 minutes
   - Uses systemd's calendar-based timer functionality
   - Automatically starts on boot/login

5. **Installation Script** (`install.sh`):
   - Automated installation script for easy setup
   - Detects Linux distribution and package manager
   - Checks and installs required dependencies
   - Copies files to correct locations
   - Sets proper permissions
   - Enables and starts the systemd timer
   - Provides clear success/error feedback

6. **Uninstall Script** (`uninstall.sh`):
   - Removes installed files
   - Stops and disables systemd timer
   - Provides cleanup confirmation

7. **Interactive Configuration Script** (`configure.sh`):
   - Modular architecture with 7 library modules in `lib/` directory
   - Interactive wizard that walks users through setting restricted hours
   - Uses zenity dialogs for user-friendly GUI interface
   - Prompts for restricted hours for each day of the week
   - Validates input and provides helpful examples
   - Updates configuration file with user selections
   - Can be run anytime after installation to modify settings

8. **Management/Help Script** (`manage.sh`):
   - Provides information and management options for the sleep warning system
   - Displays current service status (enabled/disabled, active/inactive)
   - Explains how to temporarily disable the service
   - Explains how to re-enable the service
   - Explains how to uninstall the system
   - Provides quick access to view configuration
   - Provides quick access to run configuration wizard
   - Shows service logs and troubleshooting information

## Implementation Plan

## Master Plan Overview

This master plan provides high-level phase summaries and overall checklists.
Detailed checklists and implementation notes are split into phase-specific plan files.

**Detailed Plans**:
- [plan-phase-1-setup-and-scripts.md](plan-phase-1-setup-and-scripts.md)
- [plan-phase-2-systemd.md](plan-phase-2-systemd.md)
- [plan-phase-3-installation.md](plan-phase-3-installation.md)
- [plan-phase-4-testing.md](plan-phase-4-testing.md)
- [plan-phase-5-documentation.md](plan-phase-5-documentation.md)
- [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md)

## Phase 1: Project Setup and Script Development

**Summary**: Build core scripts, configuration system, and popup behavior. Ensure display detection and logging are robust.

**Detailed Checklist**: See [plan-phase-1-setup-and-scripts.md](plan-phase-1-setup-and-scripts.md)

### Implementation Checklist
- [x] Core bash script (`sleep-warning.sh`) - Configuration parsing, time checking, popup display
- [x] Configuration system - File format, defaults, validation, configurable options
- [x] Display detection - X11, Wayland, gamescope detection with fallbacks
- [x] Dialog and popup functionality - Tool priority system, notification fallback, immovable window
- [x] Logging system - Systemd journal logging and file-based logging with automatic rotation (10 MB limit, keeps last 1000 lines)

**Status**: [x] **Complete** - All core functionality implemented including file-based logging with automatic rotation.

## Phase 2: Systemd Integration

**Summary**: Define user service + timer units. Ensure user-session compatibility.

**Detailed Checklist**: See [plan-phase-2-systemd.md](plan-phase-2-systemd.md)

### Implementation Checklist
- [x] Systemd service unit - Service definition, environment handling, user service configuration
- [x] Systemd timer unit - Timer schedule, calendar-based triggering, auto-start on boot/login
- [x] User session compatibility - Service tested and verified working

**Status**: [x] **Complete** - Service and timer units created and tested.

## Phase 3: Installation and Deployment

**Summary**: Installation/uninstall scripts and manual steps. Distribution-specific support.

**Detailed Checklist**: See [plan-phase-3-installation.md](plan-phase-3-installation.md)

### Implementation Checklist
- [x] Installation script (`install.sh`) - Distribution detection, dependency management, file installation, systemd setup
- [x] Uninstall script (`uninstall.sh`) - Service/timer removal, file cleanup, config handling
- [x] Configuration script (`configure.sh`) - Interactive wizard, visual grid, input validation
- [x] Management script (`manage.sh`) - Service status, configuration viewing, disable/enable, logs
- [x] Distribution support - Debian/Ubuntu, Fedora/RHEL, Arch/SteamOS, openSUSE, Alpine
- [ ] Testing on multiple distributions - Installation scripts created but need testing

**Status**: [-] **Partially Implemented** - All scripts created and functional, but distribution testing pending.

## Phase 4: Testing and Validation

**Summary**: Functional, edge-case, install/uninstall, and integration testing. SteamOS Gaming Mode validation.

**Detailed Checklist**: See [plan-phase-4-testing.md](plan-phase-4-testing.md)

### Testing Checklist
- [-] Functional testing - Basic functionality tested, some edge cases pending
- [ ] Edge case testing - Overnight ranges, invalid configs, missing dependencies
- [ ] Installation/uninstall testing - Scripts need testing on clean systems
- [-] Integration testing - Systemd service/timer tested, Desktop Mode tested
- [ ] SteamOS Gaming Mode validation - Critical Gaming Mode testing not yet done

**Status**: [-] **Partially Started** - Basic functional and integration testing done, Gaming Mode and edge cases pending.

## Phase 5: Documentation and Maintenance

**Summary**: User docs, technical docs, maintenance guidance. Licensing and donation considerations.

**Detailed Checklist**: See [plan-phase-5-documentation.md](plan-phase-5-documentation.md)

### Documentation Checklist
- [x] User documentation - README.md, GETTING_STARTED.md, USER_GUIDE.md, CONFIGURATION.md
- [x] Technical documentation - Architecture, technical details, SteamOS Gaming Mode compatibility
- [-] Maintenance documentation - Contributing guidelines and development setup pending
- [ ] Licensing and legal - License selection and application pending
- [ ] Donation links - PayPal donation setup and integration into README and documentation, explore GitHub sponsors, Patreon

**Status**: [-] **Partially Implemented** - Comprehensive user and technical documentation complete, maintenance docs and licensing pending.

## Future Enhancements

See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) for detailed descriptions and implementation notes.

### Complementary Enhancements

- [x] **1. Enhanced Display Detection** - Wayland/gamescope detection with multiple fallbacks (Moved to Phase 1 plan, partially implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#1-enhanced-display-detection-moved)
- [x] **2. Dialog Tool Priority System** - Environment-aware dialog tool selection (Implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#2-dialog-tool-priority-system-implemented)
- [x] **2a. Extend Dialog Tool Priority to Configuration Wizard** - Extend dialog tool selection to configure.sh (Implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#2a-extend-dialog-tool-priority-to-configuration-wizard-implemented)
- [ ] **3. Enhanced Window Size Options and Display-Based Sizing** - More size options and percentage-based sizing - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#3-enhanced-window-size-options-and-display-based-sizing)
- [ ] **4. Systemd Service Environment Detection** - Detect Desktop Mode vs Gaming Mode - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#4-systemd-service-environment-detection)
- [ ] **5. Configurable Warning Messages** - Customize warning text per day/time range - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#5-configurable-warning-messages)
- [ ] **6. Escalating Warnings** - Progressively stronger warnings for continued usage - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#6-escalating-warnings)
- [x] **7. Warning Event Logging** - File-based logging with window state information (Implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#7-warning-event-logging)
- [ ] **8. Temporary Disable via Config** - Allow temporary disabling via configuration - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#8-temporary-disable-via-config)
- [ ] **9. System Sleep/Hibernate Detection** - Skip warnings after system resume - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#9-system-sleephibernate-detection)
- [ ] **10. Audio Alerts** - Optional audio notifications alongside visual popup - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#10-audio-alerts)
- [x] **11. Desktop Notification Fallback** - Non-modal notification when dialogs fail (Implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#11-desktop-notification-fallback-moved)
- [ ] **12. Wayland-Specific Window Management** - Wayland-native window control - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#12-wayland-specific-window-management)
- [ ] **13. Distribution-Specific Optimizations** - Optimizations for specific distributions - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#13-distribution-specific-optimizations)
- [x] **14. Immovable Popup Window** - Prevent window movement during minimum display time (Implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#14-immovable-popup-window)
- [x] **14b. Configure.sh GUI Window Behavior** - Fix configure.sh GUI windows staying on top (Implemented - window title differentiation) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#14b-configure-sh-gui-window-behavior)
- [ ] **15. Auto-Close Popup Window** - Automatically close popup after configured time - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#15-auto-close-popup-window)
- [x] **16. Visual Day/Time Configuration Grid** - Visual interface for configuring restrictions (Mostly Implemented - Phase 1 complete, Phase 2 pending) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#16-visual-daytime-configuration-grid)
- [ ] **16b. 12-Hour Format Time Input and GUI Spinbox Widgets** - Support 12-hour format in configuration - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#16b-12-hour-format-time-input-and-gui-spinbox-widgets)
- [ ] **17. Multi-Display Popup Support** - Display popups on multiple monitors - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#17-multi-display-popup-support)
- [ ] **18. Config File Locking During Restricted Hours** - Prevent config file modification during restricted hours - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#18-config-file-locking-during-restricted-hours)
- [x] **19. Prevent configure.sh and manage.sh Execution During Restricted Hours** - Block configure.sh and manage.sh execution during restricted hours to prevent circumvention (Phase 1 Implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#19-prevent-configuresh-and-managesh-execution-during-restricted-hours-phase-1-implemented)
- [x] **20. Additional Hours for Config Locking and configure.sh Blocking** - Configure separate hours for config locking/blocking (Phase 1 Implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#20-additional-hours-for-config-locking-and-configuresh-blocking-phase-1-implemented)
- [ ] **21. One-Time Pause Feature (5 or 10 Minutes)** - Allow 5 or 10 minute pause of restrictions once per day, available from popup - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#21-one-time-pause-feature-5-or-10-minutes)
- [x] **22. Prevent 24/7 Restriction Configuration** - Prevent users from configuring 24/7 restrictions (Mostly Implemented - core validation complete, revisit when #18 and/or #19 are implemented) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#22-prevent-247-restriction-configuration)
- [ ] **22a. Fix Validation Edge Cases in 24/7 Restriction Detection** - Address edge cases and bugs in Enhancement 22 validation logic - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#22a-fix-validation-edge-cases-in-247-restriction-detection)
- [ ] **23. Display Restricted Times/Days in Popup** - Show configured restricted hours in the warning popup for transparency - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#23-display-restricted-timesdays-in-popup)
- [x] **24. Unified Dialog Tool Priority (YAD → Zenity → KDialog)** - Standardize dialog tool selection across all scripts (Mostly Implemented - core implementation complete, abstraction layer in place) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#24-unified-dialog-tool-priority-yad--zenity--kdialog)
- [ ] **25. User-Selectable Dialog Tool** - Allow users to manually choose dialog tool from installed options - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#25-user-selectable-dialog-tool)
- [x] **26. Prevent uninstall.sh Execution During Restricted Hours** - Implement difficult uninstall mode (confirmation phrase + algebra questions) during restricted hours to prevent circumvention while allowing legitimate uninstalls (Phase 1 Mostly Implemented - core functionality complete, testing pending). Total block mode may be considered as future phase (⚠️ **RISKY** - requires manual uninstall guide script) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#26-prevent-uninstallsh-execution-during-restricted-hours-phase-1-mostly-implemented)

### Distribution and Packaging Enhancements

- [ ] **13a. Single Executable Installer Script** - Self-extracting installer bundling all files for easy distribution - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#13a-single-executable-installer-script) and [info/DISTRIBUTION_OPTIONS.md](info/DISTRIBUTION_OPTIONS.md#option-1-single-executable-installer-script)
- [ ] **13b. Desktop GUI Application Wrapper** - Native desktop application (GTK/Qt/Electron) for configuration and management - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#13b-desktop-gui-application-wrapper) and [info/DISTRIBUTION_OPTIONS.md](info/DISTRIBUTION_OPTIONS.md#option-2-desktop-gui-application-wrapper)

### Alternative Approaches

- [ ] **1. Steam Overlay Integration** - C/C++ plugin using Steamworks SDK for maximum Gaming Mode effectiveness - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#1-steam-overlay-integration)
- [ ] **2. Custom Wayland Protocol Implementation** - Native Wayland protocol for window control - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#2-custom-wayland-protocol-implementation)
- [ ] **3. Native Desktop Application (GUI Wrapper)** - GUI application wrapper (GTK/Qt/Electron) - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#3-native-desktop-application-gui-wrapper) and [info/DISTRIBUTION_OPTIONS.md](info/DISTRIBUTION_OPTIONS.md#option-2-desktop-gui-application-wrapper)
- [ ] **4. Systemd Timer Alternative (Cron-based)** - Cron-based alternative to systemd timers - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#4-systemd-timer-alternative-cron-based)
- [ ] **5. Web-Based Configuration Interface** - Web-based configuration and management interface - See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#5-web-based-configuration-interface)
