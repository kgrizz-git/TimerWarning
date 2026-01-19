# Enhancement 22: Prevent 24/7 Restriction Configuration

- **Description**: Add validation in `configure.sh` to detect and prevent users from configuring restricted hours that cover 24 hours a day, 7 days a week (or close to it). This prevents users from accidentally locking themselves out of their computer. The validation must evaluate the entire configuration holistically (not just individual days) to account for overnight time ranges that span multiple days. **Critical**: When counting restricted minutes, the system must detect and merge overlapping intervals both within the same day (e.g., "0-10,9-23" overlaps at hour 9) and across day boundaries due to overnight ranges (e.g., Monday "23-6" and Tuesday "0-5" overlap). If 24/7 restrictions (>= 10080 minutes) are detected, show a prominent error dialog and block saving. If restrictions exceed 9660 minutes (23 hours/day), show a warning dialog and allow user to confirm or modify. Automatically disable config file locking (if implemented) and ensure configure.sh is not blocked during restricted hours.
- **Files Affected**: `configure.sh`, `sleep-warning.sh`, `sleep-warning.conf`
- **Priority**: High (critical safety feature to prevent accidental lockout)
- **Status**: Not implemented
- **Feasibility Assessment**: ✅ **Highly Feasible** - Time range calculation and validation logic
- **Implementation Approach**:
  - **Holistic Time Coverage Analysis**:
    - After user completes configuration, analyze all 7 days together
    - Convert all time ranges to a unified timeline (e.g., minutes since start of week)
    - Account for overnight ranges that span midnight (e.g., "22:00-06:00" covers 8 hours across two days)
    - Calculate total restricted minutes across the entire week
    - If total restricted minutes >= 10080 (7 days × 24 hours × 60 minutes = 10080), configuration is 24/7
  - **Validation Trigger**:
    - Run validation check in `configure.sh` before saving configuration
    - Check occurs after all day/time configurations are collected
    - Validation runs regardless of whether GUI or text mode is used
  - **Warning and Protection**:
    - If 24/7 detected, show prominent warning dialog (error dialog, not just info)
    - Prevent saving the configuration (require user to modify settings)
    - Automatically set `CONFIG_LOCK_ENABLED=false` (if config locking is implemented)
    - Ensure `CONFIGURE_BLOCK_ENABLED=false` (if configure.sh blocking is implemented)
    - Provide clear explanation of why 24/7 restrictions are problematic
