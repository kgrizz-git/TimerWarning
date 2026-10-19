#!/bin/bash

###############################################################################
# Sleep Warning System - Manual Uninstallation Guide
#
# This script provides step-by-step instructions for manually uninstalling
# the Sleep Warning System. This guide is always accessible, even during
# restricted hours when uninstall.sh may be blocked.
#
# This script is a safety mechanism for Enhancement #26 (Prevent uninstall.sh
# Execution During Restricted Hours). It provides users with instructions
# for manual uninstallation when automated uninstall is blocked.
#
# Requirements:
# - bash
# - systemd (for user services)
#
# Usage:
#   ./manual-uninstall-guide.sh              # Show instructions
#   manual-uninstall-guide                   # After installation
#
# Output:
# - Displays step-by-step manual uninstallation instructions
# - Provides copy-paste ready commands
# - Lists all files and directories to remove
#
# Note: This script now requires verification before showing instructions:
# 1. Initial confirmation that user wants to know how to uninstall
# 2. Confirmation phrase: "I confirm that I really want to know how to uninstall"
# 3. 5 arithmetic questions
###############################################################################

# Script configuration
INSTALL_DIR="${HOME}/.local/bin"
LIB_DIR="${HOME}/.local/lib/sleep-warning"
CONFIG_DIR="${HOME}/.config/sleep-warning"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Determine script directory and library path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"

# Determine which library directory to use for sourcing (project dir if available, otherwise installed location)
SOURCE_LIB_DIR="${LIB_DIR}"
if [ -d "${SCRIPT_LIB_DIR}" ]; then
    # Running from project directory - use project lib for sourcing
    SOURCE_LIB_DIR="${SCRIPT_LIB_DIR}"
fi

# Source library modules if available (for verification functions)
# These are sourced with error suppression to allow guide even if some modules are missing
# Note: Must source in dependency order for get_dialog_tool() to work correctly
if [ -f "${SOURCE_LIB_DIR}/config.sh" ]; then
    source "${SOURCE_LIB_DIR}/config.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/display-detection.sh" ]; then
    source "${SOURCE_LIB_DIR}/display-detection.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/desktop-environment.sh" ]; then
    source "${SOURCE_LIB_DIR}/desktop-environment.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/configure-core.sh" ]; then
    source "${SOURCE_LIB_DIR}/configure-core.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/configure-dialogs.sh" ]; then
    source "${SOURCE_LIB_DIR}/configure-dialogs.sh" 2>/dev/null || true
fi

if [ -f "${SOURCE_LIB_DIR}/uninstall-verification.sh" ]; then
    source "${SOURCE_LIB_DIR}/uninstall-verification.sh" 2>/dev/null || true
fi

# Colors for output (with fallback for non-color terminals)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Function to print colored messages
print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

print_step() {
    echo -e "${GREEN}→${NC} $1"
}

