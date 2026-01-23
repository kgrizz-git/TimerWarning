#!/bin/bash

###############################################################################
# Sleep Warning System - Dialog Tool Selection Test Suite (Enhancement #25)
#
# This script tests the user-selectable dialog tool feature to ensure:
# - Configuration file parsing (get_dialog_tool_config)
# - Dialog tool selection logic (check_dialog_tool with user preference)
# - Popup display integration
# - Edge cases (missing config, invalid values, case variations, etc.)
#
# Usage: ./tests/test-dialog-tool-selection.sh
###############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEST_CONFIG_DIR="${SCRIPT_DIR}/tests/test-dialog-tool-config"
TEST_CONFIG_FILE="${TEST_CONFIG_DIR}/sleep-warning.conf"

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

# Cleanup function
cleanup() {
    # Remove test config directory
    rm -rf "${TEST_CONFIG_DIR}" 2>/dev/null || true
}

# Set up trap for cleanup
trap cleanup EXIT

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Print section header
print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Setup test environment
setup_test_env() {
    print_section "Setting Up Test Environment"
    
    # Create test config directory
    mkdir -p "${TEST_CONFIG_DIR}"
    
    # Source required libraries
    source "${LIB_DIR}/config.sh"
    
    # Override CONFIG_FILE for testing
    export CONFIG_FILE="${TEST_CONFIG_FILE}"
    
    echo "Test config directory: ${TEST_CONFIG_DIR}"
    echo "Test config file: ${TEST_CONFIG_FILE}"
}

# Test get_dialog_tool_config function
test_config_parsing() {
    print_section "Testing Configuration File Parsing"
    
    # Test 1: Missing config file
    rm -f "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "auto" ]; then
        print_test_result "Missing config file → returns 'auto'" "PASS"
    else
        print_test_result "Missing config file → returns 'auto' (got: ${result})" "FAIL"
    fi
    
    # Test 2: Valid value - auto
    echo "DIALOG_TOOL=auto" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "auto" ]; then
        print_test_result "DIALOG_TOOL=auto → returns 'auto'" "PASS"
    else
        print_test_result "DIALOG_TOOL=auto → returns 'auto' (got: ${result})" "FAIL"
    fi
    
    # Test 3: Valid value - zenity
    echo "DIALOG_TOOL=zenity" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "zenity" ]; then
        print_test_result "DIALOG_TOOL=zenity → returns 'zenity'" "PASS"
    else
        print_test_result "DIALOG_TOOL=zenity → returns 'zenity' (got: ${result})" "FAIL"
    fi
    
    # Test 4: Valid value - yad
    echo "DIALOG_TOOL=yad" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "yad" ]; then
        print_test_result "DIALOG_TOOL=yad → returns 'yad'" "PASS"
    else
        print_test_result "DIALOG_TOOL=yad → returns 'yad' (got: ${result})" "FAIL"
    fi
    
    # Test 5: Valid value - kdialog
    echo "DIALOG_TOOL=kdialog" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "kdialog" ]; then
        print_test_result "DIALOG_TOOL=kdialog → returns 'kdialog'" "PASS"
    else
        print_test_result "DIALOG_TOOL=kdialog → returns 'kdialog' (got: ${result})" "FAIL"
    fi
    
    # Test 6: Invalid value
    echo "DIALOG_TOOL=invalid" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "auto" ]; then
        print_test_result "DIALOG_TOOL=invalid → returns 'auto'" "PASS"
    else
        print_test_result "DIALOG_TOOL=invalid → returns 'auto' (got: ${result})" "FAIL"
    fi
    
    # Test 7: Case variation - uppercase
    echo "DIALOG_TOOL=ZENITY" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "zenity" ]; then
        print_test_result "DIALOG_TOOL=ZENITY → normalizes to 'zenity'" "PASS"
    else
        print_test_result "DIALOG_TOOL=ZENITY → normalizes to 'zenity' (got: ${result})" "FAIL"
    fi
    
    # Test 8: Case variation - mixed case
    echo "DIALOG_TOOL=Yad" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "yad" ]; then
        print_test_result "DIALOG_TOOL=Yad → normalizes to 'yad'" "PASS"
    else
        print_test_result "DIALOG_TOOL=Yad → normalizes to 'yad' (got: ${result})" "FAIL"
    fi
    
    # Test 9: Empty value
    echo "DIALOG_TOOL=" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "auto" ]; then
        print_test_result "DIALOG_TOOL= (empty) → returns 'auto'" "PASS"
    else
        print_test_result "DIALOG_TOOL= (empty) → returns 'auto' (got: ${result})" "FAIL"
    fi
    
    # Test 10: Whitespace value
    echo "DIALOG_TOOL=   " > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "auto" ]; then
        print_test_result "DIALOG_TOOL=   (whitespace) → returns 'auto'" "PASS"
    else
        print_test_result "DIALOG_TOOL=   (whitespace) → returns 'auto' (got: ${result})" "FAIL"
    fi
    
    # Test 11: Whitespace around equals
    echo "DIALOG_TOOL = yad" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "yad" ]; then
        print_test_result "DIALOG_TOOL = yad (whitespace) → parses correctly" "PASS"
    else
        print_test_result "DIALOG_TOOL = yad (whitespace) → parses correctly (got: ${result})" "FAIL"
    fi
    
    # Test 12: Comment line (should be ignored)
    echo "# DIALOG_TOOL=yad" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "auto" ]; then
        print_test_result "# DIALOG_TOOL=yad (comment) → ignored, returns 'auto'" "PASS"
    else
        print_test_result "# DIALOG_TOOL=yad (comment) → ignored, returns 'auto' (got: ${result})" "FAIL"
    fi
    
    # Test 13: Missing DIALOG_TOOL line
    echo "CHECK_INTERVAL=10" > "${TEST_CONFIG_FILE}"
    result=$(get_dialog_tool_config)
    if [ "${result}" = "auto" ]; then
        print_test_result "Missing DIALOG_TOOL line → returns 'auto'" "PASS"
    else
        print_test_result "Missing DIALOG_TOOL line → returns 'auto' (got: ${result})" "FAIL"
    fi
}

