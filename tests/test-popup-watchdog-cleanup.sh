#!/usr/bin/env bash
#
# Regression: Linux pause early-return must cancel the absolute PID-file watchdog so
# a later popup PID is not killed when the stale watchdog fires.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

TMP_BASE="${ROOT_DIR}/tests/.tmp"
mkdir -p "${TMP_BASE}"
tmp_home="$(mktemp -d -p "${TMP_BASE}" home.XXXXXX)"
POPUP_PID_FILE="${tmp_home}/popup.pid"
export POPUP_PID_FILE

cleanup() {
    chmod -R u+rwX "${tmp_home}" 2>/dev/null || true
    rm -rf "${tmp_home}" 2>/dev/null || true
}
trap cleanup EXIT

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/popup-safety.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/popup-pid-management.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/popup-display-linux.sh"

pause_available=true
pause_duration=1
popup_auto_close=false

popup_start_pid_file_watchdog 3 "${POPUP_PID_FILE}" >/dev/null
_popup_watchdog_pid="${POPUP_WATCHDOG_LAST_PID:-}"
[ -n "${_popup_watchdog_pid}" ] || fail "watchdog did not start"

( sleep 0.2; exit 1 ) &
popup_pid=$!

_popup_maybe_handle_pause_click() { return 0; }

_popup_linux_wait_without_min_display || true

if kill -0 "${_popup_watchdog_pid}" 2>/dev/null; then
    fail "pause early return left absolute watchdog running (pid ${_popup_watchdog_pid})"
fi

sleep 60 &
victim_pid=$!
printf '%s\n' "${victim_pid}" > "${POPUP_PID_FILE}"

sleep 4

if ! kill -0 "${victim_pid}" 2>/dev/null; then
    fail "orphaned watchdog killed unrelated PID ${victim_pid}"
fi

kill "${victim_pid}" 2>/dev/null || true
wait "${victim_pid}" 2>/dev/null || true

echo "OK: pause early return cancels Linux popup watchdog"
