# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Safety scan template:** Expanded `dev-docs/templates/safety-scan-template.md` — aligned with `docs/SAFETY.md` (per-day caps, partial lock, popup watchdog), scan tiers A/B/C, automated tooling (ShellCheck, Semgrep, Gitleaks/TruffleHog, git hooks, Dependabot when CI exists), and regression test matrix.
- **Security automation:** `scripts/run-security-scan.sh`, `scripts/pre-commit-checks.sh` (ShellCheck + gitleaks on staged files), `.gitleaks.toml`, `.semgrep/sleep-warning.yml`, GitHub Actions [`.github/workflows/security.yml`](.github/workflows/security.yml), Dependabot for Actions [`.github/dependabot.yml`](.github/dependabot.yml). Docs: [docs/development/security-scanning.md](docs/development/security-scanning.md).
- **Security scan tuning:** Fixed `.gitleaks.toml` for gitleaks 8.30+ (`[[allowlists]]`); Semgrep uses project rules only (`p/bash` 404); ShellCheck CI scope excludes `tests/` and uses `-S error` on production scripts.

- **Partial configure during lock hours (tighten-only):** When configure-block or config-file lock is active, `configure.sh` and **Configure** in `manage.sh` open the wizard in limited mode instead of exiting. Users may increase lockout (more frequent popups, longer min display, add-only hours, enable locks) but not weaken existing settings. `POPUP_AUTO_CLOSE` may be toggled freely. Saves still enforce per-day 16 h caps and weekly backstop; config writes temporarily unlock chmod-locked files when needed. New module `lib/configure-partial-lock.sh`; tests `tests/test-configure-partial-lock.sh`.

### Changed

- **macOS configure wizard: menus/prompts share the tkinter daemon:** `show_list_dialog` now renders through the dialog daemon (new `configure_dialogs_darwin_list_ui.py`, daemon `list` op) instead of osascript `choose from list`. The main menu, every submenu, all true/false & yes/no-via-confirm prompts, and the weekly grid now run as one tkinter process on one root — consistent z-order, no per-prompt osascript spawn, and the daemon root is reused. Falls back to `choose from list` when tkinter is unavailable, `CONFIGURE_DARWIN_NO_DAEMON=1`, the daemon fails, or the window never maps (`shown=false`). Leaf alerts (info/error/question/text-entry) still use osascript. No menu-building code changed; the return contract (selected item text, non-zero on cancel) is unchanged.

- **macOS configure wizard performance:** Session cache for `has_dialog_tool` / `get_dialog_tool` (Darwin skips X11/Wayland display probing). Main menu no longer re-greps config or leaks temp files; weekly grid caches formatted hour strings until hour arrays change. Long-lived `configure-dialogs-darwin-daemon.py` keeps one tkinter root for table/time/text dialogs (one-shot Python fallback if daemon fails). Set `CONFIGURE_PROFILE=1` for per-dialog `prep_ms` / `ui_ms` on stderr. Fix circular nameref warnings in `_configure_build_grid_cache`.

- **macOS install:** `install-darwin.sh` sources `config.sh` before reading popup interval for LaunchAgent setup (fixes `get_check_interval: command not found`). `--force` messaging now states explicitly that `sleep-warning.conf` is preserved (programs and scheduler files are updated).

- **`tests/test-configure-blocking.sh`:** Integration test updated for partial-lock behavior (limited-mode banner, loosening rejected, tightening save allowed) instead of expecting immediate exit. New portable watchdog helper `tests/lib/test-run-timeout.sh` (GNU `timeout` / `gtimeout` when present, bash fallback otherwise).
- **`scripts/pre-commit-checks.sh`:** ShellCheck now matches CI (`-S error`, skips `backups/` and `tests/`) so commits are not blocked by style/info findings in snapshot backups or test helpers.

- **macOS configure wizard: dialogs open in front:** Tk windows use shared `configure_dialogs_darwin_window.apply_initial_frontmost()` (topmost + focus on open, drop topmost when focus leaves). AppleScript dialogs call `tell current application to activate` before `display alert`, `display dialog`, and `choose from list`.

- **macOS LaunchAgent fullscreen popup:** LaunchAgent plist now sets `LimitLoadToSessionType=Aqua` and a usable `PATH` so Tk can attach to the GUI session. `popup-blocker-darwin.py` falls back to borderless full-screen geometry (and Cocoa frame resize when pyobjc is available) when `-fullscreen` is ignored under launchd. Blocker uses `~/.config/sleep-warning/blocker-python.path` from install/configure.

