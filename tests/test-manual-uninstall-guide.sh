#!/bin/bash

###############################################################################
# Test script for manual-uninstall-guide.sh
#
# This script tests the manual uninstall guide verification logic
# without requiring user interaction.
###############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_check() {
    local test_name="$1"
    local condition="$2"
    
    if eval "$condition"; then
        echo -e "${GREEN}✓${NC} ${test_name}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} ${test_name}"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "Testing manual-uninstall-guide.sh..."
echo ""

# Test 1: Script exists and is executable
test_check "Script exists and is executable" \
    "[ -f ../manual-uninstall-guide.sh ] && [ -x ../manual-uninstall-guide.sh ]"

# Test 2: Script has correct shebang
test_check "Script has correct shebang" \
    "head -n1 ../manual-uninstall-guide.sh | grep -q '^#!/bin/bash'"

# Test 3: Script sources required libraries
test_check "Script sources desktop-environment.sh" \
    "grep -q 'source.*desktop-environment.sh' ../manual-uninstall-guide.sh"

test_check "Script sources configure-core.sh" \
    "grep -q 'source.*configure-core.sh' ../manual-uninstall-guide.sh"

test_check "Script sources configure-dialogs.sh" \
    "grep -q 'source.*configure-dialogs.sh' ../manual-uninstall-guide.sh"

test_check "Script sources uninstall-verification.sh" \
    "grep -q 'source.*uninstall-verification.sh' ../manual-uninstall-guide.sh"

# Test 4: Verification functions are defined
test_check "get_manual_uninstall_confirmation_phrase function exists" \
    "grep -q '^get_manual_uninstall_confirmation_phrase()' ../manual-uninstall-guide.sh"

test_check "verify_manual_uninstall_confirmation_phrase function exists" \
    "grep -q '^verify_manual_uninstall_confirmation_phrase()' ../manual-uninstall-guide.sh"

test_check "ask_manual_uninstall_arithmetic_questions function exists" \
    "grep -q '^ask_manual_uninstall_arithmetic_questions()' ../manual-uninstall-guide.sh"

test_check "verify_before_showing_instructions function exists" \
    "grep -q '^verify_before_showing_instructions()' ../manual-uninstall-guide.sh"

# Test 5: Confirmation phrase is correct
test_check "Confirmation phrase matches requirement" \
    "grep -q 'I confirm that I really want to know how to uninstall' ../manual-uninstall-guide.sh"

# Test 6: Initial confirmation dialog is present
test_check "Initial confirmation dialog is implemented" \
    "grep -q 'Are you sure you want to know how to uninstall' ../manual-uninstall-guide.sh"

# Test 7: Arithmetic questions are implemented (10 questions, 5 wrong answers allowed)
test_check "Arithmetic questions use 10 questions" \
    "grep -q 'total_questions=10' ../manual-uninstall-guide.sh"

test_check "Arithmetic questions allow 5 wrong answers total" \
    "grep -q 'max_wrong_answers=5' ../manual-uninstall-guide.sh"

test_check "Wrong answers count is tracked" \
    "grep -q 'wrong_answers_count' ../manual-uninstall-guide.sh"

# Test 8: GUI step-by-step display is implemented
test_check "GUI step-by-step display function exists" \
    "grep -q '^show_gui_step()' ../manual-uninstall-guide.sh"

test_check "GUI instructions show steps one at a time" \
    "grep -q 'show_gui_step' ../manual-uninstall-guide.sh"

# Test 9: Text step-by-step display is implemented
test_check "Text step-by-step display function exists" \
    "grep -q '^show_text_step()' ../manual-uninstall-guide.sh"

test_check "Text instructions clear screen between steps" \
    "grep -q '^[[:space:]]*clear$' ../manual-uninstall-guide.sh"

# Test 10: Script handles missing libraries gracefully
test_check "Script uses error suppression when sourcing libraries" \
    "grep -q '2>/dev/null || true' ../manual-uninstall-guide.sh"

# Test 11: All 5 steps are defined
test_check "Step 1 (Stop and Disable Timer) is defined" \
    "grep -q 'Stop and Disable Timer' ../manual-uninstall-guide.sh"

test_check "Step 2 (Remove Systemd Files) is defined" \
    "grep -q 'Remove Systemd Files' ../manual-uninstall-guide.sh"

test_check "Step 3 (Remove Scripts) is defined" \
    "grep -q 'Remove Scripts' ../manual-uninstall-guide.sh"

test_check "Step 4 (Remove Configuration) is defined" \
    "grep -q 'Remove Configuration' ../manual-uninstall-guide.sh"

test_check "Step 5 (Reload Systemd) is defined" \
    "grep -q 'Reload Systemd' ../manual-uninstall-guide.sh"

# Test 12: Script syntax is valid
test_check "Script has valid bash syntax" \
    "bash -n ../manual-uninstall-guide.sh 2>&1 | wc -l | grep -q '^0$'"

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Passed: ${TESTS_PASSED}"
echo "  Failed: ${TESTS_FAILED}"
echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo "=========================================="

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
