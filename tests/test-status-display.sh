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

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
