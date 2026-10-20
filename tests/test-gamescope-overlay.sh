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
unset GAMESCOPE_OVERLAY_DEBUG || true

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

# Overlay off, but the gaming drop-in still exports DISPLAY=:0. A live Wayland
# socket must keep Wayland routing instead of becoming plain X11.
_env_off_wayland="$(
    is_wayland_display_accessible() { return 0; }
    export WAYLAND_DISPLAY="wayland-0"
    export GAMING_MODE_EXPERIMENTAL_ENABLED="false"
    export XDG_CURRENT_DESKTOP="gamescope"
    export DISPLAY=":0"
    detect_display_environment
)"
assert_eq "overlay off with a Wayland socket stays wayland when DISPLAY=:0" "wayland" "${_env_off_wayland}"

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

# Session classification for the systemd drop-in stays "gaming" even when the
# overlay toggle is off. Overlay routing and the drop-in are separate.
export GAMING_MODE_EXPERIMENTAL_ENABLED="false"
unset XDG_CURRENT_DESKTOP
env_detected="$(detect_display_environment)"
assert_eq "toggle=false keeps overlay routing off while gamescope is running and XDG_CURRENT_DESKTOP is unset" "x11" "${env_detected}"
_session_mode="$(detect_system_mode)"
assert_eq "detect_system_mode still reports gaming for the drop-in when the overlay toggle is off" "gaming" "${_session_mode}"
export GAMING_MODE_EXPERIMENTAL_ENABLED="true"
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

# Getter missing: env still decides, and a drop-in does not enable the overlay.
unset -f get_gaming_mode_experimental_enabled
export GAMING_MODE_EXPERIMENTAL_ENABLED="false"
touch "${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf"
if is_gaming_mode_enabled; then
    _fail "is_gaming_mode_enabled without getter treats env false as enabled"
else
    _pass "is_gaming_mode_enabled without getter honors env false"
fi
export GAMING_MODE_EXPERIMENTAL_ENABLED="true"
if is_gaming_mode_enabled; then
    _pass "is_gaming_mode_enabled without getter honors env true"
else
    _fail "is_gaming_mode_enabled without getter ignored env true"
fi
unset GAMING_MODE_EXPERIMENTAL_ENABLED
rm -f "${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/config.sh"

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

_probe_bin="$(mktemp -d)"
_sockdir="$(mktemp -d)"
_probe_display() {
    local disp="$1"
    X11_UNIX_DIR="${_sockdir}" /bin/bash -c 'export PATH="'"${_probe_bin}"'"; export X11_UNIX_DIR="'"${_sockdir}"'"; source "'"${PROJECT_DIR}"'/lib/display-detection.sh"; is_x11_display_accessible "'"${disp}"'"; echo $?'
}
_probe_rc="$(_probe_display ":1")"
assert_eq "display with no probe tools and no socket is unanswered" "1" "${_probe_rc}"
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()' "${_sockdir}/X1"
_probe_rc="$(_probe_display ":1")"
assert_eq "display :1 with no probe tools uses socket X1" "0" "${_probe_rc}"
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()' "${_sockdir}/X0"
_probe_rc="$(_probe_display ":0.0")"
assert_eq "display :0.0 with no probe tools uses socket X0" "0" "${_probe_rc}"
_probe_rc="$(_probe_display "localhost:1")"
assert_eq "non-local display form stays unanswered without probe tools" "1" "${_probe_rc}"
rm -rf "${_probe_bin}" "${_sockdir}"

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

# xdotool --pid path (gamescope: empty _NET_CLIENT_LIST). The unmapped GTK client-leader
# window shares _NET_WM_PID and exists before the toplevel; it must not be selected.
cat > "${_mock_bin}/xprop" <<EOF
#!/usr/bin/env bash
exit 0
EOF
cat > "${_mock_bin}/xdotool" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "search" ]; then
    case " \$* " in
        *" --onlyvisible "*) echo "4194314" ;;
        *) echo "4194305" ;;
    esac
    exit 0
fi
if [ "\${1:-}" = "getwindowname" ]; then
    [ "\${2:-}" = "4194314" ] && echo "Sleep Warning" || echo "zenity"
    exit 0
fi
exit 1
EOF
chmod +x "${_mock_bin}/xprop" "${_mock_bin}/xdotool"
_found_win="$(find_window_id_for_popup "Sleep Warning" "" "${_dummy_popup_pid}")"
assert_eq "find_window_id_for_popup xdotool --pid path skips unmapped leader window" "4194314" "${_found_win}"
rm -f "${_mock_bin}/xdotool"

kill "${_dummy_popup_pid}" 2>/dev/null || true
wait "${_dummy_popup_pid}" 2>/dev/null || true

echo ""
echo "=== 3b. gamescope_interactive_dialog_dimensions (full root width) ==="

_saved_root_fn="$(declare -f gamescope_get_x11_root_size)"
gamescope_get_x11_root_size() { echo "1280 800"; return 0; }
assert_eq "interactive dims on 1280x800 root floor height at two thirds of root" "1280 533" \
    "$(gamescope_interactive_dialog_dimensions 400 250)"
gamescope_get_x11_root_size() { echo "3840 1440"; return 0; }
assert_eq "interactive dims on 3840x1440 root use full width and two-thirds height" "3840 960" \
    "$(gamescope_interactive_dialog_dimensions 400 250)"
gamescope_get_x11_root_size() { echo "800 600"; return 0; }
assert_eq "interactive dims on 800-wide root use 1201 last-resort width and two-thirds height" "1201 400" \
    "$(gamescope_interactive_dialog_dimensions 400 250)"
