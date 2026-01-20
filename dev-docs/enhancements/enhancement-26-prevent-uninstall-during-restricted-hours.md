# Enhancement 26: Prevent uninstall.sh Execution During Restricted Hours

- **Description**: Prevent `uninstall.sh` from running during restricted hours (Phase 1) and optionally during additional configurable hours (Phase 2) to prevent users from circumventing restrictions by uninstalling the system. This is a **risky** feature that could lock users out if they need to uninstall during restricted hours. A companion script will provide instructions for manual uninstallation.
- **Files Affected**: `uninstall.sh`, `sleep-warning.sh`, `sleep-warning.conf`, new `manual-uninstall-guide.sh`
- **Priority**: Medium (security/self-control feature, but risky - could prevent legitimate uninstall needs)
- **Status**: Not implemented
- **Feasibility Assessment**: ✅ **Highly Feasible** - Simple time check at script start, similar to Enhancement #19
- **Risk Assessment**: ⚠️ **HIGH RISK** - Blocking uninstall during restricted hours could prevent users from removing the system when needed (e.g., system issues, emergency situations, legitimate need to uninstall). This feature should be:
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
      2. **Algebra Questions**: User must correctly answer 10 difficult algebra questions (e.g., quadratic equations, systems of equations, polynomial factoring)
      3. **Question Generation**: Generate random algebra questions of appropriate difficulty (high school/college level)
      4. **Validation**: Verify answers are correct before allowing uninstall to proceed
    - **Pros**: 
      - Allows legitimate uninstalls while deterring impulsive ones
      - Requires cognitive engagement and effort, making it difficult to uninstall impulsively
      - Lower risk than total block - users can still uninstall if they really need to
      - More user-friendly than complete blocking
    - **Cons**: 
      - More complex to implement (requires question generation and answer validation)
      - Determined users can still uninstall if they complete the verification
      - May frustrate users who need to uninstall but struggle with math
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
      - `difficult`: Difficult uninstall - require confirmation phrase + 10 algebra questions (recommended, lower risk)
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
    - **Algebra Question Generation**:
      - Generate 10 random algebra questions of appropriate difficulty
      - Question types (mix randomly):
        - Quadratic equations: `ax² + bx + c = 0` (solve for x)
        - Systems of linear equations: `ax + by = c, dx + ey = f` (solve for x, y)
        - Polynomial factoring: Factor `ax² + bx + c` or similar
        - Rational expressions: Simplify or solve rational equations
        - Radical equations: Solve equations with square roots
      - Difficulty levels: High school to early college level
      - Ensure questions have integer or simple fractional solutions (for easier validation)
      - Store correct answers for validation
    - **Answer Validation**:
      - Accept numeric answers (integers, fractions, decimals)
      - Handle multiple solution formats (e.g., "2", "2.0", "4/2", "-2" for systems)
      - For systems of equations: Require both x and y values
      - For factoring: Accept factored form or verify factorization
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
    - **For Difficult Uninstall Mode**: Proceed to verification process (confirmation phrase + algebra questions) if in restricted hours
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
    - List requirements: "1. Type a confirmation phrase", "2. Answer 10 algebra questions correctly"
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
  - **Question Difficulty**: Algebra questions should be challenging but fair - not impossible, but requiring genuine effort
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
Prevent `uninstall.sh` from running during restricted hours when `UNINSTALL_BLOCK_ENABLED=true`. This is a user-configurable, opt-in feature (default: disabled) with **high risk** of preventing legitimate uninstall needs. A manual uninstall guide script must be provided as a safety mechanism.

### Files to Modify

#### Core Files
- `lib/config.sh` - Add function to read UNINSTALL_PROTECTION_MODE
- `lib/configure-config.sh` - Load and save UNINSTALL_PROTECTION_MODE
- `lib/configure-display.sh` - Add menu option for uninstall protection mode setting
- `lib/configure-ui.sh` - Add dialog function for uninstall protection mode setting
- `lib/uninstall-verification.sh` - New module for difficult uninstall verification (confirmation phrase + algebra questions)
- `uninstall.sh` - Add time check at startup, implement protection modes
- `sleep-warning.conf` - Add UNINSTALL_PROTECTION_MODE documentation

