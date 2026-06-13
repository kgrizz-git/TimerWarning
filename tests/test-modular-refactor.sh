#!/bin/bash

###############################################################################
# Sleep Warning System - Modular Refactor Test Suite
#
# This script tests the modular refactor of sleep-warning.sh to ensure:
# - All modules source correctly
# - Functions work identically to original
# - No functionality is broken
# - All dependencies are properly handled
#
# Usage: ./tests/test-modular-refactor.sh
###############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
MAIN_SCRIPT="${SCRIPT_DIR}/sleep-warning.sh"

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
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

# Test 1: Check if all library files exist
test_library_files_exist() {
    local expected_files=(
        "config.sh"
        "logging.sh"
        "display-detection.sh"
        "desktop-environment.sh"
        "window-management.sh"
        "time-validation.sh"
        "popup-display.sh"
    )
    
    local all_exist=true
    for file in "${expected_files[@]}"; do
        if [ ! -f "${LIB_DIR}/${file}" ]; then
            echo "  Missing: ${file}"
            all_exist=false
        fi
    done
    
    if [ "$all_exist" = true ]; then
        print_test_result "All 7 library modules exist" "PASS"
    else
        print_test_result "All 7 library modules exist" "FAIL"
    fi
}

# Test 2: Syntax check all modules
test_module_syntax() {
    local all_valid=true
    
    for module in "${LIB_DIR}"/*.sh; do
        if ! bash -n "$module" 2>/dev/null; then
            echo "  Syntax error in: $(basename $module)"
            all_valid=false
        fi
    done
    
    if [ "$all_valid" = true ]; then
        print_test_result "All modules pass syntax check" "PASS"
    else
        print_test_result "All modules pass syntax check" "FAIL"
    fi
}

# Test 3: Syntax check main script
test_main_script_syntax() {
    if bash -n "$MAIN_SCRIPT" 2>/dev/null; then
        print_test_result "Main script passes syntax check" "PASS"
    else
        print_test_result "Main script passes syntax check" "FAIL"
    fi
}

# Test 4: Test module sourcing
test_module_sourcing() {
    # Test sourcing all modules directly
    local result
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
source "${LIB_DIR}/config.sh" || exit 1
source "${LIB_DIR}/logging.sh" || exit 1
source "${LIB_DIR}/display-detection.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/window-management.sh" || exit 1
source "${LIB_DIR}/time-validation.sh" || exit 1
source "${LIB_DIR}/popup-display.sh" || exit 1
echo "SUCCESS"
' 2>/dev/null)
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "All modules source without errors" "PASS"
    else
        print_test_result "All modules source without errors" "FAIL"
    fi
}

# Test 5: Test config functions are available
test_config_functions() {
    local result
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
source "${LIB_DIR}/config.sh" || exit 1

# Test that all config functions exist
type get_check_interval >/dev/null 2>&1 || exit 1
type get_popup_size >/dev/null 2>&1 || exit 1
type get_popup_dimensions >/dev/null 2>&1 || exit 1
type get_popup_position >/dev/null 2>&1 || exit 1
type get_min_display_time >/dev/null 2>&1 || exit 1
type get_popup_immovable >/dev/null 2>&1 || exit 1
type parse_config >/dev/null 2>&1 || exit 1

# Test that constants are defined
[ -n "$SCRIPT_NAME" ] || exit 1
[ -n "$CONFIG_DIR" ] || exit 1
[ -n "$CONFIG_FILE" ] || exit 1
[ -n "$DEFAULT_CHECK_INTERVAL" ] || exit 1

echo "SUCCESS"
' 2>/dev/null)
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "Config module functions available" "PASS"
    else
        print_test_result "Config module functions available" "FAIL"
    fi
}

# Test 6: Test display detection functions
test_display_functions() {
    local result
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
source "${LIB_DIR}/display-detection.sh" || exit 1

# Test that functions exist
type detect_display_environment >/dev/null 2>&1 || exit 1
type get_display_identifier >/dev/null 2>&1 || exit 1
type get_display >/dev/null 2>&1 || exit 1
type validate_display_format >/dev/null 2>&1 || exit 1

echo "SUCCESS"
' 2>/dev/null)
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "Display detection functions available" "PASS"
    else
        print_test_result "Display detection functions available" "FAIL"
    fi
}

# Test 7: Test time validation functions
test_time_validation() {
    local result
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
source "${LIB_DIR}/config.sh" || exit 1
source "${LIB_DIR}/logging.sh" || exit 1
source "${LIB_DIR}/time-validation.sh" || exit 1

# Test validation of normal range
validate_single_range "0-5" || exit 1

# Test validation of overnight range
validate_single_range "23-6" || exit 1

# Test rejection of invalid range
if validate_single_range "5-5"; then
    exit 1  # Should have failed
fi

# Test hour checking
if is_hour_in_single_range 3 "0-5"; then
    echo "SUCCESS"
else
    exit 1
fi
' 2>/dev/null)
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "Time validation functions work correctly" "PASS"
    else
        print_test_result "Time validation functions work correctly" "FAIL"
    fi
}

# Test 8: Test that main script uses library loader (not inline source list)
test_main_script_modules() {
    if grep -q 'source_required_lib' "$MAIN_SCRIPT" && \
       grep -q 'library-loader.sh' "$MAIN_SCRIPT" && \
       grep -q 'source_required_lib "popup-display.sh"' "$MAIN_SCRIPT"; then
        print_test_result "Main script uses library loader for modules" "PASS"
    else
        print_test_result "Main script uses library loader for modules" "FAIL"
    fi
}

# Test 9: Verify main script has main() function
test_main_function_exists() {
    if grep -q "^main()" "$MAIN_SCRIPT"; then
        print_test_result "Main script contains main() function" "PASS"
    else
        print_test_result "Main script contains main() function" "FAIL"
    fi
}

# Test 10: Check main script size reduction
test_script_size() {
    local main_lines
    main_lines=$(wc -l < "$MAIN_SCRIPT")
    
    # Original monolith was 1667 lines; loader-based entrypoint grew with platform branches.
    # Budget < 450 (was 300) — see dev-docs/development/platform-test-matrix.md
    if [ "$main_lines" -lt 450 ]; then
        echo "  Main script: $main_lines lines (reduced from 1667)"
        print_test_result "Main script significantly reduced in size" "PASS"
    else
        echo "  Main script: $main_lines lines (expected < 450)"
        print_test_result "Main script significantly reduced in size" "FAIL"
    fi
}

# Main test execution
main() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Sleep Warning System - Modular Refactor Test Suite${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    print_section "File Structure Tests"
    test_library_files_exist
    test_main_function_exists
    test_script_size
    
    print_section "Syntax Tests"
    test_module_syntax
    test_main_script_syntax
    
    print_section "Module Loading Tests"
    test_module_sourcing
    test_main_script_modules
    
    print_section "Functionality Tests"
    test_config_functions
    test_display_functions
    test_time_validation
    
    # Print summary
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Tests Run:    $TESTS_RUN"
    echo -e "  Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    
    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo -e "  Tests Failed: ${RED}$TESTS_FAILED${NC}"
        echo ""
        echo -e "${RED}✗ Some tests failed${NC}"
        exit 1
    else
        echo -e "  Tests Failed: $TESTS_FAILED"
        echo ""
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        echo "The modular refactor is working correctly."
        exit 0
    fi
}

# Run tests
main "$@"
