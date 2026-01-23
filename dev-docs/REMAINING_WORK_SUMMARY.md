# Remaining Work Summary

This document provides a concise overview of work remaining to be completed for the Sleep Warning System. Enhancements are listed in numerical order.

**Note**: This document focuses on work that remains to be done. Fully implemented enhancements (with no remaining work) are not listed here but can be found in [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md). Enhancements marked as "Mostly Implemented" or "Partially Implemented" are listed here if they have remaining work (testing, documentation, etc.).

## Priority Items
- [ ] **#3: Enhanced Window Size Options and Display-Based Sizing** - More predefined sizes and display-based automatic sizing
- [ ] **Code quality improvements** - see section below for more info on each
    - [ ] **Split lib/configure-input.sh into smaller modules**  
    - [ ] **Extract day name conversion to shared function**  
    - [ ] **Extract magic numbers to constants** 
- [ ] **Donation Links** - PayPal setup, GitHub sponsors, Patreon integration
- [ ] **Licensing** - License selection and application
- [ ] **#13a: Single Executable Installer Script** - Self-extracting installer bundling all files
- [ ] **#13b: Desktop GUI Application Wrapper** - Native desktop application (GTK/Qt/Electron)

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
- [ ] **Donation Links** - PayPal setup, GitHub sponsors, Patreon integration

## Complementary Enhancements

- [ ] **#2a: Extend Dialog Tool Priority to Configuration Wizard** - ✅ **MOSTLY IMPLEMENTED** - Main functionality implemented for configure.sh. **Remaining**: Comprehensive testing across all dialog tools and environments
- [ ] **#4: Systemd Service Environment Detection** - ✅ **MOSTLY IMPLEMENTED** - Core implementation complete (Phases 1-10): mode detection functions, service configuration infrastructure, installation/configuration integration, logging, automated tests (15/15 passing), documentation. **Remaining**: Manual testing on actual SteamOS Desktop Mode and Gaming Mode environments (Phase 7.3-7.6), optional status.sh troubleshooting enhancement (Phase 6.3)
- [ ] **#5: Configurable Warning Messages** - Customize warning text per day/time range
- [ ] **#6: Escalating Warnings** - Progressively stronger warnings for continued usage
- [-] ~~**#8: Temporary Disable via Config**~~ - **PARTIALLY IMPLEMENTED** - Available via `manage.sh`; future work: config file toggle and/or `configure.sh` integration. **Note**: May remove temporary disable option entirely to discourage impulsive disabling; users can modify restrictions via config or uninstall.
- [ ] **#9: System Sleep/Hibernate Detection** - Skip warnings after system resume (prevents false warnings)
- [ ] **#10: Audio Alerts** - Optional audio notification alongside visual popup
- [ ] **#12: Wayland-Specific Window Management** - Wayland-native window control (requires research)
- [ ] **#13: Distribution-Specific Optimizations** - Optimizations for specific distributions
- [ ] **#13a: Single Executable Installer Script** - Self-extracting installer bundling all files
- [ ] **#13b: Desktop GUI Application Wrapper** - Native desktop application (GTK/Qt/Electron)
- [ ] **#15: Auto-Close Popup Window** - Automatically close after configured time period
- [ ] **#16: Visual Day/Time Configuration Grid** - Phase 2: Interactive hour-by-hour grid editing with drag selection
- [ ] **#16b: 12-Hour Format Time Input and GUI Spinbox Widgets** - Support 12-hour format with AM/PM and GUI spinbox widgets
- [ ] **#17: Multi-Display Popup Support** - Display popups on all monitors simultaneously
- [ ] **#18: Config File Locking During Restricted Hours** - Prevent config file modification during restricted hours
- [ ] **#20: Additional Hours for Config Locking and configure.sh Blocking** - ✅ **Phase 1 Mostly Complete** - Lock hours for configure.sh and manage.sh blocking are implemented. **Remaining**: Add weekday/weekend together configuration options to match restricted hours flow (currently only per-day configuration available)
- [ ] **#21: One-Time Pause Feature (5 or 10 Minutes)** - ✅ **MOSTLY IMPLEMENTED** - Core functionality complete: pause state management, popup button integration, configuration options, status display. Automated tests (27 tests) all passing. Manual testing (popup button clicks, warning suppression, daily tracking) pending.
- [ ] **#22: Prevent 24/7 Restriction Configuration** - ✅ **MOSTLY IMPLEMENTED** - Core validation logic implemented. **Remaining**: Comprehensive testing (edge cases, boundary conditions, overlapping ranges), integration testing with high restriction warnings, and revisit integration with Enhancement #18 (Config File Locking) when implemented
- [ ] **#22a: Fix Validation Edge Cases in 24/7 Restriction Detection** - Address edge cases in validation logic (handles `start_hour == end_hour`, sparse array indices, IFS handling)
- [ ] **#23: Display Restricted Times/Days in Popup** - Show configured restricted hours in warning popup
- [ ] **#24: Unified Dialog Tool Priority (YAD → Zenity → KDialog)** - ✅ **MOSTLY IMPLEMENTED** - Core implementation complete with abstraction layer. **Remaining**: Comprehensive testing across all dialog tools and environments (Wayland/X11/KDE), verify all dialog types work correctly with each tool, test positioning (center/top-left) with all tools
- [ ] **#25: User-Selectable Dialog Tool** - ✅ **MOSTLY IMPLEMENTED** - Core functionality complete: configuration option, wizard integration, status display, automated tests passing. **Remaining**: Manual testing (configuration wizard GUI/text mode, status display, popup fallback behavior, service restart persistence)
- [x] **#26: Prevent uninstall.sh Execution During Restricted Hours** - ✅ **Phase 1 Mostly Implemented, Phase 2 Complete** - Phase 1: Core functionality complete (difficult uninstall verification), testing pending. Phase 2: Implementation complete, unit tests passing (15/15), uninstall lock hours integrated into configure.sh. **Remaining**: Phase 1 comprehensive testing (integration tests, edge cases), Phase 2 integration tests (uninstall.sh behavior, UI testing), verify manual uninstall guide script documentation
- [ ] **#28: SteamOS Newbie Installation Guide** - Provide comprehensive installation instructions and helpful error messages specifically for new SteamOS/Steam Deck users, including guidance on setting up sudo password (which is not set by default) and installing required packages like yad