#### New Files
- `manual-uninstall-guide.sh` - Script providing step-by-step manual uninstallation instructions
- `lib/uninstall-verification.sh` - Module for generating algebra questions and validating answers

#### Documentation
- `dev-docs/enhancements/enhancement-26-prevent-uninstall-during-restricted-hours.md` - Update status when complete
- `user-docs/CONFIGURATION.md` - Document UNINSTALL_BLOCK_ENABLED option with warnings
- `user-docs/USER_GUIDE.md` - Document manual uninstall guide script

---

### 1. Configuration File Support

#### 1.1 Add UNINSTALL_PROTECTION_MODE to config.sh
- [ ] Add default value constant: `DEFAULT_UNINSTALL_PROTECTION_MODE="none"`
- [ ] Add function `get_uninstall_protection_mode()` in `lib/config.sh`
  - [ ] Read `UNINSTALL_PROTECTION_MODE` from config file
  - [ ] Validate value (none/difficult)
  - [ ] Return default if missing or invalid
  - [ ] Normalize output to lowercase: "none" or "difficult"
  - [ ] Handle legacy `UNINSTALL_BLOCK_ENABLED` for backward compatibility (if true, set mode to "difficult" - total block not available in Phase 1)

#### 1.2 Update configure-config.sh
- [ ] Add `uninstall_protection_mode` to global variables in `load_existing_config()`
  - [ ] Initialize with default: `declare -g uninstall_protection_mode="none"`
  - [ ] Read existing value from config file (if present)
  - [ ] Validate and normalize to "none" or "difficult"
  - [ ] Handle legacy `UNINSTALL_BLOCK_ENABLED` for backward compatibility
- [ ] Update `write_config()` function signature
  - [ ] Add `uninstall_protection_mode` as parameter (7th parameter, after `configure_block_enabled`)
  - [ ] Write `UNINSTALL_PROTECTION_MODE=${uninstall_protection_mode}` to config file
  - [ ] Add comment header explaining the option
  - [ ] Place after `CONFIGURE_BLOCK_ENABLED` section in config file

#### 1.3 Update configure.sh main function
- [ ] Add `uninstall_protection_mode` to global variable declarations
  - [ ] Add to: `declare -g check_interval popup_size popup_position min_display_time popup_immovable configure_block_enabled uninstall_protection_mode`
- [ ] Update `write_config()` call
  - [ ] Add `${uninstall_protection_mode}` as 7th argument

#### 1.4 Update config file template
- [ ] Add `UNINSTALL_PROTECTION_MODE` section to `sleep-warning.conf` template
  - [ ] Add comment explaining the feature and available modes
  - [ ] Add default value: `UNINSTALL_PROTECTION_MODE=none`
  - [ ] Explain each mode: none (no protection), difficult (verification required, recommended)
  - [ ] Note that total block mode may be considered as future phase
  - [ ] Place after `CONFIGURE_BLOCK_ENABLED` section

---

### 2. Configuration UI - Menu Option

#### 2.1 Add menu option to configure-display.sh
- [ ] Update `show_main_menu()` function
  - [ ] Add new menu option for "Uninstall Blocking" (or integrate into existing "Security Settings" option)
  - [ ] Add status indicator showing current state (Enabled/Disabled)
  - [ ] Update both GUI and text mode menus
  - [ ] Add warning indicator if enabled

#### 2.2 Add dialog function to configure-input.sh
- [ ] Create `get_uninstall_protection_mode_config()` function
  - [ ] Accept `use_gui` parameter
  - [ ] Show current setting (none/difficult)
  - [ ] Present options:
    - [ ] "No Protection" (none) - Uninstall works normally
    - [ ] "Difficult Uninstall (Recommended)" (difficult) - Require verification to uninstall
  - [ ] **Explain "difficult" mode**:
    - [ ] Explain that it requires confirmation phrase + 10 algebra questions
    - [ ] Explain that it allows legitimate uninstalls while deterring impulsive ones
    - [ ] Note that total block mode may be considered as future phase
  - [ ] Ask user to select mode
  - [ ] Return "none" or "difficult" string
  - [ ] Handle cancellation (return "CANCELLED")
  - [ ] Support both GUI and text modes
  - [ ] Include clear explanation of what each mode does