- **macOS popup UI path logging:** Each popup now logs `macOS popup UI: fullscreen-blocker` or `osascript-alert` at open time (with `reason=` and PID verification). Session end logs include `ui=` and `reason=`. Python blocker stderr is appended to `~/.config/sleep-warning/logs/popup-blocker-stderr.log` for LaunchAgent diagnosis when logs showed success but the movable alert appeared.

### Fixed

- **Popup interval message:** Warning popup text ("This warning will appear every X minutes") now uses `POPUP_DISPLAY_FREQUENCY` via `get_popup_display_frequency()`, matching configure wizard output and runtime throttling. Previously the message read legacy `CHECK_INTERVAL` only and defaulted to 10 minutes when the wizard had written only `POPUP_DISPLAY_FREQUENCY`. `get_check_interval()` now delegates to `get_popup_display_frequency()`. macOS duplicate-popup age check aligned with Linux. Test: `tests/test-popup-interval-message.sh`.

- **Configure wizard no longer spins forever on EOF stdin (cross-platform):** a new
  `configure_read` helper ([lib/configure-core.sh](lib/configure-core.sh)) replaces
  every interactive `read -p`/`read -rp` across the wizard
  (`configure-display.sh`, `configure-ui.sh`, `configure-input-*.sh`,
  `configure-workflow.sh`). When stdin is closed/non-interactive (e.g.
  `configure.sh --text` backgrounded with redirected output and no terminal), the
  old loops re-read instantly at EOF and spun forever — pegging a CPU and growing
  the redirected file without bound (this filled a disk with ~465 GB of `/tmp`
  files). `configure_read` aborts cleanly on EOF (`CANCELLED`, exit 2) while
  leaving normal interactive behaviour unchanged (a blank Enter is not EOF).
  `manage.sh` had the same menu-loop hazard and is fixed too (converted reads +
  its outer loop now breaks when `show_menu_text` aborts on EOF).
  `uninstall-verification.sh` and `manual-uninstall-guide.sh` already treated
  empty input as cancel and were left as-is; popup/runtime loops
  (`popup-display.sh`, `popup-safety.sh`, `window-management.sh`) are bounded
  (watchdog counters + sleep gates) and `sleep-warning.sh` runs once per tick.
  Bash-portable; applies to Linux and macOS. See [CLAUDE.md](CLAUDE.md) /
  [AGENTS.md](AGENTS.md) for safe-run rules.

- **macOS weekly-hours window lingered after "Back to Main Menu":** Cancelling/closing the 4-column tkinter grid no longer re-opens it. The daemon now reports whether the dialog window actually became visible (`shown`), so `_cd_darwin_show_table_dialog` only triggers the one-shot Tk fallback on a genuine invisible-mapping failure — not on a normal cancel. Previously every cancel looked identical to a daemon failure and spawned a duplicate one-shot window that sat behind the osascript main menu. `show_table_dialog()` now returns `(accepted, value, exit_code, shown)`.

- **macOS configure table dialog visibility:** Weekly grid (4-column tkinter table) now deiconifies daemon `Toplevel` windows and waits via `root.wait_window(dialog)`; removed `transient(withdrawn_root)` which could suppress the window on macOS. If the daemon path still fails, table dialogs automatically fall back to one-shot `configure-dialogs-darwin-table.py`.

- **macOS configure GUI regression tests:** Headless suite `tests/test-darwin-configure-gui.sh` — weekly grid cache (nameref, invalidation, inherited hours), table JSON payload (non-empty rows), daemon stdin/stdout protocol, and static/runtime checks that tkinter dialogs use `wait_window()` on daemon `Toplevel` (not `mainloop()`, which caused blank windows).

- **macOS configure daemon empty dialogs:** Tkinter table/time/text dialogs in `configure-dialogs-darwin-daemon.py` now use `wait_window()` on `Toplevel` windows instead of `mainloop()` (which showed blank windows on macOS when the hidden root was withdrawn). One-shot CLI dialogs still use `mainloop()` on `Tk()`.

- **Safety scan follow-up (2026-05-30):** Linux popup path now sources `lib/popup-safety.sh` and uses `popup_compute_watchdog_seconds` with shared `popup_start_pid_file_watchdog` (PID-file kill policy). Tests: portable `tests/lib/test-stat-mode.sh` for config-locking and uninstall-lock-hours; `test-manual-uninstall-guide.sh` resolves paths from repo root; `tests/test-popup-safety-linux.sh` alias. Plan: [dev-docs/plans/plan-safety-scan-fixes-2026-05-30.md](dev-docs/plans/plan-safety-scan-fixes-2026-05-30.md).

