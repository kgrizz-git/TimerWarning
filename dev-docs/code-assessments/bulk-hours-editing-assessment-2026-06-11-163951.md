# Bulk Hours Editing / Adding / Removing — Assessment

**Date:** 2026-06-11
**Scope:** Restricted hours, lock hours (configure.sh/manage.sh), and uninstall lock hours (uninstall protection)
**Status:** Design assessment — no code changes

---

## 1. Current State

### What already exists (bulk-like)

| Feature | Where | Behavior | Categories |
|---------|-------|----------|------------|
| Weekdays together | `configure_weekdays_section()` | One range applies to Mon–Fri | Restricted hours only |
| Weekends together | `configure_weekends_section()` | One range applies to Sat–Sun | Restricted hours only |
| Weekdays together | `configure_lock_hours_section()` | One range applies to Mon–Fri | Lock hours only |
| Weekends together | `configure_lock_hours_section()` | One range applies to Sat–Sun | Lock hours only |
| Weekdays together | `configure_uninstall_lock_hours_section()` | One range applies to Mon–Fri | Uninstall lock hours only |
| Weekends together | `configure_uninstall_lock_hours_section()` | One range applies to Sat–Sun | Uninstall lock hours only |
| Visual grid | `show_visual_grid()` / `configure_day_from_grid()` | Per-day click-to-edit | All three (user picks which) |

### What does **not** exist

1. **Cross-category bulk** — e.g. "set the same hours for restricted, lock, and uninstall lock all at once"
2. **Apply to all 7 days** — no "set this range for every day" shortcut
3. **Copy day-to-day** — e.g. "copy Monday's hours to Wednesday and Friday"
4. **Bulk clear / remove** — e.g. "clear all lock hours for the whole week" in one action
5. **Bulk add a range** — e.g. "add 22–23 to every weekday without touching existing ranges"
6. **Grid bulk selection** — visual grid only supports single-day selection; no multi-select or checkboxes
7. **Bulk editing across categories from the grid** — grid asks "what to edit?" per day, not per selection

---

## 2. Problem Statement

Users who want to:
- Make a small adjustment to many days (e.g. shift all weekday start times 1 hour later)
- Add a late-night range to multiple days without re-entering each day
- Clear an entire category (e.g. remove all uninstall lock hours) quickly
- Copy a complex multi-range schedule from one day to several others
- Keep restricted + lock + uninstall lock in sync (same pattern across all three)

...must currently navigate through per-day dialogs or the weekday/weekend split. For users with mixed schedules (e.g. Mon/Wed/Fri identical, Tue/Thu different), even the weekday/weekend shortcut is insufficient.

---

## 3. Candidate Approaches

### Approach A: "Apply to all days" shortcut inside the existing weekday/weekend flow

**Idea:** After the user enters a range in `configure_weekdays_section()` or `configure_weekends_section()`, add a follow-up: *"Also apply this to weekends?"* (or vice versa), and ultimately *"Apply to all 7 days?"*

**Pros:**
- Minimal UI change; reuses existing dialogs
- Low implementation risk
- No new dialog abstractions needed

**Cons:**
- Only helps for truly uniform schedules; still no day-to-day copying
- Does not address bulk *remove* or *edit* of existing ranges
- Adds extra click for the common case where users do NOT want to apply to all

**Safety impact:** Low. Still passes through the same `get_day_hours()` validation and partial-lock checks.

**Est. effort:** Small — 1–2 dialog prompts in `configure-workflow.sh`.

---

### Approach B: Grid multi-select + bulk action menu

**Idea:** In `show_visual_grid()`, allow selecting multiple days (checkboxes or Ctrl/Cmd-click), then choose a bulk action: *Set restricted hours*, *Add range*, *Clear lock hours*, *Copy from [day]*, etc.

**Pros:**
- Most powerful and discoverable; users see the whole week at once
- Natural for "clear all lock hours" or "copy Monday to Wed+Thu"
- Works for all three categories from one UI surface

**Cons:**
- **Dialog tool limitation:** yad/zenity/kdialog do not natively support multi-select lists with checkboxes in a clean way. yad has `--checklist` but column alignment is tricky. macOS tkinter would need custom widget work.
- High UI complexity: need a new "bulk action" sub-dialog after selection
- Partial lock mode must validate the combined effect of the bulk change before applying — if the user selects 5 days and tries to remove ranges, the wizard must reject the whole batch or allow only the "add" subset.
- Breaks existing grid caching (`_CONFIGURE_GRID_CACHE_VALID` / JSON cache) because selections now carry state.

**Safety impact:** Medium. Bulk changes can accidentally push a user over the 16 h/day cap or into a 24/7 lockout. Need to run `check_daily_caps` on the *proposed* batch before applying.

**Est. effort:** Medium–Large — new dialog type, new workflow function, macOS tkinter updates, grid cache invalidation logic.

---

