# Continuous integration

Agent-agnostic PR checks in [`.github/workflows/security.yml`](../../.github/workflows/security.yml). Same Tier-A list as local: `./scripts/run-tests.sh --tier a`.

## Workflows

| Job | Runner | Command | Purpose |
|-----|--------|---------|---------|
| **static-analysis** | `ubuntu-latest` | `./scripts/run-security-scan.sh --ci`, `check-python-coverage.sh`, `check-quality.sh`, `check-shell-coverage.sh`, `check-doc-drift.sh` (warn-only) | ShellCheck, Gitleaks, Semgrep; Python and shell line coverage; Ruff, shell complexity, file sizes, basedpyright; doc drift checks |
| **tier-a-tests** | `ubuntu-latest`, `macos-latest` | `CI_HEADLESS=1 ./scripts/run-tests.sh --tier a`, then `check-shell-coverage.sh` on macOS | Fast safety/unit gate; Linux runs `test-popup-safety-linux.sh`, macOS runs `test-popup-safety-darwin.sh` |

Triggers: push and pull_request to `main` / `master`.

## Local parity

```bash
# Match static-analysis job (CI=true makes missing tools fail, as in CI)
./scripts/run-security-scan.sh --ci
pip install -r requirements-dev.txt coverage==7.15.0   # plus python3-tk and xvfb on Linux
COVERAGE_FLOOR=display xvfb-run -a ./scripts/check-python-coverage.sh   # Linux; on macOS drop xvfb-run
CI=true ./scripts/check-quality.sh
./scripts/check-shell-coverage.sh   # runs Tier-A under xtrace; resource-heavy
./scripts/check-doc-drift.sh

# Match tier-a-tests job (both platforms use headless skip for GUI scripts)
CI_HEADLESS=1 ./scripts/run-tests.sh --tier a

# Static analysis + Tier-A (CI sets CI_HEADLESS automatically when CI=true)
CI=true ./scripts/run-security-scan.sh --ci --with-tests
```

## What CI does not run

- **Tier-B** (`./scripts/run-tests.sh --tier b`) — temp-`HOME` / longer configure smokes; run pre-release locally.
- **Tier-C** — manual / GUI / multi-distro; see [platform-test-matrix.md](platform-test-matrix.md).
- **GUI Tier-A on headless runners** — `test-darwin-configure-gui.sh` is skipped when `CI_HEADLESS=1` (default in GHA and when `CI=true` + `--with-tests`).

## Safety constraints

- No install/configure against the runner user's live `~/.config/sleep-warning/`.
- Tests use temp `HOME` or pure unit paths per [agent-setup.md](agent-setup.md).

## Dependabot

[`.github/dependabot.yml`](../../.github/dependabot.yml) — weekly GitHub Actions dependency updates.

## Related docs

- [security-scanning.md](security-scanning.md) — tool install and scan details
- [test-tiers.md](../testing-assessments/test-tiers.md) — Tier A/B/C manifest
- [agent-setup.md](agent-setup.md) — universal harness entry for any coding agent
