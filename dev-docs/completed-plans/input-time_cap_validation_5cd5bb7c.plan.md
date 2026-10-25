---
name: Input-Time Cap Validation
overview: Add immediate per-day 16-hour cap enforcement when users confirm restriction, configure-lock, or uninstall-lock hours in the configure wizard—using the same `check_daily_caps` logic as save time, wired through `get_day_hours` and workflow context globals.
todos:
  - id: backup-cap-input
    content: Backup configure-validation.sh, configure-input-time.sh, configure-workflow.sh to backups/
    status: completed
  - id: helper-check-input-caps
    content: Add check_input_time_daily_caps() to lib/configure-validation.sh
    status: completed
  - id: hook-get-day-hours
    content: Add _validate_input_hours_cap_or_block and call at all get_day_hours accept paths
    status: completed
  - id: workflow-globals
    content: Set CONFIGURE_INPUT_HOURS_KIND and CONFIGURE_INPUT_APPLY_DAY_INDICES in configure-workflow.sh
    status: completed
  - id: tests-tier-a
    content: Add tests/test-input-time-cap-validation.sh and register in tests/tiers.yaml
    status: completed
  - id: docs-changelog-verify
    content: Update CHANGELOG.md and dev-docs/development/invariants.md; run tier-a and shellcheck
    status: completed
isProject: false
---

# Plan: Input-time per-day cap validation

## Problem

Users can enter over-cap ranges (e.g. `1am-11pm` → 22 h) during **Configure Weekdays** with only format validation. The hard block runs at **Review and Save (option 13)** in [`configure.sh`](../../configure.sh) via `check_daily_caps`. That matches safety rules but creates a poor UX gap.

## Design

Centralize input-time checks in **`get_day_hours()`** ([`lib/configure-input-time.sh`](../../lib/configure-input-time.sh)) because every hour-entry path flows through it (restrictions, lock hours, uninstall lock, grid edit, GUI + text, multi-range manage dialog).

Reuse **`check_daily_caps()`** from [`lib/daily-caps.sh`](../../lib/daily-caps.sh) (already sourced by [`lib/configure-validation.sh`](../../lib/configure-validation.sh)) so input-time and save-time share one mechanical invariant—no duplicate cap math.

```mermaid
flowchart TD
  userConfirm[User confirms range(s)] --> normalize[normalize_time_range]
  normalize --> buildProposed[Build proposed session lines]
  buildProposed --> checkCaps[check_daily_caps]
  checkCaps -->|violations| showError[show_cap_violation_error]
  showError --> reprompt[Re-prompt / stay in dialog]
  checkCaps -->|ok| accept[Accept and return ranges]
```

### Session context (globals)

`get_day_hours` needs to know **which category** is being edited and **which day indices** the answer applies to. Avoid changing 20+ call signatures by using two optional globals set by [`lib/configure-workflow.sh`](../../lib/configure-workflow.sh) immediately before each `get_day_hours` call:

| Global | Values | Default |
|--------|--------|---------|
| `CONFIGURE_INPUT_HOURS_KIND` | `restriction` \| `configure_lock` \| `uninstall_lock` | `restriction` |
| `CONFIGURE_INPUT_APPLY_DAY_INDICES` | Comma-separated day indices `0-6` (e.g. `1,2,3,4,5` for all weekdays) | unset → single `day_index` only |

Workflow responsibilities:

- **Weekdays together** → set `CONFIGURE_INPUT_APPLY_DAY_INDICES="1,2,3,4,5"` before `get_day_hours`, clear after.
- **Weekends together** → `"6,0"`.
- **Lock / uninstall lock sections** → set `CONFIGURE_INPUT_HOURS_KIND` to `configure_lock` or `uninstall_lock` for that section’s calls.
- **Per-day / grid edit** → leave apply indices unset (single day).

Reads session state already in scope in [`configure.sh`](../../configure.sh): `config_lines[]`, `lock_hours_lines[]`, `uninstall_lock_hours_lines[]`, `configure_block_enabled`, `uninstall_protection_mode`.

### New helper

Add to [`lib/configure-validation.sh`](../../lib/configure-validation.sh):

```bash
# check_input_time_daily_caps KIND DAY_INDEX PROPOSED_RANGES_CSV
# Uses CONFIGURE_INPUT_APPLY_DAY_INDICES, session arrays, and wizard globals.
# Returns 0 if OK; on violation prints "Day|category|minutes" lines to stdout (same as check_daily_caps).
check_input_time_daily_caps() { ... }
```

Implementation sketch:

