# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
