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
TEST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
# shellcheck disable=SC1091
source "${TEST_LIB_DIR}/test-stat-mode.sh"

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

assert_file_not_exists() {
  local path="$1"
  [ ! -f "${path}" ] || fail "Expected file to NOT exist: ${path}"
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

echo "Checking is_config_lock_active() when enabled but NOT in restricted hours..."
# Set restrictions to a time that's NOT now (e.g., 2 hours from now)
future_hour="$(( (current_hour + 2) % 24 ))"
future_end_hour="$(( (future_hour + 1) % 24 ))"
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${future_hour}-${future_end_hour}
EOF
chmod 600 "${config_file}"

if is_config_lock_active; then
  fail "Expected is_config_lock_active to be inactive when NOT in restricted hours"
fi

echo "Checking is_config_lock_active() for overnight ranges..."
# Test overnight range: previous day 23-6 (11pm to 6am next day)
# If current hour is between 0-5, we should be in the overnight range from previous day
if [ "${current_hour}" -ge 0 ] && [ "${current_hour}" -lt 6 ]; then
  cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${prev_day_name}=23-6
${day_name}=
EOF
  chmod 600 "${config_file}"
  
  if ! is_config_lock_active; then
    fail "Expected is_config_lock_active to be active during overnight range from previous day"
  fi
fi

echo "Checking is_config_lock_active() for multiple ranges per day..."
# Test multiple ranges: e.g., 0-5,22-23
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=0-5,22-23
EOF
chmod 600 "${config_file}"

# Check if current hour is in either range
if [ "${current_hour}" -ge 0 ] && [ "${current_hour}" -lt 6 ]; then
  if ! is_config_lock_active; then
    fail "Expected is_config_lock_active to be active during first range (0-5)"
  fi
elif [ "${current_hour}" -ge 22 ]; then
  if ! is_config_lock_active; then
    fail "Expected is_config_lock_active to be active during second range (22-23)"
  fi
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
actual_dir_mode="$(test_stat_octal_mode "${config_locked_dir}" 2>/dev/null || true)"
actual_file_mode="$(test_stat_octal_mode "${config_file}" 2>/dev/null || true)"

if [ "${actual_dir_mode}" != "${expected_dir_mode}" ]; then
  fail "Dir mode mismatch: expected ${expected_dir_mode}, got ${actual_dir_mode}"
fi
if [ "${actual_file_mode}" != "${expected_file_mode}" ]; then
  fail "File mode mismatch: expected ${expected_file_mode}, got ${actual_file_mode}"
fi

assert_writable "${config_file}"

echo "OK: Enhancement #18 basic lock/unlock test passed."

# --- Edge case tests (Phase 8.3) ---
echo ""
echo "=== Edge Case Tests ==="

# Test with missing config file (lock should still work if directory exists)
echo "Testing lock application when config file doesn't exist initially..."
# Remove config file
rm -f "${config_file}"
# Create config in parent directory temporarily to enable lock
# Actually, we need the config file to exist to read CONFIG_LOCK_ENABLED
# So this test is more about: what if config file is missing but we still try to lock?
# The lock mechanism requires the config file to exist to read settings.
# So we'll test: create config, lock it, then verify directory stays locked
# even if we can't read the file (it's read-only)
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"
# Apply lock
apply_config_directory_lock
# Directory should be locked
assert_not_writable "${config_locked_dir}"
# Marker should exist
assert_file_exists "${marker_file}"
# Snapshot should exist
assert_file_exists "${snapshot_file}"
# Unlock
chmod 644 "${config_file}" 2>/dev/null || true
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
EOF
chmod 600 "${config_file}"
apply_config_directory_lock
assert_writable "${config_locked_dir}"

# Test self-healing: permission re-assertion
echo "Testing self-healing: permission re-assertion..."
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"
apply_config_directory_lock
assert_file_exists "${config_file}"
assert_file_exists "${snapshot_file}"
assert_not_writable "${config_file}"
assert_not_writable "${config_locked_dir}"

# Test that self-healing re-asserts permissions (simulate manual permission change)
# Temporarily unlock to simulate user tampering
chmod 755 "${config_locked_dir}" 2>/dev/null || true
chmod 644 "${config_file}" 2>/dev/null || true
# Verify they're writable now
if [ -w "${config_file}" ] && [ -w "${config_locked_dir}" ]; then
  # Call self-healing - should re-apply lock
  check_and_restore_config_file
  # Permissions should be locked again
  assert_not_writable "${config_file}"
  assert_not_writable "${config_locked_dir}"
  echo "OK: Self-healing re-asserted permissions"
else
  fail "Could not unlock files for self-healing test"
fi

# Unlock for next test
chmod 644 "${config_file}" 2>/dev/null || true
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
EOF
apply_config_directory_lock

# Test missing marker file
echo "Testing missing marker file handling..."
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"
apply_config_directory_lock
assert_file_exists "${marker_file}"
# Delete marker file (simulating tampering)
chmod 644 "${marker_file}" 2>/dev/null || true
rm -f "${marker_file}"
# Re-apply lock - should recreate marker
apply_config_directory_lock
assert_file_exists "${marker_file}"

# Unlock for next test
chmod 644 "${config_file}" 2>/dev/null || true
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
EOF
apply_config_directory_lock

# Test corrupted snapshot file
echo "Testing corrupted snapshot file handling..."
# Unlock first
chmod 644 "${config_file}" 2>/dev/null || true
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"
apply_config_directory_lock
assert_file_exists "${snapshot_file}"
# Corrupt snapshot file (need to make it writable first)
chmod 644 "${snapshot_file}" 2>/dev/null || true
echo "CORRUPTED_DATA_NOT_VALID_CONFIG" > "${snapshot_file}"
chmod 444 "${snapshot_file}" 2>/dev/null || true
# Self-healing should handle gracefully (won't restore from corrupted snapshot)
check_and_restore_config_file
# Original config file should still exist and be valid
assert_file_exists "${config_file}"
# Verify it still has valid content
if ! grep -q "CHECK_INTERVAL=10" "${config_file}"; then
  fail "Config file should still have valid content after corrupted snapshot test"
fi

# Unlock for next test
chmod 644 "${config_file}" 2>/dev/null || true
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
EOF
apply_config_directory_lock

# Test manual permission changes (self-healing)
echo "Testing self-healing: manual permission changes..."
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=true
${day_name}=${current_hour}-${end_hour}
EOF
chmod 600 "${config_file}"
apply_config_directory_lock
assert_not_writable "${config_file}"
assert_not_writable "${config_locked_dir}"

# Manually change permissions (simulating user tampering)
chmod 755 "${config_locked_dir}" 2>/dev/null || true
chmod 644 "${config_file}" 2>/dev/null || true
# Self-healing should re-apply lock
check_and_restore_config_file
assert_not_writable "${config_file}"
assert_not_writable "${config_locked_dir}"

# Unlock
chmod 644 "${config_file}" 2>/dev/null || true
cat > "${config_file}" <<EOF
# Test config for Enhancement #18
CHECK_INTERVAL=10
CONFIG_LOCK_ENABLED=false
EOF
apply_config_directory_lock

echo "OK: All edge case tests passed."

