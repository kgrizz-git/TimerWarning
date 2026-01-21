# Enhancement 4: Systemd Service Environment Detection

## Description

Detect whether the system is running in **Desktop Mode** (X11/KDE Plasma) vs **Gaming Mode** (Wayland/gamescope) and configure the systemd service behavior accordingly. This ensures optimal service configuration, environment variable setup, and dependency management for each mode.

## Why This Enhancement?

### Current Situation

The systemd service (`sleep-warning.service`) currently uses a one-size-fits-all configuration that works in both Desktop Mode and Gaming Mode, but doesn't optimize for the specific requirements of each environment:

1. **Environment Variables**: Desktop Mode uses X11 (`DISPLAY`), while Gaming Mode uses Wayland (`WAYLAND_DISPLAY`). The service could be pre-configured with the appropriate variables.

2. **Service Dependencies**: While the service currently uses `graphical-session.target`, there may be mode-specific targets or dependencies that could improve reliability.

3. **Service Startup Timing**: Gaming Mode may have different initialization timing compared to Desktop Mode, potentially requiring different `After=` dependencies.

4. **Environment Inheritance**: Systemd user services inherit environment variables from the user session, but explicit configuration can ensure critical variables are available even if inheritance fails.

5. **Troubleshooting**: Explicit mode detection and logging would help diagnose issues specific to Desktop Mode vs Gaming Mode.

### Benefits

1. **Improved Reliability**: Service configuration optimized for each mode reduces the chance of failures during mode transitions or when booting directly into Gaming Mode.

2. **Better Environment Setup**: Pre-configured environment variables ensure the script has access to the correct display protocol (X11 vs Wayland) from the start.

3. **Enhanced Debugging**: Mode detection and logging make it easier to troubleshoot issues specific to Desktop Mode or Gaming Mode.

4. **Future-Proofing**: Provides a foundation for mode-specific optimizations (e.g., different dialog tool priorities, different fallback strategies).

5. **Service Persistence**: Better handling of service state across Desktop Mode ↔ Gaming Mode transitions.

### Why Not Just Rely on Script Detection?

While `sleep-warning.sh` already has robust display detection (see `lib/display-detection.sh`), this enhancement focuses on **service-level configuration**:

- **Service Dependencies**: Ensure the service starts after the appropriate graphical session is ready
- **Environment Variables**: Pre-set critical variables at the service level, not just in the script
- **Service State**: Better handling of service lifecycle during mode transitions
- **Early Detection**: Detect mode at service start time, not just when the script runs

The script-level detection (which already exists) handles runtime display detection, while this enhancement handles service-level configuration and optimization.

## How It Would Work

### Implementation Approach

1. **Create Environment Detection Function**:
   - Add a function to detect Desktop Mode vs Gaming Mode
   - Can leverage existing `detect_display_environment()` from `lib/display-detection.sh`
   - Check for gamescope process, `WAYLAND_DISPLAY` vs `DISPLAY`, session type via `loginctl`

2. **Service Configuration Script**:
   - Create a helper script or function that generates/updates the systemd service file based on detected mode
   - Or use systemd's environment file capabilities to set mode-specific variables

3. **Service File Updates**:
   - Option A: Dynamic service file generation during installation/configuration
   - Option B: Use systemd environment files (`EnvironmentFile=`) that are updated based on mode
   - Option C: Use systemd drop-in files (`.d/` directory) for mode-specific overrides

4. **Mode-Specific Configuration**:
   - **Desktop Mode (X11)**:
     - Set `DISPLAY` environment variable explicitly
     - Ensure `After=graphical-session.target` (current)
     - May add `After=plasma-workspace.service` or similar KDE-specific targets
   - **Gaming Mode (Wayland/gamescope)**:
     - Set `WAYLAND_DISPLAY` environment variable explicitly
     - Ensure `After=graphical-session.target` (current)
     - May add `After=gamescope.service` or similar if available
     - Set `GAMESCOPE_SESSION=1` if gamescope detected

