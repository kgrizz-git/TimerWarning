# Sleep Warning System - Implementation Plan

**Related Documents**:
- [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md) - Detailed technical specifications and implementation details
- [STEAMOS_GAMING_MODE.md](STEAMOS_GAMING_MODE.md) - SteamOS Gaming Mode compatibility and effectiveness assessment
- [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) - Future enhancements and alternative approaches
- [info/DISTRIBUTION_OPTIONS.md](info/DISTRIBUTION_OPTIONS.md) - Distribution and packaging options

## High-Level Description

This project implements a systemd-based monitoring system that displays interactive warning popups when the system is being used during configurable restricted hours. **The system is designed with maximum compatibility as a core principle**, working on any modern Linux distribution with systemd (including Steam OS in both Desktop Mode and Gaming Mode, Ubuntu, Debian, Fedora, Arch, and others). It uses a bash script combined with systemd timers to check the current time every 10 minutes and display modal warning dialogs if usage occurs during user-defined restricted hours.

**Compatibility Focus**: Special attention has been given to ensuring the system works reliably on SteamOS in Gaming Mode, which presents unique challenges including Wayland compositor (gamescope) display detection, full-screen game overlay compatibility, and systemd user service persistence across mode transitions. The implementation includes robust fallback mechanisms and multiple detection strategies to maximize compatibility across all supported environments.

**Default restricted hours** (easily configurable):
- **Weekdays (Monday-Friday)**: Midnight (00:00) to 6:00 AM
- **Weekends (Saturday-Sunday)**: 1:00 AM to 6:00 AM

The restricted hours for each day of the week are easily configurable through a simple configuration file, allowing users to customize the warning schedule to their needs. The popup dialogs are modal and require user interaction before they can be dismissed, ensuring the user is aware of the late-night usage. The system runs as a user service (not system-wide) to ensure proper display access and user context.

## Disclaimer

**IMPORTANT - PLEASE READ CAREFULLY**

This software is provided "AS IS", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.

**User Responsibility**:
- Users are responsible for backing up important data before installing or using this software
- Users are responsible for ensuring system stability and compatibility before installation
- Users acknowledge that they use this software at their own risk
- The developers are not responsible for any errors, data loss, system instability, or adverse effects resulting from the use of this software
- The developers are not responsible for any consequences of missed warnings or system failures
- Users should test the software in a safe environment before relying on it for important use cases

**System Modifications**:
- This software modifies systemd user services and system configuration
- Improper installation or configuration may affect system behavior
- Users should understand systemd services and Linux system administration before installing
- Uninstallation should be performed using the provided uninstall script

**Compatibility**:
- While extensive testing is planned, compatibility cannot be guaranteed for all systems
- Some features may not work on all Linux distributions or desktop environments
- SteamOS Gaming Mode compatibility is actively being developed but may have limitations
- Users should verify compatibility with their specific system before installation

**Support**:
- Support is provided on a best-effort basis
- No guarantee is made regarding response time or resolution of issues
- Users are encouraged to review logs and documentation before requesting support

By installing or using this software, you acknowledge that you have read, understood, and agree to this disclaimer. If you do not agree, do not install or use this software.

## Architecture Overview

The solution consists of eight main components:

1. **Configuration File** (`sleep-warning.conf`):
   - Simple text-based configuration file
   - Defines restricted hours for each day of the week
   - Easy to edit and modify without changing script code
   - Located in user's config directory for easy access

2. **Bash Script** (`sleep-warning.sh`): 
   - Reads configuration file to determine restricted hours
   - Checks current day of week and time
   - Determines if current usage falls within restricted hours
   - Displays modal popup using `zenity` (with fallbacks to `yad` and `kdialog`) if conditions are met
   - Handles display environment detection with multiple fallback strategies (X11 DISPLAY, Wayland WAYLAND_DISPLAY, loginctl session detection, gamescope detection)
   - Includes SteamOS Gaming Mode compatibility features

3. **Systemd Service** (`sleep-warning.service`):
   - Defines the service that executes the bash script
   - Runs as a user service (not root)
   - Handles environment variables for display access

4. **Systemd Timer** (`sleep-warning.timer`):
   - Triggers the service every 10 minutes
   - Uses systemd's calendar-based timer functionality
   - Automatically starts on boot/login

5. **Installation Script** (`install.sh`):
   - Automated installation script for easy setup
   - Detects Linux distribution and package manager
   - Checks and installs required dependencies
   - Copies files to correct locations
   - Sets proper permissions
   - Enables and starts the systemd timer
   - Provides clear success/error feedback

6. **Uninstall Script** (`uninstall.sh`):
   - Removes installed files
   - Stops and disables systemd timer
   - Provides cleanup confirmation

7. **Interactive Configuration Script** (`configure.sh`):
   - Interactive wizard that walks users through setting restricted hours
   - Uses zenity dialogs for user-friendly GUI interface
   - Prompts for restricted hours for each day of the week
   - Validates input and provides helpful examples
   - Updates configuration file with user selections
   - Can be run anytime after installation to modify settings

8. **Management/Help Script** (`manage.sh`):
   - Provides information and management options for the sleep warning system
   - Displays current service status (enabled/disabled, active/inactive)
   - Explains how to temporarily disable the service
   - Explains how to re-enable the service
   - Explains how to uninstall the system
   - Provides quick access to view configuration
   - Provides quick access to run configuration wizard
   - Shows service logs and troubleshooting information

## Implementation Plan

## Master Plan Overview

This master plan provides high-level phase summaries and overall checklists.
Detailed checklists and implementation notes are split into phase-specific plan files.

**Detailed Plans**:
- [plan-phase-1-setup-and-scripts.md](plan-phase-1-setup-and-scripts.md)
- [plan-phase-2-systemd.md](plan-phase-2-systemd.md)
- [plan-phase-3-installation.md](plan-phase-3-installation.md)
- [plan-phase-4-testing.md](plan-phase-4-testing.md)
- [plan-phase-5-documentation.md](plan-phase-5-documentation.md)
- [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md)

## Phase Summaries

### Phase 1: Project Setup and Script Development
- Build core scripts, configuration system, and popup behavior
- Ensure display detection and logging are robust
- See detailed checklist in `plan-phase-1-setup-and-scripts.md`

### Phase 2: Systemd Integration
- Define user service + timer units
- Ensure user-session compatibility
- See detailed checklist in `plan-phase-2-systemd.md`

### Phase 3: Installation and Deployment
- Installation/uninstall scripts and manual steps
- Distribution-specific support
- See detailed checklist in `plan-phase-3-installation.md`

### Phase 4: Testing and Validation
- Functional, edge-case, install/uninstall, and integration testing
- SteamOS Gaming Mode validation
- See detailed checklist in `plan-phase-4-testing.md`

### Phase 5: Documentation and Maintenance
- User docs, technical docs, maintenance guidance
- Licensing and donation considerations
- See detailed checklist in `plan-phase-5-documentation.md`

See also [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) for optional improvements and alternative approaches.

## Overall Checklists

### Implementation
- [ ] Phase 1 complete
- [ ] Phase 2 complete
- [ ] Phase 3 complete

### Testing
- [ ] Phase 4 complete

### Documentation
- [ ] Phase 5 complete

## Future Enhancements

See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) for optional improvements and alternative approaches.
