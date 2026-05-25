# AGENTS.md — map for coding agents

**Start here.** This file is a table of contents (~100 lines), not an encyclopedia. Details live under [`docs/`](docs/index.md).

## STOP — read safety first

| Priority | Document |
|----------|----------|
| **#1** | [**docs/SAFETY.md**](docs/SAFETY.md) — per-day 16 h cap (per category), finite popup lifetime, always-available escape hatch; **required before popup/scheduler/config changes** |
| #2 | [docs/core-beliefs.md](docs/core-beliefs.md) |
| #3 | [docs/harness-engineering.md](docs/harness-engineering.md) — OpenAI harness patterns in this repo |

Cursor rules: `.cursor/rules/safety-guardrails.mdc` (always on), `config-file-edits.mdc`, `tests.mdc`.

## Project in one paragraph

Bash sleep-warning system: scheduled checks during restricted hours → modal warning (with pause). **Linux:** systemd + yad/zenity/kdialog. **macOS:** LaunchAgent + osascript. Config: `~/.config/sleep-warning/config/sleep-warning.conf`.

## Where to look (by task)

| Task | Read |
|------|------|
| Any change | [docs/SAFETY.md](docs/SAFETY.md) |
| Architecture / file placement | [docs/architecture/map.md](docs/architecture/map.md) |
| Linux vs macOS | [docs/architecture/platforms.md](docs/architecture/platforms.md) |
| Install / scheduler | `install.sh`, `lib/service-config.sh`, `lib/service-config-{linux,darwin}.sh` |
| Popups | `lib/popup-display.sh`, `lib/popup-safety.sh`, `lib/popup-*-darwin.sh` |
| Configure wizard | `configure.sh`, `lib/configure-*.sh` |
| Tests | [docs/development/testing.md](docs/development/testing.md), `tests/README.md` |
| Versioning / releases | [docs/development/versioning.md](docs/development/versioning.md) |
| Backlog / enhancements | [dev-docs/README.md](dev-docs/README.md), [dev-docs/TO_DO.md](dev-docs/TO_DO.md) |
| macOS users | [user-docs/MACOS.md](user-docs/MACOS.md) |
| Agent workflow | [docs/agent-workflow.md](docs/agent-workflow.md) |

## Platform detection

```bash
# lib/platform.sh
detect_platform   # linux | darwin
is_darwin / is_linux
get_timer_config_path
```

Source platform-specific libs from `sleep-warning.sh` / facades—do not assume systemd on macOS.

## Key paths

| Item | Path |
|------|------|
| Config | `~/.config/sleep-warning/config/sleep-warning.conf` |
| Libraries | `lib/` (installed: `~/.local/lib/sleep-warning/`) |
| Binaries | `~/.local/bin/sleep-warning*` |
| Linux timer | `~/.config/systemd/user/sleep-warning.timer` |
| macOS agent | `~/Library/LaunchAgents/com.sleep-warning.plist` |

## Safety code (do not bypass)

- `lib/popup-safety.sh` — absolute watchdog (must wrap every spawn path); cap value may grow but is always finite
- `lib/configure-validation.sh` — per-day per-category 16 h cap (hard block, no override)
- `sleep-warning.sh` — `validate_config_safety()` runtime fallback enforcing the same per-day per-category cap
- `lib/popup-pid-management.sh` — no stacked modals
- Intentional lockout behaviors (focus stealing, topmost, fullscreen blocker, respawn-on-dismiss during min-display) are **features**, not bugs — see [docs/SAFETY.md](docs/SAFETY.md) "What is *not* a safety bug"

## Testing quick reference

- Temp `HOME` for install/configure tests
- `bash tests/test-popup-safety-darwin.sh`
- `bash tests/test-platform-darwin.sh`
- Never edit installed config during restricted hours

## Harness engineering

We follow [OpenAI harness engineering](https://openai.com/index/harness-engineering/): repo-local knowledge, mechanical invariants, map-not-encyclopedia. See [docs/harness-engineering.md](docs/harness-engineering.md).

## After you ship a change

1. Run targeted tests.
2. Update `docs/` + [CHANGELOG.md](CHANGELOG.md) if behavior changed ([versioning guide](docs/development/versioning.md)).
3. Confirm [SAFETY.md](docs/SAFETY.md) checklist still passes.

## Git hooks (local)

After clone, enable repo hooks once:

```bash
./scripts/install-git-hooks.sh
```

**pre-commit** runs [scripts/prune-backups.sh](scripts/prune-backups.sh) — removes tracked files in `backups/` whose last git commit is more than **3** commits behind `HEAD`, then stages deletions. Untracked backups are kept. Preview: `./scripts/prune-backups.sh --dry-run`.
