# Stream E implementation review (Claude Opus 5.5, 2026-10-20)

**Scope:** commit `2ae2f71` (`feat(gamescope): log overlay focus behind a default-off flag`) on `chore/public-repo-prep`, checked against Stream E in [plan-gamescope-overlay-click-through-2026-10-19.md](../plans/plan-gamescope-overlay-click-through-2026-10-19.md) and the Phase 2 plan reviews ([Grok 4.7](gamescope-clickthrough-phase2-plan-review-grok-2026-10-20.md), [Opus 5.5](gamescope-clickthrough-phase2-plan-review-opus-2026-10-20.md)).

**Verdict:** approve-with-fixes. Two small log-only fixes applied in the follow-up commit. No safety invariant touched.

## Plan conformance

| Requirement | Result |
|-------------|--------|
| Default off; key constant in `config-keys.sh`; getter in `config.sh` | OK (`DEFAULT_GAMESCOPE_OVERLAY_DEBUG=false`, `get_gamescope_overlay_debug`) |
| Env wins over config, including explicit false; unrecognized env falls through | OK. Shared `_config_parse_bool_token`; tests cover `false`/`0`/`no` over config true, `true` over false, garbage env falls through |
| Writer reads the file only, never the env getter; absent key stays absent | OK. `_get_gamescope_overlay_debug_from_config`; writer reads the old `CONFIG_FILE` while writing to a `mktemp` file, then `mv` |
| Neutral partial-lock arm | OK, both directions return 0; not wired into `validate_proposed` |
| Log-only (no geometry / atom / button / auto-close / watchdog change) | OK. Debug hooks are `type`-guarded and `|| true`; test asserts no extra `xprop -set` |
| One block per spawn / respawn / pause notice, not the 2 s poll | OK. Gate `GAMESCOPE_DEBUG_LOGGED_KEY` lives in each arm subshell, so the poll inside that subshell is gated and each respawn job logs once |
| `timeout 2` on probes; census ≤ 64; probes off the spawn path | OK. `_gs_debug_probe` wraps every debug xprop/xwininfo; emit is backgrounded unless `GAMESCOPE_OVERLAY_DEBUG_SYNC=true` (tests) |
| No dialog title / body | OK. Our WID and any child named `window_title` are omitted (for the pause notice, `window_title` is the dynamic-scope local of `apply_gamescope_overlay_atoms`) |
| Focus display decode, census, `predicted_overlay_wid` | OK. Little-endian bytes to first NUL; `width > 1200 && opacity >= running max`, last wins; absent opacity = `0xffffffff`; unmapped counts; order logged as `assumed_top_first` |
| Flag off: no `DEBUG-GAMESCOPE`, no `-children` census | OK (tested) |

## Fixes applied

1. **Pause-notice `buttons=` was wrong.** The pause block took `pause_available=true` from the warning's scope and logged `OK + --extra-button=Pause N min`, but the pause notice is `zenity --info`, `yad --info --button=OK:0`, or `kdialog --msgbox`. Plan item 2 requires the flags actually passed. `gamescope_overlay_debug_button_summary` now takes the kind and reports the pause-notice flags. Three new test assertions.
2. **Missing exit line on respawn-on-dismiss.** When the user dismissed the dialog during min-display (exit without pause), the loop respawned with no `DEBUG-GAMESCOPE exit` line for the dismissed instance. Added one `_popup_linux_note_gamescope_debug_exit … false` before `_popup_linux_update_countdown`. Countdown redraws that we kill ourselves still do not log an exit (the next `respawn` block marks them).

## Test results

- `timeout 120 bash tests/test-gamescope-overlay.sh`: 123 passed, 0 failed (120 before the new assertions).
- `./scripts/run-tests.sh --tier a`: passed (22 run, 3 darwin-only skipped).
- `shellcheck -S error -x` (v0.10.0, fetched to `tmp/` because it is not installed here): all changed `lib/*.sh` clean. `tests/test-gamescope-overlay.sh` reports SC2218 on five lines; the same findings exist at `5a0a0a2` (before Stream E). They come from mocks the test intentionally redefines later. Not changed.
- `run-security-scan.sh --ci`: ShellCheck stage clean; gitleaks and semgrep not installed on this machine. Aikido MCP unavailable (server error).

## Residual risks (no change requested)

- **Miss then hit can log two blocks.** If the first apply cannot find the WID (gate `miss:<pid>`) and a later 2 s poll finds it, a second block is logged. The poll only runs when `window_tool` is empty (not on Deck with xdotool). Useful evidence; acceptable.
- **Census can run long in the background.** 64 children × up to 5 probes × 2 s timeout. It never delays the dialog or watchdog; systemd's control-group kill bounds it when the oneshot exits. A late block may land after the exit line.
- **Exit ordering on pause.** The pause notice's block and exit lines are logged before the warning's `exit … pause_handler_ran=true` line. Read by `kind=`.
- **`xwininfo -children` order is assumed top-first** and logged as such; calibrate on device as the plan says.
- **`GAMESCOPE_OVERLAY_DEBUG_SYNC=true`** in a real service environment would run probes in the foreground of the atom-arm subshell (still not in front of the spawn). Test-only knob; not documented for users.
- On-device capture is still open (manual checklist).
