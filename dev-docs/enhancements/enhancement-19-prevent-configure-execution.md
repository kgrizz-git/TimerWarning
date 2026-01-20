# Enhancement 19: Prevent configure.sh and manage.sh Execution During Restricted Hours

- **Description**: Prevent `configure.sh` and `manage.sh` from running during restricted hours (Phase 1) and optionally during additional configurable hours (Phase 2) to prevent users from circumventing restrictions by changing settings or disabling the system
- **Files Affected**: `configure.sh`, `manage.sh`, `sleep-warning.sh`, `sleep-warning.conf`
- **Priority**: Medium (security/self-control feature, complements config file locking)
- **Status**: Not implemented
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
    - `CONFIG_LOCK_ENABLED=true/false` - Enable/disable config locking (shared with #18)
    - Block applies only during restricted hours
    - **Configuration Interface**: Add option in `configure.sh` to allow user to choose whether to block `configure.sh` and `manage.sh` during restricted hours
    - User should be able to enable/disable this feature through the configuration menu
    - Default: disabled (opt-in feature)
  - **Phase 2 Config Options** (extends Phase 1):
    - `CONFIG_LOCK_HOURS=DAY=START-END` - Additional hours for blocking configure.sh and manage.sh (separate from restriction hours)
    - Block applies during restricted hours AND any additional configured lock hours
  - **Phase 1 Time Check Logic**:
    - Only applies when `CONFIG_LOCK_ENABLED=true` (user-enabled via `configure.sh`)
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
Prevent `configure.sh` and `manage.sh` from running during restricted hours when `CONFIG_LOCK_ENABLED=true`. This is a user-configurable, opt-in feature (default: disabled).

### Files to Modify

#### Core Files
- `lib/config.sh` - Add function to read CONFIG_LOCK_ENABLED
- `lib/configure-config.sh` - Load and save CONFIG_LOCK_ENABLED
- `lib/configure-display.sh` - Add menu option for config lock setting
- `lib/configure-ui.sh` - Add dialog function for config lock setting
- `configure.sh` - Add time check at startup, add menu handler
- `manage.sh` - Add time check at startup
- `sleep-warning.conf` - Add CONFIG_LOCK_ENABLED documentation

#### Documentation
- `dev-docs/enhancements/enhancement-19-prevent-configure-execution.md` - Update status when complete

---

### 1. Configuration File Support

#### 1.1 Add CONFIG_LOCK_ENABLED to config.sh
- [ ] Add default value constant: `DEFAULT_CONFIG_LOCK_ENABLED=false`
- [ ] Add function `get_config_lock_enabled()` in `lib/config.sh`
  - [ ] Read `CONFIG_LOCK_ENABLED` from config file
  - [ ] Validate value (true/false/1/0/yes/no)
  - [ ] Return default if missing or invalid
  - [ ] Normalize output to "true" or "false" string

#### 1.2 Update configure-config.sh
- [ ] Add `config_lock_enabled` to global variables in `load_existing_config()`
  - [ ] Initialize with default: `declare -g config_lock_enabled="false"`
  - [ ] Read existing value from config file (if present)
  - [ ] Validate and normalize to "true" or "false"
- [ ] Update `write_config()` function signature
  - [ ] Add `config_lock_enabled` as parameter (6th parameter, after `popup_immovable`)
  - [ ] Write `CONFIG_LOCK_ENABLED=${config_lock_enabled}` to config file
  - [ ] Add comment header explaining the option
  - [ ] Place after `POPUP_IMMOVABLE` section in config file

#### 1.3 Update configure.sh main function
- [ ] Add `config_lock_enabled` to global variable declarations (line ~107)
  - [ ] Add to: `declare -g check_interval popup_size popup_position min_display_time popup_immovable config_lock_enabled`
- [ ] Update `write_config()` call (line ~263)
  - [ ] Add `${config_lock_enabled}` as 6th argument

#### 1.4 Update config file template
- [ ] Add `CONFIG_LOCK_ENABLED` section to `sleep-warning.conf` template
  - [ ] Add comment explaining the feature
  - [ ] Add default value: `CONFIG_LOCK_ENABLED=false`
  - [ ] Place after `POPUP_IMMOVABLE` section

---

### 2. Configuration UI - Menu Option

#### 2.1 Add menu option to configure-display.sh
- [ ] Update `show_main_menu()` function
  - [ ] Add new menu option "7" for "Security Settings" or "Lock Configuration"
  - [ ] Update menu item count and descriptions
  - [ ] Add status indicator showing current state (Enabled/Disabled)
  - [ ] Update both GUI and text mode menus

#### 2.2 Add dialog function to configure-ui.sh
- [ ] Create `get_config_lock_enabled_config()` function
  - [ ] Accept `use_gui` parameter
  - [ ] Show current setting (enabled/disabled)
  - [ ] Ask user to enable/disable
  - [ ] Return "true" or "false" string
  - [ ] Handle cancellation (return "CANCELLED")
  - [ ] Support both GUI and text modes
  - [ ] Include clear explanation of what the feature does

#### 2.3 Add menu handler to configure.sh
- [ ] Add case for menu option "7" (or new option number)
  - [ ] Call `get_config_lock_enabled_config()`
  - [ ] Handle "CANCELLED" response (exit if cancelled)
  - [ ] Update global `config_lock_enabled` variable
  - [ ] Return to main menu after setting

---

### 3. Time Check Implementation

#### 3.1 Create time check function
- [ ] Create `check_config_lock_time()` function
  - [ ] Location: Add to `lib/time-validation.sh` OR create new `lib/config-lock.sh`
  - [ ] Function should:
    - [ ] Read `CONFIG_LOCK_ENABLED` from config (use `get_config_lock_enabled()`)
    - [ ] Return 0 (success) if disabled - no blocking
    - [ ] Get current day of week (0=Sunday, 6=Saturday)
    - [ ] Get current hour (0-23)
    - [ ] Parse config for current day using `parse_config()`
    - [ ] Check if current hour is restricted using `is_restricted_hour()`
    - [ ] Handle overnight ranges from previous day (same logic as sleep-warning.sh)
    - [ ] Return 0 if NOT in restricted hours (allow execution)
    - [ ] Return 1 if IN restricted hours (block execution)

#### 3.2 Add time check to configure.sh
- [ ] Source required modules at top of script
  - [ ] Ensure `lib/config.sh` is sourced (already sourced via configure-core.sh)
  - [ ] Ensure `lib/time-validation.sh` is sourced (add if not already)
  - [ ] Source new function (if in separate file)
- [ ] Add time check at start of `main()` function
  - [ ] Call `check_config_lock_time()` BEFORE showing welcome
  - [ ] If function returns 1 (blocked), show error and exit
  - [ ] Do NOT block if `CONFIG_LOCK_ENABLED=false` or missing

#### 3.3 Add time check to manage.sh
- [ ] Source required modules at top of script
  - [ ] Add: `source "${SCRIPT_DIR}/lib/config.sh"` (or determine script dir first)
  - [ ] Add: `source "${SCRIPT_DIR}/lib/time-validation.sh"`
  - [ ] Determine script directory (similar to configure.sh pattern)
- [ ] Add time check at start of `main()` function
  - [ ] Call `check_config_lock_time()` BEFORE showing menu
  - [ ] If function returns 1 (blocked), show error and exit
  - [ ] Do NOT block if `CONFIG_LOCK_ENABLED=false` or missing

#### 3.4 Ensure uninstall.sh is never blocked
- [ ] Verify `uninstall.sh` does NOT source time validation modules
- [ ] Verify `uninstall.sh` does NOT call time check function
- [ ] Document in code comments that uninstall is always allowed

---

### 4. Error Message Implementation

#### 4.1 Create error message function
- [ ] Create `show_config_locked_error()` function
  - [ ] Location: `lib/configure-ui.sh` or new helper module
  - [ ] Accept parameters: current day, current hour, restricted range, end time
  - [ ] Format message:
    - [ ] "Configuration is locked during restricted hours"
    - [ ] Show current time (day name, hour)
    - [ ] Show restricted range that applies
    - [ ] Calculate and show when restrictions end
    - [ ] Suggest when user can try again
  - [ ] Support both GUI and text modes
  - [ ] Use appropriate dialog tool (yad/zenity/kdialog) for GUI

#### 4.2 Integrate error message
- [ ] Update `check_config_lock_time()` to return error details
  - [ ] Return error message string via global variable or function output
  - [ ] OR modify to accept callback for error display
- [ ] Update configure.sh error handling
  - [ ] Call `show_config_locked_error()` with appropriate details
  - [ ] Exit with non-zero code after showing error
- [ ] Update manage.sh error handling
  - [ ] Call `show_config_locked_error()` with appropriate details
  - [ ] Exit with non-zero code after showing error

#### 4.3 Calculate restriction end time
- [ ] Add helper function to calculate when restrictions end
  - [ ] Parse restricted range for current day
  - [ ] Determine end hour of current restriction period
  - [ ] Handle overnight ranges correctly
  - [ ] Format as human-readable time (e.g., "5:00 AM")

---

### 5. Testing

#### 5.1 Unit Tests
- [ ] Test `get_config_lock_enabled()` function
  - [ ] Test with missing config file (should return default false)
  - [ ] Test with CONFIG_LOCK_ENABLED=true
  - [ ] Test with CONFIG_LOCK_ENABLED=false
  - [ ] Test with invalid values (should return default)
  - [ ] Test case insensitivity (True, TRUE, etc.)

- [ ] Test `check_config_lock_time()` function
  - [ ] Test when CONFIG_LOCK_ENABLED=false (should allow)
  - [ ] Test when CONFIG_LOCK_ENABLED=true and NOT in restricted hours (should allow)
  - [ ] Test when CONFIG_LOCK_ENABLED=true and IN restricted hours (should block)
  - [ ] Test overnight ranges (23-6 on previous day extending to current day)
  - [ ] Test multiple ranges per day
  - [ ] Test empty restriction (no restrictions for day)

#### 5.2 Integration Tests
- [ ] Test configure.sh blocking
  - [ ] Set CONFIG_LOCK_ENABLED=true
  - [ ] Set restricted hours for current day/time
  - [ ] Run configure.sh - should exit with error
  - [ ] Verify error message is displayed
  - [ ] Test when NOT in restricted hours - should work normally

- [ ] Test manage.sh blocking
  - [ ] Set CONFIG_LOCK_ENABLED=true
  - [ ] Set restricted hours for current day/time
  - [ ] Run manage.sh - should exit with error
  - [ ] Verify error message is displayed
  - [ ] Test when NOT in restricted hours - should work normally

- [ ] Test uninstall.sh (should never block)
  - [ ] Set CONFIG_LOCK_ENABLED=true
  - [ ] Set restricted hours for current day/time
  - [ ] Run uninstall.sh - should work normally (no blocking)

- [ ] Test configuration UI
  - [ ] Run configure.sh
  - [ ] Navigate to new "Security Settings" menu option
  - [ ] Enable CONFIG_LOCK_ENABLED
  - [ ] Verify it's saved to config file
  - [ ] Disable CONFIG_LOCK_ENABLED
  - [ ] Verify it's saved to config file
  - [ ] Test in both GUI and text modes

#### 5.3 Edge Cases
- [ ] Test with missing config file (should default to false, no blocking)
- [ ] Test with corrupted config file (should default to false, no blocking)
- [ ] Test at boundary times (exactly at start/end of restriction)
- [ ] Test with all days having restrictions
- [ ] Test with no days having restrictions (should never block)
- [ ] Test with system time changes (if possible)

---

### 6. Code Quality

#### 6.1 Code Documentation
- [ ] Add header comments to new functions explaining purpose
- [ ] Add inline comments for complex logic (overnight range handling)
- [ ] Document function parameters and return values
- [ ] Update main script headers if needed

#### 6.2 Error Handling
- [ ] Ensure all file operations handle errors gracefully
- [ ] Ensure config parsing handles missing/invalid values
- [ ] Ensure time calculations handle edge cases
- [ ] Add logging for debugging (optional, use log_message if available)

#### 6.3 Code Consistency
- [ ] Follow existing code style and patterns
- [ ] Use same variable naming conventions
- [ ] Use same function organization patterns
- [ ] Match existing error message style

---

### 7. Documentation Updates

#### 7.1 User Documentation
- [ ] Update `user-docs/CONFIGURATION.md` (if exists)
  - [ ] Document CONFIG_LOCK_ENABLED option
  - [ ] Explain what it does
  - [ ] Explain how to enable/disable
  - [ ] Note that it's opt-in (default disabled)

#### 7.2 Developer Documentation
- [ ] Update enhancement document status to "Phase 1 Complete"
- [ ] Document any design decisions or implementation notes
- [ ] Note any known limitations or edge cases

---

### 8. Final Verification

#### 8.1 Pre-commit Checks
- [ ] Run all existing tests to ensure no regressions
- [ ] Check for linting errors
- [ ] Verify all functions are properly sourced
- [ ] Verify config file format is correct

#### 8.2 Manual Testing
- [ ] Test full configuration workflow
- [ ] Test blocking behavior in real scenarios
- [ ] Test error messages are clear and helpful
- [ ] Verify uninstall still works

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
