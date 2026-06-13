#!/bin/bash

###############################################################################
# Tests that time-parsing and daily-caps helpers tolerate set -u with unset IFS.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-core.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-parsing.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/daily-caps.sh" || exit 1

_PASS=0
_FAIL=0

_pass() { _PASS=$(( _PASS + 1 )); echo "  PASS  $1"; }
_fail() { _FAIL=$(( _FAIL + 1 )); echo "  FAIL  $1"; }

run_under_set_u() {
    local desc="$1"
    shift
    local err_file
    err_file=$(mktemp)
    if (
        set -u
        unset IFS
        "$@"
    ) 2>"${err_file}"; then
        if grep -q 'IFS: unbound variable' "${err_file}"; then
            _fail "${desc} (IFS unbound error: $(cat "${err_file}"))"
        else
            _pass "${desc}"
        fi
    else
        if grep -q 'IFS: unbound variable' "${err_file}"; then
            _fail "${desc} (IFS unbound error: $(cat "${err_file}"))"
        else
            _fail "${desc} (command failed: $(cat "${err_file}"))"
        fi
    fi
    rm -f "${err_file}"
}

echo "=== IFS set -u robustness tests ==="

run_under_set_u "normalize_time_range with unset IFS" \
    bash -c 'source "'"${SCRIPT_DIR}"'/lib/time-parsing.sh"; normalize_time_range "11pm-5am" >/dev/null'

run_under_set_u "convert_time_range_to_24hour with unset IFS" \
    bash -c 'source "'"${SCRIPT_DIR}"'/lib/time-parsing.sh"; convert_time_range_to_24hour "11pm-5am" >/dev/null'

run_under_set_u "check_daily_caps with unset IFS" \
    bash -c 'source "'"${SCRIPT_DIR}"'/lib/daily-caps.sh"; check_daily_caps false none "MONDAY=7-23" >/dev/null'

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
