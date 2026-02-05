# Enhancement 9: System Sleep/Hibernate Detection and Popup Queue Management

## Overview

This enhancement addresses multiple related issues:
1. **System Sleep/Hibernate Detection**: Skip warnings if system was recently resumed from sleep/hibernate
2. **Popup Queue Prevention**: Prevent multiple popups from accumulating, whether from hibernation or overlapping script runs
3. **Configuration Validation**: Ensure minimum display time doesn't exceed check interval

## Problem Statement

### Issue 1: False Warnings After Resume
When the system resumes from sleep/hibernate, systemd triggers all timers that would have fired during the suspend period (this is systemd's default behavior, treating suspend as "scheduling latency"). This means the timer fires immediately after resume, potentially showing a warning popup right after the user wakes up. This is a poor user experience. Note: This behavior occurs regardless of the `Persistent` setting - `Persistent=true` in our timer is primarily for catching up after boot/shutdown, but resume behavior is separate.

### Issue 2: Popup Accumulation
Currently, there is no mechanism to prevent multiple popups from running simultaneously. This can happen in two scenarios:

**Scenario A: Hibernation/Sleep**
- System goes to sleep with a popup open
- System resumes
- Timer fires immediately (Persistent=true)
- New popup spawns while old popup may still be running (if process survived hibernation)
- Result: Multiple popups accumulate

**Scenario B: Overlapping Script Runs**
- Script runs and shows popup with `POPUP_MIN_DISPLAY_TIME=300` (5 minutes)
- Timer fires again after `CHECK_INTERVAL=1` minute (60 seconds)
- New popup spawns while previous popup is still in minimum display time
- Result: Multiple popups accumulate

### Issue 3: Configuration Conflict
It is possible to configure `POPUP_MIN_DISPLAY_TIME` (0-300 seconds) to be greater than `CHECK_INTERVAL` (1-60 minutes = 60-3600 seconds). While technically valid, this creates a problematic scenario where:
- Minimum display time: 300 seconds (5 minutes)
- Check interval: 1 minute (60 seconds)
- Result: New popup will spawn every minute while previous popup is still in minimum display time

## Solution Design

### 1. System Sleep/Hibernate Detection

**Detection Methods** (in order of preference):
1. **Systemd logind**: Check `systemd-logind` for last resume time
   - Query: `systemctl show -p ActiveEnterTimestamp user@$(id -u).service`
   - Or: Check `/run/systemd/system/user@$(id -u).service.d/` for resume events
   - Alternative: `loginctl show-user $(id -u) -p ActiveSince`

2. **System uptime**: Compare current uptime with previous recorded uptime
   - Store last known uptime in state file: `~/.config/sleep-warning/.last_uptime`
   - If current uptime < previous uptime, system was resumed
   - Limitations: Only works if system was fully suspended (not just display sleep)

3. **Systemd timer last trigger**: Check when timer last fired vs system time
   - If timer last fired > system uptime, system was resumed
   - Use: `systemctl show sleep-warning.timer -p LastTriggerUSec`

**Configuration**:
- **Fixed grace period**: 60 seconds (1 minute) - NOT configurable
- Skip warnings for 1 minute after system resume
- This is a fixed value to keep behavior consistent and predictable

**Implementation Location**: `sleep-warning.sh` main() function, before checking restricted hours

### 2. Popup Queue Prevention

**Detection Method**:
- Check for existing popup processes before spawning new one
- Use window title matching: "ALERT: Restricted time window"
- Check process tree: Look for zenity/yad/kdialog processes with matching window title
- Store popup PID in state file: `~/.config/sleep-warning/.popup_pid`

**Process Detection Approaches** (in priority order):

**Approach A: PID File Tracking (Primary)**
- Store popup PID in state file when popup is spawned
- Check if PID is still running before spawning new popup
- Use atomic file operations (temp file + rename) to avoid race conditions
- Clean up stale PID files (process no longer exists) when checking
- Works on all platforms

**Approach B: Window Title Matching (Secondary)**
- Use `wmctrl` or `xdotool` to find windows with exact title "ALERT: Restricted time window"
- Works on X11, limited on Wayland
- Used as fallback if PID file is locked/unreadable

**Approach C: Process Tree Checking (Final Fallback)**
- Check for running zenity/yad/kdialog processes
- Match command line arguments for window title
- Works on all platforms but less reliable
- Used only if PID file and window title matching both fail

**Detection Logic**:
1. Check PID file first (primary method)
2. If PID file locked/unreadable, try window title matching
3. If window title matching unavailable/fails, try process tree checking
4. If all methods fail, log warning and proceed with showing popup

**Existing Popup Handling**:
- If existing popup found, check how long it's been open
- If open longer than CHECK_INTERVAL: Close it and show new popup
- If open less than CHECK_INTERVAL: Skip showing new popup (log at INFO level)
- If multiple popups found: Close all of them, then show new one

**Implementation Location**: `lib/popup-display.sh` show_warning() function, before spawning popup

**State File Management**:
- File: `~/.config/sleep-warning/.popup_pid`
- Format: Single line with PID
- Cleanup: Remove file when popup closes, check for stale PIDs on startup

### 3. Configuration Validation

**Validation Rule**:
- Warn user if `POPUP_MIN_DISPLAY_TIME` (in seconds) > `CHECK_INTERVAL` (in minutes) * 60
- Example: `POPUP_MIN_DISPLAY_TIME=300` (5 min) with `CHECK_INTERVAL=1` (1 min) = conflict
- Validation should occur in:
  - `configure.sh` wizard (when user sets values)
  - `lib/configure-input-popup.sh` (when setting minimum display time)
  - `lib/configure-input-time.sh` (when setting check interval)

**Validation Behavior**:
- **Hard error (block)**: User cannot proceed with invalid configuration
- Show error dialog: "Error: Minimum display time (X seconds) is greater than check interval (Y minutes). This will cause multiple popups to appear simultaneously. Please adjust one of these values: either increase CHECK_INTERVAL or decrease POPUP_MIN_DISPLAY_TIME."
- User must fix the conflict before continuing (no option to proceed anyway)

**Implementation Location**: 
- `lib/configure-input-popup.sh` (after setting min display time)
- `lib/configure-input-time.sh` (after setting check interval)
- `lib/configure-validation.sh` (new validation function)

## Implementation Details

### Files Affected

1. **`sleep-warning.sh`**
   - Add sleep/hibernate detection check in main()
   - Add popup PID tracking cleanup on exit

2. **`lib/popup-display.sh`**
   - Add function: `is_popup_running()` - Check if popup already exists (returns PID and age if found)
   - Add function: `get_popup_age()` - Calculate how long popup has been open (in seconds)
   - Add function: `close_existing_popups()` - Close all existing popups found
   - Add function: `save_popup_pid()` - Store popup PID to state file (atomic: temp file + rename)
   - Add function: `cleanup_popup_pid()` - Remove PID file when popup closes
   - Add function: `cleanup_stale_pid()` - Remove PID file if process no longer exists
   - Modify `show_warning()`: Check for existing popup before spawning
   - Modify `show_warning()`: If existing popup found and age > CHECK_INTERVAL, close it and show new one
   - Modify `show_warning()`: If existing popup found and age <= CHECK_INTERVAL, skip showing new popup (log INFO)
   - Modify `show_warning()`: Save PID when popup is spawned (atomic operation) and log new PID
   - Modify `show_warning()`: Cleanup PID when popup closes
   - Modify `update_popup_countdown()`: 
     - **Before killing old popup**: Cleanup old PID file (call `cleanup_popup_pid()` with old PID)
     - **After spawning new popup**: Save new PID to file (call `save_popup_pid()` with new PID) and log new PID
     - This ensures PID file always reflects the currently active popup

3. **`lib/config.sh`**
   - Add: `SLEEP_RESUME_GRACE_PERIOD=60` (1 minute, fixed constant)
   - Add: `POPUP_PID_FILE` constant for state file path

4. **`lib/sleep-detection.sh`** (NEW FILE)
   - Function: `check_system_resume()` - Detect if system recently resumed (returns 0 if resumed, 1 if not)
     - Primary: Use systemd-logind (`systemctl show -p ActiveEnterTimestamp user@$(id -u).service`)
     - Fallback: Uptime comparison (compare current uptime with stored value)
     - Returns 0 only if clear evidence of resume (err on side of showing warnings)
   - Function: `get_last_resume_time()` - Get timestamp of last resume (Unix timestamp)
   - Function: `is_within_resume_grace_period()` - Check if within 60-second grace period
   - Function: `update_uptime_tracking()` - Store current uptime for comparison (for fallback method)
   - Function: `should_skip_warning_after_resume()` - Main function: returns 0 if should skip, 1 if should show

5. **`lib/configure-input-popup.sh`**
   - Add validation warning when min display time > check interval

6. **`lib/configure-input-time.sh`**
   - Add validation warning when check interval < min display time / 60

7. **`lib/configure-validation.sh`**
   - Add function: `validate_popup_timing_config()` - Check for timing conflicts
   - Function should return 1 if conflict detected (hard error), 0 if valid
   - Function should provide error message with both fix options (increase interval OR decrease min time)

8. **`configure.sh`**
   - No changes needed (grace period is fixed, not configurable)

### State Files

**New State File**: `~/.config/sleep-warning/.popup_pid`
- Format: Single line with process ID
- Example: `12345`
- Created: When popup is spawned
- Removed: When popup closes or script exits
- Cleanup: Check for stale PIDs (process no longer exists) on startup

**Modified State File**: `~/.config/sleep-warning/.last_uptime` (if using uptime method)
- Format: Unix timestamp of last known uptime
- Updated: On each script run
- Used: To detect if system was resumed

## Implementation Checklist

### Phase 1: Sleep/Hibernate Detection
- [x] Create `lib/sleep-detection.sh` module
- [x] Implement `check_system_resume()` using systemd-logind
- [x] Implement fallback using uptime comparison
- [x] Add `SLEEP_RESUME_GRACE_PERIOD=60` constant to `lib/config.sh`
- [x] Add grace period check in `sleep-warning.sh` main()
- [ ] Test with actual sleep/hibernate cycles - **PENDING: Requires manual testing with system sleep/hibernate**

### Phase 2: Popup Queue Prevention
- [x] Add `POPUP_PID_FILE` constant to `lib/config.sh`
- [x] Implement `is_popup_running()` in `lib/popup-display.sh`
  - [x] PID file checking (primary)
  - [x] Window title matching (fallback if PID file locked/unreadable)
  - [x] Process tree checking (final fallback)
  - [x] Return PID and age of popup if found
- [x] Implement `get_popup_age()` function - Calculate age from PID file timestamp or process start time
- [x] Implement `close_existing_popups()` function - Close all found popups
- [x] Implement `save_popup_pid()` function (atomic: temp file + rename)
- [x] Implement `cleanup_popup_pid()` function
- [x] Implement `cleanup_stale_pid()` function - Check if PID still exists, remove file if not
- [x] Modify `show_warning()` to check for existing popup before spawning
- [x] Modify `show_warning()` to check popup age vs CHECK_INTERVAL
- [x] Modify `show_warning()` to close existing popup if age > CHECK_INTERVAL, then show new one
- [x] Modify `show_warning()` to skip new popup if age <= CHECK_INTERVAL (log INFO)
- [x] Modify `show_warning()` to save PID when popup spawns (atomic operation)
- [x] Modify `show_warning()` to cleanup PID when popup closes
- [x] Modify `update_popup_countdown()` to handle PID file updates:
  - [x] Before killing old popup: Call `cleanup_popup_pid()` to remove old PID from file
  - [x] After spawning new popup: Call `save_popup_pid()` to save new PID to file
  - [x] Log both operations: "Popup respawned: Old PID ${old_pid} cleaned up, new PID ${new_pid} saved"
- [x] Add stale PID cleanup when checking for existing popup (implemented in `is_popup_running()`)
- [ ] Test with overlapping script runs - **PENDING: Requires manual testing with timer triggers**
- [ ] Test with hibernation scenarios - **PENDING: Requires manual testing with system hibernate**
- [ ] Test popup respawn scenario (user closes before min time, new PID created) - **PENDING: Requires manual testing**

### Phase 3: Configuration Validation
- [x] Add `validate_popup_timing_config()` to `lib/configure-validation.sh`
  - [x] Return 1 if conflict detected (hard error), 0 if valid
  - [x] Provide error message with both fix options (increase interval OR decrease min time)
- [x] Add validation error (hard block) in `lib/configure-input-popup.sh`
  - [x] Check against current CHECK_INTERVAL when setting min display time
  - [x] Block user from proceeding if conflict detected
  - [x] Show error with both fix options
  - [x] Implemented for both GUI and text modes
- [x] Add validation error (hard block) in `lib/configure-input-time.sh`
  - [x] Check against current POPUP_MIN_DISPLAY_TIME when setting check interval
  - [x] Block user from proceeding if conflict detected
  - [x] Show error with both fix options
  - [x] Implemented for both GUI and text modes
- [ ] Test validation with various timing combinations - **PENDING: Requires manual testing**
- [ ] Test that user cannot proceed until conflict is resolved - **PENDING: Requires manual testing**
- [x] Update user documentation with timing recommendations - ✅ **Complete** - Added validation note to CONFIGURATION.md

### Phase 4: Testing
- [ ] Test sleep detection with systemd-logind - **PENDING: Requires manual testing with system sleep**
- [ ] Test sleep detection with uptime fallback - **PENDING: Requires manual testing**
- [ ] Test popup prevention with overlapping runs - **PENDING: Requires manual testing**
- [ ] Test popup prevention after hibernation - **PENDING: Requires manual testing with system hibernate**
- [ ] Test configuration validation warnings - **PENDING: Requires manual testing**
- [ ] Test edge cases (stale PID files, missing state files, etc.) - **PENDING: Requires manual testing**

## Priority

**High** - This enhancement addresses critical user experience issues:
- Prevents annoying false warnings after system resume
- Prevents popup accumulation (both scenarios)
- Provides configuration validation to prevent problematic setups

## Status

**Partially Implemented** - Core implementation complete, testing pending

**Implementation Complete:**
- ✅ Phase 1: Sleep/Hibernate Detection (code complete, testing pending)
- ✅ Phase 2: Popup Queue Prevention (code complete, testing pending)
- ✅ Phase 3: Configuration Validation (code complete, testing pending)

**Remaining Work:**
- ⏳ Phase 4: Testing (automated unit tests complete, manual integration tests pending)

## Testing

### Automated Tests

**Test File**: `tests/test-enhancement-09.sh`

**Last Run**: 2026-01-25  
**Status**: ✅ **PASS** (24/24 tests passed)  
**Execution Time**: ~2 seconds  
**Dependencies**: bash

**Test Coverage**:

**Configuration Validation Tests (6 tests)**:
- ✅ Valid configurations (boundary cases: 30s < 10min, 0s < 1min, 60s = 1min)
- ✅ Invalid configurations detected (300s > 1min, 120s > 1min)
- ✅ Error messages include both fix options (increase interval OR decrease min time)

**PID File Management Tests (6 tests)**:
- ✅ `save_popup_pid()` saves PID correctly (atomic operation)
- ✅ PID file contains correct PID after save
- ✅ `cleanup_popup_pid()` removes PID file
- ✅ `cleanup_popup_pid()` handles missing file gracefully
- ✅ `cleanup_stale_pid()` removes stale PID files (non-existent processes)
- ✅ `cleanup_stale_pid()` handles missing file gracefully

**Sleep Detection Tests (6 tests)**:
- ✅ `SLEEP_RESUME_GRACE_PERIOD` constant is 60 seconds
- ✅ `POPUP_PID_FILE` constant is defined
- ✅ `LAST_UPTIME_FILE` constant is defined
- ✅ `check_system_resume()` function exists
- ✅ `should_skip_warning_after_resume()` function exists
- ✅ `update_uptime_tracking()` function exists

**Popup Detection Tests (4 tests)**:
- ✅ `is_popup_running()` function exists
- ✅ `get_popup_age()` function exists
- ✅ `close_existing_popups()` function exists
- ✅ `is_popup_running()` returns empty when no popup is running

**Integration Tests (2 tests)**:
- ✅ `sleep-warning.sh` sources `sleep-detection.sh`
- ✅ `sleep-warning.sh` calls `should_skip_warning_after_resume()`

**Results**: All 24 automated unit tests pass successfully. Core functionality verified:
- Configuration validation correctly detects timing conflicts
- PID file management functions work correctly (save, read, cleanup)
- All required functions exist and are properly integrated
- Constants are defined correctly

**Test Features**:
- Non-destructive: Uses temporary test config directory (doesn't touch real config)
- Comprehensive: Covers all unit-testable functions
- Clear output: Provides pass/fail results with details
- Can be run independently: `./tests/test-enhancement-09.sh`

### Manual Testing Required

The following scenarios require manual testing and cannot be automated:

**Sleep/Hibernate Detection**:
- ⏳ Test actual system sleep detection (requires system sleep)
- ⏳ Test actual system hibernate detection (requires system hibernate)
- ⏳ Test grace period behavior after resume
- ⏳ Test uptime fallback when systemd-logind unavailable

**Popup Queue Prevention**:
- ⏳ Test popup prevention with overlapping script runs (requires timer triggers)
- ⏳ Test popup prevention after hibernation (requires system hibernate)
- ⏳ Test popup respawn scenario (user closes before min time, new PID created)
- ⏳ Test popup age calculation vs CHECK_INTERVAL logic
- ⏳ Test closing existing popups when age > CHECK_INTERVAL

**Configuration Validation**:
- ⏳ Test validation in configure.sh wizard (GUI mode)
- ⏳ Test validation in configure.sh wizard (text mode)
- ⏳ Test that user cannot proceed until conflict is resolved
- ⏳ Test error message display with both fix options

**Edge Cases**:
- ⏳ Test stale PID file cleanup on startup
- ⏳ Test missing state files handling
- ⏳ Test PID file locked/unreadable scenarios
- ⏳ Test window title matching on X11 vs Wayland
- ⏳ Test process tree checking fallback

## Related Enhancements

- **Enhancement #15** (Auto-Close Popup Window): Related popup management
- **Enhancement #21** (Pause Feature): Also prevents popups, but user-initiated
- **Enhancement #17** (Multi-Display Support): May need popup tracking per display

## Implementation Decisions

The following decisions have been made for implementation:

### 1. Sleep/Hibernate Detection

**Decision**: Only skip warnings if we have clear evidence of resume (err on the side of showing warnings)
- If detection methods fail or are uncertain, show the warning
- Better to show a false warning than miss a legitimate one

**Decision**: Apply grace period to all resume types
- Sleep (suspend to RAM)
- Hibernate (suspend to disk)
- Hybrid sleep

**Decision**: Detection method priority
- **Primary**: systemd-logind (most reliable)
- **Fallback**: Uptime comparison
- If primary fails, fall back to next method, log warning, but don't fail script execution

### 2. Popup Queue Prevention

**Decision**: Existing popup handling
- Close existing popup and show new one **ONLY if it's been open longer than CHECK_INTERVAL**
- If existing popup has been open less than CHECK_INTERVAL, skip showing new popup
- This prevents disruption while still allowing refresh of stale popups

**Decision**: Logging
- Log at INFO level when skipping due to existing popup (for debugging)
- Log when closing existing popup to show new one

**Decision**: Multiple popups
- Close all existing popups found, then show new one
- This handles edge cases where multiple popups somehow exist

**Decision**: Window title matching
- Use exact match for "ALERT: Restricted time window"
- Case-sensitive matching

**Decision**: Stale PID cleanup
- Check and clean up stale PIDs when checking for existing popup
- Don't clean up on every script run (only when needed)

**Note**: When user closes popup before minimum display time and it respawns (via `update_popup_countdown()`), this creates a **new PID**. The old PID file should be cleaned up when the popup is closed, and the new PID should be saved when the new popup spawns.

### 3. Configuration Validation

**Decision**: Validation behavior
- **Hard error (block)**: User cannot proceed with invalid configuration
- Must fix the conflict before continuing

**Decision**: Bidirectional checking
- When setting min display time: check against current check interval
- When setting check interval: check against current min display time
- Validation occurs in both directions

**Decision**: Fix suggestions
- Suggest user can either:
  - Increase CHECK_INTERVAL, OR
  - Decrease POPUP_MIN_DISPLAY_TIME
- Do NOT recommend one option over the other (let user choose)
- Present both options equally

### 4. State File Management

**Decision**: Atomic file operations
- Use temp file + rename pattern to avoid race conditions
- Write to temp file first, then atomically rename to final location

**Decision**: PID file error handling
- If PID file is locked or unreadable, fall back to:
  1. Window title matching (if window tools available)
  2. Process tree checking (final fallback)
- Don't fail script execution if PID file operations fail

### 5. Error Handling

**Decision**: Sleep detection failure
- Fall back to next method, log warning, but don't fail script execution
- Continue with showing warning if all detection methods fail

**Decision**: Popup detection failure
- Log warning and proceed with showing popup
- Better to show duplicate popup than miss one entirely

## Notes

- **Systemd Timer Behavior After Resume**: Systemd treats suspend/hibernate as "scheduling latency" rather than downtime. When the system resumes, systemd triggers all timers that would have fired during the suspend/hibernate period, regardless of the `Persistent` setting. This means timers fire immediately after resume if their scheduled time elapsed while the system was suspended. The `Persistent=true` setting in our timer file is primarily for catching up on missed runs after system boot/shutdown, but the resume behavior happens regardless. This is why we need sleep detection - to skip warnings during the grace period after resume.
- Window title matching requires X11 window tools (wmctrl/xdotool) - will have limited functionality on Wayland
- PID file tracking works on all platforms but may have race conditions - window title matching is more reliable when available
- Configuration validation is a **hard error (block)** - users must fix timing conflicts before proceeding
- Error message presents both fix options equally (increase interval OR decrease min time) - no recommendation
- Grace period is fixed at 1 minute (60 seconds) - not configurable to keep behavior consistent
- **Popup Respawn Scenario**: When user closes popup before minimum display time, `update_popup_countdown()` is called:
  1. **Old PID cleanup**: Before killing the old popup process, call `cleanup_popup_pid()` to remove old PID from PID file
  2. **New PID capture**: After spawning new popup and getting new PID, call `save_popup_pid()` to save new PID to file
  3. **Logging**: Log both operations: "Popup respawned: Old PID ${old_pid} cleaned up, new PID ${new_pid} saved"
  4. This ensures PID file always reflects the currently active popup and we can track the new PID
- Existing popup is only replaced if it's been open longer than CHECK_INTERVAL - otherwise new popup is skipped
