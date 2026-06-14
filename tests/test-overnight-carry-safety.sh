#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_configure_block_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"

    get_configure_block_enabled() { echo true; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }
    parse_lock_hours() { echo ""; }

    if check_config_lock_time; then
        fail "configure block allowed previous-day overnight carry"
    fi
)

run_uninstall_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"

    get_uninstall_protection_mode() { echo difficult; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }
    parse_uninstall_lock_hours() { echo ""; }

    result="$(check_uninstall_protection_time)"
    [ "${result}" = "difficult" ] || fail "expected uninstall protection difficult, got '${result}'"
)

run_config_lock_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"
    CONFIG_DIR="${ROOT_DIR}/tests/.tmp/overnight-carry-config-lock"
    CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
    source "${ROOT_DIR}/lib/config-locking.sh"

    get_config_lock_enabled() { echo true; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }
    parse_lock_hours() { echo ""; }

    is_config_lock_active || fail "config lock inactive during previous-day overnight carry"
)

run_lock_hours_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"
    CONFIG_DIR="${ROOT_DIR}/tests/.tmp/overnight-carry-lock-hours"
    CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
    source "${ROOT_DIR}/lib/config-locking.sh"

    get_config_lock_enabled() { echo true; }
    get_configure_block_enabled() { echo true; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() { echo ""; }
    parse_lock_hours() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }

    is_config_lock_active || fail "config lock inactive during previous-day overnight lock-hours carry"
    if check_config_lock_time; then
        fail "configure block allowed previous-day overnight lock-hours carry"
    fi
)

run_uninstall_lock_hours_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"

    get_uninstall_protection_mode() { echo difficult; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() { echo ""; }
    parse_uninstall_lock_hours() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }

    result="$(check_uninstall_protection_time)"
    [ "${result}" = "difficult" ] || fail "expected uninstall lock-hours protection difficult, got '${result}'"
)

run_configure_block_case
run_uninstall_case
run_config_lock_case
run_lock_hours_case
run_uninstall_lock_hours_case

echo "OK: previous-day overnight carry safety checks passed"
