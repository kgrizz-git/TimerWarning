# Enhancement 25: User-Selectable Dialog Tool

- **Description**: Allow users to manually choose which dialog tool (zenity, yad, or kdialog) to use from a list of installed tools, overriding the automatic priority system. This gives users control over dialog tool selection when they have preferences or encounter issues with the automatic selection.
- **Priority**: Medium (improves user control and troubleshooting flexibility)
- **Status**: Not implemented
- **Related**: See [enhancement-02-dialog-tool-priority-system.md](enhancement-02-dialog-tool-priority-system.md) for current automatic selection logic, and [enhancement-24-unified-dialog-priority-yad-first.md](enhancement-24-unified-dialog-priority-yad-first.md) for unified priority system

## Implementation Details

### Configuration Option

Add a new configuration option `DIALOG_TOOL` to `sleep-warning.conf`:
- **Format**: `DIALOG_TOOL=auto|zenity|yad|kdialog`
- **Default**: `auto` (uses automatic priority system)
- **Values**:
  - `auto`: Use automatic priority system (current behavior)
  - `zenity`: Force use of zenity (if installed)
  - `yad`: Force use of yad (if installed)
  - `kdialog`: Force use of kdialog (if installed)

### Configuration Wizard Integration

Add dialog tool selection to the configuration wizard (`configure.sh`):
- Add option in "Window Behavior" menu or create separate "Dialog Tool" menu option
- Show list of installed dialog tools
- Allow user to select:
  - "Automatic (recommended)" - uses priority system
  - Specific tool (zenity, yad, or kdialog) - only shown if tool is installed
- Display current selection
- Validate selection (warn if selected tool is not installed)

### Script Behavior

Modify `sleep-warning.sh` dialog tool selection logic:
1. Check `DIALOG_TOOL` configuration option
2. If set to `auto` (or not set), use current automatic priority system
3. If set to specific tool:
   - Check if tool is installed
   - If installed, use that tool
   - If not installed, log warning and fall back to automatic priority system
   - Log which tool was selected and why (user preference vs automatic)

### Files Affected

- `lib/config.sh` - Add `DIALOG_TOOL` configuration option parsing
- `lib/desktop-environment.sh` - Modify dialog tool detection to respect user preference
- `lib/configure-config.sh` - Add dialog tool selection to configuration wizard
- `lib/configure-ui.sh` - Add dialog for selecting dialog tool
- `sleep-warning.conf` - Add `DIALOG_TOOL` option with default value
- `configure.sh` - Add menu option for dialog tool selection
- `status.sh` - Update to show selected dialog tool (user-selected or automatic) and list installed tools

### Benefits

1. **User Control**: Users can override automatic selection if they have preferences
2. **Troubleshooting**: Users can test different dialog tools to diagnose issues
3. **Compatibility**: Users can work around tool-specific bugs or limitations
4. **Flexibility**: Maintains automatic selection as default while allowing manual override

### Considerations

- Should validate that selected tool is actually installed
- Should provide clear feedback if selected tool is not available
- Should log when user preference is used vs automatic selection
- Should maintain backward compatibility (default to `auto` if not specified)
- May want to show tool capabilities/limitations in configuration wizard (e.g., "yad supports better positioning")

### Testing Requirements

- Test with `DIALOG_TOOL=auto` (default behavior)
- Test with `DIALOG_TOOL=zenity` when zenity is installed
- Test with `DIALOG_TOOL=yad` when yad is installed
- Test with `DIALOG_TOOL=kdialog` when kdialog is installed
- Test with `DIALOG_TOOL=<tool>` when tool is not installed (should fall back to auto)
- Test configuration wizard selection and saving
- Test that selection persists across service restarts
- Test that invalid values are handled gracefully

## Implementation Plan

This section provides a detailed, step-by-step plan for implementing Enhancement 25.

### Phase 1: Configuration Infrastructure

#### Step 1.1: Add Default Value and Parsing Function to `lib/config.sh`

**Location**: After line 46 (after `DEFAULT_UNINSTALL_PROTECTION_MODE`)

**Action**: Add default constant:
```bash
# Default dialog tool selection - used if config file missing or invalid
# Options: "auto" (automatic priority), "zenity", "yad", "kdialog"
DEFAULT_DIALOG_TOOL="auto"
```

**Location**: After `get_uninstall_protection_mode()` function (after line 309)

