# Enhancement 14b: Configure.sh GUI Window Behavior

- **Description**: Fix issue where `configure.sh` GUI windows (when run in GUI mode) can be mistaken for the warning popup and end up staying on top and being immovable. The actual warning popup should stay on top, not the configuration GUI windows.
- **Implementation**: 
  - ✅ **Implemented** - Window title differentiation prevents configure.sh windows from being mistaken for warning popups
  - Warning popup uses window title: **"ALERT: Restricted time window"**
  - Configure.sh dialogs use window title: **"Sleep Warning Configuration"**
  - Window management functions identify windows by title, so different titles ensure correct window identification
  - This prevents configure.sh GUI windows from being treated with stay-on-top or immovable properties intended only for warning popups
- **Files Affected**: `lib/popup-display.sh` (warning popup title), `lib/configure-*.sh` (configure dialog titles)
- **Priority**: Medium (usability issue, can confuse users)
- **Status**: ✅ **Implemented**
- **Implementation Details**: 
  - In `lib/popup-display.sh`, the warning popup window title is set to "ALERT: Restricted time window"
  - A comment explains that the popup title is intentionally different from "Sleep Warning Configuration"
  - All configure.sh dialogs consistently use "Sleep Warning Configuration" as their window title
  - This ensures window management functions (like `make_window_unclosable()`, `keep_window_on_top()`) correctly identify only the warning popup, not configure.sh dialogs
