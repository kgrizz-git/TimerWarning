# Enhancement 26b: Additional Uninstall Lock Hours (Phase 2)

This document contains Phase 2 of Enhancement 26: Prevent uninstall.sh Execution During Restricted Hours.

**Related Document**: See [enhancement-26-prevent-uninstall-during-restricted-hours.md](enhancement-26-prevent-uninstall-during-restricted-hours.md) for Phase 1 and overview.

---

## Phase 2: Additional Uninstall Lock Hours

### Overview
Phase 2 extends Phase 1 to allow users to configure additional hours (separate from restriction hours and configure.sh lock hours) during which difficult uninstall verification is required. This creates a dedicated schedule specifically for uninstall protection using new configuration variables (`UNINSTALL_LOCK_HOURS_DAYNAME`). Uninstall lock hours are independent of restriction hours and configure.sh lock hours, providing clear separation of concerns.

### Files to Modify

#### Core Files
- `lib/config.sh` - Add functions to parse `UNINSTALL_LOCK_HOURS_DAYNAME` variables
- `lib/time-validation.sh` - Add function to check uninstall lock hours, update `check_uninstall_protection_time()`
- `lib/configure-config.sh` - Load and save uninstall lock hours configuration
- `lib/configure-display.sh` - Add uninstall lock hours column to visual grid view
- `lib/configure-workflow.sh` - Add workflow for configuring uninstall lock hours (per-day and weekday/weekend bulk setting)
- `lib/configure-ui.sh` - Add UI functions for configuring uninstall lock hours
- `configure.sh` - Add menu option for uninstall lock hours configuration
- `status.sh` - Display uninstall lock hours in status output
- `sleep-warning.conf` - Add `UNINSTALL_LOCK_HOURS_DAYNAME` documentation
- `uninstall.sh` - Already uses `check_uninstall_protection_time()`, will automatically check uninstall lock hours once function is updated

#### Documentation
- `dev-docs/enhancements/enhancement-26-prevent-uninstall-during-restricted-hours.md` - Update status when complete
- `user-docs/CONFIGURATION.md` - Document `UNINSTALL_LOCK_HOURS_DAYNAME` option
- `user-docs/USER_GUIDE.md` - Document uninstall lock hours feature

---

### 1. Configuration File Support

#### 1.1 Add Uninstall Lock Hours Parsing Functions
- [ ] Add `parse_uninstall_lock_hours()` function to `lib/config.sh`
  - [ ] Accept day index (0=Sunday, 6=Saturday) or day name
  - [ ] Read `UNINSTALL_LOCK_HOURS_DAYNAME` from config file (e.g., `UNINSTALL_LOCK_HOURS_MONDAY=9-17`)
  - [ ] Return time range string (same format as restriction hours)
  - [ ] Return empty string if not configured or day name not found
  - [ ] Handle case-insensitive day name matching
  - [ ] Validate format (same validation as restriction hours)

#### 1.2 Add Uninstall Lock Hours Check Function
- [ ] Add `is_uninstall_lock_hour()` function to `lib/time-validation.sh`
  - [ ] Accept current hour and uninstall lock hours range string
  - [ ] Use same logic as `is_restricted_hour()` for consistency
  - [ ] Support multiple ranges per day (comma-separated)
  - [ ] Support overnight ranges (e.g., 23-6)
  - [ ] Return 0 if hour is in uninstall lock hours, 1 otherwise

#### 1.3 Update Uninstall Protection Time Check
- [ ] Update `check_uninstall_protection_time()` in `lib/time-validation.sh`
  - [ ] After checking restriction hours, also check uninstall lock hours
  - [ ] Use `parse_uninstall_lock_hours()` to get current day's uninstall lock hours
  - [ ] Use `is_uninstall_lock_hour()` to check if current hour is in uninstall lock hours
  - [ ] Return protection mode ("difficult") if in restriction hours OR uninstall lock hours (OR logic)
  - [ ] Handle overnight ranges from previous day for uninstall lock hours (same logic as restriction hours)
  - [ ] Only check uninstall lock hours if `UNINSTALL_PROTECTION_MODE=difficult` (dependency)

---

### 2. Configuration UI - Uninstall Lock Hours

#### 2.1 Add Uninstall Lock Hours to configure-config.sh
- [ ] Add `uninstall_lock_hours_lines` array to global variables in `load_existing_config()`
  - [ ] Initialize array with 7 elements (one per day, indices 0-6)
  - [ ] Read existing `UNINSTALL_LOCK_HOURS_DAYNAME` values from config file
  - [ ] Store in format: `UNINSTALL_LOCK_HOURS_DAYNAME=RANGE` (e.g., `UNINSTALL_LOCK_HOURS_MONDAY=9-17`)
