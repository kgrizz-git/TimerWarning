#!/usr/bin/env bash

###############################################################################
# run-security-scan.sh — Static security scans + optional Tier-A safety tests
#
# Usage:
#   ./scripts/run-security-scan.sh              # run tools that are installed
#   ./scripts/run-security-scan.sh --ci         # fail if required tools missing
#   ./scripts/run-security-scan.sh --with-tests # also run fast safety unit tests
#
# Tools (install locally for parity with CI): see docs/development/security-scanning.md
#
# See: docs/development/security-scanning.md
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

CI_MODE=false
WITH_TESTS=false

usage() {
    cat <<'EOF'
Usage: run-security-scan.sh [--ci] [--with-tests]

  --ci          Require shellcheck, gitleaks, and semgrep; exit non-zero on findings
  --with-tests  Run fast safety tests (test-daily-caps, test-popup-safety-darwin on macOS)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ci) CI_MODE=true ;;
        --with-tests) WITH_TESTS=true ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "run-security-scan.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

# Production shell scripts only (tests/ are noisy: SC1091 dynamic source, unused colors, etc.)
collect_shell_files() {
    find "${ROOT}" \
        -type f \( -name '*.sh' -o -name '*.bash' \) \
        ! -path "${ROOT}/backups/*" \
        ! -path "${ROOT}/.git/*" \
        ! -path "${ROOT}/tests/*" \
        | sort
}

# Returns 0 if tool exists; 1 if missing in --ci mode; 2 if missing locally (skip).
require_tool() {
    local tool="$1"
    local install_hint="$2"
    if command -v "${tool}" >/dev/null 2>&1; then
        return 0
    fi
    if [ "${CI_MODE}" = true ]; then
        echo "run-security-scan.sh: required tool missing: ${tool}" >&2
        echo "  ${install_hint}" >&2
        return 1
    fi
    echo "run-security-scan.sh: skipping ${tool} (not installed). ${install_hint}" >&2
    return 2
}

_run_if_tool() {
    local runner="$1"
    shift
  local _rc=0
  require_tool "${runner}" "$@" || _rc=$?
  if [ "${_rc}" -eq 2 ]; then
    return 0
  fi
  if [ "${_rc}" -ne 0 ]; then
    return 1
  fi
  return 0
}

run_shellcheck() {
  if ! _run_if_tool shellcheck "Install: brew install shellcheck  OR  apt install shellcheck"; then
    return 1
  fi
  if ! command -v shellcheck >/dev/null 2>&1; then
    return 0
  fi
  echo "=== ShellCheck ==="
  local -a files=()
  mapfile -t files < <(collect_shell_files)
  if [ "${#files[@]}" -eq 0 ]; then
    echo "No shell files found."
    return 0
  fi
  # -S error: fail only on ShellCheck errors in production code (lib/, scripts/, entrypoints).
  # tests/ are excluded. For warnings: shellcheck -S warning (many pre-existing; fix incrementally).
  shellcheck -S error -x "${files[@]}"
}

run_gitleaks() {
  if ! _run_if_tool gitleaks "Install: brew install gitleaks  OR  see https://github.com/gitleaks/gitleaks"; then
    return 1
  fi
  if ! command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi
  echo "=== Gitleaks ==="
  gitleaks detect \
    --source "${ROOT}" \
    --config "${ROOT}/.gitleaks.toml" \
    --verbose
}

run_semgrep() {
  if ! _run_if_tool semgrep "Install: pip install semgrep  OR  brew install semgrep"; then
    return 1
  fi
  if ! command -v semgrep >/dev/null 2>&1; then
    return 0
  fi
  echo "=== Semgrep ==="
  # Registry packs p/bash and p/secrets return HTTP 404; p/ci + r/bash.lang are very noisy on
  # this bash codebase. CI uses project rules only. Optional deeper scan:
  #   semgrep scan --config p/ci --config r/bash.lang
  semgrep scan --error --config "${ROOT}/.semgrep/sleep-warning.yml"
}

run_safety_tests() {
  echo "=== Tier-A safety tests ==="
  local failed=0
  if [ -f "${ROOT}/tests/test-daily-caps.sh" ]; then
    bash "${ROOT}/tests/test-daily-caps.sh" || failed=1
  fi
  # popup-safety unit tests (all platforms); use test-popup-safety-linux.sh as alias on Linux CI
  if [ -f "${ROOT}/tests/test-popup-safety-darwin.sh" ]; then
    bash "${ROOT}/tests/test-popup-safety-darwin.sh" || failed=1
  fi
  if [ -f "${ROOT}/tests/test-configure-partial-lock.sh" ]; then
    bash "${ROOT}/tests/test-configure-partial-lock.sh" || failed=1
  fi
  return "${failed}"
}

main() {
  local exit_code=0
  run_shellcheck || exit_code=1
  run_gitleaks || exit_code=1
  run_semgrep || exit_code=1
  if [ "${WITH_TESTS}" = true ]; then
    run_safety_tests || exit_code=1
  fi
  if [ "${exit_code}" -ne 0 ]; then
    echo "run-security-scan.sh: one or more checks failed." >&2
  else
    echo "run-security-scan.sh: all executed checks passed."
  fi
  exit "${exit_code}"
}

main
