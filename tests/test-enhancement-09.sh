#!/bin/bash

###############################################################################
# Test Suite for Enhancement #9: System Sleep/Hibernate Detection and Popup Queue Management
#
# This script tests the new features including:
# - Configuration validation (timing conflict detection)
# - PID file management functions
# - Popup detection functions (unit tests)
# - Sleep detection functions (unit tests)
#
# Safety:
#   This test uses a temporary test config directory and does NOT touch your real installed config.
#
# Usage:
#   ./tests/test-enhancement-09.sh
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test config directory
TEST_CONFIG_DIR="${HOME}/.config/sleep-warning-test"
TEST_CONFIG_FILE="${TEST_CONFIG_DIR}/config/sleep-warning.conf"

# Test counters
PASSED=0
FAILED=0
TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    
    TOTAL=$((TOTAL + 1))
    if [ "${result}" = "PASS" ]; then
        echo -e "${GREEN}[PASS]${NC} ${test_name}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}[FAIL]${NC} ${test_name}"
        if [ -n "${details}" ]; then
            echo "  Details: ${details}"
        fi
        FAILED=$((FAILED + 1))
    fi
}

# Setup test config
setup_test_config() {
    mkdir -p "$(dirname "${TEST_CONFIG_FILE}")"
    cat > "${TEST_CONFIG_FILE}" <<EOF
# Test configuration
CHECK_INTERVAL=10
POPUP_MIN_DISPLAY_TIME=30
EOF
}

# Cleanup test config
cleanup_test_config() {
    rm -rf "${TEST_CONFIG_DIR}" 2>/dev/null || true
}

# Source required modules
source_modules() {
    source "${LIB_DIR}/config.sh" 2>/dev/null || return 1
    source "${LIB_DIR}/configure-validation.sh" 2>/dev/null || return 1
    source "${LIB_DIR}/popup-display.sh" 2>/dev/null || return 1
    source "${LIB_DIR}/sleep-detection.sh" 2>/dev/null || return 1
    return 0
}

# Test 1: Configuration Validation - Valid Configuration
test_validation_valid() {
    echo "=== Test 1: Configuration Validation - Valid Configuration ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Test valid configuration: min_display_time (30s) < check_interval (10min = 600s)
    if validate_popup_timing_config 30 10 2>&1; then
        print_test_result "Valid config (30s < 10min)" "PASS"
    else
        print_test_result "Valid config (30s < 10min)" "FAIL" "Should return 0 for valid config"
    fi
    
    # Test valid configuration: min_display_time (0s) < check_interval (1min = 60s)
    if validate_popup_timing_config 0 1 2>&1; then
        print_test_result "Valid config (0s < 1min)" "PASS"
    else
        print_test_result "Valid config (0s < 1min)" "FAIL" "Should return 0 for valid config"
    fi
    
    # Test valid configuration: min_display_time (60s) = check_interval (1min = 60s)
    if validate_popup_timing_config 60 1 2>&1; then
        print_test_result "Valid config (60s = 1min)" "PASS"
    else
        print_test_result "Valid config (60s = 1min)" "FAIL" "Should return 0 when equal (boundary case)"
    fi
    
    echo ""
}

# Test 2: Configuration Validation - Invalid Configuration (Conflict)
test_validation_invalid() {
    echo "=== Test 2: Configuration Validation - Invalid Configuration ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Test invalid configuration: min_display_time (300s) > check_interval (1min = 60s)
    local error_msg
    error_msg=$(validate_popup_timing_config 300 1 2>&1)
    if [ $? -ne 0 ] && echo "${error_msg}" | grep -q "Error:"; then
        print_test_result "Invalid config (300s > 1min)" "PASS"
    else
        print_test_result "Invalid config (300s > 1min)" "FAIL" "Should return 1 and show error message"
    fi
    
    # Test invalid configuration: min_display_time (120s) > check_interval (1min = 60s)
    error_msg=$(validate_popup_timing_config 120 1 2>&1)
    if [ $? -ne 0 ] && echo "${error_msg}" | grep -q "Error:"; then
        print_test_result "Invalid config (120s > 1min)" "PASS"
    else
        print_test_result "Invalid config (120s > 1min)" "FAIL" "Should return 1 and show error message"
    fi
    
    # Verify error message contains both fix options
    error_msg=$(validate_popup_timing_config 300 1 2>&1)
    if echo "${error_msg}" | grep -q "increase CHECK_INTERVAL" && \
       echo "${error_msg}" | grep -q "decrease POPUP_MIN_DISPLAY_TIME"; then
        print_test_result "Error message includes both fix options" "PASS"
    else
        print_test_result "Error message includes both fix options" "FAIL" "Error message should mention both options"
    fi
    
    echo ""
}

