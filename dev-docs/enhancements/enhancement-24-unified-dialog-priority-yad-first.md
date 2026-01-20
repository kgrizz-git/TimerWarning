# Enhancement #24: Unified Dialog Tool Priority (YAD → Zenity → KDialog)

**Status**: Proposed  
**Priority**: Medium  
**Complexity**: Medium  
**Affects**: All dialog interactions (popup warnings and configuration wizard)

---

## Summary

Standardize dialog tool selection across both `sleep-warning.sh` (popup warnings) and `configure.sh` (configuration wizard) to always prefer **YAD → Zenity → KDialog** in all environments, including KDE. This leverages YAD's superior capabilities (native positioning, reliable sizing, better window management) when available while maintaining fallback compatibility. YAD's technical advantages take precedence over visual consistency considerations.

**Positioning Simplification**: As part of this enhancement, popup positioning options will be simplified to only **center** and **top-left**. This simplification reduces complexity in position calculations (top-left requires no window size knowledge, only simple margins) and eliminates edge cases with other corner positions that require complex screen dimension calculations.

---

## Current Implementation

### sleep-warning.sh (via desktop-environment.sh)

**Current Priority** (environment-aware):
- **Wayland/Gamescope**: yad → kdialog → zenity
- **KDE Desktop**: kdialog → yad → zenity
- **Default (X11)**: zenity → yad → kdialog

**Positioning Behavior**:
- **YAD**: Uses native `--geometry=WIDTHxHEIGHT+X+Y` flag + post-creation repositioning as backup
- **Zenity**: Post-creation repositioning only (no native positioning support)
- **KDialog**: Post-creation repositioning only (no size/position control)

**Note**: Positioning options will be simplified to only **center** and **top-left** as part of this enhancement. Top-left positioning is the simplest (requires only fixed margins, no window size calculations), while center is the default fallback.

From `lib/popup-display.sh`:
```bash
case "${dialog_tool}" in
    zenity)
        # zenity doesn't support position natively, only size
        zenity --warning --title="${window_title}" --text="${message}" \
            --modal --width="${width}" --height="${height}" 2>/dev/null &
        popup_pid=$!
        
        # Reposition window after creation if position is top-left
        if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
            reposition_popup_window "${window_title}" "${window_tool}" \
                "${popup_position}" "${width}" "${height}" &
        fi
        ;;
    yad)
        # yad supports both size and position via --geometry
        local geometry
        geometry=$(calculate_popup_geometry "${popup_position}" "${width}" "${height}")
        
        yad --warning --title="${window_title}" --text="${message}" \
            --modal --geometry="${geometry}" --on-top 2>/dev/null &
        popup_pid=$!
        
        # Also reposition as backup in case --geometry doesn't work properly (top-left only)
        if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
            reposition_popup_window "${window_title}" "${window_tool}" \
                "${popup_position}" "${width}" "${height}" &
        fi
        ;;
    kdialog)
        # kdialog has no size/position control
        kdialog --title "${window_title}" --sorry "${message}" 2>/dev/null &
        popup_pid=$!
        sleep 0.2
        
        # Reposition window after creation if position is top-left
        if [ -n "${popup_pid}" ] && [ -n "${window_tool}" ] && \
           [ "${popup_position}" = "top-left" ]; then
            reposition_popup_window "${window_title}" "${window_tool}" \
                "${popup_position}" "${width}" "${height}" &
        fi
        ;;
esac
```

### configure.sh (Configuration Wizard)

**Current Implementation**: Hardcoded to **Zenity only**

From `configure.sh`:
```bash
# Requirements:
# - bash
# - zenity (preferred) or fallback to text prompts
#
# Options:
#   --text, --no-gui    Force text mode (disable GUI)
#   --gui               Force GUI mode (requires zenity)
```

From `lib/configure-core.sh`:
```bash
has_zenity() {
    command -v zenity >/dev/null 2>&1
}
```

**All GUI operations** in configure library modules check `has_zenity` directly:
- `configure-ui.sh`: Confirmation dialogs, help displays
- `configure-input.sh`: Time input, size selection, position selection
- `configure-display.sh`: Menu navigation, visual grid display

---

## Rationale for YAD → Zenity → KDialog Priority

