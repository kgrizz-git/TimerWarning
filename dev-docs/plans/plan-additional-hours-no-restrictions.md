# Plan: Additional Hours Should Not Apply on Days with No Restrictions

## Overview

** This is only an idea for consideration. It may or may not ever be implemented. 

Currently, additional lock hours (config lock hours and uninstall lock hours) can be configured and will apply even on days that have no restricted times configured. This plan addresses making additional hours conditional on the presence of restriction hours for that day, with a user-configurable option to allow additional hours without restrictions (disabled by default).

## Goals

1. **Default Behavior**: Additional lock hours and uninstall lock hours should NOT apply on days when there are no restricted times configured
2. **User Configurable**: Add a configuration option to allow additional hours to apply even on days with no restrictions (disabled by default)
3. **User Warning**: Warn users when they enter additional hours on days that have no restrictions configured
4. **Backward Compatibility**: Existing configurations should continue to work (with new default behavior applied)

## Background

### Current Behavior

- **Config Lock Hours** (`CONFIG_LOCK_HOURS_DAYNAME`): Additional hours for blocking `configure.sh` and `manage.sh` (Enhancement #19 Phase 2)
- **Uninstall Lock Hours** (`UNINSTALL_LOCK_HOURS_DAYNAME`): Additional hours for difficult uninstall verification (Enhancement #26 Phase 2)
- Both types of additional hours currently apply regardless of whether the day has restriction hours configured
- This means a user could configure additional hours on a day with no restrictions, and those hours would still block configuration/uninstall

### Problem

If a user configures:
- `MONDAY=` (no restrictions)
- `CONFIG_LOCK_HOURS_MONDAY=9-17` (additional lock hours 9 AM - 5 PM)

Currently, `configure.sh` would be blocked during 9 AM - 5 PM on Monday, even though Monday has no restrictions. This may be unexpected behavior.

### Proposed Solution

1. **Default**: Additional hours only apply if the day has at least some restriction hours configured
2. **Optional Override**: New config option `ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS=false` (default) allows users to enable the old behavior if desired
3. **Warning During Configuration**: When configuring additional hours, warn users if the day has no restrictions

## Implementation Details

### 1. Configuration File Support

#### 1.1 Add New Configuration Option

**File**: `sleep-warning.conf`

Add new configuration variable:
```bash
# Allow additional lock hours and uninstall lock hours to apply on days with no restrictions (true/false)
# Default: false (additional hours only apply on days that have restriction hours)
# When false: Additional hours are ignored on days with no restriction hours configured
# When true: Additional hours apply even on days with no restriction hours (legacy behavior)
ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS=false
```

**File**: `lib/config.sh`

Add function to read this setting:
```bash
# Get additional hours apply without restrictions setting from configuration file
# Returns "true" if additional hours should apply on days with no restrictions, "false" otherwise
# Default: false (additional hours only apply on days with restriction hours)
get_additional_hours_apply_without_restrictions() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "false"  # Default
        return 0
    fi
    
    # Read ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS from config file
    local setting
    setting=$(grep -E "^[[:space:]]*ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    if [ "${setting}" = "true" ] || [ "${setting}" = "1" ] || [ "${setting}" = "yes" ]; then
        echo "true"
        return 0
    else
        # Default to false (safe default)
        echo "false"
        return 0
    fi
}
```

**File**: `lib/configure-config.sh`

Add loading of this setting in `load_config()` function:
```bash
# Load additional hours apply without restrictions setting
local existing_apply_without_restrictions
existing_apply_without_restrictions=$(grep -E "^[[:space:]]*ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

if [ -n "${existing_apply_without_restrictions}" ]; then
    if [ "${existing_apply_without_restrictions}" = "true" ] || [ "${existing_apply_without_restrictions}" = "1" ] || [ "${existing_apply_without_restrictions}" = "yes" ]; then
        declare -g additional_hours_apply_without_restrictions="true"
    else
        declare -g additional_hours_apply_without_restrictions="false"
    fi
else
    # Default to false
    declare -g additional_hours_apply_without_restrictions="false"
fi
```

### 2. Update Time Validation Functions

#### 2.1 Update `check_config_lock_time()`

**File**: `lib/time-validation.sh`

Modify the function to check if the day has restrictions before applying lock hours:

```bash
check_config_lock_time() {
    # ... existing code to check CONFIGURE_BLOCK_ENABLED ...
    
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    
    # Get current hour (0-23)
    local current_hour
    current_hour=$(date +%H)
    current_hour=$((10#${current_hour}))
    
    # Parse configuration for current day (restriction hours)
    local restricted_range
    restricted_range=$(parse_config "${current_day}")
    
    # Check if current hour is within restricted range for current day
    if is_restricted_hour "${current_hour}" "${restricted_range}"; then
        # Current hour is restricted - block execution
        return 1
    fi
    
    # Check previous day's restriction hours (overnight ranges)
    # ... existing overnight range checking code ...
    
    # Parse lock hours for current day (Phase 2)
    local lock_hours_range=""
    if type parse_lock_hours >/dev/null 2>&1; then
        lock_hours_range=$(parse_lock_hours "${current_day}")
    fi
    
    # NEW: Check if additional hours should apply on days without restrictions
    local apply_without_restrictions="false"
    if type get_additional_hours_apply_without_restrictions >/dev/null 2>&1; then
        apply_without_restrictions=$(get_additional_hours_apply_without_restrictions)
    fi
    
    # Check if current day has restrictions (including overnight from previous day)
    local day_has_restrictions="false"
    if [ -n "${restricted_range}" ]; then
        day_has_restrictions="true"
    else
        # Check if previous day has overnight ranges extending into current day
        # ... use existing overnight checking logic to determine if day_has_restrictions should be true ...
    fi
    
    # Only check lock hours if:
    # 1. Day has restrictions, OR
    # 2. apply_without_restrictions is true
    if [ "${day_has_restrictions}" = "true" ] || [ "${apply_without_restrictions}" = "true" ]; then
        # Check if current hour is within lock hours for current day (Phase 2)
        if [ -n "${lock_hours_range}" ] && type is_lock_hour >/dev/null 2>&1; then
            if is_lock_hour "${current_hour}" "${lock_hours_range}"; then
                # Current hour is in lock hours - block execution
                return 1
            fi
        fi
        
        # Check previous day's lock hours (overnight ranges) - Phase 2
        # ... existing overnight lock hours checking code ...
    fi
    
    # Not in restricted hours or lock hours - allow execution
    return 0
}
```

#### 2.2 Update `check_uninstall_protection_time()`

**File**: `lib/time-validation.sh`

Similar modification to check if day has restrictions before applying uninstall lock hours:

```bash
check_uninstall_protection_time() {
    # ... existing code to check UNINSTALL_PROTECTION_MODE ...
    
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    
    # Get current hour (0-23)
    local current_hour
    current_hour=$(date +%H)
    current_hour=$((10#${current_hour}))
    
    # Parse configuration for current day (restriction hours)
    local restricted_range
    if type parse_config >/dev/null 2>&1; then
        restricted_range=$(parse_config "${current_day}")
    fi
    
    # Check if current hour is within restricted range for current day
    if [ -n "${restricted_range}" ] && type is_restricted_hour >/dev/null 2>&1; then
        if is_restricted_hour "${current_hour}" "${restricted_range}"; then
            # Current hour is restricted - return protection mode
            echo "${protection_mode}"
            return 0
        fi
    fi
    
    # Check previous day's restriction hours (overnight ranges)
    # ... existing overnight range checking code ...
    
    # Phase 2: Check uninstall lock hours (separate from restriction hours)
    local uninstall_lock_range
    if type parse_uninstall_lock_hours >/dev/null 2>&1; then
        uninstall_lock_range=$(parse_uninstall_lock_hours "${current_day}")
    fi
    
    # NEW: Check if additional hours should apply on days without restrictions
    local apply_without_restrictions="false"
    if type get_additional_hours_apply_without_restrictions >/dev/null 2>&1; then
        apply_without_restrictions=$(get_additional_hours_apply_without_restrictions)
    fi
    
    # Check if current day has restrictions (including overnight from previous day)
    local day_has_restrictions="false"
    if [ -n "${restricted_range}" ]; then
        day_has_restrictions="true"
    else
        # Check if previous day has overnight ranges extending into current day
        # ... use existing overnight checking logic ...
    fi
    
    # Only check uninstall lock hours if:
    # 1. Day has restrictions, OR
    # 2. apply_without_restrictions is true
    if [ "${day_has_restrictions}" = "true" ] || [ "${apply_without_restrictions}" = "true" ]; then
        # Check if current hour is within uninstall lock hours for current day
        if [ -n "${uninstall_lock_range}" ] && type is_uninstall_lock_hour >/dev/null 2>&1; then
            if is_uninstall_lock_hour "${current_hour}" "${uninstall_lock_range}"; then
                # Current hour is in uninstall lock hours - return protection mode
                echo "${protection_mode}"
                return 0
            fi
        fi
        
        # Check previous day's uninstall lock hours (overnight ranges)
        # ... existing overnight uninstall lock hours checking code ...
    fi
    
    # Not in restricted hours or uninstall lock hours - return "none" (no protection needed)
    echo "none"
    return 0
}
```

### 3. Update Configuration Workflow

#### 3.1 Add Warning When Configuring Additional Hours on Days Without Restrictions

**File**: `lib/configure-workflow.sh`

Modify `configure_lock_hours_section()` to check and warn:

```bash
configure_lock_hours_section() {
    # ... existing code ...
    
    while [ "${day_index}" -le 6 ]; do
        local day_name="${DAY_NAMES[${day_index}]}"
        
        # Build friendly label
        local label="Additional Block Hours - ${day_name}"
        
        # NEW: Check if this day has restrictions configured
        local day_has_restrictions="false"
        if [ -n "${config_lines_ref[${day_index}]:-}" ]; then
            local day_line="${config_lines_ref[${day_index}]}"
            local day_range
            day_range=$(echo "${day_line}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "${day_range}" ]; then
                day_has_restrictions="true"
            fi
        fi
        
        # Allow back navigation
        local allow_back="false"
        if [ "${day_index}" -gt 0 ]; then
            allow_back="true"
        fi
        
        local range
        range=$(get_day_hours "${label}" "${day_index}" "${use_gui}" "${allow_back}" "true")
        local exit_code=$?
        
        # ... handle cancellation/back navigation ...
        
        if [ "${range}" != "skip" ]; then
            # User configured lock hours for this day
            
            # NEW: Warn if day has no restrictions
            if [ "${day_has_restrictions}" = "false" ] && [ -n "${range}" ]; then
                local warning_message
                warning_message="WARNING: ${day_name} has no restriction hours configured.\n\n"
                warning_message="${warning_message}Additional lock hours will NOT apply on ${day_name} unless you:\n"
                warning_message="${warning_message}1. Configure restriction hours for ${day_name}, OR\n"
                warning_message="${warning_message}2. Enable 'Allow Additional Hours Without Restrictions' in Security Settings\n\n"
                warning_message="${warning_message}Do you want to continue configuring lock hours for ${day_name}?"
                
                if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                    if ! show_yesno_dialog \
                        "Warning: No Restrictions on ${day_name}" \
                        "${warning_message}" \
                        600 \
                        300; then
                        # User chose "No" - skip this day
                        local day_var="${DAY_VARS[${day_index}]}"
                        lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}="
                        day_index=$((day_index + 1))
                        continue
                    fi
                else
                    echo "" >&2
                    echo "WARNING: ${day_name} has no restriction hours configured." >&2
                    echo "Additional lock hours will NOT apply on ${day_name} unless you:" >&2
                    echo "1. Configure restriction hours for ${day_name}, OR" >&2
                    echo "2. Enable 'Allow Additional Hours Without Restrictions' in Security Settings" >&2
                    echo "" >&2
                    read -p "Continue configuring lock hours for ${day_name}? (y/n): " confirm
                    if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
                        # User chose not to continue - skip this day
                        local day_var="${DAY_VARS[${day_index}]}"
                        lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}="
                        day_index=$((day_index + 1))
                        continue
                    fi
                fi
            fi
            
            # User configured lock hours for this day
            local day_var="${DAY_VARS[${day_index}]}"
            lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}=${range}"
        else
            # Explicitly skipped
            local day_var="${DAY_VARS[${day_index}]}"
            lock_hours_lines_ref[${day_index}]="CONFIG_LOCK_HOURS_${day_var}="
        fi
        
        # Move to next day
        day_index=$((day_index + 1))
    done
    
    return 0
}
```

Similar modification needed for `configure_uninstall_lock_hours_section()`.

#### 3.2 Add Configuration Option to Security Settings

**File**: `lib/configure-workflow.sh`

Add a new section or integrate into existing security settings workflow:

```bash
configure_security_settings_section() {
    local use_gui="$1"
    
    # ... existing security settings (CONFIG_LOCK_ENABLED, CONFIGURE_BLOCK_ENABLED, etc.) ...
    
    # NEW: Ask about additional hours apply without restrictions
    local current_setting="false"
    if [ -n "${additional_hours_apply_without_restrictions:-}" ]; then
        current_setting="${additional_hours_apply_without_restrictions}"
    fi
    
    local prompt_text="Allow Additional Hours Without Restrictions\n\n"
    prompt_text="${prompt_text}When enabled, additional lock hours and uninstall lock hours will apply even on days with no restriction hours configured.\n\n"
    prompt_text="${prompt_text}When disabled (default), additional hours only apply on days that have restriction hours configured.\n\n"
    prompt_text="${prompt_text}Current setting: "
    if [ "${current_setting}" = "true" ]; then
        prompt_text="${prompt_text}Enabled"
    else
        prompt_text="${prompt_text}Disabled (recommended)"
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        if show_yesno_dialog \
            "Security Settings" \
            "${prompt_text}\n\nEnable this setting?" \
            600 \
            300; then
            declare -g additional_hours_apply_without_restrictions="true"
        else
            declare -g additional_hours_apply_without_restrictions="false"
        fi
    else
        echo "" >&2
        echo "Allow Additional Hours Without Restrictions" >&2
        echo "" >&2
        echo "When enabled, additional lock hours and uninstall lock hours will apply" >&2
        echo "even on days with no restriction hours configured." >&2
        echo "" >&2
        echo "When disabled (default), additional hours only apply on days that have" >&2
        echo "restriction hours configured." >&2
        echo "" >&2
        local current_display
        if [ "${current_setting}" = "true" ]; then
            current_display="Enabled"
        else
            current_display="Disabled (recommended)"
        fi
        echo "Current setting: ${current_display}" >&2
        echo "" >&2
        read -p "Enable this setting? (y/n) [n]: " enable
        enable=${enable:-n}
        if [ "${enable}" = "y" ] || [ "${enable}" = "Y" ]; then
            declare -g additional_hours_apply_without_restrictions="true"
        else
            declare -g additional_hours_apply_without_restrictions="false"
        fi
    fi
}
```

**File**: `lib/configure-config.sh`

Update `write_config()` to save this setting:

```bash
write_config() {
    # ... existing code ...
    
    # Write additional hours apply without restrictions setting
    if [ -n "${additional_hours_apply_without_restrictions:-}" ]; then
        echo "ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS=${additional_hours_apply_without_restrictions}" >> "${tmp_config}"
    else
        # Default to false if not set
        echo "ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS=false" >> "${tmp_config}"
    fi
    
    # ... rest of write_config() ...
}
```

### 4. Update Configuration Wizard Menu

**File**: `configure.sh`

Add menu option for security settings (if not already present) or integrate into existing security menu.

### 5. Update Documentation

#### 5.1 User Documentation

**File**: `user-docs/CONFIGURATION.md`

Add section explaining the new behavior:

```markdown
### Additional Hours Apply Without Restrictions

**Description**: Controls whether additional lock hours and uninstall lock hours apply on days with no restriction hours configured.

**Default**: `false` (additional hours only apply on days with restriction hours)

**Values**:
- `false` (default): Additional hours are ignored on days with no restriction hours
- `true`: Additional hours apply even on days with no restriction hours (legacy behavior)

**How It Works**:
- When `false` (default): If a day has no restriction hours configured, any additional lock hours or uninstall lock hours for that day will be ignored
- When `true`: Additional hours apply regardless of whether the day has restriction hours

**Example**:
```
MONDAY=                    # No restrictions on Monday
CONFIG_LOCK_HOURS_MONDAY=9-17  # Additional lock hours 9 AM - 5 PM

# With ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS=false (default):
# configure.sh will NOT be blocked on Monday (lock hours ignored)

# With ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS=true:
# configure.sh WILL be blocked on Monday 9 AM - 5 PM (lock hours apply)
```

**Configuration via Wizard**:
- Use Security Settings menu option to enable/disable this setting
```

#### 5.2 Developer Documentation

**File**: `dev-docs/TECHNICAL_DETAILS.md`

Update sections on:
- Time validation functions
- Additional hours behavior
- Configuration workflow

### 6. Update Status Display

**File**: `status.sh`

Update status output to show this setting and explain its effect:

```bash
# Display additional hours apply without restrictions setting
local apply_without_restrictions
apply_without_restrictions=$(get_additional_hours_apply_without_restrictions 2>/dev/null || echo "false")

echo "Additional Hours Behavior:"
if [ "${apply_without_restrictions}" = "true" ]; then
    echo "  Additional hours apply even on days with no restrictions (enabled)"
else
    echo "  Additional hours only apply on days with restrictions (default)"
fi
```

## Implementation Checklist

### Phase 1: Core Functionality
- [ ] Add `ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS` config variable to `sleep-warning.conf`
- [ ] Add `get_additional_hours_apply_without_restrictions()` function to `lib/config.sh`
- [ ] Update `load_config()` in `lib/configure-config.sh` to load the setting
- [ ] Update `write_config()` in `lib/configure-config.sh` to save the setting
- [ ] Modify `check_config_lock_time()` in `lib/time-validation.sh` to check day restrictions
- [ ] Modify `check_uninstall_protection_time()` in `lib/time-validation.sh` to check day restrictions

### Phase 2: Configuration Workflow
- [ ] Add warning in `configure_lock_hours_section()` when configuring on days without restrictions
- [ ] Add warning in `configure_uninstall_lock_hours_section()` when configuring on days without restrictions
- [ ] Add security settings option to configure `ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS`
- [ ] Update configuration wizard menu to include security settings (if needed)

### Phase 3: Documentation and Status
- [ ] Update `user-docs/CONFIGURATION.md` with new setting documentation
- [ ] Update `dev-docs/TECHNICAL_DETAILS.md` with implementation details
- [ ] Update `status.sh` to display the setting and its effect
- [ ] Update any relevant enhancement documents

### Phase 4: Testing
- [ ] Test that additional hours are ignored on days with no restrictions (default behavior)
- [ ] Test that additional hours apply when setting is enabled
- [ ] Test warning when configuring additional hours on days without restrictions
- [ ] Test overnight ranges (previous day restrictions extending into current day)
- [ ] Test backward compatibility (existing configs work with new default)
- [ ] Test both config lock hours and uninstall lock hours

## Edge Cases and Considerations

### Overnight Ranges
- When checking if a day "has restrictions", we need to consider overnight ranges from the previous day
- If previous day has an overnight range extending into current day, current day should be considered as "having restrictions" for the purpose of this check

### Empty vs. Not Configured
- A day with `MONDAY=` (empty, explicitly skipped) should be treated as "no restrictions"
- A day with no `MONDAY=` line at all should also be treated as "no restrictions"
- Both cases should trigger the same behavior

### Backward Compatibility
- Existing configurations without `ADDITIONAL_HOURS_APPLY_WITHOUT_RESTRICTIONS` will default to `false`
- This means existing configs with additional hours on days without restrictions will stop applying those hours
- This is intentional - the new default is safer and more intuitive
- Users can enable the setting if they want the old behavior

### Configuration Order
- Users might configure additional hours before configuring restriction hours
- The warning should help guide users to configure restriction hours first, or enable the setting

## Testing Strategy

### Unit Tests
1. Test `get_additional_hours_apply_without_restrictions()` with various config values
2. Test `check_config_lock_time()` with:
   - Day with restrictions + lock hours (should apply)
   - Day without restrictions + lock hours, setting=false (should not apply)
   - Day without restrictions + lock hours, setting=true (should apply)
   - Overnight ranges from previous day
3. Test `check_uninstall_protection_time()` with similar scenarios

### Integration Tests
1. Configure restriction hours for some days, not others
2. Configure additional hours on days with and without restrictions
3. Verify blocking behavior matches expectations
4. Test configuration workflow warnings

### Manual Testing
1. Configure a day with no restrictions but with additional hours
2. Verify warning appears
3. Test that additional hours don't apply (default)
4. Enable setting and verify additional hours do apply
5. Test with overnight ranges

## Related Enhancements

- **Enhancement #19 Phase 2**: Additional Configurable Lock Hours
- **Enhancement #26 Phase 2**: Additional Uninstall Lock Hours
- **Enhancement #20**: Additional Hours for Config Locking

## Future Considerations

- Consider making this a per-day setting instead of global (e.g., `CONFIG_LOCK_HOURS_MONDAY_APPLY_WITHOUT_RESTRICTIONS=true`)
- Consider showing a summary of which days have additional hours but no restrictions during configuration review
