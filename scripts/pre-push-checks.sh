#!/usr/bin/env bash

###############################################################################
# pre-push-checks.sh — Optional pre-push: Tier-A test gate
#
# Enabled when ./scripts/install-git-hooks.sh is run with INSTALL_PRE_PUSH=1
# (creates .githooks/enable-pre-push, gitignored).
#
# Environment:
#   SKIP_PRE_PUSH_TESTS=1   Skip Tier-A (emergencies only)
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [ "${SKIP_PRE_PUSH_TESTS:-0}" = "1" ]; then
    echo "pre-push: SKIP_PRE_PUSH_TESTS=1 — skipping Tier-A" >&2
    exit 0
fi

echo "pre-push: Tier-A tests (CI_HEADLESS=1, timeout 600s)..." >&2

if command -v timeout >/dev/null 2>&1; then
    CI_HEADLESS=1 timeout 600 "${ROOT}/scripts/run-tests.sh" --tier a
else
    CI_HEADLESS=1 "${ROOT}/scripts/run-tests.sh" --tier a
fi

echo "pre-push: Tier-A passed." >&2
