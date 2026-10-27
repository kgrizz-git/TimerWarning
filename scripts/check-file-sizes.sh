#!/usr/bin/env bash

###############################################################################
# check-file-sizes.sh — Line caps with a ratchet for lib/*.sh and lib/*.py
#
# Caps: 900 lines for lib/*.sh, 500 lines for lib/*.py. Tests are uncapped.
#
# Ratchet: a file already over its cap has a recorded ceiling in ceiling_for()
# below. The check fails when the file grows past its ceiling. It also fails
# when the file shrinks below the ceiling without lowering it, and when a file
# is back under its cap but still has a ceiling. Lower or remove the ceiling in
# the commit that shrinks the file.
#
# Usage:
#   ./scripts/check-file-sizes.sh            # warn-only, exit 0
#   ./scripts/check-file-sizes.sh --strict   # exit 1 on a violation
#   ... --stdin lib/config.sh < blob         # check one blob (pre-commit)
#
# See: dev-docs/CONTRIBUTING.md, dev-docs/plans/plan-quality-gates-2026-10-26.md
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

STRICT=false
STDIN_PATH=""
FINDINGS=0
SH_CAP=900
PY_CAP=500

# Recorded line counts for files already over their cap (2026-10-27).
ceiling_for() {
    case "$1" in
        lib/config.sh) echo 908 ;;
        lib/window-management.sh) echo 933 ;;
        lib/configure-dialogs-darwin.sh) echo 939 ;;
        *) echo "" ;;
    esac
}

usage() {
    cat <<'EOF2'
Usage: check-file-sizes.sh [--strict] [--stdin PATH]

  --strict       Exit non-zero on a violation
  --stdin PATH   Judge the blob on stdin as if it were PATH (staged content)
EOF2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict) STRICT=true ;;
        --stdin)
            shift
            STDIN_PATH="${1:-}"
            [[ -n "${STDIN_PATH}" ]] || { usage >&2; exit 2; }
            ;;
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

cap_for() {
    case "$1" in
        lib/*.sh) echo "${SH_CAP}" ;;
        lib/*.py) echo "${PY_CAP}" ;;
        *) echo "" ;;
    esac
}

check_one() {
    local rel="$1" lines="$2" cap ceiling
    cap="$(cap_for "${rel}")"
    [[ -n "${cap}" ]] || return 0
    ceiling="$(ceiling_for "${rel}")"
    if [[ -z "${ceiling}" ]]; then
        if [[ "${lines}" -gt "${cap}" ]]; then
            note "${rel}: ${lines} lines > ${cap}. Split it. Do not add a ceiling to hide growth."
        fi
        return 0
    fi
    if [[ "${lines}" -le "${cap}" ]]; then
        note "${rel}: ${lines} lines is back under the ${cap} cap. Remove its ceiling (${ceiling}) in scripts/check-file-sizes.sh."
    elif [[ "${lines}" -gt "${ceiling}" ]]; then
        note "${rel}: ${lines} lines > recorded ceiling ${ceiling}. Shrink it; the file may not grow."
    elif [[ "${lines}" -lt "${ceiling}" ]]; then
        note "${rel}: ${lines} lines < recorded ceiling ${ceiling}. Lower the ceiling to ${lines} in scripts/check-file-sizes.sh."
    fi
}

if [[ -n "${STDIN_PATH}" ]]; then
    check_one "${STDIN_PATH}" "$(wc -l | tr -d ' ')"
else
    echo "=== line caps: lib/*.sh ${SH_CAP}, lib/*.py ${PY_CAP}, with a ratchet ===" >&2
    for f in lib/*.sh lib/*.py; do
        [[ -f "${f}" ]] || continue
        check_one "${f}" "$(wc -l < "${f}" | tr -d ' ')"
    done
fi

if [[ "${FINDINGS}" -eq 0 ]]; then
    echo "check-file-sizes: OK" >&2
    exit 0
fi

echo "check-file-sizes: ${FINDINGS} problem(s)" >&2
if [[ "${STRICT}" = true ]]; then
    exit 1
fi
exit 0
