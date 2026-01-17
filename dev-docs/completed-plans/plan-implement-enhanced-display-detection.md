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
- [x] **Define detection priority order in code**
  - [x] Implement an explicit ordered detection flow: X11 -> Wayland -> loginctl -> gamescope fallback
  - [x] Ensure only one path is selected and logged per run
- [x] **Harden X11 detection**
  - [x] Validate `DISPLAY` format (e.g., `:0`, `:1`, `:0.0`)
  - [x] Confirm X11 accessibility (documented check via `xdpyinfo` or `xset` if available)
  - [x] If validation fails, fall back to the next detection step
- [x] **Harden Wayland detection**
  - [x] Require `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY` and verify the socket exists
  - [x] If socket inaccessible, fall back to `loginctl`
  - [x] Optional: attempt compositor helpers (`swaymsg`, `wlr-randr`) when available
- [x] **Gamescope detection**
  - [x] Detect `gamescope` process or known environment markers
  - [x] Define a consistent way to select display identifiers when gamescope is present
- [x] **Logging requirements**
  - [x] Log the final display type (x11/wayland/gamescope)
  - [x] Log the chosen display identifier
  - [x] Log the fallback path used (e.g., env -> loginctl -> fallback)
  - [x] Log failure reason when no display is available
- [x] **Failure handling**
  - [x] Ensure "no display" results in a clean exit with log entries
  - [x] Ensure "partial detection" logs a warning but continues
- [x] **Documentation updates (if behavior changes)**
  - [x] Update `TECHNICAL_DETAILS.md` display detection notes
  - [x] Update `STEAMOS_GAMING_MODE.md` display detection section

## Notes
- Checklist items will be checked off in `dev-docs/linux-warning-system-plan.md` only after each item is fully implemented and verified.
- Any blockers will be noted inline in the plan checklist.

## Approval Needed
Please confirm this plan so I can begin implementing and updating the checklist statuses.
