# SteamOS Gaming Mode Compatibility and Effectiveness

This document provides comprehensive information about SteamOS Gaming Mode compatibility, including challenges, implementation strategies, effectiveness assessment, and testing requirements. For the master plan and detailed checklists, see [linux-warning-system-plan.md](plans/master/linux-warning-system-plan.md) and the [phase plans](plans/phases/) linked from it.

## Overview

SteamOS Gaming Mode presents unique challenges for systemd-based warning systems due to its use of the gamescope Wayland compositor, focus on full-screen gaming experiences, and different environment setup compared to traditional desktop environments. This document outlines the compatibility considerations, implementation strategies, testing requirements, and effectiveness assessment specific to SteamOS Gaming Mode.

## Executive Summary

**Key Takeaway**: SteamOS Gaming Mode (`gamescope`) does not composite standard X11/Wayland dialog windows above fullscreen games unless they are rendered on the primary Xwayland overlay display (`:0`) and tagged with `gamescope`'s `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` X11 window properties.

**Current Status**: ⚙️ **Experimental Overlay Implemented (Opt-In via `GAMING_MODE_EXPERIMENTAL_ENABLED`)**

### How the Experimental `gamescope` Overlay Works

1. **Settings Toggle (`GAMING_MODE_EXPERIMENTAL_ENABLED`)**:
   - Controlled via `sleep-warning-configure` → **Option 12: Service Mode (Desktop/Gaming - Experimental)** or in `~/.config/sleep-warning/config/sleep-warning.conf` (`GAMING_MODE_EXPERIMENTAL_ENABLED=true|false`, default `false`).
   - During active lock hours, tighten-only partial lock (`lib/configure-partial-lock.sh`) allows enabling (`false` → `true`) and blocks disabling (`true` → `false`).
   - When disabled (`false`), `is_gaming_mode_enabled()` returns false and `detect_display_environment()` treats the session as standard `x11`/`wayland` even if `gamescope` is running.
2. **Xwayland Display Detection (`:0`)**:
   - `gamescope` exposes two Xwayland displays (`:0` for the Steam UI / overlay plane and `:1` for the game plane) plus a `gamescope-0` Wayland socket.
   - When `is_gaming_mode_enabled && is_gamescope_running` is true, `detect_display_environment()` returns `"gamescope"` (including when `DISPLAY=:0` is already set in the environment), and `get_gamescope_x11_display()` resolves `:0`.
3. **Forcing X11/Xwayland Backend (`POPUP_FORCE_X11_BACKEND=true`)**:
   - In `show_warning()`, when `env_type == "gamescope"`, `DISPLAY=:0` is exported, `WAYLAND_DISPLAY` is unset, and `POPUP_FORCE_X11_BACKEND=true` is exported.
   - `_popup_spawn_warning_dialog()` in `lib/popup-dialog-implementations.sh` prefixes `yad`/`zenity`/`kdialog` with `env -u WAYLAND_DISPLAY GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb` so the dialog is an X11 client on `:0` with its exact PID preserved in `popup_pid`.
4. **Setting `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` Atoms**:
   - `find_window_id_for_popup()` in `lib/window-management.sh` queries `xprop -root _NET_CLIENT_LIST` and matches `_NET_WM_PID` against `popup_pid` (with fallbacks to `wmctrl`, `xdotool`, and `xwininfo -root -tree`), so it works on stock SteamOS without `wmctrl` or `xdotool`.
   - `apply_gamescope_overlay_atoms()` sets `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` (`32c` cardinal atoms) via `xprop` on initial spawn, on every countdown respawn (`_popup_linux_update_countdown`), and on the "Pause Activated" confirmation dialog.
5. **Safety Guardrails (`GAMESCOPE_FORCE_AUTO_CLOSE=true`)**:
   - `lib/popup-safety.sh` forces `auto_close="true"` when `env_type == "gamescope"`, ensuring popups always auto-close after `POPUP_MIN_DISPLAY_TIME + POPUP_AUTO_CLOSE_DELAY_SECONDS` in addition to the hard `POPUP_ABSOLUTE_MAX_SECONDS` watchdog.

## Key Challenges

### 1. Display Environment Detection

