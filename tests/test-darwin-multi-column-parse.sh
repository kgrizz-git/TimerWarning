#!/bin/bash
# Test darwin multi-column argument parsing (no GUI).
# Usage: ./tests/test-darwin-multi-column-parse.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/configure-dialogs-darwin.sh"

pass=0
fail=0

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${label}"
        echo "  expected: '${expected}'"
        echo "  actual:   '${actual}'"
        fail=$((fail + 1))
    fi
}

# Simulate grid call args after title/message/width/height
test_grid_parse() {
    local args=(
        1
        "Day" "Restricted Hours" "Config Lock Hours" "Uninstall Lock Hours"
        "Sunday" "12:00am -> 5:00am" "[no lock hours]" "[no uninstall lock hours]"
        "Monday" "12:00am -> 5:00am" "[no lock hours]" "[no uninstall lock hours]"
        "[Back]" "Return to Main Menu" "" ""
    )
    _cd_darwin_parse_multi_column_args "${args[@]}"
    assert_eq "grid num_columns" "4" "${_cd_num_columns}"
    assert_eq "grid first header" "Day" "${_cd_column_names[0]}"
    assert_eq "grid first day" "Sunday" "${_cd_data[0]}"
    assert_eq "grid first restricted" "12:00am -> 5:00am" "${_cd_data[1]}"
    assert_eq "grid back row day" "[Back]" "${_cd_data[8]}"
}

test_menu_parse() {
    local args=(
        1
        "Option" "Description"
        "1" "Timer Settings [Check Interval: 5 min]"
        "2" "Window Behavior [opens submenu]"
    )
    _cd_darwin_parse_multi_column_args "${args[@]}"
    assert_eq "menu num_columns" "2" "${_cd_num_columns}"
    assert_eq "menu option 1" "1" "${_cd_data[0]}"
    assert_eq "menu desc 1" "Timer Settings [Check Interval: 5 min]" "${_cd_data[1]}"
}

test_grid_parse
test_menu_parse

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