- **Implementation Notes**:
  - **Time Range Calculation**:
    - For each day, parse time ranges (e.g., "22:00-06:00", "14:00-16:00")
    - Convert to minutes since start of day (e.g., 22:00 = 1320 minutes, 06:00 = 360 minutes)
    - For overnight ranges (end < start), split into two segments:
      - Segment 1: start time to end of day (23:59)
      - Segment 2: start of day (00:00) to end time
    - Map each segment to a unified weekly timeline (day 0-6, minutes 0-10079)
  - **Coverage Calculation**:
    - Create array or set of all restricted minute intervals for the week
    - **Critical: Detect and merge overlapping intervals**:
      - **Within the same day**: Multiple ranges on the same day may overlap (e.g., "0-10,9-23" overlaps at hours 9-10)
      - **Across day boundaries**: Overnight ranges may overlap with next day's ranges (e.g., Monday "23-6" and Tuesday "0-5" overlap at hours 0-5)
    - Merge all overlapping intervals to avoid double-counting
    - Count total unique restricted minutes after merging
    - If count >= 10080 (24/7), block configuration with error dialog
    - If count > 9660 (23 hours/day), show warning dialog (user can confirm or modify)
  - **Validation Function**:
    ```bash
    # Pseudocode
    check_restriction_coverage() {
      total_restricted_minutes = 0
      restricted_intervals = []
      
      for each day (Mon-Sun):
        day_intervals = []
        for each time_range in day:
          if time_range is overnight (end < start):
            # Split overnight range into two segments
            add interval [start, 23:59] for current day to day_intervals
            add interval [00:00, end] for next day to restricted_intervals (map to next day)
          else:
            add interval [start, end] for current day to day_intervals
        
        # Merge overlaps within the same day first (e.g., "0-10,9-23" → "0-23")
        day_intervals = merge_overlapping_intervals(day_intervals)
        restricted_intervals.extend(day_intervals)
      
      # Merge overlaps across day boundaries (e.g., Monday "23-6" and Tuesday "0-5")
      restricted_intervals = merge_overlapping_intervals(restricted_intervals)
      total_restricted_minutes = sum of all interval lengths
      
      if total_restricted_minutes >= 10080:
        return "block"  # 24/7 detected - block configuration
      elif total_restricted_minutes > 9660:
        return "warn"  # > 23 hours/day - show warning, allow confirmation
      else:
        return "ok"  # Valid configuration
    }
    ```
  - **Error Dialog (24/7 detected, >= 10080 minutes)**:
    - Use error dialog (not warning/info) for maximum visibility
    - Title: "24/7 Restrictions Detected - Configuration Blocked"
    - Message should explain:
      - "You have configured restrictions for all 24 hours, 7 days a week."
      - "This would effectively lock you out of your computer."
      - "Please modify your settings to leave at least some unrestricted time."
      - "Config file locking and configure.sh blocking have been automatically disabled for your safety."
    - Dialog should be modal and require user acknowledgment
    - After acknowledgment, return to configuration (don't save, block write_config())
  
  - **Warning Dialog (> 9660 minutes, > 23 hours/day)**:
    - Use warning dialog (not error) - less severe but still important
    - Title: "Very High Restriction Level Detected"
    - Message should explain:
      - "You have configured restrictions for more than 23 hours per day, 7 days a week."
      - "This leaves very little unrestricted time and may effectively lock you out."
      - "Are you sure you want to save this configuration?"
      - "Config file locking and configure.sh blocking have been automatically disabled for your safety."
    - Dialog should offer two options:
      - "Yes, Save Anyway" - proceed with saving (user acknowledges risk)
      - "No, Modify Settings" - return to configuration menu
    - If user confirms, allow saving but log the high restriction level
  - **Automatic Safety Overrides**:
    - When restrictions >= 10080 minutes (24/7) OR > 9660 minutes (23 hours/day) detected, automatically set in configuration:
      - `CONFIG_LOCK_ENABLED=false` (prevents config file locking)
      - `CONFIGURE_BLOCK_ENABLED=false` (prevents configure.sh blocking)
    - These overrides should be applied even if user previously enabled them
    - Add comment in config file explaining why these are disabled:
      - For 24/7: "# CONFIG_LOCK_ENABLED and CONFIGURE_BLOCK_ENABLED are disabled because 24/7 restrictions were detected."
      - For > 9660: "# CONFIG_LOCK_ENABLED and CONFIGURE_BLOCK_ENABLED are disabled because restrictions exceed 23 hours/day."
  - **Edge Cases**:
    - **Overnight Ranges**: Must correctly handle ranges like "22:00-06:00" that span midnight
    - **Overlapping Ranges**: Must merge overlapping intervals correctly (e.g., "22:00-06:00" and "05:00-07:00")
    - **Multiple Ranges Per Day**: Must account for all ranges on each day
    - **Boundary Cases**: Exactly 10080 minutes (24/7) vs 10079 minutes (not 24/7)
    - **Empty Days**: Days with no restrictions should be counted as unrestricted
  - **Validation Timing**:
    - Run validation after all configuration is collected but before writing to file
    - In GUI mode: validate before closing final dialog
    - In text mode: validate after all prompts are completed
    - If validation fails, allow user to go back and modify settings
- **Safety Assessment**:
  - **Bypass Risk**: Low - Validation runs in configure.sh, user would need to manually edit config file to bypass
  - **Uninstall Safety**: ✅ **Safe** - Does not affect uninstall process
  - **Data Safety**: ✅ **Safe** - No risk of data loss, only prevents saving invalid config
  - **System Safety**: ✅ **Safe** - Prevents dangerous configuration, improves safety
  - **User Experience**: ✅ **Positive** - Prevents accidental lockout, clear warning message
  - **Effectiveness**: ✅ **High** - Effectively prevents 24/7 configuration
- **Processing/Memory Burden**:
  - **Minimal** - Time range calculation is simple arithmetic
  - Validation runs once per configuration save (not continuously)
  - No additional processes or continuous monitoring
  - **Memory**: Negligible (small arrays for time intervals)
  - **CPU**: Negligible (simple calculations, runs only during configuration)
- **User Experience Considerations**:
  - **Clear Warning**: Error dialog should be prominent and clearly explain the problem
  - **Helpful Guidance**: Suggest that users need at least some unrestricted time
  - **Automatic Protection**: Automatically disabling config locking and configure.sh blocking provides safety net
  - **Non-Blocking**: User can still modify configuration after seeing warning (just can't save 24/7 config)
  - **Transparency**: Config file comment explains why safety features are disabled
- **Edge Cases**:
  - **System Time Changes**: Not applicable (validation is based on configuration, not system time)
  - **System Sleep/Resume**: Not applicable (validation runs during configuration, not during runtime)
  - **Manual Config Editing**: User could manually edit config file to create 24/7 restrictions, but this requires deliberate action (not accidental)
  - **Partial 24/7**: What if user configures 24/7 for 6 days but not 7? Current requirement is full 24/7 (all 7 days), but could be extended to warn about very high restriction percentages (e.g., >95% of week)
  - **Multiple Time Ranges**: Must correctly handle days with multiple time ranges (e.g., "09:00-12:00,14:00-18:00")
- **Related**: 
  - **Enhancement 18 (Config File Locking)**: This enhancement automatically disables config file locking if 24/7 restrictions are detected
  - **Enhancement 19 (Prevent configure.sh Execution)**: This enhancement automatically disables configure.sh blocking if 24/7 restrictions are detected
  - **Enhancement 20 (Additional Hours for Config Locking)**: Should also be disabled if 24/7 restrictions are detected
  - **Safety Feature**: Complements other safety features by preventing the most dangerous configuration scenario

## Implementation Checklist

### Phase 1: Core Validation Function
- [ ] **Create `check_restriction_coverage()` function** in `configure.sh`
  - [ ] Function accepts config_lines array (or summary_lines) as input
  - [ ] Iterate through all 7 days (indices 0-6: Sunday-Saturday)
  - [ ] For each day, parse time ranges from config (handle empty/skipped days)
  - [ ] For each time range on each day:
    - [ ] Parse range format: "START-END" or "START-END,START-END"
    - [ ] Handle normal ranges (start < end): convert to minutes within same day
    - [ ] Handle overnight ranges (start > end): split into two segments:
      - [ ] Segment 1: start hour to 23:59 on current day
      - [ ] Segment 2: 00:00 to end hour on next day (handle wrap-around: Saturday → Sunday)
  - [ ] Convert each segment to unified weekly timeline (minutes 0-10079)
    - [ ] Day 0 (Sunday): minutes 0-1439
    - [ ] Day 1 (Monday): minutes 1440-2879
    - [ ] Day 2 (Tuesday): minutes 2880-4319
    - [ ] Day 3 (Wednesday): minutes 4320-5759
    - [ ] Day 4 (Thursday): minutes 5760-7199
    - [ ] Day 5 (Friday): minutes 7200-8639
    - [ ] Day 6 (Saturday): minutes 8640-10079
  - [ ] **CRITICAL: Merge overlaps within the same day first**
    - [ ] For each day, collect all intervals for that day
    - [ ] Merge overlapping intervals within the day (e.g., "0-10,9-23" → "0-23")
    - [ ] Example: Monday "0-10,9-23" should merge to "0-23" (24 hours) before counting
  - [ ] Store all intervals as [start_minute, end_minute] pairs
  - [ ] **CRITICAL: Merge overlapping intervals across day boundaries**
    - [ ] Merge overlaps between days (e.g., Monday "23-6" and Tuesday "0-5" overlap at hours 0-5)
    - [ ] Handle wrap-around: Saturday overnight ranges may overlap with Sunday ranges
  - [ ] Calculate total restricted minutes across all merged intervals
  - [ ] Return "block" if total >= 10080 (24/7), "warn" if total > 9660 (23 hours/day), "ok" otherwise

- [ ] **Implement interval merging logic**
  - [ ] **Two-phase merging approach**:
    - [ ] **Phase 1: Within-day merging** - Merge overlaps within each day first
      - [ ] For each day, collect all intervals for that day
      - [ ] Sort intervals by start minute
      - [ ] Merge overlapping/adjacent intervals within the day
      - [ ] Example: "0-10,9-23" → [0, 600] and [540, 1380] → [0, 1380] (24 hours)
    - [ ] **Phase 2: Cross-day merging** - Merge overlaps across day boundaries
      - [ ] Collect all intervals (after within-day merging) into single array
      - [ ] Sort intervals by start minute (across entire week)
      - [ ] Merge overlapping/adjacent intervals across day boundaries
      - [ ] Example: Monday [1320, 1440] (23-0) and Tuesday [0, 300] (0-5) → [1320, 1740]
  - [ ] Handle wrap-around intervals (Saturday overnight → Sunday)
  - [ ] Calculate total minutes from merged intervals (avoid double-counting)

- [ ] **Handle edge cases in validation**
  - [ ] Empty days (no restrictions) - count as 0 restricted minutes
  - [ ] Days with empty string "" (explicitly skipped) - count as 0 restricted minutes
  - [ ] Multiple ranges per day (e.g., "0-5,22-23") - process all ranges
  - [ ] **Overlapping ranges within same day** (e.g., "0-10,9-23" should merge to "0-23") - CRITICAL
  - [ ] **Overlapping ranges across day boundaries** (e.g., Monday "23-6" and Tuesday "0-5" overlap) - CRITICAL
  - [ ] Overnight ranges that wrap around week (Saturday 23-6 → Sunday)
  - [ ] Boundary cases: exactly 10080 minutes (24/7) vs 10079 minutes (not 24/7)
  - [ ] Boundary cases: exactly 9660 minutes (23 hours/day) vs 9661 minutes (should warn)

### Phase 2: Integration into configure.sh
- [ ] **Add validation call before saving**
  - [ ] Locate `write_config()` function in `configure.sh`
  - [ ] Add validation check at start of `write_config()` function
  - [ ] Call `check_restriction_coverage()` with current config_lines array
  - [ ] Handle three return values: "block" (>= 10080), "warn" (> 9660), "ok" (valid)

- [ ] **Create error dialog function (24/7 detected)**
  - [ ] Create `show_24_7_error()` function
  - [ ] Support both GUI mode (zenity) and text mode
  - [ ] Use error dialog (not warning/info) for maximum visibility
  - [ ] Title: "24/7 Restrictions Detected - Configuration Blocked"
  - [ ] Message includes:
    - [ ] "You have configured restrictions for all 24 hours, 7 days a week."
    - [ ] "This would effectively lock you out of your computer."
    - [ ] "Please modify your settings to leave at least some unrestricted time."
    - [ ] "Config file locking and configure.sh blocking have been automatically disabled for your safety."
  - [ ] Dialog is modal and requires user acknowledgment
  - [ ] After acknowledgment, return to configuration menu (don't save)

- [ ] **Create warning dialog function (> 9660 minutes)**
  - [ ] Create `show_high_restriction_warning()` function
  - [ ] Support both GUI mode (zenity) and text mode
  - [ ] Use warning dialog (not error) - less severe but still important
  - [ ] Title: "Very High Restriction Level Detected"
  - [ ] Message includes:
    - [ ] "You have configured restrictions for more than 23 hours per day, 7 days a week."
    - [ ] "This leaves very little unrestricted time and may effectively lock you out."
    - [ ] "Are you sure you want to save this configuration?"
    - [ ] "Config file locking and configure.sh blocking have been automatically disabled for your safety."
  - [ ] Dialog offers two options:
    - [ ] "Yes, Save Anyway" - proceed with saving (user acknowledges risk)
    - [ ] "No, Modify Settings" - return to configuration menu
  - [ ] If user confirms, allow saving but log the high restriction level

- [ ] **Update write_config() to handle validation results**
  - [ ] If validation returns "block", call `show_24_7_error()` and return error (prevent saving)
  - [ ] If validation returns "warn", call `show_high_restriction_warning()`:
    - [ ] If user confirms, proceed with saving
    - [ ] If user cancels, return to configuration menu (don't save)
  - [ ] If validation returns "ok", proceed with normal save
  - [ ] Ensure config file is NOT written if validation blocks or user cancels warning

- [ ] **Integrate validation into save flow**
  - [ ] Locate "Review and Save" option (menu choice 6) in main() function
  - [ ] Ensure validation runs after user confirms save but before `write_config()` is called
  - [ ] Or integrate validation inside `write_config()` (preferred - single point of validation)
  - [ ] If validation fails, show warning and return to menu (don't exit)

### Phase 3: Automatic Safety Overrides
- [ ] **Disable config locking features when high restrictions detected**
  - [ ] When restrictions >= 10080 minutes (24/7) OR > 9660 minutes (23 hours/day) detected, automatically set in memory (before write):
    - [ ] `CONFIG_LOCK_ENABLED=false` (if enhancement #18 is implemented)
    - [ ] `CONFIGURE_BLOCK_ENABLED=false` (if enhancement #19 is implemented)
    - [ ] `CONFIG_LOCK_ADDITIONAL_HOURS=""` (if enhancement #20 is implemented)
  - [ ] These overrides apply even if user previously enabled them
  - [ ] Add comment in config file explaining why these are disabled:
    - [ ] For 24/7 (>= 10080): "# CONFIG_LOCK_ENABLED and CONFIGURE_BLOCK_ENABLED are disabled because 24/7 restrictions were detected. This prevents accidental lockout."
    - [ ] For > 9660: "# CONFIG_LOCK_ENABLED and CONFIGURE_BLOCK_ENABLED are disabled because restrictions exceed 23 hours/day. This prevents accidental lockout."

- [ ] **Handle conditional implementation**
  - [ ] Check if config locking features exist before trying to disable them
  - [ ] Use feature detection (check if variables/functions exist) rather than hardcoding
  - [ ] If features don't exist yet, validation still works (just skip override step)

### Phase 4: Testing
- [ ] **Test normal configurations (validation should pass, allow saving)**
  - [ ] **Note**: "should pass" means the validation should allow the configuration to be saved (no 24/7 detected, write_config() succeeds)
  - [ ] Test with no restrictions (all days empty)
  - [ ] Test with partial restrictions (e.g., only weekdays 0-5)
  - [ ] Test with weekend-only restrictions
  - [ ] Test with single day restrictions
  - [ ] Test with overnight ranges that don't cover 24/7
  - [ ] Test with multiple ranges per day that don't cover 24/7

- [ ] **Test 24/7 configurations (validation should detect and block) - DO NOT AUTO-RUN!**
  - [ ] **Note**: "should fail" means the validation should detect 24/7 restrictions and prevent saving the configuration (show warning dialog, block write_config(), return error)
  - [ ] **IMPORTANT**: DO NOT AUTO-RUN. Before running any of these, set popup frequency to 15 minutes, minimum time 5 seconds, immovable window to off, and config file lock and configure.sh prevention both to off (if implemented).
  - [ ] Test with all days set to "0-23" (23 hours each day: 00:00-22:59) - Note: This is 161 hours/week = 9660 minutes, exactly at threshold, so validation should pass (not warn or block)
  - [ ] Test with configurations that actually total 24/7 (10080 minutes):
    - [ ] Each day has "0-12,12-0" (overnight range "12-0" covers hours 12-23, so "0-12" + "12-0" = 24 hours) - validation should detect and block
    - [ ] Each day has multiple ranges that together cover all 24 hours (e.g., "0-8,8-16,16-0" where "16-0" overnight covers hours 16-23) - validation should detect and block
    - [ ] Each day has "23-23" (wraps around, but invalid - start == end) - should be caught by format validation first, before 24/7 check
    - [ ] Each day has "23-0" as overnight range (covers only hour 23: 23:00-23:59, not 24 hours) - verify this is NOT detected as 24/7
  - [ ] Test with combination of normal and overnight ranges that total 24/7 - validation should detect and block
  - [ ] Test with exactly 10080 minutes (24/7) - validation should detect and block
  - [ ] Test with 10079 minutes (not 24/7) - validation should pass, allow saving

- [ ] **Test high restriction level (> 9660 minutes, > 23 hours/day) - should warn**
  - [ ] **Note**: "should warn" means validation should show warning dialog, but allow user to confirm and save
  - [ ] Test with exactly 9661 minutes (just over 23 hours/day) - validation should show warning, allow confirmation
  - [ ] Test with all days set to "0-23" plus one day with additional hour (e.g., Monday "0-23,23-0") - should warn
  - [ ] Test with overlapping ranges that total > 9660 minutes:
    - [ ] Each day has "0-10,9-23" (overlaps at hours 9-10, should merge to "0-23" = 23 hours) - exactly 9660, should pass
    - [ ] Each day has "0-10,8-23" (overlaps at hours 8-10, should merge to "0-23" = 23 hours) - exactly 9660, should pass
    - [ ] Each day has "0-12,11-23" (overlaps at hours 11-12, should merge to "0-23" = 23 hours) - exactly 9660, should pass
    - [ ] Each day has "0-12,12-0" (no overlap, covers all 24 hours) - should block (10080 minutes)
  - [ ] Test warning dialog behavior:
    - [ ] User confirms warning → configuration saves successfully
    - [ ] User cancels warning → returns to configuration menu, no save

- [ ] **Test edge cases**
  - [ ] Test overnight range on Saturday (23-6) that wraps to Sunday
  - [ ] Test multiple overlapping ranges that merge to 24/7
  - [ ] Test empty days mixed with 24-hour restricted days
  - [ ] Test multiple ranges per day (e.g., "0-12,12-23" = 24 hours)
  - [ ] **Test within-day overlaps** (CRITICAL):
    - [ ] "0-10,9-23" on single day (overlaps at hours 9-10, should merge to "0-23" = 23 hours)
    - [ ] "0-5,4-8,7-12" on single day (multiple overlaps, should merge correctly)
    - [ ] "0-12,11-23" on single day (overlaps at hour 11-12, should merge to "0-23" = 23 hours)
    - [ ] "0-12,12-0" on single day (no overlap, covers all 24 hours) - should be detected as 24 hours
  - [ ] **Test cross-day overlaps** (CRITICAL):
    - [ ] Monday "23-6" and Tuesday "0-5" (overlap at hours 0-5, should merge correctly)
    - [ ] Saturday "23-6" and Sunday "0-5" (wrap-around overlap, should merge correctly)

- [ ] **Test error dialog (24/7 detected)**
  - [ ] Test in GUI mode (zenity)
  - [ ] Test in text mode
  - [ ] Verify dialog is modal and blocks saving
  - [ ] Verify user can return to configuration after seeing error
  - [ ] Verify config file is NOT written when validation blocks

- [ ] **Test warning dialog (> 9660 minutes)**
  - [ ] Test in GUI mode (zenity)
  - [ ] Test in text mode
  - [ ] Verify dialog offers "Yes, Save Anyway" and "No, Modify Settings" options
  - [ ] Verify "Yes, Save Anyway" allows saving
  - [ ] Verify "No, Modify Settings" returns to configuration menu without saving
  - [ ] Verify config file is written only if user confirms

- [ ] **Test integration with config locking features (if implemented)**
  - [ ] Test with 24/7 restrictions (>= 10080 minutes):
    - [ ] If enhancement #18 is implemented, verify CONFIG_LOCK_ENABLED is set to false
    - [ ] If enhancement #19 is implemented, verify CONFIGURE_BLOCK_ENABLED is set to false
    - [ ] If enhancement #20 is implemented, verify CONFIG_LOCK_ADDITIONAL_HOURS is cleared
    - [ ] Verify config file comment explains 24/7 restrictions were detected
  - [ ] Test with high restrictions (> 9660 minutes, but < 10080):
    - [ ] If enhancement #18 is implemented, verify CONFIG_LOCK_ENABLED is set to false
    - [ ] If enhancement #19 is implemented, verify CONFIGURE_BLOCK_ENABLED is set to false
    - [ ] If enhancement #20 is implemented, verify CONFIG_LOCK_ADDITIONAL_HOURS is cleared
    - [ ] Verify config file comment explains restrictions exceed 23 hours/day
  - [ ] Test with normal restrictions (<= 9660 minutes):
    - [ ] Verify config locking features are NOT automatically disabled
    - [ ] User can still enable/disable config locking features normally

- [ ] **Test user workflow**
  - [ ] User configures 24/7 restrictions → warning appears → user modifies → saves successfully
  - [ ] User configures 24/7 restrictions → warning appears → user cancels → no config saved
  - [ ] User configures valid restrictions → no warning → saves successfully

### Phase 5: Code Quality and Documentation
- [ ] **Code documentation**
  - [ ] Add function header comment for `check_24_7_restrictions()` explaining:
    - [ ] Purpose: prevent 24/7 restriction configuration
    - [ ] Input: config_lines array or summary_lines array
    - [ ] Output: returns 0 if valid (not 24/7), 1 if invalid (24/7 detected)
    - [ ] Algorithm: converts all ranges to unified timeline, merges overlaps, calculates total
  - [ ] Add inline comments explaining:
    - [ ] How overnight ranges are split
    - [ ] How intervals are merged
    - [ ] How weekly timeline mapping works
    - [ ] Why 10080 is the threshold

- [ ] **Error handling**
  - [ ] Handle invalid time range formats gracefully
  - [ ] Handle missing config_lines entries (undefined array indices)
  - [ ] Handle edge cases in interval merging (empty arrays, single interval, etc.)
  - [ ] Add error logging if validation encounters unexpected data

- [ ] **Performance considerations**
  - [ ] Validation should complete quickly (< 1 second)
  - [ ] Use efficient algorithms for interval merging (O(n log n) sort + O(n) merge)
  - [ ] Avoid unnecessary calculations or loops

- [ ] **Technical documentation**
  - [ ] Add section to `dev-docs/TECHNICAL_DETAILS.md` about 24/7 restriction prevention feature
  - [ ] Document the validation algorithm and approach
  - [ ] Explain how overnight ranges are handled in the validation
  - [ ] Document the interval merging logic
  - [ ] Explain the automatic safety feature disabling (config locking, configure.sh blocking)
  - [ ] Include examples of valid vs invalid configurations
  - [ ] Reference this enhancement document for detailed implementation notes

### Phase 6: User Documentation
- [ ] **Update user documentation**
  - [ ] Add note in `user-docs/CONFIGURATION.md` about 24/7 restriction prevention
  - [ ] Explain why 24/7 restrictions are blocked
  - [ ] Provide examples of valid vs invalid configurations
  - [ ] Document the automatic safety feature disabling

- [ ] **Update help text in configure.sh**
  - [ ] Add note in welcome message about 24/7 restriction prevention
  - [ ] Update help dialog to mention this safety feature

### Phase 7: Integration Testing
- [ ] **Test with existing features**
  - [ ] Verify validation doesn't break existing configuration workflow
  - [ ] Verify validation works with visual grid (option 5)
  - [ ] Verify validation works with weekdays/weekends bulk configuration
  - [ ] Verify validation works when loading existing config and modifying it

- [ ] **Test backward compatibility**
  - [ ] Existing valid configs should still work
  - [ ] Existing invalid configs (if any exist) should be caught on next save
  - [ ] Config file format remains unchanged

### Phase 8: Final Validation
- [ ] **Code review checklist**
  - [ ] All functions have proper error handling
  - [ ] All edge cases are handled
  - [ ] Code follows existing style conventions in configure.sh
  - [ ] No hardcoded values (use constants for 10080, 1440, etc.)
  - [ ] Functions are well-documented

- [ ] **Manual testing**
  - [ ] Run through complete configuration workflow
  - [ ] Test both GUI and text modes
  - [ ] Verify warning appears at correct time
  - [ ] Verify config file is not saved when validation fails
  - [ ] Verify user can modify and save after seeing warning

- [ ] **Edge case validation**
  - [ ] Test with all possible overnight range combinations
  - [ ] Test with maximum number of ranges per day
  - [ ] Test with boundary values (10079 vs 10080 minutes)
  - [ ] Test with empty configuration (should pass)
