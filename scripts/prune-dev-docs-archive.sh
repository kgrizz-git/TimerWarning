#!/usr/bin/env bash

###############################################################################
# prune-dev-docs-archive.sh — Prune old timestamped dev-docs assessments and scans
#
# Purpose:
#   Remove tracked timestamped audit records when BOTH retention thresholds are
#   met: calendar age (filename date) and commit age (last git change).
#
# Default: dry-run (report only). Pre-commit uses dry-run; use --apply to delete.
#
# Inputs (env or flags):
#   ARCHIVE_MIN_DAYS=30
#   ARCHIVE_MIN_COMMITS=10
#   ARCHIVE_KEEP_LATEST=1
#   --apply          Delete eligible files and stage removals (git add -u)
#   --dry-run        Print actions only (default)
#
# See: dev-docs/development/doc-retention.md
#
# Requirements: git, bash; date or python3 for calendar math
###############################################################################

set -euo pipefail

ARCHIVE_MIN_DAYS="${ARCHIVE_MIN_DAYS:-30}"
ARCHIVE_MIN_COMMITS="${ARCHIVE_MIN_COMMITS:-10}"
ARCHIVE_KEEP_LATEST="${ARCHIVE_KEEP_LATEST:-1}"
APPLY=false

SCAN_DIRS=(
    dev-docs/code-assessments
    dev-docs/doc-assessments
    dev-docs/refactor-assessments
    dev-docs/testing-assessments
    dev-docs/safety-scans
)

PROTECT_BASENAMES=(
    test-tiers.md
    test-history.md
)

REFERENCE_PATHS=(
    dev-docs/plans
    docs
    AGENTS.md
    CHANGELOG.md
)

