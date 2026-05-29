#!/bin/bash

###############################################################################
# Sleep Warning System - Per-Day Cap Tests
#
# Tests for lib/daily-caps.sh: _parse_range_to_minute_intervals,
# _compute_day_merged_minutes, and check_daily_caps.
#
# Usage:
#   bash tests/test-daily-caps.sh
#
# Exit code: 0 = all pass, 1 = one or more failures.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the module under test directly (no other dependencies needed)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/daily-caps.sh" || { echo "FATAL: cannot source lib/daily-caps.sh" >&2; exit 1; }

# ── Test harness ─────────────────────────────────────────────────────────────

_PASS=0
_FAIL=0

_pass() { _PASS=$(( _PASS + 1 )); echo "  PASS  $1"; }
_fail() { _FAIL=$(( _FAIL + 1 )); echo "  FAIL  $1"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        _pass "${desc} (expected='${expected}')"
    else
        _fail "${desc} (expected='${expected}', got='${actual}')"
    fi
}

assert_gt() {
    local desc="$1" threshold="$2" actual="$3"
    if [ "${actual}" -gt "${threshold}" ]; then
        _pass "${desc} (${actual} > ${threshold})"
    else
        _fail "${desc} (expected > ${threshold}, got '${actual}')"
    fi
}

assert_le() {
    local desc="$1" threshold="$2" actual="$3"
    if [ "${actual}" -le "${threshold}" ]; then
        _pass "${desc} (${actual} <= ${threshold})"
    else
        _fail "${desc} (expected <= ${threshold}, got '${actual}')"
    fi
}

# check_daily_caps helper: returns violations string (empty = pass)
run_caps_check() {
    local cfg_block_enabled="$1"
    local un_protection="$2"
    shift 2
    check_daily_caps "${cfg_block_enabled}" "${un_protection}" "$@" 2>/dev/null
}

# ── _parse_range_to_minute_intervals ─────────────────────────────────────────

echo ""
echo "=== _parse_range_to_minute_intervals ==="

# Integer format, non-overnight
result=$(_parse_range_to_minute_intervals "7-23" "self")
assert_eq "7-23 self → 420 1380" "420 1380" "${result}"

# HH:MM format, same range
result=$(_parse_range_to_minute_intervals "07:00-23:00" "self")
assert_eq "07:00-23:00 self → 420 1380" "420 1380" "${result}"

# HH:MM exact 16h = 960 min  (00:00-16:00)
result=$(_parse_range_to_minute_intervals "00:00-16:00" "self")
assert_eq "00:00-16:00 self → 0 960" "0 960" "${result}"

# HH:MM just over 16h (00:00-16:01)
result=$(_parse_range_to_minute_intervals "00:00-16:01" "self")
assert_eq "00:00-16:01 self → 0 961" "0 961" "${result}"

# Overnight self portion
result=$(_parse_range_to_minute_intervals "23-2" "self")
assert_eq "23-2 self → 1380 1440" "1380 1440" "${result}"

# Overnight carry portion
result=$(_parse_range_to_minute_intervals "23-2" "carry")
assert_eq "23-2 carry → 0 120" "0 120" "${result}"

# Leading-zero hours (octal trap: 08, 09)
result=$(_parse_range_to_minute_intervals "08-17" "self")
assert_eq "08-17 self → 480 1020" "480 1020" "${result}"

result=$(_parse_range_to_minute_intervals "09-17" "self")
assert_eq "09-17 self → 540 1020" "540 1020" "${result}"

# HH:MM with non-zero minutes
result=$(_parse_range_to_minute_intervals "07:30-23:00" "self")
assert_eq "07:30-23:00 self → 450 1380" "450 1380" "${result}"

# Bounds: hours > 23 should be rejected
result=$(_parse_range_to_minute_intervals "25:00-26:00" "self")
assert_eq "25:00-26:00 self → rejected (empty)" "" "${result}"

# Bounds: minutes > 59 should be rejected
result=$(_parse_range_to_minute_intervals "07:60-23:00" "self")
assert_eq "07:60-23:00 self → rejected (empty)" "" "${result}"

# Comma-separated list
result=$(_parse_range_to_minute_intervals "0-12,12-23" "self")
# Should emit two lines: "0 720" and "720 1380"
line_count=$(echo "${result}" | grep -c '.')
assert_eq "0-12,12-23 self → 2 intervals" "2" "${line_count}"

