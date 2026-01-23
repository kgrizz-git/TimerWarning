# Enhancement 3: Enhanced Window Size Options and Display-Based Sizing

- **Description**: Add more predefined window size options and allow window sizes to be automatically calculated based on current display resolution
- **Implementation**: 
  - Add additional predefined size options (e.g., `xsmall`, `xlarge`, `xxlarge`) beyond current `small`, `medium`, `large`
  - Add a `fullscreen` option that uses the full available work area of the chosen display
  - Add display resolution detection function (using `xrandr` for X11, `wlr-randr` or `wayland-info` for Wayland)
  - Implement percentage-based sizing (e.g., `50%x30%` to use 50% of screen width and 30% of screen height)
  - Add resolution-aware predefined sizes that scale with display (e.g., `medium` could be 30% of screen width by 20% of screen height)
  - Update `configure.sh` to provide GUI/text options for selecting from expanded size list or entering custom dimensions
  - Add option in `configure.sh` to enable/disable display-based sizing
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
  - Add `POPUP_SIZE_MODE` config option: `fixed` (current behavior) or `display-based` (percentage-based)
  - When `display-based` is enabled, predefined sizes could map to screen percentages:
    - `small`: 20% width × 15% height
    - `medium`: 30% width × 20% height  
    - `large`: 50% width × 35% height
  - Custom sizes in display-based mode could accept percentage format: `50%x30%`
  - Fallback to fixed pixel sizes if resolution detection fails
  - Cache detected resolution to avoid repeated queries (with refresh option)
  - Update `get_popup_dimensions()` function to handle percentage calculations
  - Add resolution detection function that works across X11/Wayland with appropriate fallbacks
  - `fullscreen` can be implemented as a special-case size that maps to `100%x100%` (or compositor-reported work area), and is **low complexity** once reliable display detection and popup positioning are in place
- **Size Options Considerations**:
  - **Expanded Predefined Sizes**: Add 4-5 predefined sizes (including `fullscreen` as the maximum):
    - `xsmall`: 250x150 (or 15% width × 10% height in display-based mode)
    - `small`: 400x250 (or 20% width × 15% height in display-based mode) - existing
    - `medium`: 800x500 (or 30% width × 20% height in display-based mode) - existing
    - `large`: 2000x1350 (or 50% width × 35% height in display-based mode) - existing
    - `xlarge`: 3000x2000 (or 70% width × 50% height in display-based mode)
    - `fullscreen`: 100% width × 100% height (uses full work area of display)
  - **Custom Size Support**: Continue supporting custom pixel sizes via `WIDTHxHEIGHT` format:
    - Maintain current validation: 200-2000 width, 100-2000 height (or adjust max based on display resolution)
    - In display-based mode, allow custom percentage format: `WIDTH%xHEIGHT%` (e.g., `45%x25%`)
    - Validate percentage values (e.g., 10-100% for both dimensions)
    - Provide clear error messages for invalid formats
  - **Percentage-Based Sizing**: Enable percentage-based sizing as an alternative to fixed pixels:
    - Format: `WIDTH%xHEIGHT%` (e.g., `50%x30%`)
    - Calculate actual pixels based on detected display resolution at popup time
    - Useful for users with varying display resolutions or multi-monitor setups
    - Can be combined with `POPUP_SIZE_MODE` setting to switch between fixed and percentage modes
- **Codebase Integration Notes**:
  - **`lib/config.sh`**: 
    - Extend `get_popup_size()` validation to accept new predefined sizes (`xsmall`, `xlarge`, `fullscreen`) and percentage format
    - Update `get_popup_dimensions()` to:
      - Handle new predefined size cases
      - Parse percentage format (`WIDTH%xHEIGHT%`) and calculate pixels from display resolution
      - Add display resolution detection call (or use cached resolution if available)
      - Maintain backward compatibility with existing `WIDTHxHEIGHT` pixel format
  - **`lib/display-detection.sh`** (or create new `lib/resolution-detection.sh`):
    - Add `get_display_resolution()` function that:
      - Uses `xrandr --query` for X11 to get primary display resolution
      - Uses `wlr-randr` or compositor-specific tools for Wayland
      - Handles gamescope/SteamOS Gaming Mode (may need special handling)
      - Returns width and height as separate values or combined string
      - Caches result to avoid repeated queries during same session
  - **`lib/configure-input.sh`**:
    - Update `get_popup_size_config()` to:
      - Add new size options to GUI list dialog (`xsmall`, `small`, `medium`, `large`, `xlarge`, `fullscreen`, `custom`)
      - When "custom" is selected, prompt for either pixel format (`WIDTHxHEIGHT`) or percentage format (`WIDTH%xHEIGHT%`)
      - Validate input format and provide helpful error messages
  - **`lib/configure-display.sh`**:
    - Update window behavior description display to show percentage values when in display-based mode
    - Add option to toggle between `POPUP_SIZE_MODE=fixed` and `POPUP_SIZE_MODE=display-based`
  - **`sleep-warning.conf`**:
    - Add `POPUP_SIZE_MODE` configuration option (default: `fixed` for backward compatibility)
    - Document new size options and percentage format in comments
  - **Backward Compatibility**:
    - Existing `small`, `medium`, `large` sizes continue to work as before
    - Existing `WIDTHxHEIGHT` custom format continues to work
    - Default behavior remains unchanged (fixed pixel sizes) unless user explicitly enables display-based mode
