# Steam Deck in-game overlay investigation (temporary)

Temporary branch: `investigate/gamescope-ingame-overlay`. Delete this file and
the branch once the findings are folded into
[STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md).

## Problem

In Gaming Mode with the experimental overlay on, the warning appears over the
Gaming Mode home screen. Over a fullscreen game it mostly does not appear, or
never does. The one debug capture so far (2026-10-20) was a case that worked.
That capture showed our dialog as `predicted_overlay_wid` and every focus display
as `:0`. We need a capture from a failing case.

## Hypotheses the capture separates

| ID | Hypothesis | Evidence in the `DEBUG-GAMESCOPE` block |
|----|------------|------------------------------------------|
| H1 | A Steam overlay window wins gamescope's single overlay slot | `predicted_overlay_wid` is not ours. Another wide `STEAM_OVERLAY` child has opacity at least ours |
| H2 | The game is on another Xwayland display | Decoded focus display is `:1` (or not `:0`). Mouse or keyboard display follows the game |
| H3 | Atoms are never applied, or arrive too late | Log has `Could not find X11 window ID for gamescope overlay`, or there is no `Applied gamescope STEAM_OVERLAY` line |
| H4 | Routing never chose gamescope | No `DEBUG-GAMESCOPE` block at all. Display detection logged a non-gamescope type |

Fix direction if H1 holds: make our dialog the focused app for its lifetime
(`STEAM_GAME` on our window plus `GAMESCOPECTRL_BASELAYER_APPID` on the `:0`
root, restored on close). Do not try raise/lower; see the archived click-through
plan for why that cannot win the tie.

## Prompt for the agent on the Deck

```text
Investigate why the sleep-warning popup is not visible above fullscreen games in
SteamOS Gaming Mode. Work on branch investigate/gamescope-ingame-overlay. Read
AGENTS.md, docs/SAFETY.md, dev-docs/STEAMOS_GAMING_MODE.md and
dev-docs/development/steam-deck-ingame-overlay-investigation.md first. Follow the
isolation and bounding rules in dev-docs/development/steam-deck-first-check.md.

Scope: read-only toward the repo and installed system. Do not edit repo files,
install packages, use sudo, commit, push, edit the installed sleep-warning.conf,
run configure menus, or enable/disable/restart services. The only state you may
create is under a temporary HOME you delete at the end.

1. Record commit, SteamOS version, gamescope version, and confirm the session is
   real Gaming Mode. Run bash scripts/check-steam-deck-gaming-mode.sh and record
   its output and exit code.
2. Record gamescope's Xwayland displays (ls /tmp/.X11-unix) and which display
   Steam and the running game use (read DISPLAY from /proc/<pid>/environ for
   those PIDs only; print only DISPLAY). Note whether the game is Proton or
   native.
3. Build an isolated foreground run of the production sleep-warning.sh exactly
   as step 4 of steam-deck-first-check.md describes (temporary HOME, preserved
   XAUTHORITY, restriction window covering now, each day <=16 h,
   GAMING_MODE_EXPERIMENTAL_ENABLED=true, POPUP_MIN_DISPLAY_TIME=0,
   POPUP_AUTO_CLOSE=true). Add GAMESCOPE_OVERLAY_DEBUG=true to the temporary
   config and environment. Set POPUP_ABSOLUTE_MAX_SECONDS=20 in the environment.
   Bound the process group with timeout --kill-after=2s 40s and bound output.
   Verify key names in lib/config-keys.sh before writing the fixture.
4. Run it in three scenes, with a human observer confirming visibility each time:
   a. Gaming Mode home screen (control case; expected visible).
   b. A fullscreen game that is paused at a safe point.
   c. The same game during active play, or a second game (prefer one Proton
      and one native title if available).
   For each scene, while the dialog is alive, also capture from DISPLAY=:0:
   xwininfo -root -children (first 80 lines), and xprop -root | grep -E
   'GAMESCOPE|STEAM' (property names and values only).
5. Copy each run's DEBUG-GAMESCOPE block and the surrounding gamescope log lines
   from the temporary HOME's warnings.log. Strip the dialog title/body if present.
6. For each scene, mark H1-H4 from the investigation doc as SUPPORTED,
   REFUTED or UNCLEAR, citing the log line. Do not propose code changes beyond
   naming the hypothesis and the evidence.
7. Clean up: kill only the children you started, delete the temporary HOME,
   and confirm no sleep-warning or zenity/yad process from your runs remains.

Return: a table per scene (visible yes/no from the observer, tool, our WID,
predicted_overlay_wid, focus displays, competing overlay windows with opacity
and WM_CLASS, H1-H4 verdicts), then the raw DEBUG-GAMESCOPE blocks, then the
commands with exit codes and durations. Keep the report under 400 lines.
```
