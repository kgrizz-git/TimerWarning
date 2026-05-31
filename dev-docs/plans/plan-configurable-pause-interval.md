# Plan: Configurable Pause Cooldown and Duration

## Overview

Enhancement #21 added a pause button on warning popups that suppresses popups for a short period. Today the **pause length** is partially configurable (5 or 10 minutes, default 5), but the **time between allowed pauses** is hardcoded as once per calendar day. This plan adds user-configurable pause cooldown (6, 12, or 24 hours, or pause disabled) and expands pause duration to **1, 2, 3, 5, 10, or 15 minutes**.

**Related docs:**
- [enhancement-21-one-time-pause-feature.md](../enhancements/enhancement-21-one-time-pause-feature.md)
- [enhancement-21-pause-scope-clarification.md](../enhancements/enhancement-21/enhancement-21-pause-scope-clarification.md)
- [docs/SAFETY.md](../../docs/SAFETY.md) — partial-lock tighten-only rules during configure-block hours

## Goals

1. **Pause on/off** — Keep `PAUSE_ENABLED=true|false` (disable pause entirely).
2. **Configurable cooldown** — When pause is enabled, let the user choose minimum time between pause activations: **6, 12, or 24 hours** (replacing calendar-day once-per-day logic).
3. **Configurable duration** — Expand `PAUSE_DURATION` allowlist to **1, 2, 3, 5, 10, or 15** minutes (default remains 5).
4. **Configure wizard** — Single pause settings flow: enabled/disabled, cooldown hours, duration minutes.
5. **Runtime enforcement** — Cooldown enforced in `lib/pause-state.sh`; popup buttons hidden when cooldown not elapsed.
6. **Backward compatibility** — Existing installs with no `PAUSE_COOLDOWN_HOURS` behave like **24 hours** (closest to current once-per-day semantics).

## Current Behavior (as of 2026-05-31)

### Pause duration — not hardcoded to 5 minutes, but enum-locked

| Layer | Behavior |
|-------|----------|
| Default | `DEFAULT_PAUSE_DURATION=5` in `lib/config.sh` |
| Config key | `PAUSE_DURATION=5` or `10` in `sleep-warning.conf` |
| Configure wizard | User picks 5 or 10 via `get_pause_duration_config()` |
| Popup UI | One button: `Pause ${pause_duration} min` (from config, not both options) |
| Activation | `activate_pause()` rejects anything except 5 or 10 |

So pause length is **configurable but limited to two values**. Default is 5 minutes when unset.

### Pause cooldown — hardcoded once per calendar day

| Layer | Behavior |
|-------|----------|
| Runtime | `can_pause_today()` in `lib/pause-state.sh` compares `LAST_PAUSE_DATE` to today's date (`YYYY-MM-DD`) |
| State file | `~/.config/sleep-warning/.pause_state` stores `LAST_PAUSE_DATE` + `PAUSE_END_TIMESTAMP` |
| Config | **No config key** — once-per-day is always enforced |
| Dead code | `get_pause_once_per_day_config()` exists in `lib/configure-input-features.sh` but is **not wired** to config write or runtime (removed from enhancement-21 implementation) |

### Scope unchanged

Pause still **only suppresses warning popups**. It does not affect `configure.sh` blocking, uninstall protection, or restriction-hour math. See [pause scope clarification](../enhancements/enhancement-21/enhancement-21-pause-scope-clarification.md).

## Proposed Configuration

### New key: `PAUSE_COOLDOWN_HOURS`

```bash
# PAUSE_COOLDOWN_HOURS: Minimum hours between pause activations (6, 12, or 24)
# Only applies when PAUSE_ENABLED=true
# Default: 24 (backward-compatible with prior once-per-day behavior)
# Cooldown is measured from last activation timestamp, not calendar midnight
PAUSE_COOLDOWN_HOURS=24
```

| Value | Meaning |
|-------|---------|
| *(n/a when `PAUSE_ENABLED=false`)* | Pause feature off — no pause button |
| `6` | User may activate pause again 6 hours after the previous activation |
| `12` | User may activate pause again 12 hours after the previous activation |
| `24` | User may activate pause again 24 hours after the previous activation |

**Not in scope (unless explicitly requested later):** unlimited pauses (cooldown `0`), per-day cap separate from cooldown, or sub-hour cooldowns.

### Existing keys (unchanged semantics, expanded validation)

```bash
PAUSE_ENABLED=true|false          # default: true
PAUSE_DURATION=1|2|3|5|10|15      # default: 5
```

### State file format (extended)

```bash
# ~/.config/sleep-warning/.pause_state
PAUSE_END_TIMESTAMP=<unix_epoch>       # when current pause expires (unchanged)
LAST_PAUSE_TIMESTAMP=<unix_epoch>      # when user last clicked pause (NEW — replaces date-only tracking)
LAST_PAUSE_DATE=YYYY-MM-DD             # kept for migration / logging; optional after migration
```

