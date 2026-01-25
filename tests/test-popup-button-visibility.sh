#!/bin/bash

###############################################################################
# Popup Button Visibility Test for Enhancement #3
#
# This script opens temporary popups of all available sizes using each
# dialog tool (YAD, Zenity, KDialog) one at a time so you can manually
# test button visibility and usability.
#
# Usage:
#   ./tests/test-popup-button-visibility.sh
#
# The script will:
#   1. Test each predefined size (xsmall, small, medium, large, xlarge, max)
#   2. Test custom sizes (minimum and various percentages)
#   3. Test with each available dialog tool (YAD, Zenity, KDialog)
#   4. Open one popup at a time and wait for you to interact
#   5. Ask you to confirm if buttons were visible/clickable
#
# Safety: Uses dummy config files, does not touch real config.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
RESULTS_FILE="${SCRIPT_DIR}/tests/test-popup-button-visibility-results.txt"
> "${RESULTS_FILE}"

# Source required modules
source "${LIB_DIR}/config.sh" 2>/dev/null || { echo "Error: Could not source config.sh"; exit 1; }
source "${LIB_DIR}/resolution-detection.sh" 2>/dev/null || { echo "Error: Could not source resolution-detection.sh"; exit 1; }

# Check available dialog tools
check_available_tools() {
    local tools=()
    command -v yad >/dev/null 2>&1 && tools+=("yad")
    command -v zenity >/dev/null 2>&1 && tools+=("zenity")
    command -v kdialog >/dev/null 2>&1 && tools+=("kdialog")
    
    if [ ${#tools[@]} -eq 0 ]; then
        echo -e "${RED}Error: No dialog tools available (yad, zenity, kdialog)${NC}"
        exit 1
    fi
    
    echo "${tools[@]}"
}

# Get dimensions for a size
get_test_dimensions() {
    local size="$1"
    local mode="${2:-fixed}"
    
    # Use the actual get_popup_dimensions function
    local dims
    dims=$(get_popup_dimensions "${size}")
    echo "${dims}"
}

# Show test popup
show_test_popup() {
    local tool="$1"
    local width="$2"
    local height="$3"
    local size_name="$4"
    
    local title="Button Visibility Test - ${size_name}"
    local message="Size: ${size_name}\nDimensions: ${width}x${height}\nTool: ${tool}\n\nPlease check if the OK button is visible and clickable.\n\nClick OK when done."
    
    case "${tool}" in
        yad)
            yad --warning \
                --title="${title}" \
                --text="${message}" \
                --modal \
                --width="${width}" \
                --height="${height}" \
                --center \
                --fixed \
                --on-top \
                --button="OK:0" \
                2>/dev/null
            ;;
        zenity)
            zenity --warning \
                --title="${title}" \
                --text="${message}" \
                --modal \
                --width="${width}" \
                --height="${height}" \
                2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" \
                --sorry "${message}" \
                2>/dev/null
            ;;
    esac
}

# Test a single size with a single tool
test_size_tool() {
    local size_name="$1"
    local tool="$2"
    local mode="${3:-fixed}"
    
    echo ""
    
    # Ensure CONFIG_FILE is set for get_popup_dimensions to work
    if [ -z "${CONFIG_FILE}" ]; then
        CONFIG_FILE="${TMP_CONFIG}"
    fi
    
    local dims
    dims=$(get_test_dimensions "${size_name}" "${mode}")
    
    if [ -z "${dims}" ]; then
        echo -e "${RED}Error: Could not get dimensions for ${size_name}${NC}"
        return 1
    fi
    
    local width height
    width=$(echo "${dims}" | cut -d' ' -f1)
    height=$(echo "${dims}" | cut -d' ' -f2)
    
    echo -e "${BLUE}Testing: ${size_name} (${width}x${height}) with ${tool}${NC}"
    echo "A popup will appear. Please check if the OK button is visible and clickable."
    echo "Press Enter to show the popup..."
    read -r
    
    # Show popup
    show_test_popup "${tool}" "${width}" "${height}" "${size_name}"
    
    # Ask for result
            echo ""
            echo -e "${YELLOW}Was the OK button visible and clickable? (y/n/s=skip)${NC}"
            read -r response
            
            result=""
    case "${response}" in
        y|Y|yes|Yes|YES)
            result="PASS"
            echo -e "${GREEN}✓ Button was visible and clickable${NC}"
            ;;
        n|N|no|No|NO)
            result="FAIL"
            echo -e "${RED}✗ Button was NOT visible or NOT clickable${NC}"
            ;;
        s|S|skip|Skip|SKIP)
            result="SKIP"
            echo -e "${YELLOW}⊘ Test skipped${NC}"
            ;;
        *)
            result="UNKNOWN"
            echo -e "${YELLOW}? Unknown response, marking as unknown${NC}"
            ;;
    esac
    
    # Record result
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ${size_name} | ${tool} | ${width}x${height} | ${result}" >> "${RESULTS_FILE}"
    
    return 0
}

# Main execution
echo "=========================================="
echo "Popup Button Visibility Test"
echo "=========================================="
echo ""
echo "This script will test button visibility for all popup sizes."
echo "One popup will appear at a time for you to test."
echo ""
echo "Results will be saved to: ${RESULTS_FILE}"
echo ""

