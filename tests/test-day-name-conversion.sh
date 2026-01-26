#!/bin/bash

###############################################################################
# Test script for day name conversion functions and constants
# Tests the code quality improvements: day name conversion and magic numbers
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Source the functions we need
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/config.sh" || exit 1

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

test_constant() {
    local test_name="$1"
    local constant_name="$2"
    local expected="$3"
    
    echo -n "Testing: ${test_name}... "
    
    if [ "${!constant_name}" = "${expected}" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected: ${expected}"
        echo "  Got:      ${!constant_name}"
        ((FAILED++))
        return 1
    fi
}

echo "=========================================="
echo "Testing Day Name Conversion Functions"
echo "=========================================="
echo ""

# Test day_num_to_name_upper() for all days
test_function "day_num_to_name_upper(0)" "SUNDAY" "$(day_num_to_name_upper 0)"
test_function "day_num_to_name_upper(1)" "MONDAY" "$(day_num_to_name_upper 1)"
test_function "day_num_to_name_upper(2)" "TUESDAY" "$(day_num_to_name_upper 2)"
test_function "day_num_to_name_upper(3)" "WEDNESDAY" "$(day_num_to_name_upper 3)"
test_function "day_num_to_name_upper(4)" "THURSDAY" "$(day_num_to_name_upper 4)"
test_function "day_num_to_name_upper(5)" "FRIDAY" "$(day_num_to_name_upper 5)"
test_function "day_num_to_name_upper(6)" "SATURDAY" "$(day_num_to_name_upper 6)"

# Test day_num_to_name_title() for all days
test_function "day_num_to_name_title(0)" "Sunday" "$(day_num_to_name_title 0)"
test_function "day_num_to_name_title(1)" "Monday" "$(day_num_to_name_title 1)"
test_function "day_num_to_name_title(2)" "Tuesday" "$(day_num_to_name_title 2)"
test_function "day_num_to_name_title(3)" "Wednesday" "$(day_num_to_name_title 3)"
test_function "day_num_to_name_title(4)" "Thursday" "$(day_num_to_name_title 4)"
test_function "day_num_to_name_title(5)" "Friday" "$(day_num_to_name_title 5)"
test_function "day_num_to_name_title(6)" "Saturday" "$(day_num_to_name_title 6)"

# Test invalid day numbers
echo -n "Testing: day_num_to_name_upper(7) returns error... "
if ! day_num_to_name_upper 7 >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: non-zero exit code"
    ((FAILED++))
fi

echo -n "Testing: day_num_to_name_title(-1) returns error... "
if ! day_num_to_name_title -1 >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: non-zero exit code"
    ((FAILED++))
fi

echo ""
echo "=========================================="
echo "Testing Constants"
echo "=========================================="
echo ""

# Test hour range constants
test_constant "MIN_HOUR" "MIN_HOUR" "0"
test_constant "MAX_HOUR" "MAX_HOUR" "23"

# Test display time constants
test_constant "MIN_DISPLAY_TIME" "MIN_DISPLAY_TIME" "0"
test_constant "MAX_DISPLAY_TIME" "MAX_DISPLAY_TIME" "300"

# Test check interval constants
test_constant "MIN_CHECK_INTERVAL" "MIN_CHECK_INTERVAL" "1"
test_constant "MAX_CHECK_INTERVAL" "MAX_CHECK_INTERVAL" "60"

# Test time calculation constants
test_constant "MINUTES_PER_HOUR" "MINUTES_PER_HOUR" "60"
test_constant "MINUTES_PER_DAY" "MINUTES_PER_DAY" "1440"
test_constant "MINUTES_PER_WEEK" "MINUTES_PER_WEEK" "10080"

echo ""
echo "=========================================="
echo "Testing parse_config() uses day conversion"
echo "=========================================="
echo ""

# Create a temporary config file
TEST_CONFIG=$(mktemp)
cat > "${TEST_CONFIG}" <<EOF
SUNDAY=0-5
MONDAY=9-17
TUESDAY=22-23
WEDNESDAY=
THURSDAY=0-23
FRIDAY=10-14
SATURDAY=20-23
EOF

# Save original CONFIG_FILE
ORIGINAL_CONFIG="${CONFIG_FILE}"
CONFIG_FILE="${TEST_CONFIG}"

# Test parse_config for all days
test_function "parse_config(0) - Sunday" "0-5" "$(parse_config 0)"
test_function "parse_config(1) - Monday" "9-17" "$(parse_config 1)"
test_function "parse_config(2) - Tuesday" "22-23" "$(parse_config 2)"
test_function "parse_config(3) - Wednesday" "" "$(parse_config 3)"
test_function "parse_config(4) - Thursday" "0-23" "$(parse_config 4)"
test_function "parse_config(5) - Friday" "10-14" "$(parse_config 5)"
test_function "parse_config(6) - Saturday" "20-23" "$(parse_config 6)"

# Restore original CONFIG_FILE
CONFIG_FILE="${ORIGINAL_CONFIG}"
rm -f "${TEST_CONFIG}"

echo ""
echo "=========================================="
echo "Test Results:"
echo "=========================================="
echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
if [ "${FAILED}" -gt 0 ]; then
    echo -e "  ${RED}Failed: ${FAILED}${NC}"
    exit 1
else
    echo -e "  ${GREEN}Failed: ${FAILED}${NC}"
    exit 0
fi
