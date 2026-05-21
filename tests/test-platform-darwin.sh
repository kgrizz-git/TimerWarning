#!/bin/bash

###############################################################################
# test-platform-darwin.sh - Platform detection and plist generation (no GUI)
#
# Purpose: Verify macOS platform helpers and LaunchAgent plist content.
# Last updated: 2026-05-20
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_DIR}/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/platform.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/popup-safety.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/service-config-darwin.sh"

pass=0
fail=0

assert_eq() {
    local desc="$1"
    local got="$2"
    local want="$3"
    if [ "${got}" = "${want}" ]; then
        echo "PASS: ${desc}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${desc} (got '${got}', want '${want}')"
        fail=$((fail + 1))
    fi
}

assert_gt_zero() {
    local desc="$1"
    local val="$2"
    if [ "${val}" -gt 0 ] 2>/dev/null; then
        echo "PASS: ${desc}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${desc} (value=${val})"
        fail=$((fail + 1))
    fi
}

# Platform detection on current OS
plat="$(detect_platform)"
if [ "$(uname -s)" = "Darwin" ]; then
    assert_eq "detect_platform on Darwin" "${plat}" "darwin"
    assert_eq "get_init_system" "$(get_init_system)" "launchd"
else
    assert_eq "detect_platform on non-Darwin CI" "${plat}" "linux"
fi

# Watchdog math
wd=$(popup_compute_watchdog_seconds 30 true)
assert_gt_zero "watchdog seconds for 30s min + auto-close" "${wd}"

# Plist generation in temp HOME
export HOME
TEST_HOME=$(mktemp -d)
export HOME="${TEST_HOME}"
mkdir -p "${HOME}/Library/LaunchAgents"
mkdir -p "${HOME}/.config/sleep-warning/logs"
SLEEP_WARNING_SCRIPT="${HOME}/.local/bin/sleep-warning.sh"
mkdir -p "$(dirname "${SLEEP_WARNING_SCRIPT}")"
touch "${SLEEP_WARNING_SCRIPT}"

write_launch_agent_plist 10
assert_eq "plist created" "$([ -f "${HOME}/Library/LaunchAgents/com.sleep-warning.plist" ] && echo yes || echo no)" "yes"

if grep -q '<integer>600</integer>' "${HOME}/Library/LaunchAgents/com.sleep-warning.plist"; then
    echo "PASS: StartInterval 600 for 10 minutes"
    pass=$((pass + 1))
else
    echo "FAIL: StartInterval not 600"
    fail=$((fail + 1))
fi

rm -rf "${TEST_HOME}"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
