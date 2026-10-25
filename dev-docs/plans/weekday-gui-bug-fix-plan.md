# Weekday GUI Bug — Detailed Fix Plan

**Status:** Partially implemented; Phase 2 systematic dialog hardening remains open.

The weekday/weekend together prompts, continuation prompt, and loop hardening
shipped (see CHANGELOG). Phase 2.2's systematic macOS question/info override
has not shipped: `lib/configure-dialogs-darwin.sh` still uses osascript
`display alert` for those functions. Keep this plan active for the remaining
caller audit and hardening decision. The z-order warning comment (Phase 2.3)
is present. Diagnosis: [weekday-gui-bug-assessment.md](../weekday-gui-bug-assessment.md).

## Overview

This plan addresses the bug where weekday configuration in GUI mode (especially macOS) only applies to Monday. The root cause is a macOS z-order regression where `display alert` dialogs (used by `show_question_dialog` and `show_info_dialog` on macOS) appear behind the terminal after tkinter dialogs close, causing users to miss or dismiss the "same hours for all weekdays?" prompt. This silently routes them into the per-day flow where the continuation prompt is also vulnerable, leaving only Monday configured.

## Goals

1. **Immediate fix**: Stop the weekday/weekend configuration bug so users can reliably configure all weekdays via GUI.
2. **Hardening**: Eliminate the `local` inside `for` loop anti-pattern in nameref array code.
3. **Systematic prevention**: Apply the macOS-safe dialog pattern to all `show_question_dialog` and `show_info_dialog` callers in the configure path so this class of bug does not recur.
4. **Zero regressions**: Ensure Linux (yad/zenity/kdialog) paths remain unchanged.

## Phase 1: Targeted Fixes (High Priority)

### 1.1 Harden `ask_weekday_together` and `ask_weekend_together`

**Why**: These are the gatekeeper dialogs that decide between bulk-apply and per-day flow. If they are missed, the user silently enters per-day mode.

**File**: `lib/configure-ui.sh`

**Current behavior**:
- Uses `show_question_dialog` → on macOS triggers `osascript display alert` (z-order vulnerable).

**Desired behavior**:
- On macOS: use `show_list_dialog` (tkinter daemon / `choose from list`) instead of `show_question_dialog`.
- On Linux: keep using `show_question_dialog` (yad/zenity/kdialog are not affected by this z-order issue).

**Implementation pattern**:
Follow the exact pattern already proven in `show_confirm_dialog` (configure-dialogs-darwin.sh:700-715) and `confirm_cancel` (configure-ui.sh:144-180):

```bash
ask_weekday_together() {
    local use_gui="$1"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        if type is_darwin >/dev/null 2>&1 && is_darwin; then
            # macOS-safe: list dialog instead of display alert
            local choice
            choice=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "Would you like to use the same restricted hours for all weekdays (Monday-Friday)?" \
                600 300 \
                "Yes" \
                "No")
            local list_exit=$?
            if [ ${list_exit} -ne 0 ] || [ -z "${choice}" ]; then
                return 1  # Dismissed or cancelled → treat as "No"
            fi
            [ "${choice}" = "Yes" ]
            return $?
        fi
        # Linux path: keep original show_question_dialog
        show_question_dialog \
            "Sleep Warning Configuration" \
            "Would you like to use the same restricted hours for all weekdays (Monday-Friday)?" \
            "Yes" \
            "No"
        return $?
    else
        # Text mode unchanged
        configure_read -p "Use same hours for all weekdays (Monday-Friday)? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}
```

Apply the same pattern to `ask_weekend_together` (line 365-383). Note: `ask_weekend_together` currently passes explicit dimensions `650 250` to `show_question_dialog`; the `show_list_dialog` call should use similar dimensions.

**Rationale for not changing Linux**: `show_question_dialog` on Linux uses yad/zenity/kdialog which do not exhibit the z-order regression. Changing them to `show_list_dialog` would alter the UI (yad `--question` vs `--list` behave differently) and is unnecessary.

