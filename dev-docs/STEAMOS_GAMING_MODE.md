# SteamOS Gaming Mode Compatibility and Effectiveness

This document provides comprehensive information about SteamOS Gaming Mode compatibility, including challenges, implementation strategies, effectiveness assessment, and testing requirements. For the master plan and detailed checklists, see [linux-warning-system-plan.md](plans/master/linux-warning-system-plan.md) and the [phase plans](plans/phases/) linked from it.

## Overview

For a bounded read-only check on actual hardware, run
`bash scripts/check-steam-deck-gaming-mode.sh`. See the
[first-check guide and agent prompt](development/steam-deck-first-check.md)
for a supervised fullscreen/controller test with isolated state.

SteamOS Gaming Mode presents unique challenges for systemd-based warning systems due to its use of the gamescope Wayland compositor, focus on full-screen gaming experiences, and different environment setup compared to traditional desktop environments. This document outlines the compatibility considerations, implementation strategies, testing requirements, and effectiveness assessment specific to SteamOS Gaming Mode.

## Executive Summary

**Key Takeaway**: SteamOS Gaming Mode (`gamescope`) does not composite standard X11/Wayland dialog windows above fullscreen games unless they are rendered on the primary Xwayland overlay display (`:0`) and tagged with `gamescope`'s `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` X11 window properties.

**Current Status**: ⚙️ **Experimental Overlay Implemented (Opt-In via `GAMING_MODE_EXPERIMENTAL_ENABLED`)**

The 2026-10-20 hardware click verification covers **zenity**. Yad still needs
equivalent hardware validation. Kdialog's message boxes do not receive the
full-width size override and can remain non-interactive notifications under
gamescope; use zenity for the verified path. This is a limitation of the
experimental tool coverage, not evidence that all three tools were verified.

### How the Experimental `gamescope` Overlay Works

1. **Settings Toggle (`GAMING_MODE_EXPERIMENTAL_ENABLED`)**:
   - Controlled via `sleep-warning-configure` → **Option 12: Service Mode Configuration** or in `~/.config/sleep-warning/config/sleep-warning.conf` (`GAMING_MODE_EXPERIMENTAL_ENABLED=true|false`, default `false`).
   - During lock hours the toggle can be turned on or off. It is display routing, not a restriction-strength setting, so a broken overlay can be disabled without waiting for the lock window to end.
   - When disabled (`false`), `is_gaming_mode_enabled()` returns false and `detect_display_environment()` treats the session as standard `x11`/`wayland` even if `gamescope` is running.
   - `detect_system_mode()` is separate. It still reports `gaming` when gamescope is the session so install and Option 12 can write the matching service drop-in. That classification does not turn the overlay on.
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

The percentage tables and “planned changes” sections later in this document are historical planning estimates from before the experimental overlay. They are not measurements. Current behavior is the opt-in path above. Desktop Mode is supported. Gaming Mode remains experimental. A Steam Deck check on 2026-10-19 showed the popup over a fullscreen game, and a 2026-10-20 check showed click and Enter reaching the dialog without Enter also firing into Steam. Still unchecked: pause-enabled buttons and the pause notice, countdown input, touch, the Quick Access Menu after the popup closes, a forced timeout, and docked versus undocked.

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
- User services in Gaming Mode use `mode-gaming.conf` (`DISPLAY=:0` and `WAYLAND_DISPLAY`). The unit does not set `GAMESCOPE_SESSION`
- Services persist across Desktop Mode ↔ Gaming Mode transitions
- Services start automatically when booting directly into Gaming Mode

### 3. GUI Dialog Compatibility
- Without `STEAM_OVERLAY=1`, `zenity`/`yad`/`kdialog` do not appear over fullscreen games in `gamescope`
- Without `STEAM_INPUT_FOCUS=1`, dialogs cannot receive Steam Deck controller (`A`/`B`/touch) input
- Classic EWMH window manager tools (`wmctrl`/`xdotool`) are not installed by default on SteamOS and do not manage `gamescope` overlay stacking
- Fallback: if the dialog cannot be spawned, or gamescope has no accessible Xwayland display, a non-modal notification (`notify-send`) is attempted and logged. The fallback counts only when `notify-send` accepts the message. Gaming Mode often has no notification daemon, so this can fail and is then logged as a hard failure. When `xdpyinfo` and `xset` are both missing, accessibility is the X socket for that display (`:0` is `/tmp/.X11-unix/X0`, `:1` is `/tmp/.X11-unix/X1`). A missing socket is unanswered.

