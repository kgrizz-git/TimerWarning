# Test Suite for Sleep Warning Configuration

## Overview

Comprehensive automated test suite for `configure.sh --text` mode using `expect` for interactive testing.

## macOS tests

These run on macOS (and Linux for platform detection branches) without GUI or modifying your installed config:

| Script | Purpose |
|--------|---------|
| `tests/test-platform-darwin.sh` | Platform detection, plist `StartInterval`, watchdog math |
| `tests/test-popup-safety-darwin.sh` | Popup watchdog kills hung child processes |
| `tests/test-darwin-configure-gui.sh` | macOS configure GUI regressions (grid cache, table JSON, daemon protocol, modal dialog wiring) — headless |

```bash
bash tests/test-platform-darwin.sh
bash tests/test-popup-safety-darwin.sh
bash tests/test-darwin-configure-gui.sh
```

Linux-only tests (systemd, xrandr, zenity, `expect` GUI suites) should be run on a Linux host. See [user-docs/MACOS.md](../user-docs/MACOS.md) for manual GUI verification on Mac.

## ⚠️  IMPORTANT: Tests That Modify Your Configuration File

**Several tests run `configure.sh` (or related scripts) in a way that writes a config file under `${HOME}`.**
These tests are configured to run under an **isolated temporary `HOME`**, so they **do not touch your real installed config**.

- **test-configure-comprehensive.sh** - Runs under temp `HOME` (safe)
- **test-configure-interactive.sh** - Runs under temp `HOME` (safe)
- **test-with-expect.sh** - Runs under temp `HOME` (safe)
- **test-grid-display.sh** - Runs under temp `HOME` (safe)

**These tests:**
- Create a temporary `HOME`
- Write config to `${HOME}/.config/sleep-warning/config/sleep-warning.conf` within that temp `HOME`
- Clean up the temp directory on exit (best-effort)

**However:** If a test is forcefully killed, the temp directory may remain on disk. It won’t affect your real config.

**Safe tests (use test configs, don't modify actual config):**
- **test-pause-feature.sh** - Uses test config directory
- **test-dialog-tool-selection.sh** - Uses test config directory
- **test-lock-hours-phase2.sh** - Uses test config files
- **test-uninstall-lock-hours-phase2.sh** - Uses test config files
- **test-write-config-override-flags.sh** - Uses test config files

## Test Files

- **test-configure-comprehensive.sh** - Main test runner (bash)
- **test-configure-comprehensive.exp** - Expect automation script
- **test-with-expect.sh** - Original prototype (kept for reference)
- **test-write-config-override-flags.sh** - Unit tests for write_config() override flag detection edge cases

## Running Tests

### Execution guidelines (important)

- **Run no more than 3 tests at a time** (especially for `expect`-driven suites).
- **Always use a timeout**, even if generous (e.g. 60s–300s), so a hung `expect` run can’t block your session indefinitely.

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

### Recommended (with timeout + batching)

```bash
timeout 300s ./tests/test-configure-comprehensive.sh 1 2 3
timeout 300s ./tests/test-configure-comprehensive.sh 4 5 6
timeout 300s ./tests/test-configure-comprehensive.sh 7 8 9
timeout 300s ./tests/test-configure-comprehensive.sh 10
```

## Test Coverage

### Test 1: Popup display frequency (Enhancement #30)
- **Purpose**: Verify POPUP_DISPLAY_FREQUENCY configuration changes persist
- **Actions**: Sets popup display frequency to 15 minutes
- **Verification**: 
  - Config file contains `POPUP_DISPLAY_FREQUENCY=15`
  - No status.sh verification (run interval not shown; status shows popup frequency)

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
  - Navigation works (Back and option 13 for Review and Save)

### Test 8: Config Persistence and Reload
- **Purpose**: Full integration test of all settings
- **Actions**: Configures:
  - Popup display frequency: 20 minutes
  - Window: small, bottom-right, 45s, not immovable
  - Weekdays: 0-8 hours
- **Verification**:
  - All settings persist in config file (POPUP_DISPLAY_FREQUENCY=20, etc.)
  - status.sh shows popup display frequency correctly (20 minutes)

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
- **Purpose**: Verify main menu options (1-13) still work correctly
- **Actions**: Tests menu options in sequence (e.g. option 1 Timer, 2 Window Behavior submenu, 3–4 Weekdays/Weekends, 9 View Weekly Hours, 13 Review and Save)
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
1. Create temporary `HOME`
2. Create clean test config under that temp `HOME`
3. Run expect script with test name
4. Verify config file contents
5. Verify status.sh output (where applicable)
6. Clean up the temp `HOME`

### Adding New Tests

**⚠️ CRITICAL:** If your test runs `configure.sh` or otherwise writes to `${HOME}/.config/sleep-warning/`, you should use a **temporary `HOME`** unless the test is explicitly meant to exercise “real install” behavior.

1. **Create a temp HOME**
2. **Export `HOME` so scripts write into the temp**
3. **Use a trap to ensure cleanup even if the test is interrupted**

**Example pattern for tests that write config (safe temp HOME):**
```bash
#!/bin/bash

###############################################################################
# Test description
#
# Safety:
#   This test runs under a temporary HOME directory.
###############################################################################

# Note: Create temp dirs under the repo so sandboxed runs can write to them.
TMP_BASE="$(pwd)/tests/.tmp"
mkdir -p "${TMP_BASE}"
tmp_home="$(mktemp -d -p "${TMP_BASE}" home.XXXXXX)"
export HOME="${tmp_home}"
CONFIG_FILE="${HOME}/.config/sleep-warning/config/sleep-warning.conf"

# Cleanup function to ensure temp HOME can always be removed
cleanup() {
    chmod -R u+rwX "${tmp_home}" 2>/dev/null || true
    rm -rf "${tmp_home}" 2>/dev/null || true
}

# Set up trap to ensure cleanup on exit or interrupt
trap cleanup EXIT INT TERM

# ... your test code here ...
```

**For tests that use test configs (recommended):**
- Use a separate test config directory or file
- Don't modify the actual config file
- No backup/restore needed

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
