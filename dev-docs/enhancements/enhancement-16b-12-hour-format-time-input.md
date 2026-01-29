# Enhancement 16b: 12-Hour Format Time Input with Minute Precision and GUI Spinbox Widgets
- **Description**: Add support for 12-hour format time entry (e.g., "11pm-5am", "11:30pm-5:30am") with minute precision in addition to 24-hour format, and provide GUI spinbox widgets for easier time selection with AM/PM toggle
- **Files Affected**: `lib/configure-input.sh`, `lib/configure-time.sh`, `lib/config.sh`, `lib/time-validation.sh`, `sleep-warning.conf` (format change to support minutes)
- **Priority**: Medium (improves usability, especially for users more familiar with 12-hour format and needing precise timing)
- **Status**: MOSTLY implemented
- **Current Implementation**:
  - Time ranges entered in 24-hour format only: `DAY=START_HOUR-END_HOUR` (e.g., `SUNDAY=23-5`)
  - Text-based input via `get_day_hours()` function
  - GUI mode uses text entry fields (zenity/yad text input)
  - Configuration stored in 24-hour format internally
  - **Hour-only precision**: No support for minutes (e.g., cannot specify 23:30)
- **Implementation Approaches**:
  - **Option 1: Dual Format Support with Minute Precision (Text Input)**:
    - Accept both 24-hour format (`23-5`, `23:30-5:30`) and 12-hour format (`11pm-5am`, `11:30pm-5:30am`, `11:30PM-5:30AM`)
    - Parse input to detect format automatically
    - Convert 12-hour format to 24-hour format for internal storage
    - Support common variations: `11pm`, `11PM`, `11:00pm`, `11:30pm`, `11:00 PM`, `11 pm`, `11:30 pm`
    - Handle midnight/noon edge cases: `12am` = `0`, `12pm` = `12`
    - **Minute support**: Allow any minute value (0-59), but provide shortcuts for common increments:
      - Hour-only input (`11pm-5am`) defaults to `:00` (top of the hour)
      - Support 30-minute increments (`11:30pm-5:30am`)
      - Support any minute precision (`11:45pm-5:15am`)
    - Display format preference: Allow user to choose display format (12-hour vs 24-hour) while storing in 24-hour format with minutes
  - **Option 2: GUI Spinbox Widgets with Minute Precision** (Recommended for GUI mode):
    - **zenity/yad Implementation**:
      - Use `yad --form` with spinbox widgets for hour (1-12), minute (0-59), and AM/PM toggle
      - Use `zenity --forms` with entry fields and separate AM/PM dropdown/radio buttons
      - Create custom dialog with hour/minute spinboxes and AM/PM selector
      - **Minute spinbox options**:
        - Full precision: 0-59 with step=1 (allows any minute)
        - 30-minute increments: 0-59 with step=30 (0, 30 only)
        - 15-minute increments: 0-59 with step=15 (0, 15, 30, 45)
        - Recommended: Full precision with default=0, or combobox with common values (00, 15, 30, 45)
      - **Limitations**: zenity may not support native spinboxes, may need workarounds with entry fields
      - **yad Advantages**: Better widget support, can use `--field` with spinbox type
    - **kdialog Implementation**:
      - Use `kdialog --combobox` or custom Qt widgets for time selection
      - Better widget support than zenity for spinboxes
      - Support hour and minute selection
    - **Text Mode Fallback**:
      - Keep current text-based input for terminal mode
      - Add 12-hour format with minute parsing support
  - **Option 3: Hybrid Approach with Minute Precision** (Recommended):
    - **GUI Mode**: Use spinbox widgets (yad preferred, zenity fallback) with hour (1-12), minute (0-59), and AM/PM selector
    - **Text Mode**: Accept both 24-hour and 12-hour format text input with optional minutes (e.g., `23:30-5:30`, `11:30pm-5:30am`)
    - **Internal Storage**: Store in 24-hour format with minutes (e.g., `DAY=23:30-5:30`). Hour-only formats default to `:00`
    - **Display**: Show times in user's preferred format (12-hour or 24-hour) with minutes in summaries and status
    - **Backward Compatibility**: Hour-only configs (`DAY=23-5`) are treated as `DAY=23:00-5:00`
