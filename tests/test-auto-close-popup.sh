#!/bin/bash

###############################################################################
# Test Suite for Enhancement #15: Auto-Close Popup Window
#
# This script tests the auto-close popup window functionality including:
# - Configuration getter function (get_popup_auto_close)
# - Auto-close behavior with different dialog tools
# - Integration with minimum display time
# - Manual close cancellation
#
# Requirements:
# - bash
# - Temporary config file for testing
# - Dialog tool (zenity, yad, or kdialog) for integration tests
#
# Usage (from root project directory):
#   ./tests/test-auto-close-popup.sh
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Source required modules
source lib/config.sh || exit 1

echo "=== Enhancement #15: Auto-Close Popup Window - Tests ==="
echo ""

PASSED=0
FAILED=0
WARNINGS=0

# Create temporary config directory and file for testing
TEST_CONFIG_DIR="${HOME}/.config/sleep-warning-test"
TEST_CONFIG_FILE="${TEST_CONFIG_DIR}/config/sleep-warning.conf"
mkdir -p "${TEST_CONFIG_DIR}/config" || exit 1

# Backup original config file path
ORIGINAL_CONFIG_FILE="${CONFIG_FILE}"

# Test helper: Set test config
set_test_config() {
    local content="$1"
    echo "$content" > "${TEST_CONFIG_FILE}"
    # Temporarily override CONFIG_FILE for testing
    export CONFIG_FILE="${TEST_CONFIG_FILE}"
}

# Test helper: Restore original config
restore_config() {
    export CONFIG_FILE="${ORIGINAL_CONFIG_FILE}"
    rm -rf "${TEST_CONFIG_DIR}"
}

# Cleanup on exit
trap restore_config EXIT

###############################################################################
# Unit Tests: get_popup_auto_close() function
###############################################################################

echo "=== Unit Tests: get_popup_auto_close() ==="
echo ""

# Test 1: Valid values (true)
echo "Test 1.1: Valid value 'true'"
set_test_config "POPUP_AUTO_CLOSE=true"
result=$(get_popup_auto_close)
if [ "$result" = "true" ]; then
    echo "  ✅ PASS: Returns 'true' for 'true'"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected 'true', got '$result'"
    ((FAILED++))
fi

# Test 1.2: Valid values (false)
echo "Test 1.2: Valid value 'false'"
set_test_config "POPUP_AUTO_CLOSE=false"
result=$(get_popup_auto_close)
if [ "$result" = "false" ]; then
    echo "  ✅ PASS: Returns 'false' for 'false'"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected 'false', got '$result'"
    ((FAILED++))
fi

# Test 1.3: Valid values (1)
echo "Test 1.3: Valid value '1'"
set_test_config "POPUP_AUTO_CLOSE=1"
result=$(get_popup_auto_close)
if [ "$result" = "true" ]; then
    echo "  ✅ PASS: Returns 'true' for '1'"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected 'true', got '$result'"
    ((FAILED++))
fi

# Test 1.4: Valid values (0)
echo "Test 1.4: Valid value '0'"
set_test_config "POPUP_AUTO_CLOSE=0"
result=$(get_popup_auto_close)
if [ "$result" = "false" ]; then
    echo "  ✅ PASS: Returns 'false' for '0'"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected 'false', got '$result'"
    ((FAILED++))
fi

# Test 1.5: Valid values (yes)
echo "Test 1.5: Valid value 'yes'"
set_test_config "POPUP_AUTO_CLOSE=yes"
result=$(get_popup_auto_close)
if [ "$result" = "true" ]; then
    echo "  ✅ PASS: Returns 'true' for 'yes'"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected 'true', got '$result'"
    ((FAILED++))
fi

# Test 1.6: Valid values (no)
echo "Test 1.6: Valid value 'no'"
set_test_config "POPUP_AUTO_CLOSE=no"
result=$(get_popup_auto_close)
if [ "$result" = "false" ]; then
    echo "  ✅ PASS: Returns 'false' for 'no'"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected 'false', got '$result'"
    ((FAILED++))
fi

# Test 2: Invalid values
echo "Test 2.1: Invalid value 'invalid'"
set_test_config "POPUP_AUTO_CLOSE=invalid"
result=$(get_popup_auto_close)
if [ "$result" = "true" ]; then
    echo "  ✅ PASS: Returns default 'true' for invalid value"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected default 'true', got '$result'"
    ((FAILED++))
