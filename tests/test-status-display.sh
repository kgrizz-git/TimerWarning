#!/bin/bash

###############################################################################
# Sleep Warning System - Status configuration display regression test
#
# Verifies show_configuration() output for a fixed fixture config.
# Uses temp output only; does not modify installed config.
#
# Usage: ./tests/test-status-display.sh
###############################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
FIXTURE="${SCRIPT_DIR}/tests/test-configs/status-display-fixture.conf"
GOLDEN="${SCRIPT_DIR}/tests/test-configs/status-display-golden.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass=0
fail=0

assert_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"
    if echo "${haystack}" | grep -Fq "${needle}"; then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${label} (missing: ${needle})"
        fail=$((fail + 1))
    fi
}

# Disable colors for stable output
COLOR_RESET=""
COLOR_BOLD=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_RED=""
COLOR_BLUE=""
COLOR_CYAN=""

print_header() {
    local title="$1"
    echo ""
    echo "=== ${title} ==="
}

print_status() {
    local label="$1"
    local value="$2"
    printf "  %-30s %s\n" "${label}:" "${value}"
}

CONFIG_FILE="${FIXTURE}"

# shellcheck disable=SC1091
source "${LIB_DIR}/status-config-display.sh"

output=$(show_configuration 2>&1 || true)

assert_contains "fixture popup frequency" "${output}" "Popup display frequency"
assert_contains "fixture Monday restrictions" "${output}" "Monday:"
assert_contains "fixture Tuesday lock hours" "${output}" "Tuesday:"
if grep -q 'status-config-display.sh' "${SCRIPT_DIR}/status.sh"; then
    echo "PASS: status.sh sources display module"
    pass=$((pass + 1))
else
    echo "FAIL: status.sh sources display module"
    fail=$((fail + 1))
fi

if [ -f "${GOLDEN}" ]; then
    if diff -u "${GOLDEN}" <(printf '%s\n' "${output}") >/dev/null 2>&1; then
        echo "PASS: golden output match"
        pass=$((pass + 1))
    else
        echo "FAIL: golden output mismatch (run: show_configuration > tests/test-configs/status-display-golden.txt to refresh)"
        fail=$((fail + 1))
    fi
else
    printf '%s\n' "${output}" > "${GOLDEN}"
    echo "NOTE: created golden file at ${GOLDEN}"
    pass=$((pass + 1))
fi

assert_equals() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${label} (expected '${expected}', got '${actual}')"
        fail=$((fail + 1))
    fi
}

# format_hour_12h in this module takes "HH[:MM]". 24:00 is midnight at the end
# of the day, so it must read as AM, not noon.
assert_equals "format_hour_12h midnight" "12:00 AM" "$(format_hour_12h 0)"
assert_equals "format_hour_12h 5:30" "5:30 AM" "$(format_hour_12h 05:30)"
assert_equals "format_hour_12h noon" "12:00 PM" "$(format_hour_12h 12)"
assert_equals "format_hour_12h 4 PM" "4:00 PM" "$(format_hour_12h 16:00)"
assert_equals "format_hour_12h 23:59" "11:59 PM" "$(format_hour_12h 23:59)"
assert_equals "format_hour_12h 24:00 is midnight" "12:00 AM" "$(format_hour_12h 24:00)"
assert_equals "format_hour_12h 24 is midnight" "12:00 AM" "$(format_hour_12h 24)"
assert_equals "format_hour_12h leaves a non-numeric value alone" "soon" "$(format_hour_12h soon)"
assert_equals "format_range_human range ending at 24:00 is not overnight" \
    "4:00 PM → 12:00 AM" "$(format_range_human "16:00-24:00" Monday)"
assert_equals "format_range_human overnight range" \
    "10:00 PM → 6:00 AM (overnight)" "$(format_range_human "22:00-06:00" Monday)"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
