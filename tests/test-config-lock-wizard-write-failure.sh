#!/usr/bin/env bash
#
# Regression test for configure wizard saves during config-lock hours.
#
# The wizard temporarily restores write permissions before an atomic config
# write. If the write fails after that point, it must still run the matching
# finish hook so the config directory/file are re-locked immediately.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${ROOT}/tests/.tmp"
mkdir -p "${TMP_BASE}"
TMP_HOME="$(mktemp -d -p "${TMP_BASE}" config-lock-write.XXXXXX)"

cleanup() {
    rm -rf "${TMP_HOME}" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

export HOME="${TMP_HOME}"
CONFIG_DIR="${HOME}/.config/sleep-warning"
CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
mkdir -p "${CONFIG_DIR}/config"

# shellcheck disable=SC1091
source "${ROOT}/lib/config-keys.sh"
# shellcheck disable=SC1091
source "${ROOT}/lib/configure-config-write.sh"

THRESHOLD_WARN=6720
get_threshold_warn_description() {
    echo "16 hours/day"
}

prepare_calls=0
finish_calls=0

config_lock_prepare_for_wizard_write() {
    prepare_calls=$((prepare_calls + 1))
    return 0
}

config_lock_finish_wizard_write() {
    finish_calls=$((finish_calls + 1))
    return 0
}

# Force the atomic replacement step to fail after the prepare hook has run.
mv() {
    return 1
}

config_lines=("SUNDAY=0-5" "MONDAY=" "TUESDAY=" "WEDNESDAY=" "THURSDAY=" "FRIDAY=" "SATURDAY=")
lock_hours_lines=(
    "CONFIG_LOCK_HOURS_SUNDAY="
    "CONFIG_LOCK_HOURS_MONDAY="
    "CONFIG_LOCK_HOURS_TUESDAY="
    "CONFIG_LOCK_HOURS_WEDNESDAY="
    "CONFIG_LOCK_HOURS_THURSDAY="
    "CONFIG_LOCK_HOURS_FRIDAY="
    "CONFIG_LOCK_HOURS_SATURDAY="
)
uninstall_lock_hours_lines=(
    "UNINSTALL_LOCK_HOURS_SUNDAY="
    "UNINSTALL_LOCK_HOURS_MONDAY="
    "UNINSTALL_LOCK_HOURS_TUESDAY="
    "UNINSTALL_LOCK_HOURS_WEDNESDAY="
    "UNINSTALL_LOCK_HOURS_THURSDAY="
    "UNINSTALL_LOCK_HOURS_FRIDAY="
    "UNINSTALL_LOCK_HOURS_SATURDAY="
)

if write_config \
    "10" "medium" "center" "30" "true" "false" "true" "none" "true" "5" "24" "auto" "true" \
    "fixed" "50%x50%" "1280x720" \
    "${config_lines[@]}" "${lock_hours_lines[@]}" "${uninstall_lock_hours_lines[@]}" "false" "false" "false" "false"; then
    fail "write_config unexpectedly succeeded when mv failed"
fi

if [ "${prepare_calls}" -ne 1 ]; then
    fail "expected prepare hook once, got ${prepare_calls}"
fi

if [ "${finish_calls}" -ne 1 ]; then
    fail "expected finish hook once after failed write, got ${finish_calls}"
fi

echo "OK: failed wizard config writes run the lock finish hook"
