# Security scanning

Static analysis and secret scanning for this bash project. Complements [docs/SAFETY.md](../../docs/SAFETY.md) (runtime lockout invariants) and the manual [safety scan template](../templates/safety-scan-template.md).

## Quick start

```bash
# After clone — enable git hooks
./scripts/install-git-hooks.sh

# Local scan (skips tools not installed)
./scripts/run-security-scan.sh

# CI parity + fast safety tests
./scripts/run-security-scan.sh --ci --with-tests
```

If the scan fails, check which section failed (`=== ShellCheck ===`, `=== Gitleaks ===`, `=== Semgrep ===`). A long ShellCheck listing usually means you ran an older script version that scanned `tests/`; update and re-run.

Optional deeper Semgrep (noisy):

```bash
semgrep scan --config p/ci --config r/bash.lang
```

## Tools

| Tool | Config | Pre-commit | CI / `./scripts/run-security-scan.sh` |
|------|--------|------------|----------------------------------------|
| [ShellCheck](https://www.shellcheck.net/) | [.shellcheckrc](../../.shellcheckrc) | Staged `*.sh` (default severity) | Production `*.sh` only (`lib/`, `scripts/`, entrypoints); **`-S error`** — excludes `tests/` and `backups/` |
| [Gitleaks](https://github.com/gitleaks/gitleaks) | [.gitleaks.toml](../../.gitleaks.toml) | `gitleaks protect --staged` | `gitleaks detect` |
| [Semgrep](https://semgrep.dev/) | [.semgrep/sleep-warning.yml](../../.semgrep/sleep-warning.yml) | — | Project rules only (`eval`, `curl \| bash`). Registry `p/bash` / `p/secrets` return 404; `p/ci` is very noisy on this repo |

### Why `tests/` are not in the full ShellCheck scan

Interactive and legacy test scripts produce hundreds of **info**-level findings (dynamic `source`, unused color variables, `read` without `-r`). Those are not product safety defects. Run ShellCheck on a single test file when you edit it, or use `shellcheck -S warning tests/your-test.sh`.

### Install (macOS)

```bash
brew install shellcheck gitleaks semgrep
```

### Install (Debian/Ubuntu)

```bash
sudo apt install shellcheck
# gitleaks: see project install script or GitHub releases
pip install semgrep
```

## Git hooks

`pre-commit` runs [scripts/pre-commit-checks.sh](../../scripts/pre-commit-checks.sh):

1. [scripts/prune-backups.sh](../../scripts/prune-backups.sh) — tracked `backups/` older than **5** commits
2. [scripts/prune-dev-docs-archive.sh](../../scripts/prune-dev-docs-archive.sh) — report-only (dry-run); manual `--apply` for deletion
3. ShellCheck on staged shell files (if installed)
4. Gitleaks on staged changes (if installed)

Retention policy: [doc-retention.md](doc-retention.md). Skip archive report: `SKIP_ARCHIVE_REPORT=1`.

**pre-push** runs [scripts/check-sonar-freshness.sh](../../scripts/check-sonar-freshness.sh), [scripts/check_sonar_issues.py](../../scripts/check_sonar_issues.py), and [scripts/check-python-coverage.sh](../../scripts/check-python-coverage.sh). The Sonar checks do not start `sonar-scanner`. When `SONAR_TOKEN` is set, the recorded scan in `tmp/sonar-state.json` must match each commit being pushed and the same host; otherwise run [scripts/sonar_scan.sh](../../scripts/sonar_scan.sh) and push again. The issue check fails when a `BUG` or `VULNERABILITY` count rises for the same rule and file. The Python coverage check fails when `lib/*.py` line coverage drops below the display or headless ratio in [scripts/python-coverage-baseline.json](../../scripts/python-coverage-baseline.json). The shell coverage check ([scripts/check-shell-coverage.sh](../../scripts/check-shell-coverage.sh)), which runs with the opt-in Tier-A hook, fails when traced `lib/*.sh` lines drop below [scripts/shell-coverage-baseline.json](../../scripts/shell-coverage-baseline.json). `SKIP_SHELL_COVERAGE=1` or `SKIP_PRE_PUSH_TESTS=1` skips that check locally. CI does not honor it. `localhost`, `[::1]`, and `127.0.0.1` count as the same Sonar host when the scheme and port match. Copy [.env.example](../../.env.example) and `chmod 600 .env`. The token stays in `.env`, which is gitignored. `SKIP_LOCAL_SONAR=1` skips the Sonar checks. `SKIP_PYTHON_COVERAGE=1` skips coverage locally; CI does not honor it. Details: [sonarqube.md](sonarqube.md). Tier-A stays opt-in: `INSTALL_PRE_PUSH=1 ./scripts/install-git-hooks.sh` enables it via [scripts/pre-push-checks.sh](../../scripts/pre-push-checks.sh). Disable Tier-A: `rm .githooks/enable-pre-push`. The local server is separate from the SonarCloud GitHub app. The local Community Build analyzes Python only.

**Quality gates** (Ruff, shell complexity, file sizes, types). Install the pinned tools with `pip install -r requirements-dev.txt`. Settings are in `pyproject.toml`.
- **Ruff** checks `E`, `F`, and McCabe `C901` (ceiling 19, measured on `lib/` and `scripts/`; tests are exempt from `C901`). Line length is 120. The few diagnostics that existed when the gate was added are recorded as `per-file-ignores` in `pyproject.toml`. Do not add to them.
- **Shell complexity** ([scripts/check-shell-complexity.sh](../../scripts/check-shell-complexity.sh)) caps a function at 535 lines and 7 levels of `if`/`for`/`while`/`until`/`case` nesting, the measured maximum over `lib/*.sh` and the root scripts. It is not cyclomatic complexity.
- **File sizes** ([scripts/check-file-sizes.sh](../../scripts/check-file-sizes.sh)) cap `lib/*.sh` at 900 lines and `lib/*.py` at 500. `lib/config.sh` (908), `lib/window-management.sh` (933), and `lib/configure-dialogs-darwin.sh` (939) have recorded ceilings. A ceiling may not be exceeded, and a shrink must lower it in the same commit. A file back under 900 loses its ceiling.
- **basedpyright** runs against `.basedpyright/baseline.json` through [scripts/check-python-types.sh](../../scripts/check-python-types.sh). That wrapper fails if the run rewrites the baseline, because basedpyright 1.29 has no lock flag. After removing a baselined diagnostic, run `basedpyright --writebaseline` and commit the file. `pythonVersion` is 3.12 and `pythonPlatform` is Linux, so the result does not depend on the host OS. `useLibraryCodeForTypes` is off, so installed packages such as pyobjc do not change the diagnostics. Regenerate the baseline with the pinned version from `requirements-dev.txt`.
- Pre-commit judges the staged blobs. Pre-push runs types and file sizes. CI runs [scripts/check-quality.sh](../../scripts/check-quality.sh) on the tree. `SKIP_QUALITY_CHECKS=1` and `SKIP_PYTHON_TYPES=1` skip locally; CI honors neither. A missing tool warns and skips locally and fails in CI.

Contributor onboarding: [CONTRIBUTING.md](../../CONTRIBUTING.md).

Skip when needed:

```bash
SKIP_GITLEAKS=1 git commit -m "docs only"
SKIP_SHELLCHECK=1 git commit -m "wip"
```

## GitHub Actions

[.github/workflows/security.yml](../../.github/workflows/security.yml) runs on push/PR to `main`/`master`:

| Job | Command |
|-----|---------|
| **static-analysis** (Ubuntu) | `./scripts/run-security-scan.sh --ci`, `./scripts/check-python-coverage.sh` (under xvfb, `COVERAGE_FLOOR=display`), `./scripts/check-quality.sh` (Ruff, shell complexity, file sizes, basedpyright), `./scripts/check-shell-coverage.sh`, then `./scripts/check-doc-drift.sh` (warn-only) |
| **tier-a-tests** (Ubuntu + macOS matrix) | `CI_HEADLESS=1 ./scripts/run-tests.sh --tier a`, then `./scripts/check-shell-coverage.sh` on macOS |

### Doc drift

```bash
./scripts/check-doc-drift.sh           # warn-only (matches CI)
./scripts/check-doc-drift.sh --strict # fail on findings (pre-release)
```

Checks stale links to the pre-rehome developer docs tree (now under `dev-docs/`) in canonical files, per-day cap wording drift vs [docs/SAFETY.md](../../docs/SAFETY.md), and broken relative links in `AGENTS.md`, `dev-docs/README.md`, `docs/index.md`, `docs/SAFETY.md`.

Details: [ci.md](ci.md).

[.github/dependabot.yml](../../.github/dependabot.yml) opens weekly PRs to update **GitHub Actions** pins only.

## What this does not cover

- No npm/cargo SCA (no application package manifest)
- Snyk/container scans — N/A unless Docker images are added
- Live GUI `expect` suites — run on Linux/macOS per [testing.md](testing.md)

## Agents

Do not commit real `sleep-warning.conf` contents or tokens. Hooks and Gitleaks reduce risk; agents should still use temp `HOME` for configure tests ([config-file-edits rule](../../.cursor/rules/config-file-edits.mdc)).