- **Implementation Decisions Required**:
  **⚠️ IMPORTANT: Before implementing, ask the user to make decisions on the following items:**
  
  1. **Custom Size Maximum Limits**:
     - **Option A**: Keep fixed maximums (2000 width, 2000 height) regardless of display resolution
     - **Option B**: Scale maximums based on display resolution (e.g., 90% of screen width/height, with absolute minimums)
     - **Option C**: Allow up to fullscreen size (100% of display) for custom pixel sizes
     - **Recommendation**: Option B provides better flexibility while maintaining safety limits
  
  2. **Percentage Range Validation**:
     - **Option A**: Allow 1-100% for both width and height
     - **Option B**: Enforce minimum percentage (e.g., 10-100%) to prevent unusably small popups
     - **Option C**: Different min/max for width vs height (e.g., width: 10-100%, height: 5-100%)
     - **Recommendation**: Option B (10-100%) balances flexibility with usability
  
  3. **Resolution Caching Strategy**:
     - **Option A**: Cache for entire session (until script/service restarts)
     - **Option B**: Cache with timeout (e.g., 5-10 minutes, then refresh)
     - **Option C**: Cache per popup display (detect once per warning, refresh on next warning)
     - **Option D**: Always detect fresh (no caching, detect at each popup time)
     - **Recommendation**: Option C balances performance with handling dynamic resolution changes
  
  4. **Multi-Monitor Display Selection**:
     - **Option A**: Always use primary display for resolution detection
     - **Option B**: Allow user to configure which display to use (add `POPUP_DISPLAY` config option)
     - **Option C**: Detect resolution from display where popup will appear (if position-based detection available)
     - **Recommendation**: Option A for initial implementation, Option B as follow-on enhancement
  
  5. **Fullscreen Implementation Details**:
     - **Option A**: Use full screen resolution (100% width × 100% height, may overlap taskbars/docks)
     - **Option B**: Use work area (exclude taskbars/docks/panels) - requires compositor API or estimation
     - **Option C**: Use full screen but with small margin (e.g., 98% × 98%) to avoid overlap issues
     - **Recommendation**: Option A for simplicity, Option B if compositor APIs are available and reliable
  
  6. **Default Size Mode**:
     - **Option A**: Default to `POPUP_SIZE_MODE=fixed` (backward compatible, no change to existing behavior)
     - **Option B**: Default to `POPUP_SIZE_MODE=display-based` (new default, better for modern displays)
     - **Option C**: Auto-detect based on display resolution (e.g., use display-based for 4K+, fixed for lower res)
     - **Recommendation**: Option A for maximum backward compatibility
  
  7. **Fallback Behavior When Resolution Detection Fails**:
     - **Option A**: Fall back to fixed pixel sizes (use predefined pixel values for all sizes)
     - **Option B**: Fall back to safe default resolution (e.g., 1920x1080) for percentage calculations
     - **Option C**: Disable display-based mode and show error/warning to user
     - **Option D**: Use last known/cached resolution if available, otherwise Option A
     - **Recommendation**: Option D (use cache if available), then Option A (fixed pixels) as final fallback
  
  8. **Custom Size Input UI/UX**:
     - **Option A**: Single prompt asking for format, then validate (user types `450x220` or `50%x30%`)
     - **Option B**: Two-step: first ask format (pixel vs percentage), then ask for dimensions
     - **Option C**: Smart detection: try to parse as percentage first, if fails try pixel format
     - **Recommendation**: Option C provides best user experience (most intuitive)
  
  9. **Predefined Size Values in Display-Based Mode**:
     - **Option A**: Use exact percentages as specified (e.g., `small` = 20% × 15% always)
     - **Option B**: Calculate percentages from current fixed pixel values relative to a "standard" resolution (e.g., 1920x1080)
     - **Option C**: Allow user to customize percentage mappings for predefined sizes
     - **Recommendation**: Option A for consistency and simplicity
  
  10. **xlarge Size Pixel Value**:
      - **Option A**: Fixed 3000x2000 (may exceed some display resolutions)
      - **Option B**: Calculate as percentage of a large standard resolution (e.g., 70% of 4K = 2688x1512)
      - **Option C**: Use display resolution - small margin (e.g., 95% of detected resolution)
      - **Recommendation**: Option A for fixed mode, but in display-based mode it would be 70% × 50% anyway
  
  11. **Error Message Strategy**:
      - **Option A**: Silent fallback (use defaults, log warning but don't show user)
      - **Option B**: Show user-friendly error dialog when invalid size is configured
      - **Option C**: Show warning but continue with fallback
      - **Recommendation**: Option C (warn but continue) for configuration time, Option A (silent) for runtime popup display
  
  12. **Configuration Wizard Size Selection UI**:
      - **Option A**: Single list with all sizes + "Custom" option
      - **Option B**: Separate sections: "Predefined Sizes" and "Custom Size" with sub-options
      - **Option C**: Radio buttons for predefined, separate input field for custom
      - **Recommendation**: Option A for simplicity, but consider Option B if list becomes too long
- **Implementation Checklist**:
  **⚠️ BEFORE STARTING: Review "Implementation Decisions Required" section above and confirm all decisions with the user.**
  
  - [ ] Create or extend display resolution detection function (`get_display_resolution()`)
    - [ ] Implement X11 resolution detection using `xrandr`
    - [ ] Implement Wayland resolution detection (wlr-randr or compositor-specific)
    - [ ] Add gamescope/SteamOS Gaming Mode handling
    - [ ] Add resolution caching mechanism
    - [ ] Add fallback to safe defaults if detection fails
  - [ ] Extend `get_popup_size()` in `lib/config.sh`
    - [ ] Add validation for new predefined sizes (`xsmall`, `xlarge`, `fullscreen`)
    - [ ] Add validation for percentage format (`WIDTH%xHEIGHT%`)
    - [ ] Maintain existing validation for pixel format (`WIDTHxHEIGHT`)
  - [ ] Extend `get_popup_dimensions()` in `lib/config.sh`
    - [ ] Add cases for new predefined sizes with pixel values
    - [ ] Add percentage format parsing (`WIDTH%xHEIGHT%`)
    - [ ] Integrate display resolution detection for percentage calculations
    - [ ] Add display-based mode support (calculate percentages for predefined sizes)
    - [ ] Maintain backward compatibility with existing pixel-based sizes
    - [ ] Update validation ranges (may need to adjust max based on display resolution)
  - [ ] Add `POPUP_SIZE_MODE` configuration option
    - [ ] Add to `sleep-warning.conf` with default value `fixed`
    - [ ] Add getter function in `lib/config.sh` (`get_popup_size_mode()`)
    - [ ] Update configuration wizard to allow toggling this option
  - [ ] Update configuration wizard (`lib/configure-input.sh`)
    - [ ] Extend `get_popup_size_config()` GUI list to include all new sizes
    - [ ] Add "custom" option that prompts for either pixel or percentage format
    - [ ] Add input validation and helpful error messages
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
    - [ ] Test all new predefined sizes (xsmall, small, medium, large, xlarge, fullscreen)
    - [ ] Test custom pixel format (`WIDTHxHEIGHT`)
    - [ ] Test custom percentage format (`WIDTH%xHEIGHT%`)
    - [ ] Test display-based mode with predefined sizes
    - [ ] Test display-based mode with percentage custom sizes
    - [ ] Test resolution detection on X11, Wayland, and gamescope
    - [ ] Test fallback behavior when resolution detection fails
    - [ ] Test backward compatibility with existing configurations
    - [ ] Test on different display resolutions (1080p, 4K, ultrawide)
    - [ ] Test on multi-monitor setups
- **User Experience Benefits**:
  - Better popup sizing on high-resolution displays (4K, ultrawide monitors)
  - Consistent visual appearance across different screen sizes
  - Easier configuration for users with multiple displays or changing resolutions
  - More intuitive sizing options (percentage-based feels more natural than pixel values)
- **Related**: Complements existing window size configuration, works with popup position feature
