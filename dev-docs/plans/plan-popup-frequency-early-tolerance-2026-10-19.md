# Plan: Popup Display Frequency Early Tolerance

**Status: NEEDS REVIEW — do not implement until reviewed and approved.**

| | |
|---|---|
| **Created** | 2026-10-19 |
| **Related** | Enhancement #30 (`POPUP_DISPLAY_FREQUENCY` + last-popup-time throttle) |
| **Grok 4.7 review** | 2026-10-19 — approve-with-fixes applied; human still must approve before implementation |
| **Human add-on (2026-10-19)** | Guard: nominal frequency − early tolerance must stay above popup duration with cushion — see [Duration floor](#duration-floor-early-tolerance-vs-popup-on-screen-time) |
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

## Duration floor (early tolerance vs popup on-screen time)

Early tolerance must not shrink the quiet gap so far that the next popup can become due while the previous one is still (or barely finished being) on screen.

### Definitions (proposed — confirm in review)

| Symbol | Meaning |
|--------|---------|
| `freq_s` | Nominal interval = `POPUP_DISPLAY_FREQUENCY × 60` |
| `early` | Raw early tolerance = `min(freq_s × 5 / 100, 300)` (then possibly clamped) |
| `min_elapsed` | Earliest gate allow = `freq_s − early` |
| `popup_duration` | Expected on-screen time. **Proposed default:** `POPUP_MIN_DISPLAY_TIME` when auto-close is off; `POPUP_MIN_DISPLAY_TIME + AUTO_CLOSE_DELAY` (10s) when auto-close is on. **Review question:** use min-display alone, or include auto-close delay? Do **not** use `POPUP_ABSOLUTE_MAX_SECONDS` here (that is a safety kill ceiling, not nominal duration). |

### Required inequality (with cushion)

`min_elapsed` must stay strictly above `popup_duration`, with **both** cushions (take the stricter floor):

```text
# Cushion A — absolute quiet gap after/around on-screen time
min_elapsed >= popup_duration + 60

# Cushion B — on-screen time may not consume more than 90% of the earliest gap
popup_duration <= floor(min_elapsed * 90 / 100)
  ⇔  min_elapsed >= ceil(popup_duration * 100 / 90)   # integer-safe form in tests

required_floor = max(popup_duration + 60, ceil(popup_duration * 100 / 90))
min_elapsed    >= required_floor
```

Equivalent clamp on early tolerance:

```text
max_early_allowed = freq_s - required_floor   # if negative → config invalid / early forced to 0
early_effective   = min(early_raw, max(0, max_early_allowed))
```

### Examples

| freq | early_raw (5%) | popup_duration | required_floor | early_effective | Notes |
|------|----------------|----------------|----------------|-----------------|-------|
| 10 min (600s) | 30s | 30s (default min-display) | max(90, 34) = **90** | min(30, 600−90)=**30** | Unchanged — 570 ≥ 90 |
| 10 min | 30s | 40s (30+10 auto-close) | max(100, 45) = **100** | **30** | Still fine — 570 ≥ 100 |
| 10 min | 30s | 300s (max min-display) | max(360, 334) = **360** | **30** | Still fine — 570 ≥ 360 |
| 1 min (60s) | 3s | 30s | max(90, 34) = **90** | min(3, 60−90)→**0** | Early **clamped off**; min_elapsed stays 60. Existing `validate_popup_timing_config` already blocks min-display &gt; full interval; this floor also kills early when gap is tight |
| 5 min (300s) | 15s | 300s | max(360, 334) = **360** | **0** | Early clamped; configure should already reject min-display ≥ interval via existing validator |

### Where to enforce

1. **Runtime helper** — `popup_frequency_early_tolerance_seconds` (or a wrapper that takes `popup_duration`) returns the **clamped** early value so the gate never violates the floor even if config was edited by hand.
2. **Configure-time** — extend `validate_popup_timing_config` in `lib/configure-validation.sh` (today only checks `POPUP_MIN_DISPLAY_TIME ≤ freq_s`) so saving also fails (or warns — **review: hard block preferred**) when `freq_s − early_raw < required_floor` *and* the only fix would be clamping early to 0 *while* min-display already equals/near the full interval — actually: prefer **hard block** when even `early=0` cannot satisfy `freq_s >= required_floor` (i.e. when `freq_s < popup_duration + 60` or duration &gt; 90% of `freq_s`). When early would merely be clamped, either accept silent clamp at runtime **or** surface an INFO in configure — **review preference: silent runtime clamp + optional configure note; hard block only when `freq_s < required_floor`.**
3. Reuses / complements Enhancement #9 queue-prevention; does not replace it.

### Review open points on this section

- [ ] Confirm cushions: `+60s` **and** `≤90% of min_elapsed` (both).
- [ ] Confirm `popup_duration` includes `AUTO_CLOSE_DELAY` when auto-close is on.
- [ ] Confirm hard-block vs silent clamp when early would be reduced but `early=0` still OK.
- [ ] Confirm no change to `POPUP_ABSOLUTE_MAX_SECONDS` / watchdog math.

## Scope

### In scope

1. **Runtime gate** — `sleep-warning.sh` only (Enhancement #30 block comparing `time_since_last` to `popup_freq_seconds`). Both Linux and Darwin already share this entry script; there is **no** Darwin duplicate of the last-popup-time throttle.
2. **Shared helpers in `lib/config.sh`** (next to `read_last_popup_time` / `write_last_popup_time`; no new module). Suggested names:
   - `popup_frequency_early_tolerance_seconds` (minutes → seconds; applies 5%/5‑min then **duration-floor clamp**)
   - `popup_frequency_min_elapsed_seconds` (minutes → required elapsed after clamp)
   - `popup_frequency_is_due` (minutes + elapsed → due or not)
   - `popup_frequency_duration_floor_seconds` (popup_duration → `required_floor`)
   - Pure functions where possible; duration clamp may take `popup_duration` as an argument (caller reads min-display / auto-close from config).
3. **Configure validation** — extend `validate_popup_timing_config` (or sibling) so `freq_s >= required_floor` is a hard block; document early clamp behavior.
4. **Logging** — INFO for early-allow **and** skip (`log_message` + `log_to_file`), matching today’s skip line. Include elapsed, required, tolerance, and frequency minutes. When early was clamped by the duration floor, log that once at INFO (raw vs effective). WARNING only for negative elapsed. No DEBUG-only diagnosis. No extra line when elapsed is already ≥ full interval (on-time show).
5. **Tests** — see [Tests](#tests) below (Tier A, headless), including duration-floor cases.
6. **Docs** — see [Docs](#docs) below.
7. **Changelog** — `### Fixed` under `## [Unreleased]` when implemented (patch; no version bump).

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
| Frequency 1 | Raw tolerance 3s → required 57s **unless** duration floor clamps early to 0; timer period is 1 minute, not 5 |
| Duration floor clamp | If `freq_s − early_raw < required_floor`, reduce early (possibly to 0); never allow `min_elapsed < required_floor` at the gate |
| `freq_s < required_floor` | Configure hard-block (extend timing validator); runtime falls back to strict full interval (`early=0`) and still cannot invent gap — existing min-display vs interval check should already prevent most of these |
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
| `floor_dur30_req90` | `required_floor = max(90, 34) = 90` |
| `floor_dur40_req100` | `required_floor = max(100, 45) = 100` (auto-close path) |
| `clamp_1min_dur30_early0` | freq 1 + duration 30 → early clamped to 0 |
| `no_clamp_10min_dur40` | freq 10 + duration 40 → early stays 30 |
| `block_freq_below_floor` | `freq_s < required_floor` → validator fails (configure test; may live in timing-validation test file) |

Also extend / add cases beside existing `validate_popup_timing_config` coverage if present.

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
| `user-docs/CONFIGURATION.md` | Add a **Popup display frequency** section for `POPUP_DISPLAY_FREQUENCY` (1–60, default 10). State timer runs every `min(5, frequency)` minutes, and a popup may appear up to `min(5% of the interval, 5 minutes)` early so a 10-minute setting is not stuck on the next 5-minute tick — subject to the duration floor (earliest gap still ≥ popup on-screen time + cushions). Do **not** claim exactly every N minutes. Leave or redirect the legacy `CHECK_INTERVAL` section. Note that configure rejects combos where even zero early cannot keep the gap above the floor. |
| `user-docs/USER_GUIDE.md` | Overview “checks every 10 minutes”: say check timer is derived (5 min when frequency ≥ 5) and popups are *about* every `POPUP_DISPLAY_FREQUENCY` minutes, with early slop. |
| `dev-docs/TECHNICAL_DETAILS.md` | “Timer Configuration”: replace stale `CHECK_INTERVAL` / `OnCalendar=*:0/10` with `get_timer_run_interval`, `AccuracySec=1min` (late window), close-time stamp, and the gate formula. |
| `dev-docs/enhancements/enhancement-30-...md` | One line at top: strict `>= full interval` gate is superseded by this plan once implemented. Do not rewrite the historical checklist. |
| `CHANGELOG.md` | `## [Unreleased]` → `### Fixed`: near-miss on the frequency gate no longer waits another full timer slot; 16 h cap, watchdog, and escape hatch unchanged. No version tag. |
| `docs/SAFETY.md` | **No edit.** Confirm three invariants untouched on the PR checklist. |
| `dev-docs/TO_DO.md` | Leave item unchecked and “do not implement yet” until human approval + implementation. |

## Implementation sketch (for after approval)

1. Add helpers in `lib/config.sh` with clear docstrings and multiply-before-divide math (5%/5‑min + duration-floor clamp).
2. Replace strict `-lt "${popup_freq_seconds}"` skip with comparison against clamped `popup_frequency_min_elapsed_seconds`.
3. Extend `validate_popup_timing_config` (or sibling) for `freq_s >= required_floor` hard block.
4. Wire INFO early-allow / INFO skip / INFO clamp logging as specified.
5. Add Tier-A test file + `tests/tiers.yaml` entry; cover the case table above (including floor/clamp).
6. Update docs + CHANGELOG per [Docs](#docs).
7. Manual smoke per safety rules; do not treat residual &gt;tolerance gaps as regressions.

## Risks and safety

- **Slightly more frequent popups** (up to ~5% early within 1–60, after duration clamp): still bounded; does not bypass restricted-hours checks, pause, daily caps, watchdog, or escape hatch.
- **Double-fire in one timer window:** still one show per successful gate + `write_last_popup_time`; timer remains 5 min for freq ≥ 5. Duration floor further reduces overlap risk vs min-display / auto-close.
- **Semantic versioning:** patch (`### Fixed`), not a new user-facing setting.
- **`docs/SAFETY.md`:** no change required (popup lifetime invariant unchanged).

## Review checklist

Settled by Grok 4.7 review (2026-10-19); **human must still approve before implement:**

- [x] Formula: `min(5% of interval, 5 minutes)` — confirmed (10 min → 30s; not “always 30s”; not “5 minutes early on a 10 min timer”).
- [x] Helper location: `lib/config.sh`; Darwin is the **same** gate (no second edit).
- [x] Logging: INFO for early-allow and skip; WARNING for negative elapsed only.
- [x] Test tier: **A** (headless helper/decision tests).
- [x] Docs + CHANGELOG + enhancement-30 pointer called out explicitly; SAFETY unchanged.
- [ ] Duration floor cushions (`+60s` and `≤90%`) — confirm or adjust numbers.
- [ ] `popup_duration` definition (min-display only vs + auto-close delay).
- [ ] Hard-block vs silent clamp when early must shrink.
- [ ] **Human approve for implementation** (status stays NEEDS REVIEW until then).

## References

- Gate: `sleep-warning.sh` (~lines 310–322)
- Timer derivation: `get_timer_run_interval()` in `lib/config.sh`
- Existing timing validator: `validate_popup_timing_config` in `lib/configure-validation.sh` (Enhancement #9)
- Linux timer accuracy: `AccuracySec` in `lib/service-config-linux.sh`
- Darwin interval: `StartInterval` in `lib/service-config-darwin.sh`
- Enhancement: [enhancement-30](../enhancements/enhancement-30-separate-timer-check-interval-from-popup-display-frequency.md)
- TO_DO entry: [TO_DO.md](../TO_DO.md)
- Versioning: [development/versioning.md](../development/versioning.md)
