# Enhancement 30: Separate Timer Check Interval from Popup Display Frequency

- **Description**: Separate the systemd timer check interval (hardcoded to ~5 minutes) from a user-configurable popup display frequency. The timer runs every 5 minutes to check for restricted hours, but popups are only displayed based on the user's configured display frequency (e.g., every 30 minutes, every hour).
- **Files Affected**: `sleep-warning.sh`, `lib/config.sh`, `lib/configure-input-popup.sh`, `lib/configure-config.sh`, `lib/configure-core.sh`, `sleep-warning.timer`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Medium-High (improves minute precision support and user experience)
- **Status**: Not implemented
- **Related**: [Enhancement 16b: 12-Hour Format Time Input with Minute Precision](enhancement-16b-12-hour-format-time-input.md)

## Problem Statement

Currently, `CHECK_INTERVAL` serves two purposes:
1. **Timer frequency**: How often the systemd timer triggers to check for restricted hours
2. **Popup frequency**: How often popups are displayed to the user

This creates a conflict when minute precision is used:
- If `CHECK_INTERVAL=60` and restrictions start at 9:15, the timer only checks at :00 of each hour, so the popup appears at 10:00 (45 minutes late)
- Users who want infrequent popups (e.g., every hour) are forced to use a long timer interval, which delays detection of minute-precision restrictions
- Users who want frequent checks for minute precision are forced to see popups very frequently

## Proposed Solution

Separate these concerns:
1. **Timer Check Interval** (hardcoded, ~5 minutes):
   - Systemd timer runs every 5 minutes to check for restricted hours
   - Ensures minute-precision restrictions are detected within 5 minutes
   - Not user-configurable (hardcoded for reliability)
   - Timer format: `OnCalendar=*:0/5` (triggers at :00, :05, :10, :15, :20, :25, :30, :35, :40, :45, :50, :55)

2. **Popup Display Frequency** (user-configurable):
   - New config option: `POPUP_DISPLAY_FREQUENCY` (in minutes)
   - Controls how often popups are shown, independent of timer checks
   - Default: 10 minutes (can be 1-60 minutes, or 0 for "show every check")
   - The script tracks the last popup display time and only shows a popup if:
     - Current time is within restricted hours, AND
     - Time since last popup >= `POPUP_DISPLAY_FREQUENCY`

## Benefits

1. **Minute Precision Support**: Restrictions starting at 9:15 will be detected within 5 minutes (at 9:15, 9:20, or 9:25), not up to 60 minutes later
2. **User Control**: Users can set infrequent popups (e.g., every 60 minutes) while still having frequent checks
3. **Better UX**: Users aren't forced to choose between timely detection and popup frequency
4. **Backward Compatible**: Existing configs can be migrated (treat `CHECK_INTERVAL` as `POPUP_DISPLAY_FREQUENCY`)

## Implementation Details

### 1. Timer Configuration

- **Hardcode timer interval**: Set `OnCalendar=*:0/5` in `sleep-warning.timer` (or use 1 minute for even better precision)
- **Remove CHECK_INTERVAL from timer updates**: `update_timer_file()` should no longer accept an interval parameter
- **Timer file**: Always uses `OnCalendar=*:0/5` (or `*:0/1` for 1-minute checks)

### 2. Configuration File Changes