gamescope_get_x11_root_size() { echo "1280 800"; return 0; }
assert_eq "interactive dims keep a configured height above two thirds of root" "1280 600" \
    "$(gamescope_interactive_dialog_dimensions 400 600)"
assert_eq "interactive dims cap height at root" "1280 800" \
    "$(gamescope_interactive_dialog_dimensions 400 900)"
gamescope_get_x11_root_size() { echo "1280 250"; return 0; }
assert_eq "interactive dims raise a tiny two-thirds floor to 200 when the canvas allows" "1280 200" \
    "$(gamescope_interactive_dialog_dimensions 400 50)"
gamescope_get_x11_root_size() { echo "1280 80"; return 0; }
assert_eq "interactive dims cap a tiny root at root height" "1280 80" \
    "$(gamescope_interactive_dialog_dimensions 400 250)"
gamescope_get_x11_root_size() { return 1; }
_fb_rc=0
_fb_dims="$(gamescope_interactive_dialog_dimensions 400 250)" || _fb_rc=$?
assert_eq "interactive dims fallback size when root unread" "400 250" "${_fb_dims}"
assert_eq "interactive dims returns non-zero when root unread" "1" "${_fb_rc}"
eval "${_saved_root_fn}"

env_type="gamescope"
assert_eq "gamescope top-left pins the dialog to the canvas origin" "0 0" \
    "$(calculate_popup_geometry top-left 2560 720 true)"
env_type="x11"
_desktop_tl="$(calculate_popup_geometry top-left 400 250 true)"
if [ "${_desktop_tl}" != "0 0" ]; then
    _pass "desktop top-left is not pinned to the gamescope origin"
else
    _fail "desktop top-left was forced to 0 0"
fi
unset env_type

echo ""
echo "=== 3c. gamescope show_warning forces top-left and two-thirds-root height ==="

_gs_layout_file="${_test_dir}/gamescope-show-layout.txt"
_gs_respawn_file="${_test_dir}/gamescope-respawn-layout.txt"
(
    # shellcheck disable=SC1091
    source "${PROJECT_DIR}/lib/popup-display.sh"
    export DISPLAY_DETECTION_PATH="test"
    export DISPLAY_DETECTION_NOTE=""
    log_message() { return 0; }
    log_to_file() { return 0; }
    is_darwin() { return 1; }
    ensure_utf8_locale_for_dialogs() { return 0; }
    detect_display_environment() { echo "gamescope"; }
    get_display_identifier() { echo ":0"; }
    get_display() { echo ":0"; }
    check_window_tools() { echo ""; }
    detect_window_state() { echo "fullscreen|game"; }
    get_dialog_tool_config() { echo "auto"; }
    check_dialog_tool() { echo "zenity"; }
    get_popup_display_frequency() { echo "10"; }
    get_popup_size() { echo "small"; }
    get_popup_position() { echo "center"; }
    popup_safe_get_min_display_time() { echo "0"; }
    popup_safe_get_auto_close() { echo "true"; }
    get_popup_dimensions() { echo "400 250"; }
    get_next_unrestricted_time() { echo "07:00"; }
    can_pause_now() { return 1; }
    dialog_safe_text() { printf '%s' "${1:-}"; }
    _popup_linux_acquire_spawn_lock() { return 0; }
    _popup_linux_should_skip_for_existing_popup() { return 1; }
    _popup_linux_on_spawn_failure() { return 0; }
    gamescope_get_x11_root_size() { echo "1280 800"; return 0; }
    _popup_spawn_warning_dialog() {
        printf '%s %s %s\n' "${width}" "${height}" "${popup_position}" > "${_gs_layout_file}"
        popup_pid=""
    }
    show_warning
    gamescope_get_x11_root_size() { return 1; }
    _popup_spawn_warning_dialog() {
        printf 'fallback %s %s %s\n' "${width}" "${height}" "${popup_position}" >> "${_gs_layout_file}"
        popup_pid=""
    }
    show_warning
    popup_position="top-left"
    width="1280"
    height="533"
    window_tool=""
    base_message="base"
    dialog_tool="zenity"
    window_title="ALERT: Restricted time window"
    popup_pid=""
    pause_available="false"
    pause_duration=""
    _popup_watchdog_expired_file=""
    env_type="gamescope"
    cleanup_popup_pid() { return 0; }
    save_popup_pid() { return 0; }
    _popup_linux_arm_gamescope_atoms() { return 0; }
    _popup_spawn_warning_dialog() {
        printf '%s %s %s\n' "${width}" "${height}" "${popup_position}" > "${_gs_respawn_file}"
        popup_pid="424242"
    }
    _popup_linux_update_countdown 4
)
_gs_forced="$(head -n1 "${_gs_layout_file}" 2>/dev/null || true)"
assert_eq "gamescope show_warning forces top-left and two-thirds-root height" "1280 533 top-left" "${_gs_forced}"
_gs_fallback="$(sed -n '2p' "${_gs_layout_file}" 2>/dev/null || true)"
assert_eq "gamescope keeps configured center when root size is unread" "fallback 400 250 center" "${_gs_fallback}"
_gs_respawn="$(cat "${_gs_respawn_file}" 2>/dev/null || true)"
assert_eq "countdown respawn keeps gamescope top-left and height" "1280 533 top-left" "${_gs_respawn}"

# gamescope has no _NET_CLIENT_LIST, so wmctrl -l is empty there. The zenity
# top-left move must go through xdotool; Desktop keeps the wmctrl path.
_repo_bin="${_test_dir}/reposition-bin"
_repo_log="${_test_dir}/reposition.log"
mkdir -p "${_repo_bin}"
cat > "${_repo_bin}/wmctrl" <<EOF
#!/usr/bin/env bash
echo "wmctrl \$*" >> "${_repo_log}"
if [ "\${1:-}" = "-l" ]; then
    echo "0x0300000a  0 deck ALERT: Restricted time window"