- **Popup "next unrestricted time: now (no restrictions configured)" with HH:MM config:** `build_weekly_restricted_intervals()` only accepted integer-hour ranges (`7-23`), so configure-wizard `HH:MM` values (e.g. `17:00-17:30`) were skipped and `get_next_unrestricted_time()` thought no restrictions existed. Endpoints now parse `HH:MM` as well as `HH`. Shared helpers `range_endpoint_to_day_minutes()`, `range_is_overnight()`, and `range_overnight_tail_active_for_hour()` live in `lib/time-parsing.sh`; `lib/configure-ui.sh` overnight/carry checks use them instead of raw `cut -d'-'` integer comparisons.

- **macOS fullscreen popup: unreadable disabled OK button:** Tk on macOS drew disabled buttons with light chrome and white label text. Set `disabledforeground` and explicit `fg` when the OK button is locked during min-display time.

- **macOS resume grace period: MaintenanceWake false positive:** `pmset -g log` parsing matched any line containing `Wake`, including routine `MaintenanceWake` assertion churn (~every 90s while idle). That suppressed scheduled popups for 60s after background power events even when the user had not slept or rebooted. Wake detection now only treats pmset event type `Wake` (excluding `Wake Requests`) as a user sleep/wake resume.

- **Configure wizard: `printf: 30PM: invalid number` on macOS:** `format_range_human()` parsed `11:30PM` with a naive `cut` on `:`, leaving `30PM` as the minute. It now uses `parse_time_token_to_24h_hm()` so 12-hour tokens from the macOS picker or config (e.g. `11:30PM-5:30AM`) format without shell errors. `normalize_time_range()` fallback also converts 12-hour parts instead of passing them through unchanged.
- **macOS scheduled popup → notification only:** `configure-core.sh` defines `readonly DARWIN_MAX_MIN_DISPLAY_TIME`; `popup-safety.sh` tried to assign it again, aborting load of `popup_run_with_watchdog` so LaunchAgent runs fell back to a notification. Skip reassignment when the variable already exists.

- **Configure wizard: `printf: 01 00: invalid octal number`:** `format_ranges_human()` sets `IFS=','` before calling `format_range_human()`, so a `read` on space-separated `01 00` left the hour as `01 00`. Splitting now uses `_split_24h_hm_parts()` (parameter expansion, IFS-safe). `24hour_to_12hour()` also uses `10#` arithmetic for leading-zero hours.

- **macOS GUI: remove range appeared to do nothing:** After selecting a range to remove, the confirmation step used `display alert`, which on macOS 13+ opens behind the terminal following a `choose from list` dialog — so the user never saw the prompt and removal never ran. New `show_confirm_dialog()` uses `choose from list` on macOS (same pattern as `confirm_cancel`). Applied to range removal and time-range confirmation in the configure wizard.

### Changed — weekly-average lockout thresholds tightened (2026-05-24, evening pass)

- `lib/configure-core.sh`: `HOURS_PER_DAY_BLOCK` lowered from **24 → 16** and `HOURS_PER_DAY_WARN` lowered from **16 → 12**. Comparison in `check_restriction_coverage` switched to strict `>` so configurations that exactly max the per-day 16-hour cap on every day (= 6720 min/week) still pass at the weekly check — the per-day cap (`lib/daily-caps.sh`) remains the primary hard enforcer; the weekly check is a defense-in-depth backstop.
- New effective thresholds:
  - **OK**: weekly total ≤ 5040 min (≤ 12 h/day avg)
  - **WARN**: 5040 < weekly total ≤ 6720 min (12-16 h/day avg)
  - **BLOCK**: weekly total > 6720 min (> 16 h/day avg)
- **Migration:** Configurations whose weekly average previously fell in 16-24 h/day are now hard-blocked at the weekly check; users with such configs will be prompted at next `sleep-warning-configure` run. Runtime fallback in `validate_config_safety` covers the same case.
- Test expectations updated in `tests/test-24-7-prevention-additional-hours.sh` (37/37 pass).

### Fixed (bug-fix plan 2026-05-24 — Phases 0–4, including 3.4)

