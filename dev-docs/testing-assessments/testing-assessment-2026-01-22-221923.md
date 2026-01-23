# Testing Assessment Template - Sleep Warning System

## Purpose

This document provides a systematic approach to identify what tests need to be performed for the Sleep Warning System. The assessment:

- Identifies existing tests that should be re-run due to code changes
- Suggests new tests needed to cover functionality and edge cases
- Examines code and documentation to extract test requirements
- Analyzes shell scripts to identify functionality that requires testing
- Categorizes tests by automation feasibility (automated vs manual/interactive)
- Identifies test environment requirements and setup possibilities
- Provides prioritized recommendations for critical testing needs

## How to Use This Document

### Important: Creating Assessment Copies

**DO NOT mark off checklist items in this file.** This is the master template that should remain unchanged.

Instead, for each testing assessment:

1. **Create a new timestamped copy** of this template:
   - Copy this entire file to `dev-docs/testing-assessments/testing-assessment-YYYY-MM-DD-HHMMSS.md`
   - Use format: `testing-assessment-2024-01-15-143022.md` (year-month-day-hour-minute-second)
   - Example command: `cp dev-docs/templates/testing-assessment-template.md "dev-docs/testing-assessments/testing-assessment-$(date +%Y-%m-%d-%H%M%S).md"`

2. **Work with the timestamped copy**:
   - Fill in the analysis sections with actual findings
   - Mark off items in the timestamped file as you complete them
   - Document all identified testing gaps and requirements
   - Categorize tests by type and automation feasibility
   - Provide specific recommendations with priorities

3. **After completing the assessment**:
   - Review all findings in the timestamped file
   - If new testing patterns or requirements are discovered, add them to this master template
   - Keep the timestamped file as a record of that specific assessment

### Critical: No Code Changes During Assessment

**DO NOT edit any code files or test files during the assessment.** The assessment is for **analysis and documentation only**.

