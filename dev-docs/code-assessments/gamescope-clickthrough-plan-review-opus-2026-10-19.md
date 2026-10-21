# Review: `plan-gamescope-overlay-click-through-2026-10-19.md`

## 1. Overall: **needs rework** (small, focused rework)

Your device's own log and the gamescope build installed on it point to a different root cause than the plan's top hypothesis. H1 is close to ruled out. The plan's quoted classification rule comes from a different gamescope version than yours. Stream B, which the plan treats as a fallback, is probably the actual fix. The plan's structure (diagnose first, fallbacks after, safety held) is sound; mainly the hypothesis order and the gamescope claims need rewriting.

### What I checked
- **Your device:** gamescope `3.16.23.6`, single `X0` socket. `/usr/bin/xdotool` and `xwininfo` are installed, and `wmctrl` is in your nix profile.
- **Your log** (`~/.config/sleep-warning/warnings.log`, 2026-10-19 12:54):
  - zenity was picked, `Size: small`, then `Applied gamescope STEAM_OVERLAY=1 and STEAM_INPUT_FOCUS=1 to window 52428808` for the first popup and every respawn.
  - That ID is 0x3200008 written in decimal. Only the `xdotool search --name` fallback prints decimal, so the `_NET_WM_PID`/`_NET_CLIENT_LIST` lookup failed.
  - The earlier 04:05–04:55 popups were similar: one decimal ID (`54525960` = 0x3400008) logged for every PID. That fits the X server reusing ID slots, not a stale window.
- **Valve source:** `src/steamcompmgr.cpp` at tag `3.16.23`, read through a fetch agent. It quoted the code below verbatim except for the global input-focus pass (point 2), which it only paraphrased.

## 2. Issues

### Critical

1. **The overlay classification rule is wrong for your build.** In 3.16.23, `DetermineAndApplyFocus` reads:
   ```c
   if (w->GetGeometry().nWidth > 1200 && w->opacity >= maxOpacity) { overlayWindow = w; ... }
   else { notificationWindow = w; }
   ```
   - There is no `>= root_width` and no `|| inputFocusMode` term. `STEAM_INPUT_FOCUS` plays no part in classification on this build.
   - So a small zenity dialog (under 1200 px wide) always becomes the `notificationWindow`. Notifications are drawn but are never the input target.
   - The global input pick then falls back to `focusWindow`, which is the game.
   - That is exactly what you saw: visible, but clicks go through. The plan's `(width >= root_width || inputFocusMode)` is probably from newer master. Pin the source tag in the plan.

2. **H1 is mostly ruled out by evidence you already have.** Both `xprop -set` calls hit the same window ID in one call and logged success. The popup became visible, so `STEAM_OVERLAY` landed on a real top-level window, and `STEAM_INPUT_FOCUS` landed on the same one. Move H1 down to a quick confirmation step.

3. **The H1 check commands won't work in gamescope.** `_NET_CLIENT_LIST` wasn't found in the source portions read, and the decimal ID shows the PID lookup came back empty. That means `xprop -root _NET_CLIENT_LIST` won't list anything, and Stream A step 3 ("all windows with `_NET_WM_PID`") has nothing to iterate. Use `xdotool search --pid "$PID"` or `xwininfo -root -children` instead.

### Important

4. **The H2 timing theory is wrong.** Both atoms are re-read on PropertyNotify and mark focus dirty, so classification is recomputed each time, not fixed at first present. Drop "set before first present" and the 50 ms × 40 fast poll as mitigations. They won't change the outcome.

5. **The "2 s refresh" description is inaccurate.** In `lib/popup-display-linux.sh:186`, the refresh loop only runs when `window_tool` is empty. On your Deck it's `xdotool`, so atoms are applied once per spawn, with no refresh. That's harmless given point 4, but the plan's code table should say so. The plan also lists "requiring xdotool" as out of scope while xdotool is the path that actually works on your device. Make sure any fix keeps working with xprop alone.

6. **The H3 opacity contest is real and should be ranked second.** With equal opacity the condition is `>=`, so the window visited later wins. The window list runs from the top of the stack down, so a lower window can take `overlayWindow` from a higher one. Steam's own overlay window is 1280 wide and qualifies.
   - **Check:** read `_NET_WM_WINDOW_OPACITY` on Steam's `STEAM_OVERLAY` window while it's hidden. If it's `0`, we win the contest. If it's opaque, we can tie and lose.
   - **Mitigation:** setting our own `_NET_WM_WINDOW_OPACITY=0xffffffff` doesn't hurt, but it can't beat a tie.