# ── _compute_day_merged_minutes ───────────────────────────────────────────────

echo ""
echo "=== _compute_day_merged_minutes ==="

# Exactly 16h (960 min) — non-overnight
m=$(_compute_day_merged_minutes "7-23" "")
assert_eq "7-23 → 960 min" "960" "${m}"

# 17h (1020 min) — should exceed cap
m=$(_compute_day_merged_minutes "6-23" "")
assert_eq "6-23 → 1020 min" "1020" "${m}"

# HH:MM 16h exactly
m=$(_compute_day_merged_minutes "00:00-16:00" "")
assert_eq "00:00-16:00 → 960 min" "960" "${m}"

# HH:MM 16h 1min
m=$(_compute_day_merged_minutes "00:00-16:01" "")
assert_eq "00:00-16:01 → 961 min" "961" "${m}"

# Overlapping ranges: 0-12 + 9-23 → merged 0-23 = 1380 min (>960 → fail)
m=$(_compute_day_merged_minutes "0-12,9-23" "")
assert_eq "0-12,9-23 merged → 1380 min" "1380" "${m}"

# Overnight: 23-2 on Monday
# self portion on Monday = 1380→1440 = 60 min
# carry portion on Tuesday = 0→120 = 120 min
# Monday self:
m=$(_compute_day_merged_minutes "23-2" "")
assert_eq "23-2 self-only → 60 min" "60" "${m}"

# Tuesday carry from Monday's 23-2:
m=$(_compute_day_merged_minutes "" "23-2")
assert_eq "23-2 carry-only → 120 min" "120" "${m}"

# Combined for Tuesday: Tuesday has "9-17" (480 min) + carry from Mon "23-2" (120 min) = 600 min
m=$(_compute_day_merged_minutes "9-17" "23-2")
assert_eq "9-17 + carry 23-2 → 600 min" "600" "${m}"

# Lock-only: CONFIG_LOCK_HOURS alone (no restriction), 16h
m=$(_compute_day_merged_minutes "0-16" "")
assert_eq "0-16 → 960 min" "960" "${m}"

# Merge: restriction 8-20 + lock 15-23 → merged 8-23 = 900 min
m=$(_compute_day_merged_minutes "8-20,15-23" "")
assert_eq "8-20,15-23 merged → 900 min" "900" "${m}"

# ── check_daily_caps ──────────────────────────────────────────────────────────

echo ""
echo "=== check_daily_caps ==="

# Case 1: MONDAY=7-23 (exactly 16h) → PASS
v=$(run_caps_check "false" "none" "MONDAY=7-23")
assert_eq "MONDAY=7-23 (16h) → pass" "" "${v}"

# Case 2: MONDAY=6-23 (17h) → FAIL restriction
v=$(run_caps_check "false" "none" "MONDAY=6-23")
assert_gt "MONDAY=6-23 violation count" "0" "$(echo "${v}" | grep -c 'Monday')"

# Case 3: MONDAY=00:00-16:00 HH:MM (16h) → PASS
v=$(run_caps_check "false" "none" "MONDAY=00:00-16:00")
assert_eq "MONDAY=00:00-16:00 (16h HH:MM) → pass" "" "${v}"

# Case 4: MONDAY=00:00-16:01 HH:MM (>16h) → FAIL
v=$(run_caps_check "false" "none" "MONDAY=00:00-16:01")
assert_gt "MONDAY=00:00-16:01 violation count" "0" "$(echo "${v}" | grep -c 'Monday')"

# Case 5: MONDAY=0-12,12-23 overlapping → 23h merged → FAIL
v=$(run_caps_check "false" "none" "MONDAY=0-12,12-23")
assert_gt "MONDAY=0-12,12-23 (23h merged) violation count" "0" "$(echo "${v}" | grep -c 'Monday')"

# Case 6: overnight MONDAY=23-2 (1h Mon + 2h Tue) → PASS both days
v=$(run_caps_check "false" "none" "MONDAY=23-2")
assert_eq "MONDAY=23-2 overnight → pass" "" "${v}"

# Case 7: Lock-only 16h, CONFIGURE_BLOCK_ENABLED=false → PASS configure_block
v=$(run_caps_check "false" "none" "CONFIG_LOCK_HOURS_MONDAY=0-16")
assert_eq "lock-only 16h, block=false → pass" "" "${v}"

