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

test_comparison_15min_overnight() {
    echo "Testing 15-minute overnight boundaries (23:15-05:45)..."
    local pass=0 fail=0
    _assert_in() {
        local t="$1" want="$2"
        if is_time_in_single_range "${t}" "23:15-05:45"; then
            [ "${want}" = "in" ] && pass=$((pass + 1)) || { echo "FAIL: ${t} should be OUT"; fail=$((fail + 1)); }
        else
            [ "${want}" = "out" ] && pass=$((pass + 1)) || { echo "FAIL: ${t} should be IN"; fail=$((fail + 1)); }
        fi
    }
    _assert_in "2314" "out"
    _assert_in "2315" "in"
    _assert_in "0544" "in"
    _assert_in "0545" "out"
    echo "15-min overnight boundary: ${pass} passed, ${fail} failed"
    [ "${fail}" -eq 0 ] || exit 1
}

test_human_format() {
    echo "Testing human format..."
    format_range_human "23:30-05:30" "Monday"
    format_range_human "11:00-13:00" "Tuesday"
    # macOS tkinter picker format (no space before AM/PM)
    format_range_human "11:30PM-5:30AM" "Wednesday" 2>&1
    # format_ranges_human sets IFS=',' — must not break hour/minute split
    format_ranges_human "01:00-05:00" "Thursday" 2>&1
}

test_normalization
test_detection
test_conversion
test_range_normalization
test_validation
test_comparison
test_comparison_15min_overnight
test_human_format

rm -f "${CONFIG_FILE}"
