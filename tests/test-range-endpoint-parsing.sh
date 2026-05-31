#!/bin/bash

###############################################################################
# test-range-endpoint-parsing.sh - Shared HH / HH:MM range endpoint helpers
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/time-parsing.sh"

pass=0
fail=0

assert_minutes() {
    local desc="$1"
    local part="$2"
    local want="$3"
    local got
    got=$(range_endpoint_to_day_minutes "${part}") || got=""
    if [ "${got}" = "${want}" ]; then
        echo "PASS: ${desc}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${desc} (got '${got}', want '${want}')"
        fail=$((fail + 1))
    fi
}

assert_overnight() {
    local desc="$1"
    local start="$2"
    local end="$3"
    if range_is_overnight "${start}" "${end}"; then
        echo "PASS: ${desc} (overnight)"
        pass=$((pass + 1))
    else
        echo "FAIL: ${desc} (expected overnight)"
        fail=$((fail + 1))
    fi
}

assert_not_overnight() {
    local desc="$1"
    local start="$2"
    local end="$3"
    if range_is_overnight "${start}" "${end}"; then
        echo "FAIL: ${desc} (unexpected overnight)"
        fail=$((fail + 1))
    else
        echo "PASS: ${desc} (same-day)"
        pass=$((pass + 1))
    fi
}

assert_minutes "integer hour 5" "5" "300"
assert_minutes "HH:MM 17:30" "17:30" "1050"
assert_minutes "HH:MM 17:15" "17:15" "1035"
assert_minutes "HH:MM 23:45" "23:45" "1425"
assert_minutes "HH:MM 00:00" "00:00" "0"
assert_overnight "23:30-06:00" "23:30" "06:00"
assert_not_overnight "17:00-17:30" "17:00" "17:30"
assert_not_overnight "0-5 legacy" "0" "5"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ] || exit 1
