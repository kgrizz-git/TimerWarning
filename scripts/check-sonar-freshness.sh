#!/usr/bin/env bash
# Pre-push gate. Does not run sonar-scanner.
#
# When SONAR_TOKEN is unset, exit 0. When it is set, tmp/sonar-state.json must
# name the current HEAD. Otherwise the push stops and the message points at
# scripts/sonar_scan.sh. SKIP_LOCAL_SONAR=1 skips this check.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/sonar-env.sh
source "${ROOT}/scripts/sonar-env.sh"

if [[ "${SKIP_LOCAL_SONAR:-0}" == "1" ]]; then
    echo "pre-push: SKIP_LOCAL_SONAR=1 — skipping local SonarQube freshness" >&2
    exit 0
fi

sonar_env_load "${ROOT}"
if [[ -z "${SONAR_TOKEN:-}" ]]; then
    echo "pre-push: local SonarQube skipped — add SONAR_TOKEN to .env (see .env.example)" >&2
    exit 0
fi

state="${ROOT}/tmp/sonar-state.json"
head_commit="$(git rev-parse HEAD)"
scanned=""
if [[ -f "${state}" ]]; then
    scanned="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("commit",""))' "${state}" 2>/dev/null || true)"
fi
if [[ "${scanned}" != "${head_commit}" ]]; then
    echo "pre-push: local SonarQube scan is not current for ${head_commit}." >&2
    echo "pre-push: run bash scripts/sonar_scan.sh, then push again." >&2
    exit 1
fi
echo "pre-push: local SonarQube scan matches ${head_commit}." >&2
