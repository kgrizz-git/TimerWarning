#!/bin/bash

###############################################################################
# Interactive Dialog Size Testing Script
#
# This script walks through each dialog used in configure.sh with the actual
# content and current dimensions, asking for feedback on each one.
#
# Usage: ./test-dialog-sizes-interactive.sh
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
echo "=========================================="
echo "Interactive Dialog Size Testing"
echo "=========================================="
echo ""
echo "Using dialog tool: ${DIALOG_TOOL}"
echo ""
echo "This script will show each dialog from configure.sh"
echo "with its current size. After each dialog, you'll be"
echo "asked if the size is appropriate."
echo ""
read -p "Press Enter to begin..."

# Store feedback
declare -A feedback

# Test counter
test_num=1

# Function to get feedback
get_feedback() {
    local dialog_name="$1"
    local current_size="$2"
    
    echo ""
    echo "Dialog: ${dialog_name}"
    echo "Current size: ${current_size}"
    echo ""
    echo "Was this dialog:"
    echo "  1) Too small (text cramped, hard to read)"
    echo "  2) Just right (comfortable to read)"
    echo "  3) Too large (excessive whitespace)"
    echo ""
    read -p "Your choice [1-3]: " choice
    
    case "${choice}" in
        1) feedback["${dialog_name}"]="TOO_SMALL:${current_size}" ;;
        2) feedback["${dialog_name}"]="JUST_RIGHT:${current_size}" ;;
        3) feedback["${dialog_name}"]="TOO_LARGE:${current_size}" ;;
        *) feedback["${dialog_name}"]="UNKNOWN:${current_size}" ;;
    esac
}

echo ""
echo "=========================================="
echo "Test ${test_num}: Welcome Dialog"
echo "=========================================="
echo "This is the first dialog shown when configure.sh starts."
echo ""
read -p "Press Enter to show dialog..."

WELCOME_TEXT="Welcome to the Sleep Warning Configuration Wizard!

This wizard will help you set up restricted hours for each day of the week.
During these hours, you will receive warning popups if you use your computer.