- [ ] Update `write_config()` function signature
  - [ ] Add `uninstall_lock_hours_lines` array as parameter
  - [ ] Write `UNINSTALL_LOCK_HOURS_DAYNAME` lines to config file
  - [ ] Add comment header explaining uninstall lock hours
  - [ ] Place after `UNINSTALL_PROTECTION_MODE` section in config file

#### 2.2 Add Menu Option for Uninstall Lock Hours
- [ ] Update `show_main_menu()` in `lib/configure-display.sh`
  - [ ] Add new menu option: "Uninstall Lock Hours Configuration" (or similar)
  - [ ] Show status indicator if uninstall lock hours are configured
  - [ ] Update both GUI and text mode menus

#### 2.3 Add Uninstall Lock Hours Configuration Workflow
- [ ] Create `configure_uninstall_lock_hours_section()` function in `lib/configure-workflow.sh`
  - [ ] Similar to `configure_lock_hours_section()` but for uninstall lock hours
  - [ ] Configure each day individually (Sunday-Saturday, indices 0-6)
  - [ ] Reuse `get_day_hours()` for consistent validation and UX
  - [ ] Support weekday/weekend bulk setting (similar to restriction hours)
  - [ ] Update `uninstall_lock_hours_lines` array by reference

#### 2.4 Add Uninstall Lock Hours to Visual Grid View
- [ ] Update `show_visual_grid()` in `lib/configure-display.sh`
  - [ ] Add fourth column: "Uninstall Lock Hours" (Day | Restricted Hours | Lock Hours | Uninstall Lock Hours)
  - [ ] Populate column from `uninstall_lock_hours_lines` array
  - [ ] Show "(no uninstall lock hours)" when not configured
  - [ ] Ensure layout remains readable in both GUI and text modes
- [ ] Update `configure_day_from_grid()` in `lib/configure-workflow.sh`
  - [ ] Add `uninstall_lock_hours_lines` parameter (pass by reference)
  - [ ] Update `ask_what_to_edit()` to include "Uninstall Lock Hours" option
  - [ ] Allow editing restricted hours, lock hours, uninstall lock hours, or combinations
  - [ ] Reuse `get_day_hours()` for uninstall lock hours editing with appropriate labels

#### 2.5 Add Menu Handler to configure.sh
- [ ] Add case for uninstall lock hours menu option
  - [ ] Call `configure_uninstall_lock_hours_section()`
  - [ ] Handle cancellation (return to main menu)
  - [ ] Update global `uninstall_lock_hours_lines` array
  - [ ] Return to main menu after configuration

---

### 3. Status Display Integration

#### 3.1 Add Uninstall Lock Hours to status.sh
- [ ] Update status display to show uninstall lock hours
  - [ ] Display uninstall lock hours for each day (if configured)
  - [ ] Show format similar to restriction hours and lock hours
  - [ ] Indicate when uninstall lock hours are active (if current time is in uninstall lock hours)
  - [ ] Show in status summary section

---

### 4. Documentation Updates

#### 4.1 User Documentation
- [ ] Update `user-docs/CONFIGURATION.md`
  - [ ] Add section: "Uninstall Lock Hours Configuration"
  - [ ] Document `UNINSTALL_LOCK_HOURS_DAYNAME` format and usage
  - [ ] Explain that uninstall lock hours are separate from restriction hours and configure.sh lock hours
  - [ ] Explain OR logic: difficult uninstall applies during restriction hours OR uninstall lock hours
  - [ ] Add examples of uninstall lock hours configuration
  - [ ] Add warning about increased risk of preventing legitimate uninstall needs
- [ ] Update `user-docs/USER_GUIDE.md`
  - [ ] Document uninstall lock hours feature
  - [ ] Explain how to configure via configure.sh menu
  - [ ] Explain visual grid integration

#### 4.2 Config File Documentation
- [ ] Update `sleep-warning.conf` template
  - [ ] Add `UNINSTALL_LOCK_HOURS_DAYNAME` section with documentation
  - [ ] Explain format, examples, and usage
  - [ ] Note that it requires `UNINSTALL_PROTECTION_MODE=difficult` to take effect
  - [ ] Add warning about increased risk

#### 4.3 Enhancement Documentation
- [ ] Update this enhancement document
  - [ ] Mark Phase 2 as complete when implemented
  - [ ] Document any design decisions or implementation notes

