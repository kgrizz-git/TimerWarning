#!/usr/bin/env python3
"""
Sleep Warning System - macOS time-range picker (tkinter).

Mirrors the Linux yad/zenity time dialog: 12-hour hour + 00/30 minute + AM/PM
for start and end. Reads JSON from stdin, prints one line on stdout in the
format expected by normalize_time_range (e.g. 11:00PM-5:00AM), exit 0 on OK
or 1 on cancel.

Expected JSON:
{
  "title": "...",
  "day_name": "Monday",
  "hint_text": "Press Cancel to skip this day.",
  "start": {"hour": 11, "minute": "00", "ampm": "PM"},
  "end": {"hour": 5, "minute": "00", "ampm": "AM"},
  "width": 520,
  "height": 360
}
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import tkinter as tk
from tkinter import ttk

sys.path.insert(0, str(Path(__file__).resolve().parent))
import configure_dialogs_darwin_window as _cd_window  # noqa: E402


HOURS = [str(h) for h in range(1, 13)]
MINUTES = ["00", "30"]
AMPM = ["AM", "PM"]


def _fail(message: str, code: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def _norm_hour(value: int | str) -> str:
    try:
        h = int(value)
    except (TypeError, ValueError):
        h = 11
    if h < 1:
        h = 12
    elif h > 12:
        h = ((h - 1) % 12) + 1
    return str(h)


def _norm_minute(value: str) -> str:
    return "30" if str(value).strip() == "30" else "00"


def _norm_ampm(value: str) -> str:
    return "PM" if str(value).strip().upper() == "PM" else "AM"


def _time_block(parent: tk.Misc, label: str, defaults: dict) -> dict[str, ttk.Combobox]:
    frame = ttk.LabelFrame(parent, text=label, padding=(12, 8))
    frame.pack(fill=tk.X, pady=(0, 10))

    row = ttk.Frame(frame)
    row.pack(fill=tk.X)

    ttk.Label(row, text="Hour:").grid(row=0, column=0, padx=(0, 6), sticky=tk.W)
    hour = ttk.Combobox(row, values=HOURS, width=4, state="readonly")
    hour.set(_norm_hour(defaults.get("hour", 11)))
    hour.grid(row=0, column=1, padx=(0, 16))

    ttk.Label(row, text="Minute:").grid(row=0, column=2, padx=(0, 6), sticky=tk.W)
    minute = ttk.Combobox(row, values=MINUTES, width=4, state="readonly")
    minute.set(_norm_minute(defaults.get("minute", "00")))
    minute.grid(row=0, column=3, padx=(0, 16))

    ttk.Label(row, text="AM/PM:").grid(row=0, column=4, padx=(0, 6), sticky=tk.W)
    ampm = ttk.Combobox(row, values=AMPM, width=5, state="readonly")
    ampm.set(_norm_ampm(defaults.get("ampm", "AM")))
    ampm.grid(row=0, column=5)

    return {"hour": hour, "minute": minute, "ampm": ampm}


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        _fail(f"Invalid JSON input: {exc}")

    title = str(payload.get("title", "Time Range"))
    day_name = str(payload.get("day_name", "")).strip()
    hint_text = str(payload.get("hint_text", "")).strip()
    width = int(payload.get("width", 520))
    height = int(payload.get("height", 360))
    start_defaults = payload.get("start") or {}
    end_defaults = payload.get("end") or {}

    result: dict[str, str | None] = {"value": None}

    root = tk.Tk()
    root.title(title)
    root.geometry(f"{width}x{height}")
    root.minsize(480, 320)
    _cd_window.apply_initial_frontmost(root)

    outer = ttk.Frame(root, padding=14)
    outer.pack(fill=tk.BOTH, expand=True)

    if day_name:
        ttk.Label(
            outer,
            text=f"Day: {day_name}",
            font=("", 12, "bold"),
        ).pack(anchor=tk.W, pady=(0, 4))

    if hint_text:
        ttk.Label(outer, text=hint_text, wraplength=max(width - 48, 400), justify=tk.LEFT).pack(
            anchor=tk.W, pady=(0, 10)
        )

    start_widgets = _time_block(outer, "Start Time", start_defaults)
    end_widgets = _time_block(outer, "End Time", end_defaults)

    btn_row = ttk.Frame(outer)
    btn_row.pack(fill=tk.X, pady=(12, 0))

    def accept() -> None:
        sh = _norm_hour(start_widgets["hour"].get())
        sm = _norm_minute(start_widgets["minute"].get())
        sap = _norm_ampm(start_widgets["ampm"].get())
        eh = _norm_hour(end_widgets["hour"].get())
        em = _norm_minute(end_widgets["minute"].get())
        eap = _norm_ampm(end_widgets["ampm"].get())
        result["value"] = f"{sh}:{sm}{sap}-{eh}:{em}{eap}"
        root.destroy()

    def cancel() -> None:
        result["value"] = None
        root.destroy()

    ttk.Button(btn_row, text="Cancel", command=cancel).pack(side=tk.RIGHT)
    ttk.Button(btn_row, text="OK", command=accept).pack(side=tk.RIGHT, padx=(0, 8))

    root.bind("<Return>", lambda _e: accept())
    root.bind("<Escape>", lambda _e: cancel())
    root.protocol("WM_DELETE_WINDOW", cancel)
    root.mainloop()

    if result["value"] is None:
        raise SystemExit(1)
    print(result["value"])
    raise SystemExit(0)


if __name__ == "__main__":
    main()
