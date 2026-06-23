# AGENTS.md — map for coding agents

**Start here.** This file is a table of contents (~100 lines), not an encyclopedia. **User safety:** [`docs/`](docs/index.md). **Developer / agent detail:** [`dev-docs/`](dev-docs/README.md).

## STOP — read safety first

| Priority | Document |
|----------|----------|
| **#1** | [**docs/SAFETY.md**](docs/SAFETY.md) — per-day 16 h cap (per category), finite popup lifetime, always-available escape hatch; **required before popup/scheduler/config changes** |
| #2 | [dev-docs/core-beliefs.md](dev-docs/core-beliefs.md) |
| #3 | [dev-docs/harness-engineering.md](dev-docs/harness-engineering.md) — OpenAI harness patterns |

> ⛔ **Operational hazard — never run `configure.sh` (or `lib/configure-*.sh`
> prompts) unbounded.** Its text-mode read loops spin forever on EOF stdin (no
> terminal + no input), pegging a CPU and growing redirected output WITHOUT
> bound — this once produced ~465 GB of `/tmp` files and filled the disk. Always
> run with **all three**: a `timeout`, controlled stdin (`</dev/null` or finite
> valid input), and bounded output. Then `pkill -f configure.sh` and remove temp
> files. Never `./configure.sh ... > out.txt 2>&1 &` and walk away.

Cursor rules: `.cursor/rules/safety-guardrails.mdc` (always on), `config-file-edits.mdc`, `tests.mdc`.

## Project in one paragraph

Bash sleep-warning system: scheduled checks during restricted hours → modal warning (with pause). **Linux:** systemd + yad/zenity/kdialog. **macOS:** LaunchAgent + osascript. Config: `~/.config/sleep-warning/config/sleep-warning.conf`.

## Where to look (by task)

| Task | Read |
|------|------|
| Any change | [docs/SAFETY.md](docs/SAFETY.md) |
| Architecture / file placement | [dev-docs/architecture/map.md](dev-docs/architecture/map.md) |
| Linux vs macOS | [dev-docs/architecture/platforms.md](dev-docs/architecture/platforms.md) |
| Install / scheduler | `install.sh`, `lib/service-config.sh`, `lib/service-config-{linux,darwin}.sh` |
| Popups | `lib/popup-display.sh`, `lib/popup-display-linux.sh`, `lib/popup-safety.sh`, `lib/popup-*-darwin.sh` |
| Configure wizard | [dev-docs/architecture/configure-flow.md](dev-docs/architecture/configure-flow.md), `configure.sh`, `lib/configure-*.sh` |
| Tests | [dev-docs/development/testing.md](dev-docs/development/testing.md), [platform-test-matrix.md](dev-docs/development/platform-test-matrix.md), `tests/README.md` |
| Security scans (ShellCheck, Gitleaks, Semgrep) | [dev-docs/development/security-scanning.md](dev-docs/development/security-scanning.md), `scripts/run-security-scan.sh` |
| Versioning / releases | [dev-docs/development/versioning.md](dev-docs/development/versioning.md) |
| Backlog / enhancements | [dev-docs/README.md](dev-docs/README.md), [dev-docs/TO_DO.md](dev-docs/TO_DO.md) |
| macOS users | [user-docs/MACOS.md](user-docs/MACOS.md) |
| Agent workflow (any tool) | [dev-docs/development/agent-setup.md](dev-docs/development/agent-setup.md), [dev-docs/agent-workflow.md](dev-docs/agent-workflow.md) |

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
- `lib/daily-caps.sh` — primary per-day 16 h cap math (`check_daily_caps`)
- `lib/safety-invariants.sh` — stable invariant IDs for hard-block messages ([invariants catalog](dev-docs/development/invariants.md))
- `lib/configure-validation.sh` — per-day 16 h cap (hard block, no override)
- `lib/daily-caps.sh` — primary per-day 16 h cap math (`check_daily_caps`)
- `lib/configure-partial-lock.sh` — tighten-only configure wizard during lock hours (see [docs/SAFETY.md](docs/SAFETY.md))
- `lib/config-locking.sh` — config file chmod lock; wizard save unlock/re-lock
- `sleep-warning.sh` — `validate_config_safety()` runtime fallback enforcing the same per-day per-category cap
- `lib/popup-pid-management.sh` — no stacked modals
- Intentional lockout behaviors (focus stealing, topmost, fullscreen blocker, respawn-on-dismiss during min-display) are **features**, not bugs — see [docs/SAFETY.md](docs/SAFETY.md) "What is *not* a safety bug"

