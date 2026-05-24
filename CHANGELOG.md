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

- **AGENTS.md** tracked in git again (removed from `.gitignore`).

- `update_timer_file()` delegates to platform-specific `update_timer_file_platform()`.
- `configure.sh` / `manage.sh` / `status.sh` / `uninstall.sh` support launchd on Darwin.

## [1.0.0] - (prior releases)

- Linux systemd-based sleep warning system (see README).