# Test 3: PID File Management - Save and Read
test_pid_file_save_read() {
    echo "=== Test 3: PID File Management - Save and Read ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Use test PID file location
    TEST_PID_FILE="${TEST_CONFIG_DIR}/.popup_pid"
    POPUP_PID_FILE="${TEST_PID_FILE}"
    mkdir -p "$(dirname "${TEST_PID_FILE}")"
    
    # Test saving PID
    local test_pid=12345
    if save_popup_pid "${test_pid}" 2>/dev/null; then
        print_test_result "save_popup_pid() saves PID" "PASS"
    else
        print_test_result "save_popup_pid() saves PID" "FAIL" "Could not save PID"
        return
    fi
    
    # Test reading PID
    if [ -f "${TEST_PID_FILE}" ]; then
        local read_pid
        read_pid=$(cat "${TEST_PID_FILE}" 2>/dev/null | tr -d '\n')
        if [ "${read_pid}" = "${test_pid}" ]; then
            print_test_result "PID file contains correct PID" "PASS"
        else
            print_test_result "PID file contains correct PID" "FAIL" "Expected ${test_pid}, got ${read_pid}"
        fi
    else
        print_test_result "PID file exists after save" "FAIL" "PID file not created"
    fi
    
    # Cleanup
    rm -f "${TEST_PID_FILE}" 2>/dev/null
    
    echo ""
}

# Test 4: PID File Management - Cleanup
test_pid_file_cleanup() {
    echo "=== Test 4: PID File Management - Cleanup ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Use test PID file location
    TEST_PID_FILE="${TEST_CONFIG_DIR}/.popup_pid"
    POPUP_PID_FILE="${TEST_PID_FILE}"
    mkdir -p "$(dirname "${TEST_PID_FILE}")"
    
    # Test cleanup of existing PID file
    local test_pid=12345
    echo "${test_pid}" > "${TEST_PID_FILE}"
    if cleanup_popup_pid "${test_pid}" 2>/dev/null; then
        if [ ! -f "${TEST_PID_FILE}" ]; then
            print_test_result "cleanup_popup_pid() removes PID file" "PASS"
        else
            print_test_result "cleanup_popup_pid() removes PID file" "FAIL" "PID file still exists"
        fi
    else
        print_test_result "cleanup_popup_pid() removes PID file" "FAIL" "Function returned error"
    fi
    
    # Test cleanup of non-existent PID file (should succeed)
    if cleanup_popup_pid 99999 2>/dev/null; then
        print_test_result "cleanup_popup_pid() handles missing file" "PASS"
    else
        print_test_result "cleanup_popup_pid() handles missing file" "FAIL" "Should succeed even if file doesn't exist"
    fi
    
    echo ""
}

# Test 5: PID File Management - Stale PID Cleanup
test_stale_pid_cleanup() {
    echo "=== Test 5: PID File Management - Stale PID Cleanup ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Use test PID file location
    TEST_PID_FILE="${TEST_CONFIG_DIR}/.popup_pid"
    POPUP_PID_FILE="${TEST_PID_FILE}"
    mkdir -p "$(dirname "${TEST_PID_FILE}")"
    
    # Test cleanup of stale PID (non-existent process)
    # Use a PID that definitely doesn't exist (very high number)
    local stale_pid=999999
    echo "${stale_pid}" > "${TEST_PID_FILE}"
    
    if cleanup_stale_pid 2>/dev/null; then
        if [ ! -f "${TEST_PID_FILE}" ]; then
            print_test_result "cleanup_stale_pid() removes stale PID file" "PASS"
        else
            print_test_result "cleanup_stale_pid() removes stale PID file" "FAIL" "Stale PID file still exists"
        fi
    else
        print_test_result "cleanup_stale_pid() removes stale PID file" "FAIL" "Function returned error"
    fi
    
    # Test cleanup when PID file doesn't exist (should succeed)
    rm -f "${TEST_PID_FILE}" 2>/dev/null
    if cleanup_stale_pid 2>/dev/null; then
        print_test_result "cleanup_stale_pid() handles missing file" "PASS"
    else
        print_test_result "cleanup_stale_pid() handles missing file" "FAIL" "Should succeed even if file doesn't exist"
    fi
    
    echo ""
}

# Test 6: Sleep Detection - Constants
test_sleep_detection_constants() {
    echo "=== Test 6: Sleep Detection - Constants ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Test that SLEEP_RESUME_GRACE_PERIOD is defined and equals 60
    if [ -n "${SLEEP_RESUME_GRACE_PERIOD}" ] && [ "${SLEEP_RESUME_GRACE_PERIOD}" = "60" ]; then
        print_test_result "SLEEP_RESUME_GRACE_PERIOD is 60 seconds" "PASS"
    else
        print_test_result "SLEEP_RESUME_GRACE_PERIOD is 60 seconds" "FAIL" "Expected 60, got ${SLEEP_RESUME_GRACE_PERIOD:-undefined}"
    fi
    
    # Test that POPUP_PID_FILE is defined
    if [ -n "${POPUP_PID_FILE}" ]; then
        print_test_result "POPUP_PID_FILE is defined" "PASS"
    else
        print_test_result "POPUP_PID_FILE is defined" "FAIL" "POPUP_PID_FILE is not defined"
    fi
    
    # Test that LAST_UPTIME_FILE is defined
    if [ -n "${LAST_UPTIME_FILE}" ]; then
        print_test_result "LAST_UPTIME_FILE is defined" "PASS"
    else
        print_test_result "LAST_UPTIME_FILE is defined" "FAIL" "LAST_UPTIME_FILE is not defined"
    fi
    
    echo ""
}