### 1.2 Harden `prompt_continue_day_flow`

**Why**: Even if Fix 1.1 works perfectly, a user who deliberately chooses "No" (per-day) will still hit this vulnerable continuation prompt after Monday. If the prompt is missed, they exit with only Monday configured.

**File**: `lib/configure-workflow.sh`

**Current behavior**:
- Uses `show_question_dialog` → on macOS triggers `display alert`.

**Desired behavior**:
- On macOS: use `show_list_dialog` instead.
- On Linux: keep using `show_question_dialog`.

**Implementation**:
Same pattern as 1.1, adapted for the three-button variant (Yes, Continue / Return to Menu):

```bash
prompt_continue_day_flow() {
    local use_gui="$1"
    local next_label="$2"
    local section_label="$3"
    local prompt_text="Next up: ${next_label}. Continue configuring ${section_label}?"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        if type is_darwin >/dev/null 2>&1 && is_darwin; then
            local choice
            choice=$(show_list_dialog \
                "Continue Configuration?" \
                "${prompt_text}" \
                600 300 \
                "Yes, Continue" \
                "Return to Menu")
            local list_exit=$?
            if [ ${list_exit} -ne 0 ] || [ -z "${choice}" ]; then
                return 1
            fi
            [ "${choice}" = "Yes, Continue" ]
            return $?
        fi
        # Linux path unchanged
        show_question_dialog \
            "Continue Configuration?" \
            "${prompt_text}" \
            "Yes, Continue" \
            "Return to Menu" \
            600 250
        return $?
    else
        # Text mode unchanged
        local answer
        configure_read -p "${prompt_text} [Y/n]: " answer
        case "${answer}" in
            [Nn]*) return 1 ;;
            *) return 0 ;;
        esac
    fi
}
```

### 1.3 Harden `configure_weekdays_section` loop

**Why**: Defensive measure against a known bash anti-pattern (`local` inside loops with `local -n` namerefs). Even if the primary bug is the z-order issue, this eliminates a theoretical risk.

**File**: `lib/configure-workflow.sh`

**Current** (line 66-75):
```bash
for i in 1 2 3 4 5; do
    local day_var="${DAY_VARS[${i}]}"
    if [ "${weekday_range}" != "skip" ]; then
        config_lines_ref[${i}]="${day_var}=${weekday_range}"
        summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${weekday_range}"
    else
        config_lines_ref[${i}]="${day_var}="
        summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
    fi
done
```

**Change**:
Move `local day_var` to the top of the function (or just before the loop). Declare once, assign inside the loop.

```bash
local day_var  # Declare once
for i in 1 2 3 4 5; do
    day_var="${DAY_VARS[${i}]}"
    ...
done
```

Also apply the same pattern to `configure_weekends_section` (line 289-365) where `local day_var` and `local allow_back` are declared inside loops, and to `configure_lock_hours_section` and `configure_uninstall_lock_hours_section` which have the same `local day_var` inside loops pattern (approximately 12 additional `local day_var` declarations across those two functions).

---

## Phase 2: Systematic Prevention (High Priority)

### 2.1 Audit ALL vulnerable `show_question_dialog` / `show_info_dialog` calls in the configure path

The z-order issue is not isolated to the weekday dialog. Any `show_question_dialog` or `show_info_dialog` on macOS after a tkinter dialog is vulnerable. Here is the full inventory of callers that should be hardened:

