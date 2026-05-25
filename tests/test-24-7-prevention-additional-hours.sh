#!/bin/bash

###############################################################################
# Sleep Warning System - 24/7 Prevention with Additional Hours Tests
#
# This script tests the extended 24/7 prevention validation that includes
# additional hours (config lock hours and uninstall lock hours) in the
# combined total calculation.
#
# Tests cover:
# - Restriction hours only (backward compatibility)
# - Restriction + lock hours combinations
# - Restriction + uninstall lock hours combinations
# - All three types together
# - Overlapping ranges across types
# - Overnight ranges across types
# - Edge cases (empty arrays, sparse arrays, boundary conditions)
#
# Safety:
#   This test DOES NOT modify your real config file.
#   It only tests the validation function logic.
#
# Usage: ./tests/test-24-7-prevention-additional-hours.sh
###############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Source required modules
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/configure-validation.sh" || exit 1

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    local expected="$3"
    local actual="$4"
    local details="$5"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  ${YELLOW}Expected:${NC} $expected"
        echo -e "  ${YELLOW}Actual:${NC} $actual"
        if [ -n "$details" ]; then
            echo -e "  ${YELLOW}Details:${NC} $details"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test function
test_validation() {
    local test_name="$1"
    local expected_result="$2"
    shift 2
    local test_args=("$@")
    
    local actual_result
    actual_result=$(check_restriction_coverage "${test_args[@]}")
    
    if [ "${actual_result}" = "${expected_result}" ]; then
        print_test_result "${test_name}" "PASS" "${expected_result}" "${actual_result}"
    else
        print_test_result "${test_name}" "FAIL" "${expected_result}" "${actual_result}" "Validation result mismatch"
    fi
}

# Test 1: Restriction hours only (backward compatibility)
echo -e "${BLUE}=== Test 1: Restriction Hours Only (Backward Compatibility) ===${NC}"
test_validation \
    "Restriction hours only - valid (8 hours/day)" \
    "ok" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8"

test_validation \
    "Restriction hours only - high restriction (18 hours/day, 7560 min/week)" \
    "block" \
    "SUNDAY=0-18" \
    "MONDAY=0-18" \
    "TUESDAY=0-18" \
    "WEDNESDAY=0-18" \
    "THURSDAY=0-18" \
    "FRIDAY=0-18" \
    "SATURDAY=0-18"

test_validation \
    "Restriction hours only - 24/7 (blocked)" \
    "block" \
    "SUNDAY=0-12,12-0" \
    "MONDAY=0-12,12-0" \
    "TUESDAY=0-12,12-0" \
    "WEDNESDAY=0-12,12-0" \
    "THURSDAY=0-12,12-0" \
    "FRIDAY=0-12,12-0" \
    "SATURDAY=0-12,12-0"

# Test 2: Restriction + Lock Hours
echo -e "\n${BLUE}=== Test 2: Restriction Hours + Lock Hours ===${NC}"
test_validation \
    "Restriction (8h) + Lock (8h) = 16h/day (6720 min/week, == BLOCK boundary, warn)" \
    "warn" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "CONFIG_LOCK_HOURS_SUNDAY=8-16" \
    "CONFIG_LOCK_HOURS_MONDAY=8-16" \
    "CONFIG_LOCK_HOURS_TUESDAY=8-16" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=8-16" \
    "CONFIG_LOCK_HOURS_THURSDAY=8-16" \
    "CONFIG_LOCK_HOURS_FRIDAY=8-16" \
    "CONFIG_LOCK_HOURS_SATURDAY=8-16"

test_validation \
    "Restriction (8h) + Lock (10h) = 18h/day (7560 min/week, block)" \
    "block" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "CONFIG_LOCK_HOURS_SUNDAY=8-18" \
    "CONFIG_LOCK_HOURS_MONDAY=8-18" \
    "CONFIG_LOCK_HOURS_TUESDAY=8-18" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=8-18" \
    "CONFIG_LOCK_HOURS_THURSDAY=8-18" \
    "CONFIG_LOCK_HOURS_FRIDAY=8-18" \
    "CONFIG_LOCK_HOURS_SATURDAY=8-18"

