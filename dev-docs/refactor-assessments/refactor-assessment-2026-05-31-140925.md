# Refactor Assessment - 2026-05-31 14:09:25

## Assessment Date
- **Date**: 2026-05-31
- **Time**: 14:09:25
- **Assessor**: AI Agent
- **Baseline comparison**: [refactor-assessment-2026-02-05-121836.md](refactor-assessment-2026-02-05-121836.md), [refactor-plan-high-priority-2026-02-05.md](../completed-plans/refactor-plan-high-priority-2026-02-05.md)

## Assessment Checklist

### Preparation

- [x] Create timestamped copy of this template
- [x] **Remember: Only edit the timestamped assessment file - do not modify any code files**
- [x] Identify all `.sh` files in codebase
- [x] Count lines for each file
- [x] Create list of files exceeding 750 lines

### Analysis

For each file exceeding 750 lines:

- [x] Document file path and line count
- [x] List all functions in the file
- [x] Identify function groupings
- [x] Analyze dependencies (what it uses, what uses it)
- [x] Identify code organization patterns
- [x] Identify refactoring opportunities
- [x] Document proposed refactoring plan
- [x] Evaluate each refactoring suggestion (Ease, Safety, Practicality, Recommendation)
- [x] Calculate overall score for each suggestion
- [x] Prioritize recommendations

### Documentation

- [x] Create summary table of all files analyzed
- [x] Create prioritized list of refactoring recommendations
- [x] Document any files that are appropriately large (with justification)
- [x] Note any patterns or observations about the codebase structure

---

## Progress Since Last Assessment (2026-02-05)

Several high-priority refactorings from the Feb 2026 plan are **complete**:

| Change | Before (Feb) | Now (May) | Notes |
|--------|-------------|-----------|-------|
| `lib/popup-display.sh` | 1474 | 769 | PID mgmt → `popup-pid-management.sh`; tool logic → `popup-dialog-implementations*.sh` |
| `lib/config.sh` | 1198 | 864 | Popup size getters → `config-popup-size.sh` |
| `lib/configure-input-popup.sh` | 895 | 555 | Size input → `configure-input-popup-size.sh` |
| `lib/configure-dialogs.sh` | 1128 | 923 | Time dialogs → `configure-dialogs-time.sh` |
| `lib/configure-config.sh` | 780 | 871 | Helpers extracted inside file; net size grew with new config keys |

**Still open** from the Feb plan: finish `show_warning()` orchestration refactor (519 lines remain); verify representative `write_config()` output unchanged; finish boolean-prompt dedupe in `configure-input-features.sh`.

**Regressions / growth**: `configure-ui.sh` (+281), `install.sh` (+147), `status.sh` (+71), `configure-display.sh` (+28). New large file: `configure-dialogs-darwin.sh` (789).

---

## Files Analyzed

### Summary Table

| File | Location | Line Count | Exceeds Threshold | Status |
|------|----------|------------|-------------------|--------|
| configure-display.sh | lib/ | 1309 | Yes | Analyzed |
| configure-ui.sh | lib/ | 1255 | Yes | Analyzed |
| install.sh | root | 1077 | Yes | Analyzed |
| configure-input-features.sh | lib/ | 937 | Yes | Analyzed |
| configure-dialogs.sh | lib/ | 923 | Yes | Analyzed |
| status.sh | root | 883 | Yes | Analyzed |
| configure-config.sh | lib/ | 871 | Yes | Analyzed |
| config.sh | lib/ | 864 | Yes | Analyzed |
| configure-dialogs-darwin.sh | lib/ | 789 | Yes | Analyzed |
| popup-display.sh | lib/ | 769 | Yes | Analyzed |
| test-immovable-window.sh | tests/ | 870 | Yes | Reference only (test harness) |

**Near threshold (641–749 lines, not analyzed in depth)**: `configure-workflow.sh` (646), `configure.sh` (658), `time-validation.sh` (663), `manage.sh` (664), `test-pause-feature.sh` (741).

---

## Detailed Analysis

### File: lib/configure-display.sh

**Location**: `lib/configure-display.sh`  
**Line Count**: 1309  
**Exceeds Threshold**: Yes

