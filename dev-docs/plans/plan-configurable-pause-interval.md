# Plan: Configurable Pause Cooldown and Duration

Implements [TO_DO.md](../TO_DO.md) item **Configurable pause cooldown and duration**. Workspace copy with implementation todos: [`.cursor/plans/configurable_pause_cooldown_dfc6b7bb.plan.md`](../../.cursor/plans/configurable_pause_cooldown_dfc6b7bb.plan.md) — keep both files in sync.

**Related:** [enhancement-21-one-time-pause-feature.md](../enhancements/enhancement-21-one-time-pause-feature.md), [enhancement-21-pause-scope-clarification.md](../enhancements/enhancement-21/enhancement-21-pause-scope-clarification.md), [docs/SAFETY.md](../../docs/SAFETY.md)

---

## Problem

Enhancement #21 shipped pause as a popup-only quiet period, but cooldown is **not configurable**:

| Layer | Today |
|-------|-------|
| Runtime | [`can_pause_today()`](../../lib/pause-state.sh) compares `LAST_PAUSE_DATE` to today's calendar date |
| Config | No cooldown key; [`write_config`](../../lib/configure-config.sh) comments say "once per day (not configurable)" |
| Wizard | [`get_pause_once_per_day_config()`](../../lib/configure-input-features.sh) exists but is **dead code** (not wired) |
| Duration | Enum-locked to **5 or 10** min in `activate_pause()`, wizard, and config load |

Users cannot choose pause off, a shorter/longer gap between pauses, or shorter pause lengths.

---

## Target behavior (confirmed)

### Cooldown (`PAUSE_COOLDOWN_HOURS`)

When `PAUSE_ENABLED=true`, minimum time **between pause activations**:

| Value | Meaning |
|-------|---------|
| `6` | Next pause allowed 6 hours after last activation |
| `8` | Next pause allowed 8 hours after last activation |
| `12` | Next pause allowed 12 hours after last activation |
| `24` | Next pause allowed 24 hours after last activation (default; closest to legacy once-per-day) |

When `PAUSE_ENABLED=false`: no pause button anywhere.

**Not in scope:** cooldown `0` (unlimited), sub-hour cooldowns, separate per-day cap beyond cooldown.

### Duration (`PAUSE_DURATION`)

Expand allowlist to **1, 2, 3, 5, 10, 15** minutes (default **5**).

### Scope unchanged

Pause still **only suppresses warning popups** — not configure-block, uninstall protection, or restriction-hour math ([pause scope doc](../enhancements/enhancement-21/enhancement-21-pause-scope-clarification.md)).

```mermaid
flowchart TD
  popup[Warning popup shown] --> canPause{can_pause_now?}
  canPause -->|PAUSE_ENABLED false| noBtn[Hide pause button]
  canPause -->|is_pause_active| noBtn
  canPause -->|cooldown not elapsed| noBtn
  canPause -->|yes| showBtn["Show Pause N min button"]
  showBtn --> click[User clicks pause]
  click --> activate[activate_pause duration]
  activate --> state["Write .pause_state timestamps"]
  state --> suppress[sleep-warning skips show_warning until PAUSE_END_TIMESTAMP]
```

---

## Configuration schema

### New / updated keys in `sleep-warning.conf`

```bash
PAUSE_ENABLED=true|false              # default: true
PAUSE_COOLDOWN_HOURS=6|8|12|24        # default: 24 (new)
PAUSE_DURATION=1|2|3|5|10|15          # default: 5 (expanded allowlist)
```

### Shared validation helpers (single source of truth)

Add to [`lib/pause-state.sh`](../../lib/pause-state.sh) or [`lib/config.sh`](../../lib/config.sh):

- `pause_is_valid_cooldown_hours N` — allowlist `{6,8,12,24}`
- `pause_is_valid_duration_minutes N` — allowlist `{1,2,3,5,10,15}`

Getters:

- `get_pause_cooldown_hours()` — invalid/missing → `24`
- Update `get_pause_duration()` — use shared duration allowlist; invalid → `5`

Legacy: `get_check_interval()` delegation is unrelated; leave as-is.

---

## State file changes

**Path:** `~/.config/sleep-warning/.pause_state` (unchanged)

