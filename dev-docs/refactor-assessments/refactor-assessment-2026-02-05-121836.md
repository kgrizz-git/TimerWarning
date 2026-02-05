# Refactor Assessment - 2026-02-05 12:18:36

## Assessment Date
- **Date**: 2026-02-05
- **Time**: 12:18:36
- **Assessor**: AI Agent

## Files Analyzed

### Summary Table

| File | Location | Line Count | Exceeds Threshold | Status |
|------|----------|------------|-------------------|--------|
| popup-display.sh | lib/ | 1474 | Yes | Analyzed |
| configure-display.sh | lib/ | 1281 | Yes | Analyzed |
| config.sh | lib/ | 1198 | Yes | Analyzed |
| configure-dialogs.sh | lib/ | 1128 | Yes | Analyzed |
| configure-ui.sh | lib/ | 974 | Yes | Analyzed |
| install.sh | root | 930 | Yes | Analyzed |
| configure-input-popup.sh | lib/ | 895 | Yes | Analyzed |
| configure-input-features.sh | lib/ | 878 | Yes | Analyzed |
| status.sh | root | 812 | Yes | Analyzed |
| configure-config.sh | lib/ | 780 | Yes | Analyzed |

## Review Notes (Assessment Evaluation)

- **Overall**: I agree with the assessment’s main conclusions: the biggest refactor leverage is in a small set of *very large, high-duplication* functions (`show_warning()`, several configure wizard UI functions, and `write_config()`), and the codebase already has natural module boundaries that can be made more explicit.
- **Key correction**: `status.sh` does **not** depend on `lib/popup-display.sh` / `show_warning()`; it sources `config.sh` (optionally) and performs its own status/config parsing.
- **Key trade-off**: Splitting entry-point scripts (`install.sh`, `status.sh`) into many sourced modules can reduce readability/duplication, but may **increase failure modes** (missing sourced files when run from unexpected locations). If split, keep a stable “single entrypoint” file and make it source submodules defensively.
- **Preferred refactor shape**: When splitting a large “public” module (like `config.sh` / `configure-dialogs.sh`), keep the original file as the stable API surface that sources new submodules internally to avoid widespread churn.

## Detailed Analysis

### File: popup-display.sh

**Location**: `lib/popup-display.sh`  
**Line Count**: 1474  
**Exceeds Threshold**: Yes

#### Function Inventory
- `ensure_utf8_locale_for_dialogs()` (lines 56-83): Ensures UTF-8 locale for dialog tools
- `cleanup_stale_pid()` (lines 90-115): Cleans up stale PID files
- `get_popup_age()` (lines 122-162): Gets age of popup in seconds
- `is_popup_running()` (lines 167-235): Checks if popup is already running
- `close_existing_popups()` (lines 241-311): Closes all existing popups
- `save_popup_pid()` (lines 318-345): Saves popup PID to state file
- `cleanup_popup_pid()` (lines 352-379): Cleans up popup PID file
- `close_popup_process()` (lines 387-427): Closes popup process using termination
- `auto_close_popup()` (lines 436-461): Auto-close popup timer function
- `show_warning()` (lines 464-1474): Main popup display function (1010 lines!)

