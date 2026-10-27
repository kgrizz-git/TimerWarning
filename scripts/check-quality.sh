#!/usr/bin/env bash
# Whole-tree quality gates: Ruff (E, F, C901), shell complexity, file-size
# ratchet, and basedpyright against its committed baseline.
#
# Pre-commit judges staged blobs (scripts/pre-commit-checks.sh). This script
# reads the working tree; CI and pre-push call it. A missing Ruff warns and
# skips locally and fails when CI=true. SKIP_QUALITY_CHECKS=1 skips locally;
# CI must not set that.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ "${SKIP_QUALITY_CHECKS:-0}" == "1" && "${CI:-}" != "true" ]]; then
    echo "quality: SKIP_QUALITY_CHECKS=1 — skipping" >&2
    exit 0
fi

if command -v ruff >/dev/null 2>&1; then
    echo "quality: ruff check (E, F, C901)"
    ruff check .
elif [[ "${CI:-}" == "true" ]]; then
    echo "quality: ruff is not installed (pip install -r requirements-dev.txt)." >&2
    exit 1
else
    echo "quality: ruff is not installed — skipping (pip install -r requirements-dev.txt)." >&2
fi

echo "quality: shell function length and nesting"
"${ROOT}/scripts/check-shell-complexity.sh"

echo "quality: file-size ratchet"
"${ROOT}/scripts/check-file-sizes.sh" --strict

echo "quality: basedpyright"
"${ROOT}/scripts/check-python-types.sh"
