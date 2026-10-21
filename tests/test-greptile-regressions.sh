#!/usr/bin/env bash
# Isolated runner/interpreter and pre-spawn X11 deadline regressions.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo_root" "$BASH" <<'PY'
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

repo = Path(sys.argv[1])
selected_bash = sys.argv[2]
with tempfile.TemporaryDirectory(prefix='greptile-regressions-') as tmp:
    root = Path(tmp)
    bindir = root / 'bin'
    bindir.mkdir()
    env = dict(os.environ, HOME=tmp, TMPDIR=tmp,
               PATH=str(bindir) + ':' + os.environ['PATH'])

    def stub(name, code):
        path = bindir / name
        path.write_text('#!/bin/sh\n' + code)
        path.chmod(0o755)

    # A PATH-selected bash must never be used once the runner has selected Bash.
    stub('bash', 'echo WRONG_INTERPRETER >&2; exit 99\n')
    # The fixture tests interpreter selection only. Avoid the runner's portable
    # timer fallback holding capture pipes open after this tiny sentinel exits.
    stub('timeout', 'shift; exec "$@"\n')
    fixture = root / 'runner'
    (fixture / 'scripts').mkdir(parents=True)
    (fixture / 'tests').mkdir()
    shutil.copyfile(repo / 'scripts/run-tests.sh', fixture / 'scripts/run-tests.sh')
    (fixture / 'tests/tiers.yaml').write_text('tier_a:\n  scripts:\n    - sentinel.sh\n')
    (fixture / 'tests/sentinel.sh').write_text(
        'test "${BASH_VERSINFO[0]}" -ge 4 || exit 1\n'
        'declare -A values=([selected]=yes)\n'
        'test "${values[selected]}" = yes\necho SELECTED_BASH_OK\n')
    result = subprocess.run([selected_bash, str(fixture / 'scripts/run-tests.sh'),
                             '--tier', 'a'], env=env, capture_output=True,
                            text=True, timeout=15)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'SELECTED_BASH_OK' in result.stdout, result.stdout
    assert 'WRONG_INTERPRETER' not in result.stderr, result.stderr
    print('PASS: runner child uses selected Bash despite conflicting PATH')

    code = 'source lib/window-management.sh; gamescope_interactive_dialog_dimensions 400 250'
    stub('xwininfo', 'printf "  Width: 1280\\n  Height: 800\\n"\n')
    result = subprocess.run([selected_bash, '-c', code], cwd=repo, env=env,
                            capture_output=True, text=True, timeout=6)
    assert (result.returncode, result.stdout.strip()) == (0, '1280 533'), result
    print('PASS: successful root query preserves Deck-tested dimensions')

    stub('xwininfo', 'exit 1\n')
    result = subprocess.run([selected_bash, '-c', code], cwd=repo, env=env,
                            capture_output=True, text=True, timeout=6)
    assert (result.returncode, result.stdout.strip()) == (1, '400 250'), result
    print('PASS: failed root query uses fallback dimensions')

    pidfile = root / 'probe.pid'
    env['PROBE_PID_FILE'] = str(pidfile)
    stub('xwininfo', 'trap "" TERM\necho $$ > "$PROBE_PID_FILE"\nexec sleep 60\n')
    started = time.monotonic()
    proc = subprocess.Popen([selected_bash, '-c', code], cwd=repo, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, start_new_session=True)
    try:
        out, err = proc.communicate(timeout=6)
        elapsed = time.monotonic() - started
        assert (proc.returncode, out.strip()) == (1, '400 250'), (out, err)
        assert elapsed < 5, elapsed
        pid = int(pidfile.read_text())
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError(f'X11 probe {pid} survived deadline cleanup')
        assert not list(root.glob('sleep-warning-root.*')), 'Probe temporary file leaked'
        print(f'PASS: wedged pre-spawn query killed/reaped; fallback in {elapsed:.1f}s')
    finally:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()
PY