On activation, write both `LAST_PAUSE_TIMESTAMP` and `LAST_PAUSE_DATE`. Cooldown checks use `LAST_PAUSE_TIMESTAMP` only.

**Migration:** If `LAST_PAUSE_TIMESTAMP` is missing but `LAST_PAUSE_DATE` is today, treat last activation as start of that calendar day (conservative — user waits until cooldown from midnight). If `LAST_PAUSE_DATE` is a prior day, no cooldown block.

## Duration Expansion (Phase 6)

Current allowlist: **5, 10** minutes everywhere (`activate_pause`, configure, partial lock).

**Target allowlist:** **1, 2, 3, 5, 10, 15** minutes.

| Value | Role |
|-------|------|
| 1, 2, 3 | Short “finish this one thing” breaks; more restrictive default options for users who want minimal popup suppression |
| 5, 10 | Existing choices (5 remains default) |
| 15 | Longest allowed pause — still a brief exception window, not a hours-long bypass |

**Design constraints:**
- **Enum only** — no free-form minutes; validate in `activate_pause()`, config load, configure save, and partial lock.
- **Partial lock** — longer duration = more permissive → blocked during configure-block hours unless baseline already allowed that value; shorter duration = tighten-only (allowed).
- **Popup safety** — pause duration is independent of popup min-display / watchdog; no change to [docs/SAFETY.md](../../docs/SAFETY.md) popup lifetime invariant.
- **Invalid legacy values** — if config has a value outside the allowlist (e.g. manual edit), fall back to **5** and log a warning (same pattern as other enum config keys).

**Shared validation helper (recommended):** `pause_is_valid_duration_minutes N` in `lib/pause-state.sh` or `lib/config.sh` — single source for allowlist `{1,2,3,5,10,15}` used by runtime, wizard, and tests.

## User Experience

### Configure wizard (menu item 10 today)

Replace “Enable pause and configure duration” with a small sub-flow:

1. **Enable pause?** (`PAUSE_ENABLED`) — yes / no  
2. If yes → **Cooldown between pauses:** 6 h / 12 h / 24 h (`PAUSE_COOLDOWN_HOURS`)  
3. If yes → **Pause length:** 1 / 2 / 3 / 5 / 10 / 15 min (`PAUSE_DURATION`)

Status line example: `[Enabled, 5 min, cooldown 12 h]`

### Warning popup

- Show pause button only when `PAUSE_ENABLED=true` **and** cooldown elapsed **and** not currently in an active pause (`can_pause_now()` — new helper, replaces misleading `can_pause_today()` name).
- Button label unchanged: `Pause ${pause_duration} min`.
- If cooldown not elapsed: hide pause button (same as today when “already used today”).

### manage.sh / status.sh

Display:
- Pause enabled / disabled
- Configured duration and cooldown
- Active pause until `HH:MM` if applicable
- Next pause available at `HH:MM` if cooldown blocking

## Safety Assessment

| Invariant | Impact |
|-----------|--------|
| Per-day 16 h cap | **None** — pause does not change restriction/configure/uninstall hour sets |
| Popups must always end | **None** — pause shortens how often popups appear; popup watchdog unchanged |
| Escape hatch | **None** — `launchctl bootout` / `systemctl --user stop` / uninstall path unchanged |
| Partial configure lock | **Apply tighten-only rules:** during lock hours, user may disable pause or **decrease** cooldown hours / duration; may **not** enable pause, **increase** cooldown interval (more pauses), or **increase** duration |

Pause remains a popup-only “quiet period,” not a restriction release. Shorter cooldown (6 h vs 24 h) is more permissive and should be blocked during partial lock unless baseline already allowed it.

**Abuse note:** Cooldown is enforced via state file; a determined user can delete `.pause_state`. That is existing behavior for once-per-day and is acceptable — the product goal is self-control aid, not tamper-proof lockout.

## Implementation Plan

### Phase 1 — Config and getters

**Files:** `lib/config.sh`, `lib/configure-config.sh`

- [ ] Add `DEFAULT_PAUSE_COOLDOWN_HOURS=24`
- [ ] Add `get_pause_cooldown_hours()` — returns `6`, `12`, or `24`; invalid/missing → `24`
- [ ] Read/write `PAUSE_COOLDOWN_HOURS` in `load_existing_config` / `write_config`
- [ ] Validate on save: must be 6, 12, or 24 when `PAUSE_ENABLED=true`

### Phase 2 — Pause state logic

**Files:** `lib/pause-state.sh`

- [ ] Rename or wrap: `can_pause_now()` (public) replacing `can_pause_today()` semantics:
  - Return false if `PAUSE_ENABLED=false`
  - Return false if `is_pause_active`
  - Return false if `now - LAST_PAUSE_TIMESTAMP < PAUSE_COOLDOWN_HOURS * 3600`
  - Return true otherwise