- **Implementation Notes**:
  - **Format Parsing with Minute Support**:
    - Create `parse_time_input()` function to detect and parse both formats with optional minutes
    - Support formats:
      - 24-hour: `23`, `23-5`, `23:30`, `23:30-5:30`, `23:00-5:00`
      - 12-hour: `11pm`, `11pm-5am`, `11:00pm-5:00am`, `11:30pm-5:30am`, `11 PM - 5 AM`, `11:30 PM - 5:30 AM`
      - Hour-only formats default to `:00` minutes
    - Handle case-insensitive parsing (`pm`, `PM`, `Pm`)
    - Validate input ranges:
      - Hours: 1-12 for 12-hour, 0-23 for 24-hour
      - Minutes: 0-59 for both formats
    - Convert to 24-hour format with minutes: `12am` → `0:00`, `1:30am-11:45am` → `1:30-11:45`, `12pm` → `12:00`, `1:30pm-11:45pm` → `13:30-23:45`
    - **Minute parsing**: Extract `:MM` or `:MM` from input string, validate range, default to `00` if not specified
  - **GUI Spinbox Implementation with Minutes**:
    - **yad (Preferred)**:
      - Use `yad --form --field="Start Hour:NUM" --field="Start Minute:NUM" --field="Start AM/PM:CB" --field="End Hour:NUM" --field="End Minute:NUM" --field="End AM/PM:CB"`
      - Hour spinbox: `1..12` range with step=1
      - Minute spinbox: `0..59` range with configurable step:
        - Step=1: Full precision (any minute 0-59)
        - Step=15: Quarter-hour increments (0, 15, 30, 45)
        - Step=30: Half-hour increments (0, 30)
      - Alternative: Minute combobox with common values: `00!15!30!45` for easier selection
      - AM/PM combobox: `AM!PM` options
      - Parse selected values and convert to 24-hour format with minutes
    - **zenity (Fallback)**:
      - Use `zenity --forms` with entry fields for hour and separate radio buttons or combobox for AM/PM
      - Less elegant but functional
      - May need multiple dialogs or custom layout
    - **kdialog (KDE)**:
      - Use `kdialog --combobox` or Qt widgets if available
      - Better widget support than zenity
  - **Overnight Range Handling with Minutes**:
    - For 12-hour format, handle overnight ranges: `11:30pm-5:30am` should be recognized as spanning midnight
    - Visual indication in GUI: Show that range crosses midnight
    - Validation: Ensure end time is after start time (or handle overnight explicitly)
    - **Minute precision edge cases**: `23:59-0:01` (crosses midnight with minute precision)
  - **Time Comparison Updates in `lib/time-validation.sh`**:
    - **Current Logic**: Compares hour only using `$(date +%H)` (returns 0-23) in `is_restricted_hour()` function
    - **New Logic**: Compare time as `HHMM` using `$(date +%H%M)` (returns 0000-2359)
    - **Parsing Config**: Extract hours and minutes from `HH:MM-HH:MM` or `HH-HH` format in `lib/config.sh` `parse_config()` function
    - **Example Comparison**:
      ```bash
      # Parse config: MONDAY=23:30-5:30
      start_time="2330"
      end_time="0530"
      current_time=$(date +%H%M)
      
      # Check if current time is in restricted range (overnight)
      if [[ $current_time -ge $start_time || $current_time -lt $end_time ]]; then
          # Show warning
      fi
      ```
    - **Backward Compatibility**: If config has `HH-HH` format, append `00` for minutes (e.g., `23-5` → `2300-0500`)
  - **Configuration Format with Minute Support**:
    - **Config file format change**: Store times in 24-hour format with optional minutes (`DAY=23:30-5:30` or `DAY=23-5`)
    - **Format**: `DAY=HH[:MM]-HH[:MM]` where minutes are optional (default to `:00`)
    - **Examples**:
      - `MONDAY=23:30-5:30` (11:30 PM to 5:30 AM with minutes)
      - `TUESDAY=23-5` (11:00 PM to 5:00 AM, hour-only, defaults to :00)
      - `WEDNESDAY=14:15-18:45` (2:15 PM to 6:45 PM with minutes)
    - **Display Format**: Add `TIME_DISPLAY_FORMAT=12hour|24hour` config option (default: `24hour`)
    - **Input Format**: Accept both formats during configuration with optional minutes, convert to 24-hour for storage
    - **Backward Compatibility**: Hour-only format (`DAY=23-5`) treated as `DAY=23:00-5:00` internally
  - **User Experience with Minute Precision**:
    - **GUI Mode**: Spinbox widgets provide intuitive time selection (click up/down arrows for hours and minutes, toggle AM/PM)
    - **Text Mode**: Accept natural formats with optional minutes (`11pm-5am`, `23-5`, `11:30pm-5:30am`, `23:30-5:30`)
    - **Minute Flexibility**: Users can specify exact times (e.g., `11:45pm`) or use hour-only shortcuts (e.g., `11pm` = `11:00pm`)
    - **Common Use Cases**:
      - Half-hour precision: `11:30pm-5:30am` for bedtime at 11:30 PM
      - Quarter-hour precision: `10:45pm-6:15am` for more precise timing
      - Hour-only: `11pm-5am` for simple top-of-the-hour restrictions
    - **Display Preference**: Show times in user's preferred format in summaries, status, and grid views with minutes when specified
    - **Format Detection**: Automatically detect format from input (no need to specify format)
    - **Timer Interval Consideration**: When using minute precision, users should be aware that the timer checks at fixed intervals. For example, with `CHECK_INTERVAL=60`, the timer only checks at :00 of each hour, so restrictions starting at 9:15 will trigger at 10:00 (next check). The system will warn users if they configure minute precision with a large `CHECK_INTERVAL` and suggest shorter intervals (1, 5, or 15 minutes) for timely warnings.
  - **Backward Compatibility with Minute Support**:
    - Existing hour-only configurations (`DAY=23-5`) continue to work, treated as `23:00-5:00`
    - New minute-precision input (`DAY=23:30-5:30`) stored with minutes
    - New 12-hour format input with minutes (`11:30pm-5:30am`) is converted to 24-hour format with minutes
    - **Migration**: Existing config files with hour-only format work without changes
    - **Time Comparison**: `lib/time-validation.sh` must be updated to handle minute precision:
      - Current logic: Compares hour only (e.g., `hour -ge start_hour`) in `is_restricted_hour()` function
      - New logic: Compare time as `HHMM` format (e.g., `0630` for 6:30 AM) for proper minute-level precision
      - Example: If restriction is `23:30-5:30`, trigger warning at 23:30, not 23:00
