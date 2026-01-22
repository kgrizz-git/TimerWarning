### 21. One-Time Pause Feature (5 or 10 Minutes)
- **Description**: Allow users to pause restrictions for a short period (5 or 10 minutes) once per day, with the pause option available directly from the warning popup. This provides users with flexibility for legitimate exceptions (e.g., finishing a task, handling an emergency) while maintaining overall restriction effectiveness
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Medium (improves user experience and flexibility while maintaining restriction effectiveness)
- **Status**: Not implemented
- **Feasibility Assessment**: ✅ **Highly Feasible** - Simple timer mechanism with state tracking
- **Implementation Approach**:
  - **Popup Button Integration**:
    - Add "Pause for 5 minutes" and/or "Pause for 10 minutes" button to warning popup
    - Use dialog tool's button support (zenity/yad/kdialog support custom buttons)
    - **zenity**: `--extra-button` option for additional buttons
    - **yad**: `--button` option for custom buttons
    - **kdialog**: `--yesno` with custom button labels (limited)
  - **Pause State Tracking**:
    - Store pause state in temporary file: `~/.config/sleep-warning/.pause_state`
    - File contains: pause end timestamp (Unix epoch)
    - `sleep-warning.sh` checks pause state before showing warning
    - If current time < pause end time, skip warning
    - If current time >= pause end time, clear pause state and show warnings normally
  - **Daily Reset**:
    - Track last pause date in pause state file
    - If last pause was on different day, allow new pause
    - If last pause was today, prevent additional pauses (once per day limit)
    - Reset at midnight (new day = new pause available)
- **Implementation Notes**:
  - **Config Options**:
    - `PAUSE_ENABLED=true/false` - Enable/disable pause feature (default: `true`)
    - `PAUSE_DURATION=5|10` - Pause duration in minutes (default: `5`)
    - `PAUSE_ONCE_PER_DAY=true/false` - Limit to one pause per day (default: `true`)
  - **Popup Integration**:
    - **zenity**: `zenity --warning --text="..." --extra-button="Pause 5 min" --extra-button="Pause 10 min"`
    - **yad**: `yad --warning --text="..." --button="Pause 5 min:5" --button="Pause 10 min:10"`
    - **kdialog**: Limited support, may need to use separate dialog for pause option
    - Parse button return code to determine which pause was selected
  - **Pause State File Format**:
    - Simple text file: `PAUSE_END_TIMESTAMP=<unix_timestamp>\nLAST_PAUSE_DATE=YYYY-MM-DD`
    - Example: `PAUSE_END_TIMESTAMP=1704067200\nLAST_PAUSE_DATE=2024-01-01`
  - **Time Check Logic**:
    - Before showing warning, check: `[ -f "$PAUSE_STATE_FILE" ] && [ "$(get_pause_end_time)" -gt "$(date +%s)" ]`
    - If paused, skip warning and log pause status
    - After pause expires, clear pause state file
  - **Daily Reset Logic**:
    - Check last pause date: `LAST_PAUSE_DATE=$(date +%Y-%m-%d)`
    - If last pause date != today, allow new pause
    - If last pause date == today and `PAUSE_ONCE_PER_DAY=true`, prevent additional pauses
  - **Popup Message Update**:
    - If pause is available, show pause buttons in popup
    - If pause already used today, hide pause buttons or show "Pause already used today" message
    - Show remaining pause time if currently paused (in status/logs, not in popup)
- **Safety Assessment**:
  - **Bypass Risk**: Low-Medium - Users can manually edit/delete pause state file, but requires knowledge
  - **Uninstall Safety**: ✅ **Safe** - Pause state file is temporary, uninstall removes it
  - **Data Safety**: ✅ **Safe** - No risk of data loss, pause state is temporary
  - **System Safety**: ✅ **Safe** - No risk to system stability
  - **User Experience**: ✅ **Positive** - Provides flexibility while maintaining restrictions
  - **Effectiveness**: ⚠️ **May Reduce Effectiveness** - Pause feature may be overused, defeating purpose
