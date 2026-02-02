# Creating a "v1" Snapshot for Parallel Installation

To run a stable "v1" snapshot of the project alongside the current development version without conflicts, we must isolate **all** installed paths, configuration directories, systemd unit names, and executable names so that v1 never touches the non‑v1 install’s files.

Below is a step-by-step guide and list of required changes.

## 1. Directory Structure Strategy

We will keep the same base directories but rename **project-specific subpaths and filenames** by appending `-v1`.

| Component | Current Path | v1 Path / Name |
|-----------|--------------|----------------|
| **Install directory** | `~/.local/bin/` | `~/.local/bin/` (filenames gain `-v1`) |
| **Library directory** | `~/.local/lib/sleep-warning/` | `~/.local/lib/sleep-warning-v1/` |
| **Config directory** | `~/.config/sleep-warning/` | `~/.config/sleep-warning-v1/` |
| **Systemd units** | `~/.config/systemd/user/sleep-warning.*` | `~/.config/systemd/user/sleep-warning-v1.*` |
| **Service drop-ins** | `~/.config/systemd/user/sleep-warning.service.d/` | `~/.config/systemd/user/sleep-warning-v1.service.d/` |

## 2. File Renaming & Modifications

### A. Installed binaries & entrypoints (root scripts)

These are the user-facing entrypoints under `~/.local/bin/`. For v1, they must be renamed and wired to the v1 libraries/units.

1. **Main script: `sleep-warning.sh`**

- **Installed filename:**
  - `~/.local/bin/sleep-warning.sh` → `~/.local/bin/sleep-warning-v1.sh`.
  - In `install.sh`, ensure the copy target is `sleep-warning-v1.sh`, not `sleep-warning.sh`.
- **Library search path inside the script (`sleep-warning.sh`):**
  - Currently:
    - `INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning"`
  - For v1 snapshot:
    - `INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning-v1"`
  - This ensures the v1 executable only loads v1 libraries.

2. **Installer: `install.sh`**

- **Library/config root paths:**
  - `LIB_DIR="${HOME}/.local/lib/sleep-warning"` → `~/.local/lib/sleep-warning-v1`
  - `CONFIG_DIR="${HOME}/.config/sleep-warning"` → `~/.config/sleep-warning-v1`
- **Installed binary names:**
  - `sleep-warning.sh` → `sleep-warning-v1.sh`
  - `sleep-warning-configure` → `sleep-warning-configure-v1`
  - `sleep-warning-manage` → `sleep-warning-manage-v1`
  - `sleep-warning-status` → `sleep-warning-status-v1`
  - `sleep-warning-uninstall` → `sleep-warning-uninstall-v1`
  - `manual-uninstall-guide` → `manual-uninstall-guide-v1` (or omit for v1; see section on the manual guide).
- **Existing-installation check:**
  - Any checks like:
    - `"$INSTALL_DIR/sleep-warning.sh"`
    - `"$SYSTEMD_USER_DIR/sleep-warning.service"`
    - `"$SYSTEMD_USER_DIR/sleep-warning.timer"`
  - must be duplicated or adjusted so **v1 checks only for `sleep-warning-v1.*`**, not the non‑v1 install.
- **Timer file generation:**
  - `local timer_file="$SYSTEMD_USER_DIR/sleep-warning.timer"` → `sleep-warning-v1.timer`.
  - In the generated `[Unit]` section:
    - `Requires=sleep-warning.service` → `Requires=sleep-warning-v1.service`.
- **Systemctl calls and verification:**
  - All of the following need `-v1` equivalents:
    - `systemctl --user enable sleep-warning.timer`
    - `systemctl --user start sleep-warning.timer`
    - `systemctl --user is-active --quiet sleep-warning.timer`
    - `systemctl --user list-timers sleep-warning.timer ...`
- **Summary text:**
  - Summary paths printed at the end should reference:
    - `sleep-warning-v1.sh`
    - `sleep-warning-v1.service`
    - `sleep-warning-v1.timer`

3. **Uninstaller: `uninstall.sh`**

- **Root paths:**
  - `LIB_DIR="${HOME}/.local/lib/sleep-warning"` → `~/.local/lib/sleep-warning-v1`
  - `CONFIG_DIR="${HOME}/.config/sleep-warning"` → `~/.config/sleep-warning-v1`
