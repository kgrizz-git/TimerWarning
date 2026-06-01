#!/usr/bin/env python3
"""
Reusable tkinter time-range dialog for macOS configure wizard.
"""

from __future__ import annotations

from typing import Any

import tkinter as tk
from tkinter import ttk

import configure_dialogs_darwin_window as _cd_window

HOURS = [str(h) for h in range(1, 13)]
MINUTES = ["00", "15", "30", "45"]
AMPM = ["AM", "PM"]


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
    allowed = {"00", "15", "30", "45"}
    v = str(value).strip().zfill(2)
    if v in allowed:
        return v
    try:
        m = int(v)
        return f"{((m + 7) // 15 * 15) % 60:02d}"
    except ValueError:
        return "00"


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


def show_time_dialog(window: tk.Misc, payload: dict[str, Any]) -> tuple[bool, str | None, int]:
    """Show time-range picker on *window*. Returns (accepted, value, exit_code)."""
    title = str(payload.get("title", "Time Range"))
    day_name = str(payload.get("day_name", "")).strip()
    hint_text = str(payload.get("hint_text", "")).strip()
    width = int(payload.get("width", 520))
    height = int(payload.get("height", 360))
    start_defaults = payload.get("start") or {}
    end_defaults = payload.get("end") or {}

    result: dict[str, str | None] = {"value": None}

    window.title(title)
    _cd_window.set_stable_geometry(window, width, height)
    window.minsize(480, 320)
    _cd_window.apply_initial_frontmost(window)  # type: ignore[arg-type]

    outer = ttk.Frame(window, padding=14)
    outer.pack(fill=tk.BOTH, expand=True)

    if day_name:
        ttk.Label(outer, text=f"Day: {day_name}", font=("", 12, "bold")).pack(anchor=tk.W, pady=(0, 4))

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
        _cd_window.close_modal(window)

    def cancel() -> None:
        result["value"] = None
        _cd_window.close_modal(window)

    ttk.Button(btn_row, text="Cancel", command=cancel).pack(side=tk.RIGHT)
    ttk.Button(btn_row, text="OK", command=accept).pack(side=tk.RIGHT, padx=(0, 8))

    window.bind("<Return>", lambda _e: accept())
    window.bind("<Escape>", lambda _e: cancel())
    window.protocol("WM_DELETE_WINDOW", cancel)
    _cd_window.run_modal(window)

    _cd_window.cleanup_modal_window(window)

    if result["value"] is None:
        return False, None, 1
    return True, result["value"], 0
