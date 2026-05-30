#!/usr/bin/env bash
#
# tests/lib/test-run-timeout.sh
#
# Portable command timeout for integration tests (macOS lacks GNU timeout by default).
# Prefer GNU timeout or gtimeout when installed; otherwise poll/kill in pure bash.
#
# Usage (after sourcing):
#   test_run_with_timeout 8 some-command arg ...
# Exit 124 when the watchdog fires (same convention as GNU timeout).

test_run_with_timeout() {
    local seconds="$1"
    shift

    if [ -z "${seconds}" ] || ! [[ "${seconds}" =~ ^[0-9]+$ ]]; then
        echo "test_run_with_timeout: invalid seconds '${seconds}'" >&2
        return 2
    fi

    if command -v timeout >/dev/null 2>&1; then
        timeout "${seconds}" "$@"
        return $?
    fi
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${seconds}" "$@"
        return $?
    fi

    local pid waited=0 poll_interval=1
    "$@" &
    pid=$!

    while kill -0 "${pid}" 2>/dev/null && [ "${waited}" -lt "${seconds}" ]; do
        sleep "${poll_interval}"
        waited=$((waited + poll_interval))
    done

    if kill -0 "${pid}" 2>/dev/null; then
        kill -TERM "${pid}" 2>/dev/null || true
        sleep 1
        kill -KILL "${pid}" 2>/dev/null || true
        wait "${pid}" 2>/dev/null || true
        return 124
    fi

    wait "${pid}"
    return $?
}
