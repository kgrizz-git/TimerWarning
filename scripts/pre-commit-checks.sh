#!/usr/bin/env bash

###############################################################################
# pre-commit-checks.sh — Git pre-commit: prune backups + staged security scans
#
# Called from .githooks/pre-commit (enable via scripts/install-git-hooks.sh)
#
# Environment:
#   SKIP_SHELLCHECK=1      Skip ShellCheck on staged .sh files
#   SKIP_GITLEAKS=1        Skip gitleaks protect --staged
#   SKIP_ARCHIVE_REPORT=1  Skip dev-docs archive retention report
#   SKIP_QUALITY_CHECKS=1  Skip staged Ruff, shell complexity, and file-size checks
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

echo "pre-commit: pruning old tracked backups..."
"${ROOT}/scripts/prune-backups.sh"

if [ "${SKIP_ARCHIVE_REPORT:-0}" != "1" ]; then
    echo "pre-commit: checking dev-docs archive retention (report-only)..."
    "${ROOT}/scripts/prune-dev-docs-archive.sh"
fi

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

# --- Ruff, shell complexity, file-size ratchet on the staged blobs ---
# Each check reads `git show ":path"`, not the working tree, so a partially
# staged file is judged by what will be committed.
if [[ "${SKIP_QUALITY_CHECKS:-0}" != "1" ]]; then
    mapfile -t _staged_all < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
    _ruff_ok=1
    if ! command -v ruff >/dev/null 2>&1; then
        _ruff_ok=0
    fi
    _ruff_warned=0
    for _f in "${_staged_all[@]}"; do
        case "${_f}" in
            backups/*|tmp/*)
                continue
                ;;
            *)
                ;;
        esac
        case "${_f}" in
            *.py)
                if [[ "${_ruff_ok}" -eq 1 ]]; then
                    echo "pre-commit: ruff on staged ${_f}..."
                    git show ":${_f}" | ruff check --quiet --stdin-filename "${_f}" -
                elif [[ "${_ruff_warned}" -eq 0 ]]; then
                    echo "pre-commit: ruff not installed; skip (pip install -r requirements-dev.txt)" >&2
                    _ruff_warned=1
                fi
                ;;
            *)
                ;;
        esac
        case "${_f}" in
            lib/*.sh|lib/*.py)
                git show ":${_f}" | "${ROOT}/scripts/check-file-sizes.sh" --strict --stdin "${_f}"
                ;;
            *)
                ;;
        esac
        case "${_f}" in
            tests/*)
                ;;
            *.sh)
                git show ":${_f}" | "${ROOT}/scripts/check-shell-complexity.sh" --stdin "${_f}"
                ;;
            *)
                ;;
        esac
    done
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
