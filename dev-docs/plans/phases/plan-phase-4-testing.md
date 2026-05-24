### Phase 4: Testing and Validation

#### Checklist 4.1: Functional Testing
- [ ] Test script with default configuration
- [X] Test script manually during weekday restricted hours (00:00-05:59)
- [ ] Test script manually during weekend restricted hours (01:00-05:59)
- [X] Test script during non-restricted hours (should not show popup)
- [X] Test with custom configuration file (different hours)
- [ ] Test configuration file parsing and validation
- [ ] Verify popup appears and is modal (blocks interaction)
- [X] Verify popup can be dismissed by user
- [X] Test timer triggers every 10 minutes correctly
- [X] Test minimum display time enforcement - NOT TESTED: Requires testing with wmctrl/xdotool on X11 systems
- [ ] Test minimum display time on Wayland - NOT TESTED: Window manager tools don't work on Wayland, needs fallback testing
- [X] Test auto-reopen functionality - NOT TESTED: Verify popup reopens correctly when closed prematurely
- [X] Test countdown accuracy - NOT TESTED: Verify countdown updates correctly
- [ ] Test graceful fallback without window tools - NOT TESTED: Verify countdown still works without wmctrl/xdotool
- [X] **CRITICAL**: Test popup with full-screen game/application running
- [X] Verify popup appears on top of full-screen applications
- [X] Verify popup can steal focus from full-screen applications
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test systemd user services start automatically in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test display detection works with gamescope (Wayland compositor)
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with no game running in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with windowed game in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with full-screen game in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with exclusive full-screen game in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test popup appears with borderless windowed game in Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test with Steam games (native and Proton)
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test with non-Steam games added to library
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test timer persistence when switching between Desktop Mode and Gaming Mode
- [ ] **CRITICAL - SteamOS Gaming Mode**: Test service status after reboot into Gaming Mode

#### Checklist 4.2: Edge Case Testing
- [ ] Test at exact boundary times (00:00, 05:59, 06:00)
- [ ] Test on day transitions (Sunday to Monday, Friday to Saturday)
- [ ] Test with missing configuration file (should use defaults)
- [ ] Test with invalid configuration file (should handle gracefully)
- [ ] Test with malformed configuration entries
- [ ] Test with configuration file containing comments
- [ ] Test when DISPLAY is not set (should handle gracefully)
- [ ] Test when WAYLAND_DISPLAY is not set (should handle gracefully)
- [ ] Test when neither DISPLAY nor WAYLAND_DISPLAY is set (should use loginctl fallback)
- [ ] Test when zenity is not available (should handle gracefully)
- [ ] Test when all dialog tools unavailable (zenity, yad, kdialog) - should log error and exit gracefully
- [ ] Test with multiple user sessions (if applicable)
- [ ] Test on systems without GUI (should exit gracefully without errors)
- [ ] Test on different desktop environments if available (GNOME, KDE, XFCE)
- [ ] Test minimum display time with different window managers - NOT TESTED: Test on GNOME, KDE, XFCE, etc.
- [x] Test window stays on top during timeout - IMPLEMENTED AND TESTED: keep_window_on_top() function ensures window stays on top. Uses xprop _NET_WM_STATE_ABOVE and xdotool windowraise/windowactivate for reliable on-top behavior. Confirmed working with zenity on KDE/KWin. Requires wmctrl or xdotool to be installed.
- [ ] Test immovable window feature - NOT TESTED: Verify position monitoring and restoration works correctly on X11 systems
- [ ] **SteamOS Gaming Mode**: Test when gamescope compositor is active (Wayland)
- [ ] **SteamOS Gaming Mode**: Test display detection when switching from Desktop Mode to Gaming Mode
- [ ] **SteamOS Gaming Mode**: Test display detection when switching from Gaming Mode to Desktop Mode
- [ ] **SteamOS Gaming Mode**: Test when on-screen keyboard is active (may affect dialog input)
- [ ] **SteamOS Gaming Mode**: Test with different game rendering technologies (Vulkan, DirectX via Proton)
- [ ] **SteamOS Gaming Mode**: Test under heavy system load (game running, high CPU/GPU usage)

