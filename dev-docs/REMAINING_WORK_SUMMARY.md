# Remaining Work Summary

This document provides a concise overview of work remaining to be completed for the Sleep Warning System. Enhancements are listed in numerical order.

**Note**: This document focuses on work that remains to be done. Fully implemented enhancements (with no remaining work) are not listed here but can be found in [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md). Enhancements marked as "Mostly Implemented" or "Partially Implemented" are listed here if they have remaining work (testing, documentation, etc.).

## Priority Items
- [x] **ADDED HERE: check pause end calculation** **Done** (2026-02-08): Verified end timestamp = current_time + (duration_minutes * 60); duration always 5 or 10 from config/UI; tests confirm. Popups confirmed to appear after pause expires.
- [ ] **#16c: Multiple Time Range Entry in GUI** - Allow adding/editing multiple time ranges per day in configure.sh GUI (text mode already supports it). See [enhancement-16c-multiple-range-entry-gui.md](enhancements/enhancement-16c-multiple-range-entry-gui.md). **Mostly done (2026-02-09):** See Priority Items; remaining: test with all dialog tools (yad, zenity, kdialog). **Done (2026-02-09):** UI now displays day clearly (e.g. "Time ranges for Monday", "Additional block hours – Tuesday"); existing ranges are passed for additional block hours and uninstall lock hours in all flows (per-day, grid edit) so the Manage Ranges dialog opens with current values. **Remaining:** Test with all dialog tools (yad, zenity, kdialog).
- [x] **ADDED HERE: improve config wizard UI** **Done** (2026-02-08): Grid click only sets the clicked day (no weekday/weekend bulk prompt). Day name shown in time-selection dialogs (optional 4th param). Lock/uninstall hours from main menu ask weekday/weekend together. Security Settings already renamed to "Script Blocking and Config Locking".
- [x] **ADDED HERE: re-order configure menu items** **Done** (2026-02-08): View Weekly Hours moved to option 9 (after Additional Uninstall Protection Hours, before Pause). Window Behavior split into submenu (size, position, min display time, immovable, auto-close, Back). Menu order: 1 Timer, 2 Window Behavior (submenu), 3–4 Weekdays/Weekends, 5 Script Blocking, 6 Additional Config Block, 7 Uninstall Protection, 8 Additional Uninstall Protection, 9 View Weekly Hours, 10–13 Pause, Dialog Tool, Service Mode, Review and Save. Code and docs updated. **2026-02-09:** Configure GUI now shows all current settings in square brackets (e.g. [Check Interval: 10 min], [desktop], [Automatic]); option 12 shows current service mode as [desktop]/[gaming]/[none].
- [x] **ADDED HERE: Fix install.sh not installing lib files?** **Verified fixed** (code inspection 2026-02-07): install.sh copies libs to `~/.local/lib/sleep-warning`; status.sh sets `INSTALLED_LIB_DIR` to that path and passes it first to `init_library_paths`, so `detect_library_dir` / `find_lib_file` find installed libs when running `sleep-warning-status` from PATH.
- [x] **ADDED HERE: When choosing popup size in configure.sh, show percentages for percentage mode and pixel dimensions for fixed.** **Done** (2026-02-07): GUI shows e.g. medium [30%x30%] in percentage mode and medium [800x500] in fixed mode; text mode already showed both. As of 2026-02-09 all current-setting display in the configure GUI uses square brackets (not parentheses). "display-based" renamed to "percentage" in wizard UI and user docs (config value remains `display-based`).
- [x] **ADDED HERE: Do not preserve old comments in prior version of config file when writing a new one.** **Verified implemented** (code inspection 2026-02-07): `write_config()` in lib/configure-config.sh only writes from `_write_config_header` and section writers; no logic reads or re-inserts user comments from the existing file.
- [ ] **ADDED HERE: Fix configure.sh GUI fallback when no usable display** - tighten `has_gui()` detection so configure.sh automatically falls back to text mode when no accessible DISPLAY/Wayland socket exists.
- [x] **When checking if popup min display time > interval, use currently set interval, not one from config file** **Done** (2026-02-08): Wizard uses in-memory check_interval/min_display_time for validate_popup_timing_config; fallback to config file then defaults.
- [x] **ADDED HERE: Uninstall should remove files like warnings log, last uptime, pause state file, etc.** **Verified implemented** (code inspection 2026-02-07): `remove_ancillary_files()` in uninstall.sh removes warnings.log, .pause_state, .last_uptime, and popup PID file; it is always called during uninstall. Config file is only removed if user confirms or uses `--remove-config`. 
- [ ] **#30: Separate Timer Check Interval from Popup Display Frequency** - Hardcode timer to check every 5 minutes, add user-configurable popup display frequency to solve minute precision timing issues
- [ ] **ADDED HERE: Additional hours should not apply on days with no restrictions** - Additional lock hours and uninstall lock hours should not apply on days when there are no restricted times configured. User-configurable option to allow such locking (disabled by default). Warn users when entering additional hours on days with no restrictions. See [plan-additional-hours-no-restrictions.md](plans/plan-additional-hours-no-restrictions.md)
- [ ] **#10: Audio Alerts** 
- [ ] **Licensing** - License selection and application
- [ ] **#13a: Single Executable Installer Script** - Self-extracting installer bundling all files
- [ ] **#13b: Desktop GUI Application Wrapper** - Native desktop application (GTK/Qt/Electron)
- [ ] **ADDED HERE: Check popup, pause dialogs with all three toools** - yad, zenity, kdialog - make sure they work and cannot block script indefinitely
- [ ] **ADDED HERE: test in Desktop Mode without external display** - run all tests on Steam Deck in Desktop mode without an external display connected
- [ ] **#29: kdialog Window Size Control** - Try using `--textbox` with `--geometry` for kdialog popups to enable size control, with fallback to `--sorry` if it doesn't work properly
- [ ] **#27 Donation Links** - ✅ **Phase 1 Partially Implemented** - PayPal donation links added to README.md, GETTING_STARTED.md, and install.sh. **Remaining**: Testing and verification. **Phase 2**: GitHub Sponsors support planned (see [enhancements/enhancement-27-phase-2-github-sponsors.md](enhancements/enhancement-27-phase-2-github-sponsors.md)) - requires license first.
- [x] **ADDED HERE: check end lock hours display, calculation** **Done** (2026-02-08): Verified show_config_locked_error and calculate_restriction_end_time. Fixed display when blocked by lock hours only from previous day's overnight range (end time was missing); added same overnight lock-end calculation for "both" case. Configure/manage blocked message now shows "Lock ends: …" correctly for lock-only and overnight lock.
- [x] **Change message from install to use configured interval** **Already correct** (verified 2026-02-07): install.sh completion message uses `$(get_check_interval)` which reads CHECK_INTERVAL from the config file (new or old path) and defaults to 10 only when no valid value exists.

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
- [ ] **#3: Enhanced Window Size Options and Percentage-Based (Display-Based) Sizing** - ✅ **MOSTLY IMPLEMENTED** - Core functionality complete: resolution detection module, six predefined sizes (xsmall, small, medium, large, xlarge, max), display-based (percentage-based) and fixed modes, percentage-based custom sizing, configuration wizard integration, automated tests passing (53/53). **Remaining**: UI/Dialog Tool Testing (button visibility for all sizes with YAD/Zenity/KDialog), resolution detection testing on Wayland and gamescope environments, multi-monitor setup testing, testing on different display resolutions (1080p, 4K, ultrawide)
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
- [x] **ADDED HERE: make 24/7 prevention and high restriction warnings apply to additional hours, also** - ✅ **COMPLETED** - Validation now includes combined total of restriction hours, config lock hours, and uninstall lock hours. Safety overrides clear additional hours when high restrictions detected. See [plan-extend-24-7-prevention-to-additional-hours.md](plans/plan-extend-24-7-prevention-to-additional-hours.md). **Remaining**: Testing (Phase 5)
- [ ] **ADDED HERE: Additional hours should not apply on days with no restrictions** - Additional lock hours and uninstall lock hours should not apply on days when there are no restricted times configured. User-configurable option to allow such locking (disabled by default). Warn users when entering additional hours on days with no restrictions. See [plan-additional-hours-no-restrictions.md](plans/plan-additional-hours-no-restrictions.md)
- [ ] **ADDED HERE: steam-timer (process killer) as option** - Consider adding steam-timer (process killer) as an optional feature; currently an external script.

