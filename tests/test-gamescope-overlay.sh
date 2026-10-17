#!/usr/bin/env bash

###############################################################################
# test-gamescope-overlay.sh — Unit tests for SteamOS Gaming Mode (gamescope)
# overlay detection, toggle gate, X11 backend forcing, STEAM_OVERLAY atoms,
# auto-close safety override, and partial-lock behavior for the experimental toggle.
#
# Runs headlessly on both Linux and macOS (Tier-A).
#
# Usage:
#   bash tests/test-gamescope-overlay.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

pass=0
fail=0

_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        _pass "${desc}"
    else
        _fail "${desc} (expected='${expected}', got='${actual}')"
    fi
}

assert_rc() {
    local desc="$1" expected_rc="$2"
    shift 2
    set +e
    "$@"
    local rc=$?
    set -e
    if [ "${rc}" -eq "${expected_rc}" ]; then
        _pass "${desc} (rc=${rc})"
    else
        _fail "${desc} (expected rc=${expected_rc}, got ${rc})"
    fi
}

_test_dir=""
_cleanup() {
    if [ -n "${_test_dir}" ] && [ -d "${_test_dir}" ]; then
        rm -rf "${_test_dir}"
    fi
}
trap _cleanup EXIT
_test_dir="$(mktemp -d 2>/dev/null || mktemp -d -t gamescope-overlay-test)"

export HOME="${_test_dir}/home"
mkdir -p "${HOME}/.config/sleep-warning/config"
export CONFIG_DIR="${HOME}/.config/sleep-warning/config"
export CONFIG_FILE="${CONFIG_DIR}/sleep-warning.conf"

# Source core modules
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/config-keys.sh"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/config.sh"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/display-detection.sh"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/popup-safety.sh"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/window-management.sh"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/popup-dialog-implementations.sh"

echo "=== 1. Toggle Behavior & Display Detection ==="

# Mock X11 display accessibility so DISPLAY=:0 is considered accessible headlessly
is_x11_display_accessible() { return 0; }
# Keep detection from seeing a real gamescope process on the host
pgrep() { return 1; }

unset XDG_CURRENT_DESKTOP
export DISPLAY=":0"
export GAMESCOPE_SESSION="1"

# 1a. Toggle disabled via env var -> must return x11 even when gamescope is the desktop
export GAMING_MODE_EXPERIMENTAL_ENABLED="false"
export XDG_CURRENT_DESKTOP="gamescope"
env_detected="$(detect_display_environment)"
assert_eq "GAMING_MODE_EXPERIMENTAL_ENABLED=false forces x11 even when the session is gamescope" "x11" "${env_detected}"

# 1b. An inherited GAMESCOPE_SESSION=1 is not a session detector
export GAMING_MODE_EXPERIMENTAL_ENABLED="true"
unset XDG_CURRENT_DESKTOP
env_detected="$(detect_display_environment)"
assert_eq "GAMESCOPE_SESSION=1 alone stays x11 when gamescope is not running and XDG_CURRENT_DESKTOP is unset" "x11" "${env_detected}"

# 1c. A gamescope process with no desktop name selects the overlay path
pgrep() {
    if [ "${1:-}" = "-x" ] && [ "${2:-}" = "gamescope" ]; then
        return 0
    fi
    return 1
}
env_detected="$(detect_display_environment)"
assert_eq "pgrep gamescope with toggle=true detects gamescope when XDG_CURRENT_DESKTOP is unset" "gamescope" "${env_detected}"
pgrep() { return 1; }

export XDG_CURRENT_DESKTOP="gamescope"
env_detected="$(detect_display_environment)"
assert_eq "XDG_CURRENT_DESKTOP=gamescope detects gamescope when toggle=true" "gamescope" "${env_detected}"

# 1d. Desktop session (XDG_CURRENT_DESKTOP=KDE) prevents nested gamescope misclassification
pgrep() {
    if [ "${1:-}" = "-x" ] && [ "${2:-}" = "gamescope" ]; then
        return 0
    fi
    return 1
}
export XDG_CURRENT_DESKTOP="KDE"
env_detected="$(detect_display_environment)"
assert_eq "XDG_CURRENT_DESKTOP=KDE forces x11 even when gamescope process is running and toggle=true" "x11" "${env_detected}"
pgrep() { return 1; }
export XDG_CURRENT_DESKTOP="gamescope"

