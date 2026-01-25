# Enhancement 29: kdialog Window Size Control

- **Description**: Investigate and implement methods to control window size for kdialog warning popups, since `--geometry` is not supported for `--sorry` dialogs. If implemented, make sure kdialog popup is never over 95% of screen, similar to yad and zenity.
- **Files Affected**: `lib/popup-display.sh`, `lib/config.sh` (if adding new dialog type support)
- **Priority**: Low (kdialog is last-resort fallback, YAD and Zenity already support size control)
- **Status**: Research Complete - Proposals Documented
- **Current Implementation**:
  - kdialog uses `--sorry` dialog type for warning popups
  - No size control attempted (comment notes that `--geometry` is not supported for `--sorry`)
  - Window positioning (top-left) works via post-creation repositioning using window manager tools

---

## Research Findings

### kdialog `--geometry` Support

**Syntax**: `--geometry WIDTHxHEIGHT+X+Y` (e.g., `--geometry 500x300+100+100`)

**Supported Dialog Types**:
- ✅ `--textbox` - Geometry option works
- ✅ `--textinputbox` - Geometry option works
- ❌ `--msgbox` - Geometry silently ignored
- ❌ `--sorry` - Geometry silently ignored (used in our codebase)
- ❌ `--warning` - Geometry silently ignored
- ❌ `--error` - Geometry silently ignored
- ❌ `--progressbar` - Geometry silently ignored

**Known Limitations**:
- This is a longstanding limitation in kdialog (reported since 2004, Gentoo bug #71798, KDE bug #87389)
- The `--geometry` option is silently ignored for message box types
- Official KDE documentation does not mention `--geometry` for basic message boxes
- Even when `--geometry` works (for `--textbox`), kdialog may still shrink dialogs to fit content

**Sources**:
- KDE Official Documentation: https://develop.kde.org/docs/administration/kdialog/
- Stack Overflow: https://stackoverflow.com/questions/20003080/how-do-i-make-the-kdialog-a-certain-width
- Gentoo Bug Report: https://bugs.gentoo.org/71798

---

## Proposed Solutions

### Option 1: Use `--textbox` Instead of `--sorry`

**Description**: Replace `--sorry` dialog with `--textbox` dialog, which supports `--geometry`.

**Implementation**:
```bash
# Current (no size control):
kdialog --title "${window_title}" --sorry "${message}"

# Proposed (with size control):
kdialog --title "${window_title}" \
    --geometry "${width}x${height}" \
    --textbox /dev/stdin "${width}" "${height}" <<< "${message}"
```

**Pros**:
- ✅ Native size control via `--geometry` option
- ✅ kdialog officially supports `--geometry` for `--textbox`
- ✅ Can specify both geometry and explicit width/height parameters
- ✅ More reliable than workarounds

**Cons**:
- ❌ **Visual Difference**: `--textbox` shows a scrollable text viewer, not a warning-style message box
- ❌ **User Experience**: Different appearance from `--sorry` (no warning icon, different styling)
- ❌ **Behavioral Difference**: `--textbox` is designed for displaying file contents, not warnings
- ❌ **Inconsistency**: Different look/feel compared to YAD/Zenity warning dialogs
- ❌ **May Still Shrink**: Even with `--geometry`, kdialog may shrink to fit content

**Feasibility**: ✅ **Technically Feasible** - Easy to implement, but changes user experience

**Recommendation**: ⚠️ **Not Recommended** - Changes the visual appearance and user experience significantly

---

### Option 2: Post-Creation Window Resizing with Window Manager Tools

**Description**: Use `wmctrl` or `xdotool` to resize the kdialog window after it's created.

**Implementation**:
```bash
# Launch kdialog
kdialog --title "${window_title}" --sorry "${message}" &
popup_pid=$!
sleep 0.3  # Wait for window to appear

# Resize using window manager tool
if command -v wmctrl >/dev/null 2>&1; then
    wmctrl -r "${window_title}" -e 0,-1,-1,${width},${height}
elif command -v xdotool >/dev/null 2>&1; then
    window_id=$(xdotool search --name "${window_title}" | head -n1)
    xdotool windowsize "${window_id}" "${width}" "${height}"
fi
```

**Pros**:
- ✅ Keeps `--sorry` dialog (maintains visual consistency)
- ✅ Works on X11 (where window manager tools are available)
- ✅ Can control both size and position
- ✅ No change to dialog appearance

**Cons**:
- ❌ **X11 Only**: Doesn't work on Wayland (window manager tools don't work on Wayland)
- ❌ **Timing Issues**: Requires waiting for window to appear (race conditions possible)
- ❌ **Window Title Matching**: Must match exact window title (fragile)
- ❌ **Additional Dependencies**: Requires `wmctrl` or `xdotool` (may not be installed)
- ❌ **Unreliable**: Window may not be found, or resize may fail silently
- ❌ **Already Used for Positioning**: We already use this for top-left positioning, but sizing is less reliable