# Check available tools
available_tools=($(check_available_tools))
echo -e "${GREEN}Available dialog tools: ${available_tools[*]}${NC}"
echo ""

# Create dummy config for testing
TMP_CONFIG=$(mktemp)
export CONFIG_FILE="${TMP_CONFIG}"
cat > "${TMP_CONFIG}" << 'EOF'
POPUP_SIZE_MODE=fixed
POPUP_SIZE=medium
EOF

# Test predefined sizes
echo -e "${CYAN}━━━ Testing Predefined Sizes ━━━${NC}"
predefined_sizes=("xsmall" "small" "medium" "large" "xlarge" "max")

for size in "${predefined_sizes[@]}"; do
    for tool in "${available_tools[@]}"; do
        test_size_tool "${size}" "${tool}" "fixed"
    done
done

# Test custom sizes (minimum and percentages)
echo ""
echo -e "${CYAN}━━━ Testing Custom Sizes ━━━${NC}"

# Test minimum custom size (384x216)
for tool in "${available_tools[@]}"; do
    test_size_tool "384x216" "${tool}" "fixed"
done

# Test custom percentage sizes (need to set up display-based mode)
# First, try to get resolution for percentage calculations
resolution=$(get_display_resolution 2>/dev/null)
if [ -n "${resolution}" ]; then
    screen_width=$(echo "${resolution}" | cut -d' ' -f1)
    screen_height=$(echo "${resolution}" | cut -d' ' -f2)
    
    # Update config for display-based mode
    cat > "${TMP_CONFIG}" << EOF
POPUP_SIZE_MODE=display-based
POPUP_SIZE=custom
POPUP_SIZE_CUSTOM=15%x15%
POPUP_SIZE_CUSTOM_ABSOLUTE=384x216
EOF
    
    # Test various percentages (note: 100% removed, max is now 95%)
    percentages=("15%x15%" "20%x20%" "50%x50%" "90%x90%" "95%x95%")
    for pct in "${percentages[@]}"; do
        # Update config with this percentage
        cat > "${TMP_CONFIG}" << EOF
POPUP_SIZE_MODE=display-based
POPUP_SIZE=custom
POPUP_SIZE_CUSTOM=${pct}
EOF
        
        # Calculate expected dimensions
        pct_width=$(echo "${pct}" | cut -d'%' -f1 | cut -d'x' -f1)
        pct_height=$(echo "${pct}" | cut -d'%' -f1 | cut -d'x' -f2)
        # Clamp to 95% maximum if percentage exceeds 95%
        if [ "${pct_width}" -gt 95 ]; then
            pct_width=95
        fi
        if [ "${pct_height}" -gt 95 ]; then
            pct_height=95
        fi
        expected_width=$((screen_width * pct_width / 100))
        expected_height=$((screen_height * pct_height / 100))
        
        for tool in "${available_tools[@]}"; do
            # Use calculated dimensions directly
            echo ""
            echo -e "${BLUE}Testing: custom ${pct} (${expected_width}x${expected_height}) with ${tool}${NC}"
            echo "A popup will appear. Please check if the OK button is visible and clickable."
            echo "Press Enter to show the popup..."
            read -r
            
            show_test_popup "${tool}" "${expected_width}" "${expected_height}" "custom ${pct}"
            
            echo ""
            echo -e "${YELLOW}Was the OK button visible and clickable? (y/n/s=skip)${NC}"
            read -r response
            
            result=""
            case "${response}" in
                y|Y|yes|Yes|YES)
                    result="PASS"
                    echo -e "${GREEN}✓ Button was visible and clickable${NC}"
                    ;;
                n|N|no|No|NO)
                    result="FAIL"
                    echo -e "${RED}✗ Button was NOT visible or NOT clickable${NC}"
                    ;;
                s|S|skip|Skip|SKIP)
                    result="SKIP"
                    echo -e "${YELLOW}⊘ Test skipped${NC}"
                    ;;
                *)
                    result="UNKNOWN"
                    echo -e "${YELLOW}? Unknown response, marking as unknown${NC}"
                    ;;
            esac
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') | custom ${pct} | ${tool} | ${expected_width}x${expected_height} | ${result}" >> "${RESULTS_FILE}"
        done
    done
else
    echo -e "${YELLOW}Warning: Could not detect resolution, skipping percentage-based custom size tests${NC}"
fi

# Cleanup
rm -f "${TMP_CONFIG}"

# Summary
echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
echo ""
echo "Results saved to: ${RESULTS_FILE}"
echo ""
echo "Summary:"
echo "--------"
if [ -f "${RESULTS_FILE}" ]; then
    total=$(wc -l < "${RESULTS_FILE}")
    passed=$(grep -c "PASS" "${RESULTS_FILE}" || echo "0")
    failed=$(grep -c "FAIL" "${RESULTS_FILE}" || echo "0")
    skipped=$(grep -c "SKIP" "${RESULTS_FILE}" || echo "0")
    
    echo "Total tests: ${total}"
    echo -e "${GREEN}Passed: ${passed}${NC}"
    echo -e "${RED}Failed: ${failed}${NC}"
    echo -e "${YELLOW}Skipped: ${skipped}${NC}"
fi
echo ""
echo "Review the results file for detailed information."
