#!/usr/bin/env bash
#
# tests/test-configure-blocking.sh
#
# Purpose:
#   Integration test for configure.sh during config-file lock / lock hours.
#   Since partial-lock redesign (tighten-only mode), configure.sh --text enters
#   LIMITED CONFIGURATION MODE instead of exiting immediately.
#
# Safety:
#   This test DOES NOT touch your real installed config.
#   It runs against an isolated temporary HOME directory.
#
# Usage:
#   ./tests/test-configure-blocking.sh
#
# Notes:
#   Uses current system time; configs are built so lock is active "right now".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/test-run-timeout.sh
source "${SCRIPT_DIR}/tests/lib/test-run-timeout.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "OK: $*"
}

day_name_from_num() {
  local day_num="$1"
  case "${day_num}" in
    0) echo "SUNDAY" ;;
    1) echo "MONDAY" ;;
    2) echo "TUESDAY" ;;
    3) echo "WEDNESDAY" ;;
    4) echo "THURSDAY" ;;
    5) echo "FRIDAY" ;;
    6) echo "SATURDAY" ;;
    *) return 1 ;;
  esac
}

assert_limited_mode_banner() {
  local outfile="$1"
  if ! grep -q "LIMITED CONFIGURATION MODE (lock hours)" "${outfile}"; then
    echo "Expected partial-lock banner in output:" >&2
    cat "${outfile}" >&2
    fail "missing LIMITED CONFIGURATION MODE banner"
  fi
  if ! grep -qi "tighten-only\|tighten only\|lock hours active" "${outfile}"; then
    echo "Expected tighten-only messaging in output:" >&2
    cat "${outfile}" >&2
    fail "missing tighten-only partial-lock messaging"
  fi
}

assert_no_immediate_full_block() {
  local outfile="$1"
  if grep -qi "configure.sh.*blocked\|cannot run.*configuration.*blocked" "${outfile}"; then
    echo "Unexpected full-block message (partial lock should allow entry):" >&2
    cat "${outfile}" >&2
    fail "configure.sh exited with legacy full-block messaging"
  fi
}

run_configure_text() {
  local seconds="$1"
  local outfile="$2"
  shift 2
  local input="$1"
  export CONFIGURE_TEST_INPUT="${input}"
  # Intentional single-quoted bash -c body: expand via exported env, not commit-time quoting.
  # shellcheck disable=SC2016
  test_run_with_timeout "${seconds}" bash -c \
    'printf "%b" "${CONFIGURE_TEST_INPUT}" | "${CONFIGURE_SCRIPT}" --text' \
    >"${outfile}" 2>&1
}
export CONFIGURE_SCRIPT="${SCRIPT_DIR}/configure.sh"

TMP_BASE="${SCRIPT_DIR}/tests/.tmp"
mkdir -p "${TMP_BASE}"
tmp_home="$(mktemp -d -p "${TMP_BASE}" home.XXXXXX)"
OUT_FILE="$(mktemp -p "${TMP_BASE}" configure-blocking.XXXXXX)"

cleanup() {
  chmod -R u+rwX "${tmp_home}" 2>/dev/null || true
  rm -rf "${tmp_home}" 2>/dev/null || true
  rm -f "${OUT_FILE}" 2>/dev/null || true
}
trap cleanup EXIT

export HOME="${tmp_home}"

# Source required modules
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/time-validation.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/config-locking.sh"

mkdir -p "${CONFIG_DIR}/config"

current_day="$(date +%w)"
current_hour="$(date +%H)"
current_hour="$((10#${current_hour}))"
end_hour="$(( (current_hour + 1) % 24 ))"
day_name="$(day_name_from_num "${current_day}")"
prev_day="$(( (current_day + 6) % 7 ))"
prev_day_name="$(day_name_from_num "${prev_day}")"

echo "=== Test: partial lock during restricted hours (file lock + restrictions) ==="

cat > "${CONFIG_FILE}" <<EOF
# Integration test — partial configure lock
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${CONFIG_FILE}"
apply_config_directory_lock

if ! is_config_lock_active; then
  fail "Lock should be active for this test"
fi

echo "Running configure.sh --text (expect limited mode + interactive menu)..."
set +e
run_configure_text 8 "${OUT_FILE}" $'\n'
rc=$?
set -e

