# Weekday GUI Configuration Bug Assessment

## Symptom

When using the GUI (macOS) option to configure weekdays, the restricted hours
are only applied to Monday — Tuesday through Friday remain unconfigured.

## Investigation

### Key Code Paths

Two paths exist for weekday configuration (`lib/configure-workflow.sh:49-121`):

1. **Bulk apply** — user says "Yes" to "same hours for all weekdays" → one time
   range is collected via `get_day_hours` and applied to indices 1–5 in a
   `for i in 1 2 3 4 5` loop.

2. **Per-day flow** — user says "No" → each weekday is configured individually
   with a `prompt_continue_day_flow` dialog between days. If the user chooses
   "Return to Menu" after Monday, only Monday is configured.

### Likely Root Cause

**The user is landing in the per-day flow (path 2) instead of the bulk-apply
flow (path 1).** After configuring Monday, `prompt_continue_day_flow` presents
a "Continue configuring weekdays?" dialog. If this dialog is missed or
dismissed — which is easy on macOS due to z-order issues — the function
returns and only Monday is saved.

There are two interacting factors:

#### Factor 1: macOS dialog z-order regression

`ask_weekday_together` (lib/configure-ui.sh:345-362) uses
`show_question_dialog`, which on macOS uses **osascript `display alert`**.
The main menu and list dialogs are rendered by the **tkinter daemon**
(`configure-dialogs-darwin-daemon.py`).

On macOS 13+, osascript dialogs can appear **behind the terminal** after a
tkinter window closes (a well-documented z-order regression). The codebase
already has a workaround for this in `show_confirm_dialog`
(lib/configure-dialogs-darwin.sh:700-715), which intentionally uses
`show_list_dialog` (tkinter daemon or `choose from list`) instead of
`display alert` to avoid this issue. However, `ask_weekday_together` still
uses the vulnerable `show_question_dialog` → `display alert` path.

If the "Same hours for all weekdays?" dialog appears behind the terminal:
- The user may not see it.
- Clicking elsewhere dismisses it as "No" (the `cancel button`).
- The wizard silently proceeds to the per-day flow.

#### Factor 2: Per-day continuation dialog (`prompt_continue_day_flow`) also uses `display alert`

`prompt_continue_day_flow` (lib/configure-workflow.sh:23-47) also calls
`show_question_dialog`, which on macOS uses `display alert`. After Monday is
configured in the per-day flow, this dialog asks "Next up: Tuesday. Continue
configuring weekdays?" with "Yes, Continue" / "Return to Menu" buttons.

If this dialog also appears behind the terminal (same z-order issue), the
user may not see it and either:
- Dismiss it via Escape/close (which maps to "Return to Menu" via `cancel
  button`), ending configuration with only Monday set.
- Never interact with it, perceiving that configuration is "done."

### Why Bulk Apply Might Also Fail

Even if `ask_weekday_together` correctly returns "Yes" and the bulk-apply loop
runs, there is a theoretical risk from a known class of bash nameref bugs. The
`configure_weekdays_section` function combines `local -n` namerefs with `local`
declarations inside a `for` loop:

```bash
local -n config_lines_ref="$2"
local -n summary_lines_ref="$3"
...
for i in 1 2 3 4 5; do
    local day_var="${DAY_VARS[${i}]}"
    config_lines_ref[${i}]="${day_var}=${weekday_range}"
    summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${weekday_range}"
done
```

In bash 4.3–4.4, there are documented bugs where `local` declarations inside
loops that also use `local -n` namerefs can cause array element assignments to
fail silently or become mis-scoped. Bash 5.0+ fixes most of these issues.
Since macOS uses Homebrew bash (typically 5.x), this is unlikely to be the
primary cause but is worth hardening against.

### Why the Config File Write Path Is NOT the Bug

`_write_restrictions_section` (lib/configure-config.sh:539-549) writes all
non-empty entries from the `config_lines` nameref array. The config file
correctly includes all 5 weekday lines when tested through the write path.
The bug manifests _before_ the save step — the in-memory `config_lines` array
simply doesn't have entries for Tuesday–Friday.

## Recommended Fixes

### Fix 1: Replace `show_question_dialog` with `show_list_dialog` in `ask_weekday_together` (Primary fix)

Follow the same pattern already used in `confirm_cancel`
(lib/configure-ui.sh:144-180) and `show_confirm_dialog`
(lib/configure-dialogs-darwin.sh:700-715): use `show_list_dialog` instead of
`show_question_dialog` on macOS to avoid the `display alert` z-order regression.

This should be applied to:
- `ask_weekday_together` (lib/configure-ui.sh:345-362)
- `ask_weekend_together` (lib/configure-ui.sh:365-383)

These are the two gatekeeper dialogs that decide between bulk and per-day flow.
If either is missed, the user silently enters per-day configuration.

### Fix 2: Also protect `prompt_continue_day_flow`

Even with Fix 1, the per-day continuation dialog (`prompt_continue_day_flow`,
lib/configure-workflow.sh:23-47) should also use `show_list_dialog` on
macOS. Otherwise, if the user _does_ enter per-day mode (e.g., deliberately
choosing "No"), the continuation prompt after Monday is still vulnerable to
the z-order issue.

### Fix 3: Harden `configure_weekdays_section` loop

Move the `local day_var` declaration outside the `for` loop to eliminate any
risk of bash nameref scoping issues:

```bash
local day_var  # Declare once, outside the loop
for i in 1 2 3 4 5; do
    day_var="${DAY_VARS[${i}]}"
    ...
done
```

This is a defensive measure — the current code is not provably buggy in
bash 5.x, but the `local` inside the loop adds no value and is a known risk
pattern with namerefs.

## Files to Modify

| File | Change |
|------|--------|
| `lib/configure-ui.sh` | `ask_weekday_together`: replace `show_question_dialog` with macOS-safe dialog |
| `lib/configure-ui.sh` | `ask_weekend_together`: same replacement |
| `lib/configure-workflow.sh` | `prompt_continue_day_flow`: replace `show_question_dialog` with macOS-safe dialog |
| `lib/configure-workflow.sh` | `configure_weekdays_section`: move `local day_var` outside loop |

## Verification

1. On macOS, run `./configure.sh --gui`, select "Weekdays Configuration", and
   confirm the "Same hours for all weekdays?" dialog correctly appears in
   front and returns "Yes".
2. After bulk-applying a time range, inspect
   `~/.config/sleep-warning/config/sleep-warning.conf` and verify all five
   weekday entries (MONDAY through FRIDAY) are present.
3. Test the per-day flow: select "No" to bulk, configure Monday, and verify
   the "Continue configuring weekdays?" dialog is visible and functional.
4. Test on Linux with yad/zenity to ensure no regressions.