#!/usr/bin/env bash

###############################################################################
# Regression tests for the Opus and Space Bunny review findings:
# runtime cap resolution, uninstall cancel status, pgrep alternation,
# overnight IFS, macOS watchdog status, gamescope stay-on-top, and
# _NET_CLIENT_LIST "not found" parsing.
#
# Headless. Uses a temp HOME. Does not run configure.sh menus.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

_PASS=0
_FAIL=0
_pass() { _PASS=$((_PASS + 1)); echo "  PASS  $1"; }
_fail() { _FAIL=$((_FAIL + 1)); echo "  FAIL  $1"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        _pass "${desc}"
    else
        _fail "${desc} (expected '${expected}', got '${actual}')"
    fi
}

_tmp="$(mktemp -d)"
trap 'rm -rf "${_tmp}"' EXIT
export HOME="${_tmp}/home"
mkdir -p "${HOME}/.config/sleep-warning/config"

echo "=== Runtime cap uses feature resolution ==="
# shellcheck disable=SC1091
source "${LIB_DIR}/config.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/time-parsing.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/daily-caps.sh"

CONFIG_FILE="${HOME}/.config/sleep-warning/config/sleep-warning.conf"
cat > "${CONFIG_FILE}" <<'EOF'
MONDAY=00:00-12:00
UNINSTALL_LOCK_HOURS_MONDAY=12:00-23:00
EOF
declare -a _cfg=() _lock=() _un=()
_cbe=""
_upm=""
collect_runtime_daily_cap_inputs _cfg _lock _un _cbe _upm
assert_eq "missing uninstall mode resolves to difficult" "difficult" "${_upm}"
_viol="$(check_daily_caps "${_cbe}" "${_upm}" "${_cfg[@]}" "${_lock[@]}" "${_un[@]}")"
if printf '%s\n' "${_viol}" | grep -q 'Monday|uninstall_block|'; then
    _pass "merged uninstall block over 16h is a violation"
else
    _fail "merged uninstall block was not flagged (${_viol})"
fi

cat > "${CONFIG_FILE}" <<'EOF'
CONFIGURE_BLOCK_ENABLED=yes
MONDAY=00:00-09:00
CONFIG_LOCK_HOURS_MONDAY=09:00-23:00
EOF
collect_runtime_daily_cap_inputs _cfg _lock _un _cbe _upm
assert_eq "CONFIGURE_BLOCK_ENABLED=yes resolves to true" "true" "${_cbe}"
_viol="$(check_daily_caps "${_cbe}" "${_upm}" "${_cfg[@]}" "${_lock[@]}" "${_un[@]}")"
if printf '%s\n' "${_viol}" | grep -q 'Monday|configure_block|'; then
    _pass "configure-block yes merges past 16h"
else
    _fail "configure-block yes was not flagged (${_viol})"
fi

cat > "${CONFIG_FILE}" <<'EOF'
CONFIGURE_BLOCK_ENABLED=true
MONDAY=00:00-14:00
CONFIG_LOCK_HOURS_TUESDAY=10:00-23:00
EOF
collect_runtime_daily_cap_inputs _cfg _lock _un _cbe _upm
_viol="$(check_daily_caps "${_cbe}" "${_upm}" "${_cfg[@]}" "${_lock[@]}" "${_un[@]}")"
if printf '%s\n' "${_viol}" | grep -q 'Tuesday|configure_block|'; then
    _pass "absent Tuesday restriction hours are included in the cap"
else
    _fail "absent Tuesday was not flagged (${_viol})"
fi

cat > "${CONFIG_FILE}" <<'EOF'
MONDAY=22:00 - 06:00
TUESDAY=22-06:00
WEDNESDAY=22:00-6
THURSDAY=07:00-08:00
EOF
collect_runtime_daily_cap_inputs _cfg _lock _un _cbe _upm
_viol="$(check_daily_caps "${_cbe}" "${_upm}" "${_cfg[@]}" "${_lock[@]}" "${_un[@]}")"
if [ -z "${_viol}" ]; then
    _pass "spaced and mixed ranges that parse_config accepts stay under the cap"
else
    _fail "legal loose spellings were rejected (${_viol})"
fi
assert_eq "spaced overnight normalizes like parse_config" "MONDAY=22:00-06:00" "${_cfg[1]}"
assert_eq "leading-zero hour 08 survives normalization" "THURSDAY=07:00-08:00" "${_cfg[4]}"

echo "=== Wizard save fill matches runtime defaults ==="
_fill=()
append_missing_restriction_default_lines _fill "MONDAY=00:00-14:00" "CONFIG_LOCK_HOURS_TUESDAY=10:00-23:00"
_viol="$(check_daily_caps "true" "none" "MONDAY=00:00-14:00" "CONFIG_LOCK_HOURS_TUESDAY=10:00-23:00" "${_fill[@]}")"
if printf '%s\n' "${_viol}" | grep -q 'Tuesday|configure_block'; then
    _pass "save-gate default fill flags Tuesday when its lock plus the default exceeds 16 h"
