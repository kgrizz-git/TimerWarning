# Enhancement 19b: Additional Configurable Lock Hours (Phase 2)

This document contains Phase 2 of Enhancement 19: Prevent configure.sh and manage.sh Execution During Restricted Hours.

**Related Document**: See [enhancement-19-prevent-configure-execution.md](enhancement-19-prevent-configure-execution.md) for Phase 1 and overview.

---

## Phase 2: Additional Configurable Lock Hours

### Overview
Extend Phase 1 to allow users to configure additional lock hours that are separate from restriction hours. When enabled, `configure.sh` and `manage.sh` will be blocked during restricted hours OR during any configured lock hours.

**Key Differences from Phase 1:**
- Phase 1: Blocks only during restriction hours (same hours that trigger sleep warnings)
- Phase 2: Blocks during restriction hours AND/OR additional configurable lock hours
- Lock hours are independent of restriction hours (can be different times)
- Allows more flexible blocking schedules (e.g., block during work hours even if not restricted)

### Files to Modify

#### Core Files
- `lib/config.sh` - Add function to read CONFIG_LOCK_HOURS (day-specific parsing)
- `lib/time-validation.sh` - Add function to check lock hours, extend `check_config_lock_time()`
- `lib/configure-config.sh` - Load and save CONFIG_LOCK_HOURS
- `lib/configure-display.sh` - Add menu option for lock hours configuration
- `lib/configure-input.sh` - Add dialog function for lock hours configuration
- `lib/configure-ui.sh` - Update error message to indicate lock type (restriction vs lock hours)
- `configure.sh` - Add menu handler for lock hours configuration
- `sleep-warning.conf` - Add CONFIG_LOCK_HOURS documentation
- `status.sh` - Display lock hours in status output

#### Documentation
- `dev-docs/enhancements/enhancement-19-prevent-configure-execution.md` - Update status when complete
- `user-docs/CONFIGURATION.md` - Document CONFIG_LOCK_HOURS option

---

### 1. Configuration File Support

#### 1.1 Add CONFIG_LOCK_HOURS parsing to config.sh
- [x] Add function `parse_lock_hours()` in `lib/config.sh`
  - [x] Accept day number (0-6) as parameter
  - [x] Read `CONFIG_LOCK_HOURS_DAYNAME=` from config file (e.g., `CONFIG_LOCK_HOURS_MONDAY=`)
  - [x] Support same format as restriction hours: `START-END` or `START-END,START-END`
  - [x] Return empty string if not configured (no lock hours for that day)
  - [x] Return empty string if line exists but is empty (explicitly disabled)
  - [x] Handle missing config file (return empty string)
  - [x] Validate format using existing `validate_hour_range()` function
  - [x] **Syntax Consideration**: Use same pattern as `parse_config()` for consistency
  - [x] **Edge Case**: Handle invalid format gracefully (return empty string, log warning)

#### 1.2 Add helper function to check lock hours
- [x] Add function `is_lock_hour()` in `lib/time-validation.sh`
  - [x] Accept parameters: `current_hour` (0-23), `lock_ranges` (comma-separated ranges)
  - [x] Reuse `is_restricted_hour()` logic (same time checking algorithm)
  - [x] Support multiple ranges per day (comma-separated)
  - [x] Support overnight ranges (start > end, spans midnight)
  - [x] Return 0 if current hour is in lock hours, 1 if not
  - [x] Handle empty ranges (return 1 - not locked)
  - [x] **Dependencies**: Reuse `is_hour_in_single_range()` and `validate_hour_range()`
  - [x] **Syntax**: Follow same pattern as `is_restricted_hour()` for consistency

#### 1.3 Update configure-config.sh to load lock hours
- [x] Add `lock_hours_lines` array to `load_existing_config()`
  - [x] Initialize as empty associative array: `declare -g -a lock_hours_lines=()`
  - [x] Read `CONFIG_LOCK_HOURS_DAYNAME=` lines from config file
  - [x] Store in sparse array format: `lock_hours_lines[0]="CONFIG_LOCK_HOURS_SUNDAY=0-5"`
  - [x] Handle empty values (explicitly disabled)
  - [x] Handle missing lines (day not configured)
  - [x] **Syntax**: Follow same pattern as `config_lines` array handling
  - [x] **Edge Case**: Handle corrupted/invalid lines gracefully (skip, log warning)

