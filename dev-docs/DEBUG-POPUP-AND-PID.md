# Debug: No Popup During Restricted Hours / Stale PID Check

## 1. Check if a previous popup PID still exists

The popup PID is stored in:

- **File**: `~/.config/sleep-warning/.popup_pid`

### Commands (run in terminal)

**See if the PID file exists and what it contains:**
```bash
ls -la ~/.config/sleep-warning/.popup_pid 2>/dev/null && echo "--- Contents ---" && cat ~/.config/sleep-warning/.popup_pid
```

**Check whether that process is still running** (replace `PID` with the number from the file, or use the one-liner below):
```bash
# One-liner: report if PID file exists and if that process is alive
pid=$(cat ~/.config/sleep-warning/.popup_pid 2>/dev/null)
if [ -z "$pid" ]; then
  echo "No PID file found"
else
  if kill -0 "$pid" 2>/dev/null; then
    echo "Process $pid is still running (stale popup?)"
  else
    echo "Process $pid is not running (stale PID file)"
  fi
fi
```

**Search for any running dialog with our title** (yad/zenity/kdialog "Restricted Hours Alert"):
```bash
pgrep -af "yad.*Restricted|zenity.*Restricted|kdialog.*Restricted" || echo "No matching dialog processes"
```

**Optional: remove a stale PID file** (only if you’re sure no popup is visible):
```bash
rm -f ~/.config/sleep-warning/.popup_pid
```

---

## 2. Why the log only shows "System mode detected"

If the log has only lines like:

- `[2026-02-01 12:07:55] [INFO] System mode detected: desktop`
- `[2026-02-01 12:10:18] [INFO] System mode detected: desktop`

and **no** "Restricted time detected" or "Skipping new popup", then the script is exiting **before** it ever decides to show a popup. So either:

1. **Resume skip** – `should_skip_warning_after_resume` returned true.  
   In that case the log **would** contain:  
   `Skipping warning: System resumed X seconds ago (Y seconds remaining in grace period)`.  
   You don’t see that, so this is unlikely.

2. **Not treated as restricted** – `is_restricted` is false, so the script goes to “Not a restricted hour, exit silently” and never logs “Restricted time detected” or calls `show_warning`.  
   So during 12:00–12:30 PM on Sunday the script is deciding **current time is not in a restricted range**.

That usually means either:

- **Parsed Sunday config is wrong** – `parse_config(0)` returns something that doesn’t include 12:00–12:30, or
- **24h noon mis-converted** – Config stores `12:00-12:30` (24h, no am/pm). That was passed through `12hour_to_24hour(12, 0, 0)` with `is_pm=0`, so 12 was treated as midnight and output as `00:00-00:30`. Fixed in `lib/time-parsing.sh`: when the range has no am/pm we treat it as 24h and format as HH:MM directly (12 = noon).

**Range order:** The order of ranges in the config (e.g. 11pm–5am before 12–12:30pm) does **not** matter. `is_restricted_time()` loops over each range and returns true if **any** range matches.

---

## 3. Quick debug: what does the script think for Sunday?

From the project root, run (same env as the timer: config under `~/.config/sleep-warning`):

```bash
# From project root; uses installed or repo libs
source lib/library-loader.sh 2>/dev/null || true
init_library_paths "${HOME}/.local/lib/sleep-warning" "$(pwd)/lib"
source lib/config.sh
source lib/logging.sh
source lib/configure-core.sh
source lib/time-validation.sh
# Optional: load time-parsing so parse_config normalizes 12h format
source lib/time-parsing.sh 2>/dev/null || true

day=0   # Sunday
range=$(parse_config "$day")
echo "Parsed SUNDAY range: '${range}'"
current=$(date +%H%M)
echo "Current time HHMM: ${current}"
if is_restricted_time "${current}" "${range}"; then
  echo "Result: IN restricted hours"
else
  echo "Result: NOT in restricted hours"
fi
```

If “Parsed SUNDAY range” is empty or not what you expect (e.g. missing the 12:00–12:30 range), or “Result” is “NOT in restricted hours” while you’re in that window, the bug is in config parsing or time comparison.

---

## 4. Fix: load time-parsing in the main script

So that `parse_config()` can normalize 12-hour ranges when the timer runs, load `time-parsing.sh` from `sleep-warning.sh` (e.g. after `time-validation.sh`):

```bash
source_required_lib "time-parsing.sh" || exit 1
```

Then **reinstall** so the timer uses the updated code (see section 5). After reinstall, restart the timer and check the log again; you should see “Restricted time detected” and popup behavior during 12:00–12:30 PM on Sunday if the config is correct.

---

## 5. Timer runs the installed script (reinstall required)

The systemd timer runs the **installed** script at `~/.local/bin/sleep-warning.sh`, not the repo. Libs are in `~/.local/lib/sleep-warning/`. If you only changed files in the repo, the timer is still running the **old** installed copy. The debug snippet uses the **repo** libs, so it can show "IN restricted hours" while the timer (using old installed code) does not.

**Fix:** From the project root, run `./install.sh`. Then reload and restart the timer if needed: `systemctl --user daemon-reload` and `systemctl --user restart sleep-warning.timer`.

---

## 6. Diagnostic log line

Each run now logs one INFO line before deciding popup/no popup:

`Restriction check: day=X time=HHMM range='...' in_restricted=true|false`

- **in_restricted=false** – Script decided current time is not in any restricted range (no popup). Check that `range='...'` includes the window you expect.
- **range=''** – Either that day has **no restrictions** in the config (e.g. `SUNDAY=` with nothing after the equals), or the config file has **duplicate day lines** and the first one was empty (script now uses the **last** matching line per day). If `config_exists=yes` and the path is correct, check the config file for duplicate lines (e.g. `SUNDAY=` then `SUNDAY=00:00-05:00,...`) and remove the empty one, or reinstall so the updated parse (last line wins) is used.
- **in_restricted=true** – Script then logs "Restricted time detected" and calls `show_warning`. If no popup appears, see "Existing popup" or display/dialog issues above.

**Range 12:00–12:30:** End is **exclusive**. So 12:30:00 is already outside the window. Checks at 12:38, 12:40, etc. are outside the window; popups only when the check runs between 12:00 and 12:29 (inclusive).
