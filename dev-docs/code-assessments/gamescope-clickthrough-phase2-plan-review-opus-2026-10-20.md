# Review: Phase 2 of `plan-gamescope-overlay-click-through-2026-10-19.md` (second review)

**Reviewer:** Claude Opus 5.5
**Date:** 2026-10-20
**Prior review:** [Grok 4.7, 2026-10-20](gamescope-clickthrough-phase2-plan-review-grok-2026-10-20.md)
**Verdict:** **approve-with-fixes.** Fixes are applied in the plan. The plan is approved for coding, starting with Stream E. No production code was changed. The "Human go-ahead for Phase 2 coding" checkbox is still unchecked.

## What was checked

- The full plan after Grok's edits, plus Grok's archive.
- gamescope tag **3.16.23** `src/steamcompmgr.cpp` (downloaded for this review into gitignored `tmp/gs/`): `add_win`, `restack_win`, `circulate_win`, `configure_request`, `map_win`/`unmap_win`, `DetermineAndApplyFocus` (per-ctx walk and self-raise), the global pick (`overlayWindow` → `inputFocusWindow`/`keyboardFocusWindow`), the opacity PropertyNotify re-walk, and where the `GAMESCOPE_*_FOCUS_DISPLAY` properties are written.
- `lib/configure-partial-lock.sh` (scalar validator arms, baseline capture, `validate_proposed`), `lib/configure-config-write.sh` (whole-file rewrite, gaming-mode key), `lib/service-config-linux.sh` (drop-in handling), `uninstall.sh` (what it removes).
- `docs/SAFETY.md` invariants. No invariant changes are proposed. The watchdog and `GAMESCOPE_FORCE_AUTO_CLOSE` stay mandatory.
- **Hardcoded-credentials rule:** applied as a check because this review adds logging fields and a config key. Nothing here is a credential: one boolean flag, plus logged window IDs, display names, geometry, opacity, and window class. The plan still forbids logging the warning body and our own dialog title. No secrets go into the plan or the code it describes.

## Issues found

1. **The raise question has an answer, and it is the opposite of what the spike assumed (blocker for spike 3).** On 3.16.23, `ctx->list` is top of stack first. `CreateNotify` inserts at the head. `restack_win` re-hooks a window just before its `above` sibling. `configure_request` forwards `stack_mode`, so client raises are honored. gamescope itself runs `if (ctx->list[0] != inputFocus) XRaiseWindow(inputFocus)`. So:
   - "Later in the walk" means **lower in the X stack**. On an equal-opacity tie, the bottom-most wide overlay wins `overlayWindow`.
   - `XRaiseWindow` moves our dialog **earlier** and **loses** ties.
   - gamescope already raises the per-ctx input-focus window, which is our dialog, since Enter reaches it. That puts us at the head, where any wide Steam overlay at max opacity below us wins the global pick. That mechanism produces the observed split by itself.
   - A lower spike would fight gamescope's own re-raise on every focus pass.
2. **Display-level probes cannot be the kill-switch on their own.** `GAMESCOPE_MOUSE/KEYBOARD_FOCUS_DISPLAY` are display names. Steam's overlay windows are on `:0` with our dialog. "Mouse display = `:0`" does not mean "our dialog has the cursor". It only separates dialog from game when the game is on another display (normally `:1`). The plan had no window-level evidence to tell our dialog from a Steam overlay.
3. **The unmapped windows gap.** The focus walk does not filter by map state. Unmapped windows keep their last-read `isOverlay`/opacity until destroyed. A hidden Steam overlay can still win the tie. The diagnostics have to include unmapped windows.
4. **The writer round-trip used the env-aware getter.** With env taking precedence, a `set-environment GAMESCOPE_OVERLAY_DEBUG=true` session (or env leaking into the configure shell) would be written into `sleep-warning.conf` on the next configure save. That would turn a temporary debug override into a persistent config change. The writer needs a file-only read, and "absent stays absent".
5. **"Log-only" did not say the probes are bounded.** Debug `xprop`/`xwininfo` calls on a wedged Xwayland could block. The plan did not require `timeout`, placement off the spawn/watchdog path, or a cap on the children scan.
6. **Display-name decode was unspecified.** The values are written as format-32 CARDINAL with `strlen+1` items. Raw `xprop` output is a list of integers. Without a decode rule, people will misread the logs.
7. **Drop-in cleanup.** `uninstall.sh` removes only the `.service`/`.timer` files, not `sleep-warning.service.d/`. A leftover `gamescope-overlay-debug.conf` would re-enable debug after a reinstall. This is harmless for safety, but it needs a docs line.
8. Minor: the implementation sketch still said the Opus review comes before the first code chunk. The "Phase 2 order" line still listed stacking as a lever. Spike 1 pointed at ad-hoc opacity notes instead of a structured census.

