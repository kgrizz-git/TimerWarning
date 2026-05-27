#!/usr/bin/env python3
"""
Sleep Warning System - macOS multi-column table dialog (tkinter).

Reads JSON from stdin, shows a resizable columnar list (similar to yad/zenity
--list with multiple columns), prints the selected cell from print_column on
stdout, exit 0 on OK or 1 on cancel.

Expected JSON:
{
  "title": "...",
  "message": "...",
  "width": 1050,
  "height": 500,
  "print_column": 1,
  "columns": ["Day", "Restricted Hours", ...],
  "rows": [["Sunday", "12:00am -> 5:00am", ...], ...]
}
"""

from __future__ import annotations

import json
import sys
import tkinter as tk
from tkinter import ttk


def _fail(message: str, code: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        _fail(f"Invalid JSON input: {exc}")

    title = str(payload.get("title", "Select"))
    message = str(payload.get("message", ""))
    width = int(payload.get("width", 900))
    height = int(payload.get("height", 500))
    print_column = int(payload.get("print_column", 1))
    columns = payload.get("columns") or []
    rows = payload.get("rows") or []

    if not columns:
        _fail("No columns provided")
    if print_column < 1 or print_column > len(columns):
        _fail(f"print_column {print_column} out of range")

    result: dict[str, str | None] = {"value": None}

    root = tk.Tk()
    root.title(title)
    root.geometry(f"{width}x{height}")
    root.minsize(min(width, 640), min(height, 320))

    # Briefly stay on top so the dialog is noticed, then allow normal stacking.
    root.attributes("-topmost", True)

    main_frame = ttk.Frame(root, padding=12)
    main_frame.pack(fill=tk.BOTH, expand=True)

    if message:
        prompt = ttk.Label(main_frame, text=message, wraplength=max(width - 48, 400), justify=tk.LEFT)
        prompt.pack(fill=tk.X, pady=(0, 10))

    tree_frame = ttk.Frame(main_frame)
    tree_frame.pack(fill=tk.BOTH, expand=True)

    tree = ttk.Treeview(tree_frame, columns=[f"c{i}" for i in range(len(columns))], show="headings", selectmode="browse")
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
        # Wider defaults for hour columns; day column stays compact.
        min_w = 110 if idx == 0 else 180
        tree.column(col_id, width=min_w, minwidth=min_w, stretch=True)

    for row_idx, row in enumerate(rows):
        values = []
        for idx in range(len(columns)):
            values.append(str(row[idx]) if idx < len(row) else "")
        tree.insert("", tk.END, iid=str(row_idx), values=values)

    btn_frame = ttk.Frame(main_frame)
    btn_frame.pack(fill=tk.X, pady=(12, 0))

    def accept() -> None:
        sel = tree.selection()
        if not sel:
            return
        row = rows[int(sel[0])]
        result["value"] = str(row[print_column - 1])
        root.destroy()

    def cancel() -> None:
        result["value"] = None
        root.destroy()

    ok_btn = ttk.Button(btn_frame, text="OK", command=accept)
    cancel_btn = ttk.Button(btn_frame, text="Cancel", command=cancel)
    cancel_btn.pack(side=tk.RIGHT)
    ok_btn.pack(side=tk.RIGHT, padx=(0, 8))

    tree.bind("<Double-1>", lambda _event: accept())
    root.bind("<Return>", lambda _event: accept())
    root.bind("<Escape>", lambda _event: cancel())

    if rows:
        tree.selection_set("0")
        tree.focus("0")

    root.after(150, lambda: root.attributes("-topmost", False))
    root.protocol("WM_DELETE_WINDOW", cancel)
    root.mainloop()

    if result["value"] is None:
        raise SystemExit(1)
    print(result["value"])
    raise SystemExit(0)


if __name__ == "__main__":
    main()
