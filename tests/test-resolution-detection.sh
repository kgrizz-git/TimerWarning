#!/bin/bash

###############################################################################
# Test script to verify display resolution detection methods
#
# This script tests the proposed resolution detection methods from
# enhancement-03 to see which ones work on the current system.
###############################################################################

echo "=== Display Resolution Detection Test ==="
echo ""
echo "Testing proposed methods from enhancement-03..."
echo ""

# Function to test X11 resolution detection
test_x11() {
    echo "----------------------------------------"
    echo "1. Testing X11: xrandr --query"
    echo "----------------------------------------"
    
    if ! command -v xrandr >/dev/null 2>&1; then
        echo "❌ xrandr not found"
        return 1
    fi
    
    echo "Running: xrandr --query"
    echo ""
    
    # Try to get primary display
    primary=$(xrandr --query 2>/dev/null | grep -E " connected.*primary" | head -n1)
    if [ -n "${primary}" ]; then
        echo "Primary display found:"
        echo "  ${primary}"
        resolution=$(echo "${primary}" | grep -oE '[0-9]+x[0-9]+' | head -n1)
        if [ -n "${resolution}" ]; then
            width=$(echo "${resolution}" | cut -d'x' -f1)
            height=$(echo "${resolution}" | cut -d'x' -f2)
            echo "✅ Resolution detected: ${width} × ${height}"
            echo "   Format: ${width} ${height}"
            return 0
        fi
    fi
    
    # Fallback to first connected display
    first=$(xrandr --query 2>/dev/null | grep " connected" | head -n1)
    if [ -n "${first}" ]; then
        echo "First connected display found:"
        echo "  ${first}"
        resolution=$(echo "${first}" | grep -oE '[0-9]+x[0-9]+' | head -n1)
        if [ -n "${resolution}" ]; then
            width=$(echo "${resolution}" | cut -d'x' -f1)
            height=$(echo "${resolution}" | cut -d'x' -f2)
            echo "✅ Resolution detected: ${width} × ${height}"
            echo "   Format: ${width} ${height}"
            return 0
        fi
    fi
    
    echo "❌ Could not extract resolution from xrandr output"
    return 1
}

# Function to test Wayland wlr-randr
test_wayland_wlr_randr() {
    echo ""
    echo "----------------------------------------"
    echo "2. Testing Wayland: wlr-randr --json"
    echo "----------------------------------------"
    
    if ! command -v wlr-randr >/dev/null 2>&1; then
        echo "❌ wlr-randr not found"
        return 1
    fi
    
    echo "Running: wlr-randr --json"
    echo ""
    
    json_output=$(wlr-randr --json 2>/dev/null)
    if [ -z "${json_output}" ]; then
        echo "❌ wlr-randr returned empty output"
        return 1
    fi
    
    echo "JSON output (first 500 chars):"
    echo "${json_output}" | head -c 500
    echo "..."
    echo ""
    
    # Try to parse JSON (basic extraction)
    if command -v jq >/dev/null 2>&1; then
        width=$(echo "${json_output}" | jq -r '.[0].modes[] | select(.current==true) | .width' 2>/dev/null | head -n1)
        height=$(echo "${json_output}" | jq -r '.[0].modes[] | select(.current==true) | .height' 2>/dev/null | head -n1)
        
        if [ -n "${width}" ] && [ -n "${height}" ] && [ "${width}" != "null" ] && [ "${height}" != "null" ]; then
            echo "✅ Resolution detected: ${width} × ${height}"
            echo "   Format: ${width} ${height}"
            return 0
        fi
    else
        echo "⚠️  jq not found - cannot parse JSON automatically"
        echo "   Manual inspection needed"
    fi
    
    echo "❌ Could not extract resolution from wlr-randr JSON"
    return 1
}

