# Fix Popup Position and Status Display

**Date**: 2026-01-19  
**Status**: In Progress

## Issues

### Issue 1: Popup Position Always Appears in Center
- User reports that popup always appears in center even when "top-left" is selected
- Root cause: Only `yad` supports position via `--geometry` parameter
- `zenity` and `kdialog` don't have built-in position control
- System prioritizes `zenity` (X11) and `kdialog` (KDE), so position control only works with `yad`

### Issue 2: Status Display Shows Size Label Instead of Dimensions
- `status.sh` currently shows "small", "medium", "large" but not actual pixel dimensions
- Users want to see the actual window size (e.g., "small (400x250)")

## Solution

### For Issue 1: Add Post-Creation Positioning for All Dialog Tools
1. After creating popup with any dialog tool, use window management tools to move it
2. Add a new function `reposition_popup_window()` in `window-management.sh`
3. Call this function after popup is created for all dialog tools (not just yad)
4. This requires `wmctrl` or `xdotool` to be available

### For Issue 2: Enhance Status Display
1. Modify `status.sh` to call `get_popup_dimensions()` 
2. Format output as: `"size_label (widthxheight)"` or just dimensions for custom sizes
3. Source the config library to access the function

## Implementation Checklist

- [x] Add `reposition_popup_window()` function to `window-management.sh`
- [x] Update `popup-display.sh` to reposition windows for zenity, yad, and kdialog
- [x] Update `status.sh` to show dimensions alongside size labels
- [x] Source config.sh in status.sh
- [x] Fix documentation discrepancy in sleep-warning.conf (dimensions)
- [x] Create test script for popup positioning
- [x] Test positioning with zenity, yad, and kdialog (user tested - found issues)
- [x] Verify status display with different size configurations (working correctly)

## Follow-up Issues Found During Testing

During user testing, two critical issues were discovered:
1. Configuration window gets repositioned instead of popup (substring matching conflict)
2. Bottom-right position calculation broken (geometry parsing bug)

These issues are documented and fixed in: `fix-window-title-and-geometry-parsing.md`

## Files to Modify

1. `lib/window-management.sh` - Add reposition function
2. `lib/popup-display.sh` - Call reposition for zenity/kdialog
3. `status.sh` - Enhance popup size display

## Technical Details

### Window Repositioning Logic
- Wait for window to be fully created (sleep 0.5-1.0s)
- Find window by title using wmctrl or xdotool
- Calculate target position using existing `calculate_popup_geometry()` logic
- Move window to target position using window tools
- Works on X11 but limited on Wayland (depends on compositor)

### Status Display Format
- Named sizes: `"small (400x250)"`, `"medium (800x500)"`, `"large (2000x1350)"`
- Custom sizes: `"600x400"` (just show dimensions)
