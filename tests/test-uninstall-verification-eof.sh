#!/bin/bash

###############################################################################
# Tests uninstall verification EOF-safe reads (configure_read, not bare read).
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

_PASS=0
_FAIL=0

_pass() { _PASS=$(( _PASS + 1 )); echo "  PASS  $1"; }
_fail() { _FAIL=$(( _FAIL + 1 )); echo "  FAIL  $1"; }

echo "=== Uninstall verification EOF safety tests ==="

# verify_confirmation_phrase must exit quickly on EOF (not spin)
tmp_out=$(mktemp)
if timeout 5 bash -c '
    export HOME=$(mktemp -d)
    source "'"${LIB_DIR}"'/configure-core.sh"
    source "'"${LIB_DIR}"'/uninstall-verification.sh"
    verify_confirmation_phrase false 3
' </dev/null >"${tmp_out}" 2>&1; then
    rc=0
else
    rc=$?
fi

if [ "${rc}" -eq 124 ]; then
    _fail "verify_confirmation_phrase spun on EOF (timeout)"
elif [ "${rc}" -eq 2 ]; then
    _pass "verify_confirmation_phrase returns cancel (2) on EOF"
else
    _fail "verify_confirmation_phrase unexpected exit ${rc} on EOF (output: $(head -5 "${tmp_out}"))"
fi

rm -f "${tmp_out}"

# Source file must not use bare read -p in text-mode paths (configure_read -p is OK)
if grep 'read -p' "${LIB_DIR}/uninstall-verification.sh" | grep -qv configure_read; then
    _fail "uninstall-verification.sh still contains bare read -p"
else
    _pass "uninstall-verification.sh uses configure_read (no bare read -p)"
fi

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