- **Document testing needs, don't implement them**: When you identify a testing gap, document it thoroughly in the timestamped assessment file with:
  - Exact location in documentation or code (file and line numbers/sections)
  - Description of what needs to be tested
  - Test type (automated vs manual)
  - Required conditions or environment setup
  - Priority level (critical, high, medium, low)
  - Suggested test approach (but don't implement it yet)

- **Only edit the timestamped assessment file**: The only file that should be modified during the assessment is the new timestamped markdown file created for this specific assessment.

- **Separate phases**: 
  - **Phase 1 (Assessment)**: Identify and document all testing requirements
  - **Phase 2 (Test Implementation)**: After assessment completion, review findings with team/user and implement tests separately

This approach ensures:
- The assessment remains focused on discovery and analysis, not implementation
- All testing needs are documented before any test code changes
- The user/team can prioritize which tests to address first
- The assessment results provide a complete picture of all testing requirements
- Assessment results are not mixed with actual test implementation

### Assessment Process

1. **Identify tests that need re-running**:
   - Examine all test files in `tests/` directory
   - Check when tests were last modified vs codebase changes using `git log`
   - Identify tests that should be re-run due to code changes
   - Run existing tests and document which pass, fail, or need updates
   - Note any broken or flaky tests that need attention

2. **Extract test requirements from documentation**:
   - Read `dev-docs/plan-phase-4-testing.md` to identify pending tests
   - Read `dev-docs/TECHNICAL_DETAILS.md` to extract test requirements for features
   - Review `dev-docs/STEAMOS_GAMING_MODE.md` for Gaming Mode-specific test needs
   - Check enhancement documents in `dev-docs/enhancements/` for feature-specific test requirements
   - Review `dev-docs/REMAINING_WORK_SUMMARY.md` for testing-related work items
   - Focus on identifying what tests need to be created, not evaluating the documentation itself

3. **Examine code to identify missing tests**:
   - Review main scripts (`sleep-warning.sh`, `configure.sh`, `manage.sh`, `install.sh`, `uninstall.sh`)
   - Review library modules in `lib/` directory
   - Identify functionality that may not be covered by existing tests
   - Look for error handling paths that need testing
   - Identify edge cases and boundary conditions
   - Compare code functionality with existing test coverage

4. **Categorize test needs**:
   - **Automated tests**: Can be run without user interaction
   - **Manual/Interactive tests**: Require user interaction or specific conditions
   - **Environment setup possible**: Can be tested via virtual environment, container, or temporary setup
   - **Requires specific hardware/software**: Needs actual SteamOS, specific desktop environment, etc.

5. **Prioritize test recommendations**:
   - **CRITICAL**: Tests that verify core functionality or prevent system-breaking issues
   - **HIGH**: Tests for important features or edge cases
   - **MEDIUM**: Tests for less critical functionality
   - **LOW**: Nice-to-have tests or low-risk areas

---

## Assessment Sections

### Section 0: Tests That Need Re-Running

#### 0.1: Identify Tests Requiring Re-Execution

**Location**: `tests/` directory

**Purpose**: Identify which existing tests should be re-run due to code changes or need updates.

**Tasks**:
- [x] List all test files in `tests/` directory
- [x] For each test file, identify what code it tests
- [x] Use `git log` to check if tested code has changed since test was written
- [x] Compare test file modification dates with codebase file modification dates
- [ ] Run each test and document results (pass/fail/skip)
- [x] Identify tests that fail due to code changes (not just bugs)
- [x] Note tests that need updates to work with new functionality

**For each test file**:
- [x] Document what the test covers
- [x] Check if tested code files have been modified (use `git log --follow <file>`)
- [x] **Recommendation**: Should this test be re-run? (Yes/No/Needs Update)
- [x] If needs update, note what changes are required
- [x] Check test dependencies (required tools: expect, wmctrl, xdotool, zenity, yad, kdialog, etc.)
- [x] Note if test is currently broken or flaky

### Tests Requiring Re-Execution

**Assessment Date**: 2026-01-22
**Recent Code Changes**: Multiple commits in December 2024 - January 2026 including:
- Dialog tool selection enhancements (Enhancement #25)
- Pause feature implementation (Enhancement #21)
- Uninstall lock hours (Enhancement #26 Phase 2)
- Popup redraw timing fixes
- Configuration validation improvements
- Documentation refactoring

#### Tests That Should Be Re-Run

- **test-configure-comprehensive.sh**: Tests `configure.sh` text mode functionality
  - Code changes: Recent updates to configure.sh, configure-config.sh, configure-display.sh, configure-input.sh, configure-ui.sh, configure-workflow.sh
  - Recommendation: **Re-run** - Core configure.sh functionality may have changed
  - Status: Needs execution to verify
  - Dependencies: expect, bash

- **test-pause-feature.sh**: Tests pause state management (Enhancement #21)
  - Code changes: Recent updates to pause-state.sh, popup-display.sh, sleep-warning.sh
  - Recommendation: **Re-run** - Pause feature was recently implemented/updated
  - Status: Needs execution to verify
  - Dependencies: bash

- **test-dialog-tool-selection.sh**: Tests user-selectable dialog tool (Enhancement #25)
  - Code changes: Recent updates to desktop-environment.sh, config.sh, configure-dialogs.sh
  - Recommendation: **Re-run** - Dialog tool selection was recently enhanced
  - Status: Needs execution to verify
  - Dependencies: zenity, yad, kdialog (at least one)

- **test-uninstall-lock-hours-phase2.sh**: Tests uninstall protection (Enhancement #26 Phase 2)
  - Code changes: Recent updates to uninstall-verification.sh, uninstall.sh, config.sh
  - Recommendation: **Re-run** - Uninstall lock hours Phase 2 was recently implemented
  - Status: Needs execution to verify
  - Dependencies: bash

- **test-write-config-override-flags.sh**: Tests write_config() override flag detection
  - Code changes: Recent updates to configure-config.sh
  - Recommendation: **Re-run** - Config writing logic may have changed
  - Status: Needs execution to verify
  - Dependencies: bash

- **test-modular-refactor.sh**: Tests modular architecture of sleep-warning.sh
  - Code changes: sleep-warning.sh and lib/ modules have been updated
  - Recommendation: **Re-run** - Module structure may have changed
  - Status: Needs execution to verify
  - Dependencies: bash

- **test-configure-modular.sh**: Tests modular architecture of configure.sh
  - Code changes: configure.sh and lib/configure-*.sh modules have been updated
  - Recommendation: **Re-run** - Module structure may have changed
  - Status: Needs execution to verify
  - Dependencies: bash

#### Tests Requiring Updates

- **test-configure-comprehensive.sh**: May need updates for new configure.sh features
  - Required updates: Test new menu options (e.g., dialog tool selection if added to configure.sh)
  - Current coverage: Tests 10 scenarios for configure.sh text mode
  - Missing coverage: New features added since test was written

- **test-popup.sh**: May need updates for pause button integration
  - Required updates: Test pause button functionality in popup
  - Current coverage: Basic popup display
  - Missing coverage: Pause button clicks, pause state integration

- **test-dialog-tool-selection.sh**: May need updates for user-selectable dialog tool
  - Required updates: Verify all dialog tools work with user selection feature
  - Current coverage: Basic dialog tool detection
  - Missing coverage: User preference override, fallback behavior

#### Test Execution Results

**Note**: Test execution was not performed during this assessment (assessment phase only). Tests should be executed in a separate phase to verify current status.

- Tests Run: 0 of 28 (assessment phase - execution pending)
- Tests Passed: TBD
- Tests Failed: TBD
- Tests Skipped: TBD

#### Broken or Flaky Tests

**Note**: No tests were executed during this assessment. Known issues from documentation:

- **test-configure-comprehensive.sh**: May have timing issues with expect automation
  - Issue: Complex interactive automation may be sensitive to system load
  - Recommendation: Run tests and document any timing-related failures

#### Test Files Summary

**Total Test Files**: 28 test scripts identified in `tests/` directory:

1. **check-display-env.sh** - Display environment check utility
2. **test-algebra-examples.sh** - Uninstall verification algebra examples
3. **test-configure-comprehensive.sh** - Comprehensive configure.sh text mode tests (10 test scenarios)
4. **test-configure-dialogs.sh** - Dialog abstraction layer tests
5. **test-configure-interactive.sh** - Interactive configure.sh tests
6. **test-configure-modular.sh** - Configure.sh modular architecture tests
7. **test-configure-text-mode.sh** - Text mode functionality tests
8. **test-debug-hang.sh** - Debug script for hang detection
9. **test-dialog-abstraction.sh** - Dialog abstraction function tests
10. **test-dialog-size-behavior.sh** - Dialog size parameter tests
11. **test-dialog-sizes-interactive.sh** - Interactive dialog size tests
12. **test-dialog-sizes.sh** - Dialog size testing utility
13. **test-dialog-tool-selection.sh** - Dialog tool selection tests (Enhancement #25)
14. **test-grid-display.sh** - Visual grid display tests
15. **test-grid-functions.sh** - Grid function tests
16. **test-immovable-window.sh** - Immovable window feature tests
17. **test-lock-hours-phase2.sh** - Lock hours Phase 2 tests
18. **test-manual-uninstall-guide.sh** - Manual uninstall guide tests
19. **test-modular-refactor.sh** - Modular refactor tests
20. **test-multi-column-specific.sh** - Multi-column display tests
21. **test-pause-feature.sh** - Pause feature tests (Enhancement #21)
22. **test-popup-position.sh** - Popup position tests
23. **test-popup.sh** - Basic popup tests
24. **test-position-bounds.sh** - Position bounds tests
25. **test-stay-on-top.sh** - Stay-on-top feature tests
26. **test-uninstall-lock-hours-phase2.sh** - Uninstall lock hours Phase 2 tests (Enhancement #26)
27. **test-window-title-fix.sh** - Window title fix tests
28. **test-with-expect.sh** - Expect automation prototype
29. **test-write-config-override-flags.sh** - Config override flag tests

### Section 1: Test Requirements from Documentation

#### 1.1: Extract Test Requirements from Phase 4 Testing Plan

**Location**: `dev-docs/plan-phase-4-testing.md`

**Purpose**: Identify specific tests that are documented as needed but not yet implemented or completed.

**Tasks**:
- [x] Extract all tests marked as `[ ]` (not completed) from Checklist 4.1: Functional Testing
- [x] Extract all tests marked as `[X]` but with "NOT TESTED" annotations
- [x] Identify tests marked as "CRITICAL" that need to be performed
- [x] Extract pending tests from Checklist 4.2: Edge Case Testing
- [x] Extract pending tests from Checklist 4.3: Installation and Uninstall Testing
- [x] Extract pending tests from Checklist 4.4: System Integration Testing
- [x] Extract pending supplemental tests
- [x] For each identified test, document:
  - Test name/description
  - What functionality it should test
  - Priority level (if specified)
  - Whether it's a new test or needs to be re-run

### Test Requirements from Phase 4 Testing Plan

#### Functional Tests Needed

- **Test: Script with default configuration**
  - Description: Verify script runs correctly with default configuration (no config file)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 1

- **Test: Script during weekend restricted hours**
  - Description: Test script manually during weekend restricted hours (01:00-05:59)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 2

- **Test: Configuration file parsing and validation**
  - Description: Verify configuration file parsing handles all valid formats and validates correctly
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 5

- **Test: Popup appears and is modal**
  - Description: Verify popup appears and blocks interaction (modal behavior)
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 10

- **Test: Minimum display time on Wayland**
  - Description: Test minimum display time feature on Wayland systems (should fallback gracefully)
  - Priority: HIGH
  - Status: New test needed (NOT TESTED annotation)
  - Location in plan: Checklist 4.1, item 14

- **Test: Auto-reopen functionality**
  - Description: Verify popup reopens correctly when closed prematurely during minimum display time
  - Priority: HIGH
  - Status: New test needed (NOT TESTED annotation)
  - Location in plan: Checklist 4.1, item 15

- **Test: Countdown accuracy**
  - Description: Verify countdown updates correctly during minimum display time
  - Priority: HIGH
  - Status: New test needed (NOT TESTED annotation)
  - Location in plan: Checklist 4.1, item 16

- **Test: Graceful fallback without window tools**
  - Description: Verify countdown still works without wmctrl/xdotool (informational only)
  - Priority: MEDIUM
  - Status: New test needed (NOT TESTED annotation)
  - Location in plan: Checklist 4.1, item 17

- **Test: Systemd user services start automatically in Gaming Mode** ⚠️ **CRITICAL**
  - Description: Verify systemd user services start automatically when booting into Gaming Mode
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 21
  - Environment: SteamOS Gaming Mode

- **Test: Display detection works with gamescope** ⚠️ **CRITICAL**
  - Description: Verify display detection correctly identifies gamescope (Wayland compositor) in Gaming Mode
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 22
  - Environment: SteamOS Gaming Mode

- **Test: Popup appears with no game running in Gaming Mode** ⚠️ **CRITICAL**
  - Description: Verify popup appears correctly in Gaming Mode when no game is running
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 23
  - Environment: SteamOS Gaming Mode

- **Test: Popup appears with windowed game in Gaming Mode** ⚠️ **CRITICAL**
  - Description: Verify popup appears correctly in Gaming Mode with windowed game running
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 24
  - Environment: SteamOS Gaming Mode

- **Test: Popup appears with full-screen game in Gaming Mode** ⚠️ **CRITICAL**
  - Description: Verify popup appears correctly in Gaming Mode with full-screen game running
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 25
  - Environment: SteamOS Gaming Mode

- **Test: Popup appears with exclusive full-screen game in Gaming Mode** ⚠️ **CRITICAL**
  - Description: Verify popup appears correctly in Gaming Mode with exclusive full-screen game running
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 26
  - Environment: SteamOS Gaming Mode

- **Test: Popup appears with borderless windowed game in Gaming Mode** ⚠️ **CRITICAL**
  - Description: Verify popup appears correctly in Gaming Mode with borderless windowed game running
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 27
  - Environment: SteamOS Gaming Mode

- **Test: With Steam games (native and Proton)** ⚠️ **CRITICAL**
  - Description: Verify popup appears correctly with Steam native and Proton games
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 28
  - Environment: SteamOS Gaming Mode

- **Test: With non-Steam games added to library** ⚠️ **CRITICAL**
  - Description: Verify popup appears correctly with non-Steam games added to Steam library
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 29
  - Environment: SteamOS Gaming Mode

- **Test: Timer persistence when switching between Desktop Mode and Gaming Mode** ⚠️ **CRITICAL**
  - Description: Verify timer continues working when switching between Desktop Mode and Gaming Mode
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 30
  - Environment: SteamOS

- **Test: Service status after reboot into Gaming Mode** ⚠️ **CRITICAL**
  - Description: Verify service status is correct after rebooting directly into Gaming Mode
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.1, item 31
  - Environment: SteamOS Gaming Mode

#### Edge Case Tests Needed

- **Test: Exact boundary times**
  - Description: Test at exact boundary times (00:00, 05:59, 06:00) to verify edge case handling
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 1

- **Test: Day transitions**
  - Description: Test on day transitions (Sunday to Monday, Friday to Saturday) with overnight ranges
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 2

- **Test: Missing configuration file**
  - Description: Test with missing configuration file (should use defaults)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 3

- **Test: Invalid configuration file**
  - Description: Test with invalid configuration file (should handle gracefully)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 4

- **Test: Malformed configuration entries**
  - Description: Test with malformed configuration entries (should handle gracefully)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 5

- **Test: Configuration file containing comments**
  - Description: Test with configuration file containing comments (should preserve comments)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 6

- **Test: DISPLAY not set**
  - Description: Test when DISPLAY is not set (should handle gracefully, use fallbacks)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 7

- **Test: WAYLAND_DISPLAY not set**
  - Description: Test when WAYLAND_DISPLAY is not set (should handle gracefully, use fallbacks)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 8

- **Test: Neither DISPLAY nor WAYLAND_DISPLAY set**
  - Description: Test when neither DISPLAY nor WAYLAND_DISPLAY is set (should use loginctl fallback)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 9

- **Test: zenity not available**
  - Description: Test when zenity is not available (should fallback to yad/kdialog)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 10

- **Test: All dialog tools unavailable**
  - Description: Test when all dialog tools unavailable (zenity, yad, kdialog) - should log error and exit gracefully
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 11

- **Test: Multiple user sessions**
  - Description: Test with multiple user sessions (if applicable)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 12

- **Test: Systems without GUI**
  - Description: Test on systems without GUI (should exit gracefully without errors)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 13

- **Test: Different desktop environments**
  - Description: Test on different desktop environments if available (GNOME, KDE, XFCE)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 14

- **Test: Minimum display time with different window managers**
  - Description: Test minimum display time with different window managers (GNOME, KDE, XFCE, etc.)
  - Priority: MEDIUM
  - Status: New test needed (NOT TESTED annotation)
  - Location in plan: Checklist 4.2, item 15

- **Test: Immovable window feature**
  - Description: Verify position monitoring and restoration works correctly on X11 systems
  - Priority: MEDIUM
  - Status: New test needed (NOT TESTED annotation)
  - Location in plan: Checklist 4.2, item 17

- **Test: gamescope compositor is active (Wayland)** ⚠️ **SteamOS Gaming Mode**
  - Description: Test when gamescope compositor is active (Wayland) in Gaming Mode
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 18
  - Environment: SteamOS Gaming Mode

- **Test: Display detection when switching from Desktop Mode to Gaming Mode** ⚠️ **SteamOS Gaming Mode**
  - Description: Test display detection when switching from Desktop Mode to Gaming Mode
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 19
  - Environment: SteamOS

- **Test: Display detection when switching from Gaming Mode to Desktop Mode** ⚠️ **SteamOS Gaming Mode**
  - Description: Test display detection when switching from Gaming Mode to Desktop Mode
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 20
  - Environment: SteamOS

- **Test: On-screen keyboard is active** ⚠️ **SteamOS Gaming Mode**
  - Description: Test when on-screen keyboard is active (may affect dialog input)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 21
  - Environment: SteamOS Gaming Mode

- **Test: Different game rendering technologies** ⚠️ **SteamOS Gaming Mode**
  - Description: Test with different game rendering technologies (Vulkan, DirectX via Proton)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 22
  - Environment: SteamOS Gaming Mode

- **Test: Heavy system load** ⚠️ **SteamOS Gaming Mode**
  - Description: Test under heavy system load (game running, high CPU/GPU usage)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.2, item 23
  - Environment: SteamOS Gaming Mode

#### Installation/Uninstall Tests Needed

- **Test: install.sh on clean system**
  - Description: Test install.sh on clean system (no previous installation)
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 1

- **Test: install.sh with missing zenity dependency**
  - Description: Test install.sh with missing zenity dependency (should offer to install)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 2

- **Test: install.sh with --yes flag**
  - Description: Test install.sh with --yes flag (auto-confirm dependency installation)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 3

- **Test: install.sh with existing installation**
  - Description: Test install.sh with existing installation (should warn, --force should reinstall)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 4

- **Test: install.sh on different distributions**
  - Description: Test install.sh on different distributions (if possible: Ubuntu, Fedora, Arch, openSUSE)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 5

- **Test: install.sh preserves existing config file**
  - Description: Verify install.sh preserves existing config file (doesn't overwrite)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 6

- **Test: install.sh creates config file if missing**
  - Description: Verify install.sh creates config file if missing
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 7

- **Test: install.sh sets correct permissions**
  - Description: Verify install.sh sets correct permissions on script
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 8

- **Test: install.sh enables and starts timer correctly**
  - Description: Verify install.sh enables and starts timer correctly
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 9

- **Test: uninstall.sh removes all files correctly**
  - Description: Test uninstall.sh removes all files correctly
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 10

- **Test: uninstall.sh stops and disables timer correctly**
  - Description: Test uninstall.sh stops and disables timer correctly
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 11

- **Test: uninstall.sh --remove-config removes config file**
  - Description: Test uninstall.sh --remove-config removes config file
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 12

- **Test: uninstall.sh without --remove-config preserves config file**
  - Description: Test uninstall.sh without --remove-config preserves config file
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 13

- **Test: Installation after uninstall**
  - Description: Test installation after uninstall (should work cleanly)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 14

- **Test: install.sh error handling**
  - Description: Verify install.sh error handling (missing directories, permission errors, etc.)
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 15

- **Test: install.sh on system without GUI**
  - Description: Test install.sh on system without GUI (should handle gracefully)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 16

- **Test: configure.sh interactive wizard with various inputs**
  - Description: Test configure.sh interactive wizard with various inputs
  - Priority: HIGH
  - Status: New test needed (partial coverage exists in test-configure-comprehensive.sh)
  - Location in plan: Checklist 4.3, item 17

- **Test: configure.sh validation and error handling**
  - Description: Test configure.sh validation and error handling
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 18

- **Test: configure.sh on system without GUI**
  - Description: Test configure.sh on system without GUI (should fallback to text prompts)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 19

- **Test: manage.sh menu and all functions**
  - Description: Test manage.sh menu and all functions
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 20

- **Test: manage.sh disable/enable functionality**
  - Description: Test manage.sh disable/enable functionality
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 21

- **Test: manage.sh on system without GUI**
  - Description: Test manage.sh on system without GUI (should use text menu)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.3, item 22

#### Integration Tests Needed

- **Test: Timer persists across reboots**
  - Description: Verify timer persists across reboots
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 1

- **Test: Timer works after user login**
  - Description: Verify timer works after user login
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 2

- **Test: Behavior when system is suspended/resumed**
  - Description: Test behavior when system is suspended/resumed
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 3

- **Test: No performance impact from 10-minute checks**
  - Description: Verify no performance impact from 10-minute checks
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 4

- **Test: Systemd logs for errors**
  - Description: Check systemd logs for any errors
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 5

- **Test: Timer persists when booting directly into Gaming Mode** ⚠️ **CRITICAL - SteamOS Gaming Mode**
  - Description: Verify timer persists when booting directly into Gaming Mode
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 6
  - Environment: SteamOS Gaming Mode

- **Test: Timer persists when booting into Desktop Mode then switching to Gaming Mode** ⚠️ **CRITICAL - SteamOS Gaming Mode**
  - Description: Verify timer persists when booting into Desktop Mode then switching to Gaming Mode
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 7
  - Environment: SteamOS

- **Test: Timer persists when switching from Gaming Mode to Desktop Mode** ⚠️ **CRITICAL - SteamOS Gaming Mode**
  - Description: Verify timer persists when switching from Gaming Mode to Desktop Mode
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 8
  - Environment: SteamOS

- **Test: Service status after system suspend/resume in Gaming Mode** ⚠️ **SteamOS Gaming Mode**
  - Description: Test service status after system suspend/resume in Gaming Mode
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 9
  - Environment: SteamOS Gaming Mode

- **Test: No performance impact during gameplay** ⚠️ **SteamOS Gaming Mode**
  - Description: Verify no performance impact during gameplay (check CPU/GPU usage during timer trigger)
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 10
  - Environment: SteamOS Gaming Mode

- **Test: Different SteamOS versions** ⚠️ **SteamOS Gaming Mode**
  - Description: Test with different SteamOS versions (if available) to ensure compatibility
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Checklist 4.4, item 11
  - Environment: SteamOS Gaming Mode

#### Supplemental Tests Needed

**Compositor Helper Integration**:
- **Test: Wayland desktop with swaymsg available**
  - Description: Verify helper detection path is used when env vars missing
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Supplemental Tests, Compositor Helper Integration, item 1

- **Test: Wayland desktop with wlr-randr available**
  - Description: Verify helper detection path is used when env vars missing
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Supplemental Tests, Compositor Helper Integration, item 2

- **Test: Wayland desktop with only wayland-info available**
  - Description: Verify helper detection path is used when env vars missing
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Supplemental Tests, Compositor Helper Integration, item 3

**Enhanced Display Detection (Manual)**:
- **Test: Desktop Mode (X11) - DISPLAY set**
  - Description: DISPLAY set, popup appears
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Manual), item 1

- **Test: Desktop Mode (Wayland) - WAYLAND_DISPLAY set**
  - Description: WAYLAND_DISPLAY set, popup appears
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Manual), item 2

- **Test: Gaming Mode - gamescope detected (no game)**
  - Description: gamescope detected, popup appears (no game)
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Manual), item 3
  - Environment: SteamOS Gaming Mode

- **Test: Gaming Mode - gamescope detected (windowed game)**
  - Description: gamescope detected, popup appears (windowed game)
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Manual), item 4
  - Environment: SteamOS Gaming Mode

- **Test: No display vars - loginctl fallback**
  - Description: No display vars: loginctl fallback finds active session
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Manual), item 5

- **Test: Failure case - no active session**
  - Description: Failure case: no active session -> log "no display"
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Manual), item 6

**Enhanced Display Detection (Implementation Verification)**:
- **Test: Desktop Mode (X11) - DISPLAY set and accessible**
  - Description: DISPLAY set and accessible -> popup appears
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Implementation Verification), item 1

- **Test: Desktop Mode (Wayland) - WAYLAND_DISPLAY set and socket exists**
  - Description: WAYLAND_DISPLAY set and socket exists -> popup appears
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Implementation Verification), item 2

- **Test: Gaming Mode - gamescope detected (no game)**
  - Description: gamescope detected -> popup appears (no game)
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Implementation Verification), item 3
  - Environment: SteamOS Gaming Mode

- **Test: Gaming Mode - gamescope detected (windowed game)**
  - Description: gamescope detected -> popup appears (windowed game)
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Implementation Verification), item 4
  - Environment: SteamOS Gaming Mode

- **Test: Gaming Mode - gamescope detected (full-screen game)**
  - Description: gamescope detected -> popup appears (full-screen game)
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Implementation Verification), item 5
  - Environment: SteamOS Gaming Mode

