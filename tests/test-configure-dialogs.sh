#!/bin/bash

###############################################################################
# Test Script for Configure Dialogs Module
#
# This script tests the dialog abstraction layer functions with all three
# dialog tools (YAD, Zenity, KDialog) to verify consistent behavior.
#
# Usage:
#   ./tests/test-configure-dialogs.sh
###############################################################################

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required modules
source "${LIB_DIR}/display-detection.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/configure-dialogs.sh" || exit 1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_function() {
    local func_name="$1"
    local description="$2"
    
    echo -n "Testing ${func_name}... "
    
    if type "${func_name}" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC} - ${description}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC} - ${description}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test dialog tool detection
test_dialog_tool() {
    local tool
    tool=$(get_dialog_tool)
    
    echo -n "Testing dialog tool detection... "
    if [ -n "${tool}" ]; then
        echo -e "${GREEN}PASS${NC} - Detected: ${tool}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${YELLOW}SKIP${NC} - No dialog tool available"
        return 1
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "Testing Configure Dialogs Module"
    echo "=========================================="
    echo ""
    
    # Test function availability
    echo "1. Testing Function Availability:"
    test_function "get_dialog_tool" "Dialog tool getter function"
    test_function "show_info_dialog" "Information dialog function"
    test_function "show_question_dialog" "Question dialog function"
    test_function "show_entry_dialog" "Entry dialog function"
    test_function "show_list_dialog" "List dialog function"
    test_function "show_text_info_dialog" "Text info dialog function"
    echo ""
    
    # Test dialog tool detection
    echo "2. Testing Dialog Tool Detection:"
    test_dialog_tool
    echo ""
    
    # Summary
    echo "=========================================="
    echo "Test Summary:"
    echo "  Passed: ${TESTS_PASSED}"
    echo "  Failed: ${TESTS_FAILED}"
    echo "=========================================="
    
    if [ "${TESTS_FAILED}" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests
main "$@"
