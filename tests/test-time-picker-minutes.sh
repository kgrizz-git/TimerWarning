#!/bin/bash
# Tests for GUI time picker minute helpers (15-minute quantum).
# Usage: bash tests/test-time-picker-minutes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-dialogs-time.sh"

pass=0
fail=0

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${label}"
        echo "  expected: '${expected}'"
        echo "  actual:   '${actual}'"
        fail=$((fail + 1))
    fi
}

assert_eq "normalize 15" "15" "$(normalize_minute_for_picker "15")"
assert_eq "normalize 17 -> 15" "15" "$(normalize_minute_for_picker "17")"
assert_eq "normalize 52 -> 45" "45" "$(normalize_minute_for_picker "52")"
assert_eq "normalize 00" "00" "$(normalize_minute_for_picker "00")"
assert_eq "normalize 30" "30" "$(normalize_minute_for_picker "30")"
assert_eq "normalize 45" "45" "$(normalize_minute_for_picker "45")"
assert_eq "normalize invalid high" "00" "$(normalize_minute_for_picker "99")"

assert_eq "yad cb 15" "^15!00!15!30!45" "$(_yad_minute_cb_value "15")"
assert_eq "yad cb 17 snaps to 15" "^15!00!15!30!45" "$(_yad_minute_cb_value "17")"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