**Feasibility**: ⚠️ **Partially Feasible** - Works on X11 only, requires additional dependencies, timing-sensitive

**Recommendation**: ⚠️ **Not Recommended** - Too unreliable, X11-only, and we already have issues with window manager tools

---

### Option 3: Text Padding Workaround

**Description**: Add spaces or tabs to the message text to force kdialog to make the window wider.

**Implementation**:
```bash
# Calculate padding needed to approximate desired width
# Rough estimate: ~8-10 pixels per character
padding_chars=$(( (width - 200) / 8 ))  # Rough calculation
padded_message="${message}$(printf "%${padding_chars}s" "")"

kdialog --title "${window_title}" --sorry "${padded_message}"
```

**Pros**:
- ✅ Simple to implement
- ✅ Works with `--sorry` dialog (maintains visual consistency)
- ✅ No additional dependencies
- ✅ Works on all platforms (X11, Wayland, Gamescope)

**Cons**:
- ❌ **Imprecise**: Very rough approximation, not pixel-accurate
- ❌ **Font-Dependent**: Width calculation depends on font, which varies by system
- ❌ **Height Control**: Cannot control height reliably
- ❌ **Visual Artifact**: Extra spaces may be visible or cause text wrapping issues
- ❌ **Hacky Solution**: Not a proper solution, just a workaround

**Feasibility**: ✅ **Technically Feasible** - Easy to implement, but very imprecise and hacky

**Recommendation**: ❌ **Not Recommended** - Too imprecise and hacky, poor user experience

---

### Option 4: Accept Limitation and Document It

**Description**: Keep current implementation (no size control for kdialog), but improve documentation and user messaging.

**Implementation**:
- Update code comments to clearly explain the limitation
- Add note in user documentation that kdialog has limited size control
- Consider showing a warning in configure.sh if user selects kdialog and tries to set custom sizes
- Recommend YAD or Zenity for better size control

**Pros**:
- ✅ **Honest Approach**: Acknowledges the limitation rather than using unreliable workarounds
- ✅ **No Code Complexity**: Keeps code simple and maintainable
- ✅ **Better UX**: Users understand why size control doesn't work with kdialog
- ✅ **Consistent**: kdialog is already last-resort fallback (YAD → Zenity → KDialog priority)

**Cons**:
- ❌ **No Size Control**: Users cannot control kdialog popup size
- ❌ **Inconsistent Experience**: Different behavior between dialog tools

**Feasibility**: ✅ **Highly Feasible** - Just documentation updates

**Recommendation**: ✅ **Recommended** - kdialog is already the last-resort fallback, and YAD/Zenity provide full size control

---

### Option 5: Hybrid Approach - Use `--textbox` with Warning Styling

**Description**: Use `--textbox` for size control, but format the message to look more like a warning.

**Implementation**:
```bash
# Format message with warning indicators
warning_message="⚠️  WARNING  ⚠️

${message}

[OK]"

kdialog --title "${window_title}" \
    --geometry "${width}x${height}" \
    --textbox /dev/stdin "${width}" "${height}" <<< "${warning_message}"
```

**Pros**:
- ✅ Native size control via `--geometry`
- ✅ Can add warning symbols/formatting to message
- ✅ More control over appearance than pure `--textbox`

**Cons**:
- ❌ **Still Not a Warning Dialog**: Looks like a text viewer, not a warning dialog
- ❌ **No System Warning Icon**: Missing system-level warning icon/styling
- ❌ **Scrollable**: Text box is scrollable, which may confuse users expecting a simple warning
- ❌ **Inconsistent**: Different from YAD/Zenity warning dialogs

**Feasibility**: ✅ **Technically Feasible** - Easy to implement

**Recommendation**: ⚠️ **Not Recommended** - Still doesn't look like a proper warning dialog

---

## Comparison Table

