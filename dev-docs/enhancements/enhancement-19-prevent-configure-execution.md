# Enhancement 19: Prevent configure.sh and manage.sh Execution During Restricted Hours

- **Description**: Prevent `configure.sh` and `manage.sh` from running during restricted hours (Phase 1) and optionally during additional configurable hours (Phase 2) to prevent users from circumventing restrictions by changing settings or disabling the system
- **Files Affected**: `configure.sh`, `manage.sh`, `sleep-warning.sh`, `sleep-warning.conf`
- **Priority**: Medium (security/self-control feature, complements config file locking)
- **Status**: Phase 1 - Complete ✅
- **Feasibility Assessment**: ✅ **Highly Feasible** - Simple time check at script start
- **Implementation Approach**:
  - **Phase 1: Block During Restricted Hours**:
    - User-configurable option in `configure.sh` to enable/disable blocking
    - When enabled, `configure.sh` and `manage.sh` check current day/time at startup
    - If current time falls within restricted hours, exit with error message
    - Use same time checking logic as `sleep-warning.sh` (reuse functions)
    - **Pros**: Simple, effective, cannot be easily bypassed without modifying script, user-controlled
    - **Cons**: Can be bypassed by modifying system time or editing script directly
    - **Safety**: Medium - Determined users can bypass, but requires knowledge/effort
  - **Phase 2: Additional Configurable Lock Hours**:
    - Extend Phase 1 to also check additional configurable lock hours
    - If current time falls within restricted hours OR additional lock hours, exit with error message
    - Allows users to configure separate lock hours beyond restriction hours
    - **Pros**: More flexible, allows custom lock periods independent of restriction hours
    - **Cons**: Adds complexity, requires additional configuration
    - **Safety**: Same as Phase 1
