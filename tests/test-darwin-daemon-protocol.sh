#!/bin/bash
# Non-GUI tests for configure-dialogs-darwin-daemon.py stdin/stdout protocol.
# Does not open table/time/text dialogs (headless-safe).
#
# Usage: ./tests/test-darwin-daemon-protocol.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAEMON="${SCRIPT_DIR}/lib/configure-dialogs-darwin-daemon.py"

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

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not available"
    exit 0
fi

if ! python3 -c "import tkinter" >/dev/null 2>&1; then
    echo "SKIP: tkinter not available"
    exit 0
fi

if [ ! -f "${DAEMON}" ]; then
    echo "FAIL: daemon script missing at ${DAEMON}"
    exit 1
fi

# --- ready handshake ---
coproc DAEMON_PROC { python3 "${DAEMON}"; }
DAEMON_RFD=${DAEMON_PROC[0]}
DAEMON_WFD=${DAEMON_PROC[1]}
DAEMON_PID=${DAEMON_PROC_PID}

cleanup_daemon() {
    { printf '{"op":"quit"}\n' >&"${DAEMON_WFD}"; } 2>/dev/null || true
    read -r -t 2 -u "${DAEMON_RFD}" _ 2>/dev/null || true
    kill "${DAEMON_PID}" 2>/dev/null || true
    wait "${DAEMON_PID}" 2>/dev/null || true
}
trap cleanup_daemon EXIT

if ! read -r -t 10 -u "${DAEMON_RFD}" ready_line; then
    echo "FAIL: daemon ready line timeout"
    exit 1
fi

ready_ok=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print("yes" if d.get("ready") else "no")' "${ready_line}" 2>/dev/null || echo "no")
assert_eq "daemon ready handshake" "yes" "${ready_ok}"

# --- invalid JSON → error response, daemon stays alive ---
printf '%s\n' 'not-json' >&"${DAEMON_WFD}"
if ! read -r -t 5 -u "${DAEMON_RFD}" err_line; then
    echo "FAIL: daemon error response timeout"
    exit 1
fi
err_ok=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print("yes" if d.get("error") else "no")' "${err_line}" 2>/dev/null || echo "no")
assert_eq "invalid json returns error" "yes" "${err_ok}"

# --- quit ---
printf '{"op":"quit"}\n' >&"${DAEMON_WFD}"
if ! read -r -t 5 -u "${DAEMON_RFD}" quit_line; then
    echo "FAIL: daemon quit response timeout"
    exit 1
fi
quit_ok=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print("yes" if d.get("quit") else "no")' "${quit_line}" 2>/dev/null || echo "no")
assert_eq "daemon quit response" "yes" "${quit_ok}"

trap - EXIT
wait "${DAEMON_PID}" 2>/dev/null || true

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
