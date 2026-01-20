#!/bin/bash

###############################################################################
# Sleep Warning System - write_config Override Flags Edge Case Tests
#
# This script tests the write_config() function's handling of safety override
# flags to ensure correct detection and processing in various edge cases.
#
# Tests cover:
# - Normal cases with override flags
# - Backward compatibility (without override flags)
# - Sparse config_lines arrays
# - Empty config_lines with override flags
# - Edge cases that could cause false positives
#
# Usage: ./tests/test-write-config-override-flags.sh
###############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEST_CONFIG_DIR="${SCRIPT_DIR}/tests/test-configs"
TEST_OUTPUT_DIR="${TEST_CONFIG_DIR}/write-config-tests"

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
    source "${LIB_DIR}/configure-core.sh" || exit 1
    source "${LIB_DIR}/configure-config.sh" || exit 1
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

# Test helper: Check if config file contains expected comment
check_config_comment() {
    local config_file="$1"
    local expected_pattern="$2"
    local test_name="$3"
    
    if grep -q "${expected_pattern}" "${config_file}" 2>/dev/null; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Expected pattern '${expected_pattern}' not found in config file"
        return 1
    fi
}

# Test helper: Check if config file does NOT contain comment
check_config_no_comment() {
    local config_file="$1"
    local unexpected_pattern="$2"
    local test_name="$3"
    
    if ! grep -q "${unexpected_pattern}" "${config_file}" 2>/dev/null; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Unexpected pattern '${unexpected_pattern}' found in config file"
        return 1
    fi
}

# Test 1: Normal case with both override flags set
test_normal_with_override_flags() {
    print_section "Test 1: Normal case with override flags"
    
    local test_config="${TEST_OUTPUT_DIR}/test1.conf"
    local config_lines=(
        "SUNDAY=0-5"
        "MONDAY=0-5"
        "TUESDAY=0-5"
        "WEDNESDAY=0-5"
        "THURSDAY=0-5"
        "FRIDAY=0-5"
        "SATURDAY=1-5"
    )
    
    # Set CONFIG_FILE to test location
    CONFIG_FILE="${test_config}"
    
    # Call write_config with override flags
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}" "true" "true"
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        check_config_comment "${test_config}" "POPUP_SIZE has been restricted" \
            "Config file contains popup size override comment"
        check_config_comment "${test_config}" "CONFIGURE_BLOCK_ENABLED has been disabled" \
            "Config file contains configure block override comment"
    else
        print_test_result "write_config succeeds and creates file" "FAIL" "Function returned error or file not created"
    fi
}

# Test 2: Normal case without override flags (backward compatibility)
test_normal_without_override_flags() {
    print_section "Test 2: Normal case without override flags (backward compatibility)"
    
    local test_config="${TEST_OUTPUT_DIR}/test2.conf"
    local config_lines=(
        "SUNDAY=0-5"
        "MONDAY=0-5"
    )
    
    CONFIG_FILE="${test_config}"
    
    # Call write_config WITHOUT override flags (old style)
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}"
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        check_config_no_comment "${test_config}" "POPUP_SIZE has been restricted" \
            "Config file does NOT contain popup size override comment (backward compatible)"
        check_config_no_comment "${test_config}" "CONFIGURE_BLOCK_ENABLED has been disabled" \
            "Config file does NOT contain configure block override comment (backward compatible)"
    else
        print_test_result "write_config succeeds without override flags" "FAIL" "Function returned error or file not created"
    fi
}

# Test 3: Sparse config_lines array (only some days configured)
test_sparse_config_lines() {
    print_section "Test 3: Sparse config_lines array"
    
    local test_config="${TEST_OUTPUT_DIR}/test3.conf"
    # Only configure Sunday and Wednesday (sparse array)
    local config_lines=(
        "SUNDAY=0-5"
        "WEDNESDAY=22-23"
    )
    
    CONFIG_FILE="${test_config}"
    
    # Call with override flags
    write_config "10" "large" "center" "30" "true" "true" \
        "${config_lines[@]}" "true" "true"
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        # Check that only Sunday and Wednesday are in the file
        if grep -q "SUNDAY=0-5" "${test_config}" && \
           grep -q "WEDNESDAY=22-23" "${test_config}" && \
           ! grep -q "MONDAY=" "${test_config}" && \
           ! grep -q "TUESDAY=" "${test_config}"; then
            print_test_result "Sparse config_lines array handled correctly" "PASS"
        else
            print_test_result "Sparse config_lines array handled correctly" "FAIL" "Wrong days in config file"
        fi
    else
        print_test_result "write_config succeeds with sparse array" "FAIL" "Function returned error or file not created"
    fi
}

