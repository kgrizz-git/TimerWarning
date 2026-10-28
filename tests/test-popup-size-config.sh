#!/bin/bash

###############################################################################
# Tests lib/config-popup-size.sh: size getters, fixed and display-based
# dimensions, custom sizes, and the 95% safe-display clamp.
# Runs headless with a temp HOME and a stubbed get_display_resolution.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "${TMP_HOME}"' EXIT
export HOME="${TMP_HOME}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/config.sh" || exit 1

CONFIG_FILE="${TMP_HOME}/sleep-warning.conf"

# Values that the assertions repeat.
SIZE_DEFAULT="medium"
DIMS_FALLBACK="1280 720"
DIMS_XSMALL="384 216"
DIMS_MEDIUM_DISPLAY="768 432"
SCREEN_2560="2560 1440"
RESOLUTION="${SCREEN_2560}"
get_display_resolution() {
    [[ -n "${RESOLUTION}" ]] || return 1
    echo "${RESOLUTION}"
}

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

write_config() {
    printf '%s\n' "$@" > "${CONFIG_FILE}"
}

echo "=== get_popup_size ==="
rm -f "${CONFIG_FILE}"
check "missing config file uses the default" "${SIZE_DEFAULT}" "$(get_popup_size)"
write_config "OTHER=1"
check "absent key uses the default" "${SIZE_DEFAULT}" "$(get_popup_size)"
for s in xsmall small medium large xlarge max custom; do
    write_config "POPUP_SIZE=${s}"
    check "named size ${s}" "${s}" "$(get_popup_size)"
done
write_config "POPUP_SIZE=1000x600"
check "pixel size" "1000x600" "$(get_popup_size)"
write_config "POPUP_SIZE=40%x60%"
check "percent size in range" "40%x60%" "$(get_popup_size)"
write_config "POPUP_SIZE=10%x60%"
check "percent width under 15 falls back" "${SIZE_DEFAULT}" "$(get_popup_size)"
write_config "POPUP_SIZE=60%x96%"
check "percent height over 95 falls back" "${SIZE_DEFAULT}" "$(get_popup_size)"
write_config "POPUP_SIZE=huge"
check "unknown name falls back" "${SIZE_DEFAULT}" "$(get_popup_size)"
write_config "  POPUP_SIZE= large "
check "leading space and space after = are tolerated" "large" "$(get_popup_size)"
write_config "POPUP_SIZE=small" "POPUP_SIZE=large"
check "first assignment wins" "small" "$(get_popup_size)"

echo "=== get_popup_size_mode ==="
rm -f "${CONFIG_FILE}"
check "missing config is fixed" "fixed" "$(get_popup_size_mode)"
write_config "POPUP_SIZE_MODE=display-based"
check "display-based" "display-based" "$(get_popup_size_mode)"
write_config "POPUP_SIZE_MODE=Display-Based"
check "mode is case-insensitive" "display-based" "$(get_popup_size_mode)"
write_config "POPUP_SIZE_MODE=fixed"
check "fixed" "fixed" "$(get_popup_size_mode)"
write_config "POPUP_SIZE_MODE=sideways"
check "unknown mode is fixed" "fixed" "$(get_popup_size_mode)"

echo "=== get_popup_size_custom and absolute ==="
rm -f "${CONFIG_FILE}"
check "custom default" "50%x50%" "$(get_popup_size_custom)"
check "absolute default" "1280x720" "$(get_popup_size_custom_absolute)"
write_config "POPUP_SIZE_CUSTOM=70%x40%" "POPUP_SIZE_CUSTOM_ABSOLUTE=1600x900"
check "custom is read" "70%x40%" "$(get_popup_size_custom)"
check "absolute is read" "1600x900" "$(get_popup_size_custom_absolute)"
write_config "POPUP_SIZE_CUSTOM=" "POPUP_SIZE_CUSTOM_ABSOLUTE=wide"
check "empty custom uses the default" "50%x50%" "$(get_popup_size_custom)"
check "malformed absolute uses the default" "1280x720" "$(get_popup_size_custom_absolute)"

echo "=== clamp_popup_dimensions_to_safe_display_max ==="
check "under the limit is unchanged" "1000 500" "$(clamp_popup_dimensions_to_safe_display_max 1000 500 2560 1440)"
check "both axes are clamped to 95%" "2432 1368" "$(clamp_popup_dimensions_to_safe_display_max 5000 5000 2560 1440)"
check "only width is clamped" "950 500" "$(clamp_popup_dimensions_to_safe_display_max 2000 500 1000 1000)"
check "exactly 95% is kept" "950 950" "$(clamp_popup_dimensions_to_safe_display_max 950 950 1000 1000)"

echo "=== get_popup_dimensions: fixed mode ==="
rm -f "${CONFIG_FILE}"
check "xsmall" "${DIMS_XSMALL}" "$(get_popup_dimensions xsmall)"
check "small" "400 250" "$(get_popup_dimensions small)"
check "${SIZE_DEFAULT}" "800 500" "$(get_popup_dimensions medium)"
check "large" "1230 720" "$(get_popup_dimensions large)"
check "xlarge" "1845 1080" "$(get_popup_dimensions xlarge)"
check "max" "2214 1296" "$(get_popup_dimensions max)"
check "custom with nothing configured" "${DIMS_FALLBACK}" "$(get_popup_dimensions custom)"

