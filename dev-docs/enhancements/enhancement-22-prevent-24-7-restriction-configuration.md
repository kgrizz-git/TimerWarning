# Enhancement 22: Prevent 24/7 Restriction Configuration

- **Description**: Add validation in `configure.sh` to detect and prevent users from configuring restricted hours that cover 24 hours a day, 7 days a week (or close to it). This prevents users from accidentally locking themselves out of their computer. The validation must evaluate the entire configuration holistically (not just individual days) to account for overnight time ranges that span multiple days. **Critical**: When counting restricted minutes, the system must detect and merge overlapping intervals both within the same day (e.g., "0-10,9-23" overlaps at hour 9) and across day boundaries due to overnight ranges (e.g., Monday "23-6" and Tuesday "0-5" overlap). Overnight ranges are identified when start hour > end hour (e.g., "23-6" spans midnight). If 24/7 restrictions (>= 10080 minutes) are detected, show a prominent error dialog and block saving. If restrictions exceed 9660 minutes (23 hours/day but < 10080), show a warning dialog, apply automatic safety overrides (disable config locking, configure.sh blocking, and restrict popup window sizes to "small" and "medium" only), and allow user to confirm or modify. Note: Hour ranges are inclusive of start hour, exclusive of end hour (e.g., "0-23" covers hours 0-22 = 23 hours total; "0-12,12-0" covers all 24 hours).
- **Files Affected**: `configure.sh`, `lib/configure-validation.sh` (new), `lib/configure-ui.sh`, `sleep-warning.conf`
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
    - Run validation check in `configure.sh` (in case 6: "Review and Save") AFTER `show_summary()` confirms but BEFORE calling `write_config()`
    - This keeps `write_config()` as a pure file I/O function (consistent with codebase patterns)
    - Validation function lives in new module `lib/configure-validation.sh`
    - Dialog functions for errors/warnings live in `lib/configure-ui.sh` (consistent with existing UI functions)
    - Check occurs after all day/time configurations are collected
    - Validation runs regardless of whether GUI or text mode is used
  - **Warning and Protection**:
    - If 24/7 detected, show prominent warning dialog (error dialog, not just info)
    - Prevent saving the configuration (require user to modify settings)
    - Automatically set `CONFIG_LOCK_ENABLED=false` (if config locking is implemented)
    - Ensure `CONFIGURE_BLOCK_ENABLED=false` (if configure.sh blocking is implemented)
    - Provide clear explanation of why 24/7 restrictions are problematic
