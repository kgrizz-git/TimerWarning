# Enhancement 18: Config File Locking During Restricted Hours

- **Description**: Prevent modification of the configuration file during restricted hours (and optionally during additional configurable hours) to prevent users from circumventing restrictions by changing settings
- **Files Affected**: `sleep-warning.sh`, `configure.sh`, `uninstall.sh`, `sleep-warning.conf`
- **Priority**: Medium (security/self-control feature, but may be too restrictive for some users)
- **Status**: ✅ **Implemented** (Core functionality complete, testing and documentation pending)
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

## Implementation Status Summary

**Status**: ✅ **IMPLEMENTED** (Phases 1-6, 10 complete; Phases 7-9 partially complete)

**Completed Phases**:
- ✅ Phase 1: Configuration File Support (100%)
- ✅ Phase 2: Lock Mechanism Implementation (100%)
- ✅ Phase 3: Integration with sleep-warning.sh (100%)
- ✅ Phase 4: Integration with configure.sh (100%)
- ✅ Phase 5: Integration with uninstall.sh (100%)
- ✅ Phase 6: Migration (100%)
- ✅ Phase 10: Code Quality and Final Checks (100%)

**Partially Complete**:
- ⚠️ Phase 7: Edge Cases and Error Handling (Implementation: 100%, Testing: 0%)
- ⚠️ Phase 8: Testing (0% - all tests pending)
- ⚠️ Phase 9: Documentation (Code docs: 100%, User/Developer docs: 0%)

**Key Implementation Notes**:
- All core functionality implemented and syntax-verified
- Option A (dedicated config directory) fully implemented
- Marker file locking implemented
- Self-healing mechanism implemented
- Integration with Enhancement #22 (auto-disable) implemented
- Migration function implemented and integrated into install.sh
- All error handling and edge cases addressed in code
- Testing and user/developer documentation remain pending

---

### Phase 1: Configuration File Support

#### 1.1 Add CONFIG_LOCK_ENABLED to config.sh
- [x] Add default value constant: `DEFAULT_CONFIG_LOCK_ENABLED=false`
- [x] Add function `get_config_lock_enabled()` in `lib/config.sh`
  - [x] Read `CONFIG_LOCK_ENABLED` from config file
  - [x] Validate value (true/false/1/0/yes/no)
  - [x] Return default if missing or invalid
  - [x] Normalize output to "true" or "false" string
  - [x] Handle case insensitivity (True, TRUE, etc.)
