#!/usr/bin/env bash
# Fail on basedpyright diagnostics that are not in .basedpyright/baseline.json.
#
# basedpyright 1.29 has no baseline lock flag, and outside CI it rewrites the
# baseline when a diagnostic disappears. This wrapper snapshots the file and
# fails, restoring it, if the run changed it. A cleanup that removes a
# baselined diagnostic must run `basedpyright --writebaseline` and commit the
# new file. Settings are in pyproject.toml; pins are in requirements-dev.txt.
#
# A missing basedpyright warns and skips locally, and fails when CI=true.
# SKIP_PYTHON_TYPES=1 or SKIP_QUALITY_CHECKS=1 skips locally. CI must not set either.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ "${CI:-}" != "true" ]] &&
    [[ "${SKIP_PYTHON_TYPES:-0}" == "1" || "${SKIP_QUALITY_CHECKS:-0}" == "1" ]]; then
    echo "python types: SKIP_PYTHON_TYPES=1 or SKIP_QUALITY_CHECKS=1 — skipping" >&2
    exit 0
fi

if ! command -v basedpyright >/dev/null 2>&1; then
    if [[ "${CI:-}" == "true" ]]; then
        echo "python types: basedpyright is not installed (pip install -r requirements-dev.txt)." >&2
        exit 1
    fi
    echo "python types: basedpyright is not installed — skipping (pip install -r requirements-dev.txt)." >&2
    exit 0
fi

baseline=".basedpyright/baseline.json"
snapshot="$(mktemp)"
trap 'rm -f "${snapshot}"' EXIT
cp "${baseline}" "${snapshot}"

rc=0
basedpyright || rc=$?

if ! cmp -s "${baseline}" "${snapshot}"; then
    cp "${snapshot}" "${baseline}"
    echo "python types: the baseline is out of date (a baselined diagnostic is gone)." >&2
    echo "python types: run 'basedpyright --writebaseline' and commit ${baseline}." >&2
    exit 1
fi
exit "${rc}"
