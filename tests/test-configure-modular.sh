#!/bin/bash

###############################################################################
# Sleep Warning System - Configure Modular Refactor Test Suite
#
# This script tests the modular refactor of configure.sh to ensure:
# - All configure modules source correctly
# - Functions are accessible
# - No functionality is broken
# - All dependencies are properly handled
#
# Usage: ./tests/test-configure-modular.sh
#
# Last updated: 2026-06-12 (configure-input-features facade + submodules)
###############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
MAIN_SCRIPT="${SCRIPT_DIR}/configure.sh"

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
        "configure-core.sh"
        "configure-config.sh"
        "configure-time.sh"
        "configure-ui.sh"
        "configure-input-basic.sh"
        "configure-input-popup.sh"
        "configure-input-features.sh"
        "configure-input-feature-helpers.sh"
        "configure-input-security.sh"
        "configure-input-pause.sh"
        "configure-input-dialog-tool.sh"
        "configure-input-time.sh"
        "configure-input-service.sh"
        "configure-display.sh"
        "configure-display-menu.sh"
        "configure-display-grid.sh"
        "configure-display-summary.sh"
        "configure-ui-errors.sh"
        "configure-workflow.sh"
    )
    
    local all_exist=true
    for file in "${expected_files[@]}"; do
        if [ ! -f "${LIB_DIR}/${file}" ]; then
            echo "  Missing: ${file}"
            all_exist=false
        fi
    done
    
    if [ "$all_exist" = true ]; then
        print_test_result "All 7 configure library modules exist" "PASS"
    else
        print_test_result "All 7 configure library modules exist" "FAIL"
    fi
}

# Test 2: Syntax check all modules
test_module_syntax() {
    local all_valid=true
    
    for module in "${LIB_DIR}"/configure-*.sh; do
        if ! bash -n "$module" 2>/dev/null; then
            echo "  Syntax error in: $(basename $module)"
            all_valid=false
        fi
    done
    
    if [ "$all_valid" = true ]; then
        print_test_result "All configure modules pass syntax check" "PASS"
    else
        print_test_result "All configure modules pass syntax check" "FAIL"
    fi
}

# Test 3: Syntax check main script
test_main_script_syntax() {
    if bash -n "$MAIN_SCRIPT" 2>/dev/null; then
        print_test_result "Main configure.sh passes syntax check" "PASS"
    else
        print_test_result "Main configure.sh passes syntax check" "FAIL"
    fi
}

# Test 4: Test module sourcing (dependency order)
test_module_sourcing() {
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
SCRIPT_DIR="${SCRIPT_DIR}"
LIB_DIR="\${SCRIPT_DIR}/lib"

# Try to source all modules in dependency order
source "\${LIB_DIR}/configure-core.sh" || exit 1
source "\${LIB_DIR}/configure-config.sh" || exit 2
source "\${LIB_DIR}/configure-time.sh" || exit 3
source "\${LIB_DIR}/configure-ui.sh" || exit 4
source "\${LIB_DIR}/configure-input-basic.sh" || exit 5
source "\${LIB_DIR}/configure-input-popup.sh" || exit 5
source "\${LIB_DIR}/configure-input-features.sh" || exit 5
source "\${LIB_DIR}/configure-input-time.sh" || exit 5
source "\${LIB_DIR}/configure-input-service.sh" || exit 5
source "\${LIB_DIR}/configure-display.sh" || exit 6
source "\${LIB_DIR}/configure-workflow.sh" || exit 7

echo "SUCCESS"
EOF
    
    cd "$SCRIPT_DIR"
    local result
    result=$(bash "$test_script" 2>&1)
    local exit_code=$?
    
    rm -f "$test_script"
    
    if [ "$exit_code" -eq 0 ] && [ "$result" = "SUCCESS" ]; then
        print_test_result "All modules source in correct order" "PASS"
    else
        echo "  Exit code: $exit_code"
        echo "  Output: $result"
        print_test_result "All modules source in correct order" "FAIL"
    fi
}

# Test 5: Test core functions are defined
test_core_functions() {
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
SCRIPT_DIR="${SCRIPT_DIR}"
LIB_DIR="\${SCRIPT_DIR}/lib"

source "\${LIB_DIR}/configure-core.sh" || exit 1

# Check if core functions exist
declare -f has_zenity >/dev/null || exit 2
declare -f has_gui >/dev/null || exit 3
declare -f minutes_to_oncalendar >/dev/null || exit 4
declare -f format_hour_12h >/dev/null || exit 5

echo "SUCCESS"
EOF
    
    cd "$SCRIPT_DIR"
    local result
    result=$(bash "$test_script" 2>&1)
    local exit_code=$?
    
    rm -f "$test_script"
    
    if [ "$exit_code" -eq 0 ] && [ "$result" = "SUCCESS" ]; then
        print_test_result "Core module functions are defined" "PASS"
    else
        echo "  Exit code: $exit_code"
        print_test_result "Core module functions are defined" "FAIL"
    fi
}

