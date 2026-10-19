# Plan: Gamescope Overlay Click-Through (Buttons Not Clickable)

**Status: IMPLEMENTED (code) — awaiting on-device Deck retest** — Streams A+B landed 2026-10-19 (Grok-reviewed chunks). Manual checklist below still open.

| | |
|---|---|
| **Created** | 2026-10-19 |
| **Related** | [plan-steamos-gaming-mode-overlay-2026-10-16.md](plan-steamos-gaming-mode-overlay-2026-10-16.md), [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md) |
| **Claude Opus CLI review** | Initial needs-rework → docked approve-with-fixes (applied) → **final approve** of this file (STATUS_CHANGE: remove NEEDS REVIEW) |
| **On-device evidence** | 2026-10-19: popup **visible / stayed up**; **buttons not clickable**. Magnification reported while **docked** to a large monitor (same session family — confirm undocked separately) |
| **Device context** | `gamescope` **3.16.23.6**; dialog tool from log: **zenity**, `Size: small`; atoms logged as applied |
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
| Set `STEAM_OVERLAY=1` + `STEAM_INPUT_FOCUS=1` | `lib/window-management.sh` → `apply_gamescope_overlay_atoms` | Appears successful in log |
| Window lookup | `find_window_id_for_popup` | Prefers `_NET_CLIENT_LIST` (empty in gamescope) → falls back to **xdotool title** (decimal WID) → `xwininfo` |
| Background arm | `lib/popup-display-linux.sh` → `_popup_linux_arm_gamescope_atoms` | **2s refresh loop runs only when `window_tool` is empty.** On Deck with xdotool, atoms apply **once per spawn**, not every 2s |
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

## Phased implementation

| Phase | What | Go / no-go |
|-------|------|------------|
| **0 — Confirm** | On-device `xwininfo`/`xprop` while small popup is up (H1: width ≤ 1200, atoms = 1); note docked vs undocked; optional undocked “does small already fill the panel?” | Proceed if H1 holds (or document surprise) |
| **1 — Fix** | Stream B (full `:0` root width + modest height, gamescope-only) + Stream A logging; quote global input-pick code from installed gamescope at implement time | Unit tests green; log shows width = root |
| **2 — Retest** | Full [manual checklist](#manual-verification-checklist-on-deck) on Deck (zenity ± yad) | Clicks work; ~1:1 sharpness nested; docked no worse than Steam UI |
| **3 — Fallback** | If still click-through → H2 opacity check; if still fail → Stream D docs (display + auto-close only) | Product decision documented |

Stream C (`GAMESCOPE_EXTERNAL_OVERLAY`) stays **rejected** on 3.16.23.

## Proposed workstreams

### Stream B — Force interactive geometry (**primary fix path** — also fixes magnification)

Gamescope-only: spawn the warning (and pause confirmation) at **full `:0` root/canvas width** with **modest height**.

1. Gate on `env_type=gamescope` only; Desktop Mode sizes unchanged.
2. **Width = root width on `:0`** (must be &gt; 1200; Deck 1280 is fine). Height modest (≤ ~½ root height). Never TV-native pixels; never a partial width like 1201 on a wider canvas.
3. Keep `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` (value **1**, not 2).
4. Optionally set `_NET_WM_WINDOW_OPACITY=0xffffffff` to reduce H2 ties.
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

### Stream D — Document non-clickable fallback (if B fails on-device)

If a >1200-wide overlay still cannot receive clicks on this SteamOS build:

1. Document in `STEAMOS_GAMING_MODE.md` / user docs: Gaming Mode may be display + auto-close only.
2. Keep escape hatch (`systemctl --user stop/disable`) and forced auto-close.
3. Steamworks plugin remains separate future work.

## Tests and docs (when implementing)

| Item | Action |
|------|--------|
| `tests/test-gamescope-overlay.sh` | Mock/assert gamescope spawn path requests **width = mocked root width** (not merely &gt; 1200); keep atom regression tests |
| Tier | Tier-A for unit mocks; on-device checklist manual |
| `STEAMOS_GAMING_MODE.md` | Record click-through + 3.16.23 `> 1200` rule; update when fixed |
| `user-docs/` | Gaming Mode caveat if buttons remain unreliable |
| `CHANGELOG.md` | `### Fixed` if input works after wide overlay |
| `docs/SAFETY.md` | No edit |

## Manual verification checklist (on Deck)

- [x] Popup visible over fullscreen game (2026-10-19)
- [x] Popup stays up for min-display / until auto-close (2026-10-19)
- [ ] Before fix: `xwininfo` width **≤ 1200**; note **docked vs undocked**
- [ ] After fix: `xwininfo` width **equals `:0` root width** (and &gt; 1200)
- [ ] `xprop` shows `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` on dialog WID
- [ ] Touch on button dismisses / pauses (accuracy under finger after overlay is input target)
- [ ] Trackpad click on button works
- [ ] Controller focus + A activates button (optional)
- [ ] Countdown respawn still receives input
- [ ] Pause confirmation receives input
- [ ] Steam QAM usable again **after** auto-close / dismiss
- [ ] Watchdog / auto-close still ends popup if user cannot click
- [ ] **Undocked:** after fix, dialog appears ~1:1 (not magnified vs current small)
- [ ] **Undocked (pre-fix check):** does current small dialog already fill most of the panel?
- [ ] **Docked:** after fix, dialog no softer than Steam UI / game (canvas→TV only)

## Out of scope

- Steamworks native overlay plugin
- Weakening popup lifetime or daily caps
- Changing Desktop Mode window stacking
- Fixing unrelated log misclassification (`User closed popup manually` after SIGTERM 143) — track separately in TO_DO if desired, not this plan

## Implementation sketch

Follow [Phased implementation](#phased-implementation): Phase 0 confirm → Phase 1 Streams B+A → Phase 2 checklist → Phase 3 only if needed → update TO_DO / STEAMOS_GAMING_MODE / CHANGELOG.

## Review checklist

- [x] Primary hypothesis: **width ≤ 1200 → notification → click-through** on gamescope 3.16.23 (Opus CLI)
- [x] `STEAM_INPUT_FOCUS=1` (not `2`) for modal dialogs
- [x] Stream B (full canvas width, modest height) is the first code fix; Stream C rejected
- [x] Magnification is **per-window fit scaling** on 3.16.23; full-width dialog fixes click + sharpness together (Opus follow-up)
- [x] Stream D allowed if compositor still blocks input
- [x] No SAFETY.md invariant changes
- [x] **Claude Opus CLI approved** current plan text (2026-10-19) — NEEDS REVIEW removed
- [x] **Human go-ahead / coding** — Streams A+B implemented 2026-10-19 (Grok-reviewed chunks)
- [ ] **On-device Deck retest** (clicks + sharpness, docked and undocked)

## References

- Code: `lib/window-management.sh`, `lib/popup-display-linux.sh`
- Gamescope tag: **3.16.23** / device **3.16.23.6** — `nWidth > 1200` overlay vs notification; per-window `calc_scale_factor` fit scaling
- Parent overlay plan: [plan-steamos-gaming-mode-overlay-2026-10-16.md](plan-steamos-gaming-mode-overlay-2026-10-16.md)
- TO_DO: [TO_DO.md](../TO_DO.md)
- Opus CLI reviews (archived): [initial](../code-assessments/gamescope-clickthrough-plan-review-opus-2026-10-19.md) · [docked follow-up](../code-assessments/gamescope-clickthrough-plan-review-opus-docked-followup-2026-10-19.md) · [final approve](../code-assessments/gamescope-clickthrough-plan-review-opus-final-approve-2026-10-19.md)