# 1e. Toggle in config file (including quoted value). Session is gamescope so detection can succeed.
unset GAMING_MODE_EXPERIMENTAL_ENABLED
printf 'GAMING_MODE_EXPERIMENTAL_ENABLED="true"\n' > "${CONFIG_FILE}"
assert_eq "get_gaming_mode_experimental_enabled parses quoted true" "true" "$(get_gaming_mode_experimental_enabled)"
env_detected="$(detect_display_environment)"
assert_eq "Config file GAMING_MODE_EXPERIMENTAL_ENABLED=\"true\" enables gamescope detection" "gamescope" "${env_detected}"

printf 'GAMING_MODE_EXPERIMENTAL_ENABLED="false"\n' > "${CONFIG_FILE}"
assert_eq "get_gaming_mode_experimental_enabled parses quoted false" "false" "$(get_gaming_mode_experimental_enabled)"
env_detected="$(detect_display_environment)"
assert_eq "Config file GAMING_MODE_EXPERIMENTAL_ENABLED=\"false\" disables gamescope detection" "x11" "${env_detected}"

# 1e. Display resolution for gamescope
export GAMING_MODE_EXPERIMENTAL_ENABLED="true"
assert_eq "get_display gamescope resolves to :0" ":0" "$(get_display "gamescope")"
assert_eq "get_display_identifier gamescope resolves to :0" ":0" "$(get_display_identifier "gamescope")"

# 1f. Missing config key stays off even when mode-gaming.conf exists
unset GAMING_MODE_EXPERIMENTAL_ENABLED
printf 'CHECK_INTERVAL=10\n' > "${CONFIG_FILE}"
mkdir -p "${HOME}/.config/systemd/user/sleep-warning.service.d"
touch "${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf"
assert_eq "absent GAMING_MODE_EXPERIMENTAL_ENABLED stays false when mode-gaming.conf exists" "false" "$(get_gaming_mode_experimental_enabled)"
rm -f "${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf"

# 1g. Inaccessible :0 falls through to an accessible :1, and a dead display resolves to nothing
is_x11_display_accessible() {
    [ "${1:-}" = ":1" ]
}
unset DISPLAY
_gs_fallback="$(get_gamescope_x11_display || true)"
assert_eq "get_gamescope_x11_display falls through to accessible :1" ":1" "${_gs_fallback}"
is_x11_display_accessible() { return 1; }
_gs_none="$(get_gamescope_x11_display || true)"
assert_eq "get_gamescope_x11_display prints nothing when no display is accessible" "" "${_gs_none}"
_gs_display_none="$(get_display "gamescope" || true)"
assert_eq "get_display gamescope does not fall back to a dead :0 socket" "" "${_gs_display_none}"
is_x11_display_accessible() { return 0; }
export DISPLAY=":0"

echo ""
echo "=== 2. Popup Safety Auto-Close Override in gamescope ==="

# Simulate Linux runtime so DARWIN_FORCE_AUTO_CLOSE does not mask x11 behavior on macOS hosts
is_darwin() { return 1; }
get_popup_auto_close() { echo "false"; }
get_min_display_time() { echo "30"; }

export env_type="x11"
export GAMESCOPE_FORCE_AUTO_CLOSE="true"
assert_eq "popup_safe_get_auto_close preserves false on x11" "false" "$(popup_safe_get_auto_close)"

export env_type="gamescope"
assert_eq "popup_safe_get_auto_close forces true on gamescope" "true" "$(popup_safe_get_auto_close)"

export GAMESCOPE_FORCE_AUTO_CLOSE="false"
assert_eq "popup_safe_get_auto_close respects GAMESCOPE_FORCE_AUTO_CLOSE=false" "false" "$(popup_safe_get_auto_close)"
export GAMESCOPE_FORCE_AUTO_CLOSE="true"

