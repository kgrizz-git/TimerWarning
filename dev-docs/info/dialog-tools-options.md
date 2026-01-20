# Dialog Tool Comparison: Zenity, KDialog, and YAD

## Overview

This document compares three command-line dialog tools for Linux shell scripts: **Zenity**, **KDialog**, and **YAD** (Yet Another Dialog). The comparison focuses on their availability, sizing behavior, window management capabilities, and compatibility across different environments—particularly on SteamOS and Gamescope.

---

## Quick Reference: Tool Comparison

| Feature | Zenity | KDialog | YAD |
| :--- | :--- | :--- | :--- |
| **Toolkit** | GTK (GNOME) | Qt (KDE) | GTK (Zenity fork) |
| **SteamOS Availability** | ✅ Pre-installed | ✅ Pre-installed | ⚠️ Requires manual install (AUR) |
| **Size Control** | Minimal | Content-adaptive | Explicit |
| **Complexity** | Simple dialogs only | Medium | High (forms, tabs, lists) |
| **X11 Positioning** | Poor (needs xdotool) | Fair | Excellent (native --geometry) |
| **Wayland Compatibility** | Excellent | Excellent | Good |
| **Gamescope Behavior** | Reliable, centered | KDE-native, stable | Most flexible, but may need XWayland |
| **Window Management** | Basic | Standard | Advanced (--on-top, --undecorated, --sticky) |

---

## 1. Availability and Installation

### SteamOS (Arch-based)

**SteamOS 3.x** is based on Arch Linux and uses KDE Plasma as its desktop environment (Desktop Mode). In Gaming Mode, it uses the Gamescope compositor.

#### Pre-Installed Tools
- **Zenity**: ✅ Yes (part of base GNOME/GTK dependencies)
- **KDialog**: ✅ Yes (part of KDE Plasma, native to SteamOS Desktop Mode)
- **YAD**: ❌ No (must be installed manually)

#### Installing YAD on SteamOS
YAD is available in the AUR (Arch User Repository) but not in official Arch repos or SteamOS's default package set.

```bash
# On SteamOS, you need to disable read-only mode and install YAD manually:
sudo steamos-readonly disable
sudo pacman -S base-devel git
git clone https://aur.archlinux.org/yad-git.git
cd yad-git
makepkg -si
```

**⚠️ Important**: Installing AUR packages on SteamOS can break system updates. For production scripts targeting SteamOS, **prefer Zenity or KDialog** as they're guaranteed to be present.

### Other Distributions

| Distribution | Zenity | KDialog | YAD |
| :--- | :--- | :--- | :--- |
| **Ubuntu/Debian** | Pre-installed (GNOME) | `apt install kdialog` | `apt install yad` |
| **Fedora** | Pre-installed (GNOME) | `dnf install kdialog` | `dnf install yad` |
| **Arch Linux** | `pacman -S zenity` | `pacman -S kdialog` | AUR only |
| **openSUSE** | Pre-installed | Pre-installed (default DE) | Available in repos |

**Recommendation**: For maximum compatibility, **use Zenity as the default** with fallbacks to KDialog and YAD.

---

## 2. Sizing Behavior

### How Each Tool Handles Window Dimensions

All three tools allow you to specify window dimensions, but they handle these requests differently:

#### Zenity
- **Flags**: `--width=N` and `--height=N`
- **Behavior**: 
  - Requests these dimensions but **will shrink** if content is smaller
  - Will **expand** if content (especially text) exceeds requested size
  - No minimum size enforcement—very short text can result in tiny windows
- **Text Wrapping**: Automatically wraps long text, which can unexpectedly increase height

```bash
# Example: Request 600x400, but actual size varies with content
zenity --info --title="Test" --text="Short text" --width=600 --height=400
# Actual size: ~400x250 (shrinks to fit content)

zenity --info --title="Test" --text="Very long text that will force the window to be larger..." --width=300 --height=150
# Actual size: ~300x300 (expands height to accommodate wrapped text)
```

