# Review: Phase 2 of `plan-gamescope-overlay-click-through-2026-10-19.md`

**Reviewer:** Grok 4.7  
**Date:** 2026-10-20  
**Verdict:** **approve-with-fixes** (fixes applied in the plan; no production code)

## What was checked

- The Phase 2 plan, especially the 2026-10-20 retest, Streams E–G, tests/docs, the implementation sketch, and the review checklist.
- `docs/SAFETY.md` invariants (16 h cap, finite popup lifetime, escape hatch) and `GAMESCOPE_FORCE_AUTO_CLOSE` / `POPUP_ABSOLUTE_MAX_SECONDS`.
- Current Phase 1 code: `lib/window-management.sh`, `lib/popup-display.sh`, `lib/popup-dialog-implementations.sh`, `lib/popup-display-linux.sh`, `lib/config.sh`, `lib/config-keys.sh`, `lib/configure-config-write.sh`, `lib/configure-partial-lock.sh`, `sleep-warning.service` (`Type=oneshot`).
- gamescope tag **3.16.23** `src/steamcompmgr.cpp` (focus walk, global input pick, focus-display properties).
- Installed yad man page (`--button` omitted → OK and Cancel).
- No hardcoded credentials. The debug flag is a boolean. The plan forbids logging the warning body. Nothing in this path is a secret, so the credential rule did not change the design; it only ruled out treating the flag or log lines as a place to put one.

User findings kept as stated: full width with short height is expected; Enter can activate OK and may also hit Steam underneath; the cursor cannot enter the popup; do not invent a zenity Cancel; debug stays behind `GAMESCOPE_OVERLAY_DEBUG`, env over config, default off.

## Issues found

1. **Pointer spike aimed at height and cursor warps.** On 3.16.23, height is not part of overlay classification. The per-Xwayland walk `XSetInputFocus`es the last `isOverlay && inputFocusMode` window (width not required). Global cursor and Wayland mouse focus follow `overlayWindow` only when that width/opacity winner has `inputFocusMode`; otherwise they stay on the game. That split matches Enter-on-dialog plus a cursor that never enters the popup. A taller banner does not change the winner.
2. **`GAMESCOPE_FOCUSED_WINDOW` is the wrong probe.** On this tag it is `focusWindow` (the game). Comparing it to the dialog WID looks like failure even when the overlay has input. Mouse and keyboard displays are `GAMESCOPE_MOUSE_FOCUS_DISPLAY` and `GAMESCOPE_KEYBOARD_FOCUS_DISPLAY` (display-name strings stored as CARDINAL, not WIDs).
3. **Debug flag was under-specified.** Env-vs-config did not say that explicit `false`/`0`/`no` wins, or that unrecognized values fall through, which is how `get_gaming_mode_experimental_enabled` already works. The config writer rewrites the whole file and drops unknown keys, so a hand-added key disappears on the next configure save unless the writer round-trips it. `systemctl --user set-environment` applies to the whole user manager. `mode-gaming.conf` is regenerated. A shell `export` never reaches the oneshot service.
4. **Debug logging could change behavior or grow the log.** The flag must be log-only. The 2s atom poll must not emit the verbose block.
5. **Cancel was still an open investigation.** Code plus the installed yad man page already explain it: yad with no `--button` shows OK and Cancel; the pause path replaces that with Pause + OK; zenity `--warning` has no Cancel label; kdialog says Dismiss or uses `--sorry`.
6. **Opacity and the 2s refresh were easy to redo by mistake.** Opacity `0xffffffff` is already set and cannot beat a later equal-opacity window. The 2s refresh runs only when `window_tool` is empty; Deck has xdotool, so atoms apply once per spawn.
7. **Safety.** No invariant change was proposed. The plan needed an explicit ban on disabling forced auto-close or the watchdog while debugging, and on an `XGrabPointer` held by the parent shell.

## Fixes applied

Edited `dev-docs/plans/plan-gamescope-overlay-click-through-2026-10-19.md`:

- Recorded this review in the status line, Reviews row, and references.
- Added the split-focus hypothesis with the 3.16.23 picks, and corrected the focus-display probes.
- Stream E: approved `GAMESCOPE_OVERLAY_DEBUG`; getter matches the gaming-mode parser; writer round-trip; no wizard control; neutral partial-lock arm; log-only; one block per spawn; drop-in preferred over `set-environment`.
- Stream F: focus identity first; raise only after list order is confirmed; height only after we already are global input focus; no shell pointer grab; no mode 2; Steam/QAM button chords out of scope.
- Stream G: button matrix from current spawn flags and the yad man page. Do not add a zenity Cancel. One owner for any height change.
- Tests, CHANGELOG/semver note (no tag), and implementation order updated. Review checklist items for this review, the flag, and unchanged safety invariants are checked. Opus review and human go-ahead stay open.

## Residual risks

- `ctx->list` walk order versus `XRaiseWindow` was not proven. The plan gates any raise on that confirmation.
- Display-name properties may show up oddly in `xprop` because they are written as CARDINAL. Log the raw value.
- If mouse and keyboard displays are already the dialog's `:0` plane and the cursor still cannot enter, the split-focus hypothesis is wrong for that session. Stop and write Stream D; do not keep stacking warps.
- Dual delivery can be global keyboard focus on the game plus X11 focus on the dialog. It can also be Steam Input injecting a second event. The first log cycle has to tell those apart before any exclusivity patch.
- Adding the config key touches the writer and partial-lock. That is still log-only, but it is the one Stream E change that is not a pure log line. Default remains false.
