#!/bin/bash

# Test script for time parsing and conversion

# Source the files
source lib/configure-core.sh
source lib/time-parsing.sh
source lib/time-validation.sh
source lib/config.sh
source lib/configure-time.sh

# Mock CONFIG_FILE
export CONFIG_FILE="/tmp/sleep-warning-test.conf"
echo "TIME_DISPLAY_FORMAT=12hour" > "${CONFIG_FILE}"

test_normalization() {
    echo "Testing normalization..."
    local inputs=("11pm" "11 PM" "11:30 pm" "23:30")
    for input in "${inputs[@]}"; do
        echo "Input: '${input}' -> Normalized: '$(normalize_time_input "${input}")'"
    done
}

test_detection() {
    echo "Testing format detection..."
    echo "11pm: $(detect_time_format "11pm")"
    echo "23:00: $(detect_time_format "23:00")"
}

test_conversion() {
    echo "Testing conversion..."
    echo "11:30pm to 24h: $(12hour_to_24hour 11 30 1)"
    echo "12:00am to 24h: $(12hour_to_24hour 12 0 0)"
    echo "12:00pm to 24h: $(12hour_to_24hour 12 0 1)"
    echo "23:30 to 12h: $(24hour_to_12hour 23 30)"
    echo "00:00 to 12h: $(24hour_to_12hour 0 0)"
    echo "12:00 to 12h: $(24hour_to_12hour 12 0)"
}

test_range_normalization() {
    echo "Testing range normalization..."
    echo "11pm-5am: $(normalize_time_range "11pm-5am")"
    echo "23-5: $(normalize_time_range "23-5")"
    echo "11:30pm-5:30am,10am-12pm: $(normalize_time_range "11:30pm-5:30am,10am-12pm")"
}

test_validation() {
    echo "Testing validation..."
    validate_time_range "11:30pm-5:30am" && echo "11:30pm-5:30am is valid" || echo "11:30pm-5:30am is invalid"
    validate_time_range "23:30-05:30" && echo "23:30-05:30 is valid" || echo "23:30-05:30 is invalid"
    validate_time_range "25:00-05:00" && echo "25:00-05:00 is valid" || echo "25:00-05:00 is invalid"
}

test_comparison() {
    echo "Testing comparison..."
    is_time_in_single_range "2330" "23:00-05:00" && echo "23:30 is in 23:00-05:00" || echo "23:30 is NOT in 23:00-05:00"
    is_time_in_single_range "0430" "23:00-05:00" && echo "04:30 is in 23:00-05:00" || echo "04:30 is NOT in 23:00-05:00"
    is_time_in_single_range "0600" "23:00-05:00" && echo "06:00 is in 23:00-05:00" || echo "06:00 is NOT in 23:00-05:00"
}

test_human_format() {
    echo "Testing human format..."
    format_range_human "23:30-05:30" "Monday"
    format_range_human "11:00-13:00" "Tuesday"
}

test_normalization
test_detection
test_conversion
test_range_normalization
test_validation
test_comparison
test_human_format

rm -f "${CONFIG_FILE}"