echo ""
echo "=== 3. STEAM_OVERLAY & STEAM_INPUT_FOCUS Atoms via xprop (_NET_CLIENT_LIST + _NET_WM_PID) ==="

_mock_bin="${_test_dir}/bin"
mkdir -p "${_mock_bin}"
_xprop_log="${_test_dir}/xprop.log"
: > "${_xprop_log}"

# Create a dummy background process to represent the popup PID
sleep 30 &
_dummy_popup_pid=$!

cat > "${_mock_bin}/xprop" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "${_xprop_log}"
if [ "\${1:-}" = "-root" ] && [ "\${2:-}" = "_NET_CLIENT_LIST" ]; then
    echo "_NET_CLIENT_LIST(WINDOW): window id # 0x200001, 0x40000a"
    exit 0
fi
if [ "\${1:-}" = "-id" ] && [ "\${2:-}" = "0x200001" ] && [ "\${3:-}" = "_NET_WM_PID" ]; then
    echo "_NET_WM_PID(CARDINAL) = 999999"
    exit 0
fi
if [ "\${1:-}" = "-id" ] && [ "\${2:-}" = "0x40000a" ] && [ "\${3:-}" = "_NET_WM_PID" ]; then
    echo "_NET_WM_PID(CARDINAL) = ${_dummy_popup_pid}"
    exit 0
fi
exit 0
EOF
chmod +x "${_mock_bin}/xprop"

# Ensure wmctrl and xdotool are not used by shadowing PATH with _mock_bin first
_orig_path="${PATH}"
export PATH="${_mock_bin}:/usr/bin:/bin"

log_to_file() { :; }

_found_win="$(find_window_id_for_popup "Sleep Warning" "none" "${_dummy_popup_pid}")"
assert_eq "find_window_id_for_popup matches window ID via xprop _NET_WM_PID without wmctrl/xdotool" "0x40000a" "${_found_win}"

apply_gamescope_overlay_atoms "Sleep Warning" "none" "${_dummy_popup_pid}"
if grep -q -- "-id 0x40000a -f STEAM_OVERLAY 32c -set STEAM_OVERLAY 1" "${_xprop_log}"; then
    _pass "apply_gamescope_overlay_atoms sets STEAM_OVERLAY=1 on matched window"
else
    _fail "apply_gamescope_overlay_atoms did not set STEAM_OVERLAY=1 (log: $(cat "${_xprop_log}"))"
fi

if grep -q -- "-id 0x40000a -f STEAM_INPUT_FOCUS 32c -set STEAM_INPUT_FOCUS 1" "${_xprop_log}"; then
    _pass "apply_gamescope_overlay_atoms sets STEAM_INPUT_FOCUS=1 on matched window"
else
    _fail "apply_gamescope_overlay_atoms did not set STEAM_INPUT_FOCUS=1 (log: $(cat "${_xprop_log}"))"
fi

# Verify apply_gamescope_overlay_atoms returns 1 when xprop -set fails (e.g. window disappears before write)
cat > "${_mock_bin}/xprop" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "-root" ] && [ "\${2:-}" = "_NET_CLIENT_LIST" ]; then
    echo "_NET_CLIENT_LIST(WINDOW): window id # 0x40000a"
    exit 0
fi
if [ "\${1:-}" = "-id" ] && [ "\${2:-}" = "0x40000a" ] && [ "\${3:-}" = "_NET_WM_PID" ]; then
    echo "_NET_WM_PID(CARDINAL) = ${_dummy_popup_pid}"
    exit 0
fi
if [ "\${4:-}" = "STEAM_OVERLAY" ] || [ "\${4:-}" = "STEAM_INPUT_FOCUS" ]; then
    exit 1
fi
exit 0
EOF
chmod +x "${_mock_bin}/xprop"
assert_rc "apply_gamescope_overlay_atoms returns 1 when xprop property write fails" 1 \
    apply_gamescope_overlay_atoms "Sleep Warning" "none" "${_dummy_popup_pid}"

kill "${_dummy_popup_pid}" 2>/dev/null || true
wait "${_dummy_popup_pid}" 2>/dev/null || true

