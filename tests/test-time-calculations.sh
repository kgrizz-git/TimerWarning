#!/bin/bash

###############################################################################
# Tests lib/time-calculations.sh: range durations, interval merging, weekly
# restricted intervals, minute offsets, time formatting, the next unrestricted
# time, and the restriction end-time lookup.
# Runs headless with a temp HOME. `date` is stubbed where the clock matters.
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
source "${SCRIPT_DIR}/lib/configure-validation.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-validation.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-calculations.sh" || exit 1

CONFIG_FILE="${TMP_HOME}/sleep-warning.conf"

_PASS=0
_FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [ "${actual}" = "${expected}" ]; then
        _PASS=$(( _PASS + 1 )); echo "  PASS  ${desc} (${actual})"
    else
        _FAIL=$(( _FAIL + 1 )); echo "  FAIL  ${desc}: expected '${expected}', got '${actual}'"
    fi
}

# An empty config: every day is configured, none restricted.
all_days_empty() {
    printf '%s\n' "SUNDAY=" "MONDAY=" "TUESDAY=" "WEDNESDAY=" "THURSDAY=" "FRIDAY=" "SATURDAY=" "$@" > "${CONFIG_FILE}"
}

echo "=== calculate_range_duration ==="
check "0-5 is 5 h" "5" "$(calculate_range_duration "0-5")"
check "23-6 spans midnight for 7 h" "7" "$(calculate_range_duration "23-6")"
check "0-12 is 12 h" "12" "$(calculate_range_duration "0-12")"
check "0-13 is 13 h" "13" "$(calculate_range_duration "0-13")"
check "HH:MM endpoints" "5" "$(calculate_range_duration "00:00-05:00")"
check "overnight HH:MM endpoints" "7" "$(calculate_range_duration "23:00-06:00")"
check "mixed HH and HH:MM" "6" "$(calculate_range_duration "0-06:00")"
check "surrounding whitespace is trimmed" "5" "$(calculate_range_duration "  0-5  ")"
check "a zero-length range is 0 h" "0" "$(calculate_range_duration "5-5")"
check "a 90-minute range truncates to 1 h" "1" "$(calculate_range_duration "00:00-01:30")"

echo "=== merge_hour_intervals ==="
check "no input prints nothing" "" "$(merge_hour_intervals)"
check "one interval is unchanged" "0:5" "$(merge_hour_intervals "0:5")"
check "overlapping intervals merge" "0:10" "$(merge_hour_intervals "0:5" "4:10")"
check "adjacent intervals merge" "0:10" "$(merge_hour_intervals "0:5" "5:10")"
check "disjoint intervals stay apart" "0:3|5:8" "$(merge_hour_intervals "5:8" "0:3" | paste -sd'|' -)"
check "a contained interval is absorbed" "0:10" "$(merge_hour_intervals "0:10" "2:4")"

echo "=== calculate_total_day_duration ==="
rm -f "${CONFIG_FILE}"
all_days_empty
check "plain day with no overnight from yesterday" "5" "$(calculate_total_day_duration 1 "0-5")"
check "empty ranges are 0 h" "0" "$(calculate_total_day_duration 1 "")"
check "two ranges add up" "7" "$(calculate_total_day_duration 1 "0-5,22-24")"
check "overlapping ranges are merged, not double counted" "8" "$(calculate_total_day_duration 1 "0-5,3-8")"
check "an overnight range counts only today's portion" "3" "$(calculate_total_day_duration 1 "21-5")"
all_days_empty "SUNDAY=23-5"
check "yesterday's overnight tail is added (Mon 0-5 overlaps Sun 23-5)" "5" "$(calculate_total_day_duration 1 "0-5")"
check "tail plus today's overnight start" "6" "$(calculate_total_day_duration 1 "23-5")"
all_days_empty "SATURDAY=22-6"
check "Sunday looks back at Saturday" "6" "$(calculate_total_day_duration 0 "")"
check "partial hours round up" "2" "$(calculate_total_day_duration 1 "00:00-01:30")"

