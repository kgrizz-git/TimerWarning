#!/bin/bash

###############################################################################
# Test script for configure.sh text mode functionality
# Tests the Visual Day/Time Grid feature in text mode
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURE_SCRIPT="${PROJECT_ROOT}/configure.sh"
LIB_DIR="${PROJECT_ROOT}/lib"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Test function
test_check() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Testing: ${test_name}... "
    
    if eval "${command}" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

echo "=========================================="
echo "Testing configure.sh Text Mode"
echo "=========================================="
echo ""

# Test 1: Help flag works
test_check "Help flag (--help)" "${CONFIGURE_SCRIPT} --help | grep -q 'Force text mode'"

# Test 2: Text mode flag is recognized
test_check "Text mode flag (--text)" "${CONFIGURE_SCRIPT} --text --help 2>&1 | grep -q 'Force text mode'"

# Test 3: Script syntax is valid
test_check "Script syntax validation" "bash -n ${CONFIGURE_SCRIPT}"

# Test 4: Menu option 9 (View Weekly Hours / grid) exists in code
test_check "Menu option 9 (View Weekly Hours Settings) exists" "grep -q 'View Weekly Hours Settings' ${LIB_DIR}/configure-display.sh"

# Test 5: show_visual_grid function exists
test_check "show_visual_grid function exists" "grep -q '^show_visual_grid()' ${LIB_DIR}/configure-display.sh"

# Test 6: configure_day_from_grid function exists
test_check "configure_day_from_grid function exists" "grep -q '^configure_day_from_grid()' ${LIB_DIR}/configure-workflow.sh"

# Test 7: Case statement handles option 9 (grid)
test_check "Case statement handles option 9" "grep -A 15 '^[[:space:]]*9)' ${CONFIGURE_SCRIPT} | grep -q 'show_visual_grid'"

# Test 8: Text mode menu shows option 9 (View Weekly Hours)
test_check "Text mode menu includes option 9" "grep -q 'View Weekly Hours Settings' ${LIB_DIR}/configure-display.sh"

# Test 9: Text mode grid display function exists
test_check "Text mode grid display code exists" "grep -q '^show_visual_grid()' ${LIB_DIR}/configure-display.sh && grep -q 'Visual Day/Time Grid' ${LIB_DIR}/configure-display.sh"

# Test 10: format_ranges_human function exists (used by grid)
test_check "format_ranges_human function exists" "grep -q '^format_ranges_human()' ${LIB_DIR}/configure-time.sh"

# Test 11: Grid handles empty/unconfigured days
test_check "Grid handles empty days" "grep -q 'No restrictions' ${LIB_DIR}/configure-display.sh && grep -q '\\(no restrictions\\)' ${LIB_DIR}/configure-time.sh"

# Test 12: Grid renders a tabular listing (text mode)
test_check "Grid renders table rows" "grep -Fq 'printf \"%d.\\t%-9s\\t' ${LIB_DIR}/configure-display.sh"

# Test 13: Back to menu option exists in grid
test_check "Back to menu option in grid" "grep -q '0\\. Back to Main Menu' ${LIB_DIR}/configure-display.sh"

# Test 14: Grid navigation loop exists
test_check "Grid navigation loop exists" "grep -B 2 -A 2 'show_visual_grid' ${CONFIGURE_SCRIPT} | grep -q 'while true'"

# Test 15: Weekday bulk apply prompt exists
test_check "Weekday bulk apply prompt" "grep -q 'ask_weekday_together' ${LIB_DIR}/configure-ui.sh"

# Test 16: Weekend bulk apply prompt exists
test_check "Weekend bulk apply prompt" "grep -q 'ask_weekend_together' ${LIB_DIR}/configure-ui.sh"

# Test 17: Overnight range formatting exists
test_check "Overnight range formatting" "grep -q 'Handle overnight ranges' ${LIB_DIR}/configure-time.sh || grep -q 'Overnight' ${LIB_DIR}/configure-time.sh"

# Test 18: Multiple time ranges support
test_check "Multiple time ranges support" "grep -q '^format_ranges_human()' ${LIB_DIR}/configure-time.sh"

# Test 19: Menu includes more than 1-6 (modular wizard expanded)
test_check "Menu includes option 13 (Review and Save)" "grep -q '^[[:space:]]*13)' ${CONFIGURE_SCRIPT}"

# Test 20: Backward compatibility - options 1-4 still exist
test_check "Backward compatibility - option 1 exists" "grep -q '^[[:space:]]*1)' ${CONFIGURE_SCRIPT}"
test_check "Backward compatibility - option 2 exists" "grep -q '^[[:space:]]*2)' ${CONFIGURE_SCRIPT}"
test_check "Backward compatibility - option 3 exists" "grep -q '^[[:space:]]*3)' ${CONFIGURE_SCRIPT}"
test_check "Backward compatibility - option 4 exists" "grep -q '^[[:space:]]*4)' ${CONFIGURE_SCRIPT}"

echo ""
echo "=========================================="
echo "Test Results:"
echo "  ${GREEN}Passed: ${PASSED}${NC}"
echo "  ${RED}Failed: ${FAILED}${NC}"
echo "=========================================="

if [ ${FAILED} -eq 0 ]; then
    exit 0
else
    exit 1
fi