#### 2.3 Add menu handler to configure.sh
- [ ] Add case for menu option (or integrate into Security Settings)
  - [ ] Call `get_uninstall_protection_mode_config()`
  - [ ] Handle "CANCELLED" response (exit if cancelled)
  - [ ] Update global `uninstall_protection_mode` variable
  - [ ] Return to main menu after setting

---

### 3. Time Check Implementation

#### 3.1 Create time check function
- [ ] Create `check_uninstall_protection_time()` function
  - [ ] Location: Add to `lib/time-validation.sh` OR create new `lib/uninstall-protection.sh`
  - [ ] Function should:
    - [ ] Read `UNINSTALL_PROTECTION_MODE` from config (use `get_uninstall_protection_mode()`)
    - [ ] Return mode string ("none" or "difficult") if in restricted hours
    - [ ] Return "none" if not in restricted hours or mode is "none"
    - [ ] Get current day of week (0=Sunday, 6=Saturday)
    - [ ] Get current hour (0-23)
    - [ ] Parse config for current day using `parse_config()`
    - [ ] Check if current hour is restricted using `is_restricted_hour()`
    - [ ] Handle overnight ranges from previous day (same logic as sleep-warning.sh)
    - [ ] Return "none" if NOT in restricted hours (allow execution)
    - [ ] Return protection mode ("difficult") if IN restricted hours

#### 3.2 Add time check to uninstall.sh
- [ ] Source required modules at top of script
  - [ ] Ensure `lib/config.sh` is sourced
  - [ ] Ensure `lib/time-validation.sh` is sourced
  - [ ] Source `lib/uninstall-verification.sh` (for difficult mode)
- [ ] Add time check at start of `main()` function
  - [ ] Call `check_uninstall_protection_time()` BEFORE showing any dialogs
  - [ ] If mode is "difficult", proceed to verification process
  - [ ] If mode is "none", proceed normally
  - [ ] **Note**: Total block mode ("total") is not implemented in Phase 1 - if added in future, would show error and exit

---

### 4. Error Message Implementation

#### 4.1 Create error message function (Future Phase - Total Block)
- [ ] **Note**: This section is for future phase if total block mode is implemented
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
- [ ] Create new file `lib/uninstall-verification.sh`
  - [ ] Contains functions for difficult uninstall verification
  - [ ] Functions: `verify_uninstall_during_restrictions()`, `generate_algebra_question()`, `validate_answer()`, `get_confirmation_phrase()`

#### 4b.2 Implement confirmation phrase verification
- [ ] Create `get_confirmation_phrase()` function
  - [ ] Return exact phrase: "I really mean it and want to uninstall this program now even though restrictions are running"
  - [ ] Support case-insensitive comparison (configurable, default: case-insensitive)
- [ ] Create `verify_confirmation_phrase()` function
  - [ ] Accept user input
  - [ ] Compare with exact phrase (case-insensitive by default)
  - [ ] Return 0 if match, 1 if no match
  - [ ] Support both GUI (text entry dialog) and text mode (stdin)
  - [ ] Allow retry on failure (up to 3 attempts, configurable)
  - [ ] Show clear error message if phrase doesn't match

#### 4b.3 Implement algebra question generation
- [ ] Create `generate_algebra_question()` function
  - [ ] Generate random algebra question of appropriate difficulty
  - [ ] Question types (randomly select):
    - [ ] Quadratic equations: `ax² + bx + c = 0` (solve for x)
      - [ ] Generate random coefficients (a, b, c)
      - [ ] Ensure solutions are integers or simple fractions
      - [ ] Store correct answer(s)
    - [ ] Systems of linear equations: `ax + by = c, dx + ey = f` (solve for x, y)
      - [ ] Generate random coefficients
      - [ ] Ensure integer solutions
      - [ ] Store both x and y values
    - [ ] Polynomial factoring: Factor `ax² + bx + c` or similar
      - [ ] Generate factorable polynomials
      - [ ] Store factored form as answer
    - [ ] Rational expressions: Simplify or solve rational equations
      - [ ] Generate appropriate rational expressions
      - [ ] Store simplified form or solution
    - [ ] Radical equations: Solve equations with square roots
      - [ ] Generate equations with integer solutions
      - [ ] Store solution
  - [ ] Return question text and correct answer(s)
  - [ ] Ensure questions are solvable and have reasonable difficulty

