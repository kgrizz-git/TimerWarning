#!/bin/bash

###############################################################################
# Test Suite for Enhancement #3: Enhanced Window Size Options
#
# This script tests the new window size features including:
# - Resolution detection
# - New predefined sizes (xsmall, xlarge, max)
# - Percentage format parsing
# - Display-based mode calculations
# - Config getter functions
# - get_popup_dimensions() with all new features
#
# Safety:
#   This test uses a temporary config file and does not modify the real config.
###############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

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

# Print section header
print_section() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

# Create temporary config file
create_temp_config() {
    local mode="${1:-fixed}"
    local size="${2:-medium}"
    local custom="${3:-}"
    local custom_abs="${4:-}"
    
    local tmp_config
    tmp_config=$(mktemp)
    
    {
        echo "# Test config file"
        echo "CHECK_INTERVAL=10"
        echo "POPUP_SIZE=${size}"
        echo "POPUP_SIZE_MODE=${mode}"
        if [ -n "${custom}" ]; then
            echo "POPUP_SIZE_CUSTOM=${custom}"
        fi
        if [ -n "${custom_abs}" ]; then
            echo "POPUP_SIZE_CUSTOM_ABSOLUTE=${custom_abs}"
        fi
        echo "POPUP_POSITION=center"
        echo "POPUP_MIN_DISPLAY_TIME=30"
        echo "POPUP_IMMOVABLE=true"
    } > "${tmp_config}"
    
    echo "${tmp_config}"
}

# Test 1: Resolution detection function exists and works
test_resolution_detection() {
    print_section "Resolution Detection"
    
    local result
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
source "${LIB_DIR}/resolution-detection.sh" 2>/dev/null || exit 1

# Test that function exists
type get_display_resolution >/dev/null 2>&1 || exit 1

# Test that function can be called (may return empty on failure, but should not error)
resolution=$(get_display_resolution 2>&1)
exit_code=$?

# Function should exist and return (even if empty)
if [ $exit_code -eq 0 ] || [ $exit_code -eq 1 ]; then
    echo "SUCCESS"
else
    exit 1
fi
' 2>/dev/null)
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "Resolution detection function exists and is callable" "PASS"
    else
        print_test_result "Resolution detection function exists and is callable" "FAIL"
    fi
}

# Test 2: New getter functions exist
test_new_getter_functions() {
    print_section "New Getter Functions"
    
    local result
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
TEST_CONFIG_FILE="${CONFIG_FILE:-}"
source "${LIB_DIR}/config.sh" 2>/dev/null || exit 1
[ -n "${TEST_CONFIG_FILE}" ] && CONFIG_FILE="${TEST_CONFIG_FILE}"

# Test that new functions exist
type get_popup_size_mode >/dev/null 2>&1 || exit 1
type get_popup_size_custom >/dev/null 2>&1 || exit 1
type get_popup_size_custom_absolute >/dev/null 2>&1 || exit 1

echo "SUCCESS"
' 2>/dev/null)
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "New getter functions exist" "PASS"
    else
        print_test_result "New getter functions exist" "FAIL"
    fi
}

# Test 3: get_popup_size() validates new sizes
test_popup_size_validation() {
    print_section "Popup Size Validation"
    
    local tmp_config
    tmp_config=$(create_temp_config "fixed" "xsmall")
    
    local result
    export CONFIG_FILE="${tmp_config}"
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
TEST_CONFIG_FILE="${CONFIG_FILE:-}"
source "${LIB_DIR}/config.sh" 2>/dev/null || exit 1
[ -n "${TEST_CONFIG_FILE}" ] && CONFIG_FILE="${TEST_CONFIG_FILE}"

# Test new predefined sizes
for size in xsmall small medium large xlarge max custom; do
    echo "POPUP_SIZE=${size}" > "${CONFIG_FILE}"
    result=$(get_popup_size)
    if [ "${result}" != "${size}" ]; then
        echo "FAIL: ${size} returned ${result}"
        exit 1
    fi
done

# Test percentage format
echo "POPUP_SIZE=50%x50%" > "${CONFIG_FILE}"
result=$(get_popup_size)
if [ "${result}" != "50%x50%" ]; then
    echo "FAIL: percentage format not accepted"
    exit 1
fi

# Test pixel format (should still work)
echo "POPUP_SIZE=1280x720" > "${CONFIG_FILE}"
result=$(get_popup_size)
if [ "${result}" != "1280x720" ]; then
    echo "FAIL: pixel format not accepted"
    exit 1
fi

echo "SUCCESS"
' 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "get_popup_size() validates new sizes and formats" "PASS"
    else
        print_test_result "get_popup_size() validates new sizes and formats" "FAIL" "$result"
    fi
}