NAVIGATION:
• You can cancel at any time (changes won't be saved)
• You can go back to previous days to edit
• You can skip days to have no restrictions

TIME RANGE FORMATS:
• Single: '0-5' = Midnight to 4:59 AM
• Multiple: '0-5,22-23' = Two periods (midnight-4:59 AM AND 10 PM-11:59 PM)
• Overnight: '23-6' = 11 PM to 5:59 AM (spans midnight to next day)

IMPORTANT - Overnight Ranges:
If you enter '23-6' on Monday, it means:
  Monday 11:00 PM → Tuesday 5:59 AM

This spans across midnight to the next day. If you also set Tuesday 0-5,
both will cover Tuesday midnight-4:59 AM (redundant but harmless).

Examples:
• '0-5' = Midnight to 4:59 AM (same day)
• '22-23' = 10:00 PM to 11:59 PM (same day)
• '23-6' = 11:00 PM to 5:59 AM (overnight, spans to next day)
• '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM

Let's get started!"

show_info_dialog "Sleep Warning Configuration" "${WELCOME_TEXT}" 800 400
get_feedback "Welcome Dialog" "800x400"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Main Menu (Multi-Column)"
echo "=========================================="
echo "This is the main navigation menu."
echo ""
read -p "Press Enter to show dialog..."

show_multi_column_list_dialog \
    "Sleep Warning Configuration" \
    "Select a section to configure:" \
    700 \
    400 \
    1 \
    "Option" \
    "Description" \
    "1" "Timer Settings (Check Interval: 5 min)" \
    "2" "Window Behavior (Size: medium, Position: center, Min Display: 0s, Immovable: Off)" \
    "3" "Weekdays Configuration (configured)" \
    "4" "Weekends Configuration (configured)" \
    "5" "Visual Day/Time Grid" \
    "6" "Review and Save"

get_feedback "Main Menu" "700x400"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Popup Size Selection"
echo "=========================================="
echo "Dialog for selecting popup window size."
echo ""
read -p "Press Enter to show dialog..."

show_list_dialog \
    "Sleep Warning Configuration" \
    "Select popup size (current: medium):" \
    500 \
    300 \
    "small" "medium" "large"

get_feedback "Popup Size Selection" "500x300"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Popup Position Selection"
echo "=========================================="
echo "Dialog for selecting popup window position."
echo ""
read -p "Press Enter to show dialog..."

show_list_dialog \
    "Sleep Warning Configuration" \
    "Select popup position on screen:\n(Current: center)" \
    500 \
    300 \
    "center" "top-left"

get_feedback "Popup Position Selection" "500x300"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Immovable Setting"
echo "=========================================="
echo "Dialog for configuring immovable window setting."
echo ""
read -p "Press Enter to show dialog..."

show_list_dialog \
    "Sleep Warning Configuration" \
    "Prevent popup window from being moved during minimum display time?\n(Current: false)" \
    600 \
    300 \
    "true" "false"

get_feedback "Immovable Setting" "600x300"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Help Dialog"
echo "=========================================="
echo "Dialog shown when user clicks Help button."
echo ""
read -p "Press Enter to show dialog..."

HELP_TEXT="Configuration Help

TIME RANGE FORMAT:
• Enter hours in 24-hour format (0-23)
• Use START-END format (e.g., 0-5 for midnight to 4:59 AM)
• Multiple ranges: separate with commas (e.g., 0-5,22-23)
• Overnight ranges: START > END (e.g., 23-6 for 11 PM to 5:59 AM)

EXAMPLES:
• '0-5' = Midnight to 4:59 AM (same day)
• '22-23' = 10:00 PM to 11:59 PM (same day)
• '23-6' = 11:00 PM to 5:59 AM (overnight, spans to next day)
• '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM"

show_info_dialog \
    "Configuration Help" \
    "${HELP_TEXT}" \
    800 \
    500

get_feedback "Help Dialog" "800x500"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Visual Day/Time Grid"
echo "=========================================="
echo "Dialog showing the visual grid of configured days."
echo ""
read -p "Press Enter to show dialog..."

show_multi_column_list_dialog \
    "Visual Day/Time Grid" \
    "Select a day to edit its restricted hours:" \
    800 \
    450 \
    1 \
    "Day" \
    "Time Ranges" \
    "Sunday" "0-5, 22-23" \
    "Monday" "0-5" \
    "Tuesday" "0-5" \
    "Wednesday" "0-5" \
    "Thursday" "0-5" \
    "Friday" "0-5" \
    "Saturday" "No restrictions" \
    "[Back]" "Return to Main Menu"

get_feedback "Visual Day/Time Grid" "800x450"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Cancel Menu"
echo "=========================================="
echo "Dialog shown when user cancels or leaves a day empty."
echo ""
read -p "Press Enter to show dialog..."

show_list_dialog \
    "What would you like to do?" \
    "You cancelled or left Monday empty. What would you like to do?" \
    500 \
    300 \
    "Skip this day (no restrictions)" \
    "Try again" \
    "Go back to previous day"

get_feedback "Cancel Menu" "500x300"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Invalid Format Error"
echo "=========================================="
echo "Error dialog for invalid time format."
echo ""
read -p "Press Enter to show dialog..."

show_info_dialog \
    "Invalid Format" \
    "Invalid format. Use: START-END or START-END,START-END\n\nExamples:\n• 0-5 (midnight to 4:59 AM)\n• 0-5,22-23 (two periods)\n• 23-6 (11 PM to 5:59 AM, overnight)" \
    500 \
    200

get_feedback "Invalid Format Error" "500x200"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Invalid Hour Error"
echo "=========================================="
echo "Error dialog for invalid hour values."
echo ""
read -p "Press Enter to show dialog..."

show_info_dialog \
    "Invalid Hour" \
    "Invalid hour. Please enter a number between 0 and 23." \
    500 \
    200

get_feedback "Invalid Hour Error" "500x200"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Success Dialog"
echo "=========================================="
echo "Dialog shown after successful configuration save."
echo ""
read -p "Press Enter to show dialog..."

SUCCESS_TEXT="Configuration saved successfully!

The sleep warning system is now configured with your settings.

Check Interval: Every 5 minute(s)
Popup Size: medium
Popup Position: center

Your restricted hours have been saved.

You can run this wizard again anytime to change your settings."

show_info_dialog \
    "Sleep Warning Configuration" \
    "${SUCCESS_TEXT}" \
    600 \
    300

get_feedback "Success Dialog" "600x300"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: 24/7 Restriction Error"
echo "=========================================="
echo "Error dialog when user configures 24/7 restrictions."
echo ""
read -p "Press Enter to show dialog..."

ERROR_24_7="You have configured restrictions for all 24 hours, 7 days a week.

This would effectively lock you out of your computer.

Please modify your settings to leave at least some unrestricted time.

Configuration cannot be saved until you reduce the restriction level."

show_info_dialog \
    "ERROR: 24/7 Restrictions Detected" \
    "${ERROR_24_7}" \
    700 \
    400

get_feedback "24/7 Restriction Error" "700x400"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: High Restriction Warning"
echo "=========================================="
echo "Warning dialog for high restriction levels (>23 hours/day)."
echo ""
read -p "Press Enter to show dialog..."

WARNING_HIGH="You have configured restrictions for more than 23 hours per day.

This leaves very little unrestricted time and may effectively lock you out.

Safety measures will be applied:
• Config locking features will be disabled
• Popup size will be limited to small/medium

Do you want to save this configuration anyway?"

show_question_dialog \
    "Warning: Very High Restriction Level" \
    "${WARNING_HIGH}" \
    "Yes, Save Anyway" \
    "No, Modify Settings" \
    700 \
    400

get_feedback "High Restriction Warning (question)" "700x400"
((test_num++))

echo ""
echo "=========================================="
echo "Test ${test_num}: Configuration Summary"
echo "=========================================="
echo "Summary dialog before saving (question dialog)."
echo ""
read -p "Press Enter to show dialog..."

SUMMARY="Configuration Summary:

Check Interval: Every 5 minute(s)
Popup Size: medium
Popup Position: center
Minimum Display Time: Disabled
Prevent Window Movement: Disabled

Restricted Hours:
• Sunday: No restrictions
• Monday: Midnight-4:59 AM
• Tuesday: Midnight-4:59 AM
• Wednesday: Midnight-4:59 AM
• Thursday: Midnight-4:59 AM
• Friday: Midnight-4:59 AM
• Saturday: No restrictions

Save this configuration?"

show_question_dialog \
    "Sleep Warning Configuration" \
    "${SUMMARY}" \
    "Yes, Save" \
    "Cancel" \
    700 \
    500

get_feedback "Configuration Summary (question)" "700x500"
((test_num++))

# Show summary of feedback
echo ""
echo ""
echo "=========================================="
echo "FEEDBACK SUMMARY"
echo "=========================================="
echo ""

for dialog_name in "${!feedback[@]}"; do
    IFS=':' read -r status size <<< "${feedback[${dialog_name}]}"
    case "${status}" in
        TOO_SMALL) status_text="❌ TOO SMALL" ;;
        JUST_RIGHT) status_text="✅ JUST RIGHT" ;;
        TOO_LARGE) status_text="⚠️  TOO LARGE" ;;
        *) status_text="❓ UNKNOWN" ;;
    esac
    printf "%-35s %s (current: %s)\n" "${dialog_name}" "${status_text}" "${size}"
done

echo ""
echo "=========================================="
echo ""
echo "Test complete! Review the feedback above."
echo ""
echo "Dialogs marked as TOO_SMALL or TOO_LARGE should be adjusted."
echo "Note: Question dialogs (summary, high restriction warning) are"
echo "currently auto-sized and may need size parameters added."
echo ""
