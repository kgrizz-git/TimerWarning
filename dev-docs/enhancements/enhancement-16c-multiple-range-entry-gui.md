# Enhancement 16c: Multiple Time Range Entry in GUI

- **Description**: Allow users to configure multiple comma-separated time ranges per day **in GUI mode** (e.g., 12am–5am and 11pm–5am next day). Text mode and config storage already support multiple ranges; this enhancement extends the configure wizard GUI so users can add, edit, and remove multiple ranges per day without switching to text mode or editing the config file.
- **Files Affected**: `lib/configure-dialogs.sh`, `lib/configure-input-time.sh`; optionally `lib/configure-ui.sh` or new helpers for list management
- **Priority**: Medium (improves usability for users who need multiple ranges per day and prefer the GUI)
- **Status**: Not implemented
- **Depends on**: Enhancement #16b (12-hour format and GUI time widgets) — multiple-range GUI should reuse or extend the same single-range time widgets.

## Current Behavior

- **Text mode** (`configure.sh --text` or when no dialog tool): `get_day_hours()` uses a single free-form text prompt. Users can enter comma-separated ranges (e.g., `0-5,23-5` or `12am-5am,11pm-5am`). Validation and normalization support multiple ranges; they are stored and displayed correctly.
- **GUI mode**: When configuring a day (weekdays, weekends, or from the visual grid), `get_day_hours()` calls `show_time_selection_dialog()`, which collects **one** start/end pair per invocation. There is no way in the GUI to add a second (or further) range for the same day without dropping to text mode or editing the config.

## Goals

1. In GUI mode, allow **multiple** time ranges per day for:
   - Restricted hours (all flows: weekdays, weekends, grid edit)
   - Additional config lock hours
   - Additional uninstall lock hours
