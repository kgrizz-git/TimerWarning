#!/usr/bin/env bash

###############################################################################
# check-stale-plans.sh — Warn when completed plans still live under dev-docs/plans/
#
# Scans dev-docs/plans/*.md (not plans/phases/ or plans/master/).
# Default: warn-only, exit 0. --strict exits 1 when findings exist.
#
# See: dev-docs/development/doc-retention.md
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

STRICT=false
FINDINGS=0

usage() {
    cat <<'EOF'
Usage: check-stale-plans.sh [--strict]

  --strict   Exit non-zero when stale plans are found (default: warn-only)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --strict) STRICT=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "check-stale-plans.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

note() {
    echo "check-stale-plans: $*"
    FINDINGS=$((FINDINGS + 1))
}

scan_plan() {
    local filepath="$1"
    local relpath="${filepath#${ROOT}/}"

    if grep -qE '(^|\*\*)Status:\s*Complete|^\> \*\*Status: Superseded|^\*\*Complete\*\* — Phases' "${filepath}" 2>/dev/null; then
        note "Complete/superseded plan still in dev-docs/plans/: ${relpath} — move to dev-docs/completed-plans/"
        return
    fi

    if grep -qE 'Superseded \(archived\)|do not execute this checklist' "${filepath}" 2>/dev/null; then
        note "Archived banner in active plans folder: ${relpath} — move to dev-docs/completed-plans/"
    fi
}

for filepath in dev-docs/plans/*.md; do
    [ -f "${filepath}" ] || continue
    scan_plan "${filepath}"
done

if [ "${FINDINGS}" -eq 0 ]; then
    echo "check-stale-plans: no stale plans found"
    exit 0
fi

echo "check-stale-plans: ${FINDINGS} finding(s) — see dev-docs/development/doc-retention.md"

if [ "${STRICT}" = true ]; then
    exit 1
fi
exit 0
