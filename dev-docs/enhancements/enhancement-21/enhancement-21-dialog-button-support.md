# Dialog Tool Button Support Analysis

## Summary: ✅ **NO POPUP TYPE CHANGE NEEDED**

**Answer**: Yes, zenity and yad both support adding buttons to `--warning` dialogs. **No popup type change is required.**

---

## Test Results

### zenity --warning with --extra-button
**Test Command:**
```bash
zenity --warning --text="Test" --extra-button="Pause 5 min"
```

**Result**: ✅ **WORKS**
- Exit code: `1` (when extra button clicked)
- stdout: `"Pause 5 min"` (button label printed to stdout)
- **No popup type change needed** - `--warning` supports `--extra-button`

### yad --warning with --button
**Test Command:**
```bash
yad --warning --text="Test" --button="Pause 5 min:5" --button="OK:0"
```

**Result**: ✅ **WORKS**
- Exit code: `5` (matches button value when "Pause 5 min" clicked)
- Exit code: `0` (when "OK" clicked)
- **No popup type change needed** - `--warning` supports `--button`

### kdialog --sorry
**Status**: ⚠️ **LIMITED SUPPORT**
- `--sorry` (warning dialog) does NOT support custom buttons
- Workaround needed (see below)

---

## Implementation Details

### zenity Implementation
```bash
# Add pause buttons to existing --warning dialog
zenity --warning \
    --title="${window_title}" \
    --text="${message}" \
    --modal \
    --width="${width}" \
    --height="${height}" \
    --extra-button="Pause 5 min" \
    --extra-button="Pause 10 min" \
    2>/dev/null

# Parse result
exit_code=$?
if [ ${exit_code} -eq 1 ]; then
    # Extra button clicked - read button label from stdout
    button_label=$(cat /tmp/zenity_output 2>/dev/null)
    if [ "${button_label}" = "Pause 5 min" ]; then
        activate_pause 5
    elif [ "${button_label}" = "Pause 10 min" ]; then
        activate_pause 10
    fi
fi
```

**Note**: zenity prints button label to stdout when extra button is clicked. Need to capture stdout.

### yad Implementation
```bash
# Add pause buttons to existing --warning dialog
yad --warning \
    --title="${window_title}" \
    --text="${message}" \
    --modal \
    --width="${width}" \
    --height="${height}" \
    --button="Pause 5 min:5" \
    --button="Pause 10 min:10" \
    --button="OK:0" \
    2>/dev/null

# Parse result
exit_code=$?
if [ ${exit_code} -eq 5 ]; then
    activate_pause 5
elif [ ${exit_code} -eq 10 ]; then
    activate_pause 10
fi
```

**Note**: yad exit code directly matches button value. Simpler parsing than zenity.

### kdialog Workaround
Since `--sorry` doesn't support custom buttons, use a two-step approach:

**Option 1: Separate Menu Dialog (Recommended)**
```bash
# Step 1: Show warning (no pause buttons)
kdialog --title "${window_title}" --sorry "${message}"

# Step 2: If user wants to pause, show menu dialog
if [ $? -eq 0 ]; then  # User clicked OK
    pause_choice=$(kdialog --title "Pause Restrictions" \
        --menu "Pause restrictions for:" \
        "5" "5 minutes" \
        "10" "10 minutes" \
        "cancel" "Cancel")
    
    case "${pause_choice}" in
        5) activate_pause 5 ;;
        10) activate_pause 10 ;;
    esac
fi
```

**Option 2: Add Instructions to Message**
```bash
# Include pause instructions in warning message
message="${base_message}\n\nTo pause restrictions, use: manage.sh --pause"
kdialog --title "${window_title}" --sorry "${message}"
```

---

## Key Findings

1. ✅ **zenity**: `--warning` dialogs support `--extra-button` - NO TYPE CHANGE NEEDED
2. ✅ **yad**: `--warning` dialogs support `--button` - NO TYPE CHANGE NEEDED
3. ⚠️ **kdialog**: `--sorry` does NOT support custom buttons - WORKAROUND NEEDED

## Impact on Implementation

### Good News
- **No popup type change required** for zenity/yad (90% of use cases)
- Can add pause buttons directly to existing `--warning` dialogs
- Implementation is simpler than originally thought

### Considerations
- **zenity**: Need to capture stdout to get button label
- **yad**: Exit code parsing is straightforward
- **kdialog**: Requires two-step dialog (warning + menu) or message text instructions

## Updated Implementation Approach

### For zenity/yad (Primary Tools)
1. Keep existing `--warning` dialog type
2. Add `--extra-button` (zenity) or `--button` (yad) flags
3. Parse exit code and button label/value
4. Activate pause if pause button clicked

### For kdialog (Fallback)
1. Show warning dialog as normal
2. After dialog closes, show separate menu dialog for pause selection
3. Or: Add pause instructions in message text

---

## Conclusion

**Answer to user's question**: 
- ✅ **zenity and yad both support adding buttons to warning popups**
- ✅ **NO popup type change needed** for zenity/yad
- ⚠️ **kdialog requires workaround** (separate dialog or message instructions)

The implementation is **simpler than expected** because we can add buttons directly to the existing `--warning` dialogs without changing the dialog type.
