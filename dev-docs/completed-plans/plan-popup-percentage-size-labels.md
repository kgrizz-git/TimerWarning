# Archived — Percentage Labels for Display-Based Popup Sizes

> **Archived 2026-10-25.** Implementation shipped: GUI size selection shows
> percentage mappings (`lib/configure-input-popup-size.sh`, e.g. `xsmall (15%x15%)`),
> terminology standardized on percentage-based sizing, automated tests recorded in
> `dev-docs/testing-assessments/test-history.md`. All completion criteria checked.
> Historical record; see [REMAINING_WORK_SUMMARY.md](../REMAINING_WORK_SUMMARY.md)
> for current enhancement tracking.

## Plan: Percentage Labels for Display-Based Popup Sizes

### Overview

When users select a popup size in the configuration wizard while using the display-based size mode, the current GUI does not clearly show the underlying percentage mappings for each predefined size (xsmall, small, medium, large, xlarge, max). Text mode shows both the percentages and absolute pixel dimensions, but GUI mode only shows the size names. This plan adds clear percentage labels to the popup size selection flow and ensures that all terminology and documentation consistently describe the mode as percentage-based sizing.

### Goals

1. **Show percentage mappings when choosing popup size in display-based mode** in the `configure.sh` wizard (GUI and text mode where appropriate).
2. **Ensure consistent size mappings** (xsmall→15%, small→20%, medium→30%, large→50%, xlarge→75%, max→90%) across:
   - Configuration reading/writing
   - Wizard prompts and summaries
   - Popup rendering logic
3. **Improve terminology** so user-facing text clearly refers to the display-based mode as **percentage-based sizing**, without breaking existing configuration values (`POPUP_SIZE_MODE=display-based`).
4. **Validate with automated tests** for window size behavior and configuration wizard flows, and document tests run.

### Background

- Enhancement **#3: Enhanced Window Size Options and Display-Based Sizing** introduced:
  - Six predefined sizes: `xsmall`, `small`, `medium`, `large`, `xlarge`, `max`
  - A display-based (percentage-based) mode that maps sizes to fixed screen percentages
  - Custom percentage sizing with `WIDTH%xHEIGHT%` format and 15–95% validation.
- Current behavior:
  - `lib/config.sh` and `lib/configure-display.sh` already implement the correct mappings and use them when computing popup dimensions and when summarizing configuration.
  - `user-docs/CONFIGURATION.md` and `user-docs/USER_GUIDE.md` document both fixed and percentage-based sizes.
  - `lib/configure-input-popup.sh`:
    - Text mode lists sizes with both percentages and pixels (e.g., `xsmall (15%×15% or 384×216)`).
    - GUI mode list dialog currently shows only the bare size names (`xsmall`, `small`, etc.) without percentages.
  - Terminology is mixed: some places say “display-based”, others say “display-based (percentage-based)”.

### Implementation Plan

#### Phase 1: Analysis and Design

- [x] Review Enhancement #3 documentation and tests to confirm the canonical percentage mappings and any edge cases.
- [x] Identify all code paths where popup sizes are:
  - Selected in `configure.sh` (GUI and text modes)
  - Summarized in configuration review screens
  - Persisted to and read from `sleep-warning.conf`
- [x] Identify all user-facing documentation and comments that describe “display-based” sizing.

#### Phase 2: Wizard Popup Size Selection Improvements

- [x] Update `get_popup_size_config()` in `lib/configure-input-popup.sh` so that, when a display-based / percentage-based mode is active:
  - GUI dialogs clearly show percentage mappings for each predefined size when the user is choosing a popup size.
  - The implementation **does not change** the underlying `POPUP_SIZE` values (`xsmall`, `small`, etc.) returned from the function.
  - Behavior remains backward compatible when size mode is `fixed` or when no mode is set.
- [x] Update `configure.sh`’s Window Behavior flow to pass the current size mode into `get_popup_size_config()` (as needed) so both fixed and percentage-based modes behave correctly within a single configuration session.
- [x] Verify that high-restriction safety overrides (which may clamp sizes to xsmall/small/medium) remain consistent with the new labels.

#### Phase 3: Consistency and Terminology Updates

- [x] Audit user-facing strings in:
  - `lib/configure-input-popup.sh`
  - `lib/configure-display.sh`
  - `lib/config.sh`
  - `configure.sh` (Window Behavior section only)
- [x] Update prompts, help text, and comments so that:
  - The mode is described as **“percentage-based popup sizing”** or **“percentage of screen”**.
  - Where configuration values must remain `display-based`, documentation and prompts use phrasing like **“display-based (percentage-based) mode”** to avoid confusion.
- [x] Update `user-docs/CONFIGURATION.md` and `user-docs/USER_GUIDE.md` where they talk about “display-based” so that the primary phrasing is “percentage-based sizing” while still documenting that the config key uses `POPUP_SIZE_MODE=display-based`.

#### Phase 4: Testing and Validation

- [x] Run existing window size and enhancement #3 test suites, including:
  - `tests/test-enhancement-03-window-sizes.sh`
  - `tests/test-enhancement-03-integration.sh`
  - `tests/test-enhancement-03-wizard.sh`
  - `tests/test-dialog-sizes.sh` and `tests/test-popup-button-visibility.sh` as applicable (note: the last two remain manual/interactive tests intended for human use; automated runs covered the first three scripts).
- [x] Add or update any tests needed to cover:
  - Correct labels shown in GUI popup size selection when in display-based / percentage mode.
  - No regressions for text-mode configuration output.
- [x] Document tests run and results in `dev-docs/testing-assessments/test-history.md` following the existing format.

### Completion Criteria

- [x] When `POPUP_SIZE_MODE=display-based` is selected (or selected in the current wizard session), the popup size selection UI in `configure.sh` clearly shows percentage values for each predefined size.
- [x] All predefined sizes use the correct percentage mappings in code, documentation, and UI text:  
  `xsmall` = 15%×15%, `small` = 20%×20%, `medium` = 30%×30%, `large` = 50%×50%, `xlarge` = 75%×75%, `max` = 90%×90%.
- [x] User-facing text consistently refers to percentage-based sizing, while configuration compatibility with `POPUP_SIZE_MODE=display-based` and existing tests is preserved.
- [x] Relevant automated tests pass, and test history is updated.

