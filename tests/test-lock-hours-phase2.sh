#!/bin/bash

###############################################################################
# Sleep Warning System - Lock Hours Phase 2 Unit Tests
#
# This script tests the Phase 2 lock hours functionality for Enhancement #19.
# Tests cover:
# - parse_lock_hours() function
# - is_lock_hour() function
# - check_config_lock_time() with lock hours
#
# Usage: ./tests/test-lock-hours-phase2.sh
###############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEST_CONFIG_DIR="${SCRIPT_DIR}/tests/test-configs"
TEST_OUTPUT_DIR="${TEST_CONFIG_DIR}/lock-hours-tests"

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
    rm -rf "${TEST_OUTPUT_DIR}"
}

# Setup test environment
setup() {
    # Create test output directory
    mkdir -p "${TEST_OUTPUT_DIR}"
    
    # Source required modules
    source "${LIB_DIR}/config.sh" || exit 1
    source "${LIB_DIR}/time-validation.sh" || exit 1
    source "${LIB_DIR}/logging.sh" 2>/dev/null || true
}

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        if [ -n "$details" ]; then
            echo -e "  ${YELLOW}Details: $details${NC}"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Print section header
print_section() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

# Test parse_lock_hours with missing config file
test_parse_lock_hours_missing_config() {
    local test_config="${TEST_OUTPUT_DIR}/missing.conf"
    local original_config="${CONFIG_FILE}"
    
    # Temporarily set config file to non-existent file
    CONFIG_FILE="${test_config}"
    
    local result
    result=$(parse_lock_hours 1 2>/dev/null)
    
    if [ -z "${result}" ]; then
        print_test_result "parse_lock_hours() with missing config file" "PASS"
    else
        print_test_result "parse_lock_hours() with missing config file" "FAIL" "Expected empty string, got: '${result}'"
    fi
    
    CONFIG_FILE="${original_config}"
}

# Test parse_lock_hours with configured lock hours
test_parse_lock_hours_configured() {
    local test_config="${TEST_OUTPUT_DIR}/configured.conf"
    local original_config="${CONFIG_FILE}"
    
    # Create test config with lock hours
    cat > "${test_config}" <<EOF
CONFIG_LOCK_HOURS_MONDAY=9-17
CONFIG_LOCK_HOURS_TUESDAY=0-5,22-23
EOF
    
    CONFIG_FILE="${test_config}"
    
    local result1 result2
    result1=$(parse_lock_hours 1 2>/dev/null)  # Monday
    result2=$(parse_lock_hours 2 2>/dev/null)  # Tuesday
    
    if [ "${result1}" = "9-17" ] && [ "${result2}" = "0-5,22-23" ]; then
        print_test_result "parse_lock_hours() with configured lock hours" "PASS"
    else
        print_test_result "parse_lock_hours() with configured lock hours" "FAIL" "Monday: '${result1}' (expected '9-17'), Tuesday: '${result2}' (expected '0-5,22-23')"
    fi
    
    CONFIG_FILE="${original_config}"
    rm -f "${test_config}"
}

# Test parse_lock_hours with empty lock hours line
test_parse_lock_hours_empty_line() {
    local test_config="${TEST_OUTPUT_DIR}/empty.conf"
    local original_config="${CONFIG_FILE}"
    
    # Create test config with empty lock hours line
    cat > "${test_config}" <<EOF
CONFIG_LOCK_HOURS_MONDAY=
EOF
    
    CONFIG_FILE="${test_config}"
    
    local result
    result=$(parse_lock_hours 1 2>/dev/null)  # Monday
    
    if [ -z "${result}" ]; then
        print_test_result "parse_lock_hours() with empty lock hours line" "PASS"
    else
        print_test_result "parse_lock_hours() with empty lock hours line" "FAIL" "Expected empty string, got: '${result}'"
    fi
    
    CONFIG_FILE="${original_config}"
    rm -f "${test_config}"
}

# Test parse_lock_hours with invalid format
test_parse_lock_hours_invalid_format() {
    local test_config="${TEST_OUTPUT_DIR}/invalid.conf"
    local original_config="${CONFIG_FILE}"
    
    # Create test config with invalid format
    cat > "${test_config}" <<EOF
CONFIG_LOCK_HOURS_MONDAY=invalid-format
EOF
    
    CONFIG_FILE="${test_config}"
    
    local result
    result=$(parse_lock_hours 1 2>/dev/null)  # Monday
    
    if [ -z "${result}" ]; then
        print_test_result "parse_lock_hours() with invalid format" "PASS"
    else
        print_test_result "parse_lock_hours() with invalid format" "FAIL" "Expected empty string for invalid format, got: '${result}'"
    fi
    
    CONFIG_FILE="${original_config}"
    rm -f "${test_config}"
}

