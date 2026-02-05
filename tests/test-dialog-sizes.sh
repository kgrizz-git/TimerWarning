#!/bin/bash

###############################################################################
# Dialog Size Testing Script
#
# This script helps you test different dialog sizes to find optimal dimensions
# for each type of dialog used in the configuration wizard.
#
# Usage: ./test-dialog-sizes.sh
###############################################################################

# Source required modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/configure-core.sh" || exit 1
source "${LIB_DIR}/desktop-environment.sh" || exit 1
source "${LIB_DIR}/configure-dialogs.sh" || exit 1

# Check if GUI is available
if ! has_dialog_tool; then
    echo "Error: No dialog tool available (yad, zenity, or kdialog required)"
    exit 1
fi

DIALOG_TOOL=$(get_dialog_tool)
echo "Using dialog tool: ${DIALOG_TOOL}"
echo ""

# Test sizes array: width height description
declare -A test_sizes=(
    ["small"]="500 300"
    ["medium"]="700 500"
    ["large"]="900 700"
)

# Sample texts for different dialog types
WELCOME_TEXT="Welcome to the Sleep Warning Configuration Wizard!

This wizard will help you set up restricted hours for each day of the week.
During these hours, you will receive warning popups if you use your computer.

NAVIGATION:
- You can cancel at any time (changes won't be saved)
- You can go back to previous days to edit
- You can skip days to have no restrictions

TIME RANGE FORMATS:
- Single: '0-5' = Midnight to 4:59 AM
- Multiple: '0-5,22-23' = Two periods (midnight-4:59 AM AND 10 PM-11:59 PM)
- Overnight: '23-6' = 11 PM to 5:59 AM (spans midnight to next day)

IMPORTANT - Overnight Ranges:
If you enter '23-6' on Monday, it means:
  Monday 11:00 PM → Tuesday 5:59 AM

This spans across midnight to the next day. If you also set Tuesday 0-5,
both will cover Tuesday midnight-4:59 AM (redundant but harmless).

Examples:
- '0-5' = Midnight to 4:59 AM (same day)
- '22-23' = 10:00 PM to 11:59 PM (same day)
- '23-6' = 11:00 PM to 5:59 AM (overnight, spans to next day)
- '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM

Let's get started!"

SUCCESS_TEXT="Configuration saved successfully!

The sleep warning system is now configured with your settings.

Check Interval: Every 5 minute(s)
Popup Size: medium
Popup Position: center

Your restricted hours have been saved.

You can run this wizard again anytime to change your settings."

ERROR_TEXT="ERROR: 24/7 Restrictions Detected

You have configured restrictions for all 24 hours, 7 days a week.

This would effectively lock you out of your computer.

Please modify your settings to leave at least some unrestricted time.

Configuration cannot be saved until you reduce the restriction level."

HELP_TEXT="Configuration Help

TIME RANGE FORMAT:
- Enter hours in 24-hour format (0-23)
- Use START-END format (e.g., 0-5 for midnight to 4:59 AM)
- Multiple ranges: separate with commas (e.g., 0-5,22-23)
- Overnight ranges: START > END (e.g., 23-6 for 11 PM to 5:59 AM)

EXAMPLES:
- '0-5' = Midnight to 4:59 AM (same day)
- '22-23' = 10:00 PM to 11:59 PM (same day)
- '23-6' = 11:00 PM to 5:59 AM (overnight, spans to next day)
- '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM"

# Test function for info dialogs
test_info_dialog() {
    local size_name="$1"
    local text="$2"
    local title="$3"
    
    read width height <<< "${test_sizes[${size_name}]}"
    
    echo "Testing: ${title} - ${size_name} (${width}x${height})"
    show_info_dialog "${title}" "${text}" "${width}" "${height}"
}

# Test function for text-info dialogs
test_text_info_dialog() {
    local size_name="$1"
    local text="$2"
    local title="$3"
    
    read width height <<< "${test_sizes[${size_name}]}"
    
    echo "Testing: ${title} - ${size_name} (${width}x${height})"
    show_text_info_dialog "${title}" "${text}" "${width}" "${height}"
}

# Test function for list dialogs
test_list_dialog() {
    local size_name="$1"
    local title="$2"
    local prompt="$3"
    shift 3
    local items=("$@")
    
    read width height <<< "${test_sizes[${size_name}]}"
    
    echo "Testing: ${title} - ${size_name} (${width}x${height})"
    show_list_dialog "${title}" "${prompt}" "${width}" "${height}" "${items[@]}"
}

# Test function for multi-column list dialogs
test_multi_column_dialog() {
    local size_name="$1"
    
    read width height <<< "${test_sizes[${size_name}]}"
    
    echo "Testing: Main Menu - ${size_name} (${width}x${height})"
    show_multi_column_list_dialog \
        "Sleep Warning Configuration" \
        "Select a section to configure:" \
        "${width}" \
        "${height}" \
        1 \
        "Option" \
        "Description" \
        "1" "Timer Settings (Check Interval: 5 min)" \
        "2" "Window Behavior (Size: medium, Position: center)" \
        "3" "Weekdays Configuration (configured)" \
        "4" "Weekends Configuration (configured)" \
        "5" "Visual Day/Time Grid" \
        "6" "Review and Save"
}

# Main test menu
while true; do
    echo ""
    echo "=========================================="
    echo "Dialog Size Testing Menu"
    echo "=========================================="
    echo ""
    echo "1) Test Welcome Dialog (info)"
    echo "2) Test Success Dialog (info)"
    echo "3) Test Error Dialog (info)"
    echo "4) Test Help Dialog (text-info)"
    echo "5) Test List Dialog (popup size selection)"
    echo "6) Test Multi-Column Dialog (main menu)"
    echo "7) Test All Dialogs in Sequence"
    echo "8) Exit"
    echo ""
    read -p "Select test [1-8]: " choice
    
    case "${choice}" in
        1)
            echo ""
            echo "Testing Welcome Dialog..."
            for size in small medium large; do
                test_info_dialog "${size}" "${WELCOME_TEXT}" "Welcome - ${size}"
            done
            ;;
        2)
            echo ""
            echo "Testing Success Dialog..."
            for size in small medium large; do
                test_info_dialog "${size}" "${SUCCESS_TEXT}" "Success - ${size}"
            done
            ;;
        3)
            echo ""
            echo "Testing Error Dialog..."
            for size in small medium large; do
                test_info_dialog "${size}" "${ERROR_TEXT}" "Error - ${size}"
            done
            ;;
        4)
            echo ""
            echo "Testing Help Dialog..."
            for size in small medium large; do
                test_text_info_dialog "${size}" "${HELP_TEXT}" "Help - ${size}"
            done
            ;;
        5)
            echo ""
            echo "Testing List Dialog..."
            for size in small medium large; do
                test_list_dialog "${size}" "Popup Size - ${size}" "Select popup size:" "small" "medium" "large"
            done
            ;;
        6)
            echo ""
            echo "Testing Multi-Column Dialog..."
            for size in small medium large; do
                test_multi_column_dialog "${size}"
            done
            ;;
        7)
            echo ""
            echo "Testing all dialogs in sequence..."
            echo "Press OK/Close on each dialog to continue to the next..."
            
            # Welcome
            test_info_dialog "medium" "${WELCOME_TEXT}" "1. Welcome Dialog"
            
            # Main menu
            test_multi_column_dialog "medium"
            
            # List selection
            test_list_dialog "medium" "2. List Selection" "Select an option:" "Option 1" "Option 2" "Option 3"
            
            # Help
            test_text_info_dialog "medium" "${HELP_TEXT}" "3. Help Dialog"
            
            # Success
            test_info_dialog "medium" "${SUCCESS_TEXT}" "4. Success Dialog"
            
            # Error
            test_info_dialog "medium" "${ERROR_TEXT}" "5. Error Dialog"
            
            echo "Test sequence complete!"
            ;;
        8)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please select 1-8."
            ;;
    esac
done
