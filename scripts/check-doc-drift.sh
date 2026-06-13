#!/usr/bin/env bash

###############################################################################
# check-doc-drift.sh — Lightweight doc consistency checks (harness Phase 5)
#
# Detects stale safety wording and relocated doc paths after the docs/ →
# dev-docs/ rehome. Does not modify files.
#
# Usage:
#   ./scripts/check-doc-drift.sh           # print findings, exit 0 (warn-only)
#   ./scripts/check-doc-drift.sh --strict  # exit 1 if any finding
#
# CI: warn-only by default (no --strict). Use --strict locally before release.
#
# See: dev-docs/development/security-scanning.md
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

STRICT=false
FINDINGS=0

usage() {
    cat <<'EOF'
Usage: check-doc-drift.sh [--strict]

  --strict   Exit non-zero when drift is detected (default: warn-only, exit 0)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --strict) STRICT=true ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "check-doc-drift.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

note() {
    FINDINGS=$((FINDINGS + 1))
    echo "check-doc-drift: $*" >&2
}

# Files excluded from stale-path / wording scans (historical or intentional stubs).
is_excluded_scan_path() {
    local rel="$1"
    case "${rel}" in
        docs/development/*|docs/architecture/*|docs/harness-engineering.md|docs/agent-workflow.md|docs/core-beliefs.md|docs/safety-linux-macos-analysis.md|docs/references/*)
            return 0
            ;;
        dev-docs/safety-scans/*|dev-docs/completed-plans/*|dev-docs/refactor-assessments/*|dev-docs/enhancements/*|dev-docs/plans/*|scripts/check-doc-drift.sh|backups/*|.cursor/plans/*|.git/*)
            return 0
            ;;
    esac
    return 1
}

collect_canonical_markdown() {
    local paths=(
        AGENTS.md
        README.md
        CHANGELOG.md
        CLAUDE.md
        tests/README.md
        docs/index.md
        docs/SAFETY.md
        dev-docs/README.md
        dev-docs/TECHNICAL_DETAILS.md
        dev-docs/canonical-vs-archive.md
        dev-docs/harness-engineering.md
        dev-docs/agent-workflow.md
        dev-docs/safety-linux-macos-analysis.md
        dev-docs/templates/safety-scan-template.md
        dev-docs/development
        dev-docs/architecture
        user-docs
        .github
        .cursor/rules
    )
    local p f
    for p in "${paths[@]}"; do
        if [ -f "${ROOT}/${p}" ]; then
            echo "${p}"
        elif [ -d "${ROOT}/${p}" ]; then
            while IFS= read -r -d '' f; do
                rel="${f#${ROOT}/}"
                if ! is_excluded_scan_path "${rel}"; then
                    echo "${rel}"
                fi
            done < <(find "${ROOT}/${p}" -type f -name '*.md' -print0 2>/dev/null)
        fi
    done | sort -u
}

STALE_PATH_RE='[^-]docs/(development|architecture|harness-engineering|agent-workflow|core-beliefs)/'

scan_stale_doc_paths() {
    local rel line unreleased
    while IFS= read -r rel; do
        [ -n "${rel}" ] || continue
        case "${rel}" in
            CHANGELOG.md)
                # Release history may cite old paths; skip path scan.
                continue
                ;;
        esac
        while IFS= read -r line; do
            note "${rel}:${line}: stale relocated path (use dev-docs/…; docs/… stubs are redirect-only)"
        done < <(grep -nE "${STALE_PATH_RE}" "${ROOT}/${rel}" 2>/dev/null || true)
    done < <(collect_canonical_markdown)
}

scan_stale_safety_wording() {
    local rel
    local patterns=(
        'choose to save anyway'
        'save anyway or modify'
        'Warning shown, automatic safety overrides applied if user confirms'
        "you'll see a warning and can choose to save anyway"
        'you can still save, but safety features will be automatically applied'
    )
    local pat
    while IFS= read -r rel; do
        [ -n "${rel}" ] || continue
        case "${rel}" in
            CHANGELOG.md)
                # Only scan [Unreleased] for stale product-doc wording.
                local unreleased
                unreleased="$(awk '/^## \[Unreleased\]/{flag=1; next} /^## \[/{flag=0} flag' "${ROOT}/${rel}" 2>/dev/null || true)"
                if [ -z "${unreleased}" ]; then
                    continue
                fi
                for pat in "${patterns[@]}"; do
                    if printf '%s\n' "${unreleased}" | grep -qF "${pat}"; then
                        note "${rel} [Unreleased]: stale safety wording (${pat}) — align with docs/SAFETY.md per-day hard block"
                    fi
                done
                continue
                ;;
        esac
        for pat in "${patterns[@]}"; do
            while IFS= read -r line; do
                note "${rel}:${line}: stale safety wording (${pat}) — see docs/SAFETY.md per-day 16 h cap"
            done < <(grep -nF "${pat}" "${ROOT}/${rel}" 2>/dev/null || true)
        done
    done < <(collect_canonical_markdown)
}

scan_stale_weekly_threshold_docs() {
    local rel line
    while IFS= read -r rel; do
        [ -n "${rel}" ] || continue
        while IFS= read -r line; do
            note "${rel}:${line}: stale weekly threshold (9660 min) — per-day cap is 16 h/category/day"
        done < <(grep -n '9660 minutes' "${ROOT}/${rel}" 2>/dev/null || true)
    done < <(collect_canonical_markdown)
}

check_markdown_links() {
    local link_files=(
        AGENTS.md
        dev-docs/README.md
        docs/index.md
        docs/SAFETY.md
    )
    while IFS= read -r msg; do
        [ -n "${msg}" ] && note "${msg}"
    done < <(python3 - "${ROOT}" "${link_files[@]}" <<'PY' 2>/dev/null || true
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
files = sys.argv[2:]
link_re = re.compile(r'\[[^\]]*\]\(([^)]+)\)')
findings = []

for rel in files:
    path = root / rel
    if not path.is_file():
        findings.append(f"{rel}: file missing (link check skipped)")
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    for m in link_re.finditer(text):
        target = m.group(1).strip()
        if not target or target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        if " " in target:
            target = target.split(" ", 1)[0]
        dest = (path.parent / target).resolve()
        try:
            dest.relative_to(root.resolve())
        except ValueError:
            continue
        if not dest.exists():
            line = text.count("\n", 0, m.start()) + 1
            findings.append(f"{rel}:{line}: broken relative link → {target}")

for f in findings:
    print(f)
PY
)
}

echo "=== Doc drift scan ===" >&2

scan_stale_doc_paths
scan_stale_safety_wording
scan_stale_weekly_threshold_docs
check_markdown_links

if [ "${FINDINGS}" -eq 0 ]; then
    echo "check-doc-drift: OK (no findings)" >&2
    exit 0
fi

echo "check-doc-drift: ${FINDINGS} finding(s)" >&2
if [ "${STRICT}" = true ]; then
    exit 1
fi
exit 0
