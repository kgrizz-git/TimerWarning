# Plan: Refactor assessment follow-up (2026-05-31)

> **Status: Superseded (archived).** Open items were merged into [plan-refactor-assessment-2026-06-12.md](../plans/plan-refactor-assessment-2026-06-12.md). Kept for history only — do not execute this checklist.

**Source assessment:** [refactor-assessment-2026-05-31-140925.md](../refactor-assessments/refactor-assessment-2026-05-31-140925.md)

**Continues:** [refactor-plan-high-priority-2026-02-05.md](../plans/refactor-plan-high-priority-2026-02-05.md) (Feb extractions largely done; this plan covers remaining hotspots and May findings)

**Safety:** [docs/SAFETY.md](../../docs/SAFETY.md) invariants are non-negotiable during all refactors.

---

## Goals

1. Reduce maintenance risk in the **10 production files** still over 750 lines (assessment summary).
2. Break up monolithic **string-builder hotspots** (`show_config_locked_error`, `show_summary`, `show_configuration`, `show_warning`).
3. Preserve **all existing behavior** — yad/zenity/kdialog parity, configure wizard UX, config file format, popup safety watchdog on every spawn path.
4. Keep **stable module APIs**: parent files source new submodules; avoid churn in `configure.sh` / test source lists where possible.

## Non-goals

- User-visible UX or wording changes (unless fixing a bug discovered during extraction).
- On-disk config format changes.
- Rewriting tests to match refactored internals without behavior benefit.
- macOS configure GUI performance work (see [.cursor/plans/macos_configure_gui_performance_acc3b24e.plan.md](../../.cursor/plans/macos_configure_gui_performance_acc3b24e.plan.md) — coordinate if touching `configure-dialogs-darwin.sh`).

## Guardrails

- Refactor **incrementally**: extract → source submodule → run tests → delete dead code.
- **Backup** every modified file to `backups/` before edits (user rule).
- New `lib/*.sh` files are picked up by `install.sh` (`lib/*.sh` copy) — no install change needed unless adding non-`.sh` assets.
- Entrypoints (`install.sh`, `status.sh`): prefer thin facades; use `library-loader.sh` patterns for discoverability.
- Do **not** edit installed `~/.config/sleep-warning/` during restricted hours; use temp `HOME` for configure/install tests.

---

## Phase 0 — Verification gates (do first)

Open items from Feb plan that block safe further splits:

- [ ] **`write_config()` output parity** — Capture representative configs (weekday/weekend, lock hours, uninstall lock, pause, HH:MM + integer hours, override flags); assert byte-identical output before/after any `configure-config.sh` change.
  - Tests: `tests/test-atomic-write.sh`, `tests/test-write-config-override-flags.sh`
- [ ] **`config-popup-size.sh` caller parity** — Confirm getters return identical values for predefined, custom %, custom absolute, display-based mode.
- [ ] **`configure-input-features.sh` toggle parity** — Cancel/default handling consistent across remaining getters after prompt-helper partial refactor.

**Exit criteria:** All three verification tasks documented (pass/fail + fixtures). No Phase 2+ config splits until `write_config()` gate passes.

---

## Phase 1 — Configure UI errors (highest score: 4.50/5)

**Target:** `lib/configure-ui.sh` (1255 lines → ~750)

- [ ] Create `lib/configure-ui-errors.sh`:
  - Move: `show_config_locked_error`, `show_config_file_locked_error`, `show_cap_violation_error`, `show_partial_lock_violation_error`
  - Add shared helper(s) for restriction/lock-hour message formatting (dedupe repeated parse/format blocks)
- [ ] Update `lib/configure-ui.sh` to source submodule; keep function names exported at facade
- [ ] Move `calculate_restriction_end_time()` to `lib/time-calculations.sh` (4.00/5) — logic is pure calculation, not UI.
- [ ] Run: `tests/test-configure-partial-lock.sh`, `tests/test-configure-blocking.sh`, `tests/test-main-menu-cancel-menu.sh`, `tests/test-window-behavior-cancel-menu.sh`
- [ ] ShellCheck changed files; `./scripts/run-security-scan.sh --ci`

**Exit criteria:** `configure-ui.sh` under 900 lines; no behavior change in lock/cap error dialogs.

---

## Phase 2 — Configure display summary (4.00/5)

**Target:** `lib/configure-display.sh` (1309 lines)

- [ ] Create `lib/configure-display-summary.sh`:
  - Move `show_summary()` and private `_summary_*` section builders (restrictions, lock hours, uninstall lock, pause, service mode, dialog tool)
- [ ] Source from `configure-display.sh`; preserve `show_summary` signature
- [ ] Run: `tests/test-configure-text-mode.sh`, `tests/test-enhancement-03-wizard.sh`, `tests/test-configure-modular.sh`
- [ ] Manual smoke: wizard option 13 (Review and Save) in text mode with bounded `configure.sh` (`timeout` + finite stdin)

**Exit criteria:** `configure-display.sh` under 950 lines; summary text unchanged for fixed test fixture.

---

## Phase 3 — Configure input features split (4.00/5)

**Target:** `lib/configure-input-features.sh` (937 lines)

