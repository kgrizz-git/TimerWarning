#!/bin/bash
# Unit tests for main menu cancel menu helper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/configure-core.sh"
source "${SCRIPT_DIR}/lib/configure-dialogs-darwin.sh"
source "${SCRIPT_DIR}/lib/configure-ui.sh"

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

# Text-mode cancel menu uses confirm_cancel (decline with "n") -> return 1
set +e
result=$(printf 'n\n' | handle_main_menu_cancel_menu "false" "test")
rc=$?
set -e
assert_eq "text mode stdout empty on continue" "" "${result}"
assert_eq "text mode rc continue" "1" "${rc}"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
