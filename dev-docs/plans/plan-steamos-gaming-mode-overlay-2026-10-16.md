# Plan: SteamOS Gaming Mode (`gamescope`) Overlay & Display Detection Fix

**Date:** 2026-10-16  
**Branch:** `chore/public-repo-prep`  
**Status:** Implemented on this branch. Partial on-device verification 2026-10-19 (see below).

**On-device check (2026-10-19, Steam Deck Gaming Mode):** Popup **displayed and stayed up** over a game (overlay visibility OK). **Buttons were not clickable** — taps/clicks appeared to hit the game underneath (click-through). Follow-up: [plan-gamescope-overlay-click-through-2026-10-19.md](../completed-plans/plan-gamescope-overlay-click-through-2026-10-19.md) (archived; Phase 2 done, Deck-verified 2026-10-20).

**Follow-up (2026-10-17):** A review found that the first implementation opted existing `mode-gaming.conf` installs in, treated static `GAMESCOPE_SESSION=1` as a live gamescope session, blocked turning the overlay off during lock hours, tagged the pause dialog with an empty PID, blocked the popup thread while polling `xprop`, and returned `:0` when that display was not accessible. Those are fixed in the tree. `mode-gaming.conf` no longer writes `GAMESCOPE_SESSION`. The step text below is the original plan and still describes the first approach (`mode-gaming.conf` fallback and tighten-only toggle).  
**Safety Reference:** [docs/SAFETY.md](../../docs/SAFETY.md)

---

## 1. Root Cause Analysis (Verified Against Codebase)

Tracing [`lib/display-detection.sh`](../../lib/display-detection.sh), [`lib/service-config-linux.sh`](../../lib/service-config-linux.sh), [`lib/popup-display.sh`](../../lib/popup-display.sh), [`lib/popup-display-linux.sh`](../../lib/popup-display-linux.sh), [`lib/popup-dialog-implementations.sh`](../../lib/popup-dialog-implementations.sh), and [`lib/window-management.sh`](../../lib/window-management.sh) reveals **five concrete reasons** why popups currently fail to appear in SteamOS Gaming Mode:

1. **Bug 1 — `detect_display_environment()` misclassifies Gaming Mode as `"x11"` when `DISPLAY=:0` is present:**
   - Users typically run `./install.sh` from a terminal in **SteamOS Desktop Mode**, which generates `~/.config/systemd/user/sleep-warning.service.d/mode-desktop.conf` setting `Environment=DISPLAY=:0` ([`lib/service-config-linux.sh:90-97`](../../lib/service-config-linux.sh#L90-L97)). Even without `mode-desktop.conf`, systemd user sessions in Gaming Mode often inherit `DISPLAY=:0` because `gamescope` runs Xwayland on `:0` (`/tmp/.X11-unix/X0` for the Steam UI/overlay plane) and `:1` (`/tmp/.X11-unix/X1` for the game plane).
   - In [`lib/display-detection.sh:164-170`](../../lib/display-detection.sh#L164-L170) (and the `loginctl` `type=x11` branch at lines 238–243), `detect_display_environment()` checks `DISPLAY` accessibility **first** and immediately returns `"x11"` without checking `is_gamescope_running()`.
   - Conversely, if `mode-gaming.conf` was generated ([`lib/service-config-linux.sh:99-108`](../../lib/service-config-linux.sh#L99-L108)), it defaults to `WAYLAND_DISPLAY=wayland-0` when `wayland-*` isn't found — because `find_wayland_socket_candidate()` ([`lib/display-detection.sh:75`](../../lib/display-detection.sh#L75)) only globs `${XDG_RUNTIME_DIR}/wayland-*` and misses `gamescope`'s socket (`gamescope-0`).

2. **Bug 2 — `gamescope` ignores normal X11 windows unless `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` atoms are set:**
   - In Valve's `gamescope` compositor (`steamcompmgr`), standard X11 desktop windows on `:0` are not composited over the active game or Steam UI unless they carry the `STEAM_OVERLAY=1` cardinal property (and `STEAM_INPUT_FOCUS=1` so controller/touch input is routed to the modal dialog).
   - Currently, the codebase never sets `STEAM_OVERLAY` or `STEAM_INPUT_FOCUS`.

3. **Bug 3 — Dialog subprocesses must use X11 (`GDK_BACKEND=x11` / `QT_QPA_PLATFORM=xcb`) on `gamescope`'s `:0` display:**
   - In [`lib/popup-display.sh:288-295`](../../lib/popup-display.sh#L288-L295), when `env_type != "x11"`, `show_warning()` exports `WAYLAND_DISPLAY`. If `yad`/`zenity` or `kdialog` connects via native Wayland instead of Xwayland (`DISPLAY=:0`), it has no X11 window ID for `xprop` to tag.
   - Additionally, on SteamOS's immutable rootfs, `wmctrl` and `xdotool` are often not installed by default, whereas `xprop` and `xwininfo` are part of base X11 utilities. Today, [`_popup_linux_start_stay_on_top()`](../../lib/popup-display-linux.sh#L121-L131) is a complete no-op when `window_tool` (`wmctrl`/`xdotool`) is empty.

4. **Bug 4 — Countdown respawn (`_popup_linux_update_countdown`) and Pause confirmation dialogs also spawn new windows:**
   - [`_popup_linux_update_countdown()`](../../lib/popup-display-linux.sh#L134-L164) kills and respawns the dialog to update the min-display countdown, creating a new X11 window ID that also needs `STEAM_OVERLAY=1` + `STEAM_INPUT_FOCUS=1`.
   - [`_popup_maybe_handle_pause_click()`](../../lib/popup-dialog-implementations.sh#L238-L297) spawns a 30-second "Pause Activated" confirmation dialog (`zenity --info` / `yad --info` / `kdialog --passivepopup`). In Gaming Mode, if that confirmation dialog isn't tagged (or is spawned without overlay atoms), it will sit invisible for 30 seconds while blocking `show_warning()`.

5. **Bug 5 — `get_display()` / `get_display_identifier()` lack dedicated `gamescope` Xwayland resolution:**
   - [`get_display()`](../../lib/display-detection.sh#L336-L349) currently calls `get_display_identifier "wayland"` for `gamescope`, which returns `"unknown"` if `WAYLAND_DISPLAY` is unset or points to a non-existent socket, bypassing the `:0` Xwayland fallback in lines 341–344!

---

## 2. Verification of External Model Reviews (`composer-2.5` & `kilo/reflection/beam-free`)

### A. Cursor `composer-2.5` Review Findings (Verified)
- **Service drop-in behavior (`lib/service-config-linux.sh`):** Confirmed. `sleep-warning.service` uses drop-ins (`mode-desktop.conf` sets `DISPLAY=:0`; `mode-gaming.conf` sets `WAYLAND_DISPLAY` and `GAMESCOPE_SESSION=1`). Fixing `detect_display_environment()` to check `is_gamescope_running()` in both the `DISPLAY` and `loginctl` branches ensures Gaming Mode is detected regardless of which drop-in is installed.
- **`STEAM_OVERLAY=1` + `STEAM_INPUT_FOCUS=1` only (omit `STEAM_NOTIFICATION` and `STEAM_GAME`):** Confirmed. In `gamescope`, `STEAM_OVERLAY=1` + `STEAM_INPUT_FOCUS=1` is the interactive modal overlay plane, whereas `STEAM_NOTIFICATION=1` is for non-interactive toasts and `STEAM_GAME` is for the game surface. Setting only `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1` avoids layer/focus conflicts.
- **Window lookup via `_NET_WM_PID` before title fallback:** Confirmed. Using `xprop -root _NET_CLIENT_LIST` to match `_NET_WM_PID = ${popup_pid}` (with `xwininfo -root -tree` / `wmctrl` / `xdotool` title match as fallback) is much more reliable than title matching alone and works without `wmctrl`/`xdotool`.
- **Immediate atom application (do not wait for `_popup_linux_start_stay_on_top`'s `sleep 1.0`):** Confirmed. Applying `gamescope` atoms immediately after spawn (polling every `0.1s` up to `1.5s`) makes the dialog visible in ~100–200ms rather than leaving it invisible for >1s.
- **`GAMESCOPE_FORCE_AUTO_CLOSE` inside `popup_safe_get_auto_close()` (`lib/popup-safety.sh`):** Confirmed. Centralizing `GAMESCOPE_FORCE_AUTO_CLOSE="${GAMESCOPE_FORCE_AUTO_CLOSE:-true}"` in `lib/popup-safety.sh` (just like `DARWIN_FORCE_AUTO_CLOSE`) keeps `show_warning()`, countdowns, and safety tests consistent.

### B. `kilo/reflection/beam-free` Review Findings (Verified)
- **Do not OR `GAMESCOPE_SESSION=1` into `is_gaming_mode_enabled()` (Item #7):** Verified & valid catch. If `is_gaming_mode_enabled()` fell back to `GAMESCOPE_SESSION=1` when `GAMING_MODE_EXPERIMENTAL_ENABLED=false`, then setting the toggle to `false` would fail to disable Gaming Mode when `GAMESCOPE_SESSION=1` is in the environment. `GAMESCOPE_SESSION=1` belongs strictly in `is_gamescope_running()` (detecting whether `gamescope` is running), whereas `is_gaming_mode_enabled()` must strictly check `get_gaming_mode_experimental_enabled()` (or `GAMING_MODE_EXPERIMENTAL_ENABLED` override).
- **Single canonical fallback for `get_gaming_mode_experimental_enabled()` and `load_existing_config()` without requiring `service-config.sh` (Items #2 & #3):** Verified & valid catch. Both `get_gaming_mode_experimental_enabled()` in `lib/config.sh` and `load_existing_config()` in `lib/configure-config-load.sh` should use the exact same fallback when `GAMING_MODE_EXPERIMENTAL_ENABLED` is absent from `${CONFIG_FILE}`: check `[ -f "${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf" ]`.
- **Tighten-only partial-lock enforcement in both `lib/configure-partial-lock.sh` AND `configure_service_mode()` (Items #4 & #5):** Verified & valid catch. `lib/configure-partial-lock.sh` already validates boolean scalars (`CONFIGURE_BLOCK_ENABLED`, `CONFIG_LOCK_ENABLED`, `POPUP_IMMOVABLE`) in `configure_partial_lock_validate_scalar()` and `configure_partial_lock_validate_proposed()`. However, because Option 12 (`configure_service_mode()` in `lib/configure-input-service.sh`) writes `mode-desktop.conf` / `mode-gaming.conf` immediately when selected in the menu, `configure_service_mode()` must **also** check `configure_partial_lock_mode_enabled` before allowing a switch from `"gaming"` (`true`) to `"desktop"` (`false`), and use `config_lock_prepare_for_wizard_write` / `config_lock_finish_wizard_write` (`lib/config-locking.sh`) when updating `${CONFIG_FILE}` in place.
- **Audit of `env_type == "gamescope"` consumers across `lib/` (Item #19):** Verified via `rg -n 'env_type' lib/`. `"gamescope"` is already handled in `lib/display-detection.sh` (lines 281, 327, 388), `lib/desktop-environment.sh` (line 44), and `lib/window-management.sh` (lines 92, 134). Only `lib/popup-display.sh` (line 286) and `lib/popup-display-linux.sh` lacked `"gamescope"` branches.

---

## 3. Planned Implementation Steps

### Step 1: Add Settings Toggle (`GAMING_MODE_EXPERIMENTAL_ENABLED`) in Config & Wizard (`Option 12`)
1. **Config Key & Reader ([`lib/config-keys.sh`](../../lib/config-keys.sh) & [`lib/config.sh`](../../lib/config.sh)):**
   - Add `CONFIG_KEY_GAMING_MODE_EXPERIMENTAL_ENABLED="GAMING_MODE_EXPERIMENTAL_ENABLED"` in `lib/config-keys.sh` first.
   - Add `DEFAULT_GAMING_MODE_EXPERIMENTAL_ENABLED=false` and `get_gaming_mode_experimental_enabled()` in `lib/config.sh`:
     - If `GAMING_MODE_EXPERIMENTAL_ENABLED` is set in the environment (`true`/`false`), honor it (useful for tests/CLI).
     - Otherwise read `GAMING_MODE_EXPERIMENTAL_ENABLED` from `${CONFIG_FILE}`.
     - If the key is absent from `${CONFIG_FILE}`, return `"true"` if `[ -f "${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf" ]`, else `"false"`.
2. **Wizard Load & Write ([`lib/configure-config-load.sh`](../../lib/configure-config-load.sh) & [`lib/configure-config-write.sh`](../../lib/configure-config-write.sh)):**
   - In `load_existing_config()`, initialize `declare -g gaming_mode_experimental_enabled="false"`, read `CONFIG_KEY_GAMING_MODE_EXPERIMENTAL_ENABLED` from `${CONFIG_FILE}`, and if absent fall back to `[ -f "${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf" ] && gaming_mode_experimental_enabled="true"`.
   - In `_write_config_header()`, write `GAMING_MODE_EXPERIMENTAL_ENABLED=${gaming_mode_experimental_enabled:-false}` with comments explaining that it enables experimental SteamOS Gaming Mode (`gamescope`) Xwayland overlay support while keeping normal Desktop Mode working when in a desktop session.
   - Add a small helper `update_gaming_mode_config_in_place(new_value)` in `lib/configure-config-write.sh` that (when `[ -f "${CONFIG_FILE}" ]`) calls `config_lock_prepare_for_wizard_write`, atomically updates or appends `GAMING_MODE_EXPERIMENTAL_ENABLED=${new_value}` via `mktemp` + `mv`, and calls `_finish_config_lock_wizard_write_if_available`.
3. **Interactive Toggle in `sleep-warning-configure` Option 12 ([`lib/configure-input-service.sh`](../../lib/configure-input-service.sh) & [`lib/service-config-linux.sh`](../../lib/service-config-linux.sh)):**
   - In `configure_service_mode()` (Option 12: `Service Mode Configuration` in `configure.sh`):
     - Let the user toggle between:
       - **Desktop Mode Only (Default — Gaming Mode Disabled):** Sets `gaming_mode_experimental_enabled="false"` and writes `mode-desktop.conf`.
       - **Enable Experimental Gaming Mode Support (Desktop + SteamOS Gaming Mode Overlay):** Sets `gaming_mode_experimental_enabled="true"` and writes `mode-gaming.conf` (updated in `lib/service-config-linux.sh` to include `DISPLAY=:0` alongside `GAMESCOPE_SESSION=1` so Xwayland is always reachable in Gaming Mode).
     - If `configure_partial_lock_mode_enabled` is true and `gaming_mode_experimental_enabled` is currently `"true"` (or `current_mode` is `"Gaming"`), block switching to `"desktop"` (`false`) with `show_error_dialog "Cannot disable Experimental Gaming Mode during lock hours."` and re-prompt.
     - Call `update_gaming_mode_config_in_place "${gaming_mode_experimental_enabled}"` so toggling Option 12 persists immediately even if the user exits without running Option 13, AND also persist it in `_write_config_header()` on Option 13 (Save & Exit).
   - **Tighten-only Partial Lock Validation ([`lib/configure-partial-lock.sh`](../../lib/configure-partial-lock.sh)):**
     - Add `_baseline_gaming_mode_experimental_enabled` to `configure_partial_lock_capture_baseline()`.
     - Add `GAMING_MODE_EXPERIMENTAL_ENABLED|gaming_mode_experimental_enabled` to `configure_partial_lock_validate_scalar()` (`true` → `false` returns `1`; `false` → `true` returns `0`) and `configure_partial_lock_validate_proposed()`.
   - **Status Display ([`lib/status-config-display.sh`](../../lib/status-config-display.sh)):**
     - Show `Experimental Gaming Mode: Enabled / Disabled` in `sleep-warning-status` on Linux.

### Step 2: Fix `gamescope` Detection & Xwayland Display Resolution in [`lib/display-detection.sh`](../../lib/display-detection.sh)
1. **Gate `gamescope` detection strictly on `is_gaming_mode_enabled()`:**
   - Add `is_gaming_mode_enabled()` helper in `lib/display-detection.sh`:
     - If `type get_gaming_mode_experimental_enabled >/dev/null 2>&1`, check `[ "$(get_gaming_mode_experimental_enabled)" = "true" ]`.
     - Else check `[ "${GAMING_MODE_EXPERIMENTAL_ENABLED:-false}" = "true" ]`.
     - Never OR in `GAMESCOPE_SESSION=1` here — `GAMING_MODE_EXPERIMENTAL_ENABLED=false` must unconditionally disable `gamescope` overlay mode.
2. **Add `get_gamescope_x11_display()`:**
   - Checks `:0` first (`is_x11_display_accessible ":0"` or `[ -S "/tmp/.X11-unix/X0" ]`), then `${DISPLAY}` if valid and accessible, then `:1`. Returns `:0` (the `gamescope` overlay Xwayland server) when available.
3. **Update `is_gamescope_running()`:**
   - Return `0` when `pgrep -x gamescope >/dev/null 2>&1` is true, OR when `[ "${GAMESCOPE_SESSION:-}" = "1" ]` (used by `mode-gaming.conf` and unit tests).
4. **Update `detect_display_environment()`:**
   - When `is_gaming_mode_enabled` && `is_gamescope_running`: in step `1) X11 (DISPLAY)` (lines 164–170), step `2) Wayland` (lines 176–198), and step `3) loginctl fallback` (`session_type == "x11"`, lines 238–243), append `"gamescope:process"` to `DISPLAY_DETECTION_PATH` and return `"gamescope"`.
   - When `! is_gaming_mode_enabled`: never return `"gamescope"`; fall through to standard `"x11"` / `"wayland"` desktop handling.
5. **Update `find_wayland_socket_candidate()`, `get_display_identifier()`, and `get_display()`:**
   - In `find_wayland_socket_candidate()`, check both `${XDG_RUNTIME_DIR}/wayland-*` and `${XDG_RUNTIME_DIR}/gamescope-*`.
   - In `get_display_identifier("gamescope")` and `get_display("gamescope")`, resolve the Xwayland display via `get_gamescope_x11_display()` so `gamescope` always gets a valid Xwayland `DISPLAY` (e.g. `:0`) even when `WAYLAND_DISPLAY` is unset or inaccessible.

### Step 3: Force X11 Backend & Apply `STEAM_OVERLAY` + `STEAM_INPUT_FOCUS` Atoms
1. **In [`lib/popup-safety.sh`](../../lib/popup-safety.sh):**
   - Add `GAMESCOPE_FORCE_AUTO_CLOSE="${GAMESCOPE_FORCE_AUTO_CLOSE:-true}"`.
   - Add `popup_is_gamescope()` helper (checks `[ "${env_type:-}" = "gamescope" ]`).
   - In `popup_safe_get_auto_close()` and `popup_assert_safe_config()`, if `popup_is_gamescope` and `[ "${GAMESCOPE_FORCE_AUTO_CLOSE}" = "true" ]`, return `"true"` so popups in Gaming Mode always auto-close after `min_display_time + 10s` (in addition to the absolute watchdog).
2. **In [`lib/popup-display.sh`](../../lib/popup-display.sh) & [`lib/popup-dialog-implementations.sh`](../../lib/popup-dialog-implementations.sh):**
   - When `env_type == "gamescope"`, export `DISPLAY="${display_env}"` (`:0`) and set `POPUP_FORCE_X11_BACKEND="true"` (do not export `WAYLAND_DISPLAY` for child dialogs).
   - Add a small wrapper `_popup_run_dialog_cmd()` in `lib/popup-dialog-implementations.sh` that prefixes dialog invocations (`yad`, `zenity`, `kdialog`) with `env -u WAYLAND_DISPLAY GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb` whenever `[ "${POPUP_FORCE_X11_BACKEND:-false}" = "true" ]`.
   - In `_popup_maybe_handle_pause_click()`, when `[ "${env_type:-}" = "gamescope" ]`, pass `--timeout=10` (instead of 30s) via `_popup_run_dialog_cmd` and tag the confirmation dialog asynchronously via `apply_gamescope_overlay_atoms "Pause Activated" "${window_tool:-}" "" &` so pause confirmation never hangs invisibly.
3. **In [`lib/window-management.sh`](../../lib/window-management.sh):**
   - Add `find_window_id_for_popup(window_title, tool, popup_pid)`:
     1. **PID match (`xprop`):** If `popup_pid` is numeric and `xprop` is available, iterate window IDs from `xprop -root _NET_CLIENT_LIST` and return the window ID whose `_NET_WM_PID` equals `popup_pid`.
     2. **Tool match (`wmctrl` / `xdotool`):** Fallback to `wmctrl -l` or `xdotool search --name "${window_title}"`.
     3. **`xwininfo` title match:** Fallback to `xwininfo -root -tree` matching `"${window_title}"`.
   - Add `apply_gamescope_overlay_atoms(window_title, tool, popup_pid)`:
     - Requires `command -v xprop >/dev/null 2>&1` (logs a `WARNING` to `warnings.log` if `xprop` is missing in `gamescope` mode).
     - Polls up to 15 attempts × `0.1s` (max 1.5s, exiting immediately once `window_id` is found; if `popup_pid` is provided and no longer alive, does one final check before returning).
     - Sets:
       ```bash
       xprop -id "${window_id}" -f STEAM_OVERLAY 32c -set STEAM_OVERLAY 1 2>/dev/null || true
       xprop -id "${window_id}" -f STEAM_INPUT_FOCUS 32c -set STEAM_INPUT_FOCUS 1 2>/dev/null || true
       ```
     - Logs `INFO` on success or `WARNING` if no window ID was found after retries.
4. **In [`lib/popup-display-linux.sh`](../../lib/popup-display-linux.sh):**
   - In `_popup_linux_start_stay_on_top()`:
     - If `[ "${env_type:-}" = "gamescope" ]`, call `apply_gamescope_overlay_atoms "${window_title}" "${window_tool:-}" "${popup_pid}"` **immediately** (before the `sleep 1.0` for standard X11 `window_tool`), and also re-apply inside `keep_window_on_top` if `gamescope` is active.
   - In `_popup_linux_update_countdown()`:
     - After `_popup_spawn_warning_dialog "${updated_message}"`, if `[ "${env_type:-}" = "gamescope" ]`, call `apply_gamescope_overlay_atoms "${window_title}" "${window_tool:-}" "${popup_pid}"`.

### Step 4: Tests & Documentation
1. **Add `tests/test-gamescope-overlay.sh` (and add to `tests/tiers.yaml` Tier-A):**
   - Test 1: Toggle behavior — with a temp `CONFIG_FILE` where `GAMING_MODE_EXPERIMENTAL_ENABLED=false`, `detect_display_environment` returns `"x11"` even when `DISPLAY=:0` + `GAMESCOPE_SESSION=1`; when `GAMING_MODE_EXPERIMENTAL_ENABLED=true` and `DISPLAY=:0` + `GAMESCOPE_SESSION=1`, `detect_display_environment` returns `"gamescope"` and `get_display "gamescope"` returns `":0"` (plus test `get_gamescope_x11_display` fallback `:0` → `${DISPLAY}` → `:1`).
   - Test 2: `popup_safe_get_auto_close` returns `"true"` when `env_type="gamescope"` and `GAMESCOPE_FORCE_AUTO_CLOSE=true`.
   - Test 3: `apply_gamescope_overlay_atoms` finds window ID via mocked `xprop` (`-root _NET_CLIENT_LIST` returning `0x1400007` and `-id 0x1400007 _NET_WM_PID` returning `popup_pid`, without `wmctrl` or `xdotool`) and sets `STEAM_OVERLAY=1` and `STEAM_INPUT_FOCUS=1`.
   - Test 4: `_popup_spawn_warning_dialog` with `POPUP_FORCE_X11_BACKEND=true` passes `GDK_BACKEND=x11` and unsets `WAYLAND_DISPLAY`.
   - Test 5: Tighten-only partial lock (`lib/configure-partial-lock.sh`) allows `GAMING_MODE_EXPERIMENTAL_ENABLED` `false` → `true` and blocks `true` → `false` during active lock hours.
2. **Update Documentation (`README.md`, `user-docs/USER_GUIDE.md`, `dev-docs/STEAMOS_GAMING_MODE.md`):**
   - Document the `GAMING_MODE_EXPERIMENTAL_ENABLED` setting and Option 12 toggle in `sleep-warning-configure`.
   - Describe the `gamescope` Xwayland (`:0`) + `STEAM_OVERLAY=1` / `STEAM_INPUT_FOCUS=1` architecture accurately, note that `xprop` is used, and mark Gaming Mode support as **Experimental (requires on-device verification on Steam Deck)**.