The following bugs, identified in [dev-docs/code-assessments/bug-and-lockout-review-2026-05-24-203354.md](dev-docs/code-assessments/bug-and-lockout-review-2026-05-24-203354.md), have been corrected. All changes are enforced by new and existing tests.

**Phase 0 — Per-day 16 h cap helpers**
- `lib/daily-caps.sh`: new `compute_daily_minutes_by_category` and `check_daily_caps` functions that merge overlapping intervals per (day, category) using `10#`-safe arithmetic. Handles both `HH-HH` and `HH:MM-HH:MM` formats, overnight wrap-around, and merged configure-block = lock hours ∪ restriction hours.
- `lib/configure-validation.sh`: `check_restriction_coverage` now delegates to `check_daily_caps`. Hard-blocks any config where a single day in any category exceeds 960 minutes (16 h). Removed the "save anyway" override for cap violations.
- `tests/test-daily-caps.sh`: 42-test suite covering all cap scenarios — restriction, configure-block, uninstall-block, overlapping ranges, overnight ranges, octal-safe parsing, and boundary conditions.

**Phase 1 — Lockout arithmetic**
- `lib/time-parsing.sh`: `convert_time_range_to_24hour` now rejects hours > 23 or minutes > 59 and uses `10#` prefix on all user-derived arithmetic to eliminate the octal trap.
- `configure.sh`: Re-checks configure-block lock immediately before calling `write_config`, preventing a race where a user starts the wizard in a free period but crosses into a lock window before saving. Added `SIGINT`/`SIGTERM` trap to clean up temp files.
- `sleep-warning.sh`: `validate_config_safety` runtime fallback now includes the lock/uninstall categories via `check_daily_caps`. `show_warning` overnight-carry logic restructured so previous-day ranges are always evaluated, not skipped when the current day also has ranges (fixes under-restriction edge case).

**Phase 2 — Popup lifetime**
- `lib/popup-display.sh`: Added `flock` around the `is_popup_running → spawn → save_popup_pid` critical section on Linux to prevent race conditions that created stacked modals. Spawns an absolute-watchdog background subshell that reads `POPUP_PID_FILE` dynamically (follows PID changes from countdown redraws) and kills the popup after `POPUP_ABSOLUTE_MAX_SECONDS`.
- `lib/popup-dialog-implementations-darwin.sh`: Python blocker spawn now does a `sleep 0.3` + `kill -0` liveness check; if the process exited immediately (e.g. missing `pyobjc`), logs the exit code and falls back to osascript. `_popup_spawn_osascript_darwin` now enforces `min_display_time` via a re-spawn loop and applies `giving up after` auto-close on the final presentation; a `trap` in the background subshell kills the inner osascript on `SIGTERM`.
- `lib/popup-pid-management.sh`: `is_popup_running` on macOS now includes secondary detection via `pgrep -f` for `python3.*popup-blocker-darwin.py` and `osascript.*ALERT`, preventing stacked popups when the PID file is stale.

**Phase 3 — Escape hatches**
- `uninstall.sh`: `is_installed` now checks for the macOS LaunchAgent plist. `verify_removal` checks that the plist is gone **and** that `launchctl print` confirms the agent is no longer loaded; prints a manual-fix hint if not.
- `lib/service-config-darwin.sh`: `remove_launch_agent` surfaces `launchctl bootout` failures instead of masking them with `|| true`; returns non-zero if the agent is still loaded after bootout attempts.
- `manage.sh`: `disable_service` and `enable_service` now capture and surface the real exit status of the scheduler stop/disable commands. The configure-block check is now per-action: "Disable Service" is always permitted (escape hatch); only "Configure Restricted Hours" is gated by the lock.
- **Phase 3.4 (new):** `install.sh --force` now detects a *currently disabled* scheduler (systemd `disabled`/`masked` state, or unloaded macOS LaunchAgent) and prompts before re-enabling. New CLI flags `--re-enable` and `--no-re-enable` skip the prompt for scripted use. With `--yes`, defaults to leaving disabled (safest). macOS implementation in `lib/install-darwin.sh` writes the plist but skips `launchctl bootstrap` when the user declines.

