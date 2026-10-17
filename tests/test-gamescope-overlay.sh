#!/usr/bin/env bash

###############################################################################
# test-gamescope-overlay.sh — Unit tests for SteamOS Gaming Mode (gamescope)
# overlay detection, toggle gate, X11 backend forcing, STEAM_OVERLAY atoms,
# auto-close safety override, and tighten-only partial lock.
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

unset XDG_CURRENT_DESKTOP
export DISPLAY=":0"
export GAMESCOPE_SESSION="1"

# 1a. Toggle disabled via env var -> must return x11 even when GAMESCOPE_SESSION=1
export GAMING_MODE_EXPERIMENTAL_ENABLED="false"
env_detected="$(detect_display_environment)"
assert_eq "GAMING_MODE_EXPERIMENTAL_ENABLED=false forces x11 even with GAMESCOPE_SESSION=1" "x11" "${env_detected}"

# 1b. Toggle enabled via env var -> returns gamescope
export GAMING_MODE_EXPERIMENTAL_ENABLED="true"
env_detected="$(detect_display_environment)"
assert_eq "GAMING_MODE_EXPERIMENTAL_ENABLED=true detects gamescope with DISPLAY=:0 + GAMESCOPE_SESSION=1" "gamescope" "${env_detected}"

# 1c. Desktop session (XDG_CURRENT_DESKTOP=KDE) prevents nested gamescope / static drop-in misclassification
export XDG_CURRENT_DESKTOP="KDE"
env_detected="$(detect_display_environment)"
assert_eq "XDG_CURRENT_DESKTOP=KDE forces x11 even when GAMESCOPE_SESSION=1 and toggle=true" "x11" "${env_detected}"
export XDG_CURRENT_DESKTOP="gamescope"
env_detected="$(detect_display_environment)"
assert_eq "XDG_CURRENT_DESKTOP=gamescope detects gamescope when toggle=true" "gamescope" "${env_detected}"
unset XDG_CURRENT_DESKTOP

# 1d. Toggle in config file (including quoted value)
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
echo "=== 5. Tighten-Only Partial Lock for GAMING_MODE_EXPERIMENTAL_ENABLED ==="

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
assert_rc "partial lock blocks GAMING_MODE_EXPERIMENTAL_ENABLED true -> false" 1 \
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
if [ -n "${_lock_errors}" ]; then
    _pass "configure_partial_lock_validate_proposed reports error when disabling gaming_mode_experimental_enabled"
else
    _fail "configure_partial_lock_validate_proposed failed to block disabling gaming_mode_experimental_enabled"
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

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