## Alternative Approaches

- [ ] **#1: Steam Overlay Integration** - Integrate with Steam Overlay API (best solution for Gaming Mode full-screen games, requires significant development)
- [ ] **#2: Custom Wayland Protocol Implementation** - Custom Wayland protocol for gamescope (very complex, limited benefit)
- [ ] **#3: Native Desktop Application (GUI Wrapper)** - Full desktop application to replace bash scripts (improves UX but not Gaming Mode compatibility)
- [ ] **#4: Systemd Timer Alternative (Cron-based)** - Use cron instead of systemd timers
- [ ] **#6: Executable/Binary Distribution Options** - Various approaches for distributing as executables/binaries where end-users don't have source code access (self-extracting installer, shell compiler, obfuscation, package managers, compiled language rewrite). See [enhancements/alternative-06-executable-binary-distribution.md](enhancements/alternative-06-executable-binary-distribution.md)

## Testing & Validation Work

### Re-test after major updates/before publishing
- [x] **ADDED HERE: Check pause works and popups appear after pause expires** **Done** (2026-02-08): Confirmed popups appear after pause expires. 

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
- [ ] **ADDED HERE: SteamOS locale documentation** - Add info about setting locale on SteamOS and generating locale archive to USER_GUIDE.md and/or GETTING_STARTED.md and/or README.md. **Recommend Nix** as the preferred way to get a persistent locale (and other packages) on SteamOS: explain what Nix is (persistent package manager / fs-overlay; packages live in `/nix/store` and survive system updates; Nix profiles are user environments that keep your selection of packages active), how to install it (official installer and/or Determinate installer with Steam Deck support), how to find and install packages (search.nixos.org, `nix search`, `nix profile install`), and include links (e.g. https://nix.dev/install-nix.html, https://search.nixos.org, https://nix.dev/manual/nix/package-management/profiles, and optionally https://install.determinate.systems/nix for Steam Deck). Also document manual locale steps (disable readonly, locale.gen, locale-gen, re-enable readonly) for users who do not use Nix. **install.sh automation (research 2026-02-08):** Full automation of locale-gen in install.sh on SteamOS is **not recommended**—SteamOS uses a read-only `/usr`, so `locale-gen` (which writes to `/usr/lib/locale/locale-archive`) would require `steamos-readonly disable`; moreover SteamOS often ships with stripped glibc and locale definition files can be missing, so locale-gen may fail until glibc is reinstalled. **Feasible partial automation:** detect SteamOS, check UTF-8 locale availability (e.g. `locale -a`); if none found, show clear instructions and link to user docs; optionally set `Environment=LANG=en_US.UTF-8` (or `C.UTF-8`) in the systemd user service so the timer uses a UTF-8 locale when one exists (no root, no system changes). Do not run `steamos-readonly disable` or `locale-gen` from install.sh.

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

### Research: SteamOS locale automation (2026-02-08)

**Can we automate locale setup and locale archive generation in install.sh for SteamOS?**

- **Full automation (edit `/etc/locale.gen`, run `locale-gen`):** Not recommended. SteamOS root/usr is read-only by default; locale-gen writes to `/usr/lib/locale/`. Running it requires `sudo steamos-readonly disable`, which is invasive and can be reverted by system updates. SteamOS also ships with stripped glibc—locale definition files in `/usr/share/i18n/locales` may be missing, so locale-gen often fails with "cannot open locale definition file" until glibc is reinstalled (e.g. `pacman -S glibc`). Having install.sh run readonly-disable or locale-gen would be risky and out of scope for a user-space app installer.
- **Partial automation (feasible):** (1) Detect SteamOS (e.g. `/etc/os-release`). (2) Check if a UTF-8 locale is available (`locale -a`). (3) If none, print clear instructions and link to user docs (manual steps: disable readonly, edit locale.gen, run locale-gen, re-enable readonly; recommend Nix for persistent/reproducible setup—see Documentation Work item for full Nix spec: what it is, install, find/install packages, links). (4) Optionally set `LANG=en_US.UTF-8` or `LANG=C.UTF-8` in the systemd user service file so that when a UTF-8 locale exists, the timer runs with it; no root or system changes. Scripts already handle missing UTF-8 (ASCII fallback for dialogs).

**Nix recommendation (for SteamOS locale docs):** When writing the user-facing locale section, include a dedicated Nix subsection that: (1) **What it is** — Nix is a persistent package manager / filesystem overlay; packages are stored in `/nix/store` and survive SteamOS updates (unlike pacman); Nix profiles are user environments that keep your chosen packages active (see [Nix profiles](https://nix.dev/manual/nix/package-management/profiles)). (2) **Install** — Official: [Install Nix](https://nix.dev/install-nix.html) (`curl -L https://nixos.org/nix/install | sh`); Steam Deck: [Determinate Nix Installer](https://install.determinate.systems/nix) supports Steam Deck (`curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`). (3) **Find packages** — [search.nixos.org](https://search.nixos.org) (packages and options); CLI: `nix search <name>`. (4) **Install packages** — e.g. `nix profile install nixpkgs#glibcLocales` or profile-based install; link to [Nix manual](https://nix.dev/manual/nix/package-management/basic-package-mgmt) for package management. (5) **Why for SteamOS** — Avoids touching read-only system; locale and other tools persist across OS updates.

---

**Last Updated**: 2026-02-09 (Configure GUI: current settings and service mode shown in square brackets in main menu, grid, and summary; popup size and status strings use [ ]; option 12 shows [desktop]/[gaming]/[none]. Prior: pause work formalized; end lock hours display/calculation verified and fixed for overnight lock.)
**Related Documents**: 
- [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) - Detailed enhancement descriptions
- [linux-warning-system-plan.md](linux-warning-system-plan.md) - Master implementation plan
- [qi-assessments/qi-assessment-2026-01-23-003550.md](qi-assessments/qi-assessment-2026-01-23-003550.md) - Quality improvement assessment
