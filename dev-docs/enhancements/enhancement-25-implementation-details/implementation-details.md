# Enhancement 25: Implementation Details

This document contains detailed implementation information for Enhancement 25: User-Selectable Dialog Tool.

**Related Document**: See [../enhancement-25-user-selectable-dialog-tool.md](../enhancement-25-user-selectable-dialog-tool.md) for the full enhancement description and overview.

---

## Implementation Plan

### Phase 1: Configuration Infrastructure

#### Step 1.1: Add Default Value and Parsing Function to `lib/config.sh`

**Location**: After line 46 (after `DEFAULT_UNINSTALL_PROTECTION_MODE`)

Add default constant:
```bash
# Default dialog tool selection - used if config file missing or invalid
# Options: "auto" (automatic priority), "zenity", "yad", "kdialog"
DEFAULT_DIALOG_TOOL="auto"
```

**Location**: After `get_uninstall_protection_mode()` function (after line 309)

Add function `get_dialog_tool_config()`:
```bash
# Get dialog tool selection from configuration file
# Returns: "auto", "zenity", "yad", "kdialog", or default "auto" if invalid/missing
# This is for Enhancement #25 (User-Selectable Dialog Tool)
get_dialog_tool_config() {
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_DIALOG_TOOL}"
        return 0
    fi
    
    local dialog_tool
    dialog_tool=$(grep -E "^[[:space:]]*DIALOG_TOOL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
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
            echo "${DEFAULT_DIALOG_TOOL}"
            return 0
            ;;
    esac
}
```

**Validation**: Returns "auto" for missing/invalid values, normalizes case.

#### Step 1.2: Modify `lib/desktop-environment.sh` to Respect User Preference

**Location**: Modify `check_dialog_tool()` function (lines 32-48)

**New Behavior**: 
- Accept optional `user_preference` parameter
- If set to specific tool and installed, use that tool
- Otherwise fall back to automatic priority (YAD → Zenity → KDialog)

**Dependency Sourcing** (add after line 15, before `is_kde()`):
```bash
# Source config.sh if needed for get_dialog_tool_config() (Enhancement #25)
if ! type get_dialog_tool_config >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "${SCRIPT_DIR}/config.sh" ]; then
        source "${SCRIPT_DIR}/config.sh"
    fi
fi
```

**Function Signature**:
```bash
check_dialog_tool() {
    local env_type="$1"
    local user_preference="${2:-}"  # Optional: "auto", "zenity", "yad", "kdialog"
    
    # If user preference is set and tool is installed, use it
    if [ -n "${user_preference}" ] && [ "${user_preference}" != "auto" ]; then
        if command -v "${user_preference}" >/dev/null 2>&1; then
            echo "${user_preference}"
            return 0
        fi
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

**Backward Compatibility**: All existing callers (status.sh, configure-core.sh, test scripts) continue to work without modification.

#### Step 1.3: Update `lib/popup-display.sh` to Use User Preference

**Location**: In `show_warning()` function, around line 80

**Prerequisites**: Verify `config.sh` is sourced by calling script (`sleep-warning.sh` sources it at line 34).

**Replace**:
```bash
dialog_tool=$(check_dialog_tool "${env_type}")
```

**With**:
```bash
# Check user preference for dialog tool (Enhancement #25)
local user_dialog_preference
if type get_dialog_tool_config >/dev/null 2>&1; then
    user_dialog_preference=$(get_dialog_tool_config)
else
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

### Phase 2: Configuration Wizard Integration

#### Step 2.1: Add Dialog Tool Selection Function to `lib/configure-input.sh`

**Location**: After `get_uninstall_protection_mode_config()`, around line 501

Add function `get_dialog_tool_selection()` (different name from `get_dialog_tool_config()` to avoid conflict):

**Key Features**:
- Gets current setting from config file
- Detects recommended tool (based on automatic priority)
- Shows list of installed tools with recommendations
- Supports both GUI and text modes
- Return codes: 0=Success, 1=Retry, 2=Cancelled

**Implementation Summary**:
- Always includes "auto" option with recommendation display
- Shows which tool would be automatically selected
- Validates tool is installed before accepting selection
- Returns "auto" if user cancels without confirming (exit code 0)
- Returns "CANCELLED" if user confirms cancellation (exit code 2)

**Function Signature**:
```bash
get_dialog_tool_selection() {
    local use_gui="$1"
    # ... implementation ...
    # Returns: "auto", "zenity", "yad", "kdialog", or "CANCELLED"
    # Exit codes: 0=Success, 1=Retry, 2=Cancelled
}
```

**Note**: Full implementation includes GUI/text mode handling, tool detection, recommendation display, and validation. See original document for complete code.

