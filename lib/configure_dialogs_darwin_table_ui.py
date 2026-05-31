#!/usr/bin/env python3
"""
Reusable tkinter table dialog for macOS configure wizard.

Used by configure-dialogs-darwin-table.py (one-shot CLI) and the dialog daemon.
"""

from __future__ import annotations

from typing import Any

import tkinter as tk
from tkinter import ttk

import configure_dialogs_darwin_window as _cd_window


def show_table_dialog(window: tk.Misc, payload: dict[str, Any]) -> tuple[bool, str | None, int, bool]:
    """
    Show a multi-column table dialog on *window* (Tk or Toplevel).

    Returns:
        (accepted, selected_value, exit_code, shown) where exit_code is 0 on OK,
        1 on cancel, and *shown* is True if the window ever became visible. On
        macOS a Toplevel on a withdrawn root can fail to map and return
        immediately; *shown* lets callers tell that apart from a real cancel.
    """
    title = str(payload.get("title", "Select"))
    message = str(payload.get("message", ""))
    width = int(payload.get("width", 900))
    height = int(payload.get("height", 500))
    print_column = int(payload.get("print_column", 1))
    columns = payload.get("columns") or []
    rows = payload.get("rows") or []

    if not columns:
        raise ValueError("No columns provided")
    if print_column < 1 or print_column > len(columns):
        raise ValueError(f"print_column {print_column} out of range")

    result: dict[str, str | None] = {"value": None}
    visible: dict[str, bool] = {"shown": False}

    window.title(title)
    window.geometry(f"{width}x{height}")
    window.minsize(min(width, 640), min(height, 320))

    def _mark_shown(_event: Any = None) -> None:
        visible["shown"] = True

    window.bind("<Map>", _mark_shown, add="+")
    _cd_window.apply_initial_frontmost(window)  # type: ignore[arg-type]

    main_frame = ttk.Frame(window, padding=12)
    main_frame.pack(fill=tk.BOTH, expand=True)

    if message:
        prompt = ttk.Label(main_frame, text=message, wraplength=max(width - 48, 400), justify=tk.LEFT)
        prompt.pack(fill=tk.X, pady=(0, 10))

    tree_frame = ttk.Frame(main_frame)
    tree_frame.pack(fill=tk.BOTH, expand=True)

    tree = ttk.Treeview(
        tree_frame,
        columns=[f"c{i}" for i in range(len(columns))],
        show="headings",
        selectmode="browse",
    )
    vsb = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=tree.yview)
    hsb = ttk.Scrollbar(tree_frame, orient=tk.HORIZONTAL, command=tree.xview)
    tree.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)

    tree.grid(row=0, column=0, sticky="nsew")
    vsb.grid(row=0, column=1, sticky="ns")
    hsb.grid(row=1, column=0, sticky="ew")
    tree_frame.rowconfigure(0, weight=1)
    tree_frame.columnconfigure(0, weight=1)

    col_ids = [f"c{i}" for i in range(len(columns))]
    for idx, heading in enumerate(columns):
        col_id = col_ids[idx]
        tree.heading(col_id, text=heading)
        min_w = 110 if idx == 0 else 180
        tree.column(col_id, width=min_w, minwidth=min_w, stretch=True)

    for row_idx, row in enumerate(rows):
        values = [str(row[idx]) if idx < len(row) else "" for idx in range(len(columns))]
        tree.insert("", tk.END, iid=str(row_idx), values=values)

    btn_frame = ttk.Frame(main_frame)
    btn_frame.pack(fill=tk.X, pady=(12, 0))

    def accept() -> None:
        sel = tree.selection()
        if not sel:
            return
        row = rows[int(sel[0])]
        result["value"] = str(row[print_column - 1])
        _cd_window.close_modal(window)

    def cancel() -> None:
        result["value"] = None
        _cd_window.close_modal(window)

    cancel_btn = ttk.Button(btn_frame, text="Cancel", command=cancel)
    ok_btn = ttk.Button(btn_frame, text="OK", command=accept)
    cancel_btn.pack(side=tk.RIGHT)
    ok_btn.pack(side=tk.RIGHT, padx=(0, 8))

    tree.bind("<Double-1>", lambda _event: accept())
    window.bind("<Return>", lambda _event: accept())
    window.bind("<Escape>", lambda _event: cancel())

    if rows:
        tree.selection_set("0")
        tree.focus("0")

    window.protocol("WM_DELETE_WINDOW", cancel)
    _cd_window.run_modal(window)

    # Clear bindings/widgets before reuse in daemon mode.
    _cd_window.cleanup_modal_window(window)

    if result["value"] is None:
        return False, None, 1, visible["shown"]
    return True, result["value"], 0, visible["shown"]