echo "=== range_endpoint_to_day_minutes ==="
check "start role: plain hour" "300" "$(range_endpoint_to_day_minutes 5)"
check "start role: HH:MM" "330" "$(range_endpoint_to_day_minutes 05:30)"
range_endpoint_to_day_minutes 24 >/dev/null; check "start role rejects 24" "1" "$?"
range_endpoint_to_day_minutes 24:00 start >/dev/null; check "start role rejects 24:00" "1" "$?"
check "end role accepts 24" "1440" "$(range_endpoint_to_day_minutes 24 end)"
check "end role accepts 24:00" "1440" "$(range_endpoint_to_day_minutes 24:00 end)"
range_endpoint_to_day_minutes 24:30 end >/dev/null; check "end role rejects 24:30" "1" "$?"
range_endpoint_to_day_minutes 25 end >/dev/null; check "end role rejects 25" "1" "$?"
check "end role still reads ordinary times" "1380" "$(range_endpoint_to_day_minutes 23 end)"
range_endpoint_to_day_minutes "" >/dev/null; check "empty is invalid" "1" "$?"
range_endpoint_to_day_minutes 7:75 >/dev/null; check "minutes over 59 are invalid" "1" "$?"

echo "=== build_weekly_restricted_intervals ==="
all_days_empty
check "no restrictions prints a single blank line" "" "$(build_weekly_restricted_intervals)"
all_days_empty "MONDAY=0-5"
check "Monday 0-5" "1440:1740" "$(build_weekly_restricted_intervals)"
all_days_empty "MONDAY=9-17,20-22"
check "two ranges on one day" "1980:2460|2640:2760" "$(build_weekly_restricted_intervals | paste -sd'|' -)"
all_days_empty "MONDAY=23-6"
check "an overnight range splits at midnight" "2820:2880|2880:3240" "$(build_weekly_restricted_intervals | paste -sd'|' -)"
all_days_empty "SATURDAY=23-6"
check "Saturday overnight wraps to Sunday" "10020:10080|0:360" "$(build_weekly_restricted_intervals | paste -sd'|' -)"
all_days_empty "MONDAY=07:30-08:45"
check "HH:MM endpoints" "1890:1965" "$(build_weekly_restricted_intervals)"
all_days_empty "MONDAY=bogus-range"
check "an unparseable range is skipped" "" "$(build_weekly_restricted_intervals)"
all_days_empty "TUESDAY=16-24"
check "a range ending at 24 runs to the end of the day" "3840:4320" "$(build_weekly_restricted_intervals)"
all_days_empty "TUESDAY=16:00-24:00"
check "a range ending at 24:00 runs to the end of the day" "3840:4320" "$(build_weekly_restricted_intervals)"
all_days_empty "TUESDAY=0-24"
check "0-24 covers the whole day" "2880:4320" "$(build_weekly_restricted_intervals)"
all_days_empty "SATURDAY=16-24"
check "Saturday 16-24 ends at the end of the week" "9600:10080" "$(build_weekly_restricted_intervals)"
all_days_empty "TUESDAY=24-5"
check "24 is not a valid start" "" "$(build_weekly_restricted_intervals)"

echo "=== get_current_minute_offset ==="
date() {
    case "$1" in
        +%w) echo "${FAKE_DOW}" ;;
        +%H) echo "${FAKE_HOUR}" ;;
        +%M) echo "${FAKE_MIN}" ;;
        *) command date "$@" ;;
    esac
}
FAKE_DOW=0 FAKE_HOUR=00 FAKE_MIN=00
check "Sunday midnight is minute 0" "0" "$(get_current_minute_offset)"
FAKE_DOW=1 FAKE_HOUR=08 FAKE_MIN=09
check "leading zeros are not read as octal" "1929" "$(get_current_minute_offset)"
FAKE_DOW=6 FAKE_HOUR=23 FAKE_MIN=59
check "Saturday 23:59 is the last minute of the week" "10079" "$(get_current_minute_offset)"

echo "=== is_minute_restricted ==="
intervals=$'100:200\n500:600'
is_minute_restricted 100 "${intervals}"; check "start is restricted" "0" "$?"
is_minute_restricted 199 "${intervals}"; check "last minute inside is restricted" "0" "$?"
is_minute_restricted 200 "${intervals}"; check "end is not restricted (half-open)" "1" "$?"
is_minute_restricted 550 "${intervals}"; check "second interval" "0" "$?"
is_minute_restricted 300 "${intervals}"; check "a gap is unrestricted" "1" "$?"
is_minute_restricted 100 ""; check "no intervals means unrestricted" "1" "$?"

