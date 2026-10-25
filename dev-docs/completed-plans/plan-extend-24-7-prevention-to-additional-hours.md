# Plan: Extend 24/7 Prevention and High Restriction Warnings to Additional Hours

> **Archived 2026-10-25.** Validation code shipped (Phases 1–4) with automated
> coverage in Tier-A `tests/test-24-7-prevention-additional-hours.sh`. The only
> remainder is manual integration verification, now tracked as smoke items in
> [TO_DO.md](../TO_DO.md#smoke-tests). Historical record.

**Related Enhancement**: Enhancement #22 (Prevent 24/7 Restriction Configuration)  
**Status**: Implementation Complete (Phases 1-5), Unit Tests Passing (27/27), Manual Integration Testing Pending  
**Priority**: High (safety feature extension)  
**Date Created**: 2026-01-26  
**Date Finalized**: 2026-01-26  
**Date Implementation Started**: 2026-01-26  
**Date Implementation Completed**: 2026-01-26

### Key Decisions Made

1. **Validation Scope**: Always validate additional hours regardless of feature enablement
2. **Safety Override Behavior**: Clear additional hours completely when high restrictions detected
3. **Warning Message Detail**: Medium detail level (clear but not overwhelming)

---

## Overview

Currently, Enhancement #22's 24/7 prevention and high restriction warnings only apply to **restriction hours** (the main schedule for sleep warnings). This plan extends the validation to also include:

1. **CONFIG_LOCK_HOURS_*** - Additional hours for config file locking and configure.sh/manage.sh blocking (Enhancement #20)
2. **UNINSTALL_LOCK_HOURS_*** - Additional hours for difficult uninstall verification (Enhancement #26 Phase 2)

The goal is to prevent users from accidentally configuring a combination of restriction hours + additional hours that would effectively lock them out of their system, even if the restriction hours alone don't exceed the thresholds.

---

## Background

### Current Implementation

- **Enhancement #22** validates only `config_lines[]` (restriction hours)
- Validation thresholds:
  - **THRESHOLD_BLOCK = 10080 minutes** (24 hours/day × 7 days) - blocks configuration
  - **THRESHOLD_WARN = 6720 minutes** (16 hours/day × 7 days) - shows warning
- When high restrictions detected (> 6720 minutes), safety overrides are applied:
  - Disable `CONFIGURE_BLOCK_ENABLED`
  - Disable `CONFIG_LOCK_ENABLED` (if implemented)
  - Restrict popup sizes to xsmall/small/medium only

### Current Code State (as of 2026-01-26)

**Already Implemented**:
- ✅ `lock_hours_lines[]` and `uninstall_lock_hours_lines[]` arrays declared in configure.sh (lines 149, 153)
- ✅ Arrays are passed to `write_config()` function (line 533)
- ✅ `write_config()` has pattern detection logic to separate the three array types (lib/configure-config.sh lines 460-530)
- ✅ `write_config()` handles override flags for popup_size and configure_block (lines 491-501, 640-644)
- ✅ Validation function `check_restriction_coverage()` exists (lib/configure-validation.sh line 192)

**Needs Implementation**:
- ❌ `check_restriction_coverage()` only processes `config_lines[]` - needs to accept and process all three arrays
- ❌ Validation call in configure.sh (line 476) only passes `config_lines[@]` - needs to pass all three arrays
- ❌ Safety overrides (lines 488-525) don't clear additional hours arrays - needs to be added
- ❌ Warning messages don't mention additional hours - needs to be updated
- ❌ `write_config()` doesn't handle override flags for clearing additional hours - needs to be added

### Additional Hours Types

1. **CONFIG_LOCK_HOURS_DAYNAME** (Enhancement #20):
   - Used for config file locking (Enhancement #18) and configure.sh/manage.sh blocking (Enhancement #19)
   - Format: `CONFIG_LOCK_HOURS_MONDAY=9-17` (same as restriction hours)
   - Stored in `lock_hours_lines[]` array in configure.sh
   - OR logic with restriction hours: blocking applies if current time is in restriction hours OR lock hours

2. **UNINSTALL_LOCK_HOURS_DAYNAME** (Enhancement #26 Phase 2):
   - Used for difficult uninstall verification
   - Format: `UNINSTALL_LOCK_HOURS_MONDAY=9-17` (same as restriction hours)
   - Stored in `uninstall_lock_hours_lines[]` array in configure.sh
   - OR logic with restriction hours: difficult verification applies if current time is in restriction hours OR uninstall lock hours

### Problem Statement

A user could configure:
- **Restriction hours**: 8 hours/day (6720 minutes/week) - valid, no warning
- **CONFIG_LOCK_HOURS**: 16 hours/day (11200 minutes/week) - no validation
- **UNINSTALL_LOCK_HOURS**: 8 hours/day (6720 minutes/week) - no validation
- **Total effective lockout**: 24+ hours/day when all combined

This creates a dangerous scenario where the user has effectively configured 24/7 restrictions, but the validation doesn't catch it because it only checks restriction hours.

---

## Goals

1. **Extend validation** to include all three types of hours (restriction + config lock + uninstall lock)
2. **Calculate combined coverage** across all three hour types
3. **Apply same thresholds** (10080 for block, 6720 for warn) to the combined total
4. **Update safety overrides** to also clear/disable additional hours when high restrictions detected
5. **Maintain backward compatibility** - existing configs without additional hours should work unchanged

---

## Implementation Approach

### Phase 1: Extend Validation Function

#### 1.1 Update `check_restriction_coverage()` Function

**File**: `lib/configure-validation.sh`

**Current Signature**:
```bash
check_restriction_coverage() {
    local config_lines=("$@")
    # ... validates only restriction hours
}
```

**New Signature**:
```bash
check_restriction_coverage() {
    local config_lines=("$@")
    local lock_hours_lines=()
    local uninstall_lock_hours_lines=()
    
    # Parse arguments to identify which arrays are which
    # config_lines: lines starting with "SUNDAY=", "MONDAY=", etc.
    # lock_hours_lines: lines starting with "CONFIG_LOCK_HOURS_"
    # uninstall_lock_hours_lines: lines starting with "UNINSTALL_LOCK_HOURS_"
    
    # Combine all three types into unified timeline
    # Apply same validation thresholds
}
```

**Implementation Strategy**:
1. **Parse arguments** to separate the three array types (similar to how `write_config()` detects them)
2. **Process each type** using the same interval conversion logic
3. **Combine all intervals** into a single unified timeline
4. **Merge overlaps** across all three types (critical - same day could have restriction hours + lock hours + uninstall lock hours overlapping)
5. **Calculate total** and compare against thresholds

**Key Considerations**:
- **Validation scope**: Always validate additional hours regardless of feature enablement (CONFIGURE_BLOCK_ENABLED, CONFIG_LOCK_ENABLED, UNINSTALL_PROTECTION_MODE). This is a safety check to prevent dangerous configurations.
- **Overlap handling**: If restriction hours "0-8" and lock hours "7-15" overlap at hour 7-8, they should merge to avoid double-counting
- **Cross-type overlaps**: All three types can overlap on the same day (e.g., restriction "0-8", lock "7-15", uninstall "10-18" all overlap)
- **Overnight ranges**: All three types support overnight ranges, must handle correctly
- **Empty arrays**: If lock_hours_lines or uninstall_lock_hours_lines are empty/not provided, should work as before (backward compatible)

#### 1.2 Argument Parsing Logic

**Pattern Detection** (similar to `write_config()` in `lib/configure-config.sh`):
```bash
# Identify array boundaries by prefix patterns:
# - config_lines: "SUNDAY=", "MONDAY=", etc. (contains "=" and day name)
# - lock_hours_lines: "CONFIG_LOCK_HOURS_SUNDAY=", etc. (starts with "CONFIG_LOCK_HOURS_")
# - uninstall_lock_hours_lines: "UNINSTALL_LOCK_HOURS_SUNDAY=", etc. (starts with "UNINSTALL_LOCK_HOURS_")

local all_args=("$@")
local config_lines=()
local lock_hours_lines=()
local uninstall_lock_hours_lines=()

for arg in "${all_args[@]}"; do
    if [[ "${arg}" =~ ^CONFIG_LOCK_HOURS_ ]]; then
        lock_hours_lines+=("${arg}")
    elif [[ "${arg}" =~ ^UNINSTALL_LOCK_HOURS_ ]]; then
        uninstall_lock_hours_lines+=("${arg}")
    elif [[ "${arg}" =~ ^(SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)= ]]; then
        config_lines+=("${arg}")
    fi
done
```

**Alternative Approach** (explicit parameters):
```bash
check_restriction_coverage() {
    local config_lines=("$@")
    # ... existing logic for restriction hours
    
    # If lock_hours_lines or uninstall_lock_hours_lines are provided as separate arrays,
    # process them similarly
}
```

**Decision**: Use pattern detection (first approach) to maintain compatibility with existing call sites that pass all arrays together.

#### 1.3 Combined Interval Processing

**Algorithm**:
1. Process restriction hours (existing logic)
2. Process lock hours (same logic, different source array)
3. Process uninstall lock hours (same logic, different source array)
4. Combine all intervals into single array
5. Merge overlapping intervals (existing `merge_overlapping_intervals()` function handles this)
6. Calculate total minutes
7. Compare against thresholds

**Code Structure**:
```bash
check_restriction_coverage() {
    local all_args=("$@")
    
    # Parse arguments into three arrays
    local config_lines=()
    local lock_hours_lines=()
    local uninstall_lock_hours_lines=()
    # ... parsing logic ...
    
    local all_intervals=()
    
    # Process restriction hours (existing logic)
    process_hours_array "config_lines" "all_intervals"
    
    # Process lock hours (new)
    process_hours_array "lock_hours_lines" "all_intervals"
    
    # Process uninstall lock hours (new)
    process_hours_array "uninstall_lock_hours_lines" "all_intervals"
    
    # Merge all intervals (existing logic)
    local final_intervals=$(merge_overlapping_intervals "${all_intervals[@]}")
    
    # Calculate total and return result (existing logic)
    # ...
}

# Helper function to process any hours array
process_hours_array() {
    local source_array_name="$1"
    local -n intervals_ref="$2"  # Pass by reference
    local -n source_ref="${source_array_name}"
    
    # Same logic as current restriction hours processing
    # Extract day index from "DAYVAR=" or "CONFIG_LOCK_HOURS_DAYVAR=" format
    # Convert to intervals, add to intervals_ref array
}
```

**Alternative**: Inline the processing logic three times (simpler, more explicit).  
**Decision**: Create helper function `process_hours_array()` to avoid code duplication.

**Note**: The pattern detection approach is already implemented in `write_config()` (lib/configure-config.sh lines 460-530). The same pattern matching logic can be reused:
- `CONFIG_LOCK_HOURS_` prefix for lock hours
- `UNINSTALL_LOCK_HOURS_` prefix for uninstall lock hours  
- Day name patterns (`SUNDAY=`, `MONDAY=`, etc.) for restriction hours

---

### Phase 2: Update configure.sh Integration

#### 2.1 Update Validation Call Site

**File**: `configure.sh` (line 476)

**Current Code**:
```bash
validation_result=$(check_restriction_coverage "${config_lines[@]}")
```

**New Code**:
```bash
# Pass all three arrays to validation function
validation_result=$(check_restriction_coverage \
    "${config_lines[@]}" \
    "${lock_hours_lines[@]}" \
    "${uninstall_lock_hours_lines[@]}")
```

**Note**: 
- The arrays `lock_hours_lines` and `uninstall_lock_hours_lines` are already declared in configure.sh (lines 149, 153)
- The function will automatically detect which arguments belong to which array type using pattern matching (same approach as `write_config()` uses)
- The pattern detection logic is already implemented in `write_config()` (lib/configure-config.sh lines 460-530) and can be reused

#### 2.2 Update Safety Overrides

**File**: `configure.sh` (lines 488-525)

**Current Behavior** (when high restrictions detected):
- Disable `CONFIGURE_BLOCK_ENABLED`
- Disable `CONFIG_LOCK_ENABLED`
- Restrict popup sizes

**New Behavior** (when high restrictions detected):
- Disable `CONFIGURE_BLOCK_ENABLED` (existing)
- Disable `CONFIG_LOCK_ENABLED` (existing)
- Restrict popup sizes (existing)
- **NEW**: Clear `lock_hours_lines[]` array (set all to empty)
- **NEW**: Clear `uninstall_lock_hours_lines[]` array (set all to empty)

**Implementation**:
```bash
case "${validation_result}" in
    "warn")
        # ... existing popup size and feature disabling ...
        
        # Safety override 4: Clear additional lock hours completely (Enhancement #20)
        # This prevents accidental lockout when combined with restriction hours
        # Decision: Clear completely (set all to empty) - safest approach
        local lock_hours_cleared="false"
        for i in 0 1 2 3 4 5 6; do
            if [ -n "${lock_hours_lines[$i]}" ]; then
                lock_hours_lines[$i]=""
                lock_hours_cleared="true"
            fi
        done
        
        # Safety override 5: Clear additional uninstall lock hours completely (Enhancement #26 Phase 2)
        # This prevents accidental lockout when combined with restriction hours
        # Decision: Clear completely (set all to empty) - safest approach
        local uninstall_lock_hours_cleared="false"
        for i in 0 1 2 3 4 5 6; do
            if [ -n "${uninstall_lock_hours_lines[$i]}" ]; then
                uninstall_lock_hours_lines[$i]=""
                uninstall_lock_hours_cleared="true"
            fi
        done
        ;;
esac
```

**Alternative**: Instead of clearing arrays, set override flags and let `write_config()` handle clearing.  
**Decision**: Clear arrays directly in configure.sh for simplicity and clarity.

---

### Phase 3: Update Documentation and Messages

#### 3.1 Update Error/Warning Messages

**File**: `lib/configure-ui.sh`

**Current Messages** (lib/configure-ui.sh lines 380, 415):
- "You have configured restrictions for all 24 hours, 7 days a week."
- "You have configured restrictions for more than 16 hours per day."

**New Messages** (medium detail - clarify that additional hours are included):
- "The combined total of restriction hours and additional lock hours covers all 24 hours, 7 days a week."
- "The combined total of restriction hours and additional lock hours exceeds 16 hours per day."

**Note**: The current messages also include emoji prefixes (🚨 ⚠️) and formatting - preserve these while updating the text.

**Decision**: Use medium detail messages. Clear enough to understand what's being validated, but not overwhelming. Detailed breakdown could be shown in a secondary info dialog if needed.

#### 3.2 Update Safety Override Comments

**File**: `lib/configure-config.sh` (in `write_config()`)

**Current Comments** (when high restrictions detected):
- "# CONFIGURE_BLOCK_ENABLED has been disabled because restrictions exceed 16 hours/day."
- "# POPUP_SIZE has been restricted..."

**New Comments** (when additional hours cleared):
- "# CONFIG_LOCK_HOURS have been cleared because combined restrictions exceed 16 hours/day."
- "# UNINSTALL_LOCK_HOURS have been cleared because combined restrictions exceed 16 hours/day."

**Implementation**: 
1. Add new override flags to `write_config()` call in configure.sh (line 533):
```bash
write_config ... "${popup_size_overridden}" "${configure_block_overridden}" \
    "${lock_hours_cleared}" "${uninstall_lock_hours_cleared}"
```

2. Update `write_config()` in lib/configure-config.sh to:
   - Detect the new override flags (extend the override flag detection logic around lines 491-501)
   - Add config file comments when additional hours are cleared (similar to lines 640-644 for configure_block_overridden)

**Note**: The `write_config()` function already has pattern detection logic for separating arrays (lines 460-530) and override flag detection (lines 491-501). This can be extended to detect the new override flags.

#### 3.3 Update User Documentation

**File**: `user-docs/CONFIGURATION.md`

**Add Section**: "24/7 Prevention and Additional Hours"

**Content**:
- Explain that validation includes restriction hours + config lock hours + uninstall lock hours
- Provide examples of dangerous combinations
- Explain that additional hours are automatically cleared when high restrictions detected

**File**: `dev-docs/TECHNICAL_DETAILS.md`

**Update Section**: "24/7 Restriction Prevention"

**Content**:
- Document that validation now includes all three hour types
- Explain the combined coverage calculation
- Document the safety override behavior for additional hours

---

### Phase 4: Testing

#### 4.1 Unit Tests

**File**: `tests/test-24-7-prevention-additional-hours.sh` (new)

**Test Cases**:
1. **Restriction hours only** (existing behavior) - should work unchanged
2. **Restriction hours + lock hours** that together exceed 10080 minutes - should block
3. **Restriction hours + uninstall lock hours** that together exceed 10080 minutes - should block
4. **All three types** that together exceed 10080 minutes - should block
5. **Restriction hours + lock hours** that together exceed 6720 but < 10080 - should warn
6. **Overlapping ranges** across types (e.g., restriction "0-8", lock "7-15") - should merge correctly
7. **Overnight ranges** across types - should handle correctly
8. **Empty additional hours** (backward compatibility) - should work as before

#### 4.2 Integration Tests

**Test Scenarios**:
1. Configure restriction hours (8 hours/day) + lock hours (16 hours/day) = 24 hours/day total
   - Should detect as 24/7 and block
2. Configure restriction hours (8 hours/day) + uninstall lock hours (16 hours/day) = 24 hours/day total
   - Should detect as 24/7 and block
3. Configure restriction hours (10 hours/day) + lock hours (8 hours/day) = 18 hours/day total
   - Should show warning, clear additional hours when confirmed
4. Configure restriction hours (8 hours/day) + lock hours (8 hours/day) + uninstall lock hours (8 hours/day) = 24 hours/day total
   - Should detect as 24/7 and block

#### 4.3 Edge Cases

1. **Overlapping ranges across types**:
   - Restriction: "0-8"
   - Lock: "7-15"
   - Uninstall: "10-18"
   - Should merge to "0-18" (18 hours), not count as 26 hours

2. **Overnight ranges across types**:
   - Restriction: Monday "23-6"
   - Lock: Monday "22-5"
   - Should merge correctly

3. **Empty arrays**:
   - Only restriction hours configured (no additional hours)
   - Should work exactly as before (backward compatibility)

4. **Sparse arrays**:
   - Only some days have additional hours
   - Should calculate correctly

---

## Decisions Made

### 1. Validation Scope

**Decision**: **Always validate additional hours** regardless of feature enablement.

**Rationale**: This prevents users from creating dangerous configurations that could lock them out if they later enable the features. The validation is a safety check, not a runtime check.

**Example Scenario**:
- Restriction hours: 8 hours/day (6720 minutes/week) - valid
- CONFIG_LOCK_HOURS: 16 hours/day (11200 minutes/week)
- But `CONFIGURE_BLOCK_ENABLED=false` (feature disabled)
- **Result**: Still validated and blocked if total exceeds thresholds

### 2. Safety Override Behavior

**Decision**: **Clear additional hours completely** (set all to empty) when high restrictions detected.

**Rationale**: This is the safest approach and matches the existing behavior of disabling features. Users can reconfigure additional hours after reducing restriction hours.

**Implementation**: When high restrictions (> 6720 minutes) are detected and user confirms:
- Clear all `lock_hours_lines[]` entries (set to empty string)
- Clear all `uninstall_lock_hours_lines[]` entries (set to empty string)
- Add config file comments explaining why they were cleared

### 3. Warning Message Detail Level

**Decision**: **Medium detail** - Clear enough to understand what's being validated, but not overwhelming.

**Messages**:
- 24/7 Error: "The combined total of restriction hours and additional lock hours covers all 24 hours, 7 days a week."
- High Restriction Warning: "The combined total of restriction hours and additional lock hours exceeds 16 hours per day."

**Note**: Detailed breakdown (exact hours per type) could be shown in a secondary info dialog if needed in the future.

### 4. Backward Compatibility

**Decision**: **Yes** - The function must work with old call sites that only pass `config_lines[]`.

**Implementation**: The function detects which arguments are which based on patterns. If only `config_lines[]` is passed, it works exactly as before (backward compatible).

---

## Potential Issues

### 1. Performance Impact

**Issue**: Processing three arrays instead of one could slow down validation.

**Mitigation**:
- Validation only runs once per configuration save (not continuously)
- Time complexity is still O(n log n) where n = total number of ranges across all types
- Should be negligible (< 1 second even with many ranges)

**Testing**: Profile validation function with large configurations to ensure acceptable performance.

### 2. Argument Parsing Complexity

**Issue**: Pattern-based argument parsing could be fragile or confusing.

**Mitigation**:
- Use clear, unique prefixes ("CONFIG_LOCK_HOURS_", "UNINSTALL_LOCK_HOURS_", day names)
- Add validation to ensure patterns are unambiguous
- Add unit tests for argument parsing edge cases

**Alternative**: Use explicit function parameters (but requires updating all call sites).

### 3. Overlap Calculation Accuracy

**Issue**: Merging intervals across three different types must be accurate.

**Mitigation**:
- Reuse existing `merge_overlapping_intervals()` function (already tested)
- Add comprehensive tests for cross-type overlaps
- Verify edge cases (overnight ranges, multiple overlaps per day)

### 4. Safety Override Side Effects

**Issue**: Clearing additional hours arrays modifies user's configuration without explicit confirmation.

**Mitigation**:
- Warning dialog already explains that safety measures will be applied
- Config file comments explain why additional hours were cleared
- User can reconfigure additional hours after reducing restriction hours

**Alternative**: Show separate confirmation for clearing additional hours (but adds complexity).

### 5. Documentation Updates

**Issue**: Multiple documentation files need updates.

**Mitigation**:
- Create checklist of all files that need updates
- Update user docs and technical docs together
- Add examples showing combined validation

---

## Implementation Checklist

### Phase 1: Core Validation Extension
- [x] Update `check_restriction_coverage()` function signature
- [x] Implement argument parsing to separate three array types
- [x] Create `process_hours_array()` helper function
- [x] Update interval processing to handle all three types
- [x] Verify overlap merging works correctly across types
- [ ] Add unit tests for argument parsing
- [ ] Add unit tests for combined coverage calculation

### Phase 2: configure.sh Integration
- [x] Update validation call site to pass all three arrays
- [x] Update safety overrides to clear additional hours
- [x] Add override flags for additional hours clearing
- [x] Update `write_config()` to handle additional hours override flags
- [x] Add config file comments when additional hours cleared

### Phase 3: UI and Messages
- [x] Update `show_24_7_error()` message to mention additional hours
- [x] Update `show_high_restriction_warning()` message to mention additional hours
- [x] Update safety override comments in config file

### Phase 4: Documentation
- [x] Update `user-docs/CONFIGURATION.md` with combined validation explanation
- [x] Update `dev-docs/TECHNICAL_DETAILS.md` with implementation details
- [x] Update Enhancement #22 document to note extension

### Phase 5: Testing
- [ ] Create unit test file `tests/test-24-7-prevention-additional-hours.sh`
- [ ] Test restriction hours only (backward compatibility)
- [ ] Test restriction + lock hours combinations
- [ ] Test restriction + uninstall lock hours combinations
- [ ] Test all three types together
- [ ] Test overlapping ranges across types
- [ ] Test overnight ranges across types
- [ ] Test edge cases (empty arrays, sparse arrays)
- [ ] Integration test: Configure dangerous combination, verify blocking
- [ ] Integration test: Configure high restriction combination, verify warning and clearing

---

## Success Criteria

1. ✅ **Validation correctly detects 24/7 restrictions** when restriction hours + additional hours exceed 10080 minutes - **VERIFIED** (27/27 unit tests passing)
2. ✅ **Validation correctly warns** when combined total exceeds 6720 minutes - **VERIFIED** (tests passing)
3. ✅ **Safety overrides clear additional hours** when high restrictions detected - **IMPLEMENTED** (configure.sh lines 525-545)
4. ✅ **Backward compatibility maintained** (configs without additional hours work unchanged) - **VERIFIED** (tests passing)
5. ✅ **Overlapping ranges across types are correctly merged** (no double-counting) - **VERIFIED** (overlap tests passing)
6. ✅ **Documentation updated** to explain combined validation - **COMPLETE** (CONFIGURATION.md, TECHNICAL_DETAILS.md, Enhancement #22)
7. ✅ **All unit tests pass** - **VERIFIED** (27/27 tests passing)

---

## Related Documents

- [Enhancement #22: Prevent 24/7 Restriction Configuration](../enhancements/enhancement-22-prevent-24-7-restriction-configuration.md)
- [Enhancement #20: Additional Hours for Config Locking](../enhancements/enhancement-20-additional-hours-config-locking.md)
- [Enhancement #26: Prevent uninstall.sh Execution During Restricted Hours](../enhancements/enhancement-26-prevent-uninstall-during-restricted-hours.md)
- [REMAINING_WORK_SUMMARY.md](../REMAINING_WORK_SUMMARY.md) - Line 8

---

**Last Updated**: 2026-01-26  
**Implementation Completed**: 2026-01-26  
**Unit Tests**: 27/27 passing  
**Author**: AI Assistant
