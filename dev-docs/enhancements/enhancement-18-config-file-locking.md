# Enhancement 18: Config File Locking During Restricted Hours

- **Description**: Prevent modification of the configuration file during restricted hours (and optionally during additional configurable hours) to prevent users from circumventing restrictions by changing settings
- **Files Affected**: `sleep-warning.sh`, `configure.sh`, `uninstall.sh`, `sleep-warning.conf`
- **Priority**: Medium (security/self-control feature, but may be too restrictive for some users)
- **Status**: Not implemented
- **Feasibility Assessment**: ⚠️ **Partially Feasible (Deterrence Only)** - User-space file locking/permissions can discourage edits but cannot fully prevent a determined user from changing a user-owned config file without a privileged boundary (root/Polkit, immutable attribute, etc.).
- **Implementation Approaches**:
  - **Option 1: File Permissions (chmod)**:
    - Change file permissions to read-only (`chmod 444`) during restricted hours
    - Restore write permissions (`chmod 644`) when restrictions end
    - **Pros**: Simple, works on all filesystems, cannot be easily bypassed without root
    - **Cons**: Not a complete deterrent by itself: even if the file is read-only, many editors can still “edit” by writing a new file and renaming it over the original (rename/unlink permission is controlled by the *directory*). Users can also change permissions back on their own files.
    - **Safety**: Low-Medium (as deterrence) - prevents straightforward in-place writes, but does not prevent replace/rename or deliberate chmod changes.
  - **Option 2: Advisory File Locking (flock)**:
    - Use `flock` to acquire exclusive lock on config file during restricted hours
    - `configure.sh` checks for lock before allowing edits
    - **Pros**: Standard Unix mechanism, works across processes
    - **Cons**: Advisory only (cooperative), can be bypassed by processes that don't check lock, requires all scripts to check lock
    - **Safety**: Low - Advisory locks are cooperative and can be ignored
  - **Option 3: Lock File Marker**:
    - Create lock file (e.g., `~/.config/sleep-warning/.config_locked`) during restricted hours
    - `configure.sh` checks for lock file existence before allowing edits
    - **Pros**: Simple, easy to implement, clear indicator
    - **Cons**: Can be bypassed by deleting lock file, requires all scripts to check lock file
    - **Safety**: Low - User can delete lock file to bypass
  - **Option 4: Systemd Service Lock**:
    - Have systemd service hold exclusive lock on config file
    - Service continuously monitors and re-locks file during restricted hours
    - **Pros**: More persistent, harder to bypass without stopping service
    - **Cons**: Requires service to run continuously, adds overhead, can still be bypassed by stopping service
    - **Safety**: Medium - Requires stopping systemd service to bypass
  - **Option 5: Read-Only Mount or Bind Mount**:
    - Mount config directory as read-only during restricted hours (requires root)
    - **Pros**: Very difficult to bypass without root access
    - **Cons**: Requires root privileges, complex setup, may interfere with other operations
    - **Safety**: High - Very difficult to bypass, but requires root and complex setup
- **Recommended Approach (Deterrence-Focused, No Root)**:
  - **Option A (Strongest deterrence, moderate refactor)**: **Lock a dedicated config directory**
    - **Rationale**: `chmod 444` on the file alone is bypassable via “replace/rename” edits because directory permissions control rename/unlink. Locking a dedicated directory blocks the common editor pattern of writing a temp file then renaming it over the config.
    - **Implementation**:
      - Move config file to a dedicated folder: `~/.config/sleep-warning/config/sleep-warning.conf`
      - Keep logs/other runtime files in `~/.config/sleep-warning/` to avoid breaking logging when locking
      - During restricted hours:
        - `chmod a-w ~/.config/sleep-warning/config` (e.g., `555`)
        - `chmod a-w ~/.config/sleep-warning/config/sleep-warning.conf` (e.g., `444`)
      - Outside restricted hours: restore the prior directory/file modes (prefer restoring the previous mode rather than hardcoding)
      - Add a one-time migration: if the old config exists at `~/.config/sleep-warning/sleep-warning.conf` and the new one does not, move/copy it into the new location
  - **Option B (Minimal refactor, weaker deterrence)**: **Read-only file + marker + “self-heal”**
    - **Rationale**: If we keep the config in the same directory as logs, we cannot safely make the whole directory non-writable without breaking log writes. In that case, we can still discourage edits by making the file read-only and reverting changes that occur during restricted hours.
    - **Implementation**:
      - During restricted hours:
        - `chmod a-w ~/.config/sleep-warning/sleep-warning.conf`
        - Create a marker file `~/.config/sleep-warning/.config_locked` containing: timestamp, reason, and the prior file mode (so it can be restored accurately)
        - Save a snapshot copy at lock start (e.g., `~/.config/sleep-warning/.config_locked_snapshot`)
      - While locked (each timer tick / each `sleep-warning.sh` run):
        - Re-assert `chmod a-w`
        - If the config file was replaced/modified/deleted, restore from snapshot and re-assert `chmod a-w`
      - Outside restricted hours: restore prior file mode and remove marker/snapshot