else
    _fail "save-gate default fill did not flag Tuesday (${_viol})"
fi
_fill=()
append_missing_restriction_default_lines _fill "TUESDAY="
_has_tue=0
for _line in "${_fill[@]}"; do
    case "${_line}" in
        TUESDAY=*) _has_tue=1 ;;
    esac
done
assert_eq "explicit empty Tuesday is not replaced with the default" "0" "${_has_tue}"

echo "=== Uninstall cancel keeps exit 2 ==="
# shellcheck disable=SC1091
source "${LIB_DIR}/configure-core.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/uninstall-verification.sh"
configure_read() {
    local _name=""
    local _arg
    for _arg in "$@"; do
        _name="${_arg}"
    done
    printf -v "${_name}" '%s' "y"
    return 0
}
verify_confirmation_phrase() { return 2; }
has_dialog_tool() { return 1; }
set +e
verify_uninstall_during_restrictions false >/dev/null 2>&1
_rc=$?
set -e
assert_eq "cancelled confirmation returns 2" "2" "${_rc}"
_rc=0
verify_uninstall_during_restrictions false >/dev/null 2>&1 || _rc=$?
assert_eq "cancelled confirmation returns 2 when the caller uses set -e" "2" "${_rc}"

_bad_status="$(awk '
    /if ! / { prev = 1; next }
    prev && /exit_code=\$\?/ { print FILENAME ":" NR; found = 1 }
    { prev = 0 }
    END { if (found) exit 1 }
' "${SCRIPT_DIR}/uninstall.sh" "${SCRIPT_DIR}/manual-uninstall-guide.sh" "${LIB_DIR}/uninstall-verification.sh" || true)"
if [ -z "${_bad_status}" ]; then
    _pass "no if-not command stores \$? as the command status"
else
    _fail "negated command status still captured: ${_bad_status}"
fi

# Run the real uninstall.sh under its own set -e. A stubbed verifier must
# still reach the cancel and failure messages. Bound the process so a missed
# stub cannot sit in a read loop.
_run_stubbed_uninstall() {
    local want_rc="$1"
    local envf="${_tmp}/uninstall-bash-env-${want_rc}.sh"
    local out="${_tmp}/uninstall-out-${want_rc}.txt"
    local home="${_tmp}/uninstall-home-${want_rc}"
    mkdir -p "${home}"
    cat > "${envf}" <<EOF
trap '
  if type check_uninstall_protection_time >/dev/null 2>&1; then
    check_uninstall_protection_time() { echo difficult; return 0; }
  fi
  if type verify_uninstall_during_restrictions >/dev/null 2>&1; then
    verify_uninstall_during_restrictions() { return ${want_rc}; }
  fi
  if type check_uninstall_protection_time >/dev/null 2>&1 && type verify_uninstall_during_restrictions >/dev/null 2>&1; then
    trap - DEBUG
  fi
  true
' DEBUG
EOF
    HOME="${home}" DISPLAY="" BASH_ENV="${envf}" \
        bash "${SCRIPT_DIR}/uninstall.sh" </dev/null >"${out}" 2>&1 &
    local pid=$!
    local _i
    for _i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        if ! kill -0 "${pid}" 2>/dev/null; then
            break
        fi
        sleep 1
    done
    if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}" 2>/dev/null || true
        wait "${pid}" 2>/dev/null || true
        echo "124"
        return 0
    fi
    wait "${pid}"
    echo "$?"
}

set +e
_rc="$(_run_stubbed_uninstall 2)"
set -e
_out="$(cat "${_tmp}/uninstall-out-2.txt" 2>/dev/null || true)"
assert_eq "uninstall.sh cancel exits 0 under set -e" "0" "${_rc}"
if printf '%s\n' "${_out}" | grep -q "Uninstall cancelled by user."; then
    _pass "uninstall.sh prints the cancel message"
else
    _fail "uninstall.sh cancel message missing (${_out})"
fi

set +e
_rc="$(_run_stubbed_uninstall 1)"
set -e
_out="$(cat "${_tmp}/uninstall-out-1.txt" 2>/dev/null || true)"
assert_eq "uninstall.sh verification failure exits 1 under set -e" "1" "${_rc}"
if printf '%s\n' "${_out}" | grep -q "Uninstall verification failed."; then
    _pass "uninstall.sh prints the verification-failed message"
else
    _fail "uninstall.sh verification-failed message missing (${_out})"
fi

echo "=== pgrep fallback alternates dialog tools ==="
check_window_tools() { echo ""; }
get_popup_age() { echo 1; }
# shellcheck disable=SC1091
source "${LIB_DIR}/popup-pid-management.sh"
_pbin="${_tmp}/bin"
mkdir -p "${_pbin}"
cat > "${_pbin}/pgrep" <<'EOF'
#!/usr/bin/env bash
pattern=""
prev=""
for arg in "$@"; do
    if [ "${prev}" = "-f" ]; then
        pattern="${arg}"
    fi
    prev="${arg}"
