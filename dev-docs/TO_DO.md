# TO_DO — active priorities

Short queue of open work. For full status per enhancement, see [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md). For testing, docs, and master-plan phases, see [REMAINING_WORK_SUMMARY.md](REMAINING_WORK_SUMMARY.md).

## Configure and UI

- [ ] **#16c** — Finish GUI multiple time ranges; test with yad, zenity, and kdialog → [enhancement-16c](enhancements/enhancement-16c-multiple-range-entry-gui.md)
- [ ] **Configure GUI fallback** — Tighten `has_gui()` so configure falls back to text mode when no DISPLAY/Wayland socket
- [ ] **Dialog tools** — Verify popup and pause dialogs with all three tools; no indefinite script block

## Features and safety

- [ ] **Per-day 16 h cap + popup lifetime + escape-hatch bug fixes (2026-05-24 audit)** — Multi-phase plan covering critical lockout-math bypasses (HH:MM parser, head/tail mismatch, lock-hours ignored at runtime), popup lifetime gaps (Linux watchdog, macOS Python-blocker silent failure, osascript min-display), and macOS uninstall/manage escape-hatch fixes. See [plans/plan-real-bugs-fix-2026-05-24.md](plans/plan-real-bugs-fix-2026-05-24.md). Source audit: [code-assessments/bug-and-lockout-review-2026-05-24-203354.md](code-assessments/bug-and-lockout-review-2026-05-24-203354.md). **High priority — these are real bugs that violate the invariants in [docs/SAFETY.md](../docs/SAFETY.md).**
- [ ] **macOS Accessibility API blocking** — Grant Accessibility permission via `System Settings → Privacy & Security → Accessibility` to intercept Cmd+Tab, Mission Control, and Spotlight during restricted hours. Install script should prompt and open the correct pane. See [dev-docs/POPUP_BLOCKING_MACOS.md](POPUP_BLOCKING_MACOS.md) §Option D for implementation sketch. **Deferred** — current fullscreen tkinter overlay (+ optional pyobjc boost) is the primary blocking path.
- [x] **Linux popup watchdog (code, 2026-05-30)** — `lib/popup-display.sh` sources `lib/popup-safety.sh`; Linux uses `popup_compute_watchdog_seconds` + `popup_start_pid_file_watchdog` (PID-file watchdog for respawn path). Unit tests: `tests/test-popup-safety-linux.sh` (alias), `tests/test-popup-safety-darwin.sh` on all platforms.
- [ ] **Linux popup watchdog (verify on Linux build)** — On a Linux host or CI with DISPLAY:
  - [ ] `bash tests/test-popup-safety-linux.sh` and `./scripts/run-security-scan.sh --ci --with-tests`
  - [ ] `bash tests/test-config-locking.sh` and `bash tests/test-uninstall-lock-hours.sh` (portable stat; confirm pass on GNU stat too)
  - [ ] `bash tests/test-popup.sh` with yad/zenity/kdialog available
  - [ ] Add `tests/test-popup-safety-linux-integration.sh` — wedge dialog, assert hard kill within cap (optional but recommended)
  - [ ] Manual: `POPUP_AUTO_CLOSE=false` + stuck dialog → must terminate within `POPUP_ABSOLUTE_MAX_SECONDS`
  - [ ] Update [docs/safety-linux-macos-analysis.md](../docs/safety-linux-macos-analysis.md) §5.1 after verification
  - Plan: [plans/plan-safety-scan-fixes-2026-05-30.md](plans/plan-safety-scan-fixes-2026-05-30.md)
- [ ] **Additional hours on unrestricted days** — Lock/uninstall hours should not apply when a day has no restrictions (opt-in override) → [plan](plans/plan-additional-hours-no-restrictions.md)
- [ ] **#29** — kdialog window size via `--textbox` + `--geometry` → [enhancement-29](enhancements/enhancement-29-kdialog-window-size-control.md)
- [ ] **#10** — Audio alerts → [enhancement-10](enhancements/enhancement-10-audio-alerts.md)

## Testing (high impact)

- [ ] **SteamOS Gaming Mode** — Full validation with full-screen games → [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md), [phase 4 plan](plans/phases/plan-phase-4-testing.md)
- [ ] **Desktop Mode, no external display** — Run test suite on Steam Deck internal display only
- [ ] **Multi-distribution install** — Debian/Ubuntu, Fedora/RHEL, Arch/SteamOS, openSUSE, Alpine → [phase 3 plan](plans/phases/plan-phase-3-installation.md)

## Documentation and release

- [ ] **Licensing** — Select and apply license → [LICENSE_OPTIONS.md](info/LICENSE_OPTIONS.md), [phase 5 plan](plans/phases/plan-phase-5-documentation.md)
- [ ] **#27** — Verify PayPal donation links; Phase 2 GitHub Sponsors after license → [enhancement-27](enhancements/enhancement-27-paypal-donation-links.md)
- [ ] **SteamOS locale docs** — User guide section (Nix + manual paths); do not automate `locale-gen` in install.sh → [REMAINING_WORK_SUMMARY.md](REMAINING_WORK_SUMMARY.md#documentation-work)

## Distribution (lower priority)

- [ ] **#13a** — Single executable installer → [enhancement-13a](enhancements/enhancement-13a-single-executable-installer.md)
- [ ] **#13b** — Desktop GUI wrapper → [enhancement-13b](enhancements/enhancement-13b-desktop-gui-application-wrapper.md)

## Mostly done — finish testing only

Track detail in [REMAINING_WORK_SUMMARY.md](REMAINING_WORK_SUMMARY.md#mostly-implemented-enhancements): #2a, #3, #4, #9, #18, #20, #22, #24, #25, #26, 24/7 + additional hours plan testing.

## Recently completed

- [x] **#30** — Separate timer check interval from popup display frequency (`POPUP_DISPLAY_FREQUENCY`, derived run interval, last-popup-time throttling). Implemented 2026-02-09 → [enhancement-30](enhancements/enhancement-30-separate-timer-check-interval-from-popup-display-frequency.md)

---

**Plans index:** [Master plan](plans/master/linux-warning-system-plan.md) · [Active plans](plans/) · [Completed plans](completed-plans/)

**Last updated:** 2026-05-30
