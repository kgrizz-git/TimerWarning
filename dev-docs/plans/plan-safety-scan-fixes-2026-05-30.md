# Plan: Safety scan fixes (2026-05-30)

**Source scan:** [dev-docs/safety-scans/safety-scan-2026-05-30-011454.md](../safety-scans/safety-scan-2026-05-30-011454.md)

## Goals

1. Close ISSUE-001–003 from the scan on macOS (code + tests).
2. Leave explicit **Linux host** verification on TO_DO (yad/zenity/kdialog spawn).

## Work completed (macOS / repo)

| ID | Fix |
|----|-----|
| ISSUE-001 | Source `lib/popup-safety.sh` from `lib/popup-display.sh`; Linux watchdog uses `popup_compute_watchdog_seconds` + `popup_start_pid_file_watchdog` (shared TERM/KILL policy). |
| ISSUE-002 | `tests/lib/test-stat-mode.sh`; `test-config-locking.sh` and `test-uninstall-lock-hours.sh` use portable stat. |
| ISSUE-003 | `test-manual-uninstall-guide.sh` resolves guide via `PROJECT_DIR`; syntax check trims `wc -l` padding. |
| Tests | Added `tests/test-popup-safety-linux.sh` (alias); `run-security-scan.sh --with-tests` runs popup-safety on all platforms. |

## Linux build checklist (run on Linux machine or CI ubuntu job)

- [ ] `./scripts/run-security-scan.sh --ci --with-tests`
- [ ] `bash tests/test-popup-safety-linux.sh` (unit; same as darwin script)
- [ ] **New:** `bash tests/test-popup-safety-linux-integration.sh` when added — spawn yad or zenity with wedged dialog; confirm kill within `POPUP_ABSOLUTE_MAX_SECONDS`
- [ ] `bash tests/test-config-locking.sh`
- [ ] `bash tests/test-uninstall-lock-hours.sh`
- [ ] `bash tests/test-popup.sh` (if DISPLAY available)
- [ ] Manual: set `POPUP_AUTO_CLOSE=false`, long `POPUP_MIN_DISPLAY_TIME`, confirm dialog dies within watchdog cap
- [ ] Update [docs/safety-linux-macos-analysis.md](../../docs/safety-linux-macos-analysis.md) §5.1 after integration test exists

## Out of scope (this plan)

- Raising `POPUP_ABSOLUTE_MAX_SECONDS` above 120s (separate enhancement).
- Full SteamOS / multi-distro matrix (see TO_DO testing section).

**Last updated:** 2026-05-30
