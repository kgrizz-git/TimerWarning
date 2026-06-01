#!/bin/bash
# Headless tests for bash-level daemon JSON field parsing (A1 hybrid parser).
#
# Usage: ./tests/test-darwin-response-parse.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/configure-dialogs-darwin.sh
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

# --- ready handshake (bash, no python3) ---
ready_line='{"ok": true, "ready": true}'
if _cd_darwin_json_field_true "${ready_line}" "ready"; then
    echo "PASS: ready field detected via bash"
    pass=$((pass + 1))
else
    echo "FAIL: ready field detected via bash"
    fail=$((fail + 1))
fi

# --- table success response ---
_CD_DARWIN_DAEMON_LAST_RESPONSE='{"ok": true, "value": "Monday", "shown": true, "cancelled": false}'
_cd_darwin_parse_last_response
assert_eq "parse ok=yes" "yes" "${_CD_RESP_OK}"
assert_eq "parse cancelled=no" "no" "${_CD_RESP_CANCELLED}"
assert_eq "parse shown=yes" "yes" "${_CD_RESP_SHOWN}"
value=$(_cd_darwin_response_extract_value)
assert_eq "parse value Monday" "Monday" "${value}"

# --- simple value does not need python3 ---
_cd_darwin_parse_last_response
value=$(PATH=/nonexistent _cd_darwin_response_extract_value)
assert_eq "simple value parse without python3" "Monday" "${value}"

# --- cancel response ---
_CD_DARWIN_DAEMON_LAST_RESPONSE='{"ok": false, "cancelled": true, "shown": true}'
_cd_darwin_parse_last_response
assert_eq "cancel ok=no" "no" "${_CD_RESP_OK}"
assert_eq "cancel cancelled=yes" "yes" "${_CD_RESP_CANCELLED}"
assert_eq "cancel shown=yes" "yes" "${_CD_RESP_SHOWN}"

# --- invisible daemon failure (shown false) ---
_CD_DARWIN_DAEMON_LAST_RESPONSE='{"ok": false, "cancelled": true, "shown": false}'
_cd_darwin_parse_last_response
assert_eq "invisible shown=no" "no" "${_CD_RESP_SHOWN}"

# --- unicode / embedded quotes in value (python extract) ---
_CD_DARWIN_DAEMON_LAST_RESPONSE='{"ok": true, "value": "9:00am–5:00pm", "shown": true}'
_cd_darwin_parse_last_response
value=$(_cd_darwin_response_extract_value)
assert_eq "unicode value preserved" "9:00am–5:00pm" "${value}"

# --- escaped values still use JSON parser fallback ---
_CD_DARWIN_DAEMON_LAST_RESPONSE='{"ok": true, "value": "A \"quoted\" value", "shown": true}'
_cd_darwin_parse_last_response
value=$(_cd_darwin_response_extract_value)
assert_eq "escaped quote value preserved" 'A "quoted" value' "${value}"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
