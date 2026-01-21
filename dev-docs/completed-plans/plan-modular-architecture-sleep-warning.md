# Modular Architecture - Sleep Warning System

## Overview

The Sleep Warning System has been refactored from a monolithic 1667-line script into a modular architecture with 7 focused library modules plus a streamlined main entry point (128 lines). This document describes the modular structure, the rationale behind it, and guidelines for future development.

## Benefits of Modular Architecture

1. **Maintainability**: Each module focuses on a specific domain, making it easier to understand and modify
2. **Testability**: Individual modules can be tested in isolation
3. **Reusability**: Modules can be reused by other scripts (e.g., configure.sh, manage.sh)
4. **Clarity**: Dependencies between components are explicit
5. **Collaboration**: Multiple developers can work on different modules simultaneously
6. **Debugging**: Easier to identify which module contains a bug

## Module Structure

The system is organized into 8 library modules located in the `lib/` directory, plus the main entry point:

```
LinuxTimerWarning/
├── sleep-warning.sh          # Main entry point (~128 lines)
└── lib/
    ├── config.sh             # Configuration management (~260 lines)
    ├── logging.sh            # Logging functions (~60 lines)
    ├── time-calculations.sh  # Time calculation functions (~601 lines) [NEW]
    ├── display-detection.sh  # Display environment detection (~360 lines)
    ├── desktop-environment.sh # Desktop/dialog tool detection (~80 lines)
    ├── window-management.sh  # Window manipulation (~450 lines)
    ├── time-validation.sh    # Time range validation (~140 lines)
    └── popup-display.sh      # Warning popup display (~424 lines)
```

**Total reduction**: From 1667 lines (monolithic) to ~2,443 lines across 9 files, with significantly improved organization and a 92% reduction in main script size. The `time-calculations.sh` module was added in 2026-01-21 to consolidate time calculation functions from `popup-display.sh`.

## Module Dependency Graph

```
sleep-warning.sh (main)
    ├── config.sh (no dependencies)
    ├── logging.sh (depends on: config.sh)
    ├── configure-validation.sh (depends on: configure-core.sh)
    ├── time-calculations.sh (depends on: config.sh, configure-validation.sh, configure-core.sh) [NEW]
    ├── display-detection.sh (no dependencies)
    ├── desktop-environment.sh (no dependencies)
    ├── window-management.sh (depends on: config.sh)
    ├── time-validation.sh (depends on: logging.sh)
    └── popup-display.sh (depends on: all above modules, including time-calculations.sh)
```

**Source Order** (in sleep-warning.sh):
```bash
source "${LIB_DIR}/config.sh" || exit 1
source "${LIB_DIR}/logging.sh" || exit 1
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/configure-validation.sh" || exit 1
source "${LIB_DIR}/time-calculations.sh" || exit 1  # NEW: Consolidated time calculations
source "${LIB_DIR}/display-detection.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/window-management.sh" || exit 1
source "${LIB_DIR}/time-validation.sh" || exit 1
source "${LIB_DIR}/popup-display.sh" || exit 1
```

This order ensures all dependencies are satisfied before modules that depend on them are loaded.

## Module Descriptions

### 1. config.sh - Configuration Management

**Purpose**: Central configuration management for all settings and defaults.

**Functions** (8 total):
- `get_check_interval()` - Read check interval from config file
- `get_popup_size()` - Read popup size setting
- `get_popup_dimensions()` - Convert size name to width/height
- `get_popup_position()` - Read popup position setting
- `get_min_display_time()` - Read minimum display time
- `get_popup_immovable()` - Read immovable window setting
- `parse_config()` - Parse restricted hours for a given day

**Global Variables**:
- `SCRIPT_NAME` - Script identifier
- `CONFIG_DIR` - Configuration directory path
- `CONFIG_FILE` - Configuration file path
- `LOG_FILE` - Log file path
- `MAX_LOG_SIZE` - Maximum log file size
- `DEFAULT_*` - Various default values
- `DEFAULT_HOURS` - Associative array of default restricted hours

**Dependencies**: None (base module)

**When to add functions**: Configuration parsing, default value management, setting retrieval

---

### 2. logging.sh - Logging Functions

**Purpose**: Handles logging to systemd journal and file-based logging with rotation.

**Functions** (2 total):
- `log_message()` - Log to systemd journal
- `log_to_file()` - Log to file with automatic rotation

**Dependencies**: config.sh (for CONFIG_DIR, LOG_FILE, MAX_LOG_SIZE, SCRIPT_NAME)

**When to add functions**: New logging formats, additional log targets, log analysis helpers

---

### 3. display-detection.sh - Display Environment Detection

**Purpose**: Comprehensive display environment detection for X11, Wayland, and gamescope.

