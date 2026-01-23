# Enhancement 25: User-Selectable Dialog Tool

- **Description**: Allow users to manually choose which dialog tool (zenity, yad, or kdialog) to use from a list of installed tools, overriding the automatic priority system. This gives users control over dialog tool selection when they have preferences or encounter issues with the automatic selection.
- **Priority**: Medium (improves user control and troubleshooting flexibility)
- **Status**: Implemented and tested (automated tests passing, some manual tests pending)
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

## Implementation Checklist

### Phase 1: Configuration Infrastructure

#### Step 1.1: Add Default Value and Parsing Function to `lib/config.sh`
- [x] Add `DEFAULT_DIALOG_TOOL="auto"` constant (after line 46, after `DEFAULT_UNINSTALL_PROTECTION_MODE`)
- [x] Add `get_dialog_tool_config()` function (after `get_uninstall_protection_mode()`, after line 309)
- [x] Verify function returns "auto" for missing/invalid values
- [x] Verify function normalizes case (uppercase → lowercase)

#### Step 1.2: Modify `lib/desktop-environment.sh` to Respect User Preference
- [x] Add conditional sourcing of `config.sh` (after line 15, before `is_kde()`)
- [x] Modify `check_dialog_tool()` to accept optional `user_preference` parameter
- [x] Add logic to check user preference first, then fall back to automatic priority
- [x] Verify backward compatibility (existing callers work without modification)
- [ ] Test with all existing callers: `status.sh`, `configure-core.sh`, test scripts (code maintains backward compatibility, but explicit testing pending)

#### Step 1.3: Update `lib/popup-display.sh` to Use User Preference
- [x] Verify `config.sh` is sourced by calling script (`sleep-warning.sh`)
- [x] Replace `dialog_tool=$(check_dialog_tool "${env_type}")` with user preference logic
- [x] Add logging for user preference vs automatic selection
- [x] Add fallback logic if `get_dialog_tool_config()` is not available
- [ ] Test that function works even if `config.sh` is not sourced (fallback logic implemented, but explicit testing pending)

### Phase 2: Configuration Wizard Integration

#### Step 2.1: Add Dialog Tool Selection Function to `lib/configure-input.sh`
- [x] Add `get_dialog_tool_selection()` function (after `get_uninstall_protection_mode_config()`, around line 501)
- [x] Implement GUI mode selection (list dialog with installed tools)
- [x] Implement text mode selection (numbered menu)
- [x] Add recommendation display (shows which tool would be automatically selected)
- [x] Add validation (verify tool is installed before accepting)
- [x] Implement return codes: 0=Success, 1=Retry, 2=Cancelled
- [x] Handle cancellation (returns "auto" if user cancels without confirming)

#### Step 2.2: Update `lib/configure-config.sh` to Save DIALOG_TOOL
- [x] Add `dialog_tool` as parameter 10 to `write_config()` function signature (Note: Parameter is 10, not 8, because pause_enabled and pause_duration are parameters 8 and 9)
- [x] Update `shift 9` to `shift 10` (around line 380)
- [x] Add local variable: `local dialog_tool="${10:-auto}"` (after line 379)
- [x] Add DIALOG_TOOL to config file output (after PAUSE_DURATION section, around line 561)
- [x] Add `declare -g dialog_tool="auto"` in `load_existing_config()` (after line 34)
- [x] Add DIALOG_TOOL parsing in `load_existing_config()` (after PAUSE_DURATION loading, around line 132)
- [x] Verify parameter order matches: check_interval, popup_size, popup_position, min_display_time, popup_immovable, configure_block_enabled, uninstall_protection_mode, pause_enabled, pause_duration, **dialog_tool**, config_lines...

#### Step 2.3: Add Menu Option to `configure.sh`
- [x] Verify current menu structure in `show_main_menu()` (check option numbers)
- [x] Add `dialog_tool_status` parameter to `show_main_menu()` (as parameter 15, after `pause_duration`)
- [x] Insert "11. Dialog Tool Selection" before "Review and Save" (which becomes option 12) (Note: Menu structure had evolved - option 11 was available, Review and Save was already option 11, now option 12)
- [x] Update option count validation: Change `[1-11]` to `[1-12]` in text mode
- [x] Add case for option 11 in `configure.sh` main loop (around line 373)
- [x] Calculate dialog tool status before `show_main_menu()` call (around line 173-195)
- [x] Update `write_config()` call to include `dialog_tool` parameter (around line 406)

#### Step 2.4: Initialize dialog_tool Variable in `configure.sh`
- [x] Add initialization: `dialog_tool="${dialog_tool:-auto}"` after `load_existing_config()` (around line 130)

### Phase 3: Status Display and Documentation