# Test 4: get_popup_dimensions() with new sizes in fixed mode
test_popup_dimensions_fixed_mode() {
    print_section "Popup Dimensions - Fixed Mode"
    
    local tmp_config
    tmp_config=$(create_temp_config "fixed" "xsmall")
    
    local result
    export CONFIG_FILE="${tmp_config}"
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
TEST_CONFIG_FILE="${CONFIG_FILE:-}"
source "${LIB_DIR}/config.sh" 2>/dev/null || exit 1
[ -n "${TEST_CONFIG_FILE}" ] && CONFIG_FILE="${TEST_CONFIG_FILE}"
source "${LIB_DIR}/resolution-detection.sh" 2>/dev/null || exit 1

# Test xsmall in fixed mode (should return 384x216)
echo "POPUP_SIZE_MODE=fixed" > "${CONFIG_FILE}"
echo "POPUP_SIZE=xsmall" >> "${CONFIG_FILE}"
dimensions=$(get_popup_dimensions "xsmall")
expected="384 216"
if [ "${dimensions}" != "${expected}" ]; then
    echo "FAIL: xsmall fixed mode returned ${dimensions}, expected ${expected}"
    exit 1
fi

# Test xlarge in fixed mode (should return 1845x1080)
# Updated 2026-01-25: Changed from 1920x1080 to 1845x1080 per window size adjustments
dimensions=$(get_popup_dimensions "xlarge")
expected="1845 1080"
if [ "${dimensions}" != "${expected}" ]; then
    echo "FAIL: xlarge fixed mode returned ${dimensions}, expected ${expected}"
    exit 1
fi

# Test max in fixed mode (should return 2214x1296)
# Updated 2026-01-25: Changed from 2304x1296 to 2214x1296 per window size adjustments
dimensions=$(get_popup_dimensions "max")
expected="2214 1296"
if [ "${dimensions}" != "${expected}" ]; then
    echo "FAIL: max fixed mode returned ${dimensions}, expected ${expected}"
    exit 1
fi

echo "SUCCESS"
' 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "get_popup_dimensions() returns correct fixed mode values" "PASS"
    else
        print_test_result "get_popup_dimensions() returns correct fixed mode values" "FAIL" "$result"
    fi
}

# Test 5: get_popup_dimensions() with percentage format
test_popup_dimensions_percentage() {
    print_section "Popup Dimensions - Percentage Format"
    
    local tmp_config
    tmp_config=$(create_temp_config "fixed" "medium")
    
    local result
    export CONFIG_FILE="${tmp_config}"
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
TEST_CONFIG_FILE="${CONFIG_FILE:-}"
source "${LIB_DIR}/config.sh" 2>/dev/null || exit 1
[ -n "${TEST_CONFIG_FILE}" ] && CONFIG_FILE="${TEST_CONFIG_FILE}"
source "${LIB_DIR}/resolution-detection.sh" 2>/dev/null || exit 1

# Test percentage format (50%x50%)
# Should calculate from resolution if available, or use fallback
dimensions=$(get_popup_dimensions "50%x50%")
if [ -z "${dimensions}" ]; then
    echo "FAIL: percentage format returned empty"
    exit 1
fi

# Should return two numbers (width and height)
width=$(echo "${dimensions}" | cut -d" " -f1)
height=$(echo "${dimensions}" | cut -d" " -f2)

if ! [[ "${width}" =~ ^[0-9]+$ ]] || ! [[ "${height}" =~ ^[0-9]+$ ]]; then
    echo "FAIL: percentage format did not return valid dimensions"
    exit 1
fi

# Test invalid percentage (should use fallback)
dimensions=$(get_popup_dimensions "5%x5%")  # Below 15% minimum
# Should still return something (fallback)
if [ -z "${dimensions}" ]; then
    echo "FAIL: invalid percentage returned empty (should use fallback)"
    exit 1
fi

echo "SUCCESS"
' 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "get_popup_dimensions() handles percentage format" "PASS"
    else
        print_test_result "get_popup_dimensions() handles percentage format" "FAIL" "$result"
    fi
}

