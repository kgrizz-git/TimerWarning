# kdialog Pause Menu Timing and Race Condition Handling

## The Problem

The user correctly identified a potential issue with the kdialog workaround:

1. Warning popup appears (`--sorry` dialog)
2. User clicks OK → popup closes
3. Script exits
4. Pause menu appears... but when?
5. If timer fires (every 10 minutes), a new warning popup could appear on top of the pause menu!

## The Solution

**Show pause menu INSIDE `show_warning()` BEFORE it returns, not after script exits.**

### Correct Flow for kdialog

```
1. Timer fires → sleep-warning.sh runs
2. Check pause state → if active, skip popup and exit
3. If not paused, call show_warning()
4. Show --sorry dialog (warning popup)
5. User clicks OK → dialog closes
6. BEFORE show_warning() returns:
   a. Check if pause is available (can_pause_today())
   b. If yes, show --menu dialog (pause selection) SYNCHRONOUSLY
   c. User selects pause duration
   d. Activate pause IMMEDIATELY (write to state file)
   e. Show confirmation dialog
7. show_warning() returns
8. Script exits
9. Next timer event (10 min later):
   a. Check pause state FIRST
   b. See pause is active
   c. Skip popup, exit
```

### Why This Works

1. **Pause activated before script exits**: State file is written before `show_warning()` returns
2. **Next timer event sees pause state**: Pause check happens BEFORE showing popup
3. **Race condition handled**: Even if timer fires while pause menu is open, new script run will:
   - Check pause state first (line 2 in flow above)
   - See pause is active (or about to be active)
   - Skip showing popup
   - Exit

### Implementation Details

```bash
# In show_warning() function, after kdialog --sorry closes:
case "${dialog_tool}" in
    kdialog)
        kdialog --title "${window_title}" --sorry "${message}" 2>/dev/null &
        popup_pid=$!
        wait "${popup_pid}" 2>/dev/null
        exit_code=$?
        
        # After warning closes, check if we should show pause menu
        if [ ${exit_code} -eq 0 ] && can_pause_today; then
            # Show pause menu SYNCHRONOUSLY (blocking)
            pause_choice=$(kdialog --title "Pause Warning Popups" \
                --menu "Pause warning popups for:" \
                "5" "5 minutes" \
                "10" "10 minutes" \
                "cancel" "Cancel")
            
            # Activate pause if selected (before function returns)
            case "${pause_choice}" in
                5) activate_pause 5 ;;
                10) activate_pause 10 ;;
            esac
            
            # Show confirmation
            if [ "${pause_choice}" != "cancel" ] && [ -n "${pause_choice}" ]; then
                local pause_end_time
                pause_end_time=$(date -d "@$(get_pause_end_timestamp)" +"%H:%M" 2>/dev/null)
                kdialog --title "Pause Activated" \
                    --msgbox "Warning popups paused until ${pause_end_time}" 2>/dev/null
            fi
        fi
        ;;
esac
```

### Timing Considerations

- **Pause menu appears immediately**: No delay between warning close and pause menu
- **Pause activated synchronously**: State file written before function returns
- **Next timer event safe**: Will check pause state before showing popup
- **Window management**: kdialog dialogs are modal and stay on top automatically

### Alternative: Disable Pause for kdialog

If timing concerns remain, we can disable pause when only kdialog is available:

```bash
# Check if pause is supported by dialog tool
if [ "${dialog_tool}" = "kdialog" ] && [ -z "${other_dialog_tools}" ]; then
    # Only kdialog available - disable pause feature
    log_to_file "INFO" "Pause feature disabled: kdialog doesn't support custom buttons in warning dialogs"
    # Show warning without pause option
fi
```

**Recommendation**: Use the synchronous pause menu approach (Option 1) - it's safe and provides better UX than disabling pause entirely.
