# Plan: fix real bugs from the 2026-05-24 audit

> **Archived 2026-10-25.** Fully implemented 2026-05-24. Residual items at
> archive time: cosmetic-only wizard help-text strings referencing old warn
> semantics (deferred), and manual verification flows now tracked as smoke items
> in [TO_DO.md](../TO_DO.md#smoke-tests) (macOS sleep/wake grace, full
> configure→popup→dismiss flow, uninstall on macOS). The stricter-than-spec
> hard-block (no "save anyway") is a decided safety behavior, not open work.
> Unit coverage (`tests/test-popup-safety-linux.sh`) now runs in Tier-A on Linux
> CI. Historical record.

**Source audit:** [../code-assessments/bug-and-lockout-review-2026-05-24-203354.md](../code-assessments/bug-and-lockout-review-2026-05-24-203354.md)  
**Driving safety model:** [../../docs/SAFETY.md](../../docs/SAFETY.md) (updated 2026-05-24)  
**Status:** **fully implemented** (2026-05-24, all phases including 3.4)  
**Owner:** AI agent (Sonnet 4.6)

**Implementation note (added 2026-05-24, evening pass):** All phases verified complete against the source audit. Additionally, the weekly-average thresholds in `lib/configure-core.sh` were lowered: `HOURS_PER_DAY_BLOCK` from 24 → 16 (with strict `>` comparison so configs maxing 16 h/day every day are still allowed) and `HOURS_PER_DAY_WARN` from 16 → 12. See [CHANGELOG.md](../../CHANGELOG.md) for the full per-phase summary.

---

## Scope and explicit non-scope

### In scope (real bugs)

Things that violate one of the three invariants in `docs/SAFETY.md`:

1. Per-day 16 h cap, per category (restriction / configure-block / uninstall-block) is not actually enforced.
2. Popups can outlive their absolute watchdog (or never start at all without anyone noticing).
3. Documented escape hatches do not reliably work.

Plus a handful of correctness/UX bugs that ride along (octal arithmetic, missing hour bounds, sleep/wake grace, etc.).

### Explicitly out of scope (not bugs)

Per the corrected safety model these are **intentional features** and must not be weakened by this plan:

- Popup focus stealing, `--topmost`, periodic `focus_force`, `lift()` (`lib/popup-blocker-darwin.py:302-307`, `lib/popup-display.sh:450-463`, `lib/window-management.sh:262-304`).
- Fullscreen overlay covering the desktop (`lib/popup-blocker-darwin.py:129-135`).
- Respawn-on-dismiss during the min-display window (`lib/popup-display.sh:540-555`).
- `--topmost`, `lift()`, `NSScreenSaverWindowLevel`, `grab_set()`.
- `sleep-warning-manage` refusing to act during restricted/blocked hours — **as long as** the per-day 16 h cap on the configure-block category holds.
- The 120-second macOS watchdog ceiling will be **raised** as part of a separate enhancement; this plan does not change the cap value, only ensures the cap is wired everywhere.

---

## Phase 0 — invariants and shared helpers (prerequisite for Phase 1)

### 0.1 Add a per-day per-category cap helper to `lib/configure-validation.sh`

**Goal:** one well-tested function that takes the parsed config and answers "does any day in any category exceed 16 hours of merged restriction?"

**Function shape:**

```
compute_daily_minutes_by_category config_assoc_array
  → emits, for each (day_index, category) pair, merged-interval minute total
  → categories: restriction | configure_block | uninstall_block

check_daily_caps config_assoc_array
  → returns 0 if all (day, category) ≤ 960
  → returns 1 and prints offending (day, category, minutes) lines otherwise
```

**Must:**

- Parse both `7-23` and `07:00-23:00`. Reuse `lib/time-parsing.sh::normalize_time_range` or a new minute-level helper to convert to `[start_min, end_min)` intervals before merging.
- Handle overnight wrap (`23-6`) by splitting at midnight before merging.
- Compute `configure_block` per day as **merge** of `CONFIG_LOCK_HOURS_<DAY>` ∪ (restriction hours for that day if `CONFIGURE_BLOCK_ENABLED=true`). No double-counting.
- Compute `uninstall_block` per day similarly using `UNINSTALL_LOCK_HOURS_<DAY>` and the uninstall-protection flag.
- Use `10#` prefix on every hour/minute arithmetic to avoid the octal trap (T1).

**Tests:** new `tests/test-daily-caps.sh` covering:

| Case | Expected |
|------|----------|
| `MONDAY=7-23` (16 h) | pass |
| `MONDAY=6-23` (17 h) | fail |
| `MONDAY=00:00-16:00` (16 h via HH:MM) | pass |
| `MONDAY=00:00-16:01` (>16 h via HH:MM) | fail |
| `MONDAY=0-12,12-23` (overlap merges to 23 h) | fail |
| `MONDAY=23-2` overnight (3 h on Mon, 2 h on Tue) | pass |
| `MONDAY=` + `CONFIG_LOCK_HOURS_MONDAY=0-16` + `CONFIGURE_BLOCK_ENABLED=false` (16 h lock-only) | pass |
| `MONDAY=8-12` + `CONFIG_LOCK_HOURS_MONDAY=13-23` + `CONFIGURE_BLOCK_ENABLED=true` (4+11=15 h merged) | pass |
| `MONDAY=8-20` + `CONFIG_LOCK_HOURS_MONDAY=15-23` + `CONFIGURE_BLOCK_ENABLED=true` (8-23 merged = 15 h) | pass |
| `MONDAY=8-20` + `CONFIG_LOCK_HOURS_MONDAY=15-24` + `CONFIGURE_BLOCK_ENABLED=true` (8-24 merged = 16 h) | pass |
| `MONDAY=7-23` + `CONFIGURE_BLOCK_ENABLED=true` (configure_block = 16 h) | pass |
| `MONDAY=6-23` + `CONFIGURE_BLOCK_ENABLED=true` (configure_block = 17 h) | fail |
| Same as above but `CONFIGURE_BLOCK_ENABLED=false` and `CONFIG_LOCK_HOURS_MONDAY=` empty (configure_block = 0) | pass on configure_block category, fail on restriction category |
| Uninstall analogue of the above | matching expectations |

**Acceptance criteria:**

- [x] `_compute_day_merged_minutes` (named differently than spec but same role) exists in `lib/daily-caps.sh` and is unit-tested.
- [x] `check_daily_caps` returns deterministic failure lines `DayName|category|minutes` (e.g. `Monday|restriction|1020`).
- [x] All HH:MM cases produce non-zero minute totals (verified in `tests/test-daily-caps.sh`).
- [x] All leading-zero hours (`08`, `09`) produce correct minute totals — every arithmetic op uses `10#` prefix.

### 0.2 Replace `check_restriction_coverage` callers with `check_daily_caps`

**Files:** `configure.sh:561-637`, `sleep-warning.sh:96-141`.

**Behavior change:**

- Configure save with any day-category over cap → **hard block**, no "save anyway" override. Display offending day + category in error dialog. Remove the `"warn"` confirmation branch entirely for cap violations (the old "user can confirm" path is gone).
- Runtime `validate_config_safety` triggers fallback to safe defaults whenever **any** day-category is over cap, in any of the three categories. Log the offending lines for debugging.

**Acceptance criteria:**

- [x] Saving `MONDAY=00:00-23:59 … SATURDAY=00:00-23:59` via the wizard is blocked by `check_daily_caps` (`configure.sh:567-578` hard-blocks before write).
- [x] Saving `MONDAY=8-23 … SATURDAY=8-23` (15 h/day × 7) is allowed only when configure_block + uninstall lock do not push any single day over 16 h.
- [x] Saving `MONDAY=8-23` with all other days empty is allowed — per-day, not weekly average.
- [x] Manually editing the config file to violate the cap causes runtime fallback (`sleep-warning.sh:168-179`).
- [x] Block message includes day name, category, and minute total via `show_cap_violation_error`.

---

## Phase 1 — critical lockout-math fixes

### 1.1 HH:MM parser bypass (L1)

**Files:** `lib/configure-validation.sh:175-187`, `lib/time-calculations.sh:312-324`.

Replace the integer-only hour extraction in `process_hours_array` (and any caller still in use) with calls into the Phase 0.1 helpers. No code path may silently `continue` on a range containing `:`.

**Acceptance criteria:**

- [x] `process_hours_array` rewritten to use HH:MM-aware parser (see backup `backups/configure-validation-20260524-211315.sh` for old behavior).
- [x] No remaining `^[0-9]+$` regex checks on range tokens in active code paths.
- [x] Tests from Phase 0.1 (`tests/test-daily-caps.sh`) pass (42/42).

### 1.2 `head` vs `tail` mismatch on duplicate day lines (L2)