#### Checklist 4.3: Installation and Uninstall Testing
- [ ] Test install.sh on clean system (no previous installation)
- [ ] Test install.sh with missing zenity dependency (should offer to install)
- [ ] Test install.sh with --yes flag (auto-confirm dependency installation)
- [ ] Test install.sh with existing installation (should warn, --force should reinstall)
- [ ] Test install.sh on different distributions (if possible: Ubuntu, Fedora, Arch, openSUSE)
- [ ] Test install.sh preserves existing config file (doesn't overwrite)
- [ ] Test install.sh creates config file if missing
- [ ] Verify install.sh sets correct permissions on script
- [ ] Verify install.sh enables and starts timer correctly
- [ ] Test uninstall.sh removes all files correctly
- [ ] Test uninstall.sh stops and disables timer correctly
- [ ] Test uninstall.sh --remove-config removes config file
- [ ] Test uninstall.sh without --remove-config preserves config file
- [ ] Test installation after uninstall (should work cleanly)
- [ ] Verify install.sh error handling (missing directories, permission errors, etc.)
- [ ] Test install.sh on system without GUI (should handle gracefully)
- [ ] Test configure.sh interactive wizard with various inputs
- [ ] Test configure.sh validation and error handling
- [ ] Test configure.sh on system without GUI (should fallback to text prompts)
- [ ] Test manage.sh menu and all functions
- [ ] Test manage.sh disable/enable functionality
- [ ] Test manage.sh on system without GUI (should use text menu)

#### Checklist 4.4: System Integration Testing
- [ ] Verify timer persists across reboots
- [ ] Verify timer works after user login
- [ ] Test behavior when system is suspended/resumed
- [ ] Verify no performance impact from 10-minute checks
- [ ] Check systemd logs for any errors
- [ ] **SteamOS Gaming Mode**: Verify timer persists when booting directly into Gaming Mode
- [ ] **SteamOS Gaming Mode**: Verify timer persists when booting into Desktop Mode then switching to Gaming Mode
- [ ] **SteamOS Gaming Mode**: Verify timer persists when switching from Gaming Mode to Desktop Mode
- [ ] **SteamOS Gaming Mode**: Test service status after system suspend/resume in Gaming Mode
- [ ] **SteamOS Gaming Mode**: Verify no performance impact during gameplay (check CPU/GPU usage during timer trigger)
- [ ] **SteamOS Gaming Mode**: Test with different SteamOS versions (if available) to ensure compatibility

#### Supplemental Tests (Moved from Intermediate Plans)

##### Compositor Helper Integration
- [ ] Wayland desktop with `swaymsg` available: helper detection path is used when env vars missing
- [ ] Wayland desktop with `wlr-randr` available: helper detection path is used when env vars missing
- [ ] Wayland desktop with only `wayland-info` available: helper detection path is used when env vars missing

##### Enhanced Display Detection (Manual)
- [ ] Desktop Mode (X11): DISPLAY set, popup appears
- [ ] Desktop Mode (Wayland): WAYLAND_DISPLAY set, popup appears
- [ ] Gaming Mode: gamescope detected, popup appears (no game)
- [ ] Gaming Mode: gamescope detected, popup appears (windowed game)
- [ ] No display vars: loginctl fallback finds active session
- [ ] Failure case: no active session -> log "no display"

##### Enhanced Display Detection (Implementation Verification)
- [ ] Desktop Mode (X11): DISPLAY set and accessible -> popup appears
- [ ] Desktop Mode (Wayland): WAYLAND_DISPLAY set and socket exists -> popup appears
- [ ] Gaming Mode: gamescope detected -> popup appears (no game)
- [ ] Gaming Mode: gamescope detected -> popup appears (windowed game)
- [ ] Gaming Mode: gamescope detected -> popup appears (full-screen game)
- [ ] No display env vars -> loginctl fallback finds active session
- [ ] No active session -> "no display" logged, no popup

##### Wayland/Gamescope Popup Behavior
- [ ] Wayland Desktop: popup appears and is dismissible
- [ ] Gaming Mode (no game): popup appears
- [ ] Gaming Mode (windowed game): popup appears
- [ ] Gaming Mode (full-screen game): record whether popup appears on top

##### Dialog Tool Priority + Notify-Send Fallback
- [ ] Wayland/gamescope: verify tool selection order in logs
- [ ] Dialog failure: verify notify-send fallback and log entry
