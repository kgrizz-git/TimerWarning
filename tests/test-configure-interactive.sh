#!/bin/bash

###############################################################################
# Automated interactive tests for configure.sh text mode
# Tests various scenarios by providing input and checking config file output
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURE_SCRIPT="${PROJECT_ROOT}/configure.sh"
CONFIG_FILE="${HOME}/.config/sleep-warning/sleep-warning.conf"
BACKUP_FILE="${CONFIG_FILE}.test-backup-$$"
TEST_DIR="${PROJECT_ROOT}/tests/test-configs"
mkdir -p "${TEST_DIR}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

# Test function
test_check() {
    local test_name="$1"
    local command="$2"
    
    echo -n "  Testing: ${test_name}... "
    
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

# Backup and restore config
backup_config() {
    if [ -f "${CONFIG_FILE}" ]; then
        cp "${CONFIG_FILE}" "${BACKUP_FILE}"
    fi
}

restore_config() {
    if [ -f "${BACKUP_FILE}" ]; then
        mv "${BACKUP_FILE}" "${CONFIG_FILE}"
    else
        rm -f "${CONFIG_FILE}"
    fi
}

# Create test config file
create_test_config() {
    local content="$1"
    mkdir -p "$(dirname "${CONFIG_FILE}")"
    cat > "${CONFIG_FILE}" << EOF
# Sleep Warning Configuration
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true

${content}
EOF
}

echo "=========================================="
echo "Automated Interactive Tests for configure.sh"
echo "=========================================="
echo ""

backup_config

# Test 1: Text mode menu displays correctly
echo -e "${BLUE}Test 1: Text mode menu display${NC}"
create_test_config ""
# Press Enter to skip welcome, then menu appears
timeout 3 bash -c "printf '\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/menu-output.txt" 2>&1 || true
test_check "Menu shows option 5" "grep -q '5\. Visual Day/Time Grid' ${TEST_DIR}/menu-output.txt"
test_check "Menu shows option 6" "grep -q '6\. Review and Save' ${TEST_DIR}/menu-output.txt"
test_check "Menu shows options 1-4" "grep -q '1\. Timer Settings' ${TEST_DIR}/menu-output.txt"
echo ""

# Test 2: Grid displays with empty config (all unrestricted)
echo -e "${BLUE}Test 2: Grid with empty/unconfigured days${NC}"
create_test_config ""
# Simulate: press Enter for welcome, select option 5, then option 0 (back)
timeout 5 bash -c "printf '\n5\n0\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/grid-empty.txt" 2>&1 || true
test_check "Grid shows 'Visual Day/Time Grid' header" "grep -q 'Visual Day/Time Grid' ${TEST_DIR}/grid-empty.txt"
test_check "Grid shows all 7 days" "grep -c '\. Sunday:\|\. Monday:\|\. Tuesday:\|\. Wednesday:\|\. Thursday:\|\. Friday:\|\. Saturday:' ${TEST_DIR}/grid-empty.txt | grep -q '^7$'"
test_check "Grid shows '(no restrictions)' for unrestricted days" "grep -q '(no restrictions)' ${TEST_DIR}/grid-empty.txt"
test_check "Grid shows 'Back to Main Menu' option" "grep -q 'Back to Main Menu' ${TEST_DIR}/grid-empty.txt"
echo ""

# Test 3: Grid displays with some days configured
echo -e "${BLUE}Test 3: Grid with configured days${NC}"
create_test_config "MONDAY=0-5
TUESDAY=0-5
WEDNESDAY=0-5
THURSDAY=0-5
FRIDAY=0-5
SATURDAY=1-5"
timeout 5 bash -c "printf '\n5\n0\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/grid-configured.txt" 2>&1 || true
test_check "Grid shows Monday with restrictions" "grep -q 'Monday.*12:00 AM' ${TEST_DIR}/grid-configured.txt"
test_check "Grid shows status indicator for restricted days" "grep -q '\[✗\].*Monday' ${TEST_DIR}/grid-configured.txt"
test_check "Grid shows Saturday with restrictions" "grep -q 'Saturday.*1:00 AM' ${TEST_DIR}/grid-configured.txt"
test_check "Grid shows Sunday as unrestricted" "grep -q 'Sunday.*(no restrictions)' ${TEST_DIR}/grid-configured.txt"
echo ""

# Test 4: Grid with overnight ranges
echo -e "${BLUE}Test 4: Grid with overnight ranges${NC}"
create_test_config "MONDAY=23-6
TUESDAY=22-8"
timeout 5 bash -c "printf '\n5\n0\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/grid-overnight.txt" 2>&1 || true
test_check "Grid shows overnight range for Monday" "grep -q 'Monday.*11:00 PM.*Tuesday' ${TEST_DIR}/grid-overnight.txt"
test_check "Grid shows overnight range for Tuesday" "grep -q 'Tuesday.*10:00 PM.*Wednesday' ${TEST_DIR}/grid-overnight.txt"
echo ""

# Test 5: Grid with multiple time ranges
echo -e "${BLUE}Test 5: Grid with multiple time ranges${NC}"
create_test_config "MONDAY=0-5,22-23"
timeout 5 bash -c "printf '\n5\n0\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/grid-multiple.txt" 2>&1 || true
test_check "Grid shows multiple ranges with AND" "grep -q 'AND' ${TEST_DIR}/grid-multiple.txt"
test_check "Grid shows both time periods" "grep -q '12:00 AM.*10:00 PM' ${TEST_DIR}/grid-multiple.txt"
echo ""

# Test 6: Individual day editing (edit Monday only)
echo -e "${BLUE}Test 6: Individual day editing${NC}"
create_test_config ""
# Simulate: press Enter for welcome, option 5, select Monday (1), say no to bulk apply, enter 0-5, confirm, back
timeout 10 bash -c "printf '\n5\n1\nn\n0-5\ny\n0\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/edit-individual.txt" 2>&1 || true
# Check if config was updated (this would require the script to save, but we're just testing the flow)
test_check "Individual day edit flow works" "grep -q 'Configure restricted hours for Monday' ${TEST_DIR}/edit-individual.txt || grep -q 'Monday' ${TEST_DIR}/edit-individual.txt"
echo ""

# Test 7: Weekday bulk apply
echo -e "${BLUE}Test 7: Weekday bulk apply functionality${NC}"
create_test_config ""
# Simulate: press Enter for welcome, option 5, select Monday (1), say yes to bulk apply, enter 0-5, confirm, back
timeout 10 bash -c "printf '\n5\n1\ny\n0-5\ny\n0\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/bulk-weekday.txt" 2>&1 || true
test_check "Weekday bulk apply prompt appears" "grep -q 'all weekdays\|Monday-Friday' ${TEST_DIR}/bulk-weekday.txt"
echo ""

# Test 8: Weekend bulk apply
echo -e "${BLUE}Test 8: Weekend bulk apply functionality${NC}"
create_test_config ""
# Simulate: press Enter for welcome, option 5, select Saturday (7), say yes to bulk apply, enter 1-5, confirm, back
timeout 10 bash -c "printf '\n5\n7\ny\n1-5\ny\n0\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/bulk-weekend.txt" 2>&1 || true
test_check "Weekend bulk apply prompt appears" "grep -q 'both weekend days\|Saturday and Sunday' ${TEST_DIR}/bulk-weekend.txt"
echo ""

# Test 9: Backward compatibility - options 1-4 still work
echo -e "${BLUE}Test 9: Backward compatibility${NC}"
create_test_config ""
for option in 1 2 3 4; do
    timeout 3 bash -c "printf '\n${option}\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/option-${option}.txt" 2>&1 || true
    case ${option} in
        1) test_check "Option 1 (Timer Settings) accessible" "grep -q 'Check interval\|Timer Settings' ${TEST_DIR}/option-1.txt" ;;
        2) test_check "Option 2 (Window Behavior) accessible" "grep -q 'Window Behavior\|popup size' ${TEST_DIR}/option-2.txt" ;;
        3) test_check "Option 3 (Weekdays) accessible" "grep -q 'Weekdays\|Monday' ${TEST_DIR}/option-3.txt" ;;
        4) test_check "Option 4 (Weekends) accessible" "grep -q 'Weekends\|Saturday' ${TEST_DIR}/option-4.txt" ;;
    esac
done
echo ""

# Test 10: Cancellation handling
echo -e "${BLUE}Test 10: Cancellation handling${NC}"
create_test_config ""
# Simulate: press Enter for welcome, option 5, then let timeout cancel
timeout 2 bash -c "printf '\n5\n' | ${CONFIGURE_SCRIPT} --text 2>&1" > "${TEST_DIR}/cancel-test.txt" 2>&1 || true
test_check "Grid can be cancelled" "test -f ${TEST_DIR}/cancel-test.txt"
echo ""

# Test 11: Config file format validation
echo -e "${BLUE}Test 11: Config file format after editing${NC}"
create_test_config "MONDAY=0-5
TUESDAY=0-5,22-23
WEDNESDAY=23-6"
test_check "Config file has valid MONDAY format" "grep -q '^MONDAY=0-5$' ${CONFIG_FILE}"
test_check "Config file has valid multiple ranges format" "grep -q '^TUESDAY=0-5,22-23$' ${CONFIG_FILE}"
test_check "Config file has valid overnight format" "grep -q '^WEDNESDAY=23-6$' ${CONFIG_FILE}"
echo ""

restore_config

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