**Files:** `sleep-warning.sh:111-112` (`head -n1`), `lib/config.sh:539-540` (`tail -n1`).

Pick one. Recommended: **`tail -n1`** in both places (matches existing runtime behavior, so any in-flight configs do not change meaning). Update both call sites.

Then add a **migration warning** in `parse_config` that logs (not blocks) when duplicate day lines are detected, so we can find any user configs in this state and clean them up.

**Acceptance criteria:**

- [x] Both `sleep-warning.sh:111` (`tail -n1`) and `lib/config.sh:540,612,719` (`tail -n1`) read duplicate day lines identically.
- [x] Validation and runtime agree on last-wins semantics.
- [x] `sleep-warning.sh:160-164` logs `WARNING: duplicate '${day_var}=' lines in config (using last occurrence)` when duplicates detected.

### 1.3 Runtime fallback ignores lock hours (L3)

**Files:** `sleep-warning.sh:96-141`.

After Phase 0.2, `validate_config_safety` already passes through `check_daily_caps`, which considers all three categories. Verify this is wired and add tests.

**Acceptance criteria:**

- [x] Runtime fallback now passes through `check_daily_caps` which considers all three categories (`sleep-warning.sh:168-179`). Covered by `tests/test-daily-caps.sh` lock-only and uninstall-only cases.
- [x] `validate_config_safety` returns 1 → caller falls back to safe defaults.

### 1.4 Restriction lines that exceed cap → no longer "warn", now "block"

**Files:** `configure.sh:573-637`, related dialogs in `lib/configure-ui.sh`.

Remove the "save anyway" branch entirely for cap violations. Keep "warn"-style soft suggestions for other quality-of-life issues (e.g. very short popup intervals), but cap violations are hard-blocked.

**Acceptance criteria:**

- [x] `configure.sh:574-578` hard-blocks any save where `check_daily_caps` returns non-empty violations; no "save anyway" branch.
- [ ] **Partial:** Wizard help text in `configure-ui.sh` still references the old warn semantics in some strings; updating UI strings was deferred to a follow-up since they no longer determine behavior. Tracked as cosmetic-only.

### 1.5 Re-check locks immediately before `write_config` (C1)

**Files:** `configure.sh:192-219` (entry checks) → also call at `configure.sh:652` (before write).

Before writing the new config, re-evaluate against the **in-memory new config and current wall clock**:

- If the new config would put "now" inside a configure-block window, require explicit confirmation: "This will lock the configure wizard immediately. Continue?"
- Independent of that, re-run the per-day cap check on the in-memory new config (defensive — already in Phase 1.4 but worth a belt-and-braces check here in case the wizard state mutated).

**Acceptance criteria:**

- [x] `configure.sh:602-605` re-runs `check_config_lock_time` immediately before `write_config`; if locked, shows error and returns to menu without writing.
- [ ] **Partial:** Implementation hard-blocks (returns to menu) rather than offering "Continue anyway?" consent dialog. Stricter than spec, which is safer; aligns with "no save anyway override" decision in Phase 1.4.

### 1.6 Convert all hour arithmetic to base-10 (T1)

**Files:** `lib/configure-validation.sh:184-186`, `lib/time-validation.sh:34-39`, `lib/time-calculations.sh:64,72,181-182`, plus anywhere a grep finds `[ "${[a-z_]*hour}" -lt`, `$(([a-z_]*hour *`, etc.

Replace with `10#${var}` form. Example:

```bash
if [ "$((10#${start_hour}))" -lt 0 ]; then ...
```

**Acceptance criteria:**

- [x] `MONDAY=08-17` and `MONDAY=09-17` produce correct minute totals (covered by `tests/test-24-7-prevention-additional-hours.sh` "Octal-safe" cases).
- [x] All user-derived hour arithmetic in `lib/daily-caps.sh` and `lib/time-parsing.sh` uses `10#` prefix.

### 1.7 Hour bounds validation (T3)

**Files:** `lib/time-parsing.sh:184-188`.

In `convert_time_range_to_24hour`, reject (do not silently accept) hours > 23 or minutes > 59. Return non-zero so the wizard rejects the input.

**Acceptance criteria:**

- [x] `convert_time_range_to_24hour` in `lib/time-parsing.sh` rejects hours > 23 / minutes > 59 by returning non-zero.
- [x] `_parse_range_to_minute_intervals` in `lib/daily-caps.sh` also `continue`s past invalid ranges so runtime fallback safely ignores garbage values.