| Function | File | Dialog Type | Risk if Missed |
|----------|------|-------------|----------------|
| `ask_weekday_together` | `lib/configure-ui.sh` | `show_question_dialog` | User enters per-day flow, only Monday saved |
| `ask_weekend_together` | `lib/configure-ui.sh` | `show_question_dialog` | User enters per-day flow, only Saturday saved |
| `prompt_continue_day_flow` | `lib/configure-workflow.sh` | `show_question_dialog` | User exits per-day flow after first day |
| `show_high_restriction_warning` | `lib/configure-ui.sh` | `show_question_dialog` | User cannot confirm "Save Anyway" |
| `show_welcome` | `lib/configure-ui.sh` | `show_info_dialog` | Low risk (informational only) |
| `show_24_7_error` | `lib/configure-ui.sh` | `show_info_dialog` | Medium risk: user doesn't see 24/7 block |
| `show_cap_violation_error` | `lib/configure-ui.sh` | `show_info_dialog` | High risk: user doesn't see cap violation |
| `show_partial_lock_violation_error` | `lib/configure-ui.sh` | `show_info_dialog` | High risk: user doesn't see why save is blocked |
| `show_config_locked_error` | `lib/configure-ui.sh` | `show_info_dialog` | High risk: user doesn't see why configure is locked |
| `show_config_file_locked_error` | `lib/configure-ui.sh` | `show_info_dialog` | High risk: same as above |
| `confirm_skip_day` | `lib/configure-ui.sh` | `show_question_dialog` | High risk: called after tkinter time picker; skip dialog hidden → day silently skipped |
| `show_summary_save_dialog` (Save Configuration?) | `lib/configure-display.sh` | `show_question_dialog` | Critical risk: called after tkinter summary dialog; hidden → entire configuration session lost |

**Decision matrix for each**:
- **Informational only** (`show_welcome`, `show_24_7_error`, `show_cap_violation_error`, etc.): Can stay on `show_info_dialog` if the risk is just "user didn't read the message." But these are safety-critical messages, so they should also be hardened.
- **Requires user choice** (`show_high_restriction_warning`, `ask_weekday_together`, etc.): Must be hardened to use `show_list_dialog` on macOS.

### 2.2 Create a systematic macOS override

**Approach A (Recommended): Wrap `show_question_dialog` and `show_info_dialog` in configure-dialogs-darwin.sh**

Instead of patching every caller individually, create macOS-safe wrappers in `configure-dialogs-darwin.sh` that override the base functions. This is the least error-prone approach and prevents future callers from introducing the same bug.

```bash
# In configure-dialogs-darwin.sh
# Replace the existing show_question_dialog and show_info_dialog
# with macOS-safe implementations that delegate to the list/text
# dialog when appropriate.

show_question_dialog() {
    # ... existing signature ...
    # Use show_list_dialog instead of display alert
    # ...
}

show_info_dialog() {
    # ... existing signature ...
    # Use show_text_dialog (tkinter) or show_list_dialog
    # for safety-critical messages
    # ...
}
```

**Trade-offs**:
- **Pros**: Single point of change; future callers are automatically protected; consistent with `show_confirm_dialog` precedent.
- **Cons**: Changes the UI paradigm for all question/info dialogs on macOS (from `display alert` to `choose from list` / tkinter). This is a visual change that might affect user familiarity. But since the existing `show_confirm_dialog` already made this switch, the precedent is established.

**Approach B (Alternative): Patch each caller individually**

Only apply the macOS-safe pattern to the high-risk callers listed in the audit table. This is the current approach documented in the assessment.

- **Pros**: Minimal UI change; only fixes the known-broken paths.
- **Cons**: Future callers can reintroduce the bug; the codebase accumulates a patchwork of safe/unsafe calls.

**Recommendation**: Start with **Approach B** (targeted fixes) for the weekday bug to keep the change minimal and reviewable. Then create a **tracked follow-up issue** to evaluate **Approach A** (systematic override) for the next release, since the safety-critical dialogs (`show_cap_violation_error`, `show_config_locked_error`, etc.) are also at risk.

> **Mixed pattern note**: Phase 1 patches `is_darwin` checks into individual caller functions, while `show_confirm_dialog` solves the same z-order problem as a platform override in `configure-dialogs-darwin.sh`. This leaves two patterns for the same bug class. The follow-up issue for Approach A should unify these into a single mechanism.

### 2.3 Add a warning comment to `show_question_dialog` and `show_info_dialog` definitions

In `configure-dialogs-darwin.sh`, add a header comment above the macOS implementations:

```bash
# ⚠️ macOS Z-ORDER WARNING:
# show_question_dialog and show_info_dialog use osascript display alert.
# On macOS 13+, display alert dialogs may appear BEHIND the terminal after
# a tkinter dialog closes. Callers in the configure path should prefer
# show_list_dialog (for questions) or show_text_dialog (for info) when
# the dialog immediately follows a tkinter window.
# See: ../weekday-gui-bug-assessment.md
```

This prevents future developers from accidentally introducing new vulnerable callers.

---

## Phase 3: Verification (Required before merge)

### 3.1 Text-mode baseline

Run the weekday bulk test in text mode to confirm the data path is correct independent of GUI.

**⚠️ Critical safety requirement:** `configure.sh` read loops spin forever on EOF (AGENTS.md). The piped input must match the exact prompt sequence, or the script will hang. If the wizard hits an error, validation retry, or unexpected menu, stdin is exhausted and the loop spins without bound. **A timeout is mandatory** to bound this risk.

**Environment requirements:** This text-mode test requires either Linux (native `timeout`) or macOS with a timeout mechanism. On macOS, prefer `gtimeout` from Homebrew coreutils (`brew install coreutils`). If coreutils is unavailable, use the Perl or background+kill fallbacks below.

**Helper function (recommended — add to project test helpers):**
```bash
# Cross-platform timeout. Usage: sw_timeout SECONDS COMMAND [ARGS...]
sw_timeout() {
    local secs="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "${secs}" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${secs}" "$@"
    elif command -v perl >/dev/null 2>&1; then
        perl -e "alarm ${secs}; exec \@ARGV" -- "$@"
    else
        # Fallback: background + kill (less precise, but needs no extra tools)
        "$@" &
        local pid=$!
        sleep "${secs}"
        kill "${pid}" 2>/dev/null
        wait "${pid}" 2>/dev/null
    fi
}
```

**Linux (using `timeout`):**
```bash
export TEST_HOME=$(mktemp -d)
export HOME="${TEST_HOME}"
timeout 10 bash -c "printf '\n3\ny\n0-5\n13\ny\n' | ./configure.sh --text" || true
cat ~/.config/sleep-warning/config/sleep-warning.conf | grep -E '^(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY)='
```

**macOS (recommended: install coreutils first):**
```bash
brew install coreutils   # provides gtimeout
```
Then:
```bash
export TEST_HOME=$(mktemp -d)
export HOME="${TEST_HOME}"
gtimeout 10 bash -c "printf '\n3\ny\n0-5\n13\ny\n' | ./configure.sh --text" || true
cat ~/.config/sleep-warning/config/sleep-warning.conf | grep -E '^(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY)='
```

**macOS (using Perl, always available — no coreutils needed):**
```bash
export TEST_HOME=$(mktemp -d)
export HOME="${TEST_HOME}"
perl -e 'alarm 10; exec @ARGV' -- bash -c "printf '\n3\ny\n0-5\n13\ny\n' | ./configure.sh --text" || true
cat ~/.config/sleep-warning/config/sleep-warning.conf | grep -E '^(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY)='
```

**macOS (background + kill, no extra dependencies):**
```bash
export TEST_HOME=$(mktemp -d)
export HOME="${TEST_HOME}"
printf '\n3\ny\n0-5\n13\ny\n' | ./configure.sh --text > output.txt 2>&1 &
CPID=$!
sleep 10
kill $CPID 2>/dev/null || true
cat ~/.config/sleep-warning/config/sleep-warning.conf | grep -E '^(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY)='
```

Expected: All five weekday lines with `0-5`.

### 3.2 macOS GUI test

On macOS with Homebrew bash installed:

```bash
./configure.sh --gui
```