# Case 8: restriction 8-12 + lock 13-24 + configure_block=true → configure_block merged 8-24=16h → PASS
v=$(run_caps_check "true" "none" "MONDAY=8-12" "CONFIG_LOCK_HOURS_MONDAY=13-24")
assert_eq "restr 8-12 + lock 13-24 + block=true → 16h → pass" "" "${v}"

# Case 9: restriction 8-20 + lock 15-23 + configure_block=true → merged 8-23=15h → PASS
v=$(run_caps_check "true" "none" "MONDAY=8-20" "CONFIG_LOCK_HOURS_MONDAY=15-23")
assert_eq "restr 8-20 + lock 15-23 + block=true → 15h → pass" "" "${v}"

# Case 10: restriction 7-23 + configure_block=true → configure_block = 16h → PASS
v=$(run_caps_check "true" "none" "MONDAY=7-23")
assert_eq "restr 7-23 + block=true → configure_block 16h → pass" "" "${v}"

# Case 11: restriction 6-23 + configure_block=true → configure_block = 17h → FAIL
v=$(run_caps_check "true" "none" "MONDAY=6-23")
assert_gt "restr 6-23 + block=true → configure_block 17h fail count" "0" "$(echo "${v}" | grep -c 'Monday')"

# Case 12: restriction 6-23 + configure_block=false + no lock → restriction fails, configure_block passes
v=$(run_caps_check "false" "none" "MONDAY=6-23")
# Should have restriction violation for Monday but NOT configure_block
echo "${v}" | grep -q "configure_block" && \
    _fail "MONDAY=6-23 + block=false should NOT have configure_block violation" || \
    _pass "MONDAY=6-23 + block=false: no configure_block violation (correct)"
echo "${v}" | grep -q "restriction" && \
    _pass "MONDAY=6-23 + block=false: restriction violation present (correct)" || \
    _fail "MONDAY=6-23 + block=false: restriction violation MISSING"

# Case 13: uninstall analogue — restr 7-23, un_prot=difficult → uninstall_block 16h → PASS
v=$(run_caps_check "false" "difficult" "MONDAY=7-23")
assert_eq "restr 7-23 + un_prot=difficult → uninstall_block 16h → pass" "" "${v}"

# Case 14: uninstall analogue — restr 6-23, un_prot=difficult → uninstall_block 17h → FAIL
v=$(run_caps_check "false" "difficult" "MONDAY=6-23")
echo "${v}" | grep -q "uninstall_block" && \
    _pass "restr 6-23 + un_prot=difficult → uninstall_block violation (correct)" || \
    _fail "restr 6-23 + un_prot=difficult → uninstall_block violation MISSING"

# Case 15: uninstall only 16h with un_prot=difficult → PASS (just uninstall_lock, no restriction)
v=$(run_caps_check "false" "difficult" "UNINSTALL_LOCK_HOURS_MONDAY=0-16")
assert_eq "uninstall_lock 16h + un_prot=difficult → pass" "" "${v}"

# Case 16: only Saturday over cap → only Saturday fails
v=$(run_caps_check "false" "none" "SATURDAY=5-22")   # 17h
echo "${v}" | grep -q "Saturday" && \
    _pass "SATURDAY=5-22 (17h) → Saturday violation (correct)" || \
    _fail "SATURDAY=5-22 (17h) → Saturday violation MISSING"
echo "${v}" | grep -q "Sunday\|Monday\|Tuesday\|Wednesday\|Thursday\|Friday" && \
    _fail "SATURDAY=5-22: unexpected violation on another day" || \
    _pass "SATURDAY=5-22: no violation on other days (correct)"

# Case 17: All OK → empty violations and return 0
run_caps_check "true" "difficult" "MONDAY=9-17" "CONFIG_LOCK_HOURS_MONDAY=18-22" "UNINSTALL_LOCK_HOURS_MONDAY=6-8" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    _pass "all-OK config → return 0"
else
    _fail "all-OK config → returned non-zero (unexpected)"
fi

# Case 18: Violation → return 1
run_caps_check "false" "none" "MONDAY=6-23" > /dev/null 2>&1
if [ $? -eq 1 ]; then
    _pass "violation config → return 1"
else
    _fail "violation config → did not return 1 (unexpected)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "Results: ${_PASS} passed, ${_FAIL} failed"
echo "========================================"

[ "${_FAIL}" -eq 0 ]