**Action**: Add new function `get_dialog_tool_config()`:
```bash
# Get dialog tool selection from configuration file
# Returns: "auto", "zenity", "yad", "kdialog", or default "auto" if invalid/missing
# This is for Enhancement #25 (User-Selectable Dialog Tool)
get_dialog_tool_config() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_DIALOG_TOOL}"
        return 0
    fi
    
    # Read DIALOG_TOOL from config file
    local dialog_tool
    dialog_tool=$(grep -E "^[[:space:]]*DIALOG_TOOL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    # Validate and normalize dialog tool value
    # Handle empty string (after trimming whitespace) as invalid
    if [ -z "${dialog_tool}" ]; then
        echo "${DEFAULT_DIALOG_TOOL}"
        return 0
    fi
    
    case "${dialog_tool}" in
        auto|zenity|yad|kdialog)
            echo "${dialog_tool}"
            return 0
            ;;
        *)
            # Invalid, use default
            echo "${DEFAULT_DIALOG_TOOL}"
            return 0
            ;;
    esac
}
```

**Validation**: Function should return "auto" for missing/invalid values, and normalize case.

#### Step 1.2: Modify `lib/desktop-environment.sh` to Respect User Preference

**Location**: Modify `check_dialog_tool()` function (lines 32-48)

**Current Behavior**: Always uses automatic priority (YAD → Zenity → KDialog)

**New Behavior**: 
1. Check `DIALOG_TOOL` config option via `get_dialog_tool_config()`
2. If set to specific tool and installed, use that tool
3. If set to specific tool but not installed, log warning and fall back to automatic
4. If set to "auto" or not set, use automatic priority

**Implementation**:
- Add dependency on `config.sh` at top of file (after the header comments, before function definitions)
- Source `config.sh` conditionally if `get_dialog_tool_config()` is not available
- Modify function to accept optional user preference parameter
- Check user preference first, then fall back to automatic priority
- Log selection reason (user preference vs automatic)

**Dependency Sourcing** (add after line 15, before `is_kde()` function):
```bash
# Source config.sh if needed for get_dialog_tool_config() (Enhancement #25)
if ! type get_dialog_tool_config >/dev/null 2>&1; then
    # Determine script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "${SCRIPT_DIR}/config.sh" ]; then
        source "${SCRIPT_DIR}/config.sh"
    fi
fi
```

**Function Signature Change**:
```bash
# Check if a dialog tool is available (unified priority: YAD → Zenity → KDialog)
# If user_preference is provided and tool is installed, use that tool
# Otherwise uses automatic priority system
check_dialog_tool() {
    local env_type="$1"
    local user_preference="${2:-}"  # Optional: "auto", "zenity", "yad", "kdialog"
    
    # If user preference is set and tool is installed, use it
    if [ -n "${user_preference}" ] && [ "${user_preference}" != "auto" ]; then
        if command -v "${user_preference}" >/dev/null 2>&1; then
            echo "${user_preference}"
            return 0
        fi
        # Tool not installed - will fall back to automatic below
    fi
    
    # Unified priority for ALL environments: YAD -> Zenity -> KDialog
    if command -v yad >/dev/null 2>&1; then
        echo "yad"
        return 0
    elif command -v zenity >/dev/null 2>&1; then
        echo "zenity"
        return 0
    elif command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"
        return 0
    fi
    
    return 1
}
```

**Note**: This maintains backward compatibility - if no user preference is passed (parameter omitted or empty), behavior is unchanged and uses automatic priority system. All existing callers will continue to work without modification.

**Known Callers of `check_dialog_tool()`** (verify backward compatibility):
- `lib/popup-display.sh` (line 80) - Will be updated in Step 1.3
- `status.sh` (line 401) - Uses automatic priority (no change needed, backward compatible)
- `lib/configure-core.sh` (lines 53, 69) - Uses automatic priority (no change needed, backward compatible)
- `tests/test-popup-position.sh` (line 42) - Test script (no change needed, backward compatible)

All callers that pass only one parameter will continue to work as before.

#### Step 1.3: Update `lib/popup-display.sh` to Use User Preference

**Location**: In `show_warning()` function, around line 80 (where `check_dialog_tool()` is called)

**Prerequisites**: Verify that `config.sh` is sourced before this point. According to the file header (lines 13-27), `config.sh` is listed as a dependency and should be sourced by the calling script (`sleep-warning.sh` sources it at line 34). Verify this dependency chain is correct.

**Current Code**:
```bash
dialog_tool=$(check_dialog_tool "${env_type}")
```

