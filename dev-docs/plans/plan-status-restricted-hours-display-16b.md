## Plan: Fix `status.sh` Restricted-Hours Display for Minute Precision (Enhancement 16b Compatibility)

### 1. Goals
- **Stop runtime errors**: Eliminate the `integer expression expected` and arithmetic syntax errors when `status.sh` encounters `HH:MM` times (e.g., `23:00-05:00`).
- **Support minute precision in display**: Correctly display ranges stored as `HH[:MM]-HH[:MM]` in the config, including overnight ranges, using a readable 12-hour format with minutes.
- **Maintain backward compatibility**: Continue to support legacy hour-only ranges (`HH-HH`) and mixed configurations without requiring changes to existing config files.
- **Keep `status.sh` self-contained**: Avoid sourcing new, untested libraries (like `lib/time-parsing.sh`, which may currently have syntax issues) from `status.sh`.

### 2. Current Behavior Summary
- `status.sh` reads restricted hours / lock hours / uninstall lock hours from the installed config and passes raw `ranges` strings (e.g., `23:00-05:00`, possibly comma-separated) into:
  - `format_ranges_human()`, which splits on commas and calls
  - `format_range_human()`, which:
    - Uses `cut -d'-' -f1/2` to get `start_hour` and `end_hour`.
    - Calls `format_hour_12h` with these values.
    - Uses `[ "${start_hour}" -gt "${end_hour}" ]` to detect overnight ranges.
- `format_hour_12h()` expects **integer hours only** and performs numeric comparisons and arithmetic, which fails for `HH:MM` values and causes the observed runtime errors.

### 3. Design Overview

- **3.1 New Helper: Parse 24-hour `HH[:MM]` to numeric components**
  - Add a small internal helper to `status.sh`, e.g.:
    - `parse_24h_time_to_components "HH[:MM]" → hour minute` (both numeric, zero-padded OK).
  - Behavior:
    - If input contains `:`, split into hour/minute using `cut -d':'`.
    - If no `:`, treat as `HH` with `minute=0`.
    - Validate both parts as numeric (`^[0-9]+$`); if invalid, return non-zero so callers can fall back to a safe message.

- **3.2 New Helper: Format 24-hour `HH[:MM]` to human-readable 12-hour string**
  - Replace the current `format_hour_12h()` (which assumes integer hours) with a more robust version, e.g.:
    - `format_time_12h "HH[:MM]" → "H:MM AM/PM"`.
  - Implementation details:
    - Use `parse_24h_time_to_components` to get numeric `hour` and `minute`.
    - Perform 24h→12h conversion locally in `status.sh`:
      - 0:00 → `12:00 AM`
      - 12:00 → `12:00 PM`
      - 13:30 → `1:30 PM`, etc.
    - Always display minutes as `MM` (including `:00`) for consistency with minute precision support.
    - If parsing fails, return the original input string unchanged so the user still sees something.

- **3.3 Update range formatting to be minute-aware**
  - Update `format_range_human()`:
    - Accept full `range` strings in the form `start-end`, where `start` and `end` are `HH[:MM]`.
    - Extract `start_raw` and `end_raw` using `cut -d'-'`.
    - Use `parse_24h_time_to_components` on both to compute comparable numeric values `start_total` and `end_total` in `HHMM` form:
      - `start_total=$((10#${start_hour}${start_minute_padded}))`
      - `end_total=$((10#${end_hour}${end_minute_padded}))`
    - Detect overnight ranges using `HHMM` comparisons:
      - If parsing succeeds for both ends and `start_total > end_total`, treat as overnight (`(overnight)` tag).
      - Otherwise, treat as same-day.
    - Call `format_time_12h` on `start_raw` and `end_raw` to render user-facing strings.
    - If parsing fails for either end, fall back to displaying the raw range without `(overnight)` tagging to avoid misleading output.
  - Keep `format_ranges_human()` largely unchanged:
    - Still split on commas.
    - Trim whitespace.
    - Call updated `format_range_human()` for each range.

- **3.4 Backward compatibility handling**
  - Legacy formats (`DAY=23-5`):
    - `parse_24h_time_to_components "23"` → `23 0` → displayed as `11:00 PM`.
    - `parse_24h_time_to_components "5"` → `5 0` → displayed as `5:00 AM`.
  - Mixed formats (`DAY=23-5:30` or similar) will be supported as long as each endpoint parses as `HH[:MM]`.
  - If any malformed range is encountered (e.g., typos in config), the script:
    - Avoids arithmetic on invalid strings.
    - Shows the raw range text (e.g., `23xx-5`) instead of failing with errors.

### 4. Implementation Checklist
- [ ] Add `parse_24h_time_to_components()` helper to `status.sh`.
- [ ] Replace existing `format_hour_12h()` with `format_time_12h()` that:
  - [ ] Uses the new parser.
  - [ ] Handles 24h→12h conversion with minutes.
  - [ ] Returns a sensible fallback when parsing fails.
- [ ] Update `format_range_human()` to:
  - [ ] Parse `start` and `end` as `HH[:MM]`.
  - [ ] Compute `HHMM`-style numeric values for overnight detection.
  - [ ] Display both endpoints using `format_time_12h()`.
  - [ ] Gracefully handle malformed ranges without crashing.
- [ ] Keep `format_ranges_human()` behavior (comma-splitting, "AND" joining) but ensure it works with the updated `format_range_human()`.
- [ ] Manually verify that restricted hours, lock hours, and uninstall lock hours sections all use the new formatting.

### 5. Testing Plan

- **5.1 Manual tests (using your existing config)**
  - [ ] Run `./status.sh` and confirm:
    - [ ] No `integer expression expected` or arithmetic syntax errors are printed.
    - [ ] Each configured day with ranges like `23:00-05:00` shows something like `11:00 PM → 5:00 AM (overnight)`.
    - [ ] Days with multiple ranges show them joined by `AND` correctly.
  - [ ] Confirm lock hours and uninstall lock hours sections also display correctly with `HH:MM` ranges.

- **5.2 Synthetic / edge-case tests (if desired)**
  - Temporarily point `CONFIG_FILE` in a throwaway copy of `status.sh` (or a test-only script) to a dummy config file with the following for one day:
    - `DAY=23-5`
    - `DAY=23:30-5:30`
    - `DAY=08:15-12:45`
    - `DAY=23:59-00:01`
    - Malformed inputs like `DAY=23xx-5` to confirm graceful fallback.
  - Run that test script and verify:
    - [ ] Hour-only configs are displayed as `H:00 AM/PM`.
    - [ ] Minute-precision configs preserve minutes correctly.
    - [ ] Overnight detection uses actual `HHMM` comparisons and is correct across midnight.
    - [ ] Malformed ranges do not cause errors; they display as raw text.

### 6. Question for You
- **Do you want me to proceed with implementing these `status.sh` changes now according to this plan, and then run the manual `./status.sh` check against your current config to confirm everything looks correct?**

