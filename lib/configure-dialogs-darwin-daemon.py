#!/usr/bin/env python3
"""
Sleep Warning System - macOS configure wizard tkinter dialog daemon.

Reads newline-delimited JSON requests from stdin, shows dialogs on a single
hidden Tk root, writes one JSON response line per request to stdout.

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

import configure_dialogs_darwin_list_ui as list_ui  # noqa: E402
import configure_dialogs_darwin_table_ui as table_ui  # noqa: E402
import configure_dialogs_darwin_text_ui as text_ui  # noqa: E402
import configure_dialogs_darwin_time_ui as time_ui  # noqa: E402


def _respond(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def _run_dialog(root: tk.Tk, op: str, req: dict[str, Any]) -> dict[str, Any]:
    dialog = tk.Toplevel(root)
    # Do not call transient(root) while root is withdrawn — on macOS that can
    # prevent the Toplevel from ever appearing.

    try:
        if op == "list":
            ok, value, _code, shown = list_ui.show_list_dialog(dialog, req)
            if ok and value is not None:
                return {"ok": True, "value": value, "shown": shown}
            return {"ok": False, "cancelled": True, "shown": shown}
        elif op == "table":
            ok, value, _code, shown = table_ui.show_table_dialog(dialog, req)
            if ok and value is not None:
                return {"ok": True, "value": value, "shown": shown}
            return {"ok": False, "cancelled": True, "shown": shown}
        elif op == "time":
            ok, value, _code = time_ui.show_time_dialog(dialog, req)
        elif op == "text":
            ok, label, code = text_ui.show_text_dialog(dialog, req)
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
        try:
            if dialog.winfo_exists():
                dialog.grab_release()
        except tk.TclError:
            pass
        try:
            if dialog.winfo_exists():
                dialog.destroy()
        except tk.TclError:
            pass


def main() -> None:
    root = tk.Tk()
    root.withdraw()

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
