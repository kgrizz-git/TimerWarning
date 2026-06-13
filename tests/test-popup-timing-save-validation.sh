#!/bin/bash

###############################################################################
# Tests save-time popup timing validation (min display vs frequency).
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-core.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/safety-invariants.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/configure-validation.sh" || exit 1

_PASS=0
_FAIL=0

_pass() { _PASS=$(( _PASS + 1 )); echo "  PASS  $1"; }
_fail() { _FAIL=$(( _FAIL + 1 )); echo "  FAIL  $1"; }

echo "=== Popup timing save validation tests ==="

# min_display 120s > check_interval 1 min (60s) — must fail
if validate_popup_timing_config 120 1 >/dev/null 2>&1; then
    _fail "120s min display with 1 min frequency should be invalid"
else
    _pass "120s min display with 1 min frequency rejected"
fi

# Equal boundary: 60s min + 1 min freq — allowed (documented in test-enhancement-09)
if validate_popup_timing_config 60 1 >/dev/null 2>&1; then
    _pass "60s min display with 1 min frequency allowed at boundary"
else
    _fail "60s min display with 1 min frequency should be valid at boundary"
fi

# Normal valid combo
if validate_popup_timing_config 30 10 >/dev/null 2>&1; then
    _pass "30s min display with 10 min frequency valid"
else
    _fail "30s min display with 10 min frequency should be valid"
fi

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
