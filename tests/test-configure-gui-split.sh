#!/bin/bash

###############################################################################
# Test script to verify configure.sh GUI mode works after module split
# This tests that all split modules are accessible and functions work
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURE_SCRIPT="${PROJECT_ROOT}/configure.sh"
LIB_DIR="${PROJECT_ROOT}/lib"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Test function
test_check() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Testing: ${test_name}... "
    
    if eval "${command}" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

echo "=========================================="
echo "Testing configure.sh GUI Mode (After Split)"
echo "=========================================="
echo ""

# Check if we have a display
if [ -z "${DISPLAY}" ]; then
    echo -e "${YELLOW}WARNING: No DISPLAY set. GUI tests will be limited.${NC}"
    echo ""
fi

# Test 1: All new modules exist
test_check "All split modules exist" "test -f ${LIB_DIR}/configure-input-basic.sh && test -f ${LIB_DIR}/configure-input-popup.sh && test -f ${LIB_DIR}/configure-input-features.sh && test -f ${LIB_DIR}/configure-input-time.sh && test -f ${LIB_DIR}/configure-input-service.sh"

# Test 2: Source all modules and verify functions are accessible
test_check "Source all modules successfully" "bash -c 'source ${LIB_DIR}/configure-core.sh && source ${LIB_DIR}/configure-dialogs.sh && source ${LIB_DIR}/configure-ui.sh && source ${LIB_DIR}/configure-input-basic.sh && source ${LIB_DIR}/configure-input-popup.sh && source ${LIB_DIR}/configure-input-features.sh && source ${LIB_DIR}/configure-input-time.sh && source ${LIB_DIR}/configure-input-service.sh && echo OK'"

# Test 3: Verify key functions from each module are accessible
test_check "get_hour_zenity function accessible" "bash -c 'source ${LIB_DIR}/configure-core.sh && source ${LIB_DIR}/configure-dialogs.sh && source ${LIB_DIR}/configure-input-basic.sh && type get_hour_zenity >/dev/null 2>&1'"

test_check "get_popup_size_config function accessible" "bash -c 'source ${LIB_DIR}/configure-core.sh && source ${LIB_DIR}/configure-dialogs.sh && source ${LIB_DIR}/configure-ui.sh && source ${LIB_DIR}/configure-input-popup.sh && type get_popup_size_config >/dev/null 2>&1'"

test_check "get_security_settings_config function accessible" "bash -c 'source ${LIB_DIR}/configure-core.sh && source ${LIB_DIR}/configure-dialogs.sh && source ${LIB_DIR}/configure-ui.sh && source ${LIB_DIR}/configure-input-features.sh && type get_security_settings_config >/dev/null 2>&1'"

test_check "get_day_hours function accessible" "bash -c 'source ${LIB_DIR}/configure-core.sh && source ${LIB_DIR}/configure-dialogs.sh && source ${LIB_DIR}/configure-ui.sh && source ${LIB_DIR}/configure-time.sh && source ${LIB_DIR}/time-calculations.sh && source ${LIB_DIR}/configure-input-time.sh && type get_day_hours >/dev/null 2>&1'"

test_check "configure_service_mode function accessible" "bash -c 'source ${LIB_DIR}/configure-core.sh && source ${LIB_DIR}/configure-dialogs.sh && source ${LIB_DIR}/configure-ui.sh && source ${LIB_DIR}/configure-input-service.sh && type configure_service_mode >/dev/null 2>&1'"

# Test 4: configure.sh can start in GUI mode (help works)
test_check "configure.sh --gui --help works" "bash ${CONFIGURE_SCRIPT} --gui --help 2>&1 | grep -q 'Force GUI mode'"

# Test 5: configure.sh syntax is valid with new modules
test_check "configure.sh syntax valid" "bash -n ${CONFIGURE_SCRIPT}"

# Test 6: Dialog tool detection works
test_check "Dialog tool detection works" "bash -c 'source ${LIB_DIR}/configure-core.sh && has_dialog_tool'"

# Test 7: GUI mode detection works
if [ -n "${DISPLAY}" ]; then
    test_check "GUI mode detection works" "bash -c 'source ${LIB_DIR}/configure-core.sh && source ${LIB_DIR}/desktop-environment.sh && has_gui && has_dialog_tool'"
fi

echo ""
echo "=========================================="
echo "Test Results:"
echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
if [ ${FAILED} -gt 0 ]; then
    echo -e "  ${RED}Failed: ${FAILED}${NC}"
    exit 1
else
    echo -e "  ${GREEN}All tests passed!${NC}"
    echo ""
    echo "Note: For full GUI testing, manually run:"
    echo "  ./configure.sh --gui"
    echo ""
    echo "Then test each menu option to verify all functions work correctly."
    exit 0
fi
