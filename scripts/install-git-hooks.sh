#!/bin/bash

###############################################################################
# install-git-hooks.sh — Point git at the repo's .githooks/ directory
#
# Run once after clone (or again if hooks were reset):
#   ./scripts/install-git-hooks.sh
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
chmod +x "${ROOT}/scripts/prune-backups.sh"
chmod +x "${ROOT}/scripts/pre-commit-checks.sh"
chmod +x "${ROOT}/scripts/run-security-scan.sh"

git config core.hooksPath .githooks

echo "Git hooks installed: core.hooksPath=.githooks"
echo "  pre-commit -> scripts/pre-commit-checks.sh"
echo "    - prune tracked backups/ older than 3 commits"
echo "    - ShellCheck on staged *.sh (if shellcheck installed)"
echo "    - gitleaks protect --staged (if gitleaks installed)"
echo ""
echo "Optional: SKIP_SHELLCHECK=1 or SKIP_GITLEAKS=1 git commit ..."
echo "Full scan (CI parity): ./scripts/run-security-scan.sh --ci --with-tests"
