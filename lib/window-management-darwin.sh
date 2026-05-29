#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Window Management (Phase 3 stubs / no-ops for MVP)
#
# Stay-on-top and immovable windows require Accessibility (TTC). MVP uses no-ops.
###############################################################################

if [ -z "${WINDOW_MANAGEMENT_DARWIN_LOADED:-}" ]; then
    WINDOW_MANAGEMENT_DARWIN_LOADED=1

    check_window_tools() {
        echo ""
    }

    keep_window_on_top() {
        return 0
    }

    keep_window_on_top_periodic() {
        return 0
    }

    make_window_unclosable() {
        return 0
    }

    make_window_immovable() {
        return 0
    }

    reenable_window_closing() {
        return 0
    }

    reposition_popup_window() {
        return 0
    }

    detect_window_state() {
        echo "unknown"
    }

    close_existing_popups() {
        return 0
    }
fi
