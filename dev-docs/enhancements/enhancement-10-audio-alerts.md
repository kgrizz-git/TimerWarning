# Enhancement 10: Audio Alerts

- **Description**: Add optional audio notification (beep, sound file) alongside visual popup
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `lib/popup-display.sh`, `lib/config.sh`, `lib/configure-config.sh`, `lib/configure-display.sh`, `lib/configure-ui.sh`, `configure.sh`
- **Priority**: Low (enhancement feature)
- **Status**: Not implemented
- **Feasibility Assessment**: ✅ **Highly Feasible** - Multiple audio tools available, well-supported across distributions

---

## Audio Tools Overview

For detailed information about available audio tools, their capabilities, distribution availability, and implementation details, see:
- **[Audio Tools Options](../info/audio-tools-options.md)** - Comprehensive guide to Linux audio playback tools

### Quick Summary

**Recommended Tool Priority** (auto-detection):
1. `paplay` (PulseAudio) - Most common, best user experience
2. `pw-play` (PipeWire) - Modern systems
3. `aplay` (ALSA) - Always available fallback
4. `canberra-gtk-play` - Desktop environments
5. `beep` - Last resort
6. Terminal bell (`\a`) - Final fallback

**Systemd Service Context**: Audio works in systemd user services, with fallback to ALSA if PulseAudio/PipeWire unavailable. See [Audio Tools Options](../info/audio-tools-options.md#systemd-service-environment-considerations) for details.

---

## Implementation Recommendations

### Configuration Options

#### 1. Enable/Disable Audio Alerts
- **Config Option**: `AUDIO_ALERT_ENABLED=true/false`
- **Default**: `false` (opt-in feature)
- **User Control**: Add to configuration menu in `configure.sh`

#### 2. Audio Tool Selection
- **Config Option**: `AUDIO_ALERT_TOOL=auto|paplay|pw-play|aplay|canberra-gtk-play|beep`
- **Default**: `auto` (auto-detect best available tool)
- **User Control**: Advanced option, can be set manually in config file
- **Auto-Detection Priority**: 
  1. `paplay` (PulseAudio) - if available
  2. `pw-play` (PipeWire) - if available
  3. `aplay` (ALSA) - always available as fallback
  4. `canberra-gtk-play` - if available (desktop environments)
  5. `beep` - last resort

#### 3. Sound File Path
- **Config Option**: `AUDIO_ALERT_SOUND=/path/to/sound.wav`
- **Default**: System-provided beep or built-in tone
- **User Control**: Allow users to specify custom sound file
- **Supported Formats**: WAV (universal), OGG/MP3 (if tool supports)

#### 4. Volume Level
- **Config Option**: `AUDIO_ALERT_VOLUME=0.0-1.0` (normalized) or tool-specific
- **Default**: `0.8` (80%)
- **User Control**: Volume slider in configuration menu
- **Implementation**: Convert to tool-specific volume (e.g., PulseAudio uses 0-65536)

#### 5. Audio Alert Type
- **Config Option**: `AUDIO_ALERT_TYPE=file|beep|system`
- **Default**: `beep` (simple beep, no file required)
- **Options**:
  - `file`: Play custom sound file
  - `beep`: Simple beep tone (uses `speaker-test` or terminal bell)
  - `system`: Use system sound theme (via `canberra-gtk-play`)

---

## Implementation Plan

### Phase 1: Basic Audio Alert (Beep Only)
1. Add `AUDIO_ALERT_ENABLED` configuration option
2. Implement simple beep using available tool
3. Add to configuration menu
4. Test in systemd service environment

---

## Phase 1: Implementation Checklist

### Overview
Implement basic audio alert functionality with simple beep support. Audio alerts are opt-in (default: disabled) and supplement visual popups. This phase focuses on getting basic beep functionality working with automatic tool detection and graceful fallbacks.

### Files to Modify

#### Core Files
- `lib/config.sh` - Add function to read AUDIO_ALERT_ENABLED
- `lib/configure-config.sh` - Load and save AUDIO_ALERT_ENABLED
- `lib/configure-display.sh` - Add menu option for audio alerts
- `lib/configure-ui.sh` - Add dialog function for audio alert setting
- `lib/popup-display.sh` - Integrate audio alert playback
- `configure.sh` - Add menu handler for audio alert configuration
- `sleep-warning.conf` - Add AUDIO_ALERT_ENABLED documentation

#### New Module
- `lib/audio-alert.sh` - Audio alert detection and playback module (Phase 1: basic beep only)

#### Documentation
- `dev-docs/enhancements/enhancement-10-audio-alerts.md` - Update status when complete

---

### 1. Configuration File Support

#### 1.1 Add AUDIO_ALERT_ENABLED to config.sh
- [ ] Add default value constant: `DEFAULT_AUDIO_ALERT_ENABLED=false`
- [ ] Add function `get_audio_alert_enabled()` in `lib/config.sh`
  - [ ] Read `AUDIO_ALERT_ENABLED` from config file
  - [ ] Validate value (true/false/1/0/yes/no)
  - [ ] Return default if missing or invalid
  - [ ] Normalize output to "true" or "false" string

#### 1.2 Update configure-config.sh
- [ ] Add `audio_alert_enabled` to global variables in `load_existing_config()`
  - [ ] Initialize with default: `declare -g audio_alert_enabled="false"`
  - [ ] Read existing value from config file (if present)
  - [ ] Validate and normalize to "true" or "false"
- [ ] Update `write_config()` function signature
  - [ ] Add `audio_alert_enabled` as parameter (7th parameter, after `config_lock_enabled`)
  - [ ] Write `AUDIO_ALERT_ENABLED=${audio_alert_enabled}` to config file
  - [ ] Add comment header explaining the option
  - [ ] Place after `CONFIG_LOCK_ENABLED` section in config file

#### 1.3 Update configure.sh main function
- [ ] Add `audio_alert_enabled` to global variable declarations
  - [ ] Add to: `declare -g check_interval popup_size popup_position min_display_time popup_immovable config_lock_enabled audio_alert_enabled`
- [ ] Update `write_config()` call
  - [ ] Add `${audio_alert_enabled}` as 7th argument

#### 1.4 Update config file template
- [ ] Add `AUDIO_ALERT_ENABLED` section to `sleep-warning.conf` template
  - [ ] Add comment explaining the feature
  - [ ] Add default value: `AUDIO_ALERT_ENABLED=false`
  - [ ] Place after `CONFIG_LOCK_ENABLED` section

---

### 2. Audio Alert Module Creation

#### 2.1 Create lib/audio-alert.sh module
- [ ] Create new file `lib/audio-alert.sh`
- [ ] Add module header with description and dependencies
- [ ] Document that this module handles audio alert detection and playback

#### 2.2 Implement audio tool detection function
- [ ] Create `detect_audio_tool()` function
  - [ ] Try `paplay` first (PulseAudio) - most common
  - [ ] Try `pw-play` second (PipeWire) - modern systems
  - [ ] Try `aplay` third (ALSA) - always available fallback
  - [ ] Try `canberra-gtk-play` fourth (desktop environments)
  - [ ] Try `beep` fifth (last resort)
  - [ ] Return "bell" if no tools available (terminal bell)
  - [ ] Return tool name as string
  - [ ] Log detected tool for debugging

#### 2.3 Implement basic beep playback function
- [ ] Create `play_audio_beep()` function
  - [ ] Check if audio alerts enabled (use `get_audio_alert_enabled()`)
  - [ ] Return early if disabled
  - [ ] Call `detect_audio_tool()` to get available tool
  - [ ] Implement playback for each tool:
    - [ ] `paplay`: Play system bell sound (`/usr/share/sounds/freedesktop/stereo/bell.oga`) or generate tone
    - [ ] `pw-play`: Play system bell sound or generate tone
    - [ ] `aplay`: Use `speaker-test` to generate 1kHz tone (1 second)
    - [ ] `canberra-gtk-play`: Play system bell (`--id=bell`)
    - [ ] `beep`: Call `beep` command
    - [ ] `bell`: Output terminal bell (`echo -e "\a"`)
  - [ ] Run audio commands in background (`&`) to avoid blocking
  - [ ] Suppress stderr (`2>/dev/null`) for graceful failure
  - [ ] Log audio playback attempts (success/failure)

#### 2.4 Add error handling
- [ ] Handle missing audio tools gracefully (no errors, just silent)
- [ ] Handle audio daemon not running (PulseAudio/PipeWire)
- [ ] Handle no audio hardware available
- [ ] Ensure function never fails (always returns 0)
- [ ] Log warnings only, not errors (audio is optional feature)

---

### 3. Integration with Popup Display

#### 3.1 Source audio-alert module in popup-display.sh
- [ ] Add `source "${LIB_DIR}/audio-alert.sh"` to `lib/popup-display.sh`
  - [ ] Place after other module sources
  - [ ] Add error handling (continue if module missing)

#### 3.2 Integrate audio alert in show_warning function
- [ ] Add audio alert call in `show_warning()` function
  - [ ] Call `play_audio_beep()` after popup is displayed
  - [ ] Place after popup_pid is set (so we know popup succeeded)
  - [ ] Don't block on audio (already runs in background)
  - [ ] Don't fail if audio unavailable (graceful degradation)

#### 3.3 Test audio timing
- [ ] Verify audio plays at appropriate time (when popup appears)
- [ ] Verify audio doesn't delay popup display
- [ ] Verify audio works in systemd service context
- [ ] Test with user logged in and locked

---

### 4. Configuration UI - Menu Option

#### 4.1 Add menu option to configure-display.sh
- [ ] Update `show_main_menu()` function
  - [ ] Add new menu option for "Audio Alerts" or "Sound Settings"
  - [ ] Update menu item count and descriptions
  - [ ] Add status indicator showing current state (Enabled/Disabled)
  - [ ] Update both GUI and text mode menus
  - [ ] Place after "Window Behavior" option (option 2) or at end before "Review and Save"

#### 4.2 Add dialog function to configure-ui.sh
- [ ] Create `get_audio_alert_enabled_config()` function
  - [ ] Accept `use_gui` parameter
  - [ ] Show current setting (enabled/disabled)
  - [ ] Explain what audio alerts do (supplement visual popup with beep)
  - [ ] Ask user to enable/disable
  - [ ] Return "true" or "false" string
  - [ ] Handle cancellation (return "CANCELLED")
  - [ ] Support both GUI and text modes
  - [ ] Include clear explanation: "Play a beep sound when warning popup appears"

#### 4.3 Add menu handler to configure.sh
- [ ] Add case for new menu option (e.g., "7" or appropriate number)
  - [ ] Call `get_audio_alert_enabled_config()`
  - [ ] Handle "CANCELLED" response (return to menu, don't exit)
  - [ ] Update global `audio_alert_enabled` variable
  - [ ] Show confirmation message (optional)
  - [ ] Return to main menu after setting

---

### 5. Testing

#### 5.1 Unit Tests
- [ ] Test `get_audio_alert_enabled()` function
  - [ ] Test with missing config file (should return default false)
  - [ ] Test with AUDIO_ALERT_ENABLED=true
  - [ ] Test with AUDIO_ALERT_ENABLED=false
  - [ ] Test with invalid values (should return default)
  - [ ] Test case insensitivity (True, TRUE, etc.)

- [ ] Test `detect_audio_tool()` function
  - [ ] Test with paplay available (should return "paplay")
  - [ ] Test with only aplay available (should return "aplay")
  - [ ] Test with no tools available (should return "bell")
  - [ ] Test priority order (paplay > pw-play > aplay > canberra > beep > bell)

- [ ] Test `play_audio_beep()` function
  - [ ] Test when AUDIO_ALERT_ENABLED=false (should not play)
  - [ ] Test when AUDIO_ALERT_ENABLED=true (should play)
  - [ ] Test with each available tool (paplay, pw-play, aplay, etc.)
  - [ ] Test graceful failure when audio unavailable
  - [ ] Test non-blocking behavior (runs in background)

#### 5.2 Integration Tests
- [ ] Test audio alert with popup display
  - [ ] Set AUDIO_ALERT_ENABLED=true
  - [ ] Trigger warning popup (during restricted hours)
  - [ ] Verify beep plays when popup appears
  - [ ] Verify popup still displays if audio fails
  - [ ] Test multiple popups (verify audio doesn't overlap)

- [ ] Test configuration UI
  - [ ] Run configure.sh
  - [ ] Navigate to "Audio Alerts" menu option
  - [ ] Enable AUDIO_ALERT_ENABLED
  - [ ] Verify it's saved to config file
  - [ ] Disable AUDIO_ALERT_ENABLED
  - [ ] Verify it's saved to config file
  - [ ] Test in both GUI and text modes

- [ ] Test in systemd service context
  - [ ] Set AUDIO_ALERT_ENABLED=true
  - [ ] Trigger warning via systemd timer
  - [ ] Verify audio plays in service context
  - [ ] Check logs for audio playback status
  - [ ] Test with user session locked
  - [ ] Test with user logged out (if applicable)

#### 5.3 Edge Cases
- [ ] Test with missing config file (should default to false, no audio)
- [ ] Test with corrupted config file (should default to false, no audio)
- [ ] Test with no audio hardware available (should fail silently)
- [ ] Test with audio daemon not running (should fail silently)
- [ ] Test in headless environment (should fail silently)
- [ ] Test rapid successive alerts (should not overlap or conflict)
- [ ] Test with all audio tools unavailable (should use terminal bell)

---

### 6. Code Quality

#### 6.1 Code Documentation
- [ ] Add header comments to new functions explaining purpose
- [ ] Add inline comments for complex logic (tool detection priority)
- [ ] Document function parameters and return values
- [ ] Update main script headers if needed
- [ ] Document audio tool fallback strategy

#### 6.2 Error Handling
- [ ] Ensure all audio operations handle errors gracefully
- [ ] Ensure config parsing handles missing/invalid values
- [ ] Ensure audio tool detection handles missing tools
- [ ] Add logging for debugging (use log_message if available)
- [ ] Never fail popup display due to audio issues

#### 6.3 Code Consistency
- [ ] Follow existing code style and patterns
- [ ] Use same variable naming conventions
- [ ] Use same function organization patterns
- [ ] Match existing error message style
- [ ] Use existing logging infrastructure

---

### 7. Documentation Updates

#### 7.1 User Documentation
- [ ] Update `user-docs/CONFIGURATION.md` (if exists)
  - [ ] Document AUDIO_ALERT_ENABLED option
  - [ ] Explain what it does
  - [ ] Explain how to enable/disable
  - [ ] Note that it's opt-in (default disabled)
  - [ ] Note that it supplements visual popup

#### 7.2 Developer Documentation
- [ ] Update enhancement document status to "Phase 1 Complete"
- [ ] Document any design decisions or implementation notes
- [ ] Note any known limitations or edge cases
- [ ] Document audio tool detection priority and rationale

---

### 8. Final Verification

#### 8.1 Pre-commit Checks
- [ ] Run all existing tests to ensure no regressions
- [ ] Check for linting errors
- [ ] Verify all functions are properly sourced
- [ ] Verify config file format is correct
- [ ] Verify audio module is properly integrated

#### 8.2 Manual Testing
- [ ] Test full configuration workflow
- [ ] Test audio playback in real scenarios
- [ ] Test audio with different tools available
- [ ] Verify graceful fallback when audio unavailable
- [ ] Test in systemd service context
- [ ] Verify visual popup still works if audio fails

#### 8.3 Code Review Checklist
- [ ] All checklist items completed
- [ ] Code follows project conventions
- [ ] Error handling is robust
- [ ] User experience is clear
- [ ] Documentation is updated
- [ ] No security issues introduced
- [ ] Audio is truly optional (never blocks popup)

---

### Implementation Order Recommendation

1. **Configuration File Support** (Section 1) - Foundation
2. **Audio Alert Module Creation** (Section 2) - Core functionality
3. **Integration with Popup Display** (Section 3) - Connect to existing system
4. **Configuration UI** (Section 4) - User interface
5. **Testing** (Section 5) - Validation
6. **Code Quality & Documentation** (Sections 6-7) - Polish

---

### Notes

- Audio alerts are **opt-in** (default: disabled) to avoid annoying users
- Audio should **supplement** visual popups, not replace them
- Implement **graceful fallback** - don't fail if audio unavailable
- Audio playback should be **non-blocking** (run in background)
- Test in **systemd service context** - different from interactive shell
- Priority: `paplay` > `pw-play` > `aplay` > `canberra-gtk-play` > `beep` > `bell`

---

### Phase 2: Sound File Support
1. Add `AUDIO_ALERT_SOUND` configuration option
2. Implement audio file playback with tool detection
3. Add file selection to configuration menu
4. Support multiple audio formats

### Phase 3: Advanced Options
1. Add volume control
2. Add audio tool selection
3. Add audio alert type selection
4. Enhanced error handling and fallbacks

---

## Files to Modify

### Core Files
- `lib/config.sh` - Add functions to read audio alert settings
- `lib/configure-config.sh` - Load and save audio alert settings
- `lib/configure-display.sh` - Add menu option for audio alerts
- `lib/configure-ui.sh` - Add dialog functions for audio alert configuration
- `lib/popup-display.sh` - Add audio alert playback function
- `configure.sh` - Add menu handler for audio alert configuration
- `sleep-warning.conf` - Add audio alert configuration documentation

### New Module (Recommended)
- `lib/audio-alert.sh` - Audio alert detection and playback module
  - Tool detection function
  - Audio playback function with fallbacks
  - Volume control functions
  - Error handling

---

## Implementation Reference

For detailed code examples and implementation patterns, see:
- **[Audio Tools Options](../info/audio-tools-options.md#audio-playback-function-example)** - Complete implementation examples
- **[Audio Tools Options](../info/audio-tools-options.md#tool-detection-priority)** - Tool detection function examples

---

## Testing Considerations

### Test Scenarios
1. **Audio Enabled/Disabled**: Verify audio only plays when enabled
2. **Tool Availability**: Test with different tools available/unavailable
3. **Systemd Service**: Test audio playback from systemd timer context
4. **User Session**: Test with user logged in, locked, and logged out
5. **Sound File**: Test with custom sound file and default beep (Phase 2+)
6. **Volume Control**: Test volume settings (Phase 3)
7. **Error Handling**: Test graceful fallback when audio unavailable
8. **Multiple Alerts**: Test rapid successive alerts (should not overlap)

For detailed testing scenarios and edge cases, see:
- **[Audio Tools Options](../info/audio-tools-options.md#testing-considerations)** - Comprehensive testing guide

---

## User Experience Considerations

### Default Behavior
- **Opt-in**: Audio alerts disabled by default (non-intrusive)
- **Simple**: Default to simple beep (no file required)
- **Silent Fail**: Don't show errors if audio unavailable (graceful degradation)

### Configuration
- **Easy**: Simple enable/disable toggle in main menu
- **Advanced**: Optional sound file and volume settings
- **Clear**: Explain what audio alerts do and when they play

### Accessibility
- **Volume Control**: Allow users to set comfortable volume
- **Custom Sounds**: Support user-provided sound files
- **Visual Alternative**: Always show visual popup (audio is supplement, not replacement)

---

## Security and Privacy Considerations

### Sound File Access
- **Permissions**: Only read sound files, never write
- **Path Validation**: Validate sound file paths to prevent path traversal
- **Format Validation**: Validate audio file formats before playback

### System Resources
- **Non-blocking**: Play audio in background (don't block popup display)
- **Resource Limits**: Don't consume excessive CPU/memory for audio playback
- **Cleanup**: Ensure audio processes don't linger

---

## Related Enhancements
- Works alongside visual popup (Enhancement 14: Immovable Popup Window)
- Can be configured via configuration wizard (existing configure.sh)
- May benefit from escalation (Enhancement 6: Escalating Warnings) - louder/more frequent audio

---

## Implementation Priority

### Recommended Implementation Order
1. **Phase 1**: Basic beep functionality (simple, low risk)
2. **Phase 2**: Sound file support (moderate complexity)
3. **Phase 3**: Advanced options (volume, tool selection)

### Dependencies
- No external dependencies beyond standard Linux audio tools
- Uses existing configuration infrastructure
- Integrates with existing popup display system

---

## Notes

- Audio alerts should **supplement** visual popups, not replace them
- Default to **disabled** to avoid annoying users
- Implement **graceful fallback** - don't fail if audio unavailable
- Consider **user preferences** - some users may prefer silent mode
- Test in **systemd service context** - different from interactive shell
- Support **SteamOS/Gaming Mode** - important for Steam Deck users