echo "=== format_minute_offset_to_time ==="
# Current time: Monday 12:00 (1440 + 720 = 2160)
now=2160
check "1 minute away" "in 1 minute" "$(format_minute_offset_to_time 2161 "${now}")"
check "45 minutes away" "in 45 minutes" "$(format_minute_offset_to_time 2205 "${now}")"
check "later today, PM" "at 5:00 PM" "$(format_minute_offset_to_time $((1440 + 17 * 60)) "${now}")"
check "later today, 12:30 PM" "at 12:30 PM" "$(format_minute_offset_to_time $((1440 + 750)) $((1440 + 540)))"
check "midday is PM, not 0 PM" "at 12:00 PM" "$(format_minute_offset_to_time $((1440 + 720)) $((1440 + 540)))"
check "tomorrow morning" "Tomorrow at 6:05 AM" "$(format_minute_offset_to_time $((2880 + 6 * 60 + 5)) "${now}")"
check "tomorrow just after midnight" "Tomorrow at 12:00 AM" "$(format_minute_offset_to_time 2880 "${now}")"
check "two days out uses the day name" "Wednesday at 9:00 AM" "$(format_minute_offset_to_time $((3 * 1440 + 540)) "${now}")"
check "Saturday rolls over to Sunday as tomorrow" "Tomorrow at 7:00 AM" "$(format_minute_offset_to_time 420 $((6 * 1440 + 600)))"
check "an earlier offset wraps into next week" "in 30 minutes" "$(format_minute_offset_to_time 10 $((7 * 1440 - 20)))"

echo "=== get_next_unrestricted_time ==="
all_days_empty
check "no restrictions" "now (no restrictions configured)" "$(get_next_unrestricted_time)"
all_days_empty "MONDAY=0-5"
get_current_minute_offset() { echo "${FAKE_OFFSET}"; }
FAKE_OFFSET=$((1440 + 2 * 60))
check "inside Monday 0-5 the end is 5:00 AM today" "at 5:00 AM" "$(get_next_unrestricted_time)"
FAKE_OFFSET=$((1440 + 4 * 60 + 30))
check "30 minutes before the end" "in 30 minutes" "$(get_next_unrestricted_time)"
FAKE_OFFSET=$((1440 + 6 * 60))
check "already unrestricted gives the current minute" "in 0 minutes" "$(get_next_unrestricted_time)"
all_days_empty "MONDAY=22-6"
FAKE_OFFSET=$((1440 + 23 * 60))
check "an overnight restriction ends tomorrow" "Tomorrow at 6:00 AM" "$(get_next_unrestricted_time)"
all_days_empty "MONDAY=16-24"
FAKE_OFFSET=$((1440 + 17 * 60))
check "a range ending at 24 ends at midnight, tomorrow" "Tomorrow at 12:00 AM" "$(get_next_unrestricted_time)"
all_days_empty "MONDAY=16-24" "TUESDAY=0-5"
check "back-to-back ranges across midnight are one block" "Tomorrow at 5:00 AM" "$(get_next_unrestricted_time)"
all_days_empty "SATURDAY=16-24" "SUNDAY=0-6"
FAKE_OFFSET=$((6 * 1440 + 20 * 60))
check "a range ending at the week boundary continues into Sunday" "Tomorrow at 6:00 AM" "$(get_next_unrestricted_time)"
all_days_empty "SATURDAY=22-6"
FAKE_OFFSET=$((6 * 1440 + 23 * 60 + 30))
check "a Saturday overnight range wraps to Sunday morning" "Tomorrow at 6:00 AM" "$(get_next_unrestricted_time)"
full_day="00:00-23:59,23:59-00:00"
all_days_empty "SUNDAY=${full_day}" "MONDAY=${full_day}" "TUESDAY=${full_day}" "WEDNESDAY=${full_day}" "THURSDAY=${full_day}" "FRIDAY=${full_day}" "SATURDAY=${full_day}"
FAKE_OFFSET=100
check "24/7 restrictions never end" "No unrestricted time scheduled (24/7 restrictions active)" "$(get_next_unrestricted_time)"

