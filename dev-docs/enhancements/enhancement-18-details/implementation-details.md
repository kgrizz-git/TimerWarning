# Enhancement #18: Config File Locking - Implementation Details

This document provides comprehensive details about how the config file locking mechanism works, including which scripts perform the operations, how they're triggered, the marker file's purpose, and the complete lock/unlock process.

## Table of Contents

1. [Script Architecture and Execution Flow](#script-architecture-and-execution-flow)
2. [How Locking Works](#how-locking-works)
3. [The Marker File](#the-marker-file)
4. [How Unlocking Works](#how-unlocking-works)
5. [Self-Healing Mechanism](#self-healing-mechanism)
6. [Complete Flow Examples](#complete-flow-examples)
7. [Important Notes](#important-notes)

---

## Script Architecture and Execution Flow

### Script Components

#### 1. Locking Functions Module
**File**: `lib/config-locking.sh`

**Contains**:
- `is_config_lock_active()` - Checks if lock should be active
- `store_lock_state()` - Saves permissions to marker file
- `retrieve_lock_state()` - Reads permissions from marker file
- `apply_config_directory_lock()` - Main locking function (does all the work)
- `check_and_restore_config_file()` - Self-healing function

#### 2. Main Script
**File**: `sleep-warning.sh`

**Role**: 
- Sources the locking module
- Calls the locking functions in its main function
- Runs automatically via systemd timer

#### 2b. Configuration Wizard (toggle + safety UI)
**File**: `configure.sh`

**Role**:
- Provides a **combined "Security Settings"** menu option that configures:
  - Script blocking (Enhancement #19)
  - Config file locking enable/disable (Enhancement #18)
- Blocks execution when config file locking is active (shows a “config file locked” error and exits).

#### 3. Systemd Timer
**File**: `sleep-warning.timer`

**Role**:
- Triggers `sleep-warning.service` at regular intervals
- Default: Every 10 minutes (configurable via `CHECK_INTERVAL`)

#### 4. Systemd Service
**File**: `sleep-warning.service`

**Role**:
- Executes `sleep-warning.sh` when triggered by timer
- Runs as a oneshot service (runs once per trigger, then exits)

### Execution Flow

#### Step-by-Step Trigger Process

```
1. Systemd Timer (sleep-warning.timer)
   ↓ (fires every 10 minutes)
2. Systemd Service (sleep-warning.service)
   ↓ (executes)
3. sleep-warning.sh
   ↓ (sources modules, calls main function)
4. main() function in sleep-warning.sh
   ↓ (calls locking function early in execution)
5. apply_config_directory_lock() in lib/config-locking.sh
   ↓ (performs all locking operations)
```

#### Detailed Flow in sleep-warning.sh

```bash
# sleep-warning.sh structure (simplified)

# 1. Source all modules (including config-locking.sh)
source "${LIB_DIR}/config.sh" || exit 1
source "${LIB_DIR}/config-locking.sh" || exit 1
source "${LIB_DIR}/logging.sh" || exit 1
# ... other modules ...

# 2. Main function
main() {
    # 3. Apply config file lock (EARLY - before other checks)
    apply_config_directory_lock()  # Does all the locking work
    
    # 4. Self-healing check (if lock is active)
    if is_config_lock_active; then
        check_and_restore_config_file()  # Detects tampering
    fi
    
    # 5. Continue with normal sleep warning logic
    # ... check restricted hours, show popup, etc. ...
}

# 6. Run main function
main "$@"
```

### What Happens in apply_config_directory_lock()

This function (in `lib/config-locking.sh`) performs all the locking operations:

```bash
apply_config_directory_lock() {
    # 1. Check if lock should be active
    if ! is_config_lock_active; then
        # Lock should NOT be active - unlock if currently locked
        if [ -f ~/.config/sleep-warning/.config_locked ]; then
            # Unlock: restore permissions, remove marker
            retrieve_lock_state  # Get original permissions
            chmod 755 ~/.config/sleep-warning/config  # Restore directory
            chmod 644 ~/.config/sleep-warning/config/sleep-warning.conf  # Restore file
            rm ~/.config/sleep-warning/.config_locked  # Remove marker
            rm ~/.config/sleep-warning/.config_locked_snapshot  # Remove snapshot
        fi
        return 0
    fi
    
    # 2. Lock should be active
    # Ensure directory exists
    mkdir -p ~/.config/sleep-warning/config/
    
    # 3. First-time lock (marker file doesn't exist)
    if [ ! -f ~/.config/sleep-warning/.config_locked ]; then
        # Save current permissions
        store_lock_state  # Creates marker file with permissions
        
        # Create snapshot backup
        cp ~/.config/sleep-warning/config/sleep-warning.conf \
           ~/.config/sleep-warning/.config_locked_snapshot
    fi
    
    # 4. Apply lock (every time, even if already locked - idempotent)
    chmod 555 ~/.config/sleep-warning/config  # Directory read-only
    chmod 444 ~/.config/sleep-warning/config/sleep-warning.conf  # File read-only
    
    return 0
}
```

### Trigger Frequency

#### Default Behavior
- **Timer interval**: Every 10 minutes (default `CHECK_INTERVAL`)
- **Lock check**: Every time `sleep-warning.sh` runs
- **Lock application**: Idempotent (safe to run every 10 minutes)

#### Example Timeline

**Scenario**: Restricted hours are 0-5 (midnight to 4:59 AM)

```
12:00 AM - Timer fires → sleep-warning.sh runs
         → apply_config_directory_lock() called
         → Lock should be active? YES (it's 12:00 AM)
         → Marker file doesn't exist? YES (first lock)
         → Save permissions, create snapshot, apply lock
         → Config is now locked

12:10 AM - Timer fires → sleep-warning.sh runs
         → apply_config_directory_lock() called
         → Lock should be active? YES (still 12:10 AM)
         → Marker file exists? YES (already locked)
         → Re-assert read-only permissions (chmod 555, chmod 444)
         → Run self-healing check

12:20 AM - Timer fires → (same as 12:10 AM)
...
5:00 AM - Timer fires → sleep-warning.sh runs
         → apply_config_directory_lock() called
         → Lock should be active? NO (it's 5:00 AM, outside restricted hours)
         → Marker file exists? YES (was locked)
         → Restore original permissions (chmod 755, chmod 644)
         → Remove marker and snapshot
         → Config is now unlocked

5:10 AM - Timer fires → sleep-warning.sh runs
         → apply_config_directory_lock() called
         → Lock should be active? NO (still 5:10 AM)
         → Marker file exists? NO (already unlocked)
         → No action needed
```

### Manual Execution

The script can also be run manually for testing:

```bash
# Run manually (bypasses timer)
~/.local/bin/sleep-warning.sh

# Or from project directory
./sleep-warning.sh
```

When run manually, the locking functions still execute, so you can test locking behavior without waiting for the timer.

---

## How Locking Works

### Overview

The config file locking uses **file system permissions** (`chmod`) to make the config file and directory read-only during restricted hours. This is a **deterrence mechanism** - it discourages edits but can be bypassed by determined users.

### Step-by-Step Process

1. **Check if lock should be active**:
   - Is `CONFIG_LOCK_ENABLED=true`?
   - Is current time in restriction hours OR lock hours?
   - If no to either, skip locking

2. **First-time lock (marker file doesn't exist)**:
   - **CRITICAL**: Get ACTUAL current directory permissions: `stat -c '%a' ~/.config/sleep-warning/config` → e.g., `755` (these are the "normal" permissions)
   - **CRITICAL**: Get ACTUAL current file permissions: `stat -c '%a' ~/.config/sleep-warning/config/sleep-warning.conf` → e.g., `644` (these are the "normal" permissions)
   - Create snapshot: `cp config/sleep-warning.conf .config_locked_snapshot` (backup for self-healing)
   - Create marker file with timestamp, reason, and original permissions (DIR_MODE, FILE_MODE, MARKER_MODE)
   - Lock marker file: `chmod 444 ~/.config/sleep-warning/.config_locked` (read-only to prevent deletion/editing)
   - Apply lock: `chmod 555 ~/.config/sleep-warning/config` (directory read-only)
   - Apply lock: `chmod 444 ~/.config/sleep-warning/config/sleep-warning.conf` (file read-only)

3. **Subsequent checks (marker file exists)**:
   - Lock is already active, just verify permissions are still read-only
   - Re-assert read-only if user changed permissions: `chmod 555` and `chmod 444`
   - Run self-healing check (see below)

### What "Locked" Means

When locked:
- **Directory**: `chmod 555` = `r-xr-xr-x` (read and execute, no write)
  - Users can read files in the directory
  - Users **cannot** create, delete, or rename files in the directory
  - This prevents the common editor trick of writing a temp file and renaming it over the original
  
- **File**: `chmod 444` = `r--r--r--` (read-only)
  - Users can read the file
  - Users **cannot** modify the file directly
  - Combined with directory lock, prevents most editing attempts

### Why This Works

Most text editors use one of these methods to save files:
1. **Direct write**: Open file, modify, write back → **Blocked** by file read-only
2. **Temp file + rename**: Write to temp file, rename over original → **Blocked** by directory read-only
3. **Delete + create**: Delete old file, create new file → **Blocked** by directory read-only

---

## The Marker File

### Purpose

The marker file (`~/.config/sleep-warning/.config_locked`) serves multiple purposes:

1. **State Tracking**: Records when the lock was applied and why (restricted hours vs lock hours)
2. **Permission Storage**: Stores the original file and directory permissions so they can be restored when unlocking
3. **Audit Trail**: Provides a record of when locking occurred
4. **Self-Healing Support**: Enables the system to detect and restore tampering

### Location

The marker file is stored in the **parent directory** (`~/.config/sleep-warning/`) rather than inside the locked config directory (`~/.config/sleep-warning/config/`). This is important because:
- The config directory becomes read-only when locked
- The marker file needs to be accessible even when the directory is locked
- The parent directory remains writable (for logs, etc.)

**Important**: The marker file itself **IS locked** (read-only, `chmod 444`) after creation to prevent accidental deletion or editing. This means:
- Marker file is created with permissions 644 (readable/writable)
- Original marker file permissions are stored in the marker file itself (MARKER_MODE field)
- After writing all data, marker file is locked: `chmod 444` (read-only)
- When unlocking, marker file permissions are restored first, then it's deleted
- This prevents accidental deletion/editing while maintaining ability to restore and delete when unlocking

### Format

The marker file contains key-value pairs separated by `|`:

```
TIMESTAMP=2026-01-23T10:30:00|REASON=restricted_hours|DIR_MODE=755|FILE_MODE=644|MARKER_MODE=644
```

- **TIMESTAMP**: When the lock was first applied (ISO format)
- **REASON**: Why the lock is active (`restricted_hours` or `lock_hours`)
- **DIR_MODE**: **Original directory permissions** (e.g., `755` = rwxr-xr-x) - **CRITICAL: These are the actual "normal" permissions that must be restored**
- **FILE_MODE**: **Original file permissions** (e.g., `644` = rw-r--r--) - **CRITICAL: These are the actual "normal" permissions that must be restored**
- **MARKER_MODE**: Original marker file permissions (e.g., `644` = rw-r--r--) - stored so marker file can be restored before deletion

**Critical Requirement**: The DIR_MODE and FILE_MODE values must be the **actual current permissions** at lock time, not hardcoded defaults. These are the "normal" permissions that the user had before locking, and they MUST be restored exactly when unlocking.

### What Happens If Marker File Is Deleted or Edited?

#### Marker File Deleted

If the marker file is deleted during lock hours (user must use `chmod` first to make it writable, or use `rm -f`):

1. **On next timer tick**: `apply_config_directory_lock()` detects marker file is missing
2. **Detection**: Check if directory/file are read-only (555/444) - if so, lock was active
3. **Behavior**: If lock is active but marker missing:
   - **CRITICAL**: Original permissions are lost
   - Use safe defaults (755 for directory, 644 for file) for restoration
   - Create new marker file with defaults (DIR_MODE=755, FILE_MODE=644, MARKER_MODE=644)
   - Lock the new marker file: `chmod 444`
   - Log warning that original permissions were lost
4. **Impact**: 
   - Lock continues to work (config remains locked)
   - Original permissions are lost (will restore to defaults when unlocking)
   - System continues to function normally

#### Marker File Edited/Corrupted

If the marker file is edited or corrupted (user must use `chmod` first to make it writable):

1. **On unlock attempt**: `retrieve_lock_state()` reads marker file
2. **Detection**: Parsing fails, format is invalid, or values are invalid
3. **Behavior**: Function returns empty string (indicates failure)
4. **Action**: 
   - System uses safe defaults (755/644) for restoration
   - Log warning that original permissions were lost
   - Restore using defaults instead of original values

**Impact**:
- Lock continues to work (config remains locked)
- Unlock will restore to defaults (755/644) instead of original permissions
- System continues to function normally

#### Why Marker File IS Locked

The marker file **is locked** (read-only, `chmod 444`) after creation because:
- Prevents accidental deletion or editing
- Protects the stored permission values
- Marker file is created once, doesn't need updates during lock period
- When unlocking, permissions are restored first, then marker is deleted
- Provides additional defense-in-depth

**Unlocking Process**:
1. Restore marker file permissions: `chmod "${MARKER_MODE}" ~/.config/sleep-warning/.config_locked` (makes it writable)
2. Read marker file to get original permissions
3. Restore directory and file permissions
4. Delete marker file (now writable, can be deleted)

**Security Note**: Even if marker file is deleted/edited (user must use `chmod` first), the config directory and file remain read-only. The lock is not bypassed. However, original permissions may be lost, and system will restore to safe defaults.

---

## How Unlocking Works

### Step-by-Step Process

1. **Check if lock should be active**:
   - Is `CONFIG_LOCK_ENABLED=true`?
   - Is current time in restriction hours OR lock hours?
   - If no to both, proceed with unlocking

2. **Unlock process (marker file exists)**:
   - **CRITICAL**: Restore marker file permissions first: `chmod "${MARKER_MODE}" ~/.config/sleep-warning/.config_locked` (makes it writable, typically 644)
   - Read marker file to get original permissions
   - Parse `DIR_MODE`, `FILE_MODE`, and `MARKER_MODE` from marker file
   - **CRITICAL**: If parsing fails (corrupted), use safe defaults (755/644) but log warning
   - **CRITICAL**: Restore ORIGINAL permissions (from marker file), not hardcoded defaults:
     - Restore directory permissions: `chmod "${DIR_MODE}" ~/.config/sleep-warning/config` (original mode, e.g., 755)
     - Restore file permissions: `chmod "${FILE_MODE}" ~/.config/sleep-warning/config/sleep-warning.conf` (original mode, e.g., 644)
   - Remove marker file: `rm ~/.config/sleep-warning/.config_locked` (now writable, can be deleted)
   - Remove snapshot file: `rm ~/.config/sleep-warning/.config_locked_snapshot`

3. **Verification**:
   - Verify directory is writable
   - Verify file is writable
   - Log unlock event (if logging available)

---

## Self-Healing Mechanism

### Purpose

Self-healing detects and prevents tampering attempts:
- User deletes the config file
- User changes file/directory permissions
- User modifies the config file (if they somehow bypassed the lock)

### How It Works

On every timer tick (when `sleep-warning.sh` runs), if lock is active:

1. **Check file existence**:
   - If file missing → restore from snapshot, re-apply lock, log warning

2. **Check file integrity**:
   - Compare file checksum or modification time with snapshot
   - If file was modified → restore from snapshot, re-apply lock, log warning

3. **Re-assert permissions**:
   - Check if directory is still read-only (`chmod 555`)
   - Check if file is still read-only (`chmod 444`)
   - If permissions changed → re-apply read-only, log warning

### Why It's Needed

Even with directory lock, a determined user could:
- Delete the config file (if they have access)
- Change permissions using `chmod` (their own file)
- Stop the timer/service and edit freely

Self-healing provides **defense-in-depth** by detecting and reversing these attempts.

---

## Complete Flow Examples

### Scenario 1: Locking During Restricted Hours

**Time: 2:00 AM (within restricted hours 0-5)**

1. `sleep-warning.sh` runs (timer tick)
2. Calls `apply_config_directory_lock()`
3. `is_config_lock_active()` returns 0 (lock should be active)
4. Marker file doesn't exist (first lock):
   - **Get ACTUAL current permissions** (not defaults): `DIR_MODE=755`, `FILE_MODE=644`, `MARKER_MODE=644`
   - Create snapshot: `cp config/sleep-warning.conf .config_locked_snapshot`
   - Create marker: `TIMESTAMP=2026-01-23T02:00:00|REASON=restricted_hours|DIR_MODE=755|FILE_MODE=644|MARKER_MODE=644`
   - Lock marker file: `chmod 444 .config_locked` (read-only)
5. Apply lock: `chmod 555 config/` and `chmod 444 config/sleep-warning.conf`
6. Run self-healing check: File exists, permissions correct, no action needed

**Result**: Config file and directory are now read-only

### Scenario 2: Unlocking After Restricted Hours

**Time: 6:00 AM (outside restricted hours)**

1. `sleep-warning.sh` runs (timer tick)
2. Calls `apply_config_directory_lock()`
3. `is_config_lock_active()` returns 1 (lock should NOT be active)
4. Marker file exists (was locked):
   - Restore marker file permissions: `chmod 644 .config_locked` (makes it writable)
   - Read marker: `DIR_MODE=755`, `FILE_MODE=644`, `MARKER_MODE=644`
   - **Restore ORIGINAL permissions**: `chmod 755 config/` and `chmod 644 config/sleep-warning.conf` (using values from marker, not hardcoded)
   - Remove marker and snapshot files

**Result**: Config file and directory are now writable again

### Scenario 3: User Attempts to Edit During Lock

**Time: 3:00 AM (still locked)**

1. User tries to edit config file with text editor
2. Editor attempts to save:
   - **Method 1**: Direct write → Fails (file is read-only)
   - **Method 2**: Temp file + rename → Fails (directory is read-only)
   - **Method 3**: Delete + create → Fails (directory is read-only)
3. Editor shows error: "Permission denied" or "Read-only file"
4. Next timer tick (10 minutes later):
   - Self-healing check runs
   - Verifies file still exists and permissions are correct
   - No action needed (user's attempt was blocked)

**Result**: User cannot edit the file

### Scenario 4: User Deletes Config File During Lock

**Time: 3:00 AM (still locked)**

1. User somehow deletes config file: `rm ~/.config/sleep-warning/config/sleep-warning.conf`
2. Next timer tick (10 minutes later):
   - Self-healing check runs
   - Detects file missing
   - Restores from snapshot: `cp .config_locked_snapshot config/sleep-warning.conf`
   - Re-applies lock: `chmod 444 config/sleep-warning.conf`
   - Logs warning

**Result**: Config file is restored and locked again

### Scenario 5: User Deletes Marker File During Lock

**Time: 3:00 AM (still locked)**

1. User makes marker file writable: `chmod 644 ~/.config/sleep-warning/.config_locked`
2. User deletes marker file: `rm ~/.config/sleep-warning/.config_locked`
3. Next timer tick (10 minutes later):
   - `apply_config_directory_lock()` runs
   - Detects marker file missing
   - Detects directory/file are read-only (already locked)
   - **CRITICAL**: Original permissions are lost
   - Creates new marker file with safe defaults (DIR_MODE=755, FILE_MODE=644, MARKER_MODE=644)
   - Locks new marker file: `chmod 444 .config_locked`
   - Re-asserts read-only permissions (chmod 555, chmod 444)
   - Logs warning that original permissions were lost
   - Lock continues to work

**Result**: Marker file is recreated, lock continues, **original permissions are lost** (will restore to defaults 755/644 when unlocking)

### Scenario 6: User Edits Marker File During Lock

**Time: 3:00 AM (still locked)**

1. User makes marker file writable: `chmod 644 ~/.config/sleep-warning/.config_locked`
2. User edits marker file: Changes `FILE_MODE=644` to `FILE_MODE=777` (invalid value)
3. User locks marker file again: `chmod 444 .config_locked` (optional, system will re-lock it)
4. Next timer tick (10 minutes later):
   - Lock continues to work (config directory/file remain read-only)
   - When unlocking, `retrieve_lock_state()` reads corrupted marker
   - Parsing may succeed but value is invalid (777 is not a standard permission), or parsing fails
   - Function returns empty string (indicates failure)
   - System uses safe defaults (755/644) instead of corrupted value
   - Logs warning that original permissions were lost
   - System restores using defaults

**Result**: Lock continues to work, unlock will restore to defaults (755/644) instead of corrupted value, original permissions are lost

---

## Important Notes

### Why This Design?

#### 1. Automatic and Continuous
- Runs automatically via systemd timer
- No manual intervention needed
- Lock state is checked and maintained continuously

#### 2. Idempotent Operations
- Safe to call every 10 minutes
- If already locked, just re-asserts permissions
- If already unlocked, does nothing
- No race conditions or duplicate locks

#### 3. Self-Healing
- Every timer tick checks for tampering
- Detects file deletion, permission changes, modifications
- Automatically restores from snapshot if needed

#### 4. Integrated with Existing System
- Uses same timer as sleep warning popups
- No additional systemd services needed
- Minimal overhead (permission checks are very fast)

### Limitations

- **Deterrence Only**: This is not true security. A determined user can:
  - Change permissions back: `chmod 755 config/` and `chmod 644 config/sleep-warning.conf`
  - Stop the timer/service: `systemctl --user stop sleep-warning.timer`
  - Edit the file directly with root access (if they have it)

- **User-Owned Files**: Since the config file is owned by the user, they have full control. The lock is a **self-control aid**, not a security boundary.

### Safety Features

- **Uninstall Always Works**: `uninstall.sh` stops the timer, restores permissions (best-effort), then removes files — even during lock hours
- **Automatic Disabling**: Enhancement #22 automatically disables locking if restrictions > 9660 minutes/week
- **Opt-in**: Feature is disabled by default (`CONFIG_LOCK_ENABLED=false`)

### Performance

- **Minimal Overhead**: Permission checks and changes are very fast (< 10ms)
- **Runs on Timer Tick**: Only runs when `sleep-warning.sh` executes (typically every 10 minutes)
- **Idempotent**: Safe to call multiple times (won't cause issues if called repeatedly)

---

## Summary

### Script Architecture
- **Script**: `sleep-warning.sh` (main script)
- **Functions**: `lib/config-locking.sh` (locking module)
- **Trigger**: Systemd timer (`sleep-warning.timer`) fires every 10 minutes
- **Execution**: Timer → Service → sleep-warning.sh → main() → apply_config_directory_lock()
- **Frequency**: Every timer tick (every 10 minutes by default)
- **Behavior**: Idempotent (safe to run repeatedly)

### Locking Mechanism
- **Marker File**: Stores state and original permissions for restoration
- **Locking**: Uses `chmod` to make directory and file read-only
- **Unlocking**: Restores original permissions from marker file
- **Self-Healing**: Detects and reverses tampering attempts
- **Purpose**: Deterrence mechanism for self-control, not true security

The locking happens automatically, continuously, and transparently as part of the normal sleep warning system operation.
