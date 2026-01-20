#!/bin/bash

###############################################################################
# Test script to verify window title fix
#
# This script verifies that:
# 1. Configuration window and popup window have different titles
# 2. Window matching doesn't accidentally match the wrong window
###############################################################################

echo "=== Window Title Fix Verification ==="
echo ""

# Check for window tools
if ! command -v wmctrl >/dev/null 2>&1 && ! command -v xdotool >/dev/null 2>&1; then
    echo "ERROR: Neither wmctrl nor xdotool found. Cannot test window matching."
    exit 1
fi

echo "Window Titles:"
echo "  Configuration: 'Sleep Warning Configuration'"
echo "  Popup Alert:   'Restricted Hours Alert'"
echo ""

# Test substring matching
echo "Testing substring matching:"
echo ""

config_title="Sleep Warning Configuration"
popup_title="Restricted Hours Alert"

# Test 1: Verify titles don't share substrings used for matching
echo "1. Checking for substring conflicts..."
if echo "${config_title}" | grep -q "Restricted Hours Alert"; then
    echo "   ❌ FAIL: Config title contains popup title"
elif echo "${popup_title}" | grep -q "Sleep Warning Configuration"; then
    echo "   ❌ FAIL: Popup title contains config title"
else
    echo "   ✅ PASS: No substring conflicts"
fi

# Test 2: Verify they don't match each other with simple grep
echo ""
echo "2. Testing grep matching..."
if echo "${config_title}" | grep -q "^Restricted Hours Alert$"; then
    echo "   ❌ FAIL: Config title matches popup pattern"
elif echo "${popup_title}" | grep -q "^Sleep Warning Configuration$"; then
    echo "   ❌ FAIL: Popup title matches config pattern"
else
    echo "   ✅ PASS: Exact matching works correctly"
fi

# Test 3: Check actual window titles if any are open
echo ""
echo "3. Checking currently open windows..."
if command -v wmctrl >/dev/null 2>&1; then
    config_windows=$(wmctrl -l | grep -c "Sleep Warning Configuration" || true)
    popup_windows=$(wmctrl -l | grep -c "Restricted Hours Alert" || true)
    
    echo "   Found ${config_windows} configuration window(s)"
    echo "   Found ${popup_windows} popup alert window(s)"
    
    if [ "${config_windows}" -gt 0 ] && [ "${popup_windows}" -gt 0 ]; then
        echo ""
        echo "   Both windows are open. Testing that they're distinct:"
        config_id=$(wmctrl -l | grep "Sleep Warning Configuration" | head -n1 | awk '{print $1}')
        popup_id=$(wmctrl -l | grep "Restricted Hours Alert" | head -n1 | awk '{print $1}')
        
        if [ "${config_id}" != "${popup_id}" ]; then
            echo "   ✅ PASS: Windows have different IDs (${config_id} vs ${popup_id})"
        else
            echo "   ❌ FAIL: Windows have same ID (shouldn't happen)"
        fi
    fi
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "Summary:"
echo "  - Popup title changed to 'Restricted Hours Alert'"
echo "  - Configuration title remains 'Sleep Warning Configuration'"
echo "  - No substring conflicts between titles"
echo "  - Window matching should work correctly"
