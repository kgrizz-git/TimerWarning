# Contributing

Thanks for helping improve the Sleep Warning System. This repo is built for humans and coding agents alike — the same harness applies to both.

## Quick start (new clone)

```bash
git clone <repo-url>
cd LinuxTimerWarning

# One-time: repo git hooks (pre-commit ShellCheck + gitleaks on staged files)
./scripts/install-git-hooks.sh

# Optional: run Tier-A before every push (local only)
INSTALL_PRE_PUSH=1 ./scripts/install-git-hooks.sh

# Read the agent map (~2 min)
# open AGENTS.md

# PR gate (headless-safe; matches CI tier-a-tests job)
CI_HEADLESS=1 ./scripts/run-tests.sh --tier a
```

**Safety first:** [docs/SAFETY.md](../docs/SAFETY.md) before any popup, scheduler, or config validation work.

## License

Copyright (c) 2026 kgrizz-git. Source in this repository is licensed under the Apache License, Version 2.0, subject to the Commons Clause License Condition v1.0. The root [`LICENSE`](../LICENSE) file is the terms. This project is source-available. Do not describe it as OSI open source.

Submitting a contribution means you agree the project may include it under those same terms, including the Commons Clause. Apache License 2.0 section 5 would otherwise apply contributions under the Apache License alone. This section is the additional agreement that covers the Commons Clause. Submit only material you can license this way. Material owned by someone else must keep that owner's notices and license, and it must be compatible with distributing this repository under `LICENSE`.

## Documentation map

| Audience | Start |
|----------|-------|
| Agents (any tool) | [AGENTS.md](../AGENTS.md) → [development/agent-setup.md](development/agent-setup.md) |
| Day-to-day workflow | [agent-workflow.md](agent-workflow.md) |
| Tests / tiers | [testing-assessments/test-tiers.md](testing-assessments/test-tiers.md) |
| CI parity | [development/ci.md](development/ci.md) |
| Safety invariant IDs | [development/invariants.md](development/invariants.md) |

## Before you open a PR

1. **Scope** — Smallest correct diff; match existing Bash style in `lib/`.
2. **Platform** — Use `is_darwin` / facades; do not assume systemd on macOS.
3. **Tests** — Use temp `HOME` (`mktemp -d`); never edit live `~/.config/sleep-warning/` during restricted hours.
4. **Verify:**

```bash
CI_HEADLESS=1 ./scripts/run-tests.sh --tier a
./scripts/run-security-scan.sh --ci          # static analysis (Ubuntu CI job)
./scripts/check-doc-drift.sh               # warn-only doc consistency
./scripts/check-file-sizes.sh              # warn on lib/*.sh > 900 lines
```

For `lib/` or entrypoint changes, also run:

```bash
CI=true ./scripts/run-security-scan.sh --ci --with-tests
```

5. **Changelog** — User-visible changes: [CHANGELOG.md](../CHANGELOG.md) under `[Unreleased]` ([development/versioning.md](development/versioning.md)).
6. **Harness notes** — Doc/test/CI-only changes: [harness-changelog.md](harness-changelog.md).

## Git hooks

| Hook | Default | What it does |
|------|---------|----------------|
| **pre-commit** | On after `install-git-hooks.sh` | Prune old `backups/` (5 commits), archive retention report (dry-run), ShellCheck staged `*.sh`, gitleaks staged |
| **pre-push** | Opt-in (`INSTALL_PRE_PUSH=1`) | `CI_HEADLESS=1 ./scripts/run-tests.sh --tier a` (10 min timeout) |

Skip emergencies only:

```bash
SKIP_SHELLCHECK=1 SKIP_GITLEAKS=1 SKIP_ARCHIVE_REPORT=1 git commit -m "..."
```

Doc retention: [development/doc-retention.md](development/doc-retention.md).

Details: [development/security-scanning.md](development/security-scanning.md).

## Pull requests

GitHub loads [`.github/pull_request_template.md`](../.github/pull_request_template.md) automatically. Complete the **Safety** section when touching popups, schedulers, or config validation.

## File size guardrail

Keep `lib/*.sh` facades under **900 lines** (June 2026 refactor target). Exception: `lib/configure-dialogs-darwin.sh` (tkinter daemon; allowlisted).

```bash
./scripts/check-file-sizes.sh          # warn-only
./scripts/check-file-sizes.sh --strict # fail on violations
```

## Cursor-only local state

`.cursor/hooks/state/` (e.g. `continual-learning.json`) is **gitignored** — per-machine Cursor hook bookkeeping, not part of the repo harness. Do not commit it.

## Getting help

- Backlog: [TO_DO.md](TO_DO.md)
- Platform tests: [development/platform-test-matrix.md](development/platform-test-matrix.md)
- Open a PR with the template filled in, or an issue describing platform + repro steps.
