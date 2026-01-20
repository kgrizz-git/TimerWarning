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