#### Function Inventory
- `get_section_status()` (22–54): Menu status badges for weekday/weekend sections
- `_get_effective_popup_size_mode()` (56–78): Resolve display-based vs fixed size mode
- `format_popup_size_display()` (80–185): Shared size formatting (Feb refactor ✓)
- `_configure_build_grid_cache()` (189–274): Grid cache for visual day/time display
- `show_main_menu()` (300–567): Main configure wizard menu loop (268 lines)
- `show_window_behavior_submenu()` (575–677): Window behavior submenu
- `show_visual_grid()` (679–908): Weekly hours grid viewer (230 lines)
- `show_summary()` (910–1309): Pre-save review summary (400 lines)

#### Function Groupings
- **Menu navigation**: `show_main_menu`, `show_window_behavior_submenu`
- **Display helpers**: `get_section_status`, `format_popup_size_display`, `_get_effective_popup_size_mode`
- **Visual grid**: `_configure_build_grid_cache`, `show_visual_grid`
- **Summary/review**: `show_summary`

#### Dependencies
- **Depends on**: `configure-ui.sh` (cancel menus), `configure-input-*.sh`, `configure-dialogs.sh`, `configure-core.sh`, `configure-time.sh`, globals from `configure.sh` session
- **Depended upon by**: `configure.sh`, `manage.sh` (indirect), tests (`test-configure-text-mode.sh`, `test-darwin-grid-cache.sh`, etc.)

#### Code Organization
- Clear separation of menu vs grid vs summary, but `show_summary()` accumulates every config section into one string builder
- `show_main_menu()` mixes GUI list-dialog and text-mode branches with duplicated option lists

#### Refactoring Opportunities

##### Opportunity 1: Extract `show_summary()` to `lib/configure-display-summary.sh`

**Proposed Structure**:
- New module: `lib/configure-display-summary.sh` — `show_summary()`, section-specific summary builders
- Remaining in original: menu, grid, window-behavior functions
- `configure-display.sh` sources the submodule (stable API: keep `show_summary` callable)

**Migration Strategy**:
1. Extract `show_summary()` and private `_summary_*` helpers
2. Source from `configure-display.sh`
3. Run configure wizard review step tests

**Benefits**: −~400 lines from display module; summary logic isolated for new config keys

**Evaluation**:
- **Ease**: 4/5 — Self-contained string building; few external callers
- **Safety**: 4/5 — Display-only; no config write path
- **Practicality**: 4/5 — Grows with every new setting (pause, lock hours, service mode)
- **Recommendation**: 4/5
- **Overall Score**: 4.00/5

**Priority**: High

##### Opportunity 2: Split GUI vs text branches in `show_main_menu()`

**Proposed Structure**: `_show_main_menu_gui()` / `_show_main_menu_text()` with shared option metadata array

**Evaluation**: Ease 3, Safety 3, Practicality 3, Recommendation 3 → **Overall 3.00/5**

**Priority**: Medium

---

### File: lib/configure-ui.sh

**Location**: `lib/configure-ui.sh`  
**Line Count**: 1255  
**Exceeds Threshold**: Yes

#### Function Inventory (largest first)
- `show_config_locked_error()` (820–1242): **423 lines** — blocked-hours error with restriction/lock hour breakdown
- `calculate_restriction_end_time()` (592–732): 141 lines
- `ask_what_to_edit()` (389–474): Day edit chooser
- `show_help_dialog()`, `show_welcome()`, `show_cap_violation_error()`, cancel/confirm handlers (31–86 lines each)
- `show_config_file_locked_error()` (1250–1255): Thin wrapper at file tail

#### Function Groupings
- **Cancel/confirm UX**: `handle_*_cancel_menu`, `confirm_cancel`, `confirm_skip_day`
- **Wizard flow**: `show_welcome`, `ask_weekday_together`, `ask_weekend_together`, `ask_what_to_edit`, `show_success`
- **Validation errors**: `show_24_7_error`, `show_high_restriction_warning`, `show_cap_violation_error`, `show_partial_lock_violation_error`, `show_config_locked_error`, `show_config_file_locked_error`
- **Time math**: `calculate_restriction_end_time`