Manual steps:
1. Select "3. Weekdays Configuration" from the main menu.
2. Verify the "Same hours for all weekdays?" dialog appears **in front** of the terminal.
3. Click "Yes".
4. Enter a time range (e.g., 11:00pm to 5:00am) and confirm.
5. Click "No, Done" on the "Add another range?" dialog.
6. Return to main menu.
7. Select "13. Review and Save".
8. Verify the summary shows all five weekdays with the same range.
9. Click "Yes, Save".
10. Inspect the config file:
    ```bash
    cat ~/.config/sleep-warning/config/sleep-warning.conf
    ```
    Expected: `MONDAY=23:00-05:00`, `TUESDAY=23:00-05:00`, etc.

### 3.3 macOS per-day flow test

```bash
./configure.sh --gui
```

Manual steps:
1. Select "3. Weekdays Configuration".
2. Click "No" (configure separately).
3. Configure Monday with a range.
4. Verify the "Continue to Tuesday?" dialog appears **in front**.
5. Click "Yes, Continue".
6. Verify Tuesday time picker appears.
7. Continue through all five days.
8. Save and verify all five weekdays are in the config file.

### 3.4 Regression test: Linux

On a Linux machine with yad or zenity:

```bash
./configure.sh --gui
```

Repeat the same manual steps as 3.2. Verify:
- The yad/zenity question dialogs still work correctly.
- The weekday bulk apply still saves all five days.
- No visual or behavioral regressions.

### 3.5 Run existing test suite

```bash
bash tests/test-configure-interactive.sh
bash tests/test-configure-comprehensive.sh
bash tests/test-configure-text-mode.sh
```

All existing tests should pass. The text-mode tests are unaffected by the GUI changes.

### 3.6 Security scan

Per the AGENTS.md checklist:

```bash
./scripts/run-security-scan.sh --ci --with-tests
```

---

## Phase 4: Documentation (Required before merge)

### 4.1 Update CHANGELOG.md

Add an entry under the next version:

```markdown
### Fixed
- macOS: Weekday configuration in GUI mode only applied to Monday due to
  `display alert` z-order regression. Fixed by using `show_list_dialog`
  for `ask_weekday_together`, `ask_weekend_together`, and
  `prompt_continue_day_flow` on macOS.
```

### 4.2 Update AGENTS.md if needed

If the AGENTS.md mentions `configure-dialogs-darwin.sh` or z-order behavior,
add a cross-reference to the new assessment document.

### 4.3 Update user-docs/MACOS.md if needed

Add a note about the z-order fix for macOS users.

---

## Rollback Plan

If any regressions are detected during verification:

1. Revert the changes in `lib/configure-ui.sh` and `lib/configure-workflow.sh`.
2. Re-run the test suite to confirm the baseline passes.
3. Re-open the bug and investigate the specific regression.

The changes are localized to two files (three if doing the systematic override), so rollback is clean.

---

## Timeline Estimate

| Phase | Estimate | Notes |
|-------|----------|-------|
| Phase 1.1–1.3 (targeted fixes) | 2 hours | Straightforward pattern application |
| Phase 2.1 (audit) | 1 hour | Inventory only, not all fixes |
| Phase 2.2 (systematic override) | 4–6 hours | More complex, may be deferred to follow-up |
| Phase 3 (verification) | 2 hours | Requires macOS and Linux test machines |
| Phase 4 (documentation) | 30 min | CHANGELOG + cross-references |
| **Total** | **~1 day** | If deferring systematic override to follow-up |

---

## Open Questions

1. **Should we apply the systematic override (Phase 2.2) now or defer?**
   - *Recommendation*: Defer to a follow-up PR. The targeted fixes are sufficient to stop the reported bug. The systematic override is a broader change that needs more testing and UX review.

2. **Should `show_welcome` also be hardened?**
   - *Recommendation*: No. The welcome dialog is informational only; if the user doesn't see it, they can still proceed. The `show_question_dialog` and `show_info_dialog` used for **blocking/safety messages** (cap violations, config locked, etc.) should be prioritized in the follow-up.

3. **Should we add automated GUI tests for this?**
   - *Recommendation*: No. GUI testing on macOS (osascript/tkinter) is extremely fragile and not currently part of the test suite. The existing text-mode tests cover the data path; manual GUI verification is the pragmatic approach.