done
if [[ "${pattern}" == *'\|'* ]]; then
    exit 1
fi
if [[ "${pattern}" == *zenity* && "${pattern}" == *'|'* && "${pattern}" == *yad* && "${pattern}" == *kdialog* ]]; then
    echo 4242
    exit 0
fi
exit 1
EOF
chmod +x "${_pbin}/pgrep"
PATH="${_pbin}:${PATH}"
# shellcheck disable=SC2218 # defined by popup-pid-management.sh, sourced above
_found="$(is_popup_running || true)"
if [[ "${_found}" == "4242|"* ]]; then
    _pass "pgrep fallback finds a dialog when the pattern uses alternation"
else
    _fail "pgrep fallback finds a dialog when the pattern uses alternation (got '${_found}')"
fi

echo "=== Overnight helper does not leak IFS ==="
# shellcheck disable=SC1091
source "${LIB_DIR}/time-validation.sh"
IFS=' '
is_time_in_previous_day_overnight_tail "0100" "22-6" || true
if [ "${IFS}" = " " ]; then
    _pass "overnight helper restores the caller IFS"
else
    _fail "overnight helper left IFS as '${IFS}'"
fi
if grep -n "local IFS" "${SCRIPT_DIR}/sleep-warning.sh" >/dev/null; then
    _fail "sleep-warning.sh still has a function-scoped local IFS"
else
    _pass "sleep-warning.sh does not keep a function-scoped local IFS"
fi

echo "=== macOS watchdog rc 124 is not a spawn failure ==="
export POPUP_DARWIN_SKIP_MODULE_SOURCE=1
detect_display_environment() { echo "aqua"; }
get_display_identifier() { echo "1"; }
get_popup_display_frequency() { echo 10; }
get_popup_size() { echo medium; }
get_popup_position() { echo center; }
popup_safe_get_min_display_time() { echo 1; }
popup_safe_get_auto_close() { echo true; }
get_popup_dimensions() { echo "400 300"; }
_popup_get_interval_text() { echo "10 min"; }
get_next_unrestricted_time() { echo "5:00 AM"; }
_popup_build_base_message() { echo "base"; }
dialog_safe_text() { printf '%s' "$1"; }
_popup_build_initial_countdown_suffix() { echo ""; }
can_pause_now() { return 1; }
is_popup_running() { echo ""; }
popup_compute_watchdog_seconds() { echo 10; }
_darwin_log="${_tmp}/darwin.log"
log_to_file() { printf '%s\n' "$*" >> "${_darwin_log}"; }
popup_run_with_watchdog() { popup_pid=""; return 124; }
_notified=0
_darwin_display_notification() { _notified=1; return 0; }
# shellcheck disable=SC1091
source "${LIB_DIR}/popup-display-darwin.sh"
show_warning_darwin >/dev/null 2>&1 || true
if grep -q "Popup closed by safety watchdog" "${_darwin_log}" \
    && ! grep -q "Failed to display popup" "${_darwin_log}" \
    && [ "${_notified}" -eq 0 ]; then
    _pass "watchdog close does not notify as a spawn failure"
else
    _fail "watchdog close was treated as a spawn failure (notified=${_notified})"
fi

echo "=== gamescope stay-on-top does not poll atoms ==="
# shellcheck disable=SC1091
source "${LIB_DIR}/window-management.sh"
_atom_log="${_tmp}/atoms.log"
apply_gamescope_overlay_atoms() { echo called >> "${_atom_log}"; }
env_type="gamescope"
keep_window_on_top "ALERT" "wmctrl" 5 1
make_window_unclosable "ALERT" "wmctrl" 30
if [ -s "${_atom_log}" ]; then
    _fail "gamescope keep_window_on_top still called apply_gamescope_overlay_atoms"
else
    _pass "gamescope keep_window_on_top skips atom polling"
fi

echo "=== _NET_CLIENT_LIST not-found is not a window id ==="
_xbin="${_tmp}/xbin"
mkdir -p "${_xbin}"
_xprop_log="${_tmp}/xprop.log"
cat > "${_xbin}/xprop" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "-root" ]; then
    echo "_NET_CLIENT_LIST: not found."
    exit 0
fi
printf '%s\n' "\$*" >> "${_xprop_log}"
exit 0
EOF
chmod +x "${_xbin}/xprop"
PATH="${_xbin}:${PATH}"
hash -r 2>/dev/null || true
find_window_id_for_popup "ALERT: Restricted time window" "" "99" >/dev/null 2>&1 || true
if [ -s "${_xprop_log}" ]; then
    _fail "_NET_CLIENT_LIST not-found line was passed to xprop -id"
else
    _pass "_NET_CLIENT_LIST not-found line is ignored"
fi

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