#### 4b.4 Implement answer validation
- [ ] Create `validate_answer()` function
  - [ ] Accept user answer and correct answer(s)
  - [ ] Handle multiple answer formats:
    - [ ] Integers: "2", "-3"
    - [ ] Decimals: "2.0", "-3.5"
    - [ ] Fractions: "4/2", "-6/3"
    - [ ] For systems: "x=2, y=3" or "2,3" or separate inputs
    - [ ] For factoring: Accept factored form or verify factorization
  - [ ] Normalize and compare answers
  - [ ] Return 0 if correct, 1 if incorrect
  - [ ] Provide clear feedback on incorrect answers
  - [ ] Show correct answer if user is wrong

#### 4b.5 Implement main verification function
- [ ] Create `verify_uninstall_during_restrictions()` function
  - [ ] Accept `use_gui` parameter
  - [ ] Display explanation of verification requirements
  - [ ] Step 1: Confirmation phrase
    - [ ] Show phrase requirement clearly
    - [ ] Get user input
    - [ ] Verify phrase (allow retries)
    - [ ] Exit if user fails after max attempts
  - [ ] Step 2: Algebra questions
    - [ ] Generate 10 random algebra questions
    - [ ] For each question (1-10):
      - [ ] Display question number: "Question 1 of 10"
      - [ ] Display question
      - [ ] Get user answer
      - [ ] Validate answer
      - [ ] Show feedback (correct/incorrect)
      - [ ] Allow retry on incorrect answer (up to 3 attempts per question)
      - [ ] Track correct/incorrect answers
    - [ ] Require all 10 questions to be answered correctly
    - [ ] Exit if user fails too many questions (configurable threshold)
  - [ ] Return 0 if verification passes, 1 if fails
  - [ ] Support both GUI and text modes
  - [ ] Use appropriate dialog tools for GUI

#### 4b.6 Integrate verification into uninstall.sh
- [ ] In uninstall.sh, when protection mode is "difficult":
  - [ ] Display message explaining verification requirements
  - [ ] Ask user if they want to proceed or cancel
  - [ ] If user proceeds, call `verify_uninstall_during_restrictions()`
  - [ ] If verification passes, continue with normal uninstall
  - [ ] If verification fails, exit with message
  - [ ] If user cancels, exit gracefully

---

### 5. Manual Uninstall Guide Script

#### 5.1 Create manual-uninstall-guide.sh
- [ ] Create new script `manual-uninstall-guide.sh`
  - [ ] Location: Project root, installed to system location (e.g., `/usr/local/bin/` or `~/.local/bin/`)
  - [ ] **Must NOT be blocked** - should not check time restrictions
  - [ ] Should be executable and accessible to users
- [ ] Script functionality:
  - [ ] Display clear title: "Manual Uninstallation Guide"
  - [ ] Show step-by-step instructions for manual uninstallation
  - [ ] List all files and directories to remove:
    - [ ] Systemd service file: `~/.config/systemd/user/sleep-warning.service`
    - [ ] Systemd timer file: `~/.config/systemd/user/sleep-warning.timer`
    - [ ] Config file: `~/.config/sleep-warning/sleep-warning.conf`
    - [ ] Log file: `~/.config/sleep-warning/warnings.log`
    - [ ] Script files (if installed to system location)
  - [ ] Provide systemd commands:
    - [ ] Stop timer: `systemctl --user stop sleep-warning.timer`
    - [ ] Disable timer: `systemctl --user disable sleep-warning.timer`
    - [ ] Remove service/timer files
  - [ ] Show commands to remove config files and logs
  - [ ] Support both GUI and text modes
  - [ ] Use appropriate dialog tool (yad/zenity/kdialog) for GUI
  - [ ] Provide copy-paste ready commands

#### 5.2 Install manual-uninstall-guide.sh
- [ ] Update `install.sh` to install `manual-uninstall-guide.sh`
  - [ ] Copy to system location (e.g., `/usr/local/bin/` or `~/.local/bin/`)
  - [ ] Set executable permissions
  - [ ] Make it accessible in PATH