**New Code**:
```bash
# Check user preference for dialog tool (Enhancement #25)
# Note: get_dialog_tool_config() is from config.sh, which should be sourced by the calling script
local user_dialog_preference
if type get_dialog_tool_config >/dev/null 2>&1; then
    user_dialog_preference=$(get_dialog_tool_config)
else
    # Fallback if config.sh not sourced (should not happen in normal operation)
    user_dialog_preference="auto"
fi
dialog_tool=$(check_dialog_tool "${env_type}" "${user_dialog_preference}")

# Log selection reason
if [ -n "${user_dialog_preference}" ] && [ "${user_dialog_preference}" != "auto" ]; then
    if [ "${dialog_tool}" = "${user_dialog_preference}" ]; then
        log_to_file "INFO" "Using user-selected dialog tool: ${dialog_tool}"
    else
        log_to_file "WARNING" "User-selected dialog tool '${user_dialog_preference}' not installed, falling back to automatic selection: ${dialog_tool}"
    fi
else
    log_to_file "INFO" "Using automatically selected dialog tool: ${dialog_tool}"
fi
```

**Validation**: 
- Ensure logging clearly indicates user preference vs automatic selection
- Verify that `config.sh` is sourced before `popup-display.sh` in the calling script
- Test that the function works even if `get_dialog_tool_config()` is not available (fallback to "auto")

### Phase 2: Configuration Wizard Integration

#### Step 2.1: Add Dialog Tool Selection Function to `lib/configure-input.sh`

**Location**: After existing configuration input functions (after `get_uninstall_protection_mode_config()`, around line 501)