fi
exit 0
EOF
cat > "${_repo_bin}/xdotool" <<EOF
#!/usr/bin/env bash
echo "xdotool \$*" >> "${_repo_log}"
if [ "\${1:-}" = "search" ]; then
    echo "50331658"
fi
exit 0
EOF
chmod +x "${_repo_bin}/wmctrl" "${_repo_bin}/xdotool"
: > "${_repo_log}"
(
    export PATH="${_repo_bin}:${PATH}"
    env_type="gamescope"
    reposition_popup_window "ALERT: Restricted time window" "wmctrl" "top-left" 1280 533 1
)
if grep -q '^xdotool windowmove 50331658 0 0$' "${_repo_log}" && ! grep -q '^wmctrl' "${_repo_log}"; then
    _pass "gamescope reposition uses xdotool to move to the canvas origin even when wmctrl is installed"
else
    _fail "gamescope reposition did not use xdotool windowmove 0 0 ($(tr '\n' ';' < "${_repo_log}"))"
fi
: > "${_repo_log}"
(
    export PATH="${_repo_bin}:${PATH}"
    env_type="x11"
    reposition_popup_window "ALERT: Restricted time window" "wmctrl" "top-left" 400 250 1
)
if grep -q '^wmctrl -i -r 0x0300000a -e ' "${_repo_log}" && ! grep -q '^xdotool' "${_repo_log}"; then
    _pass "desktop reposition keeps the wmctrl path"
else
    _fail "desktop reposition changed tool ($(tr '\n' ';' < "${_repo_log}"))"
fi

echo ""
echo "=== 4. _popup_spawn_warning_dialog X11 Backend Enforcement ==="

_zenity_env_log="${_test_dir}/zenity_env.log"
cat > "${_mock_bin}/zenity" <<EOF
#!/usr/bin/env bash
_zw=""; _zh=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    --width=*) _zw="\${1#--width=}" ;;
    --height=*) _zh="\${1#--height=}" ;;
    --width) shift; _zw="\${1:-}" ;;
    --height) shift; _zh="\${1:-}" ;;
  esac
  shift
done
printf 'PID=%s\nGDK_BACKEND=%s\nQT_QPA_PLATFORM=%s\nWAYLAND_DISPLAY=%s\nGDK_SCALE=%s\nWIDTH=%s\nHEIGHT=%s\n' \
  "\$\$" "\${GDK_BACKEND:-}" "\${QT_QPA_PLATFORM:-}" "\${WAYLAND_DISPLAY:-UNSET}" \
  "\${GDK_SCALE:-UNSET}" "\${_zw}" "\${_zh}" > "${_zenity_env_log}"
exit 0
EOF
chmod +x "${_mock_bin}/zenity"

export WAYLAND_DISPLAY="gamescope-0"
export POPUP_FORCE_X11_BACKEND="true"
export GDK_SCALE="2"
dialog_tool="zenity"
window_title="Sleep Warning"
width="1280"
height="250"
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
_logged_scale="$(grep '^GDK_SCALE=' "${_zenity_env_log}" | cut -d'=' -f2-)"
_logged_w="$(grep '^WIDTH=' "${_zenity_env_log}" | cut -d'=' -f2-)"
_logged_h="$(grep '^HEIGHT=' "${_zenity_env_log}" | cut -d'=' -f2-)"

assert_eq "_popup_spawn_warning_dialog sets GDK_BACKEND=x11" "x11" "${_logged_gdk}"
assert_eq "_popup_spawn_warning_dialog sets QT_QPA_PLATFORM=xcb" "xcb" "${_logged_qt}"
assert_eq "_popup_spawn_warning_dialog unsets WAYLAND_DISPLAY" "UNSET" "${_logged_wayland}"
assert_eq "_popup_spawn_warning_dialog unsets GDK_SCALE" "UNSET" "${_logged_scale}"
assert_eq "_popup_spawn_warning_dialog passes root-width to zenity" "1280" "${_logged_w}"
assert_eq "_popup_spawn_warning_dialog passes the caller height to zenity" "250" "${_logged_h}"
assert_eq "_popup_spawn_warning_dialog preserves exact dialog PID via env exec" "${popup_pid}" "${_logged_pid}"
unset GDK_SCALE

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
# declare -f pretty-prints case patterns with spaces around "|".
if declare -f configure_partial_lock_validate_scalar | grep -q 'GAMING_MODE_EXPERIMENTAL_ENABLED | gaming_mode_experimental_enabled'; then
    _pass "partial lock names GAMING_MODE_EXPERIMENTAL_ENABLED as an explicit allow"
else
    _fail "partial lock is missing the explicit GAMING_MODE_EXPERIMENTAL_ENABLED allow arm"
fi
assert_rc "partial lock still blocks disabling CONFIGURE_BLOCK_ENABLED" 1 \
    configure_partial_lock_validate_scalar CONFIGURE_BLOCK_ENABLED true false

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
if declare -f configure_partial_lock_validate_proposed | grep -q 'GAMING_MODE_EXPERIMENTAL_ENABLED'; then
    _pass "validate_proposed checks the experimental overlay flag"
else
    _fail "validate_proposed never passes GAMING_MODE_EXPERIMENTAL_ENABLED"
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

printf 'CHECK_INTERVAL=10\nPOPUP_SIZE=medium\n' > "${CONFIG_FILE}"
update_gaming_mode_config_in_place "true"
if grep -q '^CHECK_INTERVAL=10$' "${CONFIG_FILE}" && grep -q '^POPUP_SIZE=medium$' "${CONFIG_FILE}" && grep -q '^GAMING_MODE_EXPERIMENTAL_ENABLED=true$' "${CONFIG_FILE}"; then
    _pass "update_gaming_mode_config_in_place append keeps unrelated keys"