echo ""
echo "=== 4. _popup_spawn_warning_dialog X11 Backend Enforcement ==="

_zenity_env_log="${_test_dir}/zenity_env.log"
cat > "${_mock_bin}/zenity" <<EOF
#!/usr/bin/env bash
printf 'PID=%s\nGDK_BACKEND=%s\nQT_QPA_PLATFORM=%s\nWAYLAND_DISPLAY=%s\n' "\$\$" "\${GDK_BACKEND:-}" "\${QT_QPA_PLATFORM:-}" "\${WAYLAND_DISPLAY:-UNSET}" > "${_zenity_env_log}"
exit 0
EOF
chmod +x "${_mock_bin}/zenity"

export WAYLAND_DISPLAY="gamescope-0"
export POPUP_FORCE_X11_BACKEND="true"
dialog_tool="zenity"
window_title="Sleep Warning"
width="400"
height="200"
popup_position="center"
window_tool=""
pause_available="false"
pause_duration=""
zenity_output_file="${_test_dir}/zenity_out.txt"
popup_pid=""
_popup_spawn_warning_dialog "Warning msg"
wait "${popup_pid}" 2>/dev/null || true

_logged_gdk="$(grep '^GDK_BACKEND=' "${_zenity_env_log}" | cut -d'=' -f2-)"
_logged_qt="$(grep '^QT_QPA_PLATFORM=' "${_zenity_env_log}" | cut -d'=' -f2-)"
_logged_wayland="$(grep '^WAYLAND_DISPLAY=' "${_zenity_env_log}" | cut -d'=' -f2-)"
_logged_pid="$(grep '^PID=' "${_zenity_env_log}" | cut -d'=' -f2-)"

assert_eq "_popup_spawn_warning_dialog sets GDK_BACKEND=x11" "x11" "${_logged_gdk}"
assert_eq "_popup_spawn_warning_dialog sets QT_QPA_PLATFORM=xcb" "xcb" "${_logged_qt}"
assert_eq "_popup_spawn_warning_dialog unsets WAYLAND_DISPLAY" "UNSET" "${_logged_wayland}"
assert_eq "_popup_spawn_warning_dialog preserves exact dialog PID via env exec" "${popup_pid}" "${_logged_pid}"

# Also verify POPUP_FORCE_X11_BACKEND=false works under set -u (Bash 3.2 empty-array safety)
export POPUP_FORCE_X11_BACKEND="false"
export WAYLAND_DISPLAY="wayland-0"
popup_pid=""
_popup_spawn_warning_dialog "Warning msg normal"
wait "${popup_pid}" 2>/dev/null || true
_logged_wayland_normal="$(grep '^WAYLAND_DISPLAY=' "${_zenity_env_log}" | cut -d'=' -f2-)"
assert_eq "_popup_spawn_warning_dialog with POPUP_FORCE_X11_BACKEND=false preserves WAYLAND_DISPLAY under set -u" "wayland-0" "${_logged_wayland_normal}"

export PATH="${_orig_path}"

echo ""
echo "=== 5. Experimental Gaming Mode is not a tighten-only lock ==="

# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/configure-core.sh"
ensure_day_vars
ensure_day_names
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/time-parsing.sh"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/configure-partial-lock.sh"

assert_rc "partial lock allows GAMING_MODE_EXPERIMENTAL_ENABLED false -> true" 0 \
    configure_partial_lock_validate_scalar GAMING_MODE_EXPERIMENTAL_ENABLED false true
assert_rc "partial lock allows GAMING_MODE_EXPERIMENTAL_ENABLED true -> true" 0 \
    configure_partial_lock_validate_scalar GAMING_MODE_EXPERIMENTAL_ENABLED true true
assert_rc "partial lock allows GAMING_MODE_EXPERIMENTAL_ENABLED true -> false" 0 \
    configure_partial_lock_validate_scalar GAMING_MODE_EXPERIMENTAL_ENABLED true false

