# Enhancement 3: Clarifications - RESOLVED

This document provides resolved clarifications for the enhancement plan.

## 1. User-Customizable Percentage Mappings ✅ RESOLVED

**Decision**: 
- **Default percentage values** (same percentage for width and height):
  - `xsmall`: 10% × 10%
  - `small`: 20% × 20%
  - `medium`: 40% × 40%
  - `large`: 60% × 60%
  - `xlarge`: 80% × 80%
  - `max`: 90% × 90%
- **Custom size**: Default 50% × 50%, user-configurable range 10-100%
- **Customization**: Only the custom size can be modified by the user (predefined sizes are fixed)
- **Configuration**: Set via `configure.sh` wizard
- **Absolute fallback**: User can also set an absolute pixel size that will be used if resolution cannot be detected

**Implementation Notes**:
- Predefined sizes use fixed percentages (not user-customizable)
- Only one custom size option exists, which can be configured as percentage (10-100%) or absolute pixels
- Custom size configuration should be stored in config file (see #10 for format)

## 2. Position-Based Display Detection ✅ RESOLVED

**Research Findings**:
- **X11**: Can use `xrandr --listactivemonitors` or parse `xrandr --query` output to get monitor positions (geometry includes `+X+Y` offsets)
- **Wayland**: No direct equivalent; compositor-specific (sway uses `swaymsg -t output`, wlr-randr provides basic info but limited)
- **Current code**: `calculate_popup_geometry()` in `lib/window-management.sh` already uses xrandr to get primary/first display

**Recommendation**:
- **X11**: Implement position-based detection by:
  1. Get popup position coordinates (center or top-left with margins)
  2. Parse `xrandr --query` output to get all monitor geometries (`WIDTHxHEIGHT+X+Y`)
  3. Match popup coordinates against monitor position ranges to determine which display
  4. Use that display's resolution for sizing calculations
- **Wayland**: Too complex/compositor-dependent; fallback to primary display detection
- **Feasibility**: Medium complexity for X11, Low feasibility for Wayland (compositor-specific)
- **Pros**: More accurate sizing on multi-monitor setups
- **Cons**: Additional complexity, Wayland limitations, may not work reliably on all systems

**Decision**: 
- **X11**: Implement position-based detection if not overly complicated
- **Wayland**: Use primary display fallback (Option A)
- **Fallback**: If position-based detection fails or is unavailable, use primary display

## 3. Default Percentage Values ✅ RESOLVED

**Decision**: Default percentage values (width and height same):
- `xsmall`: 10% × 10%
- `small`: 20% × 20%
- `medium`: 40% × 40%
- `large`: 60% × 60%
- `xlarge`: 80% × 80% (updated from 75%)
- `max`: 90% × 90%

## 4. Resolution Detection Function Location and Caching ✅ RESOLVED

**Decision**: 
- **No caching** - Always detect fresh at each popup time
- **New file**: Create `lib/resolution-detection.sh` (do not extend `lib/display-detection.sh`)
- Remove all caching mentions from codebase integration notes

## 5. Checklist Inconsistency ✅ RESOLVED

**Decision**: Update checklist to say `max` instead of `fullscreen`

## 6. Custom Pixel Size Validation Timing ✅ RESOLVED

**Decision**: 
- **Allow up to 100%** (updated from 90%)
- **Validate at configuration time** - Check if configured size exceeds 100% of detected resolution
- **Dialog tool behavior research**:
  - **YAD**: Height can become excessively tall with long text, but `--fixed` option helps. Width generally works. May extend off-screen if too large.
  - **Zenity**: Similar height issues, `--width` and `--height` have limited effect in newer versions. May push buttons off-screen.
  - **KDialog**: Limited information, but textbox mode may handle sizing differently
- **Recommendation**: 
  - Validate at configure time: If resolution can be detected, check that size ≤ 100%
  - If resolution cannot be detected at configure time, allow configuration but validate at popup time
  - If popup size would exceed display, clamp to 100% and log warning
  - Consider using KDialog textbox mode as alternative if available (may handle oversized windows better)

## 7. Error/Warning Display Location ✅ RESOLVED

**Decision**:
- **At configuration time**: Show dialog/error message to user
- **At popup time**: Log warning silently (use existing logging infrastructure)
- **Fallback behavior**: If resolution cannot be detected, use absolute pixel values (default absolutes as determined in #8)

## 8. Fixed Pixel Fallback Values ✅ RESOLVED

**Calculation**: Based on percentages and 2560×1440 monitor resolution:
- `xsmall`: 10% × 10% = **256 × 144** pixels
- `small`: 20% × 20% = **512 × 288** pixels
- `medium`: 40% × 40% = **1024 × 576** pixels
- `large`: 60% × 60% = **1536 × 864** pixels
- `xlarge`: 80% × 80% = **2048 × 1152** pixels
- `max`: 90% × 90% = **2304 × 1296** pixels
- `custom` (default): 50% × 50% = **1280 × 720** pixels

**Decision**: Use these calculated values as absolute pixel fallbacks when resolution detection fails.

## 9. Display Resolution Detection Function Details ✅ RESOLVED

**Research Findings**:
- **X11**: `xrandr --query` provides resolution and position info. Can get primary display or parse all displays.
- **Wayland**: `wlr-randr --json` provides structured output, but requires compositor support. `swaymsg -t output` for Sway. Limited compositor-agnostic options.
- **gamescope**: May need special handling, resolution detection may be limited

**Recommendation**:
- **Return format**: Space-separated "WIDTH HEIGHT" (consistent with `get_popup_dimensions()` which returns "WIDTH HEIGHT")
- **Exit code**: 0 on success, 1 on failure
- **On failure**: Return empty string (caller should check exit code and handle empty return)
- **Multi-monitor**: 
  - X11: Return primary display resolution, fallback to first connected display
  - Wayland: Return first available output resolution
- **Detection order**:
  1. X11: `xrandr --query` (primary display, then first connected)
  2. Wayland: `wlr-randr --json` → parse JSON for resolution
  3. Wayland fallback: `swaymsg -t output` (if Sway detected)
  4. Wayland fallback: `wayland-info` (if available)
  5. gamescope: Special handling (may need to use X11 fallback or environment variables)
  6. Final fallback: Return empty (caller uses absolute pixel values)

## 10. Configuration File Format for New Options ✅ RESOLVED

**Current Config File Format Review**:
- Config file uses simple `KEY=VALUE` format with `#` comments
- Written by `write_config()` in `lib/configure-config.sh`
- Format: Comment block explaining option, then `KEY=value`
- Options are written in specific order with section headers
- User comments are preserved via `extract_user_comments()`

**Recommendation** (compatible with existing code):
```bash
# POPUP_SIZE_MODE: Window size calculation mode
# Options: fixed (absolute pixel sizes) or display-based (percentage-based)
# Default: fixed (for backward compatibility)
POPUP_SIZE_MODE=fixed

# POPUP_SIZE_CUSTOM: Custom size configuration
# Format: PERCENT%xPERCENT% (e.g., 50%x50%) or WIDTHxHEIGHT (absolute pixels)
# If percentage format, used in display-based mode; if pixel format, used as absolute fallback
# Default: 50%x50%
POPUP_SIZE_CUSTOM=50%x50%

# POPUP_SIZE_CUSTOM_ABSOLUTE: Absolute pixel fallback for custom size
# Used when resolution cannot be detected and custom size is percentage-based
# Default: 1280x720 (50% of 2560x1440)
POPUP_SIZE_CUSTOM_ABSOLUTE=1280x720
```

**Implementation Notes**:
- Add `POPUP_SIZE_MODE` after `POPUP_SIZE` section in `write_config()`
- Add `POPUP_SIZE_CUSTOM` and `POPUP_SIZE_CUSTOM_ABSOLUTE` in same section
- Follow existing comment format pattern
- Ensure `extract_user_comments()` preserves any user-added comments for these new options

## 11. Backward Compatibility Details ✅ RESOLVED

**Decision**:
- **Default behavior**: Without `POPUP_SIZE_MODE`, default to `fixed` (absolute pixel mode) for backward compatibility
- **Size interpretation**:
  - If `POPUP_SIZE` contains any number > 100, assume absolute pixel size (e.g., `800x500`, `2000x1350`)
  - If `POPUP_SIZE` contains numbers ≤ 100, interpret as percentage (e.g., `50%x50%`, `80x80`)
- **Existing configs**: 
  - Existing `POPUP_SIZE=small/medium/large` continue to work (predefined sizes)
  - Existing `POPUP_SIZE=800x500` (absolute pixels) continue to work
  - If user wants display-based mode, they must explicitly set `POPUP_SIZE_MODE=display-based`
- **Migration**: No automatic migration needed; users opt-in to display-based mode

## 12. Wayland Resolution Detection Details ✅ RESOLVED

**Research Findings**:
- **wlr-randr**: Requires compositor to implement wlr-output-management protocol. Works with Sway, wlroots-based compositors. Provides JSON output.
- **swaymsg**: Sway-specific, provides output information via `swaymsg -t output`
- **wayland-info**: May be available but less common
- **GNOME/KDE Wayland**: May not support wlr-randr; may need compositor-specific approaches
- **gamescope**: Special case, may need X11 fallback or environment variable detection

**Recommendation**:
- **Detection order**:
  1. Check if gamescope running → use gamescope-specific detection (may need X11 fallback)
  2. Try `wlr-randr --json` → parse JSON for resolution
  3. Try `swaymsg -t output` (if Sway detected)
  4. Try `wayland-info` (if available)
  5. Fallback: Return empty (use absolute pixel values)
- **Pros**: Covers most common Wayland compositors (Sway, wlroots-based)
- **Cons**: May not work on GNOME/KDE Wayland; gamescope needs special handling
- **Feasibility**: Medium - works for common cases, fallback to absolute pixels for others

**Decision**: Implement detection order above, with fallback to absolute pixel values when detection fails.