```bash
PAUSE_END_TIMESTAMP=<unix_epoch>      # active pause expiry (unchanged)
LAST_PAUSE_TIMESTAMP=<unix_epoch>     # NEW — when user last clicked pause
LAST_PAUSE_DATE=YYYY-MM-DD            # kept for migration / display
```

### `activate_pause()` writes

On success, atomically write all three fields; set mode `0600`.

### `check_and_clear_expired_pause()` retention

When `PAUSE_END_TIMESTAMP` expires, clear only that field but **retain** `LAST_PAUSE_TIMESTAMP` and `LAST_PAUSE_DATE` (mirror current `LAST_PAUSE_DATE` retention logic at lines 224–247 of [`lib/pause-state.sh`](../../lib/pause-state.sh)).

**All state-file rewrite paths** must preserve `LAST_PAUSE_TIMESTAMP` whenever `LAST_PAUSE_DATE` is kept — not only the expiry path:

| Path in `check_and_clear_expired_pause()` | Today | Required after change |
|-------------------------------------------|-------|------------------------|
| Invalid `PAUSE_END_TIMESTAMP` | Keeps `LAST_PAUSE_DATE` only | Keep **both** `LAST_PAUSE_DATE` and `LAST_PAUSE_TIMESTAMP` |
| Expired pause | Keeps `LAST_PAUSE_DATE` only | Keep **both** timestamps/date |
| Invalid/missing `LAST_PAUSE_DATE` | Removes entire file | Unchanged |

Add helper `_pause_state_write_retained_fields()` (or equivalent) to avoid drift between rewrite paths.

### Migration (upgrade path)

| Existing state | Behavior |
|----------------|----------|
| No `PAUSE_COOLDOWN_HOURS` in config | Default **24** h |
| Only `LAST_PAUSE_DATE` (no `LAST_PAUSE_TIMESTAMP`) | If date is **today**: treat last activation as **00:00 local** that day (conservative — user waits longer). If prior day: no cooldown block |
| Invalid manual cooldown (e.g. `7`) | Fall back to **24**, log warning |
| Invalid manual duration | Fall back to **5**, log warning |

---

## Core runtime logic ([`lib/pause-state.sh`](../../lib/pause-state.sh))

### New: `get_last_pause_timestamp()`

Read/validate numeric `LAST_PAUSE_TIMESTAMP` from state file.

### New: `can_pause_now()` (primary API)

Return **0** (may pause) only when ALL true:

1. `get_pause_enabled` → `true`
2. `is_pause_active` → false
3. `now - get_last_pause_timestamp >= get_pause_cooldown_hours * 3600` (or no prior timestamp)

Return **1** otherwise.

### New: `get_next_pause_available_timestamp()` (recommended)

Returns Unix epoch when cooldown ends, or empty if pause available now. Used by `status.sh` / `manage.sh`.

### Replace `can_pause_today()`

Implement as thin wrapper calling `can_pause_now()` (keep name for backward compatibility; update docstring — no longer calendar-day logic).

### Update `activate_pause()` — defense in depth

UI gating via `can_pause_now()` is necessary but not sufficient. **`activate_pause()` must re-check before writing state** (protects double-clicks, kdialog late paths, manual invocation):

1. Reject (return 1, log) if `get_pause_enabled` is not `true`
2. Reject if `is_pause_active` (already in a pause window)
3. Reject if cooldown not elapsed (same math as `can_pause_now()` — use shared helper e.g. `_pause_cooldown_elapsed`)
4. Validate duration via `pause_is_valid_duration_minutes`
5. On success: write `LAST_PAUSE_TIMESTAMP=$(date +%s)`, `PAUSE_END_TIMESTAMP`, `LAST_PAUSE_DATE`; mode `0600`
6. Log duration, cooldown hours, and expiry time

---

## Config load / write ([`lib/configure-config.sh`](../../lib/configure-config.sh))

### `load_existing_config`

- Add global `pause_cooldown_hours` default `24`
- Read `PAUSE_COOLDOWN_HOURS` with allowlist validation
- Expand `pause_duration` load to full allowlist `{1,2,3,5,10,15}`

### `write_config` signature change

Insert **`pause_cooldown_hours` as `$11`**; shift subsequent positional args by one:

| Old | New |
|-----|-----|
| `$11` dialog_tool | `$12` dialog_tool |
| `$12` config_lock_enabled | `$13` |
| ... | ... |
| `shift 15` | `shift 16` |

**Backward compatibility in `write_config()`:**

```bash
local pause_cooldown_hours="${11:-24}"   # new; default 24 if omitted
local dialog_tool="${12:-auto}"          # was $11
# ... shift 16 ...
```

**Mechanical audit — insert `"24"` (or test value) after `pause_duration` in every caller:**

- [`configure.sh`](../../configure.sh) — `declare -g pause_cooldown_hours`, menu case `10)` sub-flow, `write_config` call
- [`tests/test-atomic-write.sh`](../../tests/test-atomic-write.sh)
- [`tests/test-write-config-override-flags.sh`](../../tests/test-write-config-override-flags.sh)
- [`tests/test-enhancement-03-wizard.sh`](../../tests/test-enhancement-03-wizard.sh)
- [`tests/test-enhancement-03-integration.sh`](../../tests/test-enhancement-03-integration.sh)
- [`tests/test-auto-close-popup.sh`](../../tests/test-auto-close-popup.sh) (if it invokes `write_config` with full positional args)

**Partial-lock test fixture:** add `pause_cooldown_hours=24` to globals in [`tests/test-configure-partial-lock.sh`](../../tests/test-configure-partial-lock.sh).

**Install defaults:** `install.sh` does not write pause keys today; **`get_pause_cooldown_hours()` default 24** is sufficient until first configure save — no install.sh change required unless we want keys visible in a fresh conf template.

### `_write_config_header` comments

Replace "once per day" prose with cooldown explanation; document `PAUSE_COOLDOWN_HOURS` and expanded `PAUSE_DURATION` values.

---

## Configure wizard

### Menu item 10 sub-flow ([`configure.sh`](../../configure.sh) case `10)`)

1. `get_pause_enabled_config` (existing; update copy — remove "5 or 10 only" / "once per day")
2. If enabled → **new** `get_pause_cooldown_hours_config(use_gui)` — list `6`, `8`, `12`, `24` with brief descriptions
3. If enabled → `get_pause_duration_config` — list `1`, `2`, `3`, `5`, `10`, `15`

Skip cooldown/duration prompts when user disables pause (still save `PAUSE_ENABLED=false`; cooldown/duration can remain in file — prefer **keep last values** for re-enable).

### New function: `get_pause_cooldown_hours_config`

In [`lib/configure-input-features.sh`](../../lib/configure-input-features.sh):

- GUI: `show_list_dialog` with four options
- Text: numbered menu
- Partial-lock guard via `configure_partial_lock_reject_scalar_change "pause_cooldown_hours" ...`

### Update existing pause prompts

- [`get_pause_enabled_config`](../../lib/configure-input-features.sh) — text mentions configurable cooldown + duration
- [`get_pause_duration_config`](../../lib/configure-input-features.sh) — six duration options; partial-lock guard unchanged pattern

### Delete dead code

Remove **`get_pause_once_per_day_config()`** entirely (lines ~543–619) — avoids competing cooldown UI. Grep confirms it is not called from [`configure.sh`](../../configure.sh).

### Menu status ([`lib/configure-display.sh`](../../lib/configure-display.sh))

**Signature ripple** — `show_main_menu()` gains a `pause_cooldown_hours` parameter (after `pause_duration`, before `dialog_tool_status`):

- Update [`show_main_menu()`](../../lib/configure-display.sh) — both GUI and text branches for menu item 10
- Update sole caller: [`configure.sh`](../../configure.sh) line ~301 — pass `"${pause_cooldown_hours}"`
- Status example: `[Enabled, 5 min, cooldown 12 h]` vs `[Disabled]`
- macOS configure uses same `show_list_dialog` / daemon path — no separate cooldown UI needed

---

## Partial configure lock ([`lib/configure-partial-lock.sh`](../../lib/configure-partial-lock.sh))

Per [docs/SAFETY.md](../../docs/SAFETY.md): shorter cooldown = **more permissive** (more pauses).

