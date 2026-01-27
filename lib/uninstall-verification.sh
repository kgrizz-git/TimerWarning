#!/bin/bash

###############################################################################
# Sleep Warning System - Uninstall Verification Module
#
# This module provides functions for difficult uninstall verification during
# restricted hours. It implements a two-step verification process:
# 1. Confirmation phrase verification
# 2. Arithmetic questions (5 questions in word form)
#
# Functions:
# - get_confirmation_phrase()              - Get the exact confirmation phrase
# - verify_confirmation_phrase()           - Verify user input matches phrase
# - generate_algebra_question()            - Generate arithmetic question (name kept for compatibility)
# - validate_answer()                      - Validate user's answer to question
# - verify_uninstall_during_restrictions() - Main verification function
#
# Dependencies:
# - configure-core.sh (for get_dialog_tool, has_dialog_tool)
# - configure-dialogs.sh (for show_entry_dialog, show_info_dialog, show_question_dialog)
# - desktop-environment.sh (for check_dialog_tool)
#
# Usage: Source this file after dependencies
#   source lib/configure-core.sh
#   source lib/desktop-environment.sh
#   source lib/configure-dialogs.sh
#   source lib/uninstall-verification.sh
###############################################################################

# Get the exact confirmation phrase that user must type
# This is for Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)
#
# Returns:
#   The exact confirmation phrase string
get_confirmation_phrase() {
    echo "I really mean it and want to uninstall this program now even though restrictions are running"
}

