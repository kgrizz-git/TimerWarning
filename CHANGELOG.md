# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Harness engineering docs:** `docs/` system of record, [AGENTS.md](AGENTS.md) as agent map, [docs/harness-engineering.md](docs/harness-engineering.md) (OpenAI article patterns), architecture and agent-workflow pages.
- **Safety discoverability:** [docs/SAFETY.md](docs/SAFETY.md) as #1 priority doc; README safety banner; always-on Cursor rules `safety-guardrails.mdc` and `harness-engineering.mdc`.
- **macOS support (MVP):** Install via `./install.sh` on macOS 13+ using a LaunchAgent (`com.sleep-warning`) and `osascript` warning dialogs with OK + Pause.
- Platform abstraction: `lib/platform.sh`, `lib/service-config-{linux,darwin}.sh`, `lib/scheduler-platform.sh`.
- Safety guardrails on macOS: popup watchdog (`lib/popup-safety.sh`), forced auto-close, capped min display time, duplicate-popup prevention.
- GUI configure subset on macOS (timer, weekdays, weekends, review/save) via `lib/configure-dialogs-darwin.sh`.
- Documentation: [user-docs/MACOS.md](user-docs/MACOS.md) with troubleshooting playbook.
- Tests: `tests/test-platform-darwin.sh`, `tests/test-popup-safety-darwin.sh`.

### Changed

- `update_timer_file()` delegates to platform-specific `update_timer_file_platform()`.
- `configure.sh` / `manage.sh` / `status.sh` / `uninstall.sh` support launchd on Darwin.

## [1.0.0] - (prior releases)

- Linux systemd-based sleep warning system (see README).
