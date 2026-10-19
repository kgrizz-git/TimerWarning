#!/bin/bash

###############################################################################
# Portable UTF-8 Locale Preference Regression Test
#
# Purpose:
# - Ensure dialog_prepare_utf8_locale prefers C.UTF-8 / C.utf8 when available,
#   even if the host LANG already reports a UTF-8 charmap (e.g. en_US.UTF-8).
#
# Why this exists:
# - Nix-packaged yad may not accept host en_US.* locales and falls back to plain
#   C, then crashes on UTF-8 menu strings (em dash). Preferring C.utf8 keeps
#   configure menu options 2 and 12 usable on Steam Deck.
#
# How to run:
#   ./tests/test-portable-utf8-dialog-locale.sh
###############################################################################

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/unicode-dialog-safety.sh"

# Simulate the Steam Deck false-positive: host LANG looks UTF-8.
unset DIALOG_UTF8_CONFIRMED
unset DIALOG_SAFETY_FORCE_ASCII
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

dialog_prepare_utf8_locale

if [ "${DIALOG_UTF8_CONFIRMED}" != "yes" ]; then
    echo "FAIL: Expected DIALOG_UTF8_CONFIRMED=yes after prepare" >&2
    echo "  got: ${DIALOG_UTF8_CONFIRMED:-<empty>}" >&2
    exit 1
fi

# When C.UTF-8 or C.utf8 exists, prepare must switch to one of them.
portable_available=0
if LC_ALL="C.UTF-8" locale charmap 2>/dev/null | grep -qi "utf-8"; then
    portable_available=1
elif LC_ALL="C.utf8" locale charmap 2>/dev/null | grep -qi "utf-8"; then
    portable_available=1
fi

if [ "${portable_available}" -eq 1 ]; then
    case "${LC_ALL}" in
        C.UTF-8|C.utf8) ;;
        *)
            echo "FAIL: Expected LC_ALL=C.UTF-8 or C.utf8 when portable locale exists" >&2
            echo "  LC_ALL=${LC_ALL}" >&2
            echo "  LANG=${LANG}" >&2
            exit 1
            ;;
    esac
fi

# Em dash must remain when UTF-8 is confirmed (not ASCII-sanitized away).
sample="Default — Gaming"
safe="$(dialog_safe_text "${sample}")"
if [ "${safe}" != "${sample}" ]; then
    echo "FAIL: dialog_safe_text should keep em dash when UTF-8 confirmed" >&2
    echo "  expected: ${sample}" >&2
    echo "  got:      ${safe}" >&2
    exit 1
fi

# Optional live yad probe when DISPLAY is available.
if [ -n "${DISPLAY:-}" ] && command -v yad >/dev/null 2>&1; then
    mkdir -p "${ROOT_DIR}/tmp"
    err_file="${ROOT_DIR}/tmp/yad-utf8-probe.err"
    : > "${err_file}"
    set +e
    yad --list --title="UTF8-LOCALE-PROBE" --text="probe" \
        --width=400 --height=200 --timeout=1 \
        --column="Option" "${sample}" \
        --print-column=1 --separator= \
        >/dev/null 2>"${err_file}"
    yad_rc=$?
    set -e
    if grep -q "Invalid byte sequence in conversion input" "${err_file}"; then
        echo "FAIL: yad still rejects UTF-8 after portable locale prepare" >&2
        echo "  LC_ALL=${LC_ALL}" >&2
        cat "${err_file}" >&2
        exit 1
    fi
    # timeout exit is typically 70; 255 with the byte-sequence error is the bug.
    if [ "${yad_rc}" -eq 255 ]; then
        echo "FAIL: yad exited 255 after portable locale prepare" >&2
        cat "${err_file}" >&2
        exit 1
    fi
    echo "PASS: yad accepted UTF-8 list item under LC_ALL=${LC_ALL} (rc=${yad_rc})."
fi

echo "PASS: dialog_prepare_utf8_locale prefers portable UTF-8 locale (LC_ALL=${LC_ALL})."
