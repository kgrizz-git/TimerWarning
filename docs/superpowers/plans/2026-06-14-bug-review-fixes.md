# Bug Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the bug-review findings around overnight safety enforcement, macOS scheduler disable status, popup size validation, duplicate config parsing, and the stale config-locking test expectation.

**Architecture:** Keep changes small and aligned with the existing shell modules. Add reusable helpers only where they remove duplicated overnight-range parsing; otherwise preserve current public function names and return contracts. Safety-critical checks must be covered with deterministic tests that stub date/time instead of depending on wall-clock time.

**Tech Stack:** Bash, shell unit/integration tests under `tests/`, existing config modules in `lib/`.

---

## File Structure

- Modify `lib/time-validation.sh`: add one reusable previous-day overnight helper and use it in configure-block and uninstall-protection checks.
- Modify `lib/config-locking.sh`: use the same previous-day overnight helper for config file locking.
- Modify `lib/scheduler-platform.sh`: return real Darwin scheduler disable/remove status instead of unconditional success.
- Modify `lib/service-config-darwin.sh`: add a strict bootout helper for explicit disable paths while preserving permissive bootout for bootstrap/reload "not loaded" cases.
- Modify `lib/configure-input-popup-size.sh`: enforce the documented 15-95 percent range in text-mode custom popup size input.
- Modify `lib/config-popup-size.sh`: clamp custom and raw pixel popup dimensions to the same 95 percent display cap.
- Modify `lib/configure-config-load.sh`: use last matching duplicate config entries to match runtime parsers.
- Modify `tests/test-config-locking.sh`: source `time-parsing.sh` and fix the end-exclusive `22-23` expectation.
- Create `tests/test-overnight-carry-safety.sh`: deterministic coverage for configure-block, uninstall protection, and config locking when previous-day overnight ranges carry into a current day that also has non-active ranges.
- Create `tests/test-popup-size-custom-validation.sh`: deterministic coverage for text-mode and runtime custom popup size caps.
- Create `tests/test-scheduler-platform-darwin-status.sh`: deterministic coverage for Darwin wrapper return status.
- Create `tests/test-config-duplicate-last-wins.sh`: deterministic coverage for configure-loader duplicate key behavior.

---

### Task 1: Previous-Day Overnight Safety Carry

**Files:**
- Modify: `lib/time-validation.sh`
- Modify: `lib/config-locking.sh`
- Create: `tests/test-overnight-carry-safety.sh`
- Test: `tests/test-overnight-carry-safety.sh`

- [ ] **Step 1: Write the failing overnight carry test**

