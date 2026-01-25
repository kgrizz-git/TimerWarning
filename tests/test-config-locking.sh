#!/usr/bin/env bash
#
# tests/test-config-locking.sh
#
# Purpose:
#   Lightweight integration tests for Enhancement #18 (config file locking).
#   Verifies that:
#     - Lock applies (config dir/file become non-writable)
#     - Marker/snapshot files are created
#     - Unlock restores original permissions and removes marker/snapshot
#
# Safety:
#   This test DOES NOT touch your real installed config.
#   It runs against an isolated temporary HOME directory.
#
# Usage:
#   ./tests/test-config-locking.sh
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

assert_file_exists() {
  local path="$1"
  [ -f "${path}" ] || fail "Expected file to exist: ${path}"
}

assert_dir_exists() {
  local path="$1"
  [ -d "${path}" ] || fail "Expected directory to exist: ${path}"
}

assert_not_writable() {
  local path="$1"
  if [ -w "${path}" ]; then
    fail "Expected NOT writable: ${path}"
  fi
}

assert_writable() {
  local path="$1"
  if [ ! -w "${path}" ]; then
    fail "Expected writable: ${path}"
  fi
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

# Source the same modules the real scripts use.
# (Do not source sleep-warning.sh or configure.sh; they may touch systemd/user session state.)
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/time-validation.sh"
source "${SCRIPT_DIR}/lib/config-locking.sh"

# config.sh defines CONFIG_DIR but does not create it. Create it here since we run under a temp HOME.
mkdir -p "${CONFIG_DIR}"

assert_dir_exists "${CONFIG_DIR}"

config_parent_dir="${CONFIG_DIR}"
config_locked_dir="${CONFIG_DIR}/config"
config_file="${CONFIG_FILE}"
marker_file="${CONFIG_DIR}/.config_locked"
snapshot_file="${CONFIG_DIR}/.config_locked_snapshot"

mkdir -p "${config_locked_dir}"

# --- Unit-ish checks (Phase 8.1) ---
echo "Checking get_config_lock_enabled() defaults..."
# With no config file, the value should fall back to DEFAULT_CONFIG_LOCK_ENABLED (false).
if [ "$(get_config_lock_enabled)" != "false" ]; then
  fail "Expected get_config_lock_enabled default 'false' when config missing"
fi

# Set non-default perms so we can verify restoration.
chmod 700 "${config_locked_dir}"

echo "Checking get_config_lock_enabled() normalization..."
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=TRUE
EOF
chmod 600 "${config_file}"

if [ "$(get_config_lock_enabled)" != "true" ]; then
  fail "Expected get_config_lock_enabled to normalize TRUE -> true"
fi

echo "Checking get_config_lock_enabled() invalid values..."
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=maybe
EOF
chmod 600 "${config_file}"

if [ "$(get_config_lock_enabled)" != "false" ]; then
  fail "Expected get_config_lock_enabled to fall back to default on invalid value"
fi

# Make restrictions cover "right now"
current_day="$(date +%w)"
current_hour="$(date +%H)"
current_hour="$((10#${current_hour}))"
end_hour="$(( (current_hour + 1) % 24 ))"
day_name="$(day_name_from_num "${current_day}")"

echo "Checking is_config_lock_active() for restricted hours..."
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"

if ! is_config_lock_active; then
  fail "Expected is_config_lock_active to be active during restricted hours"
fi

echo "Checking is_config_lock_active() for lock hours only..."
# Disable restrictions by explicitly setting current day + previous day empty, then enable lock hours.
prev_day="$(( (current_day + 6) % 7 ))"
prev_day_name="$(day_name_from_num "${prev_day}")"
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${prev_day_name}=
${day_name}=
CONFIG_LOCK_HOURS_${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"

if ! is_config_lock_active; then
  fail "Expected is_config_lock_active to be active during CONFIG_LOCK_HOURS_* (lock hours only)"
fi

echo "Checking CONFIG_LOCK_ENABLED=false disables lock..."
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
${day_name}=${current_hour}-${end_hour}
CONFIG_LOCK_HOURS_${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"

if is_config_lock_active; then
  fail "Expected is_config_lock_active to be inactive when CONFIG_LOCK_ENABLED=false"
fi

# Restore config to enabled + lock hours for the actual lock/unlock test below
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${prev_day_name}=
${day_name}=
CONFIG_LOCK_HOURS_${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"

echo "Running lock apply..."
apply_config_directory_lock

assert_dir_exists "${config_locked_dir}"
assert_file_exists "${config_file}"
assert_file_exists "${marker_file}"

assert_not_writable "${config_locked_dir}"
assert_not_writable "${config_file}"
assert_not_writable "${marker_file}"

# Snapshot is best-effort; should exist if config file existed at lock start.
assert_file_exists "${snapshot_file}"

echo "Checking idempotency (lock apply twice)..."
apply_config_directory_lock
assert_file_exists "${marker_file}"

echo "Verifying writes are blocked..."
# Note: redirect error at the subshell level because permission errors come from the redirection itself.
if (echo "SHOULD_NOT_WRITE" >> "${config_file}") 2>/dev/null; then
  fail "Was able to write to locked config file"
fi

echo "Running unlock apply (by disabling CONFIG_LOCK_ENABLED)..."
# For testing unlock, temporarily make file writable so we can flip the flag.
# (chmod does not require the directory to be writable; only accessible.)
chmod 644 "${config_file}"

# Avoid sed -i here: it typically creates a temp file in the same directory, which
# is intentionally non-writable while locked. Overwrite the file content directly.
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
${day_name}=${current_hour}-${end_hour}
EOF

apply_config_directory_lock

assert_dir_exists "${config_locked_dir}"
assert_file_exists "${config_file}"

# Marker/snapshot should be cleaned up on unlock.
if [ -f "${marker_file}" ]; then
  fail "Marker file still present after unlock: ${marker_file}"
fi
if [ -f "${snapshot_file}" ]; then
  fail "Snapshot file still present after unlock: ${snapshot_file}"
fi

# Original permissions should be restored (from marker state).
expected_dir_mode="700"
expected_file_mode="600"
actual_dir_mode="$(stat -c '%a' "${config_locked_dir}" 2>/dev/null || true)"
actual_file_mode="$(stat -c '%a' "${config_file}" 2>/dev/null || true)"

if [ "${actual_dir_mode}" != "${expected_dir_mode}" ]; then
  fail "Dir mode mismatch: expected ${expected_dir_mode}, got ${actual_dir_mode}"
fi
if [ "${actual_file_mode}" != "${expected_file_mode}" ]; then
  fail "File mode mismatch: expected ${expected_file_mode}, got ${actual_file_mode}"
fi

assert_writable "${config_file}"

echo "OK: Enhancement #18 basic lock/unlock test passed."

