# Modular Architecture - Configuration Wizard (configure.sh)

## Overview

The Sleep Warning System Configuration Wizard has been refactored from a monolithic 2,588-line script into a modular architecture with 7 focused library modules plus a streamlined main entry point (268 lines). This document describes the modular structure, the rationale behind it, and guidelines for future development.

## Benefits of Modular Architecture

1. **Maintainability**: Each module focuses on a specific domain, making it easier to understand and modify
2. **Testability**: Individual modules can be tested in isolation
3. **Reusability**: Modules can be reused by other scripts (e.g., manage.sh)
4. **Clarity**: Dependencies between components are explicit
5. **Collaboration**: Multiple developers can work on different modules simultaneously
6. **Debugging**: Easier to identify which module contains a bug
7. **Consistency**: Matches the modular pattern established by sleep-warning.sh

## Module Structure

The system is organized into 8 library modules located in the `lib/` directory, plus the main entry point:

```
LinuxTimerWarning/
├── configure.sh              # Main entry point (~268 lines)
└── lib/
    ├── configure-core.sh         # Core utilities and constants (~76 lines)
    ├── configure-config.sh       # Config file operations (~299 lines)
    ├── configure-time.sh         # Time formatting & validation (~212 lines)
    ├── time-calculations.sh      # Time calculation functions (~601 lines) [NEW]
    ├── configure-ui.sh           # Basic UI dialogs (~258 lines)
    ├── configure-input.sh        # User input collection (~1153 lines)
    ├── configure-display.sh      # Complex displays (~611 lines)
    └── configure-workflow.sh     # Section orchestration (~263 lines)
```

**Total reduction**: From 2,588 lines (monolithic) to ~3,681 lines across 9 files, with a **90% reduction in main script size** (2,588 → 268 lines). The `time-calculations.sh` module was added in 2026-01-21 to consolidate time calculation functions from `configure-input.sh` and `popup-display.sh`.

## Module Dependency Graph

```
configure.sh (main)
    ├── configure-core.sh (no dependencies)
    ├── configure-config.sh (depends on: configure-core.sh)
    ├── configure-time.sh (depends on: configure-core.sh)
    ├── time-calculations.sh (depends on: config.sh, configure-validation.sh, configure-core.sh) [NEW]
    ├── configure-ui.sh (depends on: configure-core.sh)
    ├── configure-input.sh (depends on: configure-core, configure-ui, configure-time, time-calculations.sh)
    ├── configure-display.sh (depends on: configure-core, configure-time, configure-ui)
    └── configure-workflow.sh (depends on: all above modules)
```

**Source Order** (in configure.sh):
```bash
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/config.sh" || exit 1
source "${LIB_DIR}/configure-validation.sh" || exit 1
source "${LIB_DIR}/configure-time.sh" || exit 1
source "${LIB_DIR}/time-calculations.sh" || exit 1  # NEW: Consolidated time calculations
source "${LIB_DIR}/configure-ui.sh" || exit 1
source "${LIB_DIR}/configure-input.sh" || exit 1
source "${LIB_DIR}/configure-display.sh" || exit 1
source "${LIB_DIR}/configure-workflow.sh" || exit 1
```

This order ensures all dependencies are satisfied before modules that depend on them are loaded.

## Module Descriptions

### 1. configure-core.sh - Core Utilities and Constants

**Purpose**: Provides core utilities, constants, and helper functions used throughout the configuration wizard. Has no dependencies on other modules.

**Functions** (4 total):
- `has_zenity()` - Check if zenity is available
- `has_gui()` - Check if GUI is available
- `minutes_to_oncalendar()` - Convert minutes to systemd OnCalendar format
- `format_hour_12h()` - Format hour to 12-hour format with AM/PM

**Global Variables/Constants**:
- `SCRIPT_NAME` - Script identifier for configuration
- `CONFIG_DIR` - Configuration directory path (`~/.config/sleep-warning`)
- `CONFIG_FILE` - Configuration file path
- `SYSTEMD_USER_DIR` - Systemd user directory path
- `TIMER_FILE` - Timer file path
- `SERVICE_NAME` - Service name for systemd
- `DAY_NAMES` - Array of day names (Sunday-Saturday)
- `DAY_VARS` - Array of day variable names for config file

