#!/usr/bin/env bash

###############################################################################
# pre-commit-checks.sh — Git pre-commit: prune backups + staged security scans
#
# Called from .githooks/pre-commit (enable via scripts/install-git-hooks.sh)
#
# Environment:
#   SKIP_SHELLCHECK=1   Skip ShellCheck on staged .sh files
#   SKIP_GITLEAKS=1     Skip gitleaks protect --staged
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

echo "pre-commit: pruning old tracked backups..."
"${ROOT}/scripts/prune-backups.sh"

# --- ShellCheck on staged shell scripts only ---
if [ "${SKIP_SHELLCHECK:-0}" != "1" ] && command -v shellcheck >/dev/null 2>&1; then
    mapfile -t _staged_sh < <(
        git diff --cached --name-only --diff-filter=ACM 2>/dev/null \
            | grep -E '\.(sh|bash)$' || true
    )
    if [ "${#_staged_sh[@]}" -gt 0 ]; then
        _sc_targets=()
        for _f in "${_staged_sh[@]}"; do
            case "${_f}" in
                backups/*|tests/*)
                    continue
                    ;;
            esac
            _sc_targets+=("${_f}")
        done
        if [ "${#_sc_targets[@]}" -gt 0 ]; then
            echo "pre-commit: ShellCheck on staged shell files (-S error; skips backups/ and tests/)..."
            # Match run-security-scan.sh: fail only on errors, not style/info noise.
            shellcheck -S error -x "${_sc_targets[@]}"
        fi
    fi
elif [ "${SKIP_SHELLCHECK:-0}" != "1" ]; then
    echo "pre-commit: shellcheck not installed; skip (install for CI parity)" >&2
fi

# --- Gitleaks on staged changes ---
if [ "${SKIP_GITLEAKS:-0}" != "1" ] && command -v gitleaks >/dev/null 2>&1; then
    echo "pre-commit: gitleaks protect (staged)..."
    gitleaks protect \
        --staged \
        --config "${ROOT}/.gitleaks.toml" \
        --verbose
elif [ "${SKIP_GITLEAKS:-0}" != "1" ]; then
    echo "pre-commit: gitleaks not installed; skip secret scan (brew install gitleaks)" >&2
fi

echo "pre-commit: checks finished."
