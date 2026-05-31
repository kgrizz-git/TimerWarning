#!/bin/bash

###############################################################################
# Integration Test Suite for Enhancement #3: Enhanced Window Size Options
#
# This script tests the full integration using dummy config files and
# test copies of scripts to verify:
# - write_config() with new parameters
# - Reading configs with new options
# - Display-based mode calculations
# - Custom size handling
# - Full flow from config to dimensions
#
# Safety:
#   This test DOES NOT modify your real config file.
#   It uses test config files in tests/test-configs/enhancement-03/output/
#   The test backs up and restores CONFIG_FILE/CONFIG_DIR to ensure
#   the real config is never touched.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEST_CONFIG_DIR="${SCRIPT_DIR}/tests/test-configs/enhancement-03"
TEST_OUTPUT_DIR="${TEST_CONFIG_DIR}/output"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Backup original config paths (to restore after tests)
ORIGINAL_CONFIG_DIR=""
ORIGINAL_CONFIG_FILE=""

# Cleanup
cleanup() {
    # Restore original config paths if they were backed up
    if [ -n "${ORIGINAL_CONFIG_DIR}" ]; then
        CONFIG_DIR="${ORIGINAL_CONFIG_DIR}"
    fi
    if [ -n "${ORIGINAL_CONFIG_FILE}" ]; then
        CONFIG_FILE="${ORIGINAL_CONFIG_FILE}"
    fi
    
    # Clean up test output directory
    rm -rf "${TEST_OUTPUT_DIR}"
}

trap cleanup EXIT INT TERM

# Setup
setup() {
    mkdir -p "${TEST_CONFIG_DIR}"
    mkdir -p "${TEST_OUTPUT_DIR}"
    
    # Backup original config paths before sourcing modules
    # (config.sh will set these to real paths, so we save them first)
    ORIGINAL_CONFIG_DIR="${CONFIG_DIR:-}"
    ORIGINAL_CONFIG_FILE="${CONFIG_FILE:-}"
    
    # Set test config paths BEFORE sourcing modules
    # This ensures modules use test paths from the start
    CONFIG_DIR="${TEST_OUTPUT_DIR}"
    CONFIG_FILE="${TEST_OUTPUT_DIR}/test.conf"
    
    # Create test config directory structure
    mkdir -p "${CONFIG_DIR}"
    
    # Source required modules
    # Note: config.sh will override CONFIG_FILE, so we'll restore it after sourcing
    source "${LIB_DIR}/configure-core.sh" || exit 1
    source "${LIB_DIR}/configure-config.sh" || exit 1
    source "${LIB_DIR}/config.sh" || exit 1
    source "${LIB_DIR}/resolution-detection.sh" || exit 1
    
    # Restore test CONFIG_FILE after sourcing (config.sh sets it to real path)
    CONFIG_DIR="${TEST_OUTPUT_DIR}"
    CONFIG_FILE="${TEST_OUTPUT_DIR}/test.conf"
}

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        if [ -n "$details" ]; then
            echo "    $details"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        if [ -n "$details" ]; then
            echo "    $details"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