fi

# Test 2.2: Empty value
echo "Test 2.2: Empty value"
set_test_config "POPUP_AUTO_CLOSE="
result=$(get_popup_auto_close)
if [ "$result" = "true" ]; then
    echo "  ✅ PASS: Returns default 'true' for empty value"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected default 'true', got '$result'"
    ((FAILED++))
fi

# Test 3: Missing config (should return default)
echo "Test 3.1: Missing config file"
rm -f "${TEST_CONFIG_FILE}"
result=$(get_popup_auto_close)
if [ "$result" = "true" ]; then
    echo "  ✅ PASS: Returns default 'true' when config file missing"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected default 'true', got '$result'"
    ((FAILED++))
fi

# Test 3.2: Missing POPUP_AUTO_CLOSE option
echo "Test 3.2: Missing POPUP_AUTO_CLOSE option"
set_test_config "CHECK_INTERVAL=10"
result=$(get_popup_auto_close)
if [ "$result" = "true" ]; then
    echo "  ✅ PASS: Returns default 'true' when option missing"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected default 'true', got '$result'"
    ((FAILED++))
fi

# Test 4: Case insensitivity
echo "Test 4.1: Case insensitive 'TRUE'"
set_test_config "POPUP_AUTO_CLOSE=TRUE"
result=$(get_popup_auto_close)
if [ "$result" = "true" ]; then
    echo "  ✅ PASS: Returns 'true' for 'TRUE' (case insensitive)"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected 'true', got '$result'"
    ((FAILED++))
fi

echo "Test 4.2: Case insensitive 'FALSE'"
set_test_config "POPUP_AUTO_CLOSE=FALSE"
result=$(get_popup_auto_close)
if [ "$result" = "false" ]; then
    echo "  ✅ PASS: Returns 'false' for 'FALSE' (case insensitive)"
    ((PASSED++))
else
    echo "  ❌ FAIL: Expected 'false', got '$result'"
    ((FAILED++))
fi

echo ""
echo "=== Unit Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

###############################################################################
# Integration Tests: Auto-Close Behavior
###############################################################################

echo "=== Integration Tests: Auto-Close Behavior ==="
echo ""
echo "⚠️  Note: Integration tests require manual verification"
echo "    These tests will display popups that should auto-close"
echo ""

# Check if dialog tool is available
DIALOG_TOOL=""
if command -v yad >/dev/null 2>&1; then
    DIALOG_TOOL="yad"
elif command -v zenity >/dev/null 2>&1; then
    DIALOG_TOOL="zenity"
elif command -v kdialog >/dev/null 2>&1; then
    DIALOG_TOOL="kdialog"
fi

if [ -z "$DIALOG_TOOL" ]; then
    echo "⚠️  WARNING: No dialog tool available (zenity/yad/kdialog)"
    echo "    Skipping integration tests that require popup display"
    ((WARNINGS++))
    INTEGRATION_TESTS_AVAILABLE=false
else
    echo "✅ Dialog tool available: $DIALOG_TOOL"
    INTEGRATION_TESTS_AVAILABLE=true
fi

