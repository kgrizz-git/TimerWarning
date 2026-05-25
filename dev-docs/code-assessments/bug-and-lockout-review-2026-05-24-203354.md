# Bug & lockout-safety review — 2026-05-24

**Reviewer:** AI agent (Claude) — read-only audit, no code changes  
**Scope:** GUI / popup display, configure wizard, scheduler, install/uninstall, time-math safety, runtime fallback  
**Focus question from user:** _"any bugs, particularly in the GUI or that will result in the user being able to lock themselves out more than 16 hrs/day every day"_

---

## TL;DR — executive summary

The project's stated safety contract is:

1. No 24/7 popup warnings.
2. Popups must always end.
3. The user must always be able to stop checks, dismiss UI, and fix config.

This review finds **the contract is partially broken on both Linux and macOS today**:

- **Lockout math:** the >16 h/day rule is **not enforced per calendar day** — it is a **weekly average** (16 × 7 = 6720 minutes). Configurations with 17–23 hours of restriction *every day* save with **only a warning, not a block**, and `0-23` (≈23 h/day × 7) is allowed after a single "Yes, save anyway" click.
- **Critical bypass:** `check_restriction_coverage()` parses **integer hours only** (`7-23`) but the GUI wizard *always* writes **`HH:MM` format** (`07:00-23:00`). The wizard's output is therefore **silently dropped** from validation, so a normal wizard save can produce **effective 24/7** without any warning, block, or runtime fallback.
- **Popup lifetime:** the documented hard watchdog (`POPUP_ABSOLUTE_MAX_SECONDS=120`, see [`docs/SAFETY.md`](../../docs/SAFETY.md)) is **not wired into the Linux popup path**. A Linux popup with `POPUP_AUTO_CLOSE=false` and a hung WM can stay on screen indefinitely.
- **Escape hatches:** on macOS, `uninstall.sh` can claim success while the LaunchAgent is still loaded; `sleep-warning-manage` is **fully blocked** during restricted hours when `CONFIGURE_BLOCK_ENABLED=true`, so the user is funneled to documented raw `launchctl/systemctl` commands they may not remember.
- **macOS sleep/wake grace is broken** (uses reboot time, not wake time) → immediate popup after wake during restricted hours.

Shipped **default config is safe** (~4–5 hours/day, 10-minute interval, auto-close, well under thresholds). The risk window is **the user using the configure wizard normally** or hand-editing the config.

The rest of this document enumerates each finding with file:line citations, severity, and concrete repro paths.

---

## Findings index

