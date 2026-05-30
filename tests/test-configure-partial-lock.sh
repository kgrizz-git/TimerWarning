#!/bin/bash

###############################################################################
# Tests for lib/configure-partial-lock.sh (tighten-only partial configure mode)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-core.sh" || exit 1
ensure_day_vars
ensure_day_names
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-parsing.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-partial-lock.sh" || exit 1

_PASS=0
_FAIL=0

_pass() { _PASS=$(( _PASS + 1 )); echo "  PASS  $1"; }
_fail() { _FAIL=$(( _FAIL + 1 )); echo "  FAIL  $1"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        _pass "${desc}"
    else
        _fail "${desc} (expected='${expected}', got='${actual}')"
    fi
}

assert_rc() {
    local desc="$1" expected_rc="$2"
    shift 2
    "$@"
    local rc=$?
    if [ "${rc}" -eq "${expected_rc}" ]; then
        _pass "${desc} (rc=${rc})"
    else
        _fail "${desc} (expected rc=${expected_rc}, got ${rc})"
    fi
}

echo ""
echo "=== configure_partial_lock_ranges_add_only ==="

assert_rc "add range to existing OK" 0 configure_partial_lock_ranges_add_only "9-17" "9-17,20-22"
assert_rc "unchanged OK" 0 configure_partial_lock_ranges_add_only "9-17" "9-17"
assert_rc "remove range fails" 1 configure_partial_lock_ranges_add_only "9-17" "20-22"
assert_rc "clear day fails" 1 configure_partial_lock_ranges_add_only "9-17" ""
assert_rc "empty baseline allows new" 0 configure_partial_lock_ranges_add_only "" "9-17"

echo ""
echo "=== configure_partial_lock_validate_scalar ==="

assert_rc "lower interval OK" 0 configure_partial_lock_validate_scalar check_interval 10 5
assert_rc "higher interval blocked" 1 configure_partial_lock_validate_scalar check_interval 10 15
assert_rc "higher min display OK" 0 configure_partial_lock_validate_scalar min_display_time 30 45
assert_rc "lower min display blocked" 1 configure_partial_lock_validate_scalar min_display_time 30 20
assert_rc "disable configure block blocked" 1 configure_partial_lock_validate_scalar configure_block_enabled true false
assert_rc "enable configure block OK" 0 configure_partial_lock_validate_scalar configure_block_enabled false true
assert_rc "auto-close toggle either way OK" 0 configure_partial_lock_validate_scalar POPUP_AUTO_CLOSE true false
assert_rc "auto-close enable OK" 0 configure_partial_lock_validate_scalar POPUP_AUTO_CLOSE false true

echo ""
echo "=== configure_partial_lock_validate_proposed ==="

_configure_partial_lock_reset_session() {
    CONFIGURE_PARTIAL_LOCK_MODE=true
    configure_partial_lock_capture_baseline
}

# Baseline state
config_lines=()
lock_hours_lines=()
uninstall_lock_hours_lines=()
check_interval=10
min_display_time=30
popup_immovable=true
popup_auto_close=true
configure_block_enabled=false
config_lock_enabled=false
uninstall_protection_mode=difficult
pause_enabled=true
pause_duration=5
popup_size=medium
popup_size_mode=fixed
popup_size_custom="50%x50%"
popup_size_custom_absolute="1280x720"
popup_position=center
dialog_tool=auto

_configure_partial_lock_reset_session

check_interval=5
errors=$(configure_partial_lock_validate_proposed)
assert_eq "tighten interval → no errors" "" "${errors}"

_configure_partial_lock_reset_session
check_interval=15
errors=$(configure_partial_lock_validate_proposed)
if [ -n "${errors}" ]; then
    _pass "loosen interval → errors reported"
else
    _fail "loosen interval → expected errors"
fi

_configure_partial_lock_reset_session
config_lines[1]="MONDAY=9-17"
_configure_partial_lock_reset_session
config_lines[1]="MONDAY=9-17,20-22"
errors=$(configure_partial_lock_validate_proposed)
assert_eq "add Monday range OK" "" "${errors}"

_configure_partial_lock_reset_session
config_lines[1]="MONDAY=9-17"
_configure_partial_lock_reset_session
config_lines[1]="MONDAY=10-18"
errors=$(configure_partial_lock_validate_proposed)
if [ -n "${errors}" ]; then
    _pass "edit Monday range blocked"
else
    _fail "edit Monday range should be blocked"
fi

echo ""
echo "=== Summary ==="
echo "Passed: ${_PASS}, Failed: ${_FAIL}"
if [ "${_FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