**Action**: Add new function `get_dialog_tool_selection()` (note: different name from `get_dialog_tool_config()` in `config.sh` to avoid naming conflict):
```bash
# Get dialog tool selection from user
# Returns: "auto", "zenity", "yad", "kdialog", or "CANCELLED"
# Exit Codes:
#   0 - Success (returns tool name or "auto")
#   1 - User wants to retry/re-prompt (invalid selection, tool unavailable)
#   2 - User cancelled (confirmed cancellation)
# This is for Enhancement #25 (User-Selectable Dialog Tool)
get_dialog_tool_selection() {
    local use_gui="$1"
    
    # Get current setting from config file (using function from config.sh)
    # Note: configure-input.sh is sourced by configure.sh, which sources config.sh
    # If config.sh is not available, fall back to "auto"
    local current_setting
    if type get_dialog_tool_config >/dev/null 2>&1; then
        current_setting=$(get_dialog_tool_config 2>/dev/null || echo "auto")
    else
        # Fallback if config.sh not sourced (should not happen in normal operation)
        current_setting="auto"
    fi
    
    # Detect which tool would be automatically selected (for recommendation)
    # This shows the user what tool the automatic priority system would choose
    local recommended_tool=""
    local env_type
    if type detect_display_environment >/dev/null 2>&1; then
        env_type=$(detect_display_environment 2>/dev/null || echo "x11")
    else
        env_type="x11"
    fi
    
    if type check_dialog_tool >/dev/null 2>&1; then
        # Get the tool that would be automatically selected (no user preference)
        recommended_tool=$(check_dialog_tool "${env_type}" "" 2>/dev/null || echo "")
    else
        # Fallback: check tools manually in priority order
        if command -v yad >/dev/null 2>&1; then
            recommended_tool="yad"
        elif command -v zenity >/dev/null 2>&1; then
            recommended_tool="zenity"
        elif command -v kdialog >/dev/null 2>&1; then
            recommended_tool="kdialog"
        fi
    fi
    
    # Detect installed tools
    local installed_tools=()
    local tool_descriptions=()
    
    # Always include "auto" option
    installed_tools+=("auto")
    if [ -n "${recommended_tool}" ]; then
        tool_descriptions+=("Automatic (recommended) - Will use: ${recommended_tool} (priority: YAD → Zenity → KDialog)")
    else
        tool_descriptions+=("Automatic (recommended) - Uses priority: YAD → Zenity → KDialog")
    fi
    
    # Check for installed tools
    if command -v yad >/dev/null 2>&1; then
        installed_tools+=("yad")
        if [ "${recommended_tool}" = "yad" ]; then
            tool_descriptions+=("yad - Enhanced GTK dialog (best positioning, Wayland support) [Recommended by automatic priority]")
        else
            tool_descriptions+=("yad - Enhanced GTK dialog (best positioning, Wayland support)")
        fi
    fi
    if command -v zenity >/dev/null 2>&1; then
        installed_tools+=("zenity")
        if [ "${recommended_tool}" = "zenity" ]; then
            tool_descriptions+=("zenity - Standard GTK dialog (fallback) [Recommended by automatic priority]")
        else
            tool_descriptions+=("zenity - Standard GTK dialog (fallback)")
        fi
    fi
    if command -v kdialog >/dev/null 2>&1; then
        installed_tools+=("kdialog")
        if [ "${recommended_tool}" = "kdialog" ]; then
            tool_descriptions+=("kdialog - KDE dialog (KDE integration) [Recommended by automatic priority]")
        else
            tool_descriptions+=("kdialog - KDE dialog (KDE integration)")
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode - use list dialog
        local current_index=0
        local i=0
        for tool in "${installed_tools[@]}"; do
            if [ "${tool}" = "${current_setting}" ]; then
                current_index=${i}
                break
            fi
            i=$((i + 1))
        done
        
        # Build dialog message with recommendation
        local dialog_msg="Select which dialog tool to use for popup windows:\n\n"
        dialog_msg="${dialog_msg}Current setting: ${current_setting}\n"
        if [ -n "${recommended_tool}" ]; then
            dialog_msg="${dialog_msg}Recommended: ${recommended_tool} (selected by automatic priority system)\n"
        fi
        dialog_msg="${dialog_msg}\nNote: If you don't make a selection or cancel, the system will use 'Automatic' mode, which will select ${recommended_tool:-"the best available tool"} based on priority (YAD → Zenity → KDialog).\n\n"
        dialog_msg="${dialog_msg}Only installed tools are shown. If you select a tool that becomes unavailable, the system will automatically fall back to the priority system."
        
        local choice
        choice=$(show_list_dialog \
            "Dialog Tool Selection" \
            "${dialog_msg}" \
            650 \
            450 \
            "${tool_descriptions[@]}")
        local exit_code=$?
        
        if [ ${exit_code} -ne 0 ] || [ -z "${choice}" ]; then
            # User cancelled or didn't make a selection
            # Ask if they want to cancel configuration entirely, or use default "auto"
            if confirm_cancel "${use_gui}"; then
                # User confirmed cancellation - exit configuration
                echo "CANCELLED"
                return 2
            else
                # User wants to continue - use "auto" as default and return to menu
                # This makes it clear that automatic priority will be used if no selection is made
                echo "auto"
                return 0
            fi
        fi
        
        # Extract tool name from description (first word before " - ")
        local selected_tool
        selected_tool=$(echo "${choice}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
        
        # Validate selection
        case "${selected_tool}" in
            automatic|auto)
                echo "auto"
                return 0
                ;;
            yad|zenity|kdialog)
                # Verify tool is still installed
                if command -v "${selected_tool}" >/dev/null 2>&1; then
                    echo "${selected_tool}"
                    return 0
                else
                    # Tool was uninstalled - show warning and re-prompt
                    show_info_dialog \
                        "Tool Not Available" \
                        "The selected tool '${selected_tool}' is not installed.\n\nPlease select another option." \
                        500 \
                        200
                    return 1  # Re-prompt
                fi
                ;;
            *)
                echo "auto"  # Default fallback
                return 0
                ;;
        esac
    else
        # Text mode
        echo "" >&2
        echo "=== Dialog Tool Selection ===" >&2
        echo "" >&2
        echo "Current setting: ${current_setting}" >&2
        if [ -n "${recommended_tool}" ]; then
            echo "Recommended: ${recommended_tool} (selected by automatic priority system)" >&2
        fi
        echo "" >&2
        echo "Note: If you don't make a selection, the system will use 'Automatic' mode," >&2
        echo "      which will select ${recommended_tool:-"the best available tool"} based on priority (YAD → Zenity → KDialog)." >&2
        echo "" >&2
        echo "Select dialog tool:" >&2
        local i=1
        for tool in "${installed_tools[@]}"; do
            local desc="${tool_descriptions[$((i-1))]}"
            echo "  ${i}) ${desc}" >&2
            i=$((i + 1))
        done
        echo "" >&2
        
        while true; do
            read -p "Select option [1-${#installed_tools[@]}, Enter for Automatic]: " choice >&2
            # If user just presses Enter, default to "auto"
            if [ -z "${choice}" ]; then
                echo "auto"
                return 0
            fi
            if [ "${choice}" -ge 1 ] && [ "${choice}" -le ${#installed_tools[@]} ]; then
                local selected_tool="${installed_tools[$((choice-1))]}"
                
                # Validate tool is installed (if not "auto")
                if [ "${selected_tool}" != "auto" ] && ! command -v "${selected_tool}" >/dev/null 2>&1; then
                    echo "Error: Tool '${selected_tool}' is not installed. Please select another option." >&2
                    continue
                fi
                
                echo "${selected_tool}"
                return 0
            else
                echo "Invalid option. Please enter 1-${#installed_tools[@]}." >&2
            fi
        done
    fi
}
```

**Note**: Function is named `get_dialog_tool_selection()` to distinguish from `get_dialog_tool_config()` in `config.sh`:
- `get_dialog_tool_config()` (in `config.sh`) - Reads DIALOG_TOOL from config file
- `get_dialog_tool_selection()` (in `configure-input.sh`) - Gets user input interactively