## Fixes applied (plan only)

- **Phase 2 hypothesis:** replaced "raise order not proven" with the source-proven order and its consequences: top first, bottom-most wins ties, gamescope self-raises, unmapped windows count, and there is no client-side stacking fix when a wide max-opacity overlay sits below us. Added a note that the focus-display probes are per display.
- **Stream E:**
  - Writer reads the **file** value via a config-only helper that the getter also uses. The key is preserved if present and not added if absent. Env is never persisted.
  - Partial-lock neutral arm sits in `configure_partial_lock_validate_scalar`, next to the gaming-mode arm. No baseline or `validate_proposed` wiring, because the wizard never edits the key. Tested in both directions.
  - Bounding: `timeout` ≤ 2 s per probe, backgrounded arm only, ≤ 64 children, `unavailable` on failure.
  - Display decode rule: little-endian bytes up to the first NUL, logged next to the raw value.
  - New **`:0` overlay census** with `predicted_overlay_wid`, computed with the 3.16.23 rule over mapped and unmapped windows. It includes an on-device step to calibrate `xwininfo`'s print direction. Our dialog's title is not logged.
  - Turn-off instructions, including the uninstall gap.
- **Stream F:** spike 3 now **rejects** both raise and lower on 3.16.23 and can be re-opened only for another gamescope version. Added a **decision table / kill-switch** that combines the decoded displays with the census. Spike 1 now uses the census. The "Phase 2 order" line no longer lists stacking.
- **Tests:** writer round-trip (including "env not persisted"), neutral arm in both directions, display decode, four census cases (alone, equal-opacity Steam below, lower-opacity Steam, unmapped counts), and no census call when the flag is off.
- **Bookkeeping:** status line, Updated, Reviews row, implementation sketch item 6, review checklist (Opus box checked, human go-ahead left unchecked), references.

## Answers to Grok's open questions

1. **Does `XRaiseWindow` move the dialog later in `ctx->list`?** No. It moves the dialog to the **head**, which the walk visits **first**. With `>=`, the last-visited (bottom-most) equal-opacity wide overlay wins, so a raise loses the tie. gamescope already raises the per-ctx input-focus window itself. **Decision: reject raise entirely on 3.16.23, and do not keep it as a deferred spike.** Lowering is rejected as well, because gamescope re-raises the window. Re-open only for a different gamescope version whose source shows a different walk order or tie rule.
2. **Kill-switch if mouse and keyboard displays are already on `:0`.** Grok's version was not decisive, because `:0` is shared with Steam's overlay windows. The plan now has an explicit decision table. If the game is on another display, both displays are `:0`, **and** the census predicts **our** WID, then the split-focus hypothesis is wrong for that session. In that case, stop at Stream D. The one exception is spike 4 (taller height), and only if the cursor visibly enters the window but misses the buttons. If both are `:0` but the census predicts a Steam window, that is a Steam-side hold → Stream D. If the game is itself on `:0`, the display probes are inconclusive. Use the census only.
3. **Partial-lock arm for `GAMESCOPE_OVERLAY_DEBUG`.** Confirmed: keep it **neutral** (either value allowed during lock hours). It is log-only. It does not affect the 16 h caps, popup lifetime, the watchdog, auto-close, the escape hatch, geometry, or button sets. Enabling it adds diagnostics only. Disabling it removes them. Neither direction loosens a restriction. Keep the explicit arm with a comment so nobody later copies the `DIALOG_TOOL` "any change blocked" pattern onto it.

## Residual risks

- **Pointer may be impossible on 3.16.23 from the client side.** If the census shows a wide Steam overlay at max opacity below us, no width, atom, or stacking change of ours can win the global pick. The likely outcome is then Stream D (keyboard + forced auto-close), and the plan now says so up front.
- The census models only the `overlayWindow` rule. Other inputs (`VirtualConnectorIsSingleOutput()`, a non-default virtual-connector strategy, xdg overlays used when the root ctx has none) are assumed default on Deck. The "census/rule mismatch" row exists to catch this.
- `xwininfo -children` print direction is not documented on this host. The plan calibrates it on device rather than assuming it.
- Dual Enter delivery may also come from Steam Input injecting a second event, separately from X/Wayland focus. The census cannot see that. If the census says ours and both displays are `:0` but Steam still reacts, record it as a Steam Input question, out of scope for Phase 2.
- The source was read from the upstream `3.16.23` tag. The device runs `3.16.23.6` (a SteamOS packaging revision). Small downstream patches are possible. The mismatch row covers it.
