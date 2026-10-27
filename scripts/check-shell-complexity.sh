#!/usr/bin/env bash

###############################################################################
# check-shell-complexity.sh — Cap shell function length and control nesting
#
# Not cyclomatic complexity. scripts/shell_complexity.py counts, per function,
# the lines from `name() {` to its closing brace, and the deepest nesting of
# if/for/while/until/case/select. New functions, and edits that push a function
# past a ceiling, fail. Tests and backups are not checked.
#
# Ceilings are the maximum measured on 2026-10-27 over lib/*.sh and the root
# entry scripts (622 functions):
#   MAX_LENGTH=535  configure.sh:151 main
#   MAX_DEPTH=7     configure.sh:151 main
#                   lib/configure-display-summary.sh:8 show_summary
#                   lib/configure-input-time.sh:274 get_day_hours
# Lower a ceiling in the commit that brings every function on it down.
#
# Usage:
#   ./scripts/check-shell-complexity.sh                    # lib/*.sh + root *.sh
#   ./scripts/check-shell-complexity.sh FILE...
#   ... --stdin NAME < blob                                # staged content
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

MAX_LENGTH=535
MAX_DEPTH=7

if ! command -v python3 >/dev/null 2>&1; then
    echo "check-shell-complexity: python3 is required." >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    set -- lib/*.sh ./*.sh
fi

python3 "${ROOT}/scripts/shell_complexity.py" \
    --max-length "${MAX_LENGTH}" --max-depth "${MAX_DEPTH}" "$@"
echo "check-shell-complexity: OK (length <= ${MAX_LENGTH}, nesting <= ${MAX_DEPTH})" >&2
