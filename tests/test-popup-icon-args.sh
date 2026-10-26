#!/bin/bash
# Verify popup icon flags: installers copy the icon, and each dialog tool gets the
# window-icon flag only when the icon exists and the tool's help lists the option.
# Also checks the help-probe deadline (including when a GNU-style timeout is
# on PATH), the positive and negative probe caches, paths that contain spaces,
# and that the warning spawn actually places those flags on the dialog command.
# Inputs: lib/popup-dialog-implementations.sh, lib/install-{linux,darwin}.sh, assets/.
# Output: PASS lines or a failing exit. Uses fake tools under tmp/; no real dialogs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Help text repeated by the fake dialog tools. Sonar treats each copy as a duplicate literal.
HELP_WINDOW_ICON="  --window-icon=ICONPATH"
HELP_KDIALOG_ICON="  --icon <icon>"
# Stdin marker fed to the help probe. One definition so the same bytes are not repeated.
STDIN_MARKER='SECRET-MARKER'
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
out="$(run_case "$SPACE_MOD" kdialog "${HELP_KDIALOG_ICON}")"
[[ "$out" = "$(printf -- '--icon\n%s' "${SPACE_MOD}/timerwarning-icon.png")" ]] || fail "spaced kdialog path: got '${out}'"
echo "PASS: icon paths with spaces stay one argument"

# Hide GNU timeout so the bash sleep watchdog is what enforces the deadline.
MASK="${WORK}/bin-mask"
mkdir -p "$MASK"
for cmd in sleep grep dirname dd mktemp cat rm; do
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
# The fixture must record inherited stdin. Otherwise an empty probe-stdin file
# would pass even when the probe forgot to redirect stdin.
printf '%s\n' "${STDIN_MARKER}" | PATH="${FAST}:${MASK}" "${FAST}/yad" >/dev/null || true
grep -q "${STDIN_MARKER}" "${WORK}/probe-stdin" \
    || fail "stdin fixture did not record inherited stdin: $(cat "${WORK}/probe-stdin" 2>/dev/null || true)"
: > "${WORK}/probe-stdin"
# Call the probe directly. Inside a pipeline, Bash already points a background
# command's stdin at /dev/null, so the _popup_icon_args checks below cannot
# tell whether this redirect is present.
printf '%s\n' "${STDIN_MARKER}" | PATH="${FAST}:${MASK}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_help_probe yad --help-all
' _ "$INST" > "${WORK}/probe-direct-out"
[[ ! -s "${WORK}/probe-stdin" ]] || fail "direct help probe read caller stdin: $(cat "${WORK}/probe-stdin")"
echo "PASS: direct help probe ignores caller stdin"
PATH="${MASK}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    yad() { printf "%s\n" "window-icon-from-function"; }
    _popup_icon_help_probe yad --help-all
' _ "$INST" > "${WORK}/probe-function-out"
[[ "$(cat "${WORK}/probe-function-out")" == "window-icon-from-function" ]] \
    || fail "shell-function tool produced: $(cat "${WORK}/probe-function-out")"
echo "PASS: help probe can run a shell function"
# Closing fd 8 was the old way of hiding the setpgid notice. A caller that
# owns fd 8 must still be able to write to it after the probe returns.
PATH="${MASK}:${PATH}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    exec 8>"$2"
    _popup_icon_help_probe true
    printf "fd8-ok\n" >&8
' _ "$INST" "${WORK}/fd8-marker" || fail "fd 8 probe failed"
[[ "$(cat "${WORK}/fd8-marker")" == "fd8-ok" ]] \
    || fail "help probe closed caller fd 8: $(cat "${WORK}/fd8-marker" 2>/dev/null || true)"
echo "PASS: help probe leaves caller fd 8 open"
printf '%s\n' "${STDIN_MARKER}" | PATH="${FAST}:${MASK}" "${BASH:-bash}" -c '
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
    local bin="$1" output_file="$2" path_prefix="${3:-}"
    local inner guard probe_path
    : > "${WORK}/hold-pids"
    probe_path="${bin}:${MASK}"
    [[ -z "${path_prefix}" ]] || probe_path="${path_prefix}:${probe_path}"
    set -m
    PATH="${probe_path}" "${BASH:-bash}" -c '
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

