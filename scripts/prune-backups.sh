#!/bin/bash

###############################################################################
# prune-backups.sh — Remove tracked backup files older than N commits
#
# Purpose:
#   Keeps the backups/ folder from growing without bound. For each tracked file
#   under backups/, if the last git commit that touched the file is more than
#   MAX_COMMIT_AGE commits behind HEAD, the file is deleted and the removal is
#   staged (git add -u).
#
# Untracked or never-committed backup files are always kept (active local copies).
#
# Inputs:
#   BACKUPS_DIR       — directory to scan (default: backups)
#   MAX_COMMIT_AGE    — keep if last change is within this many commits (default: 3)
#   --dry-run         — print actions only, do not delete or stage
#
# Requirements: git, bash
#
# Typical use: called from .githooks/pre-commit before each commit.
###############################################################################

set -euo pipefail

BACKUPS_DIR="backups"
MAX_COMMIT_AGE=3
DRY_RUN=false

usage() {
    cat <<'EOF'
Usage: prune-backups.sh [--dry-run] [BACKUPS_DIR] [MAX_COMMIT_AGE]

Remove tracked files in BACKUPS_DIR whose last git commit is more than
MAX_COMMIT_AGE commits behind HEAD. Default: backups/ and 3.

Examples:
  ./scripts/prune-backups.sh --dry-run
  ./scripts/prune-backups.sh backups 5
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                MAX_COMMIT_AGE="$1"
            else
                BACKUPS_DIR="$1"
            fi
            shift
            ;;
    esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "prune-backups.sh: not inside a git repository" >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

if [ ! -d "${BACKUPS_DIR}" ]; then
    exit 0
fi

deleted=0
kept=0

for filepath in "${BACKUPS_DIR}"/*; do
    [ -e "${filepath}" ] || continue
    [ -f "${filepath}" ] || continue

    relpath="${filepath#${REPO_ROOT}/}"
    relpath="${relpath#./}"

    # Never-committed or newly staged backups: keep
    if ! git ls-files --error-unmatch "${relpath}" >/dev/null 2>&1; then
        kept=$((kept + 1))
        continue
    fi

    last_commit="$(git log -1 --format=%H -- "${relpath}" 2>/dev/null || true)"
    if [ -z "${last_commit}" ]; then
        kept=$((kept + 1))
        continue
    fi

    # Commits strictly after last_commit up to HEAD
    commit_age="$(git rev-list --count "${last_commit}..HEAD" 2>/dev/null || echo 999)"

    if [ "${commit_age}" -gt "${MAX_COMMIT_AGE}" ]; then
        if [ "${DRY_RUN}" = true ]; then
            echo "Would prune (${commit_age} commits old): ${relpath}"
        else
            rm -f "${filepath}"
            echo "Pruned backup (${commit_age} commits since last change): ${relpath}"
        fi
        deleted=$((deleted + 1))
    else
        kept=$((kept + 1))
    fi
done

if [ "${deleted}" -gt 0 ] && [ "${DRY_RUN}" = false ]; then
    git add -u "${BACKUPS_DIR}" 2>/dev/null || true
fi

if [ "${deleted}" -gt 0 ] || [ "${DRY_RUN}" = true ]; then
    echo "prune-backups: ${deleted} pruned, ${kept} kept (max age ${MAX_COMMIT_AGE} commits)"
fi

exit 0