# Full session validation check
config_lines=()
lock_hours_lines=()
uninstall_lock_hours_lines=()
check_interval=10
min_display_time=30
popup_immovable=true
popup_auto_close=true
configure_block_enabled=false
config_lock_enabled=false
gaming_mode_experimental_enabled=true
uninstall_protection_mode=difficult
pause_enabled=true
pause_duration=5
pause_cooldown_hours=24
popup_size=medium
popup_size_mode=fixed
popup_size_custom="50%x50%"
popup_size_custom_absolute="1280x720"
popup_position=center
dialog_tool=auto

CONFIGURE_PARTIAL_LOCK_MODE=true
configure_partial_lock_capture_baseline

gaming_mode_experimental_enabled=false
_lock_errors="$(configure_partial_lock_validate_proposed)"
if [ -z "${_lock_errors}" ]; then
    _pass "configure_partial_lock_validate_proposed allows disabling gaming_mode_experimental_enabled"
else
    _fail "configure_partial_lock_validate_proposed blocked disabling gaming_mode_experimental_enabled (${_lock_errors})"
fi

# Test update_gaming_mode_config_in_place (append when absent + update in-place when present)
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/configure-config-write.sh"
printf 'CHECK_INTERVAL=10\nMONDAY=22-6\n' > "${CONFIG_FILE}"
update_gaming_mode_config_in_place "true"
unset GAMING_MODE_EXPERIMENTAL_ENABLED
assert_eq "update_gaming_mode_config_in_place appends GAMING_MODE_EXPERIMENTAL_ENABLED=true when absent" "true" "$(get_gaming_mode_experimental_enabled)"
update_gaming_mode_config_in_place "false"
assert_eq "update_gaming_mode_config_in_place updates GAMING_MODE_EXPERIMENTAL_ENABLED=false in place" "false" "$(get_gaming_mode_experimental_enabled)"
rm -f "${CONFIG_FILE}"
update_gaming_mode_config_in_place "true"
assert_eq "update_gaming_mode_config_in_place creates CONFIG_FILE when missing" "true" "$(get_gaming_mode_experimental_enabled)"
if [ -f "${CONFIG_FILE}" ]; then
    _pass "update_gaming_mode_config_in_place writes a config file on first Option 12 toggle"
else
    _fail "update_gaming_mode_config_in_place did not create ${CONFIG_FILE}"
fi

# Test Option 12 (configure_service_mode) surfaces save failure and keeps state consistent
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/configure-input-service.sh"
CONFIGURE_PARTIAL_LOCK_MODE=false
gaming_mode_experimental_enabled="false"
update_gaming_mode_config_in_place() { return 1; }
configure_read() {
    local _var="${!#}"
    printf -v "${_var}" '%s' "2"
    return 0
}
assert_rc "configure_service_mode returns 1 when update_gaming_mode_config_in_place fails" 1 \
    configure_service_mode "false"
assert_eq "configure_service_mode keeps gaming_mode_experimental_enabled unchanged on save failure" "false" "${gaming_mode_experimental_enabled}"

# Option 12 may disable the overlay during partial lock. Stub the drop-in writer
# so this does not reload the real user systemd manager.
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/configure-config-write.sh"
configure_service_for_mode() { return 0; }
CONFIGURE_PARTIAL_LOCK_MODE=true
gaming_mode_experimental_enabled="true"
printf 'GAMING_MODE_EXPERIMENTAL_ENABLED=true\n' > "${CONFIG_FILE}"
configure_read() {
    local _var="${!#}"
    printf -v "${_var}" '%s' "1"
    return 0
}
assert_rc "configure_service_mode allows disabling experimental gaming mode during partial lock" 0 \
    configure_service_mode "false"
assert_eq "configure_service_mode persists experimental gaming mode false during partial lock" "false" "${gaming_mode_experimental_enabled}"

echo ""
echo "=== 6. mode-gaming.conf sets DISPLAY=:0 ==="
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/service-config-linux.sh"
assert_rc "create_service_dropin writes gaming drop-in" 0 \
    create_service_dropin "gaming" "gamescope-0"