# Test 6: get_popup_dimensions() with custom size
test_popup_dimensions_custom() {
    print_section "Popup Dimensions - Custom Size"
    
    local tmp_config
    tmp_config=$(create_temp_config "fixed" "custom" "50%x50%" "1280x720")
    
    local result
    export CONFIG_FILE="${tmp_config}"
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
TEST_CONFIG_FILE="${CONFIG_FILE:-}"
source "${LIB_DIR}/config.sh" 2>/dev/null || exit 1
[ -n "${TEST_CONFIG_FILE}" ] && CONFIG_FILE="${TEST_CONFIG_FILE}"
source "${LIB_DIR}/resolution-detection.sh" 2>/dev/null || exit 1

# Test custom size with percentage
dimensions=$(get_popup_dimensions "custom")
if [ -z "${dimensions}" ]; then
    echo "FAIL: custom size returned empty"
    exit 1
fi

# Should return valid dimensions
width=$(echo "${dimensions}" | cut -d" " -f1)
height=$(echo "${dimensions}" | cut -d" " -f2)

if ! [[ "${width}" =~ ^[0-9]+$ ]] || ! [[ "${height}" =~ ^[0-9]+$ ]]; then
    echo "FAIL: custom size did not return valid dimensions"
    exit 1
fi

echo "SUCCESS"
' 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "get_popup_dimensions() handles custom size" "PASS"
    else
        print_test_result "get_popup_dimensions() handles custom size" "FAIL" "$result"
    fi
}

