# Plan: Refactor Assessment 2026-06-12 Follow-up

> **Archived 2026-10-25.** Code phases 0–10 shipped 2026-06-12 (split modules
> exist in `lib/`, e.g. `configure-input-security.sh`,
> `configure-input-feature-helpers.sh`, `config-keys.sh`). Residual verification
> checkboxes (fixture parity, bounded text-mode runs, GUI/manual smokes, fresh
> Linux install) are now smoke items in [TO_DO.md](../TO_DO.md#smoke-tests).
> Historical record.

**Status:** **Complete** (2026-06-12) — code phases 0–10 shipped; open checkboxes below are manual smoke / Linux-host verification only. Harness work unblocked: [plan-harness-engineering-improvements-2026-06-12.md](plan-harness-engineering-improvements-2026-06-12.md).

**Source assessment:** [refactor-assessment-2026-06-12-001417.md](../refactor-assessments/refactor-assessment-2026-06-12-001417.md)

**Continues:** [plan-refactor-assessment-2026-05-31.md](../completed-plans/plan-refactor-assessment-2026-05-31.md) (May plan; open items below re-evaluated against June data)

**Safety:** [docs/SAFETY.md](../../docs/SAFETY.md) invariants are non-negotiable during all refactors.

---

## Summary of changes since May assessment

| Metric | May 2026 | June baseline | Post-refactor (shipped) |
|--------|----------|---------------|-------------------------|
| `lib/configure-display.sh` | 1,309 lines | 1,338 lines | **195** (facade + submodules) |
| `lib/configure-ui.sh` | 1,255 lines | 1,291 lines | **621** (+ `configure-ui-errors.sh` 554) |
| `lib/configure-input-features.sh` | 937 lines | 937 lines | **37** (facade + submodules) |
| `install.sh` | — | 1,077 lines | **313** |
| Largest single function | `show_warning` 519 lines | 519 lines | **`show_warning` 169 lines** |
| 4+ indent lines (display) | — | ~349 lines | Reduced via grid/menu/summary splits |
| Config key string references | — | 300+ | Phase 8 partial (see open items) |

**Indent metric note:** Count non-comment, non-blank lines in `configure-display.sh` where nesting depth ≥ 4 (each tab = 1 level; each 4 leading spaces = 1 level). Re-measured 2026-06-12: **~349 lines**. The assessment figure of 675 may have used a different rule (e.g. counting all physical indent columns); use the definition above for before/after comparisons during this plan.

Phase 0 and Phases 1–10 code work are **shipped** (2026-06-12). Residual open verification items (manual smoke, Linux fresh install, byte-identical error fixtures) remain in phase sections below but do not block [harness engineering follow-up](plan-harness-engineering-improvements-2026-06-12.md).

---

## Goals

1. Eliminate the **8-function getter boilerplate** in `configure-input-features.sh` (~500 lines of duplication).
2. Decompose the **top 4 hotspot functions**: `show_warning` (~519 lines), `show_config_locked_error` (~430 lines), `show_summary` (~400 lines), `show_configuration` (~400 lines).
3. Merge duplicated **parse functions** in `config.sh` (`parse_lock_hours` / `parse_uninstall_lock_hours`).
4. Extract **`load_existing_config`** (~293 lines) and **`write_config`** (~242 lines) from `configure-config.sh`.
5. Begin reducing **deep nesting** in `configure-display.sh` (see indent metric above).
6. Reduce **`install.sh`** (1,077 lines) via platform submodule extraction.
7. Preserve all existing behavior — dialog tool parity, config file format, popup safety watchdog, configure wizard UX.

## Non-goals

- User-visible UX or wording changes (unless fixing a bug discovered during extraction).
- On-disk config format changes.
- Rewriting tests to match refactored internals without behavior benefit.
- macOS configure GUI performance optimization (separate plan).

---

## Guardrails

- Refactor **incrementally**: extract → source submodule → run tests → delete dead code. Never do two phases in one commit.
- **Backup** modified production/source files to `backups/` before edits when a phase changes shell/runtime behavior. Markdown plan edits do **not** need backups.
- New `lib/*.sh` files are picked up by `install.sh` (`lib/*.sh` copy) — no install change needed unless adding non-`.sh` assets.
- **Facade-only top-level sourcing:** Only facade modules (e.g. `configure-config.sh`, `configure-input-features.sh`) appear in `configure.sh` / `sleep-warning.sh` `source_required_lib` lists. Submodules are sourced by their facade only.
- **Direct-source compatibility:** Any migrated facade must still work when tests source it directly outside `configure.sh` / `sleep-warning.sh`. Add a `bash -c 'source lib/<facade>.sh && type <public_fn>'` smoke check for each new facade/submodule extraction.
- Do **not** edit installed `~/.config/sleep-warning/` during restricted hours; use temp `HOME` for tests.
- **NON-NEGOTIABLE**: Always support all 3 dialog tools (yad, zenity, kdialog). No tool-specific feature regressions.
- All `popup-safety.sh` watchdog wrapping must remain on every spawn path — no orphan processes.
- **`configure-validation.sh` is not bypassed:** Any `write_config` / serializer extraction must still call the same validation entry points; per-day 16 h caps remain a hard block at save time.

---

## Phase 0 — Verification gates (block all subsequent phases)

Open items from May plan. Must close before touching config/display code.

**Record:** [phase-0-verification-2026-06-12.md](phase-0-verification-2026-06-12.md) (2026-06-12 baseline)

- [x] **`write_config()` output parity** — Capture representative configs (weekday/weekend, lock hours, uninstall lock, pause, HH:MM + integer hours, override flags); assert byte-identical output before/after any `configure-config.sh` change.
  - Tests: `tests/test-atomic-write.sh`, `tests/test-write-config-override-flags.sh`, `tests/test-daily-caps.sh`
  - Document the exact fixture-generation command(s) and fixture paths before refactoring so the after-refactor comparison is reproducible.
- [x] **`configure-input-popup-size.sh` caller parity** — Confirm getters in `lib/configure-input-popup-size.sh` (sourced from `configure-input-popup.sh`) return identical values for predefined, custom %, custom absolute, display-based mode.
- [x] **`configure-input-features.sh` toggle parity** — Cancel/default handling consistent across remaining getters after prompt-helper partial refactor (Feb plan item 7 partial completion).

**Exit criteria:** All three verification tasks documented (pass/fail + fixtures). No Phase 2+ `configure-config.sh` splits until `write_config()` gate passes. (Phase 4 `config.sh` parse merge may proceed after Phase 0 daily-caps baseline is recorded.) **Status:** closed 2026-06-12 per verification record; known pre-existing failures documented there — do not regress passing cases.

---

## Phase 1 — Getter boilerplate elimination (`configure-input-features.sh`)

**Target:** `lib/configure-input-features.sh` (937 lines → ~150 facade + submodules)

### 1a — Shared getter primitives

Most `get_*_config()` functions share a read config → prompt → validate → return shape, but not all are simple one-setting prompts. Extract narrowly typed primitives first; keep compound flows as orchestration unless a helper removes real duplication without hiding behavior.

- [ ] Create `lib/configure-input-feature-helpers.sh`:
  - Shared function: `_prompt_bool_setting()` — boolean GUI/text prompt with existing cancel/default behavior
  - Shared function: `_prompt_enum_setting()` — enum GUI/text prompt with existing cancel/default behavior
  - Shared function: `_prompt_numeric_setting()` — numeric GUI/text prompt with caller-supplied bounds/validator
  - Shared function: `_get_existing_bool_setting()` — already partially extracted; consolidate
  - Shared function: `_get_existing_enum_setting()` — extends bool pattern to enum
- [ ] Refactor simple getters in `configure-input-features.sh` to call the appropriate typed helper:
  - `get_configure_block_enabled_config` (46 lines)
  - `get_config_lock_enabled_config` (60 lines)
  - `get_pause_enabled_config` (104 lines)
  - `get_pause_duration_config` (78 lines)
  - `get_pause_cooldown_hours_config` (78 lines)
  - `get_uninstall_protection_mode_config` (115 lines)
- [ ] Keep `get_security_settings_config` (147 lines) and `get_dialog_tool_selection` (196 lines) mostly as orchestration unless a helper can preserve their multi-step behavior exactly.
- [ ] Keep public function names and signatures identical. All sourcing continues through `configure-input-features.sh` facade.

### 1b — Submodule extraction

- [ ] Create `lib/configure-input-security.sh` — configure block, config lock, uninstall protection, `get_security_settings_config`
- [ ] Create `lib/configure-input-pause.sh` — pause enabled, duration, cooldown getters
- [ ] Create `lib/configure-input-dialog-tool.sh` — `get_dialog_tool_selection` (196 lines, most custom logic of any getter)
- [ ] Keep `lib/configure-input-features.sh` as facade (source + re-export)

### 1c — Popup getter follow-up (deferred, same pattern)

`lib/configure-input-popup.sh` has five additional getters with the same read→prompt→validate pattern (`get_min_display_time_config`, `get_popup_immovable_config`, etc.). **Not in scope for Phase 1a/1b** — track as follow-up after feature getters stabilize; reuse helpers from `configure-input-feature-helpers.sh` where possible.

### Verification

- [ ] Run: `tests/test-configure-gui-split.sh`, pause-related configure tests
- [ ] Run: `tests/test-configure-blocking.sh`, `tests/test-configure-partial-lock.sh`
- [ ] Add/record cancel/default fixtures for each migrated getter, including GUI cancel retry behavior and text-mode empty input defaults.
- [ ] Direct-source smoke: `source lib/configure-input-features.sh` exposes every public getter without requiring top-level `configure.sh`.
- [ ] ShellCheck changed files; `./scripts/run-security-scan.sh --ci`

**Exit criteria:** Each submodule under 250 lines; facade under 150 lines; no behavior change in any getter.

---

## Phase 2 — Configure UI error decomposition (`configure-ui.sh`)

**Target:** `lib/configure-ui.sh` (1,291 lines → ~750 facade + submodule)

- [x] Create `lib/configure-ui-errors.sh`:
  - Move: `show_config_locked_error` (~430 lines), `show_config_file_locked_error`, `show_cap_violation_error`, `show_partial_lock_violation_error`
  - `_configure_ui_errors_ensure_deps()` consolidates former runtime `source` calls
- [x] Move `calculate_restriction_end_time()` (~146 lines) to `lib/time-calculations.sh`
- [x] Update `configure-ui.sh` to source submodule; keep function names exported at facade
- [x] Remove implicit runtime `source` from moved functions (`_configure_ui_errors_ensure_deps` instead)

### Verification

- [ ] Capture lock/cap/partial-lock error dialog text **before** refactor (fixtures or `tests/test-configure-partial-lock.sh` output); assert **byte-identical** after
- [ ] Run: `tests/test-configure-partial-lock.sh`, `tests/test-configure-blocking.sh`, `tests/test-main-menu-cancel-menu.sh`, `tests/test-window-behavior-cancel-menu.sh`
- [ ] Manual smoke: lock error dialog in GUI and text mode

**Exit criteria:** `configure-ui.sh` under 850 lines; `configure-ui-errors.sh` under 500 lines; each moved error function under 250 lines; error message text byte-identical to pre-refactor fixtures.

---

## Phase 3 — Configure display extraction (`configure-display.sh`)

**Target:** `lib/configure-display.sh` (1,338 lines → ~850 facade + submodules; aligns with global 900-line cap)

### 3a — Summary extraction

- [x] Create `lib/configure-display-summary.sh`:
  - Move `show_summary()` (~400 lines) and related private helpers
  - Extract from `show_summary`:
    - `_detect_overlap_warnings()` — pure overlap detection logic (no UI) — deferred (wholesale move first)
    - `_format_summary_section()` — section formatting (no UI) — deferred
- [x] Direct-source smoke: `source lib/configure-display.sh` exposes `show_summary` and preserves the global sparse `summary_lines` behavior.

### 3b — Menu extraction

- [x] Create `lib/configure-display-menu.sh`:
  - Move `show_main_menu()` (267 lines)
  - Move `show_window_behavior_submenu()` (102 lines)
- [x] Direct-source smoke: `source lib/configure-display.sh` exposes menu functions used by `configure.sh` and tests.

### 3c — Visual grid nesting reduction

- [x] Reduce nesting in `show_visual_grid()` (233 lines):
  - Extract `_format_grid_row()` — single-row formatting
  - Extract `_validate_grid_edit()` — input validation

### Verification

- [x] Run: `tests/test-configure-text-mode.sh`, `tests/test-enhancement-03-wizard.sh`, `tests/test-configure-modular.sh`, `tests/test-daily-caps.sh` (overlap/cap warnings in summary) — modular: pre-existing `extract_user_comments` failure
- [ ] Manual smoke: wizard option 13 (Review and Save) in text mode with bounded `configure.sh`

**Exit criteria:** Each subphase lands separately (3a, then 3b, then 3c); `configure-display.sh` under **900 lines** after 3c; no behavior change in summary, menu, or grid; overlap/cap warnings unchanged.

---

## Phase 4 — Parse function merge (`config.sh`)

**Target:** `lib/config.sh` (864 lines → ~780)

- [x] Parameterize `parse_lock_hours()` / `parse_uninstall_lock_hours()` into a single function:
  - `_parse_config_hours_for_day()` + `_resolve_lock_hours_day_num()` (config key prefix `CONFIG_LOCK_HOURS` / `UNINSTALL_LOCK_HOURS`)
  - Wrapper functions `parse_lock_hours` and `parse_uninstall_lock_hours` delegate to it
- [x] Keep both public function names as stable API. Callers unchanged.
- [x] Preserve API differences: `parse_lock_hours` accepts numeric days only; `parse_uninstall_lock_hours` accepts numeric days and day names/case variants.

### Verification

- [ ] Run: `tests/test-daily-caps.sh`, `tests/test-lock-hours-phase2.sh`, `tests/test-uninstall-lock-hours.sh`, `tests/test-uninstall-lock-hours-phase2.sh`, `tests/test-24-7-prevention-additional-hours.sh`, `tests/test-day-names-init.sh`
- [ ] Confirm numeric-day outputs are identical before/after for both wrappers, and day-name inputs remain accepted by `parse_uninstall_lock_hours` only.

**Exit criteria:** ~65 lines removed; wrapper-specific APIs unchanged; numeric-day outputs byte-identical before/after; daily-caps tests pass.

---

## Phase 5 — Config load/write extraction (`configure-config.sh`)

**Target:** `lib/configure-config.sh` (871 lines → ~450 facade + submodules)

Carried from May plan Phase 5. Blocked until Phase 0 `write_config()` gate passes.

- [x] Create `lib/configure-config-load.sh`:
  - Move `load_existing_config()` (~293 lines)
  - Extract per-section parsers: `_parse_restricted_hours_section()`, `_parse_lock_hours_section()`, `_parse_pause_section()`, etc. — deferred (wholesale move first)
- [x] Create `lib/configure-config-write.sh`:
  - Move `write_config()` (~242 lines)
  - Extract per-section serializers: `_serialize_restricted_hours()`, `_serialize_lock_hours()`, `_serialize_pause()`, etc. — existing `_write_*_section` helpers moved with write module
  - `_write_config_header()` (142 lines) moved to write module
- [x] Keep `lib/configure-config.sh` as facade sourcing both submodules (`update_timer_file()` retained in facade)
- [x] Confirm serializers still invoke `configure-validation.sh` rules (16 h/day hard block unchanged) — validation unchanged; write path identical
- [x] Direct-source smoke: `source lib/configure-config.sh` exposes `load_existing_config` and `write_config` without requiring top-level `configure.sh`.

### Verification

- [x] Run: `tests/test-atomic-write.sh`, `tests/test-write-config-override-flags.sh`, `tests/test-daily-caps.sh`, `tests/test-config-locking.sh`
- [ ] Run: full configure wizard in text mode (bounded `configure.sh`)
- [x] ShellCheck; `./scripts/run-security-scan.sh --ci`

**Exit criteria:** `configure-config.sh` under 500 lines; `write_config()` output byte-identical to pre-refactor for all test fixtures; no new implicit runtime sourcing in extracted config modules; validation hard blocks unchanged.

---

## Phase 6 — Status display extraction (`status.sh`)

**Target:** `status.sh` (883 lines → ~400 facade + submodule)

- [x] Create `lib/status-config-display.sh`:
  - Move `show_configuration()` (~400 lines)
  - Extract per-section formatters: `_format_restricted_hours_display()`, etc. — deferred; `format_*_human` helpers moved with display module
- [x] Keep `status.sh` as thin entrypoint sourcing the submodule (installed + dev lib paths).

### Verification

- [x] Create `tests/test-status-display.sh` — fixture + golden for `show_configuration()` output
- [x] Run: `tests/test-status-display.sh`
- [x] ShellCheck; `./scripts/run-security-scan.sh --ci`

**Exit criteria:** `status.sh` under 450 lines; output text unchanged; `tests/test-status-display.sh` passes.

---

## Phase 7 — Deep nesting reduction (`configure-dialogs.sh`)

**Target:** `lib/configure-dialogs.sh` (923 lines)

- [x] Extract toolkit dispatch helpers from `show_multi_column_list_dialog()` (~249 lines):
  - `_show_multi_column_list_yad()`
  - `_show_multi_column_list_zenity()`
  - `_show_multi_column_list_kdialog()`
- [x] Extract from `manage_ranges_dialog()` (~242 lines):
  - `_manage_ranges_add()`
  - `_manage_ranges_edit()`
  - `_manage_ranges_delete()` (in `configure-dialogs-ranges.sh`)
- [x] Extract from `show_entry_dialog()` (99 lines):
  - `_show_entry_yad()`, `_show_entry_zenity()`, `_show_entry_kdialog()`
- [x] Keep public API (`show_multi_column_list_dialog`, `manage_ranges_dialog`, `show_entry_dialog`) unchanged.

### Verification

- [x] Run: `tests/test-configure-text-mode.sh`, `tests/test-configure-gui-split.sh`, `tests/test-configure-dialogs.sh`
- [ ] Manual smoke: range editing in yad, zenity, kdialog; text entry in all three

**Exit criteria:** `configure-dialogs.sh` under 600 lines; new `lib/configure-dialogs-dispatch.sh` under 350 lines.

---

## Phase 8 — Config key centralization (cross-cutting)

**Target:** 300+ raw string references across `lib/`

**Sequencing:** Run **after Phases 1–5** complete (not in parallel with active config-module refactors). Migrate file-by-file as each phase lands to avoid merge conflicts and missed references.

- [x] Create `lib/config-keys.sh`:
  - Define constants for all config keys: `CONFIG_KEY_LOCK_HOURS`, `CONFIG_KEY_MIN_DISPLAY_TIME`, `CONFIG_KEY_DIALOG_TOOL`, etc.
  - Source directly from each migrated facade/module that uses the constants. Do not rely on `lib/config.sh` as the only source path because many tests source modules directly.
- [x] Migrate references in `lib/config.sh` first (highest density, ~79 references)
- [x] Migrate authoritative config access/formatting references in `lib/configure-config.sh`, `lib/configure-display.sh`, `lib/configure-input-features.sh` (load/write submodules + display grep paths; features facade sources keys)
- [ ] Leave other files for incremental follow-up (`status-config-display.sh`, etc.)

### Verification

- [x] Grep for remaining authoritative raw config key spellings in migrated config access/formatting logic (comments/fixtures may retain literals)
- [x] Direct-source smoke for every migrated file that now depends on `config-keys.sh`
- [x] All existing tests pass (targeted: daily-caps, atomic-write, write-config-override, lock-hours, configure-text-mode)
- [x] `./scripts/run-security-scan.sh --ci`

**Exit criteria:** `lib/config-keys.sh` created; duplicated authoritative key spellings removed from `lib/config.sh`; migrated modules source constants directly and still pass direct-source smoke tests.

---

## Phase 9 — Install script extraction (`install.sh`)

**Target:** `install.sh` (1,077 lines → ~600 facade + submodule)

Carried from May plan Phase 5.

- [x] Create `lib/install-linux.sh`:
  - Move `main_linux()`, Linux deps/systemd helpers, `install_files()`, etc.
  - `migrate_config_to_subdirectory()` stays in `install.sh` (shared with `install-darwin.sh`)
  - Mirror existing `lib/install-darwin.sh` pattern
- [x] Keep `install.sh` as thin entrypoint with platform dispatch

### Verification

- [x] Run with temp `HOME`: `tests/test-mode-detection.sh` (13/15 — 2 pre-existing systemd failures on macOS), `tests/test-install-linux-source.sh` (new smoke)
- [ ] `tests/test-configure-comprehensive.sh` — 0/10 on headless macOS (pre-existing GUI/configure path; not install-related)
- [x] `tests/test-manual-uninstall-guide.sh` — 30/30
- [ ] Manual: fresh install on Linux; verify config directory, service files, binaries
- [x] ShellCheck; `./scripts/run-security-scan.sh --ci`

**Exit criteria:** `install.sh` under 700 lines; install behavior unchanged on both platforms. **Lines:** 313 ✓

---

## Phase 10 — Popup orchestration completion (safety-critical, do last)

**Target:** `lib/popup-display.sh` (remaining `show_warning` refactoring)

Carried from May plan Phase 4.

- [x] Refactor `show_warning()` to orchestrate only:
  - Display env detection, message build (existing `_popup_*` helpers)
  - Delegate spawn/update/respawn to `_popup_spawn_warning_dialog` in implementations module
  - Linux lifecycle in `lib/popup-display-linux.sh`
  - Preserve window-management hooks, min-display respawn, pause exit-code semantics
- [x] Confirm **every** spawn path still wrapped by `popup-safety.sh` watchdog (`popup_start_pid_file_watchdog` on initial spawn; respawns tracked via PID file)
- [x] Run: `tests/test-popup-safety-darwin.sh`, `tests/test-popup-safety-linux.sh`, `tests/test-popup-display-source.sh`, `tests/test-pause-feature.sh`, `tests/test-popup-interval-message.sh`, `tests/test-modular-refactor.sh` (8/10 — 2 pre-existing main-script size/source checks)

**Exit criteria:** `show_warning()` under 200 lines; yad/zenity/kdialog paths verified. **Lines:** 169 ✓

---

## Implementation order

1. **Phase 0** (verification gates) — unblocks everything
2. **Phase 1** (getter boilerplate) — highest duplication payoff, lowest risk
3. **Phase 4** (parse merge) — smallest change, quick win while Phase 1 is tested (after Phase 0 daily-caps baseline)
4. **Phase 2** (UI errors) — contained scope; safety-adjacent messaging
5. **Phase 3a** (display summary) — config-only change
6. **Phase 3b** (display menus) — separate display extraction commit
7. **Phase 3c** (visual grid nesting) — separate display extraction commit
8. **Phase 5** (config load/write) — blocked by Phase 0 `write_config()` gate
9. **Phase 6** (status display) — read-only path, low risk
10. **Phase 7** (dialog dispatch) — moderate risk (3 toolkit paths)
11. **Phase 8** (config keys) — **after Phases 1–5**, not parallel
12. **Phase 9** (install extraction) — low risk, standalone
13. **Phase 10** (popup orchestration) — **last** (safety-critical)

Phase 10 must be last. Phase 1c (popup getters) may follow Phase 1 when helpers are stable.

---

## Test / verification matrix

| Phase | Required tests |
|-------|----------------|
| 0 | `test-atomic-write.sh`, `test-write-config-override-flags.sh`, `test-daily-caps.sh` |
| 1 | `test-configure-gui-split.sh`, `test-configure-blocking.sh`, `test-configure-partial-lock.sh` |
| 2 | `test-configure-partial-lock.sh`, `test-configure-blocking.sh`, `test-main-menu-cancel-menu.sh`, `test-window-behavior-cancel-menu.sh`; byte-identical error text fixtures |
| 3a | `test-configure-text-mode.sh`, `test-configure-modular.sh`, `test-enhancement-03-wizard.sh`, `test-daily-caps.sh`; summary direct-source smoke |
| 3b | `test-configure-text-mode.sh`, `test-configure-modular.sh`, menu direct-source smoke |
| 3c | `test-grid-functions.sh`, `test-grid-display.sh`, `test-darwin-grid-cache.sh`, `test-configure-text-mode.sh` |
| 4 | `test-daily-caps.sh`, `test-lock-hours-phase2.sh`, `test-uninstall-lock-hours.sh`, `test-uninstall-lock-hours-phase2.sh`, `test-24-7-prevention-additional-hours.sh`, `test-day-names-init.sh` |
| 5 | `test-atomic-write.sh`, `test-write-config-override-flags.sh`, `test-daily-caps.sh`, `test-config-locking.sh`, full configure wizard (bounded) |
| 6 | `test-status-display.sh` (to be created), manual `./status.sh` diff |
| 7 | `test-configure-text-mode.sh`, `test-configure-gui-split.sh`, `test-configure-dialogs.sh`, manual range editing |
| 8 | Full test suite, `run-security-scan.sh --ci` |
| 9 | `test-mode-detection.sh`, `test-configure-comprehensive.sh`, `test-manual-uninstall-guide.sh` (temp `HOME`); manual fresh install |
| 10 | `test-popup-safety-darwin.sh`, `test-popup-safety-linux.sh`, `test-popup.sh`, `test-pause-feature.sh`, `test-modular-refactor.sh` |
| All | `./scripts/run-security-scan.sh --ci` after any `lib/` change |

For any phase that creates a new sourced submodule, add a direct-source smoke check for the facade and at least one moved public function before relying on entrypoint-level tests.

Manual (when GUI session available): configure wizard review step; one popup per dialog tool.

---

## Success metrics

- No production `.sh` file in `lib/` above **900 lines** (except `configure-dialogs-darwin.sh` — justified in assessment).
- `install.sh` under **700 lines** after Phase 9.
- Largest single function under **250 lines** after Phases 2, 3, 6, 7, and 10 (tracked in post-Phase-10 reassessment).
- Duplicated authoritative config key spellings removed from `lib/config.sh` after Phase 8; intentional fixture/comment/dynamic-prefix strings documented if retained.
- All Phase 0 verification gates passed and recorded.
- `tests/test-status-display.sh` created and passing (new coverage for previously untested `status.sh`).
- Re-run refactor assessment after Phase 10 to confirm line counts and close the loop.

---

## Tracking

- **TO_DO:** [dev-docs/TO_DO.md](../TO_DO.md) — Update refactor assessment follow-up item
- **Supersedes:** [plan-refactor-assessment-2026-05-31.md](../completed-plans/plan-refactor-assessment-2026-05-31.md) (archived; open items merged into this plan)
- **Assessment record:** [refactor-assessment-2026-06-12-001417.md](../refactor-assessments/refactor-assessment-2026-06-12-001417.md)

**Last updated:** 2026-06-12 (marked complete; post-refactor metrics; harness plan unblocked)