---

### 5. Testing (Phase 2)

#### 5.1 Unit Tests
- [ ] Test `parse_uninstall_lock_hours()` function
  - [ ] Test with valid day names and indices
  - [ ] Test with missing config (should return empty string)
  - [ ] Test with invalid day names (should return empty string)
  - [ ] Test case-insensitive day name matching
- [ ] Test `is_uninstall_lock_hour()` function
  - [ ] Test with single range
  - [ ] Test with multiple ranges
  - [ ] Test with overnight ranges
  - [ ] Test with empty ranges (should return false)
- [ ] Test `check_uninstall_protection_time()` with uninstall lock hours
  - [ ] Test when NOT in restriction/uninstall lock hours (should return "none")
  - [ ] Test when in restriction hours only (should return "difficult")
  - [ ] Test when in uninstall lock hours only (should return "difficult")
  - [ ] Test when in both restriction and uninstall lock hours (should return "difficult")
  - [ ] Test overnight ranges from previous day for uninstall lock hours
  - [ ] Test when `UNINSTALL_PROTECTION_MODE=none` (should return "none" regardless of uninstall lock hours)

#### 5.2 Integration Tests
- [ ] Test uninstall.sh with uninstall lock hours
  - [ ] Set `UNINSTALL_PROTECTION_MODE=difficult` and configure uninstall lock hours
  - [ ] Run `uninstall.sh` during uninstall lock hours (should require verification)
  - [ ] Run `uninstall.sh` during restriction hours (should require verification)
  - [ ] Run `uninstall.sh` outside both (should work normally without verification)
  - [ ] Test verification process works correctly during uninstall lock hours
- [ ] Test configuration UI
  - [ ] Test uninstall lock hours menu option
  - [ ] Test per-day configuration
  - [ ] Test weekday/weekend bulk setting
  - [ ] Test visual grid integration (fourth column)
  - [ ] Test editing uninstall lock hours from grid
  - [ ] Verify uninstall lock hours are saved to config file correctly
- [ ] Test status.sh display
  - [ ] Verify uninstall lock hours are shown in status output
  - [ ] Verify active status when current time is in uninstall lock hours

#### 5.3 Edge Cases
- [ ] Test with missing config file (should default to no uninstall lock hours)
- [ ] Test with corrupted config file (should handle gracefully)
- [ ] Test at boundary times (exactly at start/end of uninstall lock hours)
- [ ] Test with all days having uninstall lock hours
- [ ] Test with no days having uninstall lock hours (should behave like Phase 1)
- [ ] Test with system time changes (if possible)
- [ ] Test backward compatibility (Phase 1 behavior unchanged when no uninstall lock hours configured)

---

### 6. Implementation Order Recommendation

1. **Configuration File Support** (Section 1) - Foundation (parsing and checking functions)
2. **Configuration UI** (Section 2) - User interface for configuring uninstall lock hours
3. **Status Display Integration** (Section 3) - Show uninstall lock hours in status
4. **Documentation Updates** (Section 4) - User guidance
5. **Testing** (Section 5) - Validation

---

### Notes

- **Phase 1 Status**: ✅ **Mostly Complete** - Core functionality implemented, testing and user docs pending
- **Phase 2 Status**: ⏳ **Pending** - Not yet implemented
- **Default Behavior**: No uninstall lock hours configured by default (optional feature)
- **Dependencies**: 
  - Requires `UNINSTALL_PROTECTION_MODE=difficult` to take effect
  - Independent of `CONFIGURE_BLOCK_ENABLED` and `CONFIG_LOCK_HOURS`
- **OR Logic**: Uninstall lock hours use OR logic with restriction hours - if current time is in either restriction hours OR uninstall lock hours, difficult uninstall verification applies
- **Separation of Concerns**: Uninstall lock hours are separate from configure.sh lock hours (`CONFIG_LOCK_HOURS`) to provide clear separation and independent configuration
- **UI Integration**: Uninstall lock hours appear as a fourth column in the visual grid view (Day | Restricted Hours | Lock Hours | Uninstall Lock Hours)
- **Configuration Methods**: 
  - Per-day configuration (similar to restriction hours)
  - Weekday/weekend bulk setting (similar to restriction hours)
  - Visual grid editing (select day, choose to edit uninstall lock hours)
- **Safety**: Uninstall lock hours increase risk of preventing legitimate uninstall needs - should be used with caution
- **Manual Uninstall Guide**: Always accessible regardless of uninstall lock hours (safety mechanism)
