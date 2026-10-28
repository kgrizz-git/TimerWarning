#!/usr/bin/env bash
# Run a SonarQube analysis against the local Community Build server.
#
# Prerequisites:
#   - server at SONAR_HOST_URL (default http://localhost:9000)
#   - SONAR_TOKEN exported, or SONAR_TOKEN=... in repo-root .env (mode 0600)
#     (an exported value wins; .env is parsed, never sourced; the token is never printed)
#   - sonar-scanner on PATH (brew install sonar-scanner)
#   - python3 on PATH
#   - project key timer-warning (sonar-project.properties); the first analysis can create it
#     when the token's user also has Create Projects permission
#
# The working tree must be clean. The scanner analyzes the worktree, and the
# recorded commit has to be that tree. The script uploads, waits for the
# Compute Engine task, writes unresolved issues to tmp/sonar-latest-issues.json,
# and records the commit in tmp/sonar-state.json. It does not run from the hook.
# Scope lives in sonar-project.properties, which Cloud automatic analysis ignores.
# This Community Build analyzes Python. It has no Shell language, so a local
# issue count does not cover the Bash sources. SonarCloud does analyze them: see
# scripts/check-sonar-shell-newcode.sh (before a push) and
# scripts/sonarcloud_pr_issues.py (after a push).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
# shellcheck source=scripts/sonar-env.sh
source "${ROOT}/scripts/sonar-env.sh"
sonar_env_load "${ROOT}"

if [[ -z "${SONAR_TOKEN:-}" ]]; then
    echo "SONAR_TOKEN is not set; export it or add it to repo-root .env." >&2
    exit 1
fi
if [[ "${SONAR_TOKEN_SOURCE:-}" == "dotenv" ]]; then
    echo "Loaded SONAR_TOKEN from repo-local .env." >&2
fi

if ! command -v sonar-scanner >/dev/null 2>&1; then
    echo "sonar-scanner is not installed (brew install sonar-scanner)." >&2
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to read the SonarQube API." >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty. Commit or stash before scanning so the recorded commit matches the analysis." >&2
    git status --porcelain >&2
    exit 1
fi

commit="$(git rev-parse HEAD)"
project_key="$(grep -m1 '^sonar.projectKey=' "${ROOT}/sonar-project.properties" | cut -d= -f2- | tr -d '\r')"
if [[ -z "${project_key}" ]]; then
    echo "sonar-project.properties has no sonar.projectKey." >&2
    exit 1
fi

echo "== Running sonar-scanner against ${SONAR_HOST_URL} =="
# Token stays in SONAR_TOKEN. sonar-project.properties reads ${env.SONAR_TOKEN}.
# Do not pass -Dsonar.token; that puts the secret on the process command line.
sonar-scanner \
    -Dsonar.host.url="${SONAR_HOST_URL}"

if [[ "$(git rev-parse HEAD)" != "${commit}" || -n "$(git status --porcelain)" ]]; then
    echo "The tree changed during the scan. Not recording ${commit}." >&2
    exit 1
fi

report="${ROOT}/.scannerwork/report-task.txt"
if [[ ! -f "${report}" ]]; then
    echo "sonar-scanner did not produce .scannerwork/report-task.txt; cannot wait for the Compute Engine task." >&2
    exit 1
fi
ce_task_id="$(grep -m1 '^ceTaskId=' "${report}" | cut -d= -f2- | tr -d '\r' || true)"
if [[ -z "${ce_task_id}" ]]; then
    echo "report-task.txt has no ceTaskId; cannot wait for the Compute Engine task." >&2
    exit 1
fi

echo "== Waiting for Compute Engine task ${ce_task_id} =="
# sonar_collect.py reads SONAR_TOKEN from the environment and does not put it on argv.
python3 "${ROOT}/scripts/sonar_collect.py" \
    --task-id "${ce_task_id}" \
    --project-key "${project_key}" \
    --commit "${commit}"

if [[ "$(git rev-parse HEAD)" != "${commit}" || -n "$(git status --porcelain)" ]]; then
    rm -f "${ROOT}/tmp/sonar-state.json" "${ROOT}/tmp/sonar-latest-issues.json"
    echo "The tree changed while the Compute Engine task ran. Removed the scan record." >&2
    exit 1
fi
