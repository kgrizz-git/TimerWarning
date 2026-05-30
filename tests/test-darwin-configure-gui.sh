#!/bin/bash
# Run headless macOS configure GUI regression tests (grid, JSON, daemon, modal).
#
# Usage: ./tests/test-darwin-configure-gui.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${SCRIPT_DIR}"

run() {
    local script="$1"
    echo ""
    echo "========== ${script} =========="
    bash "${script}"
}

run "tests/test-darwin-multi-column-parse.sh"
run "tests/test-darwin-grid-cache.sh"
run "tests/test-darwin-table-json.sh"
run "tests/test-darwin-daemon-protocol.sh"
run "tests/test-darwin-time-dialog.sh"
python3 "tests/test-darwin-modal-dialog.py"

echo ""
echo "All darwin configure GUI regression tests passed."