else
    _fail "update_gaming_mode_config_in_place append dropped unrelated keys ($(cat "${CONFIG_FILE}"))"
fi

gaming_mode_experimental_enabled="true"
_header="$(
    _write_config_header 10 medium center 30 true true false difficult true 5 24 auto false fixed "50%x50%" "1280x720" "" ""
)"
if printf '%s\n' "${_header}" | grep -q '^GAMING_MODE_EXPERIMENTAL_ENABLED=true$'; then
    _pass "_write_config_header persists GAMING_MODE_EXPERIMENTAL_ENABLED from the wizard value"
else
    _fail "_write_config_header did not write GAMING_MODE_EXPERIMENTAL_ENABLED=true"
fi

printf 'CHECK_INTERVAL=10\n' > "${CONFIG_FILE}"
chmod 000 "${CONFIG_FILE}"
if update_gaming_mode_config_in_place "true"; then
    _fail "update_gaming_mode_config_in_place reported success when the config could not be read"
else
    _pass "update_gaming_mode_config_in_place fails when the config cannot be read"
fi
chmod 644 "${CONFIG_FILE}" 2>/dev/null || chmod u+r "${CONFIG_FILE}"
if grep -q '^CHECK_INTERVAL=10$' "${CONFIG_FILE}" && ! grep -q '^GAMING_MODE_EXPERIMENTAL_ENABLED=' "${CONFIG_FILE}"; then
    _pass "unreadable config is left unchanged"
else
    _fail "unreadable config was replaced ($(cat "${CONFIG_FILE}" 2>/dev/null))"
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

# GUI list dialogs return dialog_safe_text output. Non-UTF-8 turns the em dash
# into "-", which must still select Desktop Mode.
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/unicode-dialog-safety.sh"
DIALOG_SAFETY_FORCE_ASCII=1
DIALOG_UTF8_CONFIRMED=""
_desktop_raw="Desktop Mode Only (Default — Gaming Mode Overlay Disabled)"
_desktop_sanitized="$(dialog_safe_text "${_desktop_raw}")"
if [ "${_desktop_raw}" != "${_desktop_sanitized}" ]; then
    _pass "non-UTF-8 sanitizer rewrites the Option 12 desktop em dash"
else
    _fail "non-UTF-8 sanitizer left the Option 12 desktop label unchanged"
fi
show_list_dialog() {
    printf '%s\n' "${_desktop_sanitized}"
    return 0
}
show_info_dialog() { return 0; }
gaming_mode_experimental_enabled="true"
printf 'GAMING_MODE_EXPERIMENTAL_ENABLED=true\n' > "${CONFIG_FILE}"
assert_rc "Option 12 GUI desktop choice disables the overlay when the label is sanitized" 0 \
    configure_service_mode "true"
assert_eq "sanitized Desktop Mode label persists experimental gaming mode false" "false" "$(get_gaming_mode_experimental_enabled)"
unset DIALOG_SAFETY_FORCE_ASCII
DIALOG_UTF8_CONFIRMED=""

# Missing getter must not treat a gaming drop-in as the current overlay value.
unset -f get_gaming_mode_experimental_enabled
gaming_mode_experimental_enabled=""
get_current_service_mode() { echo "gaming"; }
configure_service_for_mode() { return 1; }
configure_read() {
    local _var="${!#}"
    printf -v "${_var}" '%s' "1"
    return 0
}
printf 'GAMING_MODE_EXPERIMENTAL_ENABLED=false\n' > "${CONFIG_FILE}"
assert_rc "Option 12 text disable rolls back to false when the getter is missing" 1 \
    configure_service_mode "false"
assert_eq "missing getter does not roll the overlay back to enabled" "false" "$(grep '^GAMING_MODE_EXPERIMENTAL_ENABLED=' "${CONFIG_FILE}" | cut -d'=' -f2)"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/config.sh"
configure_service_for_mode() { return 0; }

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

_pause_move_file="${_test_dir}/pause-move.txt"
(
    gamescope_get_x11_root_size() { echo "1280 800"; return 0; }
    cat > "${_pause_bin}/yad" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "${_pause_args}"
exit 0
EOF
    chmod +x "${_pause_bin}/yad"
    export env_type="gamescope"
    dialog_tool="yad"
    window_tool=""
    _pause_info_timeout=5
    _dlg_prefix=(env -u WAYLAND_DISPLAY GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb)
    _popup_show_pause_activated_notice "01:00"
)
if grep -q -- '--height=533' "${_pause_args}" && grep -q -- '--posx=0' "${_pause_args}" && grep -q -- '--posy=0' "${_pause_args}" && ! grep -q -- '--center' "${_pause_args}"; then
    _pass "gamescope yad pause notice is top-left and at least two thirds of root height"
else
    _fail "gamescope yad pause notice layout wrong ($(cat "${_pause_args}" 2>/dev/null))"
fi
(
    gamescope_get_x11_root_size() { echo "1280 800"; return 0; }
    reposition_popup_window() {
        printf '%s %s %s\n' "$3" "$4" "$5" > "${_pause_move_file}"
    }
    export env_type="gamescope"
    dialog_tool="zenity"
    window_tool="xdotool"
    _pause_info_timeout=5
    _dlg_prefix=(env -u WAYLAND_DISPLAY GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb)
    _popup_show_pause_activated_notice "01:00"
)
_move_seen=""
_i=0
while [ "${_i}" -lt 20 ]; do
    if [ -s "${_pause_move_file}" ]; then
        _move_seen="$(cat "${_pause_move_file}")"
        break
    fi
    sleep 0.1
    _i=$((_i + 1))
