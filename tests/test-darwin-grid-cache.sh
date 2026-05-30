#!/bin/bash
# Non-GUI tests for weekly grid cache (_configure_build_grid_cache).
# Catches empty/stale grid data and circular nameref warnings.
#
# Usage: ./tests/test-darwin-grid-cache.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/configure-core.sh
source "${SCRIPT_DIR}/lib/configure-core.sh"
# shellcheck source=../lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck source=../lib/time-parsing.sh
source "${SCRIPT_DIR}/lib/time-parsing.sh" 2>/dev/null || true
# shellcheck source=../lib/configure-time.sh
source "${SCRIPT_DIR}/lib/configure-time.sh"
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

assert_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${label}"
        echo "  expected substring: '${needle}'"
        echo "  in: '${haystack}'"
        fail=$((fail + 1))
    fi
}

assert_not_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        echo "FAIL: ${label}"
        echo "  unexpected substring: '${needle}'"
        fail=$((fail + 1))
    else
        echo "PASS: ${label}"
        pass=$((pass + 1))
    fi
}

# --- grid cache row count and Back row (index 0 = Sunday … 6 = Saturday) ---
declare -g -a summary_lines=("" "Monday: 9-17" "" "" "" "" "")
declare -g -a lock_hours_lines=()
declare -g -a uninstall_lock_hours_lines=()

_configure_build_grid_cache summary_lines lock_hours_lines uninstall_lock_hours_lines
assert_eq "grid cache valid after build" "true" "${_CONFIGURE_GRID_CACHE_VALID}"
assert_eq "grid row count (7 days + Back)" "8" "${#_CONFIGURE_GRID_DAY_NAMES[@]}"
assert_eq "grid back row label" "[Back]" "${_CONFIGURE_GRID_DAY_NAMES[7]}"
assert_contains "monday restricted formatted" "${_CONFIGURE_GRID_RESTRICTED[1]}" "9:00am"

# --- cache reuse without rebuild ---
_CONFIGURE_GRID_DAY_NAMES=("STALE")
_configure_build_grid_cache summary_lines lock_hours_lines uninstall_lock_hours_lines
assert_eq "grid cache reuse skips rebuild" "STALE" "${_CONFIGURE_GRID_DAY_NAMES[0]}"

# --- invalidation after hour data change ---
configure_hours_data_changed
assert_eq "grid cache invalid after hours change" "false" "${_CONFIGURE_GRID_CACHE_VALID}"
_configure_build_grid_cache summary_lines lock_hours_lines uninstall_lock_hours_lines
assert_eq "grid cache rebuild restores row count" "8" "${#_CONFIGURE_GRID_DAY_NAMES[@]}"

# --- nested nameref path (same as show_visual_grid → _configure_build_grid_cache) ---
declare -g -a summary_lines2=("" "Monday: 23-6" "" "" "" "" "")
declare -g -a lock_hours_lines2=()
declare -g -a uninstall_lock_hours_lines2=()
configure_invalidate_grid_cache

show_grid_via_nameref() {
    local -n summary_lines_ref="$1"
    local -n lock_hours_lines_ref="$2"
    local -n uninstall_lock_hours_lines_ref="$3"
    _configure_build_grid_cache summary_lines_ref lock_hours_lines_ref uninstall_lock_hours_lines_ref
}

stderr_file=$(mktemp "${TMPDIR:-/tmp}/sw-grid-cache-stderr.XXXXXX")
show_grid_via_nameref summary_lines2 lock_hours_lines2 uninstall_lock_hours_lines2 2>"${stderr_file}" || true
stderr=$(cat "${stderr_file}")
rm -f "${stderr_file}"
assert_not_contains "no circular nameref warning" "${stderr}" "circular name reference"
assert_contains "inherited overnight on Tuesday" "${_CONFIGURE_GRID_RESTRICTED[2]}" "inherited"

# --- helper must not reuse caller nameref names (static guard) ---
if grep -q 'local -n summary_lines_ref="\$1"' "${SCRIPT_DIR}/lib/configure-display.sh"; then
    echo "FAIL: _configure_build_grid_cache uses caller nameref name summary_lines_ref"
    fail=$((fail + 1))
else
    echo "PASS: grid cache uses distinct nameref names"
    pass=$((pass + 1))
fi

# --- set -e: get_inherited_restrictions returns 1 for most days (must not abort) ---
configure_invalidate_grid_cache
if ( set -e; _configure_build_grid_cache summary_lines lock_hours_lines uninstall_lock_hours_lines ); then
    echo "PASS: grid cache safe under set -e"
    pass=$((pass + 1))
else
    echo "FAIL: grid cache safe under set -e"
    fail=$((fail + 1))
fi

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