**Return Code Meanings** (consistent with other functions in `configure-input.sh`):
- Return 0: Success - valid selection made (including "auto" if user cancelled dialog but wants to continue)
- Return 1: Retry - user wants to re-prompt (invalid selection, tool unavailable)
- Return 2: Cancelled - user confirmed cancellation (returns "CANCELLED", exits configuration)

**Default Behavior**:
- **If user cancels the dialog without confirming cancellation**: Returns "auto" (automatic priority system) with exit code 0
  - This makes it clear that the system will use automatic priority when no manual selection is made
  - The user can continue with configuration, and "auto" will be saved
- **If user confirms cancellation**: Returns "CANCELLED" with exit code 2, exiting configuration entirely
- **The recommended tool** (based on automatic priority: YAD → Zenity → KDialog) is displayed to help users make informed choices
- The dialog message clearly states: "If you don't make a selection or cancel, the system will use 'Automatic' mode"

#### Step 2.2: Update `lib/configure-config.sh` to Save DIALOG_TOOL

**Location**: In `write_config()` function, add DIALOG_TOOL parameter and write logic

**Action**: 
1. **Verify current parameter order**: Check `write_config()` function signature (around line 311). Current parameters are:
   - $1: check_interval
   - $2: popup_size
   - $3: popup_position
   - $4: min_display_time
   - $5: popup_immovable
   - $6: configure_block_enabled
   - $7: uninstall_protection_mode
   - $8+: config_lines array, lock_hours_lines array, override flags

2. **Add `dialog_tool` parameter**: Add as parameter 8 (after `uninstall_protection_mode`, before config_lines array)
   - Update function signature: `write_config(check_interval, popup_size, popup_position, min_display_time, popup_immovable, configure_block_enabled, uninstall_protection_mode, dialog_tool, ...)`
   - Update `shift` command: Change `shift 7` to `shift 8` (around line 319)
   - Add local variable: `local dialog_tool="$8"` after line 318

3. **Add DIALOG_TOOL to config file output** (after UNINSTALL_PROTECTION_MODE section, around line 446):

**Implementation** (in `write_config()` function):
```bash
# After UNINSTALL_PROTECTION_MODE section, add:
cat >> "${temp_file}" << EOF

# DIALOG_TOOL: Dialog tool selection for popup windows
# Default: auto (uses automatic priority: YAD → Zenity → KDialog)
# Options:
#   auto - Automatic selection (recommended, uses priority system)
#   zenity - Force use of zenity (if installed)
#   yad - Force use of yad (if installed)
#   kdialog - Force use of kdialog (if installed)
# If selected tool is not installed, system falls back to automatic selection
# This is Enhancement #25 (User-Selectable Dialog Tool)
DIALOG_TOOL=${dialog_tool}
EOF
```

**Location**: In `load_existing_config()` function, add DIALOG_TOOL loading

**Action**: 
1. Add global variable declaration at the start of `load_existing_config()` (after line 26, with other default initializations):
```bash
declare -g dialog_tool="auto"
```

2. Add parsing for DIALOG_TOOL similar to other config options (after UNINSTALL_PROTECTION_MODE loading, around line 109):
```bash
# Read dialog tool setting (Enhancement #25)
local existing_dialog_tool
existing_dialog_tool=$(grep -E "^[[:space:]]*DIALOG_TOOL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
if [ -n "${existing_dialog_tool}" ]; then
    # Validate value
    case "${existing_dialog_tool}" in
        auto|zenity|yad|kdialog)
            declare -g dialog_tool="${existing_dialog_tool}"
            ;;
        *)
            # Invalid value, keep default "auto"
            ;;
    esac
fi
# If empty or invalid, keep default "auto" (already set above)
```

**Note**: The `dialog_tool` variable is declared as global using `declare -g` at the start of the function, consistent with other config variables.

#### Step 2.3: Add Menu Option to `configure.sh`

**Location**: In `show_main_menu()` function in `lib/configure-display.sh`

**Prerequisites**: 
1. **Verify current menu structure**: Check `show_main_menu()` in `lib/configure-display.sh` to confirm:
   - Current menu options and their numbers
   - Where "Review and Save" is located (should be option 9)
   - Current function signature and parameter count

2. **Menu insertion point**: Dialog Tool Selection should be inserted as option 9, just before "Review and Save" (which becomes option 10). This maintains logical grouping: restrictions → security → tools → review.

**Action**: 
1. Add dialog tool status parameter to function signature (after `uninstall_protection_mode`, as parameter 12)
2. Add menu option "9. Dialog Tool Selection" (insert before "Review and Save")
3. Update menu option numbers: Review and Save becomes option 10, Dialog Tool becomes option 9
4. Add status display showing current selection
5. Update option count validation to accept 1-10 (both GUI and text modes)