#### KDialog
- **Flags**: `--geometry WIDTHxHEIGHT` (Qt-style geometry string)
- **Behavior**:
  - **Most aggressive at shrinking to content**
  - Even with explicit geometry, KDialog often ignores width/height if content is small
  - Better at respecting size for complex dialogs (file choosers, lists)
  - On Wayland, geometry hints are often completely ignored

```bash
# Example: Request 500x300, but KDialog may render at 350x200 if text is short
kdialog --geometry 500x300 --title "Test" --msgbox "Short message"
```

**KDialog Quirk**: It calculates "optimal size" based on Qt's internal layout engine, which is designed for usability (ensuring buttons aren't cramped) but makes exact sizing unreliable.

#### YAD
- **Flags**: `--width=N --height=N` OR `--geometry=WIDTHxHEIGHT+X+Y`
- **Behavior**:
  - **Most reliable at respecting explicit dimensions**
  - Will enforce requested size even if content is smaller (leaving whitespace)
  - Will add scrollbars if content exceeds requested size (instead of auto-expanding)
  - Supports additional flags like `--fixed` to prevent user resizing

```bash
# Example: YAD will render exactly 600x400 with scrollbars if needed
yad --info --title="Test" --text="Some text" --width=600 --height=400 --fixed
```

**YAD Advantage**: For scripts requiring consistent window dimensions (e.g., for visual alignment or predictable layouts), YAD is the most dependable choice.

### Summary: Sizing Predictability

| Tool | Predictability | Best Use Case |
| :--- | :--- | :--- |
| **Zenity** | Low (content-adaptive) | Simple alerts where exact size doesn't matter |
| **KDialog** | Medium (layout-optimized) | KDE environments where native look is priority |
| **YAD** | High (explicit control) | Forms, complex layouts, consistent sizing |

---

## 3. Window Management Capabilities

Beyond basic popups, these tools offer various window management features:

### Stay-on-Top / Always-on-Top

**Purpose**: Ensure the dialog remains visible above other windows.

| Tool | Flag | X11 | Wayland | Gamescope |
| :--- | :--- | :--- | :--- | :--- |
| **Zenity** | `--modal` | Partial | Respected | Works in Gaming Mode |
| **KDialog** | `--attach` | Yes | Via KWin | Requires parent window |
| **YAD** | `--on-top` | Excellent | Compositor-dependent | Usually works |

**Notes**:
- On X11, YAD's `--on-top` is most reliable (uses `_NET_WM_STATE_ABOVE`)
- On Wayland, "always on top" is controlled by the compositor; Gamescope usually respects modal hints
- In SteamOS Gaming Mode, `--modal` helps prevent dialogs from being hidden behind games

### Window Decorations

**Purpose**: Control whether the window has a title bar, close button, and borders.

| Tool | Decoration Control | Use Case |
| :--- | :--- | :--- |
| **Zenity** | None (always decorated) | Standard dialogs |
| **KDialog** | None (always decorated) | Standard dialogs |
| **YAD** | `--undecorated`, `--skip-taskbar` | Custom overlays, HUD-style notifications |

**YAD Example**:
```bash
# Create a borderless, always-on-top status indicator
yad --text="Recording..." --undecorated --skip-taskbar --on-top --no-buttons --timeout=10
```

### Stickiness (Visible on All Workspaces)

| Tool | Flag | Behavior |
| :--- | :--- | :--- |
| **Zenity** | None | N/A |
| **KDialog** | None | N/A |
| **YAD** | `--sticky` | Window appears on all virtual desktops (X11 only) |

### Focus Management

**Issue**: Dialog windows can "steal focus" from active applications, which is disruptive during gaming or typing.