test_validation \
    "Restriction (8h) + Lock (16h) = 24h/day (blocked)" \
    "block" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "CONFIG_LOCK_HOURS_SUNDAY=8-0" \
    "CONFIG_LOCK_HOURS_MONDAY=8-0" \
    "CONFIG_LOCK_HOURS_TUESDAY=8-0" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=8-0" \
    "CONFIG_LOCK_HOURS_THURSDAY=8-0" \
    "CONFIG_LOCK_HOURS_FRIDAY=8-0" \
    "CONFIG_LOCK_HOURS_SATURDAY=8-0"

# Test 3: Restriction + Uninstall Lock Hours
echo -e "\n${BLUE}=== Test 3: Restriction Hours + Uninstall Lock Hours ===${NC}"
test_validation \
    "Restriction (8h) + Uninstall Lock (8h) = 16h/day (6720 min/week, == BLOCK boundary, warn)" \
    "warn" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=8-16" \
    "UNINSTALL_LOCK_HOURS_MONDAY=8-16" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=8-16" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=8-16" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=8-16" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=8-16" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=8-16"

test_validation \
    "Restriction (8h) + Uninstall Lock (10h) = 18h/day (7560 min/week, block)" \
    "block" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=8-18" \
    "UNINSTALL_LOCK_HOURS_MONDAY=8-18" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=8-18" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=8-18" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=8-18" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=8-18" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=8-18"

test_validation \
    "Restriction (8h) + Uninstall Lock (16h) = 24h/day (blocked)" \
    "block" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=8-0" \
    "UNINSTALL_LOCK_HOURS_MONDAY=8-0" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=8-0" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=8-0" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=8-0" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=8-0" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=8-0"

# Test 4: All Three Types Together
echo -e "\n${BLUE}=== Test 4: All Three Types Together ===${NC}"
test_validation \
    "Restriction (6h) + Lock (6h) + Uninstall (6h) = 18h/day (7560 min/week, block)" \
    "block" \
    "SUNDAY=0-6" \
    "MONDAY=0-6" \
    "TUESDAY=0-6" \
    "WEDNESDAY=0-6" \
    "THURSDAY=0-6" \
    "FRIDAY=0-6" \
    "SATURDAY=0-6" \
    "CONFIG_LOCK_HOURS_SUNDAY=6-12" \
    "CONFIG_LOCK_HOURS_MONDAY=6-12" \
    "CONFIG_LOCK_HOURS_TUESDAY=6-12" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=6-12" \
    "CONFIG_LOCK_HOURS_THURSDAY=6-12" \
    "CONFIG_LOCK_HOURS_FRIDAY=6-12" \
    "CONFIG_LOCK_HOURS_SATURDAY=6-12" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=12-18" \
    "UNINSTALL_LOCK_HOURS_MONDAY=12-18" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=12-18" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=12-18" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=12-18" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=12-18" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=12-18"

test_validation \
    "Restriction (8h) + Lock (8h) + Uninstall (8h) = 24h/day (blocked)" \
    "block" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "CONFIG_LOCK_HOURS_SUNDAY=8-16" \
    "CONFIG_LOCK_HOURS_MONDAY=8-16" \
    "CONFIG_LOCK_HOURS_TUESDAY=8-16" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=8-16" \
    "CONFIG_LOCK_HOURS_THURSDAY=8-16" \
    "CONFIG_LOCK_HOURS_FRIDAY=8-16" \
    "CONFIG_LOCK_HOURS_SATURDAY=8-16" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=16-0" \
    "UNINSTALL_LOCK_HOURS_MONDAY=16-0" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=16-0" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=16-0" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=16-0" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=16-0" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=16-0"

# Test 5: Overlapping Ranges Across Types
echo -e "\n${BLUE}=== Test 5: Overlapping Ranges Across Types ===${NC}"
test_validation \
    "Overlapping: Restriction (0-8) + Lock (7-15) = merged to 0-15 (15h/day, valid)" \
    "ok" \
    "MONDAY=0-8" \
    "CONFIG_LOCK_HOURS_MONDAY=7-15"

test_validation \
    "Overlapping: Restriction (0-8) + Lock (7-15) + Uninstall (10-18) = merged to 0-18 (18h/day, 7560 min/week, block)" \
    "block" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "CONFIG_LOCK_HOURS_SUNDAY=7-15" \
    "CONFIG_LOCK_HOURS_MONDAY=7-15" \
    "CONFIG_LOCK_HOURS_TUESDAY=7-15" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=7-15" \
    "CONFIG_LOCK_HOURS_THURSDAY=7-15" \
    "CONFIG_LOCK_HOURS_FRIDAY=7-15" \
    "CONFIG_LOCK_HOURS_SATURDAY=7-15" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_MONDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=10-18"

