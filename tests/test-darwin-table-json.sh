#!/bin/bash
# Non-GUI tests for darwin table dialog JSON (grid → rows payload).
# Catches empty/malformed table data before it reaches tkinter.
#
# Usage: ./tests/test-darwin-table-json.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/configure-dialogs-darwin.sh
source "${SCRIPT_DIR}/lib/configure-dialogs-darwin.sh"

pass=0
fail=0

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${label}"
        echo "  expected: '${expected}'"
        echo "  actual:   '${actual}'"
        fail=$((fail + 1))
    fi
}

run_python_assert() {
    local label="$1"
    local json_file="$2"
    local code="$3"
    if JSON_FILE="${json_file}" python3 -c "${code}"; then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        echo "FAIL: ${label}"
        fail=$((fail + 1))
    fi
}

json_tmp=$(mktemp "${TMPDIR:-/tmp}/sw-darwin-table.XXXXXX.json")
trap 'rm -f "${json_tmp}"' EXIT

# Realistic weekly grid args (after title/message/size/print_column).
grid_args=(
    1
    "Day" "Restricted Hours" "Config Lock Hours" "Uninstall Lock Hours"
    "Sunday" "[no restrictions]" "[no lock hours]" "[no uninstall lock hours]"
    "Monday" "9:00am -> 5:00pm" "[no lock hours]" "[no uninstall lock hours]"
    "Tuesday" "[no restrictions]" "[no lock hours]" "[no uninstall lock hours]"
    "Wednesday" "[no restrictions]" "[no lock hours]" "[no uninstall lock hours]"
    "Thursday" "[no restrictions]" "[no lock hours]" "[no uninstall lock hours]"
    "Friday" "[no restrictions]" "[no lock hours]" "[no uninstall lock hours]"
    "Saturday" "[no restrictions]" "[no lock hours]" "[no uninstall lock hours]"
    "[Back]" "Return to Main Menu" "" ""
)

_cd_darwin_parse_multi_column_args "${grid_args[@]}"
json_payload=$(_cd_darwin_build_table_json \
    "View Weekly Hours Settings" \
    "Select a day to edit:" \
    1050 500 1)

# Daemon merges op into payload: {"op":"table", ...rest without leading brace duplication}
daemon_line="{\"op\":\"table\",${json_payload:1}"

printf '%s' "${daemon_line}" >"${json_tmp}"

run_python_assert "table JSON parses" "${json_tmp}" "
import json, os
with open(os.environ['JSON_FILE'], encoding='utf-8') as fh:
    p = json.load(fh)
assert p.get('op') == 'table'
cols = p.get('columns') or []
rows = p.get('rows') or []
assert len(cols) == 4, f'expected 4 columns, got {len(cols)}'
assert len(rows) >= 8, f'expected at least 8 rows, got {len(rows)}'
assert rows[0][0] == 'Sunday', rows[0]
assert rows[-1][0] == '[Back]', rows[-1]
for i, row in enumerate(rows):
    assert len(row) == 4, f'row {i} has {len(row)} cells'
    assert any(str(c).strip() for c in row), f'row {i} is entirely empty'
"

run_python_assert "table rows have visible hour text" "${json_tmp}" "
import json, os
with open(os.environ['JSON_FILE'], encoding='utf-8') as fh:
    p = json.load(fh)
monday = p['rows'][1]
assert '9:00am' in monday[1], monday
"

# Empty data array must still produce valid JSON (but zero data rows).
_cd_darwin_parse_multi_column_args 1 "Day" "Restricted Hours" "Config Lock Hours" "Uninstall Lock Hours"
empty_payload=$(_cd_darwin_build_table_json "Title" "Message" 900 500 1)
printf '%s' "${empty_payload}" >"${json_tmp}"
run_python_assert "empty grid data still valid JSON" "${json_tmp}" "
import json, os
with open(os.environ['JSON_FILE'], encoding='utf-8') as fh:
    p = json.load(fh)
assert p['rows'] == []
assert len(p['columns']) == 4
"

# Regression: fourth column header must not be parsed as first data cell.
_cd_darwin_parse_multi_column_args "${grid_args[@]}"
assert_eq "first data cell is Sunday" "Sunday" "${_cd_data[0]}"
assert_eq "num columns detected" "4" "${_cd_num_columns}"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