**SteamOS Display Protocol Distinction**:
- **Desktop Mode**: Uses **X11** (KDE Plasma desktop environment runs on X11). Window manager tools (`wmctrl`/`xdotool`) work in Desktop Mode, enabling full window control features like making windows immovable, preventing closing, etc.
- **Gaming Mode**: Uses **gamescope** (embedded Wayland compositor with Xwayland `:0` and `:1`). Standard Wayland or untagged X11 windows are hidden behind the running game; windows must connect to Xwayland `:0` and carry `STEAM_OVERLAY=1` / `STEAM_INPUT_FOCUS=1`.

**Gaming Mode Specific Challenges**:
- Gaming Mode uses gamescope (Wayland compositor + Xwayland `:0`/`:1`)
- `DISPLAY` environment variable may not be set in user systemd units unless configured (`mode-gaming.conf` sets `Environment=DISPLAY=:0`)
- Checking `DISPLAY` before `gamescope` without checking `is_gamescope_running` would misclassify Gaming Mode as desktop `x11`
- Wayland socket in `$XDG_RUNTIME_DIR` is named `gamescope-0` rather than `wayland-0`

### 2. Systemd User Services
- User services work in Gaming Mode when configured with `mode-gaming.conf` (`PartOf=graphical-session.target`, `GAMESCOPE_SESSION=1`, `DISPLAY=:0`)
- Services persist across Desktop Mode ↔ Gaming Mode transitions
- Services start automatically when booting directly into Gaming Mode

### 3. GUI Dialog Compatibility
- Without `STEAM_OVERLAY=1`, `zenity`/`yad`/`kdialog` do not appear over fullscreen games in `gamescope`
- Without `STEAM_INPUT_FOCUS=1`, dialogs cannot receive Steam Deck controller (`A`/`B`/touch) input
- Classic EWMH window manager tools (`wmctrl`/`xdotool`) are not installed by default on SteamOS and do not manage `gamescope` overlay stacking
- Fallback: if all GUI dialogs fail, a non-modal notification (`notify-send`) is attempted and logged

### 4. Performance Considerations
- Timer checks should not impact game performance
- Dialog display should not cause frame drops or stuttering
- System should handle high CPU/GPU load scenarios gracefully

## Implementation Strategies

### Display Detection Enhancements

**Implemented**:
- [x] Detect `$WAYLAND_DISPLAY` environment variable and `gamescope-*` sockets
- [x] Detect gamescope compositor (`pgrep -x gamescope` or `GAMESCOPE_SESSION`) gated by `is_gaming_mode_enabled()`
- [x] Use `loginctl` to find sessions
- [x] Resolve gamescope Xwayland display (`:0`) via `get_gamescope_x11_display()`
- [x] Implement multi-protocol display detection (X11, Wayland, gamescope)
- [x] Log display environment information (`x11`/`wayland`/`gamescope`, display identifier) to log file