**Phase 4 — UX and correctness**
- `lib/configure-dialogs-darwin.sh`: `show_question_dialog` now passes `yes_label` and `no_label` through to the AppleScript as `argv` items so dialogs display custom button text.
- `lib/popup-dialog-implementations.sh` (kdialog): Uses `--warningyesno` with custom "Pause N min" / "Dismiss" buttons when pause is available; pause handler interprets exit code 0 as the Pause button and uses the configured `pause_duration`.
- `lib/sleep-detection-darwin.sh`: `check_system_resume` now emits the resume epoch timestamp to stdout and detects sleep/wake events by parsing `pmset -g log` for "Wake" entries, not just boot-time changes.
- `tests/test-24-7-prevention-additional-hours.sh`: 11 new test cases covering HH:MM ranges, 17 h/day warn threshold, split-range 24/7 detection, overnight HH:MM, octal-safe inputs (08, 09), and lock+restriction merging.

### Changed

- **Safety model clarified (docs only — no code change yet):** [docs/SAFETY.md](docs/SAFETY.md), [.cursor/rules/safety-guardrails.mdc](.cursor/rules/safety-guardrails.mdc), and [AGENTS.md](AGENTS.md) restated around three invariants — **per-day 16 h cap per category** (restriction / configure-block / uninstall-block, merged, no double-count), **finite popup lifetime** (cap value may grow but is always bounded by `popup_run_with_watchdog`), and **always-available escape hatch**. Intentional lockout behaviors (focus stealing, `--topmost`, fullscreen overlay, periodic `focus_force`, respawn-on-dismiss during min-display) are explicitly **features**, not safety bugs. Older language implying "no stuck modals" / "no 24/7" was too narrow; the real invariant is per-day per-category cap.

### Added

- **Bug-and-lockout audit (2026-05-24):** [dev-docs/code-assessments/bug-and-lockout-review-2026-05-24-203354.md](dev-docs/code-assessments/bug-and-lockout-review-2026-05-24-203354.md) — 35 findings across configure validation, popup display, scheduler, install/uninstall, and time math.
- **Bug-fix plan derived from that audit:** [dev-docs/plans/plan-real-bugs-fix-2026-05-24.md](dev-docs/plans/plan-real-bugs-fix-2026-05-24.md) — five phases (helpers → lockout math → popup lifetime → escape hatches → UX → verify) with acceptance criteria and test matrix.
- **Versioning guide:** [docs/development/versioning.md](docs/development/versioning.md) — semver bump rules, CHANGELOG workflow, release tagging; linked from [AGENTS.md](AGENTS.md) and [docs/index.md](docs/index.md).
- **`dev-docs/` organization:** [dev-docs/README.md](dev-docs/README.md) map, [dev-docs/TO_DO.md](dev-docs/TO_DO.md) priority queue; restructured [FUTURE_ENHANCEMENTS.md](dev-docs/FUTURE_ENHANCEMENTS.md) and [REMAINING_WORK_SUMMARY.md](dev-docs/REMAINING_WORK_SUMMARY.md); subfolders `plans/master/`, `plans/phases/`, `notes/`, `fixes/`, `alternatives/`; linked from [docs/index.md](docs/index.md).
- **Harness engineering docs:** `docs/` system of record, [AGENTS.md](AGENTS.md) as agent map, [docs/harness-engineering.md](docs/harness-engineering.md) (OpenAI article patterns), architecture and agent-workflow pages.
- **Safety discoverability:** [docs/SAFETY.md](docs/SAFETY.md) as #1 priority doc; [docs/safety-linux-macos-analysis.md](docs/safety-linux-macos-analysis.md) (Linux vs macOS gap analysis); README safety banner; always-on Cursor rules `safety-guardrails.mdc` and `harness-engineering.mdc`.
- **macOS support (MVP):** Install via `./install.sh` on macOS 13+ using a LaunchAgent (`com.sleep-warning`) and `osascript` warning dialogs with OK + Pause.
- Platform abstraction: `lib/platform.sh`, `lib/service-config-{linux,darwin}.sh`, `lib/scheduler-platform.sh`.
- Safety guardrails on macOS: popup watchdog (`lib/popup-safety.sh`), forced auto-close, capped min display time, duplicate-popup prevention.
- GUI configure subset on macOS (timer, weekdays, weekends, review/save) via `lib/configure-dialogs-darwin.sh`.
- Documentation: [user-docs/MACOS.md](user-docs/MACOS.md) with troubleshooting playbook.
- Tests: `tests/test-platform-darwin.sh`, `tests/test-popup-safety-darwin.sh`.
- **Git hooks:** `.githooks/pre-commit` + [scripts/prune-backups.sh](scripts/prune-backups.sh) (prune tracked `backups/` older than 3 commits); enable with [scripts/install-git-hooks.sh](scripts/install-git-hooks.sh).