5. **Installation/Configuration Integration**:
   - Run mode detection during `install.sh` or `configure.sh`
   - Generate/update service file with mode-specific configuration
   - Or create mode-specific environment files

6. **Logging**:
   - Log detected mode in service startup
   - Include mode information in script logs for troubleshooting

### Example Implementation

**Option 1: Environment File Approach**
```bash
# During installation/configuration
MODE=$(detect_mode)  # "desktop" or "gaming"
echo "DISPLAY=:0" > ~/.config/sleep-warning/service-env.conf  # Desktop Mode
# or
echo "WAYLAND_DISPLAY=wayland-0" > ~/.config/sleep-warning/service-env.conf  # Gaming Mode

# In sleep-warning.service
[Service]
EnvironmentFile=%h/.config/sleep-warning/service-env.conf
```

**Option 2: Drop-in File Approach**
```bash
# Create mode-specific drop-in
mkdir -p ~/.config/systemd/user/sleep-warning.service.d/
echo "[Service]
Environment=DISPLAY=:0" > ~/.config/systemd/user/sleep-warning.service.d/mode-desktop.conf
# or for Gaming Mode
echo "[Service]
Environment=WAYLAND_DISPLAY=wayland-0
Environment=GAMESCOPE_SESSION=1" > ~/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf
```

**Option 3: Dynamic Service File Generation**
```bash
# During installation, generate service file with mode-specific configuration
MODE=$(detect_mode)
if [ "$MODE" = "gaming" ]; then
    # Generate service file with Gaming Mode configuration
else
    # Generate service file with Desktop Mode configuration
fi
```

## Files Affected

- `sleep-warning.service` - May need mode-specific configuration or environment files
- `sleep-warning.sh` - May add mode detection logging at startup
- `install.sh` - Add mode detection and service configuration during installation
- `configure.sh` - Add mode detection and service reconfiguration during configuration
- `lib/display-detection.sh` - May add a high-level mode detection function (Desktop vs Gaming)

## Priority

**Medium** - Improves compatibility and reliability, especially for SteamOS users who switch between Desktop Mode and Gaming Mode. Not critical for basic functionality (current implementation works), but enhances robustness and troubleshooting capabilities.

## Status

**Not implemented** - This is a planned enhancement that would complement the existing display detection in the script.

## Related Documentation