# Function to test Sway
test_sway() {
    echo ""
    echo "----------------------------------------"
    echo "3. Testing Sway: swaymsg -t output"
    echo "----------------------------------------"
    
    if [ -z "${WAYLAND_DISPLAY}" ] && [ -z "${SWAYSOCK}" ]; then
        echo "⚠️  Sway environment variables not set"
        echo "   (WAYLAND_DISPLAY or SWAYSOCK)"
    fi
    
    if ! command -v swaymsg >/dev/null 2>&1; then
        echo "❌ swaymsg not found"
        return 1
    fi
    
    echo "Running: swaymsg -t get_outputs"
    echo ""
    
    output=$(swaymsg -t get_outputs 2>/dev/null)
    if [ -z "${output}" ]; then
        echo "❌ swaymsg returned empty output"
        return 1
    fi
    
    echo "Output (first 500 chars):"
    echo "${output}" | head -c 500
    echo "..."
    echo ""
    
    # Try to parse with jq
    if command -v jq >/dev/null 2>&1; then
        width=$(echo "${output}" | jq -r '.[] | select(.active==true) | .current_mode.width' 2>/dev/null | head -n1)
        height=$(echo "${output}" | jq -r '.[] | select(.active==true) | .current_mode.height' 2>/dev/null | head -n1)
        
        if [ -n "${width}" ] && [ -n "${height}" ] && [ "${width}" != "null" ] && [ "${height}" != "null" ]; then
            echo "✅ Resolution detected: ${width} × ${height}"
            echo "   Format: ${width} ${height}"
            return 0
        fi
    else
        echo "⚠️  jq not found - cannot parse JSON automatically"
    fi
    
    echo "❌ Could not extract resolution from swaymsg output"
    return 1
}

# Function to test wayland-info
test_wayland_info() {
    echo ""
    echo "----------------------------------------"
    echo "4. Testing Wayland: wayland-info"
    echo "----------------------------------------"
    
    if ! command -v wayland-info >/dev/null 2>&1; then
        echo "❌ wayland-info not found"
        return 1
    fi
    
    echo "Running: wayland-info"
    echo ""
    
    output=$(wayland-info 2>/dev/null)
    if [ -z "${output}" ]; then
        echo "❌ wayland-info returned empty output"
        return 1
    fi
    
    echo "Output (first 500 chars):"
    echo "${output}" | head -c 500
    echo "..."
    echo ""
    
    # Try to extract resolution (format may vary)
    resolution=$(echo "${output}" | grep -iE "(resolution|size|width.*height)" | head -n1)
    if [ -n "${resolution}" ]; then
        echo "⚠️  Found resolution info: ${resolution}"
        echo "   (Manual parsing may be needed)"
    else
        echo "❌ Could not find resolution in wayland-info output"
    fi
    
    return 1
}

# Function to check gamescope
test_gamescope() {
    echo ""
    echo "----------------------------------------"
    echo "5. Testing gamescope detection"
    echo "----------------------------------------"
    
    # Check for gamescope environment
    if [ -n "${GAMESCOPE_WIDTH}" ] && [ -n "${GAMESCOPE_HEIGHT}" ]; then
        echo "✅ gamescope environment variables found:"
        echo "   GAMESCOPE_WIDTH=${GAMESCOPE_WIDTH}"
        echo "   GAMESCOPE_HEIGHT=${GAMESCOPE_HEIGHT}"
        echo "   Format: ${GAMESCOPE_WIDTH} ${GAMESCOPE_HEIGHT}"
        return 0
    fi
    
    # Check if gamescope is running
    if pgrep -x gamescope >/dev/null 2>&1; then
        echo "⚠️  gamescope process detected, but environment variables not set"
        echo "   May need to use X11 fallback"
    else
        echo "ℹ️  gamescope not detected"
    fi
    
    return 1
}

# Function to detect display server
detect_display_server() {
    echo ""
    echo "----------------------------------------"
    echo "Display Server Detection"
    echo "----------------------------------------"
    
    if [ -n "${WAYLAND_DISPLAY}" ]; then
        echo "✅ Wayland detected: WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
    elif [ -n "${DISPLAY}" ]; then
        echo "✅ X11 detected: DISPLAY=${DISPLAY}"
    else
        echo "⚠️  No display server environment variable found"
    fi
    
    # Check for X11
    if [ -n "${DISPLAY}" ] && command -v xrandr >/dev/null 2>&1; then
        echo "   X11 appears to be available"
    fi
    
    # Check for Wayland
    if [ -n "${WAYLAND_DISPLAY}" ]; then
        echo "   Wayland appears to be available"
    fi
}

# Main execution
detect_display_server

# Test methods in order
success=0

if test_x11; then
    success=1
fi

if test_wayland_wlr_randr; then
    success=1
fi

if test_sway; then
    success=1
fi

if test_wayland_info; then
    success=1
fi

if test_gamescope; then
    success=1
fi

echo ""
echo "=== Summary ==="
echo ""

if [ ${success} -eq 1 ]; then
    echo "✅ At least one resolution detection method succeeded"
else
    echo "❌ No resolution detection methods succeeded"
    echo "   Will need to use absolute pixel fallbacks"
fi

echo ""
echo "Test complete."