- **Processing/Memory Burden**:
  - **Minimal** - Only requires file read/write operations and timestamp comparison
  - Pause state file is small (few bytes)
  - No additional processes or continuous monitoring
  - **Memory**: Negligible (no additional memory usage)
  - **CPU**: Negligible (file I/O and timestamp comparison are instant)
- **User Experience Considerations**:
  - **Clear UI**: Pause buttons should be clearly labeled and easy to access
  - **Feedback**: Show confirmation when pause is activated (e.g., "Restrictions paused until [time]")
  - **Status Display**: `manage.sh` or status command could show pause status
  - **Flexibility**: Allow users to configure pause duration (5 or 10 minutes, or custom)
  - **Once Per Day Limit**: Prevents abuse while allowing legitimate exceptions
  - **Popup Integration**: Having pause option in popup itself is most convenient (no need to open separate tool)
- **Edge Cases**:
  - **System Time Changes**: Handle clock adjustments (pause end time should be relative, not absolute)
  - **System Sleep/Resume**: Pause should continue after resume (use relative time, not absolute)
  - **Multiple Pause Attempts**: Prevent multiple pauses if already paused (check pause state before allowing)
  - **Pause Expiration**: Clear pause state when expired, resume normal warnings
  - **Config Changes**: Pause should persist even if config is changed during pause