1. Resolve affected indices: `${CONFIGURE_INPUT_APPLY_DAY_INDICES:-$day_index}` split into array.
2. Clone session lines into local arrays (copy `config_lines`, `lock_hours_lines`, `uninstall_lock_hours_lines` by index 0–6).
3. For each affected index, write proposed value into the correct array:
   - `restriction` → `DAYVAR=ranges` in config clone
   - `configure_lock` → `CONFIG_LOCK_HOURS_DAYVAR=ranges`
   - `uninstall_lock` → `UNINSTALL_LOCK_HOURS_DAYVAR=ranges`
   - Empty/`skip` → set empty range for that day in that category.
4. Flatten clones to the same `"LINE=..."` args `check_daily_caps` expects.
5. Call `check_daily_caps "${configure_block_enabled}" "${uninstall_protection_mode}" "${lines[@]}"`.
6. Return that result unchanged (caller checks non-empty stdout).

**Important:** `proposed_ranges` must already be **normalized** (`01:00-23:00`), never raw `1am-11pm`—[`daily-caps.sh`](../../lib/daily-caps.sh) silently skips unrecognized formats.

### UI wrapper in `get_day_hours`

Add private helper in [`lib/configure-input-time.sh`](../../lib/configure-input-time.sh):

```bash
_validate_input_hours_cap_or_block() {
  local day_index="$1" proposed="$2" use_gui="$3"
  # reads CONFIGURE_INPUT_HOURS_KIND, calls check_input_time_daily_caps
  # if violations: show_cap_violation_error (reuse existing dialog from configure-ui-errors.sh)
  # return 1 to block acceptance
}
```

Call `_validate_input_hours_cap_or_block` at every **accept** point:

| Path | When to call |
|------|----------------|
| GUI new range | After user confirms single range (`preview_ranges` cumulative), **before** `collected_ranges+=` |
| GUI done / return | Before final `echo` of joined ranges (when exiting multi-range loop) |
| GUI `manage_ranges_dialog` | After dialog returns, before `echo "${managed_ranges}"` |
| Text mode | After normalize + user confirms `[Y/n]`, **before** `return 0` |

On violation: show error, **do not** accept the range; loop back to input (same pattern as invalid format).

Skip cap check when `proposed` is empty / `skip`.

### Files to change

| File | Change |
|------|--------|
| [`lib/configure-validation.sh`](../../lib/configure-validation.sh) | Add `check_input_time_daily_caps()` |
| [`lib/configure-input-time.sh`](../../lib/configure-input-time.sh) | Add `_validate_input_hours_cap_or_block()`; hook all accept paths in `get_day_hours` |
| [`lib/configure-workflow.sh`](../../lib/configure-workflow.sh) | Set/clear `CONFIGURE_INPUT_HOURS_KIND` and `CONFIGURE_INPUT_APPLY_DAY_INDICES` around section `get_day_hours` calls |
| [`CHANGELOG.md`](../../CHANGELOG.md) | `[Unreleased]` entry |
| [`dev-docs/development/invariants.md`](../development/invariants.md) | Note CAP-*-DAY also surfaces at wizard input (not only save) |

No change to [`docs/SAFETY.md`](../../docs/SAFETY.md) required (behavior already documented; this closes an enforcement gap).

### Tests

Add [`tests/test-input-time-cap-validation.sh`](../../tests/test-input-time-cap-validation.sh) (Tier-A):

- Source `configure-core.sh`, `time-parsing.sh`, `configure-validation.sh`.
- Build minimal session arrays; call `check_input_time_daily_caps restriction 1 "01:00-23:00"` with Mon–Fri apply indices → expect violation lines for Monday–Friday.
- Valid case: `MONDAY=7-23` (16 h) → no violations.
- Lock-hours case: with `configure_block_enabled=true`, restriction `8-12` + proposed lock `13-24` → pass; lock that pushes configure_block category over 16 h → fail.
- Register in [`tests/tiers.yaml`](../../tests/tiers.yaml) tier `a`.

Optional integration-style test: stub `_validate_input_hours_cap_or_block` behavior via `check_input_time_daily_caps` only (avoid driving full GUI `get_day_hours`).

### Verification

- `shellcheck -S error` on changed shell files.
- `./scripts/run-tests.sh --tier a`
- `./scripts/run-security-scan.sh --ci` (lib changes)
- Manual smoke (temp `HOME`): Configure Weekdays → same hours → `1am-11pm` → expect immediate cap error before returning to main menu.

### Pre-work

Backup [`lib/configure-validation.sh`](../../lib/configure-validation.sh), [`lib/configure-input-time.sh`](../../lib/configure-input-time.sh), [`lib/configure-workflow.sh`](../../lib/configure-workflow.sh) to `backups/` before edits.

### Out of scope

- Changing cap math or the 16 h limit.
- Save-time check in option 13 (keep as defense in depth).
- [`manage.sh`](../../manage.sh) unless it sources the same `get_day_hours` path (verify during implementation; if separate, follow-up).
