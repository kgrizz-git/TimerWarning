# Plan: Dialog Tool Priority + Notify-Send Fallback

## Goal
Implement the Dialog Tool Priority System (Future Enhancements #2) and the notify-send fallback (Future Enhancements #11), moving notify-send into `dev-docs/linux-warning-system-plan.md` with a detailed checklist. Update `dev-docs/FUTURE_ENHANCEMENTS.md` to reflect progress and add cross-references.

## Scope
- **In scope**: `sleep-warning.sh` dialog tool selection logic and notify-send fallback; plan/checklist updates; documentation updates.
- **Out of scope**: Wayland-native window management (Future Enhancements #12) implementation.

## Files to Update
- `sleep-warning.sh`
- `dev-docs/linux-warning-system-plan.md`
- `dev-docs/FUTURE_ENHANCEMENTS.md`
- `dev-docs/TECHNICAL_DETAILS.md`
- `dev-docs/STEAMOS_GAMING_MODE.md`
- `README.md` / `user-docs/USER_GUIDE.md` (if behavior notes need changes)

## Checklist Additions (Draft)
### Dialog Tool Priority System
- [x] Define environment-aware priority rules (gamescope/Wayland/KDE/Desktop)
- [x] Implement selection order:
  - [x] Wayland/gamescope: `yad` → `kdialog` → `zenity`
  - [x] KDE: `kdialog` → `yad` → `zenity`
  - [x] Default: `zenity` → `yad` → `kdialog`
- [x] Log selected tool + reason
- [x] Document behavior and limitations

### Notify-Send Fallback (moved from Future Enhancements)
- [x] Add fallback in `show_warning()` if dialog tool fails or not found
- [x] Log fallback usage and errors
- [x] Document that fallback is non-modal and best-effort
- [x] Add manual test items for fallback behavior

## Documentation Updates
- [x] Move “Desktop Notification Fallback” into plan with checklist
- [x] Update Future Enhancements #11 to “Moved” status with cross-reference
- [x] Update Future Enhancements #12 section with cross-reference to plan items and current status

## Approval Needed
Please confirm this plan so I can implement the changes and update the plan/docs accordingly.