- **Remove**: `CHECK_INTERVAL` option (or keep for backward compatibility, but don't use for timer)
- **Add**: `POPUP_DISPLAY_FREQUENCY` option:
  - Format: `POPUP_DISPLAY_FREQUENCY=10` (minutes)
  - Range: 1-60 minutes, or 0 for "show every check" (every 5 minutes)
  - Default: 10 minutes
  - Description: "How often to display warning popups (in minutes). The system checks for restricted hours every 5 minutes, but popups are only shown at this frequency."

### 3. State Tracking

- **Last popup timestamp**: Store in a state file (e.g., `~/.config/sleep-warning/state/last-popup-time`)
- **Format**: Unix timestamp or `YYYY-MM-DD HH:MM:SS` format
- **Location**: `~/.config/sleep-warning/state/` directory (create if needed)
- **File**: `last-popup-time` (contains timestamp of last popup display)

### 4. Logic Changes in `sleep-warning.sh`

```bash
# Pseudo-code for main logic:
main() {
    # ... existing validation and config reading ...
    
    # Check if in restricted hours (existing logic)
    if is_restricted_time; then
        # Check if enough time has passed since last popup
        last_popup_time=$(read_last_popup_time)
        current_time=$(date +%s)
        time_since_last=$((current_time - last_popup_time))
        popup_frequency=$(get_popup_display_frequency)  # in seconds
        
        if [ "$time_since_last" -ge "$popup_frequency" ] || [ -z "$last_popup_time" ]; then
            # Show popup
            show_warning
            
            # Update last popup time
            write_last_popup_time "$current_time"
        else
            # Not enough time has passed, skip popup
            log_message "info" "Skipping popup - only ${time_since_last}s since last (frequency: ${popup_frequency}s)"
        fi
    fi
}
```

### 5. Migration Strategy

- **Backward Compatibility**: 
  - If `CHECK_INTERVAL` exists in config, use it as `POPUP_DISPLAY_FREQUENCY` default
  - If `POPUP_DISPLAY_FREQUENCY` doesn't exist, check for `CHECK_INTERVAL` and use it
  - Show migration message: "CHECK_INTERVAL is now POPUP_DISPLAY_FREQUENCY. Timer checks run every 5 minutes."
- **Config Migration**: 
  - On first run after upgrade, if `CHECK_INTERVAL` exists:
    - Copy value to `POPUP_DISPLAY_FREQUENCY`
    - Optionally remove `CHECK_INTERVAL` (or keep for reference)
    - Show informational message about the change

### 6. Configuration Wizard Updates

- **Remove**: Timer Settings option (or rename to "Popup Display Frequency")
- **Update**: Menu option text: "Popup Display Frequency (how often to show popups)"
- **Validation**: 
  - Range: 1-60 minutes, or 0 for "every check"
  - Show explanation: "The system checks for restricted hours every 5 minutes, but you can control how often popups appear."

### 7. Status Display Updates

- **Remove**: "Check Interval" from status display
- **Add**: "Timer Check Interval: Every 5 minutes (hardcoded)"
- **Add**: "Popup Display Frequency: Every X minutes (user-configurable)"

## Example Scenarios

### Scenario 1: Minute Precision with Infrequent Popups
- **Restrictions**: Start at 9:15
- **Popup Display Frequency**: 30 minutes
- **Behavior**:
  - Timer checks at 9:00, 9:05, 9:10, 9:15, 9:20, 9:25, 9:30...
  - At 9:15: Restricted hour detected, popup shown (first time)
  - At 9:20: Restricted hour detected, but only 5 minutes since last popup → skip
  - At 9:30: Restricted hour detected, 15 minutes since last popup → skip (need 30 minutes)
  - At 9:45: Restricted hour detected, 30 minutes since last popup → popup shown

### Scenario 2: Frequent Popups
- **Restrictions**: Start at 9:15
- **Popup Display Frequency**: 5 minutes
- **Behavior**:
  - Timer checks every 5 minutes
  - Popup shown every 5 minutes when in restricted hours
  - Effectively same as current behavior with `CHECK_INTERVAL=5`

### Scenario 3: Show Every Check
- **Restrictions**: Start at 9:15
- **Popup Display Frequency**: 0 (show every check)
- **Behavior**:
  - Timer checks every 5 minutes
  - Popup shown every 5 minutes when in restricted hours
  - Maximum frequency (every 5 minutes)

## Implementation Checklist

- [ ] Update `sleep-warning.timer` to hardcode `OnCalendar=*:0/5` (or `*:0/1`)
- [ ] Remove `CHECK_INTERVAL` parameter from `update_timer_file()` or make it no-op
- [ ] Add `POPUP_DISPLAY_FREQUENCY` to config file format
- [ ] Create state directory: `~/.config/sleep-warning/state/`
- [ ] Implement `read_last_popup_time()` function
- [ ] Implement `write_last_popup_time()` function
- [ ] Implement `get_popup_display_frequency()` function (with backward compatibility for `CHECK_INTERVAL`)
- [ ] Update `sleep-warning.sh` main logic to check popup frequency before showing popup
- [ ] Update `configure.sh` to remove/rename Timer Settings option
- [ ] Update `lib/configure-input-popup.sh` to add Popup Display Frequency input
- [ ] Update `lib/configure-config.sh` to handle `POPUP_DISPLAY_FREQUENCY` in read/write
- [ ] Update `lib/config.sh` to parse `POPUP_DISPLAY_FREQUENCY` (with `CHECK_INTERVAL` fallback)
- [ ] Update `status.sh` to show timer check interval and popup display frequency
- [ ] Add migration logic for existing `CHECK_INTERVAL` configs
- [ ] Update documentation (user guide, configuration guide)
- [ ] Test minute precision scenarios (restrictions at :15, :30, :45)
- [ ] Test various popup frequencies (1, 5, 10, 15, 30, 60 minutes)
- [ ] Test backward compatibility (existing configs with `CHECK_INTERVAL`)
- [ ] Test state file persistence across reboots
- [ ] Test edge cases (state file missing, corrupted, etc.)

## Technical Considerations

### Timer Interval Choice

- **5 minutes**: Good balance between responsiveness and system load
  - Detects minute-precision restrictions within 5 minutes
  - 12 checks per hour (reasonable system load)
  - Works well with common minute values (:00, :05, :10, :15, :20, :25, :30, :35, :40, :45, :50, :55)
- **1 minute**: Maximum precision
  - Detects restrictions within 1 minute
  - 60 checks per hour (higher system load, but still minimal)
  - Works with any minute precision
- **Recommendation**: Start with 5 minutes, consider 1 minute if users need sub-5-minute precision

### State File Management

- **Location**: `~/.config/sleep-warning/state/last-popup-time`
- **Format**: Unix timestamp (seconds since epoch) for easy comparison
- **Atomic writes**: Use temporary file + rename to avoid corruption
- **Cleanup**: No cleanup needed (file is small, just overwritten)
- **Permissions**: User-readable/writable only (600 permissions)

### Performance Impact

- **Timer frequency**: 5-minute interval = 12 checks/hour = 288 checks/day
- **Script execution**: Each check is very fast (< 1 second)
- **State file I/O**: Single read + optional write per check (negligible)
- **Overall impact**: Minimal system load

### Edge Cases

1. **State file missing**: Treat as "never shown popup" → show immediately
2. **State file corrupted**: Log error, treat as missing → show immediately
3. **System time change**: State file uses absolute timestamps, so time changes are handled correctly
4. **Multiple script instances**: State file locking may be needed if multiple instances could run (unlikely with systemd)
5. **Popup frequency = 0**: Show popup on every check (every 5 minutes)

## Related Enhancements

- **Enhancement 16b**: This enhancement directly addresses the timer interval limitation mentioned in Enhancement 16b's minute precision section
- **Enhancement 9**: System sleep/hibernate detection - state file should persist across sleep/resume
- **Enhancement 21**: Pause functionality - pause should not affect popup frequency tracking (pause suppresses popups, but doesn't reset timer)

## User Experience

### Configuration Wizard

- **Menu Option**: "Popup Display Frequency" (replaces "Timer Settings")
- **Description**: "How often to show warning popups (1-60 minutes). The system checks for restricted hours every 5 minutes automatically."
- **Input**: Number input (1-60) or 0 for "every check"
- **Default**: 10 minutes
- **Help Text**: "The system automatically checks for restricted hours every 5 minutes. This setting controls how often you see popups. For example, if set to 30 minutes, you'll see a popup at most once every 30 minutes, even if you're in restricted hours for longer."

### Status Display

```
Timer Configuration:
  Check Interval: Every 5 minutes (automatic)
  Popup Display Frequency: Every 10 minutes (user-configurable)
```

## Backward Compatibility

- **Existing configs**: `CHECK_INTERVAL` values are migrated to `POPUP_DISPLAY_FREQUENCY`
- **Migration message**: Show one-time message explaining the change
- **Config file**: Keep `CHECK_INTERVAL` for reference (or remove after migration)
- **Script behavior**: If both `CHECK_INTERVAL` and `POPUP_DISPLAY_FREQUENCY` exist, prefer `POPUP_DISPLAY_FREQUENCY`

## Testing Strategy

1. **Unit Tests**:
   - Test `read_last_popup_time()` with missing/corrupted files
   - Test `write_last_popup_time()` atomic writes
   - Test `get_popup_display_frequency()` with various configs

2. **Integration Tests**:
   - Test popup frequency enforcement (show popup, wait, verify next popup timing)
   - Test minute precision detection (restrictions at :15, :30, :45)
   - Test backward compatibility (migrate `CHECK_INTERVAL` to `POPUP_DISPLAY_FREQUENCY`)

3. **Manual Tests**:
   - Configure restrictions at 9:15, set popup frequency to 30 minutes
   - Verify popup appears within 5 minutes of 9:15
   - Verify subsequent popups appear at 30-minute intervals
   - Test various popup frequencies (1, 5, 10, 15, 30, 60 minutes)

## Documentation Updates

- **User Guide**: Explain timer check interval vs popup display frequency
- **Configuration Guide**: Document `POPUP_DISPLAY_FREQUENCY` option
- **Technical Details**: Document state file format and location
- **Migration Guide**: Document how `CHECK_INTERVAL` is migrated
