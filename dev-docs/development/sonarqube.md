# SonarQube (local)

Optional local analysis against a SonarQube Community Build server. It does not
replace the SonarCloud GitHub app, and CI does not call it.

## Setup

The server for this machine listens on `127.0.0.1:9000`. Confirm with
`curl -s http://127.0.0.1:9000/api/system/status` (`"status":"UP"`).

Create a token in the server UI with Execute Analysis permission. Creating the
project on the first analysis also needs Create Projects permission; otherwise
create project `timer-warning` in the UI first. Put the token in repo-root
`.env` (gitignored) and keep that file readable only by you:

```bash
cp .env.example .env
chmod 600 .env
```

`SONAR_TOKEN` is required. `SONAR_HOST_URL` defaults to `http://localhost:9000`.
The server bound to `127.0.0.1:9000` is that same service. The freshness check
compares the URL string, so `localhost` and `127.0.0.1` do not count as the
same recorded host. An exported value wins over `.env`. `scripts/sonar-env.sh`
parses `.env` and does not source it, and nothing prints the token.

Install the scanner with `brew install sonar-scanner` if it is missing.
Homebrew's scanner 8.1 bundles a JRE. `python3` is required for the API poll.

Create the project in the UI once, or let the first analysis create it. The
local project key is `timer-warning`, from
[`sonar-project.properties`](../../sonar-project.properties). That file is for
this server only. SonarQube Cloud automatic analysis ignores it. The cloud
project key stays `kgrizz-git_TimerWarning`.

## Run a scan

```bash
bash scripts/sonar_scan.sh
```

The working tree must be clean. The script uploads the analysis, waits up to
120 seconds for the Compute Engine task, and on success writes
`tmp/sonar-latest-issues.json` plus `tmp/sonar-state.json` for that commit.
The token is not passed on a command line. Results are at
<http://localhost:9000>. Community Build does not decorate pull requests.

This server analyzes Python. Its language list has no Shell, so the local
issue count does not include the Bash sources SonarCloud reviews on pull
requests. ShellCheck remains the local shell check.

The scan prints unresolved issues by type (`BUG`, `VULNERABILITY`,
`CODE_SMELL`) and by rule and severity. That print is not a gate.

## Before push

The pre-push hook does **not** run `sonar-scanner`. When `SONAR_TOKEN` is set,
[`scripts/check-sonar-freshness.sh`](../../scripts/check-sonar-freshness.sh)
requires `tmp/sonar-state.json` to name each commit being pushed and the same
host. A ref delete is not checked. A newer commit means run
`bash scripts/sonar_scan.sh`, then push again. With no token, the freshness
check skips.

[`scripts/check_sonar_issues.py`](../../scripts/check_sonar_issues.py) then
compares the dump with
[`scripts/sonar-issues-baseline.json`](../../scripts/sonar-issues-baseline.json).
It fails when a `BUG` or `VULNERABILITY` count rises for the same rule in the
same file. `CODE_SMELL` and severity are not gated. No dump, or a dump for a
different commit, does not block the push. `python3 scripts/check_sonar_issues.py --update`
only removes resolved entries or lowers a count.

`SKIP_LOCAL_SONAR=1 git push` skips both checks on purpose.

Tier-A on pre-push stays opt-in (`INSTALL_PRE_PUSH=1`).
