#!/usr/bin/env bash
# Pre-push gate. Does not run sonar-scanner.
#
# When SONAR_TOKEN is unset, exit 0. When it is set, tmp/sonar-state.json must
# name each commit being pushed and the same host. SKIP_LOCAL_SONAR=1 skips.
#
# Called with no arguments, the commit is HEAD (a direct run).
# Called with --push and no commits, the push only deletes refs and passes.
# Called with --push <sha>..., each sha must match the recorded scan.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/sonar-env.sh
source "${ROOT}/scripts/sonar-env.sh"

sonar_normalize_url() {
    local url="$1" rest
    url="${url%/}"
    case "${url}" in
        http://localhost:*)
            rest="${url#http://localhost:}"
            url="http://127.0.0.1:${rest}"
            ;;
        https://localhost:*)
            rest="${url#https://localhost:}"
            url="https://127.0.0.1:${rest}"
            ;;
        'http://[::1]:'*)
            rest="${url#http://\[::1\]:}"
            url="http://127.0.0.1:${rest}"
            ;;
        'https://[::1]:'*)
            rest="${url#https://\[::1\]:}"
            url="https://127.0.0.1:${rest}"
            ;;
    esac
    printf '%s' "${url}"
}

sonar_freshness_main() {
if [[ "${SKIP_LOCAL_SONAR:-0}" == "1" ]]; then
    echo "pre-push: SKIP_LOCAL_SONAR=1 — skipping local SonarQube freshness" >&2
    exit 0
fi

push_mode=0
if [[ "${1:-}" == "--push" ]]; then
    push_mode=1
    shift
fi

if [[ "${push_mode}" -eq 1 && "$#" -eq 0 ]]; then
    echo "pre-push: local SonarQube freshness skipped — push deletes refs only." >&2
    exit 0
fi

sonar_env_load "${ROOT}"
if [[ -z "${SONAR_TOKEN:-}" ]]; then
    echo "pre-push: local SonarQube skipped — add SONAR_TOKEN to .env (see .env.example)" >&2
    exit 0
fi

if [[ "${push_mode}" -eq 0 ]]; then
    set -- "$(git rev-parse HEAD)"
fi

state="${ROOT}/tmp/sonar-state.json"
scanned=""
scanned_host=""
if [[ -f "${state}" ]]; then
    scanned="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("commit",""))' "${state}" 2>/dev/null || true)"
    scanned_host="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("host",""))' "${state}" 2>/dev/null || true)"
fi

if [[ -f "${state}" && -z "${scanned_host}" ]]; then
    echo "pre-push: local SonarQube scan record has no host." >&2
    echo "pre-push: run bash scripts/sonar_scan.sh, then push again." >&2
    exit 1
fi
expected_host="$(sonar_normalize_url "${SONAR_HOST_URL}")"
recorded_host="$(sonar_normalize_url "${scanned_host}")"
if [[ -n "${scanned_host}" && "${recorded_host}" != "${expected_host}" ]]; then
    echo "pre-push: local SonarQube scan was recorded for ${scanned_host}, not ${SONAR_HOST_URL}." >&2
    echo "pre-push: run bash scripts/sonar_scan.sh, then push again." >&2
    exit 1
fi

for commit in "$@"; do
    if [[ "${scanned}" != "${commit}" ]]; then
        echo "pre-push: local SonarQube scan is not current for ${commit}." >&2
        echo "pre-push: run bash scripts/sonar_scan.sh, then push again." >&2
        exit 1
    fi
done

echo "pre-push: local SonarQube scan matches ${scanned}." >&2
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    sonar_freshness_main "$@"
fi