done
assert_eq "gamescope zenity pause notice repositions to top-left at two-thirds root height" "top-left 1280 533" "${_move_seen}"
(
    export env_type="x11"
    dialog_tool="yad"
    window_tool=""
    _pause_info_timeout=5
    unset _dlg_prefix
    _popup_show_pause_activated_notice "01:00"
)
if grep -q -- '--center' "${_pause_args}" && grep -q -- '--height=150' "${_pause_args}"; then
    _pass "desktop yad pause notice stays centered at the configured size"
else
    _fail "desktop yad pause notice changed ($(cat "${_pause_args}" 2>/dev/null))"
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
echo "=== 9. No usable display falls back to notify-send ==="
log_message() { return 0; }
log_to_file() { printf '%s\n' "$*" >> "${_test_dir}/popup-log.txt"; }
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/popup-display.sh"
is_darwin() { return 1; }
detect_display_environment() { echo "gamescope"; }
get_display_identifier() { echo ""; return 0; }
get_display() { echo ""; return 1; }
_notify_bin="${_test_dir}/notify-bin"
mkdir -p "${_notify_bin}"
_notify_marker="${_test_dir}/notify-sent"
cat > "${_notify_bin}/notify-send" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "${_notify_marker}"
exit 0
EOF
chmod +x "${_notify_bin}/notify-send"
export PATH="${_notify_bin}:${PATH}"
rm -f "${_notify_marker}"
assert_rc "show_warning uses notify-send when gamescope has no accessible display" 0 show_warning
if [ -s "${_notify_marker}" ]; then
    _pass "notify-send fallback received the alert text"
else
    _fail "notify-send fallback did not run"
fi

cat > "${_notify_bin}/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "${_notify_bin}/notify-send"
assert_rc "show_warning returns 1 when notify-send fails" 1 show_warning

export PATH="/usr/bin:/bin"
hash -r 2>/dev/null || true
if command -v notify-send >/dev/null 2>&1; then
    _pass "host notify-send present; skipped the missing-binary assertion"
else
    assert_rc "show_warning returns 1 when notify-send is not installed" 1 show_warning
fi

detect_display_environment() { echo "unknown"; }
get_display() { return 1; }
rm -f "${_notify_marker}"
cat > "${_notify_bin}/notify-send" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "${_notify_marker}"
exit 0
EOF
chmod +x "${_notify_bin}/notify-send"
export PATH="${_notify_bin}:${PATH}"
_saved_display="${DISPLAY-}"
unset DISPLAY
assert_rc "headless unknown session does not call notify-send" 1 show_warning
if [ -s "${_notify_marker}" ]; then
    _fail "notify-send ran for an unknown headless session"
else
    _pass "notify-send skipped for an unknown headless session"
fi
export DISPLAY=":0"
rm -f "${_notify_marker}"
assert_rc "unprobed DISPLAY still tries notify-send" 0 show_warning
if [ -s "${_notify_marker}" ]; then
    _pass "notify-send ran when DISPLAY is set and the session type is unknown"
else
    _fail "notify-send did not run for an unprobed DISPLAY"
fi
if [ -n "${_saved_display}" ]; then
    export DISPLAY="${_saved_display}"
else
    unset DISPLAY
fi

echo ""
echo "=== 10. GAMESCOPE_OVERLAY_DEBUG is log-only and default off ==="

# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/config.sh"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/window-management.sh"
# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/configure-partial-lock.sh"

unset GAMESCOPE_OVERLAY_DEBUG
printf 'CHECK_INTERVAL=10\n' > "${CONFIG_FILE}"
assert_eq "unset env and absent key stays false" "false" "$(get_gamescope_overlay_debug)"
assert_eq "file helper absent key stays false" "false" "$(_get_gamescope_overlay_debug_from_config)"

printf 'GAMESCOPE_OVERLAY_DEBUG="true"\n' > "${CONFIG_FILE}"
assert_eq "quoted config true parses true" "true" "$(get_gamescope_overlay_debug)"
export GAMESCOPE_OVERLAY_DEBUG="false"
assert_eq "env false beats config true" "false" "$(get_gamescope_overlay_debug)"
export GAMESCOPE_OVERLAY_DEBUG="0"
assert_eq "env 0 beats config true" "false" "$(get_gamescope_overlay_debug)"
export GAMESCOPE_OVERLAY_DEBUG="no"
assert_eq "env no beats config true" "false" "$(get_gamescope_overlay_debug)"
export GAMESCOPE_OVERLAY_DEBUG="maybe"
assert_eq "unrecognized env falls through to config true" "true" "$(get_gamescope_overlay_debug)"

printf 'GAMESCOPE_OVERLAY_DEBUG=false\n' > "${CONFIG_FILE}"
export GAMESCOPE_OVERLAY_DEBUG="true"
assert_eq "env true beats config false" "true" "$(get_gamescope_overlay_debug)"
assert_eq "file helper ignores env and reads false" "false" "$(_get_gamescope_overlay_debug_from_config)"

# shellcheck disable=SC1091
source "${PROJECT_DIR}/lib/configure-config-write.sh"
export GAMESCOPE_OVERLAY_DEBUG="true"
printf 'CHECK_INTERVAL=10\nGAMESCOPE_OVERLAY_DEBUG=false\n' > "${CONFIG_FILE}"
_header="$(
    _write_config_header 10 medium center 30 true true false difficult true 5 24 auto false fixed "50%x50%" "1280x720" "" ""
)"
if printf '%s\n' "${_header}" | grep -q '^GAMESCOPE_OVERLAY_DEBUG=false$'; then
    _pass "writer keeps file false when env is true"
