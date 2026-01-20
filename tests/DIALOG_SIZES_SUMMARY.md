# Dialog Size Adjustments Summary

Based on user feedback from interactive testing, the following dialog sizes have been configured.

## Critical Fix: `--fixed` Flag for YAD

**All YAD dialog calls now include the `--fixed` flag** to enforce the specified dimensions. Without this flag, YAD auto-resizes based on text content, often making dialogs taller than they are wide.

The `--fixed` flag has been added to:
- `show_info_dialog()` - for info/error messages
- `show_question_dialog()` - for yes/no questions
- `show_list_dialog()` - for list selections
- `show_text_info_dialog()` - for help text
- `show_multi_column_list_dialog()` - for grids and menus
- `lib/popup-display.sh` - for the sleep warning popup

## Changes Made

### 1. Welcome Dialog (show_info_dialog)
- **Location**: `lib/configure-ui.sh` - `show_welcome()`
- **Previous**: 700x500 (too tall, too narrow)
- **New**: 800x400
- **Feedback**: Was way too tall and too narrow

### 2. Main Menu (show_multi_column_list_dialog)
- **Location**: `lib/configure-display.sh` - `show_main_menu()`
- **Current**: 700x400
- **Feedback**: OK - no changes needed

### 3. Popup Size Selection (show_list_dialog)
- **Location**: `lib/configure-input.sh` - `get_popup_size_config()`
- **Current**: 500x300
- **Feedback**: OK - no changes needed

### 4. Popup Position Selection (show_list_dialog)
- **Location**: `lib/configure-input.sh` - `get_popup_position_config()`
- **Current**: 500x300
- **Feedback**: OK - no changes needed

### 5. Immovable Setting (show_list_dialog)
- **Location**: `lib/configure-input.sh` - `get_popup_immovable_config()`
- **Current**: 600x300
- **Feedback**: OK - no changes needed

### 6. Help Dialog (show_text_info_dialog)
- **Location**: `lib/configure-ui.sh` - `show_help_dialog()`
- **Current**: 700x600
- **Feedback**: OK but looks different (uses text-info dialog type, which is a scrollable text viewer)
- **Note**: This is intentional - help text benefits from scrollable view

### 7. Visual Day/Time Grid (show_multi_column_list_dialog)
- **Location**: `lib/configure-display.sh` - `show_grid()`
- **Current**: 800x450
- **Feedback**: OK - no changes needed

### 8. Cancel Menu (show_list_dialog)
- **Location**: `lib/configure-input.sh` - `get_day_hours()`
- **Current**: 500x300
- **Feedback**: OK - no changes needed

### 9. Invalid Format Error (show_info_dialog)
- **Location**: `lib/configure-input.sh` - `get_day_hours()`
- **Previous**: 500x200 (a little taller than needed)
- **New**: 550x280
- **Feedback**: A little taller than it needs to be

### 10. Invalid Hour Error (show_info_dialog)
- **Location**: `lib/configure-input.sh` - `get_hour_zenity()`
- **Current**: 500x200
- **Feedback**: OK - no changes needed

### 11. Success Dialog (show_info_dialog)
- **Location**: `lib/configure-ui.sh` - `show_success()`
- **Previous**: 600x300 (a bit narrow and taller than needed)
- **New**: 650x280
- **Feedback**: A bit narrow and taller than it needs to be

### 12. 24/7 Restriction Error (show_info_dialog)
- **Location**: `lib/configure-ui.sh` - `show_24_7_error()`
- **Previous**: 700x400 (just a bit bigger than needed)
- **New**: 650x350
- **Feedback**: Just a bit bigger than it needs to be

### 13. High Restriction Warning (show_question_dialog)
- **Location**: `lib/configure-ui.sh` - `show_high_restriction_warning()`
- **Previous**: auto-sized (no parameters)
- **New**: 700x400
- **Feedback**: OK - but needed size parameters added

### 14. Configuration Summary (show_question_dialog)
- **Location**: `lib/configure-display.sh` - `show_summary()`
- **Previous**: auto-sized (very very narrow)
- **New**: 700x500
- **Feedback**: Was very very narrow and much taller than wide

## Additional Question Dialogs (not in test but updated for consistency)

### Cancel Configuration Confirmation
- **Location**: `lib/configure-ui.sh` - `confirm_cancel()`
- **New**: 500x250

### Skip Day Confirmation
- **Location**: `lib/configure-ui.sh` - `confirm_skip_day()`
- **New**: 550x300

### Weekday Together Question
- **Location**: `lib/configure-ui.sh` - `ask_weekday_together()`
- **New**: 600x250

### Weekend Together Question
- **Location**: `lib/configure-ui.sh` - `ask_weekend_together()`
- **New**: 650x250

### Confirm Time Range
- **Location**: `lib/configure-input.sh` - `get_day_hours()`
- **New**: 600x350

## Key Fix: show_question_dialog Now Supports Size Parameters

The `show_question_dialog()` function in `lib/configure-dialogs.sh` was missing width/height parameters entirely, causing YAD to auto-size poorly (resulting in very narrow, tall windows).

**Updated signature**:
```bash
show_question_dialog() {
    local title="$1"
    local text="$2"
    local ok_label="${3:-Yes}"
    local cancel_label="${4:-No}"
    local width="${5:-600}"      # NEW: default 600
    local height="${6:-400}"     # NEW: default 400
    # ...
}
```

## Dialog Type Differences

### show_info_dialog
- Standard message box with icon
- Good for short to medium messages
- Auto-wraps text

### show_text_info_dialog
- Scrollable text viewer
- Good for long text or help content
- Monospace font option
- Looks different (more like a text editor)

### show_question_dialog
- Yes/No dialog with two buttons
- Now supports width/height parameters
- Critical for proper sizing in YAD

### show_list_dialog
- Single-column selection list
- Auto-sizes to content reasonably well

### show_multi_column_list_dialog
- Multi-column table view
- Requires explicit sizing for best results

## Testing

To test all dialogs with current sizes:
```bash
./tests/test-dialog-sizes-interactive.sh
```

All sizes have been optimized based on user feedback for YAD dialog tool.
