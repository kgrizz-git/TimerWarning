# Enhancement 15: Auto-Close Popup Window

## Description

Automatically close the popup window 10 seconds after the minimum display time completes, providing users with a non-interactive option for warning dismissal. This feature complements the minimum display time feature by allowing automatic dismissal after the warning has been visible for the required duration plus a short grace period.

**Key Design Decisions**:
- **Enabled by default** - Auto-close is active unless explicitly disabled
- Auto-close happens **10 seconds after minimum display time completes** (additional time, not total time)
- If minimum display time is 0, auto-close happens after 10 seconds
- Auto-close time is **not configurable** - fixed at 10 seconds for simplicity
- User is notified when auto-close will occur (minimum time remaining + 10 seconds)

## User Experience Benefits

- Provides automatic dismissal option for users who don't want to manually close warnings
- Enabled by default for better user experience
- Reduces need for user interaction while still ensuring warning visibility
- Works seamlessly with existing minimum display time and immovable window features

## Related Features

- **Enhancement #14** (Immovable Popup Window): Auto-close works with minimum display time enforcement
- **Enhancement #21** (Pause Button): Auto-close timer is cancelled if user clicks pause button
- Could work with visual countdown timer enhancement (future)

---

## Implementation Plan

### Phase 1: Configuration File Support

#### 1.1 Add Default Values to config.sh
- [ ] Add `DEFAULT_POPUP_AUTO_CLOSE=true` constant in `lib/config.sh` (after `DEFAULT_POPUP_IMMOVABLE`)
  - [ ] **Note**: Auto-close is enabled by default
- [ ] Add `AUTO_CLOSE_DELAY=10` constant (fixed 10-second delay after minimum display time)
- [ ] Document that auto-close happens 10 seconds after minimum display time completes

#### 1.2 Add Configuration Getter Functions
- [ ] Add `get_popup_auto_close()` function in `lib/config.sh`
  - [ ] Read `POPUP_AUTO_CLOSE` from config file
  - [ ] Validate value (true/false/1/0/yes/no)
  - [ ] Return default (`true`) if missing or invalid
  - [ ] Normalize output to "true" or "false" string
  - [ ] Follow same pattern as `get_popup_immovable()`
- [ ] **Note**: No `get_popup_auto_close_time()` function needed - auto-close time is fixed at 10 seconds

#### 1.3 Update configure-config.sh
- [ ] Add `popup_auto_close` to global variables in `load_existing_config()`
  - [ ] Initialize with default: `declare -g popup_auto_close="true"`
  - [ ] Read existing value from config file (if present)
  - [ ] Validate and normalize to "true" or "false"
- [ ] **Note**: No `popup_auto_close_time` variable needed - auto-close time is fixed at 10 seconds
- [ ] Update `write_config()` function signature
  - [ ] Add `popup_auto_close` as parameter (after `popup_immovable`, before `configure_block_enabled`)
  - [ ] Write `POPUP_AUTO_CLOSE=${popup_auto_close}` to config file
  - [ ] Add comment header explaining the option
  - [ ] Document that auto-close happens 10 seconds after minimum display time completes
  - [ ] Place after `POPUP_IMMOVABLE` section in config file
  - [ ] Update parameter count in function documentation

#### 1.4 Update configure.sh Main Function
- [ ] Add `popup_auto_close` to global variable declarations
  - [ ] Add to: `declare -g check_interval popup_size popup_position min_display_time popup_immovable popup_auto_close configure_block_enabled ...`
- [ ] Update `write_config()` call in `configure.sh`
  - [ ] Add `${popup_auto_close}` as argument
  - [ ] Ensure correct parameter order matches `write_config()` signature

#### 1.5 Update Config File Template
- [ ] Add `POPUP_AUTO_CLOSE` section to `sleep-warning.conf` template
  - [ ] Add comment explaining the feature
  - [ ] Document that auto-close happens 10 seconds after minimum display time completes
  - [ ] Document that if minimum display time is 0, auto-close happens after 10 seconds
  - [ ] Add default value: `POPUP_AUTO_CLOSE=true` (enabled by default)
  - [ ] Place after `POPUP_IMMOVABLE` section