#### Step 3.1: Update `status.sh` to Show Dialog Tool Selection
- [x] Verify `config.sh` is sourced by `status.sh` (around line 34-37)
- [x] Replace manual parsing with `get_dialog_tool_config()` function call (around line 457)
- [x] Keep existing display logic (user-selected vs automatic, warnings, installed tools list)
- [ ] Test status display with various DIALOG_TOOL values (code implemented, but explicit testing pending)

#### Step 3.2: Add DIALOG_TOOL to Default Config File
- [x] Add DIALOG_TOOL option to `sleep-warning.conf` (after UNINSTALL_PROTECTION_MODE section, around line 91)
- [x] Include comments explaining the option and values

### Phase 4: Testing

#### Test 4.1: Configuration File Parsing
- [x] Test `get_dialog_tool_config()` with missing config file → returns "auto"
- [x] Test with valid values: auto, zenity, yad, kdialog → returns correct value
- [x] Test with invalid value → returns "auto"
- [x] Test case variations (ZENITY, Yad) → normalizes to lowercase
- [x] Test empty/whitespace values → returns "auto"

#### Test 4.2: Dialog Tool Selection Logic
- [x] Test `check_dialog_tool()` with user_preference="auto" → uses automatic priority
- [x] Test user_preference="yad" when installed → returns "yad"
- [x] Test user_preference="yad" when NOT installed → falls back to automatic
- [x] Test user_preference="zenity" when installed → returns "zenity"
- [x] Test user_preference="kdialog" when installed → returns "kdialog"
- [x] Test with no user_preference parameter → uses automatic (backward compatibility)
- [x] Test with empty user_preference="" → uses automatic (backward compatibility)
- [x] Verify all existing callers work without modification (code maintains backward compatibility)

#### Test 4.3: Popup Display Integration
- [x] Test popup display with `DIALOG_TOOL=auto` → uses automatic selection
- [x] Test popup display with `DIALOG_TOOL=yad` when installed → uses yad
- [x] Test popup display with `DIALOG_TOOL=zenity` when installed → uses zenity
- [x] Test popup display with `DIALOG_TOOL=kdialog` when installed → uses kdialog
- [ ] Test popup display with `DIALOG_TOOL=yad` when NOT installed → falls back and logs warning (requires manual testing with tool uninstalled)
- [ ] Verify log messages indicate user preference vs automatic selection (requires manual testing)

#### Test 4.4: Configuration Wizard
- [ ] Test GUI mode dialog tool selection → shows list of installed tools
- [ ] Test text mode dialog tool selection → shows numbered menu
- [ ] Test recommended tool is displayed (based on automatic priority)
- [ ] Test selecting "Automatic" option → saves "auto"
- [ ] Test selecting specific tool when installed → saves tool name
- [ ] Test uninstalled tools not shown in selection list
- [ ] Test selection persists after save/reload
- [ ] Test cancellation → returns "auto" as default
- [ ] Test pressing Enter in text mode without selection → defaults to "auto"
- [ ] Verify dialog message clearly states default behavior

#### Test 4.5: Status Display
- [ ] Test `status.sh` with `DIALOG_TOOL=auto` → shows "automatic selection"
- [ ] Test `status.sh` with `DIALOG_TOOL=yad` when installed → shows "yad (user-selected)"
- [ ] Test `status.sh` with `DIALOG_TOOL=yad` when NOT installed → shows warning
- [ ] Test installed tools list displayed correctly

#### Test 4.6: Edge Cases
- [x] Test config file missing DIALOG_TOOL line → defaults to "auto"
- [x] Test empty `DIALOG_TOOL=` line → defaults to "auto"
- [x] Test whitespace handling: `DIALOG_TOOL = yad` → parses correctly
- [x] Test comment line: `# DIALOG_TOOL=yad` → ignored, uses default
- [x] Test empty string after trimming: `DIALOG_TOOL=   ` → defaults to "auto"
- [ ] Test service restart → selection persists (requires manual testing with systemd service)
- [ ] Test uninstalling selected tool → falls back gracefully (requires manual testing)
- [x] Test `popup-display.sh` works if `config.sh` not sourced → falls back to "auto" (fallback logic implemented and tested)

### Phase 5: Documentation Updates

#### Step 5.1: Update User Documentation
- [x] Add DIALOG_TOOL to `user-docs/CONFIGURATION.md`
- [x] Explain when users might want to select a specific tool
- [x] Document fallback behavior when selected tool is unavailable

#### Step 5.2: Update Technical Documentation
- [x] Update `dev-docs/TECHNICAL_DETAILS.md` with dialog tool selection logic
- [x] Document the priority system and user override mechanism

## Implementation Plan

**For detailed implementation plan, see**: [enhancement-25-implementation-details/implementation-details.md](enhancement-25-implementation-details/implementation-details.md)

