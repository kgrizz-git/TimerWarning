# Plan: Checklist 1.4b (Wayland/gamescope Popup Behavior)

## Goal
Add a new Checklist 1.4b to `dev-docs/linux-warning-system-plan.md` that specifies expected popup behavior on Wayland/gamescope, and update documentation to clearly state limitations, fallbacks, and testing requirements.

## Scope
- **In scope**: Plan/checklist additions and documentation updates.
- **Out of scope**: Actual code changes to popup behavior (those would follow after checklist approval).

## Files to Update
- `dev-docs/linux-warning-system-plan.md` (add Checklist 1.4b)
- `dev-docs/TECHNICAL_DETAILS.md` (Wayland/gamescope popup behavior and limitations)
- `dev-docs/STEAMOS_GAMING_MODE.md` (popup behavior expectations, limitations, and testing)
- `README.md` and/or `USER_GUIDE.md` if user-facing behavior needs clarification

## Checklist 1.4b (Draft)
- [ ] **Define popup behavior expectations on Wayland/gamescope**
  - [ ] Modal warning should appear when possible
  - [ ] Document focus/always-on-top limitations
  - [ ] Define acceptable degradation (e.g., visible but not guaranteed on top)
- [ ] **Dialog tool behavior guidance**
  - [ ] Prefer `yad` for Wayland/gamescope if available
  - [ ] Document limitations of `zenity`/`kdialog` on Wayland
- [ ] **Fallbacks when dialogs fail**
  - [ ] Define notify-send fallback behavior (if dialogs fail)
  - [ ] Define logging for fallback activation
- [ ] **Logging requirements**
  - [ ] Log dialog tool used
  - [ ] Log any Wayland-specific limitations encountered
  - [ ] Log if on-top enforcement is unavailable
- [ ] **Manual testing checklist**
  - [ ] Wayland Desktop: popup appears and is dismissible
  - [ ] Gaming Mode (no game): popup appears
  - [ ] Gaming Mode (windowed game): popup appears
  - [ ] Gaming Mode (full-screen game): record whether popup appears on top

## Notes
- Checklist items will only be checked off after implementation and verification.
- Any blockers will be noted inline with the checklist item.

## Approval Needed
Please confirm this plan so I can add Checklist 1.4b and update the documentation accordingly.
