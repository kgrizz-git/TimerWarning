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


def close_modal(window: tk.Misc) -> None:
    """
    Dismiss a dialog started by run_modal().

    Toplevel (daemon): destroy the window so wait_window() returns.
    Tk root (one-shot CLI): quit the mainloop.
    """
    if isinstance(window, tk.Toplevel):
        window.destroy()
    else:
        window.quit()


def run_modal(window: tk.Misc) -> None:
    """
    Block until the dialog closes.

    Daemon mode passes a Toplevel on a hidden root. On macOS the Toplevel must
    be deiconified explicitly and the hidden root must wait for it; calling
    wait_window() on the Toplevel alone can return immediately without showing UI.
    One-shot CLIs pass Tk() and use mainloop().
    """
    window.update_idletasks()
    if isinstance(window, tk.Toplevel):
        root = window.master
        try:
            window.deiconify()
            window.state("normal")
            window.lift()
            window.grab_set()
        except tk.TclError:
            pass
        try:
            root.wait_window(window)
        finally:
            try:
                window.grab_release()
            except tk.TclError:
                pass
    else:
        window.mainloop()


def cleanup_modal_window(window: tk.Misc) -> None:
    """Remove child widgets when reusing a window, or no-op if already destroyed."""
    try:
        if not window.winfo_exists():
            return
    except tk.TclError:
        return
    for child in window.winfo_children():
        child.destroy()


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
