#!/bin/bash

###############################################################################
# install-git-hooks.sh — Point git at the repo's .githooks/ directory
#
# Run once after clone (or again if hooks were reset):
#   ./scripts/install-git-hooks.sh
#
# Optional Tier-A pre-push (local only):
#   INSTALL_PRE_PUSH=1 ./scripts/install-git-hooks.sh
#
# Sets: git config core.hooksPath .githooks (local to this repo)
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "install-git-hooks.sh: not inside a git repository" >&2
    exit 1
fi

chmod +x "${ROOT}/.githooks/pre-commit"
chmod +x "${ROOT}/.githooks/pre-push"
chmod +x "${ROOT}/scripts/prune-backups.sh"
chmod +x "${ROOT}/scripts/prune-dev-docs-archive.sh"
chmod +x "${ROOT}/scripts/prune-completed-plans.sh"
chmod +x "${ROOT}/scripts/check-stale-plans.sh"
chmod +x "${ROOT}/scripts/pre-commit-checks.sh"
chmod +x "${ROOT}/scripts/pre-push-checks.sh"
chmod +x "${ROOT}/scripts/sonar_scan.sh"
chmod +x "${ROOT}/scripts/sonar_collect.py"
chmod +x "${ROOT}/scripts/check-sonar-freshness.sh"
chmod +x "${ROOT}/scripts/check_sonar_issues.py"
chmod +x "${ROOT}/scripts/check-python-coverage.sh"
chmod +x "${ROOT}/scripts/run-security-scan.sh"
chmod +x "${ROOT}/scripts/run-tests.sh"

git config core.hooksPath .githooks

echo "Git hooks installed: core.hooksPath=.githooks"
echo "  pre-commit -> scripts/pre-commit-checks.sh"
echo "    - prune tracked backups/ older than 5 commits"
echo "    - report dev-docs archive files eligible for pruning (dry-run)"
echo "    - ShellCheck on staged *.sh (if shellcheck installed)"
echo "    - gitleaks protect --staged (if gitleaks installed)"
echo "  pre-push -> scripts/check-sonar-freshness.sh and scripts/check_sonar_issues.py (when SONAR_TOKEN is set; run scripts/sonar_scan.sh yourself)"
echo "  pre-push -> scripts/check-python-coverage.sh (lib/*.py line coverage; SKIP_PYTHON_COVERAGE=1 skips locally)"
echo "  pre-push shell coverage runs with the opt-in Tier-A hook (SKIP_SHELL_COVERAGE=1 skips locally; CI always runs it)"

if [ "${INSTALL_PRE_PUSH:-0}" = "1" ]; then
    touch "${ROOT}/.githooks/enable-pre-push"
    echo "  pre-push -> scripts/pre-push-checks.sh (ENABLED — Tier-A before push)"
    echo "    Disable: rm .githooks/enable-pre-push"
else
    if [ -f "${ROOT}/.githooks/enable-pre-push" ]; then
        echo "  pre-push -> scripts/pre-push-checks.sh (still enabled — rm .githooks/enable-pre-push to disable)"
    else
        echo "  pre-push Tier-A -> (disabled; no-op until INSTALL_PRE_PUSH=1)"
    fi
fi

echo ""
echo "Optional: SKIP_SHELLCHECK=1 or SKIP_GITLEAKS=1 or SKIP_ARCHIVE_REPORT=1 git commit ..."
echo "Optional: SKIP_PRE_PUSH_TESTS=1 git push ..."
echo "Optional: SKIP_LOCAL_SONAR=1 git push ..."
echo "Optional: SKIP_PYTHON_COVERAGE=1 SKIP_SHELL_COVERAGE=1 git push ..."
echo "Full scan (CI parity): CI_HEADLESS=1 ./scripts/run-tests.sh --tier a"
echo "Contributor guide: dev-docs/CONTRIBUTING.md"