- **User Experience Benefits with Minute Precision**:
  - **Familiar Format**: Users more comfortable with 12-hour format can use natural time entry (e.g., `11:30pm-5:30am`)
  - **Easier Input**: Spinbox widgets eliminate typing errors and provide visual feedback for both hours and minutes
  - **Intuitive Selection**: Click to adjust hours and minutes, toggle AM/PM instead of calculating 24-hour equivalents
  - **Reduced Errors**: GUI widgets prevent invalid time entries (e.g., hour 13-23 in 12-hour format, minutes > 59)
  - **Flexibility**: Support both formats based on user preference, with or without minute precision
  - **Precise Timing**: Set exact restriction times (e.g., `11:45pm` instead of being limited to `11pm` or `12am`)
  - **Simplified Input**: Hour-only input still works (`11pm` = `11:00pm`), no need to specify `:00` for top of the hour
- **Technical Considerations with Minute Precision**:
  - **GUI Tool Support**: yad has better spinbox support than zenity for both hour and minute widgets
  - **Text Mode**: Can be enhanced with format parsing without GUI dependencies
  - **Validation**: Need robust parsing to handle various 12-hour format variations with optional minutes
  - **Edge Cases**:
    - Handle midnight (`12am` = `0:00`), noon (`12pm` = `12:00`)
    - Overnight ranges with minutes (e.g., `23:30-5:30` spans midnight)
    - Hour-only input defaults to `:00` (e.g., `11pm` = `11:00pm` = `23:00`)
  - **Time Comparison Logic**: `lib/time-validation.sh` needs updates:
    - Parse time ranges with minutes from config file
    - Compare current time at minute precision (e.g., `$(date +%H%M)` gives `2330` for 11:30 PM)
    - Handle overnight ranges with minute precision correctly
    - Example comparison: `if [[ $current_time -ge 2330 || $current_time -lt 0530 ]]; then`
  - **Display Format**: Consider adding user preference for display format (12-hour vs 24-hour) in summaries
  - **Performance**: Minute-level time comparisons have negligible performance impact
  - **Timer Interval Limitations with Minute Precision**:
    - **Problem**: The systemd timer uses `OnCalendar=*:0/N` format, which triggers at fixed intervals starting from minute 0 (e.g., `CHECK_INTERVAL=60` triggers at :00 of each hour: 9:00, 10:00, 11:00, etc.)
    - **Note**: This limitation is addressed by [Enhancement 30: Separate Timer Check Interval from Popup Display Frequency](enhancement-30-separate-timer-check-interval-from-popup-display-frequency.md), which hardcodes the timer to check every 5 minutes while allowing users to configure popup display frequency separately.
    - **Impact**: If restrictions start at a non-zero minute (e.g., 9:15), the popup will NOT appear at the exact start time. Instead, it will appear at the next timer trigger (e.g., 10:00 if `CHECK_INTERVAL=60`)
    - **Example**: With `CHECK_INTERVAL=60` and restrictions starting at 9:15:
      - Timer triggers at 9:00 → script checks → 9:00 < 9:15 → no popup
      - Timer triggers at 10:00 → script checks → 10:00 >= 9:15 → popup appears
      - **Result**: Popup appears at 10:00, not 9:15 (45 minutes late)
    - **Solutions**:
      - **Option 1: Recommend Shorter Intervals** (Recommended):
        - When minute precision is used, recommend `CHECK_INTERVAL` values that align with common minute boundaries:
          - `CHECK_INTERVAL=15` → triggers at :00, :15, :30, :45 → popup appears at 9:15 if restrictions start at 9:15
          - `CHECK_INTERVAL=5` → triggers at :00, :05, :10, :15, :20, etc. → popup appears at 9:15
          - `CHECK_INTERVAL=1` → triggers every minute → popup appears at exact time
        - Add validation/warning in configure.sh: If user sets minute precision (e.g., `9:15`) with `CHECK_INTERVAL=60`, show warning: "Warning: With CHECK_INTERVAL=60, restrictions starting at 9:15 will trigger at 10:00 (next timer check). Consider using CHECK_INTERVAL=15 or less for minute-precision restrictions."
      - **Option 2: Auto-Adjust CHECK_INTERVAL**:
        - When minute precision is detected, automatically suggest/adjust `CHECK_INTERVAL` to a value that ensures timely triggering (e.g., if restrictions use :15 or :45, recommend `CHECK_INTERVAL=15`)
        - Could be a warning dialog: "You've configured minute precision. For timely warnings, we recommend CHECK_INTERVAL=15 or less. Would you like to update CHECK_INTERVAL?"
      - **Option 3: Systemd OnCalendar with Specific Times** (Complex, not recommended):
        - Use systemd's `OnCalendar` with specific times (e.g., `OnCalendar=*-*-* 09:15:00,10:15:00,11:15:00`) to trigger at exact restriction start times
        - **Limitations**: 
          - Requires parsing all restriction start times from config
          - Complex to handle multiple days, multiple ranges, overnight ranges
          - Would need to regenerate timer file whenever restrictions change
          - Systemd timer file would become very complex with many time entries
        - **Not Recommended**: Too complex, error-prone, and doesn't scale well
      - **Option 4: Hybrid Approach** (Future enhancement):
        - Use shorter default interval (e.g., 15 minutes) when minute precision is detected
        - Allow users to override, but warn about potential delays
        - Could add a "precision mode" that automatically uses `CHECK_INTERVAL=1` or `CHECK_INTERVAL=5` when minute precision is used
    - **Recommended Implementation**:
      - Add validation in `configure.sh` or `lib/configure-validation.sh`:
        - When saving config with minute precision, check if `CHECK_INTERVAL` is compatible
        - If `CHECK_INTERVAL` is large (e.g., > 15) and minute precision is used, show warning dialog
        - Suggest appropriate `CHECK_INTERVAL` values (1, 5, 15) based on minute values used
      - Add documentation/warning in user-facing messages:
        - Status display: Show warning if minute precision is used with incompatible `CHECK_INTERVAL`
        - Configuration wizard: Show informational message about timer interval when minute precision is selected
      - **User Warning Example**: "Note: With CHECK_INTERVAL=60, restrictions starting at non-zero minutes (e.g., 9:15) will trigger at the next hour boundary (e.g., 10:00). For exact timing, use CHECK_INTERVAL=15 or less."
