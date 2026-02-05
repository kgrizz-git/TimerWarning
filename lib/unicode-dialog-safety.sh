#!/bin/bash

###############################################################################
# Unicode / Locale Safety Helpers for GUI Dialogs (yad / zenity / kdialog)
#
# Problem:
# - Some environments (notably systemd user services on SteamOS) may run with a
#   non-UTF locale (e.g., LANG=C, LC_ALL=C).
# - GTK-based tools (yad/zenity) can exit immediately when passed UTF-8 text in
#   a non-UTF locale, producing errors like:
#     "Unable to parse command line: Invalid byte sequence in conversion input"
# - This can cause popup respawn loops or make configuration dialogs unusable.
#
# Goal:
# - Prefer "fancy" Unicode text when UTF-8 locale is confirmed.
# - Guarantee "no GUI dialog crashes" by sanitizing to ASCII when UTF-8 cannot
#   be confirmed/ensured.
#
# Usage:
# - Source this file from any module that calls yad/zenity/kdialog.
# - Call dialog_prepare_utf8_locale once (optional; dialog_safe_* will call it).
# - Wrap any GUI string (title/text/button labels/list items) with:
#     dialog_safe_text "..."
#
# Test support:
# - Set DIALOG_SAFETY_FORCE_ASCII=1 to force ASCII sanitization regardless of
#   system locale. Intended for tests only.
###############################################################################

# Cached decision: "yes" / "no" / "" (unknown/not computed yet)
DIALOG_UTF8_CONFIRMED="${DIALOG_UTF8_CONFIRMED:-}"

# Attempt to ensure UTF-8 locale for GUI dialog tools.
# Returns: 0 always (best-effort).
dialog_prepare_utf8_locale() {
    # Allow tests to force ASCII mode without touching environment.
    if [ "${DIALOG_SAFETY_FORCE_ASCII:-}" = "1" ]; then
        DIALOG_UTF8_CONFIRMED="no"
        return 0
    fi

    # If we've already decided for this process, keep it.
    if [ -n "${DIALOG_UTF8_CONFIRMED:-}" ]; then
        return 0
    fi

    # If locale(1) is missing, we can't reliably detect; assume non-UTF.
    if ! command -v locale >/dev/null 2>&1; then
        DIALOG_UTF8_CONFIRMED="no"
        return 0
    fi

    # If current charmap is UTF-8, we're good.
    if dialog_is_utf8_locale; then
        DIALOG_UTF8_CONFIRMED="yes"
        return 0
    fi

    # Try to switch to a UTF-8 locale (process-local env only).
    local candidate
    for candidate in "C.UTF-8" "en_US.UTF-8" "en_US.utf8"; do
        # Verify candidate exists and yields UTF-8 charmap.
        if LC_ALL="${candidate}" locale charmap >/dev/null 2>&1; then
            export LC_ALL="${candidate}"
            # Keep LANG/LC_CTYPE consistent if unset/empty to reduce surprises.
            if [ -z "${LANG:-}" ]; then
                export LANG="${candidate}"
            fi
            if [ -z "${LC_CTYPE:-}" ]; then
                export LC_CTYPE="${candidate}"
            fi
            break
        fi
    done

    if dialog_is_utf8_locale; then
        DIALOG_UTF8_CONFIRMED="yes"
    else
        DIALOG_UTF8_CONFIRMED="no"
    fi

    return 0
}

# Returns 0 if locale charmap appears to be UTF-8.
dialog_is_utf8_locale() {
    command -v locale >/dev/null 2>&1 || return 1
    local charmap
    charmap="$(locale charmap 2>/dev/null || echo "")"
    printf '%s' "${charmap}" | grep -qi "utf-8"
}

# Convert common Unicode symbols used in this project into ASCII equivalents,
# then strip any remaining non-ASCII bytes.
dialog_sanitize_to_ascii() {
    local text="$1"

    # Common symbols and emojis seen in this repo (and likely user-facing strings).
    # Note: Some emojis are composed with variation selectors; we replace the base
    # symbol and then strip remaining non-ASCII bytes anyway.
    text=${text//→/->}
    text=${text//✓/OK}
    text=${text//✔/OK}
    text=${text//✅/OK}
    text=${text//✗/X}
    text=${text//❌/X}
    text=${text//⚠️/WARNING}
    text=${text//⚠/WARNING}
    text=${text//🚨/CRITICAL}
    text=${text//⏱️/TIMER}
    text=${text//⏱/TIMER}
    text=${text//ℹ️/INFO}
    text=${text//ℹ/INFO}
    text=${text//×/x}
    text=${text//•/-}
    text=${text//…/...}
    text=${text//—/-}
    text=${text//–/-}

    # Strip remaining non-ASCII bytes, but keep newlines/tabs/CR and printable ASCII.
    # This ensures yad/zenity won't choke under LANG=C.
    text="$(printf '%s' "${text}" | LC_ALL=C tr -cd '\11\12\15\40-\176')"

    printf '%s' "${text}"
}

# Return text safe for GUI dialogs in current locale:
# - If UTF-8 confirmed: return original text
# - Otherwise: ASCII sanitized
dialog_safe_text() {
    local text="$1"
    dialog_prepare_utf8_locale
    if [ "${DIALOG_UTF8_CONFIRMED:-no}" = "yes" ]; then
        printf '%s' "${text}"
    else
        dialog_sanitize_to_ascii "${text}"
    fi
}

