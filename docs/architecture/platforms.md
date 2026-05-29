# Platform matrix (Linux vs macOS)

| Component | Linux path | macOS path |
|-----------|------------|------------|
| Scheduler config | `~/.config/systemd/user/sleep-warning.{service,timer}` | `~/Library/LaunchAgents/com.sleep-warning.plist` |
| Install | `install.sh` → `main_linux` | `install.sh` → `lib/install-darwin.sh` |
| Timer update | `update_timer_file_platform` in `service-config-linux.sh` | `service-config-darwin.sh` |
| Warning UI | `lib/popup-dialog-implementations.sh` | `lib/popup-dialog-implementations-darwin.sh` |
| Configure GUI | GTK dialogs | `lib/configure-dialogs-darwin.sh` overrides |
| Logs | `journalctl --user` | `~/.config/sleep-warning/logs/` |

Shared: config file format, time parsing, pause state, 24/7 validation, popup safety caps.

When adding a feature, decide **shared vs platform file** before editing. Do not fork business logic unnecessarily.
