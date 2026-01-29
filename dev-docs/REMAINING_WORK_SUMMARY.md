# Remaining Work Summary

This document provides a concise overview of work remaining to be completed for the Sleep Warning System. Enhancements are listed in numerical order.

**Note**: This document focuses on work that remains to be done. Fully implemented enhancements (with no remaining work) are not listed here but can be found in [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md). Enhancements marked as "Mostly Implemented" or "Partially Implemented" are listed here if they have remaining work (testing, documentation, etc.).

## Priority Items
- [ ] **ADDED HERE: improve configuration process for additional lock/uninstall hours** - be able to set all days at once, be able to set lock or uninstall schedule equal to the other one if it is configured (state what the schedule is when asking if the user wants to set one equal to the other)
- [ ] **#30: Separate Timer Check Interval from Popup Display Frequency** - Hardcode timer to check every 5 minutes, add user-configurable popup display frequency to solve minute precision timing issues
- [ ] **ADDED HERE: Additional hours should not apply on days with no restrictions** - Additional lock hours and uninstall lock hours should not apply on days when there are no restricted times configured. User-configurable option to allow such locking (disabled by default). Warn users when entering additional hours on days with no restrictions. See [plan-additional-hours-no-restrictions.md](plans/plan-additional-hours-no-restrictions.md)
- [ ] **#10: Audio Alerts** 
- [ ] **Licensing** - License selection and application
- [ ] **#13a: Single Executable Installer Script** - Self-extracting installer bundling all files
- [ ] **#13b: Desktop GUI Application Wrapper** - Native desktop application (GTK/Qt/Electron)
- [ ] **ADDED HERE: Check popup, pause dialogs with all three toools** - yad, zenity, kdialog - make sure they work and cannot block script indefinitely
- [ ] **ADDED HERE: re-order configure menu items** - group related items better, make order more logical and user-friendly. Make sure all related code and documentation is updated.
- [ ] **ADDED HERE: test in Desktop Mode without external display** - run all tests on Steam Deck in Desktop mode without an external display connected
- [ ] **#29: kdialog Window Size Control** - Try using `--textbox` with `--geometry` for kdialog popups to enable size control, with fallback to `--sorry` if it doesn't work properly
- [ ] **#27 Donation Links** - ✅ **Phase 1 Partially Implemented** - PayPal donation links added to README.md, GETTING_STARTED.md, and install.sh. **Remaining**: Testing and verification. **Phase 2**: GitHub Sponsors support planned (see [enhancements/enhancement-27-phase-2-github-sponsors.md](enhancements/enhancement-27-phase-2-github-sponsors.md)) - requires license first.

## Master Plan Phases

### Phase 3: Installation and Deployment
- [ ] **Distribution Testing** - Test installation scripts on multiple distributions (Debian/Ubuntu, Fedora/RHEL, Arch/SteamOS, openSUSE, Alpine)

### Phase 4: Testing and Validation
- [ ] **Edge Case Testing** - Overnight ranges, invalid configs, missing dependencies
- [ ] **Installation/Uninstall Testing** - Test scripts on clean systems
- [ ] **SteamOS Gaming Mode Validation** - Critical Gaming Mode testing not yet done

### Phase 5: Documentation and Maintenance
- [ ] **Maintenance Documentation** - Contributing guidelines and development setup
- [ ] **Licensing** - License selection and application
- [ ] **Donation Links** - ✅ **Phase 1 Partially Implemented** - PayPal links added. **Remaining**: Testing. **Phase 2**: GitHub Sponsors (see [enhancements/enhancement-27-phase-2-github-sponsors.md](enhancements/enhancement-27-phase-2-github-sponsors.md)) - requires license first.

## Complementary Enhancements

