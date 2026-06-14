#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "${TMP_DIR}/lib"
cp "${ROOT_DIR}/lib/scheduler-platform.sh" "${TMP_DIR}/lib/scheduler-platform.sh"
cat > "${TMP_DIR}/lib/service-config-darwin.sh" <<'STUB'
disable_scheduled_service() {
    return 42
}
remove_launch_agent() {
    return 43
}
STUB

source "${TMP_DIR}/lib/scheduler-platform.sh"

uname() {
    if [ "${1:-}" = "-s" ]; then
        echo Darwin
    else
        command uname "$@"
    fi
}

if scheduler_stop_and_disable; then
    fail "scheduler_stop_and_disable returned success after disable_scheduled_service failed"
fi

if scheduler_remove_files; then
    fail "scheduler_remove_files returned success after remove_launch_agent failed"
fi

echo "OK: Darwin scheduler wrapper propagates failure status"