# Test 1: write_config() with new Enhancement #3 parameters
test_write_config_new_params() {
    print_section "write_config() with Enhancement #3 Parameters"
    
    local test_config="${TEST_OUTPUT_DIR}/test-write-config.conf"
    # Use test-specific config file (override the default test config)
    CONFIG_FILE="${test_config}"
    
    # Initialize arrays
    declare -a config_lines=()
    
    # Test writing with display-based mode and custom size
    # Note: write_config requires 16 positional parameters before config_lines array
    write_config \
        "10" "custom" "center" "30" "true" "false" "true" "none" "true" "5" "24" "auto" "false" \
        "display-based" "50%x50%" "1280x720" \
        "${config_lines[@]}"
    
    if [ ! -f "${test_config}" ]; then
        print_test_result "write_config() creates config file" "FAIL" "File not created"
        return
    fi
    
    # Check for new parameters
    if grep -q "^POPUP_SIZE_MODE=display-based" "${test_config}"; then
        print_test_result "write_config() writes POPUP_SIZE_MODE" "PASS"
    else
        print_test_result "write_config() writes POPUP_SIZE_MODE" "FAIL" "POPUP_SIZE_MODE not found"
    fi
    
    if grep -q "^POPUP_SIZE_CUSTOM=50%x50%" "${test_config}"; then
        print_test_result "write_config() writes POPUP_SIZE_CUSTOM" "PASS"
    else
        print_test_result "write_config() writes POPUP_SIZE_CUSTOM" "FAIL" "POPUP_SIZE_CUSTOM not found"
    fi
    
    if grep -q "^POPUP_SIZE_CUSTOM_ABSOLUTE=1280x720" "${test_config}"; then
        print_test_result "write_config() writes POPUP_SIZE_CUSTOM_ABSOLUTE" "PASS"
    else
        print_test_result "write_config() writes POPUP_SIZE_CUSTOM_ABSOLUTE" "FAIL" "POPUP_SIZE_CUSTOM_ABSOLUTE not found"
    fi
    
    # Test with fixed mode and new sizes
    # Note: write_config requires 16 positional parameters before config_lines array
    write_config \
        "10" "xlarge" "center" "30" "true" "false" "true" "none" "true" "5" "24" "auto" "false" \
        "fixed" "50%x50%" "1280x720" \
        "${config_lines[@]}"
    
    if grep -q "^POPUP_SIZE_MODE=fixed" "${test_config}"; then
        print_test_result "write_config() writes fixed mode" "PASS"
    else
        print_test_result "write_config() writes fixed mode" "FAIL" "POPUP_SIZE_MODE=fixed not found"
    fi
    
    if grep -q "^POPUP_SIZE=xlarge" "${test_config}"; then
        print_test_result "write_config() writes new size (xlarge)" "PASS"
    else
        print_test_result "write_config() writes new size (xlarge)" "FAIL" "POPUP_SIZE=xlarge not found"
    fi
}

# Test 2: Reading config with new options
test_read_config_new_options() {
    print_section "Reading Config with New Options"
    
    local test_config="${TEST_OUTPUT_DIR}/test-read-config.conf"
    CONFIG_FILE="${test_config}"
    
    # Create test config with all new options
    cat > "${test_config}" << 'EOF'
CHECK_INTERVAL=10
POPUP_SIZE=custom
POPUP_SIZE_MODE=display-based
POPUP_SIZE_CUSTOM=75%x75%
POPUP_SIZE_CUSTOM_ABSOLUTE=1920x1080
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true
EOF
    
    # Test getter functions
    local mode
    mode=$(get_popup_size_mode)
    if [ "$mode" = "display-based" ]; then
        print_test_result "get_popup_size_mode() reads display-based" "PASS"
    else
        print_test_result "get_popup_size_mode() reads display-based" "FAIL" "Got: $mode"
    fi
    
    local custom
    custom=$(get_popup_size_custom)
    if [ "$custom" = "75%x75%" ]; then
        print_test_result "get_popup_size_custom() reads custom size" "PASS"
    else
        print_test_result "get_popup_size_custom() reads custom size" "FAIL" "Got: $custom"
    fi
    
    local custom_abs
    custom_abs=$(get_popup_size_custom_absolute)
    if [ "$custom_abs" = "1920x1080" ]; then
        print_test_result "get_popup_size_custom_absolute() reads absolute" "PASS"
    else
        print_test_result "get_popup_size_custom_absolute() reads absolute" "FAIL" "Got: $custom_abs"
    fi
    
    # Test with fixed mode
    cat > "${test_config}" << 'EOF'
POPUP_SIZE_MODE=fixed
POPUP_SIZE=max
EOF
    
    mode=$(get_popup_size_mode)
    if [ "$mode" = "fixed" ]; then
        print_test_result "get_popup_size_mode() reads fixed" "PASS"
    else
        print_test_result "get_popup_size_mode() reads fixed" "FAIL" "Got: $mode"
    fi
}

