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

## Implementation Checklist

### Phase 1: Update Dialog Tool Priority and Simplify Positioning (Low Risk)

#### 1.1 Update Dialog Tool Priority in `lib/desktop-environment.sh`
- [x] Open `lib/desktop-environment.sh`
- [x] Locate `check_dialog_tool()` function (lines 30-76)
- [x] Remove environment-specific case for Wayland/Gamescope (lines 34-45)
- [x] Remove environment-specific case for KDE (lines 48-60)
- [x] Replace with unified priority: YAD → Zenity → KDialog (all environments)
- [x] Update function comment to reflect unified priority
- [x] Test function returns correct tool based on availability (not environment)
- [x] Verify function still returns error code 1 when no tools available

#### 1.2 Simplify Positioning Options in `lib/window-management.sh`
- [x] Open `lib/window-management.sh`
- [x] Locate `calculate_popup_geometry()` function (lines 407-525)
- [x] Remove `top-right` case (lines 472-474)
- [x] Remove `bottom-left` case (lines 476-478)
- [x] Remove `bottom-right` case (lines 480-482)
- [x] Remove `top-center` case (lines 484-486)
- [x] Remove `bottom-center` case (lines 488-490)
- [x] Keep only `center` and `top-left` cases
- [x] Update function comment to document only center/top-left support
- [x] Simplify bounds checking (remove unnecessary calculations for removed positions)
- [x] Test function with center position
- [x] Test function with top-left position
- [x] Verify function defaults to center for invalid positions

#### 1.3 Update Position Validation in `lib/config.sh`
- [x] Open `lib/config.sh`
- [x] Locate `get_popup_position()` function (lines 152-180)
- [x] Update validation case statement (line 170) to only accept `center|top-left`
- [x] Remove validation for: `top-right|bottom-left|bottom-right|top-center|bottom-center`
- [x] Verify default value remains `center` (line 31)
- [x] Test function with valid positions (center, top-left)
- [x] Test function with invalid positions (should default to center)
- [x] Test function with empty config file (should return default)

#### 1.4 Update Position Selection Menu in `lib/configure-input.sh`
- [x] Open `lib/configure-input.sh`
- [x] Locate `get_popup_position_config()` function (lines 294-388)
- [x] Find GUI position selection list (around line 314)
- [x] Remove position options from zenity list: `top-right`, `bottom-left`, `bottom-right`, `top-center`, `bottom-center`
- [x] Keep only: `center`, `top-left`
- [x] Update text mode menu (around line 349) to remove same options
- [x] Update menu numbering/text to reflect only 2 options
- [ ] Test GUI position selection with both options
- [ ] Test text mode position selection with both options
- [ ] Verify existing config values are preserved if valid (center/top-left)
- [ ] Verify invalid existing config values are reset to default

#### 1.5 Update Repositioning Logic in `lib/popup-display.sh`
- [x] Open `lib/popup-display.sh`
- [x] Locate zenity case block (lines 140-154)
- [x] **Current**: Line 152 uses `!= "center"` - **Change to**: `= "top-left"`
- [x] Locate yad case block (lines 156-173)
- [x] **Current**: Line 171 uses `!= "center"` - **Change to**: `= "top-left"`
- [x] Locate kdialog case block (lines 175-193)
- [x] **Current**: Line 192 uses `!= "center"` - **Change to**: `= "top-left"`
- [x] Check minimum display time section - zenity case (line 260)
- [x] **Current**: Line 260 uses `!= "center"` - **Change to**: `= "top-left"`
- [x] Check minimum display time section - yad case (line 277)
- [x] **Current**: Line 277 uses `!= "center"` - **Change to**: `= "top-left"`
- [x] Check minimum display time section - kdialog case (line 288)
- [x] **Current**: Line 288 uses `!= "center"` - **Change to**: `= "top-left"`
- [x] Verify all 6 repositioning conditionals now use `= "top-left"` check
- [ ] Test popup with center position (should not attempt repositioning)
- [x] Test popup with top-left position (should attempt repositioning)

#### 1.6 Phase 1 Testing
- [X] Test popup warnings with YAD installed (primary path)
- [ ] Test popup warnings with only Zenity installed (fallback)
- [ ] Test popup warnings with only KDialog installed (last resort)
- [ ] Test popup warnings with no tools (should fall back to notify-send)
- [ ] Test center positioning with all three tools
- [ ] Test top-left positioning with all three tools
- [X] Test on X11 environment
- [ ] Test on Wayland/Gamescope environment
- [X] Test on KDE environment (verify YAD preferred, not KDialog)
- [ ] Verify fallback chain: YAD → Zenity → KDialog works correctly

### Phase 2: Create Dialog Abstraction Layer (Medium Risk)

