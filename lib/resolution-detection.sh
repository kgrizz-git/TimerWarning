#!/bin/bash

###############################################################################
# Sleep Warning System - Display Resolution Detection Module
#
# This module provides display resolution detection functionality for
# calculating window sizes based on display dimensions.
#
# Functions:
# - get_display_resolution() - Get current display resolution (width and height)
#
# Dependencies: None (standalone module)
#
# Usage: Source this file to access resolution detection functions
#   source lib/resolution-detection.sh
#
# This is for Enhancement #3 (Enhanced Window Size Options)
###############################################################################

# Get display resolution
# Returns space-separated "WIDTH HEIGHT" format (e.g., "2560 1440")
# Returns empty string on failure (caller should use absolute pixel fallbacks)
# Exit code: 0 on success, 1 on failure
#
# Detection order:
# 1. X11: xrandr --query (primary display, then first connected)
# 2. Wayland: wlr-randr --json → parse JSON for resolution
# 3. Wayland fallback: swaymsg -t output (if Sway detected)
# 4. Wayland fallback: wayland-info (if available)
# 5. gamescope: Special handling (may need X11 fallback or environment variables)
# 6. Final fallback: Return empty (caller uses absolute pixel values)
#
# Note: Always detects fresh at each call (no caching) as per Enhancement #3
get_display_resolution() {
    local width=""
    local height=""
    
    # Detect display environment
    local display_env=""
    if [ -n "${DISPLAY}" ]; then
        # X11 session
        display_env="x11"
    elif [ -n "${WAYLAND_DISPLAY}" ] || [ -n "${XDG_SESSION_TYPE}" ] && [ "${XDG_SESSION_TYPE}" = "wayland" ]; then
        # Wayland session
        display_env="wayland"
    elif pgrep -x gamescope >/dev/null 2>&1; then
        # gamescope/SteamOS Gaming Mode
        display_env="gamescope"
    fi
    
    # Try X11 detection first (works in X11 and sometimes in gamescope)
    if command -v xrandr >/dev/null 2>&1; then
        local screen_info geometry
        
        # Try to get primary display first (usually the main screen)
        screen_info=$(xrandr --query 2>/dev/null | grep -E " connected primary " | head -n1)
        if [ -z "${screen_info}" ]; then
            # No primary display, get first connected display
            screen_info=$(xrandr --query 2>/dev/null | grep -E " connected " | head -n1)
        fi
        
        if [ -n "${screen_info}" ]; then
            # Extract resolution from screen info
            # Pattern: "connected primary 2560x1440+0+0" or "connected 1920x1080+0+0"
            # Look for resolution pattern: WIDTHxHEIGHT
            geometry=$(echo "${screen_info}" | grep -oE '[0-9]+x[0-9]+' | head -n1)
            
            if [ -n "${geometry}" ]; then
                width=$(echo "${geometry}" | cut -d'x' -f1)
                height=$(echo "${geometry}" | cut -d'x' -f2)
                
                # Validate dimensions are numeric and reasonable
                if [[ "${width}" =~ ^[0-9]+$ ]] && [[ "${height}" =~ ^[0-9]+$ ]] && \
                   [ "${width}" -ge 640 ] && [ "${height}" -ge 480 ]; then
                    echo "${width} ${height}"
                    return 0
                fi
            fi
        fi
    fi
    
    # Try Wayland detection (wlr-randr)
    if [ "${display_env}" = "wayland" ] || [ "${display_env}" = "gamescope" ]; then
        # Try wlr-randr (requires compositor to implement wlr-output-management protocol)
        if command -v wlr-randr >/dev/null 2>&1; then
            local wlr_output
            wlr_output=$(wlr-randr --json 2>/dev/null)
            
            if [ -n "${wlr_output}" ]; then
                # Parse JSON to get resolution
                # Look for "width" and "height" fields in JSON
                # Simple JSON parsing (assumes valid JSON)
                width=$(echo "${wlr_output}" | grep -oE '"width"[[:space:]]*:[[:space:]]*[0-9]+' | head -n1 | grep -oE '[0-9]+')
                height=$(echo "${wlr_output}" | grep -oE '"height"[[:space:]]*:[[:space:]]*[0-9]+' | head -n1 | grep -oE '[0-9]+')
                
                # Validate dimensions
                if [[ "${width}" =~ ^[0-9]+$ ]] && [[ "${height}" =~ ^[0-9]+$ ]] && \
                   [ "${width}" -ge 640 ] && [ "${height}" -ge 480 ]; then
                    echo "${width} ${height}"
                    return 0
                fi
            fi
        fi
        
        # Try swaymsg (Sway-specific)
        if command -v swaymsg >/dev/null 2>&1; then
            local sway_output
            sway_output=$(swaymsg -t get_outputs 2>/dev/null)
            
            if [ -n "${sway_output}" ]; then
                # Parse JSON to get resolution from first active output
                # Look for "width" and "height" in output JSON
                width=$(echo "${sway_output}" | grep -oE '"width"[[:space:]]*:[[:space:]]*[0-9]+' | head -n1 | grep -oE '[0-9]+')
                height=$(echo "${sway_output}" | grep -oE '"height"[[:space:]]*:[[:space:]]*[0-9]+' | head -n1 | grep -oE '[0-9]+')
                
                # Validate dimensions
                if [[ "${width}" =~ ^[0-9]+$ ]] && [[ "${height}" =~ ^[0-9]+$ ]] && \
                   [ "${width}" -ge 640 ] && [ "${height}" -ge 480 ]; then
                    echo "${width} ${height}"
                    return 0
                fi
            fi
        fi
        
        # Try wayland-info (if available)
        if command -v wayland-info >/dev/null 2>&1; then
            local wayland_info
            wayland_info=$(wayland-info 2>/dev/null)
            
            if [ -n "${wayland_info}" ]; then
                # Parse wayland-info output (format may vary)
                # Look for resolution patterns
                width=$(echo "${wayland_info}" | grep -oE '[0-9]+x[0-9]+' | head -n1 | cut -d'x' -f1)
                height=$(echo "${wayland_info}" | grep -oE '[0-9]+x[0-9]+' | head -n1 | cut -d'x' -f2)
                
                # Validate dimensions
                if [[ "${width}" =~ ^[0-9]+$ ]] && [[ "${height}" =~ ^[0-9]+$ ]] && \
                   [ "${width}" -ge 640 ] && [ "${height}" -ge 480 ]; then
                    echo "${width} ${height}"
                    return 0
                fi
            fi
        fi
    fi
    
    # gamescope special handling
    if [ "${display_env}" = "gamescope" ]; then
        # gamescope may set environment variables or we can try X11 fallback
        # Check for gamescope-specific environment variables
        if [ -n "${GAMESCOPE_WIDTH}" ] && [ -n "${GAMESCOPE_HEIGHT}" ]; then
            width="${GAMESCOPE_WIDTH}"
            height="${GAMESCOPE_HEIGHT}"
            
            # Validate dimensions
            if [[ "${width}" =~ ^[0-9]+$ ]] && [[ "${height}" =~ ^[0-9]+$ ]] && \
               [ "${width}" -ge 640 ] && [ "${height}" -ge 480 ]; then
                echo "${width} ${height}"
                return 0
            fi
        fi
        
        # Fallback to X11 detection (gamescope may expose X11)
        # Already tried above, so if we get here, detection failed
    fi
    
    # All detection methods failed - return empty string
    # Caller should use absolute pixel fallbacks
    echo ""
    return 1
}
