#!/bin/bash

###############################################################################
# Time-validation tests
#
# Pure checks in lib/time-validation.sh. Does not source logging.sh.
#
# Usage: bash tests/test-time-validation.sh
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-validation.sh" || {
    echo "FATAL: cannot source lib/time-validation.sh" >&2
    exit 1
}

_PASS=0
_FAIL=0

_pass() { _PASS=$((_PASS + 1)); echo "  PASS  $*"; }
_fail() { _FAIL=$((_FAIL + 1)); echo "  FAIL  $*"; }

assert_ok() {
    if "$@"; then
        _pass "$*"
    else
        _fail "$* (expected success)"
    fi
}

assert_fail() {
    if "$@"; then
        _fail "$* (expected failure)"
    else
        _pass "$*"
    fi
}

assert_ok validate_single_range "0-5"
assert_ok validate_single_range "23-6"
assert_fail validate_single_range "5-5"
assert_fail validate_single_range "24-3"
assert_fail validate_single_range "nope"

assert_ok validate_single_time_value "09:00"
assert_ok validate_single_time_value "9am"
assert_fail validate_single_time_value "13pm"
assert_fail validate_single_time_value "09:60"

assert_ok is_time_in_single_range "1000" "09:00-17:00"
assert_fail is_time_in_single_range "0800" "09:00-17:00"
assert_ok is_time_in_single_range "2300" "23:00-05:00" "self"
assert_fail is_time_in_single_range "0400" "23:00-05:00" "self"
assert_ok is_time_in_single_range "0400" "23:00-05:00" "both"

assert_ok is_restricted_time "1000" "09:00-17:00"
assert_fail is_restricted_time "0800" "09:00-17:00"
assert_fail is_restricted_time "1000" ""

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
if [ "${_FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
