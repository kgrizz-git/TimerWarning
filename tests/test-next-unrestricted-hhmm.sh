#!/bin/bash

###############################################################################
# test-next-unrestricted-hhmm.sh - HH:MM config must feed next-unrestricted math
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_DIR}/lib"

TEST_HOME=$(mktemp -d)
export HOME="${TEST_HOME}"
export CONFIG_DIR="${HOME}/.config/sleep-warning"
export CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
mkdir -p "${CONFIG_DIR}/config"

cat > "${CONFIG_FILE}" <<'EOF'
TUESDAY=00:00-05:00,17:00-17:30
EOF

# shellcheck disable=SC1091
source "${LIB_DIR}/config.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/time-parsing.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/configure-core.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/configure-validation.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/time-calculations.sh"

pass=0
fail=0

assert_nonempty_intervals() {
    local count
    count=$(build_weekly_restricted_intervals | grep -cE '^[0-9]+:[0-9]+$' || true)
    if [ "${count}" -gt 0 ]; then
        echo "PASS: build_weekly_restricted_intervals parses HH:MM (${count} intervals)"
        pass=$((pass + 1))
    else
        echo "FAIL: build_weekly_restricted_intervals returned no intervals for HH:MM config"
        fail=$((fail + 1))
    fi
}

assert_not_no_restrictions_msg() {
    local msg
    msg=$(get_next_unrestricted_time)
    if [ "${msg}" = "now (no restrictions configured)" ]; then
        echo "FAIL: get_next_unrestricted_time wrongly reports no restrictions (${msg})"
        fail=$((fail + 1))
    else
        echo "PASS: get_next_unrestricted_time recognizes HH:MM restrictions (${msg})"
        pass=$((pass + 1))
    fi
}

assert_nonempty_intervals
assert_not_no_restrictions_msg

rm -rf "${TEST_HOME}"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ] || exit 1