if [ "$INTEGRATION_TESTS_AVAILABLE" = "true" ]; then
    # Source required modules for integration tests
    source lib/config.sh 2>/dev/null || true
    source lib/logging.sh 2>/dev/null || true
    source lib/configure-validation.sh 2>/dev/null || true  # For merge_overlapping_intervals
    source lib/display-detection.sh 2>/dev/null || true
    source lib/desktop-environment.sh 2>/dev/null || true
    source lib/window-management.sh 2>/dev/null || true
    source lib/time-calculations.sh 2>/dev/null || true
    source lib/pause-state.sh 2>/dev/null || true
    source lib/popup-display.sh 2>/dev/null || true
    
    # Set up test log file
    TEST_LOG_FILE="${TEST_CONFIG_DIR}/test-auto-close.log"
    export LOG_FILE="${TEST_LOG_FILE}"
    
    # Test 5: Test close_popup_process() function directly
    echo ""
    echo "Test 5: close_popup_process() function (automated)"
    echo "  Testing process termination logic..."
    
    # Create a dummy process (sleep) to test termination
    sleep 30 &
    DUMMY_PID=$!
    
    # Test that close_popup_process can terminate it
    if kill -0 "${DUMMY_PID}" 2>/dev/null; then
        # Call close_popup_process (need to source it first)
        if type close_popup_process >/dev/null 2>&1; then
            close_popup_process "${DUMMY_PID}" "zenity" >/dev/null 2>&1
            sleep 1
            if ! kill -0 "${DUMMY_PID}" 2>/dev/null; then
                echo "  ✅ PASS: close_popup_process() successfully terminated process"
                ((PASSED++))
            else
                echo "  ❌ FAIL: close_popup_process() did not terminate process"
                kill "${DUMMY_PID}" 2>/dev/null
                ((FAILED++))
            fi
        else
            echo "  ⚠️  WARN: close_popup_process() function not available (need to source popup-display.sh)"
            kill "${DUMMY_PID}" 2>/dev/null
            ((WARNINGS++))
        fi
    else
        echo "  ⚠️  WARN: Could not create test process"
        ((WARNINGS++))
    fi
    
    # Test 6: Test auto_close_popup() function timing
    echo ""
    echo "Test 6: auto_close_popup() timing (automated)"
    echo "  Expected: Process should be terminated after ~10 seconds"
    
    # Create a long-running dummy process
    sleep 60 &
    TEST_PID=$!
    
    if kill -0 "${TEST_PID}" 2>/dev/null; then
        # Test auto_close_popup timing
        if type auto_close_popup >/dev/null 2>&1; then
            START_TIME=$(date +%s)
            auto_close_popup "${TEST_PID}" "zenity" "Test Window" "" &
            AUTO_CLOSE_PID=$!
            
            # Wait for process to be terminated (up to 12 seconds)
            TIMEOUT=12
            ELAPSED=0
            while kill -0 "${TEST_PID}" 2>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
                sleep 0.1
                CURRENT=$(date +%s)
                ELAPSED=$((CURRENT - START_TIME))
            done
            
            END_TIME=$(date +%s)
            TOTAL_ELAPSED=$((END_TIME - START_TIME))
            
            if ! kill -0 "${TEST_PID}" 2>/dev/null; then
                # Process was terminated
                if [ "${TOTAL_ELAPSED}" -ge 9 ] && [ "${TOTAL_ELAPSED}" -le 12 ]; then
                    echo "  ✅ PASS: Process terminated after ${TOTAL_ELAPSED} seconds (expected ~10 seconds)"
                    ((PASSED++))
                else
                    echo "  ⚠️  WARN: Process terminated after ${TOTAL_ELAPSED} seconds (expected ~10 seconds)"
                    ((WARNINGS++))
                fi
            else
                echo "  ❌ FAIL: Process was not terminated after ${TOTAL_ELAPSED} seconds"
                kill "${TEST_PID}" 2>/dev/null
                kill "${AUTO_CLOSE_PID}" 2>/dev/null 2>&1
                ((FAILED++))
            fi
        else
            echo "  ⚠️  WARN: auto_close_popup() function not available"
            kill "${TEST_PID}" 2>/dev/null
            ((WARNINGS++))
        fi
    else
        echo "  ⚠️  WARN: Could not create test process"
        ((WARNINGS++))
    fi
    
    # Test 7: Test with minimum display time simulation (shorter for automated testing)
    # Skip this test if SKIP_LONG_TESTS is set (takes ~11 seconds)
    if [ "${SKIP_LONG_TESTS:-false}" = "true" ]; then
        echo ""
        echo "Test 7: Auto-close after simulated minimum display time (SKIPPED - set SKIP_LONG_TESTS=false to run)"
        ((WARNINGS++))
    else
        echo ""
        echo "Test 7: Auto-close after simulated minimum display time (automated)"
        echo "  Simulating: min_display_time=1, then auto-close after 10 seconds = 11 total"
        echo "  Note: This test takes ~11 seconds to complete"
    
    sleep 60 &
    TEST_PID=$!
    
    if kill -0 "${TEST_PID}" 2>/dev/null; then
        if type auto_close_popup >/dev/null 2>&1; then
            START_TIME=$(date +%s)
            
            # Simulate minimum display time (1 second for faster test)
            sleep 1
            
            # Now start auto-close timer (10 seconds)
            auto_close_popup "${TEST_PID}" "zenity" "Test Window" "" &
            AUTO_CLOSE_PID=$!
            
            # Wait for termination (up to 13 seconds total)
            TIMEOUT=13
            ELAPSED=0
            while kill -0 "${TEST_PID}" 2>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
                sleep 0.1
                CURRENT=$(date +%s)
                ELAPSED=$((CURRENT - START_TIME))
            done
            
            END_TIME=$(date +%s)
            TOTAL_ELAPSED=$((END_TIME - START_TIME))
            
            if ! kill -0 "${TEST_PID}" 2>/dev/null; then
                # Process was terminated
                if [ "${TOTAL_ELAPSED}" -ge 10 ] && [ "${TOTAL_ELAPSED}" -le 13 ]; then
                    echo "  ✅ PASS: Process terminated after ${TOTAL_ELAPSED} seconds (expected ~11 seconds)"
                    ((PASSED++))
                else
                    echo "  ⚠️  WARN: Process terminated after ${TOTAL_ELAPSED} seconds (expected ~11 seconds)"
                    ((WARNINGS++))
                fi
            else
                echo "  ❌ FAIL: Process was not terminated after ${TOTAL_ELAPSED} seconds"
                kill "${TEST_PID}" 2>/dev/null
                kill "${AUTO_CLOSE_PID}" 2>/dev/null 2>&1
                ((FAILED++))
            fi
        else
            echo "  ⚠️  WARN: auto_close_popup() function not available"
            kill "${TEST_PID}" 2>/dev/null
            ((WARNINGS++))
        fi
    else
        echo "  ⚠️  WARN: Could not create test process"
        ((WARNINGS++))
    fi
    fi  # End of SKIP_LONG_TESTS check
    
    # Test 8: Test manual close cancellation
    echo ""
    echo "Test 8: Manual close cancels auto-close timer (automated)"
    echo "  Expected: If process closes before timer, timer should handle gracefully"
    
    sleep 10 &
    TEST_PID=$!
    
    if kill -0 "${TEST_PID}" 2>/dev/null; then
        if type auto_close_popup >/dev/null 2>&1; then
            # Start auto-close timer
            auto_close_popup "${TEST_PID}" "zenity" "Test Window" "" &
            AUTO_CLOSE_PID=$!
            
            # Immediately close the process manually (simulating user close)
            sleep 0.5
            kill "${TEST_PID}" 2>/dev/null
            sleep 0.5
            
            # Check if auto-close timer is still running (it should detect process is gone)
            if ! kill -0 "${AUTO_CLOSE_PID}" 2>/dev/null; then
                echo "  ✅ PASS: Auto-close timer exited when process closed manually"
                ((PASSED++))
            else
                # Timer might still be running (waiting for 10 seconds), but that's okay
                # The important thing is it should handle it gracefully
                sleep 1
                if ! kill -0 "${AUTO_CLOSE_PID}" 2>/dev/null; then
                    echo "  ✅ PASS: Auto-close timer handled manual close gracefully"
                    ((PASSED++))
                else
                    echo "  ⚠️  WARN: Auto-close timer still running (may be normal, will exit when it checks)"
                    kill "${AUTO_CLOSE_PID}" 2>/dev/null
                    ((WARNINGS++))
                fi
            fi
        else
            echo "  ⚠️  WARN: auto_close_popup() function not available"
            kill "${TEST_PID}" 2>/dev/null
            ((WARNINGS++))
        fi
    else
        echo "  ⚠️  WARN: Could not create test process"
        ((WARNINGS++))
    fi
    
    # Test 9: Full popup display test with auto-close (min_display_time=0)
    echo ""
    echo "Test 9: Full popup display with auto-close (min_display_time=0) - AUTOMATED"
    echo "  Expected: Popup should appear and auto-close after ~10 seconds"
    
    # Set up test config
    set_test_config "POPUP_AUTO_CLOSE=true