else
    _fail "writer did not keep file false (header: $(printf '%s\n' "${_header}" | grep GAMESCOPE_OVERLAY_DEBUG || true))"
fi
printf 'GAMESCOPE_OVERLAY_DEBUG=yes\n' > "${CONFIG_FILE}"
_header="$(
    _write_config_header 10 medium center 30 true true false difficult true 5 24 auto false fixed "50%x50%" "1280x720" "" ""
)"
if printf '%s\n' "${_header}" | grep -q '^GAMESCOPE_OVERLAY_DEBUG=true$'; then
    _pass "writer normalizes a present key to true/false"
else
    _fail "writer did not normalize yes to true"
fi
printf 'CHECK_INTERVAL=10\n' > "${CONFIG_FILE}"
_header="$(
    _write_config_header 10 medium center 30 true true false difficult true 5 24 auto false fixed "50%x50%" "1280x720" "" ""
)"
if printf '%s\n' "${_header}" | grep -q 'GAMESCOPE_OVERLAY_DEBUG='; then
    _fail "writer added GAMESCOPE_OVERLAY_DEBUG when the key was absent"
else
    _pass "writer omits GAMESCOPE_OVERLAY_DEBUG when the key is absent"
fi
unset GAMESCOPE_OVERLAY_DEBUG

assert_rc "partial lock allows GAMESCOPE_OVERLAY_DEBUG false -> true" 0 \
    configure_partial_lock_validate_scalar GAMESCOPE_OVERLAY_DEBUG false true
assert_rc "partial lock allows GAMESCOPE_OVERLAY_DEBUG true -> false" 0 \
    configure_partial_lock_validate_scalar GAMESCOPE_OVERLAY_DEBUG true false
if declare -f configure_partial_lock_validate_scalar | grep -q 'GAMESCOPE_OVERLAY_DEBUG | gamescope_overlay_debug'; then
    _pass "partial lock names GAMESCOPE_OVERLAY_DEBUG as an explicit neutral arm"
else
    _fail "partial lock is missing the explicit GAMESCOPE_OVERLAY_DEBUG arm"
fi
if declare -f configure_partial_lock_validate_proposed | grep -q 'GAMESCOPE_OVERLAY_DEBUG'; then
    _fail "validate_proposed should not special-case GAMESCOPE_OVERLAY_DEBUG"
else
    _pass "validate_proposed does not wire GAMESCOPE_OVERLAY_DEBUG"
fi

assert_eq "CARDINAL items for :0 decode" ":0" "$(gamescope_decode_cardinal_display "12346, 0, 0")"
assert_eq "CARDINAL items for :1 decode" ":1" "$(gamescope_decode_cardinal_display "12602, 0, 0")"
assert_eq "xprop display line for :0 decodes" ":0" "$(gamescope_decode_cardinal_display "GAMESCOPE_MOUSE_FOCUS_DISPLAY(CARDINAL) = 12346, 0, 0")"
assert_eq "missing display property is unavailable" "unavailable" "$(gamescope_decode_cardinal_display "GAMESCOPE_MOUSE_FOCUS_DISPLAY:  not found.")"

_census_bin="${_test_dir}/census-bin"
mkdir -p "${_census_bin}"
_census_children="${_test_dir}/census-children.txt"
_census_calls="${_test_dir}/census-calls.txt"
: > "${_census_calls}"
cat > "${_census_bin}/xwininfo" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "xwininfo \$*" >> "${_census_calls}"
if [[ " \$* " == *" -root "* && " \$* " == *" -children "* ]]; then
    cat "${_census_children}"
    exit 0
fi
_id=""
_prev=""
for _arg in "\$@"; do
    if [ "\${_prev}" = "-id" ]; then
        _id="\${_arg}"
    fi
    _prev="\${_arg}"
done
case "\${_id}" in
    0x500001|0x500002)
        printf '%s\\n' "Map State: IsUnMapped"
        ;;
    *)
        printf '%s\\n' "Map State: IsViewable"
        printf '%s\\n' "  Width: 1280"
        printf '%s\\n' "  Height: 250"
        ;;
esac
exit 0
EOF
cat > "${_census_bin}/xprop" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "xprop \$*" >> "${_census_calls}"
_id=""
_prop=""
_prev=""
for _arg in "\$@"; do
    if [ "\${_prev}" = "-id" ]; then
        _id="\${_arg}"
    fi
    _prev="\${_arg}"
    case "\${_arg}" in
        STEAM_OVERLAY|_NET_WM_WINDOW_OPACITY|STEAM_INPUT_FOCUS|WM_CLASS|GAMESCOPE_MOUSE_FOCUS_DISPLAY|GAMESCOPE_KEYBOARD_FOCUS_DISPLAY|GAMESCOPE_FOCUS_DISPLAY|GAMESCOPE_FOCUSED_WINDOW|GAMESCOPE_SCALING_FILTER|STEAM_SCREEN_SCALE|_NET_CLIENT_LIST|_NET_WM_PID)
            _prop="\${_arg}"
            ;;
    esac
done
if [[ " \$* " == *" -set "* ]]; then
    exit 0
fi
if [[ " \$* " == *" -root "* && " \$* " == *"GAMESCOPE_MOUSE_FOCUS_DISPLAY"* ]]; then
    printf '%s\\n' "GAMESCOPE_MOUSE_FOCUS_DISPLAY(CARDINAL) = 12602, 0, 0"
    printf '%s\\n' "GAMESCOPE_KEYBOARD_FOCUS_DISPLAY(CARDINAL) = 12346, 0, 0"
    printf '%s\\n' "GAMESCOPE_FOCUS_DISPLAY(CARDINAL) = 12602, 0, 0"
    printf '%s\\n' "GAMESCOPE_FOCUSED_WINDOW(CARDINAL) = 99"
    exit 0