Create `tests/test-overnight-carry-safety.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_configure_block_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"

    get_configure_block_enabled() { echo true; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }
    parse_lock_hours() { echo ""; }

    if check_config_lock_time; then
        fail "configure block allowed previous-day overnight carry"
    fi
)

run_uninstall_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"

    get_uninstall_protection_mode() { echo difficult; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }
    parse_uninstall_lock_hours() { echo ""; }

    result="$(check_uninstall_protection_time)"
    [ "${result}" = "difficult" ] || fail "expected uninstall protection difficult, got '${result}'"
)

run_config_lock_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"
    source "${ROOT_DIR}/lib/config-locking.sh"

    get_config_lock_enabled() { echo true; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }
    parse_lock_hours() { echo ""; }

    is_config_lock_active || fail "config lock inactive during previous-day overnight carry"
)

run_lock_hours_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"
    source "${ROOT_DIR}/lib/config-locking.sh"

    get_config_lock_enabled() { echo true; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() { echo ""; }
    parse_lock_hours() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }

    is_config_lock_active || fail "config lock inactive during previous-day overnight lock-hours carry"
    if check_config_lock_time; then
        fail "configure block allowed previous-day overnight lock-hours carry"
    fi
)

run_uninstall_lock_hours_case() (
    source "${ROOT_DIR}/lib/time-validation.sh"

    get_uninstall_protection_mode() { echo difficult; }
    get_current_time() { echo 0300; }
    date() {
        if [ "${1:-}" = "+%w" ]; then
            echo 2
        else
            command date "$@"
        fi
    }
    parse_config() { echo ""; }
    parse_uninstall_lock_hours() {
        case "$1" in
            1) echo "23:00-06:00" ;;
            2) echo "20:00-22:00" ;;
            *) echo "" ;;
        esac
    }

    result="$(check_uninstall_protection_time)"
    [ "${result}" = "difficult" ] || fail "expected uninstall lock-hours protection difficult, got '${result}'"
)

run_configure_block_case
run_uninstall_case
run_config_lock_case
run_lock_hours_case
run_uninstall_lock_hours_case

echo "OK: previous-day overnight carry safety checks passed"
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```bash
bash tests/test-overnight-carry-safety.sh
```

Expected: failure before implementation, starting with one of:

```text
FAIL: configure block allowed previous-day overnight carry
FAIL: config lock inactive during previous-day overnight carry
```

- [ ] **Step 3: Add a reusable previous-day overnight helper**

In `lib/time-validation.sh`, insert this helper after `get_current_hour()`:

```bash
# Check whether current HHMM falls in the post-midnight tail of any overnight
# range from the previous day. This intentionally ignores whether the current
# day has its own non-active range; previous-day overnight carry still applies.
is_time_in_previous_day_overnight_tail() {
    local current_time_hhmm="$1"
    local prev_day_ranges="$2"

    if [ -z "${prev_day_ranges}" ]; then
        return 1
    fi

    local IFS=','
    local range
    for range in ${prev_day_ranges}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -n "${range}" ] || continue

        local start_part="${range%%-*}"
        local end_part="${range##*-}"
        local start_time end_time

        if [[ "${start_part}" =~ : ]]; then
            start_time=$(echo "${start_part}" | tr -d ':')
        else
            start_time=$(printf "%02d00" "${start_part}")
        fi

        if [[ "${end_part}" =~ : ]]; then
            end_time=$(echo "${end_part}" | tr -d ':')
        else
            end_time=$(printf "%02d00" "${end_part}")
        fi

        if [ "${start_time}" -gt "${end_time}" ] && [ "${current_time_hhmm}" -lt "${end_time}" ]; then
            return 0
        fi
    done

    return 1
}
```

- [ ] **Step 4: Use the helper in configure-block checks**

In `check_config_lock_time()` in `lib/time-validation.sh`, replace the gated previous-day restriction block with:

```bash
    # Check previous day's restriction hours for overnight ranges that carry into today.
    if type parse_config >/dev/null 2>&1; then
        local prev_day_range
        prev_day_range=$(parse_config "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_range}"; then
            return 1
        fi
    fi

    # Check previous day's lock hours for overnight ranges that carry into today.
    if type parse_lock_hours >/dev/null 2>&1; then
        local prev_day_lock_hours
        prev_day_lock_hours=$(parse_lock_hours "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_lock_hours}"; then
            return 1
        fi
    fi
```

- [ ] **Step 5: Use the helper in uninstall-protection checks**

In `check_uninstall_protection_time()` in `lib/time-validation.sh`, replace the gated previous-day restriction and uninstall-lock blocks with:

```bash
    # Check previous day's restriction hours for overnight ranges that carry into today.
    if type parse_config >/dev/null 2>&1; then
        local prev_day_range
        prev_day_range=$(parse_config "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_range}"; then
            echo "${protection_mode}"
            return 0
        fi
    fi
```

and:

```bash
    # Check previous day's uninstall lock hours for overnight ranges that carry into today.
    if type parse_uninstall_lock_hours >/dev/null 2>&1; then
        local prev_day_uninstall_lock_range
        prev_day_uninstall_lock_range=$(parse_uninstall_lock_hours "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_uninstall_lock_range}"; then
            echo "${protection_mode}"
            return 0
        fi
    fi
```

- [ ] **Step 6: Use the helper in config locking**

In `lib/config-locking.sh`, replace the two gated previous-day loops with:

```bash
    # Check previous day's restriction hours for overnight ranges that carry into today.
    local prev_day_range
    prev_day_range=$(parse_config "${prev_day}")
    if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_range}"; then
        return 0
    fi

    # Check previous day's lock hours for overnight ranges that carry into today.
    if type parse_lock_hours >/dev/null 2>&1; then
        local prev_day_lock_hours
        prev_day_lock_hours=$(parse_lock_hours "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_lock_hours}"; then
            return 0
        fi
    fi
```

- [ ] **Step 7: Run targeted safety tests**

Run:

```bash
bash tests/test-overnight-carry-safety.sh
bash tests/test-configure-partial-lock.sh
bash tests/test-lock-hours-phase2.sh
bash tests/test-uninstall-lock-hours-phase2.sh
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add lib/time-validation.sh lib/config-locking.sh tests/test-overnight-carry-safety.sh
git commit -m "fix: enforce previous-day overnight safety carry"
```

---

### Task 2: macOS Scheduler Disable Status

**Files:**
- Modify: `lib/service-config-darwin.sh`
- Modify: `lib/scheduler-platform.sh`
- Create: `tests/test-scheduler-platform-darwin-status.sh`
- Test: `tests/test-scheduler-platform-darwin-status.sh`

- [ ] **Step 1: Write the failing scheduler status test**

Create `tests/test-scheduler-platform-darwin-status.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "${TMP_DIR}/lib"
cp "${ROOT_DIR}/lib/scheduler-platform.sh" "${TMP_DIR}/lib/scheduler-platform.sh"
cat > "${TMP_DIR}/lib/service-config-darwin.sh" <<'STUB'
disable_scheduled_service() {
    return 42
}
remove_launch_agent() {
    return 43
}
STUB

source "${TMP_DIR}/lib/scheduler-platform.sh"

uname() {
    if [ "${1:-}" = "-s" ]; then
        echo Darwin
    else
        command uname "$@"
    fi
}

if scheduler_stop_and_disable; then
    fail "scheduler_stop_and_disable returned success after disable_scheduled_service failed"
fi

if scheduler_remove_files; then
    fail "scheduler_remove_files returned success after remove_launch_agent failed"
fi

echo "OK: Darwin scheduler wrapper propagates failure status"
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```bash
bash tests/test-scheduler-platform-darwin-status.sh
```

Expected:

```text
FAIL: scheduler_stop_and_disable returned success after disable_scheduled_service failed
```

- [ ] **Step 3: Add strict LaunchAgent bootout**

In `lib/service-config-darwin.sh`, add this function after `launch_agent_bootout()`:

```bash
    launch_agent_bootout_strict() {
        if ! command -v launchctl >/dev/null 2>&1; then
            return 0
        fi

        local _domain
        _domain="$(_launchd_domain)"

        if launchctl bootout "${_domain}/${LAUNCH_AGENT_LABEL}" 2>/dev/null; then
            return 0
        fi
        if launchctl bootout "${_domain}" "$(launch_agent_plist_path)" 2>/dev/null; then
            return 0
        fi

        if launchctl print "${_domain}/${LAUNCH_AGENT_LABEL}" >/dev/null 2>&1; then
            echo "ERROR: launchctl bootout failed for ${LAUNCH_AGENT_LABEL}" >&2
            return 1
        fi

        return 0
    }
```

- [ ] **Step 4: Use strict bootout for disable**

Change `disable_scheduled_service()` in `lib/service-config-darwin.sh` to:

```bash
    disable_scheduled_service() {
        launch_agent_bootout_strict
    }
```

Leave `launch_agent_bootout()` permissive for bootstrap/reload paths where "not loaded" is a normal state.

- [ ] **Step 5: Propagate Darwin wrapper status**

Change `scheduler_stop_and_disable()` and `scheduler_remove_files()` in `lib/scheduler-platform.sh`:

```bash
    scheduler_stop_and_disable() {
        if scheduler_is_darwin; then
            local lib_dir
            lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [ -f "${lib_dir}/service-config-darwin.sh" ]; then
                # shellcheck disable=SC1091
                source "${lib_dir}/service-config-darwin.sh"
                disable_scheduled_service
                return $?
            fi
            return 1
        fi
        systemctl --user stop sleep-warning.timer 2>/dev/null || true
        systemctl --user disable sleep-warning.timer 2>/dev/null
    }
```

```bash
    scheduler_remove_files() {
        if scheduler_is_darwin; then
            local lib_dir
            lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [ -f "${lib_dir}/service-config-darwin.sh" ]; then
                # shellcheck disable=SC1091
                source "${lib_dir}/service-config-darwin.sh"
                remove_launch_agent
                return $?
            fi
            return 1
        fi
        rm -f "${HOME}/.config/systemd/user/sleep-warning.service" 2>/dev/null
        rm -f "${HOME}/.config/systemd/user/sleep-warning.timer" 2>/dev/null
    }
```

- [ ] **Step 6: Run targeted scheduler tests**

Run:

```bash
bash tests/test-scheduler-platform-darwin-status.sh
bash tests/test-platform-darwin.sh
bash tests/test-uninstall-verification-eof.sh
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/service-config-darwin.sh lib/scheduler-platform.sh tests/test-scheduler-platform-darwin-status.sh
git commit -m "fix: propagate macOS scheduler disable failures"
```

---

### Task 3: Popup Size Validation and Runtime Caps

**Files:**
- Modify: `lib/configure-input-popup-size.sh`
- Modify: `lib/config-popup-size.sh`
- Create: `tests/test-popup-size-custom-validation.sh`
- Test: `tests/test-popup-size-custom-validation.sh`

- [ ] **Step 1: Write the failing popup size test**

Create `tests/test-popup-size-custom-validation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_text_custom_percent_case() (
    source "${ROOT_DIR}/lib/configure-core.sh"
    source "${ROOT_DIR}/lib/configure-dialogs.sh"
    source "${ROOT_DIR}/lib/configure-input-popup-size.sh"

    get_display_resolution() { echo "1000 800"; }

    result="$(printf "%s\n%s\n%s\n" 1 "100%x100%" "95%x95%" | get_custom_popup_size_config false)"
    if printf '%s\n' "${result}" | grep -q '^100%x100%$'; then
        fail "text custom popup size accepted 100%x100%"
    fi
    printf '%s\n' "${result}" | grep -q '^95%x95%$' || fail "text custom popup size did not accept 95%x95%"
)

run_runtime_custom_pixel_case() (
    source "${ROOT_DIR}/lib/config.sh"

    get_display_resolution() { echo "1000 800"; }
    CONFIG_FILE="$(mktemp)"
    printf "%s\n" "POPUP_SIZE=custom" "POPUP_SIZE_CUSTOM=1000x800" "POPUP_SIZE_CUSTOM_ABSOLUTE=1000x800" > "${CONFIG_FILE}"

    result="$(get_popup_dimensions custom)"
    rm -f "${CONFIG_FILE}"
    [ "${result}" = "950 760" ] || fail "expected custom pixel size 950 760, got '${result}'"
)

run_runtime_raw_pixel_case() (
    source "${ROOT_DIR}/lib/config.sh"

    get_display_resolution() { echo "1000 800"; }
    CONFIG_FILE="$(mktemp)"
    printf "%s\n" "POPUP_SIZE=1000x800" > "${CONFIG_FILE}"

    result="$(get_popup_dimensions "$(get_popup_size)")"
    rm -f "${CONFIG_FILE}"
    [ "${result}" = "950 760" ] || fail "expected raw pixel size 950 760, got '${result}'"
)

run_text_custom_percent_case
run_runtime_custom_pixel_case
run_runtime_raw_pixel_case

echo "OK: popup size custom validation checks passed"
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```bash
bash tests/test-popup-size-custom-validation.sh
```

Expected: failure on accepted `100%x100%` or unclamped `1000 800`.

- [ ] **Step 3: Fix text-mode percentage validation**

In `lib/configure-input-popup-size.sh`, change the text-mode custom percentage validation from:

```bash
if [ "$width_pct" -lt 15 ] || [ "$width_pct" -gt 100 ] || [ "$height_pct" -lt 15 ] || [ "$height_pct" -gt 100 ]; then
```

to:

```bash
if [ "$width_pct" -lt 15 ] || [ "$width_pct" -gt 95 ] || [ "$height_pct" -lt 15 ] || [ "$height_pct" -gt 95 ]; then
```

- [ ] **Step 4: Add a runtime max-size helper**

In `lib/config-popup-size.sh`, add this helper near the display-size helper functions:

```bash
clamp_popup_dimensions_to_safe_display_max() {
    local width="$1"
    local height="$2"
    local screen_width="$3"
    local screen_height="$4"

    local max_width=$((screen_width * 95 / 100))
    local max_height=$((screen_height * 95 / 100))

    if [ "${width}" -gt "${max_width}" ]; then
        width="${max_width}"
    fi
    if [ "${height}" -gt "${max_height}" ]; then
        height="${max_height}"
    fi

    echo "${width} ${height}"
}
```

- [ ] **Step 5: Clamp custom and raw pixel dimensions**

In `get_popup_dimensions()` in `lib/config-popup-size.sh`, replace custom/raw pixel output paths that currently only cap to screen bounds with:

```bash
clamp_popup_dimensions_to_safe_display_max "${width}" "${height}" "${screen_width}" "${screen_height}"
```

Apply this to:

- `POPUP_SIZE=custom` with `POPUP_SIZE_CUSTOM_ABSOLUTE`
- raw pixel `POPUP_SIZE=WIDTHxHEIGHT`

- [ ] **Step 6: Run targeted popup tests**

Run:

```bash
bash tests/test-popup-size-custom-validation.sh
bash tests/test-enhancement-03-window-sizes.sh
bash tests/test-popup-button-visibility.sh
bash tests/test-dialog-size-behavior.sh
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/configure-input-popup-size.sh lib/config-popup-size.sh tests/test-popup-size-custom-validation.sh
git commit -m "fix: enforce popup custom size caps"
```

---

### Task 4: Duplicate Config Key Consistency

**Files:**
- Modify: `lib/configure-config-load.sh`
- Create: `tests/test-config-duplicate-last-wins.sh`
- Test: `tests/test-config-duplicate-last-wins.sh`

- [ ] **Step 1: Write the failing duplicate-key test**

Create `tests/test-config-duplicate-last-wins.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_HOME}"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

export HOME="${TMP_HOME}"
source "${ROOT_DIR}/lib/configure-core.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/configure-config-load.sh"

mkdir -p "$(dirname "${CONFIG_FILE}")"
cat > "${CONFIG_FILE}" <<'CONF'
MONDAY=20:00-21:00
MONDAY=22:00-23:00
CONFIG_LOCK_HOURS_MONDAY=08:00-09:00
CONFIG_LOCK_HOURS_MONDAY=10:00-11:00
UNINSTALL_LOCK_HOURS_MONDAY=12:00-13:00
UNINSTALL_LOCK_HOURS_MONDAY=14:00-15:00
CONF

load_existing_config

[ "${config_lines[1]:-}" = "MONDAY=22:00-23:00" ] || fail "configure loader did not use last MONDAY entry: '${config_lines[1]:-}'"
[ "${lock_hours_lines[1]:-}" = "CONFIG_LOCK_HOURS_MONDAY=10:00-11:00" ] || fail "configure loader did not use last lock-hours entry: '${lock_hours_lines[1]:-}'"
[ "${uninstall_lock_hours_lines[1]:-}" = "UNINSTALL_LOCK_HOURS_MONDAY=14:00-15:00" ] || fail "configure loader did not use last uninstall-lock entry: '${uninstall_lock_hours_lines[1]:-}'"

echo "OK: duplicate config keys use last matching entry"
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```bash
bash tests/test-config-duplicate-last-wins.sh
```

Expected: failure showing the first duplicate value was loaded.

- [ ] **Step 3: Change configure loader to last-wins**

In `lib/configure-config-load.sh`, change the three duplicate-sensitive reads:

```bash
day_line_exists=$(grep -E "^[[:space:]]*${day_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
lock_line_exists=$(grep -E "^[[:space:]]*${lock_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
uninstall_lock_line_exists=$(grep -E "^[[:space:]]*${uninstall_lock_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
```

to:

```bash
day_line_exists=$(grep -E "^[[:space:]]*${day_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | tail -n1)
lock_line_exists=$(grep -E "^[[:space:]]*${lock_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | tail -n1)
uninstall_lock_line_exists=$(grep -E "^[[:space:]]*${uninstall_lock_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | tail -n1)
```

- [ ] **Step 4: Consider scalar settings separately**

Do not change scalar settings in this task unless tests show a user-visible mismatch with runtime behavior. The review finding was specific to day/range entries where runtime parsers already use last-wins.

- [ ] **Step 5: Run targeted configure-loader tests**

Run:

```bash
bash tests/test-config-duplicate-last-wins.sh
bash tests/test-configure-modular.sh
bash tests/test-configure-text-mode.sh
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/configure-config-load.sh tests/test-config-duplicate-last-wins.sh
git commit -m "fix: align configure loader duplicate config handling"
```

---

### Task 5: Repair Stale Config-Locking Test Expectation

**Files:**
- Modify: `tests/test-config-locking.sh`
- Test: `tests/test-config-locking.sh`

- [ ] **Step 1: Source time parsing in the test harness**

In `tests/test-config-locking.sh`, add `time-parsing.sh` between `config.sh` and `time-validation.sh`:

```bash
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/time-parsing.sh"
source "${SCRIPT_DIR}/lib/time-validation.sh"
source "${SCRIPT_DIR}/lib/config-locking.sh"
```

- [ ] **Step 2: Replace the wall-clock-dependent `22-23` assertion**

Replace the current `elif [ "${current_hour}" -ge 22 ]; then` branch with a deterministic direct check of the range helper:

```bash
if ! is_restricted_time "2230" "0-5,22-23"; then
  fail "Expected 22:30 to be active during second range (22-23)"
fi

if is_restricted_time "2300" "0-5,22-23"; then
  fail "Expected 23:00 to be inactive because range end times are exclusive"
fi
```

Keep the `is_config_lock_active()` checks for the current wall-clock hour only when the current hour is inside `0-5`.

- [ ] **Step 3: Run the repaired config-locking test**

Run:

```bash
bash tests/test-config-locking.sh
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add tests/test-config-locking.sh
git commit -m "test: fix config locking range boundary expectation"
```

---

### Task 6: Final Verification and Safety Scan

**Files:**
- No code files unless previous tasks expose regressions.

- [ ] **Step 1: Run the focused regression suite**

Run:

```bash
bash tests/test-overnight-carry-safety.sh
bash tests/test-configure-partial-lock.sh
bash tests/test-config-locking.sh
bash tests/test-lock-hours-phase2.sh
bash tests/test-uninstall-lock-hours.sh
bash tests/test-uninstall-lock-hours-phase2.sh
bash tests/test-popup-size-custom-validation.sh
bash tests/test-enhancement-03-window-sizes.sh
bash tests/test-popup-button-visibility.sh
bash tests/test-dialog-size-behavior.sh
bash tests/test-scheduler-platform-darwin-status.sh
bash tests/test-platform-darwin.sh
bash tests/test-config-duplicate-last-wins.sh
bash tests/test-configure-modular.sh
bash tests/test-configure-text-mode.sh
```

Expected: all pass.

- [ ] **Step 2: Run shell syntax checks on touched scripts**

Run:

```bash
bash -n lib/time-validation.sh
bash -n lib/config-locking.sh
bash -n lib/service-config-darwin.sh
bash -n lib/scheduler-platform.sh
bash -n lib/configure-input-popup-size.sh
bash -n lib/config-popup-size.sh
bash -n lib/configure-config-load.sh
bash -n tests/test-overnight-carry-safety.sh
bash -n tests/test-scheduler-platform-darwin-status.sh
bash -n tests/test-popup-size-custom-validation.sh
bash -n tests/test-config-duplicate-last-wins.sh
```

Expected: no output, exit code 0.

- [ ] **Step 3: Run the repository security scan**

Run:

```bash
./scripts/run-security-scan.sh --ci --with-tests
```

Expected: pass. If optional external tools are missing, record which ones were skipped by the script.

- [ ] **Step 4: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output, exit code 0.

- [ ] **Step 5: Update docs only if behavior notes changed**

If popup custom size docs or safety docs mention different limits or old overnight behavior, update the relevant file:

- `docs/SAFETY.md`
- `docs/architecture/map.md`
- `user-docs/MACOS.md`

Do not add docs churn if the existing docs already describe the intended behavior.

- [ ] **Step 6: Final commit if docs changed**

```bash
git add docs/SAFETY.md docs/architecture/map.md user-docs/MACOS.md
git commit -m "docs: align safety notes with bug fixes"
```

Skip this commit if no docs changed.

---

## Self-Review

Spec coverage:
- Finding 1 is covered by Task 1 and deterministic tests for configure-block, uninstall protection, config locking, lock hours, and uninstall lock hours.
- Finding 2 is covered by Task 2 and a Darwin wrapper status test.
- Finding 3 is covered by Task 3 and tests for text-mode percentages, custom pixels, and raw pixels.
- Finding 4 is covered by Task 4 and a duplicate-key configure-loader test.
- The stale `tests/test-config-locking.sh` failure is covered by Task 5.

Placeholder scan:
- No task contains "TBD", "TODO", "implement later", or unbounded "add tests" language. Each code-changing task includes concrete snippets and commands.

Type/function consistency:
- New helper name is `is_time_in_previous_day_overnight_tail` everywhere.
- New strict Darwin helper name is `launch_agent_bootout_strict` and is only used by `disable_scheduled_service`.
- New popup clamp helper name is `clamp_popup_dimensions_to_safe_display_max` everywhere.