**Dependencies**: None (base module)

**When to add functions**: Utility functions needed by multiple modules, shared constants, basic environment detection

---

### 2. configure-config.sh - Configuration File Operations

**Purpose**: Handles all configuration file operations including reading, writing, and preserving user customizations. Also manages systemd timer file updates.

**Functions** (4 total):
- `load_existing_config()` - Load configuration from file
- `extract_user_comments()` - Preserve user comments when rewriting config
- `write_config()` - Write configuration file
- `update_timer_file()` - Update systemd timer file with new interval

**Key Features**:
- Preserves user comments in config files
- Validates configuration values before loading
- Creates config directory if it doesn't exist
- Updates systemd timer file and reloads daemon
- Backs up timer file before modifying

**Dependencies**: configure-core.sh (for CONFIG_DIR, CONFIG_FILE, TIMER_FILE, SERVICE_NAME, DAY_NAMES, DAY_VARS, minutes_to_oncalendar)

**When to add functions**: Config file parsing, writing, validation, systemd integration

---

### 3. configure-time.sh - Time Formatting and Validation

**Purpose**: Provides time range formatting, validation, and analysis functions for the configuration wizard.

**Functions** (4 total):
- `format_range_human()` - Format single time range to human-readable format
- `format_ranges_human()` - Format multiple time ranges
- `detect_overlaps()` - Detect overnight range overlaps between days
- `get_inherited_restrictions()` - Get restrictions inherited from previous day's overnight ranges

**Key Features**:
- Converts 24-hour format to 12-hour AM/PM format
- Handles overnight ranges that span midnight
- Detects and reports overlapping ranges
- Shows inherited restrictions from previous day

**Dependencies**: configure-core.sh (for DAY_NAMES, format_hour_12h)

**When to add functions**: Time formatting, range validation, overlap detection, time-based calculations

---

### 4. time-calculations.sh - Time Calculation Functions

**Purpose**: Provides time calculation functions for both configuration validation (hour-based) and runtime popup display (minute-based). This module consolidates time calculation logic that was previously scattered across `configure-input.sh` and `popup-display.sh`.

**Functions** (8 total):
- **Hour-based Calculations** (for Configuration Validation):
  - `calculate_range_duration()` - Calculate duration in hours of a single time range
  - `calculate_total_day_duration()` - Calculate total duration for a day including overnight from previous day
  - `merge_hour_intervals()` - Helper function to merge overlapping hour intervals (prevents double-counting)
- **Minute-based Calculations** (for Runtime Popup Display):
  - `build_weekly_restricted_intervals()` - Builds weekly timeline of restricted intervals in minutes
  - `get_current_minute_offset()` - Calculate current minute offset from start of week
  - `is_minute_restricted()` - Check if minute is restricted
  - `format_minute_offset_to_time()` - Format minute offset to human-readable time
  - `get_next_unrestricted_time()` - Calculate next unrestricted time

**Key Features**:
- Consolidates all time calculation logic in one place
- Separates hour-based (configuration) and minute-based (runtime) calculations
- Properly handles overlapping intervals to avoid double-counting
- Handles overnight ranges correctly (only counts portion within each day)
- Supports both configuration wizard and popup display use cases

**Dependencies**:
- `config.sh` (for `parse_config` function)
- `configure-validation.sh` (for `merge_overlapping_intervals` - used by minute-based functions)
- `configure-core.sh` (for `DAY_NAMES` - used by `format_minute_offset_to_time`)

**When to add functions**: Any new time calculation functions, shared time-related utilities

**History**: Created 2026-01-21 as part of refactoring to extract time calculation functions from `configure-input.sh` and `popup-display.sh`. This consolidation improves maintainability and reduces code duplication.

---

### 5. configure-ui.sh - User Interface Dialogs

**Purpose**: Provides basic UI dialog functions for user interaction in both GUI (zenity) and text modes.