**Implementation**:
- Update function signature: `show_main_menu(..., uninstall_protection_mode, dialog_tool_status)` (12 parameters total)
- Add to GUI menu (around line 147, before "Review and Save"): `"9" "Dialog Tool Selection ${dialog_tool_status}"`
- Add to text menu (around line 245, before "Review and Save"): `"9. Dialog Tool Selection ${dialog_tool_status}"`
- Update option count validation in text mode (around line 252): Change `[1-9]` to `[1-10]`

**Location**: In `configure.sh` main loop (around line 169)

**Action**: Add case for option 9:
```bash
9)
    # Dialog Tool Selection (Enhancement #25)
    local new_dialog_tool
    new_dialog_tool=$(get_dialog_tool_selection "${use_gui}")
    local selection_exit=$?
    
    if [ ${selection_exit} -eq 2 ]; then
        # User confirmed cancellation - exit configuration
        exit 0
    elif [ ${selection_exit} -eq 0 ]; then
        # Valid selection made (including "auto" if user cancelled without confirming)
        dialog_tool="${new_dialog_tool}"
    fi
    # If exit code is 1, function will have already re-prompted, so we continue the loop
    ;;
```

**Note**: The function now returns "auto" (with exit code 0) when the user cancels without confirming, ensuring the system always uses automatic priority as the default. This makes it clear that if no manual selection is made, the automatic priority system will be used.

**Location**: In `configure.sh` main loop, before calling `show_main_menu()` (around line 130-156, in the main configuration loop)

**Action**: Calculate status and pass to menu. This should be done in the main loop, after calculating `weekdays_status` and `weekends_status`, and before the `show_main_menu()` call:
```bash
# Calculate dialog tool status for menu display
# This is done in the main configuration loop, after loading config and calculating other statuses
local dialog_tool_status=""
local current_dialog_tool
# Use get_dialog_tool_config() if available, otherwise use the dialog_tool variable from config
if type get_dialog_tool_config >/dev/null 2>&1; then
    current_dialog_tool=$(get_dialog_tool_config 2>/dev/null || echo "auto")
else
    # Fallback to variable (should be set from load_existing_config())
    current_dialog_tool="${dialog_tool:-auto}"
fi

if [ "${current_dialog_tool}" = "auto" ]; then
    dialog_tool_status="(Automatic)"
else
    # Check if selected tool is installed
    if command -v "${current_dialog_tool}" >/dev/null 2>&1; then
        dialog_tool_status="(${current_dialog_tool})"
    else
        dialog_tool_status="(${current_dialog_tool} - not installed)"
    fi
fi

menu_choice=$(show_main_menu "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${weekdays_status}" "${weekends_status}" "${configure_block_enabled}" "${lock_hours_status}" "${uninstall_protection_mode}" "${dialog_tool_status}")
```

**Location**: Update `write_config()` call to include dialog_tool parameter (around line 353, in the "Review and Save" case)

**Action**: Add `dialog_tool` variable as parameter 8 (after `uninstall_protection_mode`, before `config_lines` array):
```bash
if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${configure_block_enabled}" "${uninstall_protection_mode}" "${dialog_tool}" "${config_lines[@]}" "${lock_hours_lines[@]}" "${popup_size_overridden}" "${configure_block_overridden}"; then
```

**Verification**: When implementing, verify that:
- `dialog_tool` is parameter 8 in the function signature
- The `shift` command shifts 8 parameters (not 7)
- The parameter order matches: check_interval, popup_size, popup_position, min_display_time, popup_immovable, configure_block_enabled, uninstall_protection_mode, **dialog_tool**, config_lines...

#### Step 2.4: Initialize dialog_tool Variable in `configure.sh`

**Location**: In `main()` function, after calling `load_existing_config()` (around line 126). The `load_existing_config()` function will set the global `dialog_tool` variable, but we should also ensure it's available as a local variable in the main function scope.

**Action**: The `dialog_tool` variable is already set by `load_existing_config()` as a global variable (using `declare -g`). However, to ensure it's available in the main function scope and has a default value if not set:
```bash
# Ensure dialog_tool is initialized (set by load_existing_config(), but provide fallback)
dialog_tool="${dialog_tool:-auto}"
```

**Note**: This is done after `load_existing_config()` is called, so the global variable should already be set. This line ensures a fallback if something went wrong.

### Phase 3: Status Display and Documentation

#### Step 3.1: Update `status.sh` to Show Dialog Tool Selection

**Location**: Lines 380-440 (currently has manual parsing implementation)

**Action**: Update `status.sh` to use `get_dialog_tool_config()` from `config.sh` instead of manual parsing for consistency:

1. **Verify config.sh is sourced**: Check that `status.sh` sources `config.sh` (it should, around line 34-37)

