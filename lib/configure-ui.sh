#!/bin/bash

###############################################################################
# Sleep Warning System - User Interface Dialogs Module
#
# This module provides basic UI dialog functions for user interaction in both
# GUI (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - confirm_cancel()        - Confirm cancellation dialog
# - confirm_skip_day()      - Confirm skipping a day
# - show_help_dialog()      - Display configuration help
# - show_welcome()          - Show welcome message
# - show_success()          - Show success message
# - ask_weekday_together()  - Ask if configuring weekdays together
# - ask_weekend_together()  - Ask if configuring weekends together
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
###############################################################################

# Confirm cancellation with user
confirm_cancel() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Cancel Configuration?" \
            "Are you sure you want to cancel?\n\nAll unsaved changes will be lost." \
            "Yes, Cancel" \
            "No, Continue"
        return $?
    else
        echo ""
        read -p "Cancel configuration? All unsaved changes will be lost. [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Confirm skipping a day
confirm_skip_day() {
    local day_name="$1"
    local use_gui="$2"
    
    # Determine if this is multiple days (weekdays or weekends)
    local is_multiple=false
    local skip_message=""
    if [[ "${day_name}" == *"Weekdays"* ]] || [[ "${day_name}" == *"Monday-Friday"* ]]; then
        is_multiple=true
        skip_message="Are you sure you want to skip all weekdays (Monday-Friday)?\n\nNo restrictions will be set for any weekday."
    elif [[ "${day_name}" == *"Weekends"* ]] || [[ "${day_name}" == *"Saturday and Sunday"* ]]; then
        is_multiple=true
        skip_message="Are you sure you want to skip both weekend days (Saturday and Sunday)?\n\nNo restrictions will be set for either weekend day."
    else
        skip_message="Are you sure you want to skip ${day_name}?\n\nNo restrictions will be set for this day."
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Skip ${day_name}?" \
            "${skip_message}" \
            "Yes, Skip" \
            "No, Configure"
        return $?
    else
        echo "" >&2
        if [ "${is_multiple}" = "true" ]; then
            read -p "Skip ${day_name}? No restrictions will be set. [y/N]: " answer
        else
            read -p "Skip ${day_name}? No restrictions will be set for this day. [y/N]: " answer
        fi
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Show help dialog
show_help_dialog() {
    local use_gui="$1"
    
    local help_text="TIME RANGE CONFIGURATION HELP

SINGLE RANGE:
  Format: START-END
  Example: 0-5
  Meaning: Midnight (00:00) to 4:59 AM on the same day

MULTIPLE RANGES:
  Format: START-END,START-END
  Example: 0-5,22-23
  Meaning: Two separate periods:
    • Midnight to 4:59 AM
    • 10:00 PM to 11:59 PM

OVERNIGHT RANGES (spans midnight):
  Format: START-END (where START > END)
  Example: 23-6
  Meaning: 11:00 PM on the named day to 5:59 AM on the NEXT day
  Example: Monday 23-6 = Monday 11 PM → Tuesday 5:59 AM

OVERLAPPING RANGES:
  If you set Monday 23-5 and Tuesday 0-5:
  • Both cover Tuesday midnight to 4:59 AM
  • Only one warning will be shown (not duplicated)
  • This is harmless but redundant

NAVIGATION:
  • Cancel: Exit without saving (available at any time)
  • Back: Return to previous day's configuration
  • Skip: Skip current day (no restrictions for that day)

EXAMPLES:
  • '0-5' = Midnight to 4:59 AM
  • '22-23' = 10:00 PM to 11:59 PM  
  • '23-6' = 11:00 PM to 5:59 AM (overnight)
  • '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_text_info_dialog \
            "Configuration Help" \
            "${help_text}" \
            600 \
            500
    else
        echo ""
        echo "=== CONFIGURATION HELP ==="
        echo "${help_text}"
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Show welcome message
show_welcome() {
    local use_gui="$1"
    
    local message="Welcome to the Sleep Warning Configuration Wizard!

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
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog \
            "Sleep Warning Configuration" \
            "${message}" \
            500 \
            200
    else
        echo "${message}"
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Ask if user wants to configure weekdays together
ask_weekday_together() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Sleep Warning Configuration" \
            "Would you like to use the same restricted hours for all weekdays (Monday-Friday)?" \
            "Yes" \
            "No"
        return $?
    else
        read -p "Use same hours for all weekdays (Monday-Friday)? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Ask if user wants to configure weekends together
ask_weekend_together() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Sleep Warning Configuration" \
            "Would you like to use the same restricted hours for both weekend days (Saturday and Sunday)?" \
            "Yes" \
            "No"
        return $?
    else
        read -p "Use same hours for both weekend days (Saturday and Sunday)? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Show success message
show_success() {
    local use_gui="$1"
    local check_interval="$2"
    
    local message="Configuration saved successfully!

Your settings have been saved to:
${CONFIG_FILE}

Check interval: Every ${check_interval} minute(s)

All settings (restricted hours, popup size, position, etc.) will take effect on the next check.
If the timer was already running, it has been automatically restarted with the new interval.
No manual action is required - everything is ready to use!

You can run this wizard again anytime to change your settings."

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog \
            "Sleep Warning Configuration" \
            "${message}" \
            500 \
            200
    else
        echo ""
        echo "${message}"
    fi
}