#### Dependencies
- **Depends on**: `configure-dialogs.sh`, lazy-loads `configure-core.sh`, `configure-time.sh`, `config.sh`, `time-validation.sh`
- **Depended upon by**: `configure.sh`, `manage.sh`, `uninstall.sh`, `configure-display.sh`, `configure-input-features.sh`, cancel-menu tests

#### Refactoring Opportunities

##### Opportunity 1: Extract lock/restriction error dialogs to `lib/configure-ui-errors.sh`

**Proposed Structure**:
- Move: `show_config_locked_error`, `show_config_file_locked_error`, `show_cap_violation_error`, `show_partial_lock_violation_error`, shared `_configure_ui_format_blocked_hours_message()` helper
- Keep thin re-exports in `configure-ui.sh` for stable sourcing

**Benefits**: −~500 lines; error formatting co-located with safety/cap logic docs

**Evaluation**: Ease 4, Safety 4, Practicality 5, Recommendation 5 → **Overall 4.50/5**

**Priority**: High

##### Opportunity 2: Extract `calculate_restriction_end_time()` to `configure-time.sh` or `time-calculations.sh`

**Evaluation**: Ease 4, Safety 4, Practicality 4, Recommendation 4 → **Overall 4.00/5**

**Priority**: High

---

### File: install.sh

**Location**: `install.sh`  
**Line Count**: 1077  
**Exceeds Threshold**: Yes

#### Function Inventory (largest first)
- `main_linux()` (946–1064): 119 lines
- `migrate_config_to_subdirectory()` (394–505): 112 lines
- `install_files()` (677–780): 104 lines
- `install_dependencies()`, `show_disclaimer()`, `check_existing_installation()`, `ensure_path_setup()`, `prompt_reenable_if_disabled()` (34–57 lines each)
- Platform dispatch: `main()` → `main_linux()` or sources `install-darwin.sh`

#### Dependencies
- **Depends on**: `_bootstrap-bash4.sh`, `display-detection.sh`, `service-config.sh`, `time-parsing.sh`, `config.sh`, `install-darwin.sh`
- **Depended upon by**: Users, docs, CI install tests

#### Refactoring Opportunities

##### Opportunity 1: Extract Linux install body to `lib/install-linux.sh` (mirror `install-darwin.sh`)

**Proposed Structure**:
- Move: `main_linux`, `install_files`, `migrate_config_to_subdirectory`, `generate_timer_file`, `reload_systemd`, timer helpers
- Keep `install.sh` as thin entrypoint with disclaimer + platform dispatch

**Evaluation**: Ease 3, Safety 3, Practicality 4, Recommendation 4 → **Overall 3.50/5**

**Priority**: Medium

**Risk note**: Entrypoint splitting increases “run from wrong directory” failure modes unless `library-loader.sh` patterns are reused.

---

### File: lib/configure-input-features.sh

**Location**: `lib/configure-input-features.sh`  
**Line Count**: 937  
**Exceeds Threshold**: Yes

#### Function Inventory
- `get_dialog_tool_selection()` (740–936): 197 lines
- `get_security_settings_config()` (146–293): 148 lines (combined configure-block + file lock)
- `get_uninstall_protection_mode_config()` (623–738): 116 lines
- Pause getters (357–621): ~263 lines combined
- Shared helpers: `_get_existing_bool_setting_from_config`, `_prompt_bool_setting_gui_strict` (Feb partial ✓)

#### Refactoring Opportunities

##### Opportunity 1: Split by feature domain

**Proposed Structure**:
- `lib/configure-input-security.sh` — configure block, config lock, uninstall protection
- `lib/configure-input-pause.sh` — pause enabled/duration/cooldown
- `lib/configure-input-dialog-tool.sh` — dialog tool selection
- `configure-input-features.sh` sources all three (stable API)

**Evaluation**: Ease 4, Safety 4, Practicality 4, Recommendation 4 → **Overall 4.00/5**

**Priority**: Medium

##### Opportunity 2: Finish boolean/enum prompt deduplication (Feb plan item 7)

**Evaluation**: Ease 4, Safety 4, Practicality 4, Recommendation 4 → **Overall 4.00/5**