---

## Detailed Implementation Plan

**Status**: Ready for implementation - All decisions have been made (see `enhancement-16b-decisions-needed.md`)

**Implementation Approach**: Hybrid approach with minute precision
- **GUI Mode**: Spinbox widgets (yad preferred, zenity fallback, kdialog sequential dialogs)
- **Text Mode**: Accept both 12-hour and 24-hour format text input with optional minutes
- **Internal Storage**: Store in normalized 24-hour format with minutes (`HH:MM-HH:MM`)
- **Display**: Show times in user's preferred format (12-hour default, configurable) with minutes

**Key Decisions**:
- Minute selection: Combobox with 00 and 30 options (fixed, not configurable)
- Display format: Default 12-hour, but config file remains 24-hour for backward compatibility
- Function naming: Create new `is_restricted_time()` with minute precision, keep `is_restricted_hour()` as wrapper
- Config format: Parse in `parse_config()`, normalize to `HH:MM-HH:MM`, write in normalized format always
- Migration: Automatic migration on first run/install, with runtime backward compatibility

**Implementation Phases**:
1. Core Parsing and Conversion Functions
2. Time Comparison and Current Time Functions
3. Config File Parsing and Normalization
4. Display Format Preference
5. GUI Widget Implementation
6. Status and Display Updates
7. Validation and Warnings
8. Testing
9. Documentation
10. Final Integration and Cleanup

