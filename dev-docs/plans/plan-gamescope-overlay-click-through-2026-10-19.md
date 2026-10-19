# Plan: Gamescope Overlay Click-Through (Buttons Not Clickable)

**Status: NEEDS REVIEW — do not implement until reviewed and approved.**

| | |
|---|---|
| **Created** | 2026-10-19 |
| **Related** | [plan-steamos-gaming-mode-overlay-2026-10-16.md](plan-steamos-gaming-mode-overlay-2026-10-16.md), [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md) |
| **Claude Opus CLI review** | 2026-10-19 — **needs-rework** applied below; human approval still required before implementation |
| **On-device evidence** | 2026-10-19 Steam Deck Gaming Mode: popup **visible and stayed up**; **buttons not clickable** — clicks/taps hit the game underneath |
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
# While popup is up (DISPLAY for gamescope Xwayland, usually :0):
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

## Proposed workstreams

### Stream B — Force interactive geometry (**primary fix path**)

Gamescope-only: spawn the warning (and pause confirmation) with width **> 1200**, preferably **`max(root_width, 1201)`** from `xwininfo -root` (or existing resolution helpers).

1. Gate on `env_type=gamescope` only; Desktop Mode sizes unchanged.
2. Prefer fullscreen or near-fullscreen width; height may stay modest (3.16.23 centers/scales overlays).
3. Keep `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` (value **1**, not 2).
4. Optionally set `_NET_WM_WINDOW_OPACITY=0xffffffff` to reduce H2 ties.
5. Keep `GAMESCOPE_FORCE_AUTO_CLOSE` + absolute watchdog.
6. **Safety note:** once we hold input, the game (and possibly Steam QAM) will not receive input for the popup lifetime — intentional modal behavior; still bounded by auto-close/watchdog. No `docs/SAFETY.md` invariant change.

### Stream A — Diagnostics / lookup hardening (**supporting**)

1. Log: resolved WID, lookup path (`_NET_CLIENT_LIST` / xdotool / xwininfo), geometry (width×height), atom set + read-back.
2. Prefer `xdotool search --pid` / `xwininfo -root -children` when `_NET_CLIENT_LIST` is empty — do **not** require xdotool for the atom path to work if `xwininfo` can find the title; keep xprop-only workable.
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
| `tests/test-gamescope-overlay.sh` | Mock/assert gamescope spawn path requests width > 1200 or root width; keep atom regression tests |
| Tier | Tier-A for unit mocks; on-device checklist manual |
| `STEAMOS_GAMING_MODE.md` | Record click-through + 3.16.23 `> 1200` rule; update when fixed |
| `user-docs/` | Gaming Mode caveat if buttons remain unreliable |
| `CHANGELOG.md` | `### Fixed` if input works after wide overlay |
| `docs/SAFETY.md` | No edit |

## Manual verification checklist (on Deck)

- [x] Popup visible over fullscreen game (2026-10-19)
- [x] Popup stays up for min-display / until auto-close (2026-10-19)
- [ ] `xwininfo` width **> 1200** after fix (or confirm ≤ 1200 before fix)
- [ ] `xprop` shows `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` on dialog WID
- [ ] Touch on button dismisses / pauses (finger under button — scaling)
- [ ] Trackpad click on button works
- [ ] Controller focus + A activates button (optional)
- [ ] Countdown respawn still receives input
- [ ] Pause confirmation receives input
- [ ] Steam QAM usable again **after** auto-close / dismiss
- [ ] Watchdog / auto-close still ends popup if user cannot click

## Out of scope

- Steamworks native overlay plugin
- Weakening popup lifetime or daily caps
- Changing Desktop Mode window stacking
- Fixing unrelated log misclassification (`User closed popup manually` after SIGTERM 143) — track separately in TO_DO if desired, not this plan

## Implementation sketch (post-approval)

1. Optional: one more on-device `xwininfo`/`xprop` dump while small popup is up (confirm H1).
2. Implement Stream B (gamescope-only width > 1200 / root width) + Stream A logging.
3. Retest checklist on Deck (zenity + yad if available).
4. If still click-through → check H2 opacity / Stream D docs.
5. Update TO_DO / STEAMOS_GAMING_MODE / CHANGELOG.

## Review checklist

- [x] Primary hypothesis: **width ≤ 1200 → notification → click-through** on gamescope 3.16.23 (Opus CLI)
- [x] `STEAM_INPUT_FOCUS=1` (not `2`) for modal dialogs
- [x] Stream B (wide/fullscreen gamescope-only) is the first code fix; Stream C rejected
- [x] Stream D allowed if compositor still blocks input
- [x] No SAFETY.md invariant changes
- [ ] **Human approve** before code changes (status stays NEEDS REVIEW)

## References

- Code: `lib/window-management.sh`, `lib/popup-display-linux.sh`
- Gamescope tag: **3.16.23** / device **3.16.23.6** — `nWidth > 1200` overlay vs notification
- Parent overlay plan: [plan-steamos-gaming-mode-overlay-2026-10-16.md](plan-steamos-gaming-mode-overlay-2026-10-16.md)
- TO_DO: [TO_DO.md](../TO_DO.md)
- Opus CLI review (archived): [gamescope-clickthrough-plan-review-opus-2026-10-19.md](../code-assessments/gamescope-clickthrough-plan-review-opus-2026-10-19.md)
