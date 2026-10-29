#!/bin/bash

###############################################################################
# Tests lib/scheduler-platform.sh on the Linux (systemd) path with a stubbed
# systemctl, plus the Darwin branches that touch no external service.
# Runs headless with a temp HOME. Nothing here calls the real systemctl or
# launchctl.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "${TMP_HOME}"' EXIT
export HOME="${TMP_HOME}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/scheduler-platform.sh" || exit 1

_PASS=0
_FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        _PASS=$(( _PASS + 1 )); echo "  PASS  ${desc} (${actual})"
    else
        _FAIL=$(( _FAIL + 1 )); echo "  FAIL  ${desc}: expected '${expected}', got '${actual}'"
    fi
}

# Stubs. A function named like a command wins over the real binary.
FAKE_OS="Linux"
uname() { echo "${FAKE_OS}"; }
SYSTEMCTL_LOG="${TMP_HOME}/systemctl.log"
SYSTEMCTL_FAIL=""
SYSTEMCTL_ENABLED="enabled"
SYSTEMCTL_ACTIVE="active"
systemctl() {
    local all_args="$*"
    local subcommand="${2:-}"   # called as: systemctl --user <subcommand> ...
    echo "${all_args}" >> "${SYSTEMCTL_LOG}"
    case "${all_args}" in
        *is-enabled*) echo "${SYSTEMCTL_ENABLED}" ;;
        *is-active*) echo "${SYSTEMCTL_ACTIVE}" ;;
        *list-timers*) echo "Wed 2026-10-28 13:00:00 EDT 5min left n/a n/a sleep-warning.timer" ;;
        *) ;;
    esac
    case " ${SYSTEMCTL_FAIL} " in
        *" ${subcommand} "*) return 1 ;;
        *) return 0 ;;
    esac
}
calls() { [[ -f "${SYSTEMCTL_LOG}" ]] && paste -sd'|' "${SYSTEMCTL_LOG}"; }
reset_calls() { rm -f "${SYSTEMCTL_LOG}"; SYSTEMCTL_FAIL=""; }

SYSTEMD_DIR="${HOME}/.config/systemd/user"
BIN="${HOME}/.local/bin/sleep-warning.sh"
make_installed() {
    mkdir -p "${SYSTEMD_DIR}" "$(dirname "${BIN}")"
    : > "${BIN}"
    : > "${SYSTEMD_DIR}/sleep-warning.service"
    : > "${SYSTEMD_DIR}/sleep-warning.timer"
}

echo "=== scheduler_is_darwin and scheduler_plist_path ==="
FAKE_OS="Linux"
scheduler_is_darwin; check "Linux is not Darwin" "1" "$?"
FAKE_OS="Darwin"
scheduler_is_darwin; check "Darwin is Darwin" "0" "$?"
check "plist path is under the user's LaunchAgents" "${HOME}/Library/LaunchAgents/com.sleep-warning.plist" "$(scheduler_plist_path)"

echo "=== scheduler_stop_and_disable (Linux) ==="
FAKE_OS="Linux"; reset_calls
scheduler_stop_and_disable; check "returns 0 when both calls succeed" "0" "$?"
check "stops, then disables, the timer" "--user stop sleep-warning.timer|--user disable sleep-warning.timer" "$(calls)"
reset_calls; SYSTEMCTL_FAIL="stop"
scheduler_stop_and_disable; check "a failed stop returns 1" "1" "$?"
check "disable is still attempted after a failed stop" "--user stop sleep-warning.timer|--user disable sleep-warning.timer" "$(calls)"
reset_calls; SYSTEMCTL_FAIL="disable"
scheduler_stop_and_disable; check "a failed disable returns 1" "1" "$?"

echo "=== scheduler_remove_files (Linux) ==="
FAKE_OS="Linux"; make_installed
scheduler_remove_files
check "the service file is removed" "no" "$([[ -e "${SYSTEMD_DIR}/sleep-warning.service" ]] && echo yes || echo no)"
check "the timer file is removed" "no" "$([[ -e "${SYSTEMD_DIR}/sleep-warning.timer" ]] && echo yes || echo no)"
check "the installed script is left alone" "yes" "$([[ -e "${BIN}" ]] && echo yes || echo no)"
scheduler_remove_files; check "removing again is harmless" "0" "$?"

echo "=== scheduler_reload ==="
FAKE_OS="Linux"; reset_calls
scheduler_reload; check "Linux reload returns 0" "0" "$?"
check "Linux reload runs daemon-reload" "--user daemon-reload" "$(calls)"
FAKE_OS="Darwin"; reset_calls
scheduler_reload; check "Darwin reload returns 0" "0" "$?"
check "Darwin reload calls nothing" "" "$(calls)"

echo "=== scheduler_is_installed ==="
rm -rf "${HOME}/.local" "${HOME}/.config" "${HOME}/Library"
FAKE_OS="Linux"
scheduler_is_installed; check "nothing installed" "1" "$?"
make_installed
scheduler_is_installed; check "script, service and timer present" "0" "$?"
rm -f "${SYSTEMD_DIR}/sleep-warning.timer"
scheduler_is_installed; check "a missing timer file is not installed" "1" "$?"
make_installed; rm -f "${BIN}"
scheduler_is_installed; check "a missing script is not installed" "1" "$?"
FAKE_OS="Darwin"; make_installed
scheduler_is_installed; check "Darwin needs the plist, not the systemd files" "1" "$?"
mkdir -p "$(dirname "$(scheduler_plist_path)")"; : > "$(scheduler_plist_path)"
scheduler_is_installed; check "Darwin installed with script and plist" "0" "$?"
rm -f "${BIN}"
scheduler_is_installed; check "Darwin without the script is not installed" "1" "$?"

echo "=== scheduler_status_lines (Linux) ==="
FAKE_OS="Linux"; reset_calls
SYSTEMCTL_ENABLED="enabled"; SYSTEMCTL_ACTIVE="active"
out="$(scheduler_status_lines | paste -sd'|' -)"
check "active timer shows platform, state and the first five timer fields" \
    "Platform: Linux (systemd)|Enabled: enabled|Active: active|Next trigger: Wed 2026-10-28 13:00:00 EDT 5min" "${out}"
SYSTEMCTL_ENABLED="disabled"; SYSTEMCTL_ACTIVE="inactive"
out="$(scheduler_status_lines | paste -sd'|' -)"
check "an inactive timer has no next trigger" "Platform: Linux (systemd)|Enabled: disabled|Active: inactive" "${out}"
SYSTEMCTL_ENABLED=""; SYSTEMCTL_ACTIVE=""
out="$(scheduler_status_lines | paste -sd'|' -)"
check "empty systemctl answers read as unknown" "Platform: Linux (systemd)|Enabled: unknown|Active: unknown" "${out}"

echo "=== scheduler_enable_start (Linux) ==="
FAKE_OS="Linux"; reset_calls
scheduler_enable_start; check "returns 0 when every call succeeds" "0" "$?"
check "reloads, enables, then starts the timer" \
    "--user daemon-reload|--user enable sleep-warning.timer|--user start sleep-warning.timer" "$(calls)"
reset_calls; SYSTEMCTL_FAIL="start"
scheduler_enable_start; check "the exit status is the start call's" "1" "$?"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[[ "${_FAIL}" -eq 0 ]] || exit 1
