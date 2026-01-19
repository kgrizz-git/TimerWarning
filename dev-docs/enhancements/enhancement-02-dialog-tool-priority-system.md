# Enhancement 2: Dialog Tool Priority System

- **Description**: Implement intelligent dialog tool selection based on environment (prefer yad for Gaming Mode, kdialog for KDE)
- **Implementation**: Enhance `check_dialog_tool()` function with environment-aware selection
- **Files Affected**: `sleep-warning.sh`
- **Priority**: High (improves Gaming Mode compatibility)
- **Status**: ✅ **Implemented** - Environment-aware selection added (Wayland/gamescope: yad → kdialog → zenity; KDE: kdialog → yad → zenity; default: zenity → yad → kdialog). See [plan-phase-1-setup-and-scripts.md](../plan-phase-1-setup-and-scripts.md#checklist-14c-dialog-tool-priority--notify-send-fallback).
- **Related**: See [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md#dialog-tool-selection) for priority order and implementation details
