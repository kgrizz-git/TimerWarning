#!/bin/bash

###############################################################################
# test-sleep-detection-darwin.sh - pmset wake-line filtering (no live sleep)
#
# Verifies MaintenanceWake / Wake Requests lines do not trigger resume grace.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_DIR}/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/sleep-detection-darwin.sh"

pass=0
fail=0

assert_wake_line() {
    local desc="$1"
    local line="$2"
    if _darwin_pmset_line_is_user_sleep_wake "${line}"; then
        echo "PASS: ${desc}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${desc} (expected user sleep/wake match)"
        fail=$((fail + 1))
    fi
}

assert_not_wake_line() {
    local desc="$1"
    local line="$2"
    if _darwin_pmset_line_is_user_sleep_wake "${line}"; then
        echo "FAIL: ${desc} (should not match)"
        fail=$((fail + 1))
    else
        echo "PASS: ${desc}"
        pass=$((pass + 1))
    fi
}

REAL_WAKE=$'2026-05-26 13:03:49 -0400 Wake                	Wake from Deep Idle [CDNVA] : due to lid'
MAINTENANCE=$'2026-05-26 17:22:42 -0400 Assertions          	PID 481(PowerUIAgent) Released MaintenanceWake "com.apple.obc"'
WAKE_REQUESTS=$'2026-05-26 12:14:07 -0400 Wake Requests       	[*process=dasd request=SleepService'
KERNEL_ACKS=$'2026-05-26 12:14:00 -0400 Kernel Client Acks  	Delays to Wake notifications: [Codec Output driver is slow]'
DARK_WAKE=$'2026-05-26 12:21:00 -0400 DarkWake            	DarkWake from Deep Idle [CDNP]'

assert_wake_line "real Wake from sleep" "${REAL_WAKE}"
assert_not_wake_line "MaintenanceWake assertion" "${MAINTENANCE}"
assert_not_wake_line "Wake Requests" "${WAKE_REQUESTS}"
assert_not_wake_line "Kernel Client Acks Wake mention" "${KERNEL_ACKS}"
assert_not_wake_line "DarkWake (background, not lid open)" "${DARK_WAKE}"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
if [ "${fail}" -gt 0 ]; then
    exit 1
fi
exit 0
