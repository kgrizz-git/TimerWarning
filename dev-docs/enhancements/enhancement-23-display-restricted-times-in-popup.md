# Enhancement 23: Display Restricted Times/Days in Popup

- **Description**: Enhance the warning popup to display the configured restricted hours and days, showing users exactly when restrictions are active and **when the next unrestricted time will be**. This provides transparency and helps users understand why they're seeing the warning and plan accordingly. The popup should show the current day's restricted hours in a clear, readable format, and calculate the next unrestricted time by evaluating the entire week's configuration (not just the current day). This requires careful analysis of all restricted time ranges, including overnight ranges that span multiple days and overlapping ranges across day boundaries.
- **Files Affected**: `lib/popup-display.sh`, `lib/config.sh`, `sleep-warning.conf` (optionally `lib/configure-time.sh` if reusing formatting functions)
- **Priority**: Medium (improves user experience and transparency)
- **Status**: Not implemented
- **Feasibility Assessment**: ✅ **Highly Feasible** - Read configuration and format for display
- **Implementation Approach**:
  - **Read Current Day's Restrictions**:
    - Parse configuration file to get restricted hours for current day
    - Format time ranges in human-readable format (e.g., "12:00 AM → 4:59 AM")
    - Handle overnight ranges that span midnight (e.g., "11:00 PM → 5:59 AM (next day)")
    - Handle multiple ranges per day (e.g., "12:00 AM → 4:59 AM AND 10:00 PM → 11:59 PM")
  - **Calculate Next Unrestricted Time** (NEW):
    - Build complete weekly timeline of all restricted intervals (0-10079 minutes)
    - Reuse interval merging logic from Enhancement 22 to handle overlaps
    - Starting from current time, search forward to find next unrestricted minute
    - Handle wrap-around if next unrestricted time is in the following week
    - Handle edge case: no unrestricted time in next 7 days (24/7 restrictions - should be prevented by Enhancement 22)
    - Format result in human-readable format (e.g., "Friday at 9:00 AM" or "Tomorrow at 5:00 AM")
  - **Display in Popup**:
    - Add section to popup message showing current day's restricted hours
    - Add section showing when next unrestricted time will be (e.g., "Next unrestricted time: Friday at 9:00 AM")
    - Use clear formatting with labels
    - Keep message concise to avoid overwhelming the popup
  - **Configuration Option**:
    - Add `POPUP_SHOW_RESTRICTED_TIMES=true/false` config option (default: `true`)
    - Allow users to disable this feature if they prefer shorter popup messages