**Priority**: Medium

---

### File: lib/configure-dialogs.sh

**Location**: `lib/configure-dialogs.sh`  
**Line Count**: 923  
**Exceeds Threshold**: Yes

#### Function Inventory
- `show_multi_column_list_dialog()` (433–675): 243 lines
- `manage_ranges_dialog()` (682–923): 242 lines
- `show_entry_dialog()` (189–288): 100 lines
- Smaller: list, question, info, error, text dialogs

#### Dependencies
- **Depends on**: `desktop-environment.sh`, `unicode-dialog-safety.sh`; on macOS, overrides from `configure-dialogs-darwin.sh`
- **Depended upon by**: Entire configure wizard, `uninstall-verification.sh`, many tests

#### Refactoring Opportunities

##### Opportunity 1: Extract range management to `lib/configure-dialogs-ranges.sh`

**Proposed Structure**: Move `manage_ranges_dialog()` + helpers; source from `configure-dialogs.sh`

**Evaluation**: Ease 4, Safety 3, Practicality 4, Recommendation 4 → **Overall 3.75/5**

**Priority**: Medium

##### Opportunity 2: Extract multi-column list to `lib/configure-dialogs-multicolumn.sh`

**Evaluation**: Ease 3, Safety 3, Practicality 3, Recommendation 3 → **Overall 3.00/5**

**Priority**: Low–Medium

---

### File: status.sh

**Location**: `status.sh`  
**Line Count**: 883  
**Exceeds Threshold**: Yes

#### Function Inventory
- `show_configuration()` (422–819): **398 lines** — parses and displays full config
- `check_service_status()` (313–419): 107 lines
- Formatting helpers: `format_hour_12h`, `format_range_human`, `format_ranges_human`
- `check_installation()`, `show_tips()`, `main()`

#### Dependencies
- **Depends on**: `config.sh` (optional source), platform/service checks; **does not** depend on `popup-display.sh`
- **Depended upon by**: Users, docs

#### Refactoring Opportunities

##### Opportunity 1: Extract `show_configuration()` sections to `lib/status-config-display.sh`

**Proposed Structure**: Section renderers per config category; `status.sh` orchestrates

**Evaluation**: Ease 3, Safety 4, Practicality 4, Recommendation 4 → **Overall 3.75/5**

**Priority**: Medium

##### Opportunity 2: Share formatting with `configure-core.sh` / `configure-time.sh`

**Note**: Duplicated `format_hour_12h` / range formatting exists in status vs configure modules.

**Evaluation**: Ease 3, Safety 3, Practicality 4, Recommendation 3 → **Overall 3.25/5**

**Priority**: Medium

---

### File: lib/configure-config.sh

**Location**: `lib/configure-config.sh`  
**Line Count**: 871  
**Exceeds Threshold**: Yes

#### Function Inventory
- `load_existing_config()` (23–312): **290 lines**
- `write_config()` (630–871): 242 lines
- `_write_config_header()` (395–537): 143 lines
- Section writers + `update_timer_file()`

#### Refactoring Opportunities

##### Opportunity 1: Extract `load_existing_config()` to `lib/configure-config-load.sh`

**Evaluation**: Ease 3, Safety 3, Practicality 4, Recommendation 4 → **Overall 3.50/5**

**Priority**: Medium

##### Opportunity 2: Verify + freeze `write_config()` output (Feb plan verification)

**Evaluation**: Ease 5, Safety 5, Practicality 5, Recommendation 5 → **Overall 5.00/5** (testing/doc, not split)

**Priority**: High (verification before further splits)

---

### File: lib/config.sh

**Location**: `lib/config.sh`  
**Line Count**: 864  
**Exceeds Threshold**: Yes (marginally)

#### Function Inventory
- 25 functions; largest: `parse_uninstall_lock_hours` (89), `parse_lock_hours` (68), `parse_config` (55)
- Many small getters (pause, popup, lock flags)
- Already sources `config-popup-size.sh` internally ✓

#### Refactoring Opportunities

##### Opportunity 1: Extract parse_* functions to `lib/config-parse.sh`