print_command() {
    echo -e "  ${YELLOW}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Get the confirmation phrase for manual uninstall guide
get_manual_uninstall_confirmation_phrase() {
    echo "I confirm that I really want to know how to uninstall"
}

# Verify that user input matches the confirmation phrase for manual uninstall guide
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - max_attempts (optional, default: 3)
# Returns:
#   0 - Phrase matches
#   1 - Phrase doesn't match (after max attempts)
#   2 - User cancelled
verify_manual_uninstall_confirmation_phrase() {
    local use_gui="$1"
    local max_attempts="${2:-3}"
    local phrase
    phrase=$(get_manual_uninstall_confirmation_phrase)
    
    local attempt=1
    while [ ${attempt} -le ${max_attempts} ]; do
        local user_input=""
        
        if [ "${use_gui}" = "true" ] && has_dialog_tool; then
            # GUI mode
            local dialog_text
            if [ ${attempt} -eq 1 ]; then
                dialog_text="Manual Uninstall Guide Verification - Step 1 of 2\n\nYou must type the following phrase exactly:\n\n\"${phrase}\"\n\nThis confirms you really want to see the uninstall instructions."
            else
                dialog_text="Manual Uninstall Guide Verification - Step 1 of 2\n\nAttempt ${attempt} of ${max_attempts}\n\nType the following phrase exactly:\n\n\"${phrase}\""
            fi
            
            user_input=$(show_entry_dialog \
                "Manual Uninstall Guide - Confirmation Phrase" \
                "${dialog_text}" \
                "")
            local exit_code=$?
            
            if [ ${exit_code} -ne 0 ] || [ -z "${user_input}" ]; then
                # User cancelled
                return 2
            fi
        else
            # Text mode
            echo "" >&2
            if [ ${attempt} -eq 1 ]; then
                echo "Manual Uninstall Guide Verification - Step 1 of 2: Confirmation Phrase" >&2
                echo "You must type the following phrase exactly:" >&2
                echo "" >&2
                echo "  \"${phrase}\"" >&2
                echo "" >&2
                echo "This confirms you really want to see the uninstall instructions." >&2
            else
                echo "Attempt ${attempt} of ${max_attempts}" >&2
                echo "Type the following phrase exactly:" >&2
                echo "" >&2
                echo "  \"${phrase}\"" >&2
            fi
            echo "" >&2
            read -p "Enter phrase: " user_input
            if [ -z "${user_input}" ]; then
                # User cancelled (empty input)
                return 2
            fi
        fi
        
        # Compare phrases (case-insensitive)
        local phrase_lower user_input_lower
        phrase_lower=$(echo "${phrase}" | tr '[:upper:]' '[:lower:]')
        user_input_lower=$(echo "${user_input}" | tr '[:upper:]' '[:lower:]')
        
        if [ "${phrase_lower}" = "${user_input_lower}" ]; then
            # Phrase matches
            return 0
        else
            # Phrase doesn't match
            if [ ${attempt} -lt ${max_attempts} ]; then
                local error_msg="Phrase does not match. Please try again."
                if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                    show_info_dialog "Error" "${error_msg}" 400 150
                else
                    echo "Error: ${error_msg}" >&2
                fi
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    # Max attempts exceeded
    return 1
}

# Ask arithmetic questions for manual uninstall guide verification
# Parameters:
#   $1 - use_gui (true/false)
# Returns:
#   0 - All questions answered correctly
#   1 - Verification failed
#   2 - User cancelled
ask_manual_uninstall_arithmetic_questions() {
    local use_gui="$1"
    
    # Check if generate_algebra_question and validate_answer functions are available
    if ! type generate_algebra_question >/dev/null 2>&1 || ! type validate_answer >/dev/null 2>&1; then
        # Functions not available - skip arithmetic questions
        if [ "${use_gui}" = "true" ] && has_dialog_tool; then
            show_info_dialog "Note" "Arithmetic verification functions not available. Skipping arithmetic questions." 500 200
        else
            echo "Note: Arithmetic verification functions not available. Skipping arithmetic questions." >&2
        fi
        return 0
    fi
    
    # Users get a total of 3 wrong answers across all questions
    local total_questions=5
    local max_wrong_answers=3
    local wrong_answers_count=0
    local question_num=1
    
    while [ ${question_num} -le ${total_questions} ]; do
        # Generate question
        local question_data
        question_data=$(generate_algebra_question)
        local question_text correct_answer
        question_text=$(echo "${question_data}" | cut -d'|' -f1)
        correct_answer=$(echo "${question_data}" | cut -d'|' -f2)
        
        local answered_correctly=false
        
        while [ "${answered_correctly}" = "false" ]; do
            local user_answer=""
            local remaining_wrong=$((max_wrong_answers - wrong_answers_count))
            
            if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                # GUI mode
                local dialog_text
                dialog_text="Question ${question_num} of ${total_questions}\n\n${question_text}"
                if [ ${wrong_answers_count} -gt 0 ]; then
                    dialog_text="${dialog_text}\n\n⚠ Wrong answers used: ${wrong_answers_count} of ${max_wrong_answers}\nRemaining wrong answers allowed: ${remaining_wrong}"
                else
                    dialog_text="${dialog_text}\n\nYou have ${max_wrong_answers} wrong answers allowed across all ${total_questions} questions."
                fi
                
                user_answer=$(show_entry_dialog \
                    "Manual Uninstall Guide - Arithmetic Question" \
                    "${dialog_text}" \
                    "")
                local exit_code=$?
                
                if [ ${exit_code} -ne 0 ] || [ -z "${user_answer}" ]; then
                    # User cancelled
                    return 2
                fi
            else
                # Text mode
                echo "" >&2
                echo "Question ${question_num} of ${total_questions}" >&2
                if [ ${wrong_answers_count} -gt 0 ]; then
                    echo "⚠ Wrong answers used: ${wrong_answers_count} of ${max_wrong_answers}" >&2
                    echo "Remaining wrong answers allowed: ${remaining_wrong}" >&2
                else
                    echo "You have ${max_wrong_answers} wrong answers allowed across all ${total_questions} questions." >&2
                fi
                echo "" >&2
                echo "${question_text}" >&2
                echo "" >&2
                read -p "Enter your answer (integer): " user_answer
                if [ -z "${user_answer}" ]; then
                    # User cancelled (empty input)
                    return 2
                fi
            fi
            
            # Validate answer
            if validate_answer "${user_answer}" "${correct_answer}"; then
                # Answer is correct
                answered_correctly=true
                if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                    show_info_dialog "Correct" "Answer is correct!" 300 150
                else
                    echo "Correct!" >&2
                fi
            else
                # Answer is incorrect
                wrong_answers_count=$((wrong_answers_count + 1))
                remaining_wrong=$((max_wrong_answers - wrong_answers_count))
                
                if [ ${wrong_answers_count} -ge ${max_wrong_answers} ]; then
                    # Max wrong answers exceeded
                    local error_msg="Incorrect answer. You have used all ${max_wrong_answers} wrong answers allowed.\n\nThe correct answer was ${correct_answer}.\n\nVerification failed."
                    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                        show_info_dialog "Verification Failed" "${error_msg}" 500 250
                    else
                        echo "Error: Incorrect answer. You have used all ${max_wrong_answers} wrong answers allowed." >&2
                        echo "The correct answer was ${correct_answer}. Verification failed." >&2
                    fi
                    return 1
                else
                    # Still have wrong answers remaining
                    local error_msg="Incorrect answer. The correct answer is ${correct_answer}.\n\nWrong answers used: ${wrong_answers_count} of ${max_wrong_answers}\nRemaining wrong answers allowed: ${remaining_wrong}\n\nPlease try again."
                    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                        show_info_dialog "Incorrect" "${error_msg}" 500 250
                    else
                        echo "Incorrect. The correct answer is ${correct_answer}." >&2
                        echo "Wrong answers used: ${wrong_answers_count} of ${max_wrong_answers}" >&2
                        echo "Remaining wrong answers allowed: ${remaining_wrong}" >&2
                    fi
                fi
            fi
        done
        
        question_num=$((question_num + 1))
    done
    
    # All questions answered correctly
    local success_msg="Verification successful! All questions answered correctly. Showing uninstall instructions."
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog "Verification Successful" "${success_msg}" 500 200
    else
        echo "" >&2
        echo "${success_msg}" >&2
    fi
    
    return 0
}

# Verify user before showing instructions
# Parameters:
#   $1 - use_gui (true/false)
# Returns:
#   0 - Verification passed
#   1 - Verification failed
#   2 - User cancelled
verify_before_showing_instructions() {
    local use_gui="$1"
    
    # Step 0: Initial confirmation
    local initial_msg
    initial_msg="This guide will show you how to manually uninstall the Sleep Warning System.\n\n"
    initial_msg="${initial_msg}To proceed, you will need to:\n"
    initial_msg="${initial_msg}1. Type a confirmation phrase\n"
    initial_msg="${initial_msg}2. Answer 5 arithmetic questions correctly\n"
    initial_msg="${initial_msg}   (You are allowed 3 wrong answers total across all questions)\n\n"
    initial_msg="${initial_msg}Are you sure you want to know how to uninstall?"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        if ! show_question_dialog \
            "Manual Uninstall Guide" \
            "${initial_msg}" \
            "Yes" \
            "No" \
            600 \
            400; then
            # User cancelled
            return 2
        fi
    else
        # Text mode
        echo "" >&2
        echo "Manual Uninstall Guide" >&2
        echo "======================" >&2
        echo "" >&2
        echo "${initial_msg}" | sed 's/\\n/\n/g' >&2
        echo "" >&2
        read -p "Enter 'Yes' to proceed or anything else to cancel: " proceed_choice
        if [ "${proceed_choice}" != "Yes" ] && [ "${proceed_choice}" != "yes" ] && [ "${proceed_choice}" != "YES" ] && [ "${proceed_choice}" != "y" ] && [ "${proceed_choice}" != "Y" ]; then
            # User cancelled
            return 2
        fi
    fi
    
    # Step 1: Confirmation phrase
    verify_manual_uninstall_confirmation_phrase "${use_gui}" 3
    local exit_code=$?
    if [ "${exit_code}" -ne 0 ]; then
        if [ ${exit_code} -eq 2 ]; then
            # User cancelled
            return 2
        else
            # Verification failed
            local error_msg="Confirmation phrase verification failed. Access to uninstall guide cancelled."
            if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                show_info_dialog "Verification Failed" "${error_msg}" 500 200
            else
                echo "Error: ${error_msg}" >&2
            fi
            return 1
        fi
    fi
    
    # Step 2: Arithmetic questions (5 questions)
    ask_manual_uninstall_arithmetic_questions "${use_gui}"
    local exit_code=$?
    if [ "${exit_code}" -ne 0 ]; then
        if [ ${exit_code} -eq 2 ]; then
            # User cancelled
            return 2
        else
            # Verification failed
            local error_msg="Arithmetic verification failed. Access to uninstall guide cancelled."
            if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                show_info_dialog "Verification Failed" "${error_msg}" 500 200
            else
                echo "Error: ${error_msg}" >&2
            fi
            return 1
        fi
    fi
    
    return 0
}

# Function to show a single step in GUI mode
show_gui_step() {
    local step_num="$1"
    local step_title="$2"
    local step_instructions="$3"
    local commands="$4"
    
    local tool
    tool=$(get_dialog_tool)
    
    local full_text
    full_text="STEP ${step_num}: ${step_title}\n\n${step_instructions}"
    if [ -n "${commands}" ]; then
        full_text="${full_text}\n\nCommands:\n${commands}"
    fi

    # Ensure dialog text is safe under non-UTF locales (GTK tools can crash on Unicode).
    if type dialog_safe_text >/dev/null 2>&1; then
        full_text="$(dialog_safe_text "${full_text}")"
    fi
    local safe_title="Manual Uninstall Guide - Step ${step_num}"
    if type dialog_safe_text >/dev/null 2>&1; then
        safe_title="$(dialog_safe_text "${safe_title}")"
    fi
    
    case "${tool}" in
        yad)
            # Show one step at a time (prevents easy copying of all steps at once)
            echo -e "${full_text}" | yad --text-info \
                --title="${safe_title}" \
                --width=700 \
                --height=400 \
                --button="Next Step:0" \
                --button="Close:1" \
                --wrap \
                2>/dev/null
            local exit_code=$?
            ;;
        zenity)
            # Zenity doesn't support preventing copying, but we show one step at a time
            echo -e "${full_text}" | zenity --text-info \
                --title="${safe_title}" \
                --width=700 \
                --height=400 \
                --font="monospace" \
                2>/dev/null
            local exit_code=$?
            ;;
        kdialog)
            echo -e "${full_text}" | kdialog --textbox /dev/stdin 700 400 2>/dev/null
            local exit_code=$?
            ;;
        *)
            return 1
            ;;
    esac
    
    return ${exit_code}
}