#### Step 2.2: Update `lib/configure-config.sh` to Save DIALOG_TOOL

**Location**: In `write_config()` function

**Action**: 
1. Add `dialog_tool` as parameter 8 (after `uninstall_protection_mode`, before config_lines array)
2. Update function signature: `write_config(..., uninstall_protection_mode, dialog_tool, ...)`
3. Change `shift 7` to `shift 8` (around line 319)
4. Add local variable: `local dialog_tool="$8"` after line 318

**Add DIALOG_TOOL to config file output** (after UNINSTALL_PROTECTION_MODE section, around line 446):
```bash
cat >> "${temp_file}" << EOF

# DIALOG_TOOL: Dialog tool selection for popup windows
# Default: auto (uses automatic priority: YAD → Zenity → KDialog)
# Options: auto, zenity, yad, kdialog
# If selected tool is not installed, system falls back to automatic selection
# This is Enhancement #25 (User-Selectable Dialog Tool)
DIALOG_TOOL=${dialog_tool}
EOF
```

**Location**: In `load_existing_config()` function

**Action**: 
1. Add global variable: `declare -g dialog_tool="auto"` (after line 26)
2. Add parsing for DIALOG_TOOL (after UNINSTALL_PROTECTION_MODE loading, around line 109):
```bash
# Read dialog tool setting (Enhancement #25)
local existing_dialog_tool
existing_dialog_tool=$(grep -E "^[[:space:]]*DIALOG_TOOL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
if [ -n "${existing_dialog_tool}" ]; then
    case "${existing_dialog_tool}" in
        auto|zenity|yad|kdialog)
            declare -g dialog_tool="${existing_dialog_tool}"
            ;;
    esac
fi
```

#### Step 2.3: Add Menu Option to `configure.sh`

**Location**: In `show_main_menu()` function in `lib/configure-display.sh`

**Action**: 
1. Add `dialog_tool_status` parameter (as parameter 12, after `uninstall_protection_mode`)
2. Insert "9. Dialog Tool Selection" before "Review and Save" (which becomes option 10)
3. Update option count validation: Change `[1-9]` to `[1-10]` in text mode

**Location**: In `configure.sh` main loop (around line 169)

**Action**: Add case for option 9:
```bash
9)
    # Dialog Tool Selection (Enhancement #25)
    local new_dialog_tool
    new_dialog_tool=$(get_dialog_tool_selection "${use_gui}")
    local selection_exit=$?
    
    if [ ${selection_exit} -eq 2 ]; then
        exit 0  # User confirmed cancellation
    elif [ ${selection_exit} -eq 0 ]; then
        dialog_tool="${new_dialog_tool}"
    fi
    ;;
```

**Location**: Before `show_main_menu()` call (around line 130-156)

**Action**: Calculate and pass dialog tool status:
```bash
# Calculate dialog tool status for menu display
local dialog_tool_status=""
local current_dialog_tool
if type get_dialog_tool_config >/dev/null 2>&1; then
    current_dialog_tool=$(get_dialog_tool_config 2>/dev/null || echo "auto")
else
    current_dialog_tool="${dialog_tool:-auto}"
fi

if [ "${current_dialog_tool}" = "auto" ]; then
    dialog_tool_status="(Automatic)"
else
    if command -v "${current_dialog_tool}" >/dev/null 2>&1; then
        dialog_tool_status="(${current_dialog_tool})"
    else
        dialog_tool_status="(${current_dialog_tool} - not installed)"
    fi
fi

menu_choice=$(show_main_menu ... "${dialog_tool_status}")
```

**Location**: Update `write_config()` call (around line 353)

**Action**: Add `dialog_tool` as parameter 8:
```bash
if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${configure_block_enabled}" "${uninstall_protection_mode}" "${dialog_tool}" "${config_lines[@]}" ...; then
```

#### Step 2.4: Initialize dialog_tool Variable in `configure.sh`

**Location**: In `main()` function, after `load_existing_config()` (around line 126)

**Action**: Ensure variable is initialized:
```bash
# Ensure dialog_tool is initialized (set by load_existing_config(), but provide fallback)
dialog_tool="${dialog_tool:-auto}"
```

### Phase 3: Status Display and Documentation

#### Step 3.1: Update `status.sh` to Show Dialog Tool Selection

**Location**: Lines 380-440

**Action**: Replace manual parsing with function call:
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

Keep existing display logic (shows user-selected vs automatic, warnings, installed tools list).

#### Step 3.2: Add DIALOG_TOOL to Default Config File

**Location**: `sleep-warning.conf` (after UNINSTALL_PROTECTION_MODE section, around line 91)