**Functions** (11 total):
- `append_display_detection_step()` - Build detection trace
- `validate_display_format()` - Validate X11 display format
- `is_x11_display_accessible()` - Check X11 display availability
- `is_wayland_display_accessible()` - Check Wayland socket availability
- `find_wayland_socket_candidate()` - Find Wayland socket
- `detect_wayland_with_helpers()` - Use compositor helpers for detection
- `is_gamescope_running()` - Detect gamescope session
- `get_loginctl_session_id()` - Get user's loginctl session
- `detect_display_environment()` - Main detection function (returns: x11/wayland/gamescope/unknown)
- `get_display_identifier()` - Get DISPLAY or WAYLAND_DISPLAY value
- `get_display()` - Get display with fallback logic

**Global Variables**:
- `DISPLAY_DETECTION_PATH` - Detection trace string
- `DISPLAY_DETECTION_NOTE` - Detection notes/warnings

**Dependencies**: None (standalone)

**When to add functions**: New display protocols, additional detection methods, display-related utilities

---

### 4. desktop-environment.sh - Desktop Environment Detection

**Purpose**: Detect desktop environment and available dialog tools.

**Functions** (2 total):
- `is_kde()` - Detect if running on KDE
- `check_dialog_tool()` - Find best dialog tool for environment (returns: zenity/yad/kdialog or empty)

**Priority order**:
- Wayland/gamescope: yad > kdialog > zenity
- KDE: kdialog > yad > zenity
- Default: zenity > yad > kdialog

**Dependencies**: None (standalone)

**When to add functions**: Additional desktop environment detection (GNOME, XFCE, etc.), new dialog tool support

---

### 5. window-management.sh - Window Manipulation

**Purpose**: All window manipulation functionality for popup behavior control.

**Functions** (10 total):
- `check_window_tools()` - Detect available window tools (returns: wmctrl/xdotool or empty)
- `detect_window_state_x11()` - Detect active window state on X11
- `detect_window_state_wayland()` - Detect active window state on Wayland
- `detect_window_state()` - Wrapper for environment-aware state detection
- `make_window_unclosable()` - Apply window restrictions
- `keep_window_on_top()` - Make window stay on top (with retries)
- `keep_window_on_top_periodic()` - Continuously enforce stay-on-top (background)
- `make_window_immovable()` - Monitor and restore window position (background)
- `reenable_window_closing()` - Remove window restrictions
- `calculate_popup_geometry()` - Calculate popup position coordinates

**Dependencies**: config.sh (for `get_popup_immovable()`)

**When to add functions**: New window manipulation features, additional window managers, Wayland-specific tools

---

### 6. time-validation.sh - Time Range Validation

**Purpose**: Validate and check time ranges, including overnight ranges that span midnight.

**Functions** (4 total):
- `validate_single_range()` - Validate a single START-END range
- `validate_hour_range()` - Validate comma-separated multiple ranges
- `is_hour_in_single_range()` - Check if hour falls within single range
- `is_restricted_hour()` - Check if hour falls within any configured range

**Range Format**: `START-END` (e.g., "0-5" for midnight to 5AM, "23-6" for 11PM to 6AM)

**Dependencies**: logging.sh (for `log_message()`)

**When to add functions**: Minute-level validation, timezone handling, date range support

---

### 7. popup-display.sh - Warning Popup Display

**Purpose**: Display warning popups with environment-aware configuration.

**Functions** (1 total):
- `show_warning()` - Main popup display function with full lifecycle management

**This module orchestrates**:
- Display environment detection
- Dialog tool selection
- Popup configuration (size, position, duration)
- Window manipulation (stay-on-top, immovable, minimum display time)
- Logging and error handling
- notify-send fallback

**Dependencies**: ALL previous modules (config, logging, time-calculations, display-detection, desktop-environment, window-management) [Note: Time calculation functions were moved from this module to time-calculations.sh in 2026-01-21]

**When to add functions**: New popup types, additional message customization, alternative notification methods

---

### 9. sleep-warning.sh - Main Entry Point

**Purpose**: Streamlined entry point that sources modules and contains main logic.

**Structure**:
```bash
#!/bin/bash
# Header comments

# Determine script directory and lib location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source all modules
source "${LIB_DIR}/config.sh" || exit 1
# ... (source remaining modules)

# Main function
main() {
    # Get current day and hour
    # Parse configuration
    # Check if restricted hour (including overnight ranges)
    # Show warning if restricted
}

# Execute main
main "$@"
```

**When to modify**: Only for main logic changes, not for implementation details (those go in modules)

## Installation and Paths

### Development Environment

During development, the script uses relative paths:
```bash
LIB_DIR="${SCRIPT_DIR}/lib"
```

### Installed Environment

When installed via `install.sh`, files are placed at:
- Main script: `~/.local/bin/sleep-warning.sh`
- Library modules: `~/.local/lib/sleep-warning/*.sh`
- Configuration: `~/.config/sleep-warning/sleep-warning.conf`

The installer automatically updates the main script to use absolute paths:
```bash
LIB_DIR="/home/user/.local/lib/sleep-warning"
```