- [x] **Verify variable name**: Ensure `config_lock_enabled` (lowercase) doesn't conflict with existing variables
  - [x] Check: `configure_block_enabled` (Enhancement #19) - ✅ Different name, no conflict
  - [x] Check: `lock_hours_lines` (Enhancement #19 Phase 2) - ✅ Different purpose, no conflict

#### 1.2 Additional Lock Hours Support (Reusing Existing Infrastructure)
- [x] **DECISION MADE**: Reuse existing `CONFIG_LOCK_HOURS_*` variables and `parse_lock_hours()` function
- [x] **No new parsing function needed**: Enhancement #18 will reuse `parse_lock_hours()` from `lib/config.sh`
  - [x] Function already exists and reads `CONFIG_LOCK_HOURS_*` from config file
  - [x] Function is generic and can be used by both Enhancement #19 and Enhancement #18
  - [x] Enhancement #18's `is_config_lock_active()` will call `parse_lock_hours()` to check lock hours
  - [x] No code changes needed in `lib/config.sh` for lock hours parsing
- [x] **Verify integration**: Ensure `is_config_lock_active()` can access `parse_lock_hours()` function
  - [x] Function is in `lib/config.sh` which will be sourced by `lib/config-locking.sh`
  - [x] No conflicts with existing usage in Enhancement #19

#### 1.3 Update configure-config.sh
- [x] Add `config_lock_enabled` to global variables in `load_existing_config()`
  - [x] Initialize with default: `declare -g config_lock_enabled="false"`
  - [x] Read existing value from config file (if present)
  - [x] Validate and normalize to "true" or "false"
- [x] Update `write_config()` function signature
  - [x] Add `config_lock_enabled` as parameter (position: 11th parameter, after dialog_tool)
  - [x] Write `CONFIG_LOCK_ENABLED=${config_lock_enabled}` to config file
  - [x] Add comment header explaining the option
  - [x] Place after appropriate section (after `DIALOG_TOOL`, before end of file)
- [x] Additional lock hours: Reusing existing `CONFIG_LOCK_HOURS_*` infrastructure
  - [x] No separate `config_file_lock_hours_lines` array needed
  - [x] Uses existing `lock_hours_lines` array from Enhancement #19
  - [x] No additional write_config() changes needed for lock hours

#### 1.4 Update configure.sh main function
- [x] Add `config_lock_enabled` to global variable declarations
  - [x] Add to appropriate `declare -g` statement
  - [x] Ensure it's initialized before `load_existing_config()` call
- [x] Update `write_config()` call
  - [x] Add `${config_lock_enabled}` as argument in correct position (11th parameter)
  - [x] Additional lock hours: Uses existing `lock_hours_lines` array (no separate array needed)

#### 1.5 Update config file template
- [x] Add `CONFIG_LOCK_ENABLED` section to `sleep-warning.conf` template
  - [x] Add comment explaining the feature (in `write_config()` function)
  - [x] Add default value: `CONFIG_LOCK_ENABLED=false`
  - [x] Note about Enhancement #22 automatic disabling (> 9660 minutes)
  - [x] Place after appropriate section (after `DIALOG_TOOL`)
- [x] Additional lock hours: Reusing existing `CONFIG_LOCK_HOURS_*` section
  - [x] No separate `CONFIG_FILE_LOCK_HOURS_*` section needed
  - [x] Uses existing `CONFIG_LOCK_HOURS_*` variables from Enhancement #19
  - [x] Lock applies during restriction hours AND lock hours (shared infrastructure)

---

### Phase 2: Lock Mechanism Implementation

#### 2.1 Create Config Locking Module
- [x] **DECISION MADE**: Create new `lib/config-locking.sh` module (Option 1 chosen)
  - [x] New module `lib/config-locking.sh` created for better separation of concerns
  - [x] Better organization and maintainability
- [x] Create module file with header comment:
  - [x] Purpose: config file locking during restricted hours
  - [x] Dependencies: `config.sh`, `time-validation.sh` (for time checking)
  - [x] Functions: All functions documented in header

#### 2.2 Implement Lock State Check Function
- [x] Create `is_config_lock_active()` function
  - [x] Check if `CONFIG_LOCK_ENABLED=true` (use `get_config_lock_enabled()`)
  - [x] If false, return 1 (not active)
  - [x] Get current day and hour
  - [x] Check if current time is in restricted hours (use `is_restricted_hour()` with `parse_config()`)
  - [x] Check if current time is in lock hours (use `parse_lock_hours()` and `is_lock_hour()` - **REUSE EXISTING FUNCTIONS**)
  - [x] Return 0 if lock should be active (in restriction hours OR lock hours), 1 if not
  - [x] Handle overnight ranges correctly (previous day's ranges extending into current day)
    - [x] Check previous day's restriction hours for overnight ranges
    - [x] Check previous day's lock hours for overnight ranges (use `parse_lock_hours()` for previous day)
  - [x] **Verify function name**: Check for conflicts with `check_config_lock_time()` (Enhancement #19) - ✅ Different purpose, no conflict
  - [x] **Note**: This function has similar logic to `check_config_lock_time()` but returns opposite (0=lock active, 1=not active) and checks `CONFIG_LOCK_ENABLED` instead of `CONFIGURE_BLOCK_ENABLED`

#### 2.3 Implement File and Directory Mode Storage and Retrieval (Option A)
- [x] Create `store_lock_state()` function
  - [x] Get current directory mode using `stat -c '%a' ~/.config/sleep-warning/config` (or `stat -f '%A'` on macOS)
  - [x] Get current file mode using `stat -c '%a' "${CONFIG_FILE}"` (if file exists)
  - [x] **CRITICAL**: Store ACTUAL current permissions (not defaults) - these are the "normal" permissions that must be restored
  - [x] Store in marker file: `~/.config/sleep-warning/.config_locked` (in parent directory, accessible even when config directory is locked)
  - [x] Format: Include timestamp, reason (restricted hours or lock hours), directory mode, file mode, marker file mode
  - [x] Format example: `TIMESTAMP=2026-01-23T10:30:00|REASON=restricted_hours|DIR_MODE=755|FILE_MODE=644|MARKER_MODE=644`
  - [x] **Marker file permissions**: Get current marker file permissions before writing (if file exists), or use default 644 for new file
  - [x] Store marker file's original permissions in the marker file itself (before locking it)
  - [x] Handle errors gracefully (directory/file doesn't exist, permission denied, etc.)
  - [x] Create marker file with appropriate permissions (user-readable/writable, typically 644)
- [x] Create `retrieve_lock_state()` function
  - [x] Read state from marker file: `~/.config/sleep-warning/.config_locked`
  - [x] Parse format to extract directory mode, file mode, and marker file mode
  - [x] Validate format and values (must be valid octal permissions)
  - [x] Return directory mode, file mode, and marker mode (e.g., "755 644 644") or empty string if not found/invalid
  - [x] Handle missing marker file (return empty string - caller should use defaults as fallback)
  - [x] Handle corrupted marker file gracefully (return empty string - caller should use defaults as fallback)
  - [x] **CRITICAL**: If marker file is corrupted/missing, system MUST use safe defaults (755/644) but should log warning that original permissions were lost
- [x] **Edge Case: Marker File Deleted or Edited**
  - [x] **If marker file is deleted during lock hours**:
    - [x] On next timer tick, `apply_config_directory_lock()` will detect marker file missing
    - [x] **Detection**: Check if directory/file are read-only (555/444) - if so, lock was active
    - [x] **Behavior**: If lock is active but marker missing, use safe defaults (755/644) for restoration
    - [x] Create new marker file with defaults (DIR_MODE=755, FILE_MODE=644, MARKER_MODE=644)
    - [x] **Note**: Original permissions are lost, but system continues to function
    - [x] Log warning that original permissions were lost (via log_message if available)
  - [x] **If marker file is edited/corrupted**:
    - [x] `retrieve_lock_state()` will detect invalid format
    - [x] Return empty string (caller uses defaults)
    - [x] System restores using safe defaults (755/644) instead of original permissions
    - [x] Log warning that original permissions were lost (via log_message if available)
  - [x] **Marker file IS locked**: Marker file is locked (chmod 444) after creation to prevent accidental deletion/editing
    - [x] Lock marker file after writing all data: `chmod 444 ~/.config/sleep-warning/.config_locked`
    - [x] When unlocking, restore marker file permissions first, then delete it
    - [x] This prevents accidental deletion/editing while maintaining ability to restore and delete when unlocking

#### 2.4 Implement Lock Application Function (Option A)
- [x] Create `apply_config_directory_lock()` function
  - [x] Check if lock should be active (call `is_config_lock_active()`)
  - [x] If lock should be active:
    - [x] Ensure config directory exists: `mkdir -p ~/.config/sleep-warning/config/`
    - [x] Check if marker file exists: `~/.config/sleep-warning/.config_locked`
    - [x] If marker doesn't exist (first lock):
      - [x] **CRITICAL**: Get ACTUAL current permissions (not defaults) - these are the "normal" permissions
      - [x] Store current directory mode, file mode, and marker file mode (call `store_lock_state()`)
      - [x] Create snapshot copy: `cp "${CONFIG_FILE}" ~/.config/sleep-warning/.config_locked_snapshot` (if file exists)
      - [x] Create marker file with timestamp, reason, and all permissions
      - [x] Lock marker file: `chmod 444 ~/.config/sleep-warning/.config_locked` (read-only to prevent deletion/editing)
    - [x] Set directory to read-only: `chmod 555 ~/.config/sleep-warning/config`
    - [x] Set file to read-only: `chmod 444 "${CONFIG_FILE}"` (if file exists)
    - [x] Re-assert marker file lock (in case user changed it)
  - [x] If lock should NOT be active:
    - [x] Check if marker file exists
    - [x] If marker exists (was locked, now unlocking):
      - [x] Retrieve stored directory mode, file mode, and marker mode (call `retrieve_lock_state()`)
      - [x] **CRITICAL**: If retrieval fails (corrupted/missing), use safe defaults (755/644) but log warning
      - [x] **Restore marker file permissions first**: `chmod "${stored_marker_mode}" ~/.config/sleep-warning/.config_locked` (or 644 if defaults)
      - [x] **Restore directory mode**: `chmod "${stored_dir_mode}" ~/.config/sleep-warning/config` (or 755 if defaults)
      - [x] **Restore file mode**: `chmod "${stored_file_mode}" "${CONFIG_FILE}"` (or 644 if defaults) (if file exists)
      - [x] **CRITICAL**: Must restore ORIGINAL permissions, not hardcoded defaults (unless marker corrupted/missing)
      - [x] Remove marker file: `rm -f ~/.config/sleep-warning/.config_locked` (now writable, can be deleted)
      - [x] Remove snapshot file: `rm -f ~/.config/sleep-warning/.config_locked_snapshot`
  - [x] Make function idempotent (safe to call multiple times)
  - [x] Handle errors gracefully (directory/file missing, permission denied, etc.)

#### 2.5 Implement Self-Healing Logic (Option A - Optional but Recommended)
- [x] **RECOMMENDATION**: Implement marker file and self-healing for Option A
  - **Rationale**: 
    - Marker file provides state tracking (when lock was applied, why, what modes were stored)
    - Self-healing detects and prevents tampering (user deletes config file, changes permissions)
    - With directory lock, user can't rename/replace file, but could still delete it or change permissions if they have access
    - Self-healing provides defense-in-depth
  - [x] Create `check_and_restore_config_file()` function
    - [x] Check if lock should be active
    - [x] If lock is active:
      - [x] Check if config file exists
      - [x] If file missing:
        - [x] Restore from snapshot (if available) and re-apply read-only perms
        - [x] Log warning (if logging available)
      - [x] If file exists, detect likely modification (mtime vs snapshot) and restore if needed
      - [x] Re-assert read-only mode on directory and file (in case user changed permissions)
    - [x] Return 0 on success, 1 on error
  - [x] **Note**: Self-healing is less critical with Option A (directory lock prevents most bypasses) but still recommended for robustness

#### 2.8 Source Module in sleep-warning.sh
- [x] Add `source "${LIB_DIR}/config-locking.sh" || exit 1` to `sleep-warning.sh`
  - [x] Place after `time-validation.sh` source (depends on is_restricted_hour, is_lock_hour functions)
  - [x] Place before main function (functions needed in main)

---

### Phase 3: Integration with sleep-warning.sh

#### 3.1 Add Lock Application to Main Function
- [x] In `sleep-warning.sh` main function, call lock application function:
  - [x] Call `apply_config_directory_lock()` (Option A)
  - [x] Place early in main function (before restriction checking)
  - [x] Handle errors gracefully (don't exit on lock failure)
- [x] Add self-healing check (recommended):
  - [x] Call `check_and_restore_config_file()` after lock application
  - [x] Only check if lock is active (skip if not locked)
  - [x] Handle errors gracefully (don't exit on self-heal failure)

#### 3.2 Handle Lock State Persistence
- [x] Ensure lock state persists across timer ticks:
  - [x] Lock application is idempotent (safe to call every timer tick)
  - [x] Lock state transitions correctly (locked → unlocked, unlocked → locked)
  - [x] No race conditions between timer ticks (idempotent design handles this)

---

### Phase 4: Integration with configure.sh

#### 4.1 Add Lock Check Before Config Write
- [x] In `configure.sh`, block execution when the config file is locked:
  - [x] Check if config lock is active (call `is_config_lock_active()`)
  - [x] If lock is active:
    - [x] Show error message (use existing dialog functions via `show_config_file_locked_error()`)
    - [x] Display end time information (reuses the same end-time logic as script blocking via `show_config_locked_error()`)
    - [x] Exit without calling `write_config()`
  - [x] If lock is not active, proceed normally

#### 4.2 Add Lock Check to Configuration UI
- [x] Update `lib/configure-ui.sh`:
  - [x] Create `show_config_file_locked_error()` function
  - [x] Similar to `show_config_locked_error()` (Enhancement #19) but for file locking
  - [x] Reuses `show_config_locked_error()` logic with different script name
  - [x] Support both GUI and text modes
  - [x] **Verify function name**: Check for conflicts - ✅ Different from `show_config_locked_error()`

#### 4.3 Add Configuration UI Option
- [x] **NOTE (combined menu)**: The configure wizard combines script blocking and config file locking under a single **Security Settings** menu option.
  - [x] `lib/configure-display.sh` shows **Security Settings (Script Blocking and Config Locking)** with a combined status indicator.
  - [x] `configure.sh` handles this as menu option **6** and calls `get_security_settings_config()`.
  - [x] `lib/configure-input.sh` implements `get_security_settings_config()` which returns `configure_block|config_lock`.
  - [x] `get_config_lock_enabled_config()` exists (legacy/single-setting helper), but is not the primary UX entry point after combining the menu.

#### 4.4 Integration with Enhancement #22 (24/7 Restriction Prevention)
- [x] In `configure.sh`, when saving configuration:
  - [x] After `check_restriction_coverage()` validation (Enhancement #22):
    - [x] If restrictions > 9660 minutes detected (warn case):
      - [x] Automatically set `config_lock_enabled="false"` (override user setting)
      - [x] Note: Config file will have `CONFIG_LOCK_ENABLED=false` written (no special comment needed)
      - [x] Safety override applied before calling `write_config()`
  - [x] Ensure `write_config()` receives `config_lock_enabled="false"` when high restrictions detected

---

### Phase 5: Integration with uninstall.sh

#### 5.1 Add Lock Removal to Uninstall Script
- [x] In `uninstall.sh`, before removing config file:
  - [x] Stop timer/service: `systemctl --user stop sleep-warning.timer`
  - [x] Wait briefly for service to exit (2-3 seconds)
  - [x] Force restore permissions (ignore errors) so locked files can be deleted
  - [x] Remove marker file and snapshot file (ignore errors)
  - [x] Proceed with normal uninstall

#### 5.2 Handle Uninstall During Lock Hours
- [x] Ensure uninstall always works (even during lock hours):
  - [x] Uninstall script does NOT check lock state before restoring permissions
  - [x] Force restore ignores file permission errors (uses `|| true` fallbacks)
  - [x] `restore_config_permissions()` always runs before config removal
  - [x] Document that uninstall always works regardless of lock state

---

### Phase 6: Migration (Option A only)

#### 6.1 Implement Migration Function
- [x] Create `migrate_config_to_subdirectory()` function
  - [x] Check if old config exists: `~/.config/sleep-warning/sleep-warning.conf`
  - [x] Check if new config exists: `~/.config/sleep-warning/config/sleep-warning.conf`
  - [x] If old exists and new doesn't:
    - [x] Create backup of old config
    - [x] Create config directory: `mkdir -p ~/.config/sleep-warning/config`
    - [x] Copy old config to new location
    - [x] Verify copy succeeded (size + checksum when available)
    - [x] Only remove old config after successful verification
  - [x] If old doesn't exist or new already exists:
    - [x] Return 0 (nothing to migrate)
  - [x] Return 0 on success, 1 on error
  - [x] Handle errors gracefully (don't remove old config if migration fails)

#### 6.2 Add Migration to Install Script
- [x] **DECISION MADE**: Run migration in `install.sh` (if previous config exists) - **CHOSEN**
- [x] Add migration call to `install.sh`:
  - [x] After creating config directory structure (in `create_directories()`)
  - [x] Before installing config file (if default config is being installed)
  - [x] Check if migration needed (old config exists, new doesn't)
  - [x] Call `migrate_config_to_subdirectory()`
  - [x] Handle errors gracefully:
    - [x] If migration fails, print warning but continue installation
    - [x] Don't fail installation if migration fails (user can migrate manually later)
  - [x] If no old config exists, write new config directly to `~/.config/sleep-warning/config/sleep-warning.conf`

#### 6.3 Update CONFIG_FILE Constant
- [x] Update `CONFIG_FILE` in `lib/config.sh`:
  - [x] Change from: `CONFIG_FILE="${CONFIG_DIR}/sleep-warning.conf"`
  - [x] Change to: `CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"`
  - [x] Ensure all scripts use this constant (no hardcoded paths)
  - [x] Verify all references to config file use `CONFIG_FILE` constant

#### 6.4 Backward Compatibility
- [x] **DECISION MADE**: No backward compatibility - only use new location - **CHOSEN**
  - **Rationale**: Cleaner implementation, migration handles transition
  - **Implementation**: All code should use `CONFIG_FILE` constant which points to new location
  - [x] Ensure no hardcoded paths to old location remain in codebase (uninstall.sh handles both for cleanup)
  - [x] Migration must succeed before system can function (old location not checked as fallback)

---

### Phase 7: Edge Cases and Error Handling

#### 7.1 Handle System Time Changes
- [x] Lock state should adapt to time changes:
  - [x] Lock application runs every timer tick (handles time changes automatically)
  - [x] No cached time values (always use current time via `date` command)
  - [ ] Test: Change system time during locked period (lock should persist or adapt) - **TESTING PENDING**

#### 7.2 Handle System Sleep/Resume
- [x] Lock state should persist across sleep/resume:
  - [x] Lock application runs on next timer tick after resume
  - [x] No special handling needed (idempotent lock application handles it)
  - [ ] Test: Sleep system during locked period, resume (lock should still be active) - **TESTING PENDING**

#### 7.3 Handle Manual Permission Changes
- [x] Detect if user manually changed permissions:
  - [x] Option 1: Re-apply lock on next timer tick (idempotent, handles it) - **IMPLEMENTED**
  - [x] Self-healing function also re-asserts permissions
  - [ ] Test: User manually changes file to writable during lock hours (should be re-locked) - **TESTING PENDING**

#### 7.4 Handle Config File Deletion
- [x] Prevent or handle config file deletion during lock hours:
  - [x] Option A: Directory lock prevents deletion (stronger protection)
  - [x] Self-healing: Restore from snapshot if file deleted
  - [x] Log warning if file deleted and restored (via log_message if available)
  - [ ] Test: Delete config file during lock hours (should be restored) - **TESTING PENDING**

#### 7.5 Handle Missing Marker File
- [x] If marker file missing but lock should be active:
  - [x] Treat as first lock (store current mode, create snapshot)
  - [x] Don't fail if marker missing (graceful degradation)
  - [x] Uses safe defaults (755/644) if marker missing during unlock
  - [ ] Test: Delete marker file during lock hours (should recreate) - **TESTING PENDING**

#### 7.6 Handle Corrupted Snapshot File
- [x] If snapshot file corrupted or missing:
  - [x] Log error (if logging available via log_message)
  - [x] Don't restore (prevent data loss from corrupted snapshot)
  - [x] Re-create snapshot on next lock cycle (if file exists)
  - [ ] Test: Corrupt snapshot file (should handle gracefully) - **TESTING PENDING**

---

### Phase 8: Testing

**Test harness note**:
- A basic, isolated test script is available at `tests/test-config-locking.sh`.
- It runs with a temporary `HOME` so it does not touch any real installed configuration.

**Tests performed (2026-01-25)**:
- `bash tests/test-config-locking.sh` ✅ PASS
  - Covers:
    - `get_config_lock_enabled()` default/normalization/invalid-value fallback
    - `is_config_lock_active()` during restriction hours and during `CONFIG_LOCK_HOURS_*` (lock-hours-only case)
    - `apply_config_directory_lock()` lock/unlock + idempotency + write-blocking check
  - Notes:
    - The test runs under a temporary `HOME` and creates its own config tree under `~/.config/sleep-warning/`.
- Additional “safe” test scripts also run (do not touch the real installed config):
  - `bash tests/test-lock-hours-phase2.sh` ✅ PASS
    - **Relevance to Enhancement #18**: Tests `CONFIG_LOCK_HOURS_*` parsing and `is_lock_hour()` logic used by Enhancement #18's `is_config_lock_active()`.
  - `bash tests/test-uninstall-lock-hours-phase2.sh` ✅ PASS
    - **Relevance to Enhancement #18**: Not directly related (tests uninstall lock hours, separate feature).
  - `bash tests/test-write-config-override-flags.sh` ✅ PASS
    - **Relevance to Enhancement #18**: Tests `write_config()` override flag detection, including the safety mechanism (Enhancement #22) that automatically disables `CONFIG_LOCK_ENABLED` when restrictions exceed 16 hours/day.
  - `bash tests/test-dialog-tool-selection.sh` ✅ PASS
    - **Relevance to Enhancement #18**: Not directly related (tests dialog tool selection used by configure.sh).
  - `bash tests/test-pause-feature.sh` ✅ PASS
    - **Relevance to Enhancement #18**: Not directly related.
  - Re-run note (2026-01-25 00:54 EST): all still ✅ PASS.

**Note**: The integration test "Test `configure.sh` blocking" (section 8.2) is still pending. This would verify that `configure.sh` shows an error and exits when `CONFIG_LOCK_ENABLED=true` and the current time is within restricted hours or lock hours.

#### 8.1 Unit Tests
- [x] Test `get_config_lock_enabled()` function:
  - [x] Test with missing config file (should return default false)
  - [x] Test with `CONFIG_LOCK_ENABLED=true` (and case insensitivity, e.g. `TRUE`)
  - [x] Test with `CONFIG_LOCK_ENABLED=false`
  - [x] Test with invalid values (should return default)
  - [x] Test case insensitivity

- [x] Test `is_config_lock_active()` function:
  - [x] Test when `CONFIG_LOCK_ENABLED=false` (should return inactive)
  - [ ] Test when enabled and NOT in restricted hours (should return inactive)
  - [x] Test when enabled and IN restricted hours (should return active)
  - [ ] Test overnight ranges (previous day extending into current day)
  - [x] Test additional lock hours (if implemented)
  - [ ] Test multiple ranges per day

- [x] Test lock application functions:
  - [x] Test applying lock (file becomes read-only)
  - [x] Test removing lock (file becomes writable)
  - [x] Test idempotency (calling multiple times has same effect)
  - [x] Test mode storage and retrieval (restores non-default modes)
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
- [x] **VERIFIED**: `config_lock_enabled` - ✅ No conflicts
- [x] **VERIFIED**: `get_config_lock_enabled()` - ✅ No conflicts
- [x] **VERIFIED**: `is_config_lock_active()` - ✅ No conflicts
- [x] **VERIFIED**: `apply_config_directory_lock()` - ✅ No conflicts (function name matches Option A)
- [x] **VERIFIED**: `show_config_file_locked_error()` - ✅ No conflicts
- [x] **VERIFIED**: `get_config_lock_enabled_config()` - ✅ No conflicts (legacy helper; primary UX uses combined **Security Settings** via `get_security_settings_config()`)
- [x] **VERIFIED**: `CONFIG_LOCK_HOURS_*` (reused) - ✅ No conflicts, safely reused from Enhancement #19

#### 10.2 Code Style and Consistency
- [x] Follow existing code style (snake_case for functions, UPPER_CASE for constants)
- [x] Use same error handling patterns as existing code
- [x] Use same logging patterns (if logging available via log_message)
- [x] Match existing function organization patterns

#### 10.3 Error Handling
- [x] All file operations handle errors gracefully
- [x] All permission operations handle errors gracefully
- [x] Missing files handled gracefully (don't fail, log warning)
- [x] Invalid config values handled gracefully (use defaults)

#### 10.4 Performance
- [x] Lock application is fast (< 100ms expected)
- [x] No unnecessary file operations
- [x] No continuous monitoring (only on timer tick)

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