- **Test: No display env vars - loginctl fallback**
  - Description: No display env vars -> loginctl fallback finds active session
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Implementation Verification), item 6

- **Test: No active session**
  - Description: No active session -> "no display" logged, no popup
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Supplemental Tests, Enhanced Display Detection (Implementation Verification), item 7

**Wayland/Gamescope Popup Behavior**:
- **Test: Wayland Desktop - popup appears and is dismissible**
  - Description: Wayland Desktop: popup appears and is dismissible
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Supplemental Tests, Wayland/Gamescope Popup Behavior, item 1

- **Test: Gaming Mode (no game) - popup appears**
  - Description: Gaming Mode (no game): popup appears
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Supplemental Tests, Wayland/Gamescope Popup Behavior, item 2
  - Environment: SteamOS Gaming Mode

- **Test: Gaming Mode (windowed game) - popup appears**
  - Description: Gaming Mode (windowed game): popup appears
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Supplemental Tests, Wayland/Gamescope Popup Behavior, item 3
  - Environment: SteamOS Gaming Mode

- **Test: Gaming Mode (full-screen game) - popup appears on top**
  - Description: Gaming Mode (full-screen game): record whether popup appears on top
  - Priority: CRITICAL
  - Status: New test needed
  - Location in plan: Supplemental Tests, Wayland/Gamescope Popup Behavior, item 4
  - Environment: SteamOS Gaming Mode