- **Implementation Notes**:
  - **Config Options**:
    - `CONFIG_LOCK_ENABLED=true/false` - Enable/disable config file locking (default: `false`)
    - **⚠️ Safety Restriction**: Config file locking should **NOT** be enabled/allowed if the user has configured restrictions totaling more than 9660 minutes per week (> 23 hours/day). This prevents accidental lockout scenarios where users cannot modify their configuration during the very limited unrestricted time. See Enhancement #22 (Prevent 24/7 Restriction Configuration) for details on restriction coverage calculation and validation. If high restriction levels are detected, `CONFIG_LOCK_ENABLED` should be automatically set to `false` and the user should be informed why.
    - **Additional lock hours (optional, separate from restriction hours)**:
      - **Preferred (grep-friendly, matches existing day-based style)**:
        - `CONFIG_LOCK_HOURS_SUNDAY=START-END`
        - `CONFIG_LOCK_HOURS_MONDAY=START-END`
        - `CONFIG_LOCK_HOURS_TUESDAY=START-END`
        - `CONFIG_LOCK_HOURS_WEDNESDAY=START-END`
        - `CONFIG_LOCK_HOURS_THURSDAY=START-END`
        - `CONFIG_LOCK_HOURS_FRIDAY=START-END`
        - `CONFIG_LOCK_HOURS_SATURDAY=START-END`
        - Values may be empty to disable for that day; support comma-separated ranges if desired (same as restriction hours)
      - **Alternative (compact)**:
        - `CONFIG_LOCK_HOURS=SUNDAY=START-END,MONDAY=START-END,...`
    - Lock should apply during restricted hours **and** any configured additional lock hours (see Enhancement #20 for the expanded UX/config UI).
  - **Lock Mechanism**:
    - Prefer idempotent "apply lock state" logic that runs every `sleep-warning.sh` invocation (in `lib/config.sh` or new `lib/config-locking.sh` module):
      - If lock-active: ensure read-only file mode (and directory mode if using Option A), and ensure marker exists
      - If not lock-active: ensure modes restored and marker removed
    - Avoid hardcoding `644`/`444` where possible; store and restore the prior mode to reduce surprises for users who intentionally changed permissions.
  - **Uninstall Handling**:
    - `uninstall.sh` must stop timer/service first: `systemctl --user stop sleep-warning.timer`
    - Wait briefly for service to exit (prevents re-locking)
    - Force restore permissions (ignore errors):
      - If using Option A: restore write permission on the config directory and config file
      - If using Option B: restore write permission on config file
    - Remove marker/snapshot files
    - Proceed with normal uninstall
  - **Edge Cases**:
    - Handle system time changes (clock adjustments)
    - Handle system sleep/resume (lock state should persist)
    - Handle manual permission changes by user (detect and warn, or re-apply lock)
    - Handle config file deletion (should be prevented during lock hours)
- **Safety Assessment**:
  - **Bypass Risk**: Medium-High - This is deterrence-only. Users can:
    - Change permissions back (their own file)
    - Replace the config file by writing a new file and renaming it over the original (unless the containing directory is non-writable)
    - Stop the timer/service and edit freely
  - **Uninstall Safety**: ✅ **Safe** - Uninstall script can always restore permissions and remove lock
  - **Data Safety**: ✅ **Safe** - No risk of data loss, only prevents writes
  - **System Safety**: ✅ **Safe** - No risk to system stability
  - **User Experience**: ⚠️ **May Frustrate Users** - Prevents legitimate config changes during restricted hours
- **Processing/Memory Burden**:
  - **Minimal** - Only requires permission change operations (very fast)
  - Lock file operations are trivial (file create/delete)
  - No continuous monitoring needed (permissions checked at script execution time)
  - **Memory**: Negligible (no additional processes or memory usage)
  - **CPU**: Negligible (only during permission change operations, which are instant)
- **User Experience Considerations**:
  - **Warning Message**: Should inform user why config cannot be edited during restricted hours
  - **Clear Feedback**: `configure.sh` (via `lib/configure-ui.sh` or `lib/configure-dialogs.sh`) should show clear message: "Configuration is locked during restricted hours. Please try again after [end time]."
  - **Optional Feature**: Should be opt-in (default: disabled) to avoid frustrating users who want flexibility
  - **Legitimate Use Cases**: May prevent users from making legitimate emergency config changes
- **Related**: 
  - Works with "Prevent configure.sh During Restricted Hours" (#19) - complementary features
  - Could use same lock mechanism for both features
  - Complements restriction system by preventing circumvention
  - **Enhancement #22 (Prevent 24/7 Restriction Configuration)**: Config file locking must be automatically disabled if restrictions exceed 9660 minutes per week (> 23 hours/day) to prevent accidental lockout. Enhancement #22 provides the validation logic to detect high restriction levels and automatically disable `CONFIG_LOCK_ENABLED` for safety.
- **Detailed Implementation Documentation**: 
  - See [enhancement-18-details/implementation-details.md](enhancement-18-details/implementation-details.md) for comprehensive details on:
    - Script architecture and execution flow
    - How locking and unlocking works
    - Marker file purpose and format
    - Self-healing mechanism
    - Complete flow examples
    - Edge case handling

---

## Implementation Checklist

### Pre-Implementation Decisions

#### Decision 1: Choose Implementation Option
- [x] **DECISION MADE**: Option A (dedicated config directory) - **CHOSEN**
  - **Rationale**: Stronger deterrence, prevents rename/replace bypass
  - **Implementation**: Move config to `~/.config/sleep-warning/config/sleep-warning.conf`
  - **Migration**: Required - see Decision 3

#### Decision 2: Variable Naming for Additional Lock Hours
- [x] **DECISION MADE**: Reuse `CONFIG_LOCK_HOURS_*` for shared lock hours - **CHOSEN**
  - **Rationale**: User wants shared lock hours for both config file locking and configure.sh blocking
  - **Analysis**: ✅ **SAFE TO REUSE** - Thorough code analysis confirms:
    - **`parse_lock_hours()` function** (`lib/config.sh` lines 481-543):
      - Generic function that reads `CONFIG_LOCK_HOURS_DAYNAME` from config file
      - Standalone function with no side effects
      - Returns time range string (e.g., "9-17") or empty string
      - No state management, no conflicts with other features
    - **Enhancement #19 usage** (`lib/time-validation.sh` lines 267-285):
      - Calls `parse_lock_hours()` to get lock hours for current day
      - Uses `is_lock_hour()` to check if current time is in lock hours
      - Blocks configure.sh if in restriction hours OR lock hours (OR logic)
    - **Enhancement #18 usage** (to be implemented):
      - Can call `parse_lock_hours()` to get lock hours for current day
      - Can use `is_lock_hour()` to check if current time is in lock hours
      - Locks config file if in restriction hours OR lock hours (OR logic)
    - **No conflicts**: 
      - Both features read the same config values independently
      - Both use OR logic (restriction hours OR lock hours)
      - No shared state or side effects
      - Function is idempotent (safe to call multiple times)
    - **Config file format**: `CONFIG_LOCK_HOURS_DAYNAME=START-END` already exists and works
    - **UI support**: Enhancement #19 already provides UI for configuring lock hours
  - **Implementation**: Enhancement #18's `is_config_lock_active()` will call `parse_lock_hours()` (already exists) to check lock hours
  - **No new parsing function needed**: Reuse existing `parse_lock_hours()` function
  - **No config file changes needed**: `CONFIG_LOCK_HOURS_*` variables already supported

#### Decision 3: Migration Strategy
- [x] **DECISION MADE**: Migration on install (if previous config exists) - **CHOSEN**
  - **When**: During `install.sh` execution, if old config exists at `~/.config/sleep-warning/sleep-warning.conf`
  - **If no old config**: Write new config directly to `~/.config/sleep-warning/config/sleep-warning.conf` from the beginning
  - **Migration safety**: 
    - Backup old config before migration
    - Verify migration success (compare checksums or file sizes)
    - Only remove old config after successful migration
  - **Rollback**: If migration fails, keep old config in place, log error, continue with old location as fallback (but this shouldn't happen if we verify)

#### Decision 4: File Mode Storage Location
- [x] **DECISION MADE**: Marker file approach - **CHOSEN**
  - **Location**: `~/.config/sleep-warning/.config_locked` (in parent directory, not in locked config subdirectory)
  - **Contents**: Timestamp, reason (restricted hours or lock hours), prior directory mode, prior file mode
  - **Rationale**: Consistent with Option B design, simple, works for Option A too

---

### Phase 1: Configuration File Support

#### 1.1 Add CONFIG_LOCK_ENABLED to config.sh
- [ ] Add default value constant: `DEFAULT_CONFIG_LOCK_ENABLED=false`
- [ ] Add function `get_config_lock_enabled()` in `lib/config.sh`
  - [ ] Read `CONFIG_LOCK_ENABLED` from config file
  - [ ] Validate value (true/false/1/0/yes/no)
  - [ ] Return default if missing or invalid
  - [ ] Normalize output to "true" or "false" string
  - [ ] Handle case insensitivity (True, TRUE, etc.)
- [ ] **Verify variable name**: Ensure `config_lock_enabled` (lowercase) doesn't conflict with existing variables
  - [ ] Check: `configure_block_enabled` (Enhancement #19) - ✅ Different name, no conflict
  - [ ] Check: `lock_hours_lines` (Enhancement #19 Phase 2) - ✅ Different purpose, no conflict

#### 1.2 Additional Lock Hours Support (Reusing Existing Infrastructure)
- [x] **DECISION MADE**: Reuse existing `CONFIG_LOCK_HOURS_*` variables and `parse_lock_hours()` function
- [ ] **No new parsing function needed**: Enhancement #18 will reuse `parse_lock_hours()` from `lib/config.sh`
  - [ ] Function already exists and reads `CONFIG_LOCK_HOURS_*` from config file
  - [ ] Function is generic and can be used by both Enhancement #19 and Enhancement #18
  - [ ] Enhancement #18's `is_config_lock_active()` will call `parse_lock_hours()` to check lock hours
  - [ ] No code changes needed in `lib/config.sh` for lock hours parsing
- [ ] **Verify integration**: Ensure `is_config_lock_active()` can access `parse_lock_hours()` function
  - [ ] Function is in `lib/config.sh` which will be sourced by `lib/config-locking.sh`
  - [ ] No conflicts with existing usage in Enhancement #19

#### 1.3 Update configure-config.sh
- [ ] Add `config_lock_enabled` to global variables in `load_existing_config()`
  - [ ] Initialize with default: `declare -g config_lock_enabled="false"`
  - [ ] Read existing value from config file (if present)
  - [ ] Validate and normalize to "true" or "false"
- [ ] Update `write_config()` function signature
  - [ ] Add `config_lock_enabled` as parameter (determine position based on existing parameters)
  - [ ] Write `CONFIG_LOCK_ENABLED=${config_lock_enabled}` to config file
  - [ ] Add comment header explaining the option
  - [ ] Place after appropriate section (after `CONFIGURE_BLOCK_ENABLED` or `UNINSTALL_PROTECTION_MODE`)
- [ ] If implementing additional lock hours, add to `load_existing_config()`:
  - [ ] Initialize `config_file_lock_hours_lines` array (or chosen variable name)
  - [ ] Load `CONFIG_FILE_LOCK_HOURS_*` lines from config file
  - [ ] Store in sparse array format matching `lock_hours_lines` pattern
- [ ] If implementing additional lock hours, update `write_config()`:
  - [ ] Accept `config_file_lock_hours_lines` array parameter
  - [ ] Write `CONFIG_FILE_LOCK_HOURS_*` lines to config file
  - [ ] Add section header explaining additional lock hours

#### 1.4 Update configure.sh main function
- [ ] Add `config_lock_enabled` to global variable declarations
  - [ ] Add to appropriate `declare -g` statement
  - [ ] Ensure it's initialized before `load_existing_config()` call
- [ ] Update `write_config()` call
  - [ ] Add `${config_lock_enabled}` as argument in correct position
  - [ ] If implementing additional lock hours, add `config_file_lock_hours_lines` array

#### 1.5 Update config file template
- [ ] Add `CONFIG_LOCK_ENABLED` section to `sleep-warning.conf` template
  - [ ] Add comment explaining the feature
  - [ ] Add default value: `CONFIG_LOCK_ENABLED=false`
  - [ ] Note about Enhancement #22 automatic disabling (> 9660 minutes)
  - [ ] Place after appropriate section
- [ ] If implementing additional lock hours, add `CONFIG_FILE_LOCK_HOURS_*` section
  - [ ] Add comment explaining additional lock hours
  - [ ] Show format: `CONFIG_FILE_LOCK_HOURS_DAYNAME=START-END`
  - [ ] Note that lock applies during restriction hours AND additional lock hours

---

### Phase 2: Lock Mechanism Implementation

#### 2.1 Create Config Locking Module
- [ ] **DECISION REQUIRED**: Create new `lib/config-locking.sh` module or add to existing `lib/config.sh`?
  - **Option 1**: New module `lib/config-locking.sh` (better separation of concerns)
  - **Option 2**: Add to `lib/config.sh` (simpler, fewer files)
  - **Recommendation**: New module `lib/config-locking.sh` for better organization
- [ ] Create module file with header comment:
  - [ ] Purpose: config file locking during restricted hours
  - [ ] Dependencies: `config.sh`, `time-validation.sh` (for time checking)
  - [ ] Functions: list all functions to be implemented

#### 2.2 Implement Lock State Check Function
- [ ] Create `is_config_lock_active()` function
  - [ ] Check if `CONFIG_LOCK_ENABLED=true` (use `get_config_lock_enabled()`)
  - [ ] If false, return 1 (not active)
  - [ ] Get current day and hour
  - [ ] Check if current time is in restricted hours (use `is_restricted_hour()` with `parse_config()`)
  - [ ] Check if current time is in lock hours (use `parse_lock_hours()` and `is_lock_hour()` - **REUSE EXISTING FUNCTIONS**)
  - [ ] Return 0 if lock should be active (in restriction hours OR lock hours), 1 if not
  - [ ] Handle overnight ranges correctly (previous day's ranges extending into current day)
    - [ ] Check previous day's restriction hours for overnight ranges
    - [ ] Check previous day's lock hours for overnight ranges (use `parse_lock_hours()` for previous day)
  - [ ] **Verify function name**: Check for conflicts with `check_config_lock_time()` (Enhancement #19) - ✅ Different purpose, no conflict
  - [ ] **Note**: This function will have similar logic to `check_config_lock_time()` but returns opposite (0=lock active, 1=not active) and checks `CONFIG_LOCK_ENABLED` instead of `CONFIGURE_BLOCK_ENABLED`

#### 2.3 Implement File and Directory Mode Storage and Retrieval (Option A)
- [ ] Create `store_lock_state()` function
  - [ ] Get current directory mode using `stat -c '%a' ~/.config/sleep-warning/config` (or `stat -f '%A'` on macOS)
  - [ ] Get current file mode using `stat -c '%a' "${CONFIG_FILE}"` (if file exists)
  - [ ] **CRITICAL**: Store ACTUAL current permissions (not defaults) - these are the "normal" permissions that must be restored
  - [ ] Store in marker file: `~/.config/sleep-warning/.config_locked` (in parent directory, accessible even when config directory is locked)
  - [ ] Format: Include timestamp, reason (restricted hours or lock hours), directory mode, file mode, marker file mode
  - [ ] Format example: `TIMESTAMP=2026-01-23T10:30:00|REASON=restricted_hours|DIR_MODE=755|FILE_MODE=644|MARKER_MODE=644`
  - [ ] **Marker file permissions**: Get current marker file permissions before writing (if file exists), or use default 644 for new file
  - [ ] Store marker file's original permissions in the marker file itself (before locking it)
  - [ ] Handle errors gracefully (directory/file doesn't exist, permission denied, etc.)
  - [ ] Create marker file with appropriate permissions (user-readable/writable, typically 644)
- [ ] Create `retrieve_lock_state()` function
  - [ ] Read state from marker file: `~/.config/sleep-warning/.config_locked`
  - [ ] Parse format to extract directory mode, file mode, and marker file mode
  - [ ] Validate format and values (must be valid octal permissions)
  - [ ] Return directory mode, file mode, and marker mode (e.g., "755 644 644") or empty string if not found/invalid
  - [ ] Handle missing marker file (return empty string - caller should use defaults as fallback)
  - [ ] Handle corrupted marker file gracefully (return empty string - caller should use defaults as fallback)
  - [ ] **CRITICAL**: If marker file is corrupted/missing, system MUST use safe defaults (755/644) but should log warning that original permissions were lost
- [ ] **Edge Case: Marker File Deleted or Edited**
  - [ ] **If marker file is deleted during lock hours**:
    - [ ] On next timer tick, `apply_config_directory_lock()` will detect marker file missing
    - [ ] **Detection**: Check if directory/file are read-only (555/444) - if so, lock was active
    - [ ] **Behavior**: If lock is active but marker missing, use safe defaults (755/644) for restoration
    - [ ] Create new marker file with defaults (DIR_MODE=755, FILE_MODE=644, MARKER_MODE=644)
    - [ ] **Note**: Original permissions are lost, but system continues to function
    - [ ] Log warning that original permissions were lost
  - [ ] **If marker file is edited/corrupted**:
    - [ ] `retrieve_lock_state()` will detect invalid format
    - [ ] Return empty string (caller uses defaults)
    - [ ] System restores using safe defaults (755/644) instead of original permissions
    - [ ] Log warning that original permissions were lost
  - [ ] **Marker file IS locked**: Marker file is locked (chmod 444) after creation to prevent accidental deletion/editing
    - [ ] Lock marker file after writing all data: `chmod 444 ~/.config/sleep-warning/.config_locked`
    - [ ] When unlocking, restore marker file permissions first, then delete it
    - [ ] This prevents accidental deletion/editing while maintaining ability to restore and delete when unlocking

#### 2.4 Implement Lock Application Function (Option A)
- [ ] Create `apply_config_directory_lock()` function
  - [ ] Check if lock should be active (call `is_config_lock_active()`)
  - [ ] If lock should be active:
    - [ ] Ensure config directory exists: `mkdir -p ~/.config/sleep-warning/config/`
    - [ ] Check if marker file exists: `~/.config/sleep-warning/.config_locked`
    - [ ] If marker doesn't exist (first lock):
      - [ ] **CRITICAL**: Get ACTUAL current permissions (not defaults) - these are the "normal" permissions
      - [ ] Store current directory mode, file mode, and marker file mode (call `store_lock_state()`)
      - [ ] Create snapshot copy: `cp "${CONFIG_FILE}" ~/.config/sleep-warning/.config_locked_snapshot` (if file exists)
      - [ ] Create marker file with timestamp, reason, and all permissions
      - [ ] Lock marker file: `chmod 444 ~/.config/sleep-warning/.config_locked` (read-only to prevent deletion/editing)
    - [ ] Set directory to read-only: `chmod a-w ~/.config/sleep-warning/config` (e.g., `chmod 555`)
    - [ ] Set file to read-only: `chmod a-w "${CONFIG_FILE}"` (e.g., `chmod 444`) (if file exists)
    - [ ] Verify lock applied (check directory, file, and marker file are not writable)
  - [ ] If lock should NOT be active:
    - [ ] Check if marker file exists
    - [ ] If marker exists (was locked, now unlocking):
      - [ ] Retrieve stored directory mode, file mode, and marker mode (call `retrieve_lock_state()`)
      - [ ] **CRITICAL**: If retrieval fails (corrupted/missing), use safe defaults (755/644) but log warning
      - [ ] **Restore marker file permissions first**: `chmod "${stored_marker_mode}" ~/.config/sleep-warning/.config_locked` (or 644 if defaults)
      - [ ] **Restore directory mode**: `chmod "${stored_dir_mode}" ~/.config/sleep-warning/config` (or 755 if defaults)
      - [ ] **Restore file mode**: `chmod "${stored_file_mode}" "${CONFIG_FILE}"` (or 644 if defaults) (if file exists)
      - [ ] **CRITICAL**: Must restore ORIGINAL permissions, not hardcoded defaults (unless marker corrupted/missing)
      - [ ] Remove marker file: `rm -f ~/.config/sleep-warning/.config_locked` (now writable, can be deleted)
      - [ ] Remove snapshot file: `rm -f ~/.config/sleep-warning/.config_locked_snapshot`
  - [ ] Make function idempotent (safe to call multiple times)
  - [ ] Handle errors gracefully (directory/file missing, permission denied, etc.)

#### 2.5 Implement Self-Healing Logic (Option A - Optional but Recommended)
- [ ] **RECOMMENDATION**: Implement marker file and self-healing for Option A
  - **Rationale**: 
    - Marker file provides state tracking (when lock was applied, why, what modes were stored)
    - Self-healing detects and prevents tampering (user deletes config file, changes permissions)
    - With directory lock, user can't rename/replace file, but could still delete it or change permissions if they have access
    - Self-healing provides defense-in-depth
  - [ ] Create `check_and_restore_config_file()` function
    - [ ] Check if lock should be active
    - [ ] If lock is active:
      - [ ] Check if config file exists
      - [ ] If file missing:
        - [ ] Restore from snapshot: `cp ~/.config/sleep-warning/.config_locked_snapshot "${CONFIG_FILE}"`
        - [ ] Re-apply read-only: `chmod a-w "${CONFIG_FILE}"` and `chmod a-w ~/.config/sleep-warning/config`
        - [ ] Log warning (if logging available)
      - [ ] If file exists, check if it was modified (compare checksum or modification time with snapshot)
      - [ ] If file was modified:
        - [ ] Restore from snapshot
        - [ ] Re-apply read-only on both directory and file
        - [ ] Log warning
      - [ ] Re-assert read-only mode on directory and file (in case user changed permissions)
    - [ ] Return 0 on success, 1 on error
  - [ ] **Note**: Self-healing is less critical with Option A (directory lock prevents most bypasses) but still recommended for robustness

#### 2.8 Source Module in sleep-warning.sh
- [ ] Add `source "${LIB_DIR}/config-locking.sh" || exit 1` to `sleep-warning.sh`
  - [ ] Place after `config.sh` source (depends on CONFIG_FILE constant)
  - [ ] Place before main function (functions needed in main)

---

### Phase 3: Integration with sleep-warning.sh

#### 3.1 Add Lock Application to Main Function
- [ ] In `sleep-warning.sh` main function, call lock application function:
  - [ ] Call `apply_config_directory_lock()` (Option A)
  - [ ] Place early in main function (before restriction checking)
  - [ ] Handle errors gracefully (don't exit on lock failure, log warning)
- [ ] Add self-healing check (recommended):
  - [ ] Call `check_and_restore_config_file()` after lock application
  - [ ] Only check if lock is active (skip if not locked)
  - [ ] Handle errors gracefully (don't exit on self-heal failure, log warning)

#### 3.2 Handle Lock State Persistence
- [ ] Ensure lock state persists across timer ticks:
  - [ ] Lock application is idempotent (safe to call every timer tick)
  - [ ] Lock state transitions correctly (locked → unlocked, unlocked → locked)
  - [ ] No race conditions between timer ticks

---

### Phase 4: Integration with configure.sh

#### 4.1 Add Lock Check Before Config Write
- [ ] In `configure.sh`, before calling `write_config()`:
  - [ ] Check if config lock is active (call `is_config_lock_active()`)
  - [ ] If lock is active:
    - [ ] Show error message (use existing dialog functions)
    - [ ] Calculate when lock ends (use `calculate_restriction_end_time()` if available)
    - [ ] Display message: "Configuration file is locked during restricted hours. Please try again after [end time]."
    - [ ] Exit or return to menu (don't call `write_config()`)
  - [ ] If lock is not active, proceed normally

#### 4.2 Add Lock Check to Configuration UI
- [ ] Update `lib/configure-ui.sh` or `lib/configure-dialogs.sh`:
  - [ ] Create `show_config_file_locked_error()` function
  - [ ] Similar to `show_config_locked_error()` (Enhancement #19) but for file locking
  - [ ] Show current time and when lock ends
  - [ ] Support both GUI and text modes
  - [ ] **Verify function name**: Check for conflicts - ✅ Different from `show_config_locked_error()`

#### 4.3 Add Configuration UI Option
- [ ] Add menu option in `lib/configure-display.sh`:
  - [ ] Add "Config File Locking" option to main menu
  - [ ] Show current state (Enabled/Disabled)
  - [ ] Update menu item count
- [ ] Add dialog function in `lib/configure-input.sh`:
  - [ ] Create `get_config_lock_enabled_config()` function
  - [ ] Show current setting
  - [ ] Ask user to enable/disable
  - [ ] Return "true" or "false" string
  - [ ] Handle cancellation
  - [ ] Support both GUI and text modes
  - [ ] **Verify function name**: Check for conflicts - ✅ Different from `get_configure_block_enabled_config()`
- [ ] Add menu handler in `configure.sh`:
  - [ ] Add case for new menu option
  - [ ] Call `get_config_lock_enabled_config()`
  - [ ] Update global `config_lock_enabled` variable
  - [ ] Return to main menu after setting

#### 4.4 Integration with Enhancement #22 (24/7 Restriction Prevention)
- [ ] In `configure.sh`, when saving configuration:
  - [ ] After `check_restriction_coverage()` validation (Enhancement #22):
    - [ ] If restrictions > 9660 minutes detected:
      - [ ] Automatically set `config_lock_enabled="false"` (override user setting)
      - [ ] Add comment to config file explaining why it's disabled
      - [ ] Show info message to user (if not already shown by Enhancement #22 warning)
  - [ ] Ensure `write_config()` receives `config_lock_enabled="false"` when high restrictions detected

---

### Phase 5: Integration with uninstall.sh

#### 5.1 Add Lock Removal to Uninstall Script
- [ ] In `uninstall.sh`, before removing config file:
  - [ ] Stop timer/service: `systemctl --user stop sleep-warning.timer`
  - [ ] Wait briefly for service to exit (2-3 seconds)
  - [ ] Force restore permissions (ignore errors):
    - [ ] If Option A: `chmod u+w ~/.config/sleep-warning/config` and `chmod u+w "${CONFIG_FILE}"`
    - [ ] If Option B: `chmod u+w "${CONFIG_FILE}"`
  - [ ] Remove marker file: `rm -f ~/.config/sleep-warning/.config_locked`
  - [ ] Remove snapshot file: `rm -f ~/.config/sleep-warning/.config_locked_snapshot`
  - [ ] Proceed with normal uninstall

#### 5.2 Handle Uninstall During Lock Hours
- [ ] Ensure uninstall always works (even during lock hours):
  - [ ] Uninstall script should NOT check lock state before restoring permissions
  - [ ] Force restore should ignore file permission errors
  - [ ] Document that uninstall always works regardless of lock state

---

### Phase 6: Migration (Option A only)

#### 6.1 Implement Migration Function
- [ ] Create `migrate_config_to_subdirectory()` function
  - [ ] Check if old config exists: `~/.config/sleep-warning/sleep-warning.conf`
  - [ ] Check if new config exists: `~/.config/sleep-warning/config/sleep-warning.conf`
  - [ ] If old exists and new doesn't:
    - [ ] Create backup of old config: `cp ~/.config/sleep-warning/sleep-warning.conf ~/.config/sleep-warning/sleep-warning.conf.backup`
    - [ ] Create config directory: `mkdir -p ~/.config/sleep-warning/config`
    - [ ] Copy (not move) old config to new location: `cp ~/.config/sleep-warning/sleep-warning.conf ~/.config/sleep-warning/config/sleep-warning.conf`
    - [ ] Verify copy succeeded:
      - [ ] Compare file sizes: `[ "$(stat -c%s old)" -eq "$(stat -c%s new)" ]`
      - [ ] Compare checksums (if available): `md5sum` or `sha256sum`
      - [ ] Verify new file is readable
    - [ ] Only remove old config after successful verification: `rm ~/.config/sleep-warning/sleep-warning.conf`
    - [ ] Log migration success (if logging available)
  - [ ] If old doesn't exist or new already exists:
    - [ ] Return 0 (nothing to migrate)
  - [ ] Return 0 on success, 1 on error
  - [ ] Handle errors gracefully (don't remove old config if migration fails)

#### 6.2 Add Migration to Install Script
- [x] **DECISION MADE**: Run migration in `install.sh` (if previous config exists) - **CHOSEN**
- [ ] Add migration call to `install.sh`:
  - [ ] After creating config directory structure
  - [ ] Before installing config file (if default config is being installed)
  - [ ] Check if migration needed (old config exists, new doesn't)
  - [ ] Call `migrate_config_to_subdirectory()`
  - [ ] Handle errors gracefully:
    - [ ] If migration fails, log warning but continue installation
    - [ ] Don't fail installation if migration fails (user can migrate manually later)
  - [ ] If no old config exists, write new config directly to `~/.config/sleep-warning/config/sleep-warning.conf`

#### 6.3 Update CONFIG_FILE Constant
- [ ] Update `CONFIG_FILE` in `lib/config.sh`:
  - [ ] Change from: `CONFIG_FILE="${CONFIG_DIR}/sleep-warning.conf"`
  - [ ] Change to: `CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"`
  - [ ] Ensure all scripts use this constant (no hardcoded paths)
  - [ ] Verify all references to config file use `CONFIG_FILE` constant

#### 6.4 Backward Compatibility
- [x] **DECISION MADE**: No backward compatibility - only use new location - **CHOSEN**
  - **Rationale**: Cleaner implementation, migration handles transition
  - **Implementation**: All code should use `CONFIG_FILE` constant which points to new location
  - [ ] Ensure no hardcoded paths to old location remain in codebase
  - [ ] Migration must succeed before system can function (old location not checked as fallback)

---

### Phase 7: Edge Cases and Error Handling

#### 7.1 Handle System Time Changes
- [ ] Lock state should adapt to time changes:
  - [ ] Lock application runs every timer tick (handles time changes automatically)
  - [ ] No cached time values (always use current time)
  - [ ] Test: Change system time during locked period (lock should persist or adapt)

#### 7.2 Handle System Sleep/Resume
- [ ] Lock state should persist across sleep/resume:
  - [ ] Lock application runs on next timer tick after resume
  - [ ] No special handling needed (idempotent lock application handles it)
  - [ ] Test: Sleep system during locked period, resume (lock should still be active)

#### 7.3 Handle Manual Permission Changes
- [ ] Detect if user manually changed permissions:
  - [ ] Option 1: Re-apply lock on next timer tick (idempotent, handles it)
  - [ ] Option 2: Check permissions match expected, warn if different
  - [ ] **Recommendation**: Option 1 (simpler, idempotent lock application)
  - [ ] Test: User manually changes file to writable during lock hours (should be re-locked)

#### 7.4 Handle Config File Deletion
- [ ] Prevent or handle config file deletion during lock hours:
  - [ ] Option B: Restore from snapshot if file deleted (self-healing)
  - [ ] Option A: Directory lock prevents deletion (stronger protection)
  - [ ] Log warning if file deleted and restored
  - [ ] Test: Delete config file during lock hours (should be restored)

#### 7.5 Handle Missing Marker File
- [ ] If marker file missing but lock should be active:
  - [ ] Treat as first lock (store current mode, create snapshot)
  - [ ] Don't fail if marker missing (graceful degradation)
  - [ ] Test: Delete marker file during lock hours (should recreate)

#### 7.6 Handle Corrupted Snapshot File
- [ ] If snapshot file corrupted or missing:
  - [ ] Log error (if logging available)
  - [ ] Don't restore (prevent data loss from corrupted snapshot)
  - [ ] Re-create snapshot on next lock cycle (if file exists)
  - [ ] Test: Corrupt snapshot file (should handle gracefully)

---

### Phase 8: Testing

#### 8.1 Unit Tests
- [ ] Test `get_config_lock_enabled()` function:
  - [ ] Test with missing config file (should return default false)
  - [ ] Test with `CONFIG_LOCK_ENABLED=true`
  - [ ] Test with `CONFIG_LOCK_ENABLED=false`
  - [ ] Test with invalid values (should return default)
  - [ ] Test case insensitivity

- [ ] Test `is_config_lock_active()` function:
  - [ ] Test when `CONFIG_LOCK_ENABLED=false` (should return inactive)
  - [ ] Test when enabled and NOT in restricted hours (should return inactive)
  - [ ] Test when enabled and IN restricted hours (should return active)
  - [ ] Test overnight ranges (previous day extending into current day)
  - [ ] Test additional lock hours (if implemented)
  - [ ] Test multiple ranges per day

- [ ] Test lock application functions:
  - [ ] Test applying lock (file becomes read-only)
  - [ ] Test removing lock (file becomes writable)
  - [ ] Test idempotency (calling multiple times has same effect)
  - [ ] Test mode storage and retrieval
  - [ ] Test with missing config file (should handle gracefully)

#### 8.2 Integration Tests
- [ ] Test lock application in `sleep-warning.sh`:
  - [ ] Run during restricted hours (lock should be applied)
  - [ ] Run outside restricted hours (lock should be removed)
  - [ ] Run multiple times (idempotency)
  - [ ] Verify file permissions change correctly

- [ ] Test `configure.sh` blocking:
  - [ ] Set `CONFIG_LOCK_ENABLED=true`
  - [ ] Set restricted hours for current time
  - [ ] Run `configure.sh` - should show error and exit
  - [ ] Run outside restricted hours - should work normally

- [ ] Test uninstall during lock hours:
  - [ ] Enable lock and set restricted hours for current time
  - [ ] Run `uninstall.sh` - should restore permissions and uninstall successfully
  - [ ] Verify permissions are restored even if lock is active

#### 8.3 Edge Case Tests
- [ ] Test system time changes:
  - [ ] Change system time during locked period
  - [ ] Verify lock state adapts correctly

- [ ] Test system sleep/resume:
  - [ ] Sleep system during locked period
  - [ ] Resume and verify lock persists

- [ ] Test manual permission changes:
  - [ ] User manually changes file to writable during lock hours
  - [ ] Verify lock is re-applied on next timer tick

- [ ] Test config file deletion (Option B):
  - [ ] Delete config file during lock hours
  - [ ] Verify file is restored from snapshot

- [ ] Test migration (Option A):
  - [ ] Old config exists, new doesn't
  - [ ] Run migration - verify config moved to subdirectory
  - [ ] Verify old config removed after successful migration
  - [ ] Test migration failure handling

#### 8.4 Enhancement #22 Integration Tests
- [ ] Test automatic disabling:
  - [ ] Configure restrictions > 9660 minutes
  - [ ] Try to enable `CONFIG_LOCK_ENABLED=true`
  - [ ] Verify it's automatically set to false
  - [ ] Verify config file comment explains why

---

### Phase 9: Documentation

#### 9.1 Code Documentation
- [ ] Add module header comments:
  - [ ] `lib/config-locking.sh` - explain purpose, dependencies, functions
  - [ ] All functions - explain parameters, return values, purpose
  - [ ] Inline comments for complex logic (mode storage, lock application)

#### 9.2 User Documentation
- [ ] Update `user-docs/CONFIGURATION.md`:
  - [ ] Document `CONFIG_LOCK_ENABLED` option
  - [ ] Explain what it does (deterrence feature)
  - [ ] Explain how to enable/disable (via configure.sh)
  - [ ] Note about Enhancement #22 automatic disabling
  - [ ] Document additional lock hours (if implemented)
  - [ ] Note limitations (deterrence only, can be bypassed)

#### 9.3 Developer Documentation
- [ ] Update `dev-docs/TECHNICAL_DETAILS.md`:
  - [ ] Document config file locking mechanism
  - [ ] Explain Option A vs Option B differences
  - [ ] Document migration process (if Option A)
  - [ ] Document integration with Enhancement #22
  - [ ] Document edge case handling

#### 9.4 Update Enhancement Document
- [ ] Update status to "Implemented" when complete
- [ ] Document any design decisions made during implementation
- [ ] Note any deviations from original plan
- [ ] Document known limitations

---

### Phase 10: Code Quality and Final Checks

#### 10.1 Variable Name Verification
- [ ] **VERIFIED**: `config_lock_enabled` - ✅ No conflicts
- [ ] **VERIFIED**: `get_config_lock_enabled()` - ✅ No conflicts
- [ ] **VERIFIED**: `is_config_lock_active()` - ✅ No conflicts
- [ ] **VERIFIED**: `apply_config_file_lock()` - ✅ No conflicts
- [ ] **VERIFIED**: `show_config_file_locked_error()` - ✅ No conflicts
- [ ] **VERIFIED**: `get_config_lock_enabled_config()` - ✅ No conflicts
- [ ] **VERIFIED**: `CONFIG_FILE_LOCK_HOURS_*` (if used) - ✅ No conflicts with `CONFIG_LOCK_HOURS_*`

#### 10.2 Code Style and Consistency
- [ ] Follow existing code style (snake_case for functions, UPPER_CASE for constants)
- [ ] Use same error handling patterns as existing code
- [ ] Use same logging patterns (if logging available)
- [ ] Match existing function organization patterns

#### 10.3 Error Handling
- [ ] All file operations handle errors gracefully
- [ ] All permission operations handle errors gracefully
- [ ] Missing files handled gracefully (don't fail, log warning)
- [ ] Invalid config values handled gracefully (use defaults)

#### 10.4 Performance
- [ ] Lock application is fast (< 100ms)
- [ ] No unnecessary file operations
- [ ] No continuous monitoring (only on timer tick)

---

### Decisions Made and Recommendations

1. ✅ **Option A vs Option B**: **Option A chosen** - Dedicated config directory for stronger deterrence
2. ✅ **Variable Naming**: **Reuse `CONFIG_LOCK_HOURS_*`** - Shared lock hours for both features, safe to reuse existing `parse_lock_hours()` function
3. ✅ **Additional Lock Hours**: **Implement now** - Reuse existing `CONFIG_LOCK_HOURS_*` infrastructure
4. ✅ **Migration Timing**: **On install** - If old config exists, migrate during `install.sh` with backup and verification
5. ✅ **Backward Compatibility**: **No fallback** - Only use new location, migration must succeed
6. ✅ **File Mode Storage**: **Marker file approach** - Store in `~/.config/sleep-warning/.config_locked` (parent directory)
7. ✅ **Self-Healing**: **Recommended** - Implement marker file and self-healing for Option A (defense-in-depth)

### Self-Healing Frequency Recommendation

**Recommendation**: Check and restore on every timer tick (every `sleep-warning.sh` execution)

**Rationale**:
- **Low overhead**: File existence and permission checks are very fast (< 10ms)
- **Immediate detection**: Catches tampering attempts quickly (within one check interval, typically 10 minutes)
- **Consistent with lock application**: Lock application already runs every timer tick, self-healing can run right after
- **Idempotent design**: Self-healing function is idempotent (safe to call multiple times)
- **Defense-in-depth**: With Option A, directory lock prevents most bypasses, but self-healing catches edge cases (file deletion, permission changes)

**Alternative (if performance becomes concern)**: Check every N timer ticks (e.g., every 3rd tick = every 30 minutes), but this is not recommended as the overhead is negligible.

**Implementation**: Call `check_and_restore_config_file()` immediately after `apply_config_directory_lock()` in `sleep-warning.sh` main function.

---

### Notes

- Default behavior: Feature is **disabled by default** (opt-in)
- Uninstall safety: `uninstall.sh` should **always** restore permissions and allow uninstall
- Enhancement #22 integration: Config locking automatically disabled if restrictions > 9660 minutes
- Deterrence only: This feature is deterrence-only and can be bypassed by determined users
- No root required: Implementation uses user-space permissions only (no sudo/root needed)
- **CRITICAL: Original Permissions Restoration**: System MUST restore the actual original permissions (stored in marker file), not hardcoded defaults. Only use defaults (755/644) as fallback if marker file is corrupted/missing.
- **Marker File Locking**: Marker file is locked (chmod 444) after creation to prevent accidental deletion/editing. Original marker permissions are stored in marker file itself (MARKER_MODE field) for restoration before deletion.