- **Related**: 
  - Complements restriction system by providing flexibility
  - Could work with "Temporary Disable via Config" (#8) - pause is time-limited, disable is manual
  - Enhances user experience while maintaining restriction effectiveness

---

## Implementation Plan

### Goal
Implement a one-time pause feature that allows users to pause **warning popups** for 5 or 10 minutes once per day, with pause buttons directly accessible from the warning popup window itself.

**Important**: Pause **ONLY** suppresses warning popups. It does **NOT** affect:
- ❌ `configure.sh` blocking (still blocked during restricted hours if `CONFIGURE_BLOCK_ENABLED=true`)
- ❌ `uninstall.sh` protection (still requires verification during restricted hours if `UNINSTALL_PROTECTION_MODE=difficult`)
- ❌ Any other restriction enforcement mechanisms

Pause is a **temporary suppression of warnings only**, not a release of restrictions.

### User Experience Flow
**How users pause from the popup:**
1. User receives warning popup during restricted hours
2. Popup displays pause buttons (e.g., "Pause 5 min" and/or "Pause 10 min") directly in the warning dialog
3. User clicks desired pause button
4. Pause is immediately activated, popup closes
5. User receives confirmation message: "Warning popups paused until [time]"
6. **Warning popups are suppressed** during pause period (no popups shown)
7. **Important**: Restrictions are still active - `configure.sh` blocking and `uninstall.sh` protection still apply
8. After pause expires, warning popups resume normally

**Daily tracking mechanism:**
- Pause state is stored in `~/.config/sleep-warning/.pause_state` file
- File contains two values:
  - `PAUSE_END_TIMESTAMP` - Unix timestamp when pause expires
  - `LAST_PAUSE_DATE` - Date of last pause in YYYY-MM-DD format
- Before allowing a new pause, system checks:
  1. If `PAUSE_ONCE_PER_DAY=true` (config setting)
  2. Compares `LAST_PAUSE_DATE` with today's date (`date +%Y-%m-%d`)
  3. If dates match → pause already used today, block new pause
  4. If dates differ → new day, allow pause
- Daily reset happens automatically at midnight (date comparison handles this)
- If pause expires but same day, `LAST_PAUSE_DATE` remains, preventing additional pauses
- Next day, date comparison allows new pause

### Scope
- **In scope**: Pause state tracking, popup button integration, configuration options, pause state file management, daily reset logic, status display
- **Out of scope**: Multiple pauses per day (beyond once-per-day limit), pause duration customization beyond 5/10 minutes, pause history tracking

### Files to Modify
- `lib/config.sh` - Add pause configuration functions, defaults, and `PAUSE_STATE_FILE` constant
- `lib/pause-state.sh` - **NEW FILE** - Create pause state management functions
- `lib/popup-display.sh` - Add pause button support to warning popup
- `lib/configure-input.sh` - Add pause configuration prompts
- `lib/configure-config.sh` - Add pause config reading/writing
- `lib/configure-display.sh` - Update main menu to include pause configuration option
- `sleep-warning.sh` - Add pause state checking before showing warnings
- `configure.sh` - Add pause configuration menu option (option 9)
- `status.sh` - Add pause status display to configuration section
- `manage.sh` - Add pause status display menu option

### Implementation Phases

#### Phase 1: Configuration Infrastructure
**Goal**: Add pause configuration options to the config system

- [ ] **1.1** Add pause configuration defaults to `lib/config.sh`:
  - [ ] Add `DEFAULT_PAUSE_ENABLED=true`
  - [ ] Add `DEFAULT_PAUSE_DURATION=5` (minutes)
  - [ ] Add `DEFAULT_PAUSE_ONCE_PER_DAY=true`
  - [ ] Add `PAUSE_STATE_FILE="${CONFIG_DIR}/.pause_state"` constant (define in config.sh alongside other path constants)

- [ ] **1.2** Add pause configuration getter functions to `lib/config.sh`:
  - [ ] `get_pause_enabled()` - Returns "true" or "false"
  - [ ] `get_pause_duration()` - Returns pause duration in minutes (5 or 10)
  - [ ] `get_pause_once_per_day()` - Returns "true" or "false"

- [ ] **1.3** Add pause configuration reading to `lib/configure-config.sh`:
  - [ ] Update `load_existing_config()` to read pause settings
  - [ ] Add pause settings to `write_config()` function

- [ ] **1.4** Add pause configuration prompts to `lib/configure-input.sh`:
  - [ ] `get_pause_enabled_config(use_gui)` - Prompt for enable/disable
  - [ ] `get_pause_duration_config(use_gui)` - Prompt for 5 or 10 minutes
  - [ ] `get_pause_once_per_day_config(use_gui)` - Prompt for once-per-day limit

#### Phase 2: Pause State Management
**Goal**: Create pause state file management functions

- [ ] **2.1** Create pause state management functions in new file `lib/pause-state.sh`:
  - [ ] `is_pause_active()` - Check if pause is currently active (returns 0 if active, 1 if not)
    - Reads pause state file
    - Compares current time with pause end timestamp
    - Returns 0 if current time < pause end time, 1 otherwise
  - [ ] `get_pause_end_timestamp()` - Get pause end timestamp from state file (returns Unix timestamp or empty)
  - [ ] `get_last_pause_date()` - Get last pause date from state file (returns YYYY-MM-DD or empty)
  - [ ] `can_pause_today()` - Check if user can pause today (returns 0 if yes, 1 if no)
    - Checks if pause is enabled (`get_pause_enabled()`)
    - If pause disabled, return 1 (cannot pause)
    - Checks if once-per-day limit is enabled (`get_pause_once_per_day()`)
    - If once-per-day disabled, return 0 (can pause)
    - If once-per-day enabled:
      - Get last pause date from state file (`get_last_pause_date()`)
      - Get today's date: `date +%Y-%m-%d`
      - If last pause date is empty or different from today → return 0 (can pause)
      - If last pause date equals today → return 1 (cannot pause, already used today)
  - [ ] `activate_pause(duration_minutes)` - Activate pause for specified duration
    - Calculates pause end timestamp: `current_time + (duration_minutes * 60)`
    - Gets today's date: `date +%Y-%m-%d`
    - Writes pause state file with format:
      ```
      PAUSE_END_TIMESTAMP=<unix_timestamp>
      LAST_PAUSE_DATE=YYYY-MM-DD
      ```
    - Sets file permissions to 0600 (user read/write only)
    - Creates config directory if it doesn't exist
    - Logs pause activation with end time and date
    - Returns 0 on success, 1 on error
  - [ ] `clear_pause_state()` - Clear expired or invalid pause state
    - Removes pause state file if it exists
    - Logs state clearing
  - [ ] `check_and_clear_expired_pause()` - Check if pause expired and clear if needed
    - Called before showing warnings
    - If pause end time < current time, clear pause state

- [ ] **2.2** Add pause state file format validation:
  - [ ] Validate timestamp format (must be numeric)
  - [ ] Validate date format (must be YYYY-MM-DD)
  - [ ] Handle corrupted or invalid state files gracefully (clear and log error)

#### Phase 3: Popup Button Integration
**Goal**: Add pause buttons to warning popup

  - [ ] **3.1** Modify `show_warning()` in `lib/popup-display.sh`:
  - [ ] **Before building message, check if pause is available:**
    - [ ] Call `can_pause_today()` to check if pause can be used today
    - [ ] Get configured pause duration from `get_pause_duration()` (returns 5 or 10)
    - [ ] Determine which pause button to show:
      - If pause available: Show button for configured duration only (if `PAUSE_DURATION=5`, show "Pause 5 min"; if `PAUSE_DURATION=10`, show "Pause 10 min")
      - If pause not available: Don't show pause buttons
    - [ ] **Important**: Pause buttons are available even during minimum display time - clicking pause will immediately close the popup (bypassing minimum display time)
  - [ ] **Add pause buttons directly to warning popup** (user clicks button in the popup window itself):
    - [ ] **zenity**: ✅ **SUPPORTS** `--extra-button` on `--warning` dialogs (NO popup type change needed)
      - Use temporary file to capture stdout (zenity prints button label to stdout when extra button clicked)
      - Add `--extra-button="Pause 5 min"` (if `PAUSE_DURATION=5`)
      - Add `--extra-button="Pause 10 min"` (if `PAUSE_DURATION=10`)
      - Parse exit code: Exit code 1 = extra button clicked
      - Read button label from temporary file (e.g., "Pause 5 min" or "Pause 10 min")
      - Example: `zenity --warning --text="..." --extra-button="Pause 5 min" > /tmp/zenity_output 2>/dev/null`
    - [ ] **yad**: ✅ **SUPPORTS** `--button` on `--warning` dialogs (NO popup type change needed)
      - Add `--button="Pause 5 min:5"` (if `PAUSE_DURATION=5`) - exit code will be 5
      - Add `--button="Pause 10 min:10"` (if `PAUSE_DURATION=10`) - exit code will be 10
      - Parse exit code: Exit code matches button value (5 or 10)
      - Example: `yad --warning --text="..." --button="Pause 5 min:5" --button="OK:0"` (if duration is 5)
    - [ ] **kdialog**: ⚠️ **LIMITED SUPPORT** - `--sorry` (warning) doesn't support custom buttons
      - **Option 1**: Show separate pause selection dialog BEFORE `show_warning()` returns (RECOMMENDED)
        - After `--sorry` dialog closes (user clicks OK), check if pause is available
        - If pause available, show `--menu` dialog with pause options **immediately** (synchronously, blocking)
        - User selects pause duration from menu
        - Activate pause **before** `show_warning()` returns
        - **Why this works**: Pause is activated before script exits, so next timer event (10 min later) will check pause state and skip popup
        - **Window management**: Pause menu dialog appears on top (kdialog dialogs are modal and stay on top by default)
        - **Race condition handling**: Even if timer fires while pause menu is open, new script run will check pause state first and skip popup
      - **Option 2**: Disable pause feature when kdialog is the only available tool
        - If only kdialog available and pause buttons needed, show warning without pause option
        - Log that pause is unavailable due to kdialog limitations
      - **Option 3**: Add pause instructions in message text (fallback)
        - Include text like "To pause warnings, use: manage.sh --pause" (if manage.sh supports pause command)
      - **Recommended**: Use Option 1 (separate dialog shown synchronously before function returns)
  - [ ] **Handle pause button clicks** (when user clicks pause button in popup):
    - [ ] Parse which pause duration was selected from button click
    - [ ] Call `activate_pause(duration)` with selected duration
    - [ ] Calculate pause end time for display: `date -d "@${pause_end_timestamp}" +"%H:%M"`
    - [ ] **Close warning popup immediately** (even if minimum display time is active - pause bypasses minimum display time)
    - [ ] Show confirmation dialog using same dialog tool as warning popup: "Warning popups paused until [HH:MM]"
    - [ ] Log pause activation with timestamp and duration
    - [ ] Return early from `show_warning()` (don't wait for popup close)
  - [ ] **Handle kdialog pause menu** (after warning popup closes):
    - [ ] After `--sorry` dialog closes, check if pause is available (`can_pause_today()`)
    - [ ] If pause available, show `--menu` dialog **synchronously** (blocking, before function returns)
    - [ ] User selects pause duration from menu
    - [ ] **If user cancels menu dialog**: Treat as if no pause was selected (normal flow, no pause activated)
    - [ ] **If user selects pause duration**: Activate pause **immediately** (before `show_warning()` returns)
    - [ ] Show confirmation dialog using same dialog tool (kdialog): "Warning popups paused until [HH:MM]"
    - [ ] Log pause activation
    - [ ] **Critical**: Pause must be activated before script exits, so next timer event sees pause state

- [ ] **3.2** Update popup message based on pause availability:
  - [ ] If pause already used today and `PAUSE_ONCE_PER_DAY=true`:
    - [ ] Optionally add message: "Pause already used today"
    - [ ] Don't show pause buttons
  - [ ] If pause is disabled:
    - [ ] Don't show pause buttons
  - [ ] If pause is currently active:
    - [ ] Don't show warning popup at all (handled in main script)

#### Phase 4: Main Script Integration
**Goal**: Integrate pause checking into main warning logic

- [ ] **4.1** Modify `sleep-warning.sh` main function:
  - [ ] Before checking restricted hours, call `check_and_clear_expired_pause()`
  - [ ] After determining if hour is restricted, check pause state:
    - [ ] If `is_pause_active()` returns 0 (pause active):
      - [ ] Skip showing warning popup
      - [ ] Log pause status: "Pause active, skipping warning popup"
      - [ ] Exit normally (return 0)
      - [ ] **IMPORTANT**: Pause only suppresses popup - restrictions are still active
      - [ ] **IMPORTANT**: `configure.sh` and `uninstall.sh` blocking still apply (pause does NOT affect them)
  - [ ] Only show warning if hour is restricted AND pause is not active
  - [ ] **Documentation**: Add comment clarifying that pause only affects popup display, not restriction enforcement

- [ ] **4.2** Source pause state management module:
  - [ ] Add `source "${LIB_DIR}/pause-state.sh"` to script sourcing section
  - [ ] Ensure pause-state.sh sources config.sh and logging.sh

#### Phase 5: Configuration Wizard Integration
**Goal**: Add pause configuration to configure.sh

- [ ] **5.1** Add pause configuration menu option to `configure.sh`:
  - [ ] Add "Enable pause and configure duration" as menu option 9 (current option 9 "Uninstall Protection Configuration" becomes option 10)
  - [ ] Update `show_main_menu()` in `lib/configure-display.sh` to include new menu item
  - [ ] Add case statement in `configure.sh` main loop to handle menu option 9
  - [ ] Call pause configuration functions from `lib/configure-input.sh`:
    - [ ] `get_pause_enabled_config(use_gui)` - Enable/disable pause feature
    - [ ] `get_pause_duration_config(use_gui)` - Set duration (5 or 10 minutes)
    - [ ] `get_pause_once_per_day_config(use_gui)` - Enable/disable once-per-day limit

- [ ] **5.2** Update configuration workflow:
  - [ ] Add pause settings to configuration summary display
  - [ ] Include pause settings in config file write operations

#### Phase 6: Status Display (Optional Enhancement)
**Goal**: Show pause status in status/manage commands

- [ ] **6.1** Add pause status to `status.sh`:
  - [ ] Source `lib/pause-state.sh` if available
  - [ ] Add pause status section to `show_configuration()` function
  - [ ] Check if pause is active using `is_pause_active()`
  - [ ] Display pause end time if active (formatted as HH:MM)
  - [ ] Display last pause date
  - [ ] Display whether pause is available today using `can_pause_today()`
  - [ ] Display pause configuration (enabled/disabled, duration, once-per-day setting)

- [ ] **6.2** Add pause status to `manage.sh`:
  - [ ] Source `lib/pause-state.sh` if available
  - [ ] Add "View Pause Status" menu option to both GUI and text menus
  - [ ] Create `view_pause_status()` function that displays:
    - [ ] Whether pause is currently active
    - [ ] Pause end time if active
    - [ ] Last pause date
    - [ ] Whether pause is available today
    - [ ] Current pause configuration settings

#### Phase 7: Testing
**Goal**: Comprehensive testing of pause feature

- [ ] **7.1** Create test script `tests/test-pause-feature.sh`:
  - [ ] Test pause state file creation and reading
  - [ ] Test pause activation with 5 and 10 minute durations
  - [ ] Test pause expiration and auto-clearing
  - [ ] Test once-per-day limit enforcement
  - [ ] Test pause button clicks in popup (zenity/yad/kdialog)
  - [ ] Test warning suppression during active pause
  - [ ] Test daily reset (simulate date change)
  - [ ] Test edge cases:
    - [ ] System time changes during pause
    - [ ] Corrupted pause state file
    - [ ] Missing pause state file
    - [ ] Pause state file with invalid format

- [ ] **7.2** Manual testing checklist:
  - [ ] Enable pause feature via configure.sh
  - [ ] Set pause duration to 5 minutes (default)
  - [ ] Trigger warning during restricted hours
  - [ ] **Verify pause buttons appear in warning popup window**
  - [ ] Click "Pause 5 min" button directly in the popup
  - [ ] Verify popup closes immediately after pause activation
  - [ ] Verify confirmation message appears: "Restrictions paused until [time]"
  - [ ] Verify warning doesn't appear for 5 minutes
  - [ ] Verify warning resumes after 5 minutes
  - [ ] **Test daily tracking**: Try to pause again same day (should be blocked if once-per-day enabled)
  - [ ] **Test daily reset**: Wait until next day (or manually change date), verify pause is available again
  - [ ] Verify `LAST_PAUSE_DATE` in pause state file matches date when pause was used
  - [ ] Test with 10 minute duration
  - [ ] Test with pause disabled (buttons should not appear)
  - [ ] Test with once-per-day disabled (multiple pauses allowed same day)

#### Phase 8: Documentation
**Goal**: Update documentation for pause feature

- [ ] **8.1** Update user documentation:
  - [ ] Add pause feature description to `user-docs/USER_GUIDE.md`
  - [ ] Add pause configuration instructions to `user-docs/CONFIGURATION.md`
  - [ ] Update README.md with pause feature mention

- [ ] **8.2** Update developer documentation:
  - [ ] Document pause state file format
  - [ ] Document pause state management functions
  - [ ] Add pause feature to technical details

### Implementation Notes

#### Pause State File Location and Daily Tracking
- **File**: `~/.config/sleep-warning/.pause_state`
- **Format**:
  ```
  PAUSE_END_TIMESTAMP=1704067200
  LAST_PAUSE_DATE=2024-01-01
  ```
- **Permissions**: 0600 (read/write for user only)
- **Daily Tracking Logic**:
  - `LAST_PAUSE_DATE` stores the date (YYYY-MM-DD) when pause was last used
  - Before allowing pause, system compares `LAST_PAUSE_DATE` with today's date
  - If dates match → pause already used today (if `PAUSE_ONCE_PER_DAY=true`)
  - If dates differ → new day, allow pause
  - Date comparison automatically handles midnight rollover (new day = new pause available)
  - `PAUSE_END_TIMESTAMP` tracks when current pause expires (if pause is active)
  - Both values are updated when pause is activated
- **Auto-cleared**: When pause expires, only `PAUSE_END_TIMESTAMP` is cleared; `LAST_PAUSE_DATE` persists until the next day (even if pause expires on the same day, `LAST_PAUSE_DATE` remains to enforce once-per-day limit)

#### Dialog Tool Button Handling
- **zenity**: ✅ **SUPPORTS** `--extra-button` on `--warning` dialogs
  - Exit code 1 when extra button clicked
  - Button label printed to stdout (e.g., "Pause 5 min")
  - **Implementation**: Use temporary file to capture stdout (zenity output redirected to temp file, then read button label from file)
  - **NO popup type change needed** - works with existing `--warning` dialog
- **yad**: ✅ **SUPPORTS** `--button` on `--warning` dialogs
  - Exit code matches button value (e.g., 5 for "Pause 5 min:5", 10 for "Pause 10 min:10")
  - **NO popup type change needed** - works with existing `--warning` dialog
- **kdialog**: ⚠️ **LIMITED** - `--sorry` (warning) doesn't support custom buttons
  - **Workaround**: Show separate `--menu` dialog after main popup for pause selection
  - Alternative: Add pause instructions in message text

#### Time Handling
- Use Unix timestamps (seconds since epoch) for pause end time
- Use `date +%s` for current time
- Use `date +%Y-%m-%d` for date comparison
- Handle system time changes gracefully (relative time calculation)

#### Edge Cases
1. **System time changes**: Pause duration is calculated at activation time, so time changes won't affect pause duration (it's relative)
2. **System sleep/resume**: Pause continues after resume (uses absolute timestamps)
3. **Multiple pause attempts**: Check `can_pause_today()` before allowing pause
4. **Pause expiration**: Auto-clear on next warning check; `LAST_PAUSE_DATE` persists until next day even if pause expires same day
5. **Config changes during pause**: Pause persists (state file independent of config)
6. **Timer race condition (kdialog)**: If timer fires while pause menu is open, new script run will check pause state first and skip popup (pause is activated before script exits)
7. **Popup recreation**: Warning popup is recreated every CHECK_INTERVAL (default 10 min) by timer. Pause check happens BEFORE showing popup, so paused state prevents new popups.
8. **Minimum display time**: Pause buttons are available even during minimum display time; clicking pause immediately closes popup (bypasses minimum display time)
9. **kdialog menu cancellation**: If user cancels pause menu dialog, treat as normal flow (no pause activated)
10. **zenity stdout capture**: Use temporary file to capture button label from stdout (zenity output redirected to temp file)

### Testing Strategy

#### Unit Tests
- Test pause state file read/write operations
- Test pause activation and expiration logic
- Test daily reset logic
- Test configuration reading/writing

#### Integration Tests
- Test popup button integration with all dialog tools
- Test warning suppression during active pause
- Test pause button visibility based on configuration

#### Manual Tests
- Test full user workflow: configure → trigger warning → pause → verify suppression
- Test edge cases: time changes, corrupted files, etc.
- Test on different desktop environments (GNOME, KDE, gamescope)

### Success Criteria
- [ ] Users can pause **warning popups** for 5 or 10 minutes from warning popup
- [ ] Pause is limited to once per day (if enabled)
- [ ] **Warning popups are suppressed** during active pause
- [ ] **`configure.sh` blocking still works** during pause (pause does NOT affect it)
- [ ] **`uninstall.sh` protection still works** during pause (pause does NOT affect it)
- [ ] Pause state persists across script runs
- [ ] Pause expires automatically after duration
- [ ] Daily reset works correctly (new pause available each day)
- [ ] Configuration options work correctly
- [ ] zenity/yad support pause buttons directly in warning popup
- [ ] kdialog workaround works (separate menu dialog or disabled pause)
- [ ] Edge cases are handled gracefully
- [ ] Documentation clearly explains what pause affects (popups only, not restrictions)

### Key Design Decisions

**1. Default Pause Duration: 5 minutes**
- Default is set to 5 minutes (not 10) for shorter, more focused pause periods
- Users can configure to 10 minutes if desired
- **Only the configured duration button is shown** in the popup (if `PAUSE_DURATION=5`, show only "Pause 5 min"; if `PAUSE_DURATION=10`, show only "Pause 10 min")

**2. Pause from Popup Window: YES**
- **Users pause directly from the warning popup window itself**
- Pause button appears as additional button in the warning dialog (shows configured duration only: "Pause 5 min" if `PAUSE_DURATION=5`, or "Pause 10 min" if `PAUSE_DURATION=10`)
- No need to open separate tool or menu - one-click pause from the warning
- **Pause buttons are available even during minimum display time** - clicking pause immediately closes the popup (bypasses minimum display time enforcement)
- Popup closes immediately after pause is activated
- Confirmation message shows pause end time (using same dialog tool as warning popup)
- **Exception**: kdialog requires separate menu dialog (warning closes first, then menu appears); if user cancels menu, no pause is activated

**3. What Pause Affects: WARNING POPUPS ONLY**
- ✅ **Pause suppresses warning popups** - no popups shown during pause period
- ❌ **Pause does NOT affect `configure.sh` blocking** - still blocked during restricted hours if `CONFIGURE_BLOCK_ENABLED=true`
- ❌ **Pause does NOT affect `uninstall.sh` protection** - still requires verification during restricted hours if `UNINSTALL_PROTECTION_MODE=difficult`
- ❌ **Pause does NOT release any restrictions** - restrictions are still active, only warnings are suppressed
- **Rationale**: Pause is a temporary "quiet period" for warnings, not a release of restrictions. This maintains restriction effectiveness while providing flexibility.

**4. Daily Tracking Mechanism:**
- **State file**: `~/.config/sleep-warning/.pause_state`
- **Two values tracked**:
  - `PAUSE_END_TIMESTAMP` - When current pause expires (Unix timestamp)
  - `LAST_PAUSE_DATE` - Date when pause was last used (YYYY-MM-DD format)
- **Daily check logic**:
  1. When user tries to pause, system reads `LAST_PAUSE_DATE` from state file
  2. Gets today's date: `date +%Y-%m-%d`
  3. Compares dates:
     - If `LAST_PAUSE_DATE == today` → pause already used today, block new pause
     - If `LAST_PAUSE_DATE != today` or empty → new day, allow pause
  4. When pause is activated, updates both:
     - `PAUSE_END_TIMESTAMP` = current_time + pause_duration
     - `LAST_PAUSE_DATE` = today's date
- **Automatic daily reset**: Date comparison automatically handles midnight (new day = new pause available)
- **Pause expiration**: When pause expires, only `PAUSE_END_TIMESTAMP` is cleared; `LAST_PAUSE_DATE` remains until the next day (even if pause expires on the same day, `LAST_PAUSE_DATE` persists to prevent additional pauses if once-per-day limit is enabled)

### Related Documentation

Additional supporting documents for this enhancement are located in the `enhancement-21/` subfolder:

- **Dialog Button Support Analysis**: `enhancement-21/dialog-button-support.md` - Detailed analysis of button support for zenity, yad, and kdialog
- **Integration Difficulty Assessment**: `enhancement-21/integration-difficulty-assessment.md` - Phase-by-phase difficulty analysis and implementation recommendations
- **Pause Scope Clarification**: `enhancement-21/pause-scope-clarification.md` - Detailed explanation of what pause affects and what it doesn't
- **kdialog Pause Timing**: `enhancement-21/kdialog-pause-timing.md` - Timing and race condition handling for kdialog workaround

### Approval Needed
Please review and approve this implementation plan before proceeding with development.