fi
case "\${_prop}" in
    _NET_CLIENT_LIST)
        printf '%s\\n' "_NET_CLIENT_LIST(WINDOW): window id # 0x40000a"
        ;;
    _NET_WM_PID)
        printf '%s\\n' "_NET_WM_PID(CARDINAL) = 424242"
        ;;
    STEAM_OVERLAY)
        printf '%s\\n' "STEAM_OVERLAY(CARDINAL) = 1"
        ;;
    _NET_WM_WINDOW_OPACITY)
        if [ "\${_id}" = "0x500002" ]; then
            printf '%s\\n' "_NET_WM_WINDOW_OPACITY(CARDINAL) = 100"
        else
            printf '%s\\n' "_NET_WM_WINDOW_OPACITY:  not found."
        fi
        ;;
    STEAM_INPUT_FOCUS)
        printf '%s\\n' "STEAM_INPUT_FOCUS(CARDINAL) = 1"
        ;;
    WM_CLASS)
        if [ "\${_id}" = "0x40000a" ]; then
            printf '%s\\n' "WM_CLASS(STRING) = \\"zenity\\", \\"Zenity\\""
        else
            printf '%s\\n' "WM_CLASS(STRING) = \\"steamwebhelper\\", \\"Steam\\""
        fi
        ;;
    GAMESCOPE_MOUSE_FOCUS_DISPLAY)
        printf '%s\\n' "GAMESCOPE_MOUSE_FOCUS_DISPLAY(CARDINAL) = 12602, 0, 0"
        ;;
    GAMESCOPE_KEYBOARD_FOCUS_DISPLAY)
        printf '%s\\n' "GAMESCOPE_KEYBOARD_FOCUS_DISPLAY(CARDINAL) = 12346, 0, 0"
        ;;
    GAMESCOPE_FOCUS_DISPLAY)
        printf '%s\\n' "GAMESCOPE_FOCUS_DISPLAY(CARDINAL) = 12602, 0, 0"
        ;;
    GAMESCOPE_FOCUSED_WINDOW)
        printf '%s\\n' "GAMESCOPE_FOCUSED_WINDOW(CARDINAL) = 99"
        ;;
    *)
        printf '%s\\n' "\${_prop}:  not found."
        ;;
esac
exit 0
EOF
chmod +x "${_census_bin}/xwininfo" "${_census_bin}/xprop"
export PATH="${_census_bin}:${PATH}"
hash -r 2>/dev/null || true

_write_children() {
    cat > "${_census_children}" <<EOF
xwininfo: Window id: 0x1 (the root window) (has no name)

  Width: 1280
  Height: 800
$1
EOF
}

window_title="SECRET_DIALOG_TITLE"
_write_children '     0x40000a "SECRET_DIALOG_TITLE": ("zenity" "Zenity")  1280x250+0+0  +0+0'
_scan="$(gamescope_overlay_scan_children "0x40000a")"
if printf '%s\n' "${_scan}" | grep -q '^predicted_overlay_wid=0x40000a$'; then
    _pass "census (a) our dialog alone predicts our wid"
else
    _fail "census (a) predicted wrong ($(printf '%s\n' "${_scan}" | grep predicted || true))"
fi
if printf '%s\n' "${_scan}" | grep -q 'SECRET_DIALOG_TITLE'; then
    _fail "census logged our dialog title"
else
    _pass "census omits our dialog title"
fi

_write_children '     0x40000a "SECRET_DIALOG_TITLE": ("zenity" "Zenity")  1280x250+0+0  +0+0
     0x500001 "Steam Overlay": ("steamwebhelper" "Steam")  1280x800+0+0  +0+0'
_scan="$(gamescope_overlay_scan_children "0x40000a")"
if printf '%s\n' "${_scan}" | grep -q '^predicted_overlay_wid=0x500001$'; then
    _pass "census (b) equal-opacity Steam listed below wins"
else
    _fail "census (b) predicted wrong ($(printf '%s\n' "${_scan}" | grep predicted || true))"
fi
if printf '%s\n' "${_scan}" | grep -q 'name=Steam Overlay'; then
    _pass "census logs the other window name"
else
    _fail "census did not log the competing window name"
fi

_write_children '     0x40000a "SECRET_DIALOG_TITLE": ("zenity" "Zenity")  1280x250+0+0  +0+0
     0x500002 "Steam Overlay": ("steamwebhelper" "Steam")  1280x800+0+0  +0+0'
_scan="$(gamescope_overlay_scan_children "0x40000a")"
if printf '%s\n' "${_scan}" | grep -q '^predicted_overlay_wid=0x40000a$'; then
    _pass "census (c) lower-opacity Steam does not win"
else
    _fail "census (c) predicted wrong ($(printf '%s\n' "${_scan}" | grep predicted || true))"
fi

_write_children '     0x40000a "SECRET_DIALOG_TITLE": ("zenity" "Zenity")  1280x250+0+0  +0+0
     0x500001 "Steam Overlay": ("steamwebhelper" "Steam")  1280x800+0+0  +0+0'
_scan="$(gamescope_overlay_scan_children "0x40000a")"
if printf '%s\n' "${_scan}" | grep -q 'wid=0x500001 map=IsUnMapped' && printf '%s\n' "${_scan}" | grep -q '^predicted_overlay_wid=0x500001$'; then
    _pass "census (d) unmapped wide overlay still counts"
else
    _fail "census (d) unmapped overlay did not count ($(printf '%s\n' "${_scan}" | grep -E '0x500001|predicted' || true))"
fi

