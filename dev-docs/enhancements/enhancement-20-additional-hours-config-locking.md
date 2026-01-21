### 20. Additional Hours for Config Locking and configure.sh Blocking
- **Description**: Allow users to configure additional time ranges (separate from restriction hours) during which config file locking and configure.sh blocking are active. This allows users to lock configuration during specific hours even if those hours are not restricted (e.g., lock config during work hours to prevent distraction-related changes)
- **Files Affected**: `sleep-warning.sh`, `configure.sh`, `sleep-warning.conf`, `configure.sh`, `manage.sh`, `uninstall.sh` (Phase 2)
- **Priority**: Low (nice-to-have feature, adds complexity)
- **Status**: Phase 1 Complete (configure.sh/manage.sh blocking), Phase 2 Pending (uninstall.sh integration)
- **Feasibility Assessment**: ✅ **Highly Feasible** - Simple extension of existing time range configuration
- **Implementation Approach**:
  - **Separate Time Range Configuration**:
    - Add new config options: `CONFIG_LOCK_HOURS_SUNDAY=START-END`, `CONFIG_LOCK_HOURS_MONDAY=START-END`, etc.
    - Or use single format: `CONFIG_LOCK_HOURS=SUNDAY=START-END,MONDAY=START-END,...`
    - Reuse existing time range parsing logic from restriction hours
    - Check both restriction hours AND lock hours when determining if config should be locked
  - **Implementation Notes**:
    - **Config Format**: Reuse existing `DAY=START-END` format (same as restriction hours)
    - **Time Check Logic**: Extend `is_restricted_hour()` or create `is_lock_hour()` function
    - **Combined Check**: Config is locked if current time is in restriction hours OR lock hours
    - **Visual Grid**: Could add separate section in visual grid for lock hours (optional, Phase 2)
  - **Configuration UI**:
    - Add section in `configure.sh` for configuring lock hours
    - Can reuse existing day/time configuration wizard
    - Show clear distinction between restriction hours and lock hours
    - Optional: Show in visual grid with different color/indicator
- **Safety Assessment**:
  - **Bypass Risk**: Same as #18 and #19 (depends on implementation)
  - **Uninstall Safety**: ✅ **Safe** - Uninstall should always work regardless of lock hours
  - **Data Safety**: ✅ **Safe** - No risk of data loss
  - **System Safety**: ✅ **Safe** - No risk to system stability
  - **User Experience**: ⚠️ **Adds Complexity** - More configuration options may confuse users
- **Processing/Memory Burden**:
  - **Minimal** - Only requires additional time range check (same overhead as restriction check)
  - No additional processes or continuous monitoring
  - **Memory**: Negligible (no additional memory usage)
  - **CPU**: Negligible (additional time check is instant)
- **User Experience Considerations**:
  - **Clear Distinction**: Users should understand difference between restriction hours and lock hours
  - **Use Cases**: Useful for users who want to prevent config changes during work hours, study hours, etc.
  - **Optional Feature**: Should be optional (default: no additional lock hours)
  - **Documentation**: Clear documentation needed to explain use cases and behavior