**Functions** (7 total):
- `confirm_cancel()` - Confirm cancellation dialog
- `confirm_skip_day()` - Confirm skipping a day
- `show_help_dialog()` - Display configuration help
- `show_welcome()` - Show welcome message
- `show_success()` - Show success message
- `ask_weekday_together()` - Ask if configuring weekdays together
- `ask_weekend_together()` - Ask if configuring weekends together

**Key Features**:
- Supports both GUI (zenity) and text modes
- Provides clear, user-friendly messages
- Handles confirmation dialogs
- Shows contextual help

**Dependencies**: configure-core.sh (for has_zenity, CONFIG_FILE)

**When to add functions**: New dialog types, user confirmation prompts, information displays

---

### 6. configure-input.sh - User Input Collection

**Purpose**: Provides all user input collection functions for the configuration wizard, supporting both GUI (zenity) and text modes.

**Functions** (8 total):
- `get_hour_zenity()` - Get hour input using zenity
- `get_hour_text()` - Get hour input using text prompt
- `get_popup_size_config()` - Get popup size from user
- `get_min_display_time_config()` - Get minimum display time
- `get_popup_immovable_config()` - Get immovable setting
- `get_popup_position_config()` - Get popup position
- `get_check_interval()` - Get check interval
- `get_day_hours()` - Get time ranges for a day (complex with navigation)

**Key Features**:
- Validates all user input
- Provides clear error messages
- Supports cancel and back navigation
- Shows default values from existing config
- Handles both GUI and text input methods
- Validates time ranges (including overnight ranges)

**Dependencies**: 
- configure-core.sh (for has_zenity, CONFIG_FILE)
- configure-ui.sh (for confirm_cancel, confirm_skip_day, show_help_dialog)
- configure-time.sh (for format_ranges_human)
- time-calculations.sh (for calculate_range_duration, calculate_total_day_duration) [Note: These functions were moved from this module to time-calculations.sh in 2026-01-21]

**When to add functions**: New configuration options, additional input validation

---

### 7. configure-display.sh - Complex Display Functions

**Purpose**: Provides complex display functions including menus, grids, and summary views for the configuration wizard.

**Functions** (4 total):
- `get_section_status()` - Get status indicators for menu display
- `show_main_menu()` - Show main navigation menu
- `show_visual_grid()` - Display visual day/time grid for editing
- `show_summary()` - Show configuration summary with overlap detection

**Key Features**:
- Main navigation menu with status indicators
- Visual day/time grid for easy editing
- Configuration summary with human-readable times
- Overlap warning detection
- Inherited restriction display
- Supports both GUI and text modes

**Dependencies**:
- configure-core.sh (for has_zenity, DAY_NAMES, CONFIG_FILE)
- configure-time.sh (for format_ranges_human, detect_overlaps, get_inherited_restrictions)
- configure-ui.sh (for confirm_cancel)

**When to add functions**: New display formats, additional visualization options

---

### 8. configure-workflow.sh - Configuration Workflow Orchestration

**Purpose**: Provides high-level workflow orchestration functions that coordinate the configuration process for different sections.

**Functions** (3 total):
- `configure_weekdays_section()` - Configure all weekdays (Monday-Friday)
- `configure_weekends_section()` - Configure weekend days (Saturday-Sunday)
- `configure_day_from_grid()` - Configure a day selected from visual grid

**Key Features**:
- Orchestrates multi-step configuration workflows
- Handles bulk configuration (all weekdays/weekends together)
- Manages back navigation between days
- Applies configuration to multiple days
- Integrates with grid editing

**Dependencies**: All above modules (orchestrates the entire flow)

**When to add functions**: New configuration workflows, batch operations, complex multi-step processes

---

### 9. configure.sh - Main Entry Point

**Purpose**: Streamlined entry point that sources modules and contains main orchestration logic.

