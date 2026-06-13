#!/bin/bash

###############################################################################
# test-popup-safety-darwin.sh - Popup safety watchdog unit tests (all platforms)
#
# Purpose: Verify popup_run_with_watchdog and popup_compute_watchdog_seconds.
# Linux dialog spawn is not exercised here; see test-popup-safety-linux.sh on Linux CI
# Last updated: 2026-05-30
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/popup-safety.sh"

pass=0
fail=0

_hung_spawn() {
    sleep 120 &
    popup_pid=$!
}

echo "Testing popup_run_with_watchdog (5s cap on 120s sleep)..."
start=$(date +%s)
popup_run_with_watchdog _hung_spawn 5 || true
end=$(date +%s)
elapsed=$((end - start))

if [ "${elapsed}" -le 12 ]; then
    echo "PASS: watchdog ended within 12s (elapsed=${elapsed}s)"
    pass=$((pass + 1))
else
    echo "FAIL: watchdog took too long (${elapsed}s)"
    fail=$((fail + 1))
fi

if [ -z "${popup_pid:-}" ] || ! kill -0 "${popup_pid}" 2>/dev/null; then
    echo "PASS: child process terminated"
    pass=$((pass + 1))
else
    kill -9 "${popup_pid}" 2>/dev/null || true
    wait "${popup_pid}" 2>/dev/null || true
    echo "FAIL: child still running (pid=${popup_pid})"
    fail=$((fail + 1))
fi

cap=$(popup_compute_watchdog_seconds 999 true)
if [ "${cap}" -le "${POPUP_ABSOLUTE_MAX_SECONDS}" ]; then
    echo "PASS: absolute max caps watchdog (${cap} <= ${POPUP_ABSOLUTE_MAX_SECONDS})"
    pass=$((pass + 1))
else
    echo "FAIL: watchdog not capped (${cap})"
    fail=$((fail + 1))
fi

# A 300s min-display must produce a watchdog that actually allows the full
# display window (regression guard for the old 120s ceiling clamping it short).
wd_300=$(popup_compute_watchdog_seconds 300 true)
if [ "${wd_300}" -ge 325 ]; then
    echo "PASS: 300s min-display watchdog accommodates full window (${wd_300})"
    pass=$((pass + 1))
else
    echo "FAIL: 300s min-display watchdog clamped too short (${wd_300})"
    fail=$((fail + 1))
fi

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