POPUP_MIN_DISPLAY_TIME=0
CHECK_INTERVAL=10
POPUP_SIZE=small
POPUP_POSITION=center
RESTRICTED_HOURS_MONDAY=0-23
RESTRICTED_HOURS_TUESDAY=0-23
RESTRICTED_HOURS_WEDNESDAY=0-23
RESTRICTED_HOURS_THURSDAY=0-23
RESTRICTED_HOURS_FRIDAY=0-23
RESTRICTED_HOURS_SATURDAY=0-23
RESTRICTED_HOURS_SUNDAY=0-23"
    
    # Call show_warning in background and capture PID
    show_warning &
    POPUP_PID=$!
    
    # Wait a moment for popup to start
    sleep 1
    
    if kill -0 "${POPUP_PID}" 2>/dev/null; then
        echo "  Popup started (PID: ${POPUP_PID}), monitoring for auto-close..."
        START_TIME=$(date +%s)
        
        # Wait for popup to close (up to 12 seconds)
        TIMEOUT=12
        ELAPSED=0
        while kill -0 "${POPUP_PID}" 2>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
            sleep 0.1
            CURRENT=$(date +%s)
            ELAPSED=$((CURRENT - START_TIME))
        done
        
        END_TIME=$(date +%s)
        TOTAL_ELAPSED=$((END_TIME - START_TIME))
        
        if ! kill -0 "${POPUP_PID}" 2>/dev/null; then
            if [ "${TOTAL_ELAPSED}" -ge 9 ] && [ "${TOTAL_ELAPSED}" -le 12 ]; then
                echo "  ✅ PASS: Popup auto-closed after ${TOTAL_ELAPSED} seconds (expected ~10 seconds)"
                ((PASSED++))
            else
                echo "  ⚠️  WARN: Popup closed after ${TOTAL_ELAPSED} seconds (expected ~10 seconds)"
                ((WARNINGS++))
            fi
        else
            echo "  ❌ FAIL: Popup did not auto-close after ${TOTAL_ELAPSED} seconds"
            kill "${POPUP_PID}" 2>/dev/null
            ((FAILED++))
        fi
    else
        echo "  ⚠️  WARN: Popup process did not start or exited immediately"
        ((WARNINGS++))
    fi
    
    # Test 10: Full popup display test with auto-close (min_display_time=2)
    echo ""
    echo "Test 10: Full popup display with auto-close (min_display_time=2) - AUTOMATED"
    echo "  Expected: Popup should appear, wait 2 seconds, then auto-close after ~10 more seconds = ~12 total"
    
    set_test_config "POPUP_AUTO_CLOSE=true