_lines=""
_i=0
while [ "${_i}" -lt 65 ]; do
    _hex=$(printf '0x6%04x' "${_i}")
    _lines="${_lines}     ${_hex} \"extra\": (\"x\" \"X\")  100x100+0+0  +0+0
"
    _i=$((_i + 1))
done
_write_children "${_lines}"
_scan="$(gamescope_overlay_scan_children "")"
_child_n="$(printf '%s\n' "${_scan}" | grep -c '^child ' || true)"
if printf '%s\n' "${_scan}" | grep -q '^census_truncated=true$' && [ "${_child_n}" -le 64 ]; then
    _pass "census stops at 64 children"
else
    _fail "census cap failed (children=${_child_n}, truncated=$(printf '%s\n' "${_scan}" | grep census_truncated || true))"
fi

_debug_log="${_test_dir}/debug-gamescope.log"
: > "${_debug_log}"
: > "${_census_calls}"
log_to_file() { printf '%s\n' "$*" >> "${_debug_log}"; }
export env_type="gamescope"
export GAMESCOPE_OVERLAY_DEBUG="false"
unset GAMESCOPE_DEBUG_LOGGED_KEY GAMESCOPE_ATOMS_LOGGED_WID
dialog_tool="zenity"
popup_position="center"
pause_available="true"
pause_duration="5"
gamescope_debug_event="spawn"
gamescope_debug_requested_w="400"
gamescope_debug_requested_h="250"
gamescope_debug_override_w="1280"
gamescope_debug_override_h="250"
window_title="SECRET_DIALOG_TITLE"
base_message="SECRET_WARNING_BODY"
apply_gamescope_overlay_atoms "SECRET_DIALOG_TITLE" "" "424242" || true
if grep -q 'DEBUG-GAMESCOPE' "${_debug_log}"; then
    _fail "flag off emitted DEBUG-GAMESCOPE"
else
    _pass "flag off emits no DEBUG-GAMESCOPE line"
fi
if grep -q -- '-children' "${_census_calls}"; then
    _fail "flag off called xwininfo -children"
else
    _pass "flag off does not census xwininfo -children"
fi
if grep -q -- '-set STEAM_OVERLAY 1' "${_census_calls}" && grep -q -- '-set STEAM_INPUT_FOCUS 1' "${_census_calls}"; then
    _pass "flag off still sets overlay atoms"
else
    _fail "flag off did not set overlay atoms ($(cat "${_census_calls}"))"
fi

export GAMESCOPE_OVERLAY_DEBUG="true"
export GAMESCOPE_OVERLAY_DEBUG_SYNC="true"
unset GAMESCOPE_DEBUG_LOGGED_KEY GAMESCOPE_ATOMS_LOGGED_WID
: > "${_debug_log}"
: > "${_census_calls}"
_write_children '     0x40000a "SECRET_DIALOG_TITLE": ("zenity" "Zenity")  1280x250+0+0  +0+0
     0x500001 "Steam Overlay": ("steamwebhelper" "Steam")  1280x800+0+0  +0+0'
apply_gamescope_overlay_atoms "SECRET_DIALOG_TITLE" "" "424242" || true
apply_gamescope_overlay_atoms "SECRET_DIALOG_TITLE" "" "424242" || true
_begin_n="$(grep -c 'DEBUG-GAMESCOPE begin' "${_debug_log}" || true)"
_children_n="$(grep -c -- '-children' "${_census_calls}" || true)"
assert_eq "flag on logs one DEBUG-GAMESCOPE block per window" "1" "${_begin_n}"
assert_eq "flag on census runs once across the 2s re-apply" "1" "${_children_n}"
if grep -q 'dialog_tool=zenity' "${_debug_log}" && grep -q 'pause_available=true' "${_debug_log}" && grep -q 'buttons=OK + --extra-button=Pause 5 min' "${_debug_log}" && grep -q 'predicted_overlay_wid=0x500001' "${_debug_log}" && grep -q 'mouse_focus=:1' "${_debug_log}" && grep -q 'keyboard_focus=:0' "${_debug_log}" && grep -q 'requested=400x250' "${_debug_log}" && grep -q 'override=1280x250' "${_debug_log}"; then
    _pass "flag on block contains tool, buttons, geometry, focus, and census"
else
    _fail "flag on block missing expected keys ($(cat "${_debug_log}"))"
fi
if grep -q 'SECRET_DIALOG_TITLE' "${_debug_log}" || grep -q 'SECRET_WARNING_BODY' "${_debug_log}"; then
    _fail "debug log included the dialog title or warning body"
else
    _pass "debug log omits dialog title and warning body"
fi
_set_n="$(grep -c -- '-set ' "${_census_calls}" || true)"
# Three sets: STEAM_OVERLAY, STEAM_INPUT_FOCUS, opacity. Second apply repeats them.
# Debug reads must not add -set. 2 applies * 3 sets = 6.
assert_eq "debug logging does not add extra xprop -set calls" "6" "${_set_n}"

# Pause notice is an info dialog even while the warning had pause_available=true.
assert_eq "pause notice buttons (zenity) are info OK, not warning Pause" "--info OK" "$(gamescope_overlay_debug_button_summary zenity true 5 pause)"
assert_eq "pause notice buttons (yad) are the OK:0 we pass" "--info --button=OK:0" "$(gamescope_overlay_debug_button_summary yad true 5 pause)"
assert_eq "pause notice buttons (kdialog) are msgbox OK" "--msgbox OK" "$(gamescope_overlay_debug_button_summary kdialog true 5 pause)"

unset GAMESCOPE_OVERLAY_DEBUG GAMESCOPE_OVERLAY_DEBUG_SYNC GAMESCOPE_DEBUG_LOGGED_KEY
export PATH="/usr/bin:/bin"
hash -r 2>/dev/null || true

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
