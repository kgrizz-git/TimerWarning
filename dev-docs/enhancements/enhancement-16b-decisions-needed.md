# Enhancement 16b: Decisions and Clarifications Needed

This document identifies decisions and clarifications required before implementing Enhancement 16b (12-Hour Format Time Input with Minute Precision and GUI Spinbox Widgets).

**Status**: ✅ All decisions have been made. See "Decisions Made" section below.

## 1. Dialog Tool Implementation Details

### 1.1 Feature Parity Across Tools
**Question**: Should all three dialog tools (yad, zenity, kdialog) have feature parity, or can some tools have reduced functionality?

**Current State**: The system supports all 3 tools with automatic priority (yad > zenity > kdialog) and user preference selection.

**Options**:
- **Option A**: Full feature parity - all tools support spinbox widgets with hour, minute, and AM/PM selection
- **Option B**: Graceful degradation - yad gets full spinbox support, zenity/kdialog get workarounds (e.g., entry fields with validation)
- **Option C**: Tool-specific implementations - each tool uses its best available widget type

**Recommendation**: Option C - Use best available widget for each tool, but ensure all tools can achieve the same end result (time selection with minutes and AM/PM).

**✅ DECISION**: **Option C** - Use best available widget for each tool, but ensure all tools can achieve the same end result (time selection with minutes and AM/PM).

---

### 1.2 Zenity Implementation Details
**Question**: The plan mentions zenity "may need multiple dialogs or custom layout" - what is the specific implementation approach?

**Current State**: Zenity has limited spinbox support. The plan suggests using `zenity --forms` with entry fields.

**Clarifications Needed**:
- Should we use multiple `zenity --forms` dialogs (one for start time, one for end time)?
- Or a single form with multiple entry fields (start hour, start minute, start AM/PM, end hour, end minute, end AM/PM)?
- Should we use `zenity --list` with editable columns as a workaround?
- How should we validate entry fields (numeric only, range checking)?

**Recommendation**: Single form with 6 entry fields (start hour, start minute, start AM/PM dropdown, end hour, end minute, end AM/PM dropdown) with validation.

**✅ DECISION**: **Single form with 6 entry fields** (start hour, start minute, start AM/PM dropdown, end hour, end minute, end AM/PM dropdown) with validation.

---

### 1.3 KDialog Implementation Details
**Question**: The plan mentions kdialog but lacks specific implementation details. What widgets should be used?

**Current State**: KDialog has better widget support than zenity but less than yad.

**Clarifications Needed**:
- Should we use `kdialog --combobox` for hour/minute/AM-PM selection?
- Or use `kdialog --inputbox` with validation?
- Or use Qt widgets if available?
- What is the exact command structure for time selection?

**Recommendation**: Research kdialog capabilities and document specific command syntax for time selection widgets.

**✅ DECISION**: **Research kdialog capabilities** - See "Research Findings" section below for details.

---

### 1.4 YAD Spinbox Configuration
**Question**: The plan shows yad spinbox syntax but needs confirmation of exact field types and parameters.

**Clarifications Needed**:
- Confirm yad supports `NUM` field type with range and step parameters
- Verify syntax: `--field="Hour:NUM"` with range `1..12` and step `1`
- Verify minute spinbox: `--field="Minute:NUM"` with range `0..59` and step `1` (or configurable step)
- Confirm AM/PM combobox syntax: `--field="AM/PM:CB"` with options `AM!PM`

**✅ DECISION**: **Verify yad syntax and document exact command structure** - See "Research Findings" section below for verified syntax.

---

## 2. Minute Precision Configuration

### 2.1 Minute Step/Increment Default
**Question**: What should be the default minute increment/step for spinbox widgets?

**Options**:
- **Option A**: Full precision (step=1, allows any minute 0-59)
- **Option B**: 15-minute increments (step=15, allows 0, 15, 30, 45)
- **Option C**: 30-minute increments (step=30, allows 0, 30)
- **Option D**: Combobox with common values (00, 15, 30, 45) for easier selection

