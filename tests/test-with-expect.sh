#!/bin/bash

###############################################################################
# Test runner using expect for interactive testing
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURE_SCRIPT="${PROJECT_ROOT}/configure.sh"
EXPECT_SCRIPT="${SCRIPT_DIR}/test-configure-expect.exp"
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

# Check if expect is available
if ! command -v expect >/dev/null 2>&1; then
    echo -e "${RED}Error: expect is not installed${NC}"
    echo "Install with: sudo apt install expect (Ubuntu/Debian) or sudo pacman -S expect (Arch)"
    exit 1
fi

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

# Test function
run_expect_test() {
    local test_name="$1"
    local config_content="$2"
    local description="$3"
    
    echo -n "  Testing: ${description}... "
    
    if [ -n "${config_content}" ]; then
        create_test_config "${config_content}"
    else
        create_test_config ""
    fi
    
    # Run expect and capture output
    local expect_output
    expect_output=$(expect "${EXPECT_SCRIPT}" "${CONFIGURE_SCRIPT}" "${test_name}" "" 2>&1)
    local expect_exit=$?
    
    # Check for explicit PASS/ERROR messages
    if echo "${expect_output}" | grep -q "PASS"; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    elif echo "${expect_output}" | grep -q "ERROR"; then
        echo -e "${RED}FAIL${NC}"
        echo "    Details: $(echo "${expect_output}" | grep "ERROR" | head -1)"
        ((FAILED++))
        return 1
    elif [ ${expect_exit} -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "    Exit code: ${expect_exit}"
        ((FAILED++))
        return 1
    fi
}

echo "=========================================="
echo "Automated Interactive Tests with expect"
echo "=========================================="
echo ""

backup_config

# Test 1: Menu display
echo -e "${BLUE}Test 1: Text mode menu display${NC}"
run_expect_test "menu_display" "" "Menu shows all options"
echo ""

# Test 2: Grid with empty config
echo -e "${BLUE}Test 2: Grid with empty/unconfigured days${NC}"
run_expect_test "grid_display" "" "Grid displays with empty config"
echo ""

# Test 3: Grid with configured days
echo -e "${BLUE}Test 3: Grid with configured days${NC}"
CONFIG3="MONDAY=0-5
TUESDAY=0-5
WEDNESDAY=0-5
THURSDAY=0-5
FRIDAY=0-5
SATURDAY=1-5"
run_expect_test "grid_configured_days" "${CONFIG3}" "Grid shows configured days with restrictions"
echo ""

# Test 4: Grid with overnight ranges
echo -e "${BLUE}Test 4: Grid with overnight ranges${NC}"
CONFIG4="MONDAY=23-6
TUESDAY=22-8"
run_expect_test "grid_overnight" "${CONFIG4}" "Grid shows overnight ranges correctly"
echo ""

# Test 5: Grid with multiple time ranges
echo -e "${BLUE}Test 5: Grid with multiple time ranges${NC}"
run_expect_test "grid_multiple_ranges" "MONDAY=0-5,22-23" "Grid shows multiple ranges with AND"
echo ""

# Test 6: Individual day editing
echo -e "${BLUE}Test 6: Individual day editing${NC}"
run_expect_test "individual_day_edit" "" "Individual day editing works"
echo ""

# Test 7: Weekday bulk apply
echo -e "${BLUE}Test 7: Weekday bulk apply functionality${NC}"
run_expect_test "weekday_bulk_apply" "" "Weekday bulk apply prompt appears"
echo ""

# Test 8: Weekend bulk apply
echo -e "${BLUE}Test 8: Weekend bulk apply functionality${NC}"
run_expect_test "weekend_bulk_apply" "" "Weekend bulk apply prompt appears"
echo ""

# Test 9: Backward compatibility
echo -e "${BLUE}Test 9: Backward compatibility${NC}"
run_expect_test "backward_compat" "" "Options 1-4 still accessible"
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
