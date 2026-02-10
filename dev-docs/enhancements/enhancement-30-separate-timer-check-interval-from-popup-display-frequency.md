# Enhancement 30: Separate Timer Check Interval from Popup Display Frequency

- **Description**: Separate the systemd timer run frequency from a user-configurable popup display frequency. The timer run interval is derived from the user's popup setting (5 minutes when popup interval ≥ 5; otherwise equal to popup interval). Only "Popup display frequency" (1–60 minutes) is exposed to the user; the script run frequency is not directly visible.
- **Files Affected**: `sleep-warning.sh`, `lib/config.sh`, `lib/configure-input-popup.sh`, `lib/configure-config.sh`, `lib/configure-core.sh`, `sleep-warning.timer`, `sleep-warning.conf`, `configure.sh`, `install.sh`, `status.sh`
- **Priority**: Medium-High (improves minute precision support and user experience)
- **Status**: Implemented (2026-02-09)
- **Related**: [Enhancement 16b: 12-Hour Format Time Input with Minute Precision](enhancement-16b-12-hour-format-time-input.md)

## Problem Statement

Currently, `CHECK_INTERVAL` serves two purposes:
1. **Timer frequency**: How often the systemd timer triggers to check for restricted hours
2. **Popup frequency**: How often popups are displayed to the user

This creates a conflict when minute precision is used:
- If `CHECK_INTERVAL=60` and restrictions start at 9:15, the timer only checks at :00 of each hour, so the popup appears at 10:00 (45 minutes late)
- Users who want infrequent popups (e.g., every hour) are forced to use a long timer interval, which delays detection of minute-precision restrictions
- Users who want frequent checks for minute precision are forced to see popups very frequently

## Proposed Solution (User-Approved Spec)

Separate these concerns; script run frequency is **not** shown to the user:

1. **Timer / script run frequency** (derived, not user-visible):
   - If popup display frequency is **≥ 5 minutes**: timer runs every **5 minutes**.
   - If popup display frequency is **< 5 minutes** (1–4): timer runs at that same interval (e.g. every 2 minutes if user chose 2).
   - Not displayed in configure wizard or status.

2. **Popup display frequency** (user-configurable, 1–60 minutes only):
   - New config option: `POPUP_DISPLAY_FREQUENCY` (in minutes).
   - Range: **1–60 minutes** (no zero option).
   - Default: 10 minutes.
   - The script tracks the last popup display time and only shows a popup when in restricted hours and time since last popup ≥ `POPUP_DISPLAY_FREQUENCY`.

## Benefits

1. **Minute Precision Support**: Restrictions starting at 9:15 will be detected within 5 minutes (at 9:15, 9:20, or 9:25), not up to 60 minutes later
2. **User Control**: Users can set infrequent popups (e.g., every 60 minutes) while still having frequent checks
3. **Better UX**: Users aren't forced to choose between timely detection and popup frequency
4. **Backward Compatible**: Existing configs can be migrated (treat `CHECK_INTERVAL` as `POPUP_DISPLAY_FREQUENCY`)

## Implementation Details

### 1. Timer Configuration

- **Derived run interval**: `update_timer_file(popup_display_frequency)` computes run_interval = min(5, popup_display_frequency) in effect: if popup_freq ≥ 5 then 5, else popup_freq. Timer file uses `OnCalendar=*:0/run_interval`.
- **Not user-visible**: Status and configure do not show "timer run interval" or "check interval"; only "Popup display frequency" is shown.

### 2. Configuration File Changes

- **Add**: `POPUP_DISPLAY_FREQUENCY` (primary); **migrate from** `CHECK_INTERVAL` for backward compatibility.
- **Popup display frequency**:
  - Format: `POPUP_DISPLAY_FREQUENCY=10` (minutes)
  - Range: **1-60 minutes only** (no zero)
  - Default: 10 minutes
  - Description: "How often to display warning popups (in minutes)."

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
- **Validation**: Range 1-60 minutes only (no zero). Do not expose script run frequency.

### 7. Status Display Updates

- **Remove**: "Check Interval" from status display
- **Show**: "Popup display frequency: Every X minutes" only (do not show timer/script run frequency)

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

### Scenario 3: Most Frequent (5 minutes)
- **Restrictions**: Start at 9:15
- **Popup Display Frequency**: 5 minutes
- **Behavior**:
  - Timer runs every 5 minutes; popup shown every 5 minutes when in restricted hours
  - Effectively maximum user-visible frequency (1-60 range, no zero)

## Implementation Checklist

- [x] Add `get_timer_run_interval(popup_freq)` (min 5 when popup_freq≥5, else popup_freq) and use in timer updates
- [x] Add `POPUP_DISPLAY_FREQUENCY` to config; `update_timer_file(popup_freq)` uses derived run interval
- [x] Create state directory: `~/.config/sleep-warning/state/`
- [x] Implement `read_last_popup_time()` / `write_last_popup_time()`
- [x] Implement `get_popup_display_frequency()` (with `CHECK_INTERVAL` fallback for migration)
- [x] Update `sleep-warning.sh` to check last popup time vs popup frequency before showing popup
- [x] Rename Timer Settings to "Popup display frequency" in configure (menu, input, summary, success)
- [x] Update `lib/configure-config.sh` load/write for `POPUP_DISPLAY_FREQUENCY`
- [x] Update `lib/config.sh` for `POPUP_DISPLAY_FREQUENCY` and `get_timer_run_interval`
- [x] Update `status.sh` to show only "Popup display frequency" (not run interval)
- [x] Update `install.sh` to generate timer using derived run interval from `POPUP_DISPLAY_FREQUENCY`
- [x] Migration: existing `CHECK_INTERVAL` read as fallback for `POPUP_DISPLAY_FREQUENCY`
- [ ] Update docs (user guide, configuration guide)
- [x] Tests updated for POPUP_DISPLAY_FREQUENCY and new UI text (enhancement-09, atomic-write, configure-comprehensive, expect scripts, etc.)

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
