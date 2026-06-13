# macOS Popup Blocking — Options and Implementation Notes

This document explains the options for creating a blocking warning popup on macOS,
what each approach can and cannot do, and the implementation decisions made for
this project.

## Background

The initial macOS popup was an `osascript display alert` — a small system notification
sheet. It appears in the top-right of the screen, can be easily dismissed or ignored,
and does not prevent use of other applications.

The goal is a **full-screen blocking overlay** that visually occupies the entire
display, enforces a minimum display time, and makes it meaningfully harder (not
impossible) to bypass.

---

## Option Comparison

### Option A — `osascript display alert` (original)

| | |
|---|---|
| **Dependencies** | None — ships with macOS |
| **Coverage** | Small dialog, top-right corner |
| **User bypass** | One click or Escape |
| **True blocking** | No |
| **Status** | Kept as fallback |

### Option B — tkinter fullscreen overlay ✅ implemented (primary)

| | |
|---|---|
| **Dependencies** | `python3` + `tkinter` (both already used by configure wizard) |
| **Coverage** | Full screen; semi-transparent dark panel with warning text |
| **User bypass** | Cmd+Tab, Mission Control — system shortcuts always work |
| **True blocking** | No (user-space only) |
| **Window level** | Standard foreground level, `-topmost`, periodic `lift()` |
| **Status** | Primary path |

A full-screen `tk.Tk()` window with `attributes("-fullscreen", True)` and
`attributes("-topmost", True)`, `grab_set()` to capture input, and a periodic
`lift()` call every 2 s keeps the window in front for casual use. The OK button
is disabled until the configured minimum display time elapses (live countdown
shown in the UI).

### Option C — pyobjc `NSScreenSaverWindowLevel` boost ✅ implemented (enhancement)

| | |
|---|---|
| **Dependencies** | `pip3 install pyobjc-core pyobjc-framework-Cocoa` |
| **Coverage** | Full screen; stays above fullscreen Spaces, screensavers, other apps |
| **User bypass** | Still possible via Cmd+Tab, login window, force-quit |
| **True blocking** | No — but significantly harder to dismiss than Option B |
| **Window level** | `NSScreenSaverWindowLevel` + `CanJoinAllSpaces + FullScreenAuxiliary + Stationary` |
| **Status** | Auto-detected and used when pyobjc is installed |

When pyobjc is available, `popup-blocker-darwin.py` locates the tkinter window
via `NSApplication.windows()` and raises its level to `NSScreenSaverWindowLevel`
with the following collection behaviour:

```python
NSWindowCollectionBehaviorCanJoinAllSpaces    # follows across all Spaces
NSWindowCollectionBehaviorFullScreenAuxiliary # overlays native fullscreen apps
NSWindowCollectionBehaviorStationary         # does not move with Space swipes
NSWindowCollectionBehaviorIgnoresCycle       # excluded from Cmd+Tab app switcher
```

**Installing pyobjc** (recommended for stronger blocking):

```bash
pip3 install pyobjc-core pyobjc-framework-Cocoa
```

After installation, restarting the LaunchAgent is sufficient — no reinstall needed:

```bash
launchctl bootout  gui/$(id -u)/com.sleep-warning
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.sleep-warning.plist
```

### Option D — Accessibility API (deferred — future work)

| | |
|---|---|
| **Dependencies** | User must grant Accessibility permission in System Settings |
| **Coverage** | Can intercept Cmd+Tab, Mission Control, global shortcuts |
| **User bypass** | Much harder — essentially requires log-out or force-kill |
| **True blocking** | Near-complete for casual use |
| **Status** | **Deferred** — see [TO_DO.md](TO_DO.md) |

With Accessibility API access the app can:
- Intercept and suppress `Cmd+Tab` and `Cmd+Space`
- Prevent Mission Control activation
- Disable the Dock during the block period

This requires the user to explicitly grant Accessibility permission
(`System Settings → Privacy & Security → Accessibility`). The install script
can prompt for this and open the correct pane automatically.

**Implementation sketch (future):**

```python
# Requires: pip3 install pyobjc-framework-ApplicationServices
from ApplicationServices import AXIsProcessTrustedWithOptions, kAXTrustedCheckOptionPrompt

trusted = AXIsProcessTrustedWithOptions({kAXTrustedCheckOptionPrompt: True})
if trusted:
    # Register CGEventTap to swallow Cmd+Tab, etc.
    ...
```

---

## What macOS will never allow (without root)

Even with Accessibility API, the following are always available to the user:

- Force-quit any app: `Cmd+Option+Escape`  
- Log out: Apple menu → Log Out (requires confirmation)
- Login window: fast user switching
- Kill the Python process: `kill <pid>` from another terminal
- Hardware power button / lid close

This is intentional per [docs/SAFETY.md](../docs/SAFETY.md) — the user must
always have an escape hatch.

---

## Safety invariants preserved

All blocking approaches retain the existing safety guardrails:

| Guardrail | Location | Behaviour |
|---|---|---|
| Hard watchdog | `lib/popup-safety.sh` | Kills popup process after `POPUP_ABSOLUTE_MAX_SECONDS` (default 330 s) |
| Min display cap | `popup_safe_get_min_display_time()` | Capped at 300 s on macOS (same as Linux) |
| Forced auto-close | `DARWIN_FORCE_AUTO_CLOSE=true` | Always closes; Python script mirrors this |
| OK button | `popup-blocker-darwin.py` | Always present; enabled once min display elapses |
| Pause button | `popup-blocker-darwin.py` | Shown when pause is configured; writes result to file |
| osascript fallback | `popup-dialog-implementations-darwin.sh` | Used when Python blocker is unavailable |
| Notification fallback | `popup-display-darwin.sh` | Used when all dialog methods fail |

---

## File layout

| File | Purpose |
|---|---|
| `lib/popup-blocker-darwin.py` | Python fullscreen blocking popup (Options B + C) |
| `lib/popup-dialog-implementations-darwin.sh` | Shell dispatcher: blocker → osascript → notification |
| `lib/popup-display-darwin.sh` | Orchestrator: builds message, calls dispatcher |
| `lib/popup-safety.sh` | Watchdog, caps, forced auto-close |

---

## Testing

```bash
# Syntax check
bash -n lib/popup-dialog-implementations-darwin.sh
python3 -m py_compile lib/popup-blocker-darwin.py

# Safety guardrails
bash tests/test-popup-safety-darwin.sh

# Manual smoke test (fires immediately, no LaunchAgent needed)
echo '{
  "title": "ALERT: Restricted time window",
  "message": "Manual test — you are in a restricted period.\nNext unrestricted time: 3:00 PM",
  "min_display_seconds": 5,
  "auto_close_seconds": 15,
  "pause_available": true,
  "pause_duration_minutes": 5,
  "result_file": "/tmp/sw_test_result.txt"
}' | python3 lib/popup-blocker-darwin.py
echo "Exit: $?  Result: $(cat /tmp/sw_test_result.txt 2>/dev/null)"
```
