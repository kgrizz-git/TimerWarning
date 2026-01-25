#!/bin/bash

###############################################################################
# Debug script to identify where sleep-warning.sh hangs
#
# ⚠️ NOTE: This is an old test script. Not important to run for now.
# This script runs sleep-warning.sh with debug output to identify the hang point
###############################################################################

echo "=== Starting debug test for sleep-warning.sh hang ==="
echo ""

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Script directory: ${SCRIPT_DIR}"
echo ""

echo "=== Sourcing library modules with debug output ==="
echo "1. Sourcing config.sh..."
source "${SCRIPT_DIR}/lib/config.sh" || { echo "FAILED at config.sh"; exit 1; }
echo "   ✓ config.sh loaded"

echo "2. Sourcing logging.sh..."
source "${SCRIPT_DIR}/lib/logging.sh" || { echo "FAILED at logging.sh"; exit 1; }
echo "   ✓ logging.sh loaded"

echo "3. Sourcing display-detection.sh..."
source "${SCRIPT_DIR}/lib/display-detection.sh" || { echo "FAILED at display-detection.sh"; exit 1; }
echo "   ✓ display-detection.sh loaded"

echo "4. Sourcing desktop-environment.sh..."
source "${SCRIPT_DIR}/lib/desktop-environment.sh" || { echo "FAILED at desktop-environment.sh"; exit 1; }
echo "   ✓ desktop-environment.sh loaded"

echo "5. Sourcing window-management.sh..."
source "${SCRIPT_DIR}/lib/window-management.sh" || { echo "FAILED at window-management.sh"; exit 1; }
echo "   ✓ window-management.sh loaded"

echo "6. Sourcing time-validation.sh..."
source "${SCRIPT_DIR}/lib/time-validation.sh" || { echo "FAILED at time-validation.sh"; exit 1; }
echo "   ✓ time-validation.sh loaded"

echo "7. Sourcing popup-display.sh..."
source "${SCRIPT_DIR}/lib/popup-display.sh" || { echo "FAILED at popup-display.sh"; exit 1; }
echo "   ✓ popup-display.sh loaded"

echo ""
echo "=== All modules loaded successfully ==="
echo ""

# Get current time info
echo "=== Current time information ==="
current_day=$(date +%w)
current_hour=$(date +%H)
current_hour=$((10#${current_hour}))
echo "Current day: ${current_day} (0=Sunday, 1=Monday, etc.)"
echo "Current hour: ${current_hour}"
echo ""

# Parse configuration
echo "=== Parsing configuration ==="
restricted_range=$(parse_config "${current_day}")
echo "Restricted range for today: '${restricted_range}'"
echo ""

# Check if restricted
echo "=== Checking if current hour is restricted ==="
is_restricted=false
matched_range="${restricted_range}"

if is_restricted_hour "${current_hour}" "${restricted_range}"; then
    is_restricted=true
    echo "✓ Current hour IS restricted"
elif [ -z "${restricted_range}" ]; then
    echo "Current day has no restrictions, checking previous day for overnight ranges..."
    # Calculate previous day
    if [ "${current_day}" -eq 0 ]; then
        prev_day=6
    else
        prev_day=$((current_day - 1))
    fi
    
    prev_day_range=$(parse_config "${prev_day}")
    echo "Previous day range: '${prev_day_range}'"
    
    if [ -n "${prev_day_range}" ]; then
        IFS=','
        for range in ${prev_day_range}; do
            range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            start_hour=$(echo "${range}" | cut -d'-' -f1)
            end_hour=$(echo "${range}" | cut -d'-' -f2)
            
            if [ "${start_hour}" -gt "${end_hour}" ]; then
                if [ "${current_hour}" -lt "${end_hour}" ]; then
                    is_restricted=true
                    matched_range="${range} (from previous day)"
                    echo "✓ Current hour IS restricted (overnight from previous day)"
                    break
                fi
            fi
        done
    fi
else
    echo "Current hour is NOT restricted"
fi
echo ""

if [ "${is_restricted}" = "true" ]; then
    echo "=== Restricted hour detected, testing display detection ==="
    echo "Matched range: ${matched_range}"
    echo ""
    
    echo "Step 1: Calling detect_display_environment..."
    echo "  (This may hang if display detection has issues)"
    echo "  Environment variables:"
    echo "    DISPLAY=${DISPLAY}"
    echo "    WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
    echo "    XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"
    echo ""
    
    # Add a timeout to detect_display_environment
    echo "  Starting detection (with 5-second timeout)..."
    env_type=$(timeout 5 bash -c "source '${SCRIPT_DIR}/lib/display-detection.sh'; detect_display_environment")
    detect_exit_code=$?
    
    if [ ${detect_exit_code} -eq 124 ]; then
        echo "  ✗ TIMEOUT! detect_display_environment hung for more than 5 seconds"
        echo "  This is likely the source of your hang issue."
        exit 1
    elif [ ${detect_exit_code} -ne 0 ]; then
        echo "  ✗ detect_display_environment failed with exit code ${detect_exit_code}"
        echo "  Display type: '${env_type}'"
    else
        echo "  ✓ detect_display_environment completed"
        echo "  Display type: '${env_type}'"
    fi
    echo ""
    
    echo "Step 2: Calling get_display_identifier..."
    echo "  (This may also hang if display identifier check has issues)"
    echo "  Starting identifier detection (with 5-second timeout)..."
    display_id=$(timeout 5 bash -c "source '${SCRIPT_DIR}/lib/display-detection.sh'; get_display_identifier '${env_type}'")
    identifier_exit_code=$?
    
    if [ ${identifier_exit_code} -eq 124 ]; then
        echo "  ✗ TIMEOUT! get_display_identifier hung for more than 5 seconds"
        echo "  This is likely the source of your hang issue."
        exit 1
    elif [ ${identifier_exit_code} -ne 0 ]; then
        echo "  ✗ get_display_identifier failed with exit code ${identifier_exit_code}"
        echo "  Display ID: '${display_id}'"
    else
        echo "  ✓ get_display_identifier completed"
        echo "  Display ID: '${display_id}'"
    fi
    echo ""
    
    echo "Step 3: Testing show_warning (THIS WILL DISPLAY A POPUP)..."
    echo "  WARNING: This will actually show the warning popup!"
    echo "  Press Ctrl+C now if you don't want to see it..."
    sleep 3
    echo "  Calling show_warning (with 10-second timeout for initial display)..."
    
    # We can't easily timeout show_warning since it's interactive, so just call it
    echo "  Note: show_warning will display a dialog. Close it to continue."
    show_warning
    
    echo "  ✓ show_warning completed"
    echo ""
else
    echo "=== Not a restricted hour, script would exit normally ==="
fi

echo ""
echo "=== Debug test completed successfully ==="
echo "If the script hung, you should see where it stopped above."
