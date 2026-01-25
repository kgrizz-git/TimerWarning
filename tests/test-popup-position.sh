#!/bin/bash

###############################################################################
# Test script for popup position functionality
#
# ⚠️ NOTE: This is an old test script. Not important to run for now.
# This script tests whether popups appear at the configured position
# for different dialog tools (zenity, yad, kdialog)
###############################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Source required libraries
source "${PROJECT_DIR}/lib/config.sh"
source "${PROJECT_DIR}/lib/logging.sh"
source "${PROJECT_DIR}/lib/display-detection.sh"
source "${PROJECT_DIR}/lib/desktop-environment.sh"
source "${PROJECT_DIR}/lib/window-management.sh"
source "${PROJECT_DIR}/lib/popup-display.sh"

echo "=== Popup Position Test ==="
echo ""
echo "Current configuration:"
echo "  Popup Size: $(get_popup_size)"
echo "  Popup Position: $(get_popup_position)"
echo ""

# Get dimensions
popup_size=$(get_popup_size)
dimensions=$(get_popup_dimensions "${popup_size}")
width=$(echo "${dimensions}" | cut -d' ' -f1)
height=$(echo "${dimensions}" | cut -d' ' -f2)
echo "  Dimensions: ${width}x${height}"
echo ""

# Detect display environment
env_type=$(detect_display_environment)
echo "Display environment: ${env_type}"

# Check available tools
dialog_tool=$(check_dialog_tool "${env_type}")
echo "Dialog tool: ${dialog_tool}"

window_tool=$(check_window_tools)
echo "Window tool: ${window_tool}"
echo ""

if [ -z "${dialog_tool}" ]; then
    echo "ERROR: No dialog tool available (zenity/yad/kdialog)"
    exit 1
fi

echo "This test will display a popup at the configured position."
echo "Please verify that the popup appears at: $(get_popup_position)"
echo ""
read -p "Press Enter to show popup..."

# Show the warning popup
show_warning

echo ""
echo "Test complete!"
