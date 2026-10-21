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

assert_contains_text() {
    local desc="$1" haystack="$2" pattern="$3"
    if [[ "${haystack}" == *"${pattern}"* ]]; then
        _pass "${desc}"
    else
        _fail "${desc} (pattern '${pattern}' not in '${haystack}')"
    fi
}

# Drive the real weekday loop: enter Monday, go back from Tuesday, then leave
# from Monday. A regression that unsets the previous day drops Monday.
test_real_weekday_back_keeps_monday() {
    # shellcheck disable=SC1091
    source "${LIB_DIR}/configure-core.sh"
    # shellcheck disable=SC1091
    source "${LIB_DIR}/configure-workflow.sh"

    ask_weekday_together() { return 1; }
    prompt_continue_day_flow() { return 0; }
    has_dialog_tool() { return 1; }
    # get_day_hours runs in a command substitution, so a shell variable
    # would reset every call. A file counter survives that subshell.
    _GH_FILE="$(mktemp)"
    echo 0 > "${_GH_FILE}"
    get_day_hours() {
        local _n
        _n="$(cat "${_GH_FILE}")"
        _n=$((_n + 1))
        echo "${_n}" > "${_GH_FILE}"
        case "${_n}" in
            1) echo "7-23"; return 0 ;;
            2) echo "back"; return 2 ;;
            *) echo "back"; return 2 ;;
        esac
    }

    local -a config_lines=()
    local -a summary_lines=()
    configure_weekdays_section false config_lines summary_lines
    rm -f "${_GH_FILE}"
    assert_set "real weekday back keeps Monday config_lines" config_lines 1
    assert_contains_text "real weekday back keeps Monday=7-23" "${config_lines[1]}" "MONDAY=7-23"
}

# Same regression on the real lock-hours per-day loop.
test_real_lock_hours_back_keeps_monday() {
    ask_weekday_together() { return 1; }
    ask_weekend_together() { return 1; }
    configure_read() { return 0; }
    has_dialog_tool() { return 1; }
    _GH_FILE="$(mktemp)"
    echo 0 > "${_GH_FILE}"
    get_day_hours() {
        local _n
        _n="$(cat "${_GH_FILE}")"
        _n=$((_n + 1))
        echo "${_n}" > "${_GH_FILE}"
        case "${_n}" in
            1) echo "1-2"; return 0 ;;
            2) echo "9-12"; return 0 ;;
            *) echo "back"; return 2 ;;
        esac
    }

    local -a lock_hours_lines=()
    # The weekday call above returns through a nameref into this function's
    # locals and leaves the day arrays empty here. Refill them before lock hours.
    ensure_day_names
    ensure_day_vars
    configure_lock_hours_section false lock_hours_lines
    rm -f "${_GH_FILE}"
    assert_set "real lock-hours back keeps Monday" lock_hours_lines 1
    assert_contains_text "real lock-hours back keeps Monday 9-12" "${lock_hours_lines[1]}" "CONFIG_LOCK_HOURS_MONDAY=9-12"
}

# write_config still emits Monday when config_lines[1] is set
test_write_config_preserves_monday() {
    local tmp_home
    tmp_home=$(mktemp -d)
    export HOME="${tmp_home}"
    CONFIG_DIR="${HOME}/.config/sleep-warning"
    CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
    mkdir -p "${CONFIG_DIR}/config"

    if ! type ensure_day_names >/dev/null 2>&1; then
        # shellcheck disable=SC1091
        source "${LIB_DIR}/configure-core.sh" || return 1
    fi
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

test_real_weekday_back_keeps_monday
test_real_lock_hours_back_keeps_monday
test_write_config_preserves_monday

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
