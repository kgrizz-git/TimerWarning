# Fix Window Title Matching and Geometry Parsing Issues

**Date**: 2026-01-19  
**Status**: In Progress

## Issues Discovered During Testing

### Issue 1: Configuration Window Gets Moved Instead of Popup
**Problem**: When popup is triggered while configure.sh is open, the configuration window gets repositioned instead of the popup.

**Root Cause**: 
- Configuration window title: "Sleep Warning Configuration"
- Popup window title: "Sleep Warning"
- Current matching uses substring search (`grep "Sleep Warning"` matches both)
- Window tools find the first match, which might be the config window

**Impact**: Configuration window jumps around the screen unexpectedly

### Issue 2: Bottom-Right Position is Completely Wrong
**Problem**: Window appears "way up and to the left, mostly off the screen" instead of bottom-right

**Root Cause**: Screen dimension parsing broken for multi-monitor setups
- Current code: `awk '{print $4}'` assumes geometry is always field 4
- Reality: xrandr format varies:
  - Primary display: `DisplayPort-0 connected primary 2560x1440+0+0 (...)` (field 4)
  - Non-primary: `eDP connected 1280x800+2560+640 right (...)` (field 3, field 4 is "right")
- When first display is non-primary, parses "right" → dimensions become "rightxright" → calculations use 0
- Bottom-right calculation: `x = 0 - 400 - 50 = -450` (off screen!)

## Solutions

### Solution 1: Make Popup Window Title More Specific
Change popup title from "Sleep Warning" to something unique that won't match configuration:
- Option A: "⚠️ Sleep Warning ⚠️" (includes emoji)
- Option B: "Sleep Warning - Alert" (add suffix)
- Option C: "Late Night Warning" (different name entirely)

**Recommended**: Option A (emoji makes it visually distinct and unique for matching)

### Solution 2: Fix Screen Dimension Parsing
Improve xrandr parsing to handle both primary and non-primary displays:
- Use regex to extract geometry pattern (NxN+N+N) instead of fixed field position
- Prefer primary display if available
- Add validation to ensure dimensions are numeric
- Fallback to safer defaults if parsing fails

### Solution 3: Add Window ID Tracking (Alternative)
Instead of searching by title, track the window ID when popup is created:
- Store popup window ID when created
- Use exact window ID for repositioning
- More reliable but requires more state management

## Implementation Plan

1. **Fix screen dimension parsing** (Critical - affects all positions) ✅
   - Rewrite `calculate_popup_geometry()` screen detection
   - Use grep -oE with regex to extract geometry pattern
   - Validate parsed dimensions are numeric
   - Prefer primary display

2. **Change popup window title** (Important - prevents config window interference) ✅
   - Changed from "Sleep Warning" to "ALERT: Restricted time window"
   - Updated all references in popup-display.sh
   - Updated test scripts

3. **Add debug logging** (Helpful for future issues)
   - Log detected screen dimensions
   - Log found window IDs and titles
   - Log calculated positions

## Implementation Summary

### Changes Made

1. **lib/popup-display.sh**:
   - Changed window title from "Sleep Warning" to "ALERT: Restricted time window"
   - Updated all dialog tool invocations (zenity, yad, kdialog)
   - Updated all window management function calls
   - Updated notify-send fallback

2. **lib/window-management.sh**:
   - Fixed `calculate_popup_geometry()` screen dimension parsing
   - Now prefers primary display over non-primary
   - Uses regex pattern `[0-9]+x[0-9]+\+[0-9]+\+[0-9]+` to extract geometry
   - Validates dimensions are numeric and reasonable (>= 640x480)
   - Falls back to 1920x1080 if parsing fails

3. **tests/test-popup.sh**:
   - Updated window title to match new title

### Testing Results

Geometry parsing test with multi-monitor setup:
```
Screen: DisplayPort-0 connected primary 2560x1440+0+0
Extracted: 2560x1440+0+0
Parsed: 2560x1440 ✓

Bottom-right calculation:
  Window: 400x250
  Position: x=2110, y=1140 ✓
  (Previously: x=-450, y=-450 with "rightxright" bug)
```

## Additional Enhancement: Proper Window Bounds

### Issue 3: Windows Appearing Partially Off-Screen
**Problem**: Even after fixing geometry parsing, windows could still appear partially off-screen at edge positions.

**Root Cause**: Fixed 50px margin didn't account for window decorations and panels.

**Solution**: Implemented proper margins and bounds checking:
- Horizontal: 30px (adequate for borders)
- Top: 60px (title bar + top panels)
- Bottom: 80px (taskbar + title bar + decorations)
- Added coordinate clamping to ensure windows stay on screen

**Testing**: All small and medium windows now fit completely on screen at all positions ✅

## Files Modified

1. `lib/window-management.sh` - Fixed geometry parsing + added proper margins and bounds checking
2. `lib/popup-display.sh` - Changed window title and updated all references
3. `tests/test-popup.sh` - Updated test window title
4. `tests/test-position-bounds.sh` - New comprehensive bounds testing script