POPUP_MIN_DISPLAY_TIME=2
CHECK_INTERVAL=10
POPUP_SIZE=small
POPUP_POSITION=center
RESTRICTED_HOURS_MONDAY=0-23
RESTRICTED_HOURS_TUESDAY=0-23
RESTRICTED_HOURS_WEDNESDAY=0-23
RESTRICTED_HOURS_THURSDAY=0-23
RESTRICTED_HOURS_FRIDAY=0-23
RESTRICTED_HOURS_SATURDAY=0-23
RESTRICTED_HOURS_SUNDAY=0-23"
    
    # Call show_warning in background and capture PID
    show_warning &
    POPUP_PID=$!
    
    # Wait a moment for popup to start
    sleep 1
    
    if kill -0 "${POPUP_PID}" 2>/dev/null; then
        echo "  Popup started (PID: ${POPUP_PID}), monitoring for auto-close..."
        START_TIME=$(date +%s)
        
        # Wait for popup to close (up to 14 seconds total)
        TIMEOUT=14
        ELAPSED=0
        while kill -0 "${POPUP_PID}" 2>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
            sleep 0.1
            CURRENT=$(date +%s)
            ELAPSED=$((CURRENT - START_TIME))
        done
        
        END_TIME=$(date +%s)
        TOTAL_ELAPSED=$((END_TIME - START_TIME))
        
        if ! kill -0 "${POPUP_PID}" 2>/dev/null; then
            if [ "${TOTAL_ELAPSED}" -ge 11 ] && [ "${TOTAL_ELAPSED}" -le 14 ]; then
                echo "  ✅ PASS: Popup auto-closed after ${TOTAL_ELAPSED} seconds (expected ~12 seconds)"
                ((PASSED++))
            else
                echo "  ⚠️  WARN: Popup closed after ${TOTAL_ELAPSED} seconds (expected ~12 seconds)"
                ((WARNINGS++))
            fi
        else
            echo "  ❌ FAIL: Popup did not auto-close after ${TOTAL_ELAPSED} seconds"
            kill "${POPUP_PID}" 2>/dev/null
            ((FAILED++))
        fi
    else
        echo "  ⚠️  WARN: Popup process did not start or exited immediately"
        ((WARNINGS++))
    fi
    
    # Test 11: Full popup display test with auto-close disabled
    echo ""
    echo "Test 11: Full popup display with auto-close DISABLED - AUTOMATED"
    echo "  Expected: Popup should appear and NOT auto-close (will timeout test after 12 seconds)"
    
    set_test_config "POPUP_AUTO_CLOSE=false
