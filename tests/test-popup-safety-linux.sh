#!/usr/bin/env bash

###############################################################################
# test-popup-safety-linux.sh — Popup safety unit tests (all platforms)
#
# Exercises lib/popup-safety.sh (watchdog, caps, PID-file watchdog helper).
# Does not spawn yad/zenity/kdialog; full Linux dialog integration belongs on a
# Linux host (see dev-docs/TO_DO.md).
#
# Implementation is shared with test-popup-safety-darwin.sh.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/test-popup-safety-darwin.sh" "$@"
