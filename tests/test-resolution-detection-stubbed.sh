#!/bin/bash

###############################################################################
# Tests lib/resolution-detection.sh: X11 (xrandr), Wayland (wlr-randr, swaymsg,
# wayland-info), the gamescope environment fallback, size validation, and the
# empty-answer failure. Display tools are stub scripts on a private PATH, so the
# result does not depend on the host's real display or installed tools.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WORK="$(mktemp -d)"
trap '/bin/rm -rf "${WORK}"' EXIT
BIN="${WORK}/bin"
mkdir -p "${BIN}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/resolution-detection.sh" || exit 1

# The private PATH holds only the plain utilities the module needs. Every
# display tool is absent until a test writes a stub for it.
for tool in grep head cut sed uname; do
    ln -s "$(command -v "${tool}")" "${BIN}/${tool}"
done
export PATH="${BIN}"

_PASS=0
_FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [ "${actual}" = "${expected}" ]; then
        _PASS=$(( _PASS + 1 )); echo "  PASS  ${desc} (${actual:-<empty>})"
    else
        _FAIL=$(( _FAIL + 1 )); echo "  FAIL  ${desc}: expected '${expected}', got '${actual}'"
    fi
}

# stub NAME OUTPUT: a tool that prints OUTPUT.
stub() {
    printf '#!/bin/bash\n/bin/cat <<'"'"'EOF'"'"'\n%s\nEOF\n' "$2" > "${BIN}/$1"
    /bin/chmod +x "${BIN}/$1"
}
unstub_all() {
    /bin/rm -f "${BIN}/xrandr" "${BIN}/wlr-randr" "${BIN}/swaymsg" "${BIN}/wayland-info" "${BIN}/pgrep"
}
detect() { get_display_resolution; }

clean_env() {
    unset DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE GAMESCOPE_WIDTH GAMESCOPE_HEIGHT
}

echo "=== no detection tool ==="
unstub_all; clean_env
check "nothing available prints nothing" "" "$(detect)"
detect >/dev/null; check "nothing available returns 1" "1" "$?"

echo "=== X11 (xrandr) ==="
export DISPLAY=":0"
stub xrandr $'Screen 0: minimum 320 x 200, current 2560 x 1440\nDP-1 connected primary 2560x1440+0+0 (normal) 600mm x 340mm\nHDMI-1 connected 1920x1080+2560+0'
check "the primary display wins" "2560 1440" "$(detect)"
stub xrandr $'eDP-1 connected 1920x1080+0+0\nHDMI-1 connected 3840x2160+1920+0'
check "without a primary the first connected display is used" "1920 1080" "$(detect)"
stub xrandr $'DP-1 disconnected\nHDMI-1 disconnected'
detect >/dev/null; check "no connected display fails" "1" "$?"
stub xrandr "DP-1 connected primary 320x240+0+0"
detect >/dev/null; check "a display under 640x480 is rejected" "1" "$?"
stub xrandr "DP-1 connected primary (normal left inverted)"
detect >/dev/null; check "a connected line without a geometry fails" "1" "$?"
stub xrandr "DP-1 connected primary 640x480+0+0"
check "exactly 640x480 is accepted" "640 480" "$(detect)"

echo "=== Wayland ==="
unstub_all; clean_env
export XDG_SESSION_TYPE="wayland"
stub wlr-randr '[{"name":"DP-1","modes":[{"width": 3840, "height": 2160}]}]'
check "wlr-randr JSON" "3840 2160" "$(detect)"
stub wlr-randr '[{"width": 100, "height": 100}]'
stub swaymsg '[{"name":"eDP-1","current_mode":{"width":2880,"height":1800}}]'
check "a too-small wlr-randr answer falls through to swaymsg" "2880 1800" "$(detect)"
stub swaymsg ''
stub wayland-info 'interface: wl_output  mode: 1920x1200 @ 60Hz'
check "an empty swaymsg falls through to wayland-info" "1920 1200" "$(detect)"
unstub_all
export WAYLAND_DISPLAY="wayland-0"
stub wlr-randr '[{"width": 1600, "height": 900}]'
check "a Wayland session with WAYLAND_DISPLAY set" "1600 900" "$(detect)"
# Known gap, tracked in dev-docs/TO_DO.md: with XDG_SESSION_TYPE unset,
# WAYLAND_DISPLAY alone does not select Wayland detection, because
# `A || B && C` evaluates as `(A || B) && C`. This file does not assert that.
stub wlr-randr '[{"width": 100, "height": 100}]'
detect >/dev/null; check "no Wayland tool gives a usable size" "1" "$?"
unset WAYLAND_DISPLAY XDG_SESSION_TYPE
stub wlr-randr '[{"width": 1600, "height": 900}]'
detect >/dev/null; check "without any session hint Wayland tools are not tried" "1" "$?"

echo "=== gamescope ==="
unstub_all; clean_env
printf '#!/bin/bash\n[ "$1" = "-x" ] && [ "$2" = "gamescope" ]\n' > "${BIN}/pgrep"; /bin/chmod +x "${BIN}/pgrep"
export GAMESCOPE_WIDTH=1280 GAMESCOPE_HEIGHT=800
check "environment size when gamescope is running" "1280 800" "$(detect)"
export GAMESCOPE_WIDTH=800 GAMESCOPE_HEIGHT=600
check "800x600 is above the minimum" "800 600" "$(detect)"
export GAMESCOPE_WIDTH=100 GAMESCOPE_HEIGHT=100
detect >/dev/null; check "a too-small environment size is rejected" "1" "$?"
export GAMESCOPE_WIDTH=wide GAMESCOPE_HEIGHT=tall
detect >/dev/null; check "a non-numeric environment size is rejected" "1" "$?"
unset GAMESCOPE_WIDTH GAMESCOPE_HEIGHT
detect >/dev/null; check "gamescope with no size information fails" "1" "$?"
stub wlr-randr '[{"width": 1280, "height": 800}]'
check "gamescope also tries Wayland tools" "1280 800" "$(detect)"
unstub_all
export GAMESCOPE_WIDTH=1280 GAMESCOPE_HEIGHT=800
detect >/dev/null; check "the environment size is ignored when gamescope is not running" "1" "$?"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[ "${_FAIL}" -eq 0 ] || exit 1
