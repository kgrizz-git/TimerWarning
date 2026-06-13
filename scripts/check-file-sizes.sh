#!/usr/bin/env bash

###############################################################################
# check-file-sizes.sh — Warn when lib/*.sh exceeds line budget (harness Phase 8)
#
# Refactor target: facades under 900 lines (June 2026 baseline). Non-blocking
# by default; use --strict before large extractions.
#
# Usage:
#   ./scripts/check-file-sizes.sh           # warn-only, exit 0
#   ./scripts/check-file-sizes.sh --strict  # exit 1 on violation
#
# Allowlist: lib/configure-dialogs-darwin.sh (tkinter daemon; documented exception)
#
# See: dev-docs/CONTRIBUTING.md
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

STRICT=false
MAX_LINES=900
FINDINGS=0

# Basename paths relative to repo root
ALLOWLIST=(
    lib/configure-dialogs-darwin.sh
)

usage() {
    cat <<'EOF'
Usage: check-file-sizes.sh [--strict]

  --strict   Exit non-zero when a non-allowlisted lib/*.sh exceeds 900 lines
EOF
}

is_allowlisted() {
    local rel="$1"
    local entry
    for entry in "${ALLOWLIST[@]}"; do
        if [ "${rel}" = "${entry}" ]; then
            return 0
        fi
    done
    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --strict) STRICT=true ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "check-file-sizes.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

note() {
    FINDINGS=$((FINDINGS + 1))
    echo "check-file-sizes: $*" >&2
}

echo "=== lib/*.sh line budget (max ${MAX_LINES}, allowlist: ${ALLOWLIST[*]}) ===" >&2

while IFS= read -r -d '' f; do
    rel="${f#${ROOT}/}"
    lines=$(wc -l < "${f}" | tr -d ' ')
    if [ "${lines}" -le "${MAX_LINES}" ]; then
        continue
    fi
    if is_allowlisted "${rel}"; then
        echo "check-file-sizes: OK allowlisted ${rel} (${lines} lines)" >&2
        continue
    fi
    note "${rel}: ${lines} lines > ${MAX_LINES} — split facade or add documented allowlist entry"
done < <(find "${ROOT}/lib" -maxdepth 1 -type f -name '*.sh' -print0 2>/dev/null | sort -z)

if [ "${FINDINGS}" -eq 0 ]; then
    echo "check-file-sizes: OK" >&2
    exit 0
fi

echo "check-file-sizes: ${FINDINGS} file(s) over budget" >&2
if [ "${STRICT}" = true ]; then
    exit 1
fi
exit 0