**Recommendation**: Option A (full precision) as default, but allow text input to accept any minute value regardless of GUI widget step.

**✅ DECISION**: **Combobox with 00 and 30** - Use combobox (CB field type) with options "00!30" for minute selection.

---

### 2.2 Minute Step Configurability
**Question**: Should minute step/increment be user-configurable, or fixed?

**Options**:
- **Option A**: Fixed at implementation time (no user configuration)
- **Option B**: Configurable via config file option (e.g., `MINUTE_STEP=1|15|30`)
- **Option C**: Auto-detect based on user's first input (if they enter :30, use step=30)

**Recommendation**: Option A for initial implementation (keep it simple), consider Option B for future enhancement if users request it.

**✅ DECISION**: **Fixed** - Minute step/increment is fixed (not user-configurable).

---

## 3. Display Format Preference

### 3.1 Storage Location
**Question**: Where should `TIME_DISPLAY_FORMAT` be stored and how should it be accessed?

**Options**:
- **Option A**: In main config file (`sleep-warning.conf`) as `TIME_DISPLAY_FORMAT=12hour|24hour`
- **Option B**: Separate user preference file
- **Option C**: Environment variable or system setting

**Recommendation**: Option A - store in main config file for consistency with other preferences.

**✅ DECISION**: **In main config file** - Store `TIME_DISPLAY_FORMAT=12hour|24hour` in `sleep-warning.conf`.

---

### 3.2 Default Display Format
**Question**: What should be the default display format if `TIME_DISPLAY_FORMAT` is not set?

**Options**:
- **Option A**: 24-hour format (current system default, backward compatible)
- **Option B**: 12-hour format (more user-friendly for many users)
- **Option C**: Auto-detect based on system locale

**Recommendation**: Option A (24-hour) for backward compatibility and consistency with current behavior.

**✅ DECISION**: **Default display format should be 12-hour**, including if `TIME_DISPLAY_FORMAT` is not set, but in that case the config file times should be interpreted as 24-hour format for backward compatibility.

---

### 3.3 Display Format Scope
**Question**: Where should the display format preference apply?

**Clarifications Needed**:
- Should it apply to all time displays (status.sh, grid view, summaries, error messages)?
- Or only to user-facing summaries and status displays?
- Should it affect config file display/editing, or only read-only views?

**Recommendation**: Apply to all user-facing displays (status.sh, grid view, summaries, help text), but keep config file in 24-hour format for consistency.

**✅ DECISION**: **Apply to all user-facing displays** (status.sh, grid view, summaries, help text), but keep config file in 24-hour format.

---

## 4. Function Naming and API Changes

### 4.1 Function Renaming
**Question**: Should `is_restricted_hour()` be renamed to `is_restricted_time()` since it will handle minutes?

**Current State**: Function is called `is_restricted_hour()` and is used in multiple places:
- `lib/time-validation.sh` (definition)
- `lib/configure-ui.sh` (usage)
- `lib/config-locking.sh` (usage)
- `lib/sleep-detection.sh` (usage)

**Options**:
- **Option A**: Rename to `is_restricted_time()` and update all callers (breaking change, but more accurate)
- **Option B**: Keep name `is_restricted_hour()` for backward compatibility, but update internal logic to handle minutes
- **Option C**: Create new function `is_restricted_time()`, keep old function as wrapper for backward compatibility

**Recommendation**: Option C - Create new function with minute support, keep old function as backward-compatible wrapper that extracts hour from current time. This allows gradual migration.

**✅ DECISION**: **Option C** - Create new function `is_restricted_time()` with minute support, keep `is_restricted_hour()` as backward-compatible wrapper that calls the new function.

---

### 4.2 Validation Function Updates
**Question**: Should `validate_hour_range()` be renamed/updated to handle minute formats?

**Current State**: Function validates `HH-HH` format only.

**Clarifications Needed**:
- Rename to `validate_time_range()`?
- Update to accept both `HH-HH` and `HH:MM-HH:MM` formats?
- Create separate validation for minute format, or unified validation?