- [ ] Create submodules (sourced by facade):
  - `lib/configure-input-security.sh` — configure block, config lock, uninstall protection, `get_security_settings_config`
  - `lib/configure-input-pause.sh` — pause enabled, duration, cooldown getters
  - `lib/configure-input-dialog-tool.sh` — `get_dialog_tool_selection`
- [ ] Finish boolean/enum prompt deduplication across remaining getters (Feb plan item 7)
- [ ] Run: `tests/test-configure-gui-split.sh`, pause-related configure tests

**Exit criteria:** Each submodule under 350 lines; facade under 150 lines (source + re-exports only).

---

## Phase 4 — Popup orchestration completion (3.75/5, safety-critical)

**Target:** `lib/popup-display.sh` (769 lines; `show_warning` 519 lines)

Infrastructure already exists: `popup-pid-management.sh`, `popup-dialog-implementations.sh`, `popup-dialog-implementations-darwin.sh`, `popup-display-darwin.sh`, `popup-safety.sh`.

- [ ] Refactor `show_warning()` to orchestrate only:
  - Display env detection, message build (existing `_popup_*` helpers)
  - Delegate spawn/update/respawn to `_popup_run_${dialog_tool}` in implementations module
  - Preserve window-management hooks, min-display respawn, pause exit-code semantics
- [ ] Confirm **every** spawn path still wrapped by `popup-safety.sh` watchdog
- [ ] Run: `tests/test-popup-safety-darwin.sh`, `tests/test-popup-safety-linux.sh`, `tests/test-popup.sh`, `tests/test-pause-feature.sh`, `tests/test-modular-refactor.sh`
- [ ] Linux host: popup integration checklist from [plan-safety-scan-fixes-2026-05-30.md](../plans/plan-safety-scan-fixes-2026-05-30.md) when available

**Exit criteria:** `show_warning()` under 200 lines; yad/zenity/kdialog paths verified.

---

## Phase 5 — Medium priority (as time permits)

| Item | New module / change | Score | Notes |
|------|---------------------|-------|-------|
| `status.sh` `show_configuration()` | `lib/status-config-display.sh` | 3.75 | 398-line hotspot |
| `configure-dialogs.sh` | `lib/configure-dialogs-ranges.sh` for `manage_ranges_dialog` | 3.75 | Supports #16c work |
| `configure-config.sh` | `lib/configure-config-load.sh` for `load_existing_config` | 3.50 | After Phase 0 gate |
| `install.sh` | `lib/install-linux.sh` (mirror `install-darwin.sh`) | 3.50 | Keep `install.sh` as entrypoint |
| Formatting dedupe | Share `format_hour_12h` / range helpers between status and configure | 3.25 | Avoid drift |
| `show_main_menu()` GUI/text split | Shared option metadata array | 3.00 | Do when touching display menu |
| `configure-dialogs-darwin.sh` | Bash/Python split for `_cd_darwin_show_text_dialog` | 3.00 | *Note: macOS GUI perf plan caching changes are complete; sync new refactors with them.* |

**Optional / defer:** `lib/config.sh` parse extraction (3.25) — file is appropriately large as runtime API.

---

## Implementation order

1. Phase 0 (verification gates)
2. Phase 1 (`configure-ui-errors`) — low runtime risk, highest assessment score
3. Phase 2 (`configure-display-summary`) — configure-only
4. Phase 3 (`configure-input-features` split) — configure-only
5. Phase 4 (`show_warning` orchestration) — **last among high priority** (safety-critical)
6. Phase 5 items — pick up when touching related features (#16c → ranges dialog; macOS perf → darwin dialogs)

---

## Test / verification matrix

| Phase | Required tests |
|-------|----------------|
| 0 | `test-atomic-write.sh`, `test-write-config-override-flags.sh` |
| 1 | `test-configure-partial-lock.sh`, `test-configure-blocking.sh`, cancel-menu tests |
| 2 | `test-configure-text-mode.sh`, `test-configure-modular.sh` |
| 3 | `test-configure-gui-split.sh` |
| 4 | `test-popup-safety-*.sh`, `test-popup.sh`, `test-pause-feature.sh`, `test-modular-refactor.sh` |
| All lib changes | `./scripts/run-security-scan.sh --ci` |

Manual (when GUI session available): configure wizard review step; one popup per dialog tool.

---

## Success metrics

- No production `.sh` file above **900 lines** except `install.sh` and `configure-display.sh` (menus may remain ~900 until Phase 5 menu dedupe).
- All Phase 0 verification gates passed and recorded in this plan or assessment appendix.
- [refactor-plan-high-priority-2026-02-05.md](../plans/refactor-plan-high-priority-2026-02-05.md) checkboxes updated as items complete.
- Re-run [refactor assessment template](../templates/refactor-assessment-template.md) after Phase 4 to confirm line counts and close the loop.

---

## Tracking

- **TO_DO:** [dev-docs/TO_DO.md](../TO_DO.md) — Refactor assessment follow-up item
- **Assessment record:** [refactor-assessment-2026-05-31-140925.md](../refactor-assessments/refactor-assessment-2026-05-31-140925.md)

**Last updated:** 2026-05-31
