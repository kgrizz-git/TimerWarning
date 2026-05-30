# Security scanning

Static analysis and secret scanning for this bash project. Complements [SAFETY.md](../SAFETY.md) (runtime lockout invariants) and the manual [safety scan template](../../dev-docs/templates/safety-scan-template.md).

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

1. [scripts/prune-backups.sh](../../scripts/prune-backups.sh)
2. ShellCheck on staged shell files (if installed)
3. Gitleaks on staged changes (if installed)

Skip when needed:

```bash
SKIP_GITLEAKS=1 git commit -m "docs only"
SKIP_SHELLCHECK=1 git commit -m "wip"
```

## GitHub Actions

[.github/workflows/security.yml](../../.github/workflows/security.yml) runs on push/PR to `main`/`master`:

- `./scripts/run-security-scan.sh --ci --with-tests`

[.github/dependabot.yml](../../.github/dependabot.yml) opens weekly PRs to update **GitHub Actions** pins only.

## What this does not cover

- No npm/cargo SCA (no application package manifest)
- Snyk/container scans — N/A unless Docker images are added
- Live GUI `expect` suites — run on Linux/macOS per [testing.md](testing.md)

## Agents

Do not commit real `sleep-warning.conf` contents or tokens. Hooks and Gitleaks reduce risk; agents should still use temp `HOME` for configure tests ([config-file-edits rule](../../.cursor/rules/config-file-edits.mdc)).
