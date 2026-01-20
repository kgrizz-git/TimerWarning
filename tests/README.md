# Test Suite for Sleep Warning Configuration

## Overview

Comprehensive automated test suite for `configure.sh --text` mode using `expect` for interactive testing.

## Test Files

- **test-configure-comprehensive.sh** - Main test runner (bash)
- **test-configure-comprehensive.exp** - Expect automation script
- **test-with-expect.sh** - Original prototype (kept for reference)
- **test-write-config-override-flags.sh** - Unit tests for write_config() override flag detection edge cases

## Running Tests

### Run All Tests
```bash
./tests/test-configure-comprehensive.sh 1 2 3 4 5 6 7 8 9 10
```

### Run Specific Tests
```bash
./tests/test-configure-comprehensive.sh 1 2 3    # Run tests 1, 2, and 3
./tests/test-configure-comprehensive.sh 5        # Run only test 5
./tests/test-configure-comprehensive.sh 9 10     # Run tests 9 and 10
```

## Test Coverage

### Test 1: Timer Settings
- **Purpose**: Verify CHECK_INTERVAL configuration changes persist
- **Actions**: Sets check interval to 15 minutes
- **Verification**: 
  - Config file contains `CHECK_INTERVAL=15`
  - No status.sh verification (interval not shown in status)

### Test 2: Window Behavior
- **Purpose**: Verify all popup window settings persist
- **Actions**: Configures size=large, position=top-left, min_display=60s, immovable=false
- **Verification**:
  - Config file contains all four settings
  - No status.sh verification (window settings not shown in status)

### Test 3: Weekday Bulk Apply
- **Purpose**: Verify bulk configuration of all weekdays
- **Actions**: Applies 0-5 hours to Monday-Friday together
- **Verification**:
  - Config file contains MONDAY through FRIDAY all set to `0-5`
  - No status.sh verification (weekday-specific times not shown)

### Test 4: Weekend Bulk Apply
- **Purpose**: Verify bulk configuration of weekend days
- **Actions**: Applies 1-6 hours to Saturday and Sunday together
- **Verification**:
  - Config file contains SATURDAY and SUNDAY both set to `1-6`
  - No status.sh verification

### Test 5: Multiple Time Ranges
- **Purpose**: Verify comma-separated time ranges work correctly
- **Actions**: Sets weekdays to `0-5,22-23` (midnight-5am AND 10pm-midnight)
- **Verification**:
  - Config file contains all weekdays set to `0-5,22-23`
  - status.sh displays time markers (midnight, 12:00 AM, 10:00 PM, or 22:00)

### Test 6: Overnight Ranges
- **Purpose**: Verify overnight ranges spanning midnight display correctly
- **Actions**: Sets weekdays to `23-6` (11pm to 6am next day)
- **Verification**:
  - Config file contains all weekdays set to `23-6`
  - status.sh displays `11:00 PM` (verifies overnight formatting)

### Test 7: Empty/Unconfigured Days Grid Display
- **Purpose**: Verify grid view shows unconfigured days correctly
- **Actions**: Opens grid view with empty config, navigates menu
- **Verification**:
  - Grid displays "no restrictions" for unconfigured days
  - Navigation works (option 0 and 6)

### Test 8: Config Persistence and Reload
- **Purpose**: Full integration test of all settings
- **Actions**: Configures:
  - Check interval: 20 minutes
  - Window: small, bottom-right, 45s, not immovable
  - Weekdays: 0-8 hours
- **Verification**:
  - All settings persist in config file
  - status.sh shows check interval correctly (20 minutes)

### Test 9: Skip Feature UX Improvement  
- **Purpose**: Verify easier skip functionality is implemented
- **Actions**: 
  - Automated test uses bulk apply (simpler than individual skip automation)
  - Code inspection of configure.sh line 1247 verifies implementation
- **Verification**:
  - Config file verified via bulk apply test
  - Code inspection confirms: `case "${range_input}" in skip|s|S|"")`
  - Empty string (`""`) means pressing Enter works as skip
  - Prompt updated to show: `Time range(s) for Monday (or 's' to skip):`
- **Note**: Full individual day skip flow not automated due to expect/stdin complexity

### Test 10: Backward Compatibility
- **Purpose**: Verify all menu options (1-6) still work correctly
- **Actions**: Tests all main menu options in sequence:
  - Option 1: Timer Settings (25 min)
  - Option 2: Window Behavior (medium, top-center, 90s, immovable)
  - Option 3: Weekdays (1-4)
  - Option 4: Weekends (2-7)
  - Option 6: Review and Save
- **Verification**:
  - All settings persist correctly
  - Menu structure unchanged

## Test Results

**Status**: ✅ All 10 tests passing (13 total assertions)

```
==========================================
Test Results:
  Passed: 13
  Failed: 0
  Total Tests: 10
==========================================
```

## Bugs Fixed During Testing

