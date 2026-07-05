#!/usr/bin/env bash

###############################################################################
# prune-completed-plans.sh — Prune old files under dev-docs/completed-plans/
#
# Dual threshold: 90 days AND 20 commits. Manual --apply only (not pre-commit).
# See: dev-docs/development/doc-retention.md
###############################################################################

set -euo pipefail

ARCHIVE_MIN_DAYS="${ARCHIVE_MIN_DAYS:-90}"
ARCHIVE_MIN_COMMITS="${ARCHIVE_MIN_COMMITS:-20}"
APPLY=false

PLANS_DIR="dev-docs/completed-plans"

REFERENCE_PATHS=(
    dev-docs/plans
    AGENTS.md
    CHANGELOG.md
)

usage() {
    cat <<'EOF'
Usage: prune-completed-plans.sh [--apply|--dry-run]

Prune tracked files in dev-docs/completed-plans/ when calendar age >= 90 days
AND commit age >= 20 commits.

Default is --dry-run.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=true; shift ;;
        --dry-run) APPLY=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "prune-completed-plans.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "prune-completed-plans.sh: not inside a git repository" >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

[ -d "${PLANS_DIR}" ] || exit 0

parse_date_from_basename() {
    local base="$1"
    if [[ "${base}" =~ -([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6})\.md$ ]]; then
        echo "${BASH_REMATCH[1]:0:10}"
        return 0
    fi
    if [[ "${base}" =~ -([0-9]{4}-[0-9]{2}-[0-9]{2})\.md$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

days_since_date() {
    local d="$1"
    local y="${d:0:4}" m="${d:5:2}" day="${d:8:2}"
    if date -j -f "%Y-%m-%d" "${y}-${m}-${day}" +%s >/dev/null 2>&1; then
        local then now
        then="$(date -j -f "%Y-%m-%d" "${y}-${m}-${day}" +%s)"
        now="$(date +%s)"
        echo $(( (now - then) / 86400 ))
        return 0
    fi
    python3 - <<PY
from datetime import datetime
then = datetime.strptime("${y}-${m}-${day}", "%Y-%m-%d")
print(max(0, (datetime.now() - then).days))
PY
}

days_since_last_commit() {
    local relpath="$1"
    local ts
    ts="$(git log -1 --format=%ct -- "${relpath}" 2>/dev/null || true)"
    [ -n "${ts}" ] || { echo 0; return; }
    python3 - <<PY
import time
print(max(0, int((time.time() - ${ts}) / 86400)))
PY
}

commit_age_for_file() {
    local relpath="$1"
    local last_commit
    last_commit="$(git log -1 --format=%H -- "${relpath}" 2>/dev/null || true)"
    [ -n "${last_commit}" ] || { echo 0; return; }
    git rev-list --count "${last_commit}..HEAD" 2>/dev/null || echo 999
}

has_retain_frontmatter() {
    head -n 10 "$1" 2>/dev/null | grep -qE '^retain:[[:space:]]*true[[:space:]]*$'
}

is_referenced_elsewhere() {
    local base="$1"
    local search_path found
    for search_path in "${REFERENCE_PATHS[@]}"; do
        [ -e "${search_path}" ] || continue
        found="$(git grep -l --fixed-strings "${base}" -- "${search_path}" 2>/dev/null || true)"
        if [ -n "${found}" ]; then
            return 0
        fi
    done
    return 1
}

eligible=0
kept=0
pruned=0

for filepath in "${PLANS_DIR}"/*.md; do
    [ -f "${filepath}" ] || continue
    relpath="${filepath#./}"
    base="$(basename "${filepath}")"

    if ! git ls-files --error-unmatch "${relpath}" >/dev/null 2>&1; then
        kept=$((kept + 1))
        continue
    fi

    date_part="$(parse_date_from_basename "${base}" || true)"
    if [ -n "${date_part}" ]; then
        cal_days="$(days_since_date "${date_part}")"
    else
        cal_days="$(days_since_last_commit "${relpath}")"
    fi

    com_age="$(commit_age_for_file "${relpath}")"

    if [ "${cal_days}" -lt "${ARCHIVE_MIN_DAYS}" ]; then
        kept=$((kept + 1))
        continue
    fi

    if [ "${com_age}" -lt "${ARCHIVE_MIN_COMMITS}" ]; then
        kept=$((kept + 1))
        continue
    fi

    if has_retain_frontmatter "${relpath}"; then
        kept=$((kept + 1))
        continue
    fi

    if is_referenced_elsewhere "${base}"; then
        kept=$((kept + 1))
        continue
    fi

    eligible=$((eligible + 1))
    if [ "${APPLY}" = true ]; then
        rm -f "${filepath}"
        echo "Pruned completed plan (${cal_days}d, ${com_age} commits): ${relpath}"
        pruned=$((pruned + 1))
    else
        echo "Would prune (${cal_days}d, ${com_age} commits): ${relpath}"
    fi
done

if [ "${pruned}" -gt 0 ] && [ "${APPLY}" = true ]; then
    git add -u "${PLANS_DIR}" 2>/dev/null || true
fi

if [ "${eligible}" -gt 0 ]; then
    if [ "${APPLY}" = true ]; then
        echo "prune-completed-plans: ${pruned} pruned, ${kept} kept (${eligible} eligible)"
    else
        echo "prune-completed-plans: ${eligible} eligible — run ./scripts/prune-completed-plans.sh --apply to delete"
    fi
fi

exit 0