- [ ] **Note**: No `POPUP_AUTO_CLOSE_TIME` option needed - auto-close time is fixed at 10 seconds

---

### Phase 2: Configuration UI

#### 2.1 Add Menu Option to configure-display.sh
- [ ] Update `show_main_menu()` function in `lib/configure-display.sh`
  - [ ] Add auto-close status display in window behavior description
  - [ ] Show current auto-close setting (enabled/disabled)
  - [ ] Show "Auto-close: 10s after min display time" if enabled
  - [ ] Update menu option numbering if needed (check existing menu structure)

#### 2.2 Add Input Functions to configure-input.sh
- [ ] Add `get_popup_auto_close_config()` function in `lib/configure-input.sh`
  - [ ] Prompt user to enable/disable auto-close
  - [ ] Use GUI dialog (zenity/yad/kdialog) if available
  - [ ] Use text prompt as fallback
  - [ ] Explain that auto-close happens 10 seconds after minimum display time completes
  - [ ] Show current minimum display time for reference
  - [ ] Validate input (true/false/yes/no/1/0)
  - [ ] Return normalized value ("true" or "false")
  - [ ] Follow same pattern as `get_popup_immovable_config()`
- [ ] **Note**: No `get_popup_auto_close_time_config()` function needed - auto-close time is fixed at 10 seconds

#### 2.3 Integrate into configure.sh Workflow
- [ ] Add menu option in `configure.sh` main loop
  - [ ] Add case for auto-close configuration
  - [ ] Call `get_popup_auto_close_config()` to get enabled/disabled
  - [ ] Update global variable
  - [ ] Show confirmation or summary
- [ ] Update `show_summary()` function in `lib/configure-display.sh`
  - [ ] Add auto-close status to summary display
  - [ ] Show auto-close enabled/disabled
  - [ ] Show "10s after min display time" if enabled

---

### Phase 3: Popup Display Logic

#### 3.1 Add Auto-Close Detection in popup-display.sh
- [ ] In `show_warning()` function, read auto-close settings
  - [ ] Call `get_popup_auto_close()` to check if enabled
  - [ ] Call `get_min_display_time()` to get minimum display time
  - [ ] Calculate auto-close time: `min_display_time + 10` seconds
  - [ ] If `min_display_time = 0`, auto-close time is 10 seconds
- [ ] Calculate when to notify user about auto-close
  - [ ] Calculate total time until auto-close: `min_display_time + 10`
  - [ ] Update popup message to show when auto-close will occur
  - [ ] Format: "This popup will auto-close in X seconds" (where X = min_display_time remaining + 10)

#### 3.2 Implement Auto-Close Timer
- [ ] Create background function `auto_close_popup()` in `popup-display.sh`
  - [ ] Parameters: `popup_pid`, `dialog_tool`, `window_title`, `window_tool`
  - [ ] Sleep for 10 seconds (fixed delay after minimum display time)
  - [ ] Check if popup process is still running (`kill -0 "${popup_pid}"`)
  - [ ] If still running, close the popup using appropriate method for dialog tool
  - [ ] Log auto-close event
  - [ ] Return exit code
- [ ] Start auto-close timer after minimum display time completes
  - [ ] Only if `popup_auto_close` is `true`
  - [ ] Start timer after minimum display time loop completes (if min_display_time > 0)
  - [ ] If no minimum display time (min_display_time = 0), start timer immediately after popup display
  - [ ] Store timer PID for cleanup if user manually closes popup

#### 3.3 Implement Dialog Tool-Specific Close Methods
- [ ] Create `close_popup_process()` function in `popup-display.sh`
  - [ ] Parameters: `popup_pid`, `dialog_tool`
  - [ ] Check if process is still running (`kill -0 "${popup_pid}"`)
  - [ ] If not running, return success (user already closed it)
  - [ ] Try SIGTERM first (graceful shutdown)
    - [ ] Send `kill -TERM "${popup_pid}"`
    - [ ] Wait briefly (0.5 seconds) for process to exit
    - [ ] Check if process exited
  - [ ] If still running, try SIGKILL (force termination)
    - [ ] Send `kill -KILL "${popup_pid}"` or `kill -9 "${popup_pid}"`
    - [ ] Wait briefly (0.5 seconds) for process to exit
  - [ ] Handle errors gracefully
    - [ ] If process already exited, log info message (user closed manually)
    - [ ] If close fails, log warning but don't crash
    - [ ] Return success/failure status