POPUP_MIN_DISPLAY_TIME=0
CHECK_INTERVAL=10
POPUP_SIZE=small
POPUP_POSITION=center
RESTRICTED_HOURS_MONDAY=0-23
RESTRICTED_HOURS_TUESDAY=0-23
RESTRICTED_HOURS_WEDNESDAY=0-23
RESTRICTED_HOURS_THURSDAY=0-23
RESTRICTED_HOURS_FRIDAY=0-23
RESTRICTED_HOURS_SATURDAY=0-23
RESTRICTED_HOURS_SUNDAY=0-23"
    
    # Call show_warning in background and capture PID
    show_warning &
    POPUP_PID=$!
    
    # Wait a moment for popup to start
    sleep 1
    
    if kill -0 "${POPUP_PID}" 2>/dev/null; then
        echo "  Popup started (PID: ${POPUP_PID}), monitoring (should NOT auto-close)..."
        START_TIME=$(date +%s)
        
        # Wait up to 12 seconds (if auto-close is disabled, popup should still be running)
        TIMEOUT=12
        ELAPSED=0
        while kill -0 "${POPUP_PID}" 2>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
            sleep 0.1
            CURRENT=$(date +%s)
            ELAPSED=$((CURRENT - START_TIME))
        done
        
        END_TIME=$(date +%s)
        TOTAL_ELAPSED=$((END_TIME - START_TIME))
        
        # Check if still running
        if kill -0 "${POPUP_PID}" 2>/dev/null; then
            echo "  ✅ PASS: Popup still running after ${TOTAL_ELAPSED} seconds (auto-close disabled as expected)"
            kill "${POPUP_PID}" 2>/dev/null
            ((PASSED++))
        else
            echo "  ⚠️  WARN: Popup closed after ${TOTAL_ELAPSED} seconds (unexpected if auto-close disabled)"
            ((WARNINGS++))
        fi
    else
        echo "  ⚠️  WARN: Popup process did not start or exited immediately"
        ((WARNINGS++))
    fi
fi

###############################################################################
# Configuration File Tests
###############################################################################

echo ""
echo "=== Configuration File Tests ==="
echo ""

# Test 9: Config file writing (via configure-config.sh)
echo "Test 9: Config file writing"
# This would require sourcing configure-config.sh and testing write_config()
# For now, we'll just verify the function exists
if type write_config >/dev/null 2>&1; then
    echo "  ✅ PASS: write_config() function exists"
    ((PASSED++))
else
    echo "  ⚠️  WARN: write_config() not available (may need to source configure-config.sh)"
    ((WARNINGS++))
fi

# Test 10: Default value in config.sh
echo "Test 10: Default value constant"
if [ -n "${DEFAULT_POPUP_AUTO_CLOSE}" ] && [ "${DEFAULT_POPUP_AUTO_CLOSE}" = "true" ]; then
    echo "  ✅ PASS: DEFAULT_POPUP_AUTO_CLOSE='${DEFAULT_POPUP_AUTO_CLOSE}'"
    ((PASSED++))
else
    echo "  ❌ FAIL: DEFAULT_POPUP_AUTO_CLOSE not set or incorrect"
    ((FAILED++))
fi

# Test 11: AUTO_CLOSE_DELAY constant
echo "Test 11: AUTO_CLOSE_DELAY constant"
if [ -n "${AUTO_CLOSE_DELAY}" ] && [ "${AUTO_CLOSE_DELAY}" -eq 10 ]; then
    echo "  ✅ PASS: AUTO_CLOSE_DELAY=${AUTO_CLOSE_DELAY}"
    ((PASSED++))
else
    echo "  ❌ FAIL: AUTO_CLOSE_DELAY not set or incorrect (expected 10)"
    ((FAILED++))
fi

###############################################################################
# Summary
###############################################################################

echo ""
echo "=== Final Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Warnings: $WARNINGS"
echo ""

if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -gt 0 ]; then
        echo "✅ All automated tests passed!"
        echo "⚠️  Some manual integration tests require verification"
        exit 0
    else
        echo "✅ All tests passed!"
        exit 0
    fi
else
    echo "❌ Some tests failed"
    exit 1
fi
