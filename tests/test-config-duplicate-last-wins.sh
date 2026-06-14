#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_HOME}"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

export HOME="${TMP_HOME}"
source "${ROOT_DIR}/lib/configure-core.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/configure-config-load.sh"

mkdir -p "$(dirname "${CONFIG_FILE}")"
cat > "${CONFIG_FILE}" <<'CONF'
MONDAY=20:00-21:00
MONDAY=22:00-23:00
CONFIG_LOCK_HOURS_MONDAY=08:00-09:00
CONFIG_LOCK_HOURS_MONDAY=10:00-11:00
UNINSTALL_LOCK_HOURS_MONDAY=12:00-13:00
UNINSTALL_LOCK_HOURS_MONDAY=14:00-15:00
CONF

set +e
load_existing_config
set -e

[ "${config_lines[1]:-}" = "MONDAY=22:00-23:00" ] || fail "configure loader did not use last MONDAY entry: '${config_lines[1]:-}'"
[ "${lock_hours_lines[1]:-}" = "CONFIG_LOCK_HOURS_MONDAY=10:00-11:00" ] || fail "configure loader did not use last lock-hours entry: '${lock_hours_lines[1]:-}'"
[ "${uninstall_lock_hours_lines[1]:-}" = "UNINSTALL_LOCK_HOURS_MONDAY=14:00-15:00" ] || fail "configure loader did not use last uninstall-lock entry: '${uninstall_lock_hours_lines[1]:-}'"

echo "OK: duplicate config keys use last matching entry"