### Approach C: Day-to-day copy utility in the grid

**Idea:** In the grid (or per-day dialog), add a *"Copy to other days..."* option. User picks source day, then selects target days via a checklist dialog.

**Pros:**
- Directly solves the "Mon/Wed/Fri identical" pattern
- Reuses existing range validation; just copies the string value
- Can work inside the existing `configure_day_from_grid()` flow without changing the grid selection model

**Cons:**
- Still requires entering the source day first (not a true global bulk editor)
- Checklist dialog portability across yad/zenity/kdialog/osascript needs a new abstraction
- Partial lock mode: copying a range to a day that previously had no restrictions is effectively "adding" (allowed), but copying an empty range to a day that had restrictions is "removing" (must be rejected during lock hours).

**Safety impact:** Low–Medium. Need to ensure copied ranges are validated against target-day caps.

**Est. effort:** Medium — new `configure-dialogs.sh` abstraction for multi-checklist, new copy logic in `configure-workflow.sh` or `configure-input-time.sh`.

---

### Approach D: Text-based bulk edit mode (config file snippet)

**Idea:** In text mode (or as a new GUI option), present a raw editable block:

```
SUNDAY=1-5
MONDAY=0-5
...
```

User edits all lines in a text editor (via `zenity --text-info` or `yad --text` or temp-file + `$EDITOR`), then the wizard parses and validates the entire block.

**Pros:**
- Fastest for power users
- Zero new dialog design; leverages existing parse/validate functions
- Easy to implement in text mode; GUI can use a text-info dialog

**Cons:**
- Error-prone for non-technical users (invalid syntax, typos)
- GUI text dialog sizing is poor on some dialog tools (kdialog especially)
- Requires a full validation pass after edit, which may reject the whole block and force the user to start over
- Not accessible on macOS osascript (no native multi-line text editor dialog)

**Safety impact:** Medium. One typo could create 24/7 coverage. Must run `check_daily_caps` + `check_restriction_coverage` on the parsed result.

**Est. effort:** Small–Medium — new menu option, temp-file wrapper, parser call.

---

### Approach E: Template / preset schedules

**Idea:** Offer preset schedules (e.g. "Night owl: 0–5 every day", "Student: 23–6 weekdays only", "Weekend gamer: 1–8 weekends only") that the user selects from a list, then optionally tweaks.

**Pros:**
- Reduces bulk editing to a single selection for common patterns
- No multi-select UI needed
- Very safe: presets are pre-validated

**Cons:**
- Does not solve the "custom mixed schedule" problem (e.g. Mon/Wed/Fri = 23–6, Tue/Thu = 0–5)
- Preset maintenance: every new preset needs validation + docs + i18n considerations

**Safety impact:** Very low. Presets are static and validated at build time.

**Est. effort:** Small — new list dialog, preset array, application logic in `configure-workflow.sh`.

---

## 4. Safety Considerations (must not bypass)

Any bulk implementation must preserve these existing safety gates:

1. **Per-day 16 h cap** (`lib/daily-caps.sh` / `check_daily_caps`)
   - Bulk changes must be validated day-by-day before applying.
   - A bulk "add" could push a day from 15 h to 17 h and must be blocked.

2. **24/7 restriction prevention** (`check_restriction_coverage`)
   - A bulk copy or preset must not leave the user with zero unrestricted time.

3. **Partial lock / tighten-only mode** (`lib/configure-partial-lock.sh`)
   - During lock hours, bulk *removal* or *relaxation* must be rejected.
   - Bulk *add* or *tightening* is allowed.
   - A mixed batch (some days add, some days remove) must be rejected entirely or the remove subset must be silently skipped — but silently skipping is poor UX. Better to reject the whole batch with an explanation.

4. **Config file locking** (`lib/config-locking.sh`)
   - Bulk write must still use `config_lock_prepare_for_wizard_write` + atomic `mv` + `config_lock_finish_wizard_write`.

5. **Popup safety** (`lib/popup-safety.sh`)
   - Not directly affected by bulk editing, but if the bulk UI spawns a new dialog type, it must respect the same PID-management and watchdog rules as existing popups.

---

## 5. Cross-Category Bulk Editing

The user asked specifically about bulk editing across **restricted hours, lock hours, and uninstall lock hours**. The current code treats these as three separate arrays (`config_lines`, `lock_hours_lines`, `uninstall_lock_hours_lines`) with separate menu entries (options 3/4, 6, 8).

A cross-category bulk feature could look like:

- **"Mirror restricted hours into lock hours"** — one-click copy of all `MONDAY=...` into `CONFIG_LOCK_HOURS_MONDAY=...` for every day.
- **"Mirror restricted hours into uninstall lock hours"** — same pattern.
- **"All three categories share this schedule"** — enter once, apply to all three.