| Change during lock hours | Allowed? |
|--------------------------|----------|
| `PAUSE_ENABLED` false → true | No (existing) |
| `PAUSE_DURATION` increase (5 → 15) | No (existing) |
| `PAUSE_COOLDOWN_HOURS` decrease (24 → 6) | **No** (new) |
| Disable pause, shorten duration, **increase** cooldown (6 → 24) | Yes (tighten) |

Implementation:

- `_baseline_pause_cooldown_hours` in `configure_partial_lock_capture_baseline`
- `configure_partial_lock_validate_scalar` case `PAUSE_COOLDOWN_HOURS|pause_cooldown_hours`: reject if `new_val < old_val`
- **`configure_partial_lock_reject_scalar_change`** — add field-specific message in the `case "${field}"` block (lines ~364–369):
  - `pause_cooldown_hours|PAUSE_COOLDOWN_HOURS` → `"Cannot shorten pause cooldown during lock hours."`
- `configure_partial_lock_validate_proposed` — add validation error string if cooldown loosening attempted on save

---

## Popup and entrypoints

Replace `can_pause_today` calls with `can_pause_now` (or keep wrapper — behavior must use timestamp cooldown):

| File | Change |
|------|--------|
| [`lib/popup-display.sh`](../../lib/popup-display.sh) | Pause button availability |
| [`lib/popup-display-darwin.sh`](../../lib/popup-display-darwin.sh) | Same |
| [`lib/popup-dialog-implementations.sh`](../../lib/popup-dialog-implementations.sh) | kdialog path line ~288 |
| [`manage.sh`](../../manage.sh) `view_pause_status` | Distinct states (see below); remove "Once Per Day: Always Enabled" |
| [`status.sh`](../../status.sh) | Same distinct states; use getters not raw `grep` |

**Status UX — three distinct states** (replace "Pause Available Today: Yes/No"):

| State | Display |
|-------|---------|
| Pause **active** | `Active until HH:MM` (from `PAUSE_END_TIMESTAMP`) |
| Pause **inactive**, cooldown **blocking** | `Next pause available at HH:MM` (from `get_next_pause_available_timestamp()`) |
| Pause **available** | `Pause available now` |

Always show configured **cooldown hours** and **duration**. Use `get_pause_cooldown_hours()` / `get_pause_duration()` instead of raw `grep` where feasible.

[`sleep-warning.sh`](../../sleep-warning.sh) — no change: already skips popup when `is_pause_active`; cooldown gating is only for showing the pause **button**, not for restriction checks.

---

## Safety assessment

| Invariant | Impact |
|-----------|--------|
| Per-day 16 h cap | None — pause does not alter restriction/configure/uninstall hour sets |
| Popups must always end | None — pause suppresses spawn frequency; watchdog unchanged |
| Escape hatch | None — `launchctl bootout` / `systemctl --user stop` / uninstall path unchanged |
| Partial lock tighten-only | New cooldown rule as above |

Tamper note: user can delete `.pause_state` — existing acceptable behavior for self-control tooling.

**Clock skew (known limitation):** system clock moved backward could allow an early pause; forward could extend cooldown. Acceptable for self-control tooling — document in enhancement-21 docs, no special NTP handling.

**Uninstall:** [`uninstall.sh`](../../uninstall.sh) already removes `.pause_state` — no change required.

---

## Tests

### Required test matrix

