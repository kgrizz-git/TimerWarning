#!/bin/bash

###############################################################################
# Test script to verify how different dialog tools handle size parameters
#
# This script tests whether zenity, yad, and kdialog respect requested
# window sizes or auto-resize to fit content.
###############################################################################

echo "=== Dialog Tool Size Behavior Test ==="
echo ""
echo "This test will display dialogs with different tools and requested sizes."
echo "Please observe whether the windows appear at the requested size."
echo ""

# Check available tools
available_tools=()
if command -v zenity >/dev/null 2>&1; then
    available_tools+=("zenity")
fi
if command -v yad >/dev/null 2>&1; then
    available_tools+=("yad")
fi
if command -v kdialog >/dev/null 2>&1; then
    available_tools+=("kdialog")
fi

if [ ${#available_tools[@]} -eq 0 ]; then
    echo "ERROR: No dialog tools found (zenity, yad, kdialog)"
    exit 1
fi

echo "Available tools: ${available_tools[*]}"
echo ""

# Check for window tools
window_tool=""
if command -v xdotool >/dev/null 2>&1; then
    window_tool="xdotool"
elif command -v wmctrl >/dev/null 2>&1; then
    window_tool="wmctrl"
fi

if [ -z "${window_tool}" ]; then
    echo "WARNING: No window tools found (xdotool, wmctrl)"
    echo "         Cannot measure actual window sizes"
    echo ""
fi

# Test message
message="This is a test message to check window sizing behavior.

The requested window size should be displayed in the title bar.

Does the window appear at the requested size, or has it been resized to fit content?"

# Test different sizes
declare -A test_sizes=(
    ["Small"]="400 250"
    ["Medium"]="800 500"
    ["Tiny"]="200 100"
)

for tool in "${available_tools[@]}"; do
    echo "=========================================="
    echo "Testing: ${tool}"
    echo "=========================================="
    echo ""
    
    for size_name in "Small" "Medium" "Tiny"; do
        read width height <<< "${test_sizes[${size_name}]}"
        
        echo "Test: ${size_name} (${width}x${height})"
        echo "  Launching dialog..."
        
        case "${tool}" in
            zenity)
                zenity --info \
                    --title="Test: zenity ${width}x${height}" \
                    --text="${message}" \
                    --width="${width}" \
                    --height="${height}" \
                    2>/dev/null &
                pid=$!
                ;;
            yad)
                yad --info \
                    --title="Test: yad ${width}x${height}" \
                    --text="${message}" \
                    --geometry="${width}x${height}+100+100" \
                    --on-top \
                    2>/dev/null &
                pid=$!
                ;;
            kdialog)
                # kdialog doesn't support size parameters
                kdialog --title "Test: kdialog ${width}x${height} (NO SIZE CONTROL)" \
                    --msgbox "${message}" \
                    2>/dev/null &
                pid=$!
                ;;
        esac
        
        # Wait for window to appear
        sleep 1
        
        # Try to measure actual window size
        if [ -n "${window_tool}" ]; then
            case "${window_tool}" in
                xdotool)
                    window_id=$(xdotool search --pid ${pid} 2>/dev/null | head -n1)
                    if [ -n "${window_id}" ]; then
                        geometry=$(xdotool getwindowgeometry ${window_id} 2>/dev/null | grep "Geometry:" | awk '{print $2}')
                        if [ -n "${geometry}" ]; then
                            actual_width=$(echo "${geometry}" | cut -d'x' -f1)
                            actual_height=$(echo "${geometry}" | cut -d'x' -f2)
                            echo "  Requested: ${width}x${height}"
                            echo "  Actual:    ${actual_width}x${actual_height}"
                            
                            # Check if size matches (within small tolerance)
                            width_diff=$((actual_width - width))
                            height_diff=$((actual_height - height))
                            width_diff=${width_diff#-}  # abs value
                            height_diff=${height_diff#-}  # abs value
                            
                            if [ "${width_diff}" -lt 20 ] && [ "${height_diff}" -lt 20 ]; then
                                echo "  Status:    ✅ Size respected (within 20px)"
                            else
                                echo "  Status:    ⚠️  Size modified by tool"
                            fi
                        fi
                    fi
                    ;;
                wmctrl)
                    sleep 0.5
                    window_info=$(wmctrl -lG | grep "Test: ${tool}" | head -n1)
                    if [ -n "${window_info}" ]; then
                        actual_width=$(echo "${window_info}" | awk '{print $5}')
                        actual_height=$(echo "${window_info}" | awk '{print $6}')
                        echo "  Requested: ${width}x${height}"
                        echo "  Actual:    ${actual_width}x${actual_height}"
                        
                        # Check if size matches (within small tolerance)
                        width_diff=$((actual_width - width))
                        height_diff=$((actual_height - height))
                        width_diff=${width_diff#-}  # abs value
                        height_diff=${height_diff#-}  # abs value
                        
                        if [ "${width_diff}" -lt 20 ] && [ "${height_diff}" -lt 20 ]; then
                            echo "  Status:    ✅ Size respected (within 20px)"
                        else
                            echo "  Status:    ⚠️  Size modified by tool"
                        fi
                    fi
                    ;;
            esac
        fi
        
        echo ""
        read -p "  Press Enter to close this dialog and continue..."
        
        # Close the dialog
        if kill -0 ${pid} 2>/dev/null; then
            kill ${pid} 2>/dev/null
        fi
        
        echo ""
    done
    
    echo ""
done

echo "=== Summary ==="
echo ""
echo "Known behavior:"
echo ""
echo "zenity:"
echo "  - Accepts --width and --height parameters"
echo "  - Often treats these as MINIMUM sizes"
echo "  - May expand to fit content (text, buttons)"
echo "  - Title bar and buttons add ~80-100px to height"
echo ""
echo "yad:"
echo "  - Accepts --geometry (WIDTHxHEIGHT+X+Y)"
echo "  - Generally respects size better than zenity"
echo "  - May still adjust slightly for content"
echo "  - Most reliable for size control"
echo ""
echo "kdialog:"
echo "  - NO size control parameters available"
echo "  - Always auto-sizes to fit content"
echo "  - Size depends entirely on message length and buttons"
echo ""
echo "Impact on positioning:"
echo "  - If actual size differs from requested, position calculations may be off"
echo "  - Bounds checking helps prevent off-screen windows"
echo "  - Post-creation repositioning uses actual window position"
echo ""

echo "=== Test Complete ==="
