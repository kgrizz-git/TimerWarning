#!/usr/bin/env bash
#
# Regression tests for macOS uninstall failure handling.
#
# These tests run on any platform with stubs. They verify that Darwin scheduler
# failures are surfaced to callers and that a still-loaded LaunchAgent does not
# lose its plist when bootout fails.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

test_uninstall_functions_return_scheduler_failures() {
    mkdir -p "${TMP_DIR}/uninstall/lib"
    cat > "${TMP_DIR}/uninstall/lib/library-loader.sh" <<'STUB'
init_library_paths() { return 0; }
detect_library_dir() { echo ""; return 0; }
source_optional_lib() { return 1; }
STUB

    # Source function definitions without executing main "$@".
    awk '/^# Run main function/ { exit } { print }' \
        "${ROOT}/uninstall.sh" > "${TMP_DIR}/uninstall/uninstall-functions.sh"

    # shellcheck disable=SC1091
    source "${TMP_DIR}/uninstall/uninstall-functions.sh"

    scheduler_is_darwin() {
        return 0
    }
    scheduler_stop_and_disable() {
        return 42
    }
    scheduler_remove_files() {
        return 43
    }

    if stop_timer >/dev/null 2>&1; then
        fail "stop_timer returned success after scheduler_stop_and_disable failed"
    fi

    if remove_systemd_files >/dev/null 2>&1; then
        fail "remove_systemd_files returned success after scheduler_remove_files failed"
    fi
}

test_remove_launch_agent_preserves_plist_when_loaded_bootout_fails() {
    local home bin plist
    home="${TMP_DIR}/home"
    bin="${TMP_DIR}/bin"
    plist="${home}/Library/LaunchAgents/com.sleep-warning.plist"
    mkdir -p "${home}/Library/LaunchAgents" "${bin}"
    : > "${plist}"

    cat > "${bin}/launchctl" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
    bootout)
        exit 1
        ;;
    print)
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
STUB
    chmod +x "${bin}/launchctl"

    HOME="${home}" PATH="${bin}:${PATH}" bash -c '
        set -euo pipefail
        source "$1"
        if remove_launch_agent >/dev/null 2>&1; then
            echo "remove_launch_agent returned success after bootout failed" >&2
            exit 1
        fi
        if [ ! -f "$HOME/Library/LaunchAgents/com.sleep-warning.plist" ]; then
            echo "LaunchAgent plist was removed even though bootout failed while loaded" >&2
            exit 1
        fi
    ' _ "${ROOT}/lib/service-config-darwin.sh"
}

test_uninstall_functions_return_scheduler_failures
test_remove_launch_agent_preserves_plist_when_loaded_bootout_fails

echo "OK: Darwin uninstall failures are surfaced without orphaning LaunchAgents"