**Recommendation**: Update `validate_hour_range()` to accept both formats (backward compatible), or create `validate_time_range()` that handles both and have `validate_hour_range()` call it for backward compatibility.

**✅ DECISION**: **Create `validate_time_range()`** that handles both formats and have `validate_hour_range()` call it for backward compatibility.

---

## 5. Config File Format and Parsing

### 5.1 Config Format Parsing
**Question**: How should `parse_config()` handle both `HH-HH` and `HH:MM-HH:MM` formats?

**Current State**: `parse_config()` in `lib/config.sh` extracts the value after `=` but doesn't parse the format.

**Clarifications Needed**:
- Should parsing happen in `parse_config()` or in validation/comparison functions?
- How to detect format (presence of `:` indicates minute format)?
- Should we normalize to `HH:MM-HH:MM` format internally, or preserve original format?

**Recommendation**: Parse format in validation/comparison functions (not in `parse_config()`), normalize to `HH:MM-HH:MM` internally (defaulting to `:00` for hour-only), but preserve original format in config file for readability.

**✅ DECISION**: **Parse format in `parse_config()`**, normalize to `HH:MM-HH:MM` internally (defaulting to `:00` for hour-only).

---

### 5.2 Config File Write Format
**Question**: When writing config file, should we write in original format or normalized format?

**Options**:
- **Option A**: Write in normalized format (`HH:MM-HH:MM`) always
- **Option B**: Preserve original format if user entered hour-only (`HH-HH`), write with minutes if user entered minutes
- **Option C**: Always write with minutes (`HH:MM-HH:MM`) even if `:00`

**Recommendation**: Option B - preserve user's input format preference (if they entered `23-5`, keep it as `23-5`; if they entered `23:30-5:30`, keep it as `23:30-5:30`).

**✅ DECISION**: **Write in normalized format (`HH:MM-HH:MM`) always** - Always write times with minutes format, even if `:00`.

---

### 5.3 Migration Strategy
**Question**: Should existing config files be automatically migrated, or just handled with backward compatibility?

**Options**:
- **Option A**: Automatic migration - convert all `HH-HH` to `HH:00-HH:00` on first run
- **Option B**: Backward compatibility only - treat `HH-HH` as `HH:00-HH:00` at runtime, don't modify file
- **Option C**: Prompt user to migrate on first run after upgrade

**Recommendation**: Option B - backward compatibility only. No automatic file modification. Users can manually update if they want minute precision.

**✅ DECISION**: **Automatic migration** - Convert all `HH-HH` to `HH:00-HH:00` on first run or if install is run, but also treat `HH-HH` as `HH:00-HH:00` at runtime if config somehow still has it.

---

## 6. Time Comparison Logic Updates

### 6.1 Time Comparison Function Updates
**Question**: How should time comparison be updated to handle minute precision?

**Current State**: `is_hour_in_single_range()` compares hour values only (0-23).

**Clarifications Needed**:
- Create new function `is_time_in_single_range()` that compares `HHMM` format?
- Update existing function to handle both hour-only and minute-precision ranges?
- How to handle backward compatibility with hour-only configs?

**Recommendation**: Create new function `is_time_in_single_range()` that:
- Accepts current time as `HHMM` (e.g., `2330` for 11:30 PM)
- Accepts range as `HH:MM-HH:MM` or `HH-HH` (normalizes hour-only to `:00`)
- Compares at minute precision
- Update `is_restricted_hour()` to extract hour from current time and call new function

**Decision Needed**: Time comparison update strategy.

---

### 6.2 Current Time Retrieval
**Question**: Should we always use `$(date +%H%M)` for current time, or extract from existing hour-only logic?

**Current State**: Code uses `$(date +%H)` in various places.

**Clarifications Needed**:
- Create centralized function `get_current_time()` that returns `HHMM`?
- Or update each location individually?
- Should we cache current time to avoid multiple `date` calls?

**Recommendation**: Create centralized function `get_current_time()` that returns `HHMM` format, and `get_current_hour()` that returns hour-only for backward compatibility.