# Test 4: Empty config_lines with override flags
test_empty_config_lines_with_flags() {
    print_section "Test 4: Empty config_lines with override flags"
    
    local test_config="${TEST_OUTPUT_DIR}/test4.conf"
    local config_lines=()  # Empty array
    
    CONFIG_FILE="${test_config}"
    
    # Call with override flags but no config_lines
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}" "true" "true"
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        # Should still have override comments even with no day configs
        check_config_comment "${test_config}" "POPUP_SIZE has been restricted" \
            "Config file contains popup size override comment with empty config_lines"
        check_config_comment "${test_config}" "CONFIGURE_BLOCK_ENABLED has been disabled" \
            "Config file contains configure block override comment with empty config_lines"
    else
        print_test_result "write_config succeeds with empty config_lines" "FAIL" "Function returned error or file not created"
    fi
}

# Test 5: Edge case - config_lines that might be mistaken for flags (empty restrictions)
test_empty_restrictions_not_mistaken_for_flags() {
    print_section "Test 5: Empty restrictions not mistaken for override flags"
    
    local test_config="${TEST_OUTPUT_DIR}/test5.conf"
    # Days with empty restrictions (explicitly skipped)
    local config_lines=(
        "SUNDAY="
        "MONDAY="
    )
    
    CONFIG_FILE="${test_config}"
    
    # Call WITHOUT override flags - these should NOT be mistaken for flags
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}"
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        # Check that the empty restrictions are in the file (not treated as flags)
        if grep -q "SUNDAY=" "${test_config}" && grep -q "MONDAY=" "${test_config}"; then
            print_test_result "Empty restrictions correctly identified as config_lines" "PASS"
        else
            print_test_result "Empty restrictions correctly identified as config_lines" "FAIL" "Empty restrictions not found in config file"
        fi
    else
        print_test_result "write_config succeeds with empty restrictions" "FAIL" "Function returned error or file not created"
    fi
}

# Test 6: Edge case - exactly 2 config_lines that could be mistaken for flags
test_two_config_lines_not_mistaken_for_flags() {
    print_section "Test 6: Two config_lines not mistaken for override flags"
    
    local test_config="${TEST_OUTPUT_DIR}/test6.conf"
    # Exactly 2 days configured
    local config_lines=(
        "SUNDAY=0-5"
        "SATURDAY=22-23"
    )
    
    CONFIG_FILE="${test_config}"
    
    # Call WITHOUT override flags - should NOT mistake last 2 args as flags
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}"
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        # Both days should be in config file
        if grep -q "SUNDAY=0-5" "${test_config}" && grep -q "SATURDAY=22-23" "${test_config}"; then
            print_test_result "Two config_lines correctly identified (not mistaken for flags)" "PASS"
        else
            print_test_result "Two config_lines correctly identified (not mistaken for flags)" "FAIL" "Config lines not found in file"
        fi
    else
        print_test_result "write_config succeeds with exactly 2 config_lines" "FAIL" "Function returned error or file not created"
    fi
}

# Test 7: Mixed case - some override flags empty, some set
test_mixed_override_flags() {
    print_section "Test 7: Mixed override flags (one empty, one set)"
    
    local test_config="${TEST_OUTPUT_DIR}/test7.conf"
    local config_lines=(
        "SUNDAY=0-5"
        "MONDAY=0-5"
    )
    
    CONFIG_FILE="${test_config}"
    
    # Call with popup_size_overridden="true" but configure_block_overridden="" (empty)
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}" "true" ""
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        # Should have popup comment but NOT configure block comment
        check_config_comment "${test_config}" "POPUP_SIZE has been restricted" \
            "Config file contains popup size override comment"
        check_config_no_comment "${test_config}" "CONFIGURE_BLOCK_ENABLED has been disabled" \
            "Config file does NOT contain configure block override comment (flag was empty)"
    else
        print_test_result "write_config succeeds with mixed override flags" "FAIL" "Function returned error or file not created"
    fi
}

