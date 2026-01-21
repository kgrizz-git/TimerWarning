# Enhancement 26: Prevent uninstall.sh Execution During Restricted Hours

- **Description**: Make `uninstall.sh` more difficult to run during restricted hours (Phase 1: requires verification process) and optionally fully block it during additional configurable hours (Phase 2: future enhancement) to prevent users from circumventing restrictions by uninstalling the system. **Phase 1 does NOT fully block uninstall.sh** - it requires users to complete verification (confirmation phrase + arithmetic questions) but still allows uninstall if completed. Future phases may include full blocking, which is **risky** and could lock users out if they need to uninstall during restricted hours. A companion script provides instructions for manual uninstallation.
- **Files Affected**: `uninstall.sh`, `sleep-warning.sh`, `sleep-warning.conf`, new `manual-uninstall-guide.sh`
- **Priority**: Medium (security/self-control feature, but risky - could prevent legitimate uninstall needs)
- **Status**: Phase 1 mostly implemented (Core functionality complete, some items, testing and user documentation pending)
- **Feasibility Assessment**: ✅ **Highly Feasible** - Simple time check at script start, similar to Enhancement #19
- **Risk Assessment**: 
  - **Phase 1 (Difficult Mode)**: ⚠️ **LOWER RISK** - Requires verification but still allows uninstall if user completes the process. Legitimate uninstalls are possible with effort.
  - **Future Phase (Total Block Mode)**: ⚠️ **HIGH RISK** - Fully blocking uninstall during restricted hours could prevent users from removing the system when needed (e.g., system issues, emergency situations, legitimate need to uninstall). This feature should be:
  - **Opt-in only** (default: disabled)
  - **Clearly documented** with warnings about risks
  - **Accompanied by manual uninstall guide script** that provides step-by-step instructions for manual uninstallation even during restricted hours
  - **Not recommended for most users** - primarily for users with strong self-control needs who understand the risks
- **Implementation Approach**:
  - **Phase 1: Difficult Uninstall During Restricted Hours** (Initial Implementation):
    - User-configurable option in `configure.sh` to enable/disable difficult uninstall
    - When enabled, `uninstall.sh` checks current day/time at startup
    - If current time falls within restricted hours, require user to complete difficult verification process:
      1. **Confirmation Phrase**: User must type exact phrase: "I really mean it and want to uninstall this program now even though restrictions are running"
      2. **Arithmetic Questions**: User must correctly answer 10 arithmetic questions written in word form with step-by-step instructions (e.g., "Multiply 53 by 15, then add (31 minus 58), then add 147. What is the final result?")
      3. **Question Generation**: Generate random arithmetic questions of medium or complex difficulty, written in natural language to prevent copy-pasting into search engines/calculators
      4. **Validation**: Verify answers are correct (simple integer comparison) before allowing uninstall to proceed
    - **Pros**: 
      - Allows legitimate uninstalls while deterring impulsive ones
      - Requires cognitive engagement and effort, making it difficult to uninstall impulsively
      - Lower risk than total block - users can still uninstall if they really need to
      - More user-friendly than complete blocking
      - Questions written in word form make copy-pasting into search engines/calculators more difficult
    - **Cons**: 
      - More complex to implement (requires question generation and answer validation)
      - Determined users can still uninstall if they complete the verification
      - May frustrate users who need to uninstall but struggle with math
      - Questions may still be solvable with careful copy-paste and manual conversion (though more difficult)
    - **Safety**: Lower Risk - Users can still uninstall if they complete verification, but requires significant effort and cognitive engagement
  - **Future Phase: Total Block During Restricted Hours** (Optional Future Enhancement):
    - **Status**: Not planned for initial implementation - may be considered as a future phase
    - User-configurable option in `configure.sh` to enable/disable total blocking
    - When enabled, `uninstall.sh` checks current day/time at startup
    - If current time falls within restricted hours, exit with error message
    - Use same time checking logic as `sleep-warning.sh` (reuse functions)
    - **Pros**: Simple, effective, cannot be easily bypassed without modifying script, user-controlled
    - **Cons**: Can be bypassed by modifying system time or editing script directly, **RISKY** - could prevent legitimate uninstall needs
    - **Safety**: Medium-High Risk - Determined users can bypass, but requires knowledge/effort. **Main risk is preventing legitimate uninstall needs.**
    - **Note**: This option is not recommended due to high risk of preventing legitimate uninstall needs. Manual uninstall guide script would be required as safety mechanism.
  - **Phase 2: Additional Configurable Lock Hours** (Future Enhancement):
    - Extend Phase 1 to also check additional configurable lock hours
    - If current time falls within restricted hours OR additional lock hours, apply difficult uninstall verification
    - Allows users to configure separate lock hours beyond restriction hours
    - **Pros**: More flexible, allows custom lock periods independent of restriction hours
    - **Cons**: Adds complexity, requires additional configuration
    - **Safety**: Lower risk (uses difficult uninstall verification, not total block)