# A timeout with GNU timeout's early-exit hole: wait for the direct child and
# leave descendants running. The probe must still bound the reader.
LEAKY="${WORK}/bin-leaky-timeout"
mkdir -p "$LEAKY"
cat > "${LEAKY}/timeout" <<'EOF'
#!/bin/sh
shift 2
"$@" &
child=$!
wait "$child"
EOF
cp "${LEAKY}/timeout" "${LEAKY}/gtimeout"
chmod +x "${LEAKY}/timeout" "${LEAKY}/gtimeout"

start=$SECONDS
run_holder "$SILENT" "${WORK}/hold-leaky-silent-out" "$LEAKY"
elapsed=$((SECONDS - start))
[[ "$elapsed" -le 3 ]] || fail "leaky timeout left the silent holder blocking for ${elapsed}s"
[[ -s "${WORK}/hold-pids" ]] || fail "leaky-timeout silent holder did not start a child"
while read -r hold_pid; do
    if kill -0 "${hold_pid}" 2>/dev/null; then
        kill -KILL "${hold_pid}" 2>/dev/null || true
        fail "leaky timeout left silent holder child ${hold_pid} running"
    fi
done < "${WORK}/hold-pids"
[[ -z "$(cat "${WORK}/hold-leaky-silent-out")" ]] || fail "leaky-timeout silent holder produced a flag"
echo "PASS: help probe does not wait on a pipe holder when timeout is installed (${elapsed}s)"

start=$SECONDS
run_holder "$PRINT" "${WORK}/hold-leaky-print-out" "$LEAKY"
elapsed=$((SECONDS - start))
[[ "$elapsed" -le 3 ]] || fail "leaky timeout left the printing holder blocking for ${elapsed}s"
[[ "$(cat "${WORK}/hold-leaky-print-out")" = "--window-icon=${INST}/timerwarning-icon.png" ]] \
    || fail "leaky-timeout printing holder flag: $(cat "${WORK}/hold-leaky-print-out")"
while read -r hold_pid; do
    if kill -0 "${hold_pid}" 2>/dev/null; then
        kill -KILL "${hold_pid}" 2>/dev/null || true
        fail "leaky timeout left printing holder child ${hold_pid} running"
    fi
done < "${WORK}/hold-pids"
echo "PASS: help probe keeps the icon flag when timeout is installed (${elapsed}s)"

# The same stand-in sits on PATH for a fast tool. Stdin stays /dev/null.
: > "${WORK}/probe-stdin"
printf '%s\n' "${STDIN_MARKER}" | PATH="${FAST}:${LEAKY}:${MASK}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_args yad
' _ "$INST" || fail "timeout-on-PATH probe failed"
[[ ! -s "${WORK}/probe-stdin" ]] || fail "probe read caller stdin with timeout on PATH: $(cat "${WORK}/probe-stdin")"
echo "PASS: help probe ignores caller stdin when timeout is installed"

# A leader that ignores SIGTERM must still die on the follow-up SIGKILL (~2s).
# A shell wrapper runs the real Python binary. command -v python3 is often a
# pyenv shim, which is a shell script, and the masked PATH below has no bash.
PYTHON3="$(python3 -c 'import sys; print(sys.executable)')" || fail "missing python3"
[[ -n "${PYTHON3}" && -x "${PYTHON3}" ]] || fail "python executable is not runnable: ${PYTHON3}"
python3_q="$(printf '%q' "${PYTHON3}")"
IGNORE="${WORK}/bin-ignore-term"
mkdir -p "$IGNORE"
cat > "${WORK}/ignore-term.py" <<'EOF'
import os, signal, sys, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
open(sys.argv[1], "w").write(str(os.getpid()))
time.sleep(30)
EOF
ignore_py="$(printf '%q' "${WORK}/ignore-term.py")"
ignore_pid_q="$(printf '%q' "${WORK}/ignore-pid")"
cat > "${IGNORE}/yad" <<EOF
#!/bin/sh
exec ${python3_q} ${ignore_py} ${ignore_pid_q}
EOF
chmod +x "${IGNORE}/yad"
# time.time() is wall time. time.monotonic() is not comparable across
# processes on some macOS Python builds.
start="$(python3 -c 'import time; print(f"{time.time():.6f}")')"
PATH="${IGNORE}:${PATH}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    _popup_icon_args yad
' _ "$INST" || fail "TERM-ignoring probe failed"
elapsed="$(python3 -c 'import sys,time; print(f"{time.time()-float(sys.argv[1]):.3f}")' "$start")"
python3 -c 'import sys; t=float(sys.argv[1]); sys.exit(0 if 1.5 <= t <= 5 else 1)' "$elapsed" \
    || fail "TERM-ignoring leader finished in ${elapsed}s"
