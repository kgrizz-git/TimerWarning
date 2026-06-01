## Refactoring Plan (High Priority) - 2026-02-05

**Superseded for remaining work by:** [plan-refactor-assessment-2026-05-31.md](plan-refactor-assessment-2026-05-31.md) (May 2026 assessment follow-up). Checkboxes below reflect Feb–May progress; open items are carried forward in the May plan.

### Goals

- Reduce maintenance risk by breaking up the largest “hotspot” functions and removing duplicated logic.
- Preserve **all existing functionality**, including dialog support for **yad**, **zenity**, and **kdialog**.
- Keep public entrypoints and module APIs stable wherever possible (prefer “source submodules internally”).

### Non-Goals (for this phase)

- Changing user-visible behavior/UX (text, button labels, timing semantics).
- Changing on-disk config format.
- Rewriting tests to “fit the refactor”.

### General Approach / Guardrails

- Refactor **incrementally**: extract helpers first, then switch call sites, then delete dead code.
- **NON-NEGOTIABLE: Always support all 3 dialog tools (yad, zenity, kdialog). This will not be changed.**
- Prefer **stable surfaces**:
  - For widely-sourced libs (`config.sh`, `configure-dialogs.sh`), keep the original file as the stable API and source new submodules from it.
  - For entrypoints (`install.sh`, `status.sh`), avoid deep splitting into sourced modules unless we can guarantee those modules are always discoverable.
- Any new `lib/*.sh` files must be included in installation (install copies `lib/*.sh`).
- Maintain support for dialog tools:
  - No tool-specific feature regressions (pause button, sizing/positioning behavior, countdown/min-display behavior).
  - Keep tool-specific exit-code semantics intact (especially zenity vs yad vs kdialog).

### Checklist: High-Priority Work Items

#### 1) `lib/popup-display.sh`: split hotspot + dedupe tool code

- [x] Create `lib/popup-pid-management.sh` and move PID/state functions:
  - `cleanup_stale_pid`, `get_popup_age`, `is_popup_running`, `close_existing_popups`, `save_popup_pid`, `cleanup_popup_pid`
- [x] Create `lib/popup-dialog-implementations.sh` to host tool-specific logic:
  - Spawn popup per tool (zenity/yad/kdialog)
  - Respawn/update countdown per tool
  - Pause-button handling per tool (exit code parsing, outputs)
- [ ] Refactor `show_warning()` to orchestrate:
  - Build message / determine settings once
  - Delegate to tool-specific functions for spawn/update
  - Keep window-management hooks unchanged
- [ ] Verify: yad/zenity/kdialog paths still work, including:
  - min display time enforcement + countdown redraws
  - auto-close behavior
  - pause button behavior (and kdialog’s menu fallback)

#### 2) `lib/config.sh`: extract popup-size logic to submodule (stable API)

- [x] Add `lib/config-popup-size.sh` containing:
  - `get_popup_size`, `get_popup_dimensions`, `get_popup_size_mode`, `get_popup_size_custom`, `get_popup_size_custom_absolute`
- [x] Update `lib/config.sh` to source this submodule internally while preserving function names and behavior.
- [ ] Verify: callers get identical outputs for:
  - predefined sizes
  - custom percentage + custom absolute fallback
  - display-based sizing mode

#### 3) `lib/configure-display.sh`: dedupe popup size display formatting

- [x] Add helper `format_popup_size_display(...)` used by:
  - `show_main_menu()`
  - `show_summary()`
- [x] Verify: menu + summary show identical size formatting for fixed vs display-based and custom sizes.

#### 4) `lib/configure-dialogs.sh`: extract time-selection dialogs to submodule (stable API)

- [x] Create `lib/configure-dialogs-time.sh` containing:
  - `parse_normalized_time_to_12h`
  - `show_time_selection_dialog*` (yad/zenity/kdialog + wrapper)
- [x] Update `lib/configure-dialogs.sh` to source it and remove duplicated in-file definitions.
- [x] Verify: time selection works in all three tools; zenity validation behavior unchanged.

#### 5) `lib/configure-config.sh`: split `write_config()` into helpers (stable signature)

- [x] Extract internal helpers:
  - argument parsing (config_lines / lock_hours / uninstall_lock_hours / override flags)
  - header generation
  - each section writer (restrictions/lock/uninstall)
  - atomic replace
- [x] Keep `write_config()` signature and output identical.
- [ ] Verify: produced config file remains unchanged for representative inputs.

#### 6) `lib/configure-input-popup.sh`: extract popup size input functions to submodule

- [x] Create `lib/configure-input-popup-size.sh` and move:
  - `get_popup_size_config`
  - `get_custom_popup_size_config`
- [x] Update `lib/configure-input-popup.sh` to source it and keep public behavior identical.
- [x] Verify: GUI + text-mode flows, validation, and cancel behavior unchanged.

#### 7) `lib/configure-input-features.sh`: introduce shared prompt helpers

- [x] Add shared helpers for boolean/enum prompts (GUI + text).
- [x] Refactor at least the two most duplicated toggles first:
  - `get_configure_block_enabled_config`
  - `get_config_lock_enabled_config`
- [ ] Verify: cancel/default handling consistent across toggles.

### Backup Checklist (before edits)

- [x] Create timestamped backups in `backups/` for every file that will be modified:
  - `lib/popup-display.sh`
  - `lib/config.sh`
  - `lib/configure-display.sh`
  - `lib/configure-dialogs.sh`
  - `lib/configure-config.sh`
  - `lib/configure-input-popup.sh`
  - `lib/configure-input-features.sh`
  - (and any other file discovered during implementation)

### Implementation Order

1. `lib/configure-display.sh` helper (small + low risk)
2. `lib/configure-config.sh` helper extraction (contained but critical)
3. `lib/configure-dialogs-time.sh` extraction (moderate, stable API)
4. `lib/configure-input-popup-size.sh` extraction (moderate, stable API)
5. `lib/configure-input-features.sh` prompt helpers (moderate)
6. `lib/config-popup-size.sh` extraction (moderate, many callers)
7. `lib/popup-display.sh` split (largest risk; do last after infrastructure is clean)

### Test / Verification Plan (follow-up after implementation)

- Manual smoke checks:
  - run configure wizard in GUI mode with each available tool
  - run status script
  - run main warning popup path (if safe in the environment)
- Existing repo tests (where they don’t touch an installed config file):
  - run targeted tests relevant to modified modules