- **Implementation Notes**:
  - **Config Line Format** (from `config_lines[]` array):
    - Format: `"DAYVAR=RANGE"` (e.g., `"SUNDAY=0-5"` or `"MONDAY="` for skipped days)
    - `DAYVAR` is one of: `SUNDAY`, `MONDAY`, `TUESDAY`, `WEDNESDAY`, `THURSDAY`, `FRIDAY`, `SATURDAY`
    - `RANGE` is empty string `""` for skipped days, or time range like `"0-5"` or `"0-5,22-23"`
    - Array indices 0-6 correspond to Sunday-Saturday (matching `DAY_VARS[]` in `lib/configure-core.sh`)
    - Parsing example:
      ```bash
      local line="${config_lines[$i]}"
      local range="${line#*=}"  # Extract everything after '='
      # If range is empty, day is skipped (0 restricted minutes)
      ```
  - **Time Range Format**:
    - Hour ranges are inclusive of start hour, exclusive of end hour (following logic in `lib/time-validation.sh`)
    - Example: "0-23" covers hours 0 through 22 (23 hours total: 00:00-22:59)
    - Example: "0-5" covers hours 0 through 4 (5 hours total: 00:00-04:59)
    - To cover all 24 hours, use combination like "0-12,12-0" (12 hours + 12 hours = 24 hours)
  - **Time Range Calculation** (minute-level precision):
    - Hour H converts to minute H × 60 (e.g., hour 0 = minute 0, hour 23 = minute 1380)
    - Range "START-END" covers interval [START×60, END×60) - inclusive start, exclusive end
    - For each day, parse time ranges (e.g., "22-6", "14-16")
    - For overnight ranges (start > end), split into two segments:
      - Segment 1: [start×60, 1440) on current day (e.g., "23-6" → [1380, 1440) = minutes 1380-1439)
      - Segment 2: [0, end×60) on next day (e.g., "23-6" → [0, 360) = minutes 0-359 of next day)
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
    # Pseudocode for lib/configure-validation.sh
    check_restriction_coverage() {
      local config_lines=("$@")
      local all_intervals=()
      
      for i in 0 1 2 3 4 5 6; do  # Sunday=0 through Saturday=6
        local line="${config_lines[$i]}"
        [ -z "${line}" ] && continue  # Day not configured
        
        local range="${line#*=}"  # Extract after '='
        [ -z "${range}" ] && continue  # Day explicitly skipped
        
        local day_offset=$((i * 1440))  # Minutes offset for this day
        
        # Parse comma-separated ranges
        IFS=',' read -ra ranges <<< "${range}"
        for r in "${ranges[@]}"; do
          local start_hour="${r%%-*}"
          local end_hour="${r##*-}"
          
          if [ "${start_hour}" -gt "${end_hour}" ]; then
            # Overnight range: split into two segments
            # Segment 1: [start×60, 1440) on current day
            all_intervals+=("$((day_offset + start_hour * 60)):$((day_offset + 1440))")
            # Segment 2: [0, end×60) on next day (wrap Saturday→Sunday)
            local next_day=$(( (i + 1) % 7 ))
            local next_offset=$((next_day * 1440))
            all_intervals+=("${next_offset}:$((next_offset + end_hour * 60))")
          else
            # Normal range: [start×60, end×60) on current day
            all_intervals+=("$((day_offset + start_hour * 60)):$((day_offset + end_hour * 60))")
          fi
        done
      done
      
      # Sort intervals by start minute and merge overlapping/adjacent
      local merged_intervals=($(merge_overlapping_intervals "${all_intervals[@]}"))
      
      # Calculate total restricted minutes
      local total=0
      for interval in "${merged_intervals[@]}"; do
        local start="${interval%%:*}"
        local end="${interval##*:}"
        total=$((total + end - start))
      done
      
      if [ "${total}" -ge 10080 ]; then
        echo "block"  # 24/7 detected - block configuration
      elif [ "${total}" -gt 9660 ]; then
        echo "warn"   # > 23 hours/day - show warning, allow confirmation
      else
        echo "ok"     # Valid configuration
      fi
    }
    
    # Merge overlapping/adjacent intervals
    # Input: array of "start:end" strings
    # Output: merged "start:end" strings (one per line)
    merge_overlapping_intervals() {
      local intervals=("$@")
      [ ${#intervals[@]} -eq 0 ] && return
      
      # Sort by start minute
      IFS=$'\n' sorted=($(sort -t: -k1 -n <<< "${intervals[*]}"))
      unset IFS
      
      local current_start="${sorted[0]%%:*}"
      local current_end="${sorted[0]##*:}"
      
      for interval in "${sorted[@]:1}"; do
        local start="${interval%%:*}"
        local end="${interval##*:}"
        
        if [ "${start}" -le "${current_end}" ]; then
          # Overlap or adjacent: extend current interval
          [ "${end}" -gt "${current_end}" ] && current_end="${end}"
        else
          # No overlap: output current, start new
          echo "${current_start}:${current_end}"
          current_start="${start}"
          current_end="${end}"
        fi
      done
      echo "${current_start}:${current_end}"  # Output last interval
    }
    ```
  - **Error Dialog (24/7 detected, >= 10080 minutes)**:
    - Create `show_24_7_error()` function in `lib/configure-ui.sh`
    - Use existing `show_info_dialog()` from `lib/configure-dialogs.sh` with "ERROR:" prefix in title (consistent with codebase patterns)
    - Title: "ERROR: 24/7 Restrictions Detected"
    - Message should explain:
      - "You have configured restrictions for all 24 hours, 7 days a week."
      - "This would effectively lock you out of your computer."
      - "Please modify your settings to leave at least some unrestricted time."
      - "Configuration cannot be saved until you reduce the restriction level."
    - Dialog should be modal and require user acknowledgment
    - After acknowledgment, return to configuration menu (continue in main loop, don't call `write_config()`)
    - Text mode: Use `echo "ERROR: ..." >&2` followed by `read -p "Press Enter to continue..."`
    - Implementation pattern (follows existing functions like `confirm_cancel()` and `show_help_dialog()`):
      ```bash
      show_24_7_error() {
          local use_gui="$1"
          local title="ERROR: 24/7 Restrictions Detected"
          local message="You have configured restrictions for all 24 hours, 7 days a week.\n\nThis would effectively lock you out of your computer.\n\nPlease modify your settings to leave at least some unrestricted time.\n\nConfiguration cannot be saved until you reduce the restriction level."
          
          if [ "${use_gui}" = "true" ] && has_dialog_tool; then
              show_info_dialog "${title}" "${message}" 550 280
          else
              echo "" >&2
              echo "========================================" >&2
              echo "ERROR: 24/7 Restrictions Detected" >&2
              echo "========================================" >&2
              echo "" >&2
              echo "You have configured restrictions for all 24 hours, 7 days a week." >&2
              echo "This would effectively lock you out of your computer." >&2
              echo "Please modify your settings to leave at least some unrestricted time." >&2
              echo "Configuration cannot be saved until you reduce the restriction level." >&2
              echo "" >&2
              read -p "Press Enter to continue..."
          fi
      }
      ```
  
  - **Warning Dialog (> 9660 minutes, > 23 hours/day)**:
    - Create `show_high_restriction_warning()` function in `lib/configure-ui.sh`
    - Use existing `show_question_dialog()` from `lib/configure-dialogs.sh` (consistent with codebase patterns)
    - Title: "Warning: Very High Restriction Level"
    - Message should explain:
      - "You have configured restrictions for more than 23 hours per day."
      - "This leaves very little unrestricted time and may effectively lock you out."
      - "Safety measures will be applied: config locking features disabled, popup size limited to small/medium."
      - "Do you want to save this configuration anyway?"
    - Dialog should offer two options:
      - "Yes, Save Anyway" - returns 0, proceed with saving (user acknowledges risk)
      - "No, Modify Settings" - returns 1, return to configuration menu
    - If user confirms, apply safety overrides in `configure.sh` before calling `write_config()`
    - Text mode: Use `read -p "Save anyway? [y/N]: "` pattern (follows existing `confirm_cancel()` pattern)
    - Implementation pattern:
      ```bash
      show_high_restriction_warning() {
          local use_gui="$1"
          local title="Warning: Very High Restriction Level"
          local message="You have configured restrictions for more than 23 hours per day.\n\nThis leaves very little unrestricted time and may effectively lock you out.\n\nSafety measures will be applied:\n• Config locking features will be disabled\n• Popup size will be limited to small/medium\n\nDo you want to save this configuration anyway?"
          
          if [ "${use_gui}" = "true" ] && has_dialog_tool; then
              show_question_dialog "${title}" "${message}" "Yes, Save Anyway" "No, Modify Settings"
              return $?
          else
              echo "" >&2
              echo "WARNING: Very High Restriction Level" >&2
              echo "" >&2
              echo "You have configured restrictions for more than 23 hours per day." >&2
              echo "This leaves very little unrestricted time and may effectively lock you out." >&2
              echo "" >&2
              echo "Safety measures will be applied:" >&2
              echo "• Config locking features will be disabled" >&2
              echo "• Popup size will be limited to small/medium" >&2
              echo "" >&2
              read -p "Save anyway? [y/N]: " answer
              case "${answer}" in
                  [Yy]*) return 0 ;;
                  *) return 1 ;;
              esac
          fi
      }
      ```
  - **Automatic Safety Overrides**:
    - When restrictions >= 10080 minutes (24/7) detected: configuration is BLOCKED (not saved), error dialog shown
    - When restrictions > 9660 minutes but < 10080 minutes (> 23 hours/day) detected, automatically set in configuration before writing:
      - `CONFIG_LOCK_ENABLED=false` (prevents config file locking)
      - `CONFIGURE_BLOCK_ENABLED=false` (prevents configure.sh blocking)
      - Restrict popup window size to "small" or "medium" only (if user had "large" or "fullscreen" selected, automatically change to "medium")
    - These overrides should be applied even if user previously enabled them
    - Add comment in config file explaining why these are disabled:
      - For 24/7 (>= 10080): "# CONFIG_LOCK_ENABLED and CONFIGURE_BLOCK_ENABLED are disabled because 24/7 restrictions were detected. This prevents accidental lockout."
      - For > 9660 (but < 10080): "# CONFIG_LOCK_ENABLED and CONFIGURE_BLOCK_ENABLED are disabled because restrictions exceed 23 hours/day. This prevents accidental lockout."
      - For > 9660: "# POPUP_SIZE has been restricted to small/medium only because restrictions exceed 23 hours/day. This prevents overly intrusive popups."
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
  - **Bypass Risk**: Low - Validation runs in `configure.sh` before `write_config()`, user would need to manually edit config file to bypass
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
  - **Automatic Protection**: Automatically disabling config locking, configure.sh blocking, and large popup sizes provides safety net
  - **Non-Blocking**: User can still modify configuration after seeing warning (just can't save 24/7 config)
  - **Transparency**: Config file comment explains why safety features are disabled
  - **Less Intrusive Popups**: Restricting popup sizes to small/medium prevents overly intrusive warnings when user has very limited unrestricted time
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
  - **Enhancement 03 (Enhanced Window Size Options)**: This enhancement restricts popup window sizes to small/medium only when restrictions > 9660 minutes
  - **Safety Feature**: Complements other safety features by preventing the most dangerous configuration scenario

## Implementation Checklist

### Phase 1: Core Validation Function
- [x] **Create new module `lib/configure-validation.sh`**
  - [x] Add module header comment explaining purpose: configuration validation (24/7 detection, high restriction detection)
  - [x] Add dependency note: requires `configure-core.sh` (for `DAY_VARS` array)
  - [x] Source this module in `configure.sh` after `configure-config.sh`

- [x] **Create `check_restriction_coverage()` function** in `lib/configure-validation.sh`
  - [x] Function accepts config_lines array as positional parameters: `check_restriction_coverage "${config_lines[@]}"`
  - [x] Iterate through all 7 days (indices 0-6: Sunday-Saturday)
  - [x] For each day, parse time ranges from config (handle empty/skipped days)
  - [x] For each time range on each day:
    - [x] Parse range format: "START-END" or "START-END,START-END"
    - [x] Handle normal ranges (start < end): convert to minutes within same day
    - [x] Handle overnight ranges (start > end): split into two segments:
      - [x] Segment 1: start hour to 23:59 on current day
      - [x] Segment 2: 00:00 to end hour on next day (handle wrap-around: Saturday → Sunday)
  - [x] Convert each segment to unified weekly timeline (minutes 0-10079)
    - [x] Day 0 (Sunday): minutes 0-1439
    - [x] Day 1 (Monday): minutes 1440-2879
    - [x] Day 2 (Tuesday): minutes 2880-4319
    - [x] Day 3 (Wednesday): minutes 4320-5759
    - [x] Day 4 (Thursday): minutes 5760-7199
    - [x] Day 5 (Friday): minutes 7200-8639
    - [x] Day 6 (Saturday): minutes 8640-10079
  - [x] **CRITICAL: Merge overlaps within the same day first**
    - [x] For each day, collect all intervals for that day
    - [x] Merge overlapping intervals within the day (e.g., "0-10,9-23" → "0-23")
    - [x] Example: Monday "0-10,9-23" should merge to "0-23" (24 hours) before counting
  - [x] Store all intervals as [start_minute, end_minute] pairs
  - [x] **CRITICAL: Merge overlapping intervals across day boundaries**
    - [x] Merge overlaps between days (e.g., Monday "23-6" and Tuesday "0-5" overlap at hours 0-5)
    - [x] Handle wrap-around: Saturday overnight ranges may overlap with Sunday ranges
  - [x] Calculate total restricted minutes across all merged intervals
  - [x] Return "block" if total >= 10080 (24/7), "warn" if total > 9660 (23 hours/day), "ok" otherwise

- [x] **Implement interval merging logic**
  - [x] **Single-phase merging approach** (Note: implemented as single-phase since all intervals mapped to absolute minutes 0-10079, which correctly handles both within-day and cross-day overlaps):
    - [x] **Within-day merging** - Handled by single merge pass (intervals sorted by absolute minute)
      - [x] For each day, collect all intervals for that day
      - [x] Sort intervals by start minute
      - [x] Merge overlapping/adjacent intervals within the day
      - [x] Example: "0-10,9-23" → [0, 600] and [540, 1380] → [0, 1380] (24 hours)
    - [x] **Cross-day merging** - Handled by same single merge pass
      - [x] Collect all intervals into single array
      - [x] Sort intervals by start minute (across entire week)
      - [x] Merge overlapping/adjacent intervals across day boundaries
      - [x] Example: Monday [1320, 1440] (23-0) and Tuesday [0, 300] (0-5) → [1320, 1740]
  - [x] Handle wrap-around intervals (Saturday overnight → Sunday)
  - [x] Calculate total minutes from merged intervals (avoid double-counting)

- [x] **Handle edge cases in validation**
  - [x] Empty days (no restrictions) - count as 0 restricted minutes
  - [x] Days with empty string "" (explicitly skipped) - count as 0 restricted minutes
  - [x] Multiple ranges per day (e.g., "0-5,22-23") - process all ranges
  - [x] **Overlapping ranges within same day** (e.g., "0-10,9-23" should merge to "0-23") - CRITICAL
  - [x] **Overlapping ranges across day boundaries** (e.g., Monday "23-6" and Tuesday "0-5" overlap) - CRITICAL
  - [x] Overnight ranges that wrap around week (Saturday 23-6 → Sunday)
  - [x] Boundary cases: exactly 10080 minutes (24/7) vs 10079 minutes (not 24/7)
  - [x] Boundary cases: exactly 9660 minutes (23 hours/day = "ok", should NOT warn) vs 9661 minutes (should warn)

### Phase 2: Integration into configure.sh
- [x] **Source the new validation module in configure.sh**
  - [x] Add `source "${LIB_DIR}/configure-validation.sh" || exit 1` after `configure-config.sh` source line
  - [x] This makes `check_restriction_coverage()` available in `configure.sh`

- [x] **Create error dialog function (24/7 detected)**
  - [x] Create `show_24_7_error()` function in `lib/configure-ui.sh`
  - [x] Support both GUI mode (yad/zenity/kdialog) and text mode
  - [x] Use existing `show_info_dialog()` with "ERROR:" prefix in title (consistent with codebase)
  - [x] Title: "ERROR: 24/7 Restrictions Detected"
  - [x] Message includes:
    - [x] "You have configured restrictions for all 24 hours, 7 days a week."
    - [x] "This would effectively lock you out of your computer."
    - [x] "Please modify your settings to leave at least some unrestricted time."
    - [x] "Configuration cannot be saved until you reduce the restriction level."
  - [x] Dialog is modal and requires user acknowledgment
  - [x] Text mode: `echo "ERROR: ..." >&2` followed by `read -p "Press Enter to continue..."`

- [x] **Create warning dialog function (> 9660 minutes)**
  - [x] Create `show_high_restriction_warning()` function in `lib/configure-ui.sh`
  - [x] Support both GUI mode (yad/zenity/kdialog) and text mode
  - [x] Use existing `show_question_dialog()` (consistent with codebase)
  - [x] Title: "Warning: Very High Restriction Level"
  - [x] Message includes:
    - [x] "You have configured restrictions for more than 23 hours per day."
    - [x] "This leaves very little unrestricted time and may effectively lock you out."
    - [x] "Safety measures will be applied: config locking features disabled, popup size limited."
    - [x] "Do you want to save this configuration anyway?"
  - [x] Dialog offers two options:
    - [x] "Yes, Save Anyway" (returns 0) - proceed with saving
    - [x] "No, Modify Settings" (returns 1) - return to configuration menu
  - [x] Text mode: `read -p "Save anyway? [y/N]: "` pattern (follows `confirm_cancel()` pattern)

- [x] **Integrate validation into save flow (case 6 in configure.sh)**
  - [x] Locate "Review and Save" option (menu choice 6) in `configure.sh` main() function
  - [x] **DO NOT modify `write_config()`** - keep it as a pure file I/O function
  - [x] Add validation check AFTER `show_summary()` returns true, BEFORE calling `write_config()`
  - [x] Implementation pattern:
    ```bash
    # In configure.sh, case 6:
    if show_summary "${use_gui}" ...; then
        # Validate restriction coverage before saving
        local validation_result
        validation_result=$(check_restriction_coverage "${config_lines[@]}")
        
        case "${validation_result}" in
            "block")
                show_24_7_error "${use_gui}"
                continue  # Return to menu, don't call write_config
                ;;
            "warn")
                if ! show_high_restriction_warning "${use_gui}"; then
                    continue  # User cancelled, return to menu
                fi
                # User confirmed - apply safety overrides before saving
                if [ "${popup_size}" = "large" ] || [ "${popup_size}" = "fullscreen" ]; then
                    popup_size="medium"
                fi
                # Future: disable CONFIG_LOCK_ENABLED, CONFIGURE_BLOCK_ENABLED if implemented
                ;;
            # "ok" - proceed normally
        esac
        
        # Now call write_config with (possibly modified) values
        if write_config "${check_interval}" "${popup_size}" ...; then
            ...
    ```
  - [x] Ensure config file is NOT written if validation returns "block" or user cancels warning

### Phase 3: Automatic Safety Overrides
- [ ] **Disable config locking features when high restrictions detected**
  - [ ] When restrictions >= 10080 minutes (24/7) detected:
    - [ ] Configuration is BLOCKED from being saved (validation returns "block")
    - [ ] Error dialog is shown (no config file is written)
  - [ ] When restrictions > 9660 minutes but < 10080 minutes (> 23 hours/day) detected, automatically set in memory (before write):
    - [ ] `CONFIG_LOCK_ENABLED=false` (if enhancement #18 is implemented)
    - [ ] `CONFIGURE_BLOCK_ENABLED=false` (if enhancement #19 is implemented)
    - [ ] `CONFIG_LOCK_ADDITIONAL_HOURS=""` (if enhancement #20 is implemented)
  - [ ] These overrides apply even if user previously enabled them
  - [ ] Add comment in config file explaining why these are disabled:
    - [ ] For > 9660 (but < 10080): "# CONFIG_LOCK_ENABLED and CONFIGURE_BLOCK_ENABLED are disabled because restrictions exceed 23 hours/day. This prevents accidental lockout."

- [ ] **Restrict popup window size when high restrictions detected**
  - [ ] When restrictions > 9660 minutes (> 23 hours/day) detected, automatically restrict popup window size:
    - [ ] If `POPUP_SIZE` is currently set to "large" or "fullscreen", change it to "medium"
    - [ ] Only allow "small" or "medium" options for popup size
    - [ ] This prevents excessively intrusive popups when user has very limited unrestricted time
  - [ ] Add comment in config file explaining the popup size restriction:
    - [ ] "# POPUP_SIZE has been restricted to small/medium only because restrictions exceed 23 hours/day. This prevents overly intrusive popups."
  - [ ] If user later reduces restrictions to <= 9660 minutes, they can manually re-enable large/fullscreen if desired
  - [ ] In `lib/configure-input.sh` popup size configuration:
    - [ ] During configuration, if high restrictions (> 9660) are present, only show "small" and "medium" options
    - [ ] Show info message explaining: "Due to high restriction level (> 23 hours/day), only small and medium popup sizes are available for safety."

- [ ] **Handle conditional implementation**
  - [ ] Check if config locking features exist before trying to disable them
  - [ ] Use feature detection (check if variables/functions exist) rather than hardcoding
  - [ ] If features don't exist yet, validation still works (just skip override step)

### Phase 4: Testing
**⚠️ IMPORTANT: DO NOT RUN ANY TESTS FROM THIS ENHANCEMENT WITHOUT EXPLICIT USER CONFIRMATION! ⚠️**
**These tests modify system configuration and could impact computer access. Always confirm with user before running any tests.**

- [ ] **Test normal configurations (validation should pass, allow saving) - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [ ] **Note**: "should pass" means the validation should allow the configuration to be saved (no 24/7 detected, write_config() succeeds)
  - [ ] Test with no restrictions (all days empty)
  - [ ] Test with partial restrictions (e.g., only weekdays 0-5)
  - [ ] Test with weekend-only restrictions
  - [ ] Test with single day restrictions
  - [ ] Test with overnight ranges that don't cover 24/7
  - [ ] Test with multiple ranges per day that don't cover 24/7

- [ ] **Test 24/7 configurations (validation should detect and block) - DO NOT AUTO-RUN!**
**Note**: "should fail" means the validation should detect 24/7 restrictions and prevent saving the configuration (show warning dialog, block write_config(), return error)
  - [ ] **IMPORTANT**: DO NOT AUTO-RUN. Before running any of these, set popup frequency to 15 minutes, minimum time 5 seconds, immovable window to off, and config file lock and configure.sh prevention both to off (if implemented).
  - [ ] Test with all days set to "0-23" (23 hours each day: 00:00-22:59) - Note: This is 161 hours/week = 9660 minutes, exactly at threshold, so validation should pass (not warn or block)
  - [X] Test with configurations that actually total 24/7 (10080 minutes):
    - [X] Each day has "0-12,12-0" (overnight range "12-0" covers hours 12-23, so "0-12" + "12-0" = 24 hours) - validation should detect and block
    - [X] Each day has multiple ranges that together cover all 24 hours (e.g., "0-8,8-16,16-0" where "16-0" overnight covers hours 16-23) - validation should detect and block
    - [ ] Each day has "23-23" (wraps around, but invalid - start == end) - should be caught by format validation first, before 24/7 check
    - [ ] Each day has "23-0" as overnight range (covers only hour 23: 23:00-23:59, not 24 hours) - verify this is NOT detected as 24/7
  - [X] Test with combination of normal and overnight ranges that total 24/7 - validation should detect and block
  - [X] Test with exactly 10080 minutes (24/7) - validation should detect and block
  - [ ] Test with 10079 minutes (not 24/7) - validation should pass, allow saving

- [ ] **Test high restriction level (> 9660 minutes, > 23 hours/day) - should warn - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
**Note**: "should warn" means validation should show warning dialog, but allow user to confirm and save
  - [ ] Test with exactly 9661 minutes (just over 23 hours/day) - validation should show warning, allow confirmation
  - [ ] Test with all days set to "0-23" plus one day with additional hour (e.g., Monday "0-23,23-0") - should warn
  - [X] Test with overlapping ranges that total > 9660 minutes:
    - [ ] Each day has "0-10,9-23" (overlaps at hours 9-10, should merge to "0-23" = 23 hours) - exactly 9660, should pass
    - [ ] Each day has "0-10,8-23" (overlaps at hours 8-10, should merge to "0-23" = 23 hours) - exactly 9660, should pass
    - [ ] Each day has "0-12,11-23" (overlaps at hours 11-12, should merge to "0-23" = 23 hours) - exactly 9660, should pass
    - [X] Each day has "0-12,12-0" (no overlap, covers all 24 hours) - should block (10080 minutes)
  - [ ] Test warning dialog behavior:
    - [X] User confirms warning → configuration saves successfully
    - [ ] User cancels warning → returns to configuration menu, no save

- [ ] **Test edge cases - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [ ] Test overnight range on Saturday (23-6) that wraps to Sunday
  - [ ] Test multiple overlapping ranges that merge to 24/7
  - [ ] Test empty days mixed with 24-hour restricted days
  - [ ] Test multiple ranges per day (e.g., "0-12,12-23" = 24 hours)
  - [ ] **Test within-day overlaps** (CRITICAL):
    - [X] "0-10,9-23" on single day (overlaps at hours 9-10, should merge to "0-23" = 23 hours)
    - [ ] "0-5,4-8,7-12" on single day (multiple overlaps, should merge correctly)
    - [ ] "0-12,11-23" on single day (overlaps at hour 11-12, should merge to "0-23" = 23 hours)
    - [ ] "0-12,12-0" on single day (no overlap, covers all 24 hours) - should be detected as 24 hours
  - [X] **Test cross-day overlaps** (CRITICAL):
    - [X] Monday "23-6" and Tuesday "0-5" (overlap at hours 0-5, should merge correctly)
    - [X] Saturday "23-6" and Sunday "0-5" (wrap-around overlap, should merge correctly)

- [ ] **Test error dialog (24/7 detected) - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [X] Test in GUI mode (yad)
  - [ ] Test in GUI mode (zenity)
  - [ ] Test in GUI mode (kdialog)
  - [ ] Test in text mode
  - [X] Verify dialog is modal and blocks saving
  - [X] Verify user can return to configuration after seeing error
  - [ ] Verify config file is NOT written when validation blocks

- [ ] **Test warning dialog (> 9660 minutes) - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [X] Test in GUI mode (yad)
  - [ ] Test in GUI mode (zenity)
  - [ ] Test in GUI mode (kdialog)
  - [ ] Test in text mode
  - [X] Verify dialog offers "Yes, Save Anyway" and "No, Modify Settings" options
  - [X] Verify "Yes, Save Anyway" allows saving
  - [ ] Verify "No, Modify Settings" returns to configuration menu without saving
  - [ ] Verify config file is written only if user confirms

- [ ] **Test integration with config locking features (if implemented) - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
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

- [ ] **Test popup window size restrictions (if implemented) - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [ ] Test with high restrictions (> 9660 minutes):
    - [ ] Configure restrictions > 9660 minutes with POPUP_SIZE set to "large"
    - [X] Verify POPUP_SIZE is automatically changed to "medium" after validation
    - [ ] Verify config file comment explains popup size restriction
    - [ ] Configure restrictions > 9660 minutes with POPUP_SIZE set to "fullscreen"
    - [ ] Verify POPUP_SIZE is automatically changed to "medium" after validation
    - [ ] Configure restrictions > 9660 minutes with POPUP_SIZE already set to "small" or "medium"
    - [ ] Verify POPUP_SIZE is NOT changed (already compliant)
  - [ ] Test with normal restrictions (<= 9660 minutes):
    - [ ] Verify POPUP_SIZE is NOT automatically restricted
    - [ ] User can select "large" or "fullscreen" options normally
  - [ ] Test popup size configuration menu with high restrictions:
    - [ ] During configure.sh, if restrictions > 9660 detected, verify only "small" and "medium" options are shown
    - [ ] Verify info message explaining popup size restriction is displayed
  - [ ] Test popup size configuration menu with normal restrictions:
    - [ ] Verify all four options (small, medium, large, fullscreen) are available

- [ ] **Test user workflow - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [X] User configures 24/7 restrictions → warning appears → user modifies → saves successfully
  - [ ] User configures 24/7 restrictions → warning appears → user cancels → no config saved
  - [ ] User configures valid restrictions → no warning → saves successfully

### Phase 5: Code Quality and Documentation
- [x] **Code documentation**
  - [x] Add module header comment for `lib/configure-validation.sh` explaining:
    - [x] Purpose: configuration validation functions for 24/7 restriction detection
    - [x] Dependencies: `configure-core.sh` (for `DAY_VARS` array, though not strictly required)
    - [x] Functions: `check_restriction_coverage()`, `merge_overlapping_intervals()`
  - [x] Add function header comment for `check_restriction_coverage()` in `lib/configure-validation.sh` explaining:
    - [x] Purpose: prevent 24/7 restriction configuration and detect high restriction levels
    - [x] Input: config_lines array or summary_lines array
    - [x] Output: returns "block" if >= 10080 minutes (24/7), "warn" if > 9660 minutes (> 23 hours/day), "ok" if valid
    - [x] Algorithm: converts all ranges to unified timeline, merges overlaps, calculates total restricted minutes
  - [x] Add inline comments explaining:
    - [x] How overnight ranges are split
    - [x] How intervals are merged
    - [x] How weekly timeline mapping works
    - [x] Why 10080 is the threshold
  - [ ] After completing the automatic safety overrides once config locking and blocking of manage and configure scripts are implemented, review code and update comments as necessary

- [x] **Error handling**
  - [x] Handle invalid time range formats gracefully
  - [x] Handle missing config_lines entries (undefined array indices)
  - [x] Handle edge cases in interval merging (empty arrays, single interval, etc.)
  - [x] Add error logging if validation encounters unexpected data (handled via graceful skipping of invalid ranges)
  - [ ] After completing the automatic safety overrides once config locking and blocking of manage and configure scripts are implemented, verify error handling is robust

- [x] **Performance considerations**
  - [x] Validation should complete quickly (< 1 second)
  - [x] Use efficient algorithms for interval merging (O(n log n) sort + O(n) merge)
  - [x] Avoid unnecessary calculations or loops

- [x] **Technical documentation**
  - [x] Add section to `dev-docs/TECHNICAL_DETAILS.md` about 24/7 restriction prevention feature
  - [x] Document the validation algorithm and approach
  - [x] Explain how overnight ranges are handled in the validation
  - [x] Document the interval merging logic
  - [x] Explain the automatic safety feature disabling (config locking, configure.sh blocking, popup size restrictions)
  - [x] Document the popup size restriction logic (why only small/medium are allowed for > 9660 minutes)
  - [x] Include examples of valid vs invalid configurations
  - [x] Reference this enhancement document for detailed implementation notes
  - [ ] After completing the automatic safety overrides once config locking and blocking of manage and configure scripts are implemented, update technical documentation

### Phase 6: User Documentation
- [x] **Update user documentation**
  - [x] Add note in `user-docs/CONFIGURATION.md` about 24/7 restriction prevention
  - [x] Explain why 24/7 restrictions are blocked
  - [x] Provide examples of valid vs invalid configurations
  - [x] Document the automatic safety feature disabling (config locking, configure.sh blocking, popup size restrictions)
  - [x] Explain popup size restrictions for high restriction levels (> 9660 minutes): only small/medium allowed
  - [x] Document rationale: prevents overly intrusive popups when user has very limited unrestricted time
  - [ ] After completing the automatic safety overrides once config locking and blocking of manage and configure scripts are implemented, update user documentation

- [x] **Update help text in configure modules**
  - [x] Add note in welcome message (`lib/configure-ui.sh`) about 24/7 restriction prevention
  - [x] Update help dialog (`lib/configure-ui.sh`) to mention this safety feature
  - [ ] Add info message in popup size configuration menu (`lib/configure-input.sh`) when high restrictions are detected (Note: Will be completed when Phase 3 automatic safety overrides are implemented)

### Phase 7: Integration Testing
**⚠️ DO NOT RUN TESTS WITHOUT USER CONFIRMATION! ⚠️**

- [X] **Test with existing features - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [X] Verify validation doesn't break existing configuration workflow
  - [X] Verify validation works with visual grid (option 5)
  - [X] Verify validation works with weekdays/weekends bulk configuration
  - [X] Verify validation works when loading existing config and modifying it

- [ ] **Test backward compatibility - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [ ] Existing valid configs should still work
  - [ ] Existing invalid configs (if any exist) should be caught on next save
  - [ ] Config file format remains unchanged

### Phase 8: Final Validation
**⚠️ DO NOT RUN TESTS WITHOUT USER CONFIRMATION! ⚠️**

- [ ] **Code review checklist**
  - [ ] All functions have proper error handling
  - [ ] All edge cases are handled
  - [ ] Code follows existing style conventions in configure modules
  - [ ] No hardcoded values (use constants for 10080, 1440, etc.)
  - [ ] Functions are well-documented

- [ ] **Manual testing - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [ ] Run through complete configuration workflow
  - [ ] Test both GUI and text modes
  - [ ] Verify warning appears at correct time
  - [ ] Verify config file is not saved when validation fails
  - [ ] Verify user can modify and save after seeing warning

- [ ] **Edge case validation - DO NOT AUTO-RUN! CONFIRM WITH USER FIRST!**
  - [ ] Test with all possible overnight range combinations
  - [ ] Test with maximum number of ranges per day
  - [ ] Test with boundary values (10079 vs 10080 minutes)
  - [ ] Test with empty configuration (should pass)
