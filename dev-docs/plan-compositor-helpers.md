# Plan: Compositor Helper Integration (Wayland/gamescope)

## Goal
Integrate compositor helper tooling into display detection so Wayland sessions can be identified more reliably when environment variables are missing or insufficient.

## Scope
- **In scope**: `sleep-warning.sh` display detection additions using Wayland compositor helpers (`swaymsg`, `wlr-randr`, optional `wayland-info`).
- **Out of scope**: Dialog tool priority changes, popup behavior changes, or notify-send fallback implementation.

## Files to Update
- `sleep-warning.sh`
- `dev-docs/linux-warning-system-plan.md` (checklist status update for compositor helpers)
- `dev-docs/TECHNICAL_DETAILS.md` (document helper usage)

## Implementation Checklist
- [ ] **Helper detection utilities**
  - [ ] Add function to check for Wayland helper commands: `swaymsg`, `wlr-randr`, `wayland-info`
  - [ ] Prefer `swaymsg` for wlroots/sway-based environments
  - [ ] Use `wlr-randr` as an alternate wlroots signal
  - [ ] Use `wayland-info` as a last-resort helper if available
- [ ] **Helper-based Wayland detection**
  - [ ] If `WAYLAND_DISPLAY`/socket missing, attempt helper detection before loginctl
  - [ ] Record detection path in `DISPLAY_DETECTION_PATH`
  - [ ] Set `DISPLAY_DETECTION_NOTE` to indicate helper usage
- [ ] **Logging updates**
  - [ ] Log helper name used when it determines Wayland
- [ ] **Documentation updates**
  - [ ] Note helper usage in `TECHNICAL_DETAILS.md`
  - [ ] Mark compositor helper item complete in plan checklist

## Manual Test Checklist (Do Not Run Without Approval)
- [ ] Wayland desktop with `swaymsg` available: helper detection path is used when env vars missing
- [ ] Wayland desktop with `wlr-randr` available: helper detection path is used when env vars missing
- [ ] Wayland desktop with only `wayland-info` available: helper detection path is used when env vars missing

## Approval Needed
Please confirm this plan so I can implement the compositor helper integration.