2. **Replace manual parsing** (around line 382) with function call:
```bash
# Get dialog tool configuration (Enhancement #25)
local configured_dialog_tool
if type get_dialog_tool_config >/dev/null 2>&1; then
    configured_dialog_tool=$(get_dialog_tool_config)
else
    # Fallback to manual parsing if function not available
    configured_dialog_tool=$(grep -E "^[[:space:]]*DIALOG_TOOL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -z "${configured_dialog_tool}" ]; then
        configured_dialog_tool="auto"
    fi
fi
```

3. **Keep existing display logic** (lines 384-440) - it correctly shows:
   - User-selected tool with "(user-selected)" label
   - Automatic selection with "(automatic selection)" label
   - Warning if selected tool is not installed
   - List of all installed tools

**Validation**: Test that status display correctly shows:
- "auto" when DIALOG_TOOL=auto or not set
- Specific tool name when user-selected
- Warning when selected tool is not installed
- List of installed tools

#### Step 3.2: Add DIALOG_TOOL to Default Config File

**Location**: `sleep-warning.conf` (after UNINSTALL_PROTECTION_MODE section, around line 91)

**Action**: Add configuration option with comments:
```bash
# DIALOG_TOOL: Dialog tool selection for popup windows
# Default: auto (uses automatic priority: YAD → Zenity → KDialog)
# Options:
#   auto - Automatic selection (recommended, uses priority system)
#   zenity - Force use of zenity (if installed)
#   yad - Force use of yad (if installed)
#   kdialog - Force use of kdialog (if installed)
# If selected tool is not installed, system falls back to automatic selection
# This is Enhancement #25 (User-Selectable Dialog Tool)
DIALOG_TOOL=auto
```

### Phase 4: Testing Checklist

#### Test 4.1: Configuration File Parsing
- [ ] Test `get_dialog_tool_config()` with missing config file (should return "auto")
- [ ] Test with `DIALOG_TOOL=auto` (should return "auto")
- [ ] Test with `DIALOG_TOOL=zenity` (should return "zenity")
- [ ] Test with `DIALOG_TOOL=yad` (should return "yad")
- [ ] Test with `DIALOG_TOOL=kdialog` (should return "kdialog")
- [ ] Test with invalid value `DIALOG_TOOL=invalid` (should return "auto")
- [ ] Test with case variations `DIALOG_TOOL=ZENITY` (should normalize to "zenity")

#### Test 4.2: Dialog Tool Selection Logic
- [ ] Test `check_dialog_tool()` with user_preference="auto" (should use automatic priority)
- [ ] Test with user_preference="yad" when yad is installed (should return "yad")
- [ ] Test with user_preference="yad" when yad is NOT installed (should fall back to automatic)
- [ ] Test with user_preference="zenity" when zenity is installed (should return "zenity")
- [ ] Test with user_preference="kdialog" when kdialog is installed (should return "kdialog")
- [ ] Test with no user_preference parameter (should use automatic priority, backward compatibility)
- [ ] Test with empty user_preference="" (should use automatic priority, backward compatibility)
- [ ] Test all existing callers still work without modification (status.sh, configure-core.sh, test scripts)

#### Test 4.3: Popup Display Integration
- [ ] Test popup display with `DIALOG_TOOL=auto` (should use automatic selection)
- [ ] Test popup display with `DIALOG_TOOL=yad` when yad is installed (should use yad)
- [ ] Test popup display with `DIALOG_TOOL=zenity` when zenity is installed (should use zenity)
- [ ] Test popup display with `DIALOG_TOOL=kdialog` when kdialog is installed (should use kdialog)
- [ ] Test popup display with `DIALOG_TOOL=yad` when yad is NOT installed (should fall back and log warning)
- [ ] Verify log messages indicate user preference vs automatic selection

#### Test 4.4: Configuration Wizard
- [ ] Test GUI mode dialog tool selection (should show list of installed tools)
- [ ] Test text mode dialog tool selection (should show numbered menu)
- [ ] Test that recommended tool is displayed (based on automatic priority)
- [ ] Test that recommendation shows which tool would be automatically selected
- [ ] Test selecting "Automatic" option (should save "auto")
- [ ] Test selecting specific tool when installed (should save tool name)
- [ ] Test that uninstalled tools are not shown in selection list
- [ ] Test that selection persists after saving and reloading config
- [ ] Test cancellation during selection (should return "auto" as default, not change config)
- [ ] Test pressing Enter in text mode without selection (should default to "auto")
- [ ] Verify that dialog message clearly states default behavior when no selection is made

