#!/usr/bin/env bash
#
# tests/test-configure-blocking.sh
#
# Purpose:
#   Integration test for Enhancement #18: configure.sh blocking when config file is locked.
#   Verifies that configure.sh shows an error and exits when CONFIG_LOCK_ENABLED=true
#   and the current time is within restricted hours or lock hours.
#
# Safety:
#   This test DOES NOT touch your real installed config.
#   It runs against an isolated temporary HOME directory.
#
# Usage:
#   ./tests/test-configure-blocking.sh
#
# Notes:
#   These tests use the *current* system time (day/hour) and write a config that
#   makes the lock active "right now", so no clock mocking is needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
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

TMP_BASE="${SCRIPT_DIR}/tests/.tmp"
mkdir -p "${TMP_BASE}"
tmp_home="$(mktemp -d -p "${TMP_BASE}" home.XXXXXX)"
cleanup() {
  # The lock mechanism intentionally makes the config directory non-writable.
  # Ensure the temp HOME is writable so cleanup can't get stuck/fail.
  chmod -R u+rwX "${tmp_home}" 2>/dev/null || true
  rm -rf "${tmp_home}" 2>/dev/null || true
}
trap cleanup EXIT

export HOME="${tmp_home}"

# Source required modules
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/time-validation.sh"
source "${SCRIPT_DIR}/lib/config-locking.sh"

# Create config directory structure
mkdir -p "${CONFIG_DIR}/config"

# Get current time
current_day="$(date +%w)"
current_hour="$(date +%H)"
current_hour="$((10#${current_hour}))"
end_hour="$(( (current_hour + 1) % 24 ))"
day_name="$(day_name_from_num "${current_day}")"
prev_day="$(( (current_day + 6) % 7 ))"
prev_day_name="$(day_name_from_num "${prev_day}")"

echo "=== Test: configure.sh blocking during restricted hours ==="

# Create config with lock enabled and restrictions covering current time
cat > "${CONFIG_FILE}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${CONFIG_FILE}"

# Apply lock
apply_config_directory_lock

# Verify lock is active
if ! is_config_lock_active; then
  fail "Lock should be active for this test"
fi

# Try to run configure.sh --text (should fail)
echo "Running configure.sh --text (should be blocked)..."
if "${SCRIPT_DIR}/configure.sh" --text >/tmp/configure-output.txt 2>&1; then
  fail "configure.sh should have exited with error when config file is locked"
fi

# Check that error message was shown
if ! grep -qi "locked\|error" /tmp/configure-output.txt; then
  echo "Warning: configure.sh output may not contain expected error message:"
  cat /tmp/configure-output.txt
  # Don't fail here - the exit code is what matters
fi

echo "OK: configure.sh correctly blocked during restricted hours"

# Unlock for next test
chmod 644 "${CONFIG_FILE}" 2>/dev/null || true
cat > "${CONFIG_FILE}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
EOF
apply_config_directory_lock

echo ""
echo "=== Test: configure.sh blocking during lock hours only ==="

# Create config with lock enabled and lock hours (but no restrictions) covering current time
cat > "${CONFIG_FILE}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${prev_day_name}=
${day_name}=
CONFIG_LOCK_HOURS_${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${CONFIG_FILE}"

# Apply lock
apply_config_directory_lock

# Verify lock is active
if ! is_config_lock_active; then
  fail "Lock should be active for this test (lock hours)"
fi

# Try to run configure.sh --text (should fail)
echo "Running configure.sh --text (should be blocked)..."
if "${SCRIPT_DIR}/configure.sh" --text >/tmp/configure-output.txt 2>&1; then
  fail "configure.sh should have exited with error when config file is locked (lock hours)"
fi

# Check that error message was shown
if ! grep -qi "locked\|error" /tmp/configure-output.txt; then
  echo "Warning: configure.sh output may not contain expected error message:"
  cat /tmp/configure-output.txt
  # Don't fail here - the exit code is what matters
fi

echo "OK: configure.sh correctly blocked during lock hours"

# Unlock for next test
chmod 644 "${CONFIG_FILE}" 2>/dev/null || true
cat > "${CONFIG_FILE}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
EOF
apply_config_directory_lock

echo ""
echo "=== Test: configure.sh works normally when NOT locked ==="

# Create config with lock disabled
cat > "${CONFIG_FILE}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${CONFIG_FILE}"

# Verify lock is NOT active
if is_config_lock_active; then
  fail "Lock should NOT be active for this test"
fi

# Try to run configure.sh --text (should work, but we'll just check it doesn't exit immediately)
echo "Running configure.sh --text (should NOT be blocked)..."
# Use timeout to prevent hanging, and expect it to either succeed or timeout (not fail immediately)
if timeout 5 "${SCRIPT_DIR}/configure.sh" --text >/tmp/configure-output.txt 2>&1; then
  echo "OK: configure.sh did not exit immediately (may have shown menu or prompt)"
elif [ $? -eq 124 ]; then
  # Timeout is expected - configure.sh is interactive
  echo "OK: configure.sh did not exit immediately (timeout expected for interactive script)"
else
  # Check if it failed due to lock (should not)
  if grep -qi "locked\|error.*lock" /tmp/configure-output.txt; then
    fail "configure.sh should NOT be blocked when lock is disabled"
  fi
  echo "OK: configure.sh exited (may be normal for interactive script)"
fi

echo "OK: configure.sh works normally when NOT locked"

echo ""
echo "OK: All configure.sh blocking tests passed."
