# Enhancement 23: Implementation Details

This document contains detailed implementation information for Enhancement 23: Display Restricted Times/Days in Popup.

**Related Document**: See [../enhancement-23-display-restricted-times-in-popup.md](../enhancement-23-display-restricted-times-in-popup.md) for the full enhancement description and overview.

---

## Implementation Details

### ⚠️ Critical Findings from Code Review

1. **Next Unrestricted Time is Already Implemented** ✅
   - The popup already displays "Next unrestricted time: [time]" (see `lib/popup-display.sh` line 127)
   - Uses `get_next_unrestricted_time()` from `lib/time-calculations.sh`
   - **No implementation needed** for this feature

2. **Restricted Hours Display is NOT Implemented** ⏳
   - The popup does NOT show "Restricted Hours: [Current Day] [Time Ranges]"
   - This is the remaining work for this enhancement

3. **Popup Size Concerns** ⚠️
   - **Small popup**: 400x250 pixels (only 250px height - very small!)
   - **Medium popup**: 800x500 pixels (should have plenty of space)
   - **Large popup**: 2000x1350 pixels (plenty of space)
   - **Dialog tool behavior**:
     - **YAD**: Uses `--fixed` flag - content must fit within specified dimensions (no auto-resize)
     - **Zenity**: Will auto-expand if content exceeds size - may become unreasonably large
     - **KDialog**: Auto-sizes - no size control
   - **⚠️ NO SCROLLING SUPPORT**: Dialog tools (zenity, yad, kdialog) do NOT support scrolling in warning dialogs
   - **Recommendation**: Test with small popup (400x250) - may need to:
     - Increase default height for small popup
     - Make restricted hours display optional (configurable)
     - Use abbreviated format for small popups

4. **File References Updated** ✅
   - `get_next_unrestricted_time()` is in `lib/time-calculations.sh` (not `lib/popup-display.sh`)
   - `format_hour_12h()` is in `lib/configure-core.sh` (correct)
   - `format_ranges_human()` is in `lib/configure-time.sh` (correct)
   - All interval building functions are in `lib/time-calculations.sh` and `lib/configure-validation.sh`

### Code Location Reference
- **Existing formatting functions** (can reuse from modules):
  - `format_hour_12h()` - Already exists in `lib/configure-core.sh` (can be reused)
  - `format_range_human()` - Already exists in `lib/configure-time.sh` (can be reused)
  - `format_ranges_human()` - Already exists in `lib/configure-time.sh` (can be reused)
- **Existing time calculation functions** (already implemented):
  - `get_next_unrestricted_time()` - Already exists in `lib/time-calculations.sh` (already used in popup)
  - `build_weekly_restricted_intervals()` - Already exists in `lib/time-calculations.sh`
  - `merge_overlapping_intervals()` - Already exists in `lib/configure-validation.sh` (used by time-calculations.sh)
  - `format_minute_offset_to_time()` - Already exists in `lib/time-calculations.sh`
- **Target function to modify**: `lib/popup-display.sh` `show_warning()` function (around line 122-131)
- **Config file to update**: `sleep-warning.conf`
- **Message construction**: Modify message building logic in `lib/popup-display.sh` `show_warning()` function

### Message Format Examples

**Current message (next unrestricted time already implemented):**
```
⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

Next unrestricted time: at 5:00 AM (in 3 hours 15 minutes)

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear every 10 minutes while you continue using your computer during these hours.
```

**Enhanced message (with restricted hours display added):**
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
- **Difficulty**: Low-Medium (reduced from Medium since next unrestricted time is already implemented)
- **Estimated Lines of Code**: ~100-150 lines (much less than originally estimated)
  - Restricted hours formatting: ~50 lines (reuse `format_ranges_human()` from `lib/configure-time.sh`)
  - Config option getter: ~20 lines (add to `lib/config.sh`)
  - Integration into popup: ~30-50 lines (modify `show_warning()` in `lib/popup-display.sh`)
  - Testing and edge cases: ~20-30 lines
- **Key Challenges**: 
  1. ✅ Building complete weekly timeline - Already implemented in `lib/time-calculations.sh`
  2. ✅ Merging overlapping intervals - Already implemented in `lib/configure-validation.sh`
  3. ✅ Searching for next unrestricted time - Already implemented in `lib/time-calculations.sh`
  4. Handling inherited restrictions from previous day's overnight ranges (need to detect and format)
  5. ✅ Wrap-around handling - Already implemented
  6. ✅ Formatting relative time descriptions - Already implemented
  7. **NEW**: Ensuring restricted hours display fits in small popup (400x250) - may need to increase default height or make optional
- **Dependencies**: 
  - None for basic display
  - Conceptually related to Enhancement 22 (uses similar interval merging logic)
  - Can share/adapt interval merging code if Enhancement 22 is implemented

### Performance Considerations
- **Next unrestricted time calculation**: Already implemented and optimized in `lib/time-calculations.sh`
- **Restricted hours formatting**: O(n) where n = number of ranges per day (typically 1-3)
- **Overall**: Should complete in < 5ms for formatting restricted hours
- All processing is done once per popup display
- No continuous processing or monitoring
- Config file read is already done in `main()`, can reuse parsed data via `parse_config()`
- Performance impact: Negligible (< 5ms for formatting restricted hours display)

### Code Reusability with Enhancement 22
**Status**: Enhancement 22 is already implemented, and interval building functions are available:
- ✅ Can reuse `build_weekly_restricted_intervals()` from `lib/time-calculations.sh`
- ✅ Can reuse `merge_overlapping_intervals()` from `lib/configure-validation.sh`
- ✅ Can reuse day/hour/minute conversion utilities from `lib/time-calculations.sh`
- **Implementation effort reduced**: Only need to add restricted hours formatting and display (much simpler than originally planned)

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
- **⚠️ CRITICAL**: Consider popup size limits (especially for small popup 400x250)
- **⚠️ NO SCROLLING**: Dialog tools don't support scrolling - all content must fit
- Use consistent formatting (e.g., always use → arrow, not ->)
- **Size Testing Priority**: Test small popup first - may need abbreviated format or increased height

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