- [ ] **#2a: Extend Dialog Tool Priority to Configuration Wizard** - ✅ **MOSTLY IMPLEMENTED** - Main functionality implemented for configure.sh. **Remaining**: Comprehensive testing across all dialog tools and environments
- [ ] **#3: Enhanced Window Size Options and Display-Based Sizing** - ✅ **MOSTLY IMPLEMENTED** - Core functionality complete: resolution detection module, six predefined sizes (xsmall, small, medium, large, xlarge, max), display-based and fixed modes, percentage-based custom sizing, configuration wizard integration, automated tests passing (53/53). **Remaining**: UI/Dialog Tool Testing (button visibility for all sizes with YAD/Zenity/KDialog), resolution detection testing on Wayland and gamescope environments, multi-monitor setup testing, testing on different display resolutions (1080p, 4K, ultrawide)
- [ ] **#4: Systemd Service Environment Detection** - ✅ **MOSTLY IMPLEMENTED** - Core implementation complete (Phases 1-10): mode detection functions, service configuration infrastructure, installation/configuration integration, logging, automated tests (15/15 passing), documentation. **Remaining**: Manual testing on actual SteamOS Desktop Mode and Gaming Mode environments (Phase 7.3-7.6), optional status.sh troubleshooting enhancement (Phase 6.3)
- [ ] **#5: Configurable Warning Messages** - Customize warning text per day/time range
- [ ] **#6: Escalating Warnings** - Progressively stronger warnings for continued usage
- [-] ~~**#8: Temporary Disable via Config**~~ - **PARTIALLY IMPLEMENTED** - Available via `manage.sh`; future work: config file toggle and/or `configure.sh` integration. **Note**: May remove temporary disable option entirely to discourage impulsive disabling; users can modify restrictions via config or uninstall.
- [ ] **#9: System Sleep/Hibernate Detection** - ✅ **MOSTLY Implemented** - Core implementation complete (sleep detection, popup queue prevention, configuration validation), automated unit tests passing (24/24), documentation complete. **Remaining**: Manual testing (sleep/hibernate scenarios, popup queue prevention with real popups)
- [ ] **#10: Audio Alerts** - Optional audio notification alongside visual popup
- [ ] **#12: Wayland-Specific Window Management** - Wayland-native window control (requires research)
- [ ] **#13: Distribution-Specific Optimizations** - Optimizations for specific distributions
- [ ] **#13a: Single Executable Installer Script** - Self-extracting installer bundling all files
- [ ] **#13b: Desktop GUI Application Wrapper** - Native desktop application (GTK/Qt/Electron)
- [ ] **#16: Visual Day/Time Configuration Grid** - Phase 2: Interactive hour-by-hour grid editing with drag selection
- [ ] **#16c: Multiple Time Range Entry in GUI** - Allow adding/editing multiple comma-separated time ranges per day in configure.sh GUI (text mode already supports it). See [enhancement-16c-multiple-range-entry-gui.md](enhancements/enhancement-16c-multiple-range-entry-gui.md).
- [ ] **#30: Separate Timer Check Interval from Popup Display Frequency** - Hardcode timer to check every 5 minutes, add user-configurable popup display frequency to solve minute precision timing issues
- [ ] **#17: Multi-Display Popup Support** - Display popups on all monitors simultaneously
- [ ] **#18: Config File Locking During Restricted Hours** - ✅ **MOSTLY IMPLEMENTED** - Core functionality complete (Phases 1-10): config file locking with Option A (dedicated config directory), integration with sleep-warning.sh, configure.sh, and uninstall.sh, migration support, self-healing mechanism, comprehensive testing (unit, integration, edge cases), and complete documentation (user, developer, code). All tests passing. **Remaining**: Some tests remain.
- [ ] **#20: Additional Hours for Config Locking and configure.sh Blocking** - ✅ **Phase 1 Mostly Complete** - Lock hours for configure.sh and manage.sh blocking are implemented. **Remaining**: Add weekday/weekend together configuration options to match restricted hours flow (currently only per-day configuration available)
- [ ] **#22: Prevent 24/7 Restriction Configuration** - ✅ **MOSTLY IMPLEMENTED** - Core validation logic implemented. **Remaining**: Comprehensive testing (edge cases, boundary conditions, overlapping ranges), integration testing with high restriction warnings. **Note**: Integration with Enhancement #18 (Config File Locking) is complete - config locking automatically disables when restrictions exceed 9660 minutes/week.
- [ ] **#22a: Fix Validation Edge Cases in 24/7 Restriction Detection** - Address edge cases in validation logic (handles `start_hour == end_hour`, sparse array indices, IFS handling)
- [ ] **#23: Display Restricted Times/Days in Popup** - Show configured restricted hours in warning popup
- [ ] **#24: Unified Dialog Tool Priority (YAD → Zenity → KDialog)** - ✅ **MOSTLY IMPLEMENTED** - Core implementation complete with abstraction layer. **Remaining**: Comprehensive testing across all dialog tools and environments (Wayland/X11/KDE), verify all dialog types work correctly with each tool, test positioning (center/top-left) with all tools
- [ ] **#25: User-Selectable Dialog Tool** - ✅ **MOSTLY IMPLEMENTED** - Core functionality complete: configuration option, wizard integration, status display, automated tests passing. **Remaining**: Manual testing (configuration wizard GUI/text mode, status display, popup fallback behavior, service restart persistence)
- [x] **#26: Prevent uninstall.sh Execution During Restricted Hours** - ✅ **Phase 1 Mostly Implemented, Phase 2 Complete** - Phase 1: Core functionality complete (difficult uninstall verification), testing pending. Phase 2: Implementation complete, unit tests passing (15/15), uninstall lock hours integrated into configure.sh. **Remaining**: Phase 1 comprehensive testing (integration tests, edge cases), Phase 2 integration tests (uninstall.sh behavior, UI testing), verify manual uninstall guide script documentation
- [ ] **#27: Donation Links** - ✅ **Phase 1 Partially Implemented** - PayPal donation links added to README.md, GETTING_STARTED.md, and install.sh completion message. **Remaining**: Testing and verification (link testing, mobile compatibility). **Phase 2**: GitHub Sponsors support planned - see [enhancements/enhancement-27-phase-2-github-sponsors.md](enhancements/enhancement-27-phase-2-github-sponsors.md) (requires license first). See [enhancements/enhancement-27-paypal-donation-links.md](enhancements/enhancement-27-paypal-donation-links.md) for Phase 1 details.
- [ ] **#28: SteamOS Newbie Installation Guide** - Provide comprehensive installation instructions and helpful error messages specifically for new SteamOS/Steam Deck users, including guidance on setting up sudo password (which is not set by default) and installing required packages like yad
- [ ] **#29: kdialog Window Size Control** - Try using `--textbox` with `--geometry` for kdialog popups to enable size control, with fallback to `--sorry` if it doesn't work properly. If implemented, make sure kdialog popup is never over 95% of screen, similar to yad and zenity.
- [ ] **ADDED HERE: make 24/7 prevention and high restriction warnings apply to additional hours, also** - ✅ **COMPLETED** - Validation now includes combined total of restriction hours, config lock hours, and uninstall lock hours. Safety overrides clear additional hours when high restrictions detected. See [plan-extend-24-7-prevention-to-additional-hours.md](plans/plan-extend-24-7-prevention-to-additional-hours.md). **Remaining**: Testing (Phase 5)
- [ ] **ADDED HERE: Additional hours should not apply on days with no restrictions** - Additional lock hours and uninstall lock hours should not apply on days when there are no restricted times configured. User-configurable option to allow such locking (disabled by default). Warn users when entering additional hours on days with no restrictions. See [plan-additional-hours-no-restrictions.md](plans/plan-additional-hours-no-restrictions.md)

