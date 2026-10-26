#!/usr/bin/env bash
# Real process deadlines with mocked dialogs. No display, scheduler or live HOME.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo_root" <<'PY'
import os
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import tempfile
import time

repo = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='popup-notice-deadlines-') as tmp:
    root = Path(tmp)
    bindir = root / 'bin'
    bindir.mkdir()
    real_sleep = shutil.which('sleep')
    assert real_sleep
    sleep_stub = bindir / 'sleep'
    sleep_stub.write_text('#!/usr/bin/env bash\necho $$ >> "$TEST_HELPERS"\n'
                          'exec "$TEST_REAL_SLEEP" "$@"\n')
    sleep_stub.chmod(0o755)
    for tool in ('zenity', 'yad', 'kdialog'):
        stub = bindir / tool
        # Ignore TERM and native timeout arguments: only an external KILL works.
        # Help exits before the TERM-ignoring sleep. The pause notice probes
        # --help for the icon, and that probe is not the deadline under test.
        stub.write_text('#!/usr/bin/env bash\n'
                        'for arg in "$@"; do\n'
                        '  case "$arg" in --help*) exit 0 ;; esac\n'
                        'done\n'
                        'echo $$ > "$TEST_DIALOG_PID"\n'
                        'if [ "${TEST_EARLY_CLOSE:-}" = 1 ]; then\n'
                        '  "$TEST_REAL_SLEEP" 0.2; exit 7\nfi\n'
                        'trap "" TERM\nexec "$TEST_REAL_SLEEP" 60\n')
        stub.chmod(0o755)
    probe_stub = bindir / 'xprop'
    probe_stub.write_text('#!/usr/bin/env bash\ntrap "" TERM\n'
                          'echo $$ >> "$TEST_HELPERS"\n'
                          'echo started > "$TEST_ATOM_STARTED"\n'
                          'exec "$TEST_REAL_SLEEP" 60\n')
    probe_stub.chmod(0o755)
    xwininfo = bindir / 'xwininfo'
    xwininfo.write_text('#!/usr/bin/env bash\nprintf "  Width: 1280\\n  Height: 800\\n"\n')
    xwininfo.chmod(0o755)
    env = dict(os.environ, HOME=tmp, PATH=str(bindir) + ':' + os.environ['PATH'],
               TEST_DIALOG_PID=str(root / 'dialog.pid'), TEST_REAL_SLEEP=real_sleep,
               TEST_HELPERS=str(root / 'helpers'), TEST_ATOM_STARTED=str(root / 'atom-started'),
               TEST_KILLS=str(root / 'kills'), TEST_NOTICE_EXIT=str(root / 'notice-exit'))

    def running(pid):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return False
        # Group cancellation can leave a terminated grandchild briefly awaiting
        # init's reap. A zombie is no longer running or holding display resources.
        stat = Path(f'/proc/{pid}/stat')
        try:
            if stat.exists() and stat.read_text().rsplit(')', 1)[1].split()[0] == 'Z':
                return False
        except FileNotFoundError:
            return False
        return True

    def run(code, deadline, early=False, check_helpers=True):
        pid_file = root / 'dialog.pid'
        for name in ('dialog.pid', 'helpers', 'atom-started', 'kills', 'notice-exit'):
            (root / name).unlink(missing_ok=True)
        with (root / 'output').open('w+') as out:
            start = time.monotonic()
            proc = subprocess.Popen(['bash', '-c', code], cwd=repo,
                                    env=dict(env, TEST_EARLY_CLOSE='1' if early else '0'),
                                    stdout=out, stderr=out, start_new_session=True)
            try:
                proc.wait(timeout=deadline)
                elapsed = time.monotonic() - start
                out.seek(0)
                output = out.read()
                assert proc.returncode == 0, (proc.returncode, output)
                assert pid_file.exists(), 'Dialog/probe did not start'
                child = int(pid_file.read_text())
                assert not running(child), f'Dialog/probe {child} survived its deadline'
                if check_helpers:
                    helpers = root / 'helpers'
                    assert helpers.exists(), 'Watchdog/probe helper did not start'
                    pids = [int(line) for line in helpers.read_text().splitlines()]
                    until = time.monotonic() + 1
                    while any(running(pid) for pid in pids) and time.monotonic() < until:
                        time.sleep(0.02)
                    assert not any(running(pid) for pid in pids), 'Helper survived production cleanup'
                return elapsed
            finally:
                # Failure recovery only, AFTER assertions about production cleanup.
                # Atom workers use separate groups; tracked helpers need explicit
                # failure cleanup too (a broken implementation may orphan them).
                helpers = root / 'helpers'
                if helpers.exists():
                    for line in helpers.read_text().splitlines():
                        try:
                            os.kill(int(line), signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait()

    for tool, mode in [(tool, mode) for tool in ('zenity', 'yad', 'kdialog')
                       for mode in ('gamescope', 'x11')]:
        code = f'''
source lib/window-management.sh
source lib/popup-dialog-implementations.sh
dialog_tool={tool}; env_type={mode}; window_tool=""
_pause_info_timeout=1; _dlg_prefix=()
# Real atom setup hits a TERM-ignoring xprop stub; no X server is contacted.
gamescope_overlay_debug_log_exit() {{ printf '%s\\n' "$*" > "$TEST_NOTICE_EXIT"; }}
_popup_show_pause_activated_notice 12:00
'''
        elapsed = run(code, 5)
        assert elapsed < 4, elapsed
        if mode == 'gamescope':
            assert (root / 'atom-started').exists(), 'Atom probe was never exercised'
            assert (root / 'notice-exit').read_text().strip() == '137 false pause'
        else:
            assert not (root / 'atom-started').exists(), 'Desktop notice contacted atom probe'
        print(f'PASS: {tool}/{mode} notice and helpers terminated on deadline ({elapsed:.1f}s)')

    for tool in ('zenity', 'yad', 'kdialog'):
        code = f'''
source lib/popup-dialog-implementations.sh
dialog_tool={tool}; env_type=gamescope; window_tool=""
_pause_info_timeout=1; _dlg_prefix=()
kill() {{ printf '%s\\n' "$*" >> "$TEST_KILLS"; builtin kill "$@"; }}
apply_gamescope_overlay_atoms() {{ return 0; }}
gamescope_overlay_debug_log_exit() {{ printf '%s\\n' "$*" > "$TEST_NOTICE_EXIT"; }}
_popup_show_pause_activated_notice 12:00
# Beyond the original deadline: a cancelled watchdog must not fire later.
"$TEST_REAL_SLEEP" 1.1
'''
        run(code, 4, early=True)
        child = (root / 'dialog.pid').read_text().strip()
        kills = (root / 'kills').read_text().splitlines()
        assert not any(line.split()[-1] == child for line in kills), 'Disarmed watchdog signalled closed dialog'
        assert (root / 'notice-exit').read_text().strip() == '7 false pause'
        print(f'PASS: {tool} early close disarms watchdog, reaps sleep and preserves exit log')

    elapsed = run('''
source lib/gamescope-overlay-debug.sh
_gs_debug_probe bash -c 'trap "" TERM; echo $$ > "$TEST_DIALOG_PID"; exec sleep 60'
''', 6, check_helpers=False)
    assert elapsed < 5, elapsed
    print(f'PASS: debug probe escalates to KILL ({elapsed:.1f}s)')
PY
