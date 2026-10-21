#!/usr/bin/env bash
# Real process deadlines with mocked dialogs. No display, scheduler or live HOME.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo_root" <<'PY'
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

repo = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='popup-notice-deadlines-') as tmp:
    root = Path(tmp)
    bindir = root / 'bin'
    bindir.mkdir()
    for tool in ('zenity', 'yad', 'kdialog'):
        stub = bindir / tool
        # Ignore TERM and native timeout arguments: only an external KILL works.
        stub.write_text('#!/usr/bin/env bash\ntrap "" TERM\n'
                        'echo $$ > "$TEST_DIALOG_PID"\nexec sleep 60\n')
        stub.chmod(0o755)
    env = dict(os.environ, HOME=tmp, PATH=str(bindir) + ':' + os.environ['PATH'],
               TEST_DIALOG_PID=str(root / 'dialog.pid'))

    def run(code, deadline):
        pid_file = root / 'dialog.pid'
        pid_file.unlink(missing_ok=True)
        with (root / 'output').open('w+') as out:
            start = time.monotonic()
            proc = subprocess.Popen(['bash', '-c', code], cwd=repo, env=env,
                                    stdout=out, stderr=out, start_new_session=True)
            try:
                proc.wait(timeout=deadline)
                elapsed = time.monotonic() - start
                out.seek(0)
                output = out.read()
                assert proc.returncode == 0, (proc.returncode, output)
                assert pid_file.exists(), 'Dialog/probe did not start'
                child = int(pid_file.read_text())
                try:
                    os.kill(child, 0)
                except ProcessLookupError:
                    pass
                else:
                    raise AssertionError(f'Dialog/probe {child} survived its deadline')
                return elapsed
            finally:
                # Only this test's process group; includes mock X11 probe workers.
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait()

    for tool, mode in [('zenity', 'gamescope'), ('yad', 'gamescope'),
                       ('kdialog', 'gamescope'), ('kdialog', 'x11')]:
        code = f'''
source lib/popup-dialog-implementations.sh
dialog_tool={tool}; env_type={mode}; window_tool=""
_pause_info_timeout=1; _dlg_prefix=()
# A stalled X server must not postpone the notice's independent watchdog.
apply_gamescope_overlay_atoms() {{ sleep 60; }}
_popup_show_pause_activated_notice 12:00
'''
        elapsed = run(code, 5)
        assert elapsed < 4, elapsed
        print(f'PASS: {tool}/{mode} notice reaped despite ignored TERM and stalled atom setup ({elapsed:.1f}s)')

    elapsed = run('''
source lib/gamescope-overlay-debug.sh
_gs_debug_probe bash -c 'trap "" TERM; echo $$ > "$TEST_DIALOG_PID"; exec sleep 60'
''', 6)
    assert elapsed < 5, elapsed
    print(f'PASS: debug probe escalates to KILL ({elapsed:.1f}s)')
PY
