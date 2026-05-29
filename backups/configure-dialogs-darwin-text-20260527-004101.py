#!/usr/bin/env python3
"""
Sleep Warning System - macOS scrollable text dialog (tkinter).

Reads JSON from stdin, shows read-only scrollable text (similar to yad/zenity
--text-info). Optional action buttons print the chosen label on stdout.

Expected JSON:
{
  "title": "Configuration Summary",
  "width": 700,
  "height": 500,
  "text": "multiline body...",
  "buttons": ["Yes, Save", "Back to Main Menu"],
  "default_button": "Yes, Save"
}

Without "buttons", shows a single Close button (exit 0, no stdout).
With "buttons", prints the clicked label; exit 0 for save, 1 for back/dismiss.
"""

from __future__ import annotations

import json
import sys
import tkinter as tk
from tkinter import ttk


def _fail(message: str, code: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def _is_save_action(label: str) -> bool:
    lowered = label.lower()
    return lowered.startswith("yes") or "save" in lowered


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        _fail(f"Invalid JSON input: {exc}")

    title = str(payload.get("title", "Information"))
    text = str(payload.get("text", ""))
    width = int(payload.get("width", 700))
    height = int(payload.get("height", 500))
    buttons = payload.get("buttons") or []
    default_button = str(payload.get("default_button", ""))

    if not isinstance(buttons, list):
        buttons = []

    root = tk.Tk()
    root.title(title)
    root.geometry(f"{width}x{height}")
    root.minsize(min(width, 480), min(height, 320))
    root.attributes("-topmost", True)

    main_frame = ttk.Frame(root, padding=12)
    main_frame.pack(fill=tk.BOTH, expand=True)

    text_frame = ttk.Frame(main_frame)
    text_frame.pack(fill=tk.BOTH, expand=True)

    widget = tk.Text(
        text_frame,
        wrap=tk.WORD,
        font=("Menlo", 11),
        state=tk.NORMAL,
        relief=tk.FLAT,
        borderwidth=1,
    )
    vsb = ttk.Scrollbar(text_frame, orient=tk.VERTICAL, command=widget.yview)
    widget.configure(yscrollcommand=vsb.set)
    widget.grid(row=0, column=0, sticky="nsew")
    vsb.grid(row=0, column=1, sticky="ns")
    text_frame.columnconfigure(0, weight=1)
    text_frame.rowconfigure(0, weight=1)

    widget.insert("1.0", text)
    widget.configure(state=tk.DISABLED)

    btn_frame = ttk.Frame(main_frame)
    btn_frame.pack(fill=tk.X, pady=(10, 0))

    def finish(label: str) -> None:
        print(label)
        code = 0 if _is_save_action(label) else 1
        root.quit()
        root.destroy()
        raise SystemExit(code)

    if buttons:
        dismiss_label = str(buttons[-1]) if buttons else "Back to Main Menu"
        if not default_button and buttons:
            default_button = str(buttons[0])

        def on_dismiss() -> None:
            finish(dismiss_label)

        for index in range(len(buttons) - 1, -1, -1):
            label = str(buttons[index])

            def on_click(lbl: str = label) -> None:
                finish(lbl)

            ttk.Button(btn_frame, text=label, command=on_click).pack(
                side=tk.RIGHT,
                padx=(8, 0) if index < len(buttons) - 1 else (0, 0),
            )

        def on_return(_event: tk.Event) -> None:
            finish(default_button)

        root.bind("<Return>", on_return)
        root.protocol("WM_DELETE_WINDOW", on_dismiss)
        root.bind("<Escape>", lambda _e: on_dismiss())
    else:

        def on_close() -> None:
            root.quit()
            root.destroy()

        ttk.Button(btn_frame, text="Close", command=on_close).pack(side=tk.RIGHT)
        root.protocol("WM_DELETE_WINDOW", on_close)
        root.bind("<Escape>", lambda _e: on_close())

    root.after(150, lambda: root.attributes("-topmost", False))
    root.mainloop()
    raise SystemExit(0)


if __name__ == "__main__":
    main()