| # | Case | Expected |
|---|------|----------|
| 1 | No prior pause | `can_pause_now` → true (when enabled) |
| 2 | Just activated | `can_pause_now` → false; `is_pause_active` → true |
| 3 | Pause **expired**, cooldown **not** elapsed | `can_pause_now` → false; `is_pause_active` → false |
| 4 | Cooldown elapsed, no active pause | `can_pause_now` → true |
| 5 | Each cooldown value 6, 8, 12, 24 | Blocks until `LAST_PAUSE_TIMESTAMP + N*3600` |
| 6 | `activate_pause` when cooldown blocking | Returns 1; state unchanged |
| 7 | `activate_pause` when already active | Returns 1 |
| 8 | `LAST_PAUSE_TIMESTAMP` written on activation | Grep state file |
| 9 | `check_and_clear_expired_pause` after expiry | Removes `PAUSE_END_TIMESTAMP`; keeps `LAST_PAUSE_TIMESTAMP` + `LAST_PAUSE_DATE` |
| 10 | Invalid timestamp recovery path | Keeps `LAST_PAUSE_TIMESTAMP` + `LAST_PAUSE_DATE` |
| 11 | Migration: `LAST_PAUSE_DATE`-only (today) | Conservative cooldown from midnight |
| 12 | Migration: `LAST_PAUSE_DATE`-only (prior day) | No cooldown block |
| 13 | Duration 1, 3, 15 min | Activation + end timestamp math |
| 14 | Invalid duration / cooldown in config | Fallback to 5 / 24 |
| 15 | `PAUSE_ENABLED=false` | No pause available |
| 16 | Partial lock: 24 → 6 cooldown | Rejected |
| 17 | Partial lock: 6 → 24 cooldown | Allowed |
| 18 | Duration 1 min with short min-display | Sanity — pause still activates (independent of popup watchdog) |

Implement in [`tests/test-pause-feature.sh`](../../tests/test-pause-feature.sh) (cases 1–15, 18) and [`tests/test-configure-partial-lock.sh`](../../tests/test-configure-partial-lock.sh) or [`tests/test-configure-blocking.sh`](../../tests/test-configure-blocking.sh) (cases 16–17).

Rename/extend section "Test 5" from calendar-day semantics to cooldown semantics.

Use temp `HOME` / `TEST_CONFIG_DIR`; do not touch installed config during restricted hours.

### Regression

```bash
bash tests/test-pause-feature.sh
bash tests/test-configure-partial-lock.sh
bash tests/test-popup-safety-darwin.sh
bash tests/test-platform-darwin.sh
```

---

## Documentation and release

- Keep this file in sync with [`.cursor/plans/configurable_pause_cooldown_dfc6b7bb.plan.md`](../../.cursor/plans/configurable_pause_cooldown_dfc6b7bb.plan.md)
- Update [TO_DO.md](../TO_DO.md) line 27 — `N = 6, 8, 12, 24` (currently says `6, 12, 24`)
- Update [enhancement-21-one-time-pause-feature.md](../enhancements/enhancement-21-one-time-pause-feature.md) — remove "always once per day"
- [CHANGELOG.md](../../CHANGELOG.md) — Unreleased **Added** (configurable cooldown + duration options)
- User docs ([user-docs/CONFIGURATION.md](../../user-docs/CONFIGURATION.md), [user-docs/MACOS.md](../../user-docs/MACOS.md)) if pause section exists

---

## Implementation order

1. **Validation helpers + getters** — `lib/config.sh`, constants
2. **Pause state core** — `lib/pause-state.sh` (`can_pause_now`, timestamps, migration, defense-in-depth `activate_pause`, all retention paths)
3. **Config I/O** — `lib/configure-config.sh` load/write + signature shift + caller audit
4. **Wizard** — `configure-input-features.sh`, `configure-display.sh`, `configure.sh`; delete dead once-per-day UI
5. **Partial lock** — `lib/configure-partial-lock.sh`
6. **Status/popup wiring** — popup-display*, manage.sh, status.sh, popup-dialog-implementations.sh
7. **Tests + docs + CHANGELOG**

---

## Acceptance criteria

- User can disable pause (`PAUSE_ENABLED=false`)
- User can set cooldown to **6, 8, 12, or 24** hours when pause enabled
- User can set duration to **1, 2, 3, 5, 10, or 15** minutes
- Pause button hidden when cooldown not elapsed or pause active
- Upgraded configs without `PAUSE_COOLDOWN_HOURS` behave as ~24 h cooldown
- Partial lock blocks shortening cooldown and other existing pause loosening
- `activate_pause()` rejects when cooldown active or pause already active (defense in depth)
- All `check_and_clear_expired_pause()` rewrite paths preserve `LAST_PAUSE_TIMESTAMP`
- Status/manage show three distinct pause states (active / cooldown / available)
- `bash tests/test-pause-feature.sh` passes; partial-lock cooldown cases pass
- SAFETY.md three invariants unchanged

---

**Status:** Draft — not started  
**Priority:** Medium (UX flexibility; builds on enhancement #21)  
**Last updated:** 2026-05-31