test_validation \
    "Overlapping all days: Restriction (0-8) + Lock (7-15) + Uninstall (10-18) = 18h/day (7560 min/week, block)" \
    "block" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "TUESDAY=0-8" \
    "WEDNESDAY=0-8" \
    "THURSDAY=0-8" \
    "FRIDAY=0-8" \
    "SATURDAY=0-8" \
    "CONFIG_LOCK_HOURS_SUNDAY=7-15" \
    "CONFIG_LOCK_HOURS_MONDAY=7-15" \
    "CONFIG_LOCK_HOURS_TUESDAY=7-15" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=7-15" \
    "CONFIG_LOCK_HOURS_THURSDAY=7-15" \
    "CONFIG_LOCK_HOURS_FRIDAY=7-15" \
    "CONFIG_LOCK_HOURS_SATURDAY=7-15" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_MONDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=10-18" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=10-18"

# Test 6: Overnight Ranges Across Types
echo -e "\n${BLUE}=== Test 6: Overnight Ranges Across Types ===${NC}"
test_validation \
    "Overnight: Restriction (23-6) + Lock (22-5) = merged correctly (valid)" \
    "ok" \
    "MONDAY=23-6" \
    "CONFIG_LOCK_HOURS_MONDAY=22-5"

test_validation \
    "Overnight: Restriction (23-6) + Lock (6-14) + Uninstall (14-22) = 18h/day (7560 min/week, block)" \
    "block" \
    "SUNDAY=23-6" \
    "MONDAY=23-6" \
    "TUESDAY=23-6" \
    "WEDNESDAY=23-6" \
    "THURSDAY=23-6" \
    "FRIDAY=23-6" \
    "SATURDAY=23-6" \
    "CONFIG_LOCK_HOURS_SUNDAY=6-14" \
    "CONFIG_LOCK_HOURS_MONDAY=6-14" \
    "CONFIG_LOCK_HOURS_TUESDAY=6-14" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=6-14" \
    "CONFIG_LOCK_HOURS_THURSDAY=6-14" \
    "CONFIG_LOCK_HOURS_FRIDAY=6-14" \
    "CONFIG_LOCK_HOURS_SATURDAY=6-14" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=14-22" \
    "UNINSTALL_LOCK_HOURS_MONDAY=14-22" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=14-22" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=14-22" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=14-22" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=14-22" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=14-22"

# Test 7: Edge Cases - Empty Arrays
echo -e "\n${BLUE}=== Test 7: Edge Cases - Empty Arrays ===${NC}"
test_validation \
    "Empty restriction hours (no config_lines)" \
    "ok"

test_validation \
    "Empty lock hours (only restriction hours)" \
    "ok" \
    "SUNDAY=0-8" \
    "MONDAY=0-8"

test_validation \
    "Empty uninstall lock hours (only restriction + lock)" \
    "ok" \
    "SUNDAY=0-8" \
    "MONDAY=0-8" \
    "CONFIG_LOCK_HOURS_SUNDAY=8-16" \
    "CONFIG_LOCK_HOURS_MONDAY=8-16"

# Test 8: Edge Cases - Sparse Arrays
echo -e "\n${BLUE}=== Test 8: Edge Cases - Sparse Arrays ===${NC}"
test_validation \
    "Sparse: Only some days have restrictions" \
    "ok" \
    "MONDAY=0-8" \
    "WEDNESDAY=0-8" \
    "FRIDAY=0-8"

test_validation \
    "Sparse: Only some days have lock hours" \
    "ok" \
    "MONDAY=0-8" \
    "CONFIG_LOCK_HOURS_MONDAY=8-16" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=8-16"

test_validation \
    "Sparse: Mixed days across types" \
    "ok" \
    "MONDAY=0-8" \
    "WEDNESDAY=0-8" \
    "CONFIG_LOCK_HOURS_TUESDAY=8-16" \
    "CONFIG_LOCK_HOURS_THURSDAY=8-16" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=8-16"

