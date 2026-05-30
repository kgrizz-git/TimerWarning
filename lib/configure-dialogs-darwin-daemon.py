#!/usr/bin/env python3
"""
Sleep Warning System - macOS configure wizard tkinter dialog daemon.

Reads newline-delimited JSON requests from stdin, shows dialogs on a single
Tk root, writes one JSON response line per request to stdout.

macOS: use the Tk root directly (same as one-shot CLIs). Toplevel + withdrawn
parent leaves dialogs invisible on Aqua; deiconify root per request instead.

Protocol:
  Request:  {"op":"table"|"time"|"text"|"quit", ...payload fields...}
  Response: {"ok":true,"value":"..."} | {"ok":false,"cancelled":true} | {"ok":true,"ready":true}
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import tkinter as tk

_LIB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_LIB_DIR))

import configure_dialogs_darwin_table_ui as table_ui  # noqa: E402
import configure_dialogs_darwin_text_ui as text_ui  # noqa: E402
import configure_dialogs_darwin_time_ui as time_ui  # noqa: E402
import configure_dialogs_darwin_window as cd_window  # noqa: E402


def _respond(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def _run_dialog(root: tk.Tk, op: str, req: dict[str, Any]) -> dict[str, Any]:
    cd_window.show_daemon_root(root)
    try:
        if op == "table":
            ok, value, _code = table_ui.show_table_dialog(root, req)
        elif op == "time":
            ok, value, _code = time_ui.show_time_dialog(root, req)
        elif op == "text":
            ok, label, code = text_ui.show_text_dialog(root, req)
            if ok and label is not None:
                return {"ok": True, "value": label, "exit_code": code}
            if label is not None:
                return {"ok": True, "value": label, "exit_code": code}
            return {"ok": False, "cancelled": True}
        else:
            return {"ok": False, "error": f"unknown op: {op}"}

        if ok and value is not None:
            return {"ok": True, "value": value}
        return {"ok": False, "cancelled": True}
    finally:
        cd_window.cleanup_modal_window(root)
        cd_window.hide_daemon_root(root)


def main() -> None:
    root = tk.Tk()
    cd_window.hide_daemon_root(root)

    _respond({"ok": True, "ready": True})

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError as exc:
            _respond({"ok": False, "error": f"invalid json: {exc}"})
            continue

        op = str(req.get("op", ""))
        if op == "quit":
            root.destroy()
            _respond({"ok": True, "quit": True})
            break

        _respond(_run_dialog(root, op, req))

    raise SystemExit(0)


if __name__ == "__main__":
    main()