assert_no_immediate_full_block "${OUT_FILE}"
assert_limited_mode_banner "${OUT_FILE}"

if [ "${rc}" -eq 0 ]; then
  fail "configure.sh should not exit immediately during partial lock (got rc=0)"
fi
if [ "${rc}" -ne 124 ]; then
  echo "Note: rc=${rc} (124=watchdog timeout is expected on macOS/Linux without user input)"
fi
pass "enters limited mode during restricted hours (did not hard-block at startup)"

chmod 644 "${CONFIG_FILE}" 2>/dev/null || true
cat > "${CONFIG_FILE}" <<EOF
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
EOF
apply_config_directory_lock

echo ""
echo "=== Test: partial lock during CONFIG_LOCK_HOURS only ==="

cat > "${CONFIG_FILE}" <<EOF
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${prev_day_name}=
${day_name}=
CONFIG_LOCK_HOURS_${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${CONFIG_FILE}"
apply_config_directory_lock

if ! is_config_lock_active; then
  fail "Lock should be active for this test (lock hours)"
fi

echo "Running configure.sh --text (lock hours only)..."
set +e
run_configure_text 8 "${OUT_FILE}" $'\n'
rc=$?
set -e

assert_no_immediate_full_block "${OUT_FILE}"
assert_limited_mode_banner "${OUT_FILE}"
if [ "${rc}" -eq 0 ]; then
  fail "configure.sh should not exit immediately during partial lock (lock hours)"
fi
pass "enters limited mode during lock hours only"

chmod 644 "${CONFIG_FILE}" 2>/dev/null || true
cat > "${CONFIG_FILE}" <<EOF
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
apply_config_directory_lock

echo ""
echo "=== Test: loosening change rejected during partial lock ==="

echo "Attempting less-frequent popup interval (10 -> 15)..."
set +e
run_configure_text 12 "${OUT_FILE}" $'\n1\n15\n'
set -e

if ! grep -qi "Cannot make popup checks less frequent during lock hours" "${OUT_FILE}"; then
  echo "Output:" >&2
  cat "${OUT_FILE}" >&2
  fail "expected loosening rejection message for check_interval"
fi
pass "rejects loosening check_interval during partial lock"

echo ""
echo "=== Test: tightening change can be saved during partial lock ==="

set +e
run_configure_text 60 "${OUT_FILE}" $'\n1\n5\n13\ny\n'
rc=$?
set -e

if [ "${rc}" -ne 0 ]; then
  echo "configure.sh save run output:" >&2
  cat "${OUT_FILE}" >&2
  fail "tightening save should exit 0 (got rc=${rc})"
fi

saved_interval=""
saved_interval=$(
  grep -E '^[[:space:]]*(POPUP_DISPLAY_FREQUENCY|CHECK_INTERVAL)=' "${CONFIG_FILE}" 2>/dev/null \
    | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' || true
)
if [ "${saved_interval}" != "5" ]; then
  echo "Config file:" >&2
  cat "${CONFIG_FILE}" >&2
  fail "expected POPUP_DISPLAY_FREQUENCY=5 after tighten save (got '${saved_interval}')"
fi
pass "accepts tightening check_interval save during partial lock"

chmod 644 "${CONFIG_FILE}" 2>/dev/null || true
cat > "${CONFIG_FILE}" <<EOF
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
${day_name}=${current_hour}-${end_hour}
EOF
apply_config_directory_lock

echo ""
echo "=== Test: full wizard when NOT in partial lock ==="

if is_config_lock_active; then
  fail "Lock should NOT be active for unrestricted wizard test"
fi

echo "Running configure.sh --text (no partial lock)..."
set +e
run_configure_text 6 "${OUT_FILE}" $'\n'
rc=$?
set -e

if grep -q "LIMITED CONFIGURATION MODE (lock hours)" "${OUT_FILE}"; then
  cat "${OUT_FILE}" >&2
  fail "should not show partial-lock banner when lock is inactive"
fi
if grep -qi "Cannot make popup checks less frequent during lock hours" "${OUT_FILE}"; then
  fail "should not show partial-lock scalar rejection when lock is inactive"
fi
if [ "${rc}" -eq 0 ]; then
  fail "interactive configure should not exit immediately without save/cancel"
fi
pass "normal wizard when partial lock is not active"

echo ""
echo "OK: All configure.sh partial-lock integration tests passed."