# Test 9: Boundary Conditions
echo -e "\n${BLUE}=== Test 9: Boundary Conditions ===${NC}"
test_validation \
    "Exactly 6720 minutes (16h/day, == BLOCK boundary, strict > so allowed but warn) — warn" \
    "warn" \
    "SUNDAY=0-16" \
    "MONDAY=0-16" \
    "TUESDAY=0-16" \
    "WEDNESDAY=0-16" \
    "THURSDAY=0-16" \
    "FRIDAY=0-16" \
    "SATURDAY=0-16"

test_validation \
    "Exactly 6721 minutes (just over BLOCK, 6720) - should block" \
    "block" \
    "SUNDAY=0-16" \
    "MONDAY=0-16" \
    "TUESDAY=0-16" \
    "WEDNESDAY=0-16" \
    "THURSDAY=0-16" \
    "FRIDAY=0-16" \
    "SATURDAY=0-16,16-17"

test_validation \
    "Exactly 10079 minutes (just under 24/7) — block under new thresholds" \
    "block" \
    "SUNDAY=0-12,12-0" \
    "MONDAY=0-12,12-0" \
    "TUESDAY=0-12,12-0" \
    "WEDNESDAY=0-12,12-0" \
    "THURSDAY=0-12,12-0" \
    "FRIDAY=0-12,12-0" \
    "SATURDAY=0-12,12-23"

test_validation \
    "Exactly 10080 minutes (24/7) - should block" \
    "block" \
    "SUNDAY=0-12,12-0" \
    "MONDAY=0-12,12-0" \
    "TUESDAY=0-12,12-0" \
    "WEDNESDAY=0-12,12-0" \
    "THURSDAY=0-12,12-0" \
    "FRIDAY=0-12,12-0" \
    "SATURDAY=0-12,12-0"

# Test 10: Complex Overlapping Scenarios
echo -e "\n${BLUE}=== Test 10: Complex Overlapping Scenarios ===${NC}"
test_validation \
    "Complex: Multiple overlaps within and across types (>6720 min/week, block)" \
    "block" \
    "SUNDAY=0-5,10-15" \
    "MONDAY=0-5,10-15" \
    "TUESDAY=0-5,10-15" \
    "WEDNESDAY=0-5,10-15" \
    "THURSDAY=0-5,10-15" \
    "FRIDAY=0-5,10-15" \
    "SATURDAY=0-5,10-15" \
    "CONFIG_LOCK_HOURS_SUNDAY=4-11,14-20" \
    "CONFIG_LOCK_HOURS_MONDAY=4-11,14-20" \
    "CONFIG_LOCK_HOURS_TUESDAY=4-11,14-20" \
    "CONFIG_LOCK_HOURS_WEDNESDAY=4-11,14-20" \
    "CONFIG_LOCK_HOURS_THURSDAY=4-11,14-20" \
    "CONFIG_LOCK_HOURS_FRIDAY=4-11,14-20" \
    "CONFIG_LOCK_HOURS_SATURDAY=4-11,14-20" \
    "UNINSTALL_LOCK_HOURS_SUNDAY=9-16,19-23" \
    "UNINSTALL_LOCK_HOURS_MONDAY=9-16,19-23" \
    "UNINSTALL_LOCK_HOURS_TUESDAY=9-16,19-23" \
    "UNINSTALL_LOCK_HOURS_WEDNESDAY=9-16,19-23" \
    "UNINSTALL_LOCK_HOURS_THURSDAY=9-16,19-23" \
    "UNINSTALL_LOCK_HOURS_FRIDAY=9-16,19-23" \
    "UNINSTALL_LOCK_HOURS_SATURDAY=9-16,19-23"

# Phase 4.4 / weekly-threshold-lowering: HH:MM format and split-range fixtures.
# After 2026-05-24 threshold lowering, check_restriction_coverage uses:
#   WARN  > 5040 min/week  (>12 h/day avg)
#   BLOCK > 6720 min/week  (>16 h/day avg, strict >)
# The per-day 16-h cap in lib/daily-caps.sh is the primary hard enforcer;
# this weekly check is a defense-in-depth backstop.
echo -e "\n${BLUE}=== Test 11: HH:MM Format (Phase 4.4) ===${NC}"

# Single day with 16 h in HH:MM — weekly total 960 min → "ok"
test_validation \
    "HH:MM: MONDAY=00:00-16:00 (16 h, 960 min/week) — ok" \
    "ok" \
    "MONDAY=00:00-16:00"