echo "=== get_popup_dimensions: display-based mode ==="
write_config "POPUP_SIZE_MODE=display-based"
check "xsmall is 15%" "${DIMS_XSMALL}" "$(get_popup_dimensions xsmall)"
check "small is 20%" "512 288" "$(get_popup_dimensions small)"
check "medium is 30%" "${DIMS_MEDIUM_DISPLAY}" "$(get_popup_dimensions medium)"
check "large is 50%" "${DIMS_FALLBACK}" "$(get_popup_dimensions large)"
check "xlarge is 75%" "1920 1080" "$(get_popup_dimensions xlarge)"
check "max is 90%" "2304 1296" "$(get_popup_dimensions max)"
check "custom with nothing configured is 50%" "${DIMS_FALLBACK}" "$(get_popup_dimensions custom)"
RESOLUTION="1920 1080"
check "medium scales with the detected resolution" "576 324" "$(get_popup_dimensions medium)"
RESOLUTION=""
check "xsmall falls back to pixels without a resolution" "${DIMS_XSMALL}" "$(get_popup_dimensions xsmall)"
check "small falls back to pixels" "512 288" "$(get_popup_dimensions small)"
check "medium falls back to pixels" "${DIMS_MEDIUM_DISPLAY}" "$(get_popup_dimensions medium)"
check "large falls back to pixels" "1230 720" "$(get_popup_dimensions large)"
check "xlarge falls back to pixels" "1845 1080" "$(get_popup_dimensions xlarge)"
check "max falls back to pixels" "2214 1296" "$(get_popup_dimensions max)"
check "custom falls back to pixels" "${DIMS_FALLBACK}" "$(get_popup_dimensions custom)"
RESOLUTION="${SCREEN_2560}"

echo "=== get_popup_dimensions: custom ==="
write_config "POPUP_SIZE_CUSTOM=60%x40%"
check "custom percent uses the resolution" "1536 576" "$(get_popup_dimensions custom)"
write_config "POPUP_SIZE_CUSTOM=60%x40%" "POPUP_SIZE_CUSTOM_ABSOLUTE=1000x800"
RESOLUTION=""
check "custom percent without a resolution uses the absolute size" "1000 800" "$(get_popup_dimensions custom)"
RESOLUTION="${SCREEN_2560}"
write_config "POPUP_SIZE_CUSTOM=99%x40%" "POPUP_SIZE_CUSTOM_ABSOLUTE=1000x800"
check "custom percent over 95 uses the absolute size" "1000 800" "$(get_popup_dimensions custom)"
write_config "POPUP_SIZE_CUSTOM=99%x40%" "POPUP_SIZE_CUSTOM_ABSOLUTE=junk"
check "custom percent over 95 with a bad absolute uses 1280x720" "${DIMS_FALLBACK}" "$(get_popup_dimensions custom)"
write_config "POPUP_SIZE_CUSTOM=1500x900"
check "custom pixels" "1500 900" "$(get_popup_dimensions custom)"
write_config "POPUP_SIZE_CUSTOM=9000x9000"
check "custom pixels are clamped to 95% of the display" "2432 1368" "$(get_popup_dimensions custom)"
write_config "POPUP_SIZE_CUSTOM=garbage" "POPUP_SIZE_CUSTOM_ABSOLUTE=900x700"
check "malformed custom uses the absolute size" "900 700" "$(get_popup_dimensions custom)"
write_config "POPUP_SIZE_CUSTOM=garbage" "POPUP_SIZE_CUSTOM_ABSOLUTE=junk"
check "malformed custom and absolute use 1280x720" "${DIMS_FALLBACK}" "$(get_popup_dimensions custom)"

echo "=== get_popup_dimensions: literal sizes ==="
rm -f "${CONFIG_FILE}"
check "pixel size" "1000 600" "$(get_popup_dimensions 1000x600)"
check "pixel size below the minimum becomes xsmall" "${DIMS_XSMALL}" "$(get_popup_dimensions 300x100)"
check "pixel size is clamped to 95% of the display" "2432 1368" "$(get_popup_dimensions 9000x9000)"
check "percent size uses the resolution" "1024 720" "$(get_popup_dimensions 40%x50%)"
RESOLUTION=""
check "percent size without a resolution assumes 2560x1440" "1024 720" "$(get_popup_dimensions 40%x50%)"
RESOLUTION="${SCREEN_2560}"
check "percent size out of range becomes medium pixels" "${DIMS_MEDIUM_DISPLAY}" "$(get_popup_dimensions 99%x50%)"
check "unknown size becomes medium pixels" "${DIMS_MEDIUM_DISPLAY}" "$(get_popup_dimensions nonsense)"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[[ "${_FAIL}" -eq 0 ]] || exit 1