### 4. Performance Considerations
- Timer checks should not impact game performance
- Dialog display should not cause frame drops or stuttering
- System should handle high CPU/GPU load scenarios gracefully

## Implementation Strategies

### Display Detection Enhancements

**Implemented**:
- [x] Detect `$WAYLAND_DISPLAY` environment variable and `gamescope-*` sockets
- [x] Detect the gamescope session (`XDG_CURRENT_DESKTOP` contains `gamescope`, or `pgrep -x gamescope` when that variable is unset), gated by `is_gaming_mode_enabled()`. `GAMESCOPE_SESSION` is not consulted.
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

### Phase 1: Complementary Changes (historical ~68% estimate)

**In the repo now** (device verification still open):
- [x] Gamescope display detection, gated by `GAMING_MODE_EXPERIMENTAL_ENABLED`
- [x] Dialog tool priority (yad, then zenity, then kdialog) with an X11 backend on the gamescope path
- [x] `mode-gaming.conf` service drop-in (`DISPLAY=:0`, `WAYLAND_DISPLAY`)
- [x] Desktop notification fallback (`notify-send`) when GUI dialogs fail

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

**Current Status**: ⚙️ **Experimental overlay implemented, off by default; partial Steam Deck verification 2026-10-19**

- ✅ Opt-in flag `GAMING_MODE_EXPERIMENTAL_ENABLED` (default `false`; a leftover `mode-gaming.conf` does not turn it on)
- ✅ Display detection returns `gamescope` only when that flag is on and the session is actually gamescope (`XDG_CURRENT_DESKTOP` contains `gamescope`, or the `gamescope` process is running)
- ✅ Dialogs on that path use Xwayland with `GDK_BACKEND=x11` / `QT_QPA_PLATFORM=xcb`, `STEAM_OVERLAY=1`, and `STEAM_INPUT_FOCUS=1`
- ✅ Popups still end: `GAMESCOPE_FORCE_AUTO_CLOSE` plus the absolute watchdog
- ✅ On-device appearance over fullscreen games verified (2026-10-19)
- ✅ Full `:0` root width + top-left / ≥⅔ height; Deck click verified 2026-10-20
- ❌ `wmctrl` / `xdotool` do not manage gamescope stacking

**Target Status**: ✅ **Verified on SteamOS Gaming Mode** (still open)

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

Experimental Gaming Mode overlay support is implemented and **off by default**. It routes warning dialogs through gamescope's Xwayland `:0` plane and tags them with `STEAM_OVERLAY` / `STEAM_INPUT_FOCUS`. That path is covered by unit tests.

**On-device (2026-10-19):** With the experimental toggle on in Gaming Mode, the warning **appeared and stayed visible** over a fullscreen game, but **buttons were not clickable** (notification classification) and a **small** dialog looked **heavily magnified** (per-window fit scaling). **Code fix (same day):** gamescope-only dialogs now request **full `:0` root width** + modest height, keep `STEAM_OVERLAY` / `STEAM_INPUT_FOCUS=1`, and log geometry/atom read-back.

**On-device (2026-10-20):** After Stream F (top-left + ≥⅔ root height, zenity moved with `xdotool`), cursor reaches the dialog chrome and **click works** (user confirmed). Enter dismisses the dialog and did **not** appear to fire into Steam. Do not turn off forced auto-close or the popup watchdog. Plan: [plans/plan-gamescope-overlay-click-through-2026-10-19.md](plans/plan-gamescope-overlay-click-through-2026-10-19.md).