**Pros:** Reduces repetitive configuration.
**Cons:** Easy to accidentally over-restrict. If a user wants 0–5 restricted, they probably do NOT want 0–5 as lock hours (which would block configure.sh during that time). The features are intentionally separate.

**Recommendation:** Cross-category bulk is higher risk and lower user value than within-category bulk. Defer unless user research shows strong demand.

---

## 6. Platform-Specific UI Constraints

| Platform | Constraint |
|----------|------------|
| Linux (yad) | `--checklist` exists but column layout is brittle; `--list` with `--check` is possible |
| Linux (zenity) | `--checklist` is a `--list` with `--check`; no true multi-select return |
| Linux (kdialog) | No native checklist; `--checklist` requires `--separate-output` hack |
| macOS (osascript) | No native multi-select list; tkinter daemon would need custom checkbox widget |
| macOS (tkinter) | Custom UI possible but adds maintenance burden |
| Text mode | Trivial: multi-select via comma-separated numbers (e.g. `1,3,5`) |

**Implication:** Any multi-select/checkbox UI (Approach B, C) requires a new dialog abstraction that is **not** portable across all supported tools. The project already has `show_multi_column_list_dialog` for single-select tables; extending it to multi-select is non-trivial.

---

## 7. Recommended Path Forward

### Phase 1: Low-hanging fruit (immediate value, low risk)

1. **"Apply to all days" prompt** (Approach A variant)
   - After the user sets weekday hours, ask: *"Apply the same hours to weekends?"* and vice versa.
   - Add to restricted hours, lock hours, and uninstall lock hours workflows.
   - Effort: Small. Safety: Low.

2. **"Clear all" option in each section**
   - Add a menu item inside the weekday/weekend flow: *"Clear all [category] hours for [weekdays/weekends/all days]"*.
   - Must respect partial lock mode (reject if locked).
   - Effort: Small. Safety: Low.

3. **Presets** (Approach E)
   - Add 3–5 common preset schedules to the main menu (e.g. "Night owl", "Early bird", "Weekend only").
   - Effort: Small. Safety: Very low.

### Phase 2: Power-user features (higher value, higher risk)

4. **Day-to-day copy** (Approach C)
   - Inside the visual grid or per-day dialog, add *"Copy to other days..."*.
   - Use a simple checklist dialog (new abstraction in `configure-dialogs.sh`).
   - Validate per-day caps before applying.
   - Effort: Medium. Safety: Medium.

5. **Text-mode bulk edit** (Approach D)
   - Add a hidden/expert option in text mode: *"Edit raw schedule block"*.
   - Opens `$EDITOR` or a temp file; parse and validate on save.
   - Effort: Small–Medium. Safety: Medium.

### Phase 3: Advanced UI (deferred until dialog tools support it)

6. **Grid multi-select + bulk actions** (Approach B)
   - Defer until yad/zenity/kdialog multi-select is solved, or until a native GUI wrapper (Enhancement #13b) is implemented.
   - Effort: Large. Safety: Medium.

---

## 8. Files That Would Be Touched

| File | Role | Likely change |
|------|------|---------------|
| `lib/configure-workflow.sh` | Orchestration | New bulk functions, modify existing section flows |
| `lib/configure-dialogs.sh` | Dialog abstraction | New checklist/multi-select dialog wrapper |
| `lib/configure-dialogs-darwin.sh` | macOS dialogs | Tkinter checkbox or list extension |
| `lib/configure-input-time.sh` | Time input | Bulk add/remove range logic |
| `lib/configure-ui.sh` | UI helpers | Cancel/menus for bulk actions |
| `lib/configure-display.sh` | Grid display | Multi-select grid variant (if Phase 3) |
| `lib/configure-validation.sh` | Validation | Batch validation helper (validate N days at once) |
| `lib/daily-caps.sh` | Safety caps | No change (already batch-capable) |
| `tests/test-configure-*.sh` | Tests | New test cases for bulk operations |

---

## 9. Open Questions

1. **Should bulk changes be atomic?** If a user tries to apply a range to 5 days but day 3 exceeds the 16 h cap, do we reject the entire batch or apply to the 4 valid days and warn? (Recommendation: reject entire batch; partial success is confusing.)

2. **Should partial lock mode allow bulk *adds*?** Yes, adding is tightening. But if the user selects a mix of days (some already have the range, some don't), the "add" is idempotent on existing days — acceptable.

3. **Should there be an undo?** The wizard already does not have undo. Bulk changes make the lack of undo more painful. Consider adding a "Review before apply" intermediate dialog for bulk operations.

4. **Priority vs. other backlog:** This is adjacent to [#16c](enhancements/enhancement-16c-multiple-range-entry-gui.md) (GUI multiple ranges) and the [May 2026 refactor](plans/plan-refactor-assessment-2026-05-31.md). Bulk editing should be built **after** the refactor stabilizes the configure UI, or it will add more debt to files already flagged for splitting.

---

*End of assessment.*
