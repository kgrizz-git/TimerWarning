# Enhancement 8: Temporary Disable via Config

## Current Status

**✅ Partially Implemented** - Temporary disable functionality is already available via `manage.sh` (or `sleep-warning-manage` when installed).

The management interface provides:
- **Disable Service**: Stops and disables the systemd timer, temporarily disabling all warnings
- **Re-enable Service**: Re-enables and starts the systemd timer to resume warnings
- Both options are available through the interactive menu (GUI or text mode)

### Current Implementation

The `disable_service()` function in `manage.sh`:
- Stops the systemd timer: `systemctl --user stop sleep-warning.timer`
- Disables the timer: `systemctl --user disable sleep-warning.timer`
- Provides user confirmation before disabling
- Can be re-enabled through the same interface

**Note**: The management interface may be blocked during restricted hours if config locking is enabled (Enhancement #18), which prevents accessing the disable option during those times.

**Consideration**: We may want to remove the temporary disable option entirely to discourage impulsive disabling. Users have other options for removing or changing restrictions (e.g., editing the configuration file to remove restricted hours, or uninstalling the system entirely). The temporary disable feature may make it too easy for users to circumvent their own restrictions during moments of weakness.

## Future Work

### Option 1: Configuration File Toggle
- **Description**: Add `ENABLED=false` config option to `sleep-warning.conf`
- **Implementation**: Check this flag in `sleep-warning.sh` before showing warnings
- **Files Affected**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh`
- **Priority**: Medium (useful feature)
- **Status**: Not implemented

This would allow users to:
- Edit the config file directly to disable/enable
- Use `configure.sh` to toggle the enabled state
- Have the disable state persist across system restarts (unlike systemd disable which is persistent but requires systemd commands)

### Option 2: configure.sh Integration
- **Description**: Add disable/enable toggle option to the configuration wizard
- **Implementation**: Add menu option in `configure.sh` to toggle enabled state
- **Files Affected**: `configure.sh`, `sleep-warning.conf`
- **Priority**: Medium (improves accessibility)
- **Status**: Not implemented

This would provide:
- Easy access to disable/enable through the familiar configuration interface
- Integration with existing configuration workflow
- Alternative to using `manage.sh` for users who prefer the configure interface

## Testing

### Test Current Implementation (manage.sh)

1. **Test Disable via manage.sh (GUI mode)**:
   ```bash
   # Ensure service is running
   systemctl --user status sleep-warning.timer
   
   # Run management interface
   ./manage.sh
   # or if installed:
   sleep-warning-manage
   
   # Select "Temporarily Disable Service" (option 4 in text mode)
   # Confirm the action
   
   # Verify timer is stopped and disabled
   systemctl --user status sleep-warning.timer
   # Should show: inactive (dead) and disabled
   ```

2. **Test Re-enable via manage.sh (GUI mode)**:
   ```bash
   # Run management interface
   ./manage.sh
   
   # Select "Re-enable Service" (option 5 in text mode)
   # Confirm the action
   
   # Verify timer is enabled and active
   systemctl --user status sleep-warning.timer
   # Should show: active (waiting) and enabled
   ```

3. **Test Disable via manage.sh (Text mode)**:
   ```bash
   # Force text mode by unsetting DISPLAY
   DISPLAY= ./manage.sh
   
   # Select option 4 (Temporarily Disable Service)
   # Type 'y' to confirm
   
   # Verify timer is disabled
   systemctl --user is-enabled sleep-warning.timer
   # Should output: disabled
   ```

4. **Test Re-enable via manage.sh (Text mode)**:
   ```bash
   DISPLAY= ./manage.sh
   
   # Select option 5 (Re-enable Service)
   # Type 'y' to confirm
   
   # Verify timer is enabled
   systemctl --user is-enabled sleep-warning.timer
   # Should output: enabled
   ```

5. **Test Disable via Command Line** (verify manage.sh uses correct commands):
   ```bash
   # Manually disable (what manage.sh does)
   systemctl --user stop sleep-warning.timer
   systemctl --user disable sleep-warning.timer
   
   # Verify
   systemctl --user is-active sleep-warning.timer
   # Should output: inactive
   systemctl --user is-enabled sleep-warning.timer
   # Should output: disabled
   ```

6. **Test Re-enable via Command Line** (verify manage.sh uses correct commands):
   ```bash
   # Manually enable (what manage.sh does)
   systemctl --user daemon-reload
   systemctl --user enable sleep-warning.timer
   systemctl --user start sleep-warning.timer
   
   # Verify
   systemctl --user is-active sleep-warning.timer
   # Should output: active
   systemctl --user is-enabled sleep-warning.timer
   # Should output: enabled
   ```

7. **Test Behavior During Restricted Hours** (if config locking is enabled):
   ```bash
   # If UNINSTALL_PROTECTION_MODE is set and current time is in restricted hours
   # The management interface should be blocked
   ./manage.sh
   # Should show error about config being locked and exit
   ```

### Test Future Implementation (when config file toggle is added)

1. **Test Config File Toggle**:
   ```bash
   # Add to sleep-warning.conf
   ENABLED=false
   
   # Verify warnings don't appear during restricted hours
   # (would need to trigger warning manually or wait for timer)
   
   # Change to enabled
   ENABLED=true
   
   # Verify warnings resume
   ```

2. **Test configure.sh Integration** (when implemented):
   ```bash
   ./configure.sh
   # Navigate to disable/enable option
   # Toggle state
   # Verify config file is updated correctly
   ```

## Files Affected

- **Current**: `manage.sh` (already implemented)
- **Future**: `sleep-warning.sh`, `sleep-warning.conf`, `configure.sh` (if config file toggle is added)

## Priority

Medium (useful feature) - Current implementation via manage.sh is functional. Config file toggle would add convenience and persistence options.

**Note**: Consider removing the temporary disable option entirely to discourage impulsive disabling. Users can modify restrictions via configuration or uninstall the system if needed.