# Test 7: Sleep Detection - Function Availability
test_sleep_detection_functions() {
    echo "=== Test 7: Sleep Detection - Function Availability ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Test that sleep detection functions exist
    if type check_system_resume >/dev/null 2>&1; then
        print_test_result "check_system_resume() function exists" "PASS"
    else
        print_test_result "check_system_resume() function exists" "FAIL" "Function not found"
    fi
    
    if type should_skip_warning_after_resume >/dev/null 2>&1; then
        print_test_result "should_skip_warning_after_resume() function exists" "PASS"
    else
        print_test_result "should_skip_warning_after_resume() function exists" "FAIL" "Function not found"
    fi
    
    if type update_uptime_tracking >/dev/null 2>&1; then
        print_test_result "update_uptime_tracking() function exists" "PASS"
    else
        print_test_result "update_uptime_tracking() function exists" "FAIL" "Function not found"
    fi
    
    echo ""
}

# Test 8: Popup Detection - Function Availability
test_popup_detection_functions() {
    echo "=== Test 8: Popup Detection - Function Availability ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Test that popup detection functions exist
    if type is_popup_running >/dev/null 2>&1; then
        print_test_result "is_popup_running() function exists" "PASS"
    else
        print_test_result "is_popup_running() function exists" "FAIL" "Function not found"
    fi
    
    if type get_popup_age >/dev/null 2>&1; then
        print_test_result "get_popup_age() function exists" "PASS"
    else
        print_test_result "get_popup_age() function exists" "FAIL" "Function not found"
    fi
    
    if type close_existing_popups >/dev/null 2>&1; then
        print_test_result "close_existing_popups() function exists" "PASS"
    else
        print_test_result "close_existing_popups() function exists" "FAIL" "Function not found"
    fi
    
    echo ""
}

# Test 9: Popup Detection - No Popup Running
test_popup_detection_no_popup() {
    echo "=== Test 9: Popup Detection - No Popup Running ==="
    
    if ! source_modules; then
        print_test_result "Source modules" "FAIL" "Could not source required modules"
        return
    fi
    
    # Use test PID file location
    TEST_PID_FILE="${TEST_CONFIG_DIR}/.popup_pid"
    POPUP_PID_FILE="${TEST_PID_FILE}"
    mkdir -p "$(dirname "${TEST_PID_FILE}")"
    
    # Ensure no PID file exists
    rm -f "${TEST_PID_FILE}" 2>/dev/null
    
    # Test that is_popup_running returns empty when no popup exists
    local result
    result=$(is_popup_running 2>/dev/null)
    if [ -z "${result}" ]; then
        print_test_result "is_popup_running() returns empty when no popup" "PASS"
    else
        print_test_result "is_popup_running() returns empty when no popup" "FAIL" "Expected empty, got: ${result}"
    fi
    
    echo ""
}

# Test 10: Integration - Sleep Detection in sleep-warning.sh
test_sleep_detection_integration() {
    echo "=== Test 10: Integration - Sleep Detection in sleep-warning.sh ==="
    
    # Check if sleep-warning.sh sources sleep-detection.sh
    if grep -q "sleep-detection.sh" "${PROJECT_ROOT}/sleep-warning.sh"; then
        print_test_result "sleep-warning.sh sources sleep-detection.sh" "PASS"
    else
        print_test_result "sleep-warning.sh sources sleep-detection.sh" "FAIL" "sleep-detection.sh not sourced"
    fi
    
    # Check if sleep-warning.sh calls should_skip_warning_after_resume
    if grep -q "should_skip_warning_after_resume" "${PROJECT_ROOT}/sleep-warning.sh"; then
        print_test_result "sleep-warning.sh calls should_skip_warning_after_resume" "PASS"
    else
        print_test_result "sleep-warning.sh calls should_skip_warning_after_resume" "FAIL" "Function not called"
    fi
    
    echo ""
}

# Main test execution
main() {
    echo "==================================================================="
    echo "Test Suite for Enhancement #9: System Sleep/Hibernate Detection"
    echo "and Popup Queue Management"
    echo "==================================================================="
    echo ""
    
    # Setup
    setup_test_config
    
    # Run tests
    test_validation_valid
    test_validation_invalid
    test_pid_file_save_read
    test_pid_file_cleanup
    test_stale_pid_cleanup
    test_sleep_detection_constants
    test_sleep_detection_functions
    test_popup_detection_functions
    test_popup_detection_no_popup
    test_sleep_detection_integration
    
    # Cleanup
    cleanup_test_config
    
    # Summary
    echo "==================================================================="
    echo "Test Summary"
    echo "==================================================================="
    echo "Total tests: ${TOTAL}"
    echo -e "${GREEN}Passed: ${PASSED}${NC}"
    if [ "${FAILED}" -gt 0 ]; then
        echo -e "${RED}Failed: ${FAILED}${NC}"
    else
        echo -e "${GREEN}Failed: ${FAILED}${NC}"
    fi
    echo ""
    
    if [ "${FAILED}" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