## Testing quick reference

- [Platform test matrix](dev-docs/development/platform-test-matrix.md) — macOS vs Linux, headless vs GUI
- **Tier-A (all agents / CI):** `./scripts/run-tests.sh --tier a` — manifest: `tests/tiers.yaml`
- Temp `HOME` for install/configure tests
- `bash tests/test-configure-partial-lock.sh`
- `bash tests/test-popup-safety-darwin.sh`
- `bash tests/test-platform-darwin.sh`
- Never edit installed config during restricted hours

## Harness engineering

We follow [OpenAI harness engineering](https://openai.com/index/harness-engineering/): repo-local knowledge, mechanical invariants, map-not-encyclopedia. See [dev-docs/harness-engineering.md](dev-docs/harness-engineering.md).

## After you ship a change

1. Run targeted tests (`./scripts/run-tests.sh --tier a` or relevant script).
2. For `lib/` or entrypoint script changes: `./scripts/run-security-scan.sh --ci --with-tests` (or at least `--ci`).
3. Update [docs/SAFETY.md](docs/SAFETY.md) and/or `dev-docs/` if behavior changed ([versioning guide](dev-docs/development/versioning.md)).
4. Confirm [docs/SAFETY.md](docs/SAFETY.md) checklist still passes.

## Git hooks (local)

After clone, enable repo hooks once:

```bash
./scripts/install-git-hooks.sh
# Optional: INSTALL_PRE_PUSH=1 ./scripts/install-git-hooks.sh
```

**pre-commit** runs [scripts/pre-commit-checks.sh](scripts/pre-commit-checks.sh): prune tracked `backups/` older than **5** commits, report-only dev-docs archive retention check, ShellCheck on staged `*.sh`, and `gitleaks protect --staged` when those tools are installed. **pre-push** (opt-in) runs Tier-A via [scripts/pre-push-checks.sh](scripts/pre-push-checks.sh). Doc retention: [dev-docs/development/doc-retention.md](dev-docs/development/doc-retention.md).

Contributor guide: [dev-docs/CONTRIBUTING.md](dev-docs/CONTRIBUTING.md). Full scan: [scripts/run-security-scan.sh](scripts/run-security-scan.sh). Details: [dev-docs/development/security-scanning.md](dev-docs/development/security-scanning.md).

## Learned User Preferences

- Archive superseded implementation plans under `dev-docs/completed-plans/` (the repo's established archive, not a separate deferred folder).
- Keep `AGENTS.md` as a brief map; agent/harness detail belongs in `dev-docs/`, not in root `AGENTS.md`.
- Harness engineering Phases 1–2 and 4 complete; follow [dev-docs/plans/plan-harness-engineering-improvements-2026-06-12.md](dev-docs/plans/plan-harness-engineering-improvements-2026-06-12.md) for Phase 3+.

## Learned Workspace Facts

- Doc boundary: `docs/` is for end-users (safety, user-oriented reference); `dev-docs/` is for developers and coding agents (plans, assessments, harness workflow, backlog).
- June 2026 refactor is complete; active harness backlog is in [dev-docs/TO_DO.md](dev-docs/TO_DO.md) under "Harness engineering (active — post-refactor)".
- `.cursor/hooks/state/` is local runtime cache (gitignored); durable agent memory belongs in `AGENTS.md`, not hook state files.
- Refactor line-count target for `lib/*.sh` is ~900 lines (documented allowlist exceptions in refactor/harness plans).
