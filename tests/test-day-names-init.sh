#!/bin/bash

###############################################################################
# Test script to ensure DAY_NAMES and DAY_VARS are restored when cleared
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Source core definitions
source "${LIB_DIR}/configure-core.sh" || exit 1

GREEN='\033[0;32m'
RED='\033[0;31m'
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
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected: ${expected}"
        echo "  Got:      ${actual}"
        ((FAILED++))
    fi
}

# Clear arrays to simulate unexpected clobbering
DAY_NAMES=()
DAY_VARS=()

ensure_day_names
ensure_day_vars

test_function "DAY_NAMES length" "7" "${#DAY_NAMES[@]}"
test_function "DAY_NAMES[0]" "Sunday" "${DAY_NAMES[0]}"
test_function "DAY_NAMES[6]" "Saturday" "${DAY_NAMES[6]}"

test_function "DAY_VARS length" "7" "${#DAY_VARS[@]}"
test_function "DAY_VARS[0]" "SUNDAY" "${DAY_VARS[0]}"
test_function "DAY_VARS[6]" "SATURDAY" "${DAY_VARS[6]}"

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
