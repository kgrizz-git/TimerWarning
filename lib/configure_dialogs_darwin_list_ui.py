#!/usr/bin/env python3
"""
Reusable single-column tkinter list dialog for macOS configure wizard.

Replaces the osascript `choose from list` picker so the main menu, submenus, and
true/false prompts render on the same daemon root as the weekly grid (consistent
z-order, no per-prompt process spawn). Used by the dialog daemon
(configure-dialogs-darwin-daemon.py); osascript remains the fallback when the
daemon is unavailable.
"""

from __future__ import annotations

from typing import Any

import tkinter as tk
from tkinter import ttk

import configure_dialogs_darwin_window as _cd_window


def show_list_dialog(window: tk.Misc, payload: dict[str, Any]) -> tuple[bool, str | None, int, bool]:
    """
    Show a single-column list picker on *window* (Tk or Toplevel).

    Returns:
        (accepted, selected_value, exit_code, shown) where exit_code is 0 on OK,
        1 on cancel, and *shown* is True if the window ever became visible. The
        selected value is the item string itself, matching the osascript
        `choose from list` contract. On macOS a Toplevel on a withdrawn root can
        fail to map and return immediately; *shown* lets callers tell that apart
        from a real cancel.
    """
    title = str(payload.get("title", "Select"))
    message = str(payload.get("message", ""))
    width = int(payload.get("width", 500))
    height = int(payload.get("height", 300))
    items = [str(item) for item in (payload.get("items") or [])]

    if not items:
        raise ValueError("No items provided")

    result: dict[str, str | None] = {"value": None}
    visible: dict[str, bool] = {"shown": False}

    window.title(title)
    window.geometry(f"{width}x{height}")
    window.minsize(min(width, 360), min(height, 200))

    def _mark_shown(_event: Any = None) -> None:
        visible["shown"] = True

    window.bind("<Map>", _mark_shown, add="+")
    _cd_window.apply_initial_frontmost(window)  # type: ignore[arg-type]

    main_frame = ttk.Frame(window, padding=12)
    main_frame.pack(fill=tk.BOTH, expand=True)

    if message:
        prompt = ttk.Label(main_frame, text=message, wraplength=max(width - 48, 320), justify=tk.LEFT)
        prompt.pack(fill=tk.X, pady=(0, 10))

    list_frame = ttk.Frame(main_frame)
    list_frame.pack(fill=tk.BOTH, expand=True)

    listbox = tk.Listbox(list_frame, selectmode=tk.BROWSE, activestyle="dotbox", exportselection=False)
    vsb = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=listbox.yview)
    listbox.configure(yscrollcommand=vsb.set)
    listbox.grid(row=0, column=0, sticky="nsew")
    vsb.grid(row=0, column=1, sticky="ns")
    list_frame.rowconfigure(0, weight=1)
    list_frame.columnconfigure(0, weight=1)

    for item in items:
        listbox.insert(tk.END, item)

    btn_frame = ttk.Frame(main_frame)
    btn_frame.pack(fill=tk.X, pady=(12, 0))

    def accept(_event: Any = None) -> None:
        sel = listbox.curselection()
        if not sel:
            return
        result["value"] = items[int(sel[0])]
        _cd_window.close_modal(window)

    def cancel(_event: Any = None) -> None:
        result["value"] = None
        _cd_window.close_modal(window)

    cancel_btn = ttk.Button(btn_frame, text="Cancel", command=cancel)
    ok_btn = ttk.Button(btn_frame, text="OK", command=accept)
    cancel_btn.pack(side=tk.RIGHT)
    ok_btn.pack(side=tk.RIGHT, padx=(0, 8))

    listbox.bind("<Double-1>", accept)
    window.bind("<Return>", accept)
    window.bind("<Escape>", cancel)

    listbox.selection_set(0)
    listbox.activate(0)
    listbox.focus_set()

    window.protocol("WM_DELETE_WINDOW", cancel)
    _cd_window.run_modal(window)

    # Clear bindings/widgets before reuse in daemon mode.
    _cd_window.cleanup_modal_window(window)

    if result["value"] is None:
        return False, None, 1, visible["shown"]
    return True, result["value"], 0, visible["shown"]
