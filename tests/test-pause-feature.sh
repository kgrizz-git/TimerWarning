#!/bin/bash

###############################################################################
# Sleep Warning System - Pause Feature Test Suite
#
# This script tests the one-time pause feature (Enhancement #21) to ensure:
# - Pause state file creation and reading
# - Pause activation with 5 and 10 minute durations
# - Pause expiration and auto-clearing
# - Once-per-day limit enforcement (always enforced)
# - Edge cases (corrupted files, missing files, invalid format)
#
# Usage: ./tests/test-pause-feature.sh
###############################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEST_CONFIG_DIR="${SCRIPT_DIR}/tests/test-pause-config"
TEST_PAUSE_STATE_FILE="${TEST_CONFIG_DIR}/.pause_state"
TEST_CONFIG_FILE="${TEST_CONFIG_DIR}/sleep-warning.conf"

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

# Cleanup function
cleanup() {
    # Restore original config if it exists
    if [ -f "${TEST_CONFIG_FILE}.backup" ]; then
        mv "${TEST_CONFIG_FILE}.backup" "${TEST_CONFIG_FILE}" 2>/dev/null || true
    fi
    
    # Remove test config directory
    rm -rf "${TEST_CONFIG_DIR}" 2>/dev/null || true
    
    # Restore original pause state file if backup exists
    if [ -n "${ORIGINAL_PAUSE_STATE_FILE}" ] && [ -f "${ORIGINAL_PAUSE_STATE_FILE}.backup" ]; then
        mv "${ORIGINAL_PAUSE_STATE_FILE}.backup" "${ORIGINAL_PAUSE_STATE_FILE}" 2>/dev/null || true
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

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
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Setup test environment
setup_test_env() {
    print_section "Setting Up Test Environment"
    
    # Create test config directory
    mkdir -p "${TEST_CONFIG_DIR}"
    
    # Backup original config if it exists
    if [ -f "${TEST_CONFIG_FILE}" ]; then
        cp "${TEST_CONFIG_FILE}" "${TEST_CONFIG_FILE}.backup"
    fi
    
    # Create minimal test config file
    cat > "${TEST_CONFIG_FILE}" <<EOF
# Test Configuration
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true
CONFIGURE_BLOCK_ENABLED=false
UNINSTALL_PROTECTION_MODE=none
PAUSE_ENABLED=true
PAUSE_DURATION=5
EOF
    
    # Source lib modules (must set CONFIG_DIR before sourcing)
    export CONFIG_DIR="${TEST_CONFIG_DIR}"
    
    # Source config.sh first (it will set CONFIG_FILE and PAUSE_STATE_FILE based on CONFIG_DIR)
    source "${LIB_DIR}/config.sh" || { echo "Error: Failed to source config.sh"; exit 1; }
    
    # Override CONFIG_FILE and PAUSE_STATE_FILE to use test locations
    export CONFIG_FILE="${TEST_CONFIG_FILE}"
    export PAUSE_STATE_FILE="${TEST_PAUSE_STATE_FILE}"
    
    # Source remaining modules
    source "${LIB_DIR}/logging.sh" || { echo "Error: Failed to source logging.sh"; exit 1; }
    source "${LIB_DIR}/pause-state.sh" || { echo "Error: Failed to source pause-state.sh"; exit 1; }
    
    echo -e "${GREEN}Test environment set up successfully${NC}"
}

# Test 1: Pause state file creation
test_pause_state_file_creation() {
    print_section "Test 1: Pause State File Creation"
    
    # Clean up any existing state file
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Activate pause for 5 minutes
    if activate_pause 5; then
        if [ -f "${TEST_PAUSE_STATE_FILE}" ]; then
            print_test_result "Pause state file created" "PASS"
        else
            print_test_result "Pause state file created" "FAIL"
            return 1
        fi
        
        # Check file permissions (should be 0600)
        local perms
        perms=$(stat -c "%a" "${TEST_PAUSE_STATE_FILE}" 2>/dev/null || stat -f "%OLp" "${TEST_PAUSE_STATE_FILE}" 2>/dev/null || echo "unknown")
        if [ "${perms}" = "600" ] || [ "${perms}" = "0600" ]; then
            print_test_result "Pause state file has correct permissions (0600)" "PASS"
        else
            print_test_result "Pause state file has correct permissions (0600)" "FAIL"
            echo "  Expected: 600 or 0600, Got: ${perms}"
        fi
        
        # Check file content format
        if grep -qE "^PAUSE_END_TIMESTAMP=[0-9]+$" "${TEST_PAUSE_STATE_FILE}" && \
           grep -qE "^LAST_PAUSE_DATE=[0-9]{4}-[0-9]{2}-[0-9]{2}$" "${TEST_PAUSE_STATE_FILE}"; then
            print_test_result "Pause state file has correct format" "PASS"
        else
            print_test_result "Pause state file has correct format" "FAIL"
            echo "  File content:"
            cat "${TEST_PAUSE_STATE_FILE}" | sed 's/^/    /'
        fi
    else
        print_test_result "Pause activation succeeded" "FAIL"
        return 1
    fi
    
    # Clean up
    rm -f "${TEST_PAUSE_STATE_FILE}"
}

# Test 2: Pause state file reading
test_pause_state_file_reading() {
    print_section "Test 2: Pause State File Reading"
    
    # Clean up any existing state file
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Activate pause
    activate_pause 5
    
    # Test get_pause_end_timestamp
    local end_timestamp
    end_timestamp=$(get_pause_end_timestamp)
    if [ -n "${end_timestamp}" ] && [[ "${end_timestamp}" =~ ^[0-9]+$ ]]; then
        print_test_result "get_pause_end_timestamp returns valid timestamp" "PASS"
    else
        print_test_result "get_pause_end_timestamp returns valid timestamp" "FAIL"
        echo "  Got: ${end_timestamp}"
    fi
    
    # Test get_last_pause_date
    local last_date
    last_date=$(get_last_pause_date)
    local today
    today=$(date +%Y-%m-%d)
    if [ -n "${last_date}" ] && [[ "${last_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [ "${last_date}" = "${today}" ]; then
        print_test_result "get_last_pause_date returns today's date" "PASS"
    else
        print_test_result "get_last_pause_date returns today's date" "FAIL"
        echo "  Expected: ${today}, Got: ${last_date}"
    fi
    
    # Clean up
    rm -f "${TEST_PAUSE_STATE_FILE}"
}

# Test 3: Pause activation with different durations
test_pause_activation_durations() {
    print_section "Test 3: Pause Activation with Different Durations"
    
    # Clean up any existing state file
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Test 5 minute pause
    local current_time
    current_time=$(date +%s)
    if activate_pause 5; then
        local end_timestamp
        end_timestamp=$(get_pause_end_timestamp)
        local expected_end=$((current_time + 300))  # 5 minutes = 300 seconds
        local diff=$((end_timestamp - expected_end))
        if [ ${diff} -ge -5 ] && [ ${diff} -le 5 ]; then  # Allow 5 second tolerance
            print_test_result "5 minute pause sets correct end timestamp" "PASS"
        else
            print_test_result "5 minute pause sets correct end timestamp" "FAIL"
            echo "  Expected: ~${expected_end}, Got: ${end_timestamp}, Diff: ${diff}"
        fi
    else
        print_test_result "5 minute pause activation" "FAIL"
    fi
    
    # Clean up
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Test 10 minute pause
    current_time=$(date +%s)
    if activate_pause 10; then
        local end_timestamp
        end_timestamp=$(get_pause_end_timestamp)
        local expected_end=$((current_time + 600))  # 10 minutes = 600 seconds
        local diff=$((end_timestamp - expected_end))
        if [ ${diff} -ge -5 ] && [ ${diff} -le 5 ]; then  # Allow 5 second tolerance
            print_test_result "10 minute pause sets correct end timestamp" "PASS"
        else
            print_test_result "10 minute pause sets correct end timestamp" "FAIL"
            echo "  Expected: ~${expected_end}, Got: ${end_timestamp}, Diff: ${diff}"
        fi
    else
        print_test_result "10 minute pause activation" "FAIL"
    fi
    
    # Test invalid duration
    if activate_pause 15 2>/dev/null; then
        print_test_result "Invalid duration (15 min) is rejected" "FAIL"
    else
        print_test_result "Invalid duration (15 min) is rejected" "PASS"
    fi
    
    # Clean up
    rm -f "${TEST_PAUSE_STATE_FILE}"
}

# Test 4: is_pause_active function
test_is_pause_active() {
    print_section "Test 4: is_pause_active Function"
    
    # Clean up any existing state file
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Test when no pause is active
    if is_pause_active; then
        print_test_result "is_pause_active returns false when no pause" "FAIL"
    else
        print_test_result "is_pause_active returns false when no pause" "PASS"
    fi
    
    # Activate pause for 5 minutes
    activate_pause 5
    
    # Test when pause is active
    if is_pause_active; then
        print_test_result "is_pause_active returns true when pause is active" "PASS"
    else
        print_test_result "is_pause_active returns true when pause is active" "FAIL"
    fi
    
    # Create expired pause (set timestamp to past)
    local past_timestamp
    past_timestamp=$(( $(date +%s) - 3600 ))  # 1 hour ago
    echo "PAUSE_END_TIMESTAMP=${past_timestamp}" > "${TEST_PAUSE_STATE_FILE}"
    echo "LAST_PAUSE_DATE=$(date +%Y-%m-%d)" >> "${TEST_PAUSE_STATE_FILE}"
    
    # Test when pause is expired
    if is_pause_active; then
        print_test_result "is_pause_active returns false when pause is expired" "FAIL"
    else
        print_test_result "is_pause_active returns false when pause is expired" "PASS"
    fi
    
    # Clean up
    rm -f "${TEST_PAUSE_STATE_FILE}"
}

# Test 5: can_pause_today function
test_can_pause_today() {
    print_section "Test 5: can_pause_today Function"
    
    # Clean up any existing state file
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Test when pause is enabled and not used today
    if can_pause_today; then
        print_test_result "can_pause_today returns true when pause available" "PASS"
    else
        print_test_result "can_pause_today returns true when pause available" "FAIL"
    fi
    
    # Activate pause
    activate_pause 5
    
    # Test when pause already used today (once-per-day limit enforced)
    if can_pause_today; then
        print_test_result "can_pause_today returns false when already used today" "FAIL"
    else
        print_test_result "can_pause_today returns false when already used today" "PASS"
    fi
    
    # Test with yesterday's date (should allow pause)
    local yesterday
    yesterday=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "")
    if [ -n "${yesterday}" ]; then
        echo "PAUSE_END_TIMESTAMP=$(( $(date +%s) - 3600 ))" > "${TEST_PAUSE_STATE_FILE}"
        echo "LAST_PAUSE_DATE=${yesterday}" >> "${TEST_PAUSE_STATE_FILE}"
        
        if can_pause_today; then
            print_test_result "can_pause_today returns true when last pause was yesterday" "PASS"
        else
            print_test_result "can_pause_today returns true when last pause was yesterday" "FAIL"
        fi
    fi
    
    # Test when pause is disabled
    # Replace PAUSE_ENABLED in config file
    sed -i 's/^PAUSE_ENABLED=.*/PAUSE_ENABLED=false/' "${TEST_CONFIG_FILE}"
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Verify config was updated
    local pause_enabled_in_file
    pause_enabled_in_file=$(grep -E "^[[:space:]]*PAUSE_ENABLED=" "${TEST_CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    # Test can_pause_today (should return false when pause disabled)
    # Note: This test verifies that can_pause_today respects the pause_enabled setting
    # If the config file update worked, can_pause_today should return false
    if [ "${pause_enabled_in_file}" = "false" ]; then
        if can_pause_today; then
            print_test_result "can_pause_today returns false when pause disabled" "FAIL"
            echo "  Config file has PAUSE_ENABLED=false, but can_pause_today returned true"
            echo "  get_pause_enabled returned: $(get_pause_enabled)"
        else
            print_test_result "can_pause_today returns false when pause disabled" "PASS"
        fi
    else
        # Config update didn't work - this is a test setup issue
        print_test_result "can_pause_today returns false when pause disabled" "SKIP"
        echo "  Note: Config file update failed (PAUSE_ENABLED=${pause_enabled_in_file})"
    fi
    
    # Restore config
    sed -i 's/^PAUSE_ENABLED=.*/PAUSE_ENABLED=true/' "${TEST_CONFIG_FILE}"
    
    # Clean up
    rm -f "${TEST_PAUSE_STATE_FILE}"
}

# Test 6: check_and_clear_expired_pause function
test_clear_expired_pause() {
    print_section "Test 6: check_and_clear_expired_pause Function"
    
    # Clean up any existing state file
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Create expired pause
    local past_timestamp
    past_timestamp=$(( $(date +%s) - 3600 ))  # 1 hour ago
    local today
    today=$(date +%Y-%m-%d)
    echo "PAUSE_END_TIMESTAMP=${past_timestamp}" > "${TEST_PAUSE_STATE_FILE}"
    echo "LAST_PAUSE_DATE=${today}" >> "${TEST_PAUSE_STATE_FILE}"
    
    # Check and clear expired pause
    check_and_clear_expired_pause
    
    # Verify file still exists but only contains LAST_PAUSE_DATE (PAUSE_END_TIMESTAMP cleared)
    if [ -f "${TEST_PAUSE_STATE_FILE}" ]; then
        if grep -qE "^LAST_PAUSE_DATE=${today}$" "${TEST_PAUSE_STATE_FILE}" && \
           ! grep -qE "^PAUSE_END_TIMESTAMP=" "${TEST_PAUSE_STATE_FILE}"; then
            print_test_result "check_and_clear_expired_pause clears expired pause (keeps LAST_PAUSE_DATE)" "PASS"
        else
            print_test_result "check_and_clear_expired_pause clears expired pause (keeps LAST_PAUSE_DATE)" "FAIL"
            echo "  File content:"
            cat "${TEST_PAUSE_STATE_FILE}" | sed 's/^/    /'
        fi
    else
        print_test_result "check_and_clear_expired_pause clears expired pause (keeps LAST_PAUSE_DATE)" "FAIL"
        echo "  File was completely removed (should keep LAST_PAUSE_DATE)"
    fi
    
    # Test with active pause (should not clear)
    activate_pause 5
    check_and_clear_expired_pause
    
    if [ -f "${TEST_PAUSE_STATE_FILE}" ]; then
        print_test_result "check_and_clear_expired_pause preserves active pause" "PASS"
    else
        print_test_result "check_and_clear_expired_pause preserves active pause" "FAIL"
    fi
    
    # Clean up
    rm -f "${TEST_PAUSE_STATE_FILE}"
}

# Test 7: Edge cases - corrupted pause state file
test_corrupted_pause_state_file() {
    print_section "Test 7: Edge Cases - Corrupted Pause State File"
    
    # Test with invalid timestamp format
    echo "PAUSE_END_TIMESTAMP=invalid" > "${TEST_PAUSE_STATE_FILE}"
    echo "LAST_PAUSE_DATE=$(date +%Y-%m-%d)" >> "${TEST_PAUSE_STATE_FILE}"
    
    local end_timestamp
    end_timestamp=$(get_pause_end_timestamp)
    if [ -z "${end_timestamp}" ]; then
        print_test_result "get_pause_end_timestamp handles invalid timestamp" "PASS"
    else
        print_test_result "get_pause_end_timestamp handles invalid timestamp" "FAIL"
    fi
    
    if is_pause_active; then
        print_test_result "is_pause_active handles invalid timestamp" "FAIL"
    else
        print_test_result "is_pause_active handles invalid timestamp" "PASS"
    fi
    
    # Test with invalid date format
    echo "PAUSE_END_TIMESTAMP=$(date +%s)" > "${TEST_PAUSE_STATE_FILE}"
    echo "LAST_PAUSE_DATE=invalid-date" >> "${TEST_PAUSE_STATE_FILE}"
    
    local last_date
    last_date=$(get_last_pause_date)
    if [ -z "${last_date}" ]; then
        print_test_result "get_last_pause_date handles invalid date format" "PASS"
    else
        print_test_result "get_last_pause_date handles invalid date format" "FAIL"
    fi
    
    # Clean up
    rm -f "${TEST_PAUSE_STATE_FILE}"
}

# Test 8: Edge cases - missing pause state file
test_missing_pause_state_file() {
    print_section "Test 8: Edge Cases - Missing Pause State File"
    
    # Ensure file doesn't exist
    rm -f "${TEST_PAUSE_STATE_FILE}"
    
    # Test functions with missing file
    local end_timestamp
    end_timestamp=$(get_pause_end_timestamp)
    if [ -z "${end_timestamp}" ]; then
        print_test_result "get_pause_end_timestamp handles missing file" "PASS"
    else
        print_test_result "get_pause_end_timestamp handles missing file" "FAIL"
    fi
    
    local last_date
    last_date=$(get_last_pause_date)
    if [ -z "${last_date}" ]; then
        print_test_result "get_last_pause_date handles missing file" "PASS"
    else
        print_test_result "get_last_pause_date handles missing file" "FAIL"
    fi
    
    if is_pause_active; then
        print_test_result "is_pause_active handles missing file" "FAIL"
    else
        print_test_result "is_pause_active handles missing file" "PASS"
    fi
    
    if can_pause_today; then
        print_test_result "can_pause_today handles missing file (allows pause)" "PASS"
    else
        print_test_result "can_pause_today handles missing file (allows pause)" "FAIL"
    fi
}

# Test 9: clear_pause_state function
test_clear_pause_state() {
    print_section "Test 9: clear_pause_state Function"
    
    # Activate pause
    activate_pause 5
    
    # Verify file exists
    if [ -f "${TEST_PAUSE_STATE_FILE}" ]; then
        print_test_result "Pause state file exists before clear" "PASS"
    else
        print_test_result "Pause state file exists before clear" "FAIL"
        return 1
    fi
    
    # Clear pause state
    clear_pause_state
    
    # Verify file is removed
    if [ ! -f "${TEST_PAUSE_STATE_FILE}" ]; then
        print_test_result "clear_pause_state removes state file" "PASS"
    else
        print_test_result "clear_pause_state removes state file" "FAIL"
    fi
    
    # Test clearing when file doesn't exist (should not error)
    if clear_pause_state; then
        print_test_result "clear_pause_state handles missing file gracefully" "PASS"
    else
        print_test_result "clear_pause_state handles missing file gracefully" "FAIL"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Sleep Warning System - Pause Feature Test Suite${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Setup test environment
    setup_test_env
    
    # Run tests
    test_pause_state_file_creation
    test_pause_state_file_reading
    test_pause_activation_durations
    test_is_pause_active
    test_can_pause_today
    test_clear_expired_pause
    test_corrupted_pause_state_file
    test_missing_pause_state_file
    test_clear_pause_state
    
    # Print summary
    print_section "Test Summary"
    echo -e "Tests Run:    ${TESTS_RUN}"
    echo -e "${GREEN}Tests Passed: ${TESTS_PASSED}${NC}"
    if [ ${TESTS_FAILED} -gt 0 ]; then
        echo -e "${RED}Tests Failed: ${TESTS_FAILED}${NC}"
    else
        echo -e "Tests Failed: ${TESTS_FAILED}"
    fi
    echo ""
    
    if [ ${TESTS_FAILED} -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run main function
main