_gaming_dropin="${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf"
if grep -q '^Environment=DISPLAY=:0$' "${_gaming_dropin}" && grep -q '^Environment=WAYLAND_DISPLAY=gamescope-0$' "${_gaming_dropin}" && ! grep -q 'GAMESCOPE_SESSION' "${_gaming_dropin}"; then
    _pass "mode-gaming.conf sets DISPLAY=:0 and WAYLAND_DISPLAY and omits GAMESCOPE_SESSION"
else
    _fail "mode-gaming.conf display lines are wrong ($(cat "${_gaming_dropin}"))"
fi

echo ""
echo "=== 7. Pause notice is tagged with the dialog PID ==="
_pause_bin="${_test_dir}/pause-bin"
mkdir -p "${_pause_bin}"
_pause_args="${_test_dir}/pause-args.txt"
_pause_pid_file="${_test_dir}/pause-dialog.pid"
cat > "${_pause_bin}/zenity" <<EOF
#!/usr/bin/env bash
echo "\$\$" > "${_pause_pid_file}"
printf '%s\n' "\$*" > "${_pause_args}"
sleep 0.4
exit 0
EOF
chmod +x "${_pause_bin}/zenity"
export PATH="${_pause_bin}:${PATH}"
_tagged_pid=""
apply_gamescope_overlay_atoms() {
    _tagged_pid="$3"
    return 0
}
export env_type="gamescope"
dialog_tool="zenity"
window_tool=""
_pause_info_timeout=5
_dlg_prefix=(env -u WAYLAND_DISPLAY GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb)
_popup_show_pause_activated_notice "01:00"
_dialog_pid="$(cat "${_pause_pid_file}" 2>/dev/null || true)"
assert_eq "pause notice tags the zenity PID" "${_dialog_pid}" "${_tagged_pid}"
if [ -n "${_tagged_pid}" ] && grep -q -- '--title=Pause Activated' "${_pause_args}"; then
    _pass "pause notice uses a titled zenity info dialog"
else
    _fail "pause notice did not launch a titled zenity dialog (pid=${_tagged_pid}, args=$(cat "${_pause_args}" 2>/dev/null))"
fi

cat > "${_pause_bin}/kdialog" <<EOF
#!/usr/bin/env bash
echo "\$\$" > "${_pause_pid_file}"
printf '%s\n' "\$*" > "${_pause_args}"
sleep 30
exit 0
EOF
chmod +x "${_pause_bin}/kdialog"
_tagged_pid=""
dialog_tool="kdialog"
_pause_info_timeout=1
_popup_show_pause_activated_notice "01:00"
if grep -q -- '--msgbox' "${_pause_args}" && ! grep -q -- '--passivepopup' "${_pause_args}"; then
    _pass "gamescope pause notice uses kdialog --msgbox"
else
    _fail "gamescope pause notice did not use kdialog --msgbox ($(cat "${_pause_args}" 2>/dev/null))"
fi
assert_eq "gamescope kdialog pause notice tags the dialog PID" "$(cat "${_pause_pid_file}")" "${_tagged_pid}"

echo ""
echo "=== 8. gamescope atom setup does not block the caller ==="
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/popup-display-linux.sh"
_atom_log="${_test_dir}/atom-arm.log"
: > "${_atom_log}"
apply_gamescope_overlay_atoms() {
    echo "$3" >> "${_atom_log}"
    sleep 2
    return 0
}
export env_type="gamescope"
window_title="Sleep Warning"
window_tool=""
popup_pid="4242"
_arm_start=$(date +%s)
_popup_linux_arm_gamescope_atoms 0
_arm_end=$(date +%s)
if [ $((_arm_end - _arm_start)) -le 1 ]; then
    _pass "arm_gamescope_atoms returns without waiting for xprop polling"
else
    _fail "arm_gamescope_atoms blocked the caller for $((_arm_end - _arm_start))s"
fi
_seen=""
_i=0
while [ "${_i}" -lt 20 ]; do
    if grep -q '^4242$' "${_atom_log}"; then
        _seen="yes"
        break
    fi
    sleep 0.1
    _i=$((_i + 1))
done
assert_eq "arm_gamescope_atoms applies atoms for the popup PID in the background" "yes" "${_seen}"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