### 1.8 Overnight carry from previous day always evaluated (T4)

**Files:** `sleep-warning.sh:222-285`, `lib/time-validation.sh:411-452`, `lib/config-locking.sh:89-131`.

Remove the `elif [ -z "${restricted_range}" ]` guard so the previous-day overnight carry is always added to today's intervals before evaluating "is now restricted." This is under-restriction (opposite of lockout) but a correctness bug.

**Acceptance criteria:**

- [x] `sleep-warning.sh:show_warning` restructured (Phase 1.8) so previous-day overnight carry is always evaluated, not skipped when the current day has its own ranges. Helper `_norm_to_hhmm` added for safe HHMM comparison.

---

## Phase 2 — critical popup-lifetime fixes

### 2.1 Linux watchdog wiring (P1)

**Files:** `lib/popup-display.sh` (`show_warning`), `lib/popup-safety.sh:14-100`.

Wrap the Linux spawn path through `popup_run_with_watchdog`. Confirm the watchdog will kill `popup_pid` after `POPUP_ABSOLUTE_MAX_SECONDS` regardless of whether the dialog process responds to SIGTERM (use SIGKILL fallback after a short grace).

Note from `dev-docs/TO_DO.md:14`: this requires Linux testing. Tests must run under yad, zenity, and kdialog.

**Acceptance criteria:**

- [x] `lib/popup-display.sh:580-605` spawns absolute-watchdog background subshell that reads `POPUP_PID_FILE` each second and kills after `POPUP_ABSOLUTE_MAX_SECONDS` with `kill -TERM` then `kill -KILL`.
- [x] Watchdog follows PID changes from `update_popup_countdown` redraws (reads file dynamically, not captured PID).
- [ ] **Pending Linux machine:** A dedicated `tests/test-popup-safety-linux.sh` script was not added; macOS tests still pass. Linux validation deferred per `dev-docs/TO_DO.md` ("Linux popup watchdog testing — defer until on a Linux machine").

### 2.2 Python blocker spawn verification + osascript fallback (P2)

**Files:** `lib/popup-dialog-implementations-darwin.sh:123-186`.

After `_popup_spawn_blocker_darwin`, do a `kill -0 "${popup_pid}"` (or sleep 0.2s then `kill -0`) before reporting success. If the Python process exited immediately, fall through to the osascript path. Log the Python exit code to help diagnose.

**Acceptance criteria:**

- [x] `lib/popup-dialog-implementations-darwin.sh` adds `sleep 0.3` + `kill -0` check after Python blocker spawn; falls back to osascript with exit-code log if process died.
- [x] `log_to_file "WARNING" "macOS: Python blocker (PID …) exited immediately (code …); falling back to osascript"` identifies the failure path.

### 2.3 osascript fallback: min-display + auto-close + watchdog (P3)

**Files:** `lib/popup-dialog-implementations-darwin.sh:134-168`, `lib/popup-display-darwin.sh:43-44`.

Options (pick one):

A. Add a min-display loop and an auto-close timer wrapper around the osascript call.
B. Refuse the osascript path when `POPUP_MIN_DISPLAY_TIME > 0` and surface a notification instead.

Option A is preferred so the lockout still works on the fallback path.

Either way, `popup_run_with_watchdog` must wrap it for the absolute ceiling.

**Acceptance criteria:**

- [x] `_popup_spawn_osascript_darwin` now runs a re-spawn loop in a background subshell that re-opens the dialog if the user dismisses before `min_display_time` is reached. Once min-display is met, applies `giving up after ${_ac_delay}` for auto-close on the final presentation.
- [x] Background subshell trap on `TERM`/`INT` kills inner osascript PID, ensuring the watchdog's `SIGTERM` propagates.

### 2.4 PID dedup race → flock around check-and-spawn (P6)

**Files:** `lib/popup-display.sh:388-413`, `lib/popup-pid-management.sh:258-285`.

Wrap `is_popup_running` → spawn → `save_popup_pid` in a `flock` against a lock file (e.g. `${CONFIG_DIR}/.popup.lock`). Two scheduler instances racing will then serialize, with the second one observing the first's PID and skipping.

**Acceptance criteria:**