[[ -s "${WORK}/ignore-pid" ]] || fail "TERM-ignoring leader did not record its pid"
ignore_pid="$(cat "${WORK}/ignore-pid")"
if kill -0 "${ignore_pid}" 2>/dev/null; then
    kill -KILL "${ignore_pid}" 2>/dev/null || true
    fail "TERM-ignoring leader ${ignore_pid} survived the probe"
fi
echo "PASS: TERM-ignoring help probe is killed after the grace period (${elapsed}s)"

# The child ignores SIGTERM and writes a marker only if it lives 0.4s.
# The leader exits immediately, so only the immediate group SIGKILL keeps the
# marker from appearing.
STUBBORN="${WORK}/bin-stubborn"
mkdir -p "$STUBBORN"
cat > "${WORK}/stubborn-child.py" <<'EOF'
import os, signal, sys, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
open(sys.argv[1], "w").write(str(os.getpid()))
time.sleep(0.4)
open(sys.argv[2], "w").write("survived\n")
time.sleep(30)
EOF
stubborn_py="$(printf '%q' "${WORK}/stubborn-child.py")"
stubborn_pid="$(printf '%q' "${WORK}/stubborn-pid")"
stubborn_mark="$(printf '%q' "${WORK}/stubborn-mark")"
hold_pids_q="$(printf '%q' "${WORK}/hold-pids")"
cat > "${STUBBORN}/yad" <<EOF
#!/bin/sh
${python3_q} ${stubborn_py} ${stubborn_pid} ${stubborn_mark} &
echo \$! >> ${hold_pids_q}
i=0
while [ ! -s ${stubborn_pid} ]; do
    i=\$((i + 1))
    [ "\$i" -gt 50 ] && exit 1
    sleep 0.01
done
exit 0
EOF
chmod +x "${STUBBORN}/yad"
rm -f "${WORK}/stubborn-pid" "${WORK}/stubborn-mark"
start=$SECONDS
run_holder "$STUBBORN" "${WORK}/hold-stubborn-out"
elapsed=$((SECONDS - start))
[[ "$elapsed" -le 3 ]] || fail "TERM-ignoring holder blocked the reader for ${elapsed}s"
[[ -s "${WORK}/stubborn-pid" ]] || fail "TERM-ignoring holder child did not start"
# Give a surviving child time to write the marker. Immediate SIGKILL prevents it.
sleep 0.6
[[ ! -e "${WORK}/stubborn-mark" ]] || fail "TERM-ignoring holder child survived long enough to write a marker"
while read -r hold_pid; do
    if kill -0 "${hold_pid}" 2>/dev/null; then
        kill -KILL "${hold_pid}" 2>/dev/null || true
        fail "TERM-ignoring holder left child ${hold_pid} running"
    fi
done < "${WORK}/hold-pids"
echo "PASS: immediate group kill stops a TERM-ignoring holder child (${elapsed}s)"

# A grandchild that calls setsid leaves the process group. The help text is
# read from a file, so that grandchild cannot keep the popup waiting.
SETSID="${WORK}/bin-setsid"
mkdir -p "$SETSID"
cat > "${WORK}/setsid-child.py" <<'EOF'
import os, sys, time
pidfile = sys.argv[1]
pid = os.fork()
if pid == 0:
    os.setsid()
    open(pidfile, "w").write(str(os.getpid()))
    time.sleep(30)
    os._exit(0)
for _ in range(100):
    if os.path.isfile(pidfile) and os.path.getsize(pidfile) > 0:
        os._exit(0)
    time.sleep(0.01)
os._exit(1)
EOF
setsid_py="$(printf '%q' "${WORK}/setsid-child.py")"
setsid_pid="$(printf '%q' "${WORK}/setsid-pid")"
cat > "${SETSID}/yad" <<EOF
#!/bin/sh
exec ${python3_q} ${setsid_py} ${setsid_pid}
EOF
chmod +x "${SETSID}/yad"
rm -f "${WORK}/setsid-pid"
: > "${WORK}/hold-pids"
start=$SECONDS
(
    PATH="${SETSID}:${MASK}" "${BASH:-bash}" -c '
        set -euo pipefail
        source "$1/popup-dialog-implementations.sh"
        _popup_icon_args yad
    ' _ "$INST"
) &
setsid_inner=$!
(
    sleep 6 &
    guard_sleep=$!
    trap 'kill -TERM "${guard_sleep}" 2>/dev/null || true; exit 0' TERM
    wait "${guard_sleep}" 2>/dev/null || true
    kill -KILL "${setsid_inner}" 2>/dev/null || true
) &
setsid_guard=$!
wait "${setsid_inner}" 2>/dev/null || true
kill -TERM "${setsid_guard}" 2>/dev/null || true
wait "${setsid_guard}" 2>/dev/null || true
if [[ -s "${WORK}/setsid-pid" ]]; then
    cat "${WORK}/setsid-pid" >> "${WORK}/hold-pids"
