#!/usr/bin/env bash
# Fail when lib/*.sh line coverage drops below the committed ratio.
#
# Runs Tier-A under bash xtrace (BASH_ENV + BASH_XTRACEFD). The denominator is
# every non-blank, non-comment line in lib/*.sh. Structural lines such as fi
# and done often never appear in an xtrace, so the percentage stays modest.
# The same suite must produce the same ratio.
#
# The floor is scripts/shell-coverage-baseline.json: a top-level ratio, with
# optional per-OS darwin/linux objects that override it when present. A run may
# fall "slack_lines" (30) under the floor to absorb timing noise. Raising
# the committed number is a new measurement. CI runs this on Ubuntu and macOS;
# an OS entry is used when present. Local pre-push runs it only with the
# opt-in Tier-A hook.
#
# SKIP_SHELL_COVERAGE=1 and SKIP_PRE_PUSH_TESTS=1 skip locally. CI honors neither.
# SHELL_COVERAGE_MEASURE=1 prints the ratio and exits 0 without comparing.
# Requires bash >= 4.1. Tier-A does not run configure.sh.

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 1 ) ]]; then
    for _bash4 in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "${_bash4}" ]] && [[ "$("${_bash4}" -c 'echo "${BASH_VERSINFO[0]}"')" -ge 4 ]]; then
            exec "${_bash4}" "$0" "$@"
        fi
    done
    echo "shell coverage: bash >= 4.1 is required (this shell is ${BASH_VERSION:-unknown})." >&2
    exit 1
fi

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ "${SKIP_SHELL_COVERAGE:-0}" == "1" && "${CI:-}" != "true" ]]; then
    echo "shell coverage: SKIP_SHELL_COVERAGE=1 — skipping" >&2
    exit 0
fi

if [[ "${SKIP_PRE_PUSH_TESTS:-0}" == "1" && "${CI:-}" != "true" ]]; then
    echo "shell coverage: SKIP_PRE_PUSH_TESTS=1 — skipping (Tier-A is skipped, nothing to trace)" >&2
    exit 0
fi

log_dir="${ROOT}/tmp/shell-coverage"
rm -rf "${log_dir}"
mkdir -p "${log_dir}"
keep_logs=1
cleanup() {
    if [[ "${keep_logs}" -eq 0 ]]; then
        rm -rf "${log_dir}"
    else
        echo "shell coverage: logs kept in ${log_dir}" >&2
    fi
}
trap cleanup EXIT

export SHELL_COVERAGE_DIR="${log_dir}"
export BASH_ENV="${ROOT}/scripts/shell-coverage-env.sh"

echo "shell coverage: running Tier-A under xtrace."
set +e
CI_HEADLESS=1 SKIP_GUI_TESTS=1 "${ROOT}/scripts/run-tests.sh" --tier a
suite_rc=$?
set -e
unset BASH_ENV

if [[ -f "${log_dir}/readers.pids" ]]; then
    while read -r reader_pid; do
        [[ -n "${reader_pid}" ]] || continue
        waited=0
        while kill -0 "${reader_pid}" 2>/dev/null; do
            waited=$((waited + 1))
            if [[ "${waited}" -gt 50 ]]; then
                break
            fi
            sleep 0.05
        done
    done < "${log_dir}/readers.pids"
fi

if [[ "${suite_rc}" -ne 0 ]]; then
    echo "shell coverage: Tier-A failed (exit ${suite_rc})." >&2
    exit "${suite_rc}"
fi

python3 "${ROOT}/scripts/shell_coverage_report.py" \
    "${ROOT}" "${log_dir}" \
    "${SHELL_COVERAGE_MEASURE:-0}"
keep_logs=0