# Test 3: Display-based mode calculations
test_display_based_calculations() {
    print_section "Display-Based Mode Calculations"
    
    local test_config="${TEST_OUTPUT_DIR}/test-display-based.conf"
    CONFIG_FILE="${test_config}"
    
    # Get current resolution
    local resolution
    resolution=$(get_display_resolution 2>/dev/null)
    if [ -z "$resolution" ]; then
        print_test_result "Display-based calculations" "FAIL" "Resolution detection failed"
        return
    fi
    
    local screen_width screen_height
    screen_width=$(echo "$resolution" | cut -d' ' -f1)
    screen_height=$(echo "$resolution" | cut -d' ' -f2)
    
    # Test medium (30% of screen)
    cat > "${test_config}" << EOF
POPUP_SIZE_MODE=display-based
POPUP_SIZE=medium
EOF
    
    local dims
    dims=$(get_popup_dimensions "medium")
    local expected_width expected_height
    expected_width=$((screen_width * 30 / 100))
    expected_height=$((screen_height * 30 / 100))
    local actual_width actual_height
    actual_width=$(echo "$dims" | cut -d' ' -f1)
    actual_height=$(echo "$dims" | cut -d' ' -f2)
    
    if [ "$actual_width" -eq "$expected_width" ] && [ "$actual_height" -eq "$expected_height" ]; then
        print_test_result "Display-based medium (30%) calculation" "PASS" "Got: ${actual_width}x${actual_height}, Expected: ${expected_width}x${expected_height}"
    else
        print_test_result "Display-based medium (30%) calculation" "FAIL" "Got: ${actual_width}x${actual_height}, Expected: ${expected_width}x${expected_height}"
    fi
    
    # Test xsmall (15% of screen)
    cat > "${test_config}" << EOF
POPUP_SIZE_MODE=display-based
POPUP_SIZE=xsmall
EOF
    
    dims=$(get_popup_dimensions "xsmall")
    expected_width=$((screen_width * 15 / 100))
    expected_height=$((screen_height * 15 / 100))
    actual_width=$(echo "$dims" | cut -d' ' -f1)
    actual_height=$(echo "$dims" | cut -d' ' -f2)
    
    if [ "$actual_width" -eq "$expected_width" ] && [ "$actual_height" -eq "$expected_height" ]; then
        print_test_result "Display-based xsmall (15%) calculation" "PASS" "Got: ${actual_width}x${actual_height}, Expected: ${expected_width}x${expected_height}"
    else
        print_test_result "Display-based xsmall (15%) calculation" "FAIL" "Got: ${actual_width}x${actual_height}, Expected: ${expected_width}x${expected_height}"
    fi
}

# Test 4: Custom size handling
test_custom_size_handling() {
    print_section "Custom Size Handling"
    
    local test_config="${TEST_OUTPUT_DIR}/test-custom-size.conf"
    CONFIG_FILE="${test_config}"
    
    # Test custom percentage size
    cat > "${test_config}" << 'EOF'
POPUP_SIZE_MODE=display-based
POPUP_SIZE=custom
POPUP_SIZE_CUSTOM=60%x60%
POPUP_SIZE_CUSTOM_ABSOLUTE=1536x864
EOF
    
    local dims
    dims=$(get_popup_dimensions "custom")
    if [ -n "$dims" ]; then
        local width height
        width=$(echo "$dims" | cut -d' ' -f1)
        height=$(echo "$dims" | cut -d' ' -f2)
        
        # Should use percentage calculation if resolution available
        local resolution
        resolution=$(get_display_resolution 2>/dev/null)
        if [ -n "$resolution" ]; then
            local screen_width screen_height
            screen_width=$(echo "$resolution" | cut -d' ' -f1)
            screen_height=$(echo "$resolution" | cut -d' ' -f2)
            local expected_width expected_height
            expected_width=$((screen_width * 60 / 100))
            expected_height=$((screen_height * 60 / 100))
            
            if [ "$width" -eq "$expected_width" ] && [ "$height" -eq "$expected_height" ]; then
                print_test_result "Custom percentage size calculation" "PASS" "Got: ${width}x${height}"
            else
                print_test_result "Custom percentage size calculation" "FAIL" "Got: ${width}x${height}, Expected: ${expected_width}x${expected_height}"
            fi
        else
            # Fallback to absolute
            if [ "$width" -eq 1536 ] && [ "$height" -eq 864 ]; then
                print_test_result "Custom size fallback to absolute" "PASS" "Got: ${width}x${height}"
            else
                print_test_result "Custom size fallback to absolute" "FAIL" "Got: ${width}x${height}"
            fi
        fi
    else
        print_test_result "Custom percentage size calculation" "FAIL" "No dimensions returned"
    fi
    
    # Test custom pixel size
    cat > "${test_config}" << 'EOF'
POPUP_SIZE_MODE=fixed
POPUP_SIZE=custom
POPUP_SIZE_CUSTOM=1920x1080
POPUP_SIZE_CUSTOM_ABSOLUTE=1920x1080
EOF
    
    dims=$(get_popup_dimensions "custom")
    if [ "$dims" = "1920 1080" ]; then
        print_test_result "Custom pixel size handling" "PASS"
    else
        print_test_result "Custom pixel size handling" "FAIL" "Got: $dims"
    fi
}

