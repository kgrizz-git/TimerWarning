#!/usr/bin/env bash
# Model launchd's persistent override separately from the currently loaded job.
# Headless on both platforms; every launchctl invocation uses this test's stub.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo_root" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='darwin-persistent-disable-') as tmp:
    root = Path(tmp)
    bindir = root / 'bin'
    bindir.mkdir()
    stub = bindir / 'launchctl'
    stub.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
p = Path(os.environ['TEST_LAUNCHD_STATE'])
s = json.loads(p.read_text())
cmd, *args = sys.argv[1:]
s['calls'].append([cmd, *args])
rc = 0
if cmd in os.environ.get('TEST_LAUNCHD_FAIL', '').split(','):
    rc = 1
elif cmd == 'disable': s['disabled'] = True
elif cmd == 'enable': s['disabled'] = False
elif cmd == 'bootout':
    rc = 0 if s['loaded'] else 1
    s['loaded'] = False
elif cmd == 'print': rc = 0 if s['loaded'] else 1
elif cmd in ('bootstrap', 'load'):
    # Legacy load -w would override a persistent disable, unlike plain load.
    if cmd == 'load' and '-w' in args: s['disabled'] = False
    rc = 1 if s['disabled'] else 0
    if not rc: s['loaded'] = True
elif cmd == 'simulate-login': s['loaded'] = not s['disabled']
elif cmd == 'kickstart': rc = 0 if s['loaded'] else 1
else: rc = 1
p.write_text(json.dumps(s))
sys.exit(rc)
''')
    stub.chmod(0o755)

    def run(name, code, *, disabled=False, loaded=True, fail='', expected=0):
        home = root / name
        plist = home / 'Library/LaunchAgents/com.sleep-warning.plist'
        plist.parent.mkdir(parents=True)
        plist.write_text('test fixture')
        state = home / 'launchd.json'
        state.write_text(json.dumps(dict(disabled=disabled, loaded=loaded, calls=[])))
        env = dict(os.environ, HOME=str(home), PATH=str(bindir) + ':' + os.environ['PATH'],
                   TEST_LAUNCHD_STATE=str(state), TEST_LAUNCHD_FAIL=fail)
        result = subprocess.run(['bash', '-c', 'source "$1"; ' + code, '_',
                                 str(repo / 'lib/service-config-darwin.sh')],
                                env=env, capture_output=True, text=True, timeout=15)
        assert result.returncode == expected, (name, result.returncode, result.stderr)
        return json.loads(state.read_text())

    s = run('disable', 'disable_scheduled_service && launchctl simulate-login')
    assert s['disabled'] and not s['loaded'], s
    assert [c[0] for c in s['calls']] == ['disable', 'bootout', 'simulate-login'], s
    print('PASS: disable stops now and persists across simulated login')

    s = run('disable-fails', 'disable_scheduled_service', fail='disable', expected=1)
    assert not s['loaded'] and not s['disabled'], s
    assert [c[0] for c in s['calls']] == ['disable', 'bootout'], s
    print('PASS: persistent-disable failure is reported but immediate stop still runs')

    s = run('bootout-fails', 'disable_scheduled_service', fail='bootout', expected=1)
    assert s['disabled'] and s['loaded'], s
    assert 'print' in [c[0] for c in s['calls']], s
    print('PASS: still-loaded job reports bootout failure without losing persistence')

    s = run('not-loaded', 'disable_scheduled_service', loaded=False)
    assert s['disabled'] and not s['loaded'], s
    print('PASS: already-unloaded job can still be persistently disabled')

    s = run('enable', 'enable_scheduled_service', disabled=True, loaded=False)
    assert not s['disabled'] and s['loaded'], s
    assert [c[0] for c in s['calls']][0] == 'enable', s
    assert s['calls'][-1][0] == 'kickstart', s
    print('PASS: explicit enable clears override before bootstrap and kickstart')

    s = run('enable-fails', 'enable_scheduled_service', disabled=True, loaded=False,
            fail='enable', expected=1)
    assert s['disabled'] and not s['loaded'] and len(s['calls']) == 1, s
    print('PASS: failed enable does not try to bootstrap or mask the error')

    s = run('bootstrap-fails', 'enable_scheduled_service', loaded=False,
            fail='bootstrap,load', expected=1)
    assert 'kickstart' not in [c[0] for c in s['calls']], s
    print('PASS: bootstrap failure propagates through explicit enable')

    s = run('reload', 'reload_scheduled_service', disabled=True, loaded=False, expected=1)
    assert s['disabled'] and not s['loaded'], s
    assert 'enable' not in [c[0] for c in s['calls']], s
    assert not any('-w' in c for c in s['calls']), s
    print('PASS: ordinary reload cannot force-enable a persistently disabled job')

    s = run('install', 'install_launch_agent 5', disabled=True, loaded=False)
    assert not s['disabled'] and s['loaded'], s
    print('PASS: explicit install can re-enable a previously disabled agent')
PY
