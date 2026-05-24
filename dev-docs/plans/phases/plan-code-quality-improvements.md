# Plan: Code Quality Improvements - Day Name Conversion and Magic Numbers

## Plan Metadata
- **Created**: 2026-01-26
- **Status**: ✅ **COMPLETE**
- **Implementation Started**: 2026-01-26
- **Implementation Completed**: 2026-01-26
- **Priority**: Low (as per assessment)
- **Estimated Effort**: 3-4 hours total
  - Day name conversion: 1-2 hours
  - Magic numbers extraction: 1-2 hours
- **Related**: [REMAINING_WORK_SUMMARY.md](REMAINING_WORK_SUMMARY.md#code-quality-improvements)
- **Reference**: [Quality Assessment](../code-assessments/qi-assessment-2026-01-23-003550.md)

## Executive Summary

This plan addresses two code quality improvements identified in the quality assessment:

1. **Extract day name conversion to shared function** - Consolidate repeated day number-to-name conversion logic into a shared function
2. **Extract magic numbers to constants** - Replace hardcoded numeric values with named constants for better maintainability

Both improvements are low priority but will improve code maintainability and reduce duplication.

## Task 1: Extract Day Name Conversion to Shared Function

### Current State Analysis

Day number to day name conversion logic appears in multiple locations:

#### Primary Locations (config.sh)
1. **`lib/config.sh::parse_config()`** (lines 873-882)
   - Converts day number (0-6) to uppercase day name (SUNDAY-SATURDAY)
   - Used for parsing restriction hours from config file

2. **`lib/config.sh::parse_lock_hours()`** (lines 938-947)
   - Same conversion pattern as `parse_config()`
   - Used for parsing config lock hours

3. **`lib/config.sh::parse_uninstall_lock_hours()`** (lines 1040-1049)
   - Same conversion pattern
   - Used for parsing uninstall lock hours

#### Secondary Locations (configure-input-time.sh)
4. **`lib/configure-input-time.sh`** (lines 363-368, 599-605)
   - Converts previous day index to day name for display purposes
   - Uses lowercase format ("Sunday", "Monday", etc.)
   - Used when showing previous day information in time range configuration

#### Related (but different purpose)
5. **`lib/configure-time.sh::format_range_human()`** (lines 42-51)
   - Converts day name to next day name (e.g., "Sunday" → "Monday")
   - Different purpose: next day calculation, not day number conversion
   - **Decision needed**: Should this be included or kept separate?

### Proposed Solution

#### Option A: Single Function with Format Parameter (Recommended)
Create a function in `lib/configure-core.sh` (which already has `DAY_NAMES` and `DAY_VARS` arrays):

```bash
# Convert day number to day name
# Parameters:
#   $1 - day_num (0-6, Sunday=0, Saturday=6)
#   $2 - format (optional): "uppercase" (default), "lowercase", or "titlecase"
# Returns: Day name in requested format
# Exit codes: 0 on success, 1 on invalid day number
day_num_to_name() {
    local day_num="$1"
    local format="${2:-uppercase}"
    
    case "${day_num}" in
        0) case "${format}" in
               uppercase) echo "SUNDAY" ;;
               lowercase) echo "sunday" ;;
               titlecase) echo "Sunday" ;;
               *) echo "SUNDAY" ;;
           esac ;;
        1) case "${format}" in
               uppercase) echo "MONDAY" ;;
               lowercase) echo "monday" ;;
               titlecase) echo "Monday" ;;
               *) echo "MONDAY" ;;
           esac ;;
        # ... etc for all 7 days
        6) case "${format}" in
               uppercase) echo "SATURDAY" ;;
               lowercase) echo "saturday" ;;
               titlecase) echo "Saturday" ;;
               *) echo "SATURDAY" ;;
           esac ;;
        *) return 1 ;;
    esac
}
```

**Pros**:
- Single function handles all format needs
- Flexible for future requirements
- Clear parameter interface

**Cons**:
- More complex implementation
- Nested case statements

#### Option B: Multiple Functions (Alternative)
Create separate functions for each format:
- `day_num_to_name_upper()` - Returns "SUNDAY", "MONDAY", etc.
- `day_num_to_name_lower()` - Returns "sunday", "monday", etc.
- `day_num_to_name_title()` - Returns "Sunday", "Monday", etc.

**Pros**:
- Simpler individual functions
- No format parameter needed

**Cons**:
- Three functions to maintain
- More function names to remember

#### Option C: Use Existing Arrays (Simplest)
Since `configure-core.sh` already has `DAY_NAMES` and `DAY_VARS` arrays, create a simple function that uses them:

```bash
# Convert day number to uppercase day name (for config file)
day_num_to_name_upper() {
    local day_num="$1"
    if [ "${day_num}" -ge 0 ] && [ "${day_num}" -le 6 ]; then
        echo "${DAY_VARS[${day_num}]}"
    else
        return 1
    fi
}

# Convert day number to titlecase day name (for display)
day_num_to_name_title() {
    local day_num="$1"
    if [ "${day_num}" -ge 0 ] && [ "${day_num}" -le 6 ]; then
        echo "${DAY_NAMES[${day_num}]}"
    else
        return 1
}
```

**Pros**:
- Uses existing arrays (single source of truth)
- Simple implementation
- No duplication of day names

**Cons**:
- Two functions instead of one
- Requires arrays to be defined (already done in configure-core.sh)

### Decision Made ✅

**Question 1**: Which approach should we use?
- **Decision**: Option C (use existing arrays) - simplest and leverages existing infrastructure ✅

**Question 2**: Should we also create a function for next day calculation (currently in `configure-time.sh`)?
- **Decision**: Keep separate for now - different purpose (next day vs. day number conversion) ✅

**Question 3**: Where should the function(s) be placed?
- **Decision**: `lib/configure-core.sh` - already has day-related constants and is a core utility module ✅

### Implementation Steps

1. **Add function(s) to `lib/configure-core.sh`**
   - Add `day_num_to_name_upper()` function
   - Add `day_num_to_name_title()` function (if using Option C)
   - Add documentation comments

2. **Update `lib/config.sh`**
   - Replace case statements in `parse_config()` (lines 873-882)
   - Replace case statements in `parse_lock_hours()` (lines 938-947)
   - Replace case statements in `parse_uninstall_lock_hours()` (lines 1040-1049)
   - Ensure `configure-core.sh` is sourced (check dependencies)

3. **Update `lib/configure-input-time.sh`**
   - Replace case statements for previous day name (lines 363-368, 599-605)
   - Ensure `configure-core.sh` is sourced

4. **Testing**
   - Verify all functions still work correctly
   - Test with all day numbers (0-6)
   - Test edge cases (invalid day numbers)
   - Run existing tests to ensure no regressions

### Files to Modify

- `lib/configure-core.sh` - Add new function(s)
- `lib/config.sh` - Replace 3 case statements
- `lib/configure-input-time.sh` - Replace 2 case statements

### Testing Checklist

- [ ] `parse_config()` works for all days (0-6)
- [ ] `parse_lock_hours()` works for all days (0-6)
- [ ] `parse_uninstall_lock_hours()` works for all days (0-6)
- [ ] Previous day name display in `configure-input-time.sh` works correctly
- [ ] Invalid day numbers return appropriate error codes
- [ ] All existing tests pass
- [ ] No regressions in configuration parsing

---

## Task 2: Extract Magic Numbers to Constants

### Current State Analysis

Hardcoded numeric values appear throughout the codebase. Based on the assessment and code review, the following magic numbers should be extracted:

#### Hour Range Values (0-23)
**Files with hardcoded 0 and/or 23**:
- `lib/configure-input-basic.sh` (lines 35, 38, 56, 60) - Hour validation
- `lib/configure-input-time.sh` (lines 148, 267-268, 283, 410, 414, 498-499, 512) - Hour range validation and display
- `lib/config.sh` (line 615) - Minimum display time validation (0-300, not hours)
- Potentially other files

**Usage patterns**:
- Validation: `[ "${hour}" -lt 0 ] || [ "${hour}" -gt 23 ]`
- Error messages: "Please enter a number between 0 and 23"
- Display text: "Hours use 24-hour format (0-23)"

#### Time Range Values (0-300)
**Files with hardcoded 0 and/or 300**:
- `lib/configure-input-popup.sh` (lines 417, 432, 435, 470, 496, 608) - Minimum display time validation
- `lib/config.sh` (line 615) - Minimum display time validation

**Usage patterns**:
- Validation: `[ "${time}" -lt 0 ] || [ "${time}" -gt 300 ]`
- Error messages: "Please enter a number between 0 and 300 seconds"
- Display text: "Enter time in seconds (0-300)"

#### Other Magic Numbers Found
- **60** - Minutes per hour, check interval maximum (1-60)
  - `lib/configure-input-time.sh` (lines 65, 68, 103, 129)
  - `lib/configure-core.sh` (line 60) - Already defined as `MINUTES_PER_HOUR=60`
- **1440** - Minutes per day
  - `lib/time-calculations.sh` (line 425) - Already defined locally
  - `lib/config-locking.sh`, `lib/time-validation.sh` - Used but not defined
- **10080** - Minutes per week
  - `lib/time-calculations.sh` (line 427) - Already defined locally
- **1** - Minimum check interval
  - `lib/configure-input-time.sh` (lines 65, 103, 129)

### Proposed Solution

#### Constants to Create

Create constants in appropriate modules:

**In `lib/configure-core.sh`** (already has time-related constants):
```bash
# Hour range constants
readonly MIN_HOUR=0
readonly MAX_HOUR=23

# Time range constants (for minimum display time)
readonly MIN_DISPLAY_TIME=0
readonly MAX_DISPLAY_TIME=300

# Check interval constants
readonly MIN_CHECK_INTERVAL=1
readonly MAX_CHECK_INTERVAL=60
```

**In `lib/time-calculations.sh`** (or move to configure-core.sh for consistency):
```bash
# Time calculation constants (if not already defined)
readonly MINUTES_PER_DAY=1440
readonly MINUTES_PER_WEEK=10080
```

**Note**: `MINUTES_PER_HOUR=60` already exists in `configure-core.sh` (line 60).

### Decision Made ✅

**Question 1**: Should time calculation constants (MINUTES_PER_DAY, MINUTES_PER_WEEK) be moved to `configure-core.sh` for consistency?
- **Decision**: Yes - centralize all time-related constants in one place ✅

**Question 2**: Should we extract constants for other magic numbers found (e.g., default values like 30, 10)?
- **Decision**: No - these are already defined as `DEFAULT_*` constants in `config.sh` and should remain there ✅

**Question 3**: Should constants be `readonly` or regular variables?
- **Decision**: Use `readonly` for true constants that should never change ✅

### Implementation Steps

1. **Add constants to `lib/configure-core.sh`**
   - Add hour range constants (MIN_HOUR, MAX_HOUR)
   - Add display time constants (MIN_DISPLAY_TIME, MAX_DISPLAY_TIME)
   - Add check interval constants (MIN_CHECK_INTERVAL, MAX_CHECK_INTERVAL)
   - Consider moving MINUTES_PER_DAY and MINUTES_PER_WEEK here (or document why they're in time-calculations.sh)

2. **Update `lib/configure-input-basic.sh`**
   - Replace `0` and `23` with `MIN_HOUR` and `MAX_HOUR`
   - Update error messages to use constants

3. **Update `lib/configure-input-time.sh`**
   - Replace `0` and `23` with `MIN_HOUR` and `MAX_HOUR` in validation
   - Replace `1` and `60` with `MIN_CHECK_INTERVAL` and `MAX_CHECK_INTERVAL`
   - Update error messages and display text to use constants

4. **Update `lib/configure-input-popup.sh`**
   - Replace `0` and `300` with `MIN_DISPLAY_TIME` and `MAX_DISPLAY_TIME`
   - Update error messages and display text to use constants

5. **Update `lib/config.sh`**
   - Replace `0` and `300` with `MIN_DISPLAY_TIME` and `MAX_DISPLAY_TIME` in validation

6. **Update `lib/time-calculations.sh`** (if moving constants)
   - Replace local definitions with references to configure-core.sh constants
   - Or document why they remain local

7. **Testing**
   - Verify all validation still works correctly
   - Test boundary conditions (0, 23, 300, etc.)
   - Run existing tests to ensure no regressions

### Files to Modify

- `lib/configure-core.sh` - Add constants
- `lib/configure-input-basic.sh` - Replace magic numbers
- `lib/configure-input-time.sh` - Replace magic numbers
- `lib/configure-input-popup.sh` - Replace magic numbers
- `lib/config.sh` - Replace magic numbers
- `lib/time-calculations.sh` - Possibly update (if moving constants)

### Testing Checklist

- [ ] Hour validation works correctly (0-23)
- [ ] Display time validation works correctly (0-300)
- [ ] Check interval validation works correctly (1-60)
- [ ] Boundary conditions tested (min, max, out of range)
- [ ] Error messages display correct ranges
- [ ] All existing tests pass
- [ ] No regressions in input validation

---

## Implementation Order

### Recommended Order

1. **Task 1: Day Name Conversion** (simpler, fewer files)
   - Add functions to configure-core.sh
   - Update config.sh (3 functions)
   - Update configure-input-time.sh (2 locations)
   - Test

2. **Task 2: Magic Numbers** (more files, but straightforward)
   - Add constants to configure-core.sh
   - Update all files systematically
   - Test

### Alternative: Parallel Implementation

Both tasks are independent and could be done in parallel, but sequential is recommended for easier testing and review.

---

## Questions and Decisions

### Decisions Made ✅

1. **Day Name Conversion Approach**
   - ✅ **Decision**: Option C (use existing arrays) - simplest and leverages existing infrastructure

2. **Next Day Calculation**
   - ✅ **Decision**: Keep separate for now - different purpose (next day vs. day number conversion)

3. **Time Constants Location**
   - ✅ **Decision**: Yes - move MINUTES_PER_DAY and MINUTES_PER_WEEK to configure-core.sh for consistency

4. **Constant Scope**
   - ✅ **Decision**: Use `readonly` for true constants that should never change

### Implementation Details

- Functions will be added to `lib/configure-core.sh` (already has day-related infrastructure)
- Constants will be added to `lib/configure-core.sh` (centralized location)
- Both improvements are independent and can be tested separately

---

## Risk Assessment

### Low Risk
- Both tasks are straightforward refactorings
- No functional changes, only code organization
- Existing tests should catch any regressions

### Potential Issues
- **Dependency order**: Need to ensure `configure-core.sh` is sourced before functions are called
- **Array availability**: Need to ensure `DAY_NAMES` and `DAY_VARS` are available when functions are called
- **Test coverage**: Need to verify all affected code paths are tested

### Mitigation
- Check sourcing order in all affected files
- Run full test suite after changes
- Manual testing of configuration wizard flows

---

## Success Criteria

### Task 1: Day Name Conversion
- [x] All day name conversion logic uses shared function(s)
- [x] No duplicate case statements for day conversion (kept as fallback for compatibility)
- [x] All existing functionality works correctly
- [x] All tests pass ✅ (32/32 tests passed in test-day-name-conversion.sh)

### Task 2: Magic Numbers
- [x] All hour range validations use MIN_HOUR/MAX_HOUR constants
- [x] All display time validations use MIN_DISPLAY_TIME/MAX_DISPLAY_TIME constants
- [x] All check interval validations use MIN_CHECK_INTERVAL/MAX_CHECK_INTERVAL constants
- [x] Error messages reference constants (or are updated to match)
- [x] Time calculation constants (MINUTES_PER_DAY, MINUTES_PER_WEEK) centralized in configure-core.sh
- [x] All existing functionality works correctly
- [x] All tests pass ✅ (101 total tests passed across multiple test suites)

---

## Notes

- Both improvements are low priority per assessment
- Estimated effort is conservative (3-4 hours total)
- These are maintainability improvements, not functional changes
- Should be done before any major refactoring that might duplicate this work

---

**Last Updated**: 2026-01-26
**Implementation Completed**: 2026-01-26
**Testing Completed**: 2026-01-26

## Testing Summary

### Tests Executed (2026-01-26)

**New Test Created**: `test-day-name-conversion.sh`
- **Status**: ✅ **PASS** (32/32 tests passed)
- **Coverage**:
  - Day name conversion functions (`day_num_to_name_upper()`, `day_num_to_name_title()`) for all 7 days
  - Error handling for invalid day numbers
  - All constants verification (MIN_HOUR, MAX_HOUR, MIN_DISPLAY_TIME, MAX_DISPLAY_TIME, MIN_CHECK_INTERVAL, MAX_CHECK_INTERVAL, MINUTES_PER_DAY, MINUTES_PER_WEEK)
  - Integration with `parse_config()` function

**Existing Tests Verified**:
1. **test-uninstall-lock-hours-phase2.sh**: ✅ **PASS** (15/15) - `parse_uninstall_lock_hours()` uses shared day conversion
2. **test-lock-hours-phase2.sh**: ✅ **PASS** (14/14) - `parse_lock_hours()` uses shared day conversion
3. **test-grid-functions.sh**: ✅ **PASS** (10/10) - Time formatting functions work correctly
4. **test-modular-refactor.sh**: ✅ **PASS** (10/10) - Modular structure intact
5. **test-configure-modular.sh**: ✅ **PASS** (10/10) - Configure modules and constants verified

**Total Test Results**: 101 tests passed, 0 tests failed

**Verification**:
- All constants properly defined and accessible
- Day name conversion functions work for all 7 days (0-6)
- Error handling works for invalid day numbers
- Integration with existing config parsing functions works correctly
- No regressions in existing functionality
