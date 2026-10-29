#!/bin/bash

###############################################################################
# Tests the text show_config_locked_error prints when configure is locked:
# the active range, the end time, and which day the lock ends on. Covers
# integer-hour and HH:MM configs, an overnight tail from the previous day, and
# ranges that end at 24 (midnight at the end of the day).
# Runs headless with a temp HOME and a stubbed clock. Text mode only.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "${TMP_HOME}"' EXIT
export HOME="${TMP_HOME}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-core.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/config.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-parsing.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-validation.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-calculations.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-time.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-ui-errors.sh" || exit 1

CONFIG_FILE="${TMP_HOME}/sleep-warning.conf"

FAKE_DOW=1
FAKE_HOUR=3
date() {
    case "$1" in
        +%w) echo "${FAKE_DOW}" ;;
        +%H) printf '%02d\n' "${FAKE_HOUR}" ;;
        +%H%M) printf '%02d00\n' "${FAKE_HOUR}" ;;
        *) command date "$@" ;;
    esac
}

_PASS=0
_FAIL=0

check_line() {
    local desc="$1" expected="$2" output="$3"
    if printf '%s\n' "${output}" | grep -Fqx -- "${expected}"; then
        _PASS=$(( _PASS + 1 )); echo "  PASS  ${desc} (${expected})"
    else
        _FAIL=$(( _FAIL + 1 )); echo "  FAIL  ${desc}: no line '${expected}' in:"
        printf '%s\n' "${output}" | sed 's/^/          /'
    fi
}

write_config() {
    printf '%s\n' "SUNDAY=" "MONDAY=" "TUESDAY=" "WEDNESDAY=" "THURSDAY=" "FRIDAY=" "SATURDAY=" "$@" > "${CONFIG_FILE}"
}

# message DAY HOUR: the text-mode error for that clock.
message() {
    FAKE_DOW="$1"
    FAKE_HOUR="$2"
    show_config_locked_error false Configuration 2>&1
}

echo "=== same-day restriction ==="
write_config "MONDAY=0-5"
out="$(message 1 3)"
check_line "headline names the restriction" "Error: Configuration is locked during restricted hours." "${out}"
check_line "active range" "Active restriction: 12:00am -> 5:00am" "${out}"
check_line "ends today at 5:00 AM" "Lock ends: 5:00 AM today" "${out}"

echo "=== HH:MM config ==="
write_config "MONDAY=00:00-05:30"
out="$(message 1 3)"
check_line "end time keeps its minutes" "Lock ends: 5:30 AM today" "${out}"

echo "=== overnight range, started yesterday ==="
write_config "TUESDAY=22-6"
out="$(message 3 3)"
check_line "the tail is active on Wednesday" "Current time: Wednesday, 3:00 AM" "${out}"
check_line "ends Wednesday morning" "Lock ends: 6:00 AM on Wednesday" "${out}"
write_config "TUESDAY=22:00-06:30"
out="$(message 3 3)"
check_line "the tail with minutes" "Lock ends: 6:30 AM on Wednesday" "${out}"

echo "=== overnight range, started today ==="
write_config "TUESDAY=22-6"
out="$(message 2 23)"
check_line "ends tomorrow" "Lock ends: 6:00 AM on Wednesday" "${out}"

echo "=== range ending at 24 ==="
write_config "MONDAY=16-24"
out="$(message 1 17)"
check_line "the range reads as ending at midnight" "Active restriction: 4:00pm -> 12:00am" "${out}"
check_line "the lock ends at midnight, on the next day" "Lock ends: 12:00 AM on Tuesday" "${out}"
write_config "MONDAY=16:00-24:00"
out="$(message 1 23)"
check_line "the HH:MM form agrees" "Lock ends: 12:00 AM on Tuesday" "${out}"
write_config "SATURDAY=16-24"
out="$(message 6 20)"
check_line "Saturday's midnight is Sunday" "Lock ends: 12:00 AM on Sunday" "${out}"

echo "=== lock hours only ==="
write_config "CONFIG_LOCK_HOURS_MONDAY=1-4"
out="$(message 1 2)"
check_line "headline names the lock hours" "Error: Configuration is locked during configured lock hours." "${out}"
check_line "lock ends today" "Lock ends: 4:00 AM today" "${out}"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[[ "${_FAIL}" -eq 0 ]] || exit 1