- **Implementation Notes**:
  - **Time Range Formatting**:
    - Reuse existing `format_ranges_human()` function from `lib/configure-time.sh` if possible, or implement similar logic in `lib/popup-display.sh` (consider moving shared formatting functions to a common module)
    - Convert 24-hour format to 12-hour format with AM/PM for readability
    - Handle overnight ranges clearly (show "next day" indicator)
    - Format multiple ranges with "AND" separator
  - **Popup Message Structure**:
    - Current message structure:
      ```
      ⚠️  Late Night Usage Warning ⚠️
      
      You are using your computer during restricted hours.
      
      It's recommended to get some rest. Consider taking a break or going to sleep.
      
      This warning will appear every X minutes while you continue using your computer during these hours.
      ```
    - Enhanced message structure:
      ```
      ⚠️  Late Night Usage Warning ⚠️
      
      You are using your computer during restricted hours.
      
      Restricted Hours: [Current Day] [Time Ranges]
      Example: "Restricted Hours: Monday 12:00 AM → 4:59 AM"
      Example: "Restricted Hours: Tuesday 11:00 PM → 5:59 AM (Wednesday)"
      Example: "Restricted Hours: Wednesday 12:00 AM → 4:59 AM AND 10:00 PM → 11:59 PM"
      
      It's recommended to get some rest. Consider taking a break or going to sleep.
      
      This warning will appear every X minutes while you continue using your computer during these hours.
      ```
  - **Day Name Formatting**:
    - Use full day names (Monday, Tuesday, etc.) for clarity
    - Get current day name from `date +%A` or convert day number (0-6) to day name
  - **Configuration Option**:
    - `POPUP_SHOW_RESTRICTED_TIMES=true/false` - Enable/disable display of restricted times in popup (default: `true`)
    - Add to config file with comment explaining the feature
    - Can be configured via `configure.sh` (using `lib/configure-config.sh` and `lib/configure-input.sh`) in future (optional, not required for initial implementation)
  - **Edge Cases**:
    - **Overnight Ranges**: Must clearly indicate when range spans to next day
    - **Multiple Ranges**: Format clearly with "AND" separator
    - **Empty Restrictions**: If current day has no restrictions (shouldn't happen, but handle gracefully)
    - **Inherited Restrictions**: If current hour is restricted due to previous day's overnight range, show both current day and previous day's range
    - **Long Messages**: Ensure popup doesn't become too large - may need to limit text or use scrolling
  - **Calculate Next Unrestricted Time (NEW)**:
    - **Algorithm Overview**:
      1. Build complete weekly timeline of restricted intervals (similar to Enhancement 22's validation logic)
      2. Convert all restricted ranges to minute intervals (0-10079 for entire week)
      3. Merge overlapping intervals (both within-day and cross-day overlaps)
      4. Get current time as minute offset from start of week
      5. Search forward from current minute to find first unrestricted minute
      6. If no unrestricted time found in next 7 days, display error message (should never happen if Enhancement 22 is implemented)
      7. Convert result back to day/hour/minute and format for display
    - **Interval Building** (reuse from Enhancement 22 approach):
      - For each day (Sunday=0 to Saturday=6):
        - Parse all time ranges for that day
        - For each range (e.g., "23-6"):
          - If overnight (start > end): split into two segments
            - Segment 1: start_hour to 23:59 on current day
            - Segment 2: 00:00 to end_hour on next day (with day wrap-around)
          - If normal (start < end): single segment within same day
        - Convert hours to minute offsets from start of week
          - Sunday: 0-1439, Monday: 1440-2879, etc.
      - Merge overlapping intervals within each day first
      - Then merge overlapping intervals across day boundaries
      - Result: sorted array of [start_minute, end_minute] pairs covering all restricted times
    - **Current Time Calculation**:
      - Get current day of week (0-6)
      - Get current hour (0-23) and minute (0-59)
      - Calculate minute offset from start of week: `day * 1440 + hour * 60 + minute`
    - **Next Unrestricted Time Search**:
      - Start from current minute offset
      - Check if current minute is in any restricted interval
      - If restricted, find the end of the current restricted interval
      - Search forward minute by minute (or jump to end of restricted interval for efficiency)
      - First minute NOT in any restricted interval is the next unrestricted time
      - If search reaches minute 10079 (end of week), wrap around to minute 0 and continue search
      - Stop if search returns to starting point (means 24/7 restrictions - should never happen)
    - **Result Formatting**:
      - Convert minute offset back to day/hour/minute
      - Format day name: Sunday, Monday, etc.
      - Format time in 12-hour format: "9:00 AM", "5:30 PM", etc.
      - Use relative day names when appropriate:
        - "in X minutes" (if < 60 minutes away)
        - "at HH:MM AM/PM" (if later today)
        - "Tomorrow at HH:MM AM/PM" (if next day)
        - "Day at HH:MM AM/PM" (if 2+ days away)
      - Examples:
        - "in 15 minutes" (unrestricted time is 15 minutes away)
        - "at 5:00 AM" (unrestricted time is later today)
        - "Tomorrow at 9:00 AM"
        - "Friday at 9:00 AM"
    - **Error Handling**:
      - If no unrestricted time found in next 7 days (24/7 restrictions):
        - Display: "No unrestricted time scheduled (24/7 restrictions active)"
        - Log warning: this should never happen if Enhancement 22 is implemented
        - Consider showing uninstall instructions or emergency override
  - **Implementation Location**:
    - Modify `show_warning()` function in `lib/popup-display.sh`
    - Read current day's restrictions using existing `parse_config()` function
    - Format time ranges using new or existing formatting function
    - Calculate next unrestricted time using new `get_next_unrestricted_time()` function
    - Append formatted restrictions and next unrestricted time to popup message
- **Safety Assessment**:
  - **Bypass Risk**: None - This is informational only, doesn't affect restriction enforcement
  - **Uninstall Safety**: ✅ **Safe** - Does not affect uninstall process
  - **Data Safety**: ✅ **Safe** - Read-only operation, no data modification
  - **System Safety**: ✅ **Safe** - No risk to system stability
  - **User Experience**: ✅ **Positive** - Improves transparency and user understanding
  - **Effectiveness**: ✅ **Neutral** - Doesn't change restriction effectiveness, only improves communication
- **Processing/Memory Burden**:
  - **Minimal** - Only requires reading config file and formatting text
  - No additional processes or continuous monitoring
  - **Memory**: Negligible (small string formatting)
  - **CPU**: Negligible (text formatting operations are instant)
- **User Experience Considerations**:
  - **Clear Formatting**: Use human-readable time format (12-hour with AM/PM) for better readability
  - **Concise Display**: Keep message concise to avoid overwhelming popup
  - **Optional Feature**: Allow users to disable if they prefer shorter messages
  - **Transparency**: Helps users understand why they're seeing the warning
  - **Educational**: Users can see their configured restrictions without opening config file
- **Edge Cases**:
  - **System Time Changes**: Not applicable (reads current day from system time)
  - **System Sleep/Resume**: Not applicable (reads config at popup display time)
  - **Config File Changes**: If config changes while popup is displayed, popup shows restrictions at time of display (acceptable)
  - **Long Time Ranges**: Ensure formatting handles long time range descriptions gracefully
  - **Multiple Ranges**: Format multiple ranges clearly without making message too long
- **Related**: 
  - **Enhancement 22 (Prevent 24/7 Restriction Configuration)**: **STRONGLY RELATED** - Uses similar interval building and merging logic. If Enhancement 22 is implemented first, this enhancement can reuse ~150 lines of code (interval building, merging, and timeline management). Both enhancements benefit from shared utility functions for handling weekly timelines and overlapping ranges.
  - **Enhancement 16 (Visual Day/Time Configuration Grid)**: Users can see restrictions in configure.sh, this shows them in the popup
  - **Enhancement 5 (Configurable Warning Messages)**: Could work together - show custom message plus restricted times and next unrestricted time
  - **Enhancement 6 (Escalating Warnings)**: Could show different levels of detail at different escalation levels (e.g., first warning shows current restriction, later warnings add next unrestricted time)
  - **User Experience Enhancement**: Improves transparency and helps users plan ahead by knowing when restrictions will end

---

## Implementation Details

### Code Location Reference
- **Existing formatting functions** (can reuse from modules):
  - `format_hour_12h()` - Already exists in `lib/configure-core.sh` (can be reused or moved to shared location)
  - `format_range_human()` - Already exists in `lib/configure-time.sh` (can be reused or moved to shared location)
  - `format_ranges_human()` - Already exists in `lib/configure-time.sh` (can be reused or moved to shared location)
- **Target function to modify**: `lib/popup-display.sh` `show_warning()` function
- **Config file to update**: `sleep-warning.conf`
- **Message construction**: Modify message building logic in `lib/popup-display.sh` `show_warning()` function

### Message Format Examples

**Current message (without enhancement):**
```
⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear every 10 minutes while you continue using your computer during these hours.
```

**Enhanced message (single range):**
```
⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Restricted Hours: Monday 12:00 AM → 5:00 AM
Next unrestricted time: at 5:00 AM (in 3 hours 15 minutes)

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear every 10 minutes while you continue using your computer during these hours.
```

**Enhanced message (overnight range):**
```
⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Restricted Hours: Tuesday 11:00 PM → 6:00 AM (Wednesday)
Next unrestricted time: Tomorrow at 6:00 AM

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear every 10 minutes while you continue using your computer during these hours.
```

**Enhanced message (multiple ranges):**
```
⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Restricted Hours: Wednesday 12:00 AM → 5:00 AM AND 10:00 PM → 11:59 PM
Next unrestricted time: at 5:00 AM (in 2 hours 30 minutes)

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear every 10 minutes while you continue using your computer during these hours.
```

**Enhanced message (inherited from previous day):**
```
⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Restricted Hours: Tuesday 11:00 PM → 6:00 AM (Wednesday)
(Inherited from Tuesday's overnight restriction)
Next unrestricted time: at 6:00 AM (in 4 hours 45 minutes)

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear every 10 minutes while you continue using your computer during these hours.
```

**Enhanced message (complex scenario - days away):**
```
⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Restricted Hours: Tuesday 12:00 AM → 11:59 PM
Next unrestricted time: Friday at 9:00 AM

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear every 10 minutes while you continue using your computer during these hours.
```

**Enhanced message (24/7 restrictions - should never happen with Enhancement 22):**
```
⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Restricted Hours: 24/7 (all hours, all days)
Next unrestricted time: No unrestricted time scheduled

⚠️ WARNING: 24/7 restrictions detected. This should not happen.
Please run the configuration wizard to modify your settings.

This warning will appear every 10 minutes while you continue using your computer during these hours.
```

### Implementation Complexity Assessment
- **Difficulty**: Medium (increased from Low-Medium due to next unrestricted time calculation)
- **Estimated Lines of Code**: ~400-500 lines (new functions + modifications)
  - Basic formatting functions: ~100 lines
  - Interval building and merging: ~150 lines
  - Next unrestricted time search and formatting: ~150 lines
  - Integration and testing: ~100 lines
- **Key Challenges**: 
  1. Building complete weekly timeline with all restricted intervals
  2. Merging overlapping intervals (both within-day and cross-day)
  3. Efficiently searching for next unrestricted time across entire week
  4. Handling inherited restrictions from previous day's overnight ranges
  5. Handling wrap-around from end of week to beginning of week
  6. Formatting relative time descriptions ("in X minutes", "Tomorrow at", etc.)
- **Dependencies**: 
  - None for basic display
  - Conceptually related to Enhancement 22 (uses similar interval merging logic)
  - Can share/adapt interval merging code if Enhancement 22 is implemented

### Performance Considerations
- Interval building and merging: O(n log n) where n = number of time ranges (typically < 50)
- Next unrestricted time search: O(m) where m = number of merged intervals (typically < 20)
- Overall: Should complete in < 10ms even with complex configurations
- All processing is done once per popup display
- No continuous processing or monitoring
- Config file read is already done in `main()`, can reuse parsed data
- Performance impact: Negligible (< 10ms for all calculations)

### Code Reusability with Enhancement 22
If Enhancement 22 is implemented first:
- Can reuse `build_weekly_restricted_intervals()` function
- Can reuse `merge_intervals()` function
- Can reuse day/hour/minute conversion utilities
- Reduces implementation effort by ~30% (reuse ~150 lines of code)

### Technical Implementation Tips

**1. Reusing Data from main()**
The `main()` function already:
- Gets current day/hour: `current_day=$(date +%w)`, `current_hour=$(date +%H)`
- Parses config for current day: `restricted_range=$(parse_config "${current_day}")`
- Checks for inherited restrictions from previous day
- Has `matched_range` variable that includes "(from previous day)" suffix

**Approach**: Pass this data to `show_warning()` as parameters to avoid redundant parsing:
```bash
show_warning "${current_day}" "${matched_range}"
```

**2. Handling Inherited Restrictions**
When current hour is restricted due to previous day's overnight range:
- `matched_range` will contain the range string + " (from previous day)"
- Example: "23-6 (from previous day)"
- Need to detect this suffix and format appropriately
- Show previous day name in message, not current day

**3. Function Placement in lib/popup-display.sh**
Add new functions in `lib/popup-display.sh` module (before or within `show_warning()` function):
- Keep similar functions together (formatting functions in one block)
- Add clear comments explaining each function's purpose
- Follow existing code style (function names, variable naming, etc.)

**4. Config File Update**
Add new option after existing popup options (around line 56 in config file):
```bash
# POPUP_SHOW_RESTRICTED_TIMES: Display restricted hours in popup message
# Default: true
# Options: true, false
# When enabled, shows the configured restricted hours for the current day in the popup
POPUP_SHOW_RESTRICTED_TIMES=true
```

**5. Message Formatting Gotchas**
- Ensure proper line breaks (`\n\n` between sections)
- Keep message concise (avoid overwhelming popup)
- Test with longest possible day name ("Wednesday") and time format
- Consider popup size limits (especially for small popup size setting)
- Use consistent formatting (e.g., always use → arrow, not ->)

**6. Potential Pitfalls to Avoid**
- **Don't parse config multiple times**: Reuse data from `main()`
- **Don't break existing message format**: Add restriction info as new line, don't replace existing text
- **Don't hardcode strings**: Use variables and functions for all formatting
- **Handle empty ranges gracefully**: Don't show "Restricted Hours:" if range is empty (shouldn't happen, but be safe)
- **Test timezone edge cases**: Ensure overnight ranges work correctly at midnight
- **Don't forget logging**: Log when restriction display is enabled/disabled via config

**7. Next Unrestricted Time Algorithm Optimization**
Instead of checking every minute (0-10079), jump through intervals:
```bash
# Efficient search algorithm (pseudocode)
find_next_unrestricted_minute() {
  current_minute = get_current_minute_offset()
  merged_intervals = get_merged_intervals()  # Already sorted
  
  # Check if current minute is restricted
  for interval in merged_intervals:
    if current_minute >= interval.start AND current_minute < interval.end:
      # We're in a restricted interval, jump to end
      current_minute = interval.end
      if current_minute >= 10080:
        current_minute = current_minute % 10080  # Wrap around
      break
  done
  
  # Now check if current_minute is unrestricted
  # If we jumped out of an interval, it should be unrestricted
  # But need to verify there isn't another interval starting immediately
  
  # Binary search or linear search through intervals
  for interval in merged_intervals:
    if current_minute >= interval.start AND current_minute < interval.end:
      # Found another restricted interval, jump again
      current_minute = interval.end
      # Continue loop
    fi
  done
  
  return current_minute
}
```

**8. Interval Merging Best Practices**
Following Enhancement 22's approach:
1. **Phase 1**: Build all intervals (split overnight ranges)
2. **Phase 2**: Merge within-day overlaps first (per day)
3. **Phase 3**: Merge cross-day overlaps (entire week)
4. Result: Minimal set of non-overlapping intervals

**9. Testing Quick Reference**
Create test config scenarios:
```bash
# Test 1: Single range
MONDAY=0-5
# At 2:00 AM Monday: Shows "Next unrestricted time: at 5:00 AM (in 3 hours)"

# Test 2: Overnight range
TUESDAY=23-6
# At 1:00 AM Wednesday: Shows "Next unrestricted time: at 6:00 AM (in 5 hours)"

# Test 3: Multiple ranges
WEDNESDAY=0-5,22-23
# At 11:00 PM Wednesday: Shows "Next unrestricted time: Tomorrow at 12:00 AM (in 1 hour)"

# Test 4: Complex scenario - days away
MONDAY=0-23
TUESDAY=0-23
WEDNESDAY=0-23
THURSDAY=0-23
FRIDAY=9-23
# At 10:00 AM Tuesday: Shows "Next unrestricted time: Friday at 12:00 AM (in 3 days)"

# Test 5: Disabled feature
POPUP_SHOW_RESTRICTED_TIMES=false
```

Run at specific times:
```bash
# Simulate running at 2:00 AM on Monday (restriction 0-5)
# Should show: 
# "Restricted Hours: Monday 12:00 AM → 5:00 AM"
# "Next unrestricted time: at 5:00 AM (in 3 hours)"

# Simulate running at 1:00 AM on Wednesday (inheriting from Tuesday 23-6)
# Should show:
# "Restricted Hours: Tuesday 11:00 PM → 6:00 AM (Wednesday)"
# "Next unrestricted time: at 6:00 AM (in 5 hours)"

# Simulate running at 10:00 AM on Tuesday with restrictions Mon-Thu 0-23, Fri 9-23
# Should show:
# "Restricted Hours: Tuesday 12:00 AM → 11:59 PM"
# "Next unrestricted time: Friday at 12:00 AM"
```

**10. Handling 24/7 Restrictions**
Even though Enhancement 22 should prevent 24/7 configurations, handle gracefully:
```bash
if find_next_unrestricted_minute returns -1 (no unrestricted time found):
  Display: "⚠️ No unrestricted time scheduled (24/7 restrictions active)"
  Log: "WARNING: 24/7 restrictions detected - this should not happen"
  Consider: Show uninstall instructions or emergency override info
fi
```

---

## Implementation Checklist

### Phase 1: Add Configuration Support
- [ ] Add `POPUP_SHOW_RESTRICTED_TIMES` config option to `sleep-warning.conf`
  - [ ] Add config option with default value `true`
  - [ ] Add explanatory comment describing the feature
  - [ ] Place it logically with other popup-related options
- [ ] Add function to read config option in `lib/config.sh` (or extend existing config reading functions)
  - [ ] Create `get_popup_show_restricted_times()` function
  - [ ] Follow pattern of existing config getters (e.g., `get_popup_size()`)
  - [ ] Handle true/false/yes/no/1/0 values
  - [ ] Return default value if config missing or invalid

### Phase 2: Implement Time Formatting Functions
- [ ] Reuse `format_hour_12h()` function from `lib/configure-core.sh` OR add to `lib/popup-display.sh` if not sharing modules
  - [ ] Convert 24-hour format (0-23) to 12-hour format with AM/PM
  - [ ] Handle special cases: 0 (12:00 AM), 12 (12:00 PM)
  - [ ] Format: "HH:00 AM/PM" (e.g., "1:00 AM", "12:00 PM")
- [ ] Add `format_time_12h()` function to `lib/popup-display.sh` (NEW)
  - [ ] Convert 24-hour format with minutes (HH:MM) to 12-hour format
  - [ ] Handle special cases: 0:00 (12:00 AM), 12:00 (12:00 PM)
  - [ ] Format: "HH:MM AM/PM" (e.g., "1:30 AM", "12:45 PM")
- [ ] Add `get_day_name()` function to `lib/popup-display.sh` (or reuse from configure modules if shared)
  - [ ] Convert day number (0-6) to full day name
  - [ ] Use array: 0=Sunday, 1=Monday, etc.
- [ ] Add `get_next_day_name()` function to `lib/popup-display.sh`
  - [ ] Get next day name for overnight ranges
  - [ ] Handle wrap-around: Saturday → Sunday
- [ ] Reuse `format_range_human()` function from `lib/configure-time.sh` OR add to `lib/popup-display.sh` if not sharing modules
  - [ ] Format single range: "START → END"
  - [ ] Handle overnight ranges: "START → END (NextDay)"
  - [ ] Use 12-hour format for times
  - [ ] Handle empty/invalid ranges: return empty or skip
- [ ] Reuse `format_ranges_human()` function from `lib/configure-time.sh` OR add to `lib/popup-display.sh` if not sharing modules
  - [ ] Parse comma-separated ranges
  - [ ] Format each range using `format_range_human()`
  - [ ] Join multiple ranges with " AND "
  - [ ] Return formatted string

### Phase 3: Implement Weekly Timeline and Interval Building (NEW)
- [ ] Add `build_weekly_restricted_intervals()` function to `lib/popup-display.sh`
  - [ ] Create array to store all restricted intervals as [start_minute, end_minute] pairs
  - [ ] For each day (0-6):
    - [ ] Get day's configuration using `parse_config()`
    - [ ] Parse all time ranges for that day (handle comma-separated ranges)
    - [ ] For each range:
      - [ ] Parse start and end hours
      - [ ] If overnight range (start > end):
        - [ ] Create segment 1: start_hour to 23:59 on current day
        - [ ] Create segment 2: 00:00 to end_hour on next day (handle Saturday → Sunday wrap)
      - [ ] If normal range (start <= end):
        - [ ] Create single segment within same day
      - [ ] Convert hours to minute offsets from start of week
        - [ ] Formula: `day * 1440 + hour * 60`
        - [ ] Sunday (0): 0-1439, Monday (1): 1440-2879, etc.
      - [ ] Add interval to array
  - [ ] Return array of all restricted intervals (before merging)

- [ ] Add `merge_intervals()` function to `lib/popup-display.sh`
  - [ ] Take array of [start, end] intervals as input
  - [ ] Sort intervals by start time
  - [ ] Merge overlapping or adjacent intervals:
    - [ ] If interval A ends >= interval B starts, merge them
    - [ ] New interval: [min(A.start, B.start), max(A.end, B.end)]
  - [ ] Return array of merged intervals (no overlaps)
  - [ ] Handle edge cases:
    - [ ] Empty array
    - [ ] Single interval
    - [ ] All intervals overlap → single merged interval

- [ ] Add `is_minute_restricted()` function to `lib/popup-display.sh`
  - [ ] Take minute offset (0-10079) and merged intervals array
  - [ ] Check if minute falls within any restricted interval
  - [ ] Return 0 if restricted, 1 if unrestricted
  - [ ] Use binary search or linear search for efficiency

### Phase 4: Implement Next Unrestricted Time Calculation (NEW)
- [ ] Add `get_current_minute_offset()` function to `lib/popup-display.sh`
  - [ ] Get current day of week (0-6)
  - [ ] Get current hour (0-23) and minute (0-59)
  - [ ] Calculate minute offset from start of week: `day * 1440 + hour * 60 + minute`
  - [ ] Return minute offset (0-10079)

- [ ] Add `minute_offset_to_day_hour_minute()` function to `lib/popup-display.sh`
  - [ ] Take minute offset (0-10079) as input
  - [ ] Calculate day: `minute_offset / 1440` (integer division)
  - [ ] Calculate remaining minutes: `minute_offset % 1440`
  - [ ] Calculate hour: `remaining_minutes / 60` (integer division)
  - [ ] Calculate minute: `remaining_minutes % 60`
  - [ ] Return day, hour, minute as separate values

- [ ] Add `find_next_unrestricted_minute()` function to `lib/popup-display.sh`
  - [ ] Take current minute offset and merged intervals array as input
  - [ ] Start from current minute offset
  - [ ] Check if current minute is restricted
  - [ ] If restricted, find end of current restricted interval (for efficiency)
  - [ ] Jump to end of interval + 1 minute
  - [ ] If unrestricted, check next minute
  - [ ] Continue searching forward through the week
  - [ ] If reach end of week (minute 10079), wrap to start (minute 0)
  - [ ] Stop if return to starting point (means 24/7 restrictions)
  - [ ] Return minute offset of first unrestricted time, or -1 if none found

- [ ] Add `format_next_unrestricted_time()` function to `lib/popup-display.sh`
  - [ ] Take next unrestricted minute offset and current minute offset as input
  - [ ] Convert minute offset to day/hour/minute using `minute_offset_to_day_hour_minute()`
  - [ ] Calculate time difference (in minutes)
  - [ ] Format based on time difference:
    - [ ] If < 60 minutes: "in X minutes"
    - [ ] If same day: "at HH:MM AM/PM (in X hours Y minutes)"
    - [ ] If next day: "Tomorrow at HH:MM AM/PM"
    - [ ] If 2+ days away: "[DayName] at HH:MM AM/PM"
  - [ ] Use `format_time_12h()` for time formatting
  - [ ] Use `get_day_name()` for day name
  - [ ] Return formatted string

- [ ] Add `get_next_unrestricted_time()` function to `lib/popup-display.sh` (main orchestrator)
  - [ ] Build weekly restricted intervals using `build_weekly_restricted_intervals()`
  - [ ] Merge intervals using `merge_intervals()`
  - [ ] Get current minute offset using `get_current_minute_offset()`
  - [ ] Find next unrestricted minute using `find_next_unrestricted_minute()`
  - [ ] If no unrestricted time found (24/7 restrictions):
    - [ ] Return error message: "No unrestricted time scheduled (24/7 restrictions)"
    - [ ] Log warning to log file
  - [ ] Format next unrestricted time using `format_next_unrestricted_time()`
  - [ ] Return formatted string

### Phase 5: Implement Restriction Display Logic
- [ ] Add `get_restricted_times_message()` function to `lib/popup-display.sh`
  - [ ] Get current day number
  - [ ] Get current day name using `get_day_name()`
  - [ ] Get current day's restrictions (reuse existing logic from `main()`)
  - [ ] Handle inherited restrictions from previous day (overnight ranges)
  - [ ] Format restrictions using `format_ranges_human()`
  - [ ] Call `get_next_unrestricted_time()` to get next unrestricted time
  - [ ] Build complete message with both current restrictions and next unrestricted time
  - [ ] Return formatted message lines:
    - [ ] "Restricted Hours: [Day] [TimeRanges]"
    - [ ] "Next unrestricted time: [FormattedTime]"
  - [ ] Handle edge cases:
    - [ ] Current day has no restrictions but inherits from previous day
    - [ ] Multiple ranges on same day
    - [ ] Empty restrictions (shouldn't happen during warning, but handle gracefully)
    - [ ] 24/7 restrictions (show appropriate error message)

### Phase 6: Integrate into Popup Display
- [ ] Modify `show_warning()` function in `lib/popup-display.sh`
  - [ ] Read `POPUP_SHOW_RESTRICTED_TIMES` config option
  - [ ] If enabled:
    - [ ] Call `get_restricted_times_message()` to get restriction info and next unrestricted time
    - [ ] Insert restriction info into popup message (after "restricted hours" line)
    - [ ] Insert next unrestricted time on separate line
    - [ ] Maintain proper message formatting and line breaks
  - [ ] If disabled: leave message as-is (current behavior)
  - [ ] Test message length doesn't exceed popup size limits
  - [ ] Consider increasing default popup height if needed to accommodate new content

### Phase 7: Testing

#### Basic Display Tests
- [ ] Test with single range (e.g., "0-5")
  - [ ] Verify correct 12-hour format: "12:00 AM → 5:00 AM"
  - [ ] Verify day name displays correctly
  - [ ] Verify next unrestricted time shows correctly: "at 5:00 AM"
- [ ] Test with overnight range (e.g., "23-6")
  - [ ] Verify next day indicator: "11:00 PM → 6:00 AM (NextDay)"
  - [ ] Verify inherited restrictions display correctly
  - [ ] Verify next unrestricted time: "at 6:00 AM" or "Tomorrow at 6:00 AM"
- [ ] Test with multiple ranges (e.g., "0-5,22-23")
  - [ ] Verify "AND" separator: "12:00 AM → 5:00 AM AND 10:00 PM → 11:00 PM"
  - [ ] Verify next unrestricted time shows correct time between ranges or after ranges
- [ ] Test with config option disabled
  - [ ] Verify popup displays without restriction info (original behavior)

#### Next Unrestricted Time Calculation Tests
- [ ] **Test interval building**
  - [ ] Test `build_weekly_restricted_intervals()` with various configurations
  - [ ] Verify overnight ranges split correctly across days
  - [ ] Verify minute offsets calculated correctly for each day
  - [ ] Verify Saturday → Sunday wrap-around handled correctly

- [ ] **Test interval merging**
  - [ ] Test `merge_intervals()` with non-overlapping intervals (should remain separate)
  - [ ] Test with overlapping intervals within same day (e.g., "0-10,9-23" → merge to "0-23")
  - [ ] Test with overlapping intervals across days (e.g., Monday "23-6" + Tuesday "0-5")
  - [ ] Test with adjacent intervals (e.g., "0-5" and "5-10" → merge to "0-10")
  - [ ] Test with multiple overlapping intervals
  - [ ] Verify merged intervals don't double-count restricted time

- [ ] **Test next unrestricted time search**
  - [ ] Test when next unrestricted time is same day (e.g., restricted 0-5, current time 2 AM, next time 5 AM)
  - [ ] Test when next unrestricted time is tomorrow (e.g., restricted 0-23, current time 10 AM, next time tomorrow 12 AM)
  - [ ] Test when next unrestricted time is multiple days away (e.g., Tuesday restricted 0-23, next unrestricted Friday 9 AM)
  - [ ] Test when next unrestricted time is < 60 minutes away (should show "in X minutes")
  - [ ] Test when current time is at the end of a restriction (e.g., restriction ends at 5:00 AM, current time 4:59 AM)
  - [ ] Test wrap-around from end of week to beginning (Saturday → Sunday)
  - [ ] Test with multiple gaps in restrictions (should find nearest gap)

- [ ] **Test time formatting**
  - [ ] Test relative time: "in X minutes" (for < 60 minutes)
  - [ ] Test same day: "at HH:MM AM/PM"
  - [ ] Test tomorrow: "Tomorrow at HH:MM AM/PM"
  - [ ] Test multiple days: "[DayName] at HH:MM AM/PM"
  - [ ] Test hour/minute calculation correctness
  - [ ] Test 12-hour format correctness (AM/PM)

#### Edge Case Tests
- [ ] Test all days of week
  - [ ] Verify day names are correct for each day
  - [ ] Test Sunday → Monday overnight
  - [ ] Test Saturday → Sunday overnight
  - [ ] Test each day as starting point for next unrestricted time search
- [ ] Test complex configurations
  - [ ] Monday: "0-5,22-23", Tuesday: "0-8,20-23", etc. (different patterns each day)
  - [ ] Verify next unrestricted time correctly navigates complex patterns
  - [ ] Test with overlapping ranges across multiple days
- [ ] Test 24/7 restrictions (should never happen with Enhancement 22, but handle gracefully)
  - [ ] Configure 24/7 restrictions (if possible)
  - [ ] Verify error message: "No unrestricted time scheduled"
  - [ ] Verify warning in popup
  - [ ] Verify log warning is written
- [ ] Test very long restricted periods
  - [ ] Restricted for 6 days straight, unrestricted on 7th day
  - [ ] Verify next unrestricted time correctly identifies the day
- [ ] Test boundary conditions
  - [ ] Restriction ending at midnight (23:59 → 0:00)
  - [ ] Restriction starting at midnight (0:00 start)
  - [ ] Current time exactly at restriction boundary
- [ ] Test config file missing or invalid
  - [ ] Should fall back to default restrictions
  - [ ] Next unrestricted time should still calculate correctly

#### Display and Integration Tests
- [ ] Test popup appearance
  - [ ] Verify message formatting is readable
  - [ ] Verify popup size accommodates new content (both restriction info and next unrestricted time)
  - [ ] Test with different popup sizes (small, medium, large) - may need to increase height
  - [ ] Test with different dialog tools (zenity, yad, kdialog)
  - [ ] Verify line breaks and formatting look good
- [ ] Test with different environments
  - [ ] X11
  - [ ] Wayland
  - [ ] Gamescope (Steam Deck)
- [ ] Test message length
  - [ ] Verify long day names don't break formatting (e.g., "Wednesday")
  - [ ] Verify long time descriptions don't overflow popup
  - [ ] Test with maximum message length scenarios

#### Performance Tests
- [ ] Test interval building performance
  - [ ] Should complete quickly (< 100ms) even with complex configurations
- [ ] Test next unrestricted time search performance
  - [ ] Should complete quickly (< 100ms) even when searching across multiple days
  - [ ] Verify efficient jumping through restricted intervals (not minute-by-minute)

#### Integration Tests
- [ ] Test with Enhancement 22 (if implemented)
  - [ ] Verify interval merging logic is consistent between enhancements
  - [ ] Verify 24/7 restriction prevention works (Enhancement 22 should prevent 24/7 config)
- [ ] Test configuration changes
  - [ ] Change restrictions, verify next unrestricted time updates correctly on next popup
- [ ] Test systemd timer integration
  - [ ] Verify popup shows correct times at different times of day
  - [ ] Test across multiple days

### Phase 8: Documentation
- [ ] Update user documentation
  - [ ] Add description of feature to `USER_GUIDE.md`
  - [ ] Explain that popup shows both current restrictions and next unrestricted time
  - [ ] Add screenshot or example of enhanced popup (if applicable)
  - [ ] Explain how next unrestricted time is calculated
- [ ] Update configuration documentation
  - [ ] Document `POPUP_SHOW_RESTRICTED_TIMES` option in `CONFIGURATION.md`
  - [ ] Provide examples of popup messages with/without feature
  - [ ] Include examples of next unrestricted time formatting
- [ ] Update technical documentation
  - [ ] Add section to `dev-docs/TECHNICAL_DETAILS.md` about next unrestricted time calculation
  - [ ] Document the interval building and merging algorithm
  - [ ] Explain relationship to Enhancement 22's validation logic
  - [ ] Document performance considerations
- [ ] Update README if needed
  - [ ] Mention transparency/user experience improvement
  - [ ] Highlight next unrestricted time feature
- [ ] Update AGENTS.md if needed
  - [ ] Note implementation of enhancement 23

### Phase 9: Final Review
- [ ] Code review
  - [ ] Ensure functions follow existing code style
  - [ ] Verify proper error handling
  - [ ] Check for potential performance issues
  - [ ] Ensure no breaking changes to existing functionality
  - [ ] Verify interval merging logic is correct (no double-counting)
  - [ ] Verify wrap-around logic handles Saturday → Sunday correctly
- [ ] Security review
  - [ ] Verify no new security vulnerabilities
  - [ ] Ensure config parsing is safe
  - [ ] Verify no infinite loops in next unrestricted time search
- [ ] Performance review
  - [ ] Verify interval building completes in < 10ms
  - [ ] Verify next unrestricted time search completes in < 10ms
  - [ ] Verify no unnecessary repeated calculations
- [ ] Consider code sharing with Enhancement 22
  - [ ] If Enhancement 22 is implemented, extract shared functions to common utilities
  - [ ] If this is implemented first, document functions that can be reused by Enhancement 22
- [ ] Mark enhancement as completed
  - [ ] Move plan to `dev-docs/completed-plans/`
  - [ ] Update status in `FUTURE_ENHANCEMENTS.md`

---

## Implementation Summary

This enhancement significantly improves user experience by:
1. **Showing current restrictions** - Users see exactly what restrictions are active now
2. **Showing next unrestricted time** - Users can plan ahead and know when they can use the computer without restrictions

### Key Implementation Components

1. **Time Formatting** (~100 lines)
   - Convert 24h to 12h format
   - Format ranges with day names
   - Format relative times ("in X minutes", "Tomorrow at")

2. **Interval Building** (~150 lines)
   - Build weekly timeline (0-10079 minutes)
   - Handle overnight ranges that span days
   - Handle Saturday → Sunday wrap-around

3. **Interval Merging** (~100 lines)
   - Merge overlapping intervals within same day
   - Merge overlapping intervals across day boundaries
   - Critical for accurate "next unrestricted time" calculation
   - **Shares logic with Enhancement 22**

4. **Next Unrestricted Time Search** (~100 lines)
   - Efficient search through merged intervals
   - Jump through restricted intervals (don't check every minute)
   - Handle wrap-around from end of week to beginning
   - Handle edge case: 24/7 restrictions (no unrestricted time)

5. **Display Integration** (~50 lines)
   - Integrate into `show_warning()` function
   - Add config option to enable/disable
   - Format message with proper line breaks

### Relationship to Enhancement 22

Both enhancements work with weekly timelines and need to:
- Build complete weekly timeline of restricted intervals
- Merge overlapping intervals (within-day and cross-day)
- Handle overnight ranges and wrap-around

**Code Reuse Opportunity**:
- Extract shared functions: `build_weekly_restricted_intervals()`, `merge_intervals()`
- Place in `lib/popup-display.sh` module (or create shared utility module if functions are needed by both sleep-warning.sh and configure.sh)
- Enhancement 22 uses these for validation (checking if total >= 10080 minutes)
- Enhancement 23 uses these for next unrestricted time calculation
- Implementing Enhancement 22 first reduces Enhancement 23 effort by ~30%

**Implementation Order Recommendation**:
1. Implement Enhancement 22 first (validation is critical safety feature)
2. Then implement Enhancement 23 (reuse interval logic, add display features)
3. Extract shared functions to common utilities for maintainability