- **Related**: 
  - Extends "Config File Locking" (#18) and "Prevent configure.sh" (#19)
  - Uses same time range configuration system as restriction hours
  - Could be integrated into Visual Day/Time Configuration Grid (#16)

---

## Phase 1: Implementation Checklist (configure.sh and manage.sh Blocking)

### Overview
Phase 1 implements additional lock hours for blocking `configure.sh` and `manage.sh` during configured lock hours (separate from restriction hours). When `CONFIGURE_BLOCK_ENABLED=true`, these scripts are blocked during restriction hours OR lock hours (OR logic).

### Files Modified

#### Core Files
- `lib/config.sh` - Added `parse_lock_hours()` function
- `lib/time-validation.sh` - Added `is_lock_hour()` and updated `check_config_lock_time()` to check lock hours
- `lib/configure-config.sh` - Added lock hours loading and saving
- `lib/configure-workflow.sh` - Added `configure_lock_hours_section()` function
- `lib/configure-input.sh` - Added `get_lock_hours_config()` function
- `lib/configure-display.sh` - Added lock hours display in visual grid
- `lib/configure-ui.sh` - Added lock hours support in error messages and grid editing
- `configure.sh` - Integrated lock hours configuration menu and time checking
- `manage.sh` - Integrated lock hours time checking
- `status.sh` - Added lock hours status display
- `sleep-warning.conf` - Added CONFIG_LOCK_HOURS documentation

---

### 1. Configuration File Support

#### 1.1 Config File Format
- [x] Add `CONFIG_LOCK_HOURS_DAYNAME=START-END` format to config file template
  - [x] Format: `CONFIG_LOCK_HOURS_SUNDAY=`, `CONFIG_LOCK_HOURS_MONDAY=`, etc.
  - [x] Support multiple ranges per day (comma-separated, e.g., `9-17,20-22`)
  - [x] Support overnight ranges (e.g., `23-6`)
  - [x] Empty values allowed (explicitly disabled: `CONFIG_LOCK_HOURS_MONDAY=`)
- [x] Add documentation comments in `sleep-warning.conf` template
  - [x] Explain format and usage
  - [x] Provide examples
  - [x] Note dependency on `CONFIGURE_BLOCK_ENABLED=true`

#### 1.2 Config Parsing Functions
- [x] Add `parse_lock_hours()` function in `lib/config.sh`
  - [x] Accept day number (0-6, Sunday=0, Saturday=6)
  - [x] Read `CONFIG_LOCK_HOURS_DAYNAME=` from config file
  - [x] Return time range string (e.g., "9-17" or "0-5,22-23")
  - [x] Return empty string if not configured or explicitly disabled
  - [x] Validate format before returning
  - [x] Handle missing config file gracefully

#### 1.3 Config Loading and Saving
- [x] Update `load_existing_config()` in `lib/configure-config.sh`
  - [x] Add `lock_hours_lines` array initialization
  - [x] Read `CONFIG_LOCK_HOURS_DAYNAME=` lines from config file
  - [x] Store in sparse array format: `lock_hours_lines[0]="CONFIG_LOCK_HOURS_SUNDAY=0-5"`
  - [x] Handle empty values correctly (explicitly disabled)
- [x] Update `write_config()` in `lib/configure-config.sh`
  - [x] Add `lock_hours_lines` array as parameter
  - [x] Write `CONFIG_LOCK_HOURS_DAYNAME=RANGE` lines to config file
  - [x] Write empty lines for explicitly disabled days
  - [x] Place after `CONFIGURE_BLOCK_ENABLED` section in config file
  - [x] Add comment header explaining the option

---

### 2. Time Check Implementation

#### 2.1 Lock Hours Check Function
- [x] Add `is_lock_hour()` function in `lib/time-validation.sh`
  - [x] Accept current hour and lock ranges (comma-separated)
  - [x] Use same logic as `is_restricted_hour()` for consistency
  - [x] Validate range format
  - [x] Check if current hour is within any lock range
  - [x] Handle empty ranges (return false)
  - [x] Support multiple ranges per day
  - [x] Support overnight ranges

#### 2.2 Update Config Lock Time Check
- [x] Update `check_config_lock_time()` in `lib/time-validation.sh`
  - [x] Check restriction hours (existing logic)
  - [x] Check lock hours using `parse_lock_hours()` and `is_lock_hour()`
  - [x] Block if current time is in restriction hours OR lock hours (OR logic)
  - [x] Handle overnight ranges from previous day for both restriction and lock hours
  - [x] Only check lock hours if `CONFIGURE_BLOCK_ENABLED=true` (dependency)

#### 2.3 Integration into Scripts
- [x] Update `configure.sh` to use `check_config_lock_time()`
  - [x] Source required modules (`lib/time-validation.sh`, `lib/config.sh`)
  - [x] Call `check_config_lock_time()` at script startup
  - [x] Show appropriate error message if blocked
- [x] Update `manage.sh` to use `check_config_lock_time()`
  - [x] Source required modules
  - [x] Call `check_config_lock_time()` at script startup
  - [x] Show appropriate error message if blocked

---

### 3. Configuration UI

#### 3.1 Menu Option
- [x] Add menu option in `configure.sh` for "Lock Hours Configuration"
  - [x] Add to main menu (option 7)
  - [x] Show status indicator (e.g., "(None)" or "(Configured)")
  - [x] Update both GUI and text mode menus
  - [x] Check if any lock hours are configured for status display

#### 3.2 Lock Hours Configuration Workflow
- [x] Create `configure_lock_hours_section()` function in `lib/configure-workflow.sh`
  - [x] Accept `use_gui` parameter and `lock_hours_lines` array (by reference)
  - [x] Show informational note about dependency on `CONFIGURE_BLOCK_ENABLED`
  - [x] Configure each day individually (Sunday-Saturday, indices 0-6)
  - [x] Reuse `get_day_hours()` function for consistent validation and UX
  - [x] Store results in `lock_hours_lines` array
  - [x] Support "skip" to disable lock hours for a day
  - [x] Support both GUI and text modes

#### 3.3 Input Function
- [x] Create `get_lock_hours_config()` function in `lib/configure-input.sh`
  - [x] Accept `use_gui` parameter
  - [x] Call `configure_lock_hours_section()` function
  - [x] Return updated `lock_hours_lines` array
  - [x] Handle cancellation

#### 3.4 Menu Handler
- [x] Add case for lock hours menu option in `configure.sh`
  - [x] Call `get_lock_hours_config()`
  - [x] Update global `lock_hours_lines` array
  - [x] Return to main menu after configuration

---

### 4. Visual Grid Integration

#### 4.1 Display Lock Hours in Grid
- [x] Extend `show_visual_grid()` in `lib/configure-display.sh`
  - [x] Add lock hours column to visual grid display
  - [x] Show restricted hours and lock hours side-by-side for each day
  - [x] Use `lock_hours_lines` array to populate lock hours column
  - [x] Show "(no lock hours)" when no lock hours are configured
  - [x] Ensure layout remains readable in both GUI and text modes

#### 4.2 Edit Lock Hours from Grid
- [x] Add ability to edit lock hours from visual grid
  - [x] When a day is selected, offer choice between editing restricted hours, lock hours, or both
  - [x] Reuse `get_day_hours()` with lock-hours-specific labels
  - [x] Support "skip" for lock hours on a per-day basis
  - [x] Preserve existing navigation behavior (back, cancel)
  - [x] Ensure changes update both `config_lines` and `lock_hours_lines` correctly

---

### 5. Status Display

#### 5.1 Status Script Integration
- [x] Update `status.sh` to display lock hours
  - [x] Add "LOCK HOURS" section header
  - [x] Display lock hours for each day (if configured)
  - [x] Show "(no lock hours configured)" if none are set
  - [x] Format hours in human-readable format (12-hour format with AM/PM)
  - [x] Show clear indication that lock hours only apply when `CONFIGURE_BLOCK_ENABLED=true`

---

### 6. Error Messages

#### 6.1 Config Locked Error Messages
- [x] Update `show_config_locked_error()` in `lib/configure-ui.sh`
  - [x] Check both restriction hours and lock hours
  - [x] Show which type of hours are active (restriction or lock)
  - [x] Display current time and when restrictions/lock hours end
  - [x] Support both GUI and text modes
  - [x] Handle overnight ranges correctly

---

### 7. Documentation

#### 7.1 User Documentation
- [x] Update `user-docs/CONFIGURATION.md`
  - [x] Document `CONFIG_LOCK_HOURS_DAYNAME` option
  - [x] Explain format and usage
  - [x] Provide examples
  - [x] Explain dependency on `CONFIGURE_BLOCK_ENABLED=true`
  - [x] Explain OR logic (restriction hours OR lock hours)
  - [x] Document configuration via wizard (menu option 7)
  - [x] Explain use cases and limitations

#### 7.2 Config File Documentation
- [x] Update `sleep-warning.conf` template
  - [x] Add comprehensive comments explaining CONFIG_LOCK_HOURS
  - [x] Show format examples
  - [x] Explain default behavior (no lock hours configured)
  - [x] Note dependency on CONFIGURE_BLOCK_ENABLED

---

### 8. Testing

#### 8.1 Recommended Tests (Not Yet Implemented)
- [ ] Test `parse_lock_hours()` function
  - [ ] Test with missing config file (should return empty string)
  - [ ] Test with configured lock hours (should return range)
  - [ ] Test with empty values (explicitly disabled, should return empty string)
  - [ ] Test with invalid day numbers (should return error)
  - [ ] Test with invalid range formats (should return empty string or error)
- [ ] Test `is_lock_hour()` function
  - [ ] Test with valid ranges and hours
  - [ ] Test with overnight ranges
  - [ ] Test with multiple ranges per day
  - [ ] Test with empty ranges (should return false)
  - [ ] Test boundary conditions (exactly at start/end of range)
- [ ] Test `check_config_lock_time()` function
  - [ ] Test when `CONFIGURE_BLOCK_ENABLED=false` (should allow execution)
  - [ ] Test when `CONFIGURE_BLOCK_ENABLED=true` and NOT in restriction/lock hours (should allow execution)
  - [ ] Test when in restriction hours only (should block)
  - [ ] Test when in lock hours only (should block)
  - [ ] Test when in both restriction and lock hours (should block)
  - [ ] Test overnight ranges from previous day
- [ ] Test configure.sh blocking
  - [ ] Set `CONFIGURE_BLOCK_ENABLED=true` and configure lock hours
  - [ ] Run `configure.sh` during lock hours (should be blocked)
  - [ ] Run `configure.sh` during restriction hours (should be blocked)
  - [ ] Run `configure.sh` outside both (should work normally)
- [ ] Test manage.sh blocking
  - [ ] Set `CONFIGURE_BLOCK_ENABLED=true` and configure lock hours
  - [ ] Run `manage.sh` during lock hours (should be blocked)
  - [ ] Run `manage.sh` during restriction hours (should be blocked)
  - [ ] Run `manage.sh` outside both (should work normally)
- [ ] Test configuration UI
  - [ ] Test lock hours configuration menu option
  - [ ] Test configuring lock hours for each day
  - [ ] Test "skip" option to disable lock hours
  - [ ] Test visual grid display of lock hours
  - [ ] Test editing lock hours from visual grid
  - [ ] Test in both GUI and text modes
- [ ] Test status display
  - [ ] Verify lock hours are displayed correctly in `status.sh`
  - [ ] Verify "(no lock hours configured)" message when none are set

---

### 9. Code Quality

#### 9.1 Code Documentation
- [x] Add header comments to new functions explaining purpose
- [x] Add inline comments for complex logic (overnight range handling)
- [x] Document function parameters and return values
- [x] Update main script headers if needed

#### 9.2 Error Handling
- [x] Ensure all file operations handle errors gracefully
- [x] Ensure config parsing handles missing/invalid values
- [x] Ensure time calculations handle edge cases
- [x] Validate range formats before use

#### 9.3 Code Consistency
- [x] Follow existing code style and patterns
- [x] Use same variable naming conventions
- [x] Use same function organization patterns
- [x] Match existing error message style

---

## Phase 2: Uninstall.sh Integration (Pending)

### Overview
Phase 2 extends the lock hours feature to also apply to `uninstall.sh` when `UNINSTALL_PROTECTION_MODE=difficult` is enabled. This allows users to configure additional lock hours (separate from restriction hours) during which uninstall requires difficult verification (confirmation phrase + arithmetic questions). This extends Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours) to also check lock hours.

### Files to Modify

#### Core Files
- `lib/time-validation.sh` - Update `check_uninstall_protection_time()` to check lock hours
- `uninstall.sh` - Already uses `check_uninstall_protection_time()`, no changes needed if function is updated
- `sleep-warning.conf` - Update documentation to mention uninstall integration
- `user-docs/CONFIGURATION.md` - Document uninstall lock hours integration

---

### 1. Time Check Implementation

#### 1.1 Update Uninstall Protection Time Check
- [ ] Update `check_uninstall_protection_time()` in `lib/time-validation.sh`
  - [ ] Currently only checks restriction hours
  - [ ] Add check for lock hours using `parse_lock_hours()` and `is_lock_hour()`
  - [ ] Return protection mode ("difficult") if in restriction hours OR lock hours (OR logic)
  - [ ] Handle overnight ranges from previous day for both restriction and lock hours
  - [ ] Only check lock hours if `UNINSTALL_PROTECTION_MODE=difficult` (dependency)
  - [ ] Maintain backward compatibility (if no lock hours configured, behavior unchanged)

#### 1.2 Integration Notes
- [ ] Verify `uninstall.sh` already sources required modules
  - [ ] Ensure `lib/config.sh` is sourced (for `parse_lock_hours()`)
  - [ ] Ensure `lib/time-validation.sh` is sourced (for `check_uninstall_protection_time()`)
- [ ] No changes needed to `uninstall.sh` main logic (already uses `check_uninstall_protection_time()`)

---

### 2. Documentation Updates

#### 2.1 User Documentation
- [ ] Update `user-docs/CONFIGURATION.md`
  - [ ] Update "Uninstall Protection During Restricted Hours" section
  - [ ] Add note that lock hours also apply to uninstall protection
  - [ ] Explain that uninstall requires verification during restriction hours OR lock hours
  - [ ] Update examples to show uninstall lock hours usage
  - [ ] Add warning about increased risk of preventing legitimate uninstall needs

#### 2.2 Config File Documentation
- [ ] Update `sleep-warning.conf` template
  - [ ] Update `CONFIG_LOCK_HOURS` section to mention uninstall integration
  - [ ] Note that lock hours apply to both configure.sh/manage.sh blocking AND uninstall protection
  - [ ] Add warning about uninstall lock hours increasing risk

#### 2.3 Enhancement Documentation
- [ ] Update this enhancement document
  - [ ] Mark Phase 2 as complete when implemented
  - [ ] Document any design decisions or implementation notes

---

### 3. Testing (Phase 2)

#### 3.1 Recommended Tests
- [ ] Test `check_uninstall_protection_time()` with lock hours
  - [ ] Test when `UNINSTALL_PROTECTION_MODE=difficult` and NOT in restriction/lock hours (should return "none")
  - [ ] Test when in restriction hours only (should return "difficult")
  - [ ] Test when in lock hours only (should return "difficult")
  - [ ] Test when in both restriction and lock hours (should return "difficult")
  - [ ] Test overnight ranges from previous day for lock hours
  - [ ] Test when `UNINSTALL_PROTECTION_MODE=none` (should return "none" regardless of lock hours)
- [ ] Test uninstall.sh with lock hours
  - [ ] Set `UNINSTALL_PROTECTION_MODE=difficult` and configure lock hours
  - [ ] Run `uninstall.sh` during lock hours (should require verification)
  - [ ] Run `uninstall.sh` during restriction hours (should require verification)
  - [ ] Run `uninstall.sh` outside both (should work normally without verification)
  - [ ] Test verification process works correctly during lock hours
- [ ] Test backward compatibility
  - [ ] Verify uninstall behavior unchanged when no lock hours configured
  - [ ] Verify uninstall behavior unchanged when `UNINSTALL_PROTECTION_MODE=none`

---

### 4. Safety Considerations

#### 4.1 Risk Assessment
- [ ] Review risk assessment for uninstall lock hours
  - [ ] Lock hours increase the risk of preventing legitimate uninstall needs
  - [ ] Users may need to uninstall during lock hours (e.g., system issues)
  - [ ] Manual uninstall guide script should still be accessible (not blocked)
- [ ] Document warnings in user documentation
  - [ ] Warn users about increased risk when enabling lock hours for uninstall
  - [ ] Recommend using lock hours only for configure.sh/manage.sh blocking (not uninstall)
  - [ ] Note that manual uninstall guide is always available as safety mechanism

---

### 5. Implementation Order Recommendation

1. **Time Check Implementation** (Section 1) - Core functionality
2. **Documentation Updates** (Section 2) - User guidance
3. **Testing** (Section 3) - Validation
4. **Safety Review** (Section 4) - Risk assessment

---

### Notes

- **Phase 1 Status**: ✅ **Complete** - Lock hours for configure.sh and manage.sh blocking are fully implemented
- **Phase 2 Status**: ⏳ **Pending** - Uninstall.sh integration not yet implemented
- **Default Behavior**: No lock hours configured by default (optional feature)
- **Dependencies**: 
  - Phase 1: Requires `CONFIGURE_BLOCK_ENABLED=true` to take effect
  - Phase 2: Requires `UNINSTALL_PROTECTION_MODE=difficult` to take effect
- **OR Logic**: Lock hours use OR logic with restriction hours - if current time is in either restriction hours OR lock hours, blocking/protection applies
- **Safety**: Lock hours for uninstall increase risk of preventing legitimate uninstall needs - should be used with caution
- **Manual Uninstall Guide**: Always accessible regardless of lock hours (safety mechanism)
