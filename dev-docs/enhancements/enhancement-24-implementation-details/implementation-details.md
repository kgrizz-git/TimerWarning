# Enhancement 24: Implementation Details

This document contains detailed implementation information for Enhancement 24: Unified Dialog Tool Priority (YAD → Zenity → KDialog).

**Related Document**: See [../enhancement-24-unified-dialog-priority-yad-first.md](../enhancement-24-unified-dialog-priority-yad-first.md) for the full enhancement description and overview.

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
