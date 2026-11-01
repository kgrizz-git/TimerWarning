# Steam Deck in-game overlay investigation

**Status: closed 2026-10-31. The failure did not reproduce.** The summary is in
[STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md#on-device-2026-10-31-visibility-over-fullscreen-games).
This file keeps the hypotheses, the raw findings, and the agent prompt so the
check can be repeated for the cases still unchecked (handheld, Proton, Steam
overlay or Quick Access Menu open at spawn, pressing Pause over a game).

## Problem

In Gaming Mode with the experimental overlay on, the warning appears over the
Gaming Mode home screen. Over a fullscreen game it mostly does not appear, or
never does. Before this investigation, the one debug capture (2026-10-20) was a
case that worked. That capture showed our dialog as `predicted_overlay_wid` and
every focus display as `:0`, so a capture from a failing case was needed.

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

## Findings (2026-10-31)

The failure did not reproduce. H1–H4 are all refuted for the scenes below.

**Setup:** commit `0e3431c`, SteamOS 3.8.28 (build 20260922.1), gamescope 3.16.23.6. The Deck was docked to an external 2560x1440 display. The game was Tyranny, a native Linux title (Steam Linux Runtime soldier, not Proton). Steam ran on `DISPLAY=:0` and the game on `:1`. Each run used the production `sleep-warning.sh` from the checkout with a temporary HOME, `GAMESCOPE_OVERLAY_DEBUG=true`, a `POPUP_ABSOLUTE_MAX_SECONDS` cap, and `timeout --kill-after=2s`. A human watched each run.

| Run | Tool | Settings | Visible | predicted_overlay_wid | Focus displays (mouse/kbd/focus) |
|-----|------|----------|---------|-----------------------|----------------------------------|
| Home screen | yad | medium, min 0 | yes | ours | :0 / :0 / :0 |
| Game paused | yad | medium, min 0 | yes; game input returned | ours | :0 / :0 / :1 |
| Active play | yad | medium, min 0 | yes | ours | :0 / :0 / :1 |
| Active play | zenity | medium, min 0 | yes | ours | :0 / :0 / :1 |
| Active play | yad | installed settings: large, min 90 s, pause on, 4 respawns | yes, through every respawn | ours, every block | :0 / :0 / :1 |
| Active play | zenity | installed settings and the service PATH, 4 respawns | yes, through every respawn | ours, every block | :0 / :0 / :1 |

- **H1** refuted. In every block ours was the only `STEAM_OVERLAY` window in the census. The full-screen `mangoapp overlay window` on `:0` has no `STEAM_OVERLAY` and did not compete.
- **H2** refuted as a cause. The game is on `:1` and the focus display stays `:1`, yet the dialog shows.
- **H3** refuted. Every spawn and respawn logged `readback overlay=1 focus=1`.
- **H4** refuted. Every run logged `Display environment: gamescope`. The installed timer's own log for 2026-10-29 and 2026-10-31 shows the same on all 43 popups.

Other observations:

- **Tool choice follows PATH.** yad on this Deck comes from Nix (`~/.nix-profile/bin/yad`). The user manager's PATH is `/usr/local/bin:/usr/bin`, so the scheduled service picks zenity (dark theme) and an SSH shell picks yad (light theme).
- **Focus.** Keyboard and mouse focus move to `:0` while the dialog is up and return to `:1` after it closes. In the last zenity run the observer pressed OK over the running game, and the dialog exited 0 (an auto-close logs 143). The input method was not recorded.
- **Service drop-in.** The installed drop-in was `mode-desktop.conf` (only `DISPLAY=:0`) while in Gaming Mode. Routing still worked, because the user manager supplies `XDG_CURRENT_DESKTOP=gamescope`.
- **Likely explanation for the original report.** A separate personal timer on this Deck quit Steam every 10 minutes, starting 15 minutes before the warning windows opened. In the timer logs, the first warning of a window appeared about five seconds after one of those Steam quits. So no game was running when the warnings fired. That timer now starts at the same times as the warning windows.
- **SSH preflight.** It needs `XDG_CURRENT_DESKTOP=gamescope DISPLAY=:0`; without them it reports routing `wayland` (a false blocker).

Still unchecked: handheld (undocked), a Proton title, the Steam overlay or Quick Access Menu open at spawn time, and pressing Pause over a game.

## Prompt for the agent on the Deck

```text
Investigate why the sleep-warning popup is not visible above fullscreen games in
SteamOS Gaming Mode. Read
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
   'GAMESCOPE|STEAM' (property names and values only). Keep these captures
   local. In the report, list only our window and windows that carry
   STEAM_OVERLAY or cover the full root, with WID, geometry, opacity and
   WM_CLASS. Write [redacted] for every window name, ours included (ours is
   the dialog title); identify our window by WID.
5. Copy each run's DEBUG-GAMESCOPE block and the surrounding gamescope log lines
   from the temporary HOME's warnings.log. Strip the dialog title/body, and
   redact window names the same way as in step 4.
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