echo "=== format_endpoint_12h ==="
check "bare hour matches format_hour_12h" "5:00 AM" "$(format_endpoint_12h 5)"
check "zero-padded hour" "5:00 AM" "$(format_endpoint_12h 05)"
check "HH:MM keeps its minutes" "5:30 AM" "$(format_endpoint_12h 05:30)"
check "midnight" "12:00 AM" "$(format_endpoint_12h 0)"
check "noon" "12:00 PM" "$(format_endpoint_12h 12)"
check "12:15 PM" "12:15 PM" "$(format_endpoint_12h 12:15)"
check "afternoon" "4:45 PM" "$(format_endpoint_12h 16:45)"
check "23:59" "11:59 PM" "$(format_endpoint_12h 23:59)"
check "24 is midnight at the end of the day" "12:00 AM" "$(format_endpoint_12h 24)"
check "24:00 is midnight at the end of the day" "12:00 AM" "$(format_endpoint_12h 24:00)"
check "whitespace is ignored" "6:00 AM" "$(format_endpoint_12h " 06:00 ")"
for bad in 25 24:30 7:60 abc "" 5:5 -1; do
    out="$(format_endpoint_12h "${bad}")"; rc=$?
    check "invalid endpoint '${bad}' returns 1 and prints nothing" "1|" "${rc}|${out}"
done

echo "=== calculate_restriction_end_time ==="
all_days_empty "MONDAY=0-5" "TUESDAY=22-6"
check "inside a same-day range" "5:00 AM|Monday|false" "$(calculate_restriction_end_time 2 1 "0-5")"
check "the last restricted hour" "5:00 AM|Monday|false" "$(calculate_restriction_end_time 4 1 "0-5")"
check "HH:MM range, as parse_config returns it" "5:00 AM|Monday|false" "$(calculate_restriction_end_time 2 1 "$(parse_config 1)")"
check "HH:MM end with minutes" "5:30 AM|Monday|false" "$(calculate_restriction_end_time 2 1 "00:00-05:30")"
check "outside every range" "" "$(calculate_restriction_end_time 12 1 "0-5")"
calculate_restriction_end_time 12 1 "0-5" >/dev/null
check "outside every range returns failure" "1" "$?"
calculate_restriction_end_time 12 3 "" >/dev/null
check "no ranges for today returns failure" "1" "$?"
check "inside an overnight range, ends tomorrow" "6:00 AM|Wednesday|true" "$(calculate_restriction_end_time 23 2 "22-6")"
check "inside an overnight HH:MM range" "6:00 AM|Wednesday|true" "$(calculate_restriction_end_time 23 2 "$(parse_config 2)")"
check "the second of two ranges" "11:00 PM|Monday|false" "$(calculate_restriction_end_time 21 1 "0-5,20-23")"
check "Saturday overnight ends on Sunday" "6:00 AM|Sunday|true" "$(calculate_restriction_end_time 23 6 "22-6")"
check "a range ending at 24 ends at midnight on the next day" "12:00 AM|Tuesday|true" "$(calculate_restriction_end_time 17 1 "16-24")"
check "the same range as HH:MM" "12:00 AM|Tuesday|true" "$(calculate_restriction_end_time 17 1 "16:00-24:00")"
check "Saturday 16-24 ends on Sunday" "12:00 AM|Sunday|true" "$(calculate_restriction_end_time 17 6 "16-24")"
all_days_empty "MONDAY=22-6"
check "yesterday's overnight tail ends today" "6:00 AM|Tuesday|true" "$(calculate_restriction_end_time 3 2 "")"
all_days_empty "SATURDAY=22:00-06:30"
check "Sunday looks back at Saturday's tail, with minutes" "6:30 AM|Sunday|true" "$(calculate_restriction_end_time 3 0 "")"
all_days_empty "MONDAY=22-6" "TUESDAY=0-3"
check "the tail wins over today's own ranges" "6:00 AM|Tuesday|true" "$(calculate_restriction_end_time 1 2 "0-3")"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