**✅ DECISION**: **Create centralized functions** - `get_current_time()` returns `HHMM` format, and `get_current_hour()` returns hour-only for backward compatibility.

---

## 7. GUI Widget Layout and UX

### 7.1 Widget Layout
**Question**: How should the time selection widgets be laid out in the dialog?

**Options**:
- **Option A**: Single row: Start Hour | Start Minute | Start AM/PM | End Hour | End Minute | End AM/PM
- **Option B**: Two rows: Start time (Hour | Minute | AM/PM) on top, End time (Hour | Minute | AM/PM) below
- **Option C**: Separate sections with labels: "Start Time:" followed by widgets, "End Time:" followed by widgets

**Recommendation**: Option C - clearer labeling, especially for users less familiar with 24-hour format.

**✅ DECISION**: **Separate sections with labels** - "Start Time:" followed by widgets, "End Time:" followed by widgets.

---

### 7.2 Default Values
**Question**: What should be the default values when opening the time selection dialog?

**Options**:
- **Option A**: Empty (user must select all values)
- **Option B**: Current time (if editing existing range, pre-fill with current values)
- **Option C**: Common default (e.g., 11 PM - 5 AM for bedtime restrictions)

**Recommendation**: Option B - if editing existing range, pre-fill with current values; if new, start with sensible defaults (11 PM - 5 AM) or empty.

**✅ DECISION**: **Option B** - If editing existing range, pre-fill with current values; if new, start empty.

---

### 7.3 Overnight Range Indication
**Question**: How should the GUI indicate that a range spans midnight (overnight)?

**Options**:
- **Option A**: Visual indicator (text label: "This range spans midnight")
- **Option B**: Automatic detection and warning message
- **Option C**: No special indication (rely on user understanding)

**Recommendation**: Option A - show visual indicator when start time PM and end time AM (or start > end in 24-hour), with explanation text.

**✅ DECISION**: **Option A** - Show visual indicator (text label: "This range spans midnight").

---

## 8. Text Mode Input Parsing

### 8.1 Format Detection
**Question**: How should the parser detect whether input is 12-hour or 24-hour format?

**Clarifications Needed**:
- Detect by presence of "am"/"pm" (case-insensitive)?
- What if user enters ambiguous input like "12" (could be 12 PM or 12 AM)?
- Should we require explicit AM/PM for 12-hour format, or try to infer?

**Recommendation**: Detect by presence of "am"/"pm" (case-insensitive). If present, treat as 12-hour; if not, treat as 24-hour. Require AM/PM for 12-hour format to avoid ambiguity.

**✅ DECISION**: **Follow recommendation** - Detect by presence of "am"/"pm" (case-insensitive). If present, treat as 12-hour; if not, treat as 24-hour. Require AM/PM for 12-hour format to avoid ambiguity.

---

### 8.2 Input Variations Support
**Question**: Which 12-hour format variations should be supported?

**Plan mentions**: `11pm`, `11PM`, `11:00pm`, `11:30pm`, `11:00 PM`, `11 pm`, `11:30 pm`

**Clarifications Needed**:
- Support all of these variations?
- What about `11:00pm` vs `11:00 pm` (space before PM)?
- What about `11:00PM` (no space, uppercase)?
- Should we normalize input before parsing?

**Recommendation**: Support common variations, normalize input (remove extra spaces, handle case-insensitive) before parsing.

**✅ DECISION**: **Support common variations** - Normalize input (remove extra spaces, handle case-insensitive) before parsing.

---

### 8.3 Error Handling
**Question**: How should invalid input be handled?

**Clarifications Needed**:
- Show specific error message indicating what was wrong?
- Suggest correct format?
- Allow retry or require user to start over?

**Recommendation**: Show specific error message with examples of correct format, allow retry in same dialog.

**✅ DECISION**: **Show specific error message** - Include examples of correct format, allow retry in same dialog.

---

## 9. Testing Strategy

### 9.1 Test Coverage
**Question**: What level of testing is needed for this enhancement?

