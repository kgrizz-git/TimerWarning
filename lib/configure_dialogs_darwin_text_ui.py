#!/usr/bin/env python3
"""
Reusable tkinter scrollable text dialog for macOS configure wizard.
"""

from __future__ import annotations

from typing import Any

import tkinter as tk
from tkinter import ttk

import configure_dialogs_darwin_window as _cd_window


def _is_save_action(label: str) -> bool:
    lowered = label.lower()
    return lowered.startswith("yes") or "save" in lowered


def show_text_dialog(window: tk.Misc, payload: dict[str, Any]) -> tuple[bool, str | None, int]:
    """
    Show scrollable text dialog on *window*.

    Returns (accepted, button_label_or_none, exit_code).
    exit_code 0 = save/primary action, 1 = back/dismiss.
    """
    title = str(payload.get("title", "Information"))
    text = str(payload.get("text", ""))
    width = int(payload.get("width", 700))
    height = int(payload.get("height", 500))
    buttons = payload.get("buttons") or []
    default_button = str(payload.get("default_button", ""))

    if not isinstance(buttons, list):
        buttons = []

    result: dict[str, str | None] = {"label": None, "code": 0}

    window.title(title)
    window.geometry(f"{width}x{height}")
    window.minsize(min(width, 480), min(height, 320))
    _cd_window.apply_initial_frontmost(window)  # type: ignore[arg-type]

    main_frame = ttk.Frame(window, padding=12)
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
        result["label"] = label
        result["code"] = 0 if _is_save_action(label) else 1
        _cd_window.close_modal(window)

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

        window.bind("<Return>", lambda _event: finish(default_button))
        window.protocol("WM_DELETE_WINDOW", on_dismiss)
        window.bind("<Escape>", lambda _e: on_dismiss())
    else:

        def on_close() -> None:
            result["label"] = None
            result["code"] = 0
            _cd_window.close_modal(window)

        ttk.Button(btn_frame, text="Close", command=on_close).pack(side=tk.RIGHT)
        window.protocol("WM_DELETE_WINDOW", on_close)
        window.bind("<Escape>", lambda _e: on_close())

    _cd_window.run_modal(window)

    _cd_window.cleanup_modal_window(window)

    if buttons:
        if result["label"] is None:
            return False, None, 1
        return result["code"] == 0, result["label"], result["code"]

    return True, result["label"], 0
