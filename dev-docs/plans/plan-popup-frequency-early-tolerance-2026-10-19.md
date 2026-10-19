# Plan: Popup Display Frequency Early Tolerance

**Status: NEEDS REVIEW — do not implement until reviewed and approved.**

| | |
|---|---|
| **Created** | 2026-10-19 |
| **Related** | Enhancement #30 (`POPUP_DISPLAY_FREQUENCY` + last-popup-time throttle) |
| **Grok 4.7 review** | 2026-10-19 — approve-with-fixes applied below; human approval still required before implementation |
| **Evidence** | Live Deck log 2026-10-19: reconstructed timeline — popup logged ~01:00:03; timer at 01:10:02 skipped (579s &lt; 600s); next show ~01:15 → effective ~15 min |

## Problem

With `POPUP_DISPLAY_FREQUENCY=10`, the systemd timer runs every **5** minutes (`get_timer_run_interval` → `OnCalendar=*:0/5`). The gate in `sleep-warning.sh` requires a **full** `frequency × 60` seconds since `last-popup-time`.

### Why near-misses happen (corrected mechanism)

1. **`last-popup-time` is stamped on close, not display.** Linux `show_warning` blocks until the dialog ends (`_popup_linux_run_post_spawn_lifecycle`); `write_last_popup_time` runs after that return. A “Popup displayed” log at `01:00:03` plus 579s elapsed points to a stamp around `01:09:42`, not `01:00:03` — the ~20s gap to the `01:10:02` timer tick matches dialog-on-screen time before the stamp.
2. **`AccuracySec=1min` makes ticks late, not early.** In `lib/service-config-linux.sh`, systemd may fire up to ~1 minute *after* `OnCalendar`. It does not advance the tick.
3. **Result:** Elapsed can land a few tens of seconds short of a full interval. The run skips, and the user waits until the **next** 5-minute boundary — often **~15 minutes** between popups instead of ~10.

Observed (reconstructed from Deck logs; paste raw lines when re-verifying):

```text
~01:00:03  Popup displayed (stamp written later, after dismiss)
 01:10:02  Skipping popup - 579s since last (display frequency: 10 min)   # 21s short of 600
~01:15:03  Popup displayed
```

### Residual miss (expected; do not widen the formula)

A shortfall **greater than** the early tolerance still slips to the next timer slot. Examples: previous tick ~60s late (`AccuracySec`), or on-screen time beyond ~30s before the stamp on a 10-minute setting. Manual smoke must treat that as residual behavior, not a failed fix.

## Goal

Allow the frequency gate to treat a run as “due” when elapsed time is within a small **early tolerance** of the configured interval, so a 10-minute setting lands near every 10 minutes on the 5-minute timer grid for near-misses.

**Do not** change the derived timer run interval (`5` when frequency ≥ 5), `OnCalendar`, or Darwin `StartInterval` in this plan.

## Proposed rule

When deciding whether to skip because of `last-popup-time`:

```text
early_tolerance_seconds = min( 5% of popup_freq_seconds, 5 minutes in seconds )
                        = min( popup_freq_seconds * 5 / 100, 300 )

show if time_since_last >= (popup_freq_seconds - early_tolerance_seconds)
```

For integer minutes in the legal range (1–60), tolerance simplifies to **`freq_minutes * 3` seconds** (exact 5%). Within 1–60 the **300s cap never binds** (max early at 60 min = 180s). Keep the `min(..., 300)` product rule anyway so the helper stays correct if called with larger synthetic values in unit tests.

**Integer math (required):** multiply before dividing — `$((freq_minutes * 60 * 5 / 100))` or `$((freq_minutes * 3))`. Never `$((popup_freq_seconds / 100 * 5))` (that truncates 60s → 0).

**Inclusive boundary:** `elapsed == required` → show (same style as today’s `-lt` full-interval gate). `elapsed == required - 1` → skip.

**Invalid helper input:** if minutes are non-integer or outside 1–60, tolerance is **0** (strict full interval). Config reading stays solely in `get_popup_display_frequency`.

Examples:

| `POPUP_DISPLAY_FREQUENCY` | Ideal interval | 5% early | Cap 5 min | Tolerance used | Earliest show | Notes |
|---------------------------|----------------|----------|-----------|----------------|---------------|-------|
| 1 min | 60s | 3s | 300s | **3s** | 57s | Timer period = 1 min |
| 4 min | 240s | 12s | 300s | **12s** | 228s | Run interval stays 4 (&lt; 5) |
| 5 min | 300s | 15s | 300s | **15s** | 285s | Run interval becomes 5 |
| 10 min | 600s | 30s | 300s | **30s** | 570s | Fixes 579s Deck near-miss |
| 30 min | 1800s | 90s | 300s | **90s** | 1710s | |
| 60 min | 3600s | 180s | 300s | **180s** | 3420s | From 5%; **cap not applied** |
| 120 min (synthetic) | 7200s | 360s | 300s | **300s** | 6900s | Cap binds; not a legal config — unit test only |

