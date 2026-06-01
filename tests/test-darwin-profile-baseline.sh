#!/bin/bash
# Headless baseline for CONFIGURE_PROFILE prep_ms on cached grid table JSON.
# Measures bash-side prep only (no GUI dialogs opened).
#
# Usage: CONFIGURE_PROFILE=1 ./tests/test-darwin-profile-baseline.sh
#
# Manual hop matrix (run on macOS with GUI session):
#   CONFIGURE_PROFILE=1 ./configure.sh
#   Hop: welcome -> main menu -> window behavior -> weekly grid -> time editor -> summary
#   Compare stderr lines: CONFIGURE_PROFILE dialog=... prep_ms=... ui_ms=...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CONFIGURE_PROFILE=1

# shellcheck source=../lib/configure-core.sh
source "${SCRIPT_DIR}/lib/configure-core.sh"
# shellcheck source=../lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck source=../lib/time-parsing.sh
source "${SCRIPT_DIR}/lib/time-parsing.sh" 2>/dev/null || true
# shellcheck source=../lib/configure-time.sh
source "${SCRIPT_DIR}/lib/configure-time.sh"
# shellcheck source=../lib/configure-dialogs-darwin.sh
source "${SCRIPT_DIR}/lib/configure-dialogs-darwin.sh"
# shellcheck source=../lib/configure-display.sh
source "${SCRIPT_DIR}/lib/configure-display.sh"

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

declare -g -a summary_lines=("" "Monday: 9-17" "" "" "" "" "")
declare -g -a lock_hours_lines=()
declare -g -a uninstall_lock_hours_lines=()

_configure_build_grid_cache summary_lines lock_hours_lines uninstall_lock_hours_lines
assert_eq "grid table json cached" "true" "$([ -n "${_CONFIGURE_GRID_TABLE_JSON:-}" ] && echo true || echo false)"

# Second build should reuse cache (no JSON rebuild cost in show_visual_grid path).
_CONFIGURE_GRID_TABLE_JSON="STALE_JSON"
_configure_build_grid_cache summary_lines lock_hours_lines uninstall_lock_hours_lines
assert_eq "grid table json reused with cache" "STALE_JSON" "${_CONFIGURE_GRID_TABLE_JSON}"

# Parse baseline: single python spawn for value when needed.
_CD_DARWIN_DAEMON_LAST_RESPONSE='{"ok": true, "value": "Sunday", "shown": true}'
_cd_darwin_parse_last_response
if _cd_darwin_response_is_ok && _cd_darwin_response_was_shown && ! _cd_darwin_response_is_cancelled; then
    v=$(_cd_darwin_response_extract_value)
    assert_eq "baseline parse Sunday" "Sunday" "${v}"
else
    echo "FAIL: baseline parse booleans"
    fail=$((fail + 1))
fi

echo ""
echo "Baseline harness complete (${pass} passed, ${fail} failed)."
echo "For ui_ms timings, run: CONFIGURE_PROFILE=1 ./configure.sh  (interactive macOS GUI)"
[ "${fail}" -eq 0 ]