# All 7 days 8 h in HH:MM — weekly total 3360 min → "ok"
test_validation \
    "HH:MM: all days 08:00-16:00 (8 h each, 3360 min/week) — ok" \
    "ok" \
    "SUNDAY=08:00-16:00" \
    "MONDAY=08:00-16:00" \
    "TUESDAY=08:00-16:00" \
    "WEDNESDAY=08:00-16:00" \
    "THURSDAY=08:00-16:00" \
    "FRIDAY=08:00-16:00" \
    "SATURDAY=08:00-16:00"

# HH:MM all days 17 h — weekly total 7140 min > 6720 → "block" (under new threshold)
test_validation \
    "HH:MM: all days 06:00-23:00 (17 h each, 7140 min/week) — block" \
    "block" \
    "SUNDAY=06:00-23:00" \
    "MONDAY=06:00-23:00" \
    "TUESDAY=06:00-23:00" \
    "WEDNESDAY=06:00-23:00" \
    "THURSDAY=06:00-23:00" \
    "FRIDAY=06:00-23:00" \
    "SATURDAY=06:00-23:00"

# HH:MM full 24/7 using two contiguous 12-h ranges — weekly total 10080 min → "block"
# (00:00-24:00 is invalid since hour 24 > 23; use 00:00-12:00,12:00-00:00 instead)
test_validation \
    "HH:MM: all days 00:00-12:00,12:00-00:00 (24 h each = 24/7) — block" \
    "block" \
    "SUNDAY=00:00-12:00,12:00-00:00" \
    "MONDAY=00:00-12:00,12:00-00:00" \
    "TUESDAY=00:00-12:00,12:00-00:00" \
    "WEDNESDAY=00:00-12:00,12:00-00:00" \
    "THURSDAY=00:00-12:00,12:00-00:00" \
    "FRIDAY=00:00-12:00,12:00-00:00" \
    "SATURDAY=00:00-12:00,12:00-00:00"

# HH:MM overnight range — 3 h/week → "ok"
test_validation \
    "HH:MM: SUNDAY=23:00-02:00 overnight (3 h/week) — ok" \
    "ok" \
    "SUNDAY=23:00-02:00"

# Split-range on one day covers 24 h on that day — weekly total 1440 min → "ok"
# (weekly-average check does not block single-day full coverage)
test_validation \
    "Split-range: MONDAY=00:00-12:00,12:00-00:00 (24 h Mon, 1440 min/week) — ok" \
    "ok" \
    "MONDAY=00:00-12:00,12:00-00:00"

# HH:MM split-range all 7 days 24 h → block
test_validation \
    "Split-range: all days 00:00-12:00,12:00-00:00 (24/7) — block" \
    "block" \
    "SUNDAY=00:00-12:00,12:00-00:00" \
    "MONDAY=00:00-12:00,12:00-00:00" \
    "TUESDAY=00:00-12:00,12:00-00:00" \
    "WEDNESDAY=00:00-12:00,12:00-00:00" \
    "THURSDAY=00:00-12:00,12:00-00:00" \
    "FRIDAY=00:00-12:00,12:00-00:00" \
    "SATURDAY=00:00-12:00,12:00-00:00"

# HH:MM lock hours + restriction on single day → weekly total still small → "ok"
test_validation \
    "HH:MM lock+restriction: MONDAY=08:00-16:00 + lock 16:00-24:00 (960 min/week) — ok" \
    "ok" \
    "MONDAY=08:00-16:00" \
    "CONFIG_LOCK_HOURS_MONDAY=16:00-24:00"

# Leading-zero hours (octal trap): 08-17 and 09-17 should parse correctly → "ok"
test_validation \
    "Octal-safe: MONDAY=08-17 (9 h/week) — ok" \
    "ok" \
    "MONDAY=08-17"

test_validation \
    "Octal-safe: MONDAY=09-17 (8 h/week) — ok" \
    "ok" \
    "MONDAY=09-17"

# Print summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "Total tests: ${TESTS_RUN}"
echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
if [ ${TESTS_FAILED} -gt 0 ]; then
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    exit 1
else
    echo -e "${GREEN}Failed: ${TESTS_FAILED}${NC}"
    exit 0
fi