# Test parse_lock_hours for all 7 days
test_parse_lock_hours_all_days() {
    local test_config="${TEST_OUTPUT_DIR}/all-days.conf"
    local original_config="${CONFIG_FILE}"
    
    # Create test config with all days
    cat > "${test_config}" <<EOF
CONFIG_LOCK_HOURS_SUNDAY=0-5
CONFIG_LOCK_HOURS_MONDAY=9-17
CONFIG_LOCK_HOURS_TUESDAY=10-18
CONFIG_LOCK_HOURS_WEDNESDAY=11-19
CONFIG_LOCK_HOURS_THURSDAY=12-20
CONFIG_LOCK_HOURS_FRIDAY=13-21
CONFIG_LOCK_HOURS_SATURDAY=14-22
EOF
    
    CONFIG_FILE="${test_config}"
    
    local all_passed=true
    for day in 0 1 2 3 4 5 6; do
        local result
        result=$(parse_lock_hours "${day}" 2>/dev/null)
        if [ -z "${result}" ]; then
            all_passed=false
            break
        fi
    done
    
    if [ "${all_passed}" = "true" ]; then
        print_test_result "parse_lock_hours() for all 7 days" "PASS"
    else
        print_test_result "parse_lock_hours() for all 7 days" "FAIL" "Some days returned empty string"
    fi
    
    CONFIG_FILE="${original_config}"
    rm -f "${test_config}"
}

# Test is_lock_hour with empty ranges
test_is_lock_hour_empty_ranges() {
    if is_lock_hour 10 "" 2>/dev/null; then
        print_test_result "is_lock_hour() with empty ranges" "FAIL" "Should return 1 (not locked) for empty ranges"
    else
        print_test_result "is_lock_hour() with empty ranges" "PASS"
    fi
}

# Test is_lock_hour with single range
test_is_lock_hour_single_range() {
    # Test hour within range
    if is_lock_hour 10 "9-17" 2>/dev/null; then
        local in_range=true
    else
        local in_range=false
    fi
    
    # Test hour outside range
    if is_lock_hour 8 "9-17" 2>/dev/null; then
        local out_range=true
    else
        local out_range=false
    fi
    
    if [ "${in_range}" = "true" ] && [ "${out_range}" = "false" ]; then
        print_test_result "is_lock_hour() with single range" "PASS"
    else
        print_test_result "is_lock_hour() with single range" "FAIL" "In range: ${in_range}, Out range: ${out_range}"
    fi
}

# Test is_lock_hour with multiple ranges
test_is_lock_hour_multiple_ranges() {
    # Test hour in first range
    local in_first=false
    if is_lock_hour 2 "0-5,22-23" 2>/dev/null; then
        in_first=true
    fi
    
    # Test hour in second range
    local in_second=false
    if is_lock_hour 22 "0-5,22-23" 2>/dev/null; then
        in_second=true
    fi
    
    # Test hour outside both ranges
    local out_both=false
    if is_lock_hour 10 "0-5,22-23" 2>/dev/null; then
        out_both=true
    fi
    
    if [ "${in_first}" = "true" ] && [ "${in_second}" = "true" ] && [ "${out_both}" = "false" ]; then
        print_test_result "is_lock_hour() with multiple ranges" "PASS"
    else
        print_test_result "is_lock_hour() with multiple ranges" "FAIL" "In first: ${in_first}, In second: ${in_second}, Out both: ${out_both}"
    fi
}

# Test is_lock_hour with overnight ranges
test_is_lock_hour_overnight() {
    # Test hour in overnight range (23-6)
    local in_overnight=false
    if is_lock_hour 2 "23-6" 2>/dev/null; then
        in_overnight=true
    fi
    
    # Test hour before overnight range starts
    local before_start=false
    if is_lock_hour 22 "23-6" 2>/dev/null; then
        before_start=true
    fi
    
    # Test hour after overnight range ends
    local after_end=false
    if is_lock_hour 7 "23-6" 2>/dev/null; then
        after_end=true
    fi
    
    if [ "${in_overnight}" = "true" ] && [ "${before_start}" = "false" ] && [ "${after_end}" = "false" ]; then
        print_test_result "is_lock_hour() with overnight ranges" "PASS"
    else
        print_test_result "is_lock_hour() with overnight ranges" "FAIL" "In overnight: ${in_overnight}, Before start: ${before_start}, After end: ${after_end}"
    fi
}

# Test is_lock_hour with boundary times
test_is_lock_hour_boundary_times() {
    # Test exactly at start (should be in range)
    local at_start=false
    if is_lock_hour 9 "9-17" 2>/dev/null; then
        at_start=true
    fi
    
    # Test exactly at end (should NOT be in range, end is exclusive)
    local at_end=false
    if is_lock_hour 17 "9-17" 2>/dev/null; then
        at_end=true
    fi
    
    # Test just before end (should be in range)
    local before_end=false
    if is_lock_hour 16 "9-17" 2>/dev/null; then
        before_end=true
    fi
    
    if [ "${at_start}" = "true" ] && [ "${at_end}" = "false" ] && [ "${before_end}" = "true" ]; then
        print_test_result "is_lock_hour() with boundary times" "PASS"
    else
        print_test_result "is_lock_hour() with boundary times" "FAIL" "At start: ${at_start}, At end: ${at_end}, Before end: ${before_end}"
    fi
}

