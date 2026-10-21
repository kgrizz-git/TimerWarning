# Stream F final review — gamescope top-left + taller overlay (Claude Opus 5.5, 2026-10-20)

**Scope:** commit `93604ac` (Stream F: gamescope top-left + height ≥ ½ root) against its parent `52d81b3`, plus the follow-up fixes from this review.
**Plan:** [plan-gamescope-overlay-click-through-2026-10-19.md](../plans/plan-gamescope-overlay-click-through-2026-10-19.md) (On-device debug capture 2026-10-20; Stream F spike 4).
**Verdict:** **Approve with fixes (applied).** On-device click retest still open.

## What 93604ac does

| Area | Change | Gamescope-only? |
|------|--------|-----------------|
| `gamescope_interactive_dialog_dimensions` | Height = max(configured, ½ root), 200 px floor on tiny canvases, cap `root_h`; width stays full root | Yes (only called under `env_type=gamescope`) |
| `show_warning` | Forces `popup_position=top-left` when the root-size override succeeded (was forced `center`) | Yes |
| `_popup_show_pause_activated_notice` | Same top-left override; yad gets `--posx/--posy`, zenity/kdialog get a background `reposition_popup_window` | Yes (`_pause_position` stays `center` otherwise) |
| `calculate_popup_geometry` | Gamescope + top-left returns `0 0` without probing xrandr | Yes |

Desktop Mode: unchanged. The `center` default, the xrandr margin math, and the pause-notice `--center` all stay the same (tests cover the desktop yad pause notice and desktop top-left ≠ `0 0`).
No raise, lower, warp, or grab was added. `keep_window_on_top` still returns early on gamescope.
SAFETY: the watchdog, forced auto-close, the 16 h caps, and the escape hatch are untouched. Bigger geometry does not affect popup lifetime.

## gamescope 3.16.23 source findings (why top-left matters)

Read from `ValveSoftware/gamescope` tag `3.16.23` (`src/steamcompmgr.cpp`, `src/wlserver.cpp`):

1. **The overlay is always painted centered.** `paint_all` calls `paint_window(overlay, overlay, …)`. With `w == scaleW`, `paint_window_commit` sizes the layer from the window's own buffer, fit-scales it to the output, and centers it. The window's X11 `nX`/`nY` is only added when `w != scaleW`.
2. **Pointer coordinates are surface-local.** `wlserver_clampcursor` clamps to the mouse-focus surface extent (our dialog, about 2644×304 in the capture).
3. **The drawn cursor is offset by the window position.** `MouseCursor::paint(input, …)` places the hotspot at `(cursor − nX/nY) × scale + centering offset` of the input-focus window.

Together: a dialog mapped mid-canvas (zenity/GTK center) is *painted* mid-screen, but the visible cursor is shifted up by `nY × scale`. Example: a 2560×1600 root, a 304 px window at `nY≈648`, and a 1280×800 panel give a drawn cursor of roughly y 12–159 while the dialog is painted around y 326–473. That matches the reported "confined to roughly the top third; cannot reach the centered banner".

**Consequence:** moving the window to 0,0 is the load-bearing fix. It lines the drawn cursor up with the painted dialog. Height is secondary margin.

## Issues found and fixed in this review

### 1. zenity reposition silently fails when `wmctrl` is installed (high)

`check_window_tools` prefers `wmctrl`. gamescope never sets `_NET_CLIENT_LIST` (no match in `steamcompmgr.cpp`; the plan already records the atom as empty on device), so `wmctrl -l | grep` finds nothing. `reposition_popup_window` retries and returns 1, and the zenity dialog stays where GTK mapped it. zenity has no position flag, so on that path Stream F's top-left would never take effect. This Deck has `wmctrl` from `~/.nix-profile/bin` and `xdotool` in `/usr/bin`. Whether `wmctrl` is on the service PATH depends on the systemd user environment, so the failure is plausible on device.

`configure_request` in gamescope forwards `XConfigureWindow` unchanged, so `xdotool windowmove` (a plain `XMoveWindow`) is honored.

**Fix:** `reposition_popup_window` switches `wmctrl` → `xdotool` when `env_type=gamescope` and `xdotool` exists. Desktop keeps `wmctrl`. New tests cover both directions with stub binaries.

