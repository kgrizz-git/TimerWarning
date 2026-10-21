#!/bin/bash

###############################################################################
# Portable UTF-8 Locale Preference Regression Test
#
# Purpose:
# - Ensure dialog_prepare_utf8_locale prefers C.UTF-8 / C.utf8 when available,
#   even if the host LANG already reports a UTF-8 charmap (e.g. en_US.UTF-8).
# - Ensure show_list_dialog / show_multi_column_list_dialog prepare locale in
#   the parent shell so a yad child inherits LC_ALL (the real Steam Deck bug).
#
# How to run:
#   ./tests/test-portable-utf8-dialog-locale.sh
#   RUN_GUI_PROBES=1 ./tests/test-portable-utf8-dialog-locale.sh  # optional live yad
###############################################################################

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${ROOT_DIR}/tmp"

STUB_DIR=""
cleanup() {
    if [ -n "${STUB_DIR}" ] && [ -d "${STUB_DIR}" ]; then
        rm -rf "${STUB_DIR}"
    fi
}
trap cleanup EXIT

# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/unicode-dialog-safety.sh"

# --- 1) Prepare prefers portable C.* UTF-8 under a host UTF-8 LANG ---
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
            exit 1
            ;;
    esac
fi

sample="Default — Gaming"
safe="$(dialog_safe_text "${sample}")"
if [ "${safe}" != "${sample}" ]; then
    echo "FAIL: dialog_safe_text should keep em dash when UTF-8 confirmed" >&2
    echo "  expected: ${sample}" >&2
    echo "  got:      ${safe}" >&2
    exit 1
fi

echo "PASS: dialog_prepare_utf8_locale prefers portable UTF-8 locale (LC_ALL=${LC_ALL})."

# --- 2) Stub yad: dialog helpers must export locale before spawning yad ---
# Skip on platforms without Linux dialog routing expectations.
if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "PASS: stub-yad dialog inheritance check skipped on Darwin."
    exit 0
fi

STUB_DIR="$(mktemp -d "${ROOT_DIR}/tmp/yad-stub.XXXXXX")"
YAD_STUB_ENV="${STUB_DIR}/yad.env"
YAD_STUB_ARGV="${STUB_DIR}/yad.argv"

cat > "${STUB_DIR}/yad" <<'STUB'
#!/bin/bash
# Record inherited locale and argv for assertions; return a list selection.
printf 'LC_ALL=%s\nLANG=%s\n' "${LC_ALL:-}" "${LANG:-}" > "${YAD_STUB_ENV}"
printf '%s\n' "$@" > "${YAD_STUB_ARGV}"
# Multi-column / list dialogs expect a selected value on stdout.
echo "1"
exit 0
STUB
chmod +x "${STUB_DIR}/yad"
export YAD_STUB_ENV YAD_STUB_ARGV
export PATH="${STUB_DIR}:${PATH}"

# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/configure-core.sh"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/desktop-environment.sh"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/configure-dialogs.sh"

# Force yad without probing real tools.
_CONFIGURE_CACHED_DIALOG_TOOL="yad"
_CONFIGURE_CACHED_HAS_DIALOG_TOOL="yes"

# Reset to host-looking UTF-8; do NOT call prepare here — dialogs must do it.
unset DIALOG_UTF8_CONFIRMED
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
rm -f "${YAD_STUB_ENV}" "${YAD_STUB_ARGV}"

list_out="$(show_list_dialog "Service Mode" "Select:" 400 200 "${sample}" "Back to Main Menu" || true)"
if [ ! -f "${YAD_STUB_ENV}" ]; then
    echo "FAIL: stub yad was not invoked by show_list_dialog" >&2
    exit 1
fi

stub_lc="$(grep '^LC_ALL=' "${YAD_STUB_ENV}" | cut -d= -f2-)"
case "${stub_lc}" in
    C.UTF-8|C.utf8) ;;
    *)
        if [ "${portable_available}" -eq 1 ]; then
            echo "FAIL: show_list_dialog yad child LC_ALL should be C.UTF-8/C.utf8" >&2
            echo "  got: '${stub_lc}'" >&2
            cat "${YAD_STUB_ENV}" >&2
            exit 1
        fi
        ;;
esac

if ! grep -Fq "${sample}" "${YAD_STUB_ARGV}"; then
    echo "FAIL: show_list_dialog should pass unsanitized em-dash text to yad when UTF-8 confirmed" >&2
    cat "${YAD_STUB_ARGV}" >&2
    exit 1
fi

if [ -z "${list_out}" ]; then
    echo "FAIL: show_list_dialog returned empty selection from stub" >&2
    exit 1
fi

echo "PASS: show_list_dialog prepares parent locale; stub yad saw LC_ALL=${stub_lc}."

rm -f "${YAD_STUB_ENV}" "${YAD_STUB_ARGV}"
unset DIALOG_UTF8_CONFIRMED
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

mc_out="$(show_multi_column_list_dialog \
    "Window Behavior" \
    "Select:" \
    500 \
    320 \
    1 \
    "Option" "Description" \
    "1" "Popup size — medium" \
    "6" "Back to main menu" || true)"

if [ ! -f "${YAD_STUB_ENV}" ]; then
    echo "FAIL: stub yad was not invoked by show_multi_column_list_dialog" >&2
    exit 1
fi

stub_lc="$(grep '^LC_ALL=' "${YAD_STUB_ENV}" | cut -d= -f2-)"
case "${stub_lc}" in
    C.UTF-8|C.utf8) ;;
    *)
        if [ "${portable_available}" -eq 1 ]; then
            echo "FAIL: show_multi_column_list_dialog yad child LC_ALL should be C.UTF-8/C.utf8" >&2
            echo "  got: '${stub_lc}'" >&2
            cat "${YAD_STUB_ENV}" >&2
            exit 1
        fi
        ;;
esac

if ! grep -Fq "Popup size — medium" "${YAD_STUB_ARGV}"; then
    echo "FAIL: multi-column dialog should pass em-dash description to yad when UTF-8 confirmed" >&2
    cat "${YAD_STUB_ARGV}" >&2
    exit 1
fi

if [ "${mc_out}" != "1" ]; then
    echo "FAIL: multi-column stub should return print-column value '1' (got '${mc_out}')" >&2
    exit 1
fi

echo "PASS: show_multi_column_list_dialog prepares parent locale; stub yad saw LC_ALL=${stub_lc}."

# --- 3) Optional live yad probe (opt-in; Tier A stays headless-friendly) ---
if [ "${RUN_GUI_PROBES:-}" = "1" ] && [ -n "${DISPLAY:-}" ] && command -v yad >/dev/null 2>&1; then
    # Prefer the real yad, not the stub.
    export PATH="${PATH#"${STUB_DIR}:"}"
    dialog_prepare_utf8_locale
    err_file="$(mktemp "${ROOT_DIR}/tmp/yad-utf8-probe.XXXXXX")"
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
        cat "${err_file}" >&2
        rm -f "${err_file}"
        exit 1
    fi
    if [ "${yad_rc}" -eq 255 ]; then
        echo "FAIL: yad exited 255 after portable locale prepare" >&2
        cat "${err_file}" >&2
        rm -f "${err_file}"
        exit 1
    fi
    rm -f "${err_file}"
    echo "PASS: live yad accepted UTF-8 list item under LC_ALL=${LC_ALL} (rc=${yad_rc})."
fi

echo "PASS: portable UTF-8 dialog locale regression checks complete."
