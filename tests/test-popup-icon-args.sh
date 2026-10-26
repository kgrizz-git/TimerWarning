#!/bin/bash
# Verify popup icon flags: installers copy the icon, and each dialog tool gets the
# window-icon flag only when the icon exists and the tool's help lists the option.
# Also checks the help-probe deadline (GNU timeout and the bash fallback), the
# positive and negative probe caches, paths that contain spaces, and that the
# warning spawn actually places those flags on the dialog command.
# Inputs: lib/popup-dialog-implementations.sh, lib/install-{linux,darwin}.sh, assets/.
# Output: PASS lines or a failing exit. Uses fake tools under tmp/; no real dialogs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Help text repeated by the fake dialog tools. Sonar treats each copy as a duplicate literal.
HELP_WINDOW_ICON="  --window-icon=ICONPATH"
HELP_WINDOW_ICON_DETAIL="${HELP_WINDOW_ICON}  Set the window icon"
mkdir -p "${ROOT}/tmp"
WORK="$(mktemp -d "${ROOT}/tmp/popup-icon.XXXXXX")"
cleanup() {
    if [[ -f "${WORK:-}/sleep-pids" ]]; then
        local sleep_pid
        while read -r sleep_pid; do
            kill -KILL "${sleep_pid}" 2>/dev/null || true
        done < "${WORK}/sleep-pids"
    fi
    if [[ -f "${WORK:-}/hold-pids" ]]; then
        local hold_pid
        while read -r hold_pid; do
            kill -KILL "${hold_pid}" 2>/dev/null || true
        done < "${WORK}/hold-pids"
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

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

# A path with spaces stays one argument through the installer copy and the flag.
SPACE_LIB="${WORK}/lib dir"
mkdir -p "${SPACE_LIB}" "${WORK}/home-space"
(
    export HOME="${WORK}/home-space"
    SCRIPT_DIR="$ROOT"
    LIB_DIR="${SPACE_LIB}"
    # shellcheck disable=SC1090
    source "${ROOT}/lib/install-linux.sh"
    install_copy_icon
)
cmp -s "${ROOT}/assets/icon-256.png" "${SPACE_LIB}/timerwarning-icon.png" \
    || fail "installer copy broke a path with spaces"
echo "PASS: installer copy accepts a path with spaces"

python3 - "${ROOT}/assets/icon-256.png" <<'PY' || fail "icon-256.png is not a 256x256 PNG"
import struct
import sys
data = open(sys.argv[1], "rb").read(24)
if data[:8] != b"\x89PNG\r\n\x1a\n":
    sys.exit(1)
width, height = struct.unpack(">II", data[16:24])
sys.exit(0 if (width, height) == (256, 256) else 1)
PY
echo "PASS: icon-256.png is a 256x256 PNG"

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

case_idx=0
run_case() {
    local module_dir="$1" tool="$2" help="$3"
    case_idx=$((case_idx + 1))
    local bin="${WORK}/bin-${tool}-${case_idx}"
    make_tool "$bin" "$tool" "$help"
    PATH="${bin}:${PATH}" "${BASH:-bash}" -c '
        source "$1/popup-dialog-implementations.sh"
        _popup_icon_args "$2"
        printf "%s\n" "${_dlg_icon[@]+"${_dlg_icon[@]}"}"
    ' _ "$module_dir" "$tool"
}

out="$(run_case "$INST" yad "${HELP_WINDOW_ICON_DETAIL}")"
[[ "$out" = "--window-icon=${INST}/timerwarning-icon.png" ]] || fail "yad: got '${out}'"
out="$(run_case "$INST" zenity "${HELP_WINDOW_ICON_DETAIL}")"
[[ "$out" = "--window-icon=${INST}/timerwarning-icon.png" ]] || fail "zenity: got '${out}'"
out="$(run_case "$INST" kdialog "  --icon <icon>  Use 'icon' as the application icon.")"
[[ "$out" = "$(printf -- '--icon\n%s' "${INST}/timerwarning-icon.png")" ]] || fail "kdialog: got '${out}'"
echo "PASS: supported tools get the icon flag"

out="$(run_case "$INST" zenity "  --title=TITLE  Set the dialog title")"
[[ -z "$out" ]] || fail "zenity without --window-icon in help got '${out}'"
echo "PASS: tools that do not list the option get no flag"

BARE="${WORK}/bare"
mkdir -p "$BARE"
cp "${ROOT}/lib/popup-dialog-implementations.sh" "$BARE/"
out="$(run_case "$BARE" yad "${HELP_WINDOW_ICON}")"
[[ -z "$out" ]] || fail "missing icon file still produced '${out}'"
echo "PASS: missing icon file gives no flag"

# Repo layout: lib/ module falls back to assets/icon-256.png.
out="$(run_case "${ROOT}/lib" yad "${HELP_WINDOW_ICON}")"
[[ "$out" = "--window-icon=${ROOT}/lib/../assets/icon-256.png" ]] || fail "repo fallback: got '${out}'"
echo "PASS: repo checkout uses assets/icon-256.png"

# A stalled toolkit must not hold up the spawn: the help probe has a deadline.
HANG="${WORK}/bin-hang"
mkdir -p "$HANG"
printf '#!/bin/sh\nexec sleep 30\n' > "${HANG}/yad"
chmod +x "${HANG}/yad"
start=$SECONDS
out="$(PATH="${HANG}:${PATH}" "${BASH:-bash}" -c '
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_args yad
    printf "%s\n" "${_dlg_icon[@]+"${_dlg_icon[@]}"}"
' _ "$INST")"
elapsed=$((SECONDS - start))
[[ -z "$out" ]] || fail "hung yad still produced '${out}'"
[[ "$elapsed" -le 5 ]] || fail "hung help probe took ${elapsed}s"
echo "PASS: hung help probe is cut off (${elapsed}s)"

# Countdown respawns reuse the cached probe result.
COUNT="${WORK}/bin-count"
mkdir -p "$COUNT"
printf '#!/bin/sh\necho x >> "%s"\necho "%s"\n' "${WORK}/probe-count" "${HELP_WINDOW_ICON}" > "${COUNT}/yad"
chmod +x "${COUNT}/yad"
PATH="${COUNT}:${PATH}" "${BASH:-bash}" -c '
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_args yad; _popup_icon_args yad; _popup_icon_args yad
    [[ "${#_dlg_icon[@]}" -eq 1 ]]
' _ "$INST" || fail "cached call lost the icon flag"
[[ "$(wc -l < "${WORK}/probe-count" | tr -d ' ')" = "1" ]] || fail "help probe ran more than once"
echo "PASS: help probe runs once per process"

# A "no" answer is cached too, so a countdown respawn does not probe again.
NEG="${WORK}/bin-neg"
mkdir -p "$NEG"
printf '#!/bin/sh\necho x >> "%s"\necho "  --title=TITLE"\n' "${WORK}/probe-neg" > "${NEG}/zenity"
chmod +x "${NEG}/zenity"
PATH="${NEG}:${PATH}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_args zenity
    [[ "${#_dlg_icon[@]}" -eq 0 ]]
    _popup_icon_args zenity
    [[ "${#_dlg_icon[@]}" -eq 0 ]]
' _ "$INST" || fail "negative cache returned an icon flag"
[[ "$(wc -l < "${WORK}/probe-neg" | tr -d ' ')" = "1" ]] || fail "negative help probe ran more than once"
echo "PASS: unsupported help result is cached"

# Paths with spaces stay a single flag word.
SPACE_MOD="${WORK}/module dir"
mkdir -p "$SPACE_MOD"
cp "${ROOT}/lib/popup-dialog-implementations.sh" "$SPACE_MOD/"
cp "${ROOT}/assets/icon-256.png" "${SPACE_MOD}/timerwarning-icon.png"
out="$(run_case "$SPACE_MOD" yad "${HELP_WINDOW_ICON}")"
[[ "$out" = "--window-icon=${SPACE_MOD}/timerwarning-icon.png" ]] || fail "spaced yad path: got '${out}'"
out="$(run_case "$SPACE_MOD" kdialog "  --icon <icon>")"
[[ "$out" = "$(printf -- '--icon\n%s' "${SPACE_MOD}/timerwarning-icon.png")" ]] || fail "spaced kdialog path: got '${out}'"
echo "PASS: icon paths with spaces stay one argument"

# Hide GNU timeout so the bash sleep watchdog is what enforces the deadline.
MASK="${WORK}/bin-mask"
mkdir -p "$MASK"
for cmd in sleep grep dirname; do
    target="$(command -v "$cmd")" || fail "missing ${cmd}"
    ln -s "$target" "${MASK}/${cmd}"
done
start=$SECONDS
out="$(PATH="${HANG}:${MASK}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_args yad
    printf "%s\n" "${_dlg_icon[@]+"${_dlg_icon[@]}"}"
' _ "$INST")"
elapsed=$((SECONDS - start))
[[ -z "$out" ]] || fail "bash-fallback hung yad produced '${out}'"
[[ "$elapsed" -ge 1 && "$elapsed" -le 5 ]] || fail "bash-fallback help probe took ${elapsed}s"
echo "PASS: bash help-probe fallback is cut off (${elapsed}s)"

# A fast tool must not leave the watcher's sleep behind, and must not see the
# caller's stdin. The hang case above lets that sleep finish on its own.
REAL_SLEEP="$(command -v sleep)"
rm -f "${MASK}/sleep"
cat > "${MASK}/sleep" <<EOF
#!/bin/sh
echo \$\$ >> $(printf '%q' "${WORK}/sleep-pids")
exec $(printf '%q' "${REAL_SLEEP}") "\$@"
EOF
chmod +x "${MASK}/sleep"
: > "${WORK}/sleep-pids"

FAST="${WORK}/bin-fast"
mkdir -p "$FAST"
cat > "${FAST}/yad" <<EOF
#!/bin/sh
dd if=/dev/stdin of=$(printf '%q' "${WORK}/probe-stdin") bs=64 count=1 2>/dev/null || true
printf '%s\n' "${HELP_WINDOW_ICON}"
exec $(printf '%q' "${REAL_SLEEP}") 0.3
EOF
chmod +x "${FAST}/yad"
: > "${WORK}/probe-stdin"
printf 'SECRET-MARKER\n' | PATH="${FAST}:${MASK}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_args yad
' _ "$INST" || fail "fast bash-fallback probe failed"
[[ ! -s "${WORK}/probe-stdin" ]] || fail "bash fallback probe read caller stdin: $(cat "${WORK}/probe-stdin")"
[[ -s "${WORK}/sleep-pids" ]] || fail "bash fallback watcher never started sleep"
while read -r sleep_pid; do
    if kill -0 "${sleep_pid}" 2>/dev/null; then
        kill -KILL "${sleep_pid}" 2>/dev/null || true
        fail "bash fallback left sleep ${sleep_pid} running"
    fi
done < "${WORK}/sleep-pids"
echo "PASS: bash fallback reaps its sleep and ignores caller stdin"

# A wrapper can exit after starting a child that inherits the help pipe.
# Without a process-group kill, grep waits until that child exits.
write_holder() {
    local path="$1" print_help="$2"
    cat > "$path" <<EOF
#!/bin/sh
if [ ${print_help} = yes ]; then
    printf '%s\n' $(printf '%q' "${HELP_WINDOW_ICON}")
fi
$(printf '%q' "${REAL_SLEEP}") 30 &
echo \$! >> $(printf '%q' "${WORK}/hold-pids")
exit 0
EOF
    chmod +x "$path"
}
SILENT="${WORK}/bin-hold-silent"
PRINT="${WORK}/bin-hold-print"
mkdir -p "$SILENT" "$PRINT"
write_holder "${SILENT}/yad" no
write_holder "${PRINT}/yad" yes

run_holder() {
    local bin="$1" output_file="$2"
    local inner guard
    : > "${WORK}/hold-pids"
    set -m
    PATH="${bin}:${MASK}" "${BASH:-bash}" -c '
        set -euo pipefail
        source "$1/popup-dialog-implementations.sh"
        _popup_icon_args yad
        printf "%s\n" "${_dlg_icon[@]+"${_dlg_icon[@]}"}"
    ' _ "$INST" > "${output_file}" &
    inner=$!
    set +m
    (
        # Own the deadline sleep so SIGTERM from the parent reaps it.
        sleep 6 &
        guard_sleep=$!
        trap 'kill -TERM "${guard_sleep}" 2>/dev/null || true; exit 0' TERM
        wait "${guard_sleep}" 2>/dev/null || true
        kill -KILL "${inner}" 2>/dev/null || true
    ) &
    guard=$!
    wait "${inner}" 2>/dev/null || true
    kill -TERM "${guard}" 2>/dev/null || true
    wait "${guard}" 2>/dev/null || true
}

start=$SECONDS
run_holder "$SILENT" "${WORK}/hold-silent-out"
elapsed=$((SECONDS - start))
[[ "$elapsed" -le 3 ]] || fail "silent holder blocked the reader for ${elapsed}s"
[[ -s "${WORK}/hold-pids" ]] || fail "silent holder did not start a child"
while read -r hold_pid; do
    if kill -0 "${hold_pid}" 2>/dev/null; then
        kill -KILL "${hold_pid}" 2>/dev/null || true
        fail "silent holder left child ${hold_pid} running"
    fi
done < "${WORK}/hold-pids"
[[ -z "$(cat "${WORK}/hold-silent-out")" ]] || fail "silent holder produced a flag"
echo "PASS: bash fallback does not wait on a child holding the help pipe (${elapsed}s)"

start=$SECONDS
run_holder "$PRINT" "${WORK}/hold-print-out"
elapsed=$((SECONDS - start))
[[ "$elapsed" -le 3 ]] || fail "printing holder blocked the reader for ${elapsed}s"
[[ "$(cat "${WORK}/hold-print-out")" = "--window-icon=${INST}/timerwarning-icon.png" ]] \
    || fail "printing holder flag: $(cat "${WORK}/hold-print-out")"
while read -r hold_pid; do
    if kill -0 "${hold_pid}" 2>/dev/null; then
        kill -KILL "${hold_pid}" 2>/dev/null || true
        fail "printing holder left child ${hold_pid} running"
    fi
done < "${WORK}/hold-pids"
echo "PASS: bash fallback keeps the icon flag and reaps the holder child (${elapsed}s)"

# A stand-in named timeout forces the timeout branch on machines without GNU timeout.
# It drops the deadline arguments and runs the tool with the stdin it inherited.
FAKE_TIMEOUT="${WORK}/bin-timeout"
mkdir -p "$FAKE_TIMEOUT"
cat > "${FAKE_TIMEOUT}/timeout" <<'EOF'
#!/bin/sh
shift 2
exec "$@"
EOF
chmod +x "${FAKE_TIMEOUT}/timeout"
: > "${WORK}/probe-stdin"
printf 'SECRET-MARKER\n' | PATH="${FAST}:${FAKE_TIMEOUT}:${MASK}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_args yad
' _ "$INST" || fail "timeout probe failed"
[[ ! -s "${WORK}/probe-stdin" ]] || fail "timeout probe read caller stdin: $(cat "${WORK}/probe-stdin")"
echo "PASS: timeout probe ignores caller stdin"

# The spawn path must pass the same flag the helper built.
make_spawn_tool() {
    local bin="$1" name="$2" help="$3" record="$4"
    local help_q record_q
    mkdir -p "$bin"
    help_q="$(printf '%q' "$help")"
    record_q="$(printf '%q' "$record")"
    cat > "${bin}/${name}" <<EOF
#!/bin/sh
for arg in "\$@"; do
    case "\$arg" in
        --help*)
            printf '%s\\n' ${help_q}
            exit 0
            ;;
    esac
done
printf '%s\\n' "\$@" > ${record_q}
exec sleep 30
EOF
    chmod +x "${bin}/${name}"
}

