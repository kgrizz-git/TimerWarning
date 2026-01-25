# Plan: Fix Enhancement 18 integration + update checklist/docs

Date: 2026-01-25

## Goal

Fix the remaining install/uninstall integration gaps introduced by Enhancement #18 (config file move + locking), then update `dev-docs/enhancements/enhancement-18-config-file-locking.md` (especially the checklist) so it accurately reflects:

- The **combined** `configure.sh` menu option for **Security Settings** (script blocking + config file locking).
- What is **already implemented** in code vs what is **still pending**.
- The corrected install/uninstall behavior (no drift left documented as “known issues”).

## Non-goals

- No test changes intended (only run existing tests if you ask).

## Code changes to make

- [x] **Uninstall: always restore lock permissions before removing files**
  - Ensure `uninstall.sh` calls `restore_config_permissions()` after stopping the timer (and before `remove_config()`), so locked directories/files don’t block uninstall.

- [x] **Install: write/read the config in the new location**
  - Ensure the default config is installed to `${CONFIG_DIR}/config/sleep-warning.conf` (new location), not `${CONFIG_DIR}/sleep-warning.conf` (old location).
  - Ensure `install.sh` reads `CHECK_INTERVAL` from the new location (preferably by sourcing `lib/config.sh` or by updating its helper to use the new path).
  - Ensure migration logic and “preserve existing config” logic align with the new location.

## Doc/checklist updates to make

- [x] **Phase 4.3 menu/UI checklist**: Replace “add separate Config File Locking option” with the combined **Security Settings** flow:
  - Reference `configure.sh` option 6 and `get_security_settings_config()` as the UI entry point.
  - Remove/mark obsolete the separate menu handler steps.

- [x] **Small consistency fixes**:
  - Ensure config file location references match `CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"` where applicable.
  - Note that additional lock hours are shared via `CONFIG_LOCK_HOURS_*` as already implemented/decided.

## Suggested verification

- [ ] After changes, re-scan the doc for any remaining references to a standalone “Config File Locking” menu option.
- [ ] Sanity check (manual): run install/uninstall in a controlled environment where config lock is active and confirm uninstall still succeeds.

