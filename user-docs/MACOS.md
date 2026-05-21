# macOS Support

> **Safety:** Read [**docs/SAFETY.md**](../docs/SAFETY.md) before install or development. If popups will not dismiss: `launchctl bootout gui/$(id -u)/com.sleep-warning` and `killall osascript` (details in [Troubleshooting](#troubleshooting-playbook) below).

Linux Sleep Warning System also runs on **macOS 13 (Ventura)** and later using a per-user **LaunchAgent** and **osascript** dialogs.

## Installation

```bash
git clone https://github.com/kgrizz-git/LinuxTimerWarning.git
cd LinuxTimerWarning
./install.sh
```

Requirements: `bash`, `osascript`, `launchctl` (all standard on macOS).

After install, configure restricted hours:

```bash
sleep-warning-configure --text
# or GUI for timer + hours only:
sleep-warning-configure --gui
```

## How scheduling works

| Linux | macOS |
|-------|-------|
| systemd user timer | LaunchAgent `com.sleep-warning` |
| `~/.config/systemd/user/` | `~/Library/LaunchAgents/com.sleep-warning.plist` |
| `CHECK_INTERVAL` → `OnCalendar` | `CHECK_INTERVAL` → `StartInterval` (seconds) |

The agent runs only while you are **logged in** (user session). It does not run when logged out.

Logs: `~/.config/sleep-warning/logs/launchd-stdout.log` and `launchd-stderr.log`, plus `warnings.log` from the app.

## Safety guardrails

The macOS build is designed so you are **not** left with a blocking dialog all day:

- **Hard watchdog:** each popup is killed if it runs longer than `POPUP_ABSOLUTE_MAX_SECONDS` (default 120s).
- **Auto-close forced on** for new installs (`POPUP_AUTO_CLOSE=true`).
- **Min display time capped** at 60 seconds on macOS (Linux allows up to 300s).
- **Duplicate popup prevention:** if a warning is still open, the next scheduled check skips showing another.
- **24/7 configure block:** saving restrictions that cover the entire week is blocked (same as Linux).
- **Pause button** on the warning dialog (once-per-day rules apply).

## Troubleshooting playbook

### Installation

- **`install.sh` fails:** Confirm macOS 13+ and that Terminal has not stripped `osascript`.
- **LaunchAgent not loaded:**  
  `launchctl print gui/$(id -u)/com.sleep-warning`

### Popup never appears

- Confirm restricted hours: `sleep-warning-status`
- Outside restricted hours the script exits silently (expected).
- **SSH / no GUI:** popups are skipped; check `~/.config/sleep-warning/warnings.log`.
- **Screen locked:** osascript may fail; see logs.

### Popup too often

- Adjust hours: `sleep-warning-configure --text`
- Use **Pause N min** on the dialog (subject to once-per-day settings).
- Disable scheduling: `sleep-warning-manage` → Disable, or see emergency stop below.

### Stuck or frozen popup (emergency)

1. **Stop scheduled checks:**
   ```bash
   launchctl bootout gui/$(id -u)/com.sleep-warning
   ```
   Or: `sleep-warning-manage` → Disable service.

2. **Close stuck dialogs:**
   ```bash
   killall osascript
   ```
   (This closes AppleScript dialogs system-wide.)

3. **Watchdog:** Normally the popup is killed within ~120 seconds automatically. If not, note the time and check `warnings.log` for a bug report.

4. **Edit config** (when not in configure-lock hours):
   ```bash
   sleep-warning-configure --text
   ```

### Cannot configure (locked)

Configuration may be blocked during restricted hours or when config lock is enabled. Wait for an unrestricted window, or disable the LaunchAgent first (step 1 above).

### Timer not firing

- LaunchAgents do not run when logged out.
- Reload manually:
  ```bash
  launchctl kickstart -k gui/$(id -u)/com.sleep-warning
  ```

### After sleep / wake

Resume grace uses boot-time detection on macOS. You may see a warning soon after wake unless grace applies.

### Uninstall blocked

If uninstall verification is enabled during restricted hours, complete the verification flow or use `manual-uninstall-guide`.

### Uninstall

```bash
sleep-warning-uninstall
```

## GUI configure scope on macOS

| Phase | GUI support |
|-------|-------------|
| Current | Timer, weekdays, weekends, review/save |
| Planned | Window behavior, security, visual grid, pause settings (full wizard parity) |

Use `--text` for the full configuration menu on macOS today.

## Differences from Linux

- No SteamOS gaming mode, systemd drop-ins, `yad`/`zenity`, `wmctrl`, or `journalctl`.
- Dialog tool is always **osascript** (`DIALOG_TOOL` setting ignored).
- Stay-on-top / immovable window options are not applied on macOS (Phase 3 may add limited support with Accessibility permission).

## Support

See the main [README.md](../README.md) and [CONFIGURATION.md](CONFIGURATION.md).
