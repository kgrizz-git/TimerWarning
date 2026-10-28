# TO_DO — active priorities

Short queue of open work. For full status per enhancement, see [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md). For testing, docs, and master-plan phases, see [REMAINING_WORK_SUMMARY.md](REMAINING_WORK_SUMMARY.md).

## Harness engineering (active — post-refactor)

- [x] **Harness engineering improvements** — Phases 1–8 complete → [plan](completed-plans/plan-harness-engineering-improvements-2026-06-12.md) (archived 2026-10-25)

Doc convention: **`docs/`** = end-users; **`dev-docs/`** = developers and agents (see plan Phase 4).

## Configure and UI

- [ ] **Unify time display formatting** — `format_hour_12h` (uppercase `AM`/`PM`, Unicode arrow) vs `24hour_to_12hour` / `format_range_human` (`12:00am ->`); align UX and update grid/status goldens → [platform-test-matrix.md](development/platform-test-matrix.md)
- [ ] **Refresh configure-comprehensive expect script** — verify all 10 scenarios on Linux + `expect` after `.exp` prompt fixes → [platform-test-matrix.md](development/platform-test-matrix.md)
- [ ] **#16c** — Finish GUI multiple time ranges; test with yad, zenity, and kdialog → [enhancement-16c](enhancements/enhancement-16c-multiple-range-entry-gui.md)
- [ ] **Configure GUI fallback** — Tighten `has_gui()` so configure falls back to text mode when no DISPLAY/Wayland socket
- [ ] **Dialog tools** — Verify popup and pause dialogs with all three tools; no indefinite script block

## Features and safety

- [ ] **macOS Accessibility API blocking** — Grant Accessibility permission via `System Settings → Privacy & Security → Accessibility` to intercept Cmd+Tab, Mission Control, and Spotlight during restricted hours. Install script should prompt and open the correct pane. See [dev-docs/POPUP_BLOCKING_MACOS.md](POPUP_BLOCKING_MACOS.md) §Option D for implementation sketch. **Deferred** — current fullscreen tkinter overlay (+ optional pyobjc boost) is the primary blocking path.
- [x] **Linux popup watchdog (code, 2026-05-30)** — `lib/popup-display-linux.sh` uses `popup_compute_watchdog_seconds` + `popup_start_pid_file_watchdog`. Unit tests: `tests/test-popup-safety-linux.sh` (Tier-A on Linux CI, 2026-06-12 harness Phase 7).
- [ ] **Linux popup watchdog (integration / display host)** — Optional follow-ups on a Linux machine with DISPLAY:
  - [x] Tier-A unit tests on `ubuntu-latest` CI (`test-popup-safety-linux.sh` via `./scripts/run-tests.sh --tier a`)
  - [ ] `bash tests/test-config-locking.sh` and `bash tests/test-uninstall-lock-hours.sh` on GNU stat host (Tier-B; portable helpers exist)
  - [ ] `bash tests/test-popup.sh` with yad/zenity/kdialog available
  - [ ] Add `tests/test-popup-safety-linux-integration.sh` — wedge dialog, assert hard kill within cap (recommended)
  - [ ] Manual: `POPUP_AUTO_CLOSE=false` + stuck dialog → must terminate within `POPUP_ABSOLUTE_MAX_SECONDS`
  - Plan: [plans/plan-safety-scan-fixes-2026-05-30.md](plans/plan-safety-scan-fixes-2026-05-30.md) · Analysis: [safety-linux-macos-analysis.md](safety-linux-macos-analysis.md) §5.1
- [ ] **Additional hours on unrestricted days** — Lock/uninstall hours should not apply when a day has no restrictions (opt-in override) → [plan](plans/plan-additional-hours-no-restrictions.md)
- [ ] **Popup frequency early tolerance** — Allow last-popup-time gate to fire up to `min(5% of POPUP_DISPLAY_FREQUENCY, 5 min)` early so 10-min settings do not slip to ~15 min on the 5-min timer grid; clamp early so earliest gap stays above popup on-screen time (`+60s` and `≤90%` cushions). **Plan needs human review — do not implement yet.** → [plan](plans/plan-popup-frequency-early-tolerance-2026-10-19.md)
- [ ] **#29** — kdialog window size via `--textbox` + `--geometry` → [enhancement-29](enhancements/enhancement-29-kdialog-window-size-control.md)
- [ ] **#10** — Audio alerts → [enhancement-10](enhancements/enhancement-10-audio-alerts.md)
- [x] **Configurable pause cooldown and duration** — Pause disabled, or cooldown every N hours (N = 6, 8, 12, 24; default 24); pause length 1/2/3/5/10/15 min → [plan](completed-plans/plan-configurable-pause-interval.md) (scope: [enhancement-21 pause](enhancements/enhancement-21/enhancement-21-pause-scope-clarification.md))

