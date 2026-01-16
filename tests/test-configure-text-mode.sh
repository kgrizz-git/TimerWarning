#!/bin/bash

###############################################################################
# Test script for configure.sh text mode functionality
# Tests the Visual Day/Time Grid feature in text mode
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURE_SCRIPT="${PROJECT_ROOT}/configure.sh"

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

# Test 4: Menu option 5 exists in code
test_check "Menu option 5 (Visual Day/Time Grid) exists" "grep -q '5.*Visual Day/Time Grid' ${CONFIGURE_SCRIPT}"

# Test 5: show_visual_grid function exists
test_check "show_visual_grid function exists" "grep -q '^show_visual_grid()' ${CONFIGURE_SCRIPT}"

# Test 6: configure_day_from_grid function exists
test_check "configure_day_from_grid function exists" "grep -q '^configure_day_from_grid()' ${CONFIGURE_SCRIPT}"

# Test 7: Case statement handles option 5
test_check "Case statement handles option 5" "grep -A 5 '^[[:space:]]*5)' ${CONFIGURE_SCRIPT} | grep -q 'Visual Day/Time Grid'"

# Test 8: Text mode menu shows option 5
test_check "Text mode menu includes option 5" "grep -q 'echo.*5\. Visual Day/Time Grid' ${CONFIGURE_SCRIPT}"

# Test 9: Text mode grid display function exists
test_check "Text mode grid display code exists" "grep -q '=== Visual Day/Time Grid ===' ${CONFIGURE_SCRIPT}"

# Test 10: format_ranges_human function exists (used by grid)
test_check "format_ranges_human function exists" "grep -q '^format_ranges_human()' ${CONFIGURE_SCRIPT}"

# Test 11: Grid handles empty/unconfigured days
test_check "Grid handles empty days" "grep -A 10 'Day has no configuration' ${CONFIGURE_SCRIPT} | grep -q 'no restrictions'"

# Test 12: Grid shows status indicator for restricted days
test_check "Grid shows status indicator" "grep -q 'status_indicator.*✗' ${CONFIGURE_SCRIPT}"

# Test 13: Back to menu option exists in grid
test_check "Back to menu option in grid" "grep -q 'Back to Main Menu' ${CONFIGURE_SCRIPT}"

# Test 14: Grid navigation loop exists
test_check "Grid navigation loop exists" "grep -B 2 'grid_result.*show_visual_grid' ${CONFIGURE_SCRIPT} | grep -q 'while true'"

# Test 15: Weekday bulk apply prompt exists
test_check "Weekday bulk apply prompt" "grep -q 'ask_weekday_together' ${CONFIGURE_SCRIPT}"

# Test 16: Weekend bulk apply prompt exists
test_check "Weekend bulk apply prompt" "grep -q 'ask_weekend_together' ${CONFIGURE_SCRIPT}"

# Test 17: Overnight range formatting exists
test_check "Overnight range formatting" "grep -A 5 'Handle overnight ranges' ${CONFIGURE_SCRIPT} | grep -q 'overnight'"

# Test 18: Multiple time ranges support
test_check "Multiple time ranges support" "grep -q 'format_ranges_human' ${CONFIGURE_SCRIPT}"

# Test 19: Menu validation accepts 1-6
test_check "Menu validation accepts 1-6" "grep -q '1|2|3|4|5|6' ${CONFIGURE_SCRIPT}"

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
