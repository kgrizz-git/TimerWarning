#!/bin/bash

###############################################################################
# Quick display environment check
###############################################################################

echo "=== Display Environment Variables ==="
echo "DISPLAY: '${DISPLAY}'"
echo "WAYLAND_DISPLAY: '${WAYLAND_DISPLAY}'"
echo "XDG_RUNTIME_DIR: '${XDG_RUNTIME_DIR}'"
echo "XDG_SESSION_TYPE: '${XDG_SESSION_TYPE}'"
echo ""

echo "=== Available display-related sockets ==="
echo "X11 sockets:"
ls -la /tmp/.X11-unix/ 2>/dev/null || echo "  No X11 sockets found"
echo ""

if [ -n "${XDG_RUNTIME_DIR}" ]; then
    echo "Wayland sockets in ${XDG_RUNTIME_DIR}:"
    ls -la "${XDG_RUNTIME_DIR}"/wayland-* 2>/dev/null || echo "  No Wayland sockets found"
fi
echo ""

echo "=== Process check ==="
echo "gamescope running?"
pgrep -x gamescope >/dev/null && echo "  Yes (PID: $(pgrep -x gamescope))" || echo "  No"
echo ""

echo "=== Quick command tests (may hang here if there's an issue) ==="

# Test xdpyinfo with timeout
if command -v xdpyinfo >/dev/null 2>&1; then
    echo -n "Testing xdpyinfo... "
    if timeout 2 xdpyinfo >/dev/null 2>&1; then
        echo "OK"
    else
        echo "FAILED or TIMEOUT"
    fi
else
    echo "xdpyinfo: not available"
fi

# Test xset with timeout
if command -v xset >/dev/null 2>&1; then
    echo -n "Testing xset... "
    if timeout 2 xset q >/dev/null 2>&1; then
        echo "OK"
    else
        echo "FAILED or TIMEOUT"
    fi
else
    echo "xset: not available"
fi

# Test loginctl
if command -v loginctl >/dev/null 2>&1; then
    echo -n "Testing loginctl... "
    if timeout 2 loginctl show-session --help >/dev/null 2>&1; then
        echo "OK"
        echo "  Active sessions:"
        loginctl list-sessions 2>/dev/null | head -5
    else
        echo "FAILED or TIMEOUT"
    fi
else
    echo "loginctl: not available"
fi

echo ""
echo "=== Display environment check complete ==="
