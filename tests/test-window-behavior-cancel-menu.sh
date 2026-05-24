#!/bin/bash
# Unit tests for Window Behavior cancel menu and on/off label mapping.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/configure-core.sh"
source "${SCRIPT_DIR}/lib/configure-dialogs-darwin.sh"
source "${SCRIPT_DIR}/lib/configure-ui.sh"
source "${SCRIPT_DIR}/lib/configure-input-popup.sh"

pass=0
fail=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${label} (expected '${expected}', got '${actual}')"
        fail=$((fail + 1))
    fi
}

assert_eq "immovable yes label" "true" "$(_map_on_off_list_to_bool 'Yes, prevent movement')"
assert_eq "immovable no label" "false" "$(_map_on_off_list_to_bool 'No, allow movement')"
assert_eq "auto-close yes label" "true" "$(_map_on_off_list_to_bool 'Yes, enable auto-close')"
assert_eq "auto-close no label" "false" "$(_map_on_off_list_to_bool 'No, disable auto-close')"

# Text-mode cancel menu returns BACK
set +e
result=$(handle_window_behavior_cancel_menu "false" "test")
rc=$?
set -e
assert_eq "text mode cancel menu stdout" "BACK" "${result}"
assert_eq "text mode cancel menu rc" "1" "${rc}"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