- [ ] Works for all dialog tools (zenity, yad, kdialog) - process termination is universal

#### 3.4 Handle Manual Close Before Auto-Close
- [ ] Monitor popup process in main `show_warning()` function
  - [ ] Check if popup process exited before auto-close timer
  - [ ] If exited, cancel auto-close timer (kill timer process if still running)
  - [ ] Log that user closed popup manually
  - [ ] Handle pause button clicks (existing logic) - auto-close timer should be cancelled
- [ ] Clean up timer process
  - [ ] Store timer PID when starting auto-close timer
  - [ ] If popup closes manually, kill timer process
  - [ ] If auto-close succeeds, timer process exits naturally

#### 3.5 Integration with Minimum Display Time
- [ ] Ensure auto-close respects minimum display time
  - [ ] If `min_display_time > 0`:
    - [ ] Wait for minimum display time to complete (existing loop)
    - [ ] After minimum display time completes, start 10-second auto-close timer
    - [ ] Total time until auto-close = `min_display_time + 10` seconds
  - [ ] If `min_display_time = 0`:
    - [ ] Start 10-second auto-close timer immediately after popup displays
    - [ ] Total time until auto-close = 10 seconds
- [ ] Update popup message to show auto-close countdown
  - [ ] If minimum display time is active, show: "This popup must remain visible for X more second(s) before it can be closed. It will auto-close 10 seconds after that."
  - [ ] After minimum display time completes, update message: "This popup will auto-close in X seconds" (where X counts down from 10)
  - [ ] If minimum display time is 0, show: "This popup will auto-close in X seconds" (where X counts down from 10)

#### 3.6 Logging
- [ ] Log auto-close configuration when popup is displayed
  - [ ] Log if auto-close is enabled
  - [ ] Log total time until auto-close: `min_display_time + 10` seconds
  - [ ] Log relationship to minimum display time
- [ ] Log auto-close events
  - [ ] Log when auto-close timer starts (after minimum display time completes)
  - [ ] Log when popup is auto-closed (successful termination)
  - [ ] Log if auto-close is cancelled (user closed manually before timer)
  - [ ] Log if process termination fails (SIGTERM and SIGKILL both fail)
  - [ ] Use appropriate log levels (INFO for normal operation, WARNING for issues)

---

### Phase 4: Documentation Updates

#### 4.1 Update User Documentation
- [ ] Update `user-docs/CONFIGURATION.md`
  - [ ] Add `POPUP_AUTO_CLOSE` option documentation
    - [ ] Description of feature (auto-close 10 seconds after minimum display time)
    - [ ] Default value (`true` - enabled by default)
    - [ ] Valid values (`true`/`false`)
    - [ ] Behavior when minimum display time is set (auto-close = min_display_time + 10 seconds)
    - [ ] Behavior when minimum display time is 0 (auto-close = 10 seconds)
    - [ ] Note that auto-close time is fixed at 10 seconds (not configurable)
    - [ ] Example configurations
- [ ] **Note**: No `POPUP_AUTO_CLOSE_TIME` option documentation needed - time is fixed at 10 seconds
- [ ] Update `user-docs/USER_GUIDE.md`
  - [ ] Add section about auto-close feature
  - [ ] Explain use cases
  - [ ] Provide configuration examples
  - [ ] Add to troubleshooting section if needed

#### 4.2 Update Developer Documentation
- [ ] Update `dev-docs/TECHNICAL_DETAILS.md`
  - [ ] Document auto-close implementation
  - [ ] Explain timer mechanism (10-second delay after minimum display time)
  - [ ] Document process termination method (SIGTERM first, then SIGKILL)
  - [ ] Document integration with minimum display time
  - [ ] Document Wayland compatibility (works on Wayland since it uses process termination, not window tools)
- [ ] Update this enhancement document
  - [ ] Mark checklist items as complete during implementation
  - [ ] Add implementation notes and findings
  - [ ] Document any deviations from plan