fi
elapsed=$((SECONDS - start))
[[ "$elapsed" -le 3 ]] || fail "setsid grandchild blocked the reader for ${elapsed}s"
[[ -s "${WORK}/setsid-pid" ]] || fail "setsid grandchild did not start"
setsid_child="$(cat "${WORK}/setsid-pid")"
if kill -0 "${setsid_child}" 2>/dev/null; then
    kill -KILL "${setsid_child}" 2>/dev/null || true
fi
echo "PASS: a setsid grandchild cannot hold the help reader (${elapsed}s)"

# The same escaping grandchild inherits the 2 MiB file-size cap. A writer that
# ignores the process-group kill must die with SIGXFSZ instead of filling the
# unlinked help file.
cat > "${WORK}/setsid-writer.py" <<'EOF'
import os, sys, time
pidfile = sys.argv[1]
chunk = b"x" * 4096
limit = 32 * 1024 * 1024
pid = os.fork()
if pid == 0:
    os.setsid()
    open(pidfile, "w").write(str(os.getpid()))
    written = 0
    while written < limit:
        try:
            os.write(1, chunk)
        except OSError:
            os._exit(0)
        written += len(chunk)
    time.sleep(30)
    os._exit(0)
for _ in range(100):
    if os.path.isfile(pidfile) and os.path.getsize(pidfile) > 0:
        os._exit(0)
    time.sleep(0.01)
os._exit(1)
EOF
writer_py="$(printf '%q' "${WORK}/setsid-writer.py")"
writer_pid="$(printf '%q' "${WORK}/setsid-writer-pid")"
WRITER="${WORK}/bin-setsid-writer"
mkdir -p "$WRITER"
cat > "${WRITER}/yad" <<EOF
#!/bin/sh
exec ${python3_q} ${writer_py} ${writer_pid}
EOF
chmod +x "${WRITER}/yad"
rm -f "${WORK}/setsid-writer-pid"
start=$SECONDS
(
    PATH="${WRITER}:${MASK}" "${BASH:-bash}" -c '
        set -euo pipefail
        source "$1/popup-dialog-implementations.sh"
        _popup_icon_help_probe yad --help-all
    ' _ "$INST"
) >/dev/null &
writer_inner=$!
(
    sleep 6 &
    guard_sleep=$!
    trap 'kill -TERM "${guard_sleep}" 2>/dev/null || true; exit 0' TERM
    wait "${guard_sleep}" 2>/dev/null || true
    kill -KILL "${writer_inner}" 2>/dev/null || true
) &
writer_guard=$!
wait "${writer_inner}" 2>/dev/null || true
kill -TERM "${writer_guard}" 2>/dev/null || true
wait "${writer_guard}" 2>/dev/null || true
elapsed=$((SECONDS - start))
[[ "$elapsed" -le 3 ]] || fail "setsid writer blocked the reader for ${elapsed}s"
[[ -s "${WORK}/setsid-writer-pid" ]] || fail "setsid writer did not start"
writer_child="$(cat "${WORK}/setsid-writer-pid")"
echo "${writer_child}" >> "${WORK}/hold-pids"
slept=0
while kill -0 "${writer_child}" 2>/dev/null; do
    if [[ "${slept}" -ge 10 ]]; then
        kill -KILL "${writer_child}" 2>/dev/null || true
        fail "setsid writer ${writer_child} kept writing past the file-size cap"
    fi
    sleep 0.2
    slept=$((slept + 1))
done
echo "PASS: a setsid writer stops at the help-file size cap (${elapsed}s)"

# 512 blocks is 512 KiB. The writer tries to emit 1.5 MiB. Count the bytes
# through a pipe: a regular file would stop at the caller's own 512 KiB limit
# even when the probe raised the limit inside its subshell.
cat > "${WORK}/limited-writer.py" <<'EOF'
import sys
chunk = b"x" * 4096
want = 1536 * 1024
written = 0
while written < want:
    try:
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
    except OSError:
        break
    written += len(chunk)