- See [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md#systemd-service-robustness) for Gaming Mode considerations
- See [lib/display-detection.sh](../../lib/display-detection.sh) for existing display environment detection
- See [FUTURE_ENHANCEMENTS.md](../FUTURE_ENHANCEMENTS.md#4-systemd-service-environment-detection) for related enhancements

## Relationship to Other Enhancements

**This is NOT the same as Alternative 4 (Cron-based Timer)**:
- **Enhancement 4** (this): Detects Desktop Mode vs Gaming Mode and configures the **systemd service** accordingly
- **Alternative 4**: Replaces systemd timers with cron jobs (completely different scheduling system)

These are independent enhancements that address different aspects of the system.

## Conclusions

### Would This Help Make the Script Work in Gaming Mode on SteamOS?

**Partial Help, But Not the Main Solution**

This enhancement would provide **moderate benefits** for Gaming Mode compatibility, but it **will not solve the primary challenges**:

#### What It Would Help With ✅

1. **Service Reliability** (Significant Improvement):
   - According to [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md), service reliability is expected to improve from ~70% to ~95% effectiveness with proper systemd configuration
   - Ensures service starts correctly when booting directly into Gaming Mode
   - Improves service persistence across Desktop Mode ↔ Gaming Mode transitions
   - Better handling of service dependencies and startup timing

2. **Environment Variable Availability**:
   - Pre-configures `WAYLAND_DISPLAY` or `DISPLAY` at service level, providing a safety net if environment inheritance fails
   - However, the script already has robust display detection with multiple fallbacks, so this is more of a "belt and suspenders" approach

3. **Troubleshooting and Debugging**:
   - Mode detection and logging would make it easier to diagnose Gaming Mode-specific issues
   - Helps identify whether problems are service-related vs script-related

#### What It Would NOT Help With ❌

1. **Dialog Visibility Over Full-Screen Games** (Main Challenge):
   - The primary Gaming Mode limitation is that dialogs may not appear over exclusive full-screen games
   - This is a **compositor/game limitation**, not a service configuration issue
   - Service-level environment detection cannot solve this fundamental problem
   - **Solution**: Requires Steam Overlay integration (see [FUTURE_ENHANCEMENTS.md](../FUTURE_ENHANCEMENTS.md#1-steam-overlay-integration))

2. **Window Manager Tools Not Working**:
   - `wmctrl`/`xdotool` don't work on Wayland/gamescope regardless of service configuration
   - This is a **Wayland protocol limitation**, not a service issue
   - Service configuration cannot enable X11 tools on Wayland

3. **Display Detection**:
   - The script already has comprehensive display detection (`lib/display-detection.sh`)
   - Service-level detection would be redundant for runtime functionality
   - However, it could help with early service startup if environment variables are needed before the script runs

#### Overall Assessment

This enhancement would improve **service reliability** (from ~70% to ~95% according to the effectiveness assessment), which is one component of Gaming Mode compatibility. However, the **main Gaming Mode challenges** (dialog visibility over full-screen games, window manager tools) are **fundamental limitations** that cannot be solved by service configuration alone.

**Expected Impact**: Would contribute to the "Service Reliability" improvement mentioned in the Gaming Mode effectiveness assessment, but would not significantly change the overall ~68% effectiveness target for Gaming Mode (which is primarily limited by dialog visibility issues, not service reliability).

### Other Reasons to Add This Enhancement

Beyond Gaming Mode compatibility, there are several valuable reasons to implement this:

1. **Better Troubleshooting**:
   - Explicit mode detection and logging would make it easier to diagnose issues
   - Users and developers could quickly identify whether problems are Desktop Mode vs Gaming Mode specific
   - Service logs would clearly indicate the detected mode

2. **Service Robustness**:
   - Ensures service works reliably even if environment variable inheritance fails
   - Provides explicit configuration rather than relying solely on systemd's environment inheritance
   - Better handling of edge cases during system startup or mode transitions

3. **Foundation for Future Optimizations**:
   - Establishes a framework for mode-specific optimizations
   - Could enable mode-specific dialog tool priorities (though this could also be done at script level)
   - Could enable mode-specific fallback strategies
   - Provides infrastructure for future Gaming Mode improvements

4. **Better User Experience**:
   - More reliable service startup reduces user frustration
   - Clearer error messages and logging help users understand what's happening
   - Proactive configuration reduces the chance of failures

5. **Cross-Distribution Compatibility**:
   - While primarily focused on SteamOS, this could help with other systems that have similar mode switching (e.g., other gaming-focused distributions)
   - Provides a pattern for handling environment-specific service configuration

6. **Documentation and Clarity**:
   - Explicit mode detection makes the system's behavior more transparent
   - Easier to document and explain to users
   - Helps developers understand the system's operating context

### How Easy and Safe Would It Be to Implement?

**Assessment: Easy to Moderate Difficulty, Low Risk**

#### Ease of Implementation: ⭐⭐⭐⭐ (4/5 - Easy to Moderate)

**Factors Making It Easy**:

1. **Existing Infrastructure**:
   - The codebase already has robust display detection in `lib/display-detection.sh`
   - The `detect_display_environment()` function can be leveraged or extended
   - Service file is simple and well-structured

2. **Non-Destructive Approach**:
   - Can use systemd drop-in files (`.d/` directory) which don't modify the base service file
   - Environment files can be added without changing existing service configuration
   - Installation script already has a clear structure for service file handling

3. **Incremental Implementation**:
   - Can be implemented in phases (detection first, then configuration)
   - Doesn't require changes to core script logic
   - Can be tested independently

4. **Simple Detection Logic**:
   - Mode detection is straightforward: check for gamescope process, `WAYLAND_DISPLAY` vs `DISPLAY`, session type
   - Can reuse existing `is_gamescope_running()` and `detect_display_environment()` functions

**Factors Making It Moderate**:

1. **Installation/Configuration Integration**:
   - Need to add mode detection to `install.sh` and `configure.sh`
   - Need to handle service file updates or drop-in file creation
   - Need to handle mode transitions (what if user switches modes after installation?)

2. **Testing Requirements**:
   - Requires testing in both Desktop Mode and Gaming Mode
   - Need to test mode transitions
   - Need to verify service behavior in each mode

3. **Edge Cases**:
   - What if mode detection fails or is ambiguous?
   - What if user switches modes after installation?
   - How to handle systems that aren't SteamOS?

#### Safety of Implementation: ⭐⭐⭐⭐⭐ (5/5 - Very Safe)

**Factors Making It Safe**:

1. **Additive Changes**:
   - Primarily adds new functionality rather than modifying existing code
   - Service file can remain unchanged (use drop-in files or environment files)
   - Script logic doesn't need to change (only service configuration)

2. **Non-Breaking**:
   - Drop-in files are additive - they don't break existing service configuration
   - Environment files are optional - service works without them (just uses inheritance)
   - Can be implemented with fallbacks (if detection fails, use current behavior)

3. **Backward Compatible**:
   - Existing installations continue to work
   - New installations get enhanced configuration
   - Can be rolled out incrementally

4. **Easy to Revert**:
   - Drop-in files can be removed easily
   - Environment files can be deleted
   - No permanent changes to core files

5. **Low Risk of Breaking Existing Functionality**:
   - Service file changes are isolated
   - Script behavior doesn't change (only service configuration)
   - Worst case: service might not start (easily detectable and fixable)

6. **Well-Understood Technology**:
   - Systemd drop-in files and environment files are standard, well-documented features
   - No experimental or risky approaches required

**Potential Risks (Low)**:

1. **Mode Detection Edge Cases**:
   - Risk: Detection might fail or be ambiguous
   - Mitigation: Fallback to current behavior, log warnings

2. **Service File Conflicts**:
   - Risk: Drop-in files might conflict with manual service edits
   - Mitigation: Use standard systemd practices, document clearly

3. **Mode Transitions**:
   - Risk: Service might not adapt if user switches modes after installation
   - Mitigation: Can add mode re-detection to `configure.sh`, or accept that reconfiguration may be needed

#### Recommended Implementation Approach

**Safest Approach: Drop-in Files with Fallbacks**

1. **Use systemd drop-in files** (`.d/` directory) rather than modifying base service file
2. **Add mode detection during installation** with fallback to current behavior if detection fails
3. **Make it optional** - if mode can't be detected, service works as before
4. **Add logging** to track detected mode and any issues
5. **Test incrementally** - implement detection first, then add configuration

This approach minimizes risk while providing the benefits of mode-specific configuration.

#### Estimated Effort

- **Development Time**: 2-4 hours (detection function, installation integration, testing)
- **Testing Time**: 2-3 hours (Desktop Mode, Gaming Mode, mode transitions)
- **Documentation**: 1 hour (update docs, add comments)
- **Total**: ~5-8 hours for a complete, tested implementation

#### Conclusion on Implementation

This enhancement is **relatively easy to implement** and **very safe** because:
- It leverages existing infrastructure
- Uses non-destructive, additive approaches
- Has clear fallback paths
- Doesn't modify core script logic
- Can be tested incrementally

The main complexity is in **integration with installation/configuration scripts** and **testing across different modes**, but the technical implementation itself is straightforward.