- **Installed script filenames to remove:**
  - `"$INSTALL_DIR/sleep-warning.sh"` → `sleep-warning-v1.sh`
  - `"$INSTALL_DIR/sleep-warning-configure"` → `sleep-warning-configure-v1`
  - `"$INSTALL_DIR/sleep-warning-manage"` → `sleep-warning-manage-v1`
  - `"$INSTALL_DIR/sleep-warning-status"` → `sleep-warning-status-v1`
  - `"$INSTALL_DIR/sleep-warning-uninstall"` → `sleep-warning-uninstall-v1`
  - `"$INSTALL_DIR/manual-uninstall-guide"` → `manual-uninstall-guide-v1` (if v1 installs it).
- **Library directory:**
  - `~/.local/lib/sleep-warning` → `~/.local/lib/sleep-warning-v1`.
- **Systemd service/timer control and removal:**
  - All references to `sleep-warning.service` / `.timer` in:
    - `systemctl --user stop ...`
    - `systemctl --user disable ...`
    - checks with `is-active` / `is-enabled`
    - file deletions under `$SYSTEMD_USER_DIR`
  - must be updated to `sleep-warning-v1.service` and `sleep-warning-v1.timer`.

4. **Manual uninstall guide: `manual-uninstall-guide.sh`**

This script prints **exact uninstall commands**, so a v1 copy must not target the non‑v1 install.

- **Path constants at the top:**
  - `LIB_DIR="${HOME}/.local/lib/sleep-warning"` → `~/.local/lib/sleep-warning-v1`
  - `CONFIG_DIR="${HOME}/.config/sleep-warning"` → `~/.config/sleep-warning-v1`
  - `SYSTEMD_USER_DIR` stays the same directory, but the filenames inside change to `sleep-warning-v1.*`.
- **Commands shown to the user:**
  - All embedded commands like:
    - `systemctl --user stop sleep-warning.timer`
    - `systemctl --user disable sleep-warning.timer`
    - `rm -f ${SYSTEMD_USER_DIR}/sleep-warning.service`
    - `rm -f ${SYSTEMD_USER_DIR}/sleep-warning.timer`
    - `rm -f ${INSTALL_DIR}/sleep-warning.sh`
    - `rm -f ${INSTALL_DIR}/sleep-warning-configure`
    - `rm -f ${INSTALL_DIR}/sleep-warning-manage`
    - `rm -rf ${LIB_DIR}`
    - `rm -f ${CONFIG_DIR}/sleep-warning.conf`
    - `rm -f ${CONFIG_DIR}/warnings.log`
  - must be changed to their `sleep-warning-v1.*` counterparts if you choose to ship a `manual-uninstall-guide-v1` alongside the non‑v1 guide.
- **Installed name:**
  - Consider installing this as `manual-uninstall-guide-v1` so it’s clearly the v1 guide.

### B. Systemd units & drop-ins

1. **Service unit: `sleep-warning.service`**

- **Template filename in repo:**
  - `sleep-warning.service` → `sleep-warning-v1.service` (a separate file or a generated variant).
- **Content changes:**
  - `ExecStart=%h/.local/bin/sleep-warning.sh` → `%h/.local/bin/sleep-warning-v1.sh`.

2. **Timer unit: `sleep-warning.timer`**

- **Template filename:**
  - `sleep-warning.timer` → `sleep-warning-v1.timer`.
- **Content changes:**
  - `Requires=sleep-warning.service` → `Requires=sleep-warning-v1.service`.
  - (OnCalendar and other timer logic can remain the same, but now live in the v1 unit.)

3. **Service drop-ins: `lib/service-config.sh`**

- `get_service_dropin_path()` currently returns:
  - `~/.config/systemd/user/sleep-warning.service.d`
- For v1 snapshot:
  - `~/.config/systemd/user/sleep-warning-v1.service.d`
- All helper functions that create/remove `mode-desktop.conf` / `mode-gaming.conf` should operate under `sleep-warning-v1.service.d` and target `sleep-warning-v1.service`.

### C. Core configuration & library modules (`lib/`)

1. **Configuration module: `lib/config.sh`**

- **Application identity and config root:**
  - `SCRIPT_NAME="sleep-warning"` → `SCRIPT_NAME="sleep-warning-v1"` (optional but keeps logs/messages distinguishable).
  - `CONFIG_DIR="${HOME}/.config/sleep-warning"` → `~/.config/sleep-warning-v1`.
- Because many runtime files are defined relative to `CONFIG_DIR`, changing it automatically isolates:
  - `CONFIG_FILE` (and legacy fallback) → v1 config tree.
  - `LOG_FILE` (`warnings.log`).
  - `PAUSE_STATE_FILE` (`.pause_state`).
  - `POPUP_PID_FILE` (`.popup_pid`).
  - `LAST_UPTIME_FILE` (`.last_uptime`).

2. **Configuration core: `lib/configure-core.sh`**