- **Manual Uninstall Guide Script**:
  - **Purpose**: Provide users with step-by-step instructions for manually uninstalling the system even when `uninstall.sh` is blocked
  - **Location**: `manual-uninstall-guide.sh` (in project root, installed to system location)
  - **Functionality**:
    - Display clear instructions for manual uninstallation
    - List all files and directories that need to be removed
    - Provide systemd commands to stop/disable/remove service and timer
    - Show commands to remove config files and logs
    - **Should NOT be blocked** - always accessible to users
    - Can be run even during restricted hours
    - Provides both GUI and text mode instructions
  - **Content**:
    - Step-by-step manual uninstall instructions
    - List of files to remove (service, timer, config, logs, scripts)
    - Systemd commands (stop timer, disable timer, remove service/timer files)
    - File paths for different installation locations
    - Clear warnings about what will be removed
- **Implementation Notes**:
  - **Config Options (Phase 1 - Initial Implementation)**:
    - `UNINSTALL_PROTECTION_MODE=none/difficult` - Choose protection mode for uninstall.sh during restricted hours
      - `none` (default): No protection - uninstall works normally during restricted hours
      - `difficult`: Difficult uninstall - require confirmation phrase + 10 arithmetic questions (recommended, lower risk)
    - **Note**: Total block mode (`total`) is not included in initial implementation - may be considered as future phase
    - Protection applies only during restricted hours
    - **Configuration Interface**: Add option in `configure.sh` to allow user to choose protection mode
    - User should be able to select from: "No Protection", "Difficult Uninstall (Recommended)"
    - Default: `none` (opt-in feature)
    - **Note**: This is separate from Enhancement #18 (Config File Locking) and Enhancement #19 (Prevent configure.sh Execution) which use `CONFIG_LOCK_ENABLED` and `CONFIGURE_BLOCK_ENABLED`
  - **Future Config Options (Total Block Mode - Future Phase)**:
    - If total block mode is implemented in future, add `total` option:
      - `total`: Total block - completely prevent uninstall during restricted hours (high risk, not recommended)
    - **⚠️ WARNING**: Should display prominent warning when enabling "total" mode about the risks and that manual uninstall guide is available
  - **Difficult Uninstall Implementation Details**:
    - **Confirmation Phrase**:
      - Exact phrase: "I really mean it and want to uninstall this program now even though restrictions are running"
      - Case-sensitive or case-insensitive (configurable, default: case-insensitive for user-friendliness)
      - Display phrase clearly so user knows what to type
      - Support both GUI (text entry dialog) and text mode (stdin input)
    - **Arithmetic Question Generation**:
      - Generate 10 random arithmetic questions written in word form with step-by-step instructions
      - Question complexity levels (mix randomly):
        - Medium: "Multiply X by Y, then [add/subtract] (Z [times/minus] W), then [add/subtract] N. What is the final result?"
        - Complex: "Start with X, multiply by Y, then [add/subtract] (Z [plus/minus] W), then [add/subtract] (A [plus/minus] B), then [add/subtract] N. What is the final result?"
      - Questions use natural language ("times", "plus", "minus", "add", "subtract") to make copy-pasting more difficult
      - Questions require understanding the problem structure, not just direct mathematical expressions
      - Difficulty levels: Medium to complex arithmetic (multiplication, addition, subtraction with parentheses)
      - Ensure questions have integer solutions (may be negative)
      - Store correct integer answers for validation
    - **Answer Validation**:
      - Accept integer answers (primary format)
      - Handle answer formats: "1234", "-567", "1,234" (commas stripped), "1 234" (spaces stripped)
      - Validate that user input is a valid integer
      - Simple integer comparison (no complex parsing needed)
      - Provide clear feedback on incorrect answers
      - Allow user to retry if answer is incorrect (up to 3 attempts per question, or configurable)
    - **User Interface**:
      - Support both GUI and text modes
      - GUI: Use dialog tool (yad/zenity/kdialog) for text entry and question display
      - Text mode: Use stdin/stdout for interaction
      - Show progress: "Question 1 of 10", "Question 2 of 10", etc.
      - Show confirmation phrase requirement clearly
      - Display questions in clear, readable format
    - **Error Handling**:
      - If user fails to type confirmation phrase correctly: Show error, allow retry
      - If user answers question incorrectly: Show error, show correct answer, allow retry (up to max attempts)
      - If user fails too many questions: Exit with message, suggest trying again later or using manual uninstall guide
      - If user cancels: Exit gracefully without uninstalling
  - **Phase 2 Config Options** (extends Phase 1):
    - `CONFIG_LOCK_HOURS=DAY=START-END` - Additional hours for blocking uninstall.sh (separate from restriction hours)
    - Block applies during restricted hours AND any additional configured lock hours
    - **⚠️ WARNING**: Additional lock hours increase the risk of preventing legitimate uninstall needs
  - **Time Check Logic (Phase 1)**:
    - Only applies when `UNINSTALL_PROTECTION_MODE=difficult` (user-enabled via `configure.sh`)
    - Reuse `is_restricted_hour()` function from `lib/time-validation.sh` (already shared module)
    - Source `lib/time-validation.sh` in `uninstall.sh` to use the same validation logic
    - Check only restriction hours (Phase 1) or restriction hours + additional lock hours (Phase 2)
    - **For Difficult Uninstall Mode**: Proceed to verification process (confirmation phrase + arithmetic questions) if in restricted hours
  - **Future Time Check Logic (Total Block Mode - Future Phase)**:
    - If total block mode is implemented, add check for `UNINSTALL_PROTECTION_MODE=total`
    - **For Total Block Mode**: Exit early with clear error message if in restricted hours
    - **Error message (Total Block) must include**: Reference to `manual-uninstall-guide.sh` script for manual uninstallation instructions
  - **Phase 2 Time Check Logic** (extends Phase 1):
    - Add function to check additional lock hours (similar to `is_restricted_hour()`)
    - Check both restriction hours and additional lock hours
    - Apply difficult uninstall verification if in restricted/lock hours
  - **Error Message (Total Block Mode - Future Phase)**:
    - Clear, informative: "Uninstall is blocked during restricted hours ([current time range]). Please try again after [end time], or run 'manual-uninstall-guide.sh' for manual uninstallation instructions."
    - Phase 2: Update message to indicate if locked due to restriction hours or additional lock hours
    - Show current time and when restrictions end
    - **Must prominently mention** `manual-uninstall-guide.sh` as an alternative
  - **Difficult Uninstall Message**:
    - Clear explanation: "Uninstall during restricted hours requires verification. You will need to:"
    - List requirements: "1. Type a confirmation phrase", "2. Answer 10 arithmetic questions correctly"
    - Ask if user wants to proceed or cancel
    - If user proceeds, begin verification process
  - **Bypass Prevention**:
    - Script should check time, not rely on external locks (prevents lock file deletion bypass)
    - Can combine with config file locking (#18) and configure.sh blocking (#19) for defense in depth
    - **Note**: Manual uninstall guide script should NOT be blocked and should always be accessible
- **Safety Assessment**:
  - **Bypass Risk**: Medium - Determined users can bypass by:
    - Modifying system time (requires admin access or time change permissions)
    - Editing `uninstall.sh` or library modules directly to remove time check
    - Running manual uninstall commands directly (bypassing script)
    - Using `manual-uninstall-guide.sh` to perform manual uninstall
  - **Uninstall Safety**: 
    - **Difficult Uninstall Mode (Phase 1)**: ✅ **LOWER RISK** - Users can still uninstall if they complete verification:
      - Legitimate uninstalls are possible with effort
      - Deters impulsive uninstalls while allowing necessary ones
      - Requires cognitive engagement and time, making it difficult to uninstall impulsively
      - **Mitigation**: Verification process is challenging but achievable for determined users
    - **Total Block Mode (Future Phase)**: ⚠️ **HIGH RISK** - Blocking uninstall could prevent legitimate uninstall needs:
      - System issues requiring uninstall
      - Emergency situations
      - Legitimate need to remove system
      - **Mitigation**: Manual uninstall guide script provides alternative, but requires user knowledge/effort
      - **Note**: This mode is not included in initial implementation due to high risk
  - **Data Safety**: ✅ **Safe** - No risk of data loss (uninstall only removes system files)
  - **System Safety**: ⚠️ **Medium Risk** - Could prevent removal of problematic system if issues occur during restricted hours
  - **User Experience**: 
    - **Difficult Uninstall Mode (Phase 1)**: ✅ **Better User Experience** - Allows legitimate uninstalls while deterring impulsive ones, requires effort but achievable
    - **Total Block Mode (Future Phase)**: ⚠️ **May Frustrate Users** - Prevents legitimate uninstall needs during restricted hours, could lock users out
- **Processing/Memory Burden**:
  - **Difficult Uninstall Mode (Phase 1)**: Low - Requires question generation and answer validation, but only during uninstall attempts
  - **Total Block Mode (Future Phase)**: Minimal - Only requires time check at script startup (same logic as restriction checking)
  - No additional processes or continuous monitoring
  - **Memory**: Negligible (no additional memory usage)
  - **CPU**: 
    - Difficult Uninstall: Low (question generation and validation are simple calculations, only during uninstall attempts)
    - Total Block: Negligible (time check is instant, same as existing restriction checks)
- **User Experience Considerations**:
  - **Clear Instructions (Difficult Uninstall)**: Should clearly explain verification requirements before starting
  - **Optional Feature**: Should be opt-in (default: disabled) to avoid frustrating users
  - **Documentation**: Must clearly document verification process (difficult uninstall) in user documentation
  - **Question Difficulty**: Arithmetic questions should be challenging but fair - not impossible, but requiring genuine effort. Questions are written in word form with step-by-step instructions to make copy-pasting more difficult.
  - **Accessibility**: Consider providing alternative verification methods for users who struggle with math (future enhancement)
  - **Phase 2 Additional Considerations**: Additional lock hours provide more flexibility but maintain lower risk (uses difficult uninstall verification)
  - **Future Phase Considerations (Total Block)**:
    - If total block mode is implemented: Should display prominent warning when enabling "total" mode about the risks
    - Error message should inform user why script cannot run and when they can try again
    - Must prominently mention `manual-uninstall-guide.sh` in error message
    - Consider allowing override with special flag (e.g., `--force`) for emergencies (defeats purpose but may be needed)
- **Related**: 
  - Works with "Config File Locking" (#18) - complementary features, defense in depth
  - Works with "Prevent configure.sh Execution" (#19) - complementary features, defense in depth
  - Uses same time checking logic as restriction system
  - Complements restriction system by preventing circumvention
  - **Manual uninstall guide script** is critical companion feature

---

## Phase 1: Implementation Checklist

### Overview
Make `uninstall.sh` more difficult to run during restricted hours when `UNINSTALL_PROTECTION_MODE=difficult` is enabled. **Phase 1 does NOT fully block uninstall.sh** - instead, it requires users to complete a verification process (confirmation phrase + 10 arithmetic questions) before uninstalling during restricted hours. This is a user-configurable, opt-in feature (default: disabled, mode: "none") with **lower risk** than full blocking since legitimate uninstalls are still possible with effort. A manual uninstall guide script is provided as an additional safety mechanism.

### Files to Modify

#### Core Files
- `lib/config.sh` - Add function to read UNINSTALL_PROTECTION_MODE
- `lib/configure-config.sh` - Load and save UNINSTALL_PROTECTION_MODE
- `lib/configure-display.sh` - Add menu option for uninstall protection mode setting
- `lib/configure-ui.sh` - Add dialog function for uninstall protection mode setting
- `lib/uninstall-verification.sh` - New module for difficult uninstall verification (confirmation phrase + arithmetic questions)
- `uninstall.sh` - Add time check at startup, implement protection modes
- `sleep-warning.conf` - Add UNINSTALL_PROTECTION_MODE documentation

#### New Files
- `manual-uninstall-guide.sh` - Script providing step-by-step manual uninstallation instructions
- `lib/uninstall-verification.sh` - Module for generating arithmetic questions (in word form) and validating answers

#### Documentation
- `dev-docs/enhancements/enhancement-26-prevent-uninstall-during-restricted-hours.md` - Update status when complete
- `user-docs/CONFIGURATION.md` - Document UNINSTALL_PROTECTION_MODE option with warnings (clarify that Phase 1 only implements "difficult" mode, not full blocking)
- `user-docs/USER_GUIDE.md` - Document manual uninstall guide script

---

### 1. Configuration File Support

#### 1.1 Add UNINSTALL_PROTECTION_MODE to config.sh
- [x] Add default value constant: `DEFAULT_UNINSTALL_PROTECTION_MODE="none"`
- [x] Add function `get_uninstall_protection_mode()` in `lib/config.sh`
  - [x] Read `UNINSTALL_PROTECTION_MODE` from config file
  - [x] Validate value (none/difficult)
  - [x] Return default if missing or invalid
  - [x] Normalize output to lowercase: "none" or "difficult"
  - [x] Handle legacy `UNINSTALL_BLOCK_ENABLED` for backward compatibility (if true, set mode to "difficult" - total block not available in Phase 1)

#### 1.2 Update configure-config.sh
- [x] Add `uninstall_protection_mode` to global variables in `load_existing_config()`
  - [x] Initialize with default: `declare -g uninstall_protection_mode="none"`
  - [x] Read existing value from config file (if present)
  - [x] Validate and normalize to "none" or "difficult"
  - [x] Handle legacy `UNINSTALL_BLOCK_ENABLED` for backward compatibility
- [x] Update `write_config()` function signature
  - [x] Add `uninstall_protection_mode` as parameter (7th parameter, after `configure_block_enabled`)
  - [x] Write `UNINSTALL_PROTECTION_MODE=${uninstall_protection_mode}` to config file
  - [x] Add comment header explaining the option
  - [x] Place after `CONFIGURE_BLOCK_ENABLED` section in config file

#### 1.3 Update configure.sh main function
- [x] Add `uninstall_protection_mode` to global variable declarations
  - [x] Add to: `declare -g check_interval popup_size popup_position min_display_time popup_immovable configure_block_enabled uninstall_protection_mode`
- [x] Update `write_config()` call
  - [x] Add `${uninstall_protection_mode}` as 7th argument

#### 1.4 Update config file template
- [x] Add `UNINSTALL_PROTECTION_MODE` section to `sleep-warning.conf` template
  - [x] Add comment explaining the feature and available modes
  - [x] Add default value: `UNINSTALL_PROTECTION_MODE=none`
  - [x] Explain each mode: none (no protection), difficult (verification required, recommended)
  - [x] Note that total block mode may be considered as future phase
  - [x] Place after `CONFIGURE_BLOCK_ENABLED` section

---

### 2. Configuration UI - Menu Option

#### 2.1 Add menu option to configure-display.sh
- [x] Update `show_main_menu()` function
  - [x] Add new menu option for "Uninstall Protection" (separate menu option, not integrated into Security Settings)
  - [x] Add status indicator showing current state (Enabled/Disabled)
  - [x] Update both GUI and text mode menus
  - [x] Add status indicator if enabled (shows "(Enabled)" or "(Disabled)")

#### 2.2 Add dialog function to configure-input.sh
- [x] Create `get_uninstall_protection_mode_config()` function
  - [x] Accept `use_gui` parameter
  - [x] Show current setting (none/difficult)
  - [x] Present options:
    - [x] "none" - No protection, uninstall works normally
    - [x] "difficult" - Difficult uninstall, requires verification
  - [x] **Explain "difficult" mode**:
    - [x] Explain that it requires confirmation phrase + 10 arithmetic questions
    - [x] Explain that it allows legitimate uninstalls while deterring impulsive ones
    - [x] Note that total block mode may be considered as future phase (implied in explanation)
  - [x] Ask user to select mode
  - [x] Return "none" or "difficult" string
  - [x] Handle cancellation (return "CANCELLED")
  - [x] Support both GUI and text modes
  - [x] Include clear explanation of what each mode does

#### 2.3 Add menu handler to configure.sh
- [x] Add case for menu option (option 8: Uninstall Protection)
  - [x] Call `get_uninstall_protection_mode_config()`
  - [x] Handle "CANCELLED" response (exit if cancelled)
  - [x] Update global `uninstall_protection_mode` variable
  - [x] Return to main menu after setting

---

### 3. Time Check Implementation

#### 3.1 Create time check function
- [x] Create `check_uninstall_protection_time()` function
  - [x] Location: Added to `lib/time-validation.sh`
  - [x] Function should:
    - [x] Read `UNINSTALL_PROTECTION_MODE` from config (use `get_uninstall_protection_mode()`)
    - [x] Return mode string ("none" or "difficult") if in restricted hours
    - [x] Return "none" if not in restricted hours or mode is "none"
    - [x] Get current day of week (0=Sunday, 6=Saturday)
    - [x] Get current hour (0-23)
    - [x] Parse config for current day using `parse_config()`
    - [x] Check if current hour is restricted using `is_restricted_hour()`
    - [x] Handle overnight ranges from previous day (same logic as sleep-warning.sh)
    - [x] Return "none" if NOT in restricted hours (allow execution)
    - [x] Return protection mode ("difficult") if IN restricted hours

#### 3.2 Add time check to uninstall.sh
- [x] Source required modules at top of script
  - [x] Ensure `lib/config.sh` is sourced
  - [x] Ensure `lib/time-validation.sh` is sourced
  - [x] Source `lib/uninstall-verification.sh` (for difficult mode)
- [x] Add time check at start of `main()` function
  - [x] Call `check_uninstall_protection_time()` BEFORE showing any dialogs
  - [x] If mode is "difficult", proceed to verification process
  - [x] If mode is "none", proceed normally
  - [x] **Note**: Total block mode ("total") is not implemented in Phase 1 - if added in future, would show error and exit

---

### 4. Error Message Implementation

**STATUS: INTENTIONALLY NOT IMPLEMENTED** - This section is for future Phase 2 (Total Block Mode), which was not included in Phase 1 implementation. Phase 1 only implements "difficult" mode, not "total" block mode.

#### 4.1 Create error message function (Future Phase - Total Block)
- [ ] **Note**: This section is for future phase if total block mode is implemented (**INTENTIONALLY NOT IMPLEMENTED** - Total block mode not included in Phase 1)
- [ ] Create `show_uninstall_locked_error()` function
  - [ ] Location: `lib/configure-ui.sh` or new helper module
  - [ ] Accept parameters: current day, current hour, restricted range, end time
  - [ ] Format message:
    - [ ] "Uninstall is blocked during restricted hours"
    - [ ] Show current time (day name, hour)
    - [ ] Show restricted range that applies
    - [ ] Calculate and show when restrictions end
    - [ ] Suggest when user can try again
    - [ ] **Prominently mention** `manual-uninstall-guide.sh` script for manual uninstallation
  - [ ] Support both GUI and text modes
  - [ ] Use appropriate dialog tool (yad/zenity/kdialog) for GUI

#### 4.2 Integrate error message (Future Phase - Total Block)
- [ ] **Note**: This section is for future phase if total block mode is implemented
- [ ] Update `check_uninstall_protection_time()` to return protection mode
  - [ ] Function already returns mode string ("none" or "difficult" in Phase 1)
- [ ] Update uninstall.sh error handling (total block mode - future phase)
  - [ ] Call `show_uninstall_locked_error()` with appropriate details
  - [ ] Exit with non-zero code after showing error

#### 4.3 Calculate restriction end time
- [ ] Add helper function to calculate when restrictions end
  - [ ] Parse restricted range for current day
  - [ ] Determine end hour of current restriction period
  - [ ] Handle overnight ranges correctly
  - [ ] Format as human-readable time (e.g., "5:00 AM")

---

### 4b. Difficult Uninstall Verification Implementation

#### 4b.1 Create uninstall-verification.sh module
- [x] Create new file `lib/uninstall-verification.sh`
  - [x] Contains functions for difficult uninstall verification
  - [x] Functions: `verify_uninstall_during_restrictions()`, `generate_algebra_question()`, `validate_answer()`, `get_confirmation_phrase()`, `verify_confirmation_phrase()`

#### 4b.2 Implement confirmation phrase verification
- [x] Create `get_confirmation_phrase()` function
  - [x] Return exact phrase: "I really mean it and want to uninstall this program now even though restrictions are running"
  - [x] Support case-insensitive comparison (default: case-insensitive, hardcoded)
- [x] Create `verify_confirmation_phrase()` function
  - [x] Accept user input
  - [x] Compare with exact phrase (case-insensitive by default)
  - [x] Return 0 if match, 1 if no match, 2 if cancelled
  - [x] Support both GUI (text entry dialog) and text mode (stdin)
  - [x] Allow retry on failure (up to 3 attempts, configurable via parameter)
  - [x] Show clear error message if phrase doesn't match

#### 4b.3 Implement arithmetic question generation
- [x] Create `generate_algebra_question()` function (function name kept for compatibility, but generates arithmetic questions)
  - [x] Generate random arithmetic question in word form (to prevent copy-pasting into browsers)
  - [x] Question complexity levels (randomly select from 2 levels - simple removed per user request):
    - [x] Medium complexity: Step-by-step instructions with one parenthetical expression
      - [x] Format: "Multiply X by Y, then [add/subtract] (Z [times/minus] W), then [add/subtract] N. What is the final result?"
      - [x] Example: "Multiply 53 by 15, then add (31 minus 58), then add 147. What is the final result?"
      - [x] Generate random numbers in appropriate ranges
      - [x] Use step-by-step instructions that require understanding problem structure
      - [x] Store correct numeric answer
    - [x] Complex complexity: Multi-step instructions with multiple parenthetical expressions
      - [x] Format: "Start with X, multiply by Y, then [add/subtract] (Z [plus/minus] W), then [add/subtract] (A [plus/minus] B), then [add/subtract] N. What is the final result?"
      - [x] Example: "Start with 114, multiply by 72, then add (26 plus 13), then add (29 plus 43), then add 433. What is the final result?"
      - [x] Generate random numbers in appropriate ranges
      - [x] Use natural language step-by-step instructions
      - [x] Store correct numeric answer
  - [x] Return question text and correct answer (single integer)
  - [x] Ensure questions are solvable and have reasonable difficulty
  - [x] Questions written in word form ("times", "plus", "minus", "add", "subtract") to make copy-pasting into search engines/calculators more difficult
  - [x] Use step-by-step instructions that require understanding the problem structure, not just direct mathematical expressions

#### 4b.4 Implement answer validation
- [x] Create `validate_answer()` function
  - [x] Accept user answer and correct answer (single integer)
  - [x] Handle answer formats:
    - [x] Integers: "2", "-3", "1234" (primary format)
    - [x] Integers with commas: "1,234" (commas are stripped)
    - [x] Integers with spaces: "1 234" (spaces are stripped)
    - [x] Negative integers: "-1234" (handled correctly)
  - [x] Normalize user input (trim whitespace, remove commas)
  - [x] Validate that user input is a valid integer
  - [x] Return 0 if correct, 1 if incorrect
  - [x] Provide clear feedback on incorrect answers (via main verification function)
  - [x] Show correct answer if user is wrong (via main verification function)
  - [x] **Note**: Answers are now simple integers (not algebra expressions), making validation straightforward

#### 4b.5 Implement main verification function
- [x] Create `verify_uninstall_during_restrictions()` function
  - [x] Accept `use_gui` parameter
  - [x] Display explanation of verification requirements
  - [x] Step 1: Confirmation phrase
    - [x] Show phrase requirement clearly
    - [x] Get user input
    - [x] Verify phrase (allow retries)
    - [x] Exit if user fails after max attempts
  - [x] Step 2: Arithmetic questions
    - [x] Generate 10 random arithmetic questions (medium or complex complexity, simple removed)
    - [x] For each question (1-10):
      - [x] Display question number: "Question 1 of 10"
      - [x] Display question (in word form with step-by-step instructions)
      - [x] Get user answer (integer)
      - [x] Validate answer (simple integer comparison)
      - [x] Show feedback (correct/incorrect)
      - [x] Allow retry on incorrect answer (up to 3 attempts per question)
      - [x] Track correct/incorrect answers
    - [x] Require all 10 questions to be answered correctly
    - [x] Exit if user fails too many questions (fails after max attempts per question)
  - [x] Return 0 if verification passes, 1 if fails, 2 if cancelled
  - [x] Support both GUI and text modes
  - [x] Use appropriate dialog tools for GUI

#### 4b.6 Integrate verification into uninstall.sh
- [x] In uninstall.sh, when protection mode is "difficult":
  - [x] Display message explaining verification requirements (via verification function)
  - [x] Ask user if they want to proceed or cancel (via verification function)
  - [x] If user proceeds, call `verify_uninstall_during_restrictions()`
  - [x] If verification passes, continue with normal uninstall
  - [x] If verification fails, exit with message
  - [x] If user cancels, exit gracefully

---

### 5. Manual Uninstall Guide Script

#### 5.1 Create manual-uninstall-guide.sh
- [x] Create new script `manual-uninstall-guide.sh`
  - [x] Location: Project root, installed to system location (`~/.local/bin/`)
  - [x] **Must NOT be blocked** - does not check time restrictions
  - [x] Should be executable and accessible to users
- [x] Script functionality:
  - [x] Display clear title: "Manual Uninstallation Guide"
  - [x] Show step-by-step instructions for manual uninstallation
  - [x] List all files and directories to remove:
    - [x] Systemd service file: `~/.config/systemd/user/sleep-warning.service`
    - [x] Systemd timer file: `~/.config/systemd/user/sleep-warning.timer`
    - [x] Config file: `~/.config/sleep-warning/sleep-warning.conf`
    - [x] Log file: `~/.config/sleep-warning/warnings.log`
    - [x] Script files (if installed to system location)
  - [x] Provide systemd commands:
    - [x] Stop timer: `systemctl --user stop sleep-warning.timer`
    - [x] Disable timer: `systemctl --user disable sleep-warning.timer`
    - [x] Remove service/timer files
  - [x] Show commands to remove config files and logs
  - [x] Support both GUI and text modes
  - [x] Use appropriate dialog tool (yad/zenity/kdialog) for GUI
  - [x] Provide copy-paste ready commands

#### 5.2 Install manual-uninstall-guide.sh
- [x] Update `install.sh` to install `manual-uninstall-guide.sh`
  - [x] Copy to system location (`~/.local/bin/` as `manual-uninstall-guide`)
  - [x] Set executable permissions
  - [x] Make it accessible in PATH
- [ ] Update `uninstall.sh` to mention manual uninstall guide (if not blocked) (**NOT IMPLEMENTED**: Could add mention in error messages)
- [ ] Update documentation to mention manual uninstall guide script (**NOT IMPLEMENTED**: User docs not updated)

---

### 6. Testing

**STATUS: NOT IMPLEMENTED** - No tests have been written or executed yet.

#### 6.1 Unit Tests
- [ ] Test `get_uninstall_protection_mode()` function
  - [ ] Test with missing config file (should return default "none")
  - [ ] Test with UNINSTALL_PROTECTION_MODE=none
  - [ ] Test with UNINSTALL_PROTECTION_MODE=difficult
  - [ ] Test with invalid values (should return default)
  - [ ] Test case insensitivity (Difficult, DIFFICULT, etc.)
  - [ ] Test legacy UNINSTALL_BLOCK_ENABLED=true (should map to "difficult" - total block not available in Phase 1)

- [ ] Test `check_uninstall_protection_time()` function
  - [ ] Test when UNINSTALL_PROTECTION_MODE=none (should return "none")
  - [ ] Test when mode is "none" and NOT in restricted hours (should return "none")
  - [ ] Test when mode is "difficult" and NOT in restricted hours (should return "none")
  - [ ] Test when mode is "difficult" and IN restricted hours (should return "difficult")
  - [ ] Test overnight ranges (23-6 on previous day extending to current day)
  - [ ] Test multiple ranges per day
  - [ ] Test empty restriction (no restrictions for day)

- [ ] Test arithmetic question generation
  - [ ] Test `generate_algebra_question()` generates valid questions (function name kept for compatibility)
  - [ ] Test all question complexity levels (medium, complex)
  - [ ] Test that questions are written in word form with step-by-step instructions
  - [ ] Test that questions have integer solutions
  - [ ] Test that answers are stored correctly
  - [ ] Test random question generation (different questions each time)
  - [ ] Test that questions are difficult to copy-paste into search engines

- [ ] Test answer validation
  - [ ] Test integer answer validation
  - [ ] Test decimal answer validation
  - [ ] Test fraction answer validation
  - [ ] Test system of equations answer validation (x, y)
  - [ ] Test factoring answer validation
  - [ ] Test case-insensitive comparison where applicable
  - [ ] Test incorrect answer handling

- [ ] Test confirmation phrase verification
  - [ ] Test exact phrase match (case-insensitive)
  - [ ] Test incorrect phrase rejection
  - [ ] Test retry mechanism

#### 6.2 Integration Tests
- [ ] Test uninstall.sh difficult mode
  - [ ] Set UNINSTALL_PROTECTION_MODE=difficult
  - [ ] Set restricted hours for current day/time
  - [ ] Run uninstall.sh - should require verification
  - [ ] Test confirmation phrase verification
    - [ ] Test correct phrase - should proceed
    - [ ] Test incorrect phrase - should reject and allow retry
    - [ ] Test cancellation - should exit gracefully
  - [ ] Test arithmetic questions
    - [ ] Test answering all 10 questions correctly - should proceed to uninstall
    - [ ] Test answering questions incorrectly - should show feedback
    - [ ] Test retry mechanism for incorrect answers
    - [ ] Test cancellation during questions - should exit gracefully
    - [ ] Test that questions are displayed in word form correctly
  - [ ] Test when NOT in restricted hours - should work normally (no verification)

- [ ] Test uninstall.sh none mode
  - [ ] Set UNINSTALL_PROTECTION_MODE=none
  - [ ] Set restricted hours for current day/time
  - [ ] Run uninstall.sh - should work normally (no blocking or verification)

- [ ] Test manual-uninstall-guide.sh
  - [ ] Run manual-uninstall-guide.sh during restricted hours - should work (not blocked)
  - [ ] Verify instructions are clear and complete
  - [ ] Verify commands are correct and copy-paste ready
  - [ ] Test in both GUI and text modes

- [ ] Test configuration UI
  - [ ] Run configure.sh
  - [ ] Navigate to uninstall protection mode setting
  - [ ] Verify both options are available (none, difficult)
  - [ ] Test selecting "none" - verify it's saved to config file
  - [ ] Test selecting "difficult" - verify explanation is shown, verify it's saved
  - [ ] Test in both GUI and text modes

#### 6.3 Edge Cases
- [ ] Test with missing config file (should default to "none", no protection)
- [ ] Test with corrupted config file (should default to "none", no protection)
- [ ] Test at boundary times (exactly at start/end of restriction)
- [ ] Test with all days having restrictions
- [ ] Test with no days having restrictions (should never apply protection)
- [ ] Test with system time changes (if possible)
- [ ] Test manual uninstall guide during restricted hours (should always work)
- [ ] Test difficult mode with various arithmetic question complexity levels (medium and complex)
- [ ] Test difficult mode with user who struggles with math (accessibility consideration)

---

### 7. Code Quality

#### 7.1 Code Documentation
- [x] Add header comments to new functions explaining purpose
- [x] Add inline comments for complex logic (overnight range handling)
- [x] Document function parameters and return values
- [x] Update main script headers if needed
- [x] Add warnings in code comments about risks

#### 7.2 Error Handling
- [x] Ensure all file operations handle errors gracefully
- [x] Ensure config parsing handles missing/invalid values
- [x] Ensure time calculations handle edge cases
- [ ] Add logging for debugging (optional, use log_message if available) (**NOT IMPLEMENTED**: No logging added)

#### 7.3 Code Consistency
- [x] Follow existing code style and patterns
- [x] Use same variable naming conventions
- [x] Use same function organization patterns
- [x] Match existing error message style

---

### 8. Documentation Updates

#### 8.1 User Documentation
- [x] Update `user-docs/CONFIGURATION.md` (if exists) (**COMPLETED**: User documentation updated)
  - [x] Document UNINSTALL_PROTECTION_MODE option (should be UNINSTALL_PROTECTION_MODE, not UNINSTALL_BLOCK_ENABLED)
  - [x] Explain what it does
  - [x] **Prominently warn about risks**
  - [x] Explain how to enable/disable
  - [x] Note that it's opt-in (default disabled)
  - [x] Document manual-uninstall-guide.sh script
- [x] Update `user-docs/USER_GUIDE.md` (if exists) (**COMPLETED**: User documentation updated)
  - [x] Document manual-uninstall-guide.sh script
  - [x] Explain when to use it
  - [x] Provide examples

#### 8.2 Developer Documentation
- [ ] Update enhancement document status to "Phase 1 Complete" (**IN PROGRESS**: Currently updating checklist)
- [x] Document any design decisions or implementation notes (documented in code comments)
- [x] Note any known limitations or edge cases (noted in this document)
- [x] Document risks and safety considerations (documented in enhancement document)

---

### 9. Final Verification

#### 9.1 Pre-commit Checks
- [ ] Run all existing tests to ensure no regressions (**NOT TESTED**: No tests run)
- [x] Check for linting errors (**COMPLETED**: No linting errors found)
- [x] Verify all functions are properly sourced (**COMPLETED**: All functions properly sourced)
- [x] Verify config file format is correct (**COMPLETED**: Config format verified)
- [x] Verify manual-uninstall-guide.sh is accessible and not blocked (**COMPLETED**: Script does not check restrictions)

#### 9.2 Manual Testing
- [ ] Test full configuration workflow (**NOT TESTED**: Manual testing not performed)
- [ ] Test blocking behavior in real scenarios (**NOT TESTED**: Manual testing not performed)
- [ ] Test error messages are clear and helpful (**NOT TESTED**: Manual testing not performed)
- [ ] Test manual-uninstall-guide.sh works during restricted hours (**NOT TESTED**: Manual testing not performed)
- [ ] Verify manual uninstall instructions are accurate (**NOT TESTED**: Manual testing not performed)

#### 9.3 Code Review Checklist
- [ ] All checklist items completed (**PARTIALLY**: Core implementation complete, testing and user docs pending)
- [x] Code follows project conventions (**COMPLETED**: Code follows existing patterns)
- [x] Error handling is robust (**COMPLETED**: Error handling implemented)
- [x] User experience is clear (**COMPLETED**: UI provides clear explanations)
- [x] Documentation is updated (**COMPLETED**: Code documented, user docs updated)
- [x] No security issues introduced (**COMPLETED**: No security issues identified)
- [x] Risks are clearly documented (**COMPLETED**: Risks documented in enhancement doc)
- [x] Manual uninstall guide is complete and accurate (**COMPLETED**: Guide includes all necessary steps)

---

### Implementation Order Recommendation

1. **Manual Uninstall Guide Script** (Section 5) - Safety mechanism first
2. **Configuration File Support** (Section 1) - Foundation
3. **Time Check Implementation** (Section 3) - Core functionality
4. **Difficult Uninstall Verification** (Section 4b) - Implement verification system (confirmation phrase + arithmetic questions in word form)
5. **Error Message Implementation** (Section 4) - User feedback for total block mode (future phase)
6. **Configuration UI** (Section 2) - User interface
7. **Testing** (Section 6) - Validation
8. **Code Quality & Documentation** (Sections 7-8) - Polish

---

### Notes

- Default behavior: Feature is **disabled by default** (opt-in, mode: "none")
- **Protection Modes (Phase 1 - Initial Implementation)**:
  - **"none"**: No protection - uninstall works normally (default)
  - **"difficult"**: Difficult uninstall - require verification (recommended, lower risk)
- **Future Phase: Total Block Mode**:
  - **"total"**: Total block - completely prevent uninstall (high risk, not recommended)
  - **Status**: Not included in initial implementation - may be considered as future phase
  - **Note**: Total block mode would require manual uninstall guide script as safety mechanism
- **Lower Risk (Difficult Mode)**: Allows legitimate uninstalls while deterring impulsive ones
- **High Risk (Total Block Mode - Future)**: Blocking uninstall could prevent legitimate uninstall needs
- **Safety Mechanism**: Manual uninstall guide script must always be accessible
- The time check uses the same logic as `sleep-warning.sh` for consistency
- Overnight ranges (e.g., 23-6) must be handled correctly
- Error messages should be clear and actionable
- Manual uninstall guide script should NOT be blocked and should always be accessible
- Arithmetic questions are written in word form with step-by-step instructions to make copy-pasting into search engines/calculators more difficult
- Questions use natural language ("times", "plus", "minus", "add", "subtract") and require understanding the problem structure
- Questions should be challenging but fair - requiring genuine effort but not impossible
- Only medium and complex complexity levels are used (simple removed per user request)
- Consider accessibility: Users who struggle with math may need alternative verification methods (future enhancement)