#!/usr/bin/env bash
#
# run-local-sonar.sh — Analyze this repo with a local SonarQube Community server.
#
# Inputs: .env in the repo root (gitignored), keys SONAR_HOST_URL and SONAR_TOKEN.
#   SKIP_LOCAL_SONAR=1 skips the scan.
# Output: scanner log on stdout/stderr. Exit 0 when the scan is skipped or the
#   quality gate passes. Exit non-zero when a configured scan fails.
# Requires: sonar-scanner on PATH when .env has both keys. The token is read
#   from .env and passed only through the SONAR_TOKEN environment variable.
#
# A missing .env does not fail the push. Add the two keys, then the next push
# runs the scan. See .env.example.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [ "${SKIP_LOCAL_SONAR:-0}" = "1" ]; then
    echo "pre-push: SKIP_LOCAL_SONAR=1 — skipping local SonarQube" >&2
    exit 0
fi

env_file="${ROOT}/.env"
if [ ! -f "${env_file}" ]; then
    echo "pre-push: local SonarQube skipped — copy .env.example to .env and set SONAR_HOST_URL and SONAR_TOKEN" >&2
    exit 0
fi

# Read one KEY=value line. Do not source .env; it can hold other secrets.
read_env_value() {
    local key="$1" line value
    line="$(grep -E "^${key}=" "${env_file}" | tail -n 1 || true)"
    value="${line#"${key}"=}"
    value="${value%$'\r'}"
    if [ "${value#\"}" != "${value}" ] && [ "${value%\"}" != "${value}" ]; then
        value="${value#\"}"
        value="${value%\"}"
    elif [ "${value#\'}" != "${value}" ] && [ "${value%\'}" != "${value}" ]; then
        value="${value#\'}"
        value="${value%\'}"
    fi
    printf '%s' "${value}"
}

host_url="$(read_env_value SONAR_HOST_URL)"
token="$(read_env_value SONAR_TOKEN)"
if [ -z "${host_url}" ] || [ -z "${token}" ]; then
    echo "pre-push: local SonarQube skipped — .env needs SONAR_HOST_URL and SONAR_TOKEN" >&2
    exit 0
fi

if ! command -v sonar-scanner >/dev/null 2>&1; then
    echo "pre-push: sonar-scanner is not on PATH; install it or set SKIP_LOCAL_SONAR=1" >&2
    exit 1
fi

echo "pre-push: local SonarQube (${host_url})..." >&2
export SONAR_HOST_URL="${host_url}"
export SONAR_TOKEN="${token}"
unset token

scanner_args=(
    -Dsonar.projectKey=TimerWarning
    -Dsonar.projectName=TimerWarning
    -Dsonar.sources=.
    -Dsonar.exclusions=tmp/**,backups/**,.env,.env.*,**/.git/**
    -Dsonar.qualitygate.wait=true
)

if command -v timeout >/dev/null 2>&1; then
    timeout 600 sonar-scanner "${scanner_args[@]}"
elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout 600 sonar-scanner "${scanner_args[@]}"
else
    python3 -c 'import subprocess, sys
r = subprocess.run(["sonar-scanner", *sys.argv[1:]], timeout=600)
sys.exit(r.returncode)' "${scanner_args[@]}"
fi

echo "pre-push: local SonarQube passed." >&2
