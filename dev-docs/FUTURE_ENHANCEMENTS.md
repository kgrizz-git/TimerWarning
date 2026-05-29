# Future Enhancements and Alternatives

Numbered catalog of complementary features and alternative architectures. **Active queue:** [TO_DO.md](TO_DO.md). **Backlog detail:** [REMAINING_WORK_SUMMARY.md](REMAINING_WORK_SUMMARY.md).

**Plans:** [Master plan](plans/master/linux-warning-system-plan.md) · [Phase checklists](plans/phases/) · [Active feature plans](plans/)

**Reference:** [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md) · [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md)

---

## Complementary enhancements

Integrated into the current bash/systemd (or launchd on macOS) design. Full specs live under [`enhancements/`](enhancements/).

| # | Title | Status | Spec |
|---|--------|--------|------|
| 1 | Enhanced display detection | Moved to phase plan | [Phase 1](plans/phases/plan-phase-1-setup-and-scripts.md) · [Gaming Mode](STEAMOS_GAMING_MODE.md#display-detection-enhancements) |
| 2 | Dialog tool priority | Done | [#2](enhancements/enhancement-02-dialog-tool-priority-system.md) · superseded by #24 |
| 2a | Dialog priority in configure wizard | Mostly done | [#2a](enhancements/enhancement-02a-extend-dialog-tool-priority-to-config-wizard.md) |
| 3 | Window size / percentage sizing | Mostly done | [#3](enhancements/enhancement-03-enhanced-window-size-options.md) |
| 4 | Systemd environment (Desktop vs Gaming) | Done (manual SteamOS test pending) | [#4](enhancements/enhancement-04-systemd-service-environment-detection.md) |
| 5 | Configurable warning messages | Not started | [#5](enhancements/enhancement-05-configurable-warning-messages.md) |
| 6 | Escalating warnings | Not started | [#6](enhancements/enhancement-06-escalating-warnings.md) |
| 7 | Warning event logging | Done | [#7](enhancements/enhancement-07-warning-event-logging.md) |
| 8 | Temporary disable via config | Partial (`manage.sh`) | [#8](enhancements/enhancement-08-temporary-disable-via-config.md) |
| 9 | Sleep/hibernate detection | Mostly done | [#9](enhancements/enhancement-09-system-sleep-hibernate-detection.md) |
| 10 | Audio alerts | Not started | [#10](enhancements/enhancement-10-audio-alerts.md) |
| 11 | Desktop notification fallback | Done | [Phase 1 checklist](plans/phases/plan-phase-1-setup-and-scripts.md) |
| 12 | Wayland window management | Not started | [#12](enhancements/enhancement-12-wayland-specific-window-management.md) |
| 13 | Distribution-specific optimizations | Not started | [#13](enhancements/enhancement-13-distribution-specific-optimizations.md) |
| 13a | Single executable installer | Not started | [#13a](enhancements/enhancement-13a-single-executable-installer.md) |
| 13b | Desktop GUI wrapper | Not started | [#13b](enhancements/enhancement-13b-desktop-gui-application-wrapper.md) |
| 14 | Immovable popup | Done | [#14](enhancements/enhancement-14-immovable-popup-window.md) |
| 14b | Configure GUI vs warning window | Done | [#14b](enhancements/enhancement-14b-configure-gui-window-behavior.md) |
| 15 | Auto-close popup | Done | [#15](enhancements/enhancement-15-auto-close-popup-window.md) |
| 16 | Visual day/time grid | Mostly done (Phase 2 grid TBD) | [#16](enhancements/enhancement-16-visual-day-time-configuration-grid.md) |
| 16b | 12-hour time input | Done | [#16b](enhancements/enhancement-16b-12-hour-format-time-input.md) |
| 16c | Multiple ranges in GUI | In progress | [#16c](enhancements/enhancement-16c-multiple-range-entry-gui.md) |
| 17 | Multi-display popups | Not started | [#17](enhancements/enhancement-17-multi-display-popup-support.md) |
| 18 | Config file locking | Mostly done | [#18](enhancements/enhancement-18-config-file-locking.md) |
| 19 | Block configure/manage in restricted hours | Phase 1 done | [#19](enhancements/enhancement-19-prevent-configure-execution.md) · [#19b](enhancements/enhancement-19b-additional-configurable-lock-hours.md) |
| 20 | Additional config lock hours | Phase 1 mostly done | [#20](enhancements/enhancement-20-additional-hours-config-locking.md) |
| 21 | One-time pause (5/10 min) | Mostly done | [#21](enhancements/enhancement-21-one-time-pause-feature.md) |
| 22 | Prevent 24/7 restrictions | Mostly done | [#22](enhancements/enhancement-22-prevent-24-7-restriction-configuration.md) |
| 22a | 24/7 validation edge cases | Not started | [#22a](enhancements/enhancement-22a-fix-validation-edge-cases.md) |
| 23 | Show restricted times in popup | Not started | [#23](enhancements/enhancement-23-display-restricted-times-in-popup.md) |
| 24 | Unified dialog priority (YAD first) | Mostly done | [#24](enhancements/enhancement-24-unified-dialog-priority-yad-first.md) |
| 25 | User-selectable dialog tool | Mostly done | [#25](enhancements/enhancement-25-user-selectable-dialog-tool.md) |
| 26 | Difficult uninstall in restricted hours | Mostly done | [#26](enhancements/enhancement-26-prevent-uninstall-during-restricted-hours.md) · [#26b](enhancements/enhancement-26b-additional-uninstall-lock-hours.md) |
| 27 | Donation links | Phase 1 partial | [#27 PayPal](enhancements/enhancement-27-paypal-donation-links.md) · [#27 Phase 2](enhancements/enhancement-27-phase-2-github-sponsors.md) |
| 28 | SteamOS newbie install guide | Not started | [#28](enhancements/enhancement-28-steamos-newbie-installation-guide.md) |
| 29 | kdialog window size | Not started | [#29](enhancements/enhancement-29-kdialog-window-size-control.md) |
| 30 | Timer interval vs popup frequency | Done (2026-02-09) | [#30](enhancements/enhancement-30-separate-timer-check-interval-from-popup-display-frequency.md) |

**Status key:** *Done* = shipped; *Mostly done* / *Partial* / *In progress* = code largely in place, testing or polish remains; *Not started* = spec only; *Moved* = tracked in a plan file.

---

## Alternative approaches

Major architecture changes. Specs under [`alternatives/`](alternatives/).

| # | Title | Status | Spec |
|---|--------|--------|------|
| 1 | Steam Overlay integration | Not started | [alternative-01](alternatives/alternative-01-steam-overlay-integration.md) |
| 2 | Custom Wayland protocol | Not started | [alternative-02](alternatives/alternative-02-custom-wayland-protocol.md) |
| 3 | Native desktop application | Not started | [alternative-03](alternatives/alternative-03-native-desktop-application.md) |
| 4 | Cron instead of systemd timer | Not started | [alternative-04](alternatives/alternative-04-systemd-timer-alternative.md) |
| 5 | Web-based configuration | Not planned | [alternative-05](alternatives/alternative-05-web-based-configuration-interface.md) |
| 6 | Executable / binary distribution | Not started | [alternative-06](alternatives/alternative-06-executable-binary-distribution.md) |

---

## Suggested focus

1. **Safety and lockout prevention** — #22, #18, #19 (finish testing).
2. **Gaming Mode reliability** — display detection, popups, phase 4 testing; see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md).
3. **Configure UX** — #16c, dialog-tool coverage, GUI fallback without display.

For day-to-day tasks, use [TO_DO.md](TO_DO.md). Testing checklists: [plan-phase-4-testing.md](plans/phases/plan-phase-4-testing.md).

---

## Implementation notes

- Complementary items should stay backward compatible with existing configs.
- Steam Overlay (#alt-1) is the strongest Gaming Mode full-screen path but highest effort; see [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md#path-to-maximum-effectiveness).
- Completed one-off fixes: [`fixes/`](fixes/).

**Last updated:** 2026-05-28 (#30 marked Done)
