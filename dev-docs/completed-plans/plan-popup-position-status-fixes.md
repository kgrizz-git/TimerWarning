# Recent Changes and Fixes

## 2026-01-19: Popup Position and Status Display Fixes

### Issues Fixed

#### 1. Status Display Enhancement ✅
**Problem**: Status display only showed size labels (e.g., "small") without actual dimensions.

**Solution**: Enhanced `status.sh` to show both label and dimensions:
- Small: `small (400x250)`
- Medium: `medium (800x500)`
- Large: `large (2000x1350)`
- Custom: `600x400` (just dimensions)

**Files Modified**: `status.sh`

#### 2. Popup Position Not Working ✅
**Problem**: Popup always appeared in center regardless of configured position.

**Root Cause**: Only `yad` supports position via `--geometry`. `zenity` and `kdialog` don't have built-in position control.

**Solution**: Added post-creation window repositioning using `wmctrl`/`xdotool`:
- New function `reposition_popup_window()` in `window-management.sh`
- Automatically repositions windows after creation for all dialog tools
- Works on X11 (Wayland support depends on compositor)

**Files Modified**: `lib/window-management.sh`, `lib/popup-display.sh`

#### 3. Configuration Window Gets Moved (Critical Bug) ✅
**Problem**: When popup triggered while configuration GUI open, the config window moved instead of popup.

**Root Cause**: 
- Configuration window: "Sleep Warning Configuration"
- Popup window: "Sleep Warning"
- Window matching used substring search → matched both windows

**Solution**: Changed popup window title to **"ALERT: Restricted time window"**
- No substring overlap with configuration window
- Clear, descriptive, ASCII-only

**Files Modified**: `lib/popup-display.sh`, `tests/test-popup.sh`

#### 4. Bottom-Right Position Broken (Critical Bug) ✅
**Problem**: Bottom-right position placed window off-screen (negative coordinates).

**Root Cause**: Screen dimension parsing completely broken for multi-monitor setups:
```bash
# xrandr output varies:
DisplayPort-0 connected primary 2560x1440+0+0 (...)  # field 4 = geometry ✓
eDP connected 1280x800+2560+640 right (...)          # field 3 = geometry, field 4 = "right" ✗

# Old code: awk '{print $4}' → parsed "right" as dimensions
# Result: dimensions = "rightxright" → calculations = negative → off-screen
```

**Solution**: Rewrote geometry parsing with:
- Prefer primary display (main screen)
- Use regex to extract geometry pattern: `[0-9]+x[0-9]+\+[0-9]+\+[0-9]+`
- Validate dimensions are numeric and reasonable (>= 640x480)
- Fallback to 1920x1080 if parsing fails

**Testing Results**:
```
Before: Parsed "rightxright" → x=-450, y=-450 (off-screen)
After:  Parsed "2560x1440"   → x=2110, y=1140 (correct bottom-right)
```

**Files Modified**: `lib/window-management.sh`

### Testing

Created comprehensive test scripts:
- `tests/test-popup-position.sh` - Test popup positioning
- `tests/test-window-title-fix.sh` - Verify window title separation

All tests passing ✅

### Configuration File Updates

Fixed documentation in `sleep-warning.conf`:
- Old: `small (300x150), medium (400x200), large (500x250)`
- New: `small (400x250), medium (800x500), large (2000x1350)`

### Requirements

For popup positioning to work:
- **Dialog tool**: zenity, yad, or kdialog (already required)
- **Window tool**: wmctrl or xdotool (for repositioning)
- **Display protocol**: Works best on X11; Wayland support varies by compositor

#### 5. Window Positioning Bounds (Enhancement) ✅
**Problem**: Windows could appear partially off-screen, especially at bottom-right position.

**Root Cause**: Fixed 50px margin didn't account for:
- Window decorations (title bar ~30-40px, borders ~5-10px)
- Taskbars/panels (~40-60px at bottom/top)
- Position is for content area, not including decorations

**Solution**: Implemented proper margins and bounds checking:
- Horizontal margin: 30px (left/right)
- Top margin: 60px (accounts for title bar + top panels)
- Bottom margin: 80px (accounts for taskbar + title bar + decorations)
- Added bounds checking to clamp coordinates within valid range
- Ensures windows stay fully visible on screen

**Testing Results**:
```
Small (400x250):  ✅ All positions fit on screen
Medium (800x500): ✅ All positions fit on screen
Large (2000x1350): ⚠️  Some positions off-screen (expected - window too large for display)
```

**Files Modified**: `lib/window-management.sh`

### Known Limitations

- Position control on Wayland depends on compositor (some block window repositioning)
- Multi-monitor setups use primary display dimensions for calculations
- Window repositioning has ~1 second delay (allows window to stabilize)
- Very large windows (e.g., 2000x1350 on 1440p display) may extend beyond screen bounds (expected behavior)

## Summary

**Total Issues Fixed**: 5 (3 enhancements + 2 critical bugs)
**Files Modified**: 5
**Test Scripts Added**: 3
**Status**: All fixes implemented and tested ✅