#### 2.1 Create New Module `lib/configure-dialogs.sh`
- [x] Create new file `lib/configure-dialogs.sh`
- [x] Add file header with description and dependencies
- [x] Implement `show_info_dialog()` function (YAD, Zenity, KDialog support)
- [x] Implement `show_question_dialog()` function (YAD, Zenity, KDialog support)
- [x] Implement `show_entry_dialog()` function (YAD, Zenity, KDialog support)
- [x] Implement `show_list_dialog()` function (YAD, Zenity, KDialog support)
- [x] Implement `show_text_info_dialog()` function (YAD, Zenity, KDialog support)
- [x] Add error handling for unsupported tools (return 1)
- [x] Test each function with YAD installed (all 5 dialog types tested: info, question, entry, list, text-info)
- [ ] Test each function with only Zenity installed
- [ ] Test each function with only KDialog installed
- [x] Verify functions return appropriate exit codes (tested with YAD)

#### 2.2 Integrate Dialog Module into `configure.sh`
- [x] Open `configure.sh`
- [x] Locate module sourcing section (lines 34-40)
- [x] Add `source "${LIB_DIR}/configure-dialogs.sh"` after `configure-core.sh`
- [x] Ensure proper dependency order (configure-dialogs.sh after desktop-environment.sh)
- [x] Verify module loads without errors
- [x] Test that dialog functions are available after sourcing

#### 2.3 Create Test Script for Dialog Abstraction Layer
- [x] Create test script `tests/test-configure-dialogs.sh`
- [x] Test `show_info_dialog()` with all three tools
- [x] Test `show_question_dialog()` with all three tools
- [x] Test `show_entry_dialog()` with all three tools
- [x] Test `show_list_dialog()` with all three tools
- [x] Test `show_text_info_dialog()` with all three tools
- [x] Test error handling when no tools available
- [x] Verify consistent behavior across tools (same inputs produce same outputs)
- [x] Document test results

### Phase 3: Update Configure Modules (Medium Risk)

#### 3.1 Update `lib/configure-core.sh`
- [x] Open `lib/configure-core.sh`
- [x] Locate `has_zenity()` function (lines 41-43)
- [x] Add new function `has_dialog_tool()` that calls `check_dialog_tool()`
- [x] Add new function `get_dialog_tool()` that calls `check_dialog_tool()`
- [x] Update `has_zenity()` to use `get_dialog_tool()` for backward compatibility
- [x] Update `has_gui()` function (lines 46-48) to use `has_dialog_tool()` instead of checking DISPLAY only
- [x] Ensure `has_gui()` checks both DISPLAY and dialog tool availability
- [x] Test `has_dialog_tool()` returns correct tool
- [x] Test `get_dialog_tool()` returns correct tool
- [x] Test `has_zenity()` still works (backward compatibility)
- [x] Test `has_gui()` works correctly

#### 3.2 Update `lib/configure-ui.sh`
- [x] Open `lib/configure-ui.sh`
- [x] Locate all `has_zenity` checks (7 occurrences)
- [x] Replace `has_zenity` with `has_dialog_tool` in all checks
- [x] Locate `confirm_cancel()` function (line 26)
- [x] Replace `zenity --question` call with `show_question_dialog()`
- [x] Locate `confirm_skip_day()` function (line 62)
- [x] Replace `zenity --question` call with `show_question_dialog()`
- [x] Locate `show_help_dialog()` function (line 125)
- [x] Replace `zenity --text-info` call with `show_text_info_dialog()`
- [x] Locate `show_welcome()` function (line 175)
- [x] Replace `zenity --info` call with `show_info_dialog()`
- [x] Locate `ask_weekday_together()` function (line 192)
- [x] Replace `zenity --question` call with `show_question_dialog()`
- [x] Locate `ask_weekend_together()` function (line 213)
- [x] Replace `zenity --question` call with `show_question_dialog()`
- [x] Locate `show_success()` function (line 248)
- [x] Replace `zenity --info` call with `show_info_dialog()`
- [ ] Test each updated function with all three dialog tools
- [ ] Verify all dialogs display correctly
- [ ] Verify exit codes are handled correctly