2. Reuse existing 12-hour/minute widgets (Enhancement #16b) so each range is entered with the same UX (spinboxes/combos for start and end).
3. Support add / remove / edit of individual ranges in a clear, tool-agnostic way (yad, zenity, kdialog).
4. Preserve backward compatibility: single-range entry remains valid; existing configs and validation unchanged.

## Implementation Approaches

### Option A: List dialog + single-range dialog in a loop

- Show a dialog listing “Ranges for &lt;day&gt;” with:
  - Current ranges (e.g. “12:00am → 5:00am”, “11:00pm → 5:00am (next day)”) and
  - Actions: “Add range”, “Edit range”, “Remove range”, “Done”.
- “Add range” / “Edit range” opens the existing `show_time_selection_dialog()` (or equivalent) once per range.
- On “Done”, return the comma-separated normalized string (e.g. `00:00-05:00,23:00-05:00`) to `get_day_hours()`, which already passes it to `normalize_time_range()` and `format_ranges_human()` for confirmation.

**Pros**: Reuses all current dialogs; no new widget types.  
**Cons**: Multiple dialogs per day; kdialog may need several steps for list + add/edit.

### Option B: Multi-range form in one dialog (YAD-focused)

- For YAD: one form with repeated “Range 1”, “Range 2”, … (e.g. up to 3–5 ranges) using fixed fields; empty ranges ignored.
- For Zenity/KDialog: fall back to Option A or a simplified “one extra range” step.

**Pros**: Single screen for power users on YAD.  
**Cons**: Less flexible for “N ranges”; Zenity/KDialog need a different UX.

### Option C: Hybrid (recommended)

- **Primary**: Option A — “Manage ranges” list (Add / Edit / Remove / Done) using existing `show_time_selection_dialog()` for each range.
- **Fallback**: If list dialog is too heavy for a given tool, allow “Add another range?” after the first, and loop until the user says no or cancels.
- Reuse `format_ranges_human()` for list text and confirmation preview so behavior matches summary/grid display.

## Technical Notes

- **Output format**: The value returned from the GUI into `get_day_hours()` must be a single string of comma-separated normalized ranges (e.g. `00:00-05:00,23:00-05:00`). No changes required to config write, `normalize_time_range()`, or `validate_time_range()`.
- **Pre-fill when editing**: When editing an existing day that already has multiple ranges, the “Manage ranges” list (or equivalent) should be pre-filled from the current value (split on commas, then each range shown via `format_range_human()`).
- **Tools**:  
  - **YAD**: List dialog + buttons for Add/Edit/Remove/Done; optional “Add another?” after first range for a lighter variant.  
  - **Zenity**: List or question dialogs plus repeated time forms; same logical flow as Option A.  
  - **KDialog**: Same logical flow; may require several small dialogs (list, then add/edit one range at a time).

## Suggested Implementation Phases

1. **Phase 1 – “Add another?” loop (minimal)**  
   - After user confirms the first range in GUI, show “Add another time range for this day?” Yes/No.  
   - If Yes, call `show_time_selection_dialog()` again and append the result (normalized) to the list; repeat until No or Cancel.  
   - Pass the comma-joined string back to `get_day_hours()`.  
   - Pre-fill is optional (e.g. only first range editable in Phase 1).

2. **Phase 2 – “Manage ranges” list**  
   - One dialog per day that lists all ranges (using `format_range_human()`), with Add / Edit / Remove / Done.  
   - Edit opens `show_time_selection_dialog()` with the selected range pre-filled (per 16b behavior).  
   - Full pre-fill when opening the dialog from grid or weekday/weekend flows.

3. **Phase 3 – Tool-specific polish**  
   - Optimize layout and wording per tool (YAD vs Zenity vs KDialog) and add brief in-dialog help (e.g. “e.g. 12am–5am and 11pm–5am next day”).

## Detailed Implementation Checklist

### Phase 0 – Analysis and Design

- [ ] **Review existing time input behavior**
  - [ ] Read `lib/configure-input-time.sh` around `get_day_hours()` and any helpers it calls.
  - [ ] Read `lib/configure-dialogs.sh` for `show_time_selection_dialog()` (and related GUI helpers from 16b).
  - [ ] Confirm how `normalize_time_range()`, `validate_time_range()`, and `format_ranges_human()` are currently used (likely in `lib/time-parsing.sh`, `lib/time-validation.sh`, `lib/time-calculations.sh`).
- [ ] **Map all GUI call sites that set hours per day**
  - [ ] Identify where weekdays/weekends restricted hours, additional config lock hours, and uninstall lock hours call into `get_day_hours()` in GUI flows.
  - [ ] Note which call sites are part of the visual grid vs. linear wizard steps.
- [ ] **Decide initial rollout scope**
  - [ ] Confirm that Phase 1 uses the “Add another range?” loop without a full “Manage ranges” list.
  - [ ] Decide whether Phase 1 should support editing existing multiple ranges or only adding additional ranges in a single session.

### Phase 1 – “Add another range?” Loop (Minimal)

- [ ] **Extend GUI time selection loop**
  - [ ] Add a new helper (or extend `get_day_hours()` logic) that:
    - [ ] Calls `show_time_selection_dialog()` once to collect the first range.
    - [ ] Normalizes and validates the range using existing time helpers.
    - [ ] Stores the normalized range in an internal list (e.g. bash array or comma-separated string).
  - [ ] After the first successful range:
    - [ ] Show a confirmation dialog “Add another time range for this day?” with Yes/No (tool-agnostic wrapper in `lib/configure-dialogs.sh` if possible).
    - [ ] On Yes: loop to call `show_time_selection_dialog()` again, normalize/validate, and append to the internal list.
    - [ ] On No: stop collecting and proceed.
    - [ ] On Cancel/Close: define clear behavior (e.g. discard changes and return empty / previous value) and make it consistent with existing flows.
- [ ] **Return correct output format**
  - [ ] Join all collected normalized ranges into `HH:MM-HH:MM,HH:MM-HH:MM,...`.
  - [ ] Ensure this string is returned to `get_day_hours()` exactly as existing text-mode multi-range strings are.
- [ ] **Wire Phase 1 into all GUI call sites**
  - [ ] Update the weekday/weekend flows to use the new multi-range-capable helper instead of single-range only.
  - [ ] Update flows for additional config lock hours and uninstall lock hours to use the same helper.
  - [ ] Ensure that any “edit this day” action in the grid calls through the same multi-range path.
- [ ] **Minimal pre-fill behavior (if included in Phase 1)**
  - [ ] When a day already has at least one range, pre-fill the first `show_time_selection_dialog()` with the first existing range (relying on 16b behavior).
  - [ ] Document limitations: additional existing ranges may not be individually editable yet in Phase 1.

### Phase 2 – “Manage Ranges” List

- [ ] **Introduce a “Manage ranges for <day>” dialog**
  - [ ] Add a tool-agnostic helper in `lib/configure-dialogs.sh` for a list dialog with:
    - [ ] A list of current ranges (formatted with `format_ranges_human()`).
    - [ ] Buttons: Add, Edit, Remove, Done, and Cancel.
  - [ ] Implement the common logic that:
    - [ ] Converts the current comma-separated ranges into an internal list.
    - [ ] Loops until the user chooses Done or Cancel.
- [ ] **Implement Add / Edit / Remove behavior**
  - [ ] **Add**:
    - [ ] Call `show_time_selection_dialog()` with empty initial values.
    - [ ] Normalize and validate the entered range.
    - [ ] Append it to the internal list and refresh the display text using `format_ranges_human()`.
  - [ ] **Edit**:
    - [ ] When a range is selected in the list, call `show_time_selection_dialog()` pre-filled with that range (reusing 16b widgets).
    - [ ] Normalize and validate the edited range.
    - [ ] Replace the original entry in the list and refresh the display.
  - [ ] **Remove**:
    - [ ] Remove the selected range from the list (with an optional “Are you sure?” confirm dialog).
    - [ ] Refresh the list display; handle the empty-list case cleanly.
- [ ] **Finalize and return values**
  - [ ] On Done:
    - [ ] Sort or normalize order only if consistent with existing behavior (otherwise preserve user order).
    - [ ] Join internal list into the canonical comma-separated string and return it.
  - [ ] On Cancel:
    - [ ] Define whether to return the original unmodified value or an empty string, consistent with current cancel semantics.
- [ ] **Integrate “Manage ranges” into GUI flows**
  - [ ] Replace / wrap the Phase 1 loop in a function that:
    - [ ] For new days with no ranges, either goes straight to the “Manage ranges” dialog or calls Add once, then shows the list.
    - [ ] For existing days, always opens the “Manage ranges for <day>” dialog with full pre-fill from the current value.
  - [ ] Ensure all relevant GUI entry points (grid, weekday/weekend, additional hours) now use the “Manage ranges” list rather than only the Yes/No loop.

### Phase 3 – Tool-Specific Polish and UX Consistency

- [ ] **YAD-specific enhancements**
  - [ ] Ensure the list dialog layout is clear, with columns like “Start” and “End (may be next day)”.
  - [ ] Confirm keyboard navigation and default button behavior match expectations (e.g. Enter = Done, Esc = Cancel).
  - [ ] Optionally support an inline help text or tooltip giving examples of multiple ranges.
- [ ] **Zenity-specific behavior**
  - [ ] Implement the list dialog using zenity list or a combination of dialogs if necessary.
  - [ ] Verify that Add/Edit/Remove flows are still understandable despite extra dialog hops.
- [ ] **KDialog-specific behavior**
  - [ ] Implement range management using kdialog list dialogs and per-range dialogs.
  - [ ] Confirm that the UX remains consistent with the YAD/Zenity flows (same wording, same button semantics where possible).
- [ ] **Copy and wording consistency**
  - [ ] Standardize dialog titles (e.g. “Time ranges for Monday”, “Additional lock hours – Sunday”).
  - [ ] Standardize prompts for Add/Edit/Remove/Done/Cancel across all tools.

### Cross-Cutting Validation and Compatibility

- [ ] **Backward compatibility**
  - [ ] Verify that existing configs with a single range per day are still displayed and edited correctly.
  - [ ] Verify that existing configs with multiple ranges entered via text mode are correctly parsed into separate ranges in the list dialog.
  - [ ] Confirm that no changes are required to on-disk config format, and that no new keys are added.
- [ ] **Error handling and edge cases**
  - [ ] Decide and implement behavior for:
    - [ ] User entering overlapping ranges.
    - [ ] User entering a range that spans midnight vs. two separate ranges.
    - [ ] Deleting all ranges for a day (clear restricted hours or treat as error?).
  - [ ] Ensure any validation errors are surfaced with clear, user-friendly messages.
- [ ] **Integration with summary/grid display**
  - [ ] Confirm that `format_ranges_human()` still produces correct output when called on multiple ranges returned from GUI.
  - [ ] Check that any visual grid or summary views correctly show multiple ranges without layout issues.

## Testing

- Add GUI tests that drive configure with multiple ranges per day (e.g. via expect or similar) and assert saved config contains the expected comma-separated `HH:MM-HH:MM` values.
- Manually verify with yad, zenity, and kdialog:
  - Add 2–3 ranges for one day, save, reopen grid/summary and confirm display.
  - Edit a day that has multiple ranges; change one, remove one, add one; save and verify.

## Related

- **Enhancement #16b**: Provides the single-range GUI time widgets; 16c reuses them for each range.
- **Enhancement #16**: Visual grid and day-by-day editing; 16c makes “edit this day” support multiple ranges in the GUI.
- Config format and validation already support multiple ranges; see `normalize_time_range()`, `validate_time_range()`, `format_ranges_human()`.