7. **The global input-pick code isn't verified verbatim.** The fetch agent quoted the per-display pass exactly: any overlay with `inputFocusMode` becomes the input focus there. The global pass (`inputFocusWindow = overlayWindow` if it has `inputFocusMode`, else `focusWindow`) was only paraphrased. Before coding, quote it verbatim in the plan; it's the step that decides the outcome.

8. **Stream B needs specifics:**
   - Set the width from `xwininfo -root`, and make sure it's above 1200 (e.g. `max(root_w, 1201)`). Root width satisfies both the 3.16 rule and master's rule on Deck (1280) and when docked.
   - Height can stay modest. In 3.16.23, gamescope centers and scales overlays to their own size rather than assuming they sit at 0,0.
   - Touch coordinates are only recalculated when `overlay == inputFocusWindow`. After the fix, test touch accuracy, not just whether a tap registers.

### Minor

9. Stream C (`GAMESCOPE_EXTERNAL_OVERLAY`) can't give input on 3.16.23. External overlays are excluded from focus candidates and never assigned input focus. Change the stream to "rejected — no input path" rather than a time-boxed spike.
10. Record `gamescope --version`, the SteamOS build, the dialog tool, and window geometry (`xwininfo -id`) in the evidence table. The actual dialog was zenity, not yad.
11. Separate bug spotted in the log: after the auto-close SIGTERM, it says `User closed popup manually` and then `exited with code 143`. That's a wrong classification. File it in TO_DO, not this plan.
12. Add a safety note: once our dialog holds input, the game and possibly Steam's quick-access menu won't get input for the popup's lifetime. That's intended modal behavior, but it relies on the existing auto-close and watchdog bounds. Stream B needs no SAFETY.md invariant change.

## 3. Recommended plan edits

- **Evidence:** add the 12:54 log excerpt (zenity, small, decimal ID from xdotool, atoms applied on each respawn) and gamescope `3.16.23.6`.
- **"Is clickable UI possible?":** replace the quoted rule with the verbatim 3.16.23 code (`nWidth > 1200 && opacity >= maxOpacity`, else notification). Note that master may differ and pin the tag.
- **Hypotheses, reordered:**
  - New H1: notification classification because width ≤ 1200 (primary).
  - H2: Steam overlay opacity tie (current H3).
  - H3: wrong window or missing atom (current H1, now a confirmation step).
  - Keep the touch/trackpad input-type hypothesis (H4) and the dialog-tool hypothesis (H5).
  - Remove the timing hypothesis.
- **Diagnostic commands:** replace `_NET_CLIENT_LIST` with `xdotool search --pid`, `xwininfo -root -children`, `xwininfo -id $WID` (geometry), `xprop -id $WID STEAM_OVERLAY STEAM_INPUT_FOCUS _NET_WM_WINDOW_OPACITY`, and `xprop -root | grep -i GAMESCOPE` (focused-window atoms).
- **Workstreams:** promote Stream B to first, with the width rule from point 8 and gamescope-only gating.
  - Slim Stream A to a debug read-back log: window ID, which lookup path found it, and its geometry.
  - Mark Stream C rejected.
  - Keep Stream D as the fallback.
- **Code table:** correct the refresh description (only runs when `window_tool` is empty).
- **Tests:** add a mocked test that the gamescope spawn passes a width above 1200 or the root width. Drop "fail if only `STEAM_OVERLAY` set" as a root-cause test (keep it as a regression test if you want).
- **Manual checklist:** add "dialog width (xwininfo) > 1200", "touch lands on the button under the finger (scaling)", and "Steam QAM still usable after auto-close".
- **Review checklist:** replace the H1-first item with "agree width-based classification is the primary hypothesis".

## 4. Are clickable buttons achievable?

**Probably yes.** On 3.16.23 the only path is a window tagged with `STEAM_OVERLAY` that is wider than 1200 px, has `STEAM_INPUT_FOCUS` nonzero, and wins the opacity contest. Small dialogs can't get input on this build no matter what atoms they carry.

The plan's wrong claims about gamescope:
- (a) The `width >= root_width || inputFocusMode` rule (it's not in 3.16.23).
- (b) Classification depending on when the atoms are set (they're re-read on change).
- (c) Usefulness of `_NET_CLIENT_LIST` (not found in gamescope).
- (d) `GAMESCOPE_EXTERNAL_OVERLAY` as a possible input path (it can't take input).

The `STEAM_INPUT_FOCUS=1` versus `2` guidance is correct: mode 2 sends the keyboard back to the game.

## 5. Status

Keep **NEEDS REVIEW**. I didn't edit any files. Before approving, confirm on the Deck with one `xwininfo -id` and one `xprop` dump while the popup is up. It should show width ≤ 1200 and both atoms set to 1, which confirms the new H1.
