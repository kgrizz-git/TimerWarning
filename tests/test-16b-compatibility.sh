#!/bin/bash

# Test script for minute precision compatibility check

source lib/configure-core.sh
source lib/configure-validation.sh

test_compatibility() {
    echo "Testing minute precision compatibility..."
    
    local config_lines_1=("MONDAY=23:30-05:30" "TUESDAY=00:00-05:00")
    echo "Test 1: CHECK_INTERVAL=60, minute precision used"
    check_minute_precision_compatibility "60" "${config_lines_1[@]}"
    [ $? -ne 0 ] && echo "Result: Warning shown (Correct)" || echo "Result: No warning (Incorrect)"
    
    echo "Test 2: CHECK_INTERVAL=15, minute precision used"
    check_minute_precision_compatibility "15" "${config_lines_1[@]}"
    [ $? -eq 0 ] && echo "Result: No warning (Correct)" || echo "Result: Warning shown (Incorrect)"
    
    local config_lines_2=("MONDAY=23:00-05:00" "TUESDAY=00:00-05:00")
    echo "Test 3: CHECK_INTERVAL=60, no minute precision"
    check_minute_precision_compatibility "60" "${config_lines_2[@]}"
    [ $? -eq 0 ] && echo "Result: No warning (Correct)" || echo "Result: Warning shown (Incorrect)"
}

test_compatibility