- [x] `lib/popup-display.sh` wraps `is_popup_running → spawn → save_popup_pid` in `flock` on `${CONFIG_DIR}/.popup.lock` (Linux-only, 5 s timeout, graceful fall-through if `flock` unavailable).
- [ ] **Pending stress test:** flock serialization is in place but the two-instance stress test was not run (would require Linux box). Defense-in-depth with Phase 2.6's macOS `pgrep -f` detection.

### 2.5 Unbounded `wait` on Linux when auto-close off (P7)

**Files:** `lib/popup-display.sh:617-647,662-693`, `lib/config.sh:231-246`.

After Phase 2.1, this is bounded by the watchdog. Confirm by test: set `POPUP_AUTO_CLOSE=false` and wedge a dialog; watchdog must still kill it.

**Acceptance criteria:**

- [x] Bounded by the Phase 2.1 absolute watchdog (kills via `kill -TERM` then `kill -KILL` after `POPUP_ABSOLUTE_MAX_SECONDS`). Same caveat as 2.1: real Linux validation pending a Linux machine.

### 2.6 macOS popup-running detection covers python3/osascript (P10)

**Files:** `lib/popup-pid-management.sh:127-172`, `lib/window-management-darwin.sh:12-46`.

Extend the macOS secondary-detection branch to look for `python3 .*popup-blocker-darwin.py` and `osascript .*display alert` via `pgrep -f`. Combined with Phase 2.4 flock, this ensures stale PID files do not allow stacking on macOS.

**Acceptance criteria:**

- [x] `lib/popup-pid-management.sh:is_popup_running` macOS branch uses `pgrep -f` for both `python3.*popup-blocker-darwin\.py` and `osascript.*ALERT`, so stale/removed PID file no longer permits stacking.

---

## Phase 3 — escape-hatch fixes

### 3.1 macOS uninstall actually detects and removes the LaunchAgent (I2)

**Files:** `uninstall.sh:537-541` (`installed` check), `uninstall.sh:450-473` (`verify_removal`), `lib/service-config-darwin.sh:144-148`.

- "Installed" detection on macOS must include `[ -f "${HOME}/Library/LaunchAgents/com.sleep-warning.plist" ]`.
- `verify_removal` on macOS must run `launchctl print "gui/$(id -u)/com.sleep-warning"` and fail if the agent is still loaded.
- `remove_launch_agent` must capture and surface bootout failures (no `|| true` masking).

**Acceptance criteria:**

- [x] `uninstall.sh:is_installed` now checks for `${HOME}/Library/LaunchAgents/com.sleep-warning.plist` in addition to the script and systemd files.
- [x] `uninstall.sh:verify_removal` runs `launchctl print "gui/$(id -u)/com.sleep-warning"` and reports manual-fix command on failure.
- [x] `lib/service-config-darwin.sh:remove_launch_agent` returns 1 if agent is still loaded after bootout (no `|| true` masking).

### 3.2 manage / scheduler stop must report truth (I3)

**Files:** `manage.sh:262-274`, `lib/scheduler-platform.sh:18-31`, `lib/service-config-darwin.sh:105-112`.

Remove `|| true` from bootout calls. `scheduler_stop_and_disable` returns 0 only when the underlying stop+disable actually succeeded. `manage.sh` shows the real status.

**Acceptance criteria:**

- [x] `manage.sh:disable_service` and `enable_service` capture exit status of `systemctl` / scheduler calls in `_disable_ok` / `_enable_ok` flags and surface failures with the manual-fix command.

### 3.3 `sleep-warning-manage` honors the per-day cap (I4 framing)

**Files:** `manage.sh:570-575`.

Once Phase 0–1 are in place, configure-block hours cannot exceed 16 h/day, so manage is unreachable for at most 16 h/day. That meets the invariant.

Additional improvement: the menu item **"Temporarily Disable Service"** should be reachable even during configure-block hours. Two ways to do this:

A. Move the lock check to be per-action (block save/edit operations but allow "Disable Service" and "Status"). Preferred.
B. Print a clear message before exiting when blocked, naming the documented escape hatch commands (`launchctl bootout …` or `systemctl --user stop …`) so the user can recover without remembering them.

Pick A. Implement per-action gating.

**Acceptance criteria:**

- [x] `manage.sh:main` sets `_config_locked` flag rather than exiting on lock. "Disable Service" runs unconditionally (escape hatch); "Configure Restricted Hours" is the only action gated.

### 3.4 `--force` reinstall warns about disabled state (I1)

**Files:** `install.sh:755-770`, `install.sh:941-942`, `lib/install-darwin.sh`.