# Function to show instructions in GUI mode (one step at a time)
show_gui_instructions() {
    local tool
    tool=$(get_dialog_tool)
    
    # Step 1: Stop and Disable Timer
    local step1_instructions="Stop and disable the systemd timer that runs the warning system."
    local step1_commands="systemctl --user stop sleep-warning.timer\nsystemctl --user disable sleep-warning.timer"
    if ! show_gui_step "1" "Stop and Disable Timer" "${step1_instructions}" "${step1_commands}"; then
        return 1
    fi
    
    # Step 2: Remove Systemd Files
    local step2_instructions="Remove the systemd service and timer files."
    local step2_commands="rm -f ${SYSTEMD_USER_DIR}/sleep-warning.service\nrm -f ${SYSTEMD_USER_DIR}/sleep-warning.timer"
    if ! show_gui_step "2" "Remove Systemd Files" "${step2_instructions}" "${step2_commands}"; then
        return 1
    fi
    
    # Step 3: Remove Scripts
    local step3_instructions="Remove the installed script files and library directory."
    local step3_commands="rm -f ${INSTALL_DIR}/sleep-warning.sh\nrm -f ${INSTALL_DIR}/sleep-warning-configure\nrm -f ${INSTALL_DIR}/sleep-warning-manage\nrm -rf ${LIB_DIR}"
    if ! show_gui_step "3" "Remove Scripts" "${step3_instructions}" "${step3_commands}"; then
        return 1
    fi
    
    # Step 4: Remove Configuration (Optional)
    local step4_instructions="Remove the configuration file and log file (optional - you can keep these if you plan to reinstall)."
    local step4_commands="rm -f ${CONFIG_DIR}/sleep-warning.conf\nrm -f ${CONFIG_DIR}/warnings.log\nrmdir ${CONFIG_DIR} 2>/dev/null || true"
    if ! show_gui_step "4" "Remove Configuration (Optional)" "${step4_instructions}" "${step4_commands}"; then
        return 1
    fi
    
    # Step 5: Reload Systemd
    local step5_instructions="Reload the systemd user daemon to apply changes."
    local step5_commands="systemctl --user daemon-reload"
    if ! show_gui_step "5" "Reload Systemd" "${step5_instructions}" "${step5_commands}"; then
        return 1
    fi
    
    # Final message
    local final_msg
    final_msg="Manual Uninstallation Guide Complete!\n\n"
    final_msg="${final_msg}After completing these steps, the Sleep Warning System will be completely removed from your system."
    
    # Use dialog abstraction function for consistency
    show_info_dialog "Manual Uninstall Guide - Complete" "${final_msg}" 500 200
}