This is done via sed during installation:
```bash
sed "s|LIB_DIR=\"\${SCRIPT_DIR}/lib\"|LIB_DIR=\"${LIB_DIR}\"|" \
    "$SCRIPT_DIR/sleep-warning.sh" > "$INSTALL_DIR/sleep-warning.sh"
```

## Testing

A comprehensive test suite is available at `tests/test-modular-refactor.sh`:

**Tests Include**:
1. File structure validation
2. Syntax checking (all modules)
3. Module sourcing
4. Function availability
5. Functionality tests (config, display, time validation)

**Run tests**:
```bash
cd /path/to/LinuxTimerWarning
./tests/test-modular-refactor.sh
```

**Expected output**: All 10 tests passing

## Development Guidelines

### Adding a New Function

1. **Determine the appropriate module** based on function purpose
2. **Check dependencies** - does it need data from other modules?
3. **Add the function** to the appropriate module
4. **Update module header** if adding new dependencies
5. **Test in isolation** before integrating
6. **Update this documentation** if adding significant functionality

### Creating a New Module

Only create a new module if:
1. The functionality doesn't fit in existing modules
2. It's a substantial domain (30+ lines, multiple related functions)
3. It has clear boundaries and minimal dependencies

**Steps**:
1. Create `lib/new-module.sh` with proper header
2. Add functions and document dependencies
3. Update main script to source the new module (correct order!)
4. Update this documentation
5. Add tests to test suite

### Modifying Existing Modules

**Rules**:
1. **Preserve function signatures** - other code may depend on them
2. **Document breaking changes** in commit messages
3. **Update dependent modules** if changing return values/behavior
4. **Run test suite** before committing
5. **Keep modules focused** - if a function doesn't fit, move it

### Module Size Guidelines

- **Small modules** (50-100 lines): OK if focused purpose
- **Medium modules** (100-300 lines): Ideal size
- **Large modules** (300-500 lines): Consider splitting if possible
- **Very large** (500+ lines): Definitely split into sub-modules

Current module sizes:
- config.sh: ~260 lines ✓
- logging.sh: ~60 lines ✓
- display-detection.sh: ~360 lines (acceptable - complex domain)
- desktop-environment.sh: ~80 lines ✓
- window-management.sh: ~450 lines (acceptable - complex domain)
- time-validation.sh: ~140 lines ✓
- popup-display.sh: ~290 lines ✓

## Future Considerations

### Potential Module Sharing

The modular architecture enables other scripts to use these modules:

**configure.sh** (2588 lines) could potentially use:
- `lib/config.sh` - For reading/writing configuration
- `lib/time-validation.sh` - For validating user input

**manage.sh** (509 lines) could potentially use:
- `lib/config.sh` - For shared constants and settings

**Approach**:
1. Move shared modules to a common location
2. Update sourcing paths in all scripts
3. Ensure no conflicts in global variables
4. Test all scripts thoroughly after changes

### Additional Modules to Consider

1. **notification.sh** - Extract notify-send and other notification methods from popup-display.sh
2. **systemd-integration.sh** - Functions for interacting with systemd services/timers
3. **configuration-wizard.sh** - Interactive configuration helpers (for configure.sh)

## Troubleshooting

### Module Sourcing Failures

**Symptom**: Script fails with "No such file or directory" for lib modules

**Causes**:
1. Script moved without lib directory
2. Incorrect LIB_DIR path
3. Missing module file

**Solutions**:
```bash
# Check LIB_DIR is set correctly
echo "$LIB_DIR"

# Verify module files exist
ls -la "$LIB_DIR"

# For development, ensure you're in project root
cd /path/to/LinuxTimerWarning

# For installed version, verify installation
ls -la ~/.local/lib/sleep-warning/
```

### Dependency Issues

**Symptom**: Variable not found, function undefined

**Cause**: Module sourced before its dependencies

**Solution**: Check source order in main script matches dependency graph (see above)

### Function Conflicts

**Symptom**: Unexpected function behavior, wrong function called

**Cause**: Two modules define same function name

**Solution**: Use module-prefixed function names or refactor to eliminate duplication

## Version History

- **v2.0** (2026-01-19): Initial modular refactor
  - Extracted 7 modules from monolithic script
  - Reduced main script from 1667 to 128 lines (92% reduction)
  - Added comprehensive test suite
  - Updated installer/uninstaller

## Related Documentation

- [wayland-gamescope-window-tools.md](wayland-gamescope-window-tools.md) - Wayland/gamescope window management details
- [detecting-fullscreen-exclusive-mode.md](detecting-fullscreen-exclusive-mode.md) - Fullscreen detection technical details
- [../TECHNICAL_DETAILS.md](../TECHNICAL_DETAILS.md) - General technical information
- [../../README.md](../../README.md) - Project overview and usage

## Conclusion

The modular architecture significantly improves the maintainability and extensibility of the Sleep Warning System while preserving all functionality. Future development should maintain the separation of concerns and clear dependency structure established by this refactor.

For questions or suggestions about the architecture, please open an issue on GitHub or contact the development team.
