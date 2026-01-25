# Enhancement 3: Enhanced Window Size Options and Display-Based Sizing

- **Description**: Add more predefined window size options and allow window sizes to be automatically calculated based on current display resolution
- **Implementation**: 
  - Add additional predefined size options (e.g., `xsmall`, `xlarge`, `max`) beyond current `small`, `medium`, `large`
  - Add a `max` option that uses 90% of screen width and 90% of screen height (maximum size, not fullscreen)
  - Add display resolution detection function (using `xrandr` for X11, `wlr-randr` or `wayland-info` for Wayland)
  - Implement percentage-based sizing (e.g., `50%x30%` to use 50% of screen width and 30% of screen height, with 15-100% range, minimum matches xsmall)
  - Add resolution-aware predefined sizes that scale with display (fixed percentage mappings, only custom size is user-configurable)
  - Update `configure.sh` to provide GUI/text options for selecting from expanded size list or entering custom dimensions
  - Default to fixed pixel mode for backward compatibility (can be toggled to display-based sizing mode)
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Medium (improves usability and adaptability across different display configurations)
- **Status**: Not implemented
- **Current Implementation**:
  - Three predefined sizes: `small` (400x250), `medium` (800x500), `large` (2000x1350)
  - Custom sizes via `WIDTHxHEIGHT` format (200-2000 width, 100-2000 height)
  - Size configuration available in `configure.sh` "Window Behavior" section
- **Display Resolution Detection Considerations**:
  - **X11**: Can use `xrandr --query` to get screen resolution, supports multiple displays
  - **Wayland**: More complex - may need `wlr-randr`, `wayland-info`, or compositor-specific tools
  - **gamescope (SteamOS Gaming Mode)**: Resolution detection may be limited or require special handling
  - **Multi-monitor setups**: Should detect primary display or allow user to specify which display to use for sizing calculations
  - **Dynamic resolution changes**: May need to detect resolution at popup time rather than configuration time