# Function to show a single step in text mode (clears screen after)
show_text_step() {
    local step_num="$1"
    local step_title="$2"
    local step_instructions="$3"
    local commands="$4"
    
    clear
    echo ""
    print_header "═══════════════════════════════════════════════════════════"
    print_header "  Manual Uninstallation Guide - Sleep Warning System"
    print_header "═══════════════════════════════════════════════════════════"
    echo ""
    
    print_header "STEP ${step_num}: ${step_title}"
    echo ""
    print_info "${step_instructions}"
    echo ""
    
    if [ -n "${commands}" ]; then
        print_step "Commands to run:"
        echo ""
        # Split commands by newline and print each
        echo "${commands}" | while IFS= read -r cmd; do
            if [ -n "${cmd}" ]; then
                print_command "${cmd}"
            fi
        done
        echo ""
    fi
    
    print_warning "Press Enter to continue to next step (or Ctrl+C to exit)..."
    read -r
}

# Function to show instructions in text mode (one step at a time)
show_text_instructions() {
    # Step 1: Stop and Disable Timer
    show_text_step "1" "Stop and Disable Timer" \
        "Stop and disable the systemd timer that runs the warning system." \
        "systemctl --user stop sleep-warning.timer\nsystemctl --user disable sleep-warning.timer"
    
    # Step 2: Remove Systemd Files
    show_text_step "2" "Remove Systemd Files" \
        "Remove the systemd service and timer files." \
        "rm -f ${SYSTEMD_USER_DIR}/sleep-warning.service\nrm -f ${SYSTEMD_USER_DIR}/sleep-warning.timer"
    
    # Step 3: Remove Scripts
    show_text_step "3" "Remove Scripts" \
        "Remove the installed script files and library directory." \
        "rm -f ${INSTALL_DIR}/sleep-warning.sh\nrm -f ${INSTALL_DIR}/sleep-warning-configure\nrm -f ${INSTALL_DIR}/sleep-warning-manage\nrm -rf ${LIB_DIR}"
    
    # Step 4: Remove Configuration (Optional)
    show_text_step "4" "Remove Configuration (Optional)" \
        "Remove the configuration file and log file (optional - you can keep these if you plan to reinstall)." \
        "rm -f ${CONFIG_DIR}/sleep-warning.conf\nrm -f ${CONFIG_DIR}/warnings.log\nrmdir ${CONFIG_DIR} 2>/dev/null || true"
    
    # Step 5: Reload Systemd
    show_text_step "5" "Reload Systemd" \
        "Reload the systemd user daemon to apply changes." \
        "systemctl --user daemon-reload"
    
    # Final message
    clear
    echo ""
    print_header "═══════════════════════════════════════════════════════════"
    print_header "  Manual Uninstallation Guide - Complete"
    print_header "═══════════════════════════════════════════════════════════"
    echo ""
    print_info "After completing these steps, the Sleep Warning System will be"
    print_info "completely removed from your system."
    echo ""
    print_header "═══════════════════════════════════════════════════════════"
    echo ""
}

# Main function
main() {
    # Determine GUI mode
    local use_gui="false"
    if [ -n "${DISPLAY}" ] && has_dialog_tool; then
        use_gui="true"
    fi
    
    # Verify user before showing instructions
    verify_before_showing_instructions "${use_gui}"
    local exit_code=$?
    if [ "${exit_code}" -ne 0 ]; then
        if [ ${exit_code} -eq 2 ]; then
            # User cancelled
            if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                show_info_dialog "Cancelled" "Access to uninstall guide cancelled by user." 400 150
            else
                echo "Access to uninstall guide cancelled by user." >&2
            fi
            exit 0
        else
            # Verification failed
            exit 1
        fi
    fi
    
    # Show instructions
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_gui_instructions
    else
        show_text_instructions
    fi
}

# Run main function
main "$@"