## Alternative Approaches

- [ ] **#1: Steam Overlay Integration** - Integrate with Steam Overlay API (best solution for Gaming Mode full-screen games, requires significant development)
- [ ] **#2: Custom Wayland Protocol Implementation** - Custom Wayland protocol for gamescope (very complex, limited benefit)
- [ ] **#3: Native Desktop Application (GUI Wrapper)** - Full desktop application to replace bash scripts (improves UX but not Gaming Mode compatibility)
- [ ] **#4: Systemd Timer Alternative (Cron-based)** - Use cron instead of systemd timers
- [ ] **#6: Executable/Binary Distribution Options** - Various approaches for distributing as executables/binaries where end-users don't have source code access (self-extracting installer, shell compiler, obfuscation, package managers, compiled language rewrite). See [enhancements/alternative-06-executable-binary-distribution.md](enhancements/alternative-06-executable-binary-distribution.md)

## Testing & Validation Work

### Critical Testing Gaps
- [ ] **SteamOS Gaming Mode Testing** - Validate system behavior in Gaming Mode with full-screen games
- [ ] **Edge Case Testing** - Overnight time ranges, invalid configurations, missing dependencies
- [ ] **Multi-Distribution Testing** - Verify installation scripts work across all supported distributions
- [ ] **Dialog Tool Testing** - Comprehensive testing of YAD/Zenity/KDialog across all environments

### Integration Testing
- [ ] **Systemd Service Persistence** - Verify service behavior across mode transitions (Desktop ↔ Gaming) - ✅ **Partially Addressed** - Enhancement #4 implements mode detection and service configuration. Manual testing on actual SteamOS environments recommended.
- [ ] **Display Detection Edge Cases** - Test all fallback strategies in various environments
- [ ] **Configuration Validation** - Test all validation logic with edge cases

## Documentation Work

