# Agent setup (tool-agnostic)

This repository is built for **any** coding agent or assistant that can read files and run shell commands: Cursor, GitHub Copilot/Codex, Claude Code, OpenCode, Qwen Code, Windsurf, etc. The harness is **not** Cursor-specific.

## Universal entry points (all agents)

| Priority | Read |
|----------|------|
| 1 | [docs/SAFETY.md](../../docs/SAFETY.md) — non-negotiable before popup/scheduler/config work |
| 2 | [AGENTS.md](../../AGENTS.md) — short map (~100 lines) |
| 3 | [dev-docs/CONTRIBUTING.md](../CONTRIBUTING.md) — clone, hooks, Tier-A |
| 4 | [dev-docs/agent-workflow.md](../agent-workflow.md) — day-to-day steps |
| 5 | Task-specific `dev-docs/` or `docs/` page from the AGENTS table |

**Verify changes:** `./scripts/run-tests.sh --tier a` (same list as CI Tier-A). CI runs on Ubuntu + macOS — see [dev-docs/development/ci.md](dev-docs/development/ci.md).

**Static analysis + Tier-A:** `./scripts/run-security-scan.sh --ci --with-tests`

**Doc drift (warn-only in CI):** `./scripts/check-doc-drift.sh` — use `--strict` before release.

**Invariant IDs:** Hard-block messages cite stable ids — see [invariants.md](invariants.md).

## What is agent-agnostic vs IDE-specific

| Layer | Location | Who uses it |
|-------|----------|-------------|
| **Repo harness** | `AGENTS.md`, `docs/SAFETY.md`, `dev-docs/`, `tests/tiers.yaml`, `scripts/run-tests.sh`, GitHub Actions | **All agents and humans** |
| **Cursor** | `.cursor/rules/*.mdc` | Cursor only — see [Cursor rules (optional)](#cursor-rules-optional) below |
| **Claude Code** | `CLAUDE.md` | Claude Code (points at `AGENTS.md` + safety) |
| **GitHub Copilot** | `.github/copilot-instructions.md` | Copilot in GitHub (points at `AGENTS.md` + safety) |

If your agent has no IDE rules file, **`AGENTS.md` + `dev-docs/` is sufficient.**

## Operational hazards (all agents)

- **Never** run `configure.sh` unbounded — use `timeout`, controlled stdin, bounded output. See `AGENTS.md` and `CLAUDE.md`.
- **Never** edit installed `~/.config/sleep-warning/` during restricted hours; use temp `HOME` for tests.
- On macOS, wizard tests need **bash ≥ 4** (`/opt/homebrew/bin/bash`).

## Test tiers

| Tier | Command | When |
|------|---------|------|
| A | `./scripts/run-tests.sh --tier a` | Every PR; fast headless gate |
| B | `./scripts/run-tests.sh --tier b` | Pre-release; module/configure smokes |
| C | `./scripts/run-tests.sh --tier c` | Prints manual-test doc link only |

Headless CI / sandbox: `CI_HEADLESS=1 ./scripts/run-tests.sh --tier a` skips GUI-only scripts (e.g. `test-darwin-configure-gui.sh`).

Details: [test-tiers.md](../testing-assessments/test-tiers.md)

## Cursor rules (optional)

Only loaded by **Cursor**. Canonical guidance remains in `AGENTS.md` and `dev-docs/`.

### Always on (5)

| Rule | Purpose |
|------|---------|
| `safety-guardrails.mdc` | Per-day caps, popup lifetime, escape hatch, `configure.sh` hazard |
| `config-file-edits.mdc` | No live config edits during restricted hours; temp `HOME` |
| `harness-engineering.mdc` | Map-not-encyclopedia, link to `dev-docs/` |
| `project-conventions.mdc` | Bash facades, backups, ShellCheck, Tier-A tests |
| `codeguard-1-hardcoded-credentials.mdc` | No secrets in source (gitleaks also runs in CI) |

### Requestable (`alwaysApply: false`)

| Rule | When to attach |
|------|----------------|
| `tests.mdc` | Running tests, configure/install harness, test-history notes |
| `codeguard-1-crypto-algorithms.mdc` | Only if adding crypto code (unusual in this bash repo) |
| `codeguard-1-digital-certificates.mdc` | Only if touching certificates |
| Other `codeguard-0-*` | Glob-scoped to non-bash stacks (Django, K8s, etc.) — inactive for typical `lib/*.sh` work |

**Policy:** Generic CodeGuard packs are not `alwaysApply`; they dilute project rules. Re-audit when adding Python/TS services.

## If stuck

Ask what **capability is missing** (doc, test, script, invariant) and add it to git — do not rely on chat-only memory. See [harness-engineering.md](../harness-engineering.md).