- [ ] **macOS dialog hardening** — Weekday/continuation fixes shipped; Phase 2 caller audit and systematic question/info dialog hardening remain open → [active plan](plans/weekday-gui-bug-fix-plan.md).

## Testing (high impact)

- [ ] **Raise line coverage** — Add tests that execute untested `lib/*.py` and `lib/*.sh`, then raise the floors from a new measurement. Current floors: Python 819/826 with or without a display ([python-coverage-baseline.json](../scripts/python-coverage-baseline.json)); shell darwin 4703/18047 and linux 4800/18047 ([shell-coverage-baseline.json](../scripts/shell-coverage-baseline.json)). The interactive shell modules (`configure-ui*.sh`, `configure-input-*.sh`, `configure-dialogs*.sh`, `configure-display-*.sh`) still have little or no coverage. Do not lower a floor to make a run pass.
- [ ] **SteamOS Gaming Mode** — Full validation with full-screen games → [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md), [phase 4 plan](plans/phases/plan-phase-4-testing.md)
  - [x] **2026-10-19 on-device:** popup **displays and stays up** in Gaming Mode (experimental overlay on)
  - [x] **Click-through + magnification (Phase 1 code):** full `:0` root-width gamescope dialogs + atom/geometry logging → [plan](completed-plans/plan-gamescope-overlay-click-through-2026-10-19.md)
  - [x] **Click-through Phase 2 Streams E+F:** debug capture + top-left / ≥⅔-root height; on-device click retest passed 2026-10-20 → [plan](completed-plans/plan-gamescope-overlay-click-through-2026-10-19.md)
  - [x] **Click-through Phase 2 Stream G (docs):** zenity OK-only vs yad Cancel / kdialog Dismiss documented 2026-10-20 → [plan](completed-plans/plan-gamescope-overlay-click-through-2026-10-19.md)
  - [ ] **Minor log bug (separate):** after auto-close SIGTERM, log may say `User closed popup manually` then exit 143 — fix classification when convenient
- [ ] **Desktop Mode, no external display** — Run test suite on Steam Deck internal display only
- [ ] **Multi-distribution install** — Debian/Ubuntu, Fedora/RHEL, Arch/SteamOS, openSUSE, Alpine → [phase 3 plan](plans/phases/plan-phase-3-installation.md)

## Documentation and release