**Code (2026-10-20, Stream F):** gamescope warning dialogs, countdown respawns, and the pause notice are forced to **top-left** with a height of at least two thirds of the `:0` root (capped at the root; still full root width). gamescope 3.16.23 paints the overlay centered and fit-scaled, but draws the cursor offset by the window's X11 position, so the window must sit at 0,0. zenity is moved after map with `xdotool windowmove` (preferred over `wmctrl` under gamescope). Desktop Mode unchanged. `STEAM_OVERLAY=1` / `STEAM_INPUT_FOCUS=1`, forced auto-close, and the watchdog unchanged.

### Warning buttons (zenity vs Desktop) — Stream G

Gaming Mode and Desktop Mode may pick different dialog tools (`DIALOG_TOOL=auto` prefers yad → zenity → kdialog; PATH and which packages are installed still matter). **Button labels follow the tool**, not gamescope:

| Tool | Pause available | Buttons |
|------|-----------------|---------|
| zenity `--warning` | yes | OK + extra “Pause N min”. **No Cancel** |
| zenity `--warning` | no | **OK only** (window close is exit 1, not a Cancel button) |
| yad | yes | Explicit Pause + OK (replaces yad defaults) |
| yad | no | Default **OK and Cancel** (Cancel exits 252, treated as dismiss) |
| kdialog | yes | Yes = Pause, No = **Dismiss** (not the word Cancel) |
| kdialog | no | OK (`--sorry`) |

Deck captures often used **zenity** in Gaming Mode, so the popup showed OK only when pause was unavailable — that is expected, not a missing Cancel bug. Do **not** invent a Cancel button for zenity. To match Desktop chrome more closely, install/prefer **yad** or set `DIALOG_TOOL=yad` (still subject to gamescope geometry/overlay rules).

### Debug logging (`GAMESCOPE_OVERLAY_DEBUG`)

Default **off**. When it is on, each gamescope warning spawn, countdown respawn, and pause notice writes one `DEBUG-GAMESCOPE` block to the warning log (root size, requested vs override size, tool, pause/button flags, window id, atom read-back, focus displays, and an overlay census). It does not change geometry, atoms, buttons, auto-close, or the watchdog. The 2-second atom refresh does not write another block.

Turn it on for one capture, then turn it off. Do not edit `sleep-warning.conf` during restricted or blocked hours.

Preferred: a separate drop-in, not `mode-gaming.conf` (configure rewrites that file):

```bash
mkdir -p ~/.config/systemd/user/sleep-warning.service.d
cat > ~/.config/systemd/user/sleep-warning.service.d/gamescope-overlay-debug.conf <<'EOF'
[Service]
Environment=GAMESCOPE_OVERLAY_DEBUG=true
EOF
systemctl --user daemon-reload
```

One session: `systemctl --user set-environment GAMESCOPE_OVERLAY_DEBUG=true`. The timer's next oneshot start inherits it. Undo with `systemctl --user unset-environment GAMESCOPE_OVERLAY_DEBUG`. That variable is on the whole user manager until logout, not only sleep-warning. A shell `export` does not reach the service.

Turn it off: delete `gamescope-overlay-debug.conf` and run `systemctl --user daemon-reload`. `uninstall.sh` removes the service and timer units only, not `sleep-warning.service.d/`. An orphaned drop-in does nothing without the unit, but a later reinstall would turn debug back on until that file is deleted.

If the key is already in `sleep-warning.conf`, the next configure save keeps the file value (`true` or `false`) and does not copy a temporary environment override into the file. If the key is absent, the save leaves it absent. There is no wizard prompt for this key. Either value is allowed during lock hours; it is not a restriction setting.

`GAMESCOPE_FOCUSED_WINDOW` staying on the game while a game is running is expected. Focus-display values are display names such as `:0` and `:1`, stored as CARDINAL items; the log includes the raw value and a decoded string. The census records which way `xwininfo` children were interpreted (`children_order=assumed_top_first`). Calibrate that once on device: when Enter reaches the dialog, our window should sit at the top of the stack.

The ~68% and ~95% figures earlier in this document were planning estimates, not measured results. A Steamworks overlay plugin remains a possible later approach for exclusive fullscreen games. Use Option 12 to turn the experimental path on, and turn it off again if dialogs do not appear. `systemctl --user stop sleep-warning.service` remains available during lock hours.
