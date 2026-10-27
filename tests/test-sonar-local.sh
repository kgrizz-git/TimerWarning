#!/usr/bin/env bash
# Local Sonar loader and issue-ratchet checks. No server and no token required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/sonar-env.sh
source "${ROOT}/scripts/sonar-env.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "${ROOT}/tmp"
tmp="$(mktemp -d "${ROOT}/tmp/sonar-env-test.XXXXXX")"
trap 'rm -rf "${tmp}"' EXIT

# Leading export and a trailing comment are accepted. The token value is a fixture.
printf 'export SONAR_TOKEN="fixture-token"\nSONAR_HOST_URL=http://example.test:9000 # comment\n' > "${tmp}/.env"
chmod 600 "${tmp}/.env"
env -u SONAR_TOKEN -u SONAR_HOST_URL -u SONAR_TOKEN_SOURCE \
    bash -c 'source "$1"; sonar_env_load "$2"; printf "%s\n" "$SONAR_TOKEN" "$SONAR_HOST_URL"' \
    bash "${ROOT}/scripts/sonar-env.sh" "${tmp}" > "${tmp}/out"
[[ "$(sed -n '1p' "${tmp}/out")" == "fixture-token" ]] || fail "export quoted token was not parsed"
[[ "$(sed -n '2p' "${tmp}/out")" == "http://example.test:9000" ]] || fail "inline comment stayed in the host"

printf 'SONAR_TOKEN=other\n' > "${tmp}/.env"
chmod 644 "${tmp}/.env"
warn="$(env -u SONAR_TOKEN -u SONAR_HOST_URL -u SONAR_TOKEN_SOURCE \
    bash -c 'source "$1"; sonar_env_load "$2"' \
    bash "${ROOT}/scripts/sonar-env.sh" "${tmp}" 2>&1 >/dev/null || true)"
[[ "${warn}" == *"chmod 600"* ]] || fail "group-readable .env did not warn"
chmod 600 "${tmp}/.env"

# Exported token wins over the file.
got="$(env -u SONAR_HOST_URL SONAR_TOKEN="from-env" \
    bash -c 'source "$1"; sonar_env_load "$2"; printf "%s" "$SONAR_TOKEN"' \
    bash "${ROOT}/scripts/sonar-env.sh" "${tmp}")"
[[ "${got}" == "from-env" ]] || fail "exported token did not win"

# shellcheck source=scripts/check-sonar-freshness.sh
source "${ROOT}/scripts/check-sonar-freshness.sh"
LOOPBACK_URL="http://127.0.0.1:9000"
[[ "$(sonar_normalize_url 'http://localhost:9000/')" == "${LOOPBACK_URL}" ]] || fail "localhost was not folded to 127.0.0.1"
[[ "$(sonar_normalize_url 'http://[::1]:9000')" == "${LOOPBACK_URL}" ]] || fail "::1 was not folded to 127.0.0.1"
[[ "$(sonar_normalize_url 'http://localhost:9001')" == "http://127.0.0.1:9001" ]] || fail "localhost port was rewritten"
[[ "$(sonar_normalize_url "${LOOPBACK_URL}")" != "$(sonar_normalize_url 'http://127.0.0.1:9001')" ]] || fail "different ports compared equal"
[[ "$(sonar_normalize_url 'https://localhost:9000')" == "https://127.0.0.1:9000" ]] || fail "https localhost was not folded"
[[ "$(sonar_normalize_url 'https://127.0.0.1:9000')" != "$(sonar_normalize_url "${LOOPBACK_URL}")" ]] || fail "schemes compared equal"
[[ "$(sonar_normalize_url 'http://example.test:9000')" == "http://example.test:9000" ]] || fail "a non-loopback host was rewritten"

python3 "${ROOT}/tests/test-sonar-issues.py"
echo "PASS: local sonar env parser and issue ratchet"