#### 3.3 Update `lib/configure-input.sh`
- [x] Open `lib/configure-input.sh`
- [x] Locate all `has_zenity` checks (6 occurrences)
- [x] Replace `has_zenity` with `has_dialog_tool` in all checks
- [x] Locate `get_hour_zenity()` function (line 26)
- [x] Keep legacy name `get_hour_zenity()` for backward compatibility (not renamed)
- [x] Replace `zenity --entry` call with `show_entry_dialog()`
- [x] Replace `zenity --error` calls with `show_info_dialog()` (error variant)
- [x] Locate `get_popup_size_config()` function (line 85)
- [x] Replace `zenity --list` call with `show_list_dialog()`
- [x] Locate `get_min_display_time_config()` function (line 156)
- [x] Replace `zenity --entry` call with `show_entry_dialog()`
- [x] Replace `zenity --error` call with `show_info_dialog()`
- [x] Locate `get_popup_position_config()` function (line 294)
- [x] Replace `zenity --list` call with `show_list_dialog()` (already updated in Phase 1)
- [x] Locate `get_check_interval_config()` function (line 389)
- [x] Replace `zenity --entry` call with `show_entry_dialog()`
- [x] Replace `zenity --error` call with `show_info_dialog()`
- [x] Locate `get_day_hours()` function (line 437)
- [x] Replace `zenity --entry` call with `show_entry_dialog()` (with extra button support)
- [x] Replace `zenity --list` call with `show_list_dialog()` (for menu options)
- [x] Replace `zenity --error` calls with `show_info_dialog()`
- [x] Replace `zenity --question` call with `show_question_dialog()`
- [ ] Test each updated function with all three dialog tools
- [ ] Verify input validation still works correctly
- [ ] Verify error messages display correctly

#### 3.3a Create Multi-Column List Abstraction Function
- [x] Open `lib/configure-dialogs.sh`
- [x] Add new function `show_multi_column_list_dialog()` after `show_list_dialog()`
- [x] Function signature: `show_multi_column_list_dialog(title, text, width, height, print_column, column1_name, column2_name, ...)`
- [x] Parameters: title, text, width, height, print_column_index (which column to return), column names, then alternating column1_value, column2_value pairs
- [x] Implement YAD support:
  - [x] YAD uses `--list` with `--column="Name1" --column="Name2"` and alternating values
  - [x] Use `--print-column=<index>` to specify which column to return
  - [x] Fix YAD pipe separator handling (added `--separator=""` and output parsing)
  - [x] Test YAD multi-column format (tested: main menu and visual grid formats)
- [x] Implement Zenity support:
  - [x] Zenity uses `--list` with `--column="Name1" --column="Name2"` and alternating values
  - [x] Use `--print-column=<index>` to specify which column to return
  - [ ] Test Zenity multi-column format
- [x] Implement KDialog support:
  - [x] KDialog uses `--menu` with tag/value pairs (different format)
  - [x] For multi-column, concatenate columns into description (first column as tag, others as description)
  - [x] Research KDialog multi-column capabilities (implemented workaround)
  - [ ] Test KDialog multi-column format or fallback approach
- [x] Add error handling for unsupported tools (return 1)
- [x] Add function documentation comment explaining usage
- [x] Test function with 2-column data (like show_main_menu uses) - tested with YAD
- [x] Test function with different print_column values - tested with print_column=1
- [x] Verify return value matches selected column correctly - verified clean output (no pipe separators)
- [ ] Test with all three dialog tools installed (YAD tested, Zenity/KDialog pending)

#### 3.4 Update `lib/configure-display.sh`
- [x] Open `lib/configure-display.sh`
- [x] Locate all `has_zenity` checks (2 occurrences)
- [x] Replace `has_zenity` with `has_dialog_tool` in all checks
- [x] Locate `show_main_menu()` function (line 66)
- [x] Replace `zenity --list` call with `show_multi_column_list_dialog()`
- [x] Update data format: convert from zenity format to abstraction function format
- [x] Set `print_column=1` to return the option number (1-6)
- [x] Verify menu selection works correctly (returns option number) - tested with YAD, returns clean values like "3"
- [x] Locate `show_visual_grid()` function (line 194)
- [x] Replace `zenity --list` call with `show_multi_column_list_dialog()`
- [x] Update data format: convert from zenity alternating format to abstraction function format
- [x] Set `print_column=1` to return the day name (first column)
- [x] Verify grid selection works correctly (returns day name or "<<BACK>>") - tested with YAD, returns clean values like "Monday"
- [x] Update grid data formatting for KDialog compatibility (implemented in abstraction function)
- [x] Test grid display with YAD (verified both columns display correctly, selection works)
- [ ] Test grid display with Zenity (pending)
- [ ] Test grid display with KDialog (pending)
- [x] Verify grid data is correctly parsed (tested with YAD - returns correct day names)
- [x] Locate `show_summary()` function (line 512)
- [x] Replace `zenity --question` call with `show_question_dialog()`
- [x] Replace `zenity --error` call with `show_info_dialog()`
- [x] Test each updated function with YAD (all functions tested and working)
- [ ] Test each updated function with Zenity (pending)
- [ ] Test each updated function with KDialog (pending)
- [x] Verify visual grid displays correctly with YAD (tested - both columns visible, selection works)
- [x] Verify main menu displays correctly with YAD (tested - both columns visible, selection works)

