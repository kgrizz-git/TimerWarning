# Pause Feature Scope Clarification

## What Pause Affects

### ✅ Pause DOES Suppress
- **Warning popups** - No popup dialogs shown during pause period
- **Popup display logic** - `show_warning()` is skipped when pause is active

### ❌ Pause DOES NOT Affect
- **`configure.sh` blocking** - Still blocked during restricted hours if `CONFIGURE_BLOCK_ENABLED=true`
- **`uninstall.sh` protection** - Still requires verification during restricted hours if `UNINSTALL_PROTECTION_MODE=difficult`
- **Restriction enforcement** - Restrictions are still active, only warnings are suppressed
- **Time validation** - `is_restricted_hour()` still returns true during pause
- **Config lock hours** - Still enforced if configured

## Rationale

**Pause is a "quiet period" for warnings, not a release of restrictions.**

This design maintains restriction effectiveness while providing user flexibility:
- Users can temporarily stop seeing warning popups (reduces annoyance)
- Restrictions remain in place (maintains self-control aid)
- Script blocking still works (prevents circumvention)
- Uninstall protection still works (prevents impulsive uninstalls)

## Implementation Details

### How Pause Works
1. User clicks pause button in warning popup
2. Pause state is activated (stored in `~/.config/sleep-warning/.pause_state`)
3. `sleep-warning.sh` checks pause state before showing popup
4. If pause active: Skip `show_warning()`, exit normally
5. If pause expired: Clear pause state, show warnings normally

### How Other Checks Work
1. `configure.sh` calls `check_config_lock_time()` which uses `is_restricted_hour()`
2. `uninstall.sh` calls `check_uninstall_protection_time()` which uses `is_restricted_hour()`
3. These functions check current time against restriction hours
4. **They do NOT check pause state** - pause is independent
5. Result: Blocking/protection still applies even during pause

## User Experience

**During Pause:**
- ✅ No warning popups appear
- ❌ Cannot run `configure.sh` (if blocking enabled)
- ❌ Cannot easily uninstall (if protection enabled)
- ✅ Restrictions are still "active" (just not shown via popups)

**After Pause Expires:**
- ✅ Warning popups resume
- ❌ Still cannot run `configure.sh` (if blocking enabled)
- ❌ Still cannot easily uninstall (if protection enabled)

## Edge Cases

### What if user pauses, then tries to configure?
- `configure.sh` will still block (checks restriction hours, not pause state)
- User must wait until restrictions end OR pause expires (whichever is later)

### What if user pauses, then tries to uninstall?
- `uninstall.sh` will still require verification (checks restriction hours, not pause state)
- User must complete verification OR wait until restrictions end

### What if pause expires while still in restricted hours?
- Warning popups resume immediately
- All other restrictions still apply

## Testing Requirements

- [ ] Verify pause suppresses popups
- [ ] Verify `configure.sh` still blocks during pause (if blocking enabled)
- [ ] Verify `uninstall.sh` still requires verification during pause (if protection enabled)
- [ ] Verify pause state is independent of restriction checks
- [ ] Document behavior clearly for users