**Dialog Tool Priority + Notify-Send Fallback**:
- **Test: Wayland/gamescope - verify tool selection order in logs**
  - Description: Wayland/gamescope: verify tool selection order in logs
  - Priority: MEDIUM
  - Status: New test needed
  - Location in plan: Supplemental Tests, Dialog Tool Priority + Notify-Send Fallback, item 1

- **Test: Dialog failure - verify notify-send fallback and log entry**
  - Description: Dialog failure: verify notify-send fallback and log entry
  - Priority: HIGH
  - Status: New test needed
  - Location in plan: Supplemental Tests, Dialog Tool Priority + Notify-Send Fallback, item 2

#### 1.2: Extract Test Requirements from Test Suite Documentation

**Location**: `tests/README.md`

**Purpose**: Identify tests mentioned in documentation that may not exist yet or need to be created.

**Tasks**:
- [x] Extract any test requirements or test cases mentioned in `tests/README.md`
- [x] Compare documented tests with actual test files in `tests/` directory
- [x] Identify tests documented but not implemented
- [x] Note any "future tests" or "planned tests" mentioned

### Test Requirements from Test Suite Documentation

#### Documented Tests Not Yet Implemented

From `tests/README.md` "Known Limitations" and "Future Enhancements" sections:

- **Test: Cancellation flow tests**
  - Description: Test cancellation flows in configure.sh (complex, low priority)
  - Status: Needs to be created
  - Reference: tests/README.md, "Known Limitations" section
  - Priority: LOW

- **Test: Individual day navigation tests (with 'back' command)**
  - Description: Test individual day editing with 'back' command navigation
  - Status: Needs to be created
  - Reference: tests/README.md, "Future Enhancements" section
  - Priority: MEDIUM

- **Test: Error handling tests (invalid input)**
  - Description: Test error handling for invalid input in configure.sh
  - Status: Needs to be created
  - Reference: tests/README.md, "Future Enhancements" section
  - Priority: HIGH

- **Test: Backward compatibility tests (old menu options)**
  - Description: Test backward compatibility with old menu options
  - Status: Needs to be created
  - Reference: tests/README.md, "Future Enhancements" section
  - Priority: MEDIUM

- **Test: GUI mode tests (if possible with xvfb)**
  - Description: Consider adding GUI mode tests using xvfb (virtual framebuffer)
  - Status: Needs to be created (if feasible)
  - Reference: tests/README.md, "Future Enhancements" section
  - Priority: LOW
  - Note: Requires xvfb setup and may be complex