- **Implementation Notes**:
  - **Phase 1 Config Options**:
    - `CONFIGURE_BLOCK_ENABLED=true/false` - Enable/disable blocking of configure.sh and manage.sh during restricted hours
    - Block applies only during restricted hours
    - **Configuration Interface**: Add option in `configure.sh` to allow user to choose whether to block `configure.sh` and `manage.sh` during restricted hours
    - User should be able to enable/disable this feature through the configuration menu
    - Default: disabled (opt-in feature)
    - **Note**: This is separate from Enhancement #18 (Config File Locking) which uses `CONFIG_LOCK_ENABLED`
  - **Phase 2 Config Options** (extends Phase 1):
    - `CONFIG_LOCK_HOURS=DAY=START-END` - Additional hours for blocking configure.sh and manage.sh (separate from restriction hours)
    - Block applies during restricted hours AND any additional configured lock hours
  - **Phase 1 Time Check Logic**:
    - Only applies when `CONFIGURE_BLOCK_ENABLED=true` (user-enabled via `configure.sh`)
    - Reuse `is_restricted_hour()` function from `lib/time-validation.sh` (already shared module)
    - Source `lib/time-validation.sh` in `configure.sh` and `manage.sh` to use the same validation logic
    - Check only restriction hours
    - Exit early with clear error message if in restricted hours
  - **Phase 2 Time Check Logic** (extends Phase 1):
    - Add function to check additional lock hours (similar to `is_restricted_hour()`)
    - Check both restriction hours and additional lock hours
    - Exit early with clear error message if in restricted/lock hours
  - **Error Message**:
    - Clear, informative: "Configuration is locked during restricted hours ([current time range]). Please try again after [end time]."
    - Phase 2: Update message to indicate if locked due to restriction hours or additional lock hours
    - Show current time and when restrictions end
  - **Bypass Prevention**:
    - Script should check time, not rely on external locks (prevents lock file deletion bypass)
    - Can combine with config file locking (#18) for defense in depth
- **Safety Assessment**:
  - **Bypass Risk**: Medium - Determined users can bypass by:
    - Modifying system time (requires admin access or time change permissions)
    - Editing `configure.sh`, `manage.sh`, or library modules directly to remove time check
    - Running `sleep-warning.sh` with modified time check
  - **Uninstall Safety**: ✅ **Safe** - Uninstall script should not be blocked (always allow uninstall)
  - **Data Safety**: ✅ **Safe** - No risk of data loss
  - **System Safety**: ✅ **Safe** - No risk to system stability
  - **User Experience**: ⚠️ **May Frustrate Users** - Prevents legitimate config changes and system management during restricted hours
- **Processing/Memory Burden**:
  - **Minimal** - Only requires time check at script startup (same logic as restriction checking)
  - No additional processes or continuous monitoring
  - **Memory**: Negligible (no additional memory usage)
  - **CPU**: Negligible (time check is instant, same as existing restriction checks)
- **User Experience Considerations**:
  - **Clear Error Message**: Should inform user why script cannot run and when they can try again (Phase 1)
  - **Optional Feature**: Should be opt-in (default: disabled) to avoid frustrating users (Phase 1)
  - **Emergency Override**: Consider allowing override with special flag (e.g., `--force`) for emergencies (defeats purpose but may be needed) (Phase 1)
  - **Uninstall Always Works**: `uninstall.sh` should never be blocked (critical for user control) (Phase 1)
  - **Manage.sh Blocking**: Blocking `manage.sh` prevents users from disabling the system through the management interface during restricted hours, providing additional security against circumvention (Phase 1)
  - **Phase 2 Additional Considerations**: Additional lock hours provide more flexibility but require users to understand the difference between restriction hours and lock hours
- **Related**: 
  - Works with "Config File Locking" (#18) - complementary features, defense in depth
  - Uses same time checking logic as restriction system
  - Complements restriction system by preventing circumvention

---

## Phase 1: Implementation Checklist

### Overview
Prevent `configure.sh` and `manage.sh` from running during restricted hours when `CONFIGURE_BLOCK_ENABLED=true`. This is a user-configurable, opt-in feature (default: disabled).

### Files to Modify

#### Core Files
- `lib/config.sh` - Add function to read CONFIGURE_BLOCK_ENABLED
- `lib/configure-config.sh` - Load and save CONFIGURE_BLOCK_ENABLED
- `lib/configure-display.sh` - Add menu option for configure block setting
- `lib/configure-ui.sh` - Add dialog function for configure block setting
- `configure.sh` - Add time check at startup, add menu handler
- `manage.sh` - Add time check at startup
- `sleep-warning.conf` - Add CONFIGURE_BLOCK_ENABLED documentation

#### Documentation
- `dev-docs/enhancements/enhancement-19-prevent-configure-execution.md` - Update status when complete

---

### 1. Configuration File Support

#### 1.1 Add CONFIGURE_BLOCK_ENABLED to config.sh
- [x] Add default value constant: `DEFAULT_CONFIGURE_BLOCK_ENABLED=false`
- [x] Add function `get_configure_block_enabled()` in `lib/config.sh`
  - [x] Read `CONFIGURE_BLOCK_ENABLED` from config file
  - [x] Validate value (true/false/1/0/yes/no)
  - [x] Return default if missing or invalid
  - [x] Normalize output to "true" or "false" string

#### 1.2 Update configure-config.sh
- [x] Add `configure_block_enabled` to global variables in `load_existing_config()`
  - [x] Initialize with default: `declare -g configure_block_enabled="false"`
  - [x] Read existing value from config file (if present)
  - [x] Validate and normalize to "true" or "false"
- [x] Update `write_config()` function signature
  - [x] Add `configure_block_enabled` as parameter (6th parameter, after `popup_immovable`)
  - [x] Write `CONFIGURE_BLOCK_ENABLED=${configure_block_enabled}` to config file
  - [x] Add comment header explaining the option
  - [x] Place after `POPUP_IMMOVABLE` section in config file

#### 1.3 Update configure.sh main function
- [x] Add `configure_block_enabled` to global variable declarations (line ~107)
  - [x] Add to: `declare -g check_interval popup_size popup_position min_display_time popup_immovable configure_block_enabled`
- [x] Update `write_config()` call (line ~263)
  - [x] Add `${configure_block_enabled}` as 6th argument

#### 1.4 Update config file template
- [x] Add `CONFIGURE_BLOCK_ENABLED` section to `sleep-warning.conf` template
  - [x] Add comment explaining the feature
  - [x] Add default value: `CONFIGURE_BLOCK_ENABLED=false`
  - [x] Place after `POPUP_IMMOVABLE` section

---

### 2. Configuration UI - Menu Option

#### 2.1 Add menu option to configure-display.sh
- [x] Update `show_main_menu()` function
  - [x] Add new menu option "6" for "Security Settings"
  - [x] Update menu item count and descriptions (now 1-7, with "Review and Save" as option 7)
  - [x] Add status indicator showing current state (Enabled/Disabled)
  - [x] Update both GUI and text mode menus

#### 2.2 Add dialog function to configure-input.sh
- [x] Create `get_configure_block_enabled_config()` function
  - [x] Accept `use_gui` parameter
  - [x] Show current setting (enabled/disabled)
  - [x] Ask user to enable/disable
  - [x] Return "true" or "false" string
  - [x] Handle cancellation (return "CANCELLED")
  - [x] Support both GUI and text modes
  - [x] Include clear explanation of what the feature does
  - **Note**: Function added to `lib/configure-input.sh` (not `configure-ui.sh`) to match pattern of other config functions

#### 2.3 Add menu handler to configure.sh
- [x] Add case for menu option "6" (Security Settings)
  - [x] Call `get_configure_block_enabled_config()`
  - [x] Handle "CANCELLED" response (exit if cancelled)
  - [x] Update global `configure_block_enabled` variable
  - [x] Return to main menu after setting

---

### 3. Time Check Implementation

#### 3.1 Create time check function
- [x] Create `check_config_lock_time()` function
  - [x] Location: Add to `lib/time-validation.sh` OR create new `lib/config-lock.sh`
  - [x] Function should:
    - [x] Read `CONFIGURE_BLOCK_ENABLED` from config (use `get_configure_block_enabled()`)
    - [x] Return 0 (success) if disabled - no blocking
    - [x] Get current day of week (0=Sunday, 6=Saturday)
    - [x] Get current hour (0-23)
    - [x] Parse config for current day using `parse_config()`
    - [x] Check if current hour is restricted using `is_restricted_hour()`
    - [x] Handle overnight ranges from previous day (same logic as sleep-warning.sh)
    - [x] Return 0 if NOT in restricted hours (allow execution)
    - [x] Return 1 if IN restricted hours (block execution)

#### 3.2 Add time check to configure.sh
- [x] Source required modules at top of script
  - [x] Ensure `lib/config.sh` is sourced (already sourced via configure-core.sh)
  - [x] Ensure `lib/time-validation.sh` is sourced (add if not already)
  - [x] Source new function (if in separate file)
- [x] Add time check at start of `main()` function
  - [x] Call `check_config_lock_time()` BEFORE showing welcome
  - [x] If function returns 1 (blocked), show error and exit
  - [x] Do NOT block if `CONFIG_LOCK_ENABLED=false` or missing
  - **Note**: Error message implemented inline for now; separate function (section 4) can be added later for consistency

#### 3.3 Add time check to manage.sh
- [x] Source required modules at top of script
  - [x] Add: `source "${SCRIPT_DIR}/lib/config.sh"` (or determine script dir first)
  - [x] Add: `source "${SCRIPT_DIR}/lib/time-validation.sh"`
  - [x] Determine script directory (similar to configure.sh pattern)
- [x] Add time check at start of `main()` function
  - [x] Call `check_config_lock_time()` BEFORE showing menu
  - [x] If function returns 1 (blocked), show error and exit
  - [x] Do NOT block if `CONFIG_LOCK_ENABLED=false` or missing
  - **Note**: Error message implemented inline for now; separate function (section 4) can be added later for consistency

#### 3.4 Ensure uninstall.sh is never blocked
- [x] Verify `uninstall.sh` does NOT source time validation modules
- [x] Verify `uninstall.sh` does NOT call time check function
- [x] Document in code comments that uninstall is always allowed
  - **Verified**: uninstall.sh does not source config.sh or time-validation.sh, so it will never be blocked

---

### 4. Error Message Implementation

#### 4.1 Create error message function
- [x] Create `show_config_locked_error()` function
  - [x] Location: `lib/configure-ui.sh`
  - [x] Accept parameters: `use_gui`, `script_name` (e.g., "Configuration" or "Management interface")
  - [x] Format message:
    - [x] "{script_name} is locked during restricted hours"
    - [x] Show current time (day name, 12-hour format)
    - [x] Show restricted range that applies (human-readable format)
    - [x] Calculate and show when restrictions end
    - [x] Suggest when user can try again
  - [x] Support both GUI and text modes
  - [x] Use appropriate dialog tool (yad/zenity/kdialog) for GUI

#### 4.2 Integrate error message
- [x] Update configure.sh error handling
  - [x] Call `show_config_locked_error()` with appropriate details
  - [x] Exit with non-zero code after showing error
  - **Note**: Simplified from inline error message to function call
- [x] Update manage.sh error handling
  - [x] Source required modules (configure-core.sh, configure-time.sh, configure-ui.sh, configure-dialogs.sh)
  - [x] Call `show_config_locked_error()` with appropriate details
  - [x] Exit with non-zero code after showing error
  - **Note**: Simplified from inline error message to function call

#### 4.3 Calculate restriction end time
- [x] Add helper function `calculate_restriction_end_time()` to calculate when restrictions end
  - [x] Parse restricted range for current day
  - [x] Check for overnight ranges from previous day
  - [x] Determine end hour of current restriction period
  - [x] Handle overnight ranges correctly (end time on next day)
  - [x] Handle multiple ranges per day (find the one we're currently in)
  - [x] Format as human-readable time (e.g., "5:00 AM")
  - [x] Return structured data: "END_TIME|END_DAY|IS_OVERNIGHT"
  - [x] **Tested**: Function executes correctly, handles edge cases (empty restrictions return exit code 1 as expected)

---

### 5. Testing

#### 5.1 Unit Tests
- [x] Test `get_configure_block_enabled()` function
  - [x] Test with missing config file (should return default false)
    - **Verified**: Returns "false" when config file doesn't exist
  - [ ] Test with CONFIGURE_BLOCK_ENABLED=true (requires config file setup)
  - [ ] Test with CONFIGURE_BLOCK_ENABLED=false (requires config file setup)
  - [ ] Test with invalid values (should return default) (requires config file setup)
  - [ ] Test case insensitivity (True, TRUE, etc.) (requires config file setup)
  - **Note**: Basic functionality verified; full value testing requires config file manipulation

- [x] Test `check_config_lock_time()` function
  - [x] Test when CONFIGURE_BLOCK_ENABLED=false (should allow)
    - **Verified**: Returns 0 (allowed) when blocking is disabled
  - [x] Test when CONFIGURE_BLOCK_ENABLED=true and NOT in restricted hours (should allow)
    - **Verified**: Function executes without errors when not in restricted hours
  - [ ] Test when CONFIGURE_BLOCK_ENABLED=true and IN restricted hours (should block)
    - **Note**: Requires setting CONFIGURE_BLOCK_ENABLED=true and configuring restricted hours for current time
  - [ ] Test overnight ranges (23-6 on previous day extending to current day)
    - **Note**: Requires specific time configuration
  - [ ] Test multiple ranges per day
    - **Note**: Requires config file setup
  - [x] Test empty restriction (no restrictions for day)
    - **Verified**: Function handles empty/missing restrictions correctly

#### 5.2 Integration Tests
- [x] Test configure.sh blocking
  - [x] Set CONFIGURE_BLOCK_ENABLED=true
  - [x] Set restricted hours for current day/time
  - [x] Run configure.sh - should exit with error
  - [x] Verify error message is displayed
  - [ ] Test when NOT in restricted hours - should work normally
  - **Verified**: configure.sh correctly blocks during restricted hours and displays error message

- [x] Test manage.sh blocking
  - [x] Set CONFIGURE_BLOCK_ENABLED=true
  - [x] Set restricted hours for current day/time
  - [x] Run manage.sh - should exit with error
  - [x] Verify error message is displayed
  - [ ] Test when NOT in restricted hours - should work normally
  - **Verified**: manage.sh correctly blocks during restricted hours and displays error message

- [X] Test uninstall.sh (should never block)
  - [X] Set CONFIGURE_BLOCK_ENABLED=true
  - [X] Set restricted hours for current day/time
  - [X] Run uninstall.sh - should work normally (no blocking)

- [ ] Test configuration UI
  - [X] Run configure.sh
  - [X] Navigate to new "Security Settings" menu option
  - [X] Enable CONFIGURE_BLOCK_ENABLED
  - [X] Verify it's saved to config file
  - [ ] Disable CONFIGURE_BLOCK_ENABLED
  - [ ] Verify it's saved to config file
  - [ ] Test in both GUI and text modes

#### 5.3 Edge Cases
- [x] Test with missing config file (should default to false, no blocking)
  - **Verified**: `get_configure_block_enabled()` returns "false" when config file doesn't exist
  - **Verified**: `check_config_lock_time()` allows execution when config file is missing
- [ ] Test with corrupted config file (should default to false, no blocking)
  - **Note**: Requires creating corrupted config file for testing
- [ ] Test at boundary times (exactly at start/end of restriction)
  - **Note**: Requires specific time configuration and testing
- [ ] Test with all days having restrictions
  - **Note**: Requires config file setup
- [x] Test with no days having restrictions (should never block)
  - **Verified**: `check_config_lock_time()` allows execution when no restrictions are configured
- [ ] Test with system time changes (if possible)
  - **Note**: Difficult to test automatically; would require time manipulation

---

### 6. Code Quality

#### 6.1 Code Documentation
- [x] Add header comments to new functions explaining purpose
  - [x] Enhanced `get_configure_block_enabled_config()` with detailed parameter/return documentation
  - [x] `check_config_lock_time()` already had good documentation
  - [x] `calculate_restriction_end_time()` already had good documentation
  - [x] `show_config_locked_error()` already had good documentation
- [x] Add inline comments for complex logic (overnight range handling)
  - [x] Inline comments already present in `check_config_lock_time()` for overnight range logic
  - [x] Inline comments present in `calculate_restriction_end_time()` for range detection
- [x] Document function parameters and return values
  - [x] All new functions have parameter and return value documentation
- [x] Update main script headers if needed
  - **Note**: Main scripts (configure.sh, manage.sh) already have appropriate headers

#### 6.2 Error Handling
- [x] Ensure all file operations handle errors gracefully
  - [x] Config file reading uses `2>/dev/null` and fallbacks to defaults
  - [x] Module sourcing uses `|| true` or `|| exit 1` appropriately
- [x] Ensure config parsing handles missing/invalid values
  - [x] `get_configure_block_enabled()` returns default "false" for missing/invalid values
  - [x] `check_config_lock_time()` handles missing config gracefully
- [x] Ensure time calculations handle edge cases
  - [x] Overnight ranges handled correctly (wraps around day boundaries)
  - [x] Previous day overnight ranges checked before current day ranges
  - [x] Multiple ranges per day handled correctly
- [x] Add logging for debugging (optional, use log_message if available)
  - **Note**: Logging is optional for this feature; error messages are sufficient for user feedback

#### 6.3 Code Consistency
- [x] Follow existing code style and patterns
  - [x] Functions follow same naming conventions (snake_case)
  - [x] Error handling follows same patterns as other functions
- [x] Use same variable naming conventions
  - [x] Uses `configure_block_enabled` (matches `popup_immovable` pattern)
  - [x] Uses `CONFIGURE_BLOCK_ENABLED` in config file (matches other config options)
- [x] Use same function organization patterns
  - [x] Functions placed in appropriate modules (config.sh, time-validation.sh, configure-ui.sh, configure-input.sh)
- [x] Match existing error message style
  - [x] Error messages use same format as other system messages
  - [x] GUI and text modes both supported consistently

---

### 7. Documentation Updates

#### 7.1 User Documentation
- [x] Update `user-docs/CONFIGURATION.md` (if exists)
  - [x] Document CONFIGURE_BLOCK_ENABLED option
  - [x] Explain what it does (security feature to prevent circumventing restrictions)
  - [x] Explain how to enable/disable (via configure.sh Security Settings menu)
  - [x] Note that it's opt-in (default disabled)
  - [x] Document use cases, limitations, and important notes
  - [x] Added to complete configuration example

#### 7.2 Developer Documentation
- [x] Update enhancement document status to "Phase 1 Complete"
  - [x] Status updated to "Phase 1 - Complete ✅"
- [x] Document any design decisions or implementation notes
  - **Design Decisions**:
    - Used `CONFIGURE_BLOCK_ENABLED` (separate from Enhancement #18's `CONFIG_LOCK_ENABLED`) to clearly distinguish script blocking from config file locking
    - Opt-in by default to avoid frustrating users
    - Reused existing time validation logic for consistency
    - Created reusable error message function for better UX
    - Uninstall script is never blocked (critical safety feature)
    - Error messages show human-readable times and restriction end times
- [x] Note any known limitations or edge cases
  - **Known Limitations**:
    - Can be bypassed by modifying system time or editing scripts directly
    - Designed as self-control aid, not security against determined users
    - Requires user to be outside restricted hours to enable/disable the feature
  - **Edge Cases Handled**:
    - Overnight ranges (e.g., 23-6) correctly handled
    - Previous day overnight ranges extending into current day
    - Multiple ranges per day
    - Missing or corrupted config files (defaults to false)
    - Empty restriction days (no blocking)

---

### 8. Final Verification

#### 8.1 Pre-commit Checks
- [x] Run all existing tests to ensure no regressions
  - [x] Syntax check: All modified files pass bash syntax validation
    - **Verified**: `lib/config.sh`, `lib/time-validation.sh`, `lib/configure-ui.sh`, `lib/configure-input.sh`, `configure.sh`, `manage.sh` all pass syntax check
  - [x] Integration test: `test-write-config-override-flags.sh` - All 10 tests passed
    - **Verified**: Tests for override flag handling, backward compatibility, edge cases all pass
- [x] Check for linting errors
  - **Verified**: No linting errors found in modified files
- [x] Verify all functions are properly sourced
  - **Verified**: All required modules are sourced correctly in configure.sh and manage.sh
- [x] Verify config file format is correct
  - **Verified**: Config file format matches existing patterns, override flags handled correctly

#### 8.2 Manual Testing
- [x] Test full configuration workflow
  - **Verified**: User confirmed configuration UI works (enable/disable CONFIGURE_BLOCK_ENABLED)
- [x] Test blocking behavior in real scenarios
  - **Verified**: User confirmed configure.sh and manage.sh correctly block during restricted hours
- [x] Test error messages are clear and helpful
  - **Verified**: User confirmed error messages display correctly with polished formatting
- [x] Verify uninstall still works
  - **Verified**: User confirmed uninstall.sh works normally (never blocked)

#### 8.3 Code Review Checklist
- [ ] All checklist items completed
- [ ] Code follows project conventions
- [ ] Error handling is robust
- [ ] User experience is clear
- [ ] Documentation is updated
- [ ] No security issues introduced

---

### Implementation Order Recommendation

1. **Configuration File Support** (Section 1) - Foundation
2. **Time Check Implementation** (Section 3) - Core functionality
3. **Error Message Implementation** (Section 4) - User feedback
4. **Configuration UI** (Section 2) - User interface
5. **Testing** (Section 5) - Validation
6. **Code Quality & Documentation** (Sections 6-7) - Polish

---

### Notes

- Default behavior: Feature is **disabled by default** (opt-in)
- Uninstall safety: `uninstall.sh` should **never** be blocked
- The time check uses the same logic as `sleep-warning.sh` for consistency
- Overnight ranges (e.g., 23-6) must be handled correctly
- Error messages should be clear and actionable
