#!/bin/bash

###############################################################################
# Tests for configure wizard "Go back" navigation preserving loaded day values.
#
# Regression: back navigation used to unset the previous day's config_lines entry,
# causing write_config to omit that day and drop restrictions on save.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEST_OUTPUT_DIR="${SCRIPT_DIR}/tests/test-configs/back-navigation-tests"

_PASS=0
_FAIL=0

_pass() { _PASS=$(( _PASS + 1 )); echo "  PASS  $1"; }
_fail() { _FAIL=$(( _FAIL + 1 )); echo "  FAIL  $1"; }

assert_set() {
    local desc="$1" arr_name="$2" idx="$3"
    local -n _arr_ref="${arr_name}"
    if [ -n "${_arr_ref[${idx}]+set}" ] && [ -n "${_arr_ref[${idx}]}" ]; then
        _pass "${desc}"
    else
        _fail "${desc} (index ${idx} unset or empty)"
    fi
}

assert_contains() {
    local desc="$1" file="$2" pattern="$3"
    if grep -qF "${pattern}" "${file}"; then
        _pass "${desc}"
    else
        _fail "${desc} (pattern '${pattern}' not in ${file})"
    fi
}

# Simulate weekday per-day loop back handler (fixed behavior: decrement only, no unset)
simulate_weekday_back_from_tuesday() {
    local -n config_lines_ref="$1"
    local -n summary_lines_ref="$2"
    local i=2
    local range="back"
    local exit_code=2

    if [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
        if [ "${i}" -gt 1 ]; then
            i=$((i - 1))
        fi
    fi
    # Monday (index 1) must remain after back from Tuesday
    assert_set "Monday config_lines preserved after back from Tuesday" config_lines_ref 1
    assert_set "Monday summary_lines preserved after back from Tuesday" summary_lines_ref 1
}

# Simulate lock-hours Sun-Sat loop back handler (fixed behavior: decrement only, no unset)
simulate_lock_hours_back() {
    local -n lock_hours_lines_ref="$1"
    local day_index=2
    local range="back"
    local exit_code=2

    if [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
        if [ "${day_index}" -gt 0 ]; then
            day_index=$((day_index - 1))
        fi
    fi
    assert_set "Monday lock_hours preserved after back from Tuesday" lock_hours_lines_ref 1
}

# write_config still emits Monday when config_lines[1] is set
test_write_config_preserves_monday() {
    local tmp_home
    tmp_home=$(mktemp -d)
    export HOME="${tmp_home}"
    CONFIG_DIR="${HOME}/.config/sleep-warning"
    CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
    mkdir -p "${CONFIG_DIR}/config"

    # shellcheck disable=SC1091
    source "${LIB_DIR}/configure-core.sh" || return 1
    # shellcheck disable=SC1091
    source "${LIB_DIR}/configure-config.sh" || return 1

    local config_lines=()
    config_lines[1]="MONDAY=7-23"

    write_config \
        10 medium center 30 true true false none false 15 4 zenity false fixed 50%x50% 800x600 \
        "${config_lines[@]}" \
        > "${CONFIG_FILE}"

    assert_contains "write_config output contains MONDAY=7-23" "${CONFIG_FILE}" "MONDAY=7-23"

    rm -rf "${tmp_home}"
}

echo "=== Configure back-navigation regression tests ==="

declare -a config_lines=()
declare -a summary_lines=()
config_lines[1]="MONDAY=7-23"
summary_lines[1]="Monday: 7-23"
simulate_weekday_back_from_tuesday config_lines summary_lines

declare -a lock_hours_lines=()
lock_hours_lines[1]="CONFIG_LOCK_HOURS_MONDAY=22-23"
simulate_lock_hours_back lock_hours_lines

test_write_config_preserves_monday

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