| # | Severity | Area | One-line summary |
|---|----------|------|------------------|
| [L1](#l1-hhmm-ranges-silently-dropped-by-validation) | **CRITICAL** | Lockout math | `check_restriction_coverage` ignores HH:MM → wizard saves bypass all safety |
| [L2](#l2-duplicate-day-lines-head-vs-tail-mismatch) | **CRITICAL** | Lockout math | `validate_config_safety` uses `head -n1`; runtime uses `tail -n1` |
| [L3](#l3-runtime-fallback-ignores-lock-hours) | **CRITICAL** | Lockout math | Runtime safety check ignores `CONFIG_LOCK_HOURS_*` and `UNINSTALL_LOCK_HOURS_*` |
| [L4](#l4-16-hday-is-weekly-average-not-per-day-cap) | **HIGH** | Lockout policy | 17–23 h/day every day is "warn", not "block"; `0-23` × 7 saveable with one click |
| [L5](#l5-warn-overrides-do-not-fire-for-ok-saves) | **HIGH** | Lockout policy | Single-day 20 h save with `"ok"` status keeps config-lock active |
| [L6](#l6-lock-hours-on-unrestricted-days-no-popup-feedback) | **HIGH** | Lockout policy | `CONFIG_LOCK_HOURS_MONDAY=9-17` without `MONDAY=` ranges = silent 8 h block |
| [P1](#p1-linux-has-no-hard-watchdog) | **CRITICAL** | Popup / GUI | `popup_run_with_watchdog` never called from Linux `show_warning()` |
| [P2](#p2-python-blocker-spawn-failure--no-popup-at-all) | **CRITICAL** | Popup / GUI | If Python blocker exits immediately, osascript fallback is skipped (numeric PID = "success") |
| [P3](#p3-osascript-fallback-has-no-min-display-no-auto-close) | **CRITICAL** | Popup / GUI | macOS osascript path can be dismissed instantly; message claims a countdown |
| [P4](#p4-fullscreen-macos-blocker-continuously-re-steals-focus) | **HIGH** | Popup / GUI | `_tick()` calls `focus_force()` every 500 ms → violates "should not stay on top after another window selected" |
| [P5](#p5-linux-keep_window_on_top_periodic-continuously-steals-focus) | **HIGH** | Popup / GUI | Same focus-trap class on Linux via wmctrl/xdotool every 0.5 s |
| [P6](#p6-pid-deduplication-race--stacked-modals) | **HIGH** | Popup / GUI | `is_popup_running` → spawn → `save_popup_pid` is not atomic; two scheduler runs can both spawn |
| [P7](#p7-unbounded-post-min-display-wait-on-linux-when-auto-close-off) | **HIGH** | Popup / GUI | `wait "${popup_pid}"` with no timeout when `POPUP_AUTO_CLOSE=false` |
| [P8](#p8-forced-respawn-during-min-display-on-linux) | **MEDIUM** | Popup / GUI | Closing the dialog during min-display kills and respawns it (up to 300 s) |
| [P9](#p9-kdialog-pause-button-hardcoded--no-pause-in-main-dialog) | **MEDIUM** | Popup / GUI | kdialog has no pause on the warning itself; menu hardcodes 5/10 min |
| [P10](#p10-macos-popup-running-detection-misses-orphan-blocker) | **MEDIUM** | Popup / GUI | Secondary detection only matches yad/zenity/kdialog by name, not python3/osascript |
| [C1](#c1-no-lock-recheck-before-write_config) | **HIGH** | Configure | Lock state checked only at wizard entry — long sessions can save during restricted hours |
| [C2](#c2-warn-clears-lock-flags-but-not-the-restriction-hours-that-triggered-warn) | **MEDIUM** | Configure | "Warn → save anyway" disables `CONFIG_LOCK_ENABLED` but keeps the 17–23 h/day schedule |
| [C3](#c3-macos-show_question_dialog-ignores-custom-button-labels) | **MEDIUM** | Configure / GUI | High-restriction confirm shows generic Yes/No, not "Yes, Save Anyway" |
| [C4](#c4-no-trap-in-configuresh) | **LOW** | Configure | Ctrl-C mid-wizard loses progress; no orphan-temp cleanup |
| [C5](#c5-tests-use-hour-only-ranges-and-miss-the-hhmm-bypass) | **MEDIUM** | Configure / tests | Test suite passes while the wizard path is broken |
| [I1](#i1-force-reinstall-re-enables-a-disabled-scheduler) | **MEDIUM** | Install | `./install.sh --force` always runs `enable_timer` / `install_launch_agent` |
| [I2](#i2-macos-uninstall-detection-and-verify-miss-the-launchagent) | **HIGH** | Uninstall | Uninstall reports "not installed" / "completely removed" while plist remains loaded |
| [I3](#i3-bootout--scheduler-stop-failures-reported-as-success) | **MEDIUM** | Uninstall / manage | `\|\| true` and `return 0` mean manage/uninstall always claim disable worked |
| [I4](#i4-managesh-fully-blocked-when-configure-block-enabled) | **HIGH** | Manage | Restricted hours + `CONFIGURE_BLOCK_ENABLED=true` → entire menu blocked, including Disable Service |
| [I5](#i5-macos-launchd-overlap--blocking-popup--pid-race) | **HIGH** | Scheduler | Long popup + short `StartInterval` → concurrent jobs both spawn dialogs |
| [I6](#i6-macos-sleepwake-grace-broken) | **CRITICAL** | Scheduler | `kern.boottime` does not change on sleep/wake → no grace after laptop wake |
| [I7](#i7-darwin-resume-detected-with-empty-timestamp--grace-skipped) | **HIGH** | Scheduler | Reboot grace also broken on macOS: `check_system_resume()` returns 0 without echoing timestamp |
| [T1](#t1-octal-bug-on-leading-zero-hours-in-validation) | **MEDIUM** | Time math | `[ "${start_hour}" -lt 0 ]` and `$((h * 60))` on `08`/`09` fail (octal) |
| [T2](#t2-hour-only-end-boundary-excludes-last-hour-0-23--23-h-not-24-h) | **LOW** | Time math | Off-by-one in user expectations: `0-23` is 23 h, not 24 |
| [T3](#t3-convert_time_range_to_24hour-does-not-bound-hours-to-023) | **MEDIUM** | Time math | `25:00-26:00` is accepted and stored |
| [T4](#t4-runtime-overnight-carry-from-previous-day-skipped-when-current-day-has-ranges) | **MEDIUM** | Time math | Under-restriction (opposite of lockout), but a logic bug worth knowing |

Total: **3 critical lockout-math bugs, 3 critical popup bugs, 1 critical scheduler bug, plus 9 high-severity, 11 medium, 3 low.**

---

## Lockout-math findings (config validation & runtime fallback)

### L1. HH:MM ranges silently dropped by validation

**Severity:** CRITICAL  
**Files:** `lib/configure-validation.sh:175-187`, `lib/time-calculations.sh:312-324`  
**Caller paths:** `configure.sh:561-565` (save gate); `sleep-warning.sh:132` (runtime fallback).

`process_hours_array()` extracts the hour with `start_hour="${r%%-*}"` and demands `^[0-9]+$`. Anything containing `:` fails the test and the range is **silently skipped** (`continue`).

But the GUI wizard always writes ranges in **`HH:MM-HH:MM`** form via `normalize_time_range` (`lib/time-parsing.sh:219-260`, `lib/configure-input-time.sh:275-276`). At runtime, `parse_config()` + `is_restricted_time()` honor minutes correctly.

**Concrete repro:**

```
SUNDAY=00:00-23:59
MONDAY=00:00-23:59
TUESDAY=00:00-23:59
WEDNESDAY=00:00-23:59
THURSDAY=00:00-23:59
FRIDAY=00:00-23:59
SATURDAY=00:00-23:59
```

- Validation total minutes: **0** → status `"ok"` → save proceeds with no warning, no block.
- Runtime: popups fire ~24/7.
- `validate_config_safety()` *also* runs through the same broken parser → **no fallback to safe defaults**.

This single bug allows a wizard-saved configuration to lock the user out roughly 24 hours/day with **zero safety prompts and zero runtime mitigation.** It is the highest-impact finding in this review.

---

### L2. Duplicate day lines: `head` vs `tail` mismatch

**Severity:** CRITICAL  
**Files:** `sleep-warning.sh:111-112` (uses `head -n1`) vs `lib/config.sh:539-540` (uses `tail -n1`).

If two `SUNDAY=` lines exist (manual edit, partial migration, or a buggy writer):

```
SUNDAY=
SUNDAY=0-12,12-0
…repeat for all 7 days…
```

- `validate_config_safety()` reads the empty line → weekly total is small → status `"ok"` → no fallback.
- `parse_config()` (runtime) reads the second line → 24/7 popups.

Configure GUI is locked (if `CONFIG_LOCK_ENABLED=true`) or shows popups continuously. Documented `launchctl bootout` / `systemctl --user stop` paths still work — but only if the user knows them.

---

### L3. Runtime fallback ignores lock/uninstall-lock hours

**Severity:** CRITICAL  
**Files:** `sleep-warning.sh:96-141` builds `config_lines` from `SUNDAY`…`SATURDAY` only — it never includes `CONFIG_LOCK_HOURS_*` or `UNINSTALL_LOCK_HOURS_*`. Configure-time validation in `configure.sh:562-565` does include them.

**Repro:**

```
MONDAY=
CONFIG_LOCK_HOURS_MONDAY=0-12,12-0
…
CONFIGURE_BLOCK_ENABLED=true
CONFIG_LOCK_ENABLED=true
```

- Configure-time would block this save **only if** the user used the wizard (and only if L1 is fixed).
- Runtime `validate_config_safety()` returns `"ok"` because restriction hours are empty.
- `is_config_lock_active()` and `check_config_lock_time()` still lock the config dir 24/7 → user cannot run `configure` or `manage` (manage is gated by `check_config_lock_time` — see [I4](#i4-managesh-fully-blocked-when-configure-block-enabled)).
- **No popup fires** to tell the user what is happening.

---

### L4. 16 h/day is weekly average, not per-day cap

**Severity:** HIGH (policy bug — possibly intentional, but it does not match the user's stated expectation)  
**Files:** `lib/configure-core.sh:78-85`, `lib/configure-validation.sh:446-465`.

Thresholds are weekly totals of merged minutes:

```
THRESHOLD_WARN  = 16 × 60 × 7 = 6720   → "warn" if total > 6720
THRESHOLD_BLOCK = 24 × 60 × 7 = 10080  → "block" if total ≥ 10080
```

Consequences (assuming hour-only ranges so the parser actually works):

- **`7-23` every day** (the user's example of 7am–11pm): 16 h × 7 = 6720 → boundary is `>`, so this is exactly `"ok"`. **No warning at all.**
- **`6-23` every day** (the user's example of 6am–11:30pm): 17 h × 7 = 7140 → `"warn"`. User can confirm.
- **`0-23` every day**: 23 h × 7 = 9660 → `"warn"`. User can confirm.

The wizard's own help text (`lib/configure-ui.sh:245-246`, `lib/configure-validation.sh:259-260`) suggests >16 h/day triggers a *warning per day*. The code does not enforce per-day, only weekly average. `lib/time-calculations.sh:152-244` even has a `calculate_total_day_duration()` function — but **nothing calls it from configure or runtime**. Dead code.

**This is the answer to the user's headline question.** The cap is not "16 h/day every day"; it is "16 h/day on average over the week." So a 20 h Monday + 0 h Tue–Sun saves silently as `"ok"`, and 23 h every day saves with one confirm.

---

### L5. `"warn"` overrides do not fire for `"ok"` saves

**Severity:** HIGH  
**Files:** `configure.sh:573-637`.

When validation returns `"warn"`, the save path applies automatic safety overrides — disables `CONFIGURE_BLOCK_ENABLED`, disables `CONFIG_LOCK_ENABLED`, clears `CONFIG_LOCK_HOURS_*`, clamps popup size. These overrides **only run for `"warn"`**.

Because of [L4](#l4-16-hday-is-weekly-average-not-per-day-cap), a config with 20 h restriction on a single day stays `"ok"` and keeps **all** of those lock flags enabled. The user can deliberately enable harsh lock behavior with no automatic counter-safety.

---

### L6. Lock hours on unrestricted days produce no popup feedback

**Severity:** HIGH  
**Files:** `lib/time-validation.sh:357-497`, `lib/config-locking.sh:54-76`.  
**Known/planned fix:** referenced in `dev-docs/TO_DO.md:16` and `dev-docs/plans/plan-additional-hours-no-restrictions.md`, **not implemented.**

`CONFIG_LOCK_HOURS_MONDAY=9-17` is honored by `check_config_lock_time` / `is_config_lock_active` regardless of whether `MONDAY=` has any restriction ranges. So Monday 9–17 can silently lock the configure GUI and lock the config dir, with no popup warning the user.

---

## Popup / GUI findings

### P1. Linux has no hard watchdog

**Severity:** CRITICAL  
**Files:** `lib/popup-display.sh:247-697`, `lib/popup-safety.sh:14-100`, `docs/SAFETY.md:28`.

`popup_run_with_watchdog` exists and is documented as the bounded-lifetime guarantee. **It is never called from `show_warning()` on Linux.** The Linux path relies on:

- The min-display loop completing (only fires if the dialog process is still alive).
- Optional auto-close (`POPUP_AUTO_CLOSE=true`, user-configurable).
- User clicking dismiss.

If `POPUP_AUTO_CLOSE=false` and the dialog process survives SIGTERM (stuck GTK/QT), or `close_popup_process` fails, the dialog can persist for **hours/days**. This directly violates rule #2 in `docs/SAFETY.md`.

---

### P2. Python blocker spawn failure → no popup at all

**Severity:** CRITICAL  
**Files:** `lib/popup-dialog-implementations-darwin.sh:123-125`, `lib/popup-dialog-implementations-darwin.sh:183-186`.

`_popup_spawn_blocker_darwin` always sets `popup_pid=$!` and returns 0. The dispatcher then treats any numeric PID as success without `kill -0`:

```183:186:lib/popup-dialog-implementations-darwin.sh
        if _popup_darwin_has_blocker; then
            _popup_spawn_blocker_darwin "${base_msg}"
            if [ -n "${popup_pid}" ] && [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
                return 0
```

If the Python blocker exits immediately (bad JSON, tkinter import failure, no display server, broken pyobjc), the dispatcher reports success and the **osascript fallback never runs**. The user gets no warning at all during restricted hours, while the rest of the system thinks the warning was shown.

---

### P3. osascript fallback has no min-display, no auto-close

**Severity:** CRITICAL  
**Files:** `lib/popup-dialog-implementations-darwin.sh:134-168`, `lib/popup-display-darwin.sh:7-111`, `lib/popup-safety.sh:115-125`.

On macOS, the osascript fallback (`display alert`) is **immediately dismissible** with OK. There is no min-display loop on the Darwin path and no in-osascript auto-close timer. The only ceiling is the shell-level watchdog (~120 s), which kills the alert but does not match the message text that promises "will auto-close in 10 seconds."

So `DARWIN_FORCE_AUTO_CLOSE` is effectively a no-op on the fallback path, and configured `POPUP_MIN_DISPLAY_TIME` (up to 60 s on Darwin) is not enforced.

---

### P4. Fullscreen macOS blocker continuously re-steals focus

**Severity:** HIGH (violates explicit user rule about not staying on top after another window is selected)  
**Files:** `lib/popup-blocker-darwin.py:129-135` (`grab_set`), `lib/popup-blocker-darwin.py:302-307` (`_tick`), `lib/popup-blocker-darwin.py:79-100` (pyobjc `NSScreenSaverWindowLevel`).

`_tick()` runs every 500 ms and unconditionally calls `root.attributes("-topmost", True)`, `lift()`, and **`focus_force()`**. The optional pyobjc path also bumps to `NSScreenSaverWindowLevel` with `IgnoresCycle`. The user cannot keep another app focused while the popup is open. This is fixed-duration (≤120 s watchdog), but during that window the focus trap is total.

---

### P5. Linux `keep_window_on_top_periodic` continuously steals focus

**Severity:** HIGH  
**Files:** `lib/popup-display.sh:450-463`, `lib/window-management.sh:262-304`.

A background loop calls `wmctrl -i -a` and `xdotool windowfocus/windowactivate` every 0.5 s for up to 300 s. Same focus-trap class as P4 on Linux.

---

### P6. PID deduplication race → stacked modals

**Severity:** HIGH  
**Files:** `lib/popup-display.sh:388-413`, `lib/popup-pid-management.sh:258-285`.

The sequence `is_popup_running` → spawn → `save_popup_pid` is not atomic. Two concurrent `sleep-warning.sh` runs (more likely on macOS where `StartInterval` overlap can occur — see [I5](#i5-macos-launchd-overlap--blocking-popup--pid-race)) can both pass the check and both spawn dialogs. macOS fullscreen blocker makes the stacking especially harmful.

Fix direction: add `flock` on the PID file around the check-and-spawn.

---

### P7. Unbounded post-min-display wait on Linux when auto-close off

**Severity:** HIGH  
**Files:** `lib/popup-display.sh:617-647`, `lib/popup-display.sh:662-693`, `lib/config.sh:231-246`.

After min-display completes, code does `wait "${popup_pid}"` with no timeout when `POPUP_AUTO_CLOSE != true`. Combined with P1 (no watchdog), this is the unbounded modal path on Linux.

---

### P8. Forced respawn during min-display on Linux

**Severity:** MEDIUM  
**Files:** `lib/popup-display.sh:540-555`, `lib/popup-display.sh:468-504`.

If the user closes the dialog via WM controls during min-display, `update_popup_countdown` kills and respawns the dialog with the remaining countdown. User repeatedly dismissing is overridden for the entire min-display period (default 30 s, max 300 s on Linux). Combined with the focus trap of [P5](#p5-linux-keep_window_on_top_periodic-continuously-steals-focus), this can feel like a lockout even at safe schedules.

---

### P9. kdialog: pause button hardcoded, no pause in main dialog

**Severity:** MEDIUM  
**Files:** `lib/popup-dialog-implementations.sh:159-181`, `lib/popup-dialog-implementations.sh:274-303`.

The kdialog warning uses `--sorry` and offers no in-dialog Pause button. The pause menu shown afterwards hardcodes `5` and `10` minutes, ignoring the user's configured `pause_duration`. KDE users get a degraded escape hatch.

---

### P10. macOS popup-running detection misses orphan blocker

**Severity:** MEDIUM  
**Files:** `lib/popup-pid-management.sh:127-172`, `lib/window-management-darwin.sh:12-46`.

Secondary detection only matches `zenity|yad|kdialog` via wmctrl/xdotool/pgrep. `check_window_tools` is a no-op on Darwin. If the PID file is stale but a Python blocker or osascript alert is still alive, dedup misses it and the next tick will stack a second dialog.

---

## Configure-wizard findings

### C1. No lock re-check before `write_config`

**Severity:** HIGH  
**Files:** `configure.sh:192-219` (entry checks) vs `configure.sh:652` (write).

`check_config_lock_time` and `is_config_lock_active` run **once at wizard entry**. A user who enters during an unrestricted minute can spend ten minutes editing and save during restricted hours, including saving a brand-new schedule that locks them out starting "now."

Fix direction: re-run lock checks immediately before `write_config`, and re-run validation against the in-memory new config considering current wall clock.

---

### C2. `"warn"` clears lock flags but not the restriction hours that triggered `"warn"`

**Severity:** MEDIUM  
**Files:** `configure.sh:617-635`, `lib/configure-config.sh` `_write_lock_hours_section`.

Confirming a `"warn"` save zeroes out `CONFIG_LOCK_HOURS_*` / `UNINSTALL_LOCK_HOURS_*` and disables `CONFIG_LOCK_ENABLED` / `CONFIGURE_BLOCK_ENABLED` — but it **does not touch the `MONDAY=…` restriction lines**. So the popup schedule remains as aggressive as the user requested; only the *secondary* lock features are softened. This is reasonable for safety, but the UX text does not make it clear.

---

### C3. macOS `show_question_dialog` ignores custom button labels

**Severity:** MEDIUM  
**Files:** `lib/configure-dialogs-darwin.sh:327-351` vs callers e.g. `lib/configure-ui.sh:546`.

The high-restriction confirmation passes "Yes, Save Anyway" / "Cancel, Edit" labels. AppleScript path renders generic Yes / No. Users can confirm a dangerous save without seeing what they are confirming.

---

### C4. No `trap` in `configure.sh`

**Severity:** LOW  
**Files:** entire `configure.sh` — no `trap` matches.

Ctrl-C mid-wizard loses progress (atomic temp-file write in `lib/configure-config.sh:785-828` does protect the live config — good). Temp `.tmp.*` files may be left in `$CONFIG_DIR`. Not a safety bug, but a polish gap.

---

### C5. Tests use hour-only ranges and miss the HH:MM bypass

**Severity:** MEDIUM (testing)  
**Files:** `tests/test-24-7-prevention-additional-hours.sh` (`SUNDAY=0-16` style fixtures).

The 24/7 prevention test suite only exercises integer-hour ranges. The wizard always writes `HH:MM`. The most dangerous safety bug ([L1](#l1-hhmm-ranges-silently-dropped-by-validation)) is not covered. Tests pass while real users can save 24/7 configs.

---

## Install / scheduler / uninstall findings

### I1. `--force` reinstall re-enables a disabled scheduler

**Severity:** MEDIUM  
**Files:** `install.sh:755-770`, `install.sh:941-942`, `lib/install-darwin.sh`.

`./install.sh --force` always runs `enable_timer` / `install_launch_agent` regardless of prior state. A user who has explicitly disabled the timer (e.g. as an emergency stop) gets warnings re-enabled by `--force` with no consent prompt.

---

### I2. macOS uninstall detection and verify miss the LaunchAgent

**Severity:** HIGH  
**Files:** `uninstall.sh:537-541` (installed-check), `uninstall.sh:450-473` (`verify_removal`).

`uninstall.sh` detects "installed" by checking `sleep-warning.sh` OR `sleep-warning.service`. The LaunchAgent plist at `~/Library/LaunchAgents/com.sleep-warning.plist` is not in either check. If the user manually deleted the script, uninstall says "does not appear to be installed" and exits — leaving the plist loaded and firing.

`verify_removal` similarly checks scripts and systemd files only. The completion summary can read "completely removed" while `launchctl print gui/$(id -u)/com.sleep-warning` still shows the agent.

---

### I3. Bootout / scheduler-stop failures reported as success

**Severity:** MEDIUM  
**Files:** `uninstall.sh:213-217`, `lib/service-config-darwin.sh:105-112`, `lib/service-config-darwin.sh:144-148`, `lib/scheduler-platform.sh:18-31`, `manage.sh:262-274`.

`launch_agent_bootout` uses `|| true` and `return 0`. The caller's `if [ $? -eq 0 ]` is always true. The user gets "Service disabled successfully" even if launchd refused. False confidence that checks have stopped is a safety-relevant UX bug.

---

### I4. `manage.sh` fully blocked when configure-block enabled

**Severity:** HIGH (when feature is on)  
**Files:** `manage.sh:570-575`, `lib/time-validation.sh:357-365`.

`manage.sh` calls `check_config_lock_time` before showing the menu and exits with code 1 if it returns failure. The "Temporarily Disable Service" item is inside that same menu. So if `CONFIGURE_BLOCK_ENABLED=true` and the current time is within restricted/lock hours, the user **cannot use `sleep-warning-manage` to stop the warnings** — only raw `systemctl --user stop` or `launchctl bootout` works.

Default config has `CONFIGURE_BLOCK_ENABLED=false`, so default installs are unaffected. Any user who turns this on (or any wizard save that does not clear it via the `"warn"` override path) is at risk.

Fix direction: always allow the "Disable Service" menu item even when configure is blocked, or move the lock check below menu rendering.

---

### I5. macOS launchd overlap + blocking popup + PID race

**Severity:** HIGH  
**Files:** `lib/service-config-darwin.sh:92-93` (`StartInterval`), `lib/popup-display-darwin.sh:77-96`, `lib/popup-pid-management.sh:388-412`.

`StartInterval` schedules new job starts regardless of whether the previous run has finished. `show_warning_darwin` blocks until the popup completes (up to ~120 s watchdog). With `CHECK_INTERVAL=1` (60 s), the second invocation can pass `is_popup_running` before the first calls `save_popup_pid` — both then spawn fullscreen blockers. At the default 10-minute interval this is unlikely; at any user-shortened interval it becomes plausible.

---

### I6. macOS sleep/wake grace is broken

**Severity:** CRITICAL (for the stated sleep-grace feature)  
**Files:** `lib/sleep-detection-darwin.sh:12-35`.

`get_boot_time_darwin` reads `kern.boottime`. **That value does not change on sleep/wake — only on reboot.** Therefore `check_system_resume()` never detects a wake event. A laptop that sleeps during restricted hours and wakes up gets the next-tick warning immediately, with no grace period. This is the opposite of the intended Enhancement #9 behavior.

Fix direction: use `pmset -g log | grep -E "Wake from"` or `sysctl kern.waketime` (where available) to detect wake events.

---

### I7. Darwin resume detected with empty timestamp → grace skipped

**Severity:** HIGH  
**Files:** `lib/sleep-detection-darwin.sh:22-35`, `lib/sleep-detection-darwin.sh:69-82`.

Even on actual reboot (which I6 *does* notice), `check_system_resume()` returns 0 without echoing a timestamp. `should_skip_warning_after_resume` requires a non-empty timestamp before applying the 60 s grace, so the grace is skipped on reboot too. The 60-s post-reboot mute documented in the README does not actually happen on macOS.

---

## Time-math / parsing findings

### T1. Octal bug on leading-zero hours in validation

**Severity:** MEDIUM  
**Files:** `lib/configure-validation.sh:184-186`, `lib/time-validation.sh:34-39`, `lib/time-calculations.sh:64`, `lib/time-calculations.sh:72`, `lib/time-calculations.sh:181-182`.

Hour comparisons like `[ "${start_hour}" -lt 0 ]` and arithmetic `$((start_hour * 60))` treat `08` and `09` as **invalid octal** in bash:

```
$ x=09; echo $((x * 60))
bash: 09: value too great for base (error token is "09")
```

`get_current_minute_offset()` in `lib/time-calculations.sh:370-382` correctly uses the `10#` prefix. The validation paths do not. With `set -e` this can abort scripts mid-run; without it, the range gets silently skipped. Either way, a config like `MONDAY=08-17` can be undercounted in coverage. (Wizard typically writes HH:MM and hits L1 instead, but hand edits trigger this.)

**Fix direction:** prefix all user-derived hour arithmetic with `10#`.

---

### T2. Hour-only end boundary excludes last hour (`0-23` = 23 h, not 24 h)

**Severity:** LOW (expectation mismatch, not lockout)  
**Files:** `lib/time-validation.sh:227-231`, `lib/configure-validation.sh:272-276`.

Ranges are `[start, end)` on hour boundaries. `0-23` covers hours 0–22, leaving hour 23 free. A user typing "0-24" to mean "all day" gets that rejected; a user typing "0-23" gets 23 hours, not 24. This is partly what saves [L4](#l4-16-hday-is-weekly-average-not-per-day-cap) from being a *guaranteed* 24/7 with one click — `0-23` is "only" 9660 min/week. But it is an off-by-one the user should be aware of when interpreting validation results.

---

### T3. `convert_time_range_to_24hour()` does not bound hours to 0–23

**Severity:** MEDIUM  
**Files:** `lib/time-parsing.sh:184-188`.

The 24-hour path validates numeric format but not `h ≤ 23` or `m ≤ 59`. `25:00-26:00` can be normalized and stored. Runtime `is_restricted_time()` will never match it (under-restriction), so this is not a lockout vector — but combined with the silent skip in [L1](#l1-hhmm-ranges-silently-dropped-by-validation), it lets garbage propagate into the config.

---

### T4. Runtime overnight carry from previous day skipped when current day has ranges

**Severity:** MEDIUM (under-restriction — opposite of lockout)  
**Files:** `sleep-warning.sh:222-285`, `lib/time-validation.sh:411-452`, `lib/config-locking.sh:89-131`.

Previous-day overnight extension is only checked when `restricted_range` is empty (`elif [ -z "${restricted_range}" ]`). If Sunday has `23-6` and Monday has `9-17`, the 00:00–05:59 carry from Sunday is **not** applied on Monday. The user gets fewer restrictions than configured. Not a lockout, but a correctness bug that contradicts the validation logic (which does merge overnight properly).

---

## Cross-cutting observations

- **Default install ships safe**: `sleep-warning.conf:127-133` is ~4–5 h/day, `CHECK_INTERVAL=10`, `POPUP_AUTO_CLOSE=true`. None of the critical issues hit a default user out of the box.
- **`status.sh` is clean**: read-only, no config writes. Audited.
- **Atomicity of config writes is OK**: `lib/configure-config.sh:785-828` uses temp + `mv` and preserves the original on failure.
- **Documentation drift**: `docs/SAFETY.md` lists a hard watchdog as universal; it is darwin-only in practice ([P1](#p1-linux-has-no-hard-watchdog)). Wizard help text claims 16 h/day triggers a warning; code only checks weekly average ([L4](#l4-16-hday-is-weekly-average-not-per-day-cap)).
- **Several findings are already in the backlog**: `dev-docs/TO_DO.md` references lock-hours-without-restriction-hours and macOS popup wiring. None of the critical findings here appear to be tracked.

---

## Prioritized fix order (recommendation only — no code changed)

1. **L1** — teach `process_hours_array()` to parse `HH:MM` (or normalize through `time-parsing.sh` first). Without this, every other safety check on the wizard path is illusory.
2. **L3** — include lock/uninstall-lock hours in `validate_config_safety()`.
3. **L2** — make validation and `parse_config()` agree on `head` vs `tail` (or reject duplicate day lines).
4. **I6** — replace `kern.boottime` with a real wake-event detector on macOS.
5. **P1** — call `popup_run_with_watchdog` from Linux `show_warning()`.
6. **P2 / P3** — `kill -0` after Python blocker spawn, and either implement min-display/auto-close on the osascript path or refuse to use it when min-display > 0.
7. **I2** — uninstall must check and remove the LaunchAgent on macOS, and `verify_removal` must run `launchctl print` to confirm.
8. **I4** — `sleep-warning-manage` must always permit "Disable Service" even when configure is blocked.
9. **L4** — either enforce a per-day cap (recommended: block at `> 16 h` on any single day) or change docs/UI to clearly say "weekly average."
10. **P4 / P5** — stop calling `focus_force` / `windowactivate` periodically; respect when the user focuses another window.
11. **C1** — re-run lock checks immediately before `write_config`.
12. **C5** — add tests with wizard-realistic HH:MM ranges and split ranges like `0-12,12-0`.
13. **T1** — `10#` prefix all hour arithmetic.
14. **I3** — stop reporting bootout/systemctl failures as success.
15. Remaining medium/low findings.

---

## What was not reviewed in depth

- The status display formatting (`status.sh` is read-only; behavior was confirmed but not exhaustively tested).
- The `lib/config-locking.sh` permission-restore code path beyond confirming `restore_config_permissions` is called by `uninstall.sh`.
- Localization / Unicode edge cases beyond what `lib/unicode-dialog-safety.sh` already mitigates.
- The actual `dev-docs/plans/` backlog entries — only referenced where they match a finding.

---

## File:line index (quick reference)

| Module | Key files |
|--------|-----------|
| Lockout math | `lib/configure-validation.sh`, `lib/time-calculations.sh`, `lib/time-validation.sh`, `lib/time-parsing.sh`, `sleep-warning.sh`, `lib/config.sh` |
| Popup display | `lib/popup-display.sh`, `lib/popup-display-darwin.sh`, `lib/popup-safety.sh`, `lib/popup-dialog-implementations.sh`, `lib/popup-dialog-implementations-darwin.sh`, `lib/popup-pid-management.sh`, `lib/popup-blocker-darwin.py`, `lib/window-management*.sh` |
| Configure | `configure.sh`, `lib/configure-*.sh`, `lib/configure-dialogs-darwin-*.py`, `lib/config-locking.sh` |
| Scheduler / install | `install.sh`, `lib/install-darwin.sh`, `lib/service-config*.sh`, `lib/scheduler-platform.sh`, `uninstall.sh`, `manage.sh`, `launchd/*`, `sleep-warning.service`, `sleep-warning.timer` |
| Sleep detection | `lib/sleep-detection.sh`, `lib/sleep-detection-darwin.sh` |
