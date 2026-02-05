#!/bin/bash

###############################################################################
# Non-UTF Locale Dialog Safety Regression Test
#
# Purpose:
# - Ensure our dialog safety helper sanitizes Unicode-heavy strings to pure ASCII
#   when UTF-8 cannot be confirmed (simulated via DIALOG_SAFETY_FORCE_ASCII=1).
#
# Why this exists:
# - GTK dialog tools (yad/zenity) can exit immediately when passed UTF-8 text
#   under non-UTF locales (e.g., LANG=C), causing GUI dialogs to "crash".
#
# How to run:
#   ./tests/test-non-utf-dialog-safety.sh
#
# Last updated: 2026-02-05
###############################################################################

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load helper
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/unicode-dialog-safety.sh"

# Force ASCII mode regardless of system locale.
export DIALOG_SAFETY_FORCE_ASCII=1

sample=$'Symbols: → ✓ ✔ ✗ ✅ ❌ ⚠ ⚠️ 🚨 ⏱ ⏱️ × … — – • ℹ\nSecond line.'
out="$(dialog_safe_text "${sample}")"

# Assert output is pure ASCII (plus newline/tab/CR).
ascii_only="$(printf '%s' "${out}" | LC_ALL=C tr -cd '\11\12\15\40-\176')"
if [ "${ascii_only}" != "${out}" ]; then
    echo "FAIL: Output contains non-ASCII bytes" >&2
    echo "Original: ${sample}" >&2
    echo "Output:   ${out}" >&2
    exit 1
fi

# Spot-check key replacements occurred (so we’re not just deleting everything).
printf '%s' "${out}" | grep -q "WARNING" || { echo "FAIL: Expected WARNING replacement missing" >&2; exit 1; }
printf '%s' "${out}" | grep -q "TIMER" || { echo "FAIL: Expected TIMER replacement missing" >&2; exit 1; }
printf '%s' "${out}" | grep -q -- "->" || { echo "FAIL: Expected -> replacement missing" >&2; exit 1; }
printf '%s' "${out}" | grep -q "OK" || { echo "FAIL: Expected OK replacement missing" >&2; exit 1; }

echo "PASS: dialog_safe_text produced ASCII-safe output under forced non-UTF mode."