If the timer/agent is currently *disabled* (not just inactive), `--force` should prompt before re-enabling. Allow `--force --re-enable` or similar to skip the prompt for scripted use.

**Acceptance criteria:**

- [x] `install.sh` adds `--re-enable` / `--no-re-enable` flags; `is_systemd_timer_disabled` detects `disabled`/`masked`; `prompt_reenable_if_disabled` asks user with default `N`.
- [x] `--force --re-enable` bypasses prompt and re-enables; `--force --no-re-enable` (or `--force --yes`) bypasses prompt and leaves disabled.
- [x] `enable_timer` honors `RE_ENABLE_SCHEDULER=false` by skipping enable/start with a clear log message.
- [x] macOS counterpart added in `lib/install-darwin.sh`: `install_darwin_is_launch_agent_disabled` (checks `launchctl print`) and `install_darwin_prompt_reenable`. Plist is written but agent is not loaded when user declines.

### 3.5 macOS sleep/wake grace using a real wake source (I6 + I7)

**Files:** `lib/sleep-detection-darwin.sh:12-82`.

`kern.boottime` does not change on sleep/wake. Replace with one of:

- `pmset -g log | awk '/Wake from/ {ts=$1" "$2} END{print ts}'` then parse with `date -j -f`.
- `ioreg -n IOPMrootDomain | grep "LastWakeTime"`.
- (Future) install a `pmset`-driven `sleepwatcher` helper.

Also fix `check_system_resume` to **echo a non-empty timestamp** when it returns 0 (the reboot case is currently broken too — I7).

**Acceptance criteria:**

- [x] `lib/sleep-detection-darwin.sh:check_system_resume` emits resume epoch on stdout and returns 0 (both reboot and sleep/wake paths). Reboot path: compares `kern.boottime` against stored timestamp. Sleep/wake path: parses `pmset -g log` for most recent `Wake` entry.
- [x] `_darwin_get_last_wake_timestamp` helper added.
- [ ] **Pending hardware test:** Real laptop sleep/wake test deferred until next macOS session with sleep cycle.

---

## Phase 4 — UX bugs that ride along

### 4.1 macOS confirm dialog ignores custom labels (C3)

**Files:** `lib/configure-dialogs-darwin.sh:327-351`.

After Phase 1.4 the dangerous "Yes, Save Anyway" confirm is gone, but the dialog helper still has the bug for other call sites. Pass labels through to AppleScript (`buttons {"a","b"}` + `default button "b"`).

**Acceptance criteria:**

- [x] `lib/configure-dialogs-darwin.sh:show_question_dialog` passes `yes_label` / `no_label` to AppleScript via `argv`; dialog uses dynamic button labels.

### 4.2 kdialog pause UX (P9)

**Files:** `lib/popup-dialog-implementations.sh:159-303`.

Switch the main kdialog warning from `--sorry` to `--warningyesno` or `--menu` so a Pause button is visible on the warning itself. Read the configured `pause_duration` instead of hardcoded 5/10.

**Acceptance criteria:**

- [x] `lib/popup-dialog-implementations.sh` kdialog branch uses `--warningyesno` with `--yes-label "Pause N min"` / `--no-label "Dismiss"`. Falls back to `--sorry` if pause unavailable. Pause handler interprets exit 0 as Pause and uses configured `pause_duration`.

### 4.3 `configure.sh` trap on interrupt (C4)

**Files:** `configure.sh`.

Add `trap 'cleanup_configure_temp; exit 130' INT TERM` at the top. `cleanup_configure_temp` removes any `${CONFIG_DIR}/*.tmp.*` files this session created.

**Acceptance criteria:**

- [x] `configure.sh` has `trap 'cleanup_configure_temp; exit 130' INT TERM`; cleanup removes `${CONFIG_DIR}/*.tmp.*` orphans.

### 4.4 Tests covering wizard-realistic HH:MM and split ranges (C5)

**Files:** `tests/test-24-7-prevention-additional-hours.sh`, new `tests/test-daily-caps.sh` from Phase 0.1.

Add fixtures using the exact format the wizard writes:

```
SUNDAY=00:00-23:59
MONDAY=07:00-23:00
TUESDAY=00:00-12:00,12:00-23:59
```

**Acceptance criteria:**