Yad already passes `--posx=0 --posy=0` at map time; its backup reposition now also works instead of failing harmlessly.

### 2. Height floor ½ → ⅔ root (requested)

Per the source reading above, the cursor band follows the window once it is at 0,0, so ½ would likely suffice. The user asked for taller, and the button row sits at the bottom of GTK message dialogs. ⅔ gives margin if the band model is off.
`floor_h = root_h * 2 / 3` (integer). The 200 px tiny-canvas floor and the `root_h` cap are unchanged. Width-axis fit scale is still about 1.0 (zenity grows to ~2644 on a 2560 root → about 0.97).
Examples: 1280×800 → 533; 3840×1440 → 960; 2560×1600 → 1066.

### 3. Docs / comments

`popup-display.sh` comment and log line, `CHANGELOG.md` (`### Changed`), `STEAMOS_GAMING_MODE.md`, `USER_GUIDE.md`, `CONFIGURATION.md`, `TO_DO.md`, and the plan now say ⅔ and describe the xdotool move.

## Confirmed sound (no change)

- **Countdown respawn** reuses the caller's `width`/`height`/`popup_position` locals, so the respawn stays top-left/tall (test 3c).
- **Pause notice** zenity path: `reposition_popup_window "${title}" … top-left` runs in the background and picks up the same xdotool switch (it inherits `env_type`).
- **Fallback when the root is unreadable** keeps the configured size and `center` (test 3c). This is no worse than before.
- **`calculate_popup_geometry`** gamescope/top-left short-circuit avoids the xrandr probe, which reports the panel, not the nested canvas.

## Residual risks / follow-ups (not fixed here)

| Risk | Note |
|------|------|
| Stock SteamOS without `xdotool` | zenity cannot be moved (no position flag), so the cursor offset remains. yad still works (`--posx/--posy`). Document if seen on device; installing xdotool or using yad are the remedies |
| kdialog | No size flags, so it stays a notification on 3.16.23. Already documented |
| `xdotool search --name` takes the first match | Title is fixed and the respawn kills the old dialog first. Acceptable |
| Debug census `root_size=unavailable` | `gamescope_overlay_scan_children` parses Width/Height from `xwininfo -root -children`, which prints no geometry. Log-only (Stream E). The `size override … -> WxH` INFO line still gives the root-derived height |
| `tests/test-gamescope-overlay.sh` ShellCheck SC2218 ×5 | Pre-existing (same count at `52d81b3`); functions are defined in sourced libs. Not touched |

## Verification

- `timeout 120 bash tests/test-gamescope-overlay.sh`: **137 passed, 0 failed** (includes the 2 reposition-tool tests; ½ expectations moved to ⅔ because the spec changed).
- `shellcheck -S error -x` (v0.10.0) on `lib/window-management.sh`, `lib/popup-display.sh`, `lib/popup-dialog-implementations.sh`: clean.
- `./scripts/run-tests.sh --tier a`: passed (22 run, 3 macOS-only skipped).
- `./scripts/run-security-scan.sh --ci`: ShellCheck section clean; gitleaks and semgrep are not installed on this Deck, so the script exits 1 for missing tools (not a finding).

## On-device retest (user)

1. `./install.sh --force` (outside restricted/blocked hours, or as normally done), keep experimental Gaming Mode on; optionally keep `GAMESCOPE_OVERLAY_DEBUG=true`.
2. In Gaming Mode, trigger a warning. Expect a full-width dialog anchored to the **top** of the screen, about two thirds of the screen tall.
3. Move the cursor (trackpad/mouse) onto **OK** and click. Also try touch. Note whether the drawn cursor tracks over the dialog.
4. Check the log for `size override … (root-width, top-left, height >= 2/3 root)` and the atom line's geometry.
5. If the dialog still appears centered with zenity: run `DISPLAY=:0 xdotool search --name 'ALERT: Restricted time window'` and `xwininfo -id <wid> | grep Absolute` while it is up, then report whether `xdotool` is on the service PATH.
6. If the cursor reaches the dialog but clicks do nothing, proceed to Stream D.