### 1. Prompt Text Captured in Config Values
**Issue**: Menu prompts were echoed to stdout instead of stderr, getting captured by command substitution and corrupting config values.

**Affected Functions**:
- `get_popup_size_config()` - Menu options were in POPUP_SIZE value
- `get_popup_position_config()` - Menu options were in POPUP_POSITION value
- `get_popup_immovable_config()` - Description text was in POPUP_IMMOVABLE value
- `get_day_hours()` - Empty echo at start was captured
- `confirm_skip_day()` - Empty echo was captured

**Fix**: Changed all prompt `echo` statements to `echo >&2` so they go to stderr

### 2. Newlines in Config Values
**Issue**: Related to bug #1, caused config lines like:
```
MONDAY=
0-5
```
instead of:
```
MONDAY=0-5
```

**Fix**: Same as bug #1 - redirect prompts to stderr

### 3. Sparse Array Re-indexing Bug (CRITICAL)
**Issue**: When configuring only weekdays (Mon-Fri, indices 1-5), the summary would show:
- Sunday with weekday hours (should show "No restrictions")
- Monday-Thursday correct
- Friday as "No restrictions" (should show configured hours)

**Root Cause**: Passing sparse arrays with `"${array[@]}"` causes bash to re-index from 0:
```bash
# Original array:
summary_lines[1]="Monday: 0-5"
summary_lines[5]="Friday: 0-5"

# After passing to function:
local arr=("$@")
arr[0]="Monday: 0-5"  # Was index 1
arr[4]="Friday: 0-5"   # Was index 5
```

**Fix**: Changed `show_summary()` to access `summary_lines` as a global array instead of passing it as parameters, preserving the sparse array indices.

## UX Improvements Made

### Easier Skip Command
**Before**: Users had to type `skip` to skip a day
**After**: Users can:
- Press Enter (empty input)
- Type `s` or `S`
- Type `skip` (still works)

**Changed Prompt**: 
```
Time range(s) for Monday (or 's' to skip):
```

## Test Framework Details

### Technology Stack
- **Bash**: Test orchestration and verification
- **Expect**: Interactive automation with configure.sh
- **grep/sed**: Config file verification

### Test Workflow
1. Backup existing config
2. Create clean test config
3. Run expect script with test name
4. Verify config file contents
5. Verify status.sh output (where applicable)
6. Restore original config

### Adding New Tests

1. Add test function to `test-configure-comprehensive.sh`:
```bash
run_test_N() {
    echo "Test Suite N: Description"
    create_test_config ""
    run_test "test_name" "Description" "${TEST_DIR}/test-comprehensive.exp"
    # Add verification
    if verify_config_value "KEY" "value"; then
        echo "  [OK] Verification passed"
    else
        echo "  [FAIL] Verification failed"
        ((FAILED++))
    fi
    echo ""
}
```

2. Add test case to `test-configure-comprehensive.exp`:
```tcl
} elseif {$test_name == "test_name"} {
    # Your expect automation
    send "option\r"
    expect "prompt"
    # ... more interactions
    expect {
        "success message" {
            sleep 2
            puts "PASS: Test description"
            exit 0
        }
        timeout {
            puts "ERROR: Timeout"
            exit 1
        }
    }
}
```

3. Update test runner to include new test number

## Unit Tests

### test-write-config-override-flags.sh

**Purpose**: Tests the `write_config()` function's handling of safety override flags to ensure correct detection and processing in various edge cases.

**Coverage**:
- Normal cases with override flags
- Backward compatibility (without override flags)
- Sparse config_lines arrays
- Empty config_lines with override flags
- Edge cases that could cause false positives (empty restrictions, exactly 2 config_lines, etc.)

**Run**:
```bash
./tests/test-write-config-override-flags.sh
```

**Status**: ✅ All 17 test assertions passing

**Test Cases**:
1. Normal case with both override flags set
2. Normal case without override flags (backward compatibility)
3. Sparse config_lines array (only some days configured)
4. Empty config_lines with override flags
5. Empty restrictions not mistaken for override flags
6. Two config_lines not mistaken for override flags
7. Mixed override flags (one empty, one set)
8. Single config_line with override flags
9. All 7 days configured with override flags
10. Override flags as empty strings

## Known Limitations

- **No GUI testing**: Tests only cover `--text` mode
- **No cancellation testing**: Cancellation flows not tested (complex, low priority)
- **No 'back' navigation testing**: Complex individual day editing with 'back' not tested
- **Limited error testing**: Tests focus on happy path
- **Skip testing indirect**: Test 9 verifies code but doesn't fully automate skip flow (expect/stdin issues)

## Future Enhancements

- Add cancellation flow tests
- Add individual day navigation tests (with 'back' command)
- Add error handling tests (invalid input)
- Add backward compatibility tests (old menu options)
- Consider adding GUI mode tests (if possible with xvfb)
