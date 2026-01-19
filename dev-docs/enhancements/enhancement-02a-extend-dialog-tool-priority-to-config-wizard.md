# Enhancement 2a: Extend Dialog Tool Priority System to Configuration Wizard

- **Description**: Extend environment-aware dialog tool selection to `configure.sh` for consistency with `sleep-warning.sh` and better Wayland/KDE support
- **Implementation**: 
  - Reuse or adapt `check_dialog_tool()` function from `sleep-warning.sh` (or create shared function)
  - Replace all `zenity`-specific checks with environment-aware dialog tool selection
  - Update all GUI dialogs in `configure.sh` to support yad/kdialog/zenity with appropriate syntax
  - Ensure Visual Day/Time Configuration Grid (enhancement #16) uses same dialog tool selection
- **Files Affected**: `configure.sh`, potentially shared utility functions
- **Priority**: Medium (improves consistency and Wayland/KDE compatibility for configuration interface)
- **Status**: Not implemented
- **Benefits**:
  - Consistent behavior across entire system (warning popups and configuration wizard)
  - Better Wayland support via `yad` (important for SteamOS Gaming Mode)
  - Better KDE integration via `kdialog` (important for SteamOS Desktop Mode)
  - Improved compatibility across different Linux distributions and desktop environments
- **Related**: 
  - See enhancement #2 (Dialog Tool Priority System) for implementation details
  - See enhancement #16 (Visual Day/Time Configuration Grid) which should use this system
  - See [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md#dialog-tool-selection) for priority order
