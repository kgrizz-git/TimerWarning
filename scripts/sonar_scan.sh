#!/usr/bin/env bash
# Run a SonarQube analysis against the local Community Build server.
#
# Prerequisites:
#   - server at SONAR_HOST_URL (default http://localhost:9000)
#   - SONAR_TOKEN exported, or SONAR_TOKEN=... in repo-root .env
#     (an exported value wins; .env is parsed, never sourced; the token is never printed)
#   - sonar-scanner on PATH (brew install sonar-scanner)
#   - project key timer-warning (sonar-project.properties); the first analysis can create it
#
# The scanner uploads and returns. This script then waits for the Compute Engine
# task. On success it writes tmp/sonar-state.json with the scanned commit so
# pre-push can require a fresh scan. It does not run from the hook.
# Scope lives in sonar-project.properties, which Cloud automatic analysis ignores.

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

echo "== Running sonar-scanner against ${SONAR_HOST_URL} =="
# Token stays in SONAR_TOKEN. sonar-project.properties reads ${env.SONAR_TOKEN}.
# Do not pass -Dsonar.token; that puts the secret on the process command line.
sonar-scanner \
    -Dsonar.host.url="${SONAR_HOST_URL}"

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
deadline=$((SECONDS + 120))
ce_status=""
while (( SECONDS < deadline )); do
    ce_body="$(curl -sS --max-time 15 -H "Authorization: Bearer ${SONAR_TOKEN}" \
        "${SONAR_HOST_URL}/api/ce/task?id=${ce_task_id}")" || true
    ce_status="$(printf '%s' "${ce_body}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("task",{}).get("status",""))' 2>/dev/null || true)"
    case "${ce_status}" in
        SUCCESS) break ;;
        FAILED|CANCELED|ERROR)
            echo "Compute Engine task ${ce_task_id} failed with status: ${ce_status}" >&2
            exit 1
            ;;
    esac
    sleep 5
done
if [[ "${ce_status}" != "SUCCESS" ]]; then
    echo "Timed out waiting for Compute Engine task ${ce_task_id} after 120s." >&2
    exit 1
fi

commit="$(git rev-parse HEAD)"
mkdir -p "${ROOT}/tmp"
python3 - "${ROOT}/tmp/sonar-state.json" "${commit}" "${SONAR_HOST_URL}" <<'PY'
import json, sys
path, commit, host = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({"commit": commit, "host": host}, handle)
    handle.write("\n")
PY
echo "== Scan recorded for ${commit} =="