**Proposed Structure**: Stable API via `config.sh` sourcing submodule

**Evaluation**: Ease 4, Safety 3, Practicality 3, Recommendation 3 → **Overall 3.25/5**

**Priority**: Low–Medium

##### Justification for current size
File is **appropriately large** as the runtime config API surface. Further splitting is optional; prefer internal submodules over churning callers.

---

### File: lib/configure-dialogs-darwin.sh

**Location**: `lib/configure-dialogs-darwin.sh`  
**Line Count**: 789  
**Exceeds Threshold**: Yes

#### Function Inventory
- `_cd_darwin_show_text_dialog()` (313–789): **477 lines** (tkinter daemon protocol + fallbacks)
- Daemon helpers: `_cd_darwin_daemon_start/stop/request` (~62 lines)
- JSON builders, AppleScript helpers, arg parsers (24 functions total, guard-wrapped)

#### Dependencies
- **Depends on**: Python tkinter scripts in `lib/configure-dialogs-darwin-*.py`, osascript
- **Depended upon by**: `configure.sh` (optional), overrides Linux dialog functions on macOS

#### Refactoring Opportunities

##### Opportunity 1: Move `_cd_darwin_show_text_dialog` body to Python daemon module

**Proposed Structure**: Bash retains thin RPC; complex UI in `configure-dialogs-darwin-daemon.py`

**Evaluation**: Ease 2, Safety 3, Practicality 4, Recommendation 3 → **Overall 3.00/5**

**Priority**: Medium (macOS maintainability)

##### Opportunity 2: Split daemon vs AppleScript into `configure-dialogs-darwin-daemon.sh` + `configure-dialogs-darwin-osascript.sh`

**Evaluation**: Ease 3, Safety 3, Practicality 3, Recommendation 3 → **Overall 3.00/5**

**Priority**: Low–Medium

---

### File: lib/popup-display.sh

**Location**: `lib/popup-display.sh`  
**Line Count**: 769  
**Exceeds Threshold**: Yes (barely)

#### Function Inventory
- `show_warning()` (251–769): **519 lines** (down from ~1010 in Feb assessment)
- Helpers: locale, close process, auto-close, message builders
- PID management **already extracted** to `popup-pid-management.sh` ✓
- Tool implementations in `popup-dialog-implementations.sh` / `popup-dialog-implementations-darwin.sh` ✓
- macOS path delegates to `show_warning_darwin` via `popup-display-darwin.sh` ✓

#### Refactoring Opportunities

##### Opportunity 1: Complete `show_warning()` orchestration refactor (Feb plan item 1, partial)

**Proposed Structure**: `show_warning()` only: env detection, message build, delegate to `_popup_run_${dialog_tool}` in implementations module

**Evaluation**: Ease 3, Safety 2, Practicality 5, Recommendation 5 → **Overall 3.75/5**

**Priority**: High

**Safety note**: Must preserve yad/zenity/kdialog parity, pause button semantics, min-display respawn, and `popup-safety.sh` watchdog wrapping on every spawn path.

---

## Prioritized Recommendations

### High Priority (Overall Score ≥ 4.0)

1. **Extract lock/restriction error dialogs from `configure-ui.sh`** — Score: **4.50/5**
   - File: `lib/configure-ui.sh`
   - Justification: Single function (`show_config_locked_error`) is 423 lines; file grew +281 since Feb; high duplication with cap/partial-lock errors

2. **Verify `write_config()` output before further config splits** — Score: **5.00/5** (verification task)
   - File: `lib/configure-config.sh`
   - Justification: Safety-critical path; Feb plan verification still open

3. **Extract `show_summary()` from `configure-display.sh`** — Score: **4.00/5**
   - File: `lib/configure-display.sh`
   - Justification: 400-line function; grows with each new config section

4. **Move `calculate_restriction_end_time()` to time module** — Score: **4.00/5**
   - File: `lib/configure-ui.sh` → `configure-time.sh` / `time-calculations.sh`

5. **Split `configure-input-features.sh` by domain** — Score: **4.00/5**
   - File: `lib/configure-input-features.sh`

