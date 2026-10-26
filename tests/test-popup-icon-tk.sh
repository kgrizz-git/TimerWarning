#!/bin/bash
# Run the headless Tk icon-helper checks.
# Inputs: tests/test-popup-icon-tk.py and the macOS icon helpers under lib/.
# Output: the Python script's PASS line, or SKIP when tkinter cannot be imported.
# Requirements: python3. No display and no real Tk root.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "${ROOT}/tests/test-popup-icon-tk.py"