## Scope

### In scope

1. **Runtime gate** — `sleep-warning.sh` only (Enhancement #30 block comparing `time_since_last` to `popup_freq_seconds`). Both Linux and Darwin already share this entry script; there is **no** Darwin duplicate of the last-popup-time throttle.
2. **Shared helpers in `lib/config.sh`** (next to `read_last_popup_time` / `write_last_popup_time`; no new module). Suggested names:
   - `popup_frequency_early_tolerance_seconds` (minutes → seconds)
   - `popup_frequency_min_elapsed_seconds` (minutes → required elapsed)
   - `popup_frequency_is_due` (minutes + elapsed → due or not)
   - Pure functions: take minutes / elapsed; **do not** read the config file.
3. **Logging** — INFO for early-allow **and** skip (`log_message` + `log_to_file`), matching today’s skip line. Include elapsed, required, tolerance, and frequency minutes. WARNING only for negative elapsed. No DEBUG-only diagnosis. No extra line when elapsed is already ≥ full interval (on-time show).
4. **Tests** — see [Tests](#tests) below (Tier A, headless).
5. **Docs** — see [Docs](#docs) below.
6. **Changelog** — `### Fixed` under `## [Unreleased]` when implemented (patch; no version bump).

### Out of scope (unless a later review expands)

- Changing `get_timer_run_interval`, regenerating `OnCalendar`, or Darwin `StartInterval` / plist.
- Moving `write_last_popup_time` to spawn time (would shorten quiet time after dismiss by the whole popup duration — separate review).
- Softening open-popup age checks in `lib/popup-display-linux.sh` / `lib/popup-display-darwin.sh` (stay full interval).
- Applying tolerance to pause / cooldown; writing or clearing `last-popup-time` on pause exit (pause returns **before** the gate).
- User-configurable tolerance percentage.
- Changing popup body copy (“every X minutes”) — leave `tests/test-popup-interval-message.sh` alone.
- Editing `docs/SAFETY.md` (three invariants untouched).
- Touching `lib/install-linux.sh`’s own `get_timer_run_interval` helper.

## Darwin / Linux parity

| Topic | Decision |
|-------|----------|
| Gate location | One change in `sleep-warning.sh` + helpers in `lib/config.sh` |
| Darwin-specific throttle | **None** — no second last-popup-time gate to edit |
| Open-popup skip | Remains strict full interval on both platforms; a gate pass can still no-op if a popup is already up |
| Scheduler | Linux: wall-clock `OnCalendar=*:0/5` + `AccuracySec=1min` (late window). Darwin: `StartInterval` = 300s from LaunchAgent load — phase error can be almost a full 5 minutes. Tolerance only catches **near-misses** on Darwin too |

## Edge cases

| Case | Expected behavior |
|------|-------------------|
| Missing or non-numeric `last-popup-time` | Show (today’s `read_last_popup_time` empty path) |
| `elapsed == required` | Show |
| `elapsed == required - 1` | Skip |
| `elapsed < 0` (future stamp / clock stepped back) | Skip; do **not** clamp to 0; log **WARNING** once. Forward clock jump may show once, then stamp updates |
| Midnight | Epoch seconds only; no calendar day reset. Example: stamp `23:55`, freq 10 → `00:04` next day = 540s → skip; `00:05` = 600s → show |
| Active pause | Exit before gate; must **not** refresh stamp. After pause, long gap → show immediately; short gap still uses tolerance |
| Frequency 1 | Tolerance 3s, required 57s; timer period is 1 minute, not 5 |
| Failed `show_warning` | Still writes stamp today — leave that. Early tolerance must **not** add a retry loop inside one run |

## Logging

- **INFO** early-allow and **INFO** skip: elapsed, required, tolerance, frequency minutes.
- **WARNING** only for negative elapsed.
- No DEBUG-only path for field diagnosis.
- No log when elapsed ≥ full interval (on-time).

## Tests

Add `tests/test-popup-frequency-early-tolerance.sh` and register it in `tests/tiers.yaml` under **tier_a** (headless, no GUI, no `configure.sh`; use temp `HOME` only if a config file is needed).

Pure helper / decision cases (no dialog):

| Case id | Expectation |
|---------|-------------|
| `due_10min_579s` | show (required 570) — Deck near-miss |
| `skip_10min_569s` | skip |
| `due_10min_570s_boundary` | show |
| `due_10min_599s` | show (documents that strict gate would also show; under tolerance this is clearly due) |
| `tol_1min_3s` | tolerance 3 |
| `tol_4min_12s` | tolerance 12 |
| `tol_5min_15s` | tolerance 15 |
| `tol_60min_180s_not_300` | tolerance 180 (5%, cap **not** applied) |
| `tol_120min_capped_300` | synthetic; tolerance 300 |
| `divide_order_1min_not_zero` | 1 min → tolerance 3, not 0 |
| `missing_stamp_shows` | show |
| `non_numeric_stamp_shows` | show |
| `negative_elapsed_skips` | skip |
| `midnight_540s_skips` / `midnight_600s_shows` | as edge-case table |
| `invalid_freq_tolerance_zero` | tolerance 0 |

**Do not** change `tests/test-popup-interval-message.sh` unless popup copy changes (it should not).

**Verification when implementing:**

```bash
./scripts/run-tests.sh --tier a
shellcheck -S error   # on touched shell files
./scripts/run-security-scan.sh --ci   # lib/ change
```

### Manual smoke (after approval)

- **Do not** edit live `~/.config/sleep-warning/` during restricted or lock hours ([docs/SAFETY.md](../../docs/SAFETY.md), config-file-edits rule).
- Prefer: observe an existing frequency of 10, **or** use temp `HOME`.
- Outside restricted hours only if changing installed config is required.
- Success criterion: the 579s-class near-miss **shows**. Success is **not** “every gap is exactly 10 minutes” — residual &gt;tolerance misses can still produce a ~15 min gap.

## Docs

Update when implementing (keep this checklist in the plan until then):

| Path | Change |
|------|--------|
| `user-docs/CONFIGURATION.md` | Add a **Popup display frequency** section for `POPUP_DISPLAY_FREQUENCY` (1–60, default 10). State timer runs every `min(5, frequency)` minutes, and a popup may appear up to `min(5% of the interval, 5 minutes)` early so a 10-minute setting is not stuck on the next 5-minute tick. Do **not** claim exactly every N minutes. Leave or redirect the legacy `CHECK_INTERVAL` section. |
| `user-docs/USER_GUIDE.md` | Overview “checks every 10 minutes”: say check timer is derived (5 min when frequency ≥ 5) and popups are *about* every `POPUP_DISPLAY_FREQUENCY` minutes, with early slop. |
| `dev-docs/TECHNICAL_DETAILS.md` | “Timer Configuration”: replace stale `CHECK_INTERVAL` / `OnCalendar=*:0/10` with `get_timer_run_interval`, `AccuracySec=1min` (late window), close-time stamp, and the gate formula. |
| `dev-docs/enhancements/enhancement-30-...md` | One line at top: strict `>= full interval` gate is superseded by this plan once implemented. Do not rewrite the historical checklist. |
| `CHANGELOG.md` | `## [Unreleased]` → `### Fixed`: near-miss on the frequency gate no longer waits another full timer slot; 16 h cap, watchdog, and escape hatch unchanged. No version tag. |
| `docs/SAFETY.md` | **No edit.** Confirm three invariants untouched on the PR checklist. |
| `dev-docs/TO_DO.md` | Leave item unchecked and “do not implement yet” until human approval + implementation. |

## Implementation sketch (for after approval)

1. Add helpers in `lib/config.sh` with clear docstrings and multiply-before-divide math.
2. Replace strict `-lt "${popup_freq_seconds}"` skip with comparison against `popup_frequency_min_elapsed_seconds`.
3. Wire INFO early-allow / INFO skip logging as specified.
4. Add Tier-A test file + `tests/tiers.yaml` entry; cover the case table above.
5. Update docs + CHANGELOG per [Docs](#docs).
6. Manual smoke per safety rules; do not treat residual &gt;tolerance gaps as regressions.

## Risks and safety

- **Slightly more frequent popups** (up to ~5% early within 1–60): still bounded; does not bypass restricted-hours checks, pause, daily caps, watchdog, or escape hatch.
- **Double-fire in one timer window:** still one show per successful gate + `write_last_popup_time`; timer remains 5 min for freq ≥ 5.
- **Semantic versioning:** patch (`### Fixed`), not a new user-facing setting.
- **`docs/SAFETY.md`:** no change required.

## Review checklist

Settled by Grok 4.7 review (2026-10-19); **human must still approve before implement:**

- [x] Formula: `min(5% of interval, 5 minutes)` — confirmed (10 min → 30s; not “always 30s”; not “5 minutes early on a 10 min timer”).
- [x] Helper location: `lib/config.sh`; Darwin is the **same** gate (no second edit).
- [x] Logging: INFO for early-allow and skip; WARNING for negative elapsed only.
- [x] Test tier: **A** (headless helper/decision tests).
- [x] Docs + CHANGELOG + enhancement-30 pointer called out explicitly; SAFETY unchanged.
- [ ] **Human approve for implementation** (status stays NEEDS REVIEW until then).

## References

- Gate: `sleep-warning.sh` (~lines 310–322)
- Timer derivation: `get_timer_run_interval()` in `lib/config.sh`
- Linux timer accuracy: `AccuracySec` in `lib/service-config-linux.sh`
- Darwin interval: `StartInterval` in `lib/service-config-darwin.sh`
- Enhancement: [enhancement-30](../enhancements/enhancement-30-separate-timer-check-interval-from-popup-display-frequency.md)
- TO_DO entry: [TO_DO.md](../TO_DO.md)
- Versioning: [development/versioning.md](../development/versioning.md)