---

### Phase 1: Core Parsing and Conversion Functions
- [x] **Create Time Parsing Functions**
- [x] **Create Format Conversion Functions**
- [x] **Create Validation Functions**

### Phase 2: Time Comparison and Current Time Functions
- [x] **Create Current Time Functions**
- [x] **Update Time Comparison Functions**

### Phase 3: Config File Parsing and Normalization
- [x] **Update Config Parsing**
- [x] **Update Config Writing**
- [x] **Create Migration Logic**

### Phase 4: Display Format Preference
- [x] **Add Display Format Config Option**
- [x] **Update Display Functions**

### Phase 5: GUI Widget Implementation
- [x] **Create GUI Time Selection Function**
- [x] **Update `get_day_hours()` Function**

### Phase 6: Status and Display Updates
- [x] **Update `status.sh`**
- [x] **Update Grid Display**

### Phase 7: Validation and Warnings
- [x] **Timer Interval Validation**
- [x] **Integrate validation into config save**
- [x] **Add informational message in configuration wizard**

### Phase 8: Testing

#### 8.1 Unit Tests
- [x] **Create test file `tests/test-16b-core.sh`**:
  - [x] Test `normalize_time_input()` with various formats
  - [x] Test `detect_time_format()` with 12-hour and 24-hour inputs
  - [x] Test `parse_time_input()` (implemented via `parse_single_time` and `parse_time_range`)
  - [x] Test `12hour_to_24hour()` with all edge cases
  - [x] Test `24hour_to_12hour()` with all edge cases
  - [x] Test `convert_time_range_to_24hour()` with various inputs
  - [x] Test `normalize_time_range()` with various inputs
  - [x] Test `validate_time_range()` with valid and invalid formats
  - [x] Test `is_time_in_single_range()` with minute precision
  - [x] Test `is_restricted_time()` with minute precision
  - [x] Test overnight ranges with minute precision
  - [x] Test backward compatibility of `is_restricted_hour()`
  - [x] Test `format_range_human()` with minutes and display preference