### Changed

- **macOS configure main menu / Review and Save:** Scrollable tkinter summary with **Yes, Save** / **Back to Main Menu** on the same window (fixes save step failing when a second `osascript` alert ran after tkinter). Main-menu Cancel offers “Exit without saving” vs “Continue configuring”. Empty OK on the menu no longer jumps to Review and Save.
- **GUI dead-end loop fixes (all platforms):** All three cancel menus (`handle_main_menu_cancel_menu`, `handle_window_behavior_cancel_menu`, `_handle_day_hours_cancel_menu`) now treat a dismissed cancel-menu as "Continue" instead of looping forever. Grid option 9 calls `exit 0` on confirmed cancel, same as options 3/4/6/7/8. `get_day_hours` Phase 2 "Continue configuring" re-shows the manage-ranges dialog instead of falling into Phase 1 fresh-entry.
- **Cancel menu UX / day-hours navigation (macOS):** "Cancel configuration" in the day-hours cancel menu no longer shows a second confirm dialog (the list selection itself is the confirmation). "Go back to previous day" is now hidden on the first day of each section (Monday, Saturday) where there is no previous day — it previously navigated silently to the main menu. `_cd_darwin_json_escape` rewritten in pure bash (no per-string Python subprocess); `_cd_darwin_has_tkinter` result is now cached — both reduce View Weekly Hours startup from ~3–5 s to under 1 s.
- **macOS fullscreen blocking popup:** Replaced `osascript display alert` (easy-to-ignore notification) with a full-screen dark overlay (`lib/popup-blocker-darwin.py`). The overlay covers the entire display, disables the OK button until the configured minimum display time elapses (live countdown shown), and auto-closes per the configured delay. When `pyobjc-core` + `pyobjc-framework-Cocoa` are installed (`pip3 install pyobjc-core pyobjc-framework-Cocoa`), the window is raised to `NSScreenSaverWindowLevel` with `CanJoinAllSpaces + FullScreenAuxiliary` so it stays above fullscreen Spaces. The osascript alert is retained as automatic fallback. Pause button and result-file handling are unchanged. See [dev-docs/POPUP_BLOCKING_MACOS.md](dev-docs/POPUP_BLOCKING_MACOS.md) for option comparison and future Accessibility API work.
- **macOS `confirm_cancel` z-order fix (all remaining call sites):** `confirm_cancel` now uses `show_list_dialog` (`choose from list`) on macOS instead of `show_question_dialog` (`display alert`). On macOS 13+, `display alert` appears behind the terminal after any list/entry dialog closes; `choose from list` always appears in front. This fixes all 9 remaining call sites where pressing Cancel on any setting dialog (pause, block/lock, check interval, security, dialog-tool selection, "What to edit?") appeared to reload the same window instead of offering the exit choice.
- **macOS time entry & range editor:** tkinter hour/minute/AM-PM picker (Linux yad parity); multi-range Add/Edit/Remove uses shared `manage_ranges_dialog` (no longer stubbed).
- **macOS configure dialogs:** Literal `\n` in prompts now render as line breaks; min display time wizard uses `get_max_min_display_time_limit()` (60s cap on macOS vs 300s on Linux).
- **Window Behavior GUI cancel UX:** Shared cancel menu (return to submenu / continue / quit wizard); friendly Yes/No labels for immovable and auto-close; macOS immovable marked Linux-only.
- **macOS weekly hours grid:** Fixed jumbled four-column view (header row mixed with data); uses tkinter table dialog aligned with Linux yad/zenity layout (1050×500).
- **macOS configure cancel flow:** Fixed cancel on time-range entry → “Cancel configuration” looping back to time entry (AppleScript Yes/No buttons; shared cancel menu helper).
- **macOS bash 4+:** System bash 3.2 is insufficient (`declare -A`, `local -n`). Install re-execs via Homebrew bash; LaunchAgent runs `bash` + script; `get_default_hours_for_day()` replaces associative array in `config.sh`.
- **AGENTS.md** tracked in git again (removed from `.gitignore`).

- `update_timer_file()` delegates to platform-specific `update_timer_file_platform()`.
- `configure.sh` / `manage.sh` / `status.sh` / `uninstall.sh` support launchd on Darwin.

## [1.0.0] - (prior releases)

- Linux systemd-based sleep warning system (see README).