**Clarifications Needed**:
- Unit tests for parsing functions?
- Integration tests for GUI widgets (all 3 tools)?
- Manual testing checklist?
- Automated tests for time comparison logic?

**Recommendation**: 
- Unit tests for parsing (12-hour to 24-hour conversion, minute parsing)
- Integration tests for time comparison logic
- Manual testing checklist for GUI widgets (all 3 tools)
- Automated tests for edge cases (midnight, noon, overnight ranges)

**✅ DECISION**: **Follow recommendation** - Unit tests for parsing, integration tests for time comparison, manual testing checklist for GUI widgets, automated tests for edge cases.

---

### 9.2 GUI Testing
**Question**: How should GUI widgets be tested across all 3 dialog tools?

**Clarifications Needed**:
- Can we automate GUI testing, or is manual testing required?
- Should we create test scripts that simulate user input?
- How to test on systems where only one tool is available?

**Recommendation**: Create test scripts that can run with each tool (if available), plus manual testing checklist. Document expected behavior for each tool.

**✅ DECISION**: **Follow recommendation** - Create test scripts that can run with each tool (if available), plus manual testing checklist. Document expected behavior for each tool.

---

## 10. Backward Compatibility

### 10.1 Existing Config Compatibility
**Question**: How should we ensure existing configs continue to work?

**Clarifications Needed**:
- Should we test with real user config files?
- What if user has custom scripts that parse config file directly?
- Should we document the format change?

**Recommendation**: 
- Test backward compatibility with existing config format (`HH-HH`)
- Document format change in release notes
- Ensure all parsing functions handle both formats gracefully

**✅ DECISION**: **Follow recommendation** - Test backward compatibility, document format change, ensure parsing functions handle both formats gracefully.

---

### 10.2 Function API Compatibility
**Question**: Should we maintain backward compatibility for function APIs?

**Current State**: Functions like `is_restricted_hour()` are used in multiple places.

**Clarifications Needed**:
- Keep existing function signatures?
- Or update all callers to use new APIs?
- Should we deprecate old functions?

**Recommendation**: Keep existing function signatures for backward compatibility, update internal implementation to handle minutes. Document that new code should use minute-precision functions.

**✅ DECISION**: **Follow recommendation** - Keep existing function signatures for backward compatibility, update internal implementation to handle minutes. Document that new code should use minute-precision functions.

---

## Summary of Critical Decisions

**High Priority** (block implementation):
1. Dialog tool implementation details (zenity, kdialog specifics)
2. Function naming strategy (`is_restricted_hour` vs `is_restricted_time`)
3. Config file parsing and normalization strategy
4. Time comparison logic update approach

**Medium Priority** (affect UX):
5. Minute step/increment default
6. Display format preference scope and defaults
7. GUI widget layout
8. Text mode input parsing rules

**Low Priority** (can be refined during implementation):
9. Testing strategy details
10. Error message specifics
11. Default values for GUI widgets

---

---

## Research Findings

### YAD Form Widget Syntax

**Verified Syntax for Time Selection:**

1. **NUM Field (Spinbox)** for Hour:
   ```bash
   --field="Start Hour:NUM" "11!1..12!1!0"
   ```
   - Format: `VALUE[!RANGE[!STEP![PREC]]]`
   - `11` = initial value
   - `1..12` = range (1 to 12 for 12-hour format)
   - `1` = step increment
   - `0` = precision (no decimals)

2. **CB Field (Combobox)** for Minutes:
   ```bash
   --field="Start Minute:CB" "00!30"
   ```
   - Format: `"Option1!Option2!..."`
   - Options separated by `!`
   - `^Option` marks default (e.g., `"^00!30"` makes 00 default)

3. **CB Field (Combobox)** for AM/PM:
   ```bash
   --field="Start AM/PM:CB" "AM!PM"
   ```
   - Or with default: `"^AM!PM"` (AM as default)