#### Test 4.5: Status Display
- [ ] Test status.sh with `DIALOG_TOOL=auto` (should show "automatic selection")
- [ ] Test status.sh with `DIALOG_TOOL=yad` when yad is installed (should show "yad (user-selected)")
- [ ] Test status.sh with `DIALOG_TOOL=yad` when yad is NOT installed (should show warning)
- [ ] Test that installed tools list is displayed correctly

#### Test 4.6: Edge Cases
- [ ] Test with config file missing DIALOG_TOOL line (should default to "auto")
- [ ] Test with empty DIALOG_TOOL= line (should default to "auto")
- [ ] Test with whitespace: `DIALOG_TOOL = yad` (should parse correctly)
- [ ] Test with comment: `# DIALOG_TOOL=yad` (should be ignored, use default)
- [ ] Test with empty string after trimming: `DIALOG_TOOL=   ` (should default to "auto")
- [ ] Test service restart with user-selected tool (should persist)
- [ ] Test uninstalling selected tool after configuration (should fall back gracefully)
- [ ] Test that popup-display.sh works if config.sh is not sourced (should fall back to "auto")

### Phase 5: Documentation Updates

#### Step 5.1: Update User Documentation
- [ ] Add DIALOG_TOOL to `user-docs/CONFIGURATION.md`
- [ ] Explain when users might want to select a specific tool
- [ ] Document fallback behavior when selected tool is unavailable

#### Step 5.2: Update Technical Documentation
- [ ] Update `dev-docs/TECHNICAL_DETAILS.md` with dialog tool selection logic
- [ ] Document the priority system and user override mechanism

### Implementation Order

1. **Phase 1** (Configuration Infrastructure): Steps 1.1, 1.2, 1.3
   - Foundation for user preference support
   - No user-facing changes yet

2. **Phase 2** (Configuration Wizard): Steps 2.1, 2.2, 2.3, 2.4
   - User interface for selecting dialog tool
   - Config file persistence

3. **Phase 3** (Status Display): Steps 3.1, 3.2
   - Visual feedback of current selection
   - Default config file update

4. **Phase 4** (Testing): All test cases
   - Comprehensive validation

5. **Phase 5** (Documentation): All documentation updates
   - User and technical documentation

### Notes and Considerations

1. **Backward Compatibility**: 
   - Default value "auto" ensures existing configs continue working without changes
   - `check_dialog_tool()` maintains backward compatibility: if the second parameter is omitted or empty, it uses automatic priority system
   - All existing callers of `check_dialog_tool()` (status.sh, configure-core.sh, test scripts) will continue to work without modification
   - Existing config files without DIALOG_TOOL will default to "auto" behavior

2. **Function Naming**: 
   - `get_dialog_tool_config()` in `config.sh` - Reads DIALOG_TOOL from config file
   - `get_dialog_tool_selection()` in `configure-input.sh` - Gets user input interactively
   - Clear naming prevents confusion and conflicts

3. **Error Handling**: When user-selected tool is unavailable, system gracefully falls back to automatic selection with clear logging.

4. **Menu Integration**: 
   - Adding as option 9, moving "Review and Save" to option 10
   - This maintains logical grouping (restrictions → security → tools → review)
   - **Important**: Verify current menu structure before implementation to ensure correct numbering

5. **Status Display**: Update `status.sh` to use `get_dialog_tool_config()` function instead of manual parsing for consistency.

6. **Parameter Order Verification**: 
   - `dialog_tool` is parameter 8 in `write_config()` (after `uninstall_protection_mode`)
   - Verify parameter order when implementing to ensure consistency

7. **Dependency Sourcing**: 
   - `desktop-environment.sh` conditionally sources `config.sh` if needed
   - `popup-display.sh` relies on calling script to source `config.sh` (verified in sleep-warning.sh)
   - Both include fallback logic if functions are not available

8. **Return Code Consistency**: 
   - Functions in `configure-input.sh` use consistent return codes:
     - 0 = Success (returns "auto" if user cancels, ensuring default behavior)
     - 1 = Retry/re-prompt
     - 2 = Cancelled (user confirmed cancellation, exits configuration)
   - `get_dialog_tool_selection()` follows this pattern
   - **Default Behavior**: If user doesn't make a selection or cancels, the function returns "auto" (automatic priority), ensuring the system always uses the automatic priority system when no manual choice is made

9. **User Recommendation Display**:
   - The selection dialog shows which tool would be automatically selected (based on priority: YAD → Zenity → KDialog)
   - This helps users make informed choices by showing what the automatic system would choose
   - The recommended tool is marked in the list with "[Recommended by automatic priority]"
   - Both GUI and text modes display the recommendation

10. **Testing Priority**: Focus on:
   - Config parsing with various values (including empty strings)
   - Fallback behavior when tool unavailable
   - Configuration wizard integration
   - Service restart persistence
   - Backward compatibility with existing callers