# Verify that user input matches the confirmation phrase
# This is for Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)
#
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - max_attempts (optional, default: 3)
#
# Returns:
#   0 - Phrase matches
#   1 - Phrase doesn't match (after max attempts)
#   2 - User cancelled
#
# Exit Codes:
#   0 - Success (phrase verified)
#   1 - Failure (max attempts exceeded)
#   2 - Cancelled
verify_confirmation_phrase() {
    local use_gui="$1"
    local max_attempts="${2:-3}"
    local phrase
    phrase=$(get_confirmation_phrase)
    
    local attempt=1
    while [ ${attempt} -le ${max_attempts} ]; do
        local user_input=""
        
        if [ "${use_gui}" = "true" ] && has_dialog_tool; then
            # GUI mode
            local dialog_text
            if [ ${attempt} -eq 1 ]; then
                dialog_text="Uninstall Verification - Step 1 of 2\n\nYou must type the following phrase exactly:\n\n\"${phrase}\"\n\nThis confirms you really want to uninstall during restricted hours."
            else
                dialog_text="Uninstall Verification - Step 1 of 2\n\nAttempt ${attempt} of ${max_attempts}\n\nType the following phrase exactly:\n\n\"${phrase}\""
            fi
            
            user_input=$(show_entry_dialog \
                "Uninstall Verification - Confirmation Phrase" \
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
                echo "Uninstall Verification - Step 1 of 2: Confirmation Phrase" >&2
                echo "You must type the following phrase exactly:" >&2
                echo "" >&2
                echo "  \"${phrase}\"" >&2
                echo "" >&2
                echo "This confirms you really want to uninstall during restricted hours." >&2
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

# Generate a random arithmetic question in word form
# Function name kept as "generate_algebra_question" for compatibility, but generates arithmetic questions
# This is for Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)
#
# Returns:
#   Question text and correct answer separated by pipe: "QUESTION_TEXT|CORRECT_ANSWER"
#   Example: "Multiply 53 by 15, then add (31 minus 58), then add 147. What is the final result?|797"
#
# Question Complexity Levels:
#   - Medium: "Multiply X by Y, then [add/subtract] (Z [times/minus] W), then [add/subtract] N. What is the final result?"
#   - Complex: "Start with X, multiply by Y, then [add/subtract] (Z [plus/minus] W), then [add/subtract] (A [plus/minus] B), then [add/subtract] N. What is the final result?"
generate_algebra_question() {
    # Randomly select complexity level (medium or complex, simple removed per user request)
    local complexity
    complexity=$((RANDOM % 2))
    
    if [ ${complexity} -eq 0 ]; then
        # Medium complexity: Multiply X by Y, then [add/subtract] (Z [times/minus] W), then [add/subtract] N
        local x y z w n
        x=$((RANDOM % 100 + 10))  # 10-109
        y=$((RANDOM % 100 + 10))  # 10-109
        z=$((RANDOM % 100 + 10))  # 10-109
        w=$((RANDOM % 100 + 10))  # 10-109
        n=$((RANDOM % 200 + 50))  # 50-249
        
        # Randomly choose operations
        local op1 op2 op3
        op1=$((RANDOM % 2))  # 0=add, 1=subtract
        op2=$((RANDOM % 2))  # 0=add, 1=subtract
        op3=$((RANDOM % 2))  # 0=times, 1=minus
        
        # Calculate correct answer
        local answer
        local paren_result
        if [ ${op3} -eq 0 ]; then
            # times
            paren_result=$((z * w))
        else
            # minus
            paren_result=$((z - w))
        fi
        
        local step1
        step1=$((x * y))
        
        local step2
        if [ ${op1} -eq 0 ]; then
            # add
            step2=$((step1 + paren_result))
        else
            # subtract
            step2=$((step1 - paren_result))
        fi
        
        if [ ${op2} -eq 0 ]; then
            # add
            answer=$((step2 + n))
        else
            # subtract
            answer=$((step2 - n))
        fi
        
        # Build question text
        local question_text
        local op1_text op2_text op3_text
        if [ ${op1} -eq 0 ]; then
            op1_text="add"
        else
            op1_text="subtract"
        fi
        
        if [ ${op2} -eq 0 ]; then
            op2_text="add"
        else
            op2_text="subtract"
        fi
        
        if [ ${op3} -eq 0 ]; then
            op3_text="times"
        else
            op3_text="minus"
        fi
        
        question_text="Multiply ${x} by ${y}, then ${op1_text} (${z} ${op3_text} ${w}), then ${op2_text} ${n}. What is the final result?"
        
        echo "${question_text}|${answer}"
    else
        # Complex complexity: Start with X, multiply by Y, then [add/subtract] (Z [plus/minus] W), then [add/subtract] (A [plus/minus] B), then [add/subtract] N
        local x y z w a b n
        x=$((RANDOM % 50 + 50))   # 50-99
        y=$((RANDOM % 100 + 50))  # 50-149
        z=$((RANDOM % 50 + 10))   # 10-59
        w=$((RANDOM % 50 + 10))   # 10-59
        a=$((RANDOM % 50 + 10))   # 10-59
        b=$((RANDOM % 50 + 10))   # 10-59
        n=$((RANDOM % 500 + 100)) # 100-599
        
        # Randomly choose operations
        local op1 op2 op3 op4
        op1=$((RANDOM % 2))  # 0=add, 1=subtract
        op2=$((RANDOM % 2))  # 0=add, 1=subtract
        op3=$((RANDOM % 2))  # 0=plus, 1=minus
        op4=$((RANDOM % 2))  # 0=plus, 1=minus
        
        # Calculate correct answer
        local answer
        local paren1_result paren2_result
        if [ ${op3} -eq 0 ]; then
            # plus
            paren1_result=$((z + w))
        else
            # minus
            paren1_result=$((z - w))
        fi
        
        if [ ${op4} -eq 0 ]; then
            # plus
            paren2_result=$((a + b))
        else
            # minus
            paren2_result=$((a - b))
        fi
        
        local step1 step2 step3
        step1=$((x * y))
        
        if [ ${op1} -eq 0 ]; then
            # add
            step2=$((step1 + paren1_result))
        else
            # subtract
            step2=$((step1 - paren1_result))
        fi
        
        if [ ${op2} -eq 0 ]; then
            # add
            step3=$((step2 + paren2_result))
        else
            # subtract
            step3=$((step2 - paren2_result))
        fi
        
        answer=$((step3 + n))
        
        # Build question text
        local question_text
        local op1_text op2_text op3_text op4_text
        if [ ${op1} -eq 0 ]; then
            op1_text="add"
        else
            op1_text="subtract"
        fi
        
        if [ ${op2} -eq 0 ]; then
            op2_text="add"
        else
            op2_text="subtract"
        fi
        
        if [ ${op3} -eq 0 ]; then
            op3_text="plus"
        else
            op3_text="minus"
        fi
        
        if [ ${op4} -eq 0 ]; then
            op4_text="plus"
        else
            op4_text="minus"
        fi
        
        question_text="Start with ${x}, multiply by ${y}, then ${op1_text} (${z} ${op3_text} ${w}), then ${op2_text} (${a} ${op4_text} ${b}), then add ${n}. What is the final result?"
        
        echo "${question_text}|${answer}"
    fi
}

# Validate user's answer to arithmetic question
# This is for Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)
#
# Parameters:
#   $1 - user_answer (string, may contain commas or spaces)
#   $2 - correct_answer (integer)
#
# Returns:
#   0 - Answer is correct
#   1 - Answer is incorrect
#
# Exit Codes:
#   0 - Correct
#   1 - Incorrect
validate_answer() {
    local user_answer="$1"
    local correct_answer="$2"
    
    # Normalize user input: trim whitespace, remove commas, remove spaces
    user_answer=$(echo "${user_answer}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d ',' | tr -d ' ')
    
    # Validate that user input is a valid integer
    if ! [[ "${user_answer}" =~ ^-?[0-9]+$ ]]; then
        return 1
    fi
    
    # Convert to integer for comparison
    local user_int
    user_int=$((10#${user_answer}))
    
    # Compare with correct answer
    if [ ${user_int} -eq ${correct_answer} ]; then
        return 0
    else
        return 1
    fi
}

# Main verification function for uninstall during restricted hours
# This is for Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)
#
# Parameters:
#   $1 - use_gui (true/false)
#
# Returns:
#   0 - Verification passed
#   1 - Verification failed
#   2 - User cancelled
#
# Exit Codes:
#   0 - Success (verification passed)
#   1 - Failure (verification failed)
#   2 - Cancelled
verify_uninstall_during_restrictions() {
    local use_gui="$1"
    
    # Display explanation
    local explanation
    explanation="Uninstall during restricted hours requires verification.\n\n"
    explanation="${explanation}You will need to:\n"
    explanation="${explanation}1. Type a confirmation phrase\n"
    explanation="${explanation}2. Answer 5 arithmetic questions correctly\n"
    explanation="${explanation}   (You are allowed 3 wrong answers total across all questions)\n\n"
    explanation="${explanation}This process requires significant effort and cognitive engagement,\n"
    explanation="${explanation}allowing legitimate uninstalls while deterring impulsive ones."
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode - ask if user wants to proceed
        if ! show_question_dialog \
            "Uninstall Verification Required" \
            "${explanation}\n\nDo you want to proceed with verification?" \
            "Proceed" \
            "Cancel" \
            600 \
            400; then
            # User cancelled
            return 2
        fi
    else
        # Text mode
        echo "" >&2
        echo "Uninstall Verification Required" >&2
        echo "================================" >&2
        echo "" >&2
        echo "${explanation}" | sed 's/\\n/\n/g' >&2
        echo "" >&2
        read -p "Do you want to proceed with verification? [y/n]: " proceed_choice
        if [ "${proceed_choice}" != "y" ] && [ "${proceed_choice}" != "Y" ] && [ "${proceed_choice}" != "yes" ] && [ "${proceed_choice}" != "YES" ]; then
            # User cancelled
            return 2
        fi
    fi
    
    # Step 1: Confirmation phrase
    if ! verify_confirmation_phrase "${use_gui}" 3; then
        local exit_code=$?
        if [ ${exit_code} -eq 2 ]; then
            # User cancelled
            return 2
        else
            # Verification failed
            local error_msg="Confirmation phrase verification failed. Uninstall cancelled."
            if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                show_info_dialog "Verification Failed" "${error_msg}" 500 200
            else
                echo "Error: ${error_msg}" >&2
            fi
            return 1
        fi
    fi
    
    # Step 2: Arithmetic questions (5 questions)
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
                    "Uninstall Verification - Arithmetic Question" \
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
    local success_msg="Verification successful! All questions answered correctly. Proceeding with uninstall."
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog "Verification Successful" "${success_msg}" 500 200
    else
        echo "" >&2
        echo "${success_msg}" >&2
    fi
    
    return 0
}