4. **Complete YAD Form Example:**
   ```bash
   yad --form --title="Time Selection" \
       --separator="|" \
       --field="Start Time:":LBL "" \
       --field="Hour:NUM" "11!1..12!1!0" \
       --field="Minute:CB" "^00!30" \
       --field="AM/PM:CB" "^AM!PM" \
       --field="End Time:":LBL "" \
       --field="Hour:NUM" "5!1..12!1!0" \
       --field="Minute:CB" "^00!30" \
       --field="AM/PM:CB" "^AM!PM"
   ```
   - Output format: `11|00|AM|5|00|AM` (separated by `|` by default, or custom separator)
   - `:LBL` creates a label field (read-only text)

**Key Points:**
- YAD supports native spinbox widgets via `NUM` field type
- Comboboxes via `CB` field type
- Multiple fields in single form
- Custom separator for output (`--separator="|"` or `--separator=":"`)
- Label fields for section headers (`:LBL`)

---

### KDialog Capabilities

**Research Findings:**

1. **No Built-in Time Picker Widget**: KDialog does not have a dedicated time picker widget like Qt's `KTimeComboBox`.

2. **Available Widgets for Time Selection:**
   - `--combobox`: Dropdown selection from list of options
   - `--inputbox`: Text input with optional default value
   - Multiple dialogs can be run sequentially

3. **Recommended Approach for KDialog:**
   - Use multiple `--combobox` dialogs in sequence:
     ```bash
     # Start Hour
     start_hour=$(kdialog --combobox "Start Hour:" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" --default "11")
     
     # Start Minute
     start_minute=$(kdialog --combobox "Start Minute:" "00" "30" --default "00")
     
     # Start AM/PM
     start_ampm=$(kdialog --combobox "Start AM/PM:" "AM" "PM" --default "PM")
     
     # End Hour
     end_hour=$(kdialog --combobox "End Hour:" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" --default "5")
     
     # End Minute
     end_minute=$(kdialog --combobox "End Minute:" "00" "30" --default "00")
     
     # End AM/PM
     end_ampm=$(kdialog --combobox "End AM/PM:" "AM" "PM" --default "AM")
     ```

4. **Alternative Approach (Single Form-like Dialog):**
   - Use `--inputbox` with formatted prompt and parse input:
     ```bash
     kdialog --inputbox "Enter start time (HH:MM AM/PM):" "11:00 PM"
     ```
   - Requires validation and parsing in script
   - Less user-friendly but simpler implementation

5. **Limitations:**
   - No native spinbox widgets
   - No single form with multiple fields (unlike yad)
   - Requires multiple dialog calls or text input with validation
   - Best UX: Multiple combobox dialogs in sequence

**Recommendation for Implementation:**
- Use sequential `--combobox` dialogs (6 dialogs total: start hour, start minute, start AM/PM, end hour, end minute, end AM/PM)
- Pre-populate comboboxes with all valid values (1-12 for hours, 00/30 for minutes, AM/PM for period)
- Use `--default` to set sensible defaults
- Consider showing a progress indicator or summary dialog after all selections

---

### Zenity Implementation Notes

**Zenity Form Syntax:**
```bash
zenity --forms --title="Time Selection" \
    --text="Configure time range:" \
    --add-entry="Start Hour (1-12)" \
    --add-entry="Start Minute (00 or 30)" \
    --add-combo="Start AM/PM" \
    --combo-values="AM|PM" \
    --add-entry="End Hour (1-12)" \
    --add-entry="End Minute (00 or 30)" \
    --add-combo="End AM/PM" \
    --combo-values="AM|PM"
```

**Key Points:**
- `--add-entry`: Text input field (requires validation)
- `--add-combo`: Dropdown selection (limited options)
- No native spinbox support
- Output: Pipe-separated (`|`) by default
- Validation must be done in script after dialog returns

**Validation Strategy:**
- Validate numeric ranges for hour (1-12) and minute (00 or 30)
- Show error dialog if invalid, allow retry
- Use `zenity --error` for validation errors

---

## Next Steps

1. ✅ All decisions have been made
2. Update enhancement plan with decided approaches and research findings
3. Create detailed implementation plan with specific code changes
4. Begin implementation with verified syntax and approaches