#### Function Groupings
- **Popup PID Management**: `cleanup_stale_pid`, `get_popup_age`, `is_popup_running`, `save_popup_pid`, `cleanup_popup_pid`, `close_existing_popups` (Enhancement #9)
- **Popup Process Control**: `close_popup_process`, `auto_close_popup` (Enhancement #15)
- **Locale/Unicode Handling**: `ensure_utf8_locale_for_dialogs`
- **Main Display Logic**: `show_warning` (massive function containing all dialog tool implementations)

#### Dependencies
- **Depends on**: 
  - `config.sh` (configuration functions)
  - `logging.sh` (logging functions)
  - `pause-state.sh` (pause state management)
  - `display-detection.sh` (display environment detection)
  - `desktop-environment.sh` (dialog tool detection)
  - `window-management.sh` (window manipulation)
  - `time-calculations.sh` (time calculation functions)
  - `unicode-dialog-safety.sh` (Unicode safety)
- **Depended upon by**:
  - `sleep-warning.sh` (main script)
  - (Tests may exercise this indirectly via the main script.)

#### Code Organization
- Current organization: Header with dependencies, helper functions, then massive `show_warning()` function
- Logical sections: PID management, process control, locale handling, main display
- Repeated patterns: Dialog tool implementations (zenity/yad/kdialog) repeated multiple times within `show_warning()`

#### Refactoring Opportunities

##### Opportunity 1: Extract Popup PID Management to Separate Module

**Proposed Structure**:
- New module: `lib/popup-pid-management.sh`
  - Functions to move: `cleanup_stale_pid`, `get_popup_age`, `is_popup_running`, `save_popup_pid`, `cleanup_popup_pid`, `close_existing_popups`
- Remaining in original: `ensure_utf8_locale_for_dialogs`, `close_popup_process`, `auto_close_popup`, `show_warning`

**Migration Strategy**:
1. Create new module file `lib/popup-pid-management.sh`
2. Move PID management functions to new module
3. Update source statements in `popup-display.sh`
4. Update any files that depend on moved functions
5. Test thoroughly

**Benefits**:
- Reduces original file by ~200 lines
- Improves separation of concerns (PID management vs display logic)
- Makes PID management functions reusable
- Improves testability

**Evaluation**:
- **Ease of Implementation**: 4/5 - Functions are well-contained, clear dependencies
- **Safety**: 4/5 - Low risk, functions are independent, used by single caller
- **Practicality**: 4/5 - Good benefit-to-effort ratio, clear module boundary
- **Recommendation**: 4/5 - Should be done, improves organization
- **Overall Score**: 4.00/5

**Priority**: High

##### Opportunity 2: Extract Dialog Tool Implementations from show_warning()

**Proposed Structure**:
- New module: `lib/popup-dialog-implementations.sh`
  - Functions to extract: Dialog tool-specific code blocks (zenity/yad/kdialog implementations)
  - Create helper functions: `show_popup_zenity()`, `show_popup_yad()`, `show_popup_kdialog()`, `update_popup_countdown_zenity()`, `update_popup_countdown_yad()`, `update_popup_countdown_kdialog()`
- Remaining in original: `show_warning()` orchestration logic, locale handling, process control

**Migration Strategy**:
1. Create new module file
2. Extract dialog tool implementations into separate functions
3. Refactor `show_warning()` to call appropriate function based on tool
4. Extract `update_popup_countdown()` nested function similarly
5. Test thoroughly with all dialog tools

**Benefits**:
- Reduces `show_warning()` from ~1010 lines to ~300-400 lines
- Eliminates code duplication (zenity/yad/kdialog code repeated multiple times)
- Improves maintainability (dialog tool changes isolated)
- Makes dialog implementations testable independently

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity, requires careful extraction of nested function
- **Safety**: 3/5 - Moderate risk, `show_warning()` is critical path, requires extensive testing
- **Practicality**: 5/5 - Excellent benefit, eliminates massive duplication
- **Recommendation**: 5/5 - Highly recommended, addresses largest code smell
- **Overall Score**: 4.00/5

**Priority**: High

##### Opportunity 3: Extract Popup Process Control Functions

**Proposed Structure**:
- New module: `lib/popup-process-control.sh`
  - Functions to move: `close_popup_process`, `auto_close_popup`
- Remaining in original: Display logic, PID management

**Migration Strategy**:
1. Create new module file
2. Move process control functions
3. Update source statements
4. Test auto-close functionality

**Benefits**:
- Reduces original file by ~50 lines
- Separates process control from display logic
- Improves testability

**Evaluation**:
- **Ease of Implementation**: 4/5 - Simple extraction, clear boundaries
- **Safety**: 4/5 - Low risk, functions are independent
- **Practicality**: 3/5 - Moderate benefit, smaller impact than other opportunities
- **Recommendation**: 3/5 - Worth considering, moderate priority
- **Overall Score**: 3.50/5

**Priority**: Medium

---

### File: configure-display.sh

**Location**: `lib/configure-display.sh`  
**Line Count**: 1281  
**Exceeds Threshold**: Yes

#### Function Inventory
- `get_section_status()` (lines 22-54): Get status indicators for menu display
- `show_main_menu()` (lines 78-506): Show main navigation menu (428 lines!)
- `show_visual_grid()` (lines 508-830): Display weekly hours settings grid (322 lines!)
- `show_summary()` (lines 832-1281): Show configuration summary with overlap detection (449 lines!)

#### Function Groupings
- **Menu Display**: `get_section_status`, `show_main_menu`
- **Grid Display**: `show_visual_grid`
- **Summary Display**: `show_summary`

#### Dependencies
- **Depends on**: 
  - `configure-core.sh` (has_dialog_tool, DAY_NAMES, CONFIG_FILE)
  - `configure-dialogs.sh` (dialog abstraction functions)
  - `configure-time.sh` (format_ranges_human, detect_overlaps, get_inherited_restrictions)
  - `configure-ui.sh` (confirm_cancel)
- **Depended upon by**:
  - `configure.sh` (main configuration script)

#### Code Organization
- Current organization: Three large display functions
- Logical sections: Menu, grid, summary
- Repeated patterns: Window size display formatting duplicated in `show_main_menu()` and `show_summary()`

#### Refactoring Opportunities

##### Opportunity 1: Extract Window Size Display Formatting

**Proposed Structure**:
- New module: `lib/configure-display-helpers.sh`
  - Function to create: `format_popup_size_display()` - consolidates window size formatting logic
- Remaining in original: Menu, grid, summary functions call helper

**Migration Strategy**:
1. Create helper function for window size formatting
2. Extract duplicated logic from `show_main_menu()` and `show_summary()`
3. Update both functions to use helper
4. Test display consistency

**Benefits**:
- Reduces duplication (~150 lines of duplicated code)
- Ensures consistent formatting between menu and summary
- Improves maintainability (single source of truth for formatting)

**Evaluation**:
- **Ease of Implementation**: 4/5 - Straightforward extraction, clear duplication
- **Safety**: 4/5 - Low risk, formatting logic only
- **Practicality**: 4/5 - Good benefit, eliminates duplication
- **Recommendation**: 4/5 - Should be done
- **Overall Score**: 4.00/5

**Priority**: High

##### Opportunity 2: Split show_main_menu() into Smaller Functions

**Proposed Structure**:
- Keep in original: `show_main_menu()` as orchestrator (~100 lines)
- New helper functions in same file or `configure-display-helpers.sh`:
  - `build_window_desc()` - Builds window behavior description
  - `build_security_status()` - Builds security settings status
  - `build_lock_status()` - Builds lock hours status
  - `build_pause_status()` - Builds pause settings status
  - `display_main_menu_gui()` - GUI menu display logic
  - `display_main_menu_text()` - Text menu display logic

**Migration Strategy**:
1. Extract helper functions from `show_main_menu()`
2. Refactor main function to call helpers
3. Test menu display in both GUI and text modes

**Benefits**:
- Reduces `show_main_menu()` from 428 lines to ~100 lines
- Improves readability and testability
- Makes status building logic reusable

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity, function is large but cohesive
- **Safety**: 3/5 - Moderate risk, menu is critical UI component
- **Practicality**: 4/5 - Good benefit, improves maintainability
- **Recommendation**: 4/5 - Should be done
- **Overall Score**: 3.50/5

**Priority**: Medium

##### Opportunity 3: Split show_summary() into Smaller Functions

**Proposed Structure**:
- Keep in original: `show_summary()` as orchestrator (~150 lines)
- New helper functions:
  - `build_summary_text()` - Builds summary text content
  - `format_summary_popup_size()` - Formats popup size for summary
  - `build_restricted_hours_summary()` - Builds restricted hours section
  - `build_lock_hours_summary()` - Builds lock hours section
  - `detect_and_format_overlaps()` - Detects and formats overlap warnings
  - `display_summary_gui()` - GUI summary display
  - `display_summary_text()` - Text summary display

**Migration Strategy**:
1. Extract helper functions from `show_summary()`
2. Refactor main function to call helpers
3. Test summary display in both modes

**Benefits**:
- Reduces `show_summary()` from 449 lines to ~150 lines
- Improves readability
- Makes summary building logic testable

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity
- **Safety**: 3/5 - Moderate risk, summary is important UI component
- **Practicality**: 4/5 - Good benefit
- **Recommendation**: 4/5 - Should be done
- **Overall Score**: 3.50/5

**Priority**: Medium

---

### File: config.sh

**Location**: `lib/config.sh`  
**Line Count**: 1198  
**Exceeds Threshold**: Yes

#### Function Inventory
- Configuration getters: `get_check_interval`, `get_popup_size`, `get_popup_dimensions`, `get_popup_size_mode`, `get_popup_size_custom`, `get_popup_size_custom_absolute`, `get_popup_position`, `get_min_display_time`, `get_popup_immovable`, `get_popup_auto_close`, `get_configure_block_enabled`, `get_uninstall_protection_mode`, `get_dialog_tool_config`, `get_pause_enabled`, `get_pause_duration`, `get_config_lock_enabled`, `get_time_display_format`
- Configuration setters: `set_time_display_format`
- Parsing functions: `parse_config`, `parse_lock_hours`, `parse_uninstall_lock_hours`
- Migration/utility: `migrate_config_to_minute_format`

#### Function Groupings
- **Popup Configuration Getters**: All popup-related getters (size, position, display time, etc.)
- **Security Configuration Getters**: `get_configure_block_enabled`, `get_config_lock_enabled`, `get_uninstall_protection_mode`
- **Pause Configuration Getters**: `get_pause_enabled`, `get_pause_duration`
- **Time Configuration**: `get_check_interval`, `get_time_display_format`, `set_time_display_format`
- **Parsing Functions**: `parse_config`, `parse_lock_hours`, `parse_uninstall_lock_hours`
- **Migration/Utility**: `migrate_config_to_minute_format`
- **Special Case**: `get_popup_dimensions()` is very large (~310 lines) due to size mode handling

#### Dependencies
- **Depends on**: None (base module)
- **Depended upon by**: Almost all other modules

#### Code Organization
- Current organization: Constants, then getter functions grouped by feature, then parsing functions
- Logical sections: Constants, popup config, security config, pause config, time config, parsing
- Repeated patterns: All getter functions follow same pattern (check file exists, grep value, validate, return default)

#### Refactoring Opportunities

##### Opportunity 1: Extract Popup Size Configuration to Separate Module

**Proposed Structure**:
- New module: `lib/config-popup-size.sh`
  - Functions to move: `get_popup_size`, `get_popup_dimensions`, `get_popup_size_mode`, `get_popup_size_custom`, `get_popup_size_custom_absolute`
  - Constants to move: `DEFAULT_POPUP_SIZE`, popup size-related constants
- Remaining in original: Other configuration getters, parsing functions

**Migration Strategy**:
1. Create new module file
2. Move popup size functions and constants
3. Update source statements in files that use these functions
4. Test popup size configuration

**Benefits**:
- Reduces original file by ~400 lines
- Groups related popup size functionality together
- Makes popup size configuration more maintainable
- `get_popup_dimensions()` is very large and would benefit from isolation

**Evaluation**:
- **Ease of Implementation**: 4/5 - Functions are well-contained, clear dependencies
- **Safety**: 4/5 - Low risk, functions are independent getters
- **Practicality**: 4/5 - Good benefit, large functions moved
- **Recommendation**: 4/5 - Should be done
- **Overall Score**: 4.00/5

**Priority**: High

##### Opportunity 2: Extract Configuration Parsing Functions

**Proposed Structure**:
- New module: `lib/config-parsing.sh`
  - Functions to move: `parse_config`, `parse_lock_hours`, `parse_uninstall_lock_hours`, `migrate_config_to_minute_format`
- Remaining in original: Configuration getters

**Migration Strategy**:
1. Create new module file
2. Move parsing functions
3. Update source statements
4. Test configuration parsing

**Benefits**:
- Reduces original file by ~200 lines
- Separates parsing logic from getter logic
- Improves organization

**Evaluation**:
- **Ease of Implementation**: 4/5 - Functions are independent
- **Safety**: 4/5 - Low risk, parsing functions are well-tested
- **Practicality**: 3/5 - Moderate benefit
- **Recommendation**: 3/5 - Worth considering
- **Overall Score**: 3.50/5

**Priority**: Medium

##### Opportunity 3: Extract Security Configuration Getters

**Proposed Structure**:
- New module: `lib/config-security.sh`
  - Functions to move: `get_configure_block_enabled`, `get_config_lock_enabled`, `get_uninstall_protection_mode`
- Remaining in original: Other configuration getters

**Migration Strategy**:
1. Create new module file
2. Move security getters
3. Update source statements
4. Test security configuration

**Benefits**:
- Reduces original file by ~100 lines
- Groups security-related configuration together
- Improves organization

**Evaluation**:
- **Ease of Implementation**: 4/5 - Simple extraction
- **Safety**: 4/5 - Low risk
- **Practicality**: 3/5 - Moderate benefit
- **Recommendation**: 3/5 - Worth considering
- **Overall Score**: 3.50/5

**Priority**: Medium

---

### File: configure-dialogs.sh

**Location**: `lib/configure-dialogs.sh`  
**Line Count**: 1128  
**Exceeds Threshold**: Yes

#### Function Inventory
- `_dialog_safe_array_items()` (lines 44-51): Helper for sanitizing arrays
- `show_info_dialog()` (lines 54-85): Information message dialog
- `show_error_dialog()` (lines 88-119): Error message dialog
- `parse_normalized_time_to_12h()` (lines 123-160): Parse time to 12-hour format
- `show_time_selection_dialog()` (lines 168-193): Time selection dialog wrapper
- `show_time_selection_dialog_yad()` (lines 196-255): YAD time selection implementation
- `show_time_selection_dialog_zenity()` (lines 258-320): Zenity time selection implementation
- `show_time_selection_dialog_kdialog()` (lines 323-363): KDialog time selection implementation
- `show_question_dialog()` (lines 366-406): Yes/No question dialog
- `show_entry_dialog()` (lines 411-510): Text input dialog
- `show_list_dialog()` (lines 513-605): Selection from list dialog
- `show_text_info_dialog()` (lines 608-641): Display text file/content dialog
- `show_multi_column_list_dialog()` (lines 655-897): Multi-column list dialog (242 lines!)
- `manage_ranges_dialog()` (lines 904-1128): Manage multiple time ranges dialog (224 lines!)

#### Function Groupings
- **Basic Dialogs**: `show_info_dialog`, `show_error_dialog`, `show_question_dialog`, `show_entry_dialog`, `show_list_dialog`, `show_text_info_dialog`
- **Time Selection Dialogs**: `show_time_selection_dialog`, `show_time_selection_dialog_yad`, `show_time_selection_dialog_zenity`, `show_time_selection_dialog_kdialog`, `parse_normalized_time_to_12h`
- **Complex Dialogs**: `show_multi_column_list_dialog`, `manage_ranges_dialog`
- **Helpers**: `_dialog_safe_array_items`

#### Dependencies
- **Depends on**: 
  - `configure-core.sh` (get_dialog_tool)
  - `desktop-environment.sh` (check_dialog_tool, detect_display_environment)
  - `unicode-dialog-safety.sh` (dialog_safe_text)
- **Depended upon by**: Most configuration modules

#### Code Organization
- Current organization: Helper functions, basic dialogs, time selection dialogs, complex dialogs
- Logical sections: Basic dialogs, time selection, complex dialogs
- Repeated patterns: Each dialog type has yad/zenity/kdialog implementations

#### Refactoring Opportunities

##### Opportunity 1: Extract Time Selection Dialogs to Separate Module

**Proposed Structure**:
- New module: `lib/configure-dialogs-time.sh`
  - Functions to move: `parse_normalized_time_to_12h`, `show_time_selection_dialog`, `show_time_selection_dialog_yad`, `show_time_selection_dialog_zenity`, `show_time_selection_dialog_kdialog`
- Remaining in original: Basic dialogs, complex dialogs, helpers

**Migration Strategy**:
1. Create new module file
2. Move time selection functions
3. Update source statements
4. Test time selection dialogs

**Benefits**:
- Reduces original file by ~240 lines
- Groups time-related dialog functionality together
- Improves organization

**Evaluation**:
- **Ease of Implementation**: 4/5 - Functions are well-contained
- **Safety**: 4/5 - Low risk, functions are independent
- **Practicality**: 4/5 - Good benefit
- **Recommendation**: 4/5 - Should be done
- **Overall Score**: 4.00/5

**Priority**: High

##### Opportunity 2: Extract Complex Dialogs to Separate Module

**Proposed Structure**:
- New module: `lib/configure-dialogs-complex.sh`
  - Functions to move: `show_multi_column_list_dialog`, `manage_ranges_dialog`
- Remaining in original: Basic dialogs, time selection dialogs, helpers

**Migration Strategy**:
1. Create new module file
2. Move complex dialog functions
3. Update source statements
4. Test complex dialogs

**Benefits**:
- Reduces original file by ~470 lines
- Separates complex dialogs from basic dialogs
- Improves readability

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity, `show_multi_column_list_dialog` is complex
- **Safety**: 3/5 - Moderate risk, complex dialogs are critical UI components
- **Practicality**: 4/5 - Good benefit, large functions moved
- **Recommendation**: 4/5 - Should be done
- **Overall Score**: 3.50/5

**Priority**: Medium

---

### File: configure-ui.sh

**Location**: `lib/configure-ui.sh`  
**Line Count**: 974  
**Exceeds Threshold**: Yes

#### Function Inventory
- `confirm_cancel()` (lines 30-50): Confirm cancellation dialog
- `confirm_skip_day()` (lines 53-91): Confirm skipping a day
- `show_help_dialog()` (lines 94-154): Display configuration help
- `show_welcome()` (lines 157-208): Show welcome message
- `ask_weekday_together()` (lines 211-228): Ask if configuring weekdays together
- `ask_weekend_together()` (lines 231-250): Ask if configuring weekends together
- `ask_what_to_edit()` (lines 255-340): Ask what to edit (restricted hours, lock hours, or both)
- `show_success()` (lines 343-370): Show success message
- `show_24_7_error()` (lines 374-404): Show error dialog for 24/7 restrictions
- `show_high_restriction_warning()` (lines 409-447): Show warning dialog for high restriction levels
- `calculate_restriction_end_time()` (lines 458-577): Calculate when current restriction period ends (119 lines!)
- `show_config_locked_error()` (lines 586-961): Show error when configure.sh/manage.sh is blocked (375 lines!)
- `show_config_file_locked_error()` (lines 969-975): Show error when config file is locked

#### Function Groupings
- **Confirmation Dialogs**: `confirm_cancel`, `confirm_skip_day`
- **Information Dialogs**: `show_help_dialog`, `show_welcome`, `show_success`
- **Input Dialogs**: `ask_weekday_together`, `ask_weekend_together`, `ask_what_to_edit`
- **Error/Warning Dialogs**: `show_24_7_error`, `show_high_restriction_warning`, `show_config_locked_error`, `show_config_file_locked_error`
- **Utility Functions**: `calculate_restriction_end_time`

#### Dependencies
- **Depends on**: 
  - `configure-core.sh` (has_dialog_tool, CONFIG_FILE)
  - `configure-dialogs.sh` (dialog abstraction functions)
  - `configure-time.sh` (format_ranges_human)
  - `config.sh` (parse_config, parse_lock_hours)
  - `time-validation.sh` (is_restricted_time, is_hour_in_single_range)
- **Depended upon by**: Configuration modules

#### Code Organization
- Current organization: Grouped by function type (confirmation, information, input, error)
- Logical sections: Confirmation, information, input, error/warning, utility
- Repeated patterns: `show_config_locked_error()` is extremely large (375 lines) with complex logic

#### Refactoring Opportunities

##### Opportunity 1: Extract show_config_locked_error() Logic

**Proposed Structure**:
- Keep in original: `show_config_locked_error()` as orchestrator (~100 lines)
- New helper functions in same file or `configure-ui-helpers.sh`:
  - `determine_lock_type()` - Determines if blocked by restriction, lock hours, or both
  - `format_active_ranges()` - Formats active restriction/lock ranges for display
  - `calculate_lock_end_info()` - Calculates when lock ends
  - `build_lock_error_message()` - Builds error message based on lock type
  - `display_lock_error_gui()` - GUI error display
  - `display_lock_error_text()` - Text error display

**Migration Strategy**:
1. Extract helper functions from `show_config_locked_error()`
2. Refactor main function to call helpers
3. Test error display in both modes

**Benefits**:
- Reduces `show_config_locked_error()` from 375 lines to ~100 lines
- Improves readability and testability
- Makes error message building logic reusable

**Evaluation**:
- **Ease of Implementation**: 3/5 - Moderate complexity, function is large but cohesive
- **Safety**: 3/5 - Moderate risk, error display is important
- **Practicality**: 4/5 - Good benefit, large function refactored
- **Recommendation**: 4/5 - Should be done
- **Overall Score**: 3.50/5

**Priority**: Medium

##### Opportunity 2: Extract calculate_restriction_end_time() to Time Utilities

**Proposed Structure**:
- New module: `lib/time-utilities.sh` or move to `configure-time.sh`
  - Function to move: `calculate_restriction_end_time`
- Remaining in original: UI dialogs

**Migration Strategy**:
1. Move function to time utilities module
2. Update source statements
3. Test restriction end time calculation

**Benefits**:
- Groups time calculation logic together
- Makes function reusable outside UI context
- Improves organization

**Evaluation**:
- **Ease of Implementation**: 4/5 - Simple move
- **Safety**: 4/5 - Low risk
- **Practicality**: 3/5 - Moderate benefit
- **Recommendation**: 3/5 - Worth considering
- **Overall Score**: 3.50/5

**Priority**: Medium

---

### File: install.sh

**Location**: `install.sh`  
**Line Count**: 930  
**Exceeds Threshold**: Yes

#### Function Inventory
- Utility functions: `print_success`, `print_error`, `print_warning`, `print_info`, `command_exists`
- Installation flow: `show_disclaimer`, `detect_distribution`, `detect_package_manager`, `check_dependencies`, `check_optional_dependencies`, `check_sudo_access`, `install_dependencies`, `check_existing_installation`, `migrate_config_to_subdirectory`, `create_directories`, `ensure_path_setup`, `get_check_interval`, `configure_service_mode`, `generate_timer_file`, `install_files`, `reload_systemd`, `enable_timer`, `verify_installation`, `print_summary`, `main`

#### Function Groupings
- **Utility Functions**: Print functions, `command_exists`
- **Dependency Management**: `detect_distribution`, `detect_package_manager`, `check_dependencies`, `check_optional_dependencies`, `check_sudo_access`, `install_dependencies`
- **Installation Steps**: `check_existing_installation`, `migrate_config_to_subdirectory`, `create_directories`, `ensure_path_setup`, `configure_service_mode`, `generate_timer_file`, `install_files`
- **Systemd Management**: `reload_systemd`, `enable_timer`
- **Verification/Summary**: `verify_installation`, `print_summary`
- **Main Flow**: `show_disclaimer`, `main`

#### Dependencies
- **Depends on**: None (standalone installation script)
- **Depended upon by**: None (entry point)

#### Code Organization
- Current organization: Utility functions, then installation flow functions, then main
- Logical sections: Utilities, dependency management, installation steps, systemd, verification
- Repeated patterns: Print functions follow same pattern

#### Refactoring Opportunities

##### Opportunity 1: Extract Dependency Management to Separate Module

**Proposed Structure**:
- New module: `lib/install-dependencies.sh`
  - Functions to move: `detect_distribution`, `detect_package_manager`, `check_dependencies`, `check_optional_dependencies`, `check_sudo_access`, `install_dependencies`
- Remaining in original: Installation steps, systemd management, main flow

**Migration Strategy**:
1. Create new module file
2. Move dependency management functions
3. Update source statement in `install.sh`
4. Test dependency installation

**Benefits**:
- Reduces original file by ~200 lines
- Separates dependency management from installation logic
- Makes dependency functions reusable

**Evaluation**:
- **Ease of Implementation**: 4/5 - Functions are well-contained
- **Safety**: 4/5 - Low risk, functions are independent
- **Practicality**: 2/5 - Benefits are real, but keeping `install.sh` self-contained may be more reliable for users running from arbitrary locations/environments
- **Recommendation**: 3/5 - Consider only if you can guarantee sourced modules are always present and easy to locate
- **Overall Score**: 3.25/5

**Priority**: Medium

##### Opportunity 2: Extract Systemd Management to Separate Module

**Proposed Structure**:
- New module: `lib/install-systemd.sh`
  - Functions to move: `generate_timer_file`, `reload_systemd`, `enable_timer`
- Remaining in original: Other installation steps

**Migration Strategy**:
1. Create new module file
2. Move systemd functions
3. Update source statement
4. Test systemd setup

**Benefits**:
- Reduces original file by ~150 lines
- Groups systemd-related functionality together
- Improves organization

**Evaluation**:
- **Ease of Implementation**: 4/5 - Simple extraction
- **Safety**: 4/5 - Low risk
- **Practicality**: 3/5 - Moderate benefit
- **Recommendation**: 3/5 - Worth considering
- **Overall Score**: 3.50/5

**Priority**: Medium

---

### File: configure-input-popup.sh

**Location**: `lib/configure-input-popup.sh`  
**Line Count**: 895  
**Exceeds Threshold**: Yes

#### Function Inventory
- `get_popup_size_config()` (lines 27-184): Get popup size from user
- `get_custom_popup_size_config()` (lines 192-447): Get custom popup size configuration (255 lines!)
- `get_min_display_time_config()` (lines 450-554): Get minimum display time
- `get_popup_immovable_config()` (lines 555-637): Get immovable setting
- `get_popup_auto_close_config()` (lines 638-740): Get auto-close setting
- `get_popup_size_mode_config()` (lines 741-828): Get popup size mode
- `get_popup_position_config()` (lines 829-895): Get popup position

#### Function Groupings
- **Popup Size Configuration**: `get_popup_size_config`, `get_custom_popup_size_config`
- **Popup Behavior Configuration**: `get_min_display_time_config`, `get_popup_immovable_config`, `get_popup_auto_close_config`
- **Popup Display Configuration**: `get_popup_size_mode_config`, `get_popup_position_config`

#### Dependencies
- **Depends on**: 
  - `configure-core.sh` (has_dialog_tool, CONFIG_FILE)
  - `configure-dialogs.sh` (dialog abstraction functions)
  - `configure-ui.sh` (confirm_cancel)
  - `display-detection.sh` (get_display_resolution)
- **Depended upon by**: `configure.sh`

#### Code Organization
- Current organization: Functions grouped by configuration type
- Logical sections: Size, behavior, display
- Repeated patterns: All functions follow similar pattern (GUI/text mode branching, validation, cancellation handling)

#### Refactoring Opportunities

##### Opportunity 1: Extract Custom Popup Size Configuration

**Proposed Structure**:
- New module: `lib/configure-input-popup-size.sh`
  - Functions to move: `get_popup_size_config`, `get_custom_popup_size_config`
- Remaining in original: Other popup configuration functions

**Migration Strategy**:
1. Create new module file
2. Move popup size functions
3. Update source statements
4. Test popup size configuration

**Benefits**:
- Reduces original file by ~420 lines
- Groups popup size configuration together
- `get_custom_popup_size_config()` is large (255 lines) and benefits from isolation

**Evaluation**:
- **Ease of Implementation**: 4/5 - Functions are well-contained
- **Safety**: 4/5 - Low risk
- **Practicality**: 4/5 - Good benefit
- **Recommendation**: 4/5 - Should be done
- **Overall Score**: 4.00/5

**Priority**: High

---

### File: configure-input-features.sh

**Location**: `lib/configure-input-features.sh`  
**Line Count**: 878  
**Exceeds Threshold**: Yes

#### Function Inventory
- `get_configure_block_enabled_config()` (starts ~line 26): Prompt for script blocking during restricted hours (Enhancement #19)
- `get_security_settings_config()` (starts ~line 107): Combined prompt for script blocking + config locking (Enhancements #19 + #18)
- `get_config_lock_enabled_config()` (starts ~line 233): Prompt for config locking (Enhancement #18)
- `get_pause_enabled_config()` (starts ~line 336): Prompt for pause enable (Enhancement #21)
- `get_pause_duration_config()` (starts ~line 417): Prompt for pause duration (Enhancement #21)
- `get_pause_once_per_day_config()` (starts ~line 490): Once-per-day pause (note: comments elsewhere imply this is fixed; confirm whether this is legacy/UI-only)
- `get_uninstall_protection_mode_config()` (starts ~line 570): Prompt for uninstall protection mode (Enhancement #26)
- `get_dialog_tool_selection()` (starts ~line 681): Prompt for dialog tool selection (Enhancement #25)

#### Function Groupings
- **Security toggles**: `get_configure_block_enabled_config`, `get_config_lock_enabled_config`, `get_security_settings_config`
- **Pause feature**: `get_pause_enabled_config`, `get_pause_duration_config`, `get_pause_once_per_day_config`
- **Uninstall protection**: `get_uninstall_protection_mode_config`
- **Dialog tool selection**: `get_dialog_tool_selection`

#### Dependencies
- **Depends on**:
  - `configure-core.sh` (for `has_dialog_tool`, `CONFIG_FILE`)
  - `configure-dialogs.sh` (dialog abstraction functions)
  - `configure-ui.sh` (for `confirm_cancel`)
  - `config.sh` (indirectly, for `get_dialog_tool_config` when available)
  - `desktop-environment.sh` / display helpers (indirectly, via `detect_display_environment` / `check_dialog_tool` when available)
- **Depended upon by**:
  - `configure.sh` (wizard entrypoint)

#### Code Organization
- Current organization: One function per feature toggle, each with GUI/text-mode branches and per-setting validation.
- Repeated patterns:
  - Many functions do the same “read current setting → prompt user → handle cancel → validate boolean/enum” flow.
  - `get_security_settings_config()` duplicates the interaction logic of the individual toggles rather than composing them.

#### Refactoring Opportunities

##### Opportunity 1: Introduce a Shared “Boolean/Enum Prompt” Helper and Use It Everywhere

**Proposed Structure**:
- Add internal helpers (same file, or a small `lib/configure-input-helpers.sh`):
  - `prompt_bool_setting(...)`
  - `prompt_enum_setting(...)`
- Update each feature-toggle function to call the helper(s).

**Migration Strategy**:
1. Create helper(s) first and add tests (where possible) around edge cases (cancel/default handling).
2. Refactor one function at a time (e.g., config lock, then configure block) to reduce risk.

**Benefits**:
- Reduces duplication and keeps behavior consistent across toggles.
- Makes it easier to adjust cancel/default policy globally.

**Evaluation**:
- **Ease of Implementation**: 4/5 - Mechanical refactor, mostly localized.
- **Safety**: 4/5 - Low risk if done incrementally and tested.
- **Practicality**: 4/5 - High leverage; reduces ongoing maintenance cost.
- **Recommendation**: 4/5
- **Overall Score**: 4.00/5

**Priority**: High

##### Opportunity 2: Remove/Clarify `get_pause_once_per_day_config()` if Pause Is Truly Non-Configurable

**Proposed Structure**:
- If once-per-day is hard policy (as other docs/UI suggest), remove the prompt and any config surface for it, or mark it as legacy/no-op and hide it from menus.

**Benefits**:
- Reduces UI complexity and eliminates “settings that don’t actually do anything”.

**Evaluation**:
- **Ease of Implementation**: 3/5 - Depends on usage sites and backward-compat needs.
- **Safety**: 3/5 - Moderate risk if other scripts expect the setting.
- **Practicality**: 3/5
- **Recommendation**: 3/5
- **Overall Score**: 3.00/5

**Priority**: Medium

---

### File: status.sh

**Location**: `status.sh`  
**Line Count**: 812  
**Exceeds Threshold**: Yes

#### Function Inventory
- `print_header()` (starts ~line 101): Section headers
- `print_status()` (starts ~line 110): Labeled status rows with severity coloring
- `format_hour_12h()`, `format_range_human()`, `format_ranges_human()` (starts ~lines 126/162/223): Human formatting helpers (note: overlaps with `configure-time.sh`)
- `check_installation()` (starts ~line 250): Detect installed vs local run, locate config/timer files
- `check_service_status()` (starts ~line 284): systemd timer/service checks
- `show_configuration()` (starts ~line 367): Parses config and displays many settings (largest function)
- `show_tips()` (starts ~line 751): Quick commands
- `main()` (starts ~line 785): Entry point

#### Dependencies
- **Depends on**:
  - `lib/library-loader.sh` (via `source_optional_lib` pattern) when available
  - Optionally `config.sh` (for `get_popup_dimensions`, `get_dialog_tool_config`, etc.)
  - Optionally `desktop-environment.sh`, `pause-state.sh`
  - system tools: `systemctl`, `grep`, `awk`, `sed`, `date`
- **Depended upon by**:
  - None (entrypoint script)

#### Code Organization
- Current organization: Library loading, color setup, formatting helpers, then status checks.
- Repeated patterns:
  - Manual `grep/cut/tr` parsing of config values inside `show_configuration()` duplicates logic already present in `lib/config.sh` getters.
  - Time-range human formatting duplicates logic that exists (or could exist) in `configure-time.sh`.

#### Refactoring Opportunities

##### Opportunity 1: Prefer `lib/config.sh` Getters in `show_configuration()` (when available)

**Proposed Structure**:
- If `config.sh` is sourced successfully, use `get_check_interval`, `get_popup_size`, `get_popup_position`, `get_min_display_time`, `get_popup_immovable`, etc. instead of re-parsing with `grep`.
- Keep the existing manual parsing as fallback when `config.sh` isn’t available.

**Benefits**:
- Reduces duplication and ensures status output matches runtime behavior.
- Shrinks `show_configuration()` significantly.

**Evaluation**:
- **Ease of Implementation**: 3/5 - Needs careful handling of `CONFIG_FILE` fallback logic.
- **Safety**: 4/5 - Status-only changes; low risk to core behavior.
- **Practicality**: 4/5
- **Recommendation**: 4/5
- **Overall Score**: 3.75/5

**Priority**: Medium

##### Opportunity 2: Consolidate Human Time Formatting with `configure-time.sh`

**Benefits**:
- Single source of truth for time formatting; fewer subtle inconsistencies.

**Evaluation**:
- **Ease of Implementation**: 3/5
- **Safety**: 4/5
- **Practicality**: 3/5
- **Recommendation**: 3/5
- **Overall Score**: 3.25/5

**Priority**: Medium

---

### File: configure-config.sh

**Location**: `lib/configure-config.sh`  
**Line Count**: 780  
**Exceeds Threshold**: Yes

#### Function Inventory
- `load_existing_config()` (starts ~line 23): Reads config file into globals/arrays (many `grep` reads + array population)
- `update_timer_file()` (starts ~line 294): Rewrites the systemd timer file based on interval
- `write_config()` (starts ~line 372): Writes config with complex argument parsing (config_lines + optional lock/uninstall arrays + override flags) and atomic write

#### Dependencies
- **Depends on**:
  - `configure-core.sh` (for `CONFIG_DIR`, `CONFIG_FILE`, `TIMER_FILE`, `SERVICE_NAME`, `DAY_NAMES`, `DAY_VARS`, `minutes_to_oncalendar`)
  - system tools: `systemctl`, `grep`, `sed`, `mktemp`, `mv`, `cp`, `date`
- **Depended upon by**:
  - `configure.sh` (wizard entrypoint)

#### Code Organization
- `write_config()` is doing multiple jobs:
  - parse heterogeneous argv (including optional arrays and flags)
  - generate a long, commented config file header
  - write day restrictions + lock hours + uninstall lock hours sections
  - perform atomic write and post-write effects (timer update via caller)
- `load_existing_config()` duplicates parsing logic found elsewhere (notably in `lib/config.sh` getters).
- `update_timer_file()` duplicates timer-file generation concepts that also exist in `install.sh`.

#### Refactoring Opportunities

##### Opportunity 1: Split `write_config()` into Focused Helpers (Keep Public Signature Stable)

**Proposed Structure** (inside `configure-config.sh`):
- `_parse_write_config_args(...)` → returns structured arrays/flags
- `_write_config_header(...)`
- `_write_restrictions_section(...)`
- `_write_lock_hours_section(...)`
- `_write_uninstall_lock_hours_section(...)`
- `_atomic_replace_file(...)`

**Benefits**:
- Improves readability and reduces regression risk by isolating parsing from output generation.
- Makes it easier to test the parsing logic separately (even in shell).

**Evaluation**:
- **Ease of Implementation**: 3/5 - Some complexity but mostly mechanical extraction.
- **Safety**: 3/5 - Config writing is critical; needs careful tests.
- **Practicality**: 5/5 - High leverage: this function is a maintenance hotspot.
- **Recommendation**: 5/5
- **Overall Score**: 4.00/5

**Priority**: High

##### Opportunity 2: Deduplicate “Read Config” Logic by Composing with `lib/config.sh` Where Reasonable

**Benefits**:
- Fewer divergent parsing paths; status/wizard/runtime stay aligned.

**Evaluation**:
- **Ease of Implementation**: 2/5 - Requires deciding the single source of truth for defaults and legacy fallbacks.
- **Safety**: 3/5
- **Practicality**: 4/5
- **Recommendation**: 4/5
- **Overall Score**: 3.25/5

**Priority**: Medium

---

## Prioritized Recommendations

### High Priority (Overall Score ≥ 4.0)

1. **Extract Dialog Tool Implementations from show_warning()** - Score: 4.00/5
   - File: `lib/popup-display.sh`
   - Justification: Eliminates massive code duplication (zenity/yad/kdialog implementations repeated multiple times), reduces `show_warning()` from ~1010 lines to ~300-400 lines

2. **Extract Popup PID Management to Separate Module** - Score: 4.00/5
   - File: `lib/popup-display.sh`
   - Justification: Clear module boundary, improves separation of concerns, reduces file by ~200 lines

3. **Extract Popup Size Configuration from config.sh** - Score: 4.00/5
   - File: `lib/config.sh`
   - Justification: Large functions (`get_popup_dimensions` is ~310 lines), groups related functionality, reduces file by ~400 lines

4. **Extract Window Size Display Formatting** - Score: 4.00/5
   - File: `lib/configure-display.sh`
   - Justification: Eliminates ~150 lines of duplicated code between `show_main_menu()` and `show_summary()`

5. **Extract Time Selection Dialogs** - Score: 4.00/5
   - File: `lib/configure-dialogs.sh`
   - Justification: Groups time-related dialog functionality, reduces file by ~240 lines

6. **Split `write_config()` into focused helpers (keep signature stable)** - Score: 4.00/5
   - File: `lib/configure-config.sh`
   - Justification: Highest-maintenance hotspot in config writing; isolates argv parsing from file generation; makes testing/refactoring safer.

7. **Extract Custom Popup Size Configuration** - Score: 4.00/5
   - File: `lib/configure-input-popup.sh`
   - Justification: Large function (`get_custom_popup_size_config` is 255 lines), reduces file by ~420 lines

8. **Introduce shared prompt helpers for feature toggles** - Score: 4.00/5
   - File: `lib/configure-input-features.sh`
   - Justification: Removes repeated “prompt/cancel/default/validate” patterns; keeps behavior consistent across settings.

### Medium Priority (Overall Score 3.0-3.9)

1. **Extract Popup Process Control Functions** - Score: 3.50/5
   - File: `lib/popup-display.sh`
   - Justification: Smaller impact but improves organization

2. **Split show_main_menu() into Smaller Functions** - Score: 3.50/5
   - File: `lib/configure-display.sh`
   - Justification: Improves readability, reduces function from 428 lines to ~100 lines

3. **Split show_summary() into Smaller Functions** - Score: 3.50/5
   - File: `lib/configure-display.sh`
   - Justification: Improves readability, reduces function from 449 lines to ~150 lines

4. **Extract Configuration Parsing Functions** - Score: 3.50/5
   - File: `lib/config.sh`
   - Justification: Separates parsing logic from getter logic

5. **Extract Security Configuration Getters** - Score: 3.50/5
   - File: `lib/config.sh`
   - Justification: Groups security-related configuration together

6. **Extract Complex Dialogs** - Score: 3.50/5
   - File: `lib/configure-dialogs.sh`
   - Justification: Separates complex dialogs from basic dialogs, reduces file by ~470 lines

7. **Extract show_config_locked_error() Logic** - Score: 3.50/5
   - File: `lib/configure-ui.sh`
   - Justification: Reduces function from 375 lines to ~100 lines, improves readability

8. **Extract calculate_restriction_end_time()** - Score: 3.50/5
   - File: `lib/configure-ui.sh`
   - Justification: Groups time calculation logic together

9. **Prefer `lib/config.sh` getters in `status.sh` (fallback to grep parsing)** - Score: 3.75/5
   - File: `status.sh`
   - Justification: Reduces duplication; status output matches runtime behavior more closely.

10. **Extract Dependency Management from install.sh (optional)** - Score: 3.25/5
   - File: `install.sh`
   - Justification: Improves organization, but consider keeping `install.sh` self-contained to minimize “missing sourced file” failure modes.

11. **Extract Systemd Management from install.sh (optional)** - Score: 3.50/5
   - File: `install.sh`
   - Justification: Groups systemd-related functionality together

## Files Appropriately Large

- **install.sh** (930 lines): While it has refactor opportunities, it may be *pragmatically appropriate* to keep largely self-contained for reliability/portability. Prefer internal helper extraction first; split into sourced modules only if distribution/runtime guarantees are clear.
- **status.sh** (812 lines): Similar trade-off: it’s an entrypoint and should stay robust when run from multiple contexts. Refactors that *reduce duplication via existing libs* are attractive; deep module-splitting is optional.

## Observations and Patterns

1. **Massive Functions**: Several files contain extremely large functions (1000+ lines):
   - `show_warning()` in `popup-display.sh` (~1010 lines)
   - `show_main_menu()` in `configure-display.sh` (428 lines)
   - `show_summary()` in `configure-display.sh` (449 lines)
   - `show_config_locked_error()` in `configure-ui.sh` (375 lines)
   - `get_popup_dimensions()` in `config.sh` (~310 lines)

2. **Code Duplication**: Significant duplication found:
   - Dialog tool implementations (zenity/yad/kdialog) repeated multiple times in `popup-display.sh`
   - Window size formatting duplicated in `configure-display.sh`

3. **Module Boundaries**: Clear opportunities for better module boundaries:
   - PID management vs display logic
   - Configuration getters vs parsing logic
   - Basic dialogs vs complex dialogs
   - Dependency management vs installation logic

4. **Consistent Patterns**: Most configuration getter functions follow the same pattern, suggesting potential for helper functions or code generation.

## Next Steps

- [ ] Review prioritized recommendations with team/user
- [ ] Create implementation plans for high-priority refactorings
- [ ] Schedule refactoring work
- [ ] Update this assessment after refactorings are completed
- [ ] Before implementation, decide whether entrypoints (`install.sh`, `status.sh`) should remain largely self-contained vs. split into sourced submodules (reliability trade-off).