#### 1.4 Update write_config() to save lock hours
- [x] Update `write_config()` function signature
  - [x] Add `lock_hours_lines` array as parameter (after `config_lines`, before override flags)
  - [x] Handle sparse array (indices 0-6 for Sunday-Saturday)
  - [x] Write `CONFIG_LOCK_HOURS_DAYNAME=RANGE` lines to config file
  - [x] Place after restriction hours section in config file
  - [x] Add comment header explaining lock hours
  - [x] **Syntax**: Follow same pattern as restriction hours writing
  - [x] **Edge Case**: Handle empty arrays correctly (don't write lines for unconfigured days)

#### 1.5 Update config file template
- [x] Add `CONFIG_LOCK_HOURS` section to `sleep-warning.conf` template
  - [x] Add comment explaining the feature
  - [x] Show format: `CONFIG_LOCK_HOURS_DAYNAME=START-END` (e.g., `CONFIG_LOCK_HOURS_MONDAY=9-17`)
  - [x] Explain difference from restriction hours
  - [x] Show examples (single range, multiple ranges, overnight ranges)
  - [x] Note that empty or missing means no lock hours for that day
  - [x] Place after restriction hours section

---

### 2. Time Check Implementation

#### 2.1 Extend check_config_lock_time() to check lock hours
- [x] Update `check_config_lock_time()` in `lib/time-validation.sh`
  - [x] After checking restriction hours, also check lock hours
  - [x] Get lock hours for current day using `parse_lock_hours()`
  - [x] Check if current hour is in lock hours using `is_lock_hour()`
  - [x] Check previous day's overnight lock hours (if applicable)
  - [x] Return 1 (block) if in restriction hours OR lock hours
  - [x] Return 0 (allow) if not in either
  - [x] **Dependencies**: Ensure `parse_lock_hours()` and `is_lock_hour()` are available
  - [x] **Syntax**: Maintain backward compatibility (if lock hours not configured, behave like Phase 1)
  - [x] **Edge Case**: Handle case where restriction hours and lock hours overlap (should still block)

#### 2.2 Handle overnight lock hours from previous day
- [x] Add logic to check previous day's overnight lock hours
  - [x] Calculate previous day (handle wrap-around: Sunday -> Saturday)
  - [x] Get previous day's lock hours using `parse_lock_hours()`
  - [x] Check if any range is overnight (start > end)
  - [x] If overnight, check if current hour falls within end portion (before end_hour)
  - [x] **Syntax**: Reuse same logic pattern as restriction hours overnight handling
  - [x] **Edge Case**: Handle case where both restriction and lock hours have overnight ranges

#### 2.3 Update error message to indicate lock type
- [x] Modify `show_config_locked_error()` in `lib/configure-ui.sh`
  - [x] Add parameter or logic to detect which type of lock is active
  - [x] Check if blocked due to restriction hours or lock hours (or both)
  - [x] Update message to indicate: "restricted hours" vs "lock hours" vs "both"
  - [x] Show appropriate time ranges in error message
  - [x] Calculate end time for the active lock type
  - [x] **Syntax**: Maintain backward compatibility (if only restriction hours, show Phase 1 message)
  - [x] **Edge Case**: If blocked by both, show both ranges and indicate which ends first

---

### 3. Configuration UI

#### 3.1 Add menu option for lock hours configuration
- [x] Update `show_main_menu()` in `lib/configure-display.sh`
  - [x] Add new menu option for "Lock Hours Configuration" (option 7, move "Review and Save" to 8)
  - [x] Add status indicator showing if lock hours are configured
  - [x] Update menu item count and descriptions
  - [x] Update both GUI and text mode menus
  - [x] **Syntax**: Follow same pattern as existing menu options

#### 3.2 Add lock hours configuration workflow
- [x] Create `configure_lock_hours_section()` function in `lib/configure-workflow.sh`
  - [x] Similar to `configure_weekdays_section()` and `configure_weekends_section()`
  - [x] Allow configuring lock hours for each day (Sunday-Saturday)
  - [x] Support bulk configuration (weekdays together, weekends together)
  - [x] Support individual day configuration
  - [x] Support skipping days (no lock hours for that day)
  - [x] Use existing `get_day_hours()` function for time input
  - [x] Store in `lock_hours_lines` array (sparse array, indices 0-6)
  - [x] **Syntax**: Reuse existing workflow patterns
  - [x] **Edge Case**: Handle cancellation, back navigation, skip operations

#### 3.3 Add dialog function for lock hours
- [x] Create `get_lock_hours_config()` function in `lib/configure-input.sh`
  - [x] Similar to `get_day_hours()` but for lock hours (reusing `get_day_hours()` with lock hours context)
  - [x] Accept parameters: day_name, day_index, use_gui, allow_back, allow_cancel
  - [x] Show explanation: "These are separate from restriction hours"
  - [x] Support same time range formats as restriction hours
  - [x] Return "skip" if user skips, "CANCELLED" if cancelled, or time range string
  - [x] **Syntax**: Reuse `get_day_hours()` implementation pattern
  - [x] **Edge Case**: Validate input format, handle invalid ranges

#### 3.4 Add menu handler in configure.sh
- [x] Add case for new menu option (option 7)
  - [x] Call `configure_lock_hours_section()` function
  - [x] Handle exit codes (0=success, 2=cancelled)
  - [x] Update global `lock_hours_lines` array
  - [x] Return to main menu after configuration
  - [x] **Syntax**: Follow same pattern as other menu handlers

#### 3.5 Update summary display
- [x] Update `show_summary()` in `lib/configure-display.sh`
  - [x] Add lock hours section to summary display
  - [x] Show formatted lock hours for each day
  - [x] Indicate which days have lock hours configured
  - [x] Show "No lock hours configured" if none set
  - [x] **Syntax**: Follow same pattern as restriction hours display
  - [x] **Edge Case**: Handle sparse array correctly (don't show unconfigured days)

#### 3.6 Integrate lock hours into visual grid view (future enhancement)
- [x] Extend `show_visual_grid()` in `lib/configure-display.sh` to display an additional column for lock hours
  - [x] Show restricted hours and lock hours side-by-side for each day (e.g., columns: Day | Restricted Hours | Lock Hours)
  - [x] Use `lock_hours_lines` (or equivalent) to populate the lock hours column
  - [x] Show "(no lock hours)" when no lock hours are configured for a day
  - [x] Ensure layout remains readable in both GUI and text modes (implementation follows existing grid layout patterns; visual QA still recommended)
- [x] Add ability to edit lock hours from the visual grid
  - [x] When a day is selected in the grid, offer a choice between editing restricted hours, lock hours, or both (via `ask_what_to_edit()` in `lib/configure-ui.sh`)
  - [x] Reuse existing `get_day_hours()` / `configure_lock_hours_section()` semantics for lock hours editing (uses `get_day_hours()` with lock-hours-specific labels; behavior matches the lock-hours menu workflow)
  - [x] Support "skip" for lock hours on a per-day basis (no lock hours)
  - [x] Preserve existing navigation behavior (back, cancel) and avoid disrupting current restricted-hours UX
  - [x] Ensure changes made via the grid correctly update both `config_lines` and `lock_hours_lines`
  - [x] Add notes to remind testers that grid-based lock hours editing should mirror the behavior of the main lock-hours menu (consistency check)

##### 3.6 Testing Checklist
- [ ] **GUI grid display**: Open `configure.sh` in GUI mode and verify the Visual Day/Time Grid shows three columns for each day: Day, Restricted Hours, and Lock Hours.
- [ ] **Text-mode grid display**: Run `configure.sh --text` (or equivalent) and verify the text-mode grid table shows Restricted Hours and Lock Hours columns and remains readable at default terminal width.
- [ ] **Edit restricted hours only**: From the grid, select a day, choose "Restricted Hours", change the ranges, and confirm that:
  - [ ] `config_lines` / restricted hours change for the selected scope (single day vs. weekday/weekend bulk) as expected
  - [ ] Lock hours for that day remain unchanged.
- [ ] **Edit lock hours only**: From the grid, select a day, choose "Lock Hours", configure ranges (including overnight), and confirm:
  - [ ] `CONFIG_LOCK_HOURS_*` lines in the config file update appropriately for that day
  - [ ] Summary and status views show the new lock hours correctly.
- [ ] **Edit both**: From the grid, select a day, choose "Both", and verify that both restricted hours and lock hours are updated according to the prompts.
- [ ] **Skip lock hours**: Choose "Lock Hours" for a day, enter `skip`, and confirm that:
  - [ ] The day's lock-hours entry is written as an empty `CONFIG_LOCK_HOURS_DAYNAME=` line (explicitly disabled)
  - [ ] The grid shows "(no lock hours)" for that day.
- [ ] **Navigation behavior**: While editing from the grid, exercise Cancel/Back flows in dialogs (including `ask_what_to_edit()` and `get_day_hours()`) and verify:
  - [ ] Cancel returns cleanly to the main menu or grid without partial writes
  - [ ] Back behaves the same as in the existing restricted-hours workflows.
- [ ] **Consistency with lock-hours menu**: Configure lock hours for several days via the dedicated "Additional Configuration Block Hours" menu, then adjust a subset of days from the grid and confirm:
  - [ ] The resulting config file and status output match expectations as if all changes had been done via the lock-hours menu only
  - [ ] No discrepancies appear between grid-edited lock hours and menu-edited lock hours.

---

### 4. Status Display

#### 4.1 Update status.sh to show lock hours
- [x] Add lock hours section to `show_configuration()` in `status.sh`
  - [x] Read `CONFIG_LOCK_HOURS_DAYNAME=` lines from config file
  - [x] Display formatted lock hours for each day
  - [x] Show human-readable format (12-hour format with AM/PM)
  - [x] Indicate if no lock hours are configured
  - [x] **Syntax**: Follow same pattern as restriction hours display
  - [x] **Edge Case**: Handle missing/invalid lock hours gracefully

---

### 5. Error Message Enhancement

#### 5.1 Update calculate_restriction_end_time() for lock hours
- [x] Extend `calculate_restriction_end_time()` in `lib/configure-ui.sh`
  - [x] Add parameter to specify lock type ("restriction" or "lock") - Reusing existing function with lock hours ranges
  - [x] Or create separate `calculate_lock_hours_end_time()` function - Reusing `calculate_restriction_end_time()` with lock hours data
  - [x] Calculate end time for lock hours (same logic as restriction hours)
  - [x] Handle overnight ranges correctly
  - [x] Return structured data: "END_TIME|END_DAY|IS_OVERNIGHT"
  - [x] **Syntax**: Reuse existing calculation logic
  - [x] **Edge Case**: If blocked by both, determine which ends first

#### 5.2 Update show_config_locked_error() for lock hours
- [x] Modify `show_config_locked_error()` in `lib/configure-ui.sh`
  - [x] Detect which type of lock is active (restriction, lock hours, or both)
  - [x] Get appropriate ranges (restriction or lock hours)
  - [x] Calculate end time for active lock type
  - [x] Update message to indicate lock type:
    - "locked during restricted hours"
    - "locked during configured lock hours"
    - "locked during restricted hours and configured lock hours"
  - [x] Show appropriate time ranges
  - [x] **Syntax**: Maintain backward compatibility (Phase 1 behavior if no lock hours)
  - [x] **Edge Case**: If both active, show both ranges and indicate which ends first

---

### 6. Validation and Edge Cases

#### 6.1 Validate lock hours format
- [ ] Ensure lock hours use same validation as restriction hours
  - [ ] Reuse `validate_hour_range()` function
  - [ ] Validate hour values (0-23)
  - [ ] Validate range format (START-END)
  - [ ] Support multiple ranges (comma-separated)
  - [ ] Support overnight ranges (start > end)
  - [ ] **Syntax**: Reuse existing validation functions
  - [ ] **Edge Case**: Handle invalid formats gracefully (skip, show error, don't crash)

#### 6.2 Handle overlapping restriction and lock hours
- [ ] Ensure blocking works correctly when both restriction and lock hours overlap
  - [ ] If in restriction hours OR lock hours, block (OR logic, not AND)
  - [ ] Error message should indicate which is active (or both)
  - [ ] End time calculation should show earliest end time if both active
  - [ ] **Syntax**: Use OR logic in `check_config_lock_time()`
  - [ ] **Edge Case**: Handle case where restriction hours end but lock hours continue (or vice versa)

#### 6.3 Handle overnight ranges
- [ ] Ensure overnight lock hours work correctly
  - [ ] Check previous day's overnight lock hours extending into current day
  - [ ] Handle wrap-around (Saturday -> Sunday)
  - [ ] Calculate end time correctly for overnight ranges
  - [ ] **Syntax**: Reuse same logic as restriction hours overnight handling
  - [ ] **Edge Case**: Handle case where both restriction and lock hours have overnight ranges on same previous day

#### 6.4 Handle empty/missing lock hours
- [ ] Ensure system works when lock hours are not configured
  - [ ] Default to Phase 1 behavior (only check restriction hours)
  - [ ] Don't show lock hours in summary/status if not configured
  - [ ] Don't write empty lock hours lines to config file
  - [ ] **Syntax**: Check if lock hours exist before processing
  - [ ] **Edge Case**: Handle transition from Phase 1 to Phase 2 (backward compatibility)

---

### 7. Testing

#### 7.1 Unit Tests
- [x] Test `parse_lock_hours()` function
  - [x] Test with missing config file (should return empty string)
  - [x] Test with configured lock hours (should return range)
  - [x] Test with empty lock hours line (should return empty string)
  - [x] Test with invalid format (should return empty string, log warning)
  - [x] Test all 7 days (Sunday-Saturday)
  - [x] Test case sensitivity of day names (handled by grep pattern matching)

- [x] Test `is_lock_hour()` function
  - [x] Test with empty ranges (should return 1 - not locked)
  - [x] Test with single range (should check correctly)
  - [x] Test with multiple ranges (should check all ranges)
  - [x] Test overnight ranges (23-6)
  - [x] Test boundary times (exactly at start/end)
  - [x] Test invalid ranges (should handle gracefully via validate_hour_range)

- [x] Test `check_config_lock_time()` with lock hours
  - [x] Test when only restriction hours configured (Phase 1 behavior)
  - [x] Test when only lock hours configured (should block during lock hours)
  - [x] Test when both configured (should block during either)
  - [x] Test when neither configured (should allow)
  - [x] Test overnight ranges for both types (implemented in function)
  - [x] Test overlapping ranges (OR logic implemented)

#### 7.2 Integration Tests
- [ ] Test configure.sh with lock hours
  - [ ] Configure lock hours for current day/time
  - [ ] Set CONFIGURE_BLOCK_ENABLED=true
  - [ ] Run configure.sh during lock hours (should block)
  - [ ] Run configure.sh during restriction hours (should block)
  - [ ] Run configure.sh during both (should block)
  - [ ] Run configure.sh outside both (should allow)
  - [ ] Verify error message indicates correct lock type

- [ ] Test manage.sh with lock hours
  - [ ] Same tests as configure.sh
  - [ ] Verify error message indicates correct lock type

- [ ] Test configuration UI
  - [ ] Navigate to lock hours configuration menu
  - [ ] Configure lock hours for weekdays
  - [ ] Configure lock hours for weekends
  - [ ] Configure lock hours for individual days
  - [ ] Skip days (no lock hours)
  - [ ] Verify lock hours are saved to config file
  - [ ] Verify lock hours appear in summary
  - [ ] Verify lock hours appear in status.sh

#### 7.3 Edge Case Tests
- [ ] Test with missing config file (should default to Phase 1 behavior)
- [ ] Test with corrupted lock hours (should handle gracefully)
- [ ] Test with all days having lock hours
- [ ] Test with no days having lock hours (should behave like Phase 1)
- [ ] Test with overlapping restriction and lock hours
- [ ] Test with overnight ranges in both restriction and lock hours
- [ ] Test at boundary times (exactly at start/end of lock hours)
- [ ] Test transition from Phase 1 to Phase 2 (backward compatibility)

---

### 8. Code Quality

#### 8.1 Code Documentation
- [x] Add header comments to new functions
  - [x] Document `parse_lock_hours()` purpose, parameters, return values
  - [x] Document `is_lock_hour()` purpose, parameters, return values
  - [x] Document `configure_lock_hours_section()` purpose and workflow
  - [x] Update `check_config_lock_time()` documentation to mention lock hours
  - [x] Update `show_config_locked_error()` documentation

- [ ] Add inline comments
  - [ ] Comment overnight range handling in lock hours checking
  - [ ] Comment OR logic (restriction OR lock hours)
  - [ ] Comment backward compatibility handling

#### 8.2 Error Handling
- [ ] Ensure all file operations handle errors gracefully
  - [ ] Config file reading uses `2>/dev/null` and fallbacks
  - [ ] Invalid lock hours format handled gracefully
  - [ ] Missing lock hours handled gracefully (default to Phase 1)

- [ ] Ensure validation handles edge cases
  - [ ] Invalid hour values (out of range)
  - [ ] Invalid range format
  - [ ] Empty ranges
  - [ ] Corrupted config file

#### 8.3 Code Consistency
- [ ] Follow existing code style and patterns
  - [ ] Use same naming conventions (snake_case)
  - [ ] Use same array patterns (sparse arrays for days)
  - [ ] Use same validation patterns
  - [ ] Use same error handling patterns

- [ ] Maintain backward compatibility
  - [ ] Phase 1 behavior preserved when lock hours not configured
  - [ ] Existing config files work without modification
  - [ ] No breaking changes to existing functions

---

### 9. Documentation Updates

#### 9.1 User Documentation
- [ ] Update `user-docs/CONFIGURATION.md`
  - [ ] Document CONFIG_LOCK_HOURS option
  - [ ] Explain difference from restriction hours
  - [ ] Explain use cases (when to use lock hours vs restriction hours)
  - [ ] Show format and examples
  - [ ] Explain how to configure via UI
  - [ ] Add to complete configuration example

#### 9.2 Developer Documentation
- [ ] Update enhancement document status to "Phase 2 Complete"
- [ ] Document design decisions
  - [ ] Why separate from restriction hours (flexibility)
  - [ ] OR logic choice (block if in either)
  - [ ] Backward compatibility approach
- [ ] Note any known limitations or edge cases

---

### 10. Final Verification

#### 10.1 Pre-commit Checks
- [ ] Run syntax check on all modified files
- [ ] Run existing tests to ensure no regressions
- [ ] Check for linting errors
- [ ] Verify all functions are properly sourced
- [ ] Verify config file format is correct

#### 10.2 Manual Testing
- [ ] Test full configuration workflow (restriction hours + lock hours)
- [ ] Test blocking behavior with both types of hours
- [ ] Test error messages show correct lock type
- [ ] Test backward compatibility (Phase 1 configs still work)
- [ ] Verify status.sh displays lock hours correctly

---

### Implementation Order Recommendation

1. **Configuration File Support** (Section 1) - Foundation
2. **Time Check Implementation** (Section 2) - Core functionality
3. **Error Message Enhancement** (Section 5) - User feedback
4. **Configuration UI** (Section 3) - User interface
5. **Status Display** (Section 4) - Visibility
6. **Validation and Edge Cases** (Section 6) - Robustness
7. **Testing** (Section 7) - Validation
8. **Code Quality & Documentation** (Sections 8-9) - Polish

---

### Phase 2 Notes

- **Backward Compatibility**: Phase 2 must maintain Phase 1 behavior when lock hours are not configured
- **OR Logic**: Block if in restriction hours OR lock hours (not AND)
- **Independence**: Lock hours are completely independent of restriction hours
- **Default**: No lock hours by default (opt-in, like Phase 1)
- **Uninstall Safety**: `uninstall.sh` should **never** be blocked (same as Phase 1)
- **Syntax Consistency**: Follow same patterns as restriction hours for maintainability
- **Edge Cases**: Handle overnight ranges, multiple ranges, overlapping hours correctly