- [x] **Public repository preparation** — `kgrizz-git/TimerWarning` is public (2026-10-26); plan archived 2026-10-28 → [plan](completed-plans/plan-public-repo-prep-2026-10-16.md). Open residue: the install/status/help string check for the public name, and adding the CI and Security workflow checks as required status checks in the `Mainrules1` ruleset (it requires none today). Donation removal is the deferred item below.
- [ ] **Donation cleanup — deferred 2026-10-24** — Leave existing PayPal links in place until the owner reopens this. Do not add donation integrations as part of publication preparation. Spec: [#27](enhancements/enhancement-27-paypal-donation-links.md).
- [ ] **SteamOS locale docs** — User guide section (Nix + manual paths); do not automate `locale-gen` in install.sh → [REMAINING_WORK_SUMMARY.md](REMAINING_WORK_SUMMARY.md#documentation-work)

## Smoke tests

Manual-only checks left over from archived plans. Code and docs are done; each
item needs a human (or a hardware host) to run it once and record the result in
[testing-assessments/test-history.md](testing-assessments/test-history.md). Do not
re-implement code for these — verify and close.

- [ ] **macOS conditional osascript `activate` (throttle shipped, QA open)** — `_cd_darwin_should_osascript_activate` in `lib/configure-dialogs-darwin.sh` already skips redundant `activate` when the previous dialog was osascript and closed <500 ms ago (always activates after tkinter and on the first dialog). Manual z-order matrix still open: terminal-focused vs IDE launches, Cancel/Back/Escape, confirm-after-list, osascript-after-tk. Source: archived [macOS configure GUI performance plan](completed-plans/macos_configure_gui_performance_acc3b24e.plan.md) Tier B1.
- [ ] **macOS sleep/wake grace** — real laptop sleep/wake cycle; popup/watchdog behavior across resume.
- [ ] **Full manual flow (macOS)** — configure → save → run → popup → dismiss, end to end.
- [ ] **Uninstall on macOS** — manual uninstall run; LaunchAgent removed, status truthful.
- [ ] **Lock error dialog** — trigger in GUI and text mode; confirm dialog text matches fixtures.
- [ ] **Wizard option 13 (Review and Save)** — text-mode run with bounded `configure.sh` (`timeout`, controlled stdin).
- [ ] **Range editing across dialog tools** — yad, zenity, kdialog GUI entry + text entry.
- [ ] **Fresh Linux install** — clean host; verify config directory, service files, installed binaries.
- [ ] **24/7 + additional-hours integration** — configure a dangerous restriction+lock combination and verify blocking; configure a high-restriction combination and verify the warning plus additional-hours clearing. (Unit coverage is Tier-A in `tests/test-24-7-prevention-additional-hours.sh`.)
- [ ] **Deck overlay manual checks** — consolidated with the [SteamOS Gaming Mode checklist](#testing-high-impact): pause-enabled buttons/notice, countdown input, touch, QAM usable after closure, forced watchdog timeout, docked + undocked. Detail in archived [overlay plan](completed-plans/plan-gamescope-overlay-click-through-2026-10-19.md).

## Distribution (lower priority)

- [ ] **#13a** — Single executable installer → [enhancement-13a](enhancements/enhancement-13a-single-executable-installer.md)
- [ ] **#13b** — Desktop GUI wrapper → [enhancement-13b](enhancements/enhancement-13b-desktop-gui-application-wrapper.md)

## Mostly done — finish testing only

Track detail in [REMAINING_WORK_SUMMARY.md](REMAINING_WORK_SUMMARY.md#mostly-implemented-enhancements): #2a, #3, #4, #9, #18, #20, #22, #24, #25, #26, 24/7 + additional hours plan testing.

## Recently completed

- [x] **June 2026 refactor assessment** — Facade splits for configure display/UI/config/input, UI errors, dialog dispatch, config load/write, status display, install-linux, `show_warning` orchestration; success metrics met (`configure-display.sh` 195 lines, `install.sh` 313, `show_warning` 169). Plan archived → [plan](completed-plans/plan-refactor-assessment-2026-06-12.md) · [assessment](refactor-assessments/refactor-assessment-2026-06-12-001417.md). Residual manual checks moved to [Smoke tests](#smoke-tests).
- [x] **Per-day 16 h cap + popup lifetime + escape-hatch (2026-05-24 audit)** — Shipped 2026-05-24 (Phases 0–4): `lib/daily-caps.sh` / `check_daily_caps`, HH:MM lockout math, configure hard-block + runtime fallback, popup watchdog wiring, macOS blocker/osascript/min-display and uninstall/manage escape-hatch fixes. Plan: [plan-real-bugs-fix-2026-05-24](completed-plans/plan-real-bugs-fix-2026-05-24.md) (archived) · Audit: [bug-and-lockout-review-2026-05-24](code-assessments/bug-and-lockout-review-2026-05-24-203354.md) · Tests: `tests/test-daily-caps.sh`. **Linux host verification** remains open: [Linux popup watchdog (verify on Linux build)](#features-and-safety). Residual manual flows moved to [Smoke tests](#smoke-tests).
- [x] **#30** — Separate timer check interval from popup display frequency (`POPUP_DISPLAY_FREQUENCY`, derived run interval, last-popup-time throttling). Implemented 2026-02-09 → [enhancement-30](enhancements/enhancement-30-separate-timer-check-interval-from-popup-display-frequency.md)

---

**Plans index:** [Master plan](plans/master/linux-warning-system-plan.md) · [Active plans](plans/) · [Completed plans](completed-plans/)

**Last updated:** 2026-10-25 (publication Phase 3 done: stubs removed, completed plans archived, smoke items collected; PayPal removal and public rename deferred)