**Structure**:
```bash
#!/bin/bash
# Header comments

# Determine script directory and lib location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source all modules
source "${LIB_DIR}/configure-core.sh" || exit 1
# ... (source remaining modules)

# Main function
main() {
    # Parse command-line arguments
    # Determine GUI mode
    # Show welcome
    
    # CRITICAL: Declare global arrays and variables BEFORE calling load_existing_config()
    declare -g -a config_lines=()
    declare -g -a summary_lines=()
    declare -g check_interval popup_size popup_position min_display_time popup_immovable
    
    # Load existing configuration
    load_existing_config
    
    # Main configuration loop
    while true; do
        # Show menu and handle user choices
        # Option 1: Timer Settings
        # Option 2: Window Behavior
        # Option 3: Weekdays Configuration
        # Option 4: Weekends Configuration
        # Option 5: Visual Day/Time Grid
        # Option 6: Review and Save
    done
}

# Execute main
main "$@"
```

**When to modify**: Only for main logic changes, command-line argument handling, or high-level flow changes (implementation details go in modules)

## Critical Design Patterns

### Global Variable Declaration Strategy

**CRITICAL**: The following arrays and variables MUST be declared in `main()` BEFORE calling `load_existing_config()`:

```bash
declare -g -a config_lines=()
declare -g -a summary_lines=()
declare -g check_interval popup_size popup_position min_display_time popup_immovable
```

**Rationale**:
- `load_existing_config()` uses `declare -g` to set default values but expects arrays to already exist in the parent shell
- Sparse arrays (config_lines, summary_lines) use indices 0-6 for days and must be preserved across modules
- Variables are passed between functions via global scope to maintain state across the configuration wizard

### Nameref Pattern for Arrays

Functions that modify configuration arrays use nameref parameters:

```bash
configure_weekdays_section() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    
    # Modify arrays via nameref
    config_lines_ref[1]="${DAY_VARS[1]}=${range}"
}
```

**Note**: The `grid_result_var` pattern is used to work around nameref limitations in subshells.

### Sparse Array Handling

Configuration arrays use sparse indices (0-6) corresponding to days:
- 0 = Sunday
- 1 = Monday
- 2 = Tuesday
- 3 = Wednesday
- 4 = Thursday
- 5 = Friday
- 6 = Saturday

**Important**: When iterating, always use explicit indices rather than `${!array[@]}` to preserve sparse structure.

## Installation and Paths

### Development Environment

During development, the script uses relative paths:
```bash
LIB_DIR="${SCRIPT_DIR}/lib"
```

### Installed Environment

When installed via `install.sh`, files are placed at:
- Main script: `~/.local/bin/sleep-warning-configure`
- Library modules: `~/.local/lib/sleep-warning/configure-*.sh`
- Configuration: `~/.config/sleep-warning/config/sleep-warning.conf` (older installs may have `~/.config/sleep-warning/sleep-warning.conf`)

The installer automatically updates the main script to use absolute paths:
```bash
LIB_DIR="/home/user/.local/lib/sleep-warning"
```

This is done via sed during installation:
```bash
sed "s|LIB_DIR=\"\${SCRIPT_DIR}/lib\"|LIB_DIR=\"${LIB_DIR}\"|" \
    "$SCRIPT_DIR/configure.sh" > "$INSTALL_DIR/sleep-warning-configure"
```

## Testing

### Module Testing

The `test-configure-modular.sh` test suite verifies:
1. All 7 configure modules exist
2. All modules pass bash syntax check (`bash -n`)
3. Main script passes syntax check
4. All modules source correctly in dependency order
5. Core functions are defined after sourcing
6. Config functions are defined
7. Time formatting functions are defined
8. All constants are defined (SCRIPT_NAME, CONFIG_DIR, etc.)
9. All modules have reasonable sizes (50-1000 lines)
10. Main script is streamlined (200-350 lines)

**Usage**:
```bash
./tests/test-configure-modular.sh
```

### Functional Testing

Existing functional tests verify the wizard works correctly:
- `test-configure-text-mode.sh` - Text mode functionality
- `test-configure-comprehensive.sh` - All configuration workflows
- `test-configure-interactive.sh` - Interactive GUI workflows

## Development Guidelines

### Adding New Features

1. **Determine the appropriate module**:
   - Core utilities → configure-core.sh
   - Config file operations → configure-config.sh
   - Time formatting → configure-time.sh
   - Simple dialogs → configure-ui.sh
   - User input → configure-input.sh
   - Complex displays → configure-display.sh
   - Workflows → configure-workflow.sh

