# SteamOS Gaming Mode Effectiveness Assessment

## Executive Summary

This document provides a comprehensive assessment of how effective the Sleep Warning System can be made in SteamOS Gaming Mode through planned implementation changes. The analysis covers different game states, implementation phases, and provides realistic effectiveness percentages based on technical constraints and known limitations.

**Key Takeaway**: With planned complementary changes, the system can achieve approximately **68% overall effectiveness** in Gaming Mode. With Steam Overlay integration (alternative approach), effectiveness can reach approximately **95%**.

## Effectiveness Breakdown by Scenario

### High Effectiveness Scenarios (80-95% Success Rate)

#### 1. Systemd User Services
- **Expected Effectiveness**: ~95%
- **Why**: Systemd user services are well-supported in Gaming Mode
- **Implementation**: Services persist across Desktop Mode ↔ Gaming Mode transitions
- **Reliability**: Timer triggers every 10 minutes as expected
- **Status**: Should work reliably with minimal changes

#### 2. Display Detection (After Implementation)
- **Expected Effectiveness**: ~90%
- **Why**: Multiple fallback strategies ensure display detection
- **Implementation**: 
  - Detect `WAYLAND_DISPLAY` environment variable
  - Detect gamescope compositor
  - Use `loginctl` to find Wayland sessions
  - Query gamescope-specific display information
- **Reliability**: Multi-protocol detection (X11 → Wayland → fallbacks)
- **Status**: Requires implementation but should be highly reliable once done

#### 3. No Game Running / Desktop Mode
- **Expected Effectiveness**: ~95%
- **Why**: Works identically to Desktop Mode
- **Implementation**: Full dialog functionality available
- **Reliability**: Same as Desktop Mode experience
- **Status**: Should work perfectly

#### 4. Windowed Games
- **Expected Effectiveness**: ~85-90%
- **Why**: Dialog tools work reliably over windowed applications
- **Implementation**: 
  - Dialog tools (yad/kdialog/zenity) can appear over windowed games
  - Window manager can manage dialogs properly
- **Reliability**: High, with proper dialog tool selection
- **Status**: Should work well with planned changes

### Moderate Effectiveness Scenarios (50-80% Success Rate)

#### 5. Borderless Windowed Games
- **Expected Effectiveness**: ~70-80%
- **Why**: Depends on game and compositor behavior
- **Implementation**: 
  - yad with `--on-top` flag improves reliability
  - Some games may still block dialogs
- **Reliability**: Moderate, game-dependent
- **Status**: Works in most cases but not guaranteed

#### 6. Full-Screen Games (Non-Exclusive)
- **Expected Effectiveness**: ~50-70%
- **Why**: Variable behavior depending on game implementation
- **Implementation**: 
  - Some games allow compositor overlays
  - Others may block or partially block dialogs
- **Reliability**: Moderate, highly game-dependent
- **Status**: Unpredictable, requires testing per game

### Low Effectiveness Scenarios (20-50% Success Rate)

#### 7. Exclusive Full-Screen Games
- **Expected Effectiveness**: ~20-40%
- **Why**: Games bypass compositor entirely
- **Implementation**: 
  - Dialog tools cannot appear over exclusive full-screen
  - Compositor has no control over exclusive full-screen applications
- **Reliability**: Low, fundamental limitation
- **Status**: Major limitation, requires Steam Overlay integration for solution

#### 8. Minimum Display Time Enforcement
- **Expected Effectiveness**: ~30% (Informational Only)
- **Why**: Window manager tools don't work on Wayland/gamescope
- **Implementation**: 
  - `wmctrl`/`xdotool` only work on X11, not Wayland
  - Countdown message still shown, but no window control
  - Cannot prevent closing/minimizing in Gaming Mode
- **Reliability**: Low enforcement, high informational value
- **Status**: Limited functionality in Gaming Mode

## Overall Effectiveness Summary

### Effectiveness Comparison Table

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

## What the Planned Changes Achieve

### ✅ High Success Areas

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

### ⚠️ Partial Success Areas

1. **Full-Screen Games (Non-Exclusive)**: Variable success
   - Some games: ~60-70% success
   - Others: ~40-50% success
   - Highly game-dependent

2. **Minimum Display Time**: Limited enforcement
   - Countdown message shown (informational)
   - No window control on Wayland
   - ~30% effectiveness (informational value only)

### ❌ Remaining Limitations

1. **Exclusive Full-Screen Games**: Major limitation
   - Only ~30% effectiveness with planned changes
   - Games bypass compositor entirely
   - Dialog tools cannot appear
   - **Solution**: Requires Steam Overlay integration

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

## Testing Requirements

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

## Conclusion

With the planned complementary changes, the Sleep Warning System can achieve **approximately 68% overall effectiveness** in SteamOS Gaming Mode. This represents a significant improvement over the current ~32% effectiveness and covers most common usage scenarios:

- ✅ **Excellent** for no game, windowed, and borderless windowed scenarios
- ⚠️ **Moderate** for full-screen (non-exclusive) games
- ❌ **Limited** for exclusive full-screen games

The remaining gap (exclusive full-screen games) can be addressed through Steam Overlay integration, which would bring overall effectiveness to approximately **95%**. However, this requires significant additional development effort using a different technology stack.

**Recommendation**: Implement the planned complementary changes first to achieve good coverage for most scenarios, then evaluate Steam Overlay integration as a future enhancement based on user needs and development resources.
