# Refactor Assessment - 2026-01-21 15:08:49

## Assessment Date
- **Date**: 2026-01-21
- **Time**: 15:08:49
- **Assessor**: AI Agent

## Files Analyzed

### Summary Table

| File | Location | Line Count | Exceeds Threshold | Status |
|------|----------|------------|-------------------|--------|
| configure-input.sh | lib/ | 1279 | Yes | Analyzed |
| configure-ui.sh | lib/ | 916 | Yes | Analyzed |
| popup-display.sh | lib/ | 797 | Yes | Analyzed |
| configure-display.sh | lib/ | 780 | Yes | Analyzed |
| install.sh | root | 704 | No | Not analyzed |
| window-management.sh | lib/ | 570 | No | Not analyzed |
| status.sh | root | 557 | No | Not analyzed |
| manage.sh | root | 529 | No | Not analyzed |
| uninstall-verification.sh | lib/ | 520 | No | Not analyzed |
| configure-config.sh | lib/ | 503 | No | Not analyzed |

## Detailed Analysis

### File: configure-input.sh

**Location**: `lib/configure-input.sh`  
**Line Count**: 1279  
**Exceeds Threshold**: Yes

#### Function Inventory
- `get_hour_zenity()` (lines 31-57): Get hour input using dialog tool (legacy name)
- `get_hour_text()` (lines 60-75): Get hour input using text prompt
- `get_popup_size_config()` (lines 78-136): Get popup size from user
- `get_min_display_time_config()` (lines 139-197): Get minimum display time
- `get_popup_immovable_config()` (lines 200-281): Get immovable setting
- `get_configure_block_enabled_config()` (lines 305-384): Get configure block enabled setting (Enhancement #19)
- `get_uninstall_protection_mode_config()` (lines 401-500): Get uninstall protection mode configuration (Enhancement #26)
- `get_popup_position_config()` (lines 503-568): Get popup position
- `get_check_interval()` (lines 571-639): Get check interval
- `calculate_range_duration()` (lines 653-673): Calculate duration in hours of a single time range
- `calculate_total_day_duration()` (lines 693-766): Calculate total duration for a day including overnight from previous day
- `get_day_hours()` (lines 769-1279): Get time ranges for a day (complex with navigation) - **510 lines**

#### Function Groupings
- **Group 1 - Simple Input Functions** (lines 31-639): `get_hour_zenity`, `get_hour_text`, `get_popup_size_config`, `get_min_display_time_config`, `get_popup_immovable_config`, `get_configure_block_enabled_config`, `get_uninstall_protection_mode_config`, `get_popup_position_config`, `get_check_interval`
  - All follow similar pattern: GUI/text mode branching, validation, default value handling
  - Total: ~608 lines
  
- **Group 2 - Time Calculation Functions** (lines 641-766): `calculate_range_duration`, `calculate_total_day_duration`
  - Pure calculation functions, no UI
  - Total: ~125 lines
  
- **Group 3 - Complex Day Hours Input** (lines 769-1279): `get_day_hours`
  - Complex function with extensive validation, navigation, warnings, overnight range handling
  - Total: ~510 lines

#### Dependencies
- **Depends on**: 
  - `lib/configure-core.sh` (for `has_dialog_tool`, `CONFIG_FILE`)
  - `lib/configure-dialogs.sh` (for dialog abstraction functions: `show_entry_dialog`, `show_list_dialog`, `show_info_dialog`, `show_question_dialog`)
  - `lib/configure-ui.sh` (for `confirm_cancel`, `confirm_skip_day`, `show_help_dialog`)
  - `lib/configure-time.sh` (for `format_ranges_human`)
  - `lib/config.sh` (for `parse_config` to read previous day's ranges)
- **Depended upon by**:
  - `configure.sh` (main entry point)
  - `lib/configure-workflow.sh` (uses multiple input functions)

#### Code Organization
- Current organization: Functions are organized roughly by complexity, with simple input functions first, then calculation functions, then the complex day hours function
- Logical sections: 
  1. Simple input collection functions (GUI/text mode branching)
  2. Time calculation utilities
  3. Complex day hours input with navigation
- Repeated patterns: 
  - GUI/text mode branching pattern repeated in every input function
  - Default value reading from config file (repeated pattern)
  - Validation and error handling (similar patterns)
  - Cancel confirmation handling (repeated)

#### Refactoring Opportunities

##### Opportunity 1: Extract Time Calculation Functions to Separate Module

**Proposed Structure**:
- New module: `lib/configure-time-calculations.sh`
  - Functions to move: `calculate_range_duration`, `calculate_total_day_duration`
- Remaining in original: All input collection functions

**Migration Strategy**:
1. Create new module file `lib/configure-time-calculations.sh`
2. Move `calculate_range_duration()` and `calculate_total_day_duration()` to new module
3. Update source statements in `configure.sh` to include new module (after `configure-time.sh`)
4. Update `configure-input.sh` to source the new module or ensure it's sourced before use
5. Test thoroughly to ensure calculations still work correctly

**Benefits**:
- Reduces original file by ~125 lines (to ~1154 lines)
- Separates pure calculation logic from UI/input logic
- Makes calculation functions reusable by other modules
- Improves testability (can test calculations independently)
- Better aligns with single responsibility principle

**Evaluation**:
- **Ease of Implementation**: 4/5 - Simple extraction, clear boundaries, minimal dependencies
- **Safety**: 5/5 - Very low risk, pure functions with no side effects, easy to test
- **Practicality**: 4/5 - Good benefit-to-effort ratio, improves organization
- **Recommendation**: 4/5 - Should be done, good priority
- **Overall Score**: 4.25/5

**Priority**: High

##### Opportunity 2: Extract Simple Input Functions to Separate Module

**Proposed Structure**:
- New module: `lib/configure-input-simple.sh`
  - Functions to move: `get_hour_zenity`, `get_hour_text`, `get_popup_size_config`, `get_min_display_time_config`, `get_popup_immovable_config`, `get_configure_block_enabled_config`, `get_uninstall_protection_mode_config`, `get_popup_position_config`, `get_check_interval`
- Remaining in original: `get_day_hours` (complex function)
- Alternative: Could split into multiple modules by category (popup settings, security settings, etc.)

**Migration Strategy**:
1. Create new module file `lib/configure-input-simple.sh`
2. Move all simple input functions to new module
3. Update source statements in `configure.sh` (after `configure-input.sh` or rename current file)
4. Update any files that depend on moved functions
5. Test thoroughly

**Benefits**:
- Reduces original file by ~608 lines (to ~671 lines, bringing it under threshold)
- Separates simple input collection from complex day hours input
- Makes simple input functions easier to find and maintain
- Improves readability (main file focuses on complex day hours logic)

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity, many functions to move, need to update dependencies
- **Safety**: 4/5 - Low risk, functions are well-isolated, but need to ensure all dependencies are satisfied
- **Practicality**: 3/5 - Moderate benefit, significant effort required, but brings file under threshold
- **Recommendation**: 3/5 - Worth considering, moderate priority
- **Overall Score**: 3.5/5

**Priority**: Medium

##### Opportunity 3: Extract Complex Day Hours Function to Separate Module

**Proposed Structure**:
- New module: `lib/configure-input-day-hours.sh`
  - Function to move: `get_day_hours` (510 lines)
- Remaining in original: All simple input functions and calculation functions

**Migration Strategy**:
1. Create new module file `lib/configure-input-day-hours.sh`
2. Move `get_day_hours()` function to new module
3. Ensure all dependencies are available (configure-ui, configure-time, config.sh)
4. Update source statements in `configure.sh`
5. Test thoroughly (this is a complex function with many edge cases)

**Benefits**:
- Reduces original file by ~510 lines (to ~769 lines, still over threshold but closer)
- Isolates the most complex input function
- Makes the complex day hours logic easier to understand and test in isolation
- Allows for future enhancements to day hours input without affecting other input functions

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity, large function with many dependencies
- **Safety**: 3/5 - Moderate risk, complex function with many edge cases, requires careful testing
- **Practicality**: 3/5 - Moderate benefit, significant effort, but improves organization
- **Recommendation**: 3/5 - Worth considering, moderate priority
- **Overall Score**: 3.0/5

**Priority**: Medium

##### Opportunity 4: Split get_day_hours Function into Smaller Functions

**Proposed Structure**:
- Keep `get_day_hours()` as orchestrator function (~100 lines)
- Extract validation logic to `validate_day_hours_input()` (~150 lines)
- Extract warning logic to `show_day_hours_warnings()` (~150 lines)
- Extract text mode logic to `get_day_hours_text()` (~110 lines)
- Keep GUI mode logic in main function but simplify

**Migration Strategy**:
1. Identify distinct logical sections within `get_day_hours()`
2. Extract validation logic to separate function
3. Extract warning display logic to separate function
4. Extract text mode logic to separate function
5. Refactor main function to call extracted functions
6. Test thoroughly

**Benefits**:
- Reduces complexity of main function
- Improves testability (can test validation, warnings, text mode separately)
- Makes code more maintainable
- Easier to understand flow

**Evaluation**:
- **Ease of Implementation**: 2/5 - Difficult, complex function with intertwined logic, risk of breaking functionality
- **Safety**: 2/5 - Moderate-high risk, complex refactoring of critical function, extensive testing needed
- **Practicality**: 3/5 - Good benefit but high effort and risk
- **Recommendation**: 2/5 - Low priority, consider after other refactorings
- **Overall Score**: 2.25/5

**Priority**: Low

---

### File: configure-ui.sh

**Location**: `lib/configure-ui.sh`  
**Line Count**: 916  
**Exceeds Threshold**: Yes

#### Function Inventory
- `confirm_cancel()` (lines 29-49): Confirm cancellation dialog
- `confirm_skip_day()` (lines 52-90): Confirm skipping a day
- `show_help_dialog()` (lines 93-153): Display configuration help
- `show_welcome()` (lines 156-207): Show welcome message
- `show_success()` (lines 332-359): Show success message
- `ask_weekday_together()` (lines 210-227): Ask if configuring weekdays together
- `ask_weekend_together()` (lines 230-249): Ask if configuring weekends together
- `ask_what_to_edit()` (lines 254-329): Ask what to edit (restricted hours, lock hours, or both)
- `show_24_7_error()` (lines 363-393): Show error dialog for 24/7 restrictions detected
- `show_high_restriction_warning()` (lines 398-434): Show warning dialog for high restriction levels
- `calculate_restriction_end_time()` (lines 445-564): Calculate when current restriction period ends (~120 lines)
- `show_config_locked_error()` (lines 573-916): Show error when configure.sh/manage.sh is blocked (~344 lines)

#### Function Groupings
- **Group 1 - Simple Confirmation/Info Dialogs** (lines 29-359): `confirm_cancel`, `confirm_skip_day`, `show_help_dialog`, `show_welcome`, `show_success`, `ask_weekday_together`, `ask_weekend_together`, `ask_what_to_edit`
  - Simple UI dialogs with GUI/text mode branching
  - Total: ~330 lines
  
- **Group 2 - Validation/Error Dialogs** (lines 363-434): `show_24_7_error`, `show_high_restriction_warning`
  - Error and warning dialogs for validation
  - Total: ~72 lines
  
- **Group 3 - Complex Time Calculation and Error Display** (lines 445-916): `calculate_restriction_end_time`, `show_config_locked_error`
  - Complex functions with time calculations and detailed error messages
  - Total: ~472 lines

#### Dependencies
- **Depends on**: 
  - `lib/configure-core.sh` (for `has_dialog_tool`, `CONFIG_FILE`, `format_hour_12h`, `DAY_NAMES`)
  - `lib/configure-dialogs.sh` (for dialog abstraction functions)
  - `lib/configure-time.sh` (for `format_ranges_human`)
  - `lib/config.sh` (for `parse_config`, `parse_lock_hours`)
  - `lib/time-validation.sh` (for `is_restricted_hour`, `is_lock_hour`, `is_hour_in_single_range`)
- **Depended upon by**:
  - `configure.sh` (main entry point)
  - `lib/configure-input.sh` (uses `confirm_cancel`, `confirm_skip_day`, `show_help_dialog`)
  - `lib/configure-display.sh` (uses `confirm_cancel`)
  - `lib/configure-workflow.sh` (uses multiple UI functions)
  - `manage.sh` (uses `show_config_locked_error`)

#### Code Organization
- Current organization: Functions organized by type (confirmations, info dialogs, errors, complex calculations)
- Logical sections:
  1. Simple confirmation and info dialogs
  2. Validation error dialogs
  3. Complex time calculation and error display functions
- Repeated patterns:
  - GUI/text mode branching (repeated in every dialog function)
  - Dialog abstraction usage (consistent pattern)

#### Refactoring Opportunities

##### Opportunity 1: Extract Complex Time Calculation and Error Display Functions

**Proposed Structure**:
- New module: `lib/configure-ui-errors.sh` or `lib/configure-ui-locking.sh`
  - Functions to move: `calculate_restriction_end_time`, `show_config_locked_error`
- Remaining in original: All simple dialog functions

**Migration Strategy**:
1. Create new module file `lib/configure-ui-errors.sh`
2. Move `calculate_restriction_end_time()` and `show_config_locked_error()` to new module
3. Ensure all dependencies are available (configure-core, configure-time, config.sh, time-validation.sh)
4. Update source statements in `configure.sh` (after `configure-ui.sh`)
5. Update any files that depend on moved functions (manage.sh, configure-workflow.sh)
6. Test thoroughly

**Benefits**:
- Reduces original file by ~472 lines (to ~444 lines, bringing it well under threshold)
- Separates complex error/time calculation logic from simple dialogs
- Makes error handling logic easier to find and maintain
- Improves organization (simple dialogs vs. complex error handling)

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity, need to ensure all dependencies are satisfied, need to update multiple dependent files
- **Safety**: 4/5 - Low-moderate risk, functions are well-isolated, but `show_config_locked_error` is used by manage.sh
- **Practicality**: 4/5 - Good benefit-to-effort ratio, brings file under threshold significantly
- **Recommendation**: 4/5 - Should be done, good priority
- **Overall Score**: 3.75/5

**Priority**: High

##### Opportunity 2: Extract Validation Error Dialogs to Separate Module

**Proposed Structure**:
- New module: `lib/configure-ui-validation.sh`
  - Functions to move: `show_24_7_error`, `show_high_restriction_warning`
- Remaining in original: Simple dialogs and complex error functions

**Migration Strategy**:
1. Create new module file `lib/configure-ui-validation.sh`
2. Move validation error dialogs to new module
3. Update source statements in `configure.sh`
4. Update any files that depend on moved functions
5. Test thoroughly

**Benefits**:
- Reduces original file by ~72 lines (to ~844 lines, still over threshold)
- Groups validation-related dialogs together
- Makes validation error handling easier to find

**Evaluation**:
- **Ease of Implementation**: 4/5 - Simple extraction, clear boundaries
- **Safety**: 5/5 - Very low risk, simple functions
- **Practicality**: 2/5 - Questionable benefit, doesn't bring file under threshold alone, minimal improvement
- **Recommendation**: 2/5 - Low priority, only if combined with other refactorings
- **Overall Score**: 3.25/5

**Priority**: Low (only if combined with Opportunity 1)

---

### File: popup-display.sh

**Location**: `lib/popup-display.sh`  
**Line Count**: 797  
**Exceeds Threshold**: Yes

#### Function Inventory
- `build_weekly_restricted_intervals()` (lines 52-130): Build weekly timeline of restricted intervals
- `get_current_minute_offset()` (lines 142-167): Calculate current minute offset from start of week
- `is_minute_restricted()` (lines 182-200): Check if minute is restricted
- `format_minute_offset_to_time()` (lines 221-295): Format minute offset to human-readable time
- `get_next_unrestricted_time()` (lines 315-401): Calculate next unrestricted time
- `show_warning()` (lines 404-797): Display warning popup (~394 lines)

#### Function Groupings
- **Group 1 - Time Calculation Functions** (lines 52-401): `build_weekly_restricted_intervals`, `get_current_minute_offset`, `is_minute_restricted`, `format_minute_offset_to_time`, `get_next_unrestricted_time`
  - Pure calculation and formatting functions for time intervals
  - Total: ~350 lines
  
- **Group 2 - Popup Display Function** (lines 404-797): `show_warning`
  - Complex function that handles popup display, window management, countdown, etc.
  - Total: ~394 lines

#### Dependencies
- **Depends on**: 
  - `lib/config.sh` (for configuration functions: `get_check_interval`, `get_popup_size`, `get_popup_position`, `get_min_display_time`, `get_popup_dimensions`)
  - `lib/logging.sh` (for logging functions)
  - `lib/display-detection.sh` (for display environment detection)
  - `lib/desktop-environment.sh` (for dialog tool detection)
  - `lib/window-management.sh` (for window manipulation)
  - `lib/configure-validation.sh` (for `merge_overlapping_intervals`)
- **Depended upon by**:
  - `sleep-warning.sh` (main script, uses `show_warning`)

#### Code Organization
- Current organization: Time calculation functions first, then the main popup display function
- Logical sections:
  1. Time interval calculation and formatting utilities
  2. Popup display and window management
- Repeated patterns:
  - Time calculation functions follow consistent patterns
  - Popup display has complex branching for different dialog tools (zenity, yad, kdialog)

#### Refactoring Opportunities

##### Opportunity 1: Extract Time Calculation Functions to Separate Module

**Proposed Structure**:
- New module: `lib/popup-time-calculations.sh`
  - Functions to move: `build_weekly_restricted_intervals`, `get_current_minute_offset`, `is_minute_restricted`, `format_minute_offset_to_time`, `get_next_unrestricted_time`
- Remaining in original: `show_warning()` function

**Migration Strategy**:
1. Create new module file `lib/popup-time-calculations.sh`
2. Move all time calculation functions to new module
3. Update source statements in `sleep-warning.sh` (before `popup-display.sh`)
4. Ensure `popup-display.sh` sources the new module or it's sourced before
5. Test thoroughly

**Benefits**:
- Reduces original file by ~350 lines (to ~447 lines, bringing it well under threshold)
- Separates pure calculation logic from UI/display logic
- Makes time calculation functions reusable by other modules
- Improves testability (can test calculations independently)
- Better aligns with single responsibility principle

**Evaluation**:
- **Ease of Implementation**: 4/5 - Simple extraction, clear boundaries, minimal dependencies
- **Safety**: 5/5 - Very low risk, pure functions with no side effects, easy to test
- **Practicality**: 4/5 - Good benefit-to-effort ratio, brings file under threshold
- **Recommendation**: 4/5 - Should be done, good priority
- **Overall Score**: 4.25/5

**Priority**: High

##### Opportunity 2: Extract Popup Display Logic into Smaller Functions

**Proposed Structure**:
- Keep `show_warning()` as orchestrator function (~100 lines)
- Extract dialog tool selection to `select_popup_dialog_tool()` (~50 lines)
- Extract popup creation logic to `create_popup_window()` (~150 lines)
- Extract countdown update logic to `update_popup_countdown()` (already nested function, ~90 lines)
- Extract window management logic to `manage_popup_window()` (~100 lines)

**Migration Strategy**:
1. Identify distinct logical sections within `show_warning()`
2. Extract dialog tool selection logic
3. Extract popup creation logic (zenity/yad/kdialog branching)
4. Extract countdown update logic (already a nested function)
5. Extract window management logic
6. Refactor main function to call extracted functions
7. Test thoroughly

**Benefits**:
- Reduces complexity of main function
- Improves testability (can test dialog selection, popup creation, window management separately)
- Makes code more maintainable
- Easier to understand flow

**Evaluation**:
- **Ease of Implementation**: 2/5 - Difficult, complex function with intertwined logic, risk of breaking functionality
- **Safety**: 2/5 - Moderate-high risk, complex refactoring of critical function, extensive testing needed
- **Practicality**: 3/5 - Good benefit but high effort and risk
- **Recommendation**: 2/5 - Low priority, consider after Opportunity 1
- **Overall Score**: 2.25/5

**Priority**: Low

---

### File: configure-display.sh

**Location**: `lib/configure-display.sh`  
**Line Count**: 780  
**Exceeds Threshold**: Yes

#### Function Inventory
- `get_section_status()` (lines 22-54): Get status indicators for menu display
- `show_main_menu()` (lines 69-264): Show main navigation menu (~196 lines)
- `show_visual_grid()` (lines 266-528): Display visual day/time grid for editing (~263 lines)
- `show_summary()` (lines 530-780): Show configuration summary with overlap detection (~251 lines)

#### Function Groupings
- **Group 1 - Menu and Status Functions** (lines 22-264): `get_section_status`, `show_main_menu`
  - Menu display and status calculation
  - Total: ~243 lines
  
- **Group 2 - Complex Display Functions** (lines 266-780): `show_visual_grid`, `show_summary`
  - Complex display functions with grid and summary views
  - Total: ~514 lines

#### Dependencies
- **Depends on**: 
  - `lib/configure-core.sh` (for `has_dialog_tool`, `DAY_NAMES`, `CONFIG_FILE`)
  - `lib/configure-dialogs.sh` (for dialog abstraction functions: `show_multi_column_list_dialog`)
  - `lib/configure-time.sh` (for `format_ranges_human`, `detect_overlaps`, `get_inherited_restrictions`)
  - `lib/configure-ui.sh` (for `confirm_cancel`)
- **Depended upon by**:
  - `configure.sh` (main entry point)
  - `lib/configure-workflow.sh` (uses all display functions)

#### Code Organization
- Current organization: Functions organized by complexity, with simpler menu functions first, then complex grid and summary functions
- Logical sections:
  1. Menu and status functions
  2. Complex display functions (grid and summary)
- Repeated patterns:
  - GUI/text mode branching (repeated in every function)
  - Multi-column dialog usage (in grid and menu)
  - Formatting and display patterns

#### Refactoring Opportunities

##### Opportunity 1: Extract Complex Display Functions to Separate Module

**Proposed Structure**:
- New module: `lib/configure-display-complex.sh`
  - Functions to move: `show_visual_grid`, `show_summary`
- Remaining in original: `get_section_status`, `show_main_menu`

**Migration Strategy**:
1. Create new module file `lib/configure-display-complex.sh`
2. Move `show_visual_grid()` and `show_summary()` to new module
3. Ensure all dependencies are available
4. Update source statements in `configure.sh` (after `configure-display.sh`)
5. Update any files that depend on moved functions
6. Test thoroughly

**Benefits**:
- Reduces original file by ~514 lines (to ~266 lines, bringing it well under threshold)
- Separates complex display logic from simple menu functions
- Makes complex display functions easier to find and maintain
- Improves organization

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity, need to ensure all dependencies are satisfied
- **Safety**: 4/5 - Low-moderate risk, functions are well-isolated, but need careful testing
- **Practicality**: 4/5 - Good benefit-to-effort ratio, brings file under threshold significantly
- **Recommendation**: 4/5 - Should be done, good priority
- **Overall Score**: 3.75/5

**Priority**: High

##### Opportunity 2: Extract Menu Functions to Separate Module

**Proposed Structure**:
- New module: `lib/configure-display-menu.sh`
  - Functions to move: `get_section_status`, `show_main_menu`
- Remaining in original: Complex display functions

**Migration Strategy**:
1. Create new module file `lib/configure-display-menu.sh`
2. Move menu functions to new module
3. Update source statements in `configure.sh`
4. Test thoroughly

**Benefits**:
- Reduces original file by ~243 lines (to ~537 lines, still over threshold)
- Groups menu-related functions together
- Makes menu logic easier to find

**Evaluation**:
- **Ease of Implementation**: 4/5 - Simple extraction, clear boundaries
- **Safety**: 5/5 - Very low risk, simple functions
- **Practicality**: 2/5 - Questionable benefit, doesn't bring file under threshold alone
- **Recommendation**: 2/5 - Low priority, only if combined with Opportunity 1
- **Overall Score**: 3.25/5

**Priority**: Low (only if combined with Opportunity 1)

---

## Prioritized Recommendations

### High Priority (Overall Score ≥ 4.0)

1. **Extract Time Calculation Functions from configure-input.sh** - Score: 4.25/5
   - File: `lib/configure-input.sh`
   - Justification: Simple extraction with clear boundaries, very low risk, brings file closer to threshold, improves organization and testability

2. **Extract Time Calculation Functions from popup-display.sh** - Score: 4.25/5
   - File: `lib/popup-display.sh`
   - Justification: Simple extraction with clear boundaries, very low risk, brings file well under threshold, improves organization and testability

### Medium-High Priority (Overall Score 3.5-3.9)

3. **Extract Complex Error Display Functions from configure-ui.sh** - Score: 3.75/5
   - File: `lib/configure-ui.sh`
   - Justification: Good benefit-to-effort ratio, brings file well under threshold, improves organization, but requires updating multiple dependent files

4. **Extract Complex Display Functions from configure-display.sh** - Score: 3.75/5
   - File: `lib/configure-display.sh`
   - Justification: Good benefit-to-effort ratio, brings file well under threshold, improves organization

### Medium Priority (Overall Score 3.0-3.9)

5. **Extract Simple Input Functions from configure-input.sh** - Score: 3.5/5
   - File: `lib/configure-input.sh`
   - Justification: Moderate benefit, brings file under threshold, but requires moving many functions and updating dependencies

6. **Extract Complex Day Hours Function from configure-input.sh** - Score: 3.0/5
   - File: `lib/configure-input.sh`
   - Justification: Moderate benefit, improves organization, but complex function with many dependencies

### Low Priority (Overall Score < 3.0)

7. **Extract Validation Error Dialogs from configure-ui.sh** - Score: 3.25/5
   - File: `lib/configure-ui.sh`
   - Justification: Only recommended if combined with Opportunity 1, doesn't bring file under threshold alone

8. **Extract Menu Functions from configure-display.sh** - Score: 3.25/5
   - File: `lib/configure-display.sh`
   - Justification: Only recommended if combined with Opportunity 1, doesn't bring file under threshold alone

9. **Split get_day_hours Function into Smaller Functions** - Score: 2.25/5
   - File: `lib/configure-input.sh`
   - Justification: High risk, complex refactoring, consider after other refactorings are complete

10. **Extract Popup Display Logic into Smaller Functions** - Score: 2.25/5
    - File: `lib/popup-display.sh`
    - Justification: High risk, complex refactoring, consider after Opportunity 1 is complete

## Files Appropriately Large

None identified. All files exceeding 750 lines have clear refactoring opportunities that would improve maintainability and organization.

## Observations and Patterns

### Common Patterns Across Files

1. **GUI/Text Mode Branching**: All UI and input functions follow a consistent pattern of branching between GUI and text modes. This pattern is repeated extensively but is necessary for the dual-mode functionality.

2. **Dialog Abstraction**: The codebase uses dialog abstraction functions from `configure-dialogs.sh`, which is good for maintainability. However, the abstraction layer could potentially be extended to reduce repetition further.

3. **Time Calculation Functions**: Multiple files contain time calculation functions that could potentially be consolidated into a shared time calculation module.

4. **Complex Functions**: Several files contain very large functions (500+ lines) that handle complex logic. These would benefit from being split into smaller, more focused functions.

5. **Dependency Management**: The modular architecture is well-designed with clear dependency chains. Refactoring should maintain this structure.

### Structural Observations

1. **Modular Architecture**: The codebase follows a well-designed modular architecture with clear separation of concerns. The refactoring opportunities identified maintain this structure.

2. **File Growth**: Some files have grown beyond the 750-line threshold due to feature additions (e.g., Enhancement #19, Enhancement #26). This is expected but should be addressed through refactoring.

3. **Test Coverage**: The codebase has good test coverage, which will help ensure refactorings don't break functionality.

4. **Documentation**: Functions are well-documented with clear headers explaining purpose, parameters, and dependencies.

## Next Steps

- [ ] Review prioritized recommendations with team/user
- [ ] Create implementation plans for high-priority refactorings
- [ ] Schedule refactoring work (start with high-priority items)
- [ ] Update this assessment after refactorings are completed
- [ ] Consider creating shared time calculation module if multiple time calculation modules are created

## Assessment Checklist

### Preparation

- [x] Create timestamped copy of this template
- [x] **Remember: Only edit the timestamped assessment file - do not modify any code files**
- [x] Identify all `.sh` files in codebase
- [x] Count lines for each file
- [x] Create list of files exceeding 750 lines

### Analysis

For each file exceeding 750 lines:

- [x] Document file path and line count
- [x] List all functions in the file
- [x] Identify function groupings
- [x] Analyze dependencies (what it uses, what uses it)
- [x] Identify code organization patterns
- [x] Identify refactoring opportunities
- [x] Document proposed refactoring plan
- [x] Evaluate each refactoring suggestion (Ease, Safety, Practicality, Recommendation)
- [x] Calculate overall score for each suggestion
- [x] Prioritize recommendations

### Documentation

- [x] Create summary table of all files analyzed
- [x] Create prioritized list of refactoring recommendations
- [x] Document any files that are appropriately large (with justification)
- [x] Note any patterns or observations about the codebase structure

---

## Implementation Plans

### Consolidation Analysis

**Analysis of Time Calculation Functions:**

The time calculation functions from both files serve different but related purposes:

**From configure-input.sh (Hour-based, for configuration validation):**
- `calculate_range_duration()` - Calculates duration in **hours** of a single time range
- `calculate_total_day_duration()` - Calculates total duration in **hours** for a day

**From popup-display.sh (Minute-based, for runtime popup display):**
- `build_weekly_restricted_intervals()` - Builds weekly timeline in **minutes**
- `get_current_minute_offset()` - Gets current minute offset
- `is_minute_restricted()` - Checks if minute is restricted
- `format_minute_offset_to_time()` - Formats minute offset to human-readable time
- `get_next_unrestricted_time()` - Finds next unrestricted time

**Consolidation Strategy:**

While these functions serve different purposes (configuration validation vs. runtime display), they share common concepts:
- Both handle overnight ranges (start > end)
- Both parse time ranges in "START-END" format
- Both need to handle day wrap-around

**Recommended Approach:** Create a unified `lib/time-calculations.sh` module that contains both sets of functions, organized into logical sections:
1. **Hour-based calculations** (for configuration validation)
2. **Minute-based calculations** (for runtime popup display)

This consolidation:
- ✅ Groups all time calculation logic in one place
- ✅ Makes it easier to maintain and test time-related functions
- ✅ Allows for potential future shared utilities
- ✅ Maintains clear separation between hour-based and minute-based functions
- ✅ Reduces code duplication if any shared logic is identified

---

## Implementation Checklist #1: Extract Time Calculation Functions from configure-input.sh

**Target:** Move `calculate_range_duration()` and `calculate_total_day_duration()` to shared time calculations module

### Phase 1: Create Shared Time Calculations Module

- [ ] Create new file `lib/time-calculations.sh`
- [ ] Add file header with module description, purpose, and dependencies
- [ ] Add section header for "Hour-based Calculations (for Configuration Validation)"
- [ ] Copy `calculate_range_duration()` function (lines 653-673) to new module
- [ ] Copy `calculate_total_day_duration()` function (lines 693-766) to new module
- [ ] Ensure all function documentation is preserved
- [ ] Add dependency comments (requires: `config.sh` for `parse_config`)

### Phase 2: Update configure-input.sh

- [ ] Remove `calculate_range_duration()` function from `configure-input.sh`
- [ ] Remove `calculate_total_day_duration()` function from `configure-input.sh`
- [ ] Update file header to remove these functions from the function list
- [ ] Verify file still compiles (syntax check: `bash -n lib/configure-input.sh`)
- [ ] Count lines to verify reduction (~125 lines removed, should be ~1154 lines)

### Phase 3: Update Source Statements

- [ ] Update `configure.sh` to source `lib/time-calculations.sh` before `lib/configure-input.sh`
- [ ] Verify source order maintains dependency chain:
  - `configure-core.sh` (first)
  - `config.sh` (needed by time-calculations.sh)
  - `time-calculations.sh` (new module)
  - `configure-input.sh` (uses time-calculations.sh)
- [ ] Update any other files that source `configure-input.sh` directly (if any)

### Phase 4: Testing

- [ ] Run existing tests for `configure-input.sh` functionality
- [ ] Test `calculate_range_duration()` with various inputs:
  - [ ] Normal range: "0-5" (should return 5)
  - [ ] Overnight range: "23-6" (should return 7)
  - [ ] Edge case: "0-23" (should return 23)
  - [ ] Edge case: "23-0" (should return 1)
- [ ] Test `calculate_total_day_duration()` with various scenarios:
  - [ ] Day with no overnight from previous day
  - [ ] Day with overnight from previous day
  - [ ] Day with overnight range on current day
  - [ ] Edge case: Sunday with Saturday overnight range
- [ ] Test configuration wizard end-to-end to ensure time calculations work correctly
- [ ] Verify no regressions in configuration validation

### Phase 5: Documentation

- [ ] Update `dev-docs/completed-plans/plan-modular-architecture-configure.md` if it exists
- [ ] Update any architecture documentation to include new module
- [ ] Add entry to this assessment file documenting completion

### Phase 6: Verification

- [ ] Verify `configure-input.sh` line count is reduced (target: ~1154 lines)
- [ ] Verify all functions are accessible from `configure.sh`
- [ ] Run full test suite
- [ ] Check for any linting errors or warnings

---

## Implementation Checklist #2: Extract Time Calculation Functions from popup-display.sh

**Target:** Move minute-based time calculation functions to shared time calculations module

### Phase 1: Add Minute-based Functions to Shared Module

- [ ] Open `lib/time-calculations.sh` (created in Checklist #1)
- [ ] Add section header for "Minute-based Calculations (for Runtime Popup Display)"
- [ ] Copy `build_weekly_restricted_intervals()` function (lines 52-130) to new module
- [ ] Copy `get_current_minute_offset()` function (lines 142-167) to new module
- [ ] Copy `is_minute_restricted()` function (lines 182-200) to new module
- [ ] Copy `format_minute_offset_to_time()` function (lines 221-295) to new module
- [ ] Copy `get_next_unrestricted_time()` function (lines 315-401) to new module
- [ ] Ensure all function documentation is preserved
- [ ] Add dependency comments:
  - Requires: `config.sh` for `parse_config`
  - Requires: `configure-validation.sh` for `merge_overlapping_intervals` (used by `get_next_unrestricted_time`)

### Phase 2: Update popup-display.sh

- [ ] Remove `build_weekly_restricted_intervals()` function from `popup-display.sh`
- [ ] Remove `get_current_minute_offset()` function from `popup-display.sh`
- [ ] Remove `is_minute_restricted()` function from `popup-display.sh`
- [ ] Remove `format_minute_offset_to_time()` function from `popup-display.sh`
- [ ] Remove `get_next_unrestricted_time()` function from `popup-display.sh`
- [ ] Update file header to remove these functions from the function list
- [ ] Update file header dependencies section to note that time calculations are now in `time-calculations.sh`
- [ ] Verify file still compiles (syntax check: `bash -n lib/popup-display.sh`)
- [ ] Count lines to verify reduction (~350 lines removed, should be ~447 lines)

### Phase 3: Update Source Statements

- [ ] Update `sleep-warning.sh` to source `lib/time-calculations.sh` before `lib/popup-display.sh`
- [ ] Verify source order maintains dependency chain:
  - `config.sh` (needed by time-calculations.sh)
  - `configure-validation.sh` (needed by time-calculations.sh for `merge_overlapping_intervals`)
  - `time-calculations.sh` (new module)
  - `popup-display.sh` (uses time-calculations.sh)
- [ ] Update any other files that source `popup-display.sh` directly (if any)

### Phase 4: Testing

- [ ] Run existing tests for `popup-display.sh` functionality
- [ ] Test `build_weekly_restricted_intervals()`:
  - [ ] With normal ranges (e.g., "0-5")
  - [ ] With overnight ranges (e.g., "23-6")
  - [ ] With multiple ranges per day
  - [ ] With no restrictions configured
- [ ] Test `get_current_minute_offset()`:
  - [ ] Verify it returns correct minute offset for current time
  - [ ] Test at different times of day and week
- [ ] Test `is_minute_restricted()`:
  - [ ] With minute inside restricted interval
  - [ ] With minute outside restricted interval
  - [ ] With minute at interval boundary
- [ ] Test `format_minute_offset_to_time()`:
  - [ ] With time < 60 minutes away
  - [ ] With time later today
  - [ ] With time tomorrow
  - [ ] With time 2+ days away
- [ ] Test `get_next_unrestricted_time()`:
  - [ ] With current time in restriction
  - [ ] With current time not in restriction
  - [ ] With no restrictions configured
  - [ ] With overnight ranges
- [ ] Test popup display end-to-end to ensure time calculations work correctly
- [ ] Verify popup shows correct "next unrestricted time" message
- [ ] Verify no regressions in popup functionality

### Phase 5: Documentation

- [ ] Update any architecture documentation to reflect consolidation
- [ ] Update `dev-docs/completed-plans/plan-modular-architecture-configure.md` if it exists
- [ ] Document the consolidation of time calculation functions
- [ ] Add entry to this assessment file documenting completion

### Phase 6: Verification

- [ ] Verify `popup-display.sh` line count is reduced (target: ~447 lines)
- [ ] Verify `time-calculations.sh` contains all time calculation functions
- [ ] Verify all functions are accessible from `sleep-warning.sh`
- [ ] Run full test suite
- [ ] Check for any linting errors or warnings
- [ ] Verify no duplicate function definitions exist

---

## Implementation Checklist #3: Consolidation Verification

**Target:** Verify consolidated time calculations module works correctly

### Verification Steps

- [ ] Verify `lib/time-calculations.sh` contains:
  - [ ] Hour-based section with 2 functions
  - [ ] Minute-based section with 5 functions
  - [ ] Total: 7 functions
- [ ] Verify module structure is clear and well-organized
- [ ] Verify all dependencies are properly documented
- [ ] Run integration tests:
  - [ ] Configuration wizard uses hour-based functions correctly
  - [ ] Popup display uses minute-based functions correctly
  - [ ] No conflicts between hour-based and minute-based functions
- [ ] Verify no circular dependencies introduced
- [ ] Check that both `configure.sh` and `sleep-warning.sh` can use the module independently
- [ ] Verify module follows existing code style and documentation standards

### Final Verification

- [ ] All files compile without errors
- [ ] All tests pass
- [ ] Line counts verified:
  - [ ] `configure-input.sh`: ~1154 lines (down from 1279)
  - [ ] `popup-display.sh`: ~447 lines (down from 797)
  - [ ] `time-calculations.sh`: ~475 lines (new module)
- [ ] No functionality regressions
- [ ] Documentation updated
- [ ] Mark both implementation checklists as complete in this assessment file