2. **Add function to module**:
   - Include clear documentation comments
   - Specify dependencies
   - Handle both GUI and text modes where applicable
   - Validate all inputs

3. **Update main() if needed**:
   - Add menu option or workflow integration
   - Keep main() focused on orchestration

4. **Test thoroughly**:
   - Run module tests
   - Run functional tests
   - Test in both GUI and text modes
   - Test navigation (back, cancel, skip)

### Modifying Existing Functions

1. **Preserve function signatures**: Other modules may depend on them
2. **Maintain backward compatibility**: Existing config files must work
3. **Update tests**: Reflect any behavior changes
4. **Document changes**: Update this file if architecture changes

### Best Practices

1. **Keep modules focused**: Each module should have a clear, single purpose
2. **Minimize dependencies**: Modules should depend on as few other modules as possible
3. **Use constants**: Define magic numbers/strings as constants in configure-core.sh
4. **Validate inputs**: Check all user input for validity
5. **Handle errors gracefully**: Provide clear error messages
6. **Support both modes**: Implement GUI (zenity) and text fallbacks
7. **Document thoroughly**: Include clear comments and docstrings

## Common Patterns

### Dual-Mode Function (GUI and Text)

```bash
my_function() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI implementation using zenity
        zenity --question --text="..." 2>/dev/null
    else
        # Text implementation
        read -p "..." answer
    fi
}
```

### Input Validation with Retry

```bash
while true; do
    # Get input
    local value=$(get_input)
    
    # Validate
    if validate_input "${value}"; then
        echo "${value}"
        return 0
    else
        show_error "Invalid input"
        continue
    fi
done
```

### Cancellation Handling

```bash
if [ "${exit_code}" -ne 0 ]; then
    if confirm_cancel "${use_gui}"; then
        echo "CANCELLED"
        return 2  # Special return code for cancellation
    else
        continue  # User wants to continue
    fi
fi
```

## Troubleshooting

### Module Sourcing Errors

**Symptom**: Error about module not found  
**Solution**: Check that LIB_DIR is set correctly and all modules exist

### Function Not Defined

**Symptom**: "command not found" error for a function  
**Solution**: Verify modules are sourced in correct dependency order

### Global Variable Issues

**Symptom**: Variables or arrays are empty  
**Solution**: Ensure arrays are declared with `declare -g -a` in main() before use

### Sparse Array Problems

**Symptom**: Array indices are incorrect (0-indexed instead of day-indexed)  
**Solution**: Use explicit indices (0-6) rather than array expansion patterns

## Migration Notes

The refactoring from monolithic to modular was completed on 2026-01-19:

**Before**:
- Single file: configure.sh (2,588 lines)
- All functionality in one script

**After**:
- Main script: configure.sh (268 lines) - 90% reduction
- 7 library modules: ~2,469 lines total
- All 34 functions preserved with identical signatures
- 100% backward compatible with existing config files

**No user-visible changes**: The wizard works identically to the original, with all features, navigation, and workflows preserved.

## Future Enhancements

Potential improvements to consider:

1. **Additional Validation**: More sophisticated time range validation
2. **Configuration Templates**: Pre-defined configuration templates (e.g., "night owl", "early bird")
3. **Import/Export**: Ability to save and load configuration profiles
4. **Advanced Scheduling**: Support for different schedules by date/season
5. **Integration**: Better integration with manage.sh for seamless configuration updates
6. **Accessibility**: Enhanced support for screen readers and accessibility tools

## References

- Main system plan: [dev-docs/linux-warning-system-plan.md](../linux-warning-system-plan.md)
- Sleep warning modular architecture: [plan-modular-architecture-sleep-warning.md](plan-modular-architecture-sleep-warning.md)
- Technical details: [dev-docs/TECHNICAL_DETAILS.md](../TECHNICAL_DETAILS.md)
- User documentation: [user-docs/CONFIGURATION.md](../../user-docs/CONFIGURATION.md)
- Test documentation: [tests/README.md](../../tests/README.md)
