### Phase 2: Systemd Integration

#### Checklist 2.1: Create Systemd Service File
- [x] Define service unit with appropriate description - IMPLEMENTED: Service file includes description and documentation
- [x] Set Type=oneshot (runs once per trigger) - IMPLEMENTED: Type=oneshot set in service file
- [x] Configure to run as user (not root) - IMPLEMENTED: User service (runs as user, not root)
- [x] Set environment variables for display access - IMPLEMENTED: Service configured with After=graphical-session.target to ensure GUI access, script handles DISPLAY/WAYLAND_DISPLAY detection internally
- [x] Point ExecStart to script location - IMPLEMENTED: ExecStart=%h/.local/bin/sleep-warning.sh
- [x] Add appropriate user/group settings - IMPLEMENTED: User services run as the user automatically, no explicit user/group needed

#### Checklist 2.2: Create Systemd Timer File
- [x] Define timer unit with appropriate description - IMPLEMENTED: Timer file includes description and documentation
- [x] Set OnCalendar to trigger based on CHECK_INTERVAL from config (defaults to 10 minutes if not configured) - IMPLEMENTED: Timer file defaults to `*:0/10` (every 10 minutes), but configure.sh can update it based on CHECK_INTERVAL setting
- [x] Configure to start on boot/login (WantedBy) - IMPLEMENTED: WantedBy=timers.target set in [Install] section
- [x] Link timer to service file - IMPLEMENTED: Requires=sleep-warning.service links timer to service
- [x] Set appropriate accuracy settings - IMPLEMENTED: AccuracySec=1min set, Persistent=true for missed triggers
- [x] Note: Timer interval is configurable via CHECK_INTERVAL in config file (1-60 minutes). The configure.sh script automatically updates the timer file when CHECK_INTERVAL is changed. Install script should read CHECK_INTERVAL from config (if exists) when creating timer file.

#### Checklist 2.3: Test Systemd Integration
- [x] Test service manually (`systemctl --user start sleep-warning.service`) - TESTED: Service starts and runs successfully, exits cleanly when not in restricted hours
- [x] Test timer activation (`systemctl --user start sleep-warning.timer`) - TESTED: Timer activates and shows correct next trigger time
- [x] Verify timer status (`systemctl --user status sleep-warning.timer`) - TESTED: Timer shows active (waiting) status with correct trigger time
- [x] Check timer list (`systemctl --user list-timers`) - TESTED: Timer appears in list with correct next trigger time
- [x] Verify service runs correctly when triggered - TESTED: Service executes successfully when started manually, logs show proper execution
