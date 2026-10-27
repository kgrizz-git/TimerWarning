#!/usr/bin/env bash
# Fail when lib/*.py line coverage drops below the committed ratio.
#
# Runs every tests/test-*.py under coverage.py with --source=lib. Shell
# scripts are outside this gate. CI's static-analysis job installs python3-tk
# and runs this script under xvfb, so that job uses the display floor.
# A machine where Tk() cannot open a window uses the headless floor. Tests
# that only need TclError install a stub when the tkinter module is absent,
# so they run without a display or a system tkinter package.
#
# The floor is scripts/python-coverage-baseline.json. A display run uses the
# display ratio. A run whose tkinter probe fails uses the headless ratio.
# COVERAGE_FLOOR=display or COVERAGE_FLOOR=headless overrides the probe.
# Raising either floor is a new measurement. Lowering one is a deliberate edit.
#
# A missing coverage package skips locally with a warning and fails in CI.
# SKIP_PYTHON_COVERAGE=1 skips. CI must not set that. A headless machine does
# not need the skip: it is checked against the headless floor.
# Requirements: python3 and the coverage package (pip install coverage).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ "${SKIP_PYTHON_COVERAGE:-0}" == "1" && "${CI:-}" != "true" ]]; then
    echo "python coverage: SKIP_PYTHON_COVERAGE=1 — skipping" >&2
    exit 0
fi

if ! python3 -c 'import coverage' >/dev/null 2>&1; then
    if [[ "${CI:-}" == "true" ]]; then
        echo "python coverage: the coverage package is not installed (python3 -m pip install coverage)." >&2
        exit 1
    fi
    echo "python coverage: the coverage package is not installed — skipping (python3 -m pip install coverage)." >&2
    exit 0
fi

floor_mode="${COVERAGE_FLOOR:-}"
if [[ -z "${floor_mode}" ]]; then
    if python3 -c 'import tkinter as tk; root = tk.Tk(); root.withdraw(); root.destroy()' >/dev/null 2>&1; then
        floor_mode="display"
    else
        floor_mode="headless"
    fi
fi
case "${floor_mode}" in
    display|headless) ;;
    *)
        echo "python coverage: COVERAGE_FLOOR must be display or headless." >&2
        exit 1
        ;;
esac
echo "python coverage: using the ${floor_mode} floor."

mkdir -p "${ROOT}/tmp"
data="${ROOT}/tmp/.coverage"
report="${ROOT}/tmp/python-coverage.json"
rm -f "${data}" "${report}"

found=0
first=1
for test in "${ROOT}"/tests/test-*.py; do
    [[ -f "${test}" ]] || continue
    found=1
    echo "python coverage: ${test#"${ROOT}/"}"
    if [[ "${first}" -eq 1 ]]; then
        COVERAGE_FILE="${data}" python3 -m coverage run --source=lib "${test}"
        first=0
    else
        COVERAGE_FILE="${data}" python3 -m coverage run --append --source=lib "${test}"
    fi
done
if [[ "${found}" -eq 0 ]]; then
    echo "python coverage: no tests/test-*.py files." >&2
    exit 1
fi

COVERAGE_FILE="${data}" python3 -m coverage json -o "${report}" --quiet
python3 - "${report}" "${ROOT}/scripts/python-coverage-baseline.json" "${floor_mode}" <<'PY'
import json
import sys

report_path, baseline_path, floor_mode = sys.argv[1:]
report = json.loads(open(report_path, encoding="utf-8").read())
baseline = json.loads(open(baseline_path, encoding="utf-8").read())
covered = 0
statements = 0
for meta in report["files"].values():
    summary = meta["summary"]
    statements += summary["num_statements"]
    covered += summary["num_statements"] - summary["missing_lines"]
chosen = baseline[floor_mode]
base_covered = int(chosen["covered_statements"])
base_statements = int(chosen["statements"])
percent = (100.0 * covered / statements) if statements else 0.0
floor = (100.0 * base_covered / base_statements) if base_statements else 0.0
print(
    f"python coverage: {covered}/{statements} statements "
    f"({percent:.2f}%). {floor_mode} floor is {base_covered}/{base_statements} ({floor:.2f}%)."
)
if statements == 0 or covered * base_statements < base_covered * statements:
    print(
        "python coverage: lib/*.py line coverage dropped. "
        "Add tests, or lower scripts/python-coverage-baseline.json in a commit that says why.",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