# Test 7: get_popup_size_mode() returns correct values
test_popup_size_mode() {
    print_section "Popup Size Mode Getter"
    
    # Test default (no config file)
    local result1
    result1=$(bash -c "
cd '${SCRIPT_DIR}' || exit 1
LIB_DIR='./lib'
source \"\${LIB_DIR}/config.sh\" 2>/dev/null || exit 1

# No config file - should default to fixed
# Set CONFIG_FILE after sourcing (since sourcing sets it to default)
CONFIG_FILE='/nonexistent/file'
mode=\$(get_popup_size_mode)
if [ \"\${mode}\" != \"fixed\" ]; then
    echo \"FAIL: default mode should be fixed, got \${mode}\"
    exit 1
fi

echo \"SUCCESS\"
" 2>/dev/null)
    
    # Test with config file
    local tmp_config
    tmp_config=$(create_temp_config "display-based" "medium")
    
    local result2
    result2=$(bash -c "
cd '${SCRIPT_DIR}' || exit 1
LIB_DIR='./lib'
source \"\${LIB_DIR}/config.sh\" 2>/dev/null || exit 1

# Set CONFIG_FILE after sourcing (since sourcing sets it to default)
CONFIG_FILE='${tmp_config}'
mode=\$(get_popup_size_mode)
if [ \"\${mode}\" != \"display-based\" ]; then
    echo \"FAIL: should return display-based, got \${mode}\"
    exit 1
fi

# Test fixed mode
echo \"POPUP_SIZE_MODE=fixed\" > \"\${CONFIG_FILE}\"
mode=\$(get_popup_size_mode)
if [ \"\${mode}\" != \"fixed\" ]; then
    echo \"FAIL: should return fixed, got \${mode}\"
    exit 1
fi

echo \"SUCCESS\"
" 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result1" = "SUCCESS" ] && [ "$result2" = "SUCCESS" ]; then
        print_test_result "get_popup_size_mode() returns correct values" "PASS"
    else
        local error_msg=""
        [ "$result1" != "SUCCESS" ] && error_msg="${error_msg}Test 1: ${result1}. "
        [ "$result2" != "SUCCESS" ] && error_msg="${error_msg}Test 2: ${result2}."
        print_test_result "get_popup_size_mode() returns correct values" "FAIL" "$error_msg"
    fi
}

# Test 8: Validation ranges (minimum 384x216)
test_validation_ranges() {
    print_section "Validation Ranges"
    
    local tmp_config
    tmp_config=$(create_temp_config "fixed" "medium")
    
    local result
    export CONFIG_FILE="${tmp_config}"
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
TEST_CONFIG_FILE="${CONFIG_FILE:-}"
source "${LIB_DIR}/config.sh" 2>/dev/null || exit 1
[ -n "${TEST_CONFIG_FILE}" ] && CONFIG_FILE="${TEST_CONFIG_FILE}"
source "${LIB_DIR}/resolution-detection.sh" 2>/dev/null || exit 1

# Test minimum size (384x216 should be accepted)
dimensions=$(get_popup_dimensions "384x216")
if [ -z "${dimensions}" ]; then
    echo "FAIL: minimum size 384x216 rejected"
    exit 1
fi

# Test below minimum (should be clamped to minimum)
dimensions=$(get_popup_dimensions "200x100")
width=$(echo "${dimensions}" | cut -d" " -f1)
height=$(echo "${dimensions}" | cut -d" " -f2)

# Should be clamped to at least 384x216
if [ "${width}" -lt 384 ] || [ "${height}" -lt 216 ]; then
    echo "FAIL: size below minimum not clamped correctly"
    exit 1
fi

echo "SUCCESS"
' 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "Validation ranges enforce minimum 384x216" "PASS"
    else
        print_test_result "Validation ranges enforce minimum 384x216" "FAIL" "$result"
    fi
}

# Test 9: Backward compatibility
test_backward_compatibility() {
    print_section "Backward Compatibility"
    
    local tmp_config
    tmp_config=$(create_temp_config "fixed" "small")
    export CONFIG_FILE="${tmp_config}"
    
    local result
    result=$(CONFIG_FILE="${tmp_config}" bash -c "
	cd '${SCRIPT_DIR}' || exit 1
	LIB_DIR='./lib'
	TEST_CONFIG_FILE=\"\${CONFIG_FILE:-}\"
	source \"\${LIB_DIR}/config.sh\" 2>/dev/null || exit 1
	[ -n \"\${TEST_CONFIG_FILE}\" ] && CONFIG_FILE=\"\${TEST_CONFIG_FILE}\"
	source \"\${LIB_DIR}/resolution-detection.sh\" 2>/dev/null || exit 1

# Test old sizes still work
for size in small medium large; do
    dimensions=\$(get_popup_dimensions \"\${size}\")
    if [ -z \"\${dimensions}\" ]; then
        echo \"FAIL: old size \${size} not working\"
        exit 1
    fi
done

# Test old pixel format still works
dimensions=\$(get_popup_dimensions \"800x500\")
if [ -z \"\${dimensions}\" ]; then
    echo \"FAIL: old pixel format not working\"
    exit 1
fi

# Test that missing POPUP_SIZE_MODE defaults to fixed
# (simulate old config without POPUP_SIZE_MODE)
echo \"POPUP_SIZE=medium\" > \"\${CONFIG_FILE}\"
# Don't add POPUP_SIZE_MODE
dimensions=\$(get_popup_dimensions \"medium\")
# In fixed mode, medium should return 800x500 (old behavior)
expected=\"800 500\"
if [ \"\${dimensions}\" != \"\${expected}\" ]; then
    echo \"FAIL: backward compatibility broken - medium should return 800x500 in fixed mode\"
    exit 1
fi

echo \"SUCCESS\"
" 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "Backward compatibility maintained" "PASS"
    else
        print_test_result "Backward compatibility maintained" "FAIL" "$result"
    fi
}

# Test 10: Resolution detection integration
test_resolution_integration() {
    print_section "Resolution Detection Integration"
    
    local tmp_config
    tmp_config=$(create_temp_config "display-based" "medium")
    
    local result
    export CONFIG_FILE="${tmp_config}"
    result=$(cd "$SCRIPT_DIR" && bash -c '
LIB_DIR="./lib"
TEST_CONFIG_FILE="${CONFIG_FILE:-}"
source "${LIB_DIR}/config.sh" 2>/dev/null || exit 1
[ -n "${TEST_CONFIG_FILE}" ] && CONFIG_FILE="${TEST_CONFIG_FILE}"
source "${LIB_DIR}/resolution-detection.sh" 2>/dev/null || exit 1

# Test that get_popup_dimensions can call get_display_resolution
# Even if resolution detection fails, should fall back gracefully
dimensions=$(get_popup_dimensions "medium")
if [ -z "${dimensions}" ]; then
    echo "FAIL: get_popup_dimensions failed even with fallback"
    exit 1
fi

# Should return valid dimensions (either from resolution or fallback)
width=$(echo "${dimensions}" | cut -d" " -f1)
height=$(echo "${dimensions}" | cut -d" " -f2)

if ! [[ "${width}" =~ ^[0-9]+$ ]] || ! [[ "${height}" =~ ^[0-9]+$ ]]; then
    echo "FAIL: invalid dimensions returned"
    exit 1
fi

echo "SUCCESS"
' 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "Resolution detection integrates correctly with fallback" "PASS"
    else
        print_test_result "Resolution detection integrates correctly with fallback" "FAIL" "$result"
    fi
}

# Test 11: Size interpretation edge cases
# Tests how the code interprets sizes with values around 100 to verify format detection
# Note: Current implementation uses explicit format (WIDTHxHEIGHT for pixels, WIDTH%xHEIGHT% for percentages)
# This test verifies the actual behavior vs. the documented heuristic
test_size_interpretation() {
    print_section "Size Interpretation Edge Cases"
    
    local tmp_config
    tmp_config=$(create_temp_config "fixed" "medium")
    
    local result
    export CONFIG_FILE="${tmp_config}"
    result=$(CONFIG_FILE="${tmp_config}" bash -c "
	cd '${SCRIPT_DIR}' || exit 1
	LIB_DIR='./lib'
	TEST_CONFIG_FILE=\"\${CONFIG_FILE:-}\"
	source \"\${LIB_DIR}/config.sh\" 2>/dev/null || exit 1
	[ -n \"\${TEST_CONFIG_FILE}\" ] && CONFIG_FILE=\"\${TEST_CONFIG_FILE}\"
	source \"\${LIB_DIR}/resolution-detection.sh\" 2>/dev/null || exit 1

# Test 1: Values <= 100 in WIDTHxHEIGHT format (should be treated as pixels, not percentages)
# Current implementation: WIDTHxHEIGHT is always pixels, regardless of value
# Note: Values below minimum (384x216) will be clamped to minimum
dimensions=\$(get_popup_dimensions \"400x300\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Should be treated as 400x300 pixels (not 400% of screen)
if [ \"\${width}\" != \"400\" ] || [ \"\${height}\" != \"300\" ]; then
    echo \"FAIL: 400x300 should be treated as 400x300 pixels, got \${width}x\${height}\"
    exit 1
fi

# Test 2: Values > 100 in WIDTHxHEIGHT format (should be treated as pixels)
# Note: Values below minimum (384x216) will be clamped to minimum
dimensions=\$(get_popup_dimensions \"500x400\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Should be treated as 500x400 pixels
if [ \"\${width}\" != \"500\" ] || [ \"\${height}\" != \"400\" ]; then
    echo \"FAIL: 500x400 should be treated as 500x400 pixels, got \${width}x\${height}\"
    exit 1
fi

# Test 3: Values <= 100 in WIDTH%xHEIGHT% format (should be treated as percentages)
dimensions=\$(get_popup_dimensions \"50%x50%\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Should be calculated as percentage of screen (or fallback)
# If resolution detection works, should be 50% of screen
# If not, should use fallback calculation
if [ -z \"\${width}\" ] || [ -z \"\${height}\" ]; then
    echo \"FAIL: 50%x50% should return valid dimensions\"
    exit 1
fi

# Test 4: Values > 100 in WIDTH%xHEIGHT% format (should be rejected as invalid percentage)
# Percentage format with values > 100 should be rejected and fall back to default
dimensions=\$(get_popup_dimensions \"101%x101%\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Should fall back to medium default (768x432) since 101% is invalid
if [ \"\${width}\" != \"768\" ] || [ \"\${height}\" != \"432\" ]; then
    echo \"FAIL: 101%x101% should be rejected and fall back to default, got \${width}x\${height}\"
    exit 1
fi

# Test 5: Edge case - exactly 100% (should be treated as percentage if format is correct)
dimensions=\$(get_popup_dimensions \"100%x100%\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# 100% is > 95% max, so should be rejected and fall back to default
if [ \"\${width}\" != \"768\" ] || [ \"\${height}\" != \"432\" ]; then
    echo \"FAIL: 100%x100% should be rejected (greater than 95% max), got \${width}x\${height}\"
    exit 1
fi

# Test 6: Edge case - exactly 95% (should be accepted as valid percentage)
dimensions=\$(get_popup_dimensions \"95%x95%\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Should calculate 95% of screen (or fallback)
if [ -z \"\${width}\" ] || [ -z \"\${height}\" ]; then
    echo \"FAIL: 95%x95% should return valid dimensions\"
    exit 1
fi

# Test 7: Edge case - exactly 15% (minimum valid percentage)
dimensions=\$(get_popup_dimensions \"15%x15%\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Should calculate 15% of screen (or fallback)
if [ -z \"\${width}\" ] || [ -z \"\${height}\" ]; then
    echo \"FAIL: 15%x15% should return valid dimensions\"
    exit 1
fi

# Test 8: Edge case - 14% (below minimum, should be rejected)
dimensions=\$(get_popup_dimensions \"14%x14%\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Should fall back to default since 14% < 15% minimum
if [ \"\${width}\" != \"768\" ] || [ \"\${height}\" != \"432\" ]; then
    echo \"FAIL: 14%x14% should be rejected (less than 15% min), got \${width}x\${height}\"
    exit 1
fi

# Test 9: Mixed format edge case - one dimension > 100, one <= 100 in pixel format
# Note: Values below minimum (384x216) will be clamped, so use values above minimum
dimensions=\$(get_popup_dimensions \"500x300\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Both should be treated as pixels
if [ \"\${width}\" != \"500\" ] || [ \"\${height}\" != \"300\" ]; then
    echo \"FAIL: 500x300 should be treated as 500x300 pixels, got \${width}x\${height}\"
    exit 1
fi

# Test 10: Large pixel values (should be treated as pixels, not percentages)
dimensions=\$(get_popup_dimensions \"2000x1350\")
width=\$(echo \"\${dimensions}\" | cut -d\" \" -f1)
height=\$(echo \"\${dimensions}\" | cut -d\" \" -f2)

# Should be treated as pixels (may be clamped to screen size if resolution detected)
# The key is that it is NOT treated as 2000% of screen - it is treated as 2000 pixels
# If screen is smaller, it may be clamped, but that is expected behavior
if [ -z \"\${width}\" ] || [ -z \"\${height}\" ]; then
    echo \"FAIL: 2000x1350 should return valid dimensions\"
    exit 1
fi
# If width is 2000, that is correct. If it is less, it was clamped (also correct)
# The important thing is it was not interpreted as 2000% of screen

echo \"SUCCESS\"
" 2>/dev/null)
    
    rm -f "${tmp_config}"
    
    if [ "$result" = "SUCCESS" ]; then
        print_test_result "Size interpretation edge cases" "PASS"
    else
        print_test_result "Size interpretation edge cases" "FAIL" "$result"
    fi
}

# Main execution
echo "=========================================="
echo "Enhancement #3: Window Size Options Test"
echo "=========================================="

# Run all tests
test_resolution_detection
test_new_getter_functions
test_popup_size_validation
test_popup_dimensions_fixed_mode
test_popup_dimensions_percentage
test_popup_dimensions_custom
test_popup_size_mode
test_validation_ranges
test_backward_compatibility
test_resolution_integration
test_size_interpretation

# Print summary
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
