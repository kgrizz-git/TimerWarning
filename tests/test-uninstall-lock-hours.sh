#!/usr/bin/env bash
#
# tests/test-uninstall-lock-hours.sh
#
# Purpose:
#   Integration test for Enhancement #18: uninstall.sh during lock hours.
#   Verifies that uninstall.sh can restore permissions and uninstall successfully
#   even when the config file is locked.
#
# Safety:
#   This test DOES NOT touch your real installed config or systemd services.
#   It runs against an isolated temporary HOME directory and does NOT actually
#   uninstall anything from the real system.
#
# Usage:
#   ./tests/test-uninstall-lock-hours.sh
#
# Notes:
#   These tests use the *current* system time (day/hour) and write a config that
#   makes the lock active "right now", so no clock mocking is needed.
#   This test does NOT actually run uninstall.sh (which would affect systemd),
#   but instead tests the restore_config_permissions() function logic.

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

# Function to restore config permissions (same logic as uninstall.sh)
restore_config_permissions() {
    local config_dir_locked="${CONFIG_DIR}/config"
    local config_file="${config_dir_locked}/sleep-warning.conf"
    local marker_file="${CONFIG_DIR}/.config_locked"
    local snapshot_file="${CONFIG_DIR}/.config_locked_snapshot"

    # Always try to make marker/snapshot writable first (ignore errors)
    chmod 644 "${marker_file}" 2>/dev/null || true
    chmod 644 "${snapshot_file}" 2>/dev/null || true

    local dir_mode="755"
    local file_mode="644"

    # If marker exists, try to restore the original modes for completeness
    if [ -f "${marker_file}" ]; then
        local marker_content
        marker_content=$(cat "${marker_file}" 2>/dev/null)

        if echo "${marker_content}" | grep -q "DIR_MODE="; then
            dir_mode=$(echo "${marker_content}" | sed -n 's/.*DIR_MODE=\([0-7]\{3,4\}\).*/\1/p' 2>/dev/null || echo "755")
        fi
        if echo "${marker_content}" | grep -q "FILE_MODE="; then
            file_mode=$(echo "${marker_content}" | sed -n 's/.*FILE_MODE=\([0-7]\{3,4\}\).*/\1/p' 2>/dev/null || echo "644")
        fi
    fi

    # Validate modes (fallback to safe defaults)
    if ! [[ "${dir_mode}" =~ ^[0-7]{3,4}$ ]]; then
        dir_mode="755"
    fi
    if ! [[ "${file_mode}" =~ ^[0-7]{3,4}$ ]]; then
        file_mode="644"
    fi

    # Restore directory/file permissions (ignore errors)
    if [ -d "${config_dir_locked}" ]; then
        chmod "${dir_mode}" "${config_dir_locked}" 2>/dev/null || chmod 755 "${config_dir_locked}" 2>/dev/null || true
    fi

    if [ -f "${config_file}" ]; then
        chmod "${file_mode}" "${config_file}" 2>/dev/null || chmod 644 "${config_file}" 2>/dev/null || true
    fi

    # Remove marker and snapshot files
    rm -f "${marker_file}" 2>/dev/null || true
    rm -f "${snapshot_file}" 2>/dev/null || true
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

echo "=== Test: Uninstall during lock hours (restore permissions) ==="

# Set non-default permissions to verify restoration
chmod 700 "${CONFIG_DIR}/config"
chmod 600 "${CONFIG_FILE}" 2>/dev/null || true

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

# Verify files are locked
if [ -w "${CONFIG_DIR}/config" ]; then
  fail "Config directory should be locked"
fi
if [ -w "${CONFIG_FILE}" ]; then
  fail "Config file should be locked"
fi

# Test restore function (simulates uninstall.sh behavior)
echo "Calling restore_config_permissions()..."
restore_config_permissions

# Verify permissions are restored
if [ ! -w "${CONFIG_DIR}/config" ]; then
  fail "Config directory should be writable after restore"
fi
if [ ! -w "${CONFIG_FILE}" ]; then
  fail "Config file should be writable after restore"
fi

# Verify marker and snapshot are removed
if [ -f "${CONFIG_DIR}/.config_locked" ]; then
  fail "Marker file should be removed after restore"
fi
if [ -f "${CONFIG_DIR}/.config_locked_snapshot" ]; then
  fail "Snapshot file should be removed after restore"
fi

# Verify original permissions were restored
actual_dir_mode="$(stat -c '%a' "${CONFIG_DIR}/config" 2>/dev/null || true)"
if [ "${actual_dir_mode}" != "700" ]; then
  fail "Directory mode should be restored to 700, got ${actual_dir_mode}"
fi

actual_file_mode="$(stat -c '%a' "${CONFIG_FILE}" 2>/dev/null || true)"
if [ "${actual_file_mode}" != "600" ]; then
  fail "File mode should be restored to 600, got ${actual_file_mode}"
fi

echo "OK: Permissions restored correctly during lock hours"

echo ""
echo "=== Test: Uninstall with missing marker file (safe defaults) ==="

# Re-lock
apply_config_directory_lock

# Delete marker file (simulating corruption or missing file)
chmod 644 "${CONFIG_DIR}/.config_locked" 2>/dev/null || true
rm -f "${CONFIG_DIR}/.config_locked"

# Test restore function with missing marker
echo "Calling restore_config_permissions() with missing marker..."
restore_config_permissions

# Verify permissions are restored (should use safe defaults 755/644)
if [ ! -w "${CONFIG_DIR}/config" ]; then
  fail "Config directory should be writable after restore (safe default)"
fi
if [ ! -w "${CONFIG_FILE}" ]; then
  fail "Config file should be writable after restore (safe default)"
fi

# Verify safe defaults were used (755/644)
actual_dir_mode="$(stat -c '%a' "${CONFIG_DIR}/config" 2>/dev/null || true)"
if [ "${actual_dir_mode}" != "755" ]; then
  fail "Directory mode should use safe default 755, got ${actual_dir_mode}"
fi

actual_file_mode="$(stat -c '%a' "${CONFIG_FILE}" 2>/dev/null || true)"
if [ "${actual_file_mode}" != "644" ]; then
  fail "File mode should use safe default 644, got ${actual_file_mode}"
fi

echo "OK: Safe defaults used when marker file is missing"

echo ""
echo "OK: All uninstall lock hours tests passed."
