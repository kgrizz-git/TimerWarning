#!/bin/bash

###############################################################################
# Test script to verify visual grid display functionality
# Tests that the grid can display days with various configurations
#
# Safety:
#   This test does NOT touch your real installed config.
#   It runs under an isolated temporary HOME directory.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURE_SCRIPT="${PROJECT_ROOT}/configure.sh"

# Run under temp HOME so we never touch the real config.
# Note: Create temp dirs under the repo so sandboxed runs can write to them.
TMP_BASE="${PROJECT_ROOT}/tests/.tmp"
mkdir -p "${TMP_BASE}"
tmp_home="$(mktemp -d -p "${TMP_BASE}" home.XXXXXX)"
export HOME="${tmp_home}"
CONFIG_FILE="${HOME}/.config/sleep-warning/config/sleep-warning.conf"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Testing Visual Grid Display Functionality"
echo "=========================================="
echo ""

# Cleanup function to remove temp HOME
cleanup() {
    chmod -R u+rwX "${tmp_home}" 2>/dev/null || true
    rm -rf "${tmp_home}" 2>/dev/null || true
}

# Set up trap to ensure cleanup on exit or interrupt
trap cleanup EXIT INT TERM

# Test 1: Grid with empty config (all days unrestricted)
echo -e "${YELLOW}Test 1: Grid with empty config${NC}"
cat > "${CONFIG_FILE}" << 'EOF'
# Sleep Warning Configuration
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true
EOF

echo "Expected: All days should show '(no restrictions)' with blank status"
echo ""

# Test 2: Grid with some days configured
echo -e "${YELLOW}Test 2: Grid with some days configured${NC}"
cat > "${CONFIG_FILE}" << 'EOF'
# Sleep Warning Configuration
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true

MONDAY=0-5
TUESDAY=0-5
WEDNESDAY=0-5
THURSDAY=0-5
FRIDAY=0-5
SATURDAY=1-5
EOF

echo "Expected:"
echo "  - Monday-Friday should show '12:00 AM → 5:00 AM'"
echo "  - Saturday should show '1:00 AM → 5:00 AM'"
echo "  - Sunday should show '(no restrictions)'"
echo ""

# Test 3: Grid with overnight ranges
echo -e "${YELLOW}Test 3: Grid with overnight ranges${NC}"
cat > "${CONFIG_FILE}" << 'EOF'
# Sleep Warning Configuration
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true

MONDAY=23-6
TUESDAY=22-8
EOF

echo "Expected:"
echo "  - Monday should show '11:00 PM → 6:00 AM (Tuesday)'"
echo "  - Tuesday should show '10:00 PM → 8:00 AM (Wednesday)'"
echo ""

# Test 4: Grid with multiple time ranges
echo -e "${YELLOW}Test 4: Grid with multiple time ranges${NC}"
cat > "${CONFIG_FILE}" << 'EOF'
# Sleep Warning Configuration
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true

MONDAY=0-5,22-23
EOF

echo "Expected:"
echo "  - Monday should show ✗ with '12:00 AM → 4:59 AM AND 10:00 PM → 11:59 PM'"
echo ""

# Test 5: Grid with explicitly skipped days
echo -e "${YELLOW}Test 5: Grid with explicitly skipped days${NC}"
cat > "${CONFIG_FILE}" << 'EOF'
# Sleep Warning Configuration
CHECK_INTERVAL=10
POPUP_SIZE=medium
POPUP_POSITION=center
POPUP_MIN_DISPLAY_TIME=30
POPUP_IMMOVABLE=true

MONDAY=0-5
TUESDAY=
WEDNESDAY=0-5
EOF

echo "Expected:"
echo "  - Monday should show ✗ with restrictions"
echo "  - Tuesday should show blank with '(no restrictions)' (explicitly skipped)"
echo "  - Wednesday should show ✗ with restrictions"
echo ""

# Config will be restored by trap on exit
# Explicitly call cleanup to restore now (trap will handle if script exits normally)
cleanup

echo ""
echo -e "${GREEN}Configuration test scenarios prepared.${NC}"
echo "These scenarios can be manually tested by running:"
echo "  ./configure.sh --text"
echo "  Then select option 5 (Visual Day/Time Grid)"
echo ""