For implementation details, see [plan-phase-1-setup-and-scripts.md](plans/phases/plan-phase-1-setup-and-scripts.md#checklist-14-implement-display-and-popup-functionality).

### Window State Detection

**Purpose**: Detect and log the state of the active window to help troubleshoot popup visibility issues, especially in Gaming Mode.

**Required Implementation**:
- [ ] Detect active window state (full-screen, exclusive full-screen, windowed, borderless windowed)
- [ ] For X11: Use `xdotool` or `wmctrl` to query window state
  - Check if window is full-screen
  - Check if window is maximized
  - Check if window is in exclusive full-screen mode (if detectable)
  - Get window title/application name if available
- [ ] For Wayland: Use `swaymsg` (if Sway/sway-based) or other Wayland tools if available
  - Note: Limited window state detection on Wayland/gamescope
  - Log that detection is limited on Wayland
- [ ] Log window state information when warning is triggered
- [ ] Include window state in log file entries (`~/.config/sleep-warning/warnings.log`)
- [ ] Add graceful fallback when window state detection tools unavailable
- [ ] Log window title/application name if available (for troubleshooting)

**Log Format**:
```
[YYYY-MM-DD HH:MM:SS] WARNING_TRIGGERED | Window State: <state> | Display: <X11/Wayland> | Dialog Tool: <tool> | Popup Success: <yes/no> | Window Title: <title>
```

**Window States to Detect**:
- `windowed` - Normal windowed mode
- `borderless_windowed` - Borderless windowed mode
- `fullscreen` - Full-screen (non-exclusive, compositor-managed)
- `exclusive_fullscreen` - Exclusive full-screen (bypasses compositor)
- `unknown` - Cannot determine (fallback when detection unavailable)
- `no_window` - No active window detected

**Log File Location**: `~/.config/sleep-warning/warnings.log`

For implementation checklists, see [plan-phase-1-setup-and-scripts.md](plans/phases/plan-phase-1-setup-and-scripts.md#checklist-14-implement-display-and-popup-functionality).

### Dialog Tool Selection

**Unified Priority Order** (all environments, including Gaming Mode):
1. **yad** (preferred): Better Wayland support, `--on-top` flag, native positioning, more reliable over full-screen
2. **zenity** (fallback): Standard GTK dialog, good compatibility, may have limitations in Gaming Mode
3. **kdialog** (last resort): Native KDE tool, provides KDE integration when needed

**Note**: The system now uses a unified priority (YAD → Zenity → KDialog) across all environments, including Gaming Mode and Desktop Mode. This ensures consistent behavior regardless of the environment.

**Implementation**:
- [x] Detect available dialog tools in unified priority order (YAD → Zenity → KDialog)
- [x] Prefer yad when available (best Wayland support and positioning)
- [x] Fall back to zenity if yad unavailable
- [x] Use kdialog as last resort if others unavailable
- [x] Log which tool is used for troubleshooting

For implementation checklists, see [plan-phase-1-setup-and-scripts.md](plans/phases/plan-phase-1-setup-and-scripts.md#checklist-14-implement-display-and-popup-functionality).

### Systemd Service Robustness

**Required Enhancements**:
- [ ] Ensure service starts in Gaming Mode (test after boot)
- [ ] Verify service persists across mode transitions
- [ ] Add service dependencies if needed (e.g., graphical-session.target)
- [ ] Test service status in both Desktop and Gaming Modes
- [ ] Document any Gaming Mode-specific service configuration

For testing requirements, see [plan-phase-4-testing.md](plans/phases/plan-phase-4-testing.md#phase-4-testing-and-validation).

## Effectiveness Assessment

### Effectiveness Breakdown by Scenario

#### High Effectiveness Scenarios (80-95% Success Rate)

##### 1. Systemd User Services
- **Expected Effectiveness**: ~95%
- **Why**: Systemd user services are well-supported in Gaming Mode
- **Implementation**: Services persist across Desktop Mode ↔ Gaming Mode transitions
- **Reliability**: Timer triggers every 10 minutes as expected
- **Status**: Should work reliably with minimal changes

##### 2. Display Detection (After Implementation)
- **Expected Effectiveness**: ~90%
- **Why**: Multiple fallback strategies ensure display detection
- **Implementation**: 
  - Detect `WAYLAND_DISPLAY` environment variable
  - Detect gamescope compositor
  - Use `loginctl` to find Wayland sessions
  - Query gamescope-specific display information
- **Reliability**: Multi-protocol detection (X11 → Wayland → fallbacks)
- **Status**: Requires implementation but should be highly reliable once done

##### 3. No Game Running / Desktop Mode
- **Expected Effectiveness**: ~95%
- **Why**: Works identically to Desktop Mode (X11 environment)
- **Implementation**: Full dialog functionality available, window manager tools work (X11)
- **Reliability**: Same as Desktop Mode experience with full window control capabilities
- **Status**: Should work perfectly

##### 3a. Full-Screen Games in Desktop Mode
- **Expected Effectiveness**: Variable (game-dependent)
- **Why**: Desktop Mode uses X11, enabling window manager tools and better dialog visibility
- **Implementation**: 
  - Window manager tools (`wmctrl`/`xdotool`) work in Desktop Mode (X11)
  - Dialog tools can appear over full-screen applications more reliably than in Gaming Mode
  - Some full-screen games may still block dialogs depending on their implementation
- **Reliability**: Moderate to high, highly game-dependent
- **Status**: ⚠️ Limited testing indicates popups work with some full-screen games in Desktop Mode, but results vary by game. Exclusive full-screen games may still block popups. No guarantees can be made for all games.

##### 4. Windowed Games
- **Expected Effectiveness**: ~85-90%
- **Why**: Dialog tools work reliably over windowed applications
- **Implementation**: 
  - Dialog tools (yad/kdialog/zenity) can appear over windowed games
  - Window manager can manage dialogs properly
- **Reliability**: High, with proper dialog tool selection
- **Status**: Should work well with planned changes

#### Moderate Effectiveness Scenarios (50-80% Success Rate)

##### 5. Borderless Windowed Games
- **Expected Effectiveness**: ~70-80%
- **Why**: Depends on game and compositor behavior
- **Implementation**: 
  - yad with `--on-top` flag improves reliability
  - Some games may still block dialogs
- **Reliability**: Moderate, game-dependent
- **Status**: Works in most cases but not guaranteed

##### 6. Full-Screen Games (Non-Exclusive)
- **Expected Effectiveness**: ~50-70%
- **Why**: Variable behavior depending on game implementation
- **Implementation**: 
  - Some games allow compositor overlays
  - Others may block or partially block dialogs
- **Reliability**: Moderate, highly game-dependent
- **Status**: Unpredictable, requires testing per game

#### Low Effectiveness Scenarios (20-50% Success Rate)

##### 7. Exclusive Full-Screen Games
- **Expected Effectiveness**: ~20-40%
- **Why**: Games bypass compositor entirely
- **Implementation**: 
  - Dialog tools cannot appear over exclusive full-screen
  - Compositor has no control over exclusive full-screen applications
- **Reliability**: Low, fundamental limitation
- **Status**: Major limitation, requires Steam Overlay integration for solution

##### 8. Minimum Display Time Enforcement
- **Expected Effectiveness**: ~30% (Informational Only)
- **Why**: Window manager tools don't work on Wayland/gamescope
- **Implementation**: 
  - `wmctrl`/`xdotool` only work on X11, not Wayland
  - Countdown message still shown, but no window control
  - Cannot prevent closing/minimizing in Gaming Mode
- **Reliability**: Low enforcement, high informational value
- **Status**: Limited functionality in Gaming Mode

### Overall Effectiveness Summary

| Scenario | Current State | With Planned Changes | With Steam Overlay |
|----------|---------------|---------------------|-------------------|
| No game running | ~60% | **~95%** | ~95% |
| Windowed games | ~40% | **~85%** | ~95% |
| Borderless windowed | ~30% | **~75%** | ~95% |
| Full-screen (non-exclusive) | ~20% | **~60%** | ~95% |
| Exclusive full-screen | ~10% | **~30%** | **~95%** |
| **Overall Average** | **~32%** | **~68%** | **~95%** |

### Key Improvements with Planned Changes

1. **Display Detection**: From ~60% to ~90% effectiveness
   - Wayland/gamescope detection implemented
   - Multiple fallback strategies

2. **Dialog Tool Selection**: From basic to intelligent selection
   - Environment-aware tool selection (yad > kdialog > zenity)
   - Better compatibility with Gaming Mode

3. **Service Reliability**: From ~70% to ~95% effectiveness
   - Services persist across mode transitions
   - Automatic start in Gaming Mode

4. **Windowed/Borderless Games**: From ~35% to ~80% effectiveness
   - Significant improvement for most common scenarios

5. **Full-Screen Games**: From ~15% to ~45% effectiveness
   - Partial improvement, but still limited by exclusive full-screen

### What the Planned Changes Achieve

#### ✅ High Success Areas

1. **Display Detection**: Fully functional in Gaming Mode
   - Wayland/gamescope detection works
   - Multiple fallback strategies ensure reliability

2. **Dialog Tool Selection**: Intelligent tool choice
   - Prefers yad for Gaming Mode (better Wayland support)
   - Falls back to kdialog for KDE systems
   - Uses zenity as last resort

3. **Service Reliability**: Robust systemd integration
   - Services persist across Desktop ↔ Gaming Mode transitions
   - Automatic start when booting into Gaming Mode
   - Timer continues working reliably

4. **Windowed/Borderless Games**: Good coverage
   - Most windowed games: ~85-90% success
   - Borderless windowed: ~70-80% success

5. **Desktop Mode**: Full functionality
   - Works identically to standard desktop environments
   - Uses X11, so window manager tools (`wmctrl`/`xdotool`) work
   - Full window control features available (immovable windows, prevent closing, etc.)
   - **Full-Screen Games**: Limited testing indicates popups work with some full-screen games in Desktop Mode, but results vary by game. Exclusive full-screen games may still block popups. No guarantees can be made for all games.

#### ⚠️ Partial Success Areas

1. **Full-Screen Games (Non-Exclusive)**: Variable success
   - Some games: ~60-70% success
   - Others: ~40-50% success
   - Highly game-dependent

2. **Minimum Display Time**: Limited enforcement
   - Countdown message shown (informational)
   - No window control on Wayland
   - ~30% effectiveness (informational value only)

#### ❌ Remaining Limitations

1. **Exclusive Full-Screen Games**: Major limitation
   - Only ~30% effectiveness with planned changes
   - Games bypass compositor entirely
   - Dialog tools cannot appear
   - **Solution**: Requires Steam Overlay integration (see [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md))

2. **Window Management**: Wayland limitation
   - Window manager tools don't work on Wayland/gamescope
   - Cannot force windows on top
   - Cannot prevent closing/minimizing
   - **Workaround**: Informational countdown only

3. **On-Screen Keyboard**: zenity limitation
   - zenity dialogs may not receive input from Steam Deck keyboard
   - **Mitigation**: Prefer yad/kdialog which handle this better

4. **Dialog Visibility**: Game-dependent
   - Varies by game type, rendering technology, full-screen mode
   - Requires extensive testing per game
   - **Documentation**: Document known working/not-working scenarios

## Path to Maximum Effectiveness

### Phase 1: Planned Complementary Changes (Target: ~68% Overall Effectiveness)

**Implementation Required**:
- [ ] Enhanced Display Detection (Wayland/gamescope)
- [ ] Dialog Tool Priority System (environment-aware)
- [ ] Systemd Service Robustness (mode transition handling)
- [ ] Desktop Notification Fallback (notify-send)

**Expected Results**:
- ✅ No game running: ~95% effectiveness
- ✅ Windowed games: ~85% effectiveness
- ✅ Borderless windowed: ~75% effectiveness
- ⚠️ Full-screen (non-exclusive): ~60% effectiveness
- ❌ Exclusive full-screen: ~30% effectiveness

**Effort**: Medium (can be done incrementally)
**Timeline**: Can be implemented alongside current development
**Compatibility**: Maintains backward compatibility

For implementation checklists, see [linux-warning-system-plan.md](plans/master/linux-warning-system-plan.md) and the phase plans linked from it.

### Phase 2: Steam Overlay Integration (Target: ~95% Overall Effectiveness)

**Implementation Required**:
- [ ] C/C++ plugin using Steamworks SDK
- [ ] Steam Overlay notification system
- [ ] Integration with existing systemd service
- [ ] Testing with various game types

**Expected Results**:
- ✅ No game running: ~95% effectiveness
- ✅ Windowed games: ~95% effectiveness
- ✅ Borderless windowed: ~95% effectiveness
- ✅ Full-screen (non-exclusive): ~95% effectiveness
- ✅ **Exclusive full-screen: ~95% effectiveness** (major improvement)

**Effort**: High (requires different technology stack)
**Timeline**: Separate development phase
**Compatibility**: Works alongside current system (complementary)

**Advantages**:
- Guaranteed to work over full-screen games
- Native Steam integration
- Better user experience for Steam users
- Solves exclusive full-screen limitation

**Disadvantages**:
- Only works with Steam games
- Requires Steam to be running
- Significant development effort
- Different technology stack (C/C++ vs bash)

For details, see [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md#1-steam-overlay-integration).

## Known Limitations

### 1. Exclusive Full-Screen Games
May block dialog popups entirely
- **Workaround**: Use borderless windowed mode in games
- **Future Solution**: Steam Overlay integration (see [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md))
- **Logging**: Window state detection will log when exclusive full-screen is detected to help diagnose issues

### 2. On-Screen Keyboard
zenity dialogs may not receive input from Steam Deck keyboard overlay
- **Reference**: https://github.com/ValveSoftware/SteamOS/issues/1039
- **Workaround**: Use yad or kdialog if available
- **Future Solution**: Steam Overlay integration
- **Logging**: Dialog tool used is logged to help identify when zenity issues occur

### 3. Window Manager Tools
wmctrl/xdotool don't work on Wayland/gamescope
- **Impact**: Minimum display time feature has limited enforcement in Gaming Mode
- **Impact**: Window state detection is limited on Wayland/gamescope
- **Workaround**: Countdown message still shown, but window control unavailable
- **Logging**: Logs will indicate when window state detection is unavailable (Wayland limitation)

### 4. Dialog Visibility
May vary by game type, rendering technology, and full-screen mode
- **Testing Required**: Extensive testing with different games and configurations
- **Documentation**: Document known working/not-working scenarios
- **Logging**: Window state and popup success/failure are logged to help identify patterns

## Compatibility Status

**Current Status**: ⚠️ **Partially Compatible - Requires Testing**

- ✅ Systemd user services: Should work (needs verification)
- ⚠️ Display detection: Needs Wayland/gamescope support (implementation required)
- ⚠️ Dialog popups: May work but needs extensive testing
- ❌ Window manager tools: Not compatible (Wayland limitation)
- ⚠️ Full-screen games: Unknown compatibility (critical testing required)

**Target Status**: ✅ **Fully Compatible** (after implementation and testing)

## Testing Requirements

See [plan-phase-4-testing.md](plans/phases/plan-phase-4-testing.md#phase-4-testing-and-validation) for comprehensive SteamOS Gaming Mode testing checklists. Key test scenarios include:

### Critical Test Scenarios

1. **Systemd Services**:
   - [ ] Service starts in Gaming Mode
   - [ ] Service persists across mode transitions
   - [ ] Timer triggers correctly

2. **Display Detection**:
   - [ ] Wayland display detected
   - [ ] gamescope compositor detected
   - [ ] Fallback strategies work

3. **Dialog Appearance**:
   - [ ] No game running
   - [ ] Windowed games
   - [ ] Borderless windowed games
   - [ ] Full-screen (non-exclusive) games
   - [ ] Exclusive full-screen games

4. **Game Types**:
   - [ ] Steam native games
   - [ ] Proton games
   - [ ] Non-Steam games
   - [ ] Different rendering technologies (Vulkan, DirectX)

5. **Performance**:
   - [ ] No performance impact during gameplay
   - [ ] No frame drops or stuttering
   - [ ] Handles high CPU/GPU load

For detailed testing checklists, see [plan-phase-4-testing.md](plans/phases/plan-phase-4-testing.md#checklist-41-functional-testing).

## Technical Constraints

### Fundamental Limitations

1. **Wayland Compositor Limitations**:
   - Window manager tools (wmctrl/xdotool) don't work
   - Limited window control capabilities
   - Compositor-level dialogs may be blocked by exclusive full-screen

2. **Exclusive Full-Screen Games**:
   - Bypass compositor entirely
   - No way for external dialogs to appear
   - Requires application-level integration (Steam Overlay)

3. **On-Screen Keyboard**:
   - zenity has known issues with Steam Deck keyboard overlay
   - Mitigated by using yad/kdialog instead

### Solvable Limitations

1. **Display Detection**: Solvable with Wayland/gamescope detection
2. **Dialog Tool Selection**: Solvable with intelligent tool selection
3. **Service Persistence**: Solvable with proper systemd configuration
4. **Full-Screen Games**: Solvable with Steam Overlay integration

## Recommendations

### Short-Term Strategy (Immediate Implementation)

**Goal**: Achieve ~68% overall effectiveness

1. **Implement Planned Complementary Changes**:
   - Enhanced display detection (Wayland/gamescope)
   - Dialog tool priority system
   - Systemd service robustness
   - Desktop notification fallback

2. **Benefits**:
   - Works for most common scenarios (no game, windowed, borderless)
   - Significant improvement over current state
   - Maintains backward compatibility
   - Can be implemented incrementally

3. **Limitations Accepted**:
   - Exclusive full-screen games remain problematic
   - Minimum display time enforcement limited

### Long-Term Strategy (Future Enhancement)

**Goal**: Achieve ~95% overall effectiveness

1. **Develop Steam Overlay Integration**:
   - C/C++ plugin using Steamworks SDK
   - Native Steam overlay notifications
   - Integration with existing system

2. **Benefits**:
   - Solves exclusive full-screen game limitation
   - Works with all Steam games
   - Better user experience
   - Maximum compatibility

3. **Considerations**:
   - Significant development effort required
   - Different technology stack
   - Only works with Steam games
   - Can be developed alongside current system

For implementation details, see [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md).

## Conclusion

With the planned complementary changes, the Sleep Warning System can achieve **approximately 68% overall effectiveness** in SteamOS Gaming Mode. This represents a significant improvement over the current ~32% effectiveness and covers most common usage scenarios:

- ✅ **Excellent** for no game, windowed, and borderless windowed scenarios
- ⚠️ **Moderate** for full-screen (non-exclusive) games
- ❌ **Limited** for exclusive full-screen games

The remaining gap (exclusive full-screen games) can be addressed through Steam Overlay integration, which would bring overall effectiveness to approximately **95%**. However, this requires significant additional development effort using a different technology stack.

**Recommendation**: Implement the planned complementary changes first to achieve good coverage for most scenarios, then evaluate Steam Overlay integration as a future enhancement based on user needs and development resources.