#### 8.2 Integration Tests
- [x] **Create test file `tests/test-16b-core.sh` (includes integration checks)**:
  - [x] Test `parse_config()` with `HH-HH` format (backward compatibility)
  - [x] Test `parse_config()` with `HH:MM-HH:MM` format
  - [x] Test config migration function (`migrate_config_to_minute_format`)
  - [x] Test config write with normalized format
- [ ] **Create test file `tests/test-gui-time-selection.sh`**:
  - [ ] Test yad time selection dialog (if yad available)
  - [ ] Test zenity time selection dialog (if zenity available)
  - [ ] Test kdialog time selection dialog (if kdialog available)
  - [ ] Test pre-filling with existing values
  - [ ] Test overnight range indication

#### 8.3 Manual Testing Checklist
- [ ] **GUI Testing**:
  - [ ] Test yad spinbox widgets (hour, minute, AM/PM)
  - [ ] Test zenity form fields (entry and combobox)
  - [ ] Test kdialog sequential combobox dialogs
  - [ ] Test pre-filling when editing existing range
  - [ ] Test overnight range visual indicator
  - [ ] Test error handling and validation
- [ ] **Text Mode Testing**:
  - [ ] Test 12-hour format input (`11pm-5am`)
  - [ ] Test 24-hour format input (`23-5`)
  - [ ] Test minute precision input (`11:30pm-5:30am`)
  - [ ] Test various format variations
  - [ ] Test error messages for invalid input
- [ ] **Display Format Testing**:
  - [ ] Test 12-hour display format preference
  - [ ] Test 24-hour display format preference
  - [ ] Test default (12-hour) when not set
  - [ ] Test status.sh output with both formats
  - [ ] Test grid display with both formats
- [ ] **Backward Compatibility Testing**:
  - [ ] Test existing config files with `HH-HH` format
  - [ ] Test automatic migration on first run
  - [ ] Test runtime backward compatibility (treat `HH-HH` as `HH:00-HH:00`)
  - [ ] Test that existing function calls still work

### Phase 9: Documentation
- [x] **Update `user-docs/CONFIGURATION.md`**
- [x] **Update `user-docs/USER_GUIDE.md`**
- [x] **Update `dev-docs/TECHNICAL_DETAILS.md`**

### Phase 10: Final Integration and Cleanup

#### 10.1 Code Review and Refactoring
- [x] Review all new functions for consistency
- [x] Ensure error handling is comprehensive
- [x] Check for code duplication
- [x] Verify backward compatibility maintained
- [x] Update function documentation/comments

#### 10.2 Release Preparation
- [ ] Update version number
- [ ] Create release notes documenting:
  - [ ] 12-hour format support
  - [ ] Minute precision
  - [ ] Display format preference
  - [ ] Config format migration
  - [ ] Timer interval considerations
- [ ] Test full installation from scratch
- [ ] Test upgrade from previous version
- **Minute Precision Benefits**:
  - **Fine-Grained Control**: Users can set precise bedtimes (e.g., "No gaming after 11:30 PM")
  - **Flexibility**: Accommodates schedules that don't align with hour boundaries
  - **Real-World Scenarios**:
    - School nights: `10:30pm-6:30am` (early bedtime with wake-up at 6:30)
    - Weeknights: `11:30pm-5:30am` (later bedtime, earlier wake-up)
    - Weekends: `12:30am-9:00am` (late night gaming allowed until 12:30 AM)
  - **Backward Compatible**: Hour-only configurations still work (default to `:00`)
- **Implementation Complexity**:
  - **Low to Medium**: Requires updates to parsing, storage, and time comparison logic
  - **Config Format Change**: Requires handling both `HH-HH` (legacy) and `HH:MM-HH:MM` (new) formats
  - **Time Comparison**: `lib/time-validation.sh` logic needs update to compare `HHMM` instead of just `HH`
  - **Testing**: Additional test cases for minute boundaries and edge cases
- **Related**: 
  - Complements Visual Day/Time Configuration Grid (#16) - spinbox widgets would enhance grid editing
  - Works with existing time range configuration system
  - Could be integrated into Phase 2 of Visual Day/Time Configuration Grid (interactive grid editing)