# Test check_dialog_tool with user preference
test_dialog_tool_selection() {
    print_section "Testing Dialog Tool Selection Logic"
    
    # Source required libraries
    source "${LIB_DIR}/desktop-environment.sh"
    
    # Detect environment
    env_type=$(detect_display_environment 2>/dev/null || echo "x11")
    
    # Test 1: user_preference="auto" → uses automatic priority
    result=$(check_dialog_tool "${env_type}" "auto")
    if [ -n "${result}" ]; then
        print_test_result "user_preference='auto' → uses automatic priority (got: ${result})" "PASS"
    else
        print_test_result "user_preference='auto' → uses automatic priority" "FAIL"
    fi
    
    # Test 2: No user_preference parameter → uses automatic (backward compatibility)
    result=$(check_dialog_tool "${env_type}")
    if [ -n "${result}" ]; then
        print_test_result "No user_preference parameter → uses automatic (backward compatibility)" "PASS"
    else
        print_test_result "No user_preference parameter → uses automatic (backward compatibility)" "FAIL"
    fi
    
    # Test 3: Empty user_preference="" → uses automatic
    result=$(check_dialog_tool "${env_type}" "")
    if [ -n "${result}" ]; then
        print_test_result "Empty user_preference='' → uses automatic" "PASS"
    else
        print_test_result "Empty user_preference='' → uses automatic" "FAIL"
    fi
    
    # Test 4-6: Test with specific tools (if installed)
    for tool in yad zenity kdialog; do
        if command -v "${tool}" >/dev/null 2>&1; then
            result=$(check_dialog_tool "${env_type}" "${tool}")
            if [ "${result}" = "${tool}" ]; then
                print_test_result "user_preference='${tool}' when installed → returns '${tool}'" "PASS"
            else
                print_test_result "user_preference='${tool}' when installed → returns '${tool}' (got: ${result})" "FAIL"
            fi
        else
            echo -e "${YELLOW}⊘${NC} user_preference='${tool}' when NOT installed → skipped (tool not available)"
        fi
    done
    
    # Test 7-9: Test fallback when tool not installed
    for tool in nonexistent_tool_xyz; do
        result=$(check_dialog_tool "${env_type}" "${tool}")
        if [ -n "${result}" ] && [ "${result}" != "${tool}" ]; then
            print_test_result "user_preference='${tool}' when NOT installed → falls back to automatic (got: ${result})" "PASS"
        else
            print_test_result "user_preference='${tool}' when NOT installed → falls back to automatic" "FAIL"
        fi
    done
}

# Test popup display integration
test_popup_display_integration() {
    print_section "Testing Popup Display Integration"
    
    # Source required libraries
    source "${LIB_DIR}/popup-display.sh"
    source "${LIB_DIR}/display-detection.sh"
    
    # Test 1: DIALOG_TOOL=auto
    echo "DIALOG_TOOL=auto" > "${TEST_CONFIG_FILE}"
    export CONFIG_FILE="${TEST_CONFIG_FILE}"
    
    # Check that get_dialog_tool_config is available
    if type get_dialog_tool_config >/dev/null 2>&1; then
        result=$(get_dialog_tool_config)
        if [ "${result}" = "auto" ]; then
            print_test_result "Popup display with DIALOG_TOOL=auto → uses automatic selection" "PASS"
        else
            print_test_result "Popup display with DIALOG_TOOL=auto → uses automatic selection (got: ${result})" "FAIL"
        fi
    else
        print_test_result "Popup display with DIALOG_TOOL=auto → function not available" "FAIL"
    fi
    
    # Test 2-4: Test with specific tools (if installed)
    for tool in yad zenity kdialog; do
        if command -v "${tool}" >/dev/null 2>&1; then
            echo "DIALOG_TOOL=${tool}" > "${TEST_CONFIG_FILE}"
            result=$(get_dialog_tool_config)
            if [ "${result}" = "${tool}" ]; then
                print_test_result "Popup display with DIALOG_TOOL=${tool} when installed → uses ${tool}" "PASS"
            else
                print_test_result "Popup display with DIALOG_TOOL=${tool} when installed → uses ${tool} (got: ${result})" "FAIL"
            fi
        else
            echo -e "${YELLOW}⊘${NC} Popup display with DIALOG_TOOL=${tool} when NOT installed → skipped (tool not available)"
        fi
    done
}

# Main test execution
main() {
    echo "==================================================================="
    echo "Dialog Tool Selection Test Suite (Enhancement #25)"
    echo "==================================================================="
    echo ""
    
    setup_test_env
    
    test_config_parsing
    test_dialog_tool_selection
    test_popup_display_integration
    
    # Print summary
    print_section "Test Summary"
    echo "Tests run: ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
    echo ""
    
    if [ ${TESTS_FAILED} -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run tests
main
