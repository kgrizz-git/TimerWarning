#!/usr/bin/env bash
# Exercise diagnostic safety and outcomes without Deck hardware or a GUI.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo_root" <<'PY'
import os
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(sys.argv[1]) / 'scripts/check-steam-deck-gaming-mode.sh'
with tempfile.TemporaryDirectory(prefix='deck-preflight-') as tmp:
    root = Path(tmp)
    home = root / 'home'
    config = home / '.config/sleep-warning/config/sleep-warning.conf'
    config.parent.mkdir(parents=True)
    bindir = root / 'bin'
    bindir.mkdir()
    marker = root / 'forbidden-action'
    commands = {
        'uname': 'echo Linux',
        # A test double, not the hardware timeout: subprocess.run bounds tests.
        'timeout': 'if [ "${PREFLIGHT_TEST_TIMEOUT:-}" = 1 ]; then exit 124; fi\n'
                   'shift 2\nexec "$@"',
        'xdpyinfo': 'exit "${PREFLIGHT_TEST_X11_FAILURE:-0}"',
        'xprop': 'exit 0',
        'zenity': 'touch "$PREFLIGHT_TEST_MARKER"; exit 99',
        'systemctl': 'case "$*" in\n'
                     '  *stop*|*disable*|*start*|*enable*) touch "$PREFLIGHT_TEST_MARKER"; exit 99;;\n'
                     'esac\necho ActiveState=inactive',
    }
    for name, body in commands.items():
        path = bindir / name
        path.write_text('#!/usr/bin/env bash\n' + body + '\n')
        path.chmod(0o755)
    env = dict(os.environ, HOME=str(home), PATH=str(bindir) + ':' + os.environ['PATH'],
               DISPLAY=':0', XDG_CURRENT_DESKTOP='gamescope', WAYLAND_DISPLAY='',
               XDG_RUNTIME_DIR=str(root), PREFLIGHT_TEST_MARKER=str(marker))
    env.pop('GAMING_MODE_EXPERIMENTAL_ENABLED', None)

    def run(expected, contains, **overrides):
        before = {p.relative_to(home): p.read_bytes() for p in home.rglob('*') if p.is_file()}
        result = subprocess.run(['bash', str(script)], env=dict(env, **overrides),
                                capture_output=True, text=True, timeout=10)
        assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
        assert contains in result.stdout, result.stdout
        assert len(result.stdout) <= 16384
        after = {p.relative_to(home): p.read_bytes() for p in home.rglob('*') if p.is_file()}
        assert before == after, 'Diagnostic modified installed state'
        assert not marker.exists(), 'Config executed, GUI launched, or service mutated'

    config.write_text('GAMING_MODE_EXPERIMENTAL_ENABLED=true\n'
                      'touch "$PREFLIGHT_TEST_MARKER"\n')
    run(0, 'PREFLIGHT READY')
    run(1, 'experimental overlay is disabled', GAMING_MODE_EXPERIMENTAL_ENABLED='false')
    run(1, 'no accessible overlay X11 display', PREFLIGHT_TEST_X11_FAILURE='1')
    run(124, '', PREFLIGHT_TEST_TIMEOUT='1')
    config.unlink()
    run(1, 'experimental overlay is disabled')
    help_result = subprocess.run(['bash', str(script), '--help'], env=env,
                                 capture_output=True, text=True, timeout=10)
    assert help_result.returncode == 0 and 'No popup' in help_result.stdout
    bad_arg = subprocess.run(['bash', str(script), '--popup'], env=env,
                             capture_output=True, text=True, timeout=10)
    assert bad_arg.returncode == 2
print('PASS: preflight outcomes, timeout propagation, config isolation and no GUI/service writes')
PY
