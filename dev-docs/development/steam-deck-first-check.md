# Steam Deck Gaming Mode first check

Run from a checkout **on the Deck**, in Gaming Mode:

```bash
bash scripts/check-steam-deck-gaming-mode.sh
```

This read-only preflight uses the production config reader and display detection.
It checks overlay opt-in, routing, X11 connectivity and tool availability, and
prints the installed timer's status. It has a 25-second deadline and bounded
output. It does not launch a popup, change settings, or enable/disable services.
It can run before installation; an absent timer is informational.

SSH is useful while a game is running, but a fresh SSH shell may lack the gaming
session's display credentials. A blocked result there is not proof the overlay is
broken. Supply only the known session display variables/credentials; do not dump
the session environment or guess authorization cookies. Desktop Mode passing
does not establish Gaming Mode compatibility. The existing
`tests/test-gamescope-overlay.sh` covers routing/atoms with mocks, not hardware.

## Prompt for an agent running on the Deck

Copy the following prompt into an agent with access to the Deck checkout:

```text
Test Steam Deck Gaming Mode functionality in this repository. Read AGENTS.md,
docs/SAFETY.md and dev-docs/STEAMOS_GAMING_MODE.md first. Review only: do not edit
repository files, install packages, use sudo/remount, commit, push, change the
installed config, or enable/disable/restart services. Do not run configure menus.
Do not run tests/test-mode-detection.sh with the real HOME.

1. Record the checkout commit/dirty status, SteamOS version, gamescope version
   if available, and whether this is actual Gaming Mode. Do not dump secrets,
   complete environment/config files, or unrelated game/user data.
2. Run bash scripts/check-steam-deck-gaming-mode.sh. Record its output and exit
   status. Explain blockers without silently changing settings. A passing
   preflight is not a passing hardware test. SSH environment failures should be
   distinguished from failures in the actual gaming session.
3. Run the existing headless tests/test-gamescope-overlay.sh under a temporary
   HOME, a 120-second timeout and bounded output. Record what is mocked.
4. If GUI access and a human observer are available, prepare a supervised live
   smoke using the production sleep-warning.sh entrypoint, NOT a hand-written
   lookalike dialog. First inspect its dependencies and cleanup behavior. Run
   only with a temporary HOME/config/state, keeping the gaming session's display
   credentials (preserve the original XAUTHORITY path before changing HOME).
   Use temporary restriction hours containing the current time, each day's
   coverage <=16 hours, experimental overlay=true, POPUP_MIN_DISPLAY_TIME=0,
   POPUP_AUTO_CLOSE=true. Set POPUP_ABSOLUTE_MAX_SECONDS=15 in this invocation's
   environment (it is not a config-file key). Verify the actual config key names
   in lib/config.sh before writing the temporary fixture.
   Do not copy or modify the installed config. Leave session runtime sockets
   available. Bound the whole foreground test process group with GNU timeout
   --kill-after=2s 30s; bound output too. Track only this invocation's children
   and temporary files; clean them on exit/signals. No broad pkill/killall.
   Never start a second modal while an installed popup is already active.
   If a safe isolated invocation cannot be established, mark this step BLOCKED.
5. Exercise once in the Gaming Mode home screen, then once above a running
   fullscreen game at a safe pause point with no unsaved progress. Ask the
   observer to confirm visibility, touch/controller input, dismissal, return
   of game input/focus and disappearance by the deadline. Read back this test
   window's STEAM_OVERLAY and STEAM_INPUT_FOCUS properties using xprop while it
   is alive. If possible, repeat for each installed supported dialog tool using
   temporary config only. Record observed timings and tool names. Do not infer
   controller success from atoms alone. Stop immediately on a lingering modal.
6. Inspect the installed systemd unit/drop-in's selected display variables
   read-only, without dumping unrelated environment values. Compare with the
   test session. A foreground test alone does not validate scheduled execution.
   Report scheduled delivery and actual stop/disable as UNTESTED unless they
   were separately authorized and directly observed. Print the documented
   escape hatch but do not execute service changes under this review scope:
   systemctl --user stop sleep-warning.timer && systemctl --user disable sleep-warning.timer

Return a compact table: check, PASS/FAIL/BLOCKED/UNTESTED, evidence. Include
commands, exit codes, durations, config isolation/cleanup, hardware/session
details and any bug's file/line. Separate headless, foreground visual and
scheduled-service evidence. Do not claim full compatibility from preflight.
```

The live smoke checks the real popup path without waiting for a timer tick. It
does not establish reliable delivery after mode switches, suspend/resume, reboot,
or under load. Those remain follow-up hardware tests, along with a separately
authorized test of the installed service and escape hatch.
