# Enhancement 23: Display Restricted Times/Days in Popup

- **Description**: Enhance the warning popup to display the configured restricted hours and days, showing users exactly when restrictions are active. This provides transparency and helps users understand why they're seeing the warning. The popup should show the current day's restricted hours in a clear, readable format, and optionally show all days' restrictions or a summary.
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`
- **Priority**: Medium (improves user experience and transparency)
- **Status**: Not implemented
- **Feasibility Assessment**: ✅ **Highly Feasible** - Read configuration and format for display
- **Implementation Approach**:
  - **Read Current Day's Restrictions**:
    - Parse configuration file to get restricted hours for current day
    - Format time ranges in human-readable format (e.g., "12:00 AM → 4:59 AM")
    - Handle overnight ranges that span midnight (e.g., "11:00 PM → 5:59 AM (next day)")
    - Handle multiple ranges per day (e.g., "12:00 AM → 4:59 AM AND 10:00 PM → 11:59 PM")
  - **Display in Popup**:
    - Add section to popup message showing current day's restricted hours
    - Use clear formatting with labels (e.g., "Restricted Hours: Monday 12:00 AM → 4:59 AM")
    - Optionally show all days' restrictions or a summary
    - Keep message concise to avoid overwhelming the popup
  - **Configuration Option**:
    - Add `POPUP_SHOW_RESTRICTED_TIMES=true/false` config option (default: `true`)
    - Allow users to disable this feature if they prefer shorter popup messages
- **Implementation Notes**:
  - **Time Range Formatting**:
    - Reuse existing `format_ranges_human()` function from `configure.sh` if possible, or implement similar logic in `sleep-warning.sh`
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
    - Can be configured via `configure.sh` in future (optional, not required for initial implementation)
  - **Edge Cases**:
    - **Overnight Ranges**: Must clearly indicate when range spans to next day
    - **Multiple Ranges**: Format clearly with "AND" separator
    - **Empty Restrictions**: If current day has no restrictions (shouldn't happen, but handle gracefully)
    - **Inherited Restrictions**: If current hour is restricted due to previous day's overnight range, show both current day and previous day's range
    - **Long Messages**: Ensure popup doesn't become too large - may need to limit text or use scrolling
  - **Implementation Location**:
    - Modify `show_warning()` function in `sleep-warning.sh`
    - Read current day's restrictions using existing `parse_config()` function
    - Format time ranges using new or existing formatting function
    - Append formatted restrictions to popup message
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
  - **Enhancement 16 (Visual Day/Time Configuration Grid)**: Users can see restrictions in configure.sh, this shows them in the popup
  - **Enhancement 5 (Configurable Warning Messages)**: Could work together - show custom message plus restricted times
  - **Enhancement 6 (Escalating Warnings)**: Could show different levels of detail at different escalation levels
  - **User Experience Enhancement**: Improves transparency and helps users understand the system
