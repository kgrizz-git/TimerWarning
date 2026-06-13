#!/bin/bash

###############################################################################
# Tests for input-time per-day 16 h cap validation (check_input_time_daily_caps).
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-core.sh" || exit 1
ensure_day_vars
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-parsing.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-validation.sh" || exit 1

_PASS=0
_FAIL=0

_pass() { _PASS=$(( _PASS + 1 )); echo "  PASS  $1"; }
_fail() { _FAIL=$(( _FAIL + 1 )); echo "  FAIL  $1"; }

assert_cap_violation() {
    local desc="$1"
    shift
    local violations
    violations=$(check_input_time_daily_caps "$@")
    if [ -n "${violations}" ]; then
        _pass "${desc}"
    else
        _fail "${desc} (expected violation, got none)"
    fi
}

assert_cap_ok() {
    local desc="$1"
    shift
    local violations
    violations=$(check_input_time_daily_caps "$@")
    if [ -z "${violations}" ]; then
        _pass "${desc}"
    else
        _fail "${desc} (unexpected violation: ${violations})"
    fi
}

echo "=== Input-time daily cap validation tests ==="

config_lines=()
lock_hours_lines=()
uninstall_lock_hours_lines=()
configure_block_enabled="false"
uninstall_protection_mode="none"

# 22 h weekdays together (1am-11pm normalized)
CONFIGURE_INPUT_APPLY_DAY_INDICES="1,2,3,4,5"
assert_cap_violation \
    "Mon-Fri 01:00-23:00 exceeds 16 h cap" \
    restriction 1 "01:00-23:00"
unset CONFIGURE_INPUT_APPLY_DAY_INDICES

# 16 h boundary (7-23 integer hours as HH:MM)
assert_cap_ok \
    "Monday 07:00-23:00 at 16 h cap is OK" \
    restriction 1 "07:00-23:00"

# configure_block merged category
configure_block_enabled="true"
config_lines[1]="MONDAY=08:00-12:00"
lock_hours_lines[1]="CONFIG_LOCK_HOURS_MONDAY=13:00-17:00"
assert_cap_ok \
    "configure_block merge 4h restriction + 4h lock stays under cap" \
    configure_lock 1 "13:00-17:00"

config_lines[1]="MONDAY=07:00-23:00"
assert_cap_violation \
    "configure_block merge exceeds 16 h when lock extends range" \
    configure_lock 1 "06:00-07:00"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