**Summary**: YAD provides superior technical capabilities (native positioning, reliable sizing, better window management) that outweigh visual consistency considerations. Zenity serves as a reliable fallback (pre-installed on most systems, including SteamOS). KDialog is the last resort (heavier dependencies, less universal availability).

**Detailed comparison**: See [dialog-tools-options.md](../info/dialog-tools-options.md#13-chosen-priority-for-this-project) for comprehensive rationale, advantages/disadvantages of each tool, and why this priority was chosen over environment-specific alternatives.

**Key Points**:
- **YAD First**: Native positioning, reliable sizing, advanced window management (when available)
- **Zenity Second**: Guaranteed fallback, pre-installed on SteamOS, lightweight
- **KDialog Last**: Heavier dependencies, less universal, but provides KDE integration when needed
- **Unified Priority**: Same priority across all environments (including KDE) - technical advantages take precedence over visual consistency

---

## Proposed Changes

### 1. Update Dialog Tool Priority in `lib/desktop-environment.sh`

**Current**:
```bash
check_dialog_tool() {
    local env_type="$1"

    # Wayland/gamescope: prefer yad for better Wayland behavior
    if [ "${env_type}" = "wayland" ] || [ "${env_type}" = "gamescope" ]; then
        if command -v yad >/dev/null 2>&1; then
            echo "yad"
            return 0
        elif command -v kdialog >/dev/null 2>&1; then
            echo "kdialog"
            return 0
        elif command -v zenity >/dev/null 2>&1; then
            echo "zenity"
            return 0
        fi
        return 1
    fi

    # KDE: prefer kdialog for KDE integration
    if is_kde; then
        if command -v kdialog >/dev/null 2>&1; then
            echo "kdialog"
            return 0
        elif command -v yad >/dev/null 2>&1; then
            echo "yad"
            return 0
        elif command -v zenity >/dev/null 2>&1; then
            echo "zenity"
            return 0
        fi
        return 1
    fi

    # Default: zenity -> yad -> kdialog
    if command -v zenity >/dev/null 2>&1; then
        echo "zenity"
        return 0
    elif command -v yad >/dev/null 2>&1; then
        echo "yad"
        return 0
    elif command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"
        return 0
    fi

    return 1
}
```

**Proposed**:
```bash
check_dialog_tool() {
    local env_type="$1"

    # Unified priority for ALL environments: YAD -> Zenity -> KDialog
    # YAD's superior capabilities (native positioning, reliable sizing, window management)
    # outweigh visual consistency considerations, even on KDE
    if command -v yad >/dev/null 2>&1; then
        echo "yad"
        return 0
    elif command -v zenity >/dev/null 2>&1; then
        echo "zenity"
        return 0
    elif command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"
        return 0
    fi

    return 1
}
```

**Changes**:
- Remove all environment-specific cases (Wayland/Gamescope, KDE)
- Unified priority for **ALL environments**: **YAD → Zenity → KDialog**
- Much simpler, more maintainable logic
- YAD's technical advantages take precedence over visual consistency

### 2. Extend configure.sh to Support All Three Dialog Tools

#### 2.1 Update Main Script (`configure.sh`)

**Change documentation**:
```bash
# Requirements:
# - bash
# - Dialog tool: yad (preferred), zenity, or kdialog (fallback to text prompts if none available)
#
# Options:
#   --text, --no-gui    Force text mode (disable GUI)
#   --gui               Force GUI mode (requires yad, zenity, or kdialog)
```

**Update error messages**:
```bash
if has_gui; then
    use_gui="true"
else
    echo "Error: --gui flag specified but no dialog tool is available." >&2
    echo "Please install yad, zenity, or kdialog, or use --text mode." >&2
    exit 1
fi
```

#### 2.2 Update `lib/configure-core.sh`

**Add unified dialog detection**:
```bash
# Check if any dialog tool is available
has_dialog_tool() {
    check_dialog_tool "$(detect_display_environment)"
}

# Get the currently selected dialog tool
get_dialog_tool() {
    check_dialog_tool "$(detect_display_environment)"
}

# Legacy function for backward compatibility
has_zenity() {
    local tool
    tool=$(get_dialog_tool)
    [ -n "${tool}" ]
}

# Check if GUI is available
has_gui() {
    [ -n "${DISPLAY:-}" ] && has_dialog_tool
}
```

#### 2.3 Create Abstraction Functions in New Module: `lib/configure-dialogs.sh`

This module provides tool-agnostic dialog functions that configure modules can use:

```bash
#!/bin/bash

###############################################################################
# Sleep Warning System - Configure Dialogs Module
#
# This module provides tool-agnostic dialog functions that work with
# YAD, Zenity, or KDialog automatically based on what's available.
#
# Dependencies:
#   - configure-core.sh (for get_dialog_tool)
#   - desktop-environment.sh (for check_dialog_tool)
#
# Functions:
#   - show_info_dialog()      - Information message
#   - show_question_dialog()  - Yes/No question
#   - show_entry_dialog()     - Text input
#   - show_list_dialog()      - Selection from list
#   - show_text_info_dialog() - Display text file/content
###############################################################################

# Show information dialog
show_info_dialog() {
    local title="$1"
    local text="$2"
    local width="${3:-500}"
    local height="${4:-200}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            yad --info --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --button="OK:0" 2>/dev/null
            ;;
        zenity)
            zenity --info --title="${title}" --text="${text}" \
                --width="${width}" 2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" --msgbox "${text}" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Show yes/no question dialog
show_question_dialog() {
    local title="$1"
    local text="$2"
    local ok_label="${3:-Yes}"
    local cancel_label="${4:-No}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            yad --question --title="${title}" --text="${text}" \
                --button="${ok_label}:0" --button="${cancel_label}:1" \
                2>/dev/null
            ;;
        zenity)
            zenity --question --title="${title}" --text="${text}" \
                --ok-label="${ok_label}" --cancel-label="${cancel_label}" \
                2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" --yesno "${text}" \
                --yes-label "${ok_label}" --no-label "${cancel_label}" \
                2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Show text entry dialog
show_entry_dialog() {
    local title="$1"
    local text="$2"
    local default_value="${3:-}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            yad --entry --title="${title}" --text="${text}" \
                --entry-text="${default_value}" 2>/dev/null
            ;;
        zenity)
            zenity --entry --title="${title}" --text="${text}" \
                --entry-text="${default_value}" 2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" --inputbox "${text}" "${default_value}" \
                2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Show list selection dialog
show_list_dialog() {
    local title="$1"
    local text="$2"
    local width="$3"
    local height="$4"
    shift 4
    local items=("$@")
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            # YAD uses --list with column format
            # Convert items array to column format: "Column1" "value1" "Column2" "value2"
            local yad_args=()
            for item in "${items[@]}"; do
                yad_args+=("${item}")
            done
            yad --list --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --column="Option" "${yad_args[@]}" \
                --print-column=1 2>/dev/null
            ;;
        zenity)
            # Zenity expects: --column="Name" item1 item2 item3
            zenity --list --title="${title}" --text="${text}" \
                --width="${width}" --height="${height}" \
                --column="Option" "${items[@]}" 2>/dev/null
            ;;
        kdialog)
            # KDialog uses --menu format: tag1 "item1" tag2 "item2"
            local kdialog_args=()
            local tag=1
            for item in "${items[@]}"; do
                kdialog_args+=("${tag}" "${item}")
                ((tag++))
            done
            local result
            result=$(kdialog --title "${title}" --menu "${text}" \
                "${kdialog_args[@]}" 2>/dev/null)
            # Convert tag back to item
            if [ -n "${result}" ]; then
                echo "${items[$((result - 1))]}"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Show text information dialog (for help, summaries, etc.)
show_text_info_dialog() {
    local title="$1"
    local text="$2"
    local width="${3:-600}"
    local height="${4:-500}"
    
    local tool
    tool=$(get_dialog_tool)
    
    case "${tool}" in
        yad)
            echo "${text}" | yad --text-info --title="${title}" \
                --width="${width}" --height="${height}" \
                --button="Close:0" 2>/dev/null
            ;;
        zenity)
            echo "${text}" | zenity --text-info --title="${title}" \
                --width="${width}" --height="${height}" \
                --font="monospace" 2>/dev/null
            ;;
        kdialog)
            kdialog --title "${title}" --textbox /dev/stdin \
                "${width}" "${height}" <<< "${text}" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}
```

#### 2.4 Update All Configure Library Modules

Replace direct `zenity` calls with abstraction functions:

**Example from `lib/configure-ui.sh`**:

**Before**:
```bash
confirm_cancel() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        zenity --question \
            --title="Cancel Configuration?" \
            --text="Are you sure you want to cancel?\n\nAll unsaved changes will be lost." \
            --ok-label="Yes, Cancel" \
            --cancel-label="No, Continue" \
            2>/dev/null
        return $?
    else
        # Text mode
        ...
    fi
}
```

**After**:
```bash
confirm_cancel() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Cancel Configuration?" \
            "Are you sure you want to cancel?\n\nAll unsaved changes will be lost." \
            "Yes, Cancel" \
            "No, Continue"
        return $?
    else
        # Text mode
        ...
    fi
}
```

**Modules to Update**:
- `lib/configure-ui.sh`: Replace 7 zenity calls
- `lib/configure-input.sh`: Replace 6 zenity calls
- `lib/configure-display.sh`: Replace 4 zenity calls

### 3. Simplify Positioning Options

**Update `lib/window-management.sh`**:
- Modify `calculate_popup_geometry()` to only support `center` and `top-left` positions
- Remove support for `top-right`, `bottom-left`, `bottom-right`, `top-center`, `bottom-center`
- Simplify top-left calculation (already simple - just fixed margins, no window size needed)

**Update `lib/config.sh`**:
- Modify `get_popup_position()` validation to only accept `center` or `top-left`
- Update default value if needed

**Update `lib/configure-input.sh`**:
- Update position selection dialog to only offer `center` and `top-left` options
- Remove other position options from the menu

**Update `lib/popup-display.sh`**:
- Update repositioning logic to only check for `top-left` (not `!= center`)
- Simplify conditional checks

**Rationale**: Top-left positioning is the simplest (requires only fixed margins, no window size calculations), while center is the default fallback. This eliminates complex screen dimension calculations for corner positions and reduces edge cases.

### 4. Update Documentation

**Files to Update**:
- `README.md`: Update dependencies to show YAD as preferred
- `GETTING_STARTED.md`: Add YAD installation instructions
- `user-docs/CONFIGURATION.md`: Mention dialog tool priority and simplified positioning options (center/top-left only)
- `dev-docs/TECHNICAL_DETAILS.md`: Document new unified priority system and positioning simplification
- `dev-docs/info/dialog-tools-options.md`: Update implementation section with positioning simplification

---

## Benefits

1. **Better User Experience**: YAD provides more predictable sizing, native positioning, and better window management
2. **Unified Behavior**: Both popup warnings and configuration wizard use the same tool selection logic
3. **Simpler Code**: Remove all environment-specific branching in dialog tool selection
4. **Simplified Positioning**: Reducing positioning options to center and top-left eliminates complex calculations and edge cases. Top-left positioning is particularly simple (fixed margins only, no window size needed).
5. **Backward Compatible**: Still supports systems with only Zenity or KDialog installed
6. **Consistent Priority**: Same tool selection logic everywhere, regardless of desktop environment

---

## Implementation Phases

### Phase 1: Update Dialog Tool Priority and Simplify Positioning (Low Risk)
- Modify `lib/desktop-environment.sh` `check_dialog_tool()` function
- Remove all environment-specific cases (Wayland/Gamescope, KDE)
- Implement unified YAD → Zenity → KDialog priority for all environments
- Simplify positioning options to only center and top-left
- Update `lib/window-management.sh` `calculate_popup_geometry()` function
- Update `lib/config.sh` position validation
- Update `lib/configure-input.sh` position selection menu
- Update `lib/popup-display.sh` repositioning conditionals
- Test popup warnings with all three tools on various environments
- Test both center and top-left positioning options

### Phase 2: Create Dialog Abstraction Layer (Medium Risk)
- Create `lib/configure-dialogs.sh` with abstraction functions
- Add to `configure.sh` sourced modules
- Create test script to verify all dialog types work with all tools

### Phase 3: Update Configure Modules (Medium Risk)
- Update `lib/configure-core.sh` with new detection functions
- Update `lib/configure-ui.sh` to use abstractions
- Update `lib/configure-input.sh` to use abstractions
- Update `lib/configure-display.sh` to use abstractions
- Test complete configuration workflow with all three tools

### Phase 4: Documentation (Low Risk)
- Update all documentation files
- Update README and GETTING_STARTED
- Update technical documentation

---

## Testing Requirements

### Test Matrix

| Tool | Popup Warnings | Configure Wizard | X11 Positioning | Wayland/Gamescope |
| :--- | :--- | :--- | :--- | :--- |
| **YAD** | ✅ Already tested | 🔲 Needs testing | ✅ Already tested | ✅ Already tested |
| **Zenity** | ✅ Already tested | ✅ Already tested | ✅ Already tested | ✅ Already tested |
| **KDialog** | ✅ Already tested | 🔲 Needs testing | ✅ Already tested | 🔲 Needs testing |

### Test Scenarios

1. **YAD Installed** (Primary path):
   - Run `./sleep-warning.sh` manually to test popup
   - Run `./configure.sh` to test full configuration wizard
   - Verify positioning works correctly (test both center and top-left positions)
   - Verify window size matches configuration
   - Verify top-left positioning uses simple fixed margins (no window size calculations)

2. **Only Zenity Installed** (Common fallback):
   - Uninstall/hide YAD temporarily: `sudo mv $(which yad) $(which yad).backup`
   - Test popup warnings
   - Test configuration wizard
   - Restore YAD: `sudo mv $(which yad).backup $(which yad)`

3. **Only KDialog Installed** (Rare fallback):
   - Hide both YAD and Zenity
   - Test popup warnings
   - Test configuration wizard

4. **KDE Environment** (Verify unified priority):
   - Test on KDE Plasma with all three tools installed
   - Verify YAD is preferred (not KDialog)
   - Verify fallback chain works (YAD → Zenity → KDialog)

5. **No GUI Tools** (Text fallback):
   - Hide all three tools
   - Test `./configure.sh --text`
   - Verify text mode still works

---

## Risks and Mitigations

### Risk 1: YAD Not Available on SteamOS
**Mitigation**: This is already the case. The priority system ensures Zenity (which IS pre-installed) is used as fallback. This change doesn't break anything; it just uses YAD when a user has manually installed it.

### Risk 2: YAD Dialogs Look Different
**Mitigation**: YAD is a fork of Zenity using the same GTK toolkit, so visual appearance is nearly identical. Test extensively to ensure consistency.

### Risk 3: Breaking Configure Wizard
**Mitigation**: Phase the implementation carefully. Create abstraction layer first, test it thoroughly, then migrate modules one at a time. Keep ability to force text mode as escape hatch.

### Risk 4: KDE Visual Consistency
**Mitigation**: YAD uses GTK (same as Zenity) and integrates well with KDE Plasma. The technical advantages (native positioning, reliable sizing) outweigh minor visual consistency differences. Test on KDE to ensure YAD dialogs look acceptable.

---

## Alternatives Considered

### Alternative 1: Keep Current Mixed Priority
**Rejected**: Having different priorities for popup vs. configure is confusing and harder to maintain. Unified approach is cleaner.

### Alternative 2: Always Prefer Zenity for Compatibility
**Rejected**: Zenity has clear limitations (no native positioning, unpredictable sizing). When YAD is available, we should use its superior capabilities.

### Alternative 3: Make Dialog Tool User-Configurable
**Rejected**: Adds unnecessary complexity. Auto-detection based on availability and environment is sufficient for 99% of users.

---

## Related Enhancements

- **Enhancement #2**: Dialog Tool Priority System (original implementation)
- **Enhancement #2a**: Extend Dialog Tool Priority to Config Wizard (proposed here)
- **Enhancement #3**: Enhanced Window Size Options (benefits from YAD's better size control)
- **Enhancement #14**: Immovable Popup Window (works better with YAD's window management flags)

---

## References

- Current implementation: `lib/desktop-environment.sh` (`check_dialog_tool()`)
- Popup display: `lib/popup-display.sh` (`show_warning()`)
- Configure wizard: `configure.sh` and `lib/configure-*.sh` modules
- Dialog comparison: `dev-docs/info/dialog-tools-options.md`

---

## Conclusion

This enhancement unifies dialog tool selection across the entire project, preferring YAD's superior capabilities when available while maintaining robust fallback support. The implementation is phased to minimize risk and can be tested incrementally.

**Recommendation**: Implement in phases, starting with Phase 1 (dialog priority update) in the next development cycle, followed by Phases 2-3 (configure wizard abstraction) as a separate effort.
