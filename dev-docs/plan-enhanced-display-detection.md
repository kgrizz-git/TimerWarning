# Plan: Enhanced Display Detection (Move + Detailed Checklist)

## Goal
Move the "Enhanced Display Detection" section from `dev-docs/FUTURE_ENHANCEMENTS.md` to `dev-docs/linux-warning-system-plan.md` and expand it into a detailed, actionable checklist aligned with the existing plan format.

## Scope
- Documentation-only changes (no script changes in this step).
- Preserve content accuracy and cross-references.
- Add a detailed checklist that is implementation-ready.

## Proposed Changes
1. **Move section**:
   - Remove "### 1. Enhanced Display Detection" from `dev-docs/FUTURE_ENHANCEMENTS.md`.
   - Add it to `dev-docs/linux-warning-system-plan.md` under Phase 1 (Implementation) or Phase 4 (Testing) as a new checklist subsection.
2. **Expand into checklist**:
   - Break down display detection into X11, Wayland, and gamescope strategies.
   - Include environment variable detection, `loginctl` fallbacks, and session queries.
   - Add logging requirements and failure handling.
3. **Add tests**:
   - List required manual tests in Desktop Mode and Gaming Mode.
   - Include expected log outputs for success/failure scenarios.

## Detailed Checklist (Draft)
- [x] **Define detection priority order**
  - [x] X11: `DISPLAY` if present and valid
  - [x] Wayland: `WAYLAND_DISPLAY` if present and valid
  - [x] `loginctl` session discovery fallback
  - [x] gamescope-specific detection fallback
- [x] **Implement X11 detection details (doc spec)**
  - [x] Validate `DISPLAY` format (e.g., `:0`, `:1`)
  - [x] Confirm display accessibility (`xdpyinfo`/`xset` availability noted)
  - [x] Document fallback behavior if X11 tools missing
- [x] **Implement Wayland detection details (doc spec)**
  - [x] Check `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`
  - [x] Document compositor-specific helpers (e.g., `swaymsg`, `wlr-randr`)
  - [x] Define fallback to `loginctl` if Wayland socket not accessible
- [x] **Implement gamescope detection details (doc spec)**
  - [x] Detect gamescope process (`pgrep gamescope`)
  - [x] Map gamescope environment variables (if present)
  - [x] Document display selection priority when gamescope is active
- [x] **Logging requirements**
  - [x] Log selected display type (X11/Wayland/gamescope)
  - [x] Log selected display identifier
  - [x] Log fallback path taken (if any)
  - [x] Log failure reason when no display is available
- [x] **Failure handling**
  - [x] Define "no display" behavior (silent exit + log)
  - [x] Define partial detection behavior (warn + continue)
- [x] **Documentation updates**
  - [x] Add references to `STEAMOS_GAMING_MODE.md` display detection section
  - [x] Keep cross-links consistent with plan format
- [ ] **Testing checklist (manual)**
  - [ ] Desktop Mode (X11): DISPLAY set, popup appears
  - [ ] Desktop Mode (Wayland): WAYLAND_DISPLAY set, popup appears
  - [ ] Gaming Mode: gamescope detected, popup appears (no game)
  - [ ] Gaming Mode: gamescope detected, popup appears (windowed game)
  - [ ] No display vars: `loginctl` fallback finds active session
  - [ ] Failure case: no active session -> log "no display"

## Suggested Tests (Ask Before Running)
- Manual tests listed above (requires GUI and possibly Gaming Mode).

## Approval Needed
Please confirm whether you want this plan applied to update `dev-docs/linux-warning-system-plan.md` and move/remove the section from `dev-docs/FUTURE_ENHANCEMENTS.md`.