---

### Phase 5: Testing

#### 5.1 Unit Tests
- [ ] Test `get_popup_auto_close()` function
  - [ ] Test with valid values (true/false/1/0/yes/no)
  - [ ] Test with invalid values
  - [ ] Test with missing config (should return default)
- [ ] **Note**: No `get_popup_auto_close_time()` function to test - time is fixed at 10 seconds

#### 5.2 Integration Tests
- [ ] Test auto-close with zenity
  - [ ] Enable auto-close, set minimum display time to 0
  - [ ] Verify popup closes after 10 seconds
  - [ ] Verify logging
  - [ ] Test with minimum display time enabled (e.g., 30 seconds)
  - [ ] Verify popup closes after 40 seconds (30 + 10)
- [ ] Test auto-close with yad
  - [ ] Enable auto-close, set minimum display time to 0
  - [ ] Verify popup closes after 10 seconds
  - [ ] Verify logging
  - [ ] Test with minimum display time enabled (e.g., 30 seconds)
  - [ ] Verify popup closes after 40 seconds (30 + 10)
- [ ] Test auto-close with kdialog
  - [ ] Enable auto-close, set minimum display time to 0
  - [ ] Verify popup closes after 10 seconds
  - [ ] Verify logging
  - [ ] Test with minimum display time enabled (e.g., 30 seconds)
  - [ ] Verify popup closes after 40 seconds (30 + 10)
- [ ] Test auto-close with minimum display time
  - [ ] Set minimum display time to 30 seconds
  - [ ] Enable auto-close
  - [ ] Verify popup closes after 40 seconds (30 + 10)
  - [ ] Verify message shows correct countdown
- [ ] Test manual close before auto-close
  - [ ] Enable auto-close, set minimum display time to 30 seconds
  - [ ] Manually close popup after 35 seconds (during the 10-second grace period)
  - [ ] Verify auto-close timer is cancelled
  - [ ] Verify no error messages
- [ ] Test pause button with auto-close
  - [ ] Enable auto-close and pause button
  - [ ] Set minimum display time to 30 seconds
  - [ ] Click pause button during minimum display time
  - [ ] Verify auto-close timer is cancelled
  - [ ] Verify pause activates correctly

#### 5.3 Edge Cases
- [ ] Test with auto-close enabled but no window tools available
  - [ ] Should still work (process termination method works without window tools)
- [ ] Test with very short minimum display time (1 second)
  - [ ] Verify popup closes after 11 seconds (1 + 10)
- [ ] Test with very long minimum display time (300 seconds)
  - [ ] Verify popup closes after 310 seconds (300 + 10)