usage() {
    cat <<'EOF'
Usage: prune-dev-docs-archive.sh [--apply|--dry-run]

Prune timestamped files under dev-docs/*-assessments/ and dev-docs/safety-scans/
when calendar age >= ARCHIVE_MIN_DAYS (default 30) AND commit age >=
ARCHIVE_MIN_COMMITS (default 10).

Default is --dry-run (report only). Pre-commit never passes --apply.

Environment:
  ARCHIVE_MIN_DAYS=30
  ARCHIVE_MIN_COMMITS=10
  ARCHIVE_KEEP_LATEST=1

Examples:
  ./scripts/prune-dev-docs-archive.sh
  ./scripts/prune-dev-docs-archive.sh --apply
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --apply)
            APPLY=true
            shift
            ;;
        --dry-run)
            APPLY=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "prune-dev-docs-archive.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "prune-dev-docs-archive.sh: not inside a git repository" >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

# --- helpers ---

is_protected_basename() {
    local base="$1"
    local p
    for p in "${PROTECT_BASENAMES[@]}"; do
        if [ "${base}" = "${p}" ]; then
            return 0
        fi
    done
    return 1
}

parse_timestamp_from_basename() {
    # Prints YYYY-MM-DD-HHMMSS or empty
    local base="$1"
    if [[ "${base}" =~ ^safety-scan-([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6})\.md$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    if [[ "${base}" =~ -([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6})\.md$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

days_since_timestamp() {
    # Args: YYYY-MM-DD-HHMMSS
    local ts="$1"
    local y m d h mi s
    y="${ts:0:4}"
    m="${ts:5:2}"
    d="${ts:8:2}"
    h="${ts:11:2}"
    mi="${ts:13:2}"
    s="${ts:15:2}"

    if date -j -f "%Y-%m-%d %H:%M:%S" "${y}-${m}-${d} ${h}:${mi}:${s}" +%s >/dev/null 2>&1; then
        local then now
        then="$(date -j -f "%Y-%m-%d %H:%M:%S" "${y}-${m}-${d} ${h}:${mi}:${s}" +%s)"
        now="$(date +%s)"
        echo $(( (now - then) / 86400 ))
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - <<PY
from datetime import datetime
import sys
ts = "${y}-${m}-${d} ${h}:${mi}:${s}"
then = datetime.strptime(ts, "%Y-%m-%d %H:%M:%S")
now = datetime.now()
print(max(0, (now - then).days))
PY
        return 0
    fi

    echo "prune-dev-docs-archive.sh: need date (BSD) or python3 for calendar age" >&2
    exit 1
}

has_retain_frontmatter() {
    local relpath="$1"
    head -n 10 "${relpath}" 2>/dev/null | grep -qE '^retain:[[:space:]]*true[[:space:]]*$'
}

is_referenced_elsewhere() {
    local relpath="$1"
    local base="$2"
    local search_path found

    for search_path in "${REFERENCE_PATHS[@]}"; do
        if [ ! -e "${search_path}" ]; then
            continue
        fi
        found="$(git grep -l --fixed-strings "${base}" -- "${search_path}" 2>/dev/null \
            | grep -v "^${relpath}$" || true)"
        if [ -n "${found}" ]; then
            return 0
        fi
    done

    # Top-level dev-docs/*.md (not assessment folders)
    found="$(git grep -l --fixed-strings "${base}" -- 'dev-docs/*.md' 2>/dev/null \
        | grep -vE '^dev-docs/(code-assessments|doc-assessments|refactor-assessments|testing-assessments|safety-scans)/' \
        | grep -v "^${relpath}$" || true)"
    if [ -n "${found}" ]; then
        return 0
    fi

    return 1
}

commit_age_for_file() {
    local relpath="$1"
    local last_commit
    last_commit="$(git log -1 --format=%H -- "${relpath}" 2>/dev/null || true)"
    if [ -z "${last_commit}" ]; then
        echo 0
        return
    fi
    if ! git rev-list --count "${last_commit}..HEAD" 2>/dev/null; then
        echo "Warning: could not compute commit age for ${relpath}; keeping archive file" >&2
        echo -1
    fi
}

# Collect newest timestamps per directory for keep-latest
KEEP_LIST=()

collect_keep_latest() {
    local dir="$1"
    [ -d "${dir}" ] || return 0

    local -a entries=()
    local filepath base ts
    for filepath in "${dir}"/*.md; do
        [ -f "${filepath}" ] || continue
        base="$(basename "${filepath}")"
        is_protected_basename "${base}" && continue
        ts="$(parse_timestamp_from_basename "${base}" || true)"
        [ -n "${ts}" ] || continue
        entries+=("${ts}:${base}")
    done

    if [ "${#entries[@]}" -eq 0 ]; then
        return 0
    fi

    IFS=$'\n' sorted=($(printf '%s\n' "${entries[@]}" | sort -r))
    unset IFS
    local i=0
    while [ "${i}" -lt "${ARCHIVE_KEEP_LATEST}" ] && [ "${i}" -lt "${#sorted[@]}" ]; do
        base="${sorted[$i]#*:}"
        KEEP_LIST+=("${dir}/${base}")
        i=$((i + 1))
    done
}

is_keep_latest() {
    local relpath="$1"
    local k
    # bash 3.2 with set -u treats "${empty[@]}" as unbound. An empty keep
    # list means nothing is protected.
    if [ "${#KEEP_LIST[@]}" -eq 0 ]; then
        return 1
    fi
    for k in "${KEEP_LIST[@]}"; do
        if [ "${k}" = "${relpath}" ]; then
            return 0
        fi
    done
    return 1
}

for dir in "${SCAN_DIRS[@]}"; do
    collect_keep_latest "${dir}"
done

eligible=0
kept=0
pruned=0

for dir in "${SCAN_DIRS[@]}"; do
    [ -d "${dir}" ] || continue

    for filepath in "${dir}"/*.md; do
        [ -f "${filepath}" ] || continue

        relpath="${filepath#./}"
        base="$(basename "${filepath}")"

        if is_protected_basename "${base}"; then
            kept=$((kept + 1))
            continue
        fi

        if [[ "${relpath}" == dev-docs/enhancements/* ]]; then
            kept=$((kept + 1))
            continue
        fi

        ts="$(parse_timestamp_from_basename "${base}" || true)"
        if [ -z "${ts}" ]; then
            kept=$((kept + 1))
            continue
        fi

        if ! git ls-files --error-unmatch "${relpath}" >/dev/null 2>&1; then
            kept=$((kept + 1))
            continue
        fi

        if is_keep_latest "${relpath}"; then
            kept=$((kept + 1))
            continue
        fi

        cal_days="$(days_since_timestamp "${ts}")"
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

        if is_referenced_elsewhere "${relpath}" "${base}"; then
            kept=$((kept + 1))
            continue
        fi

        eligible=$((eligible + 1))
        if [ "${APPLY}" = true ]; then
            rm -f "${filepath}"
            echo "Pruned archive (${cal_days}d, ${com_age} commits): ${relpath}"
            pruned=$((pruned + 1))
        else
            echo "Would prune (${cal_days}d, ${com_age} commits): ${relpath}"
        fi
    done
done

if [ "${pruned}" -gt 0 ] && [ "${APPLY}" = true ]; then
    for dir in "${SCAN_DIRS[@]}"; do
        git add -u "${dir}" 2>/dev/null || true
    done
fi

if [ "${eligible}" -gt 0 ] || [ "${APPLY}" = true ]; then
    if [ "${APPLY}" = true ]; then
        echo "prune-dev-docs-archive: ${pruned} pruned, ${kept} kept (${eligible} eligible)"
    else
        echo "prune-dev-docs-archive: ${eligible} eligible — run ./scripts/prune-dev-docs-archive.sh --apply to delete"
    fi
fi

exit 0
