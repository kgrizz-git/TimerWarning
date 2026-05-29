#!/bin/bash
# Non-GUI tests for darwin time dialog JSON wiring.
# Usage: ./tests/test-darwin-time-dialog.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/configure-dialogs-time.sh"
source "${SCRIPT_DIR}/lib/configure-dialogs-darwin.sh"

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

# parse_normalized_time_to_12h defaults
data=$(parse_normalized_time_to_12h "23:00")
assert_eq "parse 23:00 hour" "11" "$(echo "${data}" | cut -d' ' -f1)"
assert_eq "parse 23:00 minute" "00" "$(echo "${data}" | cut -d' ' -f2)"
assert_eq "parse 23:00 ampm" "PM" "$(echo "${data}" | cut -d' ' -f3)"

data=$(parse_normalized_time_to_12h "05:30")
assert_eq "parse 05:30 hour" "5" "$(echo "${data}" | cut -d' ' -f1)"
assert_eq "parse 05:30 minute" "30" "$(echo "${data}" | cut -d' ' -f2)"
assert_eq "parse 05:30 ampm" "AM" "$(echo "${data}" | cut -d' ' -f3)"

if _cd_darwin_has_time_dialog; then
    echo "PASS: time dialog helper available"
    pass=$((pass + 1))
else
    echo "FAIL: time dialog helper available"
    fail=$((fail + 1))
fi

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
