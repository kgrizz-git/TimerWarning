# SonarQube (local)

Optional local analysis against a SonarQube Community Build server. It does not
replace the SonarCloud GitHub app, and CI does not call it.

## Setup

The server for this machine listens on `127.0.0.1:9000`. Confirm with
`curl -s http://127.0.0.1:9000/api/system/status` (`"status":"UP"`).

Create a token in the server UI with Execute Analysis permission. Put it in
repo-root `.env` (gitignored):

```bash
cp .env.example .env
```

`SONAR_TOKEN` is required. `SONAR_HOST_URL` defaults to `http://localhost:9000`.
An exported value wins over `.env`. `scripts/sonar-env.sh` parses `.env` and
does not source it, and nothing prints the token.

Install the scanner with `brew install sonar-scanner` if it is missing.
Homebrew's scanner 8.1 bundles a JRE.

Create the project in the UI once, or let the first analysis create it. The
local project key is `timer-warning`, from
[`sonar-project.properties`](../../sonar-project.properties). That file is for
this server only. SonarQube Cloud automatic analysis ignores it. The cloud
project key stays `kgrizz-git_TimerWarning`.

## Run a scan

```bash
bash scripts/sonar_scan.sh
```

The script uploads the analysis, waits up to 120 seconds for the Compute Engine
task, and on success writes `tmp/sonar-state.json` with the current commit.
Results are at <http://localhost:9000>. Community Build does not decorate pull
requests.

## Before push

The pre-push hook does **not** run `sonar-scanner`. When `SONAR_TOKEN` is set,
[`scripts/check-sonar-freshness.sh`](../../scripts/check-sonar-freshness.sh)
requires `tmp/sonar-state.json` to name the current `HEAD`. A newer commit
means run `bash scripts/sonar_scan.sh`, then push again. With no token, the
check skips. `SKIP_LOCAL_SONAR=1 git push` skips it on purpose.

Tier-A on pre-push stays opt-in (`INSTALL_PRE_PUSH=1`).
