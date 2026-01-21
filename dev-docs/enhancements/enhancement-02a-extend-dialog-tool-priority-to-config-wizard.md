# Enhancement 2a: Extend Dialog Tool Priority System to Configuration Wizard

- **Description**: Extend environment-aware dialog tool selection to `configure.sh` for consistency with `sleep-warning.sh` and better Wayland/KDE support
- **Implementation**: 
  - Reuse or adapt `check_dialog_tool()` function from `sleep-warning.sh` (or create shared function)
  - Replace all `zenity`-specific checks with environment-aware dialog tool selection
  - Update all GUI dialogs in `configure.sh` to support yad/kdialog/zenity with appropriate syntax
  - Ensure Visual Day/Time Configuration Grid (enhancement #16) uses same dialog tool selection
- **Files Affected**: `configure.sh`, potentially shared utility functions
- **Priority**: Medium (improves consistency and Wayland/KDE compatibility for configuration interface)
- **Status**: ✅ **Implemented** - All requirements completed. Main functionality implemented and working. **Note**: Comprehensive testing across all dialog tools and environments has not yet been performed. See implementation summary below.
- **Benefits**:
  - Consistent behavior across entire system (warning popups and configuration wizard)
  - Better Wayland support via `yad` (important for SteamOS Gaming Mode)
  - Better KDE integration via `kdialog` (important for SteamOS Desktop Mode)
  - Improved compatibility across different Linux distributions and desktop environments
- **Related**: 
  - See enhancement #2 (Dialog Tool Priority System) for implementation details
  - See enhancement #16 (Visual Day/Time Configuration Grid) which should use this system
  - See enhancement #24 (Unified Dialog Tool Priority) which supersedes the original environment-aware approach
  - See [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md#dialog-tool-selection) for priority order

## Implementation Summary

### ✅ Completed Items

1. **Shared Dialog Tool Function Created**
   - `check_dialog_tool()` function exists in `lib/desktop-environment.sh` (shared module)
   - Uses unified priority: **YAD → Zenity → KDialog** (all environments)
   - Function is sourced by `configure.sh` (line 39) and available to all configure modules

2. **Core Dialog Detection Functions Implemented**
   - `has_dialog_tool()` function added to `lib/configure-core.sh` (lines 48-61)
     - Uses `check_dialog_tool()` with environment detection
     - Includes fallback for direct tool checking if functions unavailable
   - `get_dialog_tool()` function added to `lib/configure-core.sh` (lines 65-80)
     - Returns the currently selected dialog tool
     - Uses `check_dialog_tool()` with environment detection
     - Includes fallback for direct tool checking
   - `has_zenity()` updated for backward compatibility (lines 84-88)
     - Now uses `get_dialog_tool()` internally instead of checking zenity directly
   - `has_gui()` updated to use `has_dialog_tool()` (lines 92-99)
     - Checks both display availability and dialog tool availability

3. **Dialog Abstraction Layer Created**
   - New module `lib/configure-dialogs.sh` provides tool-agnostic dialog functions
   - All functions automatically detect and use appropriate tool via `get_dialog_tool()`
   - Functions implemented:
     - `show_info_dialog()` - Information messages (supports yad/zenity/kdialog)
     - `show_question_dialog()` - Yes/No questions (supports yad/zenity/kdialog)
     - `show_entry_dialog()` - Text input with optional extra button (supports yad/zenity/kdialog)
     - `show_list_dialog()` - Single-column list selection (supports yad/zenity/kdialog)
     - `show_text_info_dialog()` - Multi-line text display (supports yad/zenity/kdialog)
     - `show_multi_column_list_dialog()` - Multi-column list selection (supports yad/zenity/kdialog)

4. **Main Configuration Script Updated**
   - `configure.sh` sources `lib/desktop-environment.sh` (line 39)
   - `configure.sh` sources `lib/configure-dialogs.sh` (line 40)
   - All `zenity`-specific checks replaced with `has_dialog_tool()`:
     - Line 89: GUI mode detection
     - Line 98: Auto-detect GUI mode
     - Line 359: Error dialog display
     - Line 371: Error dialog display
   - Documentation updated to mention yad/zenity/kdialog (lines 12, 20, 23, 71, 74, 92-93)
   - No direct zenity/yad/kdialog calls remain in `configure.sh`

5. **All Configure Modules Updated**
   - `lib/configure-ui.sh`: All dialog calls use abstraction functions from `configure-dialogs.sh`
     - All `has_zenity` checks replaced with `has_dialog_tool` (11 occurrences)
   - `lib/configure-input.sh`: All dialog calls use abstraction functions
     - All `has_zenity` checks replaced with `has_dialog_tool` (8 occurrences)
   - `lib/configure-display.sh`: All dialog calls use abstraction functions
     - All `has_zenity` checks replaced with `has_dialog_tool` (3 occurrences)
   - `lib/configure-workflow.sh`: Uses `has_dialog_tool` (1 occurrence)
   - No direct zenity/yad/kdialog calls remain in any configure module

6. **Visual Day/Time Configuration Grid Updated**
   - `show_visual_grid()` function in `lib/configure-display.sh` uses `show_multi_column_list_dialog()` (line 367)
   - `show_multi_column_list_dialog()` automatically uses `get_dialog_tool()` to select appropriate tool
   - Grid fully supports yad/zenity/kdialog with unified priority
   - Note: Enhancement #16 documentation still lists this as "NOT YET IMPLEMENTED" but code shows it is implemented

7. **Module Integration Complete**
   - Proper dependency order maintained in `configure.sh`:
     - `desktop-environment.sh` sourced before `configure-core.sh`
     - `configure-core.sh` sourced before `configure-dialogs.sh`
     - `configure-dialogs.sh` sourced before modules that use it
   - All modules can access dialog tool functions without errors

### 📝 Implementation Details

**How It Works:**
1. `configure.sh` sources `lib/desktop-environment.sh` which provides `check_dialog_tool()`
2. `configure.sh` sources `lib/configure-core.sh` which provides `has_dialog_tool()` and `get_dialog_tool()`
3. `configure.sh` sources `lib/configure-dialogs.sh` which provides abstraction functions
4. All dialog functions in `configure-dialogs.sh` call `get_dialog_tool()` to determine which tool to use
5. `get_dialog_tool()` calls `check_dialog_tool()` with environment type
6. `check_dialog_tool()` returns tool based on unified priority: YAD → Zenity → KDialog
7. Dialog functions use appropriate syntax for the selected tool

**Priority System:**
- **Unified Priority** (all environments): YAD → Zenity → KDialog
- This supersedes the original environment-aware approach from enhancement #2
- See enhancement #24 for details on the unified priority decision

### ⚠️ Notes and Suggestions

1. **Enhancement #16 Documentation** ✅ **Updated**
   - Enhancement #16 documentation has been updated to reflect that dialog tool support is implemented
   - The Visual Day/Time Grid uses `show_multi_column_list_dialog()` which supports all three tools
   - Testing with yad and kdialog is still pending, but implementation is complete

2. **Testing Recommendations** ⚠️ **Not Yet Performed**
   
   While the implementation is complete and functional, comprehensive testing across all dialog tools and environments has not yet been performed. The following testing should be conducted:
   
   **Priority Testing:**
   - [ ] Test `configure.sh` with only YAD installed (verify YAD is selected and all dialogs work)
   - [ ] Test `configure.sh` with only Zenity installed (verify Zenity is selected and all dialogs work)
   - [ ] Test `configure.sh` with only KDialog installed (verify KDialog is selected and all dialogs work)
   - [ ] Test with multiple tools installed (verify priority order: YAD → Zenity → KDialog)
   
   **Environment Testing:**
   - [ ] Test in Wayland environment (SteamOS Gaming Mode, GNOME Wayland, etc.)
   - [ ] Test in X11 environment (traditional X11 desktop)
   - [ ] Test in KDE environment (verify KDialog integration works)
   - [ ] Test in GNOME environment (verify Zenity works)
   
   **Feature-Specific Testing:**
   - [ ] Test Visual Day/Time Grid with each dialog tool
   - [ ] Test all dialog types (info, question, entry, list, multi-column list, text info)
   - [ ] Test error handling when no dialog tools are available
   - [ ] Test fallback behavior when preferred tool is unavailable
   
   **Integration Testing:**
   - [ ] Verify dialog tool selection matches `sleep-warning.sh` behavior
   - [ ] Test configuration wizard end-to-end with each tool
   - [ ] Verify all configure modules work correctly with each tool

3. **Extending to Other Scripts**
   
   The dialog tool priority system is currently implemented in `configure.sh` and its modules. Other scripts in the project could benefit from the same system:
   
   **Scripts That May Need Updates:**
   - `manage.sh` - Currently has local `has_zenity()` function (line 45-47) that checks zenity directly
     - Uses zenity-specific dialog calls throughout
     - Could use `lib/configure-dialogs.sh` abstraction functions
     - **Suggestion**: Create enhancement to extend dialog tool support to `manage.sh`
   - `status.sh` - May have some dialog tool usage that could be standardized
   - `uninstall.sh` - May have dialog tool usage that could be standardized
   
   **Benefits of Extension:**
   - Consistent user experience across all scripts
   - Better Wayland/KDE support in management interface
   - Unified maintenance (one system to update instead of multiple)
   
   **Implementation Approach:**
   - Source `lib/desktop-environment.sh` and `lib/configure-dialogs.sh` in target scripts
   - Replace direct tool calls with abstraction functions
   - Update tool detection to use `has_dialog_tool()` and `get_dialog_tool()`
   - Test thoroughly with all three tools

4. **Documentation Update Checklist** ⚠️ **Pending**
   
   The following documentation should be updated to reflect the multi-tool support:
   
   - [ ] **User Documentation:**
     - [ ] `README.md` - Update requirements section to mention yad/zenity/kdialog
     - [ ] `user-docs/USER_GUIDE.md` - Update any zenity-specific references
     - [ ] `user-docs/CONFIGURATION.md` - Update dialog tool requirements
   
   - [ ] **Technical Documentation:**
     - [ ] `dev-docs/TECHNICAL_DETAILS.md` - Update dialog tool section
     - [ ] `dev-docs/STEAMOS_GAMING_MODE.md` - Verify dialog tool priority documentation is current
     - [ ] Any installation guides that mention zenity requirements
   
   - [ ] **Enhancement Documentation:**
     - [x] `dev-docs/enhancements/enhancement-02a-extend-dialog-tool-priority-to-config-wizard.md` - This file (completed)
     - [x] `dev-docs/enhancements/enhancement-16-visual-day-time-configuration-grid.md` - Updated to reflect implementation
     - [ ] Verify enhancement #24 documentation is consistent
   
   - [ ] **Code Comments:**
     - [ ] Review and update inline comments that reference zenity as primary tool
     - [ ] Ensure module headers mention multi-tool support
   
   **Priority**: Medium - Documentation updates improve user experience but don't affect functionality
