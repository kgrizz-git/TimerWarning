#!/bin/bash

###############################################################################
# Tests lib/config-safety.sh: default hours, last-assignment reads, runtime
# hour normalization, cap-input collection, the runtime cap gate, and the
# default-filling helper the wizard save gate uses.
# Runs headless with a temp HOME.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "${TMP_HOME}"' EXIT
export HOME="${TMP_HOME}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/config.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-parsing.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/daily-caps.sh" || exit 1

CONFIG_FILE="${TMP_HOME}/sleep-warning.conf"

_PASS=0
_FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        _PASS=$(( _PASS + 1 )); echo "  PASS  ${desc} (${actual})"
    else
        _FAIL=$(( _FAIL + 1 )); echo "  FAIL  ${desc}: expected '${expected}', got '${actual}'"
    fi
}

write_config() {
    printf '%s\n' "$@" > "${CONFIG_FILE}"
}

echo "=== get_default_hours_for_day ==="
check "Sunday" "1-5" "$(get_default_hours_for_day 0)"
for d in 1 2 3 4 5; do
    check "weekday ${d}" "0-5" "$(get_default_hours_for_day "${d}")"
done
check "Saturday" "1-5" "$(get_default_hours_for_day 6)"
get_default_hours_for_day 7 >/dev/null
check "day 7 returns failure" "1" "$?"
get_default_hours_for_day "" >/dev/null
check "empty day returns failure" "1" "$?"

echo "=== _config_last_assigned_value ==="
rm -f "${CONFIG_FILE}"
_config_last_assigned_value MONDAY >/dev/null
check "missing file returns 1" "1" "$?"
write_config "TUESDAY=1-5"
_config_last_assigned_value MONDAY >/dev/null
check "absent key returns 1" "1" "$?"
write_config "MONDAY=1-2" "MONDAY=3-4"
check "last assignment wins" "3-4" "$(_config_last_assigned_value MONDAY)"
write_config "MONDAY="
check "present but empty prints nothing" "" "$(_config_last_assigned_value MONDAY)"
_config_last_assigned_value MONDAY >/dev/null
check "present but empty returns 0" "0" "$?"
write_config "  MONDAY = 22 - 6  "
check "surrounding whitespace is trimmed" "22 - 6" "$(_config_last_assigned_value MONDAY)"
write_config "MONDAY=a=b"
check "a value keeps later equals signs" "a=b" "$(_config_last_assigned_value MONDAY)"

echo "=== _config_hours_as_runtime ==="
check "empty stays empty" "" "$(_config_hours_as_runtime "")"
check "whitespace-only stays empty" "" "$(_config_hours_as_runtime "   ")"
check "plain hours are normalized" "07:00-23:00" "$(_config_hours_as_runtime "7-23")"
check "spaced overnight is normalized" "22:00-06:00" "$(_config_hours_as_runtime "22 - 6")"
check "mixed 22-06:00 is normalized" "22:00-06:00" "$(_config_hours_as_runtime "22-06:00")"
garbage_out="$(_config_hours_as_runtime "not-a-range")"
if [[ "${garbage_out}" =~ ^[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}$ ]]; then
    check "garbage never becomes a valid HH:MM range" "not a range" "${garbage_out}"
else
    check "garbage never becomes a valid HH:MM range" "not a range" "not a range"
fi

echo "=== collect_runtime_daily_cap_inputs ==="
write_config \
    "MONDAY=7-23" \
    "TUESDAY=" \
    "CONFIG_LOCK_HOURS_MONDAY=8-12" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=22 - 6" \
    "CONFIGURE_BLOCK_ENABLED=yes" \
    "UNINSTALL_PROTECTION_MODE=none" \
    "CONFIG_LOCK_ENABLED=true"
cfg=() lock=() uninst=() cbe="" upm=""
collect_runtime_daily_cap_inputs cfg lock uninst cbe upm
check "Sunday restriction defaults" "SUNDAY=1-5" "${cfg[0]}"
check "Monday restriction is normalized" "MONDAY=07:00-23:00" "${cfg[1]}"
check "an explicit empty Tuesday stays empty" "TUESDAY=" "${cfg[2]}"
check "Wednesday restriction defaults" "WEDNESDAY=0-5" "${cfg[3]}"
check "Saturday restriction defaults" "SATURDAY=1-5" "${cfg[6]}"
check "Monday configure lock is read" "CONFIG_LOCK_HOURS_MONDAY=08:00-12:00" "${lock[1]}"
check "an omitted configure lock day stays unset" "" "${lock[4]:-}"
check "Friday uninstall lock is normalized" "UNINSTALL_LOCK_HOURS_FRIDAY=22:00-06:00" "${uninst[5]}"
check "configure block flag resolves yes to true" "true" "${cbe}"
check "uninstall protection mode is read" "none" "${upm}"
check "lock enabled is appended after the day lines" "CONFIG_LOCK_ENABLED=true" "${lock[@]: -1}"

echo "=== runtime_daily_caps_are_safe ==="
rm -f "${CONFIG_FILE}"
runtime_daily_caps_are_safe
check "a missing config file is safe" "0" "$?"
write_config "MONDAY=7-23"
runtime_daily_caps_are_safe
check "16 h is safe" "0" "$?"
write_config "MONDAY=6-23"
runtime_daily_caps_are_safe
check "17 h is unsafe" "1" "$?"
write_config "MONDAY=not-a-range"
runtime_daily_caps_are_safe
check "an unparseable day is unsafe" "1" "$?"
write_config "MONDAY=8-20" "CONFIG_LOCK_HOURS_MONDAY=15-23" "CONFIGURE_BLOCK_ENABLED=yes"
runtime_daily_caps_are_safe
check "restriction plus lock merged to 15 h is safe" "0" "$?"
write_config "MONDAY=6-23" "CONFIGURE_BLOCK_ENABLED=no"
runtime_daily_caps_are_safe
check "the restriction alone still counts with the block off" "1" "$?"

echo "=== append_missing_restriction_default_lines ==="
missing=()
append_missing_restriction_default_lines missing "MONDAY=7-23" "TUESDAY=" "CONFIG_LOCK_HOURS_WEDNESDAY=1-2"
check "five days are missing" "5" "${#missing[@]}"
check "Sunday gets the Sunday default" "SUNDAY=1-5" "${missing[0]}"
check "Wednesday is still missing despite a lock line" "WEDNESDAY=0-5" "${missing[1]}"
check "Saturday gets the Saturday default" "SATURDAY=1-5" "${missing[4]}"
all_present=()
append_missing_restriction_default_lines all_present SUNDAY=1 MONDAY=1 TUESDAY=1 WEDNESDAY=1 THURSDAY=1 FRIDAY=1 SATURDAY=1
check "nothing is added when every day is present" "0" "${#all_present[@]}"
none_present=()
append_missing_restriction_default_lines none_present
check "all seven are added from no arguments" "7" "${#none_present[@]}"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[[ "${_FAIL}" -eq 0 ]] || exit 1