spawn_case() {
    local tool="$1" help="$2" record="$3"
    case_idx=$((case_idx + 1))
    local bin="${WORK}/bin-spawn-${tool}-${case_idx}"
    make_spawn_tool "$bin" "$tool" "$help" "$record"
    PATH="${bin}:${PATH}" "${BASH:-bash}" -c '
        set -euo pipefail
        source "$1/popup-dialog-implementations.sh"
        dialog_tool=$2
        pause_available=false
        pause_duration=
        window_title=TimerWarning
        width=100
        height=100
        popup_position=center
        window_tool=
        zenity_output_file=
        POPUP_FORCE_X11_BACKEND=false
        popup_pid=
        _popup_spawn_warning_dialog "time to stop"
        if [ -n "${popup_pid}" ]; then
            kill -TERM "${popup_pid}" 2>/dev/null || true
            wait "${popup_pid}" 2>/dev/null || true
        fi
    ' _ "$SPACE_MOD" "$tool" || fail "${tool} spawn helper failed"
}

spawn_case yad "${HELP_WINDOW_ICON}" "${WORK}/spawn-yad"
grep -qxF -- "--window-icon=${SPACE_MOD}/timerwarning-icon.png" "${WORK}/spawn-yad" \
    || fail "yad spawn args: $(cat "${WORK}/spawn-yad")"
spawn_case kdialog "  --icon <icon>" "${WORK}/spawn-kdialog"
[[ "$(sed -n '1p' "${WORK}/spawn-kdialog")" = "--icon" ]] || fail "kdialog spawn missing --icon"
[[ "$(sed -n '2p' "${WORK}/spawn-kdialog")" = "${SPACE_MOD}/timerwarning-icon.png" ]] \
    || fail "kdialog spawn path: $(sed -n '2p' "${WORK}/spawn-kdialog")"
spawn_case zenity "${HELP_WINDOW_ICON}" "${WORK}/spawn-zenity"
grep -qxF -- "--window-icon=${SPACE_MOD}/timerwarning-icon.png" "${WORK}/spawn-zenity" \
    || fail "zenity spawn args: $(cat "${WORK}/spawn-zenity")"
echo "PASS: warning spawn passes the icon flag"