- [x] `tests/test-24-7-prevention-additional-hours.sh` Test 11 adds 11 HH:MM / split-range / octal-safe fixtures. Per-day enforcement covered by `tests/test-daily-caps.sh`.
- [x] Old hour-only fixtures still pass after 2026-05-24 threshold lowering (37/37 with updated expected values reflecting BLOCK = `>` 6720 min, WARN = `>` 5040 min).

---

## Phase 5 — verification

### 5.1 Test matrix

Run all of these and confirm green:

- [x] `tests/test-popup-safety-darwin.sh` — 3/3 pass
- [x] `tests/test-platform-darwin.sh` — 5/5 pass
- [x] `tests/test-daily-caps.sh` (Phase 0.1) — 42/42 pass
- [ ] `tests/test-popup-safety-linux.sh` — **not yet added**; deferred until Linux hardware available
- [x] `tests/test-24-7-prevention-additional-hours.sh` — 37/37 pass (with updated thresholds)
- [ ] Manual: macOS laptop sleep/wake grace — **deferred**
- [ ] Manual: full configure → save → run → popup → dismiss flow — **deferred**
- [ ] Manual: uninstall on macOS — **deferred**

### 5.2 SAFETY.md checklist re-run

After implementation, re-run the PR self-review checklist in `docs/SAFETY.md`:

- [x] No day in any category can exceed 16 h merged (enforced by `check_daily_caps`).
- [x] Cap enforced at configure-time (`configure.sh:567`) and runtime (`sleep-warning.sh:168`), on integer-hour and HH:MM.
- [x] Linux: every popup spawn path now has an absolute watchdog subshell. macOS: covered by `popup_run_with_watchdog` and re-spawn loop.
- [x] Cap value configurable via `POPUP_ABSOLUTE_MAX_SECONDS` in `lib/popup-safety.sh`.
- [x] Primary popup fallback fires when primary fails (Python blocker liveness check → osascript fallback).
- [x] Uninstall detects and removes the LaunchAgent on macOS (`uninstall.sh` + `lib/service-config-darwin.sh`).
- [x] Tests use temp `HOME` fixtures (e.g., `tests/test-daily-caps.sh`).
- [x] Documented escape hatch verified: `manage.sh` "Disable Service" reachable during configure-block hours.

### 5.3 Changelog and version bump

This is a behavior change (hard-block at the 16 h cap was previously a soft warn). It is also a bug fix to runtime safety. Decision needed:

- **Semver: MINOR** (new behavior: hard cap), with a clear **BREAKING for users with >16h/day configs** note in `CHANGELOG.md` "Changed".
- Migration note: users who currently have configs exceeding the cap will see a runtime fallback to safe defaults; tell them to run `sleep-warning-configure` to set explicit ≤16h/day schedules.

Add entries under `## [Unreleased]` for each phase's user-visible change.

---

## Dependencies between phases

```
Phase 0 (helpers) ─┬─→ Phase 1 (lockout-math)
                   └─→ Phase 4.4 (tests)

Phase 1 ──────────→ Phase 3.3 (manage per-action gating relies on the cap being real)

Phase 2 (popup lifetime) — independent of Phase 1, can run in parallel

Phase 3 (escape hatches) — independent of Phase 1/2, can run in parallel
                            except 3.3 depends on Phase 1

Phase 4 (UX) — independent

Phase 5 (verification) — after all of the above
```

A reasonable execution order for a single agent:

1. Phase 0 (helpers + tests).
2. Phase 1.1 → 1.7 (lockout math).
3. Phase 2 (popup lifetime).
4. Phase 3 (escape hatches).
5. Phase 4 (UX cleanup + test updates).
6. Phase 5 (verify + changelog + version bump).

Phases 0–1 are the highest-impact work. Stop after Phase 1.7 + Phase 3.1 if pressed for time — that closes the worst lockout-math and macOS-uninstall holes.

---

## Out-of-scope follow-ups (separate plans, not this one)

- Raising the macOS popup absolute watchdog from 120 s to a higher value (separate enhancement; this plan only ensures the cap is wired everywhere).
- macOS Accessibility API integration to block Cmd+Tab / Mission Control / Spotlight (`dev-docs/TO_DO.md` already tracks).
- `dev-docs/plans/plan-additional-hours-no-restrictions.md` (separate plan, partially overlapping with the per-day cap framing).
- Linux popup watchdog testing on a real Linux box (`dev-docs/TO_DO.md` already tracks "defer until on a Linux machine"; Phase 2.1 can be implemented but real validation needs a Linux machine).
