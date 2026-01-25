#!/bin/bash

###############################################################################
# Test script to directly test grid display functions
# Sources configure.sh functions and tests them
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Source the functions we need from their modular homes.
# These functions used to live in the monolithic configure.sh, but are now in lib/ modules.
source "${LIB_DIR}/configure-core.sh" || exit 1   # format_hour_12h, DAY_NAMES
source "${LIB_DIR}/configure-time.sh" || exit 1   # format_range_human, format_ranges_human

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

test_function() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    echo -n "Testing: ${test_name}... "
    
    if [ "${actual}" = "${expected}" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected: ${expected}"
        echo "  Got:      ${actual}"
        ((FAILED++))
        return 1
    fi
}

echo "=========================================="
echo "Testing Grid Display Functions"
echo "=========================================="
echo ""

# Test format_hour_12h
test_function "format_hour_12h(0)" "12:00 AM" "$(format_hour_12h 0)"
test_function "format_hour_12h(12)" "12:00 PM" "$(format_hour_12h 12)"
test_function "format_hour_12h(23)" "11:00 PM" "$(format_hour_12h 23)"
test_function "format_hour_12h(5)" "5:00 AM" "$(format_hour_12h 5)"

# Test format_range_human (single range, same day)
# Note: Range 0-5 means 0:00 to 4:59, but function displays end hour as 5:00 AM
test_function "format_range_human(0-5, Sunday)" "12:00 AM → 5:00 AM" "$(format_range_human "0-5" "Sunday")"

# Test format_range_human (overnight range)
# Note: Range 23-6 means 23:00 to 5:59, but function displays end hour as 6:00 AM
test_function "format_range_human(23-6, Monday)" "11:00 PM → 6:00 AM (Tuesday)" "$(format_range_human "23-6" "Monday")"

# Test format_ranges_human (single range)
test_function "format_ranges_human(0-5, Sunday)" "12:00 AM → 5:00 AM" "$(format_ranges_human "0-5" "Sunday")"

# Test format_ranges_human (multiple ranges)
test_function "format_ranges_human(0-5,22-23, Monday)" "12:00 AM → 5:00 AM AND 10:00 PM → 11:00 PM" "$(format_ranges_human "0-5,22-23" "Monday")"

# Test format_range_human with empty/no restrictions
test_function "format_range_human(empty)" "(no restrictions)" "$(format_range_human "" "Sunday")"
test_function "format_range_human(no restrictions)" "(no restrictions)" "$(format_range_human "(no restrictions)" "Sunday")"

echo ""
echo "=========================================="
echo "Test Results:"
echo "  ${GREEN}Passed: ${PASSED}${NC}"
echo "  ${RED}Failed: ${FAILED}${NC}"
echo "=========================================="

if [ ${FAILED} -eq 0 ]; then
    exit 0
else
    exit 1
fi