This file wires the configuration wizard to the service/timer/config files; for v1 it must be pointed at v1 resources.

- Update:
  - `SCRIPT_NAME="sleep-warning-configure"` → `"sleep-warning-configure-v1"` (optional but clearer).
  - `CONFIG_DIR="${HOME}/.config/sleep-warning"` → `~/.config/sleep-warning-v1`.
  - `CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"` → same path under v1 config dir.
  - `SYSTEMD_USER_DIR` remains `~/.config/systemd/user`, but:
    - `TIMER_FILE="${SYSTEMD_USER_DIR}/sleep-warning.timer"` → `sleep-warning-v1.timer`.
  - `SERVICE_NAME="sleep-warning"` → `"sleep-warning-v1"`.

Without this change, the v1 configure wizard would still edit the non‑v1 config and service.

3. **Config-locking module: `lib/config-locking.sh`**

- No direct renames are needed in this file if `CONFIG_DIR` / `CONFIG_FILE` are updated in `lib/config.sh` and `lib/configure-core.sh`.
- It uses `CONFIG_DIR` (and derived paths) so it will naturally lock v1’s config tree once `CONFIG_DIR` points to `~/.config/sleep-warning-v1`.

4. **Library loader: `lib/library-loader.sh`**

- This module is generic: it operates on the set of search paths passed via `init_library_paths`.
- For v1, the **important change is in each top-level script** (`sleep-warning.sh`, `configure.sh`, `manage.sh`, `status.sh`, `uninstall.sh`, `manual-uninstall-guide.sh`):
  - Each one should pass `INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning-v1"` to `init_library_paths`.
- The loader itself does not require a name change.

### D. Management and status scripts

1. **Configuration wizard: `configure.sh` (installed as `sleep-warning-configure-v1`)**

- **Library root:**
  - `INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning"` → `~/.local/lib/sleep-warning-v1`.
- Other behavior uses `lib/configure-core.sh` and `lib/config.sh`, so once those are updated, the wizard will operate entirely on v1 config/service/timer.

2. **Management UI: `manage.sh` (installed as `sleep-warning-manage-v1`)**

- **Identity and wiring at top of file:**
  - `INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning"` → `~/.local/lib/sleep-warning-v1`.
  - `SCRIPT_NAME="sleep-warning-manage"` → `sleep-warning-manage-v1` (optional but consistent).
  - `SERVICE_NAME="sleep-warning"` → `"sleep-warning-v1"`.
  - `TIMER_NAME="${SERVICE_NAME}.timer"` → now expands to `sleep-warning-v1.timer`.
  - `SCRIPT_PATH="${HOME}/.local/bin/${SERVICE_NAME}.sh"` → `sleep-warning-v1.sh`.
  - `CONFIG_DIR="${HOME}/.config/sleep-warning"` → `~/.config/sleep-warning-v1`.
  - `SERVICE_FILE` / `TIMER_FILE` → `sleep-warning-v1.service` / `.timer`.
- **Systemctl/journalctl references:**
  - Any direct references to `sleep-warning.timer` or `sleep-warning.service` in printed help or commands must be updated to the v1 names for the v1 build.

3. **Status script: `status.sh` (installed as `sleep-warning-status-v1`)**

- **Identity and wiring at top of file:**
  - `SCRIPT_NAME="sleep-warning-status"` → `sleep-warning-status-v1` (optional).
  - `CONFIG_DIR="${HOME}/.config/sleep-warning"` → `~/.config/sleep-warning-v1`.
  - `CONFIG_FILE` / `CONFIG_FILE_OLD` under that directory.
  - `INSTALLED_LIB_DIR` in the loader setup → `~/.local/lib/sleep-warning-v1`.
  - `TIMER_FILE="${SYSTEMD_USER_DIR}/sleep-warning.timer"` → `sleep-warning-v1.timer`.
  - `SERVICE_FILE="${SYSTEMD_USER_DIR}/sleep-warning.service"` → `sleep-warning-v1.service`.
  - `SERVICE_NAME="sleep-warning"` → `"sleep-warning-v1"`.
- **Printed commands and tips:**
  - In the “Quick commands” / status text, update example commands to use:
    - `sleep-warning-v1.timer`, `sleep-warning-v1.service`.
    - `sleep-warning-manage-v1`, `sleep-warning-uninstall-v1`, etc., where appropriate for the v1 snapshot.

### E. Documentation & user-facing command names (recommended)

To avoid confusion (but not strictly required for runtime isolation), update references in docs and help text to make it clear which commands are v1 versus dev:

- `README.md`, `GETTING_STARTED.md`, `user-docs/USER_GUIDE.md`, `user-docs/CONFIGURATION.md`:
  - Where they mention commands like `sleep-warning.sh`, `sleep-warning-configure`, `sleep-warning-status`, `sleep-warning-manage`, `sleep-warning-uninstall`, `sleep-warning.service`, `sleep-warning.timer`, add v1 variants or an explicit note about the v1 snapshot.
- Any `echo`/help blocks in scripts (`manage.sh`, `status.sh`, `install.sh`, `uninstall.sh`, `manual-uninstall-guide.sh`) that print these command names should be duplicated or parameterized for v1.

## 3. Configuration & Runtime Isolation

Once the above renames are applied:

- **Config files and state (via `lib/config.sh` and `lib/configure-core.sh`):**
  - Config file: `~/.config/sleep-warning-v1/config/sleep-warning.conf`.
  - Log file: `~/.config/sleep-warning-v1/warnings.log`.
  - Locking state: `~/.config/sleep-warning-v1/config/` plus marker/snapshot files:
    - `.config_locked`, `.config_locked_snapshot`.
  - Pause state: `~/.config/sleep-warning-v1/.pause_state`.
  - Popup PID file: `~/.config/sleep-warning-v1/.popup_pid`.
  - Last uptime file: `~/.config/sleep-warning-v1/.last_uptime`.
- **Systemd units and drop-ins:**
  - Service: `~/.config/systemd/user/sleep-warning-v1.service` (+ drop-ins under `.service.d/`).
  - Timer: `~/.config/systemd/user/sleep-warning-v1.timer`.
- **Libraries:**
  - All v1 scripts load from `~/.local/lib/sleep-warning-v1/` and no longer touch `~/.local/lib/sleep-warning/`.

This ensures v1’s configuration, logs, lock state, and runtime metadata are completely separate from the in-development install.

## 4. Implementation Checklist

1. [ ] **Create v1 branch/folder:** Duplicate the project to a new folder (e.g. `LinuxTimerWarning-v1`) or a dedicated git branch.
2. [ ] **Update `sleep-warning.sh`:** Set `INSTALLED_LIB_DIR` to `sleep-warning-v1` and ensure the installed binary name is `sleep-warning-v1.sh`.
3. [ ] **Update `lib/config.sh`:** Change `SCRIPT_NAME` (optional) and `CONFIG_DIR` to the v1 paths.
4. [ ] **Update `lib/configure-core.sh`:** Point `CONFIG_DIR` / `CONFIG_FILE` / `SERVICE_NAME` / `TIMER_FILE` at v1 resources.
5. [ ] **Update `lib/service-config.sh`:** Use `sleep-warning-v1.service.d` for drop-ins and ensure they target `sleep-warning-v1.service`.
6. [ ] **Update systemd unit templates:** Rename `sleep-warning.service` / `.timer` to v1 equivalents and fix `ExecStart` / `Requires`.
7. [ ] **Update `install.sh`:** Library/config paths, installed binary names, service/timer names, systemctl calls, and summary text for v1.
8. [ ] **Update `uninstall.sh`:** Library/config paths, script filenames, service/timer names, and verification logic to remove only v1.
9. [ ] **Update `manual-uninstall-guide.sh`:** Paths and embedded commands so the v1 guide only removes v1 (or omit from v1 entirely).
10. [ ] **Update `configure.sh`:** `INSTALLED_LIB_DIR` to the v1 library path.
11. [ ] **Update `manage.sh` & `status.sh`:** `SERVICE_NAME`, `TIMER_NAME`, `CONFIG_DIR`, `SERVICE_FILE`, `TIMER_FILE`, example commands.
12. [ ] **Optional – update docs/help text:** Reflect v1 command names in `README`, `GETTING_STARTED`, `USER_GUIDE`, and script help outputs.
13. [ ] **Test v1 install:** Run `./install.sh` in the v1 snapshot and verify files land only in v1 locations.
14. [ ] **Verify parallel run:** Confirm:
    - `sleep-warning.timer` (dev) and `sleep-warning-v1.timer` (v1) can both be enabled and started.
    - Each instance uses its own config/logs and does not modify the other’s files.

## 5. Potential Conflicts to Watch

- **Double popups:** If both dev and v1 timers are enabled and their restricted hours overlap, you can see **two** popups (one per install). The popup PID files are separated, so each install believes it is responsible for its own popup.
- **User confusion:** Commands like `sleep-warning-status` vs `sleep-warning-status-v1` and `sleep-warning.timer` vs `sleep-warning-v1.timer` should be clearly documented so you know which install you are interacting with.
- **System resources:** Both timers run on the same interval; impact is minor but expect duplicate checks if both are active. Adjust one interval if desired.
