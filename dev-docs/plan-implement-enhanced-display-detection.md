# Plan: Implement Checklist 1.4a (Enhanced Display Detection)

## Goal
Implement the "Checklist 1.4a: Enhanced Display Detection (Wayland/gamescope)" items in `dev-docs/linux-warning-system-plan.md` by updating the detection logic in `sleep-warning.sh`, adding structured logging for detection paths, and documenting any behavior changes.

## Scope
- **In scope**: `sleep-warning.sh` display detection functions, logging, and environment variable handling; documentation updates if behavior changes.
- **Out of scope**: Dialog tool priority changes, popup behavior changes, or unrelated refactors.

## Files to Update
- `sleep-warning.sh`
- `dev-docs/linux-warning-system-plan.md` (checklist status updates)
- `dev-docs/TECHNICAL_DETAILS.md` (if detection behavior changes)
- `dev-docs/STEAMOS_GAMING_MODE.md` (if detection behavior changes)

## Implementation Checklist
- [ ] **Define detection priority order in code**
  - [ ] Implement an explicit ordered detection flow: X11 -> Wayland -> loginctl -> gamescope fallback
  - [ ] Ensure only one path is selected and logged per run
- [ ] **Harden X11 detection**
  - [ ] Validate `DISPLAY` format (e.g., `:0`, `:1`, `:0.0`)
  - [ ] Confirm X11 accessibility (documented check via `xdpyinfo` or `xset` if available)
  - [ ] If validation fails, fall back to the next detection step
- [ ] **Harden Wayland detection**
  - [ ] Require `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY` and verify the socket exists
  - [ ] If socket inaccessible, fall back to `loginctl`
  - [ ] Optional: attempt compositor helpers (`swaymsg`, `wlr-randr`) when available
- [ ] **Gamescope detection**
  - [ ] Detect `gamescope` process or known environment markers
  - [ ] Define a consistent way to select display identifiers when gamescope is present
- [ ] **Logging requirements**
  - [ ] Log the final display type (x11/wayland/gamescope)
  - [ ] Log the chosen display identifier
  - [ ] Log the fallback path used (e.g., env -> loginctl -> fallback)
  - [ ] Log failure reason when no display is available
- [ ] **Failure handling**
  - [ ] Ensure "no display" results in a clean exit with log entries
  - [ ] Ensure "partial detection" logs a warning but continues
- [ ] **Documentation updates (if behavior changes)**
  - [ ] Update `TECHNICAL_DETAILS.md` display detection notes
  - [ ] Update `STEAMOS_GAMING_MODE.md` display detection section

## Manual Test Checklist (Do Not Run Without Approval)
- [ ] Desktop Mode (X11): `DISPLAY` set and accessible -> popup appears
- [ ] Desktop Mode (Wayland): `WAYLAND_DISPLAY` set and socket exists -> popup appears
- [ ] Gaming Mode: gamescope detected -> popup appears (no game)
- [ ] Gaming Mode: gamescope detected -> popup appears (windowed game)
- [ ] Gaming Mode: gamescope detected -> popup appears (full-screen game)
- [ ] No display env vars -> `loginctl` fallback finds active session
- [ ] No active session -> "no display" logged, no popup

## Notes
- Checklist items will be checked off in `dev-docs/linux-warning-system-plan.md` only after each item is fully implemented and verified.
- Any blockers will be noted inline in the plan checklist.

## Approval Needed
Please confirm this plan so I can begin implementing and updating the checklist statuses.