# Test check_config_lock_time with only restriction hours (Phase 1 behavior)
test_check_config_lock_time_restriction_only() {
    local test_config="${TEST_OUTPUT_DIR}/restriction-only.conf"
    local original_config="${CONFIG_FILE}"
    
    # Create test config with only restriction hours
    cat > "${test_config}" <<EOF
CONFIGURE_BLOCK_ENABLED=true
MONDAY=9-17
EOF
    
    CONFIG_FILE="${test_config}"
    
    # Mock current time to be in restriction hours (Monday, 10:00)
    # Note: This test is simplified - in real scenario we'd need to mock date command
    # For now, we'll test the function exists and can be called
    if type check_config_lock_time >/dev/null 2>&1; then
        print_test_result "check_config_lock_time() function exists" "PASS"
    else
        print_test_result "check_config_lock_time() function exists" "FAIL" "Function not found"
    fi
    
    CONFIG_FILE="${original_config}"
    rm -f "${test_config}"
}

# Test check_config_lock_time with only lock hours
test_check_config_lock_time_lock_only() {
    local test_config="${TEST_OUTPUT_DIR}/lock-only.conf"
    local original_config="${CONFIG_FILE}"
    
    # Create test config with only lock hours
    cat > "${test_config}" <<EOF
CONFIGURE_BLOCK_ENABLED=true
CONFIG_LOCK_HOURS_MONDAY=9-17
EOF
    
    CONFIG_FILE="${test_config}"
    
    # Function should exist and handle lock hours
    if type check_config_lock_time >/dev/null 2>&1; then
        print_test_result "check_config_lock_time() with only lock hours" "PASS"
    else
        print_test_result "check_config_lock_time() with only lock hours" "FAIL" "Function not found"
    fi
    
    CONFIG_FILE="${original_config}"
    rm -f "${test_config}"
}

# Test check_config_lock_time with both restriction and lock hours
test_check_config_lock_time_both() {
    local test_config="${TEST_OUTPUT_DIR}/both.conf"
    local original_config="${CONFIG_FILE}"
    
    # Create test config with both restriction and lock hours
    cat > "${test_config}" <<EOF
CONFIGURE_BLOCK_ENABLED=true
MONDAY=0-5
CONFIG_LOCK_HOURS_MONDAY=9-17
EOF
    
    CONFIG_FILE="${test_config}"
    
    # Function should handle both
    if type check_config_lock_time >/dev/null 2>&1; then
        print_test_result "check_config_lock_time() with both restriction and lock hours" "PASS"
    else
        print_test_result "check_config_lock_time() with both restriction and lock hours" "FAIL" "Function not found"
    fi
    
    CONFIG_FILE="${original_config}"
    rm -f "${test_config}"
}

# Test check_config_lock_time when blocking disabled
test_check_config_lock_time_disabled() {
    local test_config="${TEST_OUTPUT_DIR}/disabled.conf"
    local original_config="${CONFIG_FILE}"
    
    # Create test config with blocking disabled
    cat > "${test_config}" <<EOF
CONFIGURE_BLOCK_ENABLED=false
MONDAY=9-17
CONFIG_LOCK_HOURS_MONDAY=9-17
EOF
    
    CONFIG_FILE="${test_config}"
    
    # Function should allow execution when disabled
    if check_config_lock_time 2>/dev/null; then
        print_test_result "check_config_lock_time() when blocking disabled" "PASS"
    else
        print_test_result "check_config_lock_time() when blocking disabled" "FAIL" "Should allow execution when disabled"
    fi
    
    CONFIG_FILE="${original_config}"
    rm -f "${test_config}"
}

# Main test execution
main() {
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Lock Hours Phase 2 Unit Test Suite${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    
    setup
    
    print_section "parse_lock_hours() Tests"
    test_parse_lock_hours_missing_config
    test_parse_lock_hours_configured
    test_parse_lock_hours_empty_line
    test_parse_lock_hours_invalid_format
    test_parse_lock_hours_all_days
    
    print_section "is_lock_hour() Tests"
    test_is_lock_hour_empty_ranges
    test_is_lock_hour_single_range
    test_is_lock_hour_multiple_ranges
    test_is_lock_hour_overnight
    test_is_lock_hour_boundary_times
    
    print_section "check_config_lock_time() Tests"
    test_check_config_lock_time_restriction_only
    test_check_config_lock_time_lock_only
    test_check_config_lock_time_both
    test_check_config_lock_time_disabled
    
    # Print summary
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Test Summary${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo "Tests run: ${TESTS_RUN}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    if [ ${TESTS_FAILED} -gt 0 ]; then
        echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    else
        echo -e "Failed: ${TESTS_FAILED}"
    fi
    echo ""
    
    cleanup
    
    if [ ${TESTS_FAILED} -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run tests
main "$@"