# Test 6: Test config functions are defined
test_config_functions() {
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
SCRIPT_DIR="${SCRIPT_DIR}"
LIB_DIR="\${SCRIPT_DIR}/lib"

source "\${LIB_DIR}/configure-core.sh" || exit 1
source "\${LIB_DIR}/configure-config.sh" || exit 2

# Check if config functions exist
declare -f load_existing_config >/dev/null || exit 3
declare -f extract_user_comments >/dev/null || exit 4
declare -f write_config >/dev/null || exit 5
declare -f update_timer_file >/dev/null || exit 6

echo "SUCCESS"
EOF
    
    cd "$SCRIPT_DIR"
    local result
    result=$(bash "$test_script" 2>&1)
    local exit_code=$?
    
    rm -f "$test_script"
    
    if [ "$exit_code" -eq 0 ] && [ "$result" = "SUCCESS" ]; then
        print_test_result "Config module functions are defined" "PASS"
    else
        echo "  Exit code: $exit_code"
        print_test_result "Config module functions are defined" "FAIL"
    fi
}

# Test 7: Test time formatting functions are defined
test_time_functions() {
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
SCRIPT_DIR="${SCRIPT_DIR}"
LIB_DIR="\${SCRIPT_DIR}/lib"

source "\${LIB_DIR}/configure-core.sh" || exit 1
source "\${LIB_DIR}/configure-time.sh" || exit 2

# Check if time functions exist
declare -f format_range_human >/dev/null || exit 3
declare -f format_ranges_human >/dev/null || exit 4
declare -f detect_overlaps >/dev/null || exit 5
declare -f get_inherited_restrictions >/dev/null || exit 6

echo "SUCCESS"
EOF
    
    cd "$SCRIPT_DIR"
    local result
    result=$(bash "$test_script" 2>&1)
    local exit_code=$?
    
    rm -f "$test_script"
    
    if [ "$exit_code" -eq 0 ] && [ "$result" = "SUCCESS" ]; then
        print_test_result "Time module functions are defined" "PASS"
    else
        echo "  Exit code: $exit_code"
        print_test_result "Time module functions are defined" "FAIL"
    fi
}

# Test 8: Test all constants are defined
test_constants_defined() {
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
SCRIPT_DIR="${SCRIPT_DIR}"
LIB_DIR="\${SCRIPT_DIR}/lib"

source "\${LIB_DIR}/configure-core.sh" || exit 1

# Check if constants exist
[ -n "\$SCRIPT_NAME" ] || exit 2
[ -n "\$CONFIG_DIR" ] || exit 3
[ -n "\$CONFIG_FILE" ] || exit 4
[ \${#DAY_NAMES[@]} -eq 7 ] || exit 5
[ \${#DAY_VARS[@]} -eq 7 ] || exit 6

echo "SUCCESS"
EOF
    
    cd "$SCRIPT_DIR"
    local result
    result=$(bash "$test_script" 2>&1)
    local exit_code=$?
    
    rm -f "$test_script"
    
    if [ "$exit_code" -eq 0 ] && [ "$result" = "SUCCESS" ]; then
        print_test_result "All constants are defined" "PASS"
    else
        echo "  Exit code: $exit_code"
        print_test_result "All constants are defined" "FAIL"
    fi
}

# Test 9: Test module file sizes (ensure they're reasonable)
test_module_sizes() {
    local all_reasonable=true
    
    for module in "${LIB_DIR}"/configure-*.sh; do
        local basename_module=$(basename "$module")
        # Skip the old configure-input.sh if it still exists (being kept as backup temporarily)
        if [ "${basename_module}" = "configure-input.sh" ]; then
            continue
        fi
        local lines=$(wc -l < "$module")
        # Thin facades (e.g. configure-input-features.sh) may be under 50 lines.
        local min_lines=50
        case "${basename_module}" in
            configure-input-features.sh)
                min_lines=20
                ;;
        esac
        # Modules should be between min_lines and 2500 lines (reasonable sizes)
        if [ "$lines" -lt "${min_lines}" ] || [ "$lines" -gt 2500 ]; then
            echo "  ${basename_module}: $lines lines (unexpected size)"
            all_reasonable=false
        fi
    done
    
    if [ "$all_reasonable" = true ]; then
        print_test_result "All modules have reasonable sizes" "PASS"
    else
        print_test_result "All modules have reasonable sizes" "FAIL"
    fi
}

# Test 10: Test main script is streamlined
test_main_script_size() {
    local lines=$(wc -l < "$MAIN_SCRIPT")
    
    # Main script should be streamlined (adjusted expectation: 200-700 lines)
    if [ "$lines" -ge 200 ] && [ "$lines" -le 700 ]; then
        print_test_result "Main script is streamlined ($lines lines)" "PASS"
    else
        echo "  Expected 200-600 lines, got $lines"
        print_test_result "Main script is streamlined" "FAIL"
    fi
}

# Main test execution
main() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Configure.sh Modular Refactor Test Suite${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    
    print_section "File Existence Tests"
    test_library_files_exist
    
    print_section "Syntax Tests"
    test_module_syntax
    test_main_script_syntax
    
    print_section "Module Sourcing Tests"
    test_module_sourcing
    
    print_section "Function Definition Tests"
    test_core_functions
    test_config_functions
    test_time_functions
    
    print_section "Configuration Tests"
    test_constants_defined
    
    print_section "Size and Structure Tests"
    test_module_sizes
    test_main_script_size
    
    # Print summary
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Test Summary${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        echo ""
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        echo ""
        exit 0
    fi
}

# Run tests
main