EOF
limited_chars="$(PATH="${MASK}:${PATH}" "${BASH:-bash}" -c '
    set -euo pipefail
    source "$1/popup-dialog-implementations.sh"
    ulimit -S -f 512
    out="$(_popup_icon_help_probe "$2" "$3")"
    [[ "$(ulimit -S -f)" == "512" ]] || exit 1
    printf "%s" "${#out}"
' _ "$INST" "${PYTHON3}" "${WORK}/limited-writer.py")" \
    || fail "lower file-size limit probe failed"
[[ "${limited_chars}" -le 524288 ]] \
    || fail "lower file-size limit wrote ${limited_chars} bytes"
echo "PASS: help probe keeps a lower file-size limit (${limited_chars} bytes)"

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
spawn_case kdialog "${HELP_KDIALOG_ICON}" "${WORK}/spawn-kdialog"
[[ "$(sed -n '1p' "${WORK}/spawn-kdialog")" = "--icon" ]] || fail "kdialog spawn missing --icon"
[[ "$(sed -n '2p' "${WORK}/spawn-kdialog")" = "${SPACE_MOD}/timerwarning-icon.png" ]] \
    || fail "kdialog spawn path: $(sed -n '2p' "${WORK}/spawn-kdialog")"
spawn_case zenity "${HELP_WINDOW_ICON}" "${WORK}/spawn-zenity"
grep -qxF -- "--window-icon=${SPACE_MOD}/timerwarning-icon.png" "${WORK}/spawn-zenity" \
    || fail "zenity spawn args: $(cat "${WORK}/spawn-zenity")"
echo "PASS: warning spawn passes the icon flag"

# The pause confirmation uses the same helper. A fast stub exits after recording
# args so the notice watchdog is not what this check measures.
make_notice_tool() {
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
exit 0
EOF
    chmod +x "${bin}/${name}"
}

notice_case() {
    local tool="$1" help="$2" record="$3" mode="${4:-x11}"
    case_idx=$((case_idx + 1))
    local bin="${WORK}/bin-notice-${tool}-${case_idx}"
    make_notice_tool "$bin" "$tool" "$help" "$record"
    PATH="${bin}:${PATH}" "${BASH:-bash}" -c '
        set -euo pipefail
        source "$1/popup-dialog-implementations.sh"
        dialog_tool=$2
        env_type=$3
        window_tool=
        _pause_info_timeout=1
        _dlg_prefix=()
        _popup_show_pause_activated_notice "01:00"
    ' _ "$SPACE_MOD" "$tool" "$mode" || fail "${tool} pause notice failed (${mode})"
}

notice_case yad "${HELP_WINDOW_ICON}" "${WORK}/notice-yad"
grep -qxF -- "--window-icon=${SPACE_MOD}/timerwarning-icon.png" "${WORK}/notice-yad" \
    || fail "yad pause notice args: $(cat "${WORK}/notice-yad")"
notice_case zenity "${HELP_WINDOW_ICON}" "${WORK}/notice-zenity"
grep -qxF -- "--window-icon=${SPACE_MOD}/timerwarning-icon.png" "${WORK}/notice-zenity" \
    || fail "zenity pause notice args: $(cat "${WORK}/notice-zenity")"
notice_case kdialog "${HELP_KDIALOG_ICON}" "${WORK}/notice-kdialog"
[[ "$(sed -n '1p' "${WORK}/notice-kdialog")" = "--icon" ]] || fail "kdialog pause notice missing --icon"
[[ "$(sed -n '2p' "${WORK}/notice-kdialog")" = "${SPACE_MOD}/timerwarning-icon.png" ]] \
    || fail "kdialog pause notice path: $(sed -n '2p' "${WORK}/notice-kdialog")"
grep -qxF -- "--passivepopup" "${WORK}/notice-kdialog" \
    || fail "desktop kdialog pause notice args: $(cat "${WORK}/notice-kdialog")"
notice_case kdialog "${HELP_KDIALOG_ICON}" "${WORK}/notice-kdialog-gs" gamescope
[[ "$(sed -n '1p' "${WORK}/notice-kdialog-gs")" = "--icon" ]] || fail "gamescope kdialog pause notice missing --icon"
grep -qxF -- "--msgbox" "${WORK}/notice-kdialog-gs" \
    || fail "gamescope kdialog pause notice args: $(cat "${WORK}/notice-kdialog-gs")"
echo "PASS: pause notice passes the icon flag"