- **Implementation Notes**:
  - Add `POPUP_SIZE_MODE` config option: `fixed` (pixel-based) or `display-based` (percentage-based), **default: `fixed`** (for backward compatibility)
  - When `display-based` is enabled, predefined sizes map to fixed screen percentages:
    - xsmall: 15%×15%, small: 20%×20%, medium: 30%×30%, large: 55%×55%, xlarge: 75%×75%, max: 90%×90%
  - Custom size: User-configurable, default 50%×50%, range 15-100% (only custom size can be modified, minimum matches xsmall)
  - Custom sizes in display-based mode accept percentage format: `WIDTH%xHEIGHT%` (15-100% range, minimum matches xsmall)
  - Custom pixel sizes: minimum 384x216 (matches xsmall size), maximum 100% of screen width/height (validate at configure time if possible)
  - Always detect resolution fresh at each popup time (no caching) - create new `lib/resolution-detection.sh`
  - Prefer detecting resolution from display where popup will appear (X11 only, if not overly complicated), otherwise use primary display
  - Fallback to absolute pixel sizes if resolution detection fails (see #8 for calculated values based on 2560×1440)
  - Update `get_popup_dimensions()` function to handle percentage calculations
  - Add resolution detection function that works across X11/Wayland with appropriate fallbacks
  - `max` option maps to `90%×90%` (maximum size option, not fullscreen)
  - `xlarge` option: 75% × 75% if resolution can be determined, otherwise fixed 1920×1080 pixels
- **Size Options Considerations**:
  - **Expanded Predefined Sizes**: Add predefined sizes (including `max` as the maximum):
    - `xsmall`: 15% × 15% (absolute fallback: 384×216 for 2560×1440 display)
    - `small`: 20% × 20% (absolute fallback: 512×288 for 2560×1440 display) - **Note**: Current implementation likely uses different dimensions (see "Current Implementation" section above)
    - `medium`: 30% × 30% (absolute fallback: 768×432 for 2560×1440 display) - **Note**: Current implementation likely uses different dimensions (see "Current Implementation" section above)
    - `large`: 55% × 55% (absolute fallback: 1408×792 for 2560×1440 display) - **Note**: Current implementation likely uses different dimensions (see "Current Implementation" section above)
    - `xlarge`: 75% × 75% (absolute fallback: 1920×1080 for 2560×1440 display)
    - `max`: 90% × 90% (absolute fallback: 2304×1296 for 2560×1440 display)
    - `custom`: User-configurable, default 50% × 50% (absolute fallback: 1280×720 for 2560×1440 display), range 15-100% (minimum matches xsmall)
  - **Custom Size Support**: Continue supporting custom pixel sizes via `WIDTHxHEIGHT` format:
    - Validation: Minimum 384x216 pixels (matches xsmall size), maximum 100% of screen width/height (scaled based on display resolution)
    - In display-based mode, allow custom percentage format: `WIDTH%xHEIGHT%` (e.g., `50%x50%`)
    - Validate percentage values: 15-100% for both dimensions (minimum matches xsmall percentage)
    - Validate at configuration time if resolution can be detected, otherwise validate at popup time
    - Provide clear error messages for invalid formats
    - User can configure both percentage and absolute pixel fallback for custom size
  - **Percentage-Based Sizing**: Enable percentage-based sizing as an alternative to fixed pixels:
    - Format: `WIDTH%xHEIGHT%` (e.g., `50%x30%`)
    - Calculate actual pixels based on detected display resolution at popup time
    - Useful for users with varying display resolutions or multi-monitor setups
    - Can be combined with `POPUP_SIZE_MODE` setting to switch between fixed and percentage modes
- **Codebase Integration Notes**:
  - **`lib/config.sh`**: 
    - Extend `get_popup_size()` validation to accept new predefined sizes (`xsmall`, `xlarge`, `max`) and percentage format
    - Update `get_popup_dimensions()` to:
      - Handle new predefined size cases with percentage-based calculations (xsmall: 15%×15%, small: 20%×20%, medium: 30%×30%, large: 55%×55%, xlarge: 75%×75%, max: 90%×90%)
      - Use absolute pixel fallbacks when resolution detection fails (xsmall: 384×216, small: 512×288, medium: 768×432, large: 1408×792, xlarge: 1920×1080, max: 2304×1296)
      - Parse percentage format (`WIDTH%xHEIGHT%`) with 15-100% validation (minimum matches xsmall) and calculate pixels from display resolution
      - Add display resolution detection call (always detect fresh, no caching)
      - Prefer detecting resolution from display where popup will appear (X11 only, if not overly complicated), fallback to primary display
      - Validate custom pixel sizes: minimum 384x216 (matches xsmall size), maximum 100% of screen (validate at configure time if possible, otherwise at popup time)
      - Maintain backward compatibility with existing `WIDTHxHEIGHT` pixel format
      - Support custom size configuration (percentage or absolute pixels)
  - **Create new `lib/resolution-detection.sh`**:
    - Add `get_display_resolution()` function that:
      - Uses `xrandr --query` for X11 to get primary display resolution (with position-based detection if available)
      - Uses `wlr-randr --json` or compositor-specific tools for Wayland
      - Handles gamescope/SteamOS Gaming Mode (may need special handling)
      - Returns space-separated "WIDTH HEIGHT" format (consistent with `get_popup_dimensions()`)
      - Exit code: 0 on success, 1 on failure
      - Returns empty string on failure (caller should use absolute pixel fallbacks)
      - **No caching** - always detect fresh at each popup time
  - **`lib/configure-input.sh`**:
    - Update `get_popup_size_config()` to:
      - Add new size options to GUI list dialog (`xsmall`, `small`, `medium`, `large`, `xlarge`, `max`, `custom`)
      - When "custom" is selected, use two-step process: first ask format (pixel vs percentage), then ask for dimensions
      - Validate input format and provide helpful error messages
  - **`lib/configure-display.sh`**:
    - Update window behavior description display to show percentage values when in display-based mode
    - Add option to toggle between `POPUP_SIZE_MODE=fixed` and `POPUP_SIZE_MODE=display-based`
  - **`sleep-warning.conf`**:
    - Add `POPUP_SIZE_MODE` configuration option (default: `fixed` for backward compatibility)
    - Add `POPUP_SIZE_CUSTOM` for custom size (default: `50%x50%`, range 15-100%, minimum matches xsmall)
    - Add `POPUP_SIZE_CUSTOM_ABSOLUTE` for absolute pixel fallback (default: `1280x720`)
    - Document new size options and percentage format in comments
  - **Backward Compatibility**:
    - Existing `small`, `medium`, `large` sizes continue to work as before
    - Existing `WIDTHxHEIGHT` custom format continues to work
    - **Default behavior**: Without `POPUP_SIZE_MODE`, default to `fixed` (absolute pixel mode) for backward compatibility
    - **Size interpretation**: If `POPUP_SIZE` contains numbers > 100, assume absolute pixels; if ≤ 100, interpret as percentage
    - Fixed pixel sizes used as fallback when resolution detection fails
- **Implementation Decisions Required**:
  **✅ DECISIONS MADE BY USER:**
  
  1. **Custom Size Maximum Limits**: ✅ **Option B** - Scale maximums based on display resolution
     - Maximum: 100% of screen width/height
     - Minimum: 384x216 pixels (absolute minimums, matches xsmall size)
  
  2. **Percentage Range Validation**: ✅ **Option B** - Enforce minimum percentage
     - Range: 15-100% for both width and height (minimum matches xsmall percentage)
  
  3. **Resolution Caching Strategy**: ✅ **Option D** - Always detect fresh
     - No caching, detect at each popup time
  
  4. **Multi-Monitor Display Selection**: ✅ **Option C** (if not overly complicated), otherwise **Option A**
     - Prefer: Detect resolution from display where popup will appear (if position-based detection available)
     - Fallback: Always use primary display for resolution detection
  
  5. **Fullscreen Implementation Details**: ✅ **"max" option** (not fullscreen)
     - Add a "max" option instead of fullscreen
     - Set as 90% in each direction (width and height)
  
  6. **Default Size Mode**: ✅ **Option A** - Default to `POPUP_SIZE_MODE=fixed`
     - Default to `fixed` (absolute pixel mode) for backward compatibility
     - Users can opt-in to `display-based` mode via configuration
  
  7. **Fallback Behavior When Resolution Detection Fails**: ✅ **Option A** - Fall back to fixed pixel sizes
     - Use predefined pixel values for all sizes when resolution detection fails
  
  8. **Custom Size Input UI/UX**: ✅ **Option B** - Two-step process
     - First ask format (pixel vs percentage), then ask for dimensions
  
  9. **Predefined Size Values in Display-Based Mode**: ✅ **Option A** - Fixed percentages (not user-customizable)
     - Predefined sizes use fixed percentage mappings (not user-customizable)
     - Only the custom size can be modified by the user (15-100% range, minimum matches xsmall)
  
  10. **xlarge Size Pixel Value**: ✅ **Custom approach**
      - Use 75% × 75% if resolution can be determined
      - Otherwise use fixed 1920×1080 pixels
  
  11. **Error Message Strategy**: ✅ **Option C** - Show warning but continue with fallback
      - Show warning but continue with fallback behavior
  
  12. **Configuration Wizard Size Selection UI**: ✅ **Option A** - Single list
      - Single list with all sizes + "Custom" option
- **Implementation Checklist**:
  **⚠️ BEFORE STARTING: Review "Implementation Decisions Required" section above and confirm all decisions with the user.**
  **⚠️ CRITICAL: Review all clarifications in `dev-docs/enhancements/enhancement-03-clarifications-needed.md` before implementing.**
  
  - [ ] Create or extend display resolution detection function (`get_display_resolution()`)
    - [ ] Implement X11 resolution detection using `xrandr`
    - [ ] Implement Wayland resolution detection (wlr-randr or compositor-specific)
    - [ ] Add gamescope/SteamOS Gaming Mode handling
    - [ ] No caching - always detect fresh at each popup time
    - [ ] Prefer detecting resolution from display where popup will appear (if position-based detection available)
    - [ ] Fallback to primary display if position-based detection not available
    - [ ] Add fallback to fixed pixel sizes if detection fails
  - [ ] Extend `get_popup_size()` in `lib/config.sh`
    - [ ] Add validation for new predefined sizes (`xsmall`, `xlarge`, `max`)
    - [ ] Add validation for percentage format (`WIDTH%xHEIGHT%`)
    - [ ] Maintain existing validation for pixel format (`WIDTHxHEIGHT`)
  - [ ] Extend `get_popup_dimensions()` in `lib/config.sh`
    - [ ] Add cases for new predefined sizes with pixel values
    - [ ] Add percentage format parsing (`WIDTH%xHEIGHT%`)
    - [ ] Integrate display resolution detection for percentage calculations (always detect fresh, no caching)
    - [ ] Add display-based mode support (calculate percentages for predefined sizes using fixed mappings)
    - [ ] Add "max" size option (90% × 90%)
    - [ ] Update xlarge: 75% × 75% if resolution detected, otherwise 1920×1080
    - [ ] Maintain backward compatibility with existing pixel-based sizes
    - [ ] Update validation ranges: minimum 384x216 (matches xsmall size), maximum 100% of screen (scaled based on display resolution)
    - [ ] Validate percentage range: 15-100% for both dimensions (minimum matches xsmall percentage)
    - [ ] Validate at configuration time if resolution can be detected, otherwise validate at popup time
    - [ ] Add `POPUP_SIZE_MODE` configuration option
    - [ ] Add to `sleep-warning.conf` with default value `fixed` (for backward compatibility)
    - [ ] Add `POPUP_SIZE_CUSTOM` and `POPUP_SIZE_CUSTOM_ABSOLUTE` options
    - [ ] Add getter function in `lib/config.sh` (`get_popup_size_mode()`)
    - [ ] Update configuration wizard to allow toggling this option
    - [ ] Update configuration wizard to allow configuring custom size (percentage or absolute pixels)
  - [ ] Update configuration wizard (`lib/configure-input.sh`)
    - [ ] Extend `get_popup_size_config()` GUI list to include all new sizes (xsmall, small, medium, large, xlarge, max, custom)
    - [ ] Add "custom" option with two-step process: first ask format (pixel vs percentage), then ask for dimensions
    - [ ] Add input validation: 384x216 minimum (matches xsmall size), 100% maximum for pixels; 15-100% range (minimum matches xsmall) for percentages
    - [ ] Validate at configuration time if resolution can be detected
    - [ ] Add helpful error messages (show dialog/error at configure time, log silently at popup time)
    - [ ] Update text mode prompts similarly
  - [ ] Update configuration display (`lib/configure-display.sh`)
    - [ ] Show percentage values when in display-based mode
    - [ ] Add UI option to toggle `POPUP_SIZE_MODE`
    - [ ] Update window behavior description formatting
  - [ ] Update documentation
    - [ ] Update `user-docs/CONFIGURATION.md` with new size options and percentage format
    - [ ] Update `user-docs/USER_GUIDE.md` if needed
    - [ ] Add examples of percentage-based sizing
  - [ ] Testing
    - [ ] Test all new predefined sizes (xsmall, small, medium, large, xlarge, max)
    - [ ] Test custom pixel format (`WIDTHxHEIGHT`) with 384x216 minimum (matches xsmall) and 100% maximum validation
    - [ ] Test custom percentage format (`WIDTH%xHEIGHT%`) with 10-100% range validation
    - [ ] Test display-based mode with predefined sizes (xsmall: 15%×15%, small: 20%×20%, medium: 30%×30%, large: 55%×55%, xlarge: 75%×75%, max: 90%×90%)
    - [ ] Test display-based mode with percentage custom sizes (default 50%×50%, configurable 15-100%, minimum matches xsmall)
    - [ ] Test resolution detection on X11, Wayland, and gamescope (always detect fresh, no caching)
    - [ ] Test fallback behavior when resolution detection fails (should use absolute pixel values: xsmall: 384×216, small: 512×288, medium: 768×432, large: 1408×792, xlarge: 1920×1080, max: 2304×1296, custom: 1280×720)
    - [ ] Test xlarge size: 75% × 75% when resolution detected, 1920×1080 when not
    - [ ] Test "max" size: 90% × 90% when resolution detected, 2304×1296 when not
    - [ ] Test dialog tool behavior with oversized windows (YAD, Zenity, KDialog)
    - [ ] **Test button visibility and usability for all predefined sizes**:
      - [ ] Test xsmall (256×144): Verify buttons are visible and clickable for all dialog tools (YAD, Zenity, KDialog)
      - [ ] Test small (384×216): Verify buttons are visible and clickable for all dialog tools
      - [ ] Test medium (768×432): Verify buttons are visible and clickable for all dialog tools
      - [ ] Test large (1408×792): Verify buttons are visible and clickable for all dialog tools
      - [ ] Test xlarge (1920×1080): Verify buttons are visible and clickable for all dialog tools
      - [ ] Test max (2304×1296): Verify buttons are visible and clickable for all dialog tools
      - [ ] Test custom sizes at minimum (384×216, matches xsmall): Verify buttons are visible and clickable
      - [ ] Test custom sizes at various percentages (15%, 20%, 50%, 90%, 100%): Verify buttons are visible and clickable
      - [ ] **Note**: Very small windows (especially xsmall at 384×216) may have button visibility issues with some dialog tools:
        - **YAD**: Generally handles small windows well, buttons should be visible even at minimum size
        - **Zenity**: May have issues with very small windows; buttons might be cut off or require scrolling
        - **KDialog**: Consider using `--textbox` mode (see Enhancement #29) for better size control; `--sorry`/`--msgbox` may not respect geometry and buttons may be hidden at very small sizes
      - [ ] **KDialog textbox consideration**: Test whether using `--textbox` mode (which supports `--geometry`) provides better button visibility at small sizes compared to `--sorry` dialog
      - [ ] Document any size limitations discovered during testing (e.g., "minimum practical size for Zenity is 300×200" or "KDialog requires textbox mode for sizes < 400×300")
    - [ ] Test backward compatibility (existing configs without POPUP_SIZE_MODE default to fixed mode)
    - [ ] Test size interpretation (numbers >100 = absolute, ≤100 = percentage)
    - [ ] Test backward compatibility with existing configurations
    - [ ] Test on different display resolutions (1080p, 4K, ultrawide)
    - [ ] Test on multi-monitor setups (prefer display where popup appears, fallback to primary)
- **User Experience Benefits**:
  - Better popup sizing on high-resolution displays (4K, ultrawide monitors)
  - Consistent visual appearance across different screen sizes
  - Easier configuration for users with multiple displays or changing resolutions
  - More intuitive sizing options (percentage-based feels more natural than pixel values)
- **Dialog Tool Considerations for Small Windows**:
  - **Button Visibility at Small Sizes**: Very small windows (especially at minimum 384×216, matching xsmall) may have button visibility issues:
    - **YAD**: Generally reliable even at small sizes; `--fixed` flag helps enforce dimensions
    - **Zenity**: May cut off buttons or require scrolling at very small sizes; consider minimum practical size of 300×200
    - **KDialog**: `--sorry` and `--msgbox` dialogs don't support `--geometry`; buttons may be hidden at small sizes. Consider using `--textbox` mode (see Enhancement #29) which supports `--geometry` and may provide better control at small sizes, though it has different visual appearance (scrollable text viewer vs. message box)
  - **Testing Requirement**: All predefined sizes must be tested to confirm buttons are visible and clickable for all dialog tools
  - **Fallback Strategy**: If a dialog tool cannot display buttons properly at a requested size, consider:
    1. Clamping to a minimum practical size for that tool (e.g., 300×200 for Zenity)
    2. Using alternative dialog mode (e.g., `--textbox` for KDialog) if available
    3. Logging a warning and using fallback size
  - **KDialog Textbox Mode**: Enhancement #29 explores using `--textbox` with `--geometry` for KDialog to enable size control. This may be necessary for small window sizes, though it changes the visual appearance from a message box to a scrollable text viewer.
- **Related**: Complements existing window size configuration, works with popup position feature. See Enhancement #29 for KDialog window size control considerations.
- **Interaction with Enhancement 22 (Prevent 24/7 Restriction Configuration)**:
  - When restrictions exceed 6720 minutes (> 16 hours/day), enhancement-22 automatically restricts popup window sizes to prevent overly intrusive popups
  - **Allowed sizes when restrictions > 6720 minutes**: `xsmall`, `small`, and `medium` only
    - Enhancement-22 currently allows only `small` and `medium`; `xsmall` should be added to the allowed list
  - **Custom size handling**: When restrictions > 6720 minutes, custom sizes should be restricted to match the maximum allowed predefined size
    - If custom size (percentage or absolute pixels) would exceed `medium` size (30% × 30% or 768×432 for 2560×1440), it should be automatically clamped to `medium` size
    - This ensures custom sizes don't bypass the safety restriction for high restriction levels
  - **Implementation notes**:
    - In `lib/configure-validation.sh` or `configure.sh`, when high restrictions are detected, validate that `POPUP_SIZE` is one of: `xsmall`, `small`, or `medium`
    - If `POPUP_SIZE` is `large`, `xlarge`, `max`, or `custom` with dimensions exceeding medium, automatically change to `medium`
    - If `POPUP_SIZE` is `custom` with dimensions ≤ medium size, allow it to remain as custom (user may have configured a small custom size intentionally)
    - Add validation in `get_popup_size_config()` to show only allowed sizes when high restrictions are detected