## Alternative Approaches

- [ ] **#1: Steam Overlay Integration** - Integrate with Steam Overlay API (best solution for Gaming Mode full-screen games, requires significant development)
- [ ] **#2: Custom Wayland Protocol Implementation** - Custom Wayland protocol for gamescope (very complex, limited benefit)
- [ ] **#3: Native Desktop Application (GUI Wrapper)** - Full desktop application to replace bash scripts (improves UX but not Gaming Mode compatibility)
- [ ] **#4: Systemd Timer Alternative (Cron-based)** - Use cron instead of systemd timers

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
- [ ] **Licensing** - Select and apply appropriate license (MIT, GPL, etc.)
- [ ] **Donation Integration** - Set up PayPal, GitHub Sponsors, Patreon and integrate into README/docs

## Code Quality Improvements

Based on [Quality Improvement Assessment (2026-01-23)](qi-assessments/qi-assessment-2026-01-23-003550.md):

- [ ] **Split lib/configure-input.sh into smaller modules** - Split the 1,797-line module into focused modules (basic input, popup settings, feature toggles, time range input) for improved maintainability
- [ ] **Extract day name conversion to shared function** - Consolidate repeated day number-to-name conversion logic in `lib/config.sh` into a shared function in `lib/configure-core.sh`
- [ ] **Extract magic numbers to constants** - Replace hardcoded values (hour ranges 0-23, time ranges 0-300) in `lib/configure-input.sh` with named constants

## Completed Enhancements (No Remaining Work)

The following enhancements are fully implemented with no remaining work. They are listed here for reference but are not tracked in the remaining work sections above:

- ✅ **#2: Dialog Tool Priority System** - Fully implemented (superseded by Enhancement #24)
- ✅ **#7: Warning Event Logging** - Fully implemented (file-based logging with rotation)
- ✅ **#11: Desktop Notification Fallback** - Fully implemented (fallback in sleep-warning.sh)
- ✅ **#14: Immovable Popup Window** - Fully implemented (X11 support with wmctrl/xdotool)
- ✅ **#14b: Configure.sh GUI Window Behavior** - Fully implemented (window title differentiation)

**Note**: Enhancement #19 Phase 1 is complete, but Phase 2 work is integrated with Enhancement #20 and listed above. Enhancement #26 Phase 1 has remaining testing work, and Phase 2 is complete with integration tests pending (both listed above).

## Notes

- Enhancements are listed in numerical order for easy reference
- **Mostly Implemented** items may need testing, documentation, or minor completion work
- **Phase 2** items refer to follow-up phases of multi-phase enhancements
- **Alternative Approaches** require significant architectural changes and should be evaluated carefully
- Testing work is critical for ensuring reliability, especially for SteamOS Gaming Mode compatibility
- Fully completed enhancements (no remaining work) are listed in the "Completed Enhancements" section above

---

**Last Updated**: 2026-01-23 (Added code quality improvements from quality assessment)  
**Related Documents**: 
- [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) - Detailed enhancement descriptions
- [linux-warning-system-plan.md](linux-warning-system-plan.md) - Master implementation plan
- [qi-assessments/qi-assessment-2026-01-23-003550.md](qi-assessments/qi-assessment-2026-01-23-003550.md) - Quality improvement assessment
