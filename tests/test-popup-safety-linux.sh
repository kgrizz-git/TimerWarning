#!/usr/bin/env bash

###############################################################################
# test-popup-safety-linux.sh — Linux popup safety unit tests (Tier-A on Linux CI)
#
# Exercises lib/popup-safety.sh shared helpers plus the Linux PID-file watchdog
# path used by lib/popup-display-linux.sh. Does not spawn yad/zenity/kdialog;
# wedge-dialog integration remains optional (see dev-docs/TO_DO.md).
#
# Usage:
#   bash tests/test-popup-safety-linux.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

pass=0
fail=0

_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

echo "=== Shared popup-safety unit tests (via test-popup-safety-darwin.sh) ==="
if bash "${SCRIPT_DIR}/test-popup-safety-darwin.sh"; then
    _pass "shared popup_run_with_watchdog / compute_watchdog_seconds"
else
    _fail "shared popup-safety unit tests"
fi

echo ""
echo "=== Linux PID-file watchdog (popup_start_pid_file_watchdog) ==="

# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/popup-safety.sh"

_test_dir=""
_cleanup() {
    if [ -n "${_test_dir}" ] && [ -d "${_test_dir}" ]; then
        rm -rf "${_test_dir}"
    fi
}
trap _cleanup EXIT

_test_dir="$(mktemp -d 2>/dev/null || mktemp -d -t popup-safety-linux)"
_pid_file="${_test_dir}/popup.pid"

sleep 120 &
_hung_pid=$!
echo "${_hung_pid}" > "${_pid_file}"

_assign_start=$(date +%s)
popup_start_pid_file_watchdog 4 "${_pid_file}" >/dev/null
_wd_bg_pid="${POPUP_WATCHDOG_LAST_PID:-}"
_assign_elapsed=$(($(date +%s) - _assign_start))
if ! [[ "${_wd_bg_pid}" =~ ^[0-9]+$ ]]; then
    _fail "popup_start_pid_file_watchdog returned pid (${_wd_bg_pid})"
elif [ "${_assign_elapsed}" -gt 2 ]; then
    _fail "popup_start_pid_file_watchdog blocked caller for ${_assign_elapsed}s (command substitution wait)"
else
    _pass "popup_start_pid_file_watchdog started background watcher without blocking caller"
fi

_start=$(date +%s)
_deadline=$((_start + 12))
while kill -0 "${_hung_pid}" 2>/dev/null && [ "$(date +%s)" -lt "${_deadline}" ]; do
    sleep 1
done

if kill -0 "${_hung_pid}" 2>/dev/null; then
    kill -9 "${_hung_pid}" 2>/dev/null || true
    wait "${_hung_pid}" 2>/dev/null || true
    _fail "PID-file watchdog did not kill hung dialog within 12s"
else
    wait "${_hung_pid}" 2>/dev/null || true
    _pass "PID-file watchdog killed hung process within cap"
fi

if kill -0 "${_wd_bg_pid}" 2>/dev/null; then
    kill "${_wd_bg_pid}" 2>/dev/null || true
    wait "${_wd_bg_pid}" 2>/dev/null || true
fi

echo ""
echo "=== popup-display-linux wiring ==="
if grep -q 'popup_start_pid_file_watchdog' "${PROJECT_DIR}/lib/popup-display-linux.sh" \
    && grep -q 'popup_compute_watchdog_seconds' "${PROJECT_DIR}/lib/popup-display-linux.sh"; then
    _pass "popup-display-linux.sh sources watchdog helpers"
else
    _fail "popup-display-linux.sh missing watchdog wiring"
fi

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