# Test 8: Edge case - single config_line with override flags
test_single_config_line_with_flags() {
    print_section "Test 8: Single config_line with override flags"
    
    local test_config="${TEST_OUTPUT_DIR}/test8.conf"
    local config_lines=(
        "SUNDAY=0-5"
    )
    
    CONFIG_FILE="${test_config}"
    
    # Call with 1 config_line + 2 override flags = 3 total args after shift 6
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}" "true" "true"
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        # Should have both override comments
        check_config_comment "${test_config}" "POPUP_SIZE has been restricted" \
            "Config file contains popup size override comment with single config_line"
        check_config_comment "${test_config}" "CONFIGURE_BLOCK_ENABLED has been disabled" \
            "Config file contains configure block override comment with single config_line"
        # Should have the config_line
        if grep -q "SUNDAY=0-5" "${test_config}"; then
            print_test_result "Single config_line correctly processed with override flags" "PASS"
        else
            print_test_result "Single config_line correctly processed with override flags" "FAIL" "Config line not found"
        fi
    else
        print_test_result "write_config succeeds with single config_line" "FAIL" "Function returned error or file not created"
    fi
}

# Test 9: All 7 days configured with override flags
test_all_days_with_flags() {
    print_section "Test 9: All 7 days configured with override flags"
    
    local test_config="${TEST_OUTPUT_DIR}/test9.conf"
    local config_lines=(
        "SUNDAY=0-5"
        "MONDAY=0-5"
        "TUESDAY=0-5"
        "WEDNESDAY=0-5"
        "THURSDAY=0-5"
        "FRIDAY=0-5"
        "SATURDAY=1-5"
    )
    
    CONFIG_FILE="${test_config}"
    
    # Call with all 7 days + 2 override flags = 9 total args after shift 6
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}" "true" "true"
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        # Check that all 7 days are in the file
        local days_found=0
        for day in SUNDAY MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY SATURDAY; do
            if grep -q "${day}=" "${test_config}"; then
                days_found=$((days_found + 1))
            fi
        done
        
        if [ $days_found -eq 7 ]; then
            print_test_result "All 7 days correctly processed with override flags" "PASS"
        else
            print_test_result "All 7 days correctly processed with override flags" "FAIL" "Only $days_found/7 days found in config file"
        fi
    else
        print_test_result "write_config succeeds with all 7 days" "FAIL" "Function returned error or file not created"
    fi
}

# Test 10: Edge case - override flags with empty string values
test_override_flags_empty_strings() {
    print_section "Test 10: Override flags as empty strings"
    
    local test_config="${TEST_OUTPUT_DIR}/test10.conf"
    local config_lines=(
        "SUNDAY=0-5"
    )
    
    CONFIG_FILE="${test_config}"
    
    # Call with both override flags as empty strings (should not add comments)
    write_config "10" "medium" "center" "30" "true" "false" \
        "${config_lines[@]}" "" ""
    
    if [ $? -eq 0 ] && [ -f "${test_config}" ]; then
        # Should NOT have override comments (flags are empty)
        check_config_no_comment "${test_config}" "POPUP_SIZE has been restricted" \
            "Config file does NOT contain popup size override comment (flag was empty)"
        check_config_no_comment "${test_config}" "CONFIGURE_BLOCK_ENABLED has been disabled" \
            "Config file does NOT contain configure block override comment (flag was empty)"
    else
        print_test_result "write_config succeeds with empty override flags" "FAIL" "Function returned error or file not created"
    fi
}

# Main test runner
main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  write_config() Override Flags Edge Case Tests${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Setup
    setup
    
    # Run all tests
    test_normal_with_override_flags
    test_normal_without_override_flags
    test_sparse_config_lines
    test_empty_config_lines_with_flags
    test_empty_restrictions_not_mistaken_for_flags
    test_two_config_lines_not_mistaken_for_flags
    test_mixed_override_flags
    test_single_config_line_with_flags
    test_all_days_with_flags
    test_override_flags_empty_strings
    
    # Print summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    
    # Cleanup
    cleanup
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests
main "$@"
