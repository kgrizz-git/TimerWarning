#!/usr/bin/env bash
#
# tests/lib/test-platform.sh — platform skip helpers for test scripts.
#
# Usage (after sourcing):
#   test_is_linux && ...
#   test_skip_linux_only "systemd drop-in path" && exit 0
#   test_skip_unless_display_resolution && exit 0
#   test_skip_gui_manual "dialog abstraction" && exit 0

test_is_linux() {
    [ "$(uname -s 2>/dev/null)" = "Linux" ]
}

test_is_darwin() {
    [ "$(uname -s 2>/dev/null)" = "Darwin" ]
}

# Echo SKIP reason and return 0 when not Linux (caller should exit 0).
test_skip_linux_only() {
    local reason="${1:-Linux-only test}"
    if test_is_linux; then
        return 1
    fi
    echo "SKIP: ${reason} (not Linux — $(uname -s 2>/dev/null))"
    return 0
}

# Skip when get_display_resolution is unavailable (headless / no display).
test_skip_unless_display_resolution() {
    local reason="${1:-display resolution required}"
    if type get_display_resolution >/dev/null 2>&1; then
        local resolution
        resolution=$(get_display_resolution 2>/dev/null || true)
        if [ -n "${resolution}" ]; then
            return 1
        fi
    fi
    echo "SKIP: ${reason} (get_display_resolution unavailable)"
    return 0
}

# Skip GUI manual tests in CI or when no dialog tool is installed.
test_skip_gui_manual() {
    local reason="${1:-GUI manual test}"
    if [ "${CI:-}" = "true" ] || [ "${CI:-}" = "1" ]; then
        echo "SKIP: ${reason} (CI=true)"
        return 0
    fi
    if type has_dialog_tool >/dev/null 2>&1; then
        if has_dialog_tool; then
            return 1
        fi
    fi
    if command -v zenity >/dev/null 2>&1 || \
       command -v yad >/dev/null 2>&1 || \
       command -v kdialog >/dev/null 2>&1; then
        return 1
    fi
    echo "SKIP: ${reason} (no yad/zenity/kdialog)"
    return 0
}