- [ ] Test process termination failure
  - [ ] Simulate case where SIGTERM and SIGKILL both fail (unlikely but possible)
  - [ ] Verify system handles gracefully (logs warning, doesn't crash)
- [ ] Test configuration UI
  - [ ] Test enabling/disabling auto-close
  - [ ] Verify message explains 10-second delay after minimum display time
  - [ ] Test with GUI and text modes
- [ ] Test on Wayland
  - [ ] Verify auto-close works on Wayland (process termination is platform-independent)

---

## Implementation Notes

### Dialog Tool Close Methods

**All Tools (zenity, yad, kdialog)**: Process termination is the universal method. The popup process can be killed using:
1. First try `kill -TERM "${popup_pid}"` (SIGTERM - graceful shutdown)
2. Wait 0.5 seconds
3. If still running, try `kill -KILL "${popup_pid}"` or `kill -9 "${popup_pid}"` (SIGKILL - force termination)

This approach works on all platforms (X11, Wayland, gamescope) since it doesn't rely on window management tools.

### Timer Implementation

The auto-close timer should be implemented as a background process that:
1. Waits for minimum display time to complete (if min_display_time > 0)
2. Sleeps for 10 seconds (fixed delay)
3. Checks if the popup process is still running
4. If running, closes it using process termination (SIGTERM, then SIGKILL if needed)
5. Logs the event

The timer PID should be stored so it can be cancelled if the user manually closes the popup.

### Integration with Minimum Display Time

The auto-close feature respects the minimum display time:
- **If minimum display time > 0**: 
  - Wait for minimum display time to complete (existing loop)
  - Then start 10-second auto-close timer
  - Total time = `min_display_time + 10` seconds
- **If minimum display time = 0**:
  - Start 10-second auto-close timer immediately
  - Total time = 10 seconds

This ensures the popup is always visible for at least the minimum display time, then auto-closes 10 seconds later.

### Error Handling

All close operations should be wrapped in error handling:
- Check if process exists before attempting to close (`kill -0 "${popup_pid}"`)
- Try SIGTERM first (allows graceful shutdown)
- If SIGTERM fails or process still running, try SIGKILL
- Log warnings if both SIGTERM and SIGKILL fail but don't crash
- Handle race conditions gracefully (popup closes between check and close attempt)
- Process termination works without window tools, so no dependency on wmctrl/xdotool

---

## Files Affected

### Core Files
- `lib/config.sh` - Add getter functions and default values
- `lib/popup-display.sh` - Implement auto-close logic
- `lib/configure-config.sh` - Add config file writing support
- `lib/configure-input.sh` - Add input functions for configuration UI
- `lib/configure-display.sh` - Update menu and summary displays
- `configure.sh` - Integrate into configuration workflow
- `sleep-warning.conf` - Add config file template entries

### Documentation Files
- `user-docs/CONFIGURATION.md` - Document new options
- `user-docs/USER_GUIDE.md` - Add user guide section
- `dev-docs/TECHNICAL_DETAILS.md` - Document implementation
- `dev-docs/enhancements/enhancement-15-auto-close-popup-window.md` - This file

### Test Files (to be created)
- `tests/test-auto-close-popup.sh` - Integration tests for auto-close feature

---

## Priority

**Medium** - Useful feature for users who want automatic dismissal without manual interaction. Complements existing minimum display time feature.

## Status

**Not implemented** - Ready for implementation following this plan.

---

## Implementation Decisions

The following decisions have been made for this implementation:

### 1. Auto-Close Timer Start Timing ✅

**Decision**: **Additional time after minimum display time** (10 seconds fixed)

- Auto-close happens **10 seconds after minimum display time completes**
- If `min_display_time=30`, total time until auto-close = 40 seconds (30 + 10)
- If `min_display_time=0`, total time until auto-close = 10 seconds
- Timer starts counting **after** minimum display time loop completes

### 2. Auto-Close Time Configuration ✅

**Decision**: **Not configurable by user** - fixed at 10 seconds

- No `POPUP_AUTO_CLOSE_TIME` configuration option
- Auto-close always happens 10 seconds after minimum display time
- Simplifies implementation and user experience
- User is notified when auto-close will occur (min_display_time remaining + 10 seconds)

### 3. Process Termination Method ✅

**Decision**: **SIGTERM first, then SIGKILL if needed**

- Try `kill -TERM "${popup_pid}"` first (graceful shutdown)
- Wait 0.5 seconds
- If process still running, try `kill -KILL "${popup_pid}"` (force termination)
- Standard approach for process termination

### 4. Configuration Validation ✅

**Decision**: **No validation needed** - auto-close time is fixed, not configurable

- Since auto-close time is always 10 seconds (not user-configurable), no validation needed
- Only `POPUP_AUTO_CLOSE=true/false` needs validation (standard boolean validation)

### 5. Maximum Time Limit ✅

**Decision**: **Not applicable** - auto-close time is fixed at 10 seconds

- No user-configurable time limit to validate
- Maximum total time is `min_display_time + 10` (where min_display_time max is 300 seconds)

### 6. Wayland Compatibility Documentation ✅

**Decision**: **Yes, document that auto-close works on Wayland**

- Process termination (kill) works on all platforms including Wayland
- Unlike window management features (minimum display time enforcement), auto-close doesn't require window tools
- Document this advantage in user and developer documentation

---

## Related Enhancements

- **Enhancement #14** (Immovable Popup Window): Auto-close works with minimum display time
- **Enhancement #21** (Pause Button): Auto-close timer cancelled on pause button click
- Future: Visual countdown timer could show auto-close countdown
