#!/usr/bin/env python3
"""
Shared window stacking for macOS configure wizard tkinter dialogs.

Shows each window on top and focused when it first opens. Clears -topmost when
the user focuses another window (does not stay above other apps after that).
"""

from __future__ import annotations

from typing import Any

import tkinter as tk

# Ignore brief FocusOut events while the window is still being mapped.
_GRACE_MS = 400


def apply_initial_frontmost(root: tk.Tk) -> None:
    """
    Raise *root* above other windows and request keyboard focus.

    Re-asserts once after idle mapping. Drops -topmost on FocusOut once the
    open grace period ends so the user can click behind the dialog normally.
    """
    grace = {"active": True}

    def _set_topmost(enabled: bool) -> None:
        try:
            root.attributes("-topmost", enabled)
        except tk.TclError:
            pass

    def _raise_and_focus() -> None:
        try:
            root.lift()
            root.update_idletasks()
            root.focus_force()
            _set_topmost(True)
        except tk.TclError:
            pass

    def _drop_topmost(_event: Any = None) -> None:
        if grace["active"]:
            return
        _set_topmost(False)

    def _end_grace() -> None:
        grace["active"] = False

    _raise_and_focus()
    root.bind("<FocusOut>", _drop_topmost, add="+")
    root.after(_GRACE_MS, _end_grace)
    root.after(50, _raise_and_focus)
    root.after_idle(_raise_and_focus)