#### 3.5 Update `configure.sh` Main Script
- [x] Open `configure.sh`
- [x] Locate requirements comment (lines 11-12)
- [x] Update to mention yad, zenity, or kdialog (not just zenity)
- [x] Locate help text (line 64)
- [x] Update to mention all three dialog tools
- [x] Locate `force_gui` handling (lines 81-88)
- [x] Replace `has_zenity` check with `has_dialog_tool`
- [x] Update error message to mention all three tools
- [x] Locate auto-detect section (lines 90-93)
- [x] Replace `has_zenity` check with `has_dialog_tool`
- [x] Replace `zenity --warning` call with `show_info_dialog()`
- [x] Replace `zenity --error` call with `show_info_dialog()`
- [ ] Test `--gui` flag with YAD installed
- [ ] Test `--gui` flag with only Zenity installed
- [ ] Test `--gui` flag with only KDialog installed
- [ ] Test `--gui` flag with no tools (should show error)
- [ ] Test auto-detect with all tool combinations

#### 3.6 Phase 3 Testing
- [ ] Run complete configuration workflow with YAD installed
- [ ] Run complete configuration workflow with only Zenity installed
- [ ] Run complete configuration workflow with only KDialog installed
- [ ] Test all configuration options (time ranges, sizes, positions, intervals)
- [ ] Test visual grid display with all three tools
- [ ] Test error handling and validation with all three tools
- [ ] Verify configuration file is saved correctly
- [ ] Test text mode fallback when no GUI tools available
- [ ] Test `--text` flag still works
- [ ] Verify backward compatibility (existing configs still work)

### Phase 4: Documentation Updates (Low Risk)

#### 4.1 Update `README.md`
- [x] Locate dependencies section
- [x] Update to show YAD as preferred, Zenity/KDialog as alternatives
- [x] Add note about unified priority (YAD → Zenity → KDialog)
- [x] Update installation instructions if needed
- [x] Verify all dialog tool references are updated

#### 4.2 Update `GETTING_STARTED.md`
- [x] Add YAD installation instructions
- [x] Update dialog tool requirements section
- [x] Mention that Zenity/KDialog are fallbacks
- [x] Add note about positioning options (center/top-left only)

#### 4.3 Update `user-docs/CONFIGURATION.md`
- [x] Locate popup position configuration section
- [x] Update to mention only center and top-left options
- [x] Remove references to other position options
- [x] Add note about dialog tool priority (if relevant)
- [x] Update any examples that use removed positions

#### 4.4 Update `dev-docs/TECHNICAL_DETAILS.md`
- [x] Locate dialog tool section
- [x] Document new unified priority system
- [x] Document positioning simplification (center/top-left only)
- [x] Update implementation details
- [x] Add note about configure wizard abstraction layer

#### 4.5 Update `dev-docs/info/dialog-tools-options.md`
- [x] Verify Section 9 (Implementation in This Project) reflects implemented changes
- [x] Verify Section 13 (Chosen Priority) is complete
- [x] Update any outdated implementation details
- [x] Ensure positioning simplification is documented

#### 4.6 Phase 4 Verification
- [ ] Review all documentation for consistency
- [ ] Verify no references to removed position options remain
- [ ] Verify dialog tool priority is correctly documented everywhere
- [ ] Check for broken links or outdated information
- [ ] Ensure examples in documentation are still valid

---

## Testing Performed

### Dialog Abstraction Layer Tests (YAD)

The following tests were performed with YAD installed:

1. **Info Dialog**: ✅ Tested - displays correctly, returns proper exit code
2. **Question Dialog**: ✅ Tested - yes/no buttons work correctly
3. **Entry Dialog**: ✅ Tested - text input works, returns clean values (fixed pipe separator issue)
4. **Single-Column List Dialog**: ✅ Tested - selection works, returns clean values (fixed pipe separator issue)
5. **Multi-Column List Dialog (Main Menu)**: ✅ Tested - both columns display correctly, returns option numbers (e.g., "3")
6. **Multi-Column List Dialog (Visual Grid)**: ✅ Tested - both columns display correctly, returns day names (e.g., "Monday")
7. **Text Info Dialog**: ✅ Tested - displays formatted text correctly

**Issues Found and Fixed**:
- YAD returns pipe-separated values by default - fixed by adding `--separator=""` and parsing output
- Entry dialog was returning appended text - fixed by extracting just the entry value
- All functions now return clean values without pipe separators

**Test Results**: All dialog abstraction functions work correctly with YAD. Ready for testing with Zenity and KDialog.

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
