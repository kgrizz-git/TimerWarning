### 1. Steam Overlay Integration
- **Description**: Integrate with Steam Overlay API to display warnings within Steam's native overlay system
- **Why Alternative**: Requires Steamworks SDK, C/C++ development, different architecture
- **Advantages**: 
  - Guaranteed to work over full-screen games in Gaming Mode
  - Native Steam integration
  - Better user experience for Steam users
- **Disadvantages**:
  - Only works with Steam games
  - Requires Steam to be running
  - Significant development effort
  - Different technology stack (C/C++ vs bash)
- **Implementation Approach**:
  - Develop C/C++ plugin using Steamworks SDK
  - Create overlay notification system
  - Integrate with existing systemd service (call plugin from bash script)
- **Complementary Option**: Could be developed alongside current system as optional enhancement
- **Priority**: Medium (best solution for SteamOS Gaming Mode full-screen games, but requires significant development effort)
- **Status**: Not implemented
- **Related**: See [STEAMOS_GAMING_MODE.md](../STEAMOS_GAMING_MODE.md#path-to-maximum-effectiveness) for effectiveness analysis and [info/DISTRIBUTION_OPTIONS.md](../info/DISTRIBUTION_OPTIONS.md#option-6-steam-overlay-integration) for distribution methods

**User Experience (UX)**:

**What Users Would See**:
- When restricted hours are detected during gameplay, a notification appears in the Steam overlay (accessible via Shift+Tab)
- The notification appears as a native Steam overlay notification, similar to friend messages or achievement notifications
- Notification includes:
  - Warning message (e.g., "You're using the system during restricted hours (12:00 AM - 5:59 AM)")
  - Timestamp
  - Option to dismiss or acknowledge
- Notification appears even when playing exclusive full-screen games, as it uses Steam's overlay system
- Users can interact with the notification using Steam overlay controls (keyboard/mouse or controller)
- Notification persists until user acknowledges it (similar to Steam achievement notifications)

**Installation Experience** (depends on distribution method):

**Method 1: Steam Workshop** (Not Available - Workshop is for game mods, not system plugins):
- ⚠️ **Reality**: Steam Workshop is designed for game-specific content (mods, maps, skins), not system-level plugins
- Workshop items must be tied to a specific Steam app/game that supports Workshop
- For a system-level plugin like this, Workshop is not the appropriate distribution method
- **Alternative**: Use Method 2 (Standalone) or Method 3 (Integrated) instead
- **If somehow possible** (unlikely): Would require Steam Partner account, app registration, Workshop support implementation, Valve approval (weeks to months)

**Method 2: Standalone Plugin Installation**:
1. User downloads plugin file from GitHub releases
2. Extracts plugin to Steam plugin directory (e.g., `~/.local/share/Steam/plugins/` or systemd service directory)
3. Runs installer script: `./install-steam-plugin.sh`
4. Installer configures plugin and integrates with existing systemd service
5. User restarts Steam (if needed)
6. **Complexity**: ⭐⭐ **Easy to Moderate** - Manual file placement, but straightforward

**Method 3: Integrated with Main Package**:
1. User runs main installation script (`install.sh`)
2. Installer detects Steam installation automatically
3. Prompts user: "Steam detected. Install Steam Overlay plugin? (y/n)"
4. If yes, plugin is installed automatically alongside main system
5. Configuration is shared with main system (same config file)
6. **Complexity**: ⭐ **Very Easy** - Automatic detection and installation

**Method 4: Flatpak/Snap Package**:
1. User installs via `flatpak install sleep-warning` or `snap install sleep-warning`
2. Package includes Steam plugin if Steam is detected
3. May require additional permissions for Steam access
4. **Complexity**: ⭐⭐ **Easy** - Standard package installation, but may need permission configuration

**Daily Use Experience**:
- **During Gameplay**: When restricted hours are detected, Steam overlay notification appears
- **Accessing Overlay**: User presses Shift+Tab (default Steam overlay hotkey) to see notification
- **Notification Appearance**: Native Steam-style notification in overlay interface
- **Interaction**: User can acknowledge/dismiss notification using overlay controls
- **Configuration**: Can be configured via main configuration system (same config file as bash scripts)
- **Status**: Plugin status visible in Steam overlay or via main management script
- **No Interruption**: Notification appears in overlay, doesn't interrupt gameplay unless user opens overlay

**Advantages for Users**:
- ✅ **Works in all game modes** - Even exclusive full-screen games
- ✅ **Native Steam integration** - Feels like part of Steam
- ✅ **Non-intrusive** - Appears in overlay, doesn't force game to minimize
- ✅ **Familiar interface** - Uses Steam's native notification system
- ✅ **Controller support** - Can interact with overlay using game controller

**Limitations**:
- ❌ **Steam required** - Only works when Steam is running
- ❌ **Steam games only** - Doesn't work for non-Steam games
- ❌ **Overlay must be enabled** - Requires Steam overlay to be enabled in Steam settings
- ❌ **User must open overlay** - Notification appears in overlay, user must press Shift+Tab to see it (unless notification is persistent)

**Configuration**:
- Uses same configuration file as main system (`~/.config/sleep-warning/config/sleep-warning.conf`; older installs may have `~/.config/sleep-warning/sleep-warning.conf`)
- Restricted hours, check interval, and other settings shared with main system
- Can be configured via main configuration script (`sleep-warning-configure`)
- Plugin-specific settings (if any) can be added to config file

**Integration with Existing System**:
- Plugin is called by existing `sleep-warning.sh` script when Steam is detected
- **Dual notification strategy**: If Steam is running and plugin is available, shows BOTH Steam overlay notification AND regular popup (maximum visibility)
- If Steam is not running or plugin unavailable, shows regular popup only
- Works alongside existing system (complementary, not replacement)
- Same systemd timer triggers both notification types when available
- **Rationale**: Showing both ensures visibility - Steam overlay for full-screen games, regular popup for desktop/non-Steam scenarios