| Tool | Non-Intrusive Options |
| :--- | :--- |
| **Zenity** | No native option; historically requires modifying `.glade` files |
| **KDialog** | `--passivepopup` (notification-style, doesn't steal focus) |
| **YAD** | `--no-focus` (window appears but doesn't grab keyboard focus) |

**Recommendation for Gaming Environments**: For non-critical notifications, use `notify-send` (libnotify) instead of dialog tools, as it integrates with the Steam overlay without stealing focus.

---

## 4. Wayland and Gamescope Compatibility

### X11 vs. Wayland: Key Differences

| Feature | X11 | Wayland |
| :--- | :--- | :--- |
| **Absolute Positioning** | Full support (`+X+Y` coordinates) | Not allowed (security model) |
| **Window Querying** | Can read position/size via `xwininfo` | Cannot query other windows |
| **Always-on-Top** | Application can request via EWMH | Compositor decides |
| **Focus Stealing** | Application controlled | Compositor controlled |

**Impact**: On Wayland, dialog tools have **less control** over their appearance and behavior. The compositor (GNOME Shell, KWin, Gamescope) makes final decisions.

### Gamescope (SteamOS Gaming Mode)

**Gamescope** is a micro-compositor designed for gaming. It enforces strict window management to optimize game performance and controller-based UI navigation.

#### How Dialogs Behave in Gamescope

1. **Forced Centering**: Most dialogs default to screen center, ignoring positioning flags
2. **Scaling**: Windows may be scaled up to fit the display resolution (especially on Steam Deck's 800p screen)
3. **Layering Issues**: Dialogs can appear "behind" the game if not properly tagged as transient popups
4. **Input Capture**: Game may retain controller input focus, requiring touchscreen to interact with dialog

#### Tool-Specific Gamescope Behavior

| Tool | Gamescope Compatibility | Notes |
| :--- | :--- | :--- |
| **Zenity** | ⭐⭐⭐⭐⭐ Excellent | Most reliable; GTK backend handles Gamescope well |
| **KDialog** | ⭐⭐⭐⭐ Good | Works well in Desktop Mode; can be heavy in Gaming Mode |
| **YAD** | ⭐⭐⭐ Fair | Advanced features may require XWayland; positioning often ignored |

**Testing Observations** (Steam Deck, SteamOS 3.5):
- **Zenity**: Always appears centered, respects modal flag, scales correctly
- **KDialog**: Sometimes pulls in KDE service dependencies; may show brief loading delay
- **YAD**: Most customizable but flags like `--geometry`, `--posx` usually ignored; `--on-top` works via XWayland

#### Example: Gamescope-Optimized Dialog

```bash
# For SteamOS Gaming Mode, use simple centered dialogs with modal flag
if [ "$XDG_SESSION_TYPE" = "wayland" ] || pgrep -x gamescope >/dev/null; then
    # Wayland/Gamescope: Keep it simple
    zenity --warning --text="Restricted hours active" --width=600 --height=400 --modal
else
    # X11: Can use advanced positioning
    yad --warning --text="Restricted hours active" --geometry=600x400+100+100 --on-top
fi
```

### Wayland Positioning: The XDG-Shell Protocol

On Wayland, windows use **positioners** instead of absolute coordinates. A positioner describes:
- **Anchor point**: Where to attach relative to parent window
- **Gravity**: Which direction to expand
- **Constraint adjustment**: What to do if window would go off-screen (slide, flip, resize)

**Limitation**: Command-line tools like Zenity, KDialog, and YAD **do not expose** positioner APIs to shell scripts. They use default behaviors defined by their GTK/Qt backends.

**Result**: You cannot precisely control dialog position on Wayland; you can only **suggest** via hints like `--center` or by launching the dialog as a child process of another window.

---

## 5. Priority Recommendations

### By Environment

#### SteamOS Desktop Mode (KDE Plasma, X11/Wayland)
1. **KDialog** (Priority 1): Native to KDE, best visual integration
2. **Zenity** (Priority 2): More predictable sizing
3. **YAD** (Priority 3): If installed and advanced features needed

#### SteamOS Gaming Mode (Gamescope)
1. **Zenity** (Priority 1): Most reliable, lightest, best Gamescope compatibility
2. **KDialog** (Priority 2): Use for file choosers or KDE-specific features
3. **YAD** (Priority 3): Avoid unless advanced layouts required

#### Generic Desktop Linux (X11)
1. **YAD** (Priority 1): Maximum control, best positioning, complex forms
2. **KDialog** (Priority 2): If on KDE/Qt environment
3. **Zenity** (Priority 3): If on GNOME/GTK environment or for simple alerts

#### Generic Desktop Linux (Wayland)
1. **Zenity** (Priority 1): Best native Wayland support (GTK4)
2. **KDialog** (Priority 2): Good on KDE/Plasma Wayland
3. **YAD** (Priority 3): Falls back to XWayland; advanced features limited

### By Use Case

| Use Case | Recommended Tool | Reason |
| :--- | :--- | :--- |
| **Simple Yes/No alerts** | Zenity | Pre-installed everywhere, minimal |
| **Forms with multiple inputs** | YAD | Native form support, field validation |
| **File/directory choosers** | KDialog or Zenity | Both have mature file picker widgets |
| **Custom layouts (tabs, notebooks)** | YAD | Only tool with notebook/tab support |
| **HUD-style overlays** | YAD | `--undecorated`, `--on-top`, `--skip-taskbar` |
| **SteamOS production scripts** | Zenity + KDialog fallback | Guaranteed availability |
| **KDE-integrated tools** | KDialog | Access to KDE services, D-Bus integration |
| **Critical warnings (gaming)** | Zenity with `--modal` | Best at interrupting without focus issues |

---

## 6. Detailed Capabilities

### Zenity

**Strengths**:
- Pre-installed on nearly all GNOME-based systems and SteamOS
- Simple, clean GTK interface that adapts to system theme
- Excellent Wayland support (GTK3/4 native)
- Minimal dependencies
- Reliable modal behavior in gaming environments

**Weaknesses**:
- Very limited layout options (no forms, tabs, or complex widgets)
- Poor control over window positioning on X11 (requires external tools like `xdotool`)
- Unpredictable sizing (always shrinks/expands to fit content)
- No built-in progress tracking or live updates
- Cannot prevent focus stealing without system modifications

**Best For**:
- Simple alerts, confirmations, and notifications
- SteamOS Gaming Mode scripts (guaranteed compatibility)
- Wayland-first environments
- Scenarios where exact sizing doesn't matter

**Example**:
```bash
# Basic confirmation dialog
if zenity --question --text="Start maintenance?" --width=400 --height=200 --modal; then
    echo "User confirmed"
fi
```

### KDialog

**Strengths**:
- Native to KDE Plasma (SteamOS Desktop Mode)
- Beautiful integration with Qt/KDE themes
- Supports complex dialogs (multi-file select, color picker, progress bars)
- Can integrate with KDE services via D-Bus
- `--passivepopup` for non-intrusive notifications

**Weaknesses**:
- Requires Qt libraries (heavier than GTK in non-KDE environments)
- Geometry hints often ignored, especially on Wayland
- Aggressive content-adaptive sizing can make exact dimensions impossible
- May pull in KDE service dependencies, causing startup delays

**Best For**:
- KDE/Plasma environments (especially SteamOS Desktop Mode)
- File/directory selection with preview
- Integration with KDE notification system
- Passive popups that don't interrupt workflow

**Example**:
```bash
# File selection dialog with filter
selected_file=$(kdialog --getopenfilename "$HOME" "*.txt *.md|Text Files")
echo "Selected: $selected_file"

# Passive notification (doesn't steal focus)
kdialog --passivepopup "Task complete!" 5
```

### YAD (Yet Another Dialog)

**Strengths**:
- **Most powerful and flexible** of the three tools
- Native support for forms, tabs, notebooks, multiple columns
- Precise geometry control: `--geometry=WIDTHxHEIGHT+X+Y`
- Advanced window management: `--on-top`, `--undecorated`, `--sticky`, `--fixed`
- Supports live updates via named pipes or command substitution
- Can create custom button layouts with specific exit codes
- Handles lists, tables, and progress bars natively

**Weaknesses**:
- **Not pre-installed** on SteamOS or most distributions
- Advanced positioning features fail on Wayland (falls back to XWayland)
- Steeper learning curve (many flags and options)
- On Gamescope, sophisticated features often degrade to basic behavior

**Best For**:
- Complex forms (multiple text fields, checkboxes, dropdowns)
- Custom HUDs or status overlays (using `--undecorated` and `--on-top`)
- X11 environments requiring precise positioning
- Scripts where YAD installation can be guaranteed
- Dynamic interfaces (updating dialog content in real-time)

**Example**:
```bash
# Complex form with multiple fields
result=$(yad --form --title="User Registration" \
    --field="Name:TEXT" "" \
    --field="Age:NUM" "25" \
    --field="Email:TEXT" "" \
    --field="Subscribe:CHK" "TRUE" \
    --button="Register:0" \
    --button="Cancel:1" \
    --width=500 --height=300 --center)

if [ $? -eq 0 ]; then
    # Parse result (fields separated by |)
    IFS='|' read -r name age email subscribe <<< "$result"
    echo "Registered: $name, $age, $email, Subscribe=$subscribe"
fi
```

**YAD Real-Time Updates**:
```bash
# Progress dialog that updates via pipe
mkfifo /tmp/yad-pipe
yad --progress --auto-close --title="Processing" < /tmp/yad-pipe &
yadpid=$!

for i in {1..100}; do
    echo "$i" > /tmp/yad-pipe
    sleep 0.1
done

rm /tmp/yad-pipe
```

---

## 7. Technical Details: Size Enforcement

### How Sizing Actually Works

When you specify dimensions for a dialog, the tool **requests** these dimensions from the window manager (X11) or compositor (Wayland). However:

1. **Window Manager/Compositor** receives the size request
2. **Layout Engine** (GTK or Qt) calculates content size
3. **Comparison**: If content size > requested size, layout engine usually overrides
4. **Decoration Overhead**: Title bar, borders, and buttons add 20-80px to effective height

### Test Results: Actual vs. Requested Size

| Tool | Requested | Short Text (Actual) | Long Text (Actual) | Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **Zenity** | 600x400 | ~380x220 | ~600x450 | Shrinks to fit / Expands if needed |
| **KDialog** | 600x400 | ~400x250 | ~600x400 | Aggressive shrink / Respects max |
| **YAD** | 600x400 | 600x400 (with whitespace) | 600x400 (with scrollbar) | Enforces size |

### Over-Provisioning Strategy

To ensure dialogs are sized appropriately across tools:

```bash
# Add 20% extra to width and 50px to height for overhead
requested_width=600
requested_height=400

# Account for title bar (~40px), borders (~10px), button bar (~50px)
effective_width=$((requested_width + requested_width / 5))
effective_height=$((requested_height + 100))

zenity --info --text="$message" --width=$effective_width --height=$effective_height
```

---

## 8. Bounds Checking and Screen Limits

Regardless of requested size, windows must fit on screen. All tools respect screen boundaries, but with different behaviors:

### Automatic Clamping

| Tool | X11 Behavior | Wayland Behavior |
| :--- | :--- | :--- |
| **Zenity** | WM clamps to visible area | Compositor enforces boundaries |
| **KDialog** | Qt layout engine prevents off-screen | Compositor enforces boundaries |
| **YAD** | Honors geometry but WM can override | Falls back to compositor rules |

### Implementation Recommendation

For scripts that calculate window positions (X11 only), implement bounds checking:

```bash
# Get screen dimensions
screen_width=$(xrandr --current | grep 'primary\|connected' | grep -oE '[0-9]+x[0-9]+' | head -n1 | cut -d'x' -f1)
screen_height=$(xrandr --current | grep 'primary\|connected' | grep -oE '[0-9]+x[0-9]+' | head -n1 | cut -d'x' -f2)

# Define window size
width=800
height=500

# Calculate bottom-right position with margins
margin_x=30
margin_y_bottom=80  # Account for taskbar
x=$((screen_width - width - margin_x))
y=$((screen_height - height - margin_y_bottom))

# Ensure positive coordinates
[ $x -lt 0 ] && x=0
[ $y -lt 0 ] && y=0

# Launch dialog (X11 only)
yad --info --text="Positioned dialog" --geometry="${width}x${height}+${x}+${y}"
```

**Note**: This only works on X11. On Wayland, the compositor will ignore `+X+Y` coordinates and center the window or place it according to its own rules.

---

## 9. Implementation in This Project

### Current Approach (Post-Enhancement #24 - Implemented)

**Unified Priority**: YAD → Zenity → KDialog (all environments, all components)

**Popup Warnings** (`sleep-warning.sh`): Unified priority
- **All Environments**: yad → zenity → kdialog
- Same priority regardless of Wayland/Gamescope, KDE, or X11

**Configuration Wizard** (`configure.sh`): Dialog abstraction layer
- Uses `lib/configure-dialogs.sh` abstraction functions
- Tool-agnostic interface: `show_info_dialog()`, `show_question_dialog()`, `show_entry_dialog()`, `show_list_dialog()`, `show_multi_column_list_dialog()`, `show_text_info_dialog()`
- Unified priority: yad → zenity → kdialog

**Positioning Strategy** (Simplified):
- Only `center` and `top-left` positions supported
- Center: Default fallback, works with all tools
- Top-left: Simple fixed margins, no window size calculations required
- Removed complex corner positions (top-right, bottom-left, bottom-right, top-center, bottom-center)

### Previous Approach (Pre-Enhancement #24)

**Popup Warnings** (`sleep-warning.sh`): Environment-aware priority
- **Wayland/Gamescope**: yad → kdialog → zenity
- **KDE Desktop**: kdialog → yad → zenity
- **Default (X11)**: zenity → yad → kdialog

**Configuration Wizard** (`configure.sh`): Zenity only (hardcoded)

**Positioning**: Supported center, top-left, top-right, bottom-left, bottom-right, top-center, bottom-center
- **YAD**: Use native `--geometry` flag (center/top-left)
- **Zenity/KDialog**: Use post-creation repositioning via `wmctrl` or `xdotool` (X11 only, top-left only)
- **Top-left**: Simplest positioning (fixed margins only, no window size calculations needed)

```bash
# From lib/window-management.sh
reposition_popup_window() {
    local window_title="$1"
    local window_tool="$2"  # wmctrl or xdotool
    local position="$3"
    local width="$4"
    local height="$5"
    
    # Wait for window to appear
    sleep 0.3
    
    # Calculate coordinates
    local coords
    coords=$(calculate_popup_geometry "${position}" "${width}" "${height}" "true")
    local x=$(echo "${coords}" | cut -d' ' -f1)
    local y=$(echo "${coords}" | cut -d' ' -f2)
    
    # Move window
    case "${window_tool}" in
        wmctrl)
            wmctrl -r "${window_title}" -e "0,${x},${y},${width},${height}"
            ;;
        xdotool)
            xdotool search --name "${window_title}" windowmove "${x}" "${y}"
            ;;
    esac
}
```

### Size Configuration

```bash
# From lib/config.sh
get_popup_dimensions() {
    local size="${1:-medium}"
    local width height
    
    case "${size}" in
        small)
            width=400
            height=250
            ;;
        medium)
            width=800
            height=500
            ;;
        large)
            width=2000
            height=1350
            ;;
        *x*)
            # Custom size (e.g., "450x300")
            width=$(echo "${size}" | cut -d'x' -f1)
            height=$(echo "${size}" | cut -d'x' -f2)
            ;;
        *)
            # Default to medium
            width=800
            height=500
            ;;
    esac
    
    echo "${width} ${height}"
}
```

### Environment Detection

```bash
# Detect if we're in a Wayland or Gamescope environment
if [ "$XDG_SESSION_TYPE" = "wayland" ] || pgrep -x gamescope >/dev/null; then
    # Wayland/Gamescope: Simplified approach
    # - Don't attempt precise positioning
    # - Use --center or --modal flags
    # - Rely on compositor placement
else
    # X11: Full control
    # - Use calculated coordinates
    # - Apply repositioning after creation
    # - Enforce stay-on-top with wmctrl/xdotool
fi
```

---

## 10. Best Practices Summary

### For Maximum Compatibility
1. **Prefer Zenity** as default (pre-installed on SteamOS)
2. **Fall back to KDialog** on KDE environments
3. **Use YAD only** if installed and complex features needed

### For SteamOS Specifically
1. **Don't assume YAD** is available
2. **Use `--modal` flag** to prevent dialogs being hidden behind games
3. **Keep dialogs simple** in Gaming Mode (complex layouts may break)
4. **Test on actual hardware** (Steam Deck's 800p display behaves differently than desktop)

### For Sizing
1. **Over-provision dimensions** by 20% width, 100px height to account for decorations
2. **Accept that Zenity/KDialog will shrink** for short content
3. **Use YAD with `--fixed`** if exact size is critical

### For Positioning (X11 only)
1. **Use YAD's native `--geometry`** when possible
2. **Implement bounds checking** to prevent off-screen windows
3. **Account for taskbars/panels** (80-100px bottom margin)
4. **Avoid top-left if there's a panel** (60px top margin)

### For Wayland/Gamescope
1. **Abandon precise positioning** (compositor controls placement)
2. **Use `--center` flag** for predictable centering
3. **Test in actual Gamescope** (behavior differs from standard Wayland)
4. **Consider notifications** (`notify-send`) instead of dialogs for non-critical alerts

---

## 11. References and Resources

### Official Documentation
- [Zenity Manual](https://help.gnome.org/users/zenity/stable/)
- [KDialog Documentation](https://develop.kde.org/docs/administration/kdialog/)
- [YAD Project](https://github.com/v1cont/yad)

### Wayland Protocol
- [Wayland Book: XDG-Shell Positioners](https://wayland-book.com/xdg-shell-in-depth/positioners.html)

### SteamOS and Gamescope
- [SteamOS Documentation](https://store.steampowered.com/steamos)
- [Gamescope GitHub](https://github.com/ValveSoftware/gamescope)

### Related Files in This Project
- `lib/desktop-environment.sh`: Dialog tool detection
- `lib/window-management.sh`: Positioning and geometry calculation
- `lib/popup-display.sh`: Popup display implementation
- `dev-docs/STEAMOS_GAMING_MODE.md`: SteamOS-specific considerations
- `dev-docs/info/wayland-gamescope-window-tools.md`: Wayland window management

---

## 12. Testing Recommendations

### Basic Functionality Test

```bash
# Test each tool with same content
test_message="This is a test dialog.\nIt contains multiple lines.\nDoes sizing work correctly?"

echo "Testing Zenity..."
zenity --info --title="Zenity Test" --text="$test_message" --width=600 --height=400

echo "Testing KDialog..."
kdialog --title "KDialog Test" --msgbox "$test_message"

echo "Testing YAD..."
yad --info --title="YAD Test" --text="$test_message" --width=600 --height=400 --center
```

### Environment Detection Test

```bash
echo "Desktop Environment: $XDG_CURRENT_DESKTOP"
echo "Session Type: $XDG_SESSION_TYPE"
echo "Gamescope running: $(pgrep -x gamescope >/dev/null && echo 'Yes' || echo 'No')"
echo "Available tools: $(detect_dialog_tool)"
```

### Sizing Behavior Test

```bash
# Test with very short text
zenity --info --text="Hi" --width=800 --height=600
# Observe: Window shrinks significantly

# Test with very long text
zenity --info --text="$(seq 1 100 | tr '\n' ' ')" --width=300 --height=200
# Observe: Window expands height to accommodate wrapped text

# Test YAD with scrollbars
yad --info --text="$(seq 1 100 | tr '\n' ' ')" --width=300 --height=200 --fixed
# Observe: Window stays 300x200, shows scrollbar
```

---

---

## 13. Chosen Priority for This Project

### Unified Priority: YAD → Zenity → KDialog

**Decision**: This project uses a **unified priority** across all environments: **YAD → Zenity → KDialog**, regardless of desktop environment (including KDE).

### Rationale

#### Why Prefer YAD (If Installed)?

**Technical Advantages**:
1. **Native Positioning**: `--geometry=WIDTHxHEIGHT+X+Y` works on X11 (doesn't require post-creation hacks). With simplified positioning (center/top-left only), top-left positioning is particularly simple (fixed margins, no window size calculations needed).
2. **Size Control**: Actually enforces requested dimensions (adds scrollbars if needed)
3. **Window Management**: `--on-top`, `--undecorated`, `--sticky`, `--fixed` flags
4. **Complex Forms**: Native support for forms, tabs, notebooks, lists
5. **Live Updates**: Can update dialog content via named pipes
6. **Custom Buttons**: Define button labels and exit codes

**No Technical Downsides** (if installed):
- Works on X11, Wayland (via XWayland), and Gamescope
- GTK-based (same as Zenity, no additional toolkit overhead)
- Mature and stable (fork of Zenity with years of development)

#### Why Zenity Second?

**Advantages**:
- **Pre-installed** on nearly all systems (GNOME/GTK base)
- **Lightweight**: Minimal dependencies
- **Wayland Native**: Excellent modern compositor support
- **SteamOS**: Guaranteed to be present

**Disadvantages**:
- No native positioning support (requires `xdotool`/`wmctrl` workarounds). With simplified positioning (center/top-left only), top-left repositioning is straightforward (fixed margins only).
- Unpredictable sizing (shrinks/expands to fit content)
- Very limited dialog types
- No complex form support

#### Why KDialog Last?

**Advantages**:
- **KDE Native**: Beautiful integration on Plasma desktops
- **Qt Features**: File pickers, color choosers, passive popups
- **D-Bus Integration**: Can integrate with KDE services

**Disadvantages**:
- **Heavier**: Requires Qt/KDE libraries (larger dependency footprint on non-KDE systems)
- **Size Behavior**: Aggressively shrinks to content, ignores geometry hints
- **Wayland Limitations**: Geometry often ignored even more than Zenity
- **Less Universal**: Not as commonly pre-installed outside KDE environments

### Why Not Prefer KDialog on KDE?

Originally considered preferring KDialog on KDE for visual consistency, but **YAD's superior capabilities** (native positioning, reliable sizing, better window management) outweigh visual consistency considerations. All environments, including KDE, use the unified priority: **YAD → Zenity → KDialog**.

### Positioning Simplification

As part of the unified priority implementation, popup positioning options are simplified to only **center** and **top-left**:
- **Top-left**: Simplest positioning (requires only fixed margins, no window size calculations)
- **Center**: Default fallback (standard dialog placement)
- **Removed**: `top-right`, `bottom-left`, `bottom-right`, `top-center`, `bottom-center` (eliminates complex screen dimension calculations and edge cases)

### Implementation Status

**Current State** (post-enhancement #24 - **IMPLEMENTED**):
- **All dialogs**: Unified YAD → Zenity → KDialog priority ✅
- **All environments**: Same priority regardless of desktop environment ✅
- **Positioning**: Simplified to center and top-left only ✅
- **Configuration wizard**: Dialog abstraction layer with tool-agnostic functions ✅
- **Multi-column lists**: Abstraction function supports all three tools ✅

See [enhancement-24-unified-dialog-priority-yad-first.md](../enhancements/enhancement-24-unified-dialog-priority-yad-first.md) for implementation details and checklist.

---

## Conclusion

**For this project (SteamOS sleep warning system)**:

**Current Implementation** (post-enhancement #24 - **IMPLEMENTED**):
1. **Primary**: YAD (superior capabilities when available) ✅
2. **Secondary**: Zenity (guaranteed fallback, pre-installed on SteamOS) ✅
3. **Tertiary**: KDialog (last resort fallback) ✅

**Previous Implementation** (pre-enhancement #24):
1. **Primary**: Zenity (guaranteed availability, reliable in Gaming Mode)
2. **Secondary**: KDialog (better for Desktop Mode, native to KDE)
3. **Tertiary**: YAD (most powerful, but requires manual installation)

**Key takeaway**: The chosen priority (YAD → Zenity → KDialog) prioritizes **technical capabilities** (native positioning, reliable sizing, window management) over **visual consistency** or **environment-specific preferences**. This ensures the best user experience when advanced tools are available, while maintaining robust fallback support for all systems.
