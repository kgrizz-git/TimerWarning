# Plan: Gamescope Overlay Click-Through (Buttons Not Clickable)

**Status: PHASE 2 IN PROGRESS** — Streams A+B (full-width overlay) shipped 2026-10-19. On-device retest 2026-10-20 found **partial** success; mouse/pointer and dual keyboard delivery still open. Grok 4.7 reviewed this Phase 2 revision on 2026-10-20 (approve-with-fixes, edits applied). Claude Opus 5.5 second review 2026-10-20: approve-with-fixes, edits applied; plan is ready for Stream E coding.

| | |
|---|---|
| **Created** | 2026-10-19 |
| **Updated** | 2026-10-20 (retest findings, then Grok 4.7 plan fixes: split-focus hypothesis, log-only debug flag; then Opus 5.5 fixes: list order proven, raise rejected, overlay census, kill-switch, file-only writer read) |
| **Related** | [plan-steamos-gaming-mode-overlay-2026-10-16.md](plan-steamos-gaming-mode-overlay-2026-10-16.md), [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md) |
| **Reviews** | Opus CLI approved the Phase 1 plan. Grok 4.7 Phase 2 review 2026-10-20: approve-with-fixes, edits applied ([archive](../code-assessments/gamescope-clickthrough-phase2-plan-review-grok-2026-10-20.md)). Claude Opus 5.5 Phase 2 review 2026-10-20: approve-with-fixes, edits applied, plan approved for coding (Stream E first) ([archive](../code-assessments/gamescope-clickthrough-phase2-plan-review-opus-2026-10-20.md)). |
| **On-device evidence** | See [Retest 2026-10-20](#retest-2026-10-20-after-full-width-fix) and earlier 2026-10-19 notes |
| **Device context** | `gamescope` **3.16.23.6**; Deck Gaming Mode |
| **Safety** | [docs/SAFETY.md](../../docs/SAFETY.md) — do not weaken watchdog, 16 h cap, or escape hatch; auto-close / finite lifetime remain mandatory in gamescope |

## Problem

Experimental Gaming Mode overlay (`STEAM_OVERLAY=1` + `STEAM_INPUT_FOCUS=1` on Xwayland `:0`) successfully composites the warning dialog above the game. Input does **not** reach the dialog chrome (OK / Pause / etc.): pointer/touch events behave as if they pass through to the fullscreen game.

## On-device evidence (2026-10-19)

From `~/.config/sleep-warning/warnings.log` (~12:54 session) and host tools:

- Gaming Mode experimental path ran; **zenity** selected; size **small**.
- Log: `Applied gamescope STEAM_OVERLAY=1 and STEAM_INPUT_FOCUS=1 to window <decimal_id>` on first show and countdown respawns (e.g. `52428808` = `0x3200008`).
- Decimal IDs indicate the **xdotool `search --name` fallback** found the window — `_NET_CLIENT_LIST` / `_NET_WM_PID` lookup returned empty (expected under gamescope; that atom is not a reliable client list here).
- Host: `gamescope version 3.16.23.6`; `/usr/bin/xdotool` and `xwininfo` present.

**Interpretation:** Visibility proves `STEAM_OVERLAY` landed on a real top-level window. Click-through with atoms also logged strongly suggests gamescope classified the dialog as a **notification** (drawn) rather than the **interactive overlay** (input), not a failed `xprop -set`.

### Why the dialog is magnified (Opus follow-up — corrected)

User report (docked large monitor): warning filled most of the screen; text looked blocky/soft despite log `Size: small` (~400×250 fixed).

**Real cause on gamescope 3.16.23 (per-window fit-to-canvas scaling), not “whole nested FB blown up to the TV” and not nearest-neighbor filtering:**

1. Notifications/overlays are painted scaled against **their own buffer size** so they **fit the gamescope nested canvas** (`g_nNestedWidth/Height`, usually matching `:0` root on Deck).
2. `calc_scale_factor` roughly does `min(canvasW/srcW, canvasH/srcH)` (fit), optionally clamped by `g_flMaxWindowScale` (defined outside `steamcompmgr.cpp` — unverified value), then applies output/nested ratio.
3. Overlay/notification paint uses **`NoFilter` → smooth (linear) scaling**. Soft/blocky text is from stretching a ~400 px-wide buffer ~3–4×, not integer nearest.
4. **Not docking-specific:** the same small dialog should also look screen-filling **undocked** on the Deck panel (unless max-scale clamps). The TV mostly makes softness easier to notice.
5. Extra root props `STEAM_SCREEN_SCALE` / `STEAM_SCREEN_MAGNIFICATION` can add more zoom (minor; record if set).

**Worked examples:** 400×250 on 1280×800 canvas ≈ **3.2×**; on 1920×1080 ≈ **4.3×** — fills most of the view either way.

### Stream B also fixes magnification (no design tension)

A dialog **as wide as the canvas** with modest height scales at **1.0** for the width axis (e.g. 1280×350 on 1280×800 → `min(1.0, 800/350)=1.0`) → sharp 1:1 in nested space, **and** clears `nWidth > 1200`.

So the click-through fix and the sharpness fix are the **same change**. Remaining softness after that is only canvas→TV (shared with the game and Steam UI).

**Width rule (revised):** `width = :0 root/canvas width` (never less than 1201; if root &lt; 1201 use `max(1201, root_w)` only as a last resort). **Do not** use widths in (1201, canvas_w) — those still get magnified (e.g. 1201 on 1920 ≈ 1.6×). Height modest (≤ ~½ root height). Never size to the TV’s native pixels.

**Confirm next session:**

```bash
DISPLAY=:0 xwininfo -root | rg 'Width|Height'
DISPLAY=:0 xwininfo -id "$WID" | rg 'Width|Height'   # actual buffer; zenity may ignore --height
xprop -root GAMESCOPE_SCALING_FILTER STEAM_SCREEN_SCALE STEAM_SCREEN_MAGNIFICATION
tr '\0' ' ' </proc/$(pgrep -x gamescope | head -n1)/cmdline; echo
# Note docked vs undocked for click-through vs magnification symptoms
```

Also check undocked: does a current **small** dialog already fill most of the Deck panel? That cheaply confirms per-window scaling.

## Is clickable UI even possible?

**Probably yes on this SteamOS gamescope build**, but **only** if the window meets gamescope’s interactive-overlay rules. Small dialogs cannot receive input on **3.16.23** no matter what atoms they carry.

### Verbatim rule — gamescope **3.16.23** (`steamcompmgr.cpp`)

Pin this tag; **do not** assume `master`. On the Deck:

```c
// Classify STEAM_OVERLAY windows (simplified from DetermineAndApplyFocus):
if (w->isOverlay) {
    if (w->GetGeometry().nWidth > 1200 && w->opacity >= maxOpacity) {
        ctx->focus.overlayWindow = w;   // interactive candidate
        ...
    } else {
        ctx->focus.notificationWindow = w;  // drawn, not the input pick
    }
}
```

Global input pick (same tag; confirm verbatim at implement time around the `overlayWindow->inputFocusMode` branch):

- If `overlayWindow` exists **and** `overlayWindow->inputFocusMode` (from `STEAM_INPUT_FOCUS`) → `inputFocusWindow = overlayWindow`.
- **Else** → `inputFocusWindow = focusWindow` (**the game**).

Implications:

| Condition | Result |
|-----------|--------|
| `STEAM_OVERLAY` + width **≤ 1200** (typical “small” zenity) | → `notificationWindow` → **visible, no input** (matches user report) |
| `STEAM_OVERLAY` + width **> 1200** + wins opacity + `STEAM_INPUT_FOCUS ≠ 0` | → can become `inputFocusWindow` → **buttons clickable** |
| `STEAM_INPUT_FOCUS=2` | Mouse may stay on overlay; **keyboard** routed back to game — prefer **`1`** for our modal |
| `GAMESCOPE_EXTERNAL_OVERLAY` | Separate plane; **cannot take input** on 3.16.23 — **not** a fix path |

Deck internal panel is 1280-wide; `root_width` (1280) satisfies `> 1200`. Docked higher resolutions also work if we size to root width.

**Note:** Newer gamescope `master` may use a different rule (e.g. `width >= root_width \|\| inputFocusMode`). Always pin the **installed** `gamescope --version` when coding or retesting.

## Current code path

| Piece | Location | Notes |
|-------|----------|--------|
| Force X11 on `:0` in gamescope | `lib/popup-display.sh` | OK for visibility |
| Set `STEAM_OVERLAY=1` + `STEAM_INPUT_FOCUS=1` | `lib/window-management.sh` → `apply_gamescope_overlay_atoms` | Appears successful in log. Also sets `_NET_WM_WINDOW_OPACITY=0xffffffff` (cannot beat a later equal-opacity window) |
| Full-width size | `gamescope_interactive_dialog_dimensions` | Width = `:0` root (1201 only if root ≤ 1200). Height = configured, floored at 200, capped at half root |
| Window lookup | `find_window_id_for_popup` | Prefers `_NET_CLIENT_LIST` (empty in gamescope) → **xdotool `--onlyvisible --pid`** → title → `xwininfo` |
| Background arm | `lib/popup-display-linux.sh` → `_popup_linux_arm_gamescope_atoms` | **2s refresh loop runs only when `window_tool` is empty.** On Deck with xdotool, atoms apply **once per spawn**, not every 2s. `keep_window_on_top` returns immediately on gamescope |
| Unit tests | `tests/test-gamescope-overlay.sh` | Mocked xprop; no geometry / 1200 rule |

## Hypotheses (ordered after Opus review)

### H1 — Notification classification because width ≤ 1200 (**primary**)

Small zenity + `STEAM_OVERLAY` → `notificationWindow` → game keeps `inputFocusWindow`. Explains visible + click-through with successful atom logs.

**Confirm on next show:**

```bash
# While popup is up (gamescope Xwayland, usually :0):
export DISPLAY=:0
WID=$(xdotool search --name "Sleep Warning" | head -n1)   # or title actually used
xwininfo -id "$WID" | rg 'Width|Height|Absolute'
xprop -id "$WID" STEAM_OVERLAY STEAM_INPUT_FOCUS _NET_WM_WINDOW_OPACITY WM_NAME _NET_WM_PID
```

Expect: width ≤ 1200, both Steam atoms = 1.

### H2 — Steam overlay opacity tie (secondary)

Interactive pick uses `opacity >= maxOpacity` while walking the list; a later equal-opacity Steam overlay (≥1200 wide) can win `overlayWindow`.

**Check:** While our popup is up (and Steam QAM closed vs open), compare `_NET_WM_WINDOW_OPACITY` on competing `STEAM_OVERLAY` windows. Optional: set ours to `0xffffffff`.

### H3 — Wrong window / missing atom (confirmation only)

Mostly ruled out by the 12:54 log (same WID, both atoms set, popup visible). Keep a one-shot `xprop` read-back as regression insurance.

### H4 — Input modality (touch / trackpad / mouse)

After a width fix, retest touch accuracy (gamescope recalculates touch when `overlay == inputFocusWindow`) as well as trackpad and optional controller A.

### H5 — Dialog tool / window type

zenity was used in the failing session; retest yad/kdialog only after geometry fix, or force the same wide geometry for all tools in gamescope.

### Rejected hypotheses

- **“Set atoms earlier / 50ms poll”** — atoms are re-read on PropertyNotify; timing does not flip notification vs overlay when width ≤ 1200.
- **`GAMESCOPE_EXTERNAL_OVERLAY` as input path** — no input assignment on 3.16.23.

## Retest 2026-10-20 (after full-width fix)

User report in SteamOS Gaming Mode:

| Observation | Interpretation |
|-------------|----------------|
| Dialog **full width**, **not tall** | **Expected.** Stream B forces width = `:0` root; height stays modest (preferred height from configure size, e.g. `small` ≈ 250px, capped at ½ root). Not a failed override. Raising configure popup size can increase height up to the half-root cap; full-screen tall needs a code change if desired. |
| **Enter** on keyboard activated OK | Keyboard focus reaches the dialog — `STEAM_INPUT_FOCUS` partially working |
| Enter **may also have hit Steam UI underneath** | Dual delivery / focus not exclusive — Steam QAM or Big Picture may still see key events. Verify with `GAMESCOPE_KEYBOARD_FOCUS_DISPLAY` vs `GAMESCOPE_MOUSE_FOCUS_DISPLAY` (not `GAMESCOPE_FOCUSED_WINDOW`, which stays the game) and whether dismiss coincided with a Steam action |
| Mouse/cursor **cannot move onto** the popup; cannot click it | Pointer still bound to the game (or overlay hit-test fails). Separate from keyboard path on gamescope 3.16.23 |
| **No Cancel button** like on Desktop | Investigate: (1) zenity `--warning` is OK-only (+ optional Pause extra-button) — Desktop “Cancel/Dismiss” may be yad/kdialog wording; (2) Pause may be unavailable (`can_pause_now` false) so only OK shows; (3) short height + `--fixed` (yad) may **clip** a second button; (4) wrong tool in Gaming Mode vs Desktop. Log `dialog_tool`, `pause_available`, requested vs actual geometry, and button flags. |

**Phase 1 result:** visibility + width + keyboard-on-dialog improved. **Not done:** exclusive keyboard, pointer/mouse, button chrome parity, confirmed exclusive dismiss.

### Phase 2 hypothesis — split focus (primary)

Pinned to gamescope tag **3.16.23** (`steamcompmgr.cpp`, read 2026-10-20). Height is not part of classification. Two different picks explain the retest:

```c
// Per-Xwayland walk: ANY isOverlay window with inputFocusMode (width is not required).
// Last window in the ctx->list walk wins. Then XSetInputFocus on that window,
// unless inputFocusMode == 2, in which case the keyboard goes to focusWindow (the game).
if (VirtualConnectorIsSingleOutput() && w->isOverlay && w->inputFocusMode)
    inputFocus = w;

// Global pick: cursor and touch follow overlayWindow only when THAT window
// (the width > 1200 opacity winner) has inputFocusMode. Otherwise the game.
if (VirtualConnectorIsSingleOutput() && overlayWindow && overlayWindow->inputFocusMode) {
    inputFocusWindow = overlayWindow;      // cursor; touch scaling only if overlay == this
    keyboardFocusWindow = overlayWindow;
} else {
    inputFocusWindow = focusWindow;        // the game
    keyboardFocusWindow = overrideWindow ? overrideWindow : focusWindow;
}
if (VirtualConnectorIsSingleOutput() && inputFocusMode == 2)
    keyboardFocusWindow = overrideWindow ? overrideWindow : focusWindow;
```

Tie-break on the overlay slot is `opacity >= maxOpacity`, so a **later** window in the `ctx->list` walk wins an equal opacity. `0xffffffff` is already the max we can set.

**List order (proven from 3.16.23 source, Opus 5.5 review):** `ctx->list` is **top of stack first**. `CreateNotify` → `add_win(…, prev=0)` inserts at the head; `restack_win` (from `ConfigureNotify`) re-hooks the window just before its `above` sibling; `CirculateNotify PlaceOnTop` re-hooks before the current head; `configure_request` forwards `stack_mode` unchanged, so client raises are honored. Consequences:

- "Later in the walk" means **lower in the X stack**. On an opacity tie, the **bottom-most** wide `STEAM_OVERLAY` wins `overlayWindow`. The per-ctx `inputFocus` pick ("last `isOverlay && inputFocusMode`") is also the bottom-most such window.
- `XRaiseWindow` moves our dialog **earlier** (to the head), which **loses** ties. A raise spike would make things worse, not better.
- gamescope **already raises** the per-ctx input-focus window itself (`if (ctx->list[0] != inputFocus) XRaiseWindow(inputFocus)` in `DetermineAndApplyFocus`). Because Enter reaches the dialog, our dialog is very likely already at the head of `:0`'s list. So any wide Steam overlay window on `:0` with opacity `0xffffffff` sits later in the walk and takes `overlayWindow`. If that window has `STEAM_INPUT_FOCUS=0`, the global cursor stays on the game. That is the split seen in the retest.
- Lowering our window is not a fix either. gamescope would raise it again on the next focus pass (fighting over the stack each pass), and it changes stacking for every client on `:0`.
- The walk does **not** filter by map state. Unmapped windows stay in `ctx->list` until destroyed, with their last-read `isOverlay`/opacity (property events are deselected on unmap). A hidden Steam overlay window can still compete.

Net: from the client side on 3.16.23 we can only control our own width, opacity (already max), and `STEAM_INPUT_FOCUS`. If a competing wide overlay at max opacity exists below us on `:0`, our dialog cannot win the global pick by stacking tricks.

`GAMESCOPE_FOCUSED_WINDOW` is `focusWindow` (the game) on this tag. It will not match the dialog WID during a game. The probes that match this split are `GAMESCOPE_MOUSE_FOCUS_DISPLAY` and `GAMESCOPE_KEYBOARD_FOCUS_DISPLAY`.

**These probes are per display, not per window.** Steam's own overlay windows live on `:0` with our dialog. So "mouse display = `:0`" can mean **either** our dialog **or** a Steam overlay window has the cursor. They only separate dialog from game when `GAMESCOPE_FOCUS_DISPLAY` (the game) is a **different** display (normally `:1` on Deck). Telling our dialog apart from a Steam overlay needs the window-level overlay census in Stream E item 5.

What this predicts for the 2026-10-20 retest:

| Observation | Fit |
|-------------|-----|
| Enter activates OK | Per-ctx `XSetInputFocus` landed on the dialog (`STEAM_INPUT_FOCUS=1`, mode ≠ 2) |
| Enter may also hit Steam or the game | Global `keyboardFocusWindow` can still be Steam's overlay or the game while X11 focus is the dialog |
| Cursor cannot enter the popup | Cursor is painted for global `inputFocusWindow`, which is the opacity-winning overlay or the game, not "whoever has X focus" |

`window_wants_no_focus_when_mouse_hidden` is Steam-only. It does not park our dialog's cursor. A taller banner does not change which window wins `overlayWindow`.

**Phase 2 order:** prove which window is global input focus (Stream E) before changing height or atoms (Stream F). Stacking changes are rejected on 3.16.23 (see list order above). Button labels (Stream G) are a separate chrome question.

## Phased implementation

| Phase | What | Go / no-go |
|-------|------|------------|
| **0 — Confirm** | On-device small-popup width ≤ 1200 | Done (pre-fix) |
| **1 — Full-width fix** | Streams A+B | Done 2026-10-19; retest 2026-10-20 partial |
| **2 — Input exclusivity + chrome** | Streams E–G (log-only debug flag, then focus-identity spikes, then button chrome) | Cursor on dialog; Enter/A does not also activate Steam UI or the game; buttons match the tool matrix. Steam/QAM button chords stay out of scope |
| **3 — Fallback docs** | Stream D if pointer remains impossible | Product decision documented |

Stream C (`GAMESCOPE_EXTERNAL_OVERLAY`) stays **rejected** on 3.16.23.

## Proposed workstreams

### Stream B — Force interactive geometry (**primary fix path** — also fixes magnification)

Gamescope-only: spawn the warning (and pause confirmation) at **full `:0` root/canvas width** with **modest height**.

1. Gate on `env_type=gamescope` only; Desktop Mode sizes unchanged.
2. **Width = root width on `:0`** (must be &gt; 1200; Deck 1280 is fine). Height modest (≤ ~½ root height). Never TV-native pixels; never a partial width like 1201 on a wider canvas.
3. Keep `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` (value **1**, not 2).
4. **Done in Phase 1:** `_NET_WM_WINDOW_OPACITY=0xffffffff` is already set. Do not set it again as new work. It cannot outrank a later window at the same opacity (`>=`).
5. Keep `GAMESCOPE_FORCE_AUTO_CLOSE` + absolute watchdog.
6. Confirm zenity/yad/kdialog actually honor the requested geometry (`xwininfo` read-back); GTK4 zenity may ignore `--height` or enforce minima.
7. Leave `GDK_SCALE` / HiDPI unset in the gamescope popup env so buffer size matches window size.
8. **After fix:** expect ~1:1 sharpness in nested space; docked TV softness should match Steam UI / game (not worse). If read-back still shows scale ≫ 1, fall back to documenting residual blur.
9. **Safety note:** once we hold input, the game (and possibly Steam QAM) will not receive input for the popup lifetime — intentional modal behavior; still bounded by auto-close/watchdog. No `docs/SAFETY.md` invariant change.

### Stream A — Diagnostics / lookup hardening (**supporting**)

1. Log: resolved WID, lookup path (`_NET_CLIENT_LIST` / xdotool / xwininfo), **actual** geometry (width×height from `xwininfo`), atom set + read-back.
2. Prefer `xdotool search --pid` / `xwininfo -root -children` when `_NET_CLIENT_LIST` is empty — keep an xprop/`xwininfo`-only path workable.
3. Do not rely on “tag all `_NET_WM_PID` via `_NET_CLIENT_LIST`” under gamescope.

### Stream C — `GAMESCOPE_EXTERNAL_OVERLAY`

**Rejected** on 3.16.23 (no input path). Do not time-box a spike unless a future gamescope version documents otherwise.

### Stream D — Document non-clickable fallback (if pointer remains impossible)

If pointer cannot be given to the overlay on this SteamOS build after Streams E–G:

1. Document: Gaming Mode warnings may be keyboard/auto-close oriented; mouse may stay on the game.
2. Keep escape hatch + forced auto-close.
3. Steamworks plugin remains separate future work.

### Stream E — Gated debug logging (**implement first in Phase 2**)

**Approved name:** `GAMESCOPE_OVERLAY_DEBUG`. **Log-only.** When on, it must not change geometry, atoms, button sets, auto-close, or the watchdog. Default **off**.

Getter: `get_gamescope_overlay_debug` in `lib/config.sh`, same shape as `get_gaming_mode_experimental_enabled`. Key constant in `lib/config-keys.sh`. Call sites in the gamescope popup/atom path. Do not put a second parser in `lib/window-management.sh`.

| Source | Rule |
|--------|------|
| Environment | If set to `true`/`1`/`yes` or `false`/`0`/`no` (after trim, strip quotes, casefold), **the env wins**, including explicit false over a config true. Unrecognized or unset falls through. |
| Config key | Same boolean tokens. Missing key stays **false**. |
| Writer | `lib/configure-config-write.sh` rewrites the whole file and drops unknown keys. If the key is present in the file, the writer must read the **file** value back and emit it (normalized `true`/`false`). If the key is absent, omit it, so configs of users who never used the flag stay unchanged. Do **not** use the env-aware getter for this. Otherwise a session `set-environment GAMESCOPE_OVERLAY_DEBUG=true` (or any env leaking into the configure shell) would be saved into the file on the next configure save. Add a config-only helper (for example `_get_gamescope_overlay_debug_from_config`) that the getter also uses. Do not add a configure-wizard prompt. |
| Partial lock | Add an explicit **neutral** arm (either value allowed) in `configure_partial_lock_validate_scalar`, with a one-line comment like the `GAMING_MODE_EXPERIMENTAL_ENABLED` arm. This key is not a cap, a popup lifetime, or an escape hatch. The validator's default arm already allows unknown fields; the explicit arm is so a later edit does not copy the "any change blocked" pattern used for `DIALOG_TOOL`. No baseline capture or `validate_proposed` call is needed, because the wizard never edits this key. A partial-lock test asserts both directions return 0. |

On-device enablement (do **not** edit the installed `sleep-warning.conf` during restricted or blocked hours; tests keep using a temp `HOME`):

- Preferred: a **separate** drop-in `~/.config/systemd/user/sleep-warning.service.d/gamescope-overlay-debug.conf` with `Environment=GAMESCOPE_OVERLAY_DEBUG=true`, then `systemctl --user daemon-reload`. Do not put this line in `mode-gaming.conf` — configure regenerates that file.
- One session: `systemctl --user set-environment GAMESCOPE_OVERLAY_DEBUG=true`. The unit is `Type=oneshot`, so the **next** timer start inherits it. Undo with `unset-environment`. This sets the variable on the whole user manager until logout, not only sleep-warning.
- A shell `export` does not reach the service.
- **Turn it off afterwards:** delete the drop-in and `daemon-reload`. `uninstall.sh` removes only the `.service`/`.timer` files, not `sleep-warning.service.d/`, so the docs must say this explicitly. An orphaned drop-in does nothing without the unit, but it would re-enable debug on a reinstall.

**Bounding (log-only must also mean "cannot delay or hang the popup"):** every debug `xprop`/`xwininfo` call is wrapped in `timeout` (≤ 2 s each) and runs in the existing backgrounded atom-arm path, never in front of the dialog spawn or the watchdog arm. The census (item 5) inspects at most 64 root children. A failed or timed-out probe logs `unavailable` and continues.

When the getter is true **and** `env_type=gamescope`, log one `DEBUG-GAMESCOPE` block per spawn, countdown respawn, and pause notice — **not** on the 2s atom poll:

1. Root size, requested vs override width/height, `popup_position`, `dialog_tool`
2. `pause_available`, `pause_duration`, and the button flags actually passed (see Stream G matrix)
3. Lookup path, WID, `--onlyvisible` PID hit count, post-map `xwininfo` geometry
4. Atom read-back: `STEAM_OVERLAY`, `STEAM_INPUT_FOCUS`, `_NET_WM_WINDOW_OPACITY`
5. Root focus displays. These are display-name strings (`":0"`, `":1"`) written as format-32 CARDINAL with `strlen+1` items, not WIDs. Log the raw `xprop` value **and** a decoded string (little-endian bytes of the items up to the first NUL; ignore bytes after it):
   - `GAMESCOPE_MOUSE_FOCUS_DISPLAY` — display of global `inputFocusWindow` (cursor)
   - `GAMESCOPE_KEYBOARD_FOCUS_DISPLAY` — display of global `keyboardFocusWindow`
   - `GAMESCOPE_FOCUS_DISPLAY` — display of `focusWindow` (the game/base layer)
   - `GAMESCOPE_FOCUSED_WINDOW` is that base window's id. A mismatch with our WID is **expected** while a game is running and is not evidence that the overlay lost input
   - `GAMESCOPE_SCALING_FILTER` / `STEAM_SCREEN_SCALE` only when present
6. **`:0` overlay census** (window-level evidence; the display probes cannot tell our dialog from a Steam overlay). From one `xwininfo -root -children` snapshot, for each child (≤ 64) that has `STEAM_OVERLAY` set: WID, stack index, map state, width, `_NET_WM_WINDOW_OPACITY` (absent = `0xffffffff`), `STEAM_INPUT_FOCUS`, `WM_CLASS`, and `is_ours`. Then compute and log `predicted_overlay_wid` with the 3.16.23 rule: walk **top → bottom**; the last window with `width > 1200` and `opacity >= running max` wins; mapped and unmapped windows both count. Record which direction `xwininfo` prints children. Calibrate once on device: gamescope raises the per-ctx input-focus window to the top, so with Enter reaching the dialog, our WID should sit at the top end. Only log the window name when it is not our dialog (do not log our title/body).
7. On exit: exit code, whether the pause handler ran, timestamp

Do not log the warning message body. When the flag is off, keep today's one-line atom INFO and do not emit `DEBUG-GAMESCOPE`.

Document the flag in `STEAMOS_GAMING_MODE.md` and, briefly, `CONFIGURATION.md` (advanced, default off).

### Stream F — Pointer / exclusive keyboard (Phase 2)

Goals, after Stream E logs:

1. **Pointer:** the cursor can enter the dialog and a click activates OK or Pause (trackpad and/or touch).
2. **Keyboard:** Enter/A activates the dialog and does not also activate a Steam UI control or the game. The Steam/QAM **button** is a compositor chord; capturing it is out of scope. After dismiss or auto-close, QAM must work again.

Spikes, in order. Stop when logs answer the question. Do not change the default height first.

1. Read `GAMESCOPE_MOUSE_FOCUS_DISPLAY` and `GAMESCOPE_KEYBOARD_FOCUS_DISPLAY`. Cursor-on-game shows up as the mouse display staying on the game plane while the dialog is on `:0`. Keyboard on `:0` and mouse on the game plane is the split. Read the Stream E census (`predicted_overlay_wid`, competing overlays' opacity and `STEAM_INPUT_FOCUS`) with these, then apply the decision table below. Re-asserting `STEAM_INPUT_FOCUS` on a window that is not `overlayWindow` will not move the cursor. Do not use `GAMESCOPE_FOCUSED_WINDOW` for this; on 3.16.23 that property is `focusWindow` (the game).
2. The 2s refresh in `_popup_linux_arm_gamescope_atoms` does **not** run when `window_tool` is set. Deck has xdotool, so atoms are once per spawn. A re-apply spike must be explicit, still backgrounded, and bounded by the popup duration. Do not clear `window_tool` to turn the old loop on.
3. **No raise or lower spike (rejected by the Opus 5.5 review).** On 3.16.23, `ctx->list` is top first, so a raise moves us **earlier** and loses `>=` ties. gamescope already raises the per-ctx input-focus window itself, and a lower would be raised again on the next focus pass. If the census shows another wide overlay won the tie, there is no client-side stacking fix. Go to the decision table below. Do not set `STEAM_INPUT_FOCUS=2`. Re-open this only for a different gamescope version whose source shows another walk order or tie rule.
4. Taller height (including full root height) only if logs show our WID **is** global input focus and clicks still miss the button rectangle. That change belongs here, not in Stream G, and must stay gamescope-only, ≤ root height, and re-check that OK/Pause are still visible. Full-width + full-height stays scale 1.0; it is not a magnification regression.
5. Do not warp or `XGrabPointer` from the shell. gamescope hides the cursor on input-focus change and owns the pointer. An X11 warp on `:0` is unlikely to move that cursor, and a grab in the parent shell can outlive the dialog. The watchdog must remain the lifetime bound.

If our window is global input focus and pointer events still never arrive, stop and write Stream D. Keep Enter and forced auto-close.

**Decision table after the first `GAMESCOPE_OVERLAY_DEBUG` cycle (kill-switch).** Read the decoded displays together with the census `predicted_overlay_wid`:

| `FOCUS_DISPLAY` (game) | Mouse / keyboard display | `predicted_overlay_wid` | Meaning | Next |
|---|---|---|---|---|
| ≠ `:0` | mouse = game display, keyboard = game or `:0` | another Steam window | Split confirmed. Steam's wide overlay won the tie | Stream D (no client-side stacking fix on 3.16.23). Record the competing window's class/opacity/`STEAM_INPUT_FOCUS` |
| ≠ `:0` | mouse = game display | ours | Census/rule mismatch: our model of 3.16.23 is wrong somewhere | Stop. Re-read source against the installed build before any code change |
| ≠ `:0` | **both `:0`** | ours | **Split-focus hypothesis is wrong for this session.** We already hold global input | If the cursor visibly enters the window but clicks miss the buttons, spike 4 (taller height) is the only Stream F step left. Otherwise stop at Stream D |
| ≠ `:0` | both `:0` | another Steam window | Steam's overlay holds input (would also explain Enter hitting Steam) | Stream D. Note it as a Steam-side interaction |
| = `:0` | any | any | Display probes cannot separate game from overlay | Inconclusive. Rely on the census only. Do not act on display values |

"Stop at Stream D" means: no further pointer/keyboard-exclusivity code in Phase 2. Write the Stream D docs. Stream G may still proceed for chrome issues.

### Stream G — Button chrome parity (Phase 2)

Do not invent a Cancel button for zenity. Current spawn flags:

| Tool | Pause available | Buttons we pass |
|------|-----------------|-----------------|
| zenity `--warning` | yes | OK + `--extra-button="Pause N min"`. No Cancel label |
| zenity `--warning` | no | OK only. Window close is exit 1, not a Cancel button |
| yad | yes | Explicit `Pause N min` and `OK` only. That **replaces** yad's defaults |
| yad | no | No `--button` flags. Installed yad's man page: if no buttons are specified, **OK and Cancel** are used (Cancel exits 252, already treated as a normal dismiss) |
| kdialog | yes | `--warningyesno`: Yes = `Pause N min`, No = **Dismiss** (not the word Cancel). No width/height flags |
| kdialog | no | `--sorry` (OK). No width/height flags |

Gamescope forces `popup_position=center`, so the yad path is the `--center --fixed` branch. `--fixed` plus a short height can clip a button row; confirm with post-map geometry before raising height.

1. Stream E logs the tool, `pause_available`, and these flags. Desktop vs Gaming Mode can differ because the service PATH or `DIALOG_TOOL` picks a different tool (2026-10-19 session was zenity).
2. Pause missing because `can_pause_now` is false is expected. Document it; do not treat it as a gamescope bug.
3. A missing Cancel on zenity or a kdialog **Dismiss** label is tool chrome. Align docs with the table above. Do not add a zenity Cancel.
4. Raise the gamescope height floor only when read-back shows a button row clipped. Keep the cap at half root unless Stream F has already taken ownership of height for a confirmed hit-test miss. Do not also change height in Stream F for a different reason in the same patch.

## Tests and docs (Phase 2)

| Item | Action |
|------|--------|
| `tests/test-gamescope-overlay.sh` | Temp `HOME` only (already). Getter cases: unset+absent → false; env `true` beats config `false`; env `false`/`0`/`no` beats config `true`; quoted config `true`; unrecognized env falls through. Writer: key present → preserved; key absent → not added; env `true` with file `false` → file stays `false`. Partial-lock neutral arm: `false→true` and `true→false` both allowed. Display decode: mocked CARDINAL items for `":0"`/`":1"` decode correctly. Census: mocked `xwininfo`/`xprop` with (a) our dialog alone → `predicted_overlay_wid` = ours; (b) a wide Steam overlay with equal opacity listed below ours → predicted = Steam's; (c) the same Steam window with lower opacity → ours; (d) an unmapped wide overlay still counts. Flag off: no `DEBUG-GAMESCOPE` line and no census `xwininfo -children` call. Flag on: mock `log_to_file` sees the expected keys once per spawn. Keep width=root tests. No live `DISPLAY` or gamescope process |
| Tier | Tier-A unit mocks. On-device cycle is manual, with the flag on via the drop-in or `set-environment` |
| `STEAMOS_GAMING_MODE.md` | 2026-10-20 retest (full width, short height expected, Enter partial, cursor blocked); debug-flag how-to; pointer caveat until Stream F lands |
| `user-docs/` | Short Gaming Mode input caveat if Stream D is reached, or a one-line note that mouse may lag keyboard until then |
| `CHANGELOG.md` | Under `[Unreleased]` only when code ships. `### Added` for the debug flag (MINOR-worthy capability; do not tag unless asked). `### Fixed` only if pointer or exclusivity actually improves. No version bump in the plan pass |
| `docs/SAFETY.md` | No edit. Do not disable `GAMESCOPE_FORCE_AUTO_CLOSE` or the watchdog to debug |

## Manual verification checklist (on Deck)

- [x] Popup visible over fullscreen game (2026-10-19)
- [x] Popup stays up for min-display / until auto-close (2026-10-19)
- [x] After Phase 1: full width (2026-10-20)
- [x] After Phase 1: keyboard Enter can activate OK (2026-10-20) — **exclusivity unconfirmed**
- [ ] With `GAMESCOPE_OVERLAY_DEBUG=true`: capture one full popup cycle in `warnings.log` (mouse/keyboard focus displays, opacity, tool, buttons, geometry). `GAMESCOPE_FOCUSED_WINDOW` staying on the game is expected
- [ ] Mouse/trackpad cursor can enter dialog and click OK/Pause
- [ ] Enter/A does **not** also trigger Steam UI underneath
- [ ] Button set matches Desktop intent (OK + Pause when pause available); no unexpected clipping
- [ ] Touch on button works (if applicable)
- [ ] Countdown respawn still receives input
- [ ] Pause confirmation receives input
- [ ] Steam QAM usable again **after** auto-close / dismiss
- [ ] Watchdog / auto-close still ends popup if user cannot click
- [ ] Docked and undocked both checked

## Out of scope

- Steamworks native overlay plugin
- Weakening popup lifetime or daily caps
- Changing Desktop Mode window stacking
- Fixing unrelated log misclassification (`User closed popup manually` after SIGTERM 143) — track separately
- Removing `PartOf=graphical-session.target` / mode-switch `TransactionIsDestructive` — separate issue (2026-10-20)

## Implementation sketch (Phase 2)

1. Stream E only: getter, writer round-trip, neutral partial-lock arm, one `DEBUG-GAMESCOPE` block per spawn, tests. No behavior change.
2. On-device: one popup cycle with the flag on. Attach excerpts (decoded mouse/keyboard/focus displays, overlay census with `predicted_overlay_wid`, tool, buttons, geometry). Do not edit the live config file to turn the flag on.
3. Stream F from those logs: apply the decision table first. Height stays behind spike 4. Raise/lower is rejected on 3.16.23. No input grab.
4. Stream G only for a confirmed tool mismatch or a clipped button row. One owner for height if both F and G want it.
5. Docs + CHANGELOG. Stream D when the decision table says so.
6. Chunked implementation: each chunk gets a Grok review and a commit, then a final Opus review. The plan reviews (Grok 4.7, Opus 5.5) are done. Stream E is approved to start.

## Review checklist

- [x] Phase 1: full-width + atom logging (done)
- [x] Retest 2026-10-20 findings recorded (height expected; Enter partial; mouse fail; Cancel question)
- [x] Phase 2 plan: Grok 4.7 review (2026-10-20, approve-with-fixes applied)
- [x] Phase 2 plan: Claude Opus 5.5 review (2026-10-20, approve-with-fixes applied; plan approved for coding, Stream E first)
- [x] Stream E debug flag approved (name `GAMESCOPE_OVERLAY_DEBUG`; env wins over config with the gaming-mode boolean parser; writer preserves the key; not a wizard control; log-only) — Grok 4.7, 2026-10-20
- [x] Stream E code: getter, file-only writer round-trip, neutral partial-lock arm, one `DEBUG-GAMESCOPE` block per spawn/respawn/pause notice (not the 2s poll). Log-only; default off. On-device capture is still open.
- [x] No SAFETY.md invariant changes (16 h cap, finite popup lifetime, and escape hatch unchanged; debug flag does not alter them)
- [ ] Human go-ahead for Phase 2 coding after plan reviews

## References

- Code: `lib/window-management.sh`, `lib/popup-display.sh`, `lib/popup-dialog-implementations.sh`, `lib/popup-display-linux.sh`
- Gamescope tag: **3.16.23** / device **3.16.23.6** — `nWidth > 1200` overlay vs notification; per-window `calc_scale_factor` fit scaling
- Parent overlay plan: [plan-steamos-gaming-mode-overlay-2026-10-16.md](plan-steamos-gaming-mode-overlay-2026-10-16.md)
- TO_DO: [TO_DO.md](../TO_DO.md)
- Prior Opus CLI reviews (archived): [initial](../code-assessments/gamescope-clickthrough-plan-review-opus-2026-10-19.md) · [docked follow-up](../code-assessments/gamescope-clickthrough-plan-review-opus-docked-followup-2026-10-19.md) · [final approve](../code-assessments/gamescope-clickthrough-plan-review-opus-final-approve-2026-10-19.md)
- Phase 2 plan reviews: [Grok 4.7, 2026-10-20](../code-assessments/gamescope-clickthrough-phase2-plan-review-grok-2026-10-20.md) · [Claude Opus 5.5, 2026-10-20](../code-assessments/gamescope-clickthrough-phase2-plan-review-opus-2026-10-20.md)
