#!/usr/bin/env python3
"""
Sleep Warning System - macOS multi-column table dialog (tkinter).

One-shot CLI: reads JSON from stdin, shows dialog, prints selected value.
For session mode see configure-dialogs-darwin-daemon.py.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import tkinter as tk

sys.path.insert(0, str(Path(__file__).resolve().parent))
import configure_dialogs_darwin_table_ui as table_ui  # noqa: E402
import configure_dialogs_darwin_window as _cd_window  # noqa: E402


def _fail(message: str, code: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        _fail(f"Invalid JSON input: {exc}")

    root = tk.Tk()
    _cd_window.apply_app_icon(root)
    try:
        ok, value, code, _shown = table_ui.show_table_dialog(root, payload)
    finally:
        root.destroy()

    if not ok or value is None:
        raise SystemExit(1)
    print(value)
    raise SystemExit(code)


if __name__ == "__main__":
    main()
