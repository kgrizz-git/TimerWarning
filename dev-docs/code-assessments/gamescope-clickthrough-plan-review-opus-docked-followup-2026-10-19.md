# Follow-up review: `plan-gamescope-overlay-click-through-2026-10-19.md`

## 1. Overall: **approve-with-fixes** (status stays NEEDS REVIEW)

The click-through part of the plan is now right: the 1200-px classification rule, the reordered hypotheses, Stream C rejected, and the lookup notes. But the new docking section explains the magnification wrongly, and the Stream B tradeoff built on it points the wrong way. The plan currently says that widening the dialog to over 1200 px would make the docked magnification worse. In gamescope 3.16.23, widening the dialog to the full canvas width should make the magnification go away.

**What I checked:** a fetch agent read all of `steamcompmgr.cpp` at tag `3.16.23` and quoted the code verbatim. A few values are defined in other files and weren't read; I mark those as unverified below.

## 4. Is the nested→TV upscale explanation correct? **Mostly no.**

**What the code actually does.** gamescope scales every overlay and notification from its own size so that it fits the whole screen:
- In `paint_all`, a notification is drawn with `paint_window(notification, notification, …, NotificationMode | NoFilter)`. The window is scaled against its own size, not the game's.
- In `paint_window_commit`, when the window is scaled against itself, the source size is its own buffer size. The scale comes from `calc_scale_factor`:
  ```c
  XRatio = g_nNestedWidth / sourceWidth;  YRatio = g_nNestedHeight / sourceHeight;
  out = min(XRatio, YRatio);                       // fit
  if (AUTO) out = min(g_flMaxWindowScale, out);    // clamp — value defined outside this file
  out *= min(outputW/nestedW, outputH/nestedH);
  ```
  The result is centered, and there is no corner placement for notifications.
- **Worked example:** a 400×250 dialog on a 1280×800 canvas gets scaled about 3.2×. On a 1920×1080 canvas it's about 4.3×. In both cases it fills most of the screen.

**What that means for the plan's explanation:**
- **This isn't a docking effect.** Undocked on the Deck's own panel, the small dialog should also be blown up to roughly full screen. The only exception is if `g_flMaxWindowScale` is clamped low, and that value wasn't read. The TV just makes the softness easier to see.
- **The filter claim is wrong.** Notifications and overlays always get the `NoFilter` flag, which means smooth (linear) scaling. They never get the nearest or integer filter. The blocky text comes from stretching a roughly 400 px buffer 3–4× or more.
- **The root/canvas detail is incomplete.** The scale is measured against gamescope's nested canvas (`g_nNestedWidth/Height`), not the Xwayland root size. They are probably equal on a single-Xwayland Deck (only `X0` exists), but that isn't proven.
- Two root properties, `STEAM_SCREEN_SCALE` and `STEAM_SCREEN_MAGNIFICATION`, add further magnification. That's minor, but worth recording.

**What it means for Stream B:**
- A dialog as wide as the canvas with a modest height gets a scale of exactly 1. For example, 1280×350 on a 1280×800 canvas gives `min(1280/1280, 800/350)` = 1.0. It's drawn 1:1 and sharp, and it also clears the `> 1200` rule.
- So the click fix and the sharpness fix are the same change. The "design tension" in the plan doesn't exist.
- The only leftover blur is the canvas-to-TV ratio, which applies to the game and Steam's UI equally.
- The plan's `max(1201, min(root_w, …))` is risky. Any width between 1201 and the canvas width still gets magnified. On a 1920-wide canvas, a 1201-wide dialog is scaled about 1.6×.
- **Rule:** width = canvas width (read from the root on `:0`, or `max(1201, root_w)` if the root is narrower than 1201). Keep the height modest. Never use the TV's native resolution.

## 2. Remaining issues

### Critical
1. **The docking section's cause is wrong.** It blames upscaling of the whole nested output plus integer/nearest filtering. The real cause is per-window fit-to-screen scaling with smooth filtering, and it happens undocked too. The plan's next steps follow from this, so it needs rewriting.
2. **The "design tension" section has the direction backwards.** It says a dialog over 1200 px wide makes docked magnification worse. A dialog as wide as the canvas makes it better: the scale drops from about 3–4× to 1.0.

### Important
3. **The Stream B width formula** still allows widths between 1201 and the canvas width, which are still magnified. Replace it with "width = canvas/root width on `:0`; height modest (≤ about half the root height); never less than 1201".
4. **The plan doesn't record whether each symptom was docked or undocked.** The click-through report and the magnification report may come from different sessions ("same session family"). Note which was which, and add an undocked check: "was the small dialog also screen-filling?" That confirms the per-window scaling explanation cheaply.
5. **Unverified values.** `g_flMaxWindowScale` (the auto-mode clamp) and how `g_nNestedWidth` is set are defined outside `steamcompmgr.cpp`, and the scaling mode varies. When the focused window is Steam itself, scaling is forced to fit with no clamp. Capture the gamescope command line from Gaming Mode (`tr '\0' ' ' </proc/$(pgrep -x gamescope)/cmdline`) to look for `--max-scale`, `-w`/`-h`, or scaler flags. Also record the `GAMESCOPE_SCALING_FILTER` root property.
6. **Confirm zenity honors the requested size.** zenity 4 is GTK4 and may enforce its own minimum size or ignore `--height`. The scale is computed from the real buffer size, so the read-back log (Stream A) must include the actual `xwininfo` width×height. The test should check the requested width, and the on-device step should check the actual one.

### Minor
7. The tests table should assert width = mocked root width, not just "> 1200".
8. The touch-accuracy check should explicitly cover the scaled case. Touch mapping is only updated when the overlay is the input target, so it should work after the fix, but it's untested.
9. Optional: if `GDK_SCALE`/HiDPI is ever set in Gaming Mode, the buffer size and the window size can differ. Note that it should be left unset in gamescope.
10. The archived Opus review file is present, and the references look fine.

## 3. Concrete plan edits

- **"Docked / large-monitor magnification" → "Why the dialog is magnified":**
  - Replace steps 1–3 with: per-window fit scaling (the verbatim `calc_scale_factor` excerpt above), smooth filtering via `NoFilter`, centered placement.
  - State that it applies undocked too, unless `g_flMaxWindowScale` clamps it.
  - Keep the `xwininfo -root` / `-id` confirmation commands, and add the gamescope command-line capture and `xprop -root GAMESCOPE_SCALING_FILTER STEAM_SCREEN_SCALE STEAM_SCREEN_MAGNIFICATION`.
- **Delete "Design tension with Stream B"** and replace it with "Stream B also fixes magnification": the canvas-width example (scale 1.0), plus the note that the remaining canvas-to-TV blur is shared with the game and Steam UI.
- **Stream B steps 1–2 and 6:** width = `:0` root width (at least 1201); height modest; drop "accept large/blocky when docked" as the expected outcome. Keep it only as a fallback note if the read-back shows the scale isn't about 1.
- **"Is clickable UI possible?":** keep. Optionally add the `paint_all` notification call as a second verbatim excerpt.
- **Evidence table:** add docked/undocked per symptom; add "undocked size observation: TBD".
- **Manual checklist:** add "dialog appears 1:1 (not magnified) undocked after fix" and "docked: dialog is no softer than the Steam UI".
- **Tests table:** width = mocked root width.
- **Review checklist:** add "agree magnification is per-window fit scaling (3.16.23), fixed by the full-width dialog".

## 5. Status

Keep **NEEDS REVIEW**. I didn't edit any files. Once the docking section is corrected and someone has looked at a small popup undocked, the plan is ready for a human decision on implementation.