- [ ] Update `uninstall.sh` to mention manual uninstall guide (if not blocked)
- [ ] Update documentation to mention manual uninstall guide script

---

### 6. Testing

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

- [ ] Test algebra question generation
  - [ ] Test `generate_algebra_question()` generates valid questions
  - [ ] Test all question types (quadratic, systems, factoring, rational, radical)
  - [ ] Test that questions have solvable answers
  - [ ] Test that answers are stored correctly
  - [ ] Test random question generation (different questions each time)

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
  - [ ] Test algebra questions
    - [ ] Test answering all 10 questions correctly - should proceed to uninstall
    - [ ] Test answering questions incorrectly - should show feedback
    - [ ] Test retry mechanism for incorrect answers
    - [ ] Test cancellation during questions - should exit gracefully
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
- [ ] Test difficult mode with various algebra question types
- [ ] Test difficult mode with user who struggles with math (accessibility consideration)

---

### 7. Code Quality

#### 7.1 Code Documentation
- [ ] Add header comments to new functions explaining purpose
- [ ] Add inline comments for complex logic (overnight range handling)
- [ ] Document function parameters and return values
- [ ] Update main script headers if needed
- [ ] Add warnings in code comments about risks

#### 7.2 Error Handling
- [ ] Ensure all file operations handle errors gracefully
- [ ] Ensure config parsing handles missing/invalid values
- [ ] Ensure time calculations handle edge cases
- [ ] Add logging for debugging (optional, use log_message if available)

#### 7.3 Code Consistency
- [ ] Follow existing code style and patterns
- [ ] Use same variable naming conventions
- [ ] Use same function organization patterns
- [ ] Match existing error message style

---

### 8. Documentation Updates

#### 8.1 User Documentation
- [ ] Update `user-docs/CONFIGURATION.md` (if exists)
  - [ ] Document UNINSTALL_BLOCK_ENABLED option
  - [ ] Explain what it does
  - [ ] **Prominently warn about risks**
  - [ ] Explain how to enable/disable
  - [ ] Note that it's opt-in (default disabled)
  - [ ] Document manual-uninstall-guide.sh script
- [ ] Update `user-docs/USER_GUIDE.md` (if exists)
  - [ ] Document manual-uninstall-guide.sh script
  - [ ] Explain when to use it
  - [ ] Provide examples

#### 8.2 Developer Documentation
- [ ] Update enhancement document status to "Phase 1 Complete"
- [ ] Document any design decisions or implementation notes
- [ ] Note any known limitations or edge cases
- [ ] Document risks and safety considerations

---

### 9. Final Verification

#### 9.1 Pre-commit Checks
- [ ] Run all existing tests to ensure no regressions
- [ ] Check for linting errors
- [ ] Verify all functions are properly sourced
- [ ] Verify config file format is correct
- [ ] Verify manual-uninstall-guide.sh is accessible and not blocked

#### 9.2 Manual Testing
- [ ] Test full configuration workflow
- [ ] Test blocking behavior in real scenarios
- [ ] Test error messages are clear and helpful
- [ ] Test manual-uninstall-guide.sh works during restricted hours
- [ ] Verify manual uninstall instructions are accurate

#### 9.3 Code Review Checklist
- [ ] All checklist items completed
- [ ] Code follows project conventions
- [ ] Error handling is robust
- [ ] User experience is clear
- [ ] Documentation is updated
- [ ] No security issues introduced
- [ ] Risks are clearly documented
- [ ] Manual uninstall guide is complete and accurate

---

### Implementation Order Recommendation

1. **Manual Uninstall Guide Script** (Section 5) - Safety mechanism first
2. **Configuration File Support** (Section 1) - Foundation
3. **Time Check Implementation** (Section 3) - Core functionality
4. **Difficult Uninstall Verification** (Section 4b) - Implement verification system (confirmation phrase + algebra questions)
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
- Algebra questions should be challenging but fair - requiring genuine effort but not impossible
- Consider accessibility: Users who struggle with math may need alternative verification methods (future enhancement)