6. **Complete `show_warning()` orchestration slim-down** — Score: **3.75/5** (rounded up for safety impact)
   - File: `lib/popup-display.sh`
   - Justification: Largest remaining runtime hotspot; infrastructure for split already exists

### Medium Priority (Overall Score 3.0–3.9)

1. **Extract Linux install to `lib/install-linux.sh`** — Score: 3.50/5 (`install.sh`)
2. **Extract `load_existing_config()`** — Score: 3.50/5 (`configure-config.sh`)
3. **Extract `show_configuration()` from `status.sh`** — Score: 3.75/5
4. **Extract `manage_ranges_dialog()`** — Score: 3.75/5 (`configure-dialogs.sh`)
5. **Dedupe status/configure formatting helpers** — Score: 3.25/5
6. **Split GUI/text in `show_main_menu()`** — Score: 3.00/5
7. **macOS dialog daemon bash/Python split** — Score: 3.00/5

### Low Priority (Overall Score < 3.0)

- None strongly recommended against; lowest scores are 3.00 (consider when touching nearby code)

---

## Files Appropriately Large

- **`lib/config.sh` (864 lines)**: Central runtime config API; already uses `config-popup-size.sh` submodule. Marginal over threshold; splitting parse helpers is optional.
- **`lib/popup-display.sh` (769 lines)**: Down 48% from Feb; further reduction depends on completing orchestration refactor, not reverting extractions.
- **`tests/test-immovable-window.sh` (870 lines)**: Integration test harness; size acceptable for test coverage of window behavior matrix.

---

## Observations and Patterns

1. **Modular configure wizard is working**: `configure.sh` sources 15+ lib modules in dependency order via `library-loader.sh`. New splits should follow “stable facade sources submodule” pattern from Feb plan.

2. **Hotspot pattern = monolithic string builders**: `show_summary`, `show_configuration`, `show_config_locked_error`, and formerly `show_warning` all embed large formatted output blocks. Extract section builders, not just line count.

3. **Platform split precedent**: `install-darwin.sh`, `popup-display-darwin.sh`, `configure-dialogs-darwin.sh`, `service-config-{linux,darwin}.sh` — use same pattern for `install-linux.sh` if pursued.

4. **Safety-sensitive paths**: Popup spawn (`popup-safety.sh` watchdog), config write (`write_config` atomic replace), cap validation (`configure-validation.sh`, `daily-caps.sh`) — refactor with targeted tests; never weaken invariants in [docs/SAFETY.md](../../docs/SAFETY.md).

5. **File size trend**: Core runtime modules improved (`popup-display`, `config`); configure UI/error modules grew with pause, lock hours, partial lock, and HH:MM resolution features.

6. **Python already used for macOS configure UI**: Prefer extending Python for new macOS dialog complexity rather than growing bash further in `configure-dialogs-darwin.sh`.

---

## Next Steps

- [x] Review prioritized recommendations with user
- [x] Implementation plan created → [plan-refactor-assessment-2026-05-31.md](../completed-plans/plan-refactor-assessment-2026-05-31.md) (superseded by [plan-refactor-assessment-2026-06-12.md](../completed-plans/plan-refactor-assessment-2026-06-12.md))
- [x] TO_DO item added → [dev-docs/TO_DO.md](../TO_DO.md) (Refactoring / maintainability)
- [ ] Run `write_config()` representative output verification (Phase 0 in plan)
- [ ] Implement per plan: Phase 1 `configure-ui-errors` → Phase 2 `configure-display-summary` → Phase 3 input-features split → Phase 4 `show_warning` orchestration
- [ ] After each extraction: targeted tests per [docs/development/testing.md](../development/testing.md); `./scripts/run-security-scan.sh --ci` for lib changes
- [ ] Update [refactor-plan-high-priority-2026-02-05.md](../completed-plans/refactor-plan-high-priority-2026-02-05.md) checkboxes when items complete
- [ ] Re-run assessment after Phase 4 completes

---

## Template Version Reference

- **Template**: [refactor-assessment-template.md](../templates/refactor-assessment-template.md) v1.0
- **Assessment file**: `dev-docs/refactor-assessments/refactor-assessment-2026-05-31-140925.md`
