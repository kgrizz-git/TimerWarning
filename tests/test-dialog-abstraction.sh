#!/bin/bash

###############################################################################
# Test Script for Dialog Abstraction Layer
#
# This script tests all dialog abstraction functions by displaying actual
# dialogs that you can verify visually. It will show dialogs one by one
# so you can confirm they look correct.
#
# Usage:
#   ./tests/test-dialog-abstraction.sh
###############################################################################

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required modules
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/display-detection.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/configure-dialogs.sh" || exit 1

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Check if we have a dialog tool
check_dialog_available() {
    if ! has_dialog_tool; then
        echo -e "${YELLOW}WARNING: No dialog tool available. Cannot run GUI tests.${NC}"
        echo "Please install yad, zenity, or kdialog to test dialogs."
        exit 1
    fi
    
    local tool
    tool=$(get_dialog_tool)
    echo -e "${BLUE}Using dialog tool: ${tool}${NC}"
    echo ""
}

# Test info dialog
test_info_dialog() {
    echo -e "${GREEN}Test 1: Information Dialog${NC}"
    echo "This should show an information dialog with title 'Test Info' and a message."
    echo "Press OK to continue..."
    echo ""
    
    if show_info_dialog "Test Info" "This is a test information dialog.\n\nIt should display correctly with the current dialog tool." 500 200; then
        echo -e "${GREEN}✓ Info dialog displayed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}✗ Info dialog failed or was cancelled${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test question dialog
test_question_dialog() {
    echo -e "${GREEN}Test 2: Question Dialog${NC}"
    echo "This should show a yes/no question dialog."
    echo "Try both Yes and No to verify it works correctly."
    echo ""
    
    if show_question_dialog "Test Question" "Do you want to continue testing?\n\nThis tests the question dialog functionality." "Yes, Continue" "No, Skip"; then
        echo -e "${GREEN}✓ Question dialog: User selected Yes${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${GREEN}✓ Question dialog: User selected No (this is expected)${NC}"
        ((TESTS_PASSED++))
    fi
    echo ""
}

# Test entry dialog
test_entry_dialog() {
    echo -e "${GREEN}Test 3: Entry Dialog${NC}"
    echo "This should show a text entry dialog with a default value."
    echo "Try entering text and also try cancelling."
    echo ""
    
    local result
    result=$(show_entry_dialog "Test Entry" "Please enter some text:" "default value")
    local exit_code=$?
    
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        echo -e "${GREEN}✓ Entry dialog: User entered: '${result}'${NC}"
        ((TESTS_PASSED++))
    elif [ ${exit_code} -ne 0 ]; then
        echo -e "${GREEN}✓ Entry dialog: User cancelled (this is expected)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}✗ Entry dialog: Unexpected result${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test single-column list dialog
test_list_dialog() {
    echo -e "${GREEN}Test 4: Single-Column List Dialog${NC}"
    echo "This should show a list with options: small, medium, large"
    echo "Select one option to continue."
    echo ""
    
    local result
    result=$(show_list_dialog "Test List" "Select an option:" 400 250 "small" "medium" "large")
    local exit_code=$?
    
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        echo -e "${GREEN}✓ List dialog: User selected: '${result}'${NC}"
        ((TESTS_PASSED++))
    elif [ ${exit_code} -ne 0 ]; then
        echo -e "${GREEN}✓ List dialog: User cancelled (this is expected)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}✗ List dialog: Unexpected result${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test multi-column list dialog
test_multi_column_list_dialog() {
    echo -e "${GREEN}Test 5: Multi-Column List Dialog${NC}"
    echo "This should show a 2-column list with Option and Description columns."
    echo "Select one option to continue."
    echo ""
    
    local result
    result=$(show_multi_column_list_dialog \
        "Test Multi-Column List" \
        "Select an option:" \
        500 \
        300 \
        1 \
        "Option" \
        "Description" \
        "1" "First option with description" \
        "2" "Second option with description" \
        "3" "Third option with description")
    local exit_code=$?
    
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        echo -e "${GREEN}✓ Multi-column list dialog: User selected: '${result}'${NC}"
        ((TESTS_PASSED++))
    elif [ ${exit_code} -ne 0 ]; then
        echo -e "${GREEN}✓ Multi-column list dialog: User cancelled (this is expected)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}✗ Multi-column list dialog: Unexpected result${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test text info dialog
test_text_info_dialog() {
    echo -e "${GREEN}Test 6: Text Info Dialog${NC}"
    echo "This should show a text information dialog with formatted text."
    echo "Press Close to continue."
    echo ""
    
    local text_content="This is a test of the text info dialog.

It should display:
- Multiple lines
- Formatted text
- Scrollable content if needed

This dialog is used for help text and other long-form information."
    
    if show_text_info_dialog "Test Text Info" "${text_content}" 600 400; then
        echo -e "${GREEN}✓ Text info dialog displayed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}✗ Text info dialog failed or was cancelled${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Main test execution
main() {
    echo "=========================================="
    echo "Dialog Abstraction Layer Visual Tests"
    echo "=========================================="
    echo ""
    
    check_dialog_available
    
    echo "This script will show dialogs one by one."
    echo "Please verify each dialog looks correct and functions properly."
    echo ""
    read -p "Press Enter to start testing..."
    echo ""
    
    # Run tests
    test_info_dialog
    read -p "Press Enter to continue to next test..."
    echo ""
    
    test_question_dialog
    read -p "Press Enter to continue to next test..."
    echo ""
    
    test_entry_dialog
    read -p "Press Enter to continue to next test..."
    echo ""
    
    test_list_dialog
    read -p "Press Enter to continue to next test..."
    echo ""
    
    test_multi_column_list_dialog
    read -p "Press Enter to continue to next test..."
    echo ""
    
    test_text_info_dialog
    
    # Summary
    echo "=========================================="
    echo "Test Summary:"
    echo "  Passed: ${TESTS_PASSED}"
    echo "  Failed: ${TESTS_FAILED}"
    echo "=========================================="
    echo ""
    echo "Please verify:"
    echo "  1. All dialogs displayed correctly"
    echo "  2. Dialog titles and text were readable"
    echo "  3. Buttons worked correctly"
    echo "  4. Multi-column list showed both columns"
    echo "  5. Text info dialog was scrollable (if needed)"
    echo ""
    
    if [ "${TESTS_FAILED}" -eq 0 ]; then
        echo -e "${GREEN}All tests completed!${NC}"
        exit 0
    else
        echo -e "${YELLOW}Some tests had issues.${NC}"
        exit 1
    fi
}

# Run tests
main "$@"