**Action**: Add configuration option:
```bash
# DIALOG_TOOL: Dialog tool selection for popup windows
# Default: auto (uses automatic priority: YAD → Zenity → KDialog)
# Options: auto, zenity, yad, kdialog
# If selected tool is not installed, system falls back to automatic selection
# This is Enhancement #25 (User-Selectable Dialog Tool)
DIALOG_TOOL=auto
```

### Phase 4: Testing Checklist

#### Test 4.1: Configuration File Parsing
- [ ] Missing config file → returns "auto"
- [ ] Valid values: auto, zenity, yad, kdialog → returns correct value
- [ ] Invalid value → returns "auto"
- [ ] Case variations (ZENITY, Yad) → normalizes to lowercase
- [ ] Empty/whitespace values → returns "auto"

#### Test 4.2: Dialog Tool Selection Logic
- [ ] `check_dialog_tool()` with user_preference="auto" → uses automatic priority
- [ ] user_preference="yad" when installed → returns "yad"
- [ ] user_preference="yad" when NOT installed → falls back to automatic
- [ ] No user_preference parameter → uses automatic (backward compatibility)
- [ ] All existing callers work without modification

#### Test 4.3: Popup Display Integration
- [ ] DIALOG_TOOL=auto → uses automatic selection
- [ ] DIALOG_TOOL=yad/zenity/kdialog when installed → uses selected tool
- [ ] DIALOG_TOOL=yad when NOT installed → falls back and logs warning
- [ ] Log messages indicate user preference vs automatic selection

#### Test 4.4: Configuration Wizard
- [ ] GUI/text mode selection works
- [ ] Recommended tool displayed (based on automatic priority)
- [ ] Selecting "Automatic" → saves "auto"
- [ ] Selecting specific tool when installed → saves tool name
- [ ] Uninstalled tools not shown in list
- [ ] Selection persists after save/reload
- [ ] Cancellation → returns "auto" as default
- [ ] Pressing Enter in text mode → defaults to "auto"

#### Test 4.5: Status Display
- [ ] DIALOG_TOOL=auto → shows "automatic selection"
- [ ] DIALOG_TOOL=yad when installed → shows "yad (user-selected)"
- [ ] DIALOG_TOOL=yad when NOT installed → shows warning
- [ ] Installed tools list displayed correctly

#### Test 4.6: Edge Cases
- [ ] Config file missing DIALOG_TOOL line → defaults to "auto"
- [ ] Empty DIALOG_TOOL= line → defaults to "auto"
- [ ] Whitespace handling: `DIALOG_TOOL = yad` → parses correctly
- [ ] Comment line: `# DIALOG_TOOL=yad` → ignored, uses default
- [ ] Service restart → selection persists
- [ ] Uninstalling selected tool → falls back gracefully
- [ ] popup-display.sh works if config.sh not sourced → falls back to "auto"

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
2. **Phase 2** (Configuration Wizard): Steps 2.1, 2.2, 2.3, 2.4
3. **Phase 3** (Status Display): Steps 3.1, 3.2
4. **Phase 4** (Testing): All test cases
5. **Phase 5** (Documentation): All documentation updates

### Notes and Considerations

1. **Backward Compatibility**: 
   - Default "auto" ensures existing configs work without changes
   - `check_dialog_tool()` maintains backward compatibility (optional second parameter)
   - All existing callers continue to work without modification

2. **Function Naming**: 
   - `get_dialog_tool_config()` (config.sh) - Reads from config file
   - `get_dialog_tool_selection()` (configure-input.sh) - Gets user input

3. **Error Handling**: When user-selected tool is unavailable, system gracefully falls back to automatic selection with clear logging.

4. **Menu Integration**: 
   - Adding as option 9, moving "Review and Save" to option 10
   - Maintains logical grouping (restrictions → security → tools → review)
   - **Important**: Verify current menu structure before implementation

5. **Parameter Order**: `dialog_tool` is parameter 8 in `write_config()` (after `uninstall_protection_mode`). Verify parameter order when implementing.

6. **Dependency Sourcing**: 
   - `desktop-environment.sh` conditionally sources `config.sh` if needed
   - `popup-display.sh` relies on calling script to source `config.sh`
   - Both include fallback logic if functions are not available

7. **Return Code Consistency**: 
   - 0 = Success (returns "auto" if user cancels)
   - 1 = Retry/re-prompt
   - 2 = Cancelled (exits configuration)

8. **User Recommendation Display**: Selection dialog shows which tool would be automatically selected, helping users make informed choices.

9. **Testing Priority**: Focus on config parsing, fallback behavior, wizard integration, service persistence, and backward compatibility.