| Option | Size Control | Visual Consistency | Platform Support | Reliability | Complexity | Recommendation |
|--------|-------------|-------------------|------------------|-------------|------------|----------------|
| **1. Use --textbox** | ✅ Yes | ❌ Different appearance | ✅ All | ⚠️ May shrink | Low | ⚠️ Not Recommended |
| **2. Window Manager Tools** | ✅ Yes | ✅ Same appearance | ❌ X11 only | ❌ Unreliable | Medium | ⚠️ Not Recommended |
| **3. Text Padding** | ⚠️ Rough | ✅ Same appearance | ✅ All | ❌ Very imprecise | Low | ❌ Not Recommended |
| **4. Accept Limitation** | ❌ No | ✅ Same appearance | ✅ All | ✅ N/A | Very Low | ✅ **Recommended** |
| **5. Hybrid --textbox** | ✅ Yes | ⚠️ Similar | ✅ All | ⚠️ May shrink | Low | ⚠️ Not Recommended |

---

## Recommended Approach

**Option 1 with Fallback: Try `--textbox` for Size Control, Revert to `--sorry` if It Doesn't Work**

### Rationale

1. **Attempt Size Control**: Try using `--textbox` with `--geometry` to provide size control when possible.

2. **Graceful Fallback**: If `--textbox` doesn't work properly (e.g., window doesn't appear, sizing fails, or user experience is poor), automatically fall back to `--sorry` dialog.

3. **Best of Both Worlds**: This approach attempts to provide size control while maintaining a reliable fallback to the standard warning dialog.

4. **User Experience**: Users get size control when it works, but never lose functionality if it doesn't.

### Implementation Approach

1. **Try `--textbox` First**:
   - Use `--textbox` with `--geometry` option to attempt size control
   - Format message appropriately for textbox display (may need warning symbols/formatting)
   - Monitor for success (window appears, process doesn't exit immediately)

2. **Fallback Detection**:
   - Check if `--textbox` dialog actually appeared and is functioning
   - If dialog fails to start, doesn't respect geometry, or has other issues, fall back to `--sorry`
   - Use timeout or process monitoring to detect failures

3. **Revert to `--sorry`**:
   - If `--textbox` approach fails, use the standard `--sorry` dialog (current implementation)
   - Log the fallback for debugging purposes

### Implementation Steps

1. ✅ **Update Code Comments** (Already Done):
   - Updated comment in `lib/popup-display.sh` to clarify that `--geometry` is not supported for `--sorry` dialogs

2. **Implement `--textbox` with Fallback**:
   - Modify `lib/popup-display.sh` kdialog case to try `--textbox` first
   - Add fallback logic to detect if `--textbox` works properly
   - Revert to `--sorry` if `--textbox` fails or doesn't provide acceptable UX
   - Test on various systems to ensure fallback works reliably

3. **Update Documentation**:
   - Document the attempt-and-fallback approach in code comments
   - Note in user documentation that kdialog size control is attempted but may fall back to standard dialog
   - Update developer documentation with implementation details

### Testing Requirements

- Test `--textbox` with `--geometry` on various systems (X11, Wayland, KDE)
- Verify fallback to `--sorry` works when `--textbox` fails
- Ensure popup still appears even if size control doesn't work
- Test with different popup sizes (small, medium, large)
- Verify user experience is acceptable with `--textbox` format

---

## Alternative: Accept Limitation (Previous Recommendation)

**Option 4: Accept Limitation and Document It** was the previous recommendation, but we're now trying the `--textbox` approach with fallback instead. If the `--textbox` approach proves problematic in testing, we can revert to Option 4 (accepting the limitation).

---

## References

- **KDE Official Documentation**: https://develop.kde.org/docs/administration/kdialog/
- **Stack Overflow Discussion**: https://stackoverflow.com/questions/20003080/how-do-i-make-the-kdialog-a-certain-width
- **Gentoo Bug Report**: https://bugs.gentoo.org/71798
- **KDE Bug Report**: https://bugs.kde.org/show_bug.cgi?id=87389
- **Current Codebase**: `lib/popup-display.sh` lines 295-315

---

## Status

- ✅ **Research Complete**: Comprehensive investigation of kdialog geometry support
- ✅ **Code Comment Updated**: Clarified limitation in `lib/popup-display.sh`
- ⏳ **Implementation**: Try `--textbox` with `--geometry` for size control, fallback to `--sorry` if it doesn't work
- ⏳ **Testing**: Test `--textbox` approach on various systems and verify fallback works reliably
