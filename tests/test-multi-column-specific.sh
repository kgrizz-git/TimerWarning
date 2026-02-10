#!/bin/bash

###############################################################################
# Test Script for Multi-Column List Dialog (Specific Tests)
#
# This script specifically tests the multi-column list dialog to verify
# it works correctly with the actual use cases from configure-display.sh
#
# Usage:
#   ./tests/test-multi-column-specific.sh
###############################################################################

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required modules
source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/display-detection.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/configure-dialogs.sh" || exit 1

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Multi-Column List Dialog Specific Tests"
echo "=========================================="
echo ""

# Check dialog tool
tool=$(get_dialog_tool)
echo -e "${BLUE}Using dialog tool: ${tool}${NC}"
echo ""

# Test 1: Main Menu Format (like show_main_menu)
echo -e "${GREEN}Test 1: Main Menu Format${NC}"
echo "This simulates the main menu from configure.sh"
echo "It should show 2 columns: Option and Description"
echo "The first column should be hidden from view but returned when selected."
echo ""
read -p "Press Enter to show dialog..."

menu_result=$(show_multi_column_list_dialog \
    "Sleep Warning Configuration" \
    "Select a section to configure:" \
    700 \
    400 \
    1 \
    "Option" \
    "Description" \
    "1" "Popup display frequency [Every 5 min]" \
    "2" "Window Behavior (Size: medium, Position: center)" \
    "3" "Weekdays Configuration ✓" \
    "4" "Weekends Configuration ✓" \
    "5" "Visual Day/Time Grid" \
    "6" "Review and Save")

if [ -n "${menu_result}" ]; then
    echo -e "${GREEN}✓ Selected: '${menu_result}'${NC}"
    echo "Expected: A number from 1-6"
else
    echo "User cancelled or no selection"
fi
echo ""

# Test 2: Visual Grid Format (like show_visual_grid)
echo -e "${GREEN}Test 2: Visual Grid Format${NC}"
echo "This simulates the day/time grid from configure.sh"
echo "It should show 2 columns: Day and Time Ranges"
echo "Select a day to see if it returns the day name correctly."
echo ""
read -p "Press Enter to show dialog..."

grid_result=$(show_multi_column_list_dialog \
    "Visual Day/Time Grid" \
    "Select a day to edit its restricted hours:" \
    800 \
    450 \
    1 \
    "Day" \
    "Time Ranges" \
    "Sunday" "[no restrictions]" \
    "Monday" "Midnight to 4:59 AM" \
    "Tuesday" "[no restrictions]" \
    "Wednesday" "10:00 PM to 11:59 PM" \
    "Thursday" "[no restrictions]" \
    "Friday" "Midnight to 4:59 AM, 10:00 PM to 11:59 PM" \
    "Saturday" "[no restrictions]" \
    "<<BACK>>" "Back to Main Menu")

if [ -n "${grid_result}" ]; then
    echo -e "${GREEN}✓ Selected: '${grid_result}'${NC}"
    echo "Expected: A day name (Sunday-Saturday) or '<<BACK>>'"
else
    echo "User cancelled or no selection"
fi
echo ""

echo "=========================================="
echo "Tests Complete"
echo "=========================================="
echo ""
echo "Please verify:"
echo "  1. Both columns were visible in the dialog"
echo "  2. The correct value was returned (first column)"
echo "  3. The dialog looked properly formatted"
echo "  4. Column headers were displayed correctly"
echo ""