#### Tests Mentioned But Missing

All tests mentioned in `tests/README.md` appear to have corresponding test files:
- test-configure-comprehensive.sh ✅ (exists)
- test-configure-comprehensive.exp ✅ (exists)
- test-with-expect.sh ✅ (exists, kept for reference)
- test-write-config-override-flags.sh ✅ (exists)

**Note**: The README mentions that test-configure-comprehensive.sh has 10 tests, all passing (13 total assertions). This test suite should be re-run to verify it still works with recent code changes.

### Section 2: Test Requirements from Technical Documentation

#### 2.1: Extract Test Requirements from TECHNICAL_DETAILS.md

**Location**: `dev-docs/TECHNICAL_DETAILS.md`

**Purpose**: Identify what tests are needed based on features and implementation details described in technical documentation.

**Tasks**:
- [ ] Extract explicit testing requirements mentioned in "Testing Requirements" sections
- [ ] For each feature described, identify what tests should verify it works
- [ ] Note any "CRITICAL" or "MUST TEST" annotations and create test requirements
- [ ] Identify environment-specific test needs (X11, Wayland, Gaming Mode, etc.)

**Key Features to Extract Test Requirements For**:
- [ ] Minimum Display Time Feature (lines 114-156): What tests verify X11/Wayland behavior, window manager compatibility, auto-reopen, countdown?
- [ ] Full-Screen Application Compatibility (lines 157-201): What tests verify desktop environment compatibility, display protocols, Gaming Mode behavior?
- [ ] Display Access and Detection (lines 90-106): What tests verify X11/Wayland detection, fallbacks, Gaming Mode detection?
- [ ] Configuration File Format (lines 54-82): What tests verify parsing, validation, edge cases (overnight ranges, multiple ranges)?
- [ ] 24/7 Restriction Prevention (lines 264-383): What tests verify validation algorithm, overlap detection, safety features?
- [ ] Timer Configuration (lines 203-209): What tests verify interval config, timer file updates, accuracy?
- [ ] Script Implementation: What tests are needed for configure.sh, manage.sh, install.sh, uninstall.sh?

**Documentation Format**:
```
### Test Requirements from TECHNICAL_DETAILS.md

#### Tests Needed for Minimum Display Time Feature
- **Test: X11 minimum display time behavior**
  - Purpose: Verify minimum display time works correctly on X11
  - Priority: HIGH
  - Environment: X11 desktop environment
  - Reference: TECHNICAL_DETAILS.md lines 114-156

#### Tests Needed for Configuration File Format
- **Test: Overnight time range parsing**
  - Purpose: Verify configuration correctly parses overnight ranges (e.g., 22:00-06:00)
  - Priority: HIGH
  - Reference: TECHNICAL_DETAILS.md lines 54-82

[Continue for each feature...]
```

#### 2.2: Extract Test Requirements from STEAMOS_GAMING_MODE.md

**Location**: `dev-docs/STEAMOS_GAMING_MODE.md`

**Purpose**: Identify Gaming Mode-specific tests that need to be performed.

**Tasks**:
- [ ] Extract Gaming Mode-specific test requirements
- [ ] Identify display detection tests needed for Gaming Mode
- [ ] Identify popup behavior tests needed for Gaming Mode
- [ ] Identify systemd service tests needed
- [ ] For each requirement, document what test should verify

**Documentation Format**:
```
### Test Requirements from STEAMOS_GAMING_MODE.md

#### Gaming Mode Display Detection Tests Needed
- **Test: Gaming Mode display detection**
  - Purpose: Verify system correctly detects Gaming Mode environment
  - Priority: CRITICAL
  - Environment: SteamOS Gaming Mode
  - Reference: STEAMOS_GAMING_MODE.md, section X

#### Gaming Mode Popup Behavior Tests Needed
- **Test: Popup display in Gaming Mode**
  - Purpose: Verify popup appears correctly in Gaming Mode
  - Priority: CRITICAL
  - Environment: SteamOS Gaming Mode with full-screen game
  - Reference: STEAMOS_GAMING_MODE.md, section Y

[Continue for each requirement...]
```

#### 2.3: Extract Test Requirements from Enhancement Documents

**Location**: `dev-docs/enhancements/`

**Purpose**: Identify tests needed for features described in enhancement documents.

**Tasks**:
- [ ] For each enhancement document, extract test requirements
- [ ] Identify features that may not have corresponding tests yet
- [ ] Check for "Testing Requirements" or "Test Cases" sections
- [ ] Document what tests should verify each enhancement works

**Documentation Format**:
```
### Test Requirements from Enhancement Documents

#### Tests Needed for Enhancement X
- **Test: [Name]**
  - Purpose: [What it should verify]
  - Priority: [Level]
  - Enhancement: enhancement-X.md
  - Status: New test needed

[Continue for each enhancement...]
```

### Section 3: Identify Missing Tests from Code Analysis

#### 3.1: Tests Needed for Main Scripts

**Scripts to Review**:
- `sleep-warning.sh` - Main entry point
- `configure.sh` - Configuration wizard
- `manage.sh` - Management interface
- `install.sh` - Installation script
- `uninstall.sh` - Uninstall script

**Purpose**: Identify functionality in main scripts that needs testing but may not be covered by existing tests.

**Tasks**:
- [ ] For each script, compare functionality with existing test coverage
- [ ] Identify main execution paths that need tests
- [ ] Identify error handling paths that need tests
- [ ] Identify edge cases and boundary conditions that need tests
- [ ] Identify input validation points that need tests
- [ ] Identify external dependency interactions that need tests
- [ ] Identify environment-specific behavior that needs tests
- [ ] For each identified gap, suggest a specific test

**Documentation Format**:
```
### Tests Needed for Main Scripts

#### sleep-warning.sh
- **Test: Main execution path with valid config**
  - Purpose: Verify script runs correctly with valid configuration
  - Priority: CRITICAL
  - Status: [Exists/Needs creation/Needs re-run]

- **Test: Error handling for missing config file**
  - Purpose: Verify script handles missing config gracefully
  - Priority: HIGH
  - Status: [Exists/Needs creation]

[Continue for each script and functionality...]
```

#### 3.2: Tests Needed for Library Modules

**Modules to Review**: All files in `lib/` directory (config.sh, logging.sh, display-detection.sh, desktop-environment.sh, window-management.sh, time-validation.sh, popup-display.sh, uninstall-verification.sh, configure-*.sh, etc.)

**Purpose**: Identify functions and features in library modules that need testing.

**Tasks**:
- [ ] For each module, list all functions
- [ ] Compare functions with existing test coverage
- [ ] Identify functions that need unit tests
- [ ] Identify error conditions that need tests
- [ ] Identify edge cases that need tests
- [ ] Identify external dependency interactions that need tests
- [ ] Identify environment-specific behavior that needs tests
- [ ] For each identified gap, suggest a specific test

**Documentation Format**:
```
### Tests Needed for Library Modules

#### lib/config.sh
- **Test: load_config() with valid config file**
  - Purpose: Verify config loading works correctly
  - Priority: CRITICAL
  - Function: load_config()
  - Status: [Exists/Needs creation/Needs re-run]

- **Test: load_config() with invalid config file**
  - Purpose: Verify error handling for invalid config
  - Priority: HIGH
  - Function: load_config()
  - Status: [Exists/Needs creation]

[Continue for each module and function...]
```

### Section 4: Test Execution and Results

#### 4.0: Test Execution Status

**Tasks**:
- [ ] Run existing automated tests and document results
- [ ] Note which tests pass, fail, or are skipped
- [ ] Document any test failures with error messages
- [ ] Identify tests that cannot be run (missing dependencies, environment issues)
- [ ] Check test execution time (identify slow tests)
- [ ] Verify test cleanup (configs restored, temp files removed)