# Test 5: Backward compatibility with old configs
test_backward_compatibility() {
    print_section "Backward Compatibility"
    
    local test_config="${TEST_OUTPUT_DIR}/test-backward-compat.conf"
    CONFIG_FILE="${test_config}"
    
    # Old config without new options
    cat > "${test_config}" << 'EOF'
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true
EOF
    
    # Should default to fixed mode
    local mode
    mode=$(get_popup_size_mode)
    if [ "$mode" = "fixed" ]; then
        print_test_result "Old config defaults to fixed mode" "PASS"
    else
        print_test_result "Old config defaults to fixed mode" "FAIL" "Got: $mode"
    fi
    
    # Should still work with old sizes
    local dims
    dims=$(get_popup_dimensions "medium")
    if [ "$dims" = "800 500" ]; then
        print_test_result "Old config works with old sizes" "PASS"
    else
        print_test_result "Old config works with old sizes" "FAIL" "Got: $dims"
    fi
}

# Test 6: All new sizes in both modes
test_all_new_sizes() {
    print_section "All New Sizes in Both Modes"
    
    local test_config="${TEST_OUTPUT_DIR}/test-all-sizes.conf"
    CONFIG_FILE="${test_config}"
    
    # Test fixed mode
    cat > "${test_config}" << 'EOF'
POPUP_SIZE_MODE=fixed
EOF
    
    # Updated 2026-01-25: Window size adjustments:
    # - large: Changed from 2000x1350 to 1230x720
    # - xlarge: Changed from 1920x1080 to 1845x1080
    # - max: Changed from 2304x1296 to 2214x1296
    local sizes=("xsmall:384 216" "small:400 250" "medium:800 500" "large:1230 720" "xlarge:1845 1080" "max:2214 1296")
    for size_spec in "${sizes[@]}"; do
        local size expected
        size=$(echo "$size_spec" | cut -d':' -f1)
        expected=$(echo "$size_spec" | cut -d':' -f2)
        
        local dims
        dims=$(get_popup_dimensions "$size")
        if [ "$dims" = "$expected" ]; then
            print_test_result "Fixed mode: $size" "PASS"
        else
            print_test_result "Fixed mode: $size" "FAIL" "Got: $dims, Expected: $expected"
        fi
    done
    
    # Test display-based mode (if resolution available)
    local resolution
    resolution=$(get_display_resolution 2>/dev/null)
    if [ -n "$resolution" ]; then
        cat > "${test_config}" << 'EOF'
POPUP_SIZE_MODE=display-based
EOF
        
        local screen_width screen_height
        screen_width=$(echo "$resolution" | cut -d' ' -f1)
        screen_height=$(echo "$resolution" | cut -d' ' -f2)
        
        # Test a few sizes
        local dims
        dims=$(get_popup_dimensions "xsmall")
        local expected_width expected_height
        expected_width=$((screen_width * 15 / 100))
        expected_height=$((screen_height * 15 / 100))
        local actual_width actual_height
        actual_width=$(echo "$dims" | cut -d' ' -f1)
        actual_height=$(echo "$dims" | cut -d' ' -f2)
        
        if [ "$actual_width" -eq "$expected_width" ] && [ "$actual_height" -eq "$expected_height" ]; then
            print_test_result "Display-based mode: xsmall" "PASS" "Got: ${actual_width}x${actual_height}"
        else
            print_test_result "Display-based mode: xsmall" "FAIL" "Got: ${actual_width}x${actual_height}, Expected: ${expected_width}x${expected_height}"
        fi
    fi
}

# Main execution
echo "=========================================="
echo "Enhancement #3: Integration Tests"
echo "=========================================="

setup

test_write_config_new_params
test_read_config_new_options
test_display_based_calculations
test_custom_size_handling
test_backward_compatibility
test_all_new_sizes

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests run: ${TESTS_RUN}"
echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
echo ""

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
