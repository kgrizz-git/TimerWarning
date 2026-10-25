#!/bin/bash
# Verify popup icon flags: installers copy the icon, and each dialog tool gets the
# window-icon flag only when the icon exists and the tool's help lists the option.
# Inputs: lib/popup-dialog-implementations.sh, lib/install-{linux,darwin}.sh, assets/.
# Output: PASS lines or a failing exit. Uses fake tools under tmp/; no real dialogs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${ROOT}/tmp"
WORK="$(mktemp -d "${ROOT}/tmp/popup-icon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

print_success() { :; }
print_error() { :; }
print_warning() { :; }
print_info() { :; }

for installer in install-linux.sh install-darwin.sh; do
    (
        export HOME="${WORK}/home-${installer}"
        dest="${WORK}/lib-${installer}"
        mkdir -p "$HOME" "$dest"
        SCRIPT_DIR="$ROOT"
        LIB_DIR="$dest"
        # shellcheck disable=SC1090
        source "${ROOT}/lib/${installer}"
        install_copy_icon
        cmp -s "${ROOT}/assets/icon-256.png" "${dest}/timerwarning-icon.png"
    ) || fail "${installer} did not copy the icon"
done
echo "PASS: installers copy the icon"

# Fake dialog tools: $1 tool name, $2 help text printed for any --help* flag.
make_tool() {
    local bin="$1" name="$2" help="$3"
    mkdir -p "$bin"
    printf '#!/bin/sh\necho "%s"\n' "$help" > "${bin}/${name}"
    chmod +x "${bin}/${name}"
}

# Installed layout: module copied beside timerwarning-icon.png.
INST="${WORK}/installed"
mkdir -p "$INST"
cp "${ROOT}/lib/popup-dialog-implementations.sh" "$INST/"
cp "${ROOT}/assets/icon-256.png" "${INST}/timerwarning-icon.png"

run_case() {
    local module_dir="$1" tool="$2" help="$3"
    local bin="${WORK}/bin-$RANDOM"
    make_tool "$bin" "$tool" "$help"
    PATH="${bin}:${PATH}" bash -c '
        source "$1/popup-dialog-implementations.sh"
        _popup_icon_args "$2"
        printf "%s\n" "${_dlg_icon[@]+"${_dlg_icon[@]}"}"
    ' _ "$module_dir" "$tool"
}

out="$(run_case "$INST" yad "  --window-icon=ICONPATH  Set the window icon")"
[ "$out" = "--window-icon=${INST}/timerwarning-icon.png" ] || fail "yad: got '${out}'"
out="$(run_case "$INST" zenity "  --window-icon=ICONPATH  Set the window icon")"
[ "$out" = "--window-icon=${INST}/timerwarning-icon.png" ] || fail "zenity: got '${out}'"
out="$(run_case "$INST" kdialog "  --icon <icon>  Use 'icon' as the application icon.")"
[ "$out" = "$(printf -- '--icon\n%s' "${INST}/timerwarning-icon.png")" ] || fail "kdialog: got '${out}'"
echo "PASS: supported tools get the icon flag"

out="$(run_case "$INST" zenity "  --title=TITLE  Set the dialog title")"
[ -z "$out" ] || fail "zenity without --window-icon in help got '${out}'"
echo "PASS: tools that do not list the option get no flag"

BARE="${WORK}/bare"
mkdir -p "$BARE"
cp "${ROOT}/lib/popup-dialog-implementations.sh" "$BARE/"
out="$(run_case "$BARE" yad "  --window-icon=ICONPATH")"
[ -z "$out" ] || fail "missing icon file still produced '${out}'"
echo "PASS: missing icon file gives no flag"

# Repo layout: lib/ module falls back to assets/icon-256.png.
out="$(run_case "${ROOT}/lib" yad "  --window-icon=ICONPATH")"
[ "$out" = "--window-icon=${ROOT}/lib/../assets/icon-256.png" ] || fail "repo fallback: got '${out}'"
echo "PASS: repo checkout uses assets/icon-256.png"