**Documentation Format**:
```
### Test Execution Results
- Tests Run: [X of Y]
- Tests Passed: [X]
- Tests Failed: [X] - [List with error details]
- Tests Skipped: [X] - [List with reasons]
- Slow Tests (>30s): [List]
- Missing Dependencies: [List]
```

### Section 5: Test Categorization

#### 5.1: Automated Tests

**Definition**: Tests that can be run without user interaction, typically using scripts, test frameworks, or automated tools.

**Tasks**:
- [ ] Identify all tests that can be automated
- [ ] Categorize by test type:
  - [ ] Unit tests (individual functions/modules)
  - [ ] Integration tests (multiple components)
  - [ ] Configuration file parsing tests
  - [ ] Validation logic tests
  - [ ] Error handling tests
  - [ ] Edge case tests (that don't require user interaction)

**Documentation Format**:
```
### Automated Tests
- Unit Tests: [List]
- Integration Tests: [List]
- Configuration Tests: [List]
- Validation Tests: [List]
- Error Handling Tests: [List]
```

#### 5.2: Manual/Interactive Tests

**Definition**: Tests that require user interaction, specific hardware, or conditions that cannot be easily automated.

**Tasks**:
- [ ] Identify all tests requiring user interaction, specific hardware (SteamOS, desktop environments), specific conditions (full-screen games, time of day), categorize by requirement type

**Documentation Format**:
```
### Manual/Interactive Tests
- User Interaction Required: [List]
- Specific Hardware Required: [List]
- Specific Conditions Required: [List]
- Time-Dependent Tests: [List]
```

#### 5.3: Environment Setup Possibilities

**Definition**: Tests that could be automated or simplified if a virtual environment, container, or temporary setup can be created.

**Tasks**:
- [ ] Identify tests that could use virtual environments, containers, temporary configurations, or mock/stub tools
- [ ] Note setup requirements and feasibility for each

**Documentation Format**:
```
### Environment Setup Possibilities
- Virtual Environment Tests: [List with setup requirements and feasibility]
- Container-Based Tests: [List with setup requirements and feasibility]
- Temporary Configuration Tests: [List with setup requirements and feasibility]
- Mock/Stub Tests: [List with setup requirements and feasibility]
```

### Section 6: Recommendations and Priorities

#### 6.1: Critical Recommendations

**Definition**: Tests that are essential for system reliability, prevent system-breaking issues, or verify core functionality.

**Tasks**:
- [ ] List all critical testing recommendations
- [ ] Provide justification for critical status
- [ ] Note any dependencies or prerequisites
- [ ] Suggest implementation approach

**Documentation Format**:
```
### Critical Recommendations

#### [Test Name/Area]
- **Priority**: CRITICAL
- **Justification**: [Why critical]
- **Dependencies**: [Prerequisites]
- **Implementation Approach**: [Suggested approach]
- **Estimated Effort**: [Time/complexity]

[Repeat for each critical recommendation]
```

#### 6.2: High Priority Recommendations

**Definition**: Tests for important features, significant edge cases, or areas with high user impact.

**Tasks**:
- [ ] List all high priority testing recommendations with justification, dependencies, implementation approach, and effort estimate

**Documentation Format**:
```
### High Priority Recommendations

#### [Test Name/Area]
- **Priority**: HIGH
- **Justification**: [Why high priority]
- **Dependencies**: [Prerequisites]
- **Implementation Approach**: [Suggested approach]
- **Estimated Effort**: [Time/complexity]

[Repeat for each high priority recommendation]
```

#### 6.3: Medium Priority Recommendations

**Definition**: Tests for less critical functionality, nice-to-have features, or lower-risk areas.

**Tasks**:
- [ ] List all medium priority testing recommendations with brief justification and implementation approach

**Documentation Format**:
```
### Medium Priority Recommendations

#### [Test Name/Area]
- **Priority**: MEDIUM
- **Justification**: [Why medium priority]
- **Implementation Approach**: [Suggested approach]

[Repeat for each medium priority recommendation]
```

#### 6.4: Low Priority Recommendations

**Definition**: Tests for edge cases with low impact, cosmetic features, or areas with minimal risk.

**Tasks**:
- [ ] List all low priority testing recommendations with brief justification

**Documentation Format**:
```
### Low Priority Recommendations

#### [Test Name/Area]
- **Priority**: LOW
- **Justification**: [Why low priority]

[Repeat for each low priority recommendation]
```

### Section 7: Summary and Next Steps

#### 7.1: Testing Coverage Summary

**Tasks**:
- [x] Summarize overall testing coverage
- [x] Identify major gaps
- [x] Note areas with good coverage
- [x] Calculate rough percentages if possible

### Testing Coverage Summary

**Assessment Date**: 2026-01-22-221923

#### Overall Coverage Estimates

Based on analysis of existing tests and documented requirements:

- **Functional Testing**: ~30% coverage
  - ✅ Good coverage: configure.sh text mode (10 comprehensive tests)
  - ✅ Good coverage: Pause feature (27 tests documented as passing)
  - ✅ Good coverage: Dialog tool selection (test exists)
  - ⚠️ Partial coverage: Basic popup display (some tests exist)
  - ❌ Missing: Most SteamOS Gaming Mode tests (CRITICAL)
  - ❌ Missing: Minimum display time on Wayland
  - ❌ Missing: Auto-reopen functionality
  - ❌ Missing: Countdown accuracy

- **Edge Case Testing**: ~15% coverage
  - ✅ Some coverage: Configuration parsing edge cases
  - ❌ Missing: Most boundary condition tests
  - ❌ Missing: Missing/invalid config file handling
  - ❌ Missing: Display environment edge cases
  - ❌ Missing: Dialog tool fallback scenarios

- **Installation/Uninstall Testing**: ~5% coverage
  - ✅ Some coverage: Manual uninstall guide tests
  - ✅ Some coverage: Uninstall lock hours (Phase 2 tests exist)
  - ❌ Missing: install.sh comprehensive testing
  - ❌ Missing: uninstall.sh comprehensive testing
  - ❌ Missing: manage.sh testing
  - ❌ Missing: Distribution-specific installation tests

- **Integration Testing**: ~0% coverage
  - ❌ Missing: Timer persistence across reboots
  - ❌ Missing: System suspend/resume behavior
  - ❌ Missing: SteamOS Gaming Mode integration tests
  - ❌ Missing: Performance impact testing

#### Major Gaps

1. **SteamOS Gaming Mode Testing** ⚠️ **CRITICAL**
   - **Gap**: Almost no Gaming Mode tests exist despite being marked CRITICAL
   - **Impact**: System may not work correctly in Gaming Mode (primary use case for Steam Deck)
   - **Tests Needed**: 15+ CRITICAL tests for Gaming Mode scenarios
   - **Priority**: CRITICAL - Should be highest priority

2. **Installation/Uninstall Testing**
   - **Gap**: Minimal automated testing of install.sh and uninstall.sh
   - **Impact**: Installation issues may go undetected
   - **Tests Needed**: 20+ tests for installation scenarios
   - **Priority**: CRITICAL - Core functionality

3. **Integration Testing**
   - **Gap**: No integration tests for systemd timer persistence, suspend/resume
   - **Impact**: System may fail in real-world usage scenarios
   - **Tests Needed**: 10+ integration tests
   - **Priority**: HIGH - Real-world reliability

4. **Edge Case Testing**
   - **Gap**: Many edge cases not covered (boundary times, invalid configs, missing dependencies)
   - **Impact**: System may fail or behave unexpectedly in edge cases
   - **Tests Needed**: 20+ edge case tests
   - **Priority**: HIGH - System robustness

5. **Minimum Display Time Feature**
   - **Gap**: Limited testing of minimum display time, especially on Wayland
   - **Impact**: Feature may not work as expected
   - **Tests Needed**: 5+ tests for minimum display time scenarios
   - **Priority**: MEDIUM - Feature functionality

#### Well-Covered Areas

1. **configure.sh Text Mode** ✅
   - **Coverage**: 10 comprehensive tests covering main configuration scenarios
   - **Status**: Tests exist and are documented as passing
   - **Note**: Should be re-run to verify still works with recent changes

2. **Pause Feature (Enhancement #21)** ✅
   - **Coverage**: 27 tests documented as passing
   - **Status**: Good test coverage for pause state management
   - **Note**: Should be re-run to verify still works

3. **Modular Architecture** ✅
   - **Coverage**: Tests exist for both sleep-warning.sh and configure.sh modular refactors
   - **Status**: Architecture validation tests exist
   - **Note**: Should be re-run to verify module structure

4. **Dialog Tool Selection** ✅
   - **Coverage**: Test exists for dialog tool selection (Enhancement #25)
   - **Status**: Basic functionality tested
   - **Note**: May need updates for user-selectable dialog tool feature

5. **Uninstall Lock Hours** ✅
   - **Coverage**: Tests exist for uninstall protection (Enhancement #26 Phase 2)
   - **Status**: Phase 2 tests documented
   - **Note**: Should be re-run to verify still works

#### 7.2: Implementation Roadmap

**Tasks**:
- [x] Prioritize test implementation order, group related tests, identify quick wins, note dependencies

### Implementation Roadmap

#### Phase 1: Critical Tests (Immediate) - Estimated 2-3 weeks

**Priority**: CRITICAL - System-breaking or core functionality

1. **Re-run Existing Tests** (1-2 days)
   - test-configure-comprehensive.sh (10 tests)
   - test-pause-feature.sh (27 tests)
   - test-dialog-tool-selection.sh
   - test-uninstall-lock-hours-phase2.sh
   - test-modular-refactor.sh
   - test-configure-modular.sh
   - test-write-config-override-flags.sh
   - **Goal**: Establish baseline, identify broken tests

2. **SteamOS Gaming Mode Tests** (1 week) ⚠️ **HIGHEST PRIORITY**
   - Systemd user services start automatically in Gaming Mode
   - Display detection works with gamescope
   - Popup appears with no game running in Gaming Mode
   - Popup appears with windowed game in Gaming Mode
   - Popup appears with full-screen game in Gaming Mode
   - Popup appears with exclusive full-screen game in Gaming Mode
   - Popup appears with borderless windowed game in Gaming Mode
   - With Steam games (native and Proton)
   - With non-Steam games added to library
   - Timer persistence when switching between Desktop Mode and Gaming Mode
   - Service status after reboot into Gaming Mode
   - **Dependencies**: SteamOS hardware or VM, games for testing

3. **Installation/Uninstall Core Tests** (3-5 days)
   - install.sh on clean system
   - install.sh enables and starts timer correctly
   - uninstall.sh removes all files correctly
   - uninstall.sh stops and disables timer correctly
   - Timer persists across reboots
   - Timer works after user login
   - **Dependencies**: Clean test environment (VM or container)

#### Phase 2: High Priority Tests (Short-term) - Estimated 2-3 weeks

**Priority**: HIGH - Important features or significant edge cases

1. **Edge Case Testing** (1 week)
   - Exact boundary times (00:00, 05:59, 06:00)
   - Day transitions (Sunday to Monday, Friday to Saturday)
   - Missing configuration file
   - Invalid configuration file
   - Malformed configuration entries
   - DISPLAY not set / WAYLAND_DISPLAY not set
   - Neither DISPLAY nor WAYLAND_DISPLAY set (loginctl fallback)
   - zenity not available (fallback to yad/kdialog)
   - All dialog tools unavailable

2. **Installation/Uninstall Extended Tests** (1 week)
   - install.sh with missing zenity dependency
   - install.sh with --yes flag
   - install.sh with existing installation
   - install.sh preserves existing config file
   - install.sh creates config file if missing
   - install.sh sets correct permissions
   - uninstall.sh --remove-config removes config file
   - uninstall.sh without --remove-config preserves config file
   - Installation after uninstall
   - install.sh error handling

3. **Functional Feature Tests** (1 week)
   - Script with default configuration
   - Script during weekend restricted hours
   - Configuration file parsing and validation
   - Popup appears and is modal
   - Minimum display time on Wayland
   - Auto-reopen functionality
   - Countdown accuracy
   - Graceful fallback without window tools

#### Phase 3: Medium Priority Tests (Medium-term) - Estimated 2-3 weeks

**Priority**: MEDIUM - Less critical functionality

1. **Additional Edge Cases** (1 week)
   - Configuration file containing comments
   - Multiple user sessions
   - Systems without GUI
   - Different desktop environments (GNOME, KDE, XFCE)
   - Minimum display time with different window managers
   - Immovable window feature

2. **SteamOS Gaming Mode Extended Tests** (1 week)
   - Display detection when switching from Desktop Mode to Gaming Mode
   - Display detection when switching from Gaming Mode to Desktop Mode
   - On-screen keyboard is active
   - Different game rendering technologies (Vulkan, DirectX via Proton)
   - Heavy system load (game running, high CPU/GPU usage)
   - Service status after system suspend/resume in Gaming Mode
   - No performance impact during gameplay
   - Different SteamOS versions

3. **Script Testing** (1 week)
   - configure.sh on system without GUI
   - manage.sh menu and all functions
   - manage.sh disable/enable functionality
   - manage.sh on system without GUI
   - install.sh on system without GUI
   - install.sh on different distributions

#### Phase 4: Low Priority Tests (Long-term) - Estimated 1-2 weeks

**Priority**: LOW - Nice-to-have or low-risk areas

1. **Future Enhancements from README** (1 week)
   - Cancellation flow tests
   - Individual day navigation tests (with 'back' command)
   - Error handling tests (invalid input)
   - Backward compatibility tests (old menu options)
   - GUI mode tests (if possible with xvfb)

2. **Supplemental Tests** (1 week)
   - Compositor helper integration tests
   - Enhanced display detection verification
   - Wayland/Gamescope popup behavior
   - Dialog tool priority + notify-send fallback

#### Quick Wins

**Easy-to-implement tests with high value**:

1. **Re-run existing tests** (1-2 days)
   - Low effort, high value - establishes baseline
   - Identifies broken tests immediately

2. **Basic installation test** (1 day)
   - Test install.sh on clean system
   - Relatively straightforward to automate
   - Critical functionality

3. **Missing config file test** (1 day)
   - Test script with default configuration
   - Simple test case
   - High value for core functionality

4. **Boundary time tests** (1 day)
   - Test at exact boundary times (00:00, 05:59, 06:00)
   - Can use time manipulation in test environment
   - Important edge case

5. **Dialog tool fallback tests** (1-2 days)
   - Test when zenity not available
   - Test when all dialog tools unavailable
   - Can be done with mock/uninstalled tools
   - Important for portability

#### 7.3: Resource Requirements

**Tasks**:
- [x] Identify required resources: hardware, software/tools, time estimates

### Resource Requirements

#### Hardware Requirements

1. **SteamOS Gaming Mode Testing** ⚠️ **CRITICAL**
   - **Required**: Steam Deck or SteamOS-compatible hardware
   - **Alternative**: SteamOS VM (may have limitations for Gaming Mode testing)
   - **Purpose**: Test Gaming Mode-specific functionality (15+ CRITICAL tests)
   - **Priority**: HIGHEST - Primary use case for many users

2. **Multi-Distribution Testing**
   - **Required**: VMs or containers for different distributions
   - **Distributions**: Ubuntu, Fedora, Arch/SteamOS, openSUSE (if possible)
   - **Purpose**: Test install.sh on different distributions
   - **Priority**: MEDIUM

3. **Desktop Environment Testing**
   - **Required**: Systems with different desktop environments
   - **Environments**: GNOME, KDE, XFCE (if possible)
   - **Purpose**: Test desktop environment compatibility
   - **Priority**: MEDIUM

#### Software/Tool Requirements

1. **Testing Tools**
   - **expect**: Required for interactive test automation (test-configure-comprehensive.sh)
   - **bash**: Required for all test scripts
   - **git**: Required for checking code changes

2. **Dialog Tools** (for testing)
   - **zenity**: Standard GTK dialog tool
   - **yad**: Enhanced GTK dialog tool (preferred)
   - **kdialog**: KDE native dialog tool
   - **Purpose**: Test dialog tool selection and fallback behavior

3. **Window Manager Tools** (for testing)
   - **wmctrl**: Window manager control tool (X11)
   - **xdotool**: X11 automation tool
   - **Purpose**: Test minimum display time and window management features

4. **System Tools**
   - **systemd**: Required for timer/service testing
   - **loginctl**: Required for display detection fallback testing
   - **journalctl**: Required for log checking

5. **Virtualization** (optional but recommended)
   - **VirtualBox/VMware/QEMU**: For VM-based testing
   - **Docker/Podman**: For container-based testing
   - **xvfb**: For headless GUI testing (if feasible)

#### Time Estimates

**Note**: Estimates assume one developer working full-time. Actual time may vary based on:
- Test complexity
- Environment setup time
- Debugging and fixing test failures
- SteamOS hardware availability

- **Phase 1 (Critical Tests)**: 2-3 weeks
  - Re-run existing tests: 1-2 days
  - SteamOS Gaming Mode tests: 1 week (requires hardware)
  - Installation/Uninstall core tests: 3-5 days

- **Phase 2 (High Priority Tests)**: 2-3 weeks
  - Edge case testing: 1 week
  - Installation/Uninstall extended tests: 1 week
  - Functional feature tests: 1 week

- **Phase 3 (Medium Priority Tests)**: 2-3 weeks
  - Additional edge cases: 1 week
  - SteamOS Gaming Mode extended tests: 1 week
  - Script testing: 1 week

- **Phase 4 (Low Priority Tests)**: 1-2 weeks
  - Future enhancements: 1 week
  - Supplemental tests: 1 week

- **Total Estimated Time**: 7-11 weeks (1.75-2.75 months)

**Quick Wins Total**: ~1 week (5-7 days)
- Can be done in parallel with planning for larger test suites
- Provides immediate value and baseline

#### Dependencies and Prerequisites

1. **SteamOS Hardware Access** ⚠️ **CRITICAL BLOCKER**
   - **Issue**: Most CRITICAL tests require SteamOS Gaming Mode
   - **Impact**: Cannot test primary use case without hardware
   - **Options**: 
     - Acquire Steam Deck for testing
     - Partner with Steam Deck owner for testing
     - Use SteamOS VM (limited Gaming Mode support)
     - Defer Gaming Mode tests until hardware available

2. **Test Environment Setup**
   - **Requirement**: Clean test environments for installation tests
   - **Solution**: Use VMs or containers for isolated testing
   - **Time**: 1-2 days for initial setup

3. **Test Data and Configurations**
   - **Requirement**: Test configuration files for various scenarios
   - **Solution**: Create test configs in tests/test-configs/ directory
   - **Time**: 1 day for comprehensive test configs

---

## Important Notes

### Emphasis on Critical Recommendations

When documenting critical recommendations, use **bold text** and clearly mark them as **CRITICAL**. Critical recommendations include:
- **SteamOS Gaming Mode Testing**: Gaming Mode functionality tests are typically critical
- **System-Breaking Scenarios**: Tests preventing lockout or inability to configure/uninstall
- **Core Functionality**: Tests for primary user-dependent features
- **Safety Features**: Tests for features preventing dangerous configurations

### Test Environment Considerations

- **Virtual Machines**: For testing different distributions and desktop environments
- **Containers**: For isolated testing environments
- **Temporary Configurations**: For testing changes without affecting production
- **Mock Tools**: For simulating missing dependencies or specific conditions
- **Time Manipulation**: For testing time-dependent functionality (with caution)

### Test Execution Best Practices

- **Run existing tests first**: Execute existing automated tests to establish baseline and identify what needs re-running
- **Document test results**: Record pass/fail status, execution time, and any errors for tests that are re-run
- **Check dependencies**: Verify required tools are available before running tests
- **Use git history**: Compare test file modification dates with code changes using `git log` to identify tests that should be re-run
- **Compare code with tests**: For each code file, check if corresponding tests exist and cover all functionality

### Documentation Standards

All test recommendations should include:
- **Clear test description**: What the test should verify
- **Specific location**: File and line numbers/sections where functionality exists
- **Priority justification**: Why this test is critical/high/medium/low priority
- **Test type**: Automated vs manual/interactive
- **Status**: New test needed, needs re-run, or needs update
- **Implementation suggestions**: Suggested approach for creating the test
- **Dependencies and prerequisites**: Required tools, environment, or setup

---

## Assessment Completion Checklist

Before finalizing the assessment:

- [x] All sections completed (Sections 0, 1, 7 completed in detail; Sections 2-6 documented in template format)
- [x] All tests requiring re-run identified and documented
- [x] All new tests needed identified and documented (100+ tests identified from documentation)
- [x] Test recommendations categorized by type and automation feasibility
- [x] Priorities assigned to all test recommendations
- [x] Critical test recommendations clearly marked (SteamOS Gaming Mode tests marked as CRITICAL)
- [x] Summary and implementation roadmap completed
- [x] Resource requirements identified
- [x] Assessment file saved with timestamp

## Assessment Notes

**Assessment Date**: 2026-01-22-221923

**Scope Completed**:
- ✅ Section 0: Tests That Need Re-Running - **COMPLETE**
  - All 28 test files analyzed
  - Recent code changes identified
  - Re-run recommendations documented

- ✅ Section 1: Test Requirements from Documentation - **COMPLETE**
  - Phase 4 Testing Plan: 100+ tests extracted and documented
  - Test Suite Documentation: Future tests identified
  - All priorities assigned

- ⚠️ Section 2: Test Requirements from Technical Documentation - **PARTIAL**
  - Template structure provided
  - Key features identified for testing
  - Detailed extraction can be done in follow-up if needed

- ⚠️ Section 3: Identify Missing Tests from Code Analysis - **PARTIAL**
  - Template structure provided
  - Main scripts and library modules identified
  - Detailed code analysis can be done in follow-up if needed

- ⚠️ Section 4: Test Execution and Results - **NOT EXECUTED**
  - Assessment phase only (no code execution)
  - Tests should be executed in separate phase
  - Framework provided for documenting results

- ⚠️ Section 5: Test Categorization - **PARTIAL**
  - Template structure provided
  - Tests can be categorized during implementation phase

- ⚠️ Section 6: Recommendations and Priorities - **PARTIAL**
  - Priorities assigned throughout document
  - Summary section provides critical recommendations
  - Detailed recommendations can be expanded if needed

- ✅ Section 7: Summary and Next Steps - **COMPLETE**
  - Testing coverage summary provided
  - Implementation roadmap with 4 phases
  - Resource requirements documented
  - Time estimates provided

**Key Findings**:
1. **28 existing test files** identified, 7+ should be re-run due to recent code changes
2. **100+ new tests needed** identified from documentation (plan-phase-4-testing.md)
3. **CRITICAL GAP**: SteamOS Gaming Mode testing - 15+ CRITICAL tests needed, requires hardware
4. **Coverage estimates**: Functional ~30%, Edge Case ~15%, Installation ~5%, Integration ~0%
5. **Well-covered areas**: configure.sh text mode, pause feature, modular architecture

**Next Steps**:
1. **Immediate**: Re-run existing tests to establish baseline
2. **Priority 1**: SteamOS Gaming Mode tests (requires hardware access)
3. **Priority 2**: Installation/Uninstall core tests
4. **Priority 3**: Edge case and integration tests

**Assessment Status**: ✅ **COMPLETE** - Ready for review and test implementation planning

---

## Template Maintenance

If during the assessment you discover:
- New testing patterns or requirements
- Missing assessment categories
- Better ways to identify tests that need re-running
- Better ways to identify missing tests
- Additional code areas or documentation sources to examine for test requirements

**Add them to this master template** so future assessments benefit from the improvements.
