#!/bin/bash

###############################################################################
# Test script to verify popup positioning stays within screen bounds
#
# This script tests that popups appear fully on screen with proper margins
# for window decorations and taskbars/panels.
###############################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Source required libraries
source "${PROJECT_DIR}/lib/window-management.sh"

echo "=== Popup Position Bounds Test ==="
echo ""

# Get screen dimensions
screen_info=$(xrandr --current 2>/dev/null | grep -E " connected primary " | head -n1)
if [ -z "${screen_info}" ]; then
    screen_info=$(xrandr --current 2>/dev/null | grep -E " connected " | head -n1)
fi

if [ -z "${screen_info}" ]; then
    echo "ERROR: Could not detect screen dimensions"
    exit 1
fi

geometry=$(echo "${screen_info}" | grep -oE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' | head -n1)
screen_width=$(echo "${geometry}" | cut -d'x' -f1)
screen_height=$(echo "${geometry}" | cut -d'x' -f2 | cut -d'+' -f1)

echo "Screen Resolution: ${screen_width}x${screen_height}"
echo ""

# Test all standard popup sizes
declare -A sizes=(
    ["small"]="400 250"
    ["medium"]="800 500"
    ["large"]="2000 1350"
)

# Only test supported positions (center and top-left)
# Other positions have been removed as part of Enhancement #24
positions=("center" "top-left")

for size_name in "small" "medium" "large"; do
    read width height <<< "${sizes[${size_name}]}"
    
    echo "Testing ${size_name} window (${width}x${height}):"
    echo ""
    
    all_pass=true
    
    for pos in "${positions[@]}"; do
        coords=$(calculate_popup_geometry "${pos}" "${width}" "${height}" "true")
        x=$(echo "${coords}" | cut -d' ' -f1)
        y=$(echo "${coords}" | cut -d' ' -f2)
        
        # Calculate window bounds with decorations
        # Title bar + borders: ~40-50px height, ~10px width
        decoration_width=10
        decoration_height=40
        
        x_end=$((x + width + decoration_width))
        y_end=$((y + height + decoration_height))
        
        # Check if within bounds
        status="✅ ON-SCREEN"
        if [ "${x}" -lt 0 ]; then
            status="❌ OFF-SCREEN (left)"
            all_pass=false
        elif [ "${y}" -lt 0 ]; then
            status="❌ OFF-SCREEN (top)"
            all_pass=false
        elif [ "${x_end}" -gt "${screen_width}" ]; then
            status="❌ OFF-SCREEN (right)"
            all_pass=false
        elif [ "${y_end}" -gt "${screen_height}" ]; then
            status="❌ OFF-SCREEN (bottom)"
            all_pass=false
        fi
        
        printf "  %-15s: (%4d, %4d) to (%4d, %4d)  %s\n" \
            "${pos}" "${x}" "${y}" "${x_end}" "${y_end}" "${status}"
    done
    
    echo ""
    
    if [ "${all_pass}" = "true" ]; then
        echo "  ✅ All positions fit on screen for ${size_name} windows"
    else
        if [ "${size_name}" = "large" ]; then
            echo "  ⚠️  Some positions off-screen (expected for large windows on smaller displays)"
        else
            echo "  ❌ FAIL: Some positions off-screen (should not happen for ${size_name} windows)"
        fi
    fi
    
    echo ""
done

echo "=== Margin Information ==="
echo ""
echo "Current margins:"
echo "  Horizontal (left/right): 30px"
echo "  Top: 60px (accounts for title bar + top panels)"
echo "  Bottom: 80px (accounts for taskbar + title bar + decorations)"
echo ""
echo "These margins ensure windows stay fully visible even with:"
echo "  - Window decorations (title bar ~30-40px, borders ~5-10px)"
echo "  - Desktop panels/taskbars (~40-60px)"
echo "  - Safety buffer (~10-20px)"
echo ""

echo "=== Test Complete ==="
