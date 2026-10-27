#!/usr/bin/env bash

###############################################################################
# Quality-gate script tests
#
# Exercises scripts/check-file-sizes.sh (cap and ratchet) and
# scripts/check-shell-complexity.sh (length and nesting) on synthetic blobs.
# Does not touch lib/ and does not run Ruff or basedpyright.
#
# Usage: bash tests/test-quality-gates.sh
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIZES="${SCRIPT_DIR}/scripts/check-file-sizes.sh"
COMPLEXITY="${SCRIPT_DIR}/scripts/check-shell-complexity.sh"

_PASS=0
_FAIL=0
_pass() { _PASS=$((_PASS + 1)); echo "  PASS  $*"; }
_fail() { _FAIL=$((_FAIL + 1)); echo "  FAIL  $*"; }

# lines COUNT: print COUNT lines
lines() { yes x | head -n "$1"; }

# nested DEPTH: a function with DEPTH nested ifs
nested() {
    local depth="$1" i
    echo "f() {"
    for ((i = 0; i < depth; i++)); do echo "if true; then"; done
    echo ":"
    for ((i = 0; i < depth; i++)); do echo "fi"; done
    echo "}"
}

# expect_rc DESCRIPTION EXPECTED_RC COMMAND...  (stdin is passed through)
expect_rc() {
    local desc="$1" want="$2" rc
    shift 2
    "$@" >/dev/null 2>&1
    rc=$?
    if [[ "${rc}" -eq "${want}" ]]; then
        _pass "${desc}"
    else
        _fail "${desc} (rc ${rc}, wanted ${want})"
    fi
}

# --- file sizes: shell cap 900, python cap 500, recorded ceilings ---
expect_rc "900-line new shell file passes" 0 bash -c "$(declare -f lines); lines 900 | '${SIZES}' --strict --stdin lib/new.sh"
expect_rc "901-line new shell file fails" 1 bash -c "$(declare -f lines); lines 901 | '${SIZES}' --strict --stdin lib/new.sh"
expect_rc "500-line python file passes" 0 bash -c "$(declare -f lines); lines 500 | '${SIZES}' --strict --stdin lib/new.py"
expect_rc "501-line python file fails" 1 bash -c "$(declare -f lines); lines 501 | '${SIZES}' --strict --stdin lib/new.py"
expect_rc "tests are uncapped" 0 bash -c "$(declare -f lines); lines 2000 | '${SIZES}' --strict --stdin tests/big.sh"
expect_rc "file at its ceiling passes" 0 bash -c "$(declare -f lines); lines 908 | '${SIZES}' --strict --stdin lib/config.sh"
expect_rc "file above its ceiling fails" 1 bash -c "$(declare -f lines); lines 909 | '${SIZES}' --strict --stdin lib/config.sh"
expect_rc "shrink without lowering the ceiling fails" 1 bash -c "$(declare -f lines); lines 905 | '${SIZES}' --strict --stdin lib/config.sh"
expect_rc "file back under the cap must drop its ceiling" 1 bash -c "$(declare -f lines); lines 880 | '${SIZES}' --strict --stdin lib/config.sh"
expect_rc "current tree passes the ratchet" 0 "${SIZES}" --strict

# --- shell complexity: length <= 535, nesting <= 7 ---
expect_rc "nesting 7 passes" 0 bash -c "$(declare -f nested); nested 7 | '${COMPLEXITY}' --stdin lib/x.sh"
expect_rc "nesting 8 fails" 1 bash -c "$(declare -f nested); nested 8 | '${COMPLEXITY}' --stdin lib/x.sh"
expect_rc "535-line function passes" 0 bash -c "(echo 'g() {'; yes ':' | head -n 533; echo '}') | '${COMPLEXITY}' --stdin lib/x.sh"
expect_rc "536-line function fails" 1 bash -c "(echo 'g() {'; yes ':' | head -n 534; echo '}') | '${COMPLEXITY}' --stdin lib/x.sh"
expect_rc "keywords in strings and heredocs do not count" 0 bash -c "printf '%s\n' 'h() {' \"  echo 'if if if if if if if if if'\" '  cat <<TXT' 'if' 'if' 'if' 'if' 'if' 'if' 'if' 'if' 'TXT' '}' | '${COMPLEXITY}' --stdin lib/x.sh"
expect_rc "current tree passes complexity" 0 "${COMPLEXITY}"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[[ "${_FAIL}" -eq 0 ]]