- [ ] **Maintenance Documentation** - Contributing guidelines, development setup, coding standards
- [ ] **Licensing** - Select and apply appropriate license (MIT, GPL, etc.) - See [LICENSE_OPTIONS.md](info/LICENSE_OPTIONS.md) and [plan-phase-5-documentation.md](plan-phase-5-documentation.md#checklist-54-license-selection-and-implementation)
- [ ] **Donation Integration** - ✅ **Phase 1 Partially Implemented** - PayPal links integrated into README.md, GETTING_STARTED.md, and install.sh. **Remaining**: Testing. **Phase 2**: GitHub Sponsors planned (see [enhancements/enhancement-27-phase-2-github-sponsors.md](enhancements/enhancement-27-phase-2-github-sponsors.md)) - requires license first.

## Code Quality Improvements

Based on [Quality Improvement Assessment (2026-01-23)](qi-assessments/qi-assessment-2026-01-23-003550.md):

- [x] **Split lib/configure-input.sh into smaller modules** - ✅ **COMPLETED** - Split the 2,571-line module into 5 focused modules (configure-input-basic.sh, configure-input-popup.sh, configure-input-features.sh, configure-input-time.sh, configure-input-service.sh) for improved maintainability. All tests passing (44/44). See [plan-split-configure-input.md](completed-plans/plan-split-configure-input.md)
- [x] **Extract day name conversion to shared function** - ✅ **COMPLETED** - Consolidated repeated day number-to-name conversion logic into shared functions `day_num_to_name_upper()` and `day_num_to_name_title()` in `lib/configure-core.sh`. Updated `lib/config.sh` (3 functions) and `lib/configure-input-time.sh` (2 locations) to use shared functions with fallback for compatibility. All tests passing (32/32 in test-day-name-conversion.sh, plus 69 related tests verified). See [plan-code-quality-improvements.md](plan-code-quality-improvements.md)
- [x] **Extract magic numbers to constants** - ✅ **COMPLETED** - Replaced hardcoded values with named constants in `lib/configure-core.sh`: MIN_HOUR/MAX_HOUR (0-23), MIN_DISPLAY_TIME/MAX_DISPLAY_TIME (0-300), MIN_CHECK_INTERVAL/MAX_CHECK_INTERVAL (1-60), and centralized MINUTES_PER_DAY/MINUTES_PER_WEEK. Updated all validation functions in configure-input modules and config.sh to use constants. All tests passing (101 total tests verified). See [plan-code-quality-improvements.md](plan-code-quality-improvements.md)

## Completed Enhancements (No Remaining Work)

The following enhancements are fully implemented with no remaining work. They are listed here for reference but are not tracked in the remaining work sections above:

- [x] **#16b: 12-Hour Format Time Input and GUI Spinbox Widgets** - ✅ **COMPLETED** - Support for 12-hour format (e.g., 11:30pm) and minute precision implemented across all components. Specialized GUI widgets created for YAD (spinboxes), Zenity (forms), and KDialog (sequential comboboxes). Automatic config migration and display format preference added. See [enhancement-16b-12-hour-format-time-input.md](enhancements/enhancement-16b-12-hour-format-time-input.md).

- [x] **ADDED HERE (no enhancement md file): reduce arithmetic questions from 10 to 5, allow up to 3 wrong answers total** - for uninstall.sh and for manual-uninstall-guide.sh ✅ **COMPLETED** - Updated both `lib/uninstall-verification.sh` and `manual-uninstall-guide.sh` to use 5 questions with 3 wrong answers allowed. All user-facing messages and comments updated. Tests updated and passing (30/30).

- ✅ **#2: Dialog Tool Priority System** - Fully implemented (superseded by Enhancement #24)
- ✅ **#7: Warning Event Logging** - Fully implemented (file-based logging with rotation)
- ✅ **#11: Desktop Notification Fallback** - Fully implemented (fallback in sleep-warning.sh)
- ✅ **#14: Immovable Popup Window** - Fully implemented (X11 support with wmctrl/xdotool)
- ✅ **#14b: Configure.sh GUI Window Behavior** - Fully implemented (window title differentiation)
- ✅ **#15: Auto-Close Popup Window** - Fully implemented (automatically closes popup 10 seconds after minimum display time completes, all automated tests passing)

**Note**: Enhancement #19 Phase 1 is complete, but Phase 2 work is integrated with Enhancement #20 and listed above. Enhancement #26 Phase 1 has remaining testing work, and Phase 2 is complete with integration tests pending (both listed above).

## Notes

- Enhancements are listed in numerical order for easy reference
- **Mostly Implemented** items may need testing, documentation, or minor completion work
- **Phase 2** items refer to follow-up phases of multi-phase enhancements
- **Alternative Approaches** require significant architectural changes and should be evaluated carefully
- Testing work is critical for ensuring reliability, especially for SteamOS Gaming Mode compatibility
- Fully completed enhancements (no remaining work) are listed in the "Completed Enhancements" section above

---

**Last Updated**: 2026-01-26 (Added Enhancement #16c: Multiple Time Range Entry in GUI)
**Related Documents**: 
- [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) - Detailed enhancement descriptions
- [linux-warning-system-plan.md](linux-warning-system-plan.md) - Master implementation plan
- [qi-assessments/qi-assessment-2026-01-23-003550.md](qi-assessments/qi-assessment-2026-01-23-003550.md) - Quality improvement assessment