- [ ] Add `get_last_pause_timestamp()` reader
- [ ] Update `activate_pause()` to write `LAST_PAUSE_TIMESTAMP=$(date +%s)`
- [ ] Update `check_and_clear_expired_pause()` to retain `LAST_PAUSE_TIMESTAMP` when clearing expired `PAUSE_END_TIMESTAMP` (mirror current `LAST_PAUSE_DATE` retention)
- [ ] Migration helper: populate `LAST_PAUSE_TIMESTAMP` from `LAST_PAUSE_DATE` when missing

### Phase 3 — Configure wizard

**Files:** `lib/configure-input-features.sh`, `lib/configure-display.sh`, `configure.sh` (orchestration)

- [ ] Add `get_pause_cooldown_hours_config(use_gui)`
- [ ] Wire sub-flow after `get_pause_enabled_config` / `get_pause_duration_config`
- [ ] Update menu status strings (GUI + text)
- [ ] Remove or repurpose dead `get_pause_once_per_day_config()` — **delete** if unused (avoid two competing cooldown UIs)
- [ ] Partial lock baselines in `lib/configure-partial-lock.sh`:
  - `_baseline_pause_cooldown_hours`
  - Validate: cannot **decrease** cooldown hours (e.g. 24 → 6) during lock hours
  - Validate: cannot enable pause or increase duration (existing)

### Phase 4 — Popup and entrypoints

**Files:** `lib/popup-display.sh`, `lib/popup-display-darwin.sh`, `lib/popup-dialog-implementations*.sh`, `sleep-warning.sh`, `manage.sh`, `status.sh`

- [ ] Replace `can_pause_today` calls with `can_pause_now`
- [ ] Optional: `get_next_pause_available_time()` for status display

### Phase 5 — Tests and docs

- [ ] Extend `tests/test-pause-feature.sh`:
  - Cooldown 6/12/24 blocks re-pause until elapsed
  - Migration from `LAST_PAUSE_DATE`-only state file
  - `PAUSE_ENABLED=false` hides pause
- [ ] Partial lock test cases in `tests/test-configure-partial-lock.sh`
- [ ] Update [enhancement-21-one-time-pause-feature.md](../enhancements/enhancement-21-one-time-pause-feature.md) — cooldown replaces “always once per day”
- [ ] Update [user-docs/MACOS.md](../../user-docs/MACOS.md) / Linux user docs if pause section exists
- [ ] CHANGELOG entry under “Unreleased”

### Phase 6 — Duration allowlist expansion

**Files:** `lib/pause-state.sh`, `lib/config.sh`, `lib/configure-config.sh`, `lib/configure-input-features.sh`, `lib/configure-partial-lock.sh`

- [ ] Add `pause_is_valid_duration_minutes` (or equivalent) — allowlist **1, 2, 3, 5, 10, 15**
- [ ] Update `activate_pause()` validation and error messages
- [ ] Update `get_pause_duration()` / config load in `lib/configure-config.sh` — reject invalid values → default 5
- [ ] Update `get_pause_duration_config()` wizard list (GUI + text) with all six options and short descriptions
- [ ] Update `write_config` comments for `PAUSE_DURATION`
- [ ] Partial lock: treat duration as ordered allowlist index or numeric minutes for tighten-only compare
- [ ] Extend `tests/test-pause-feature.sh` — activation and timestamp math for 1, 2, 3, and 15 min; invalid value fallback

## Backward Compatibility

| Scenario | Behavior |
|----------|----------|
| No `PAUSE_COOLDOWN_HOURS` in config | Default **24** — approximates once-per-day |
| Existing `.pause_state` with only `LAST_PAUSE_DATE` | Migration on read (see §State file format) |
| `PAUSE_ENABLED=false` | Unchanged — no pause button |
| Manual `PAUSE_DURATION=5` or `10` | Unchanged |
| Manual `PAUSE_DURATION` outside allowlist | Fall back to **5** on read |

## Open Questions

1. **Default cooldown for new installs:** 24 h (recommended) vs 12 h?
2. **kdialog / osascript UX:** Any extra copy when cooldown active (“Pause available again at …”) — status only, or also in popup footer?

## Acceptance Criteria

- [ ] User can disable pause entirely (`PAUSE_ENABLED=false`).
- [ ] User can set cooldown to 6, 12, or 24 hours when pause is enabled.
- [ ] Pause button appears only when cooldown has elapsed and no active pause.
- [ ] Pause duration respects config — any of **1, 2, 3, 5, 10, 15** minutes; default 5.
- [ ] Upgraded configs without new key behave as ~once per 24 hours.
- [ ] Partial lock prevents loosening pause settings during configure-block hours.
- [ ] `bash tests/test-pause-feature.sh` passes; partial-lock tests updated.
- [ ] SAFETY.md checklist unchanged for the three invariants.

---

**Status:** Draft — not started  
**Priority:** Medium (UX flexibility; builds on enhancement #21)  
**Last updated:** 2026-05-31
