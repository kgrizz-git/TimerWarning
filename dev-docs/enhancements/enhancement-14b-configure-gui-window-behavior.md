# Enhancement 14b: Configure.sh GUI Window Behavior

- **Description**: Fix issue where `configure.sh` GUI windows (when run in GUI mode) can be mistaken for the warning popup and end up staying on top and being immovable. The actual warning popup should stay on top, not the configuration GUI windows.
- **Implementation**: 
  - Ensure `configure.sh` GUI windows (zenity dialogs) do not use stay-on-top or immovable window properties
  - Ensure warning popup windows have higher z-order priority than configuration GUI windows
  - Consider using different window properties or flags for configuration dialogs vs warning popups
  - May need to adjust window manager hints or properties to distinguish between configuration dialogs and warning popups
- **Files Affected**: `configure.sh`, `sleep-warning.sh`
- **Priority**: Medium (usability issue, can confuse users)
- **Status**: Not implemented
- **Current Issue**: When `configure.sh` is run in GUI mode, the zenity dialogs may be treated similarly to warning popups, causing them to stay on top and potentially be immovable, which interferes with the intended behavior where only the actual warning popup should have these properties.
