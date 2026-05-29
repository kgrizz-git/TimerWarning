#!/usr/bin/env python3
"""
Sleep Warning System - macOS Fullscreen Blocking Popup.

Displays a full-screen dark overlay that covers the entire display.  The OK
button is disabled until the configured minimum display time has elapsed
(live countdown shown in the UI).  An auto-close countdown is also shown when
applicable.

Two rendering paths (auto-selected at startup):
  1. tkinter + optional pyobjc boost  (always available — tkinter ships with
     Homebrew/pyenv Python; pyobjc raises the window to NSScreenSaverWindowLevel
     so it stays above fullscreen Spaces when installed)
  2. osascript fallback               (handled by the shell dispatcher; this
     script always uses tkinter)

To enable the pyobjc boost:
    pip3 install pyobjc-core pyobjc-framework-Cocoa

Input  — JSON object read from stdin:
    {
      "title":                  "ALERT: Restricted time window",
      "message":                "You are in a restricted period.\\nNext free: 3 PM",
      "min_display_seconds":    30,    # 0 = OK available immediately
      "auto_close_seconds":     40,    # 0 = no auto-close (watchdog still applies)
      "pause_available":        true,
      "pause_duration_minutes": 5,
      "result_file":            "/tmp/sw_popup_result.XXXXX"
    }

Output:
    result_file  — written with "OK" or "Pause N min" before exit
    exit code 0  — dismissed (OK or auto-close)
    exit code 2  — pause requested
"""
from __future__ import annotations

import json
import sys
import threading
import time
from pathlib import Path
from typing import Any

# ── optional pyobjc (raises window to NSScreenSaverWindowLevel) ──────────────
_HAS_PYOBJC = False
try:
    import AppKit  # type: ignore[import-untyped]
    import objc    # type: ignore[import-untyped]
    _HAS_PYOBJC = True
except ImportError:
    pass

# ── colour palette (dark-mode inspired) ──────────────────────────────────────
_BG_OVERLAY  = "#0a0a0a"   # full-screen overlay background
_BG_PANEL    = "#1c1c1e"   # centre content panel
_CLR_ICON    = "#FF9500"   # warning icon (orange)
_CLR_TITLE   = "#FFFFFF"
_CLR_BODY    = "#EBEBF5"   # off-white body text
_CLR_WARN    = "#FF453A"   # countdown / alert text (red)
_CLR_OK_OFF  = "#3A3A3C"   # OK button while locked
_CLR_OK_ON   = "#34C759"   # OK button when enabled (green)
_CLR_PAUSE   = "#FF9500"   # pause button (orange)
# Use dark text for both enabled and disabled button labels so they remain
# readable against the light native button chrome on macOS (including dark mode).
_CLR_BTN_TXT = "#111111"
_CLR_BTN_TXT_DISABLED = "#555555"


# ── helpers ───────────────────────────────────────────────────────────────────

def _write_result(path: str, label: str) -> None:
    """Write the chosen button label to result_file so the shell can read it."""
    if not path:
        return
    try:
        Path(path).write_text(label + "\n", encoding="utf-8")
    except OSError:
        pass


def _screen_pixels(root: "Any") -> tuple[int, int]:
    """
    Return main display size in points. Prefer NSScreen (reliable under launchd);
    fall back to tk screen metrics, then a safe default if GUI session is broken.
    """
    if _HAS_PYOBJC:
        try:
            screen = AppKit.NSScreen.mainScreen()
            if screen is not None:
                frame = screen.frame()
                w, h = int(frame.size.width), int(frame.size.height)
                if w >= 200 and h >= 200:
                    return w, h
        except Exception:
            pass
    import tkinter as tk

    w = int(root.winfo_screenwidth())
    h = int(root.winfo_screenheight())
    if w >= 200 and h >= 200:
        return w, h
    print(
        f"popup-blocker: tk screen size unusable ({w}x{h}); using 1728x1117 fallback",
        file=sys.stderr,
    )
    return 1728, 1117


def _nswindow_fill_screen(title: str, width: int, height: int) -> None:
    """Resize the Cocoa window backing this tk root to cover the main display."""
    if not _HAS_PYOBJC:
        return
    try:
        for win in AppKit.NSApplication.sharedApplication().windows():
            if win.title() == title:
                # NSScreen frame origin is bottom-left; y=0 base fills primary display.
                win.setFrame_display_(
                    AppKit.NSMakeRect(0, 0, width, height),
                    True,
                )
                win.setLevel_(AppKit.NSScreenSaverWindowLevel)
                win.makeKeyAndOrderFront_(None)
                return
    except Exception:
        pass


def _apply_fullscreen(root: "Any", title: str, screen_w: int, screen_h: int) -> str:
    """
    Force a true full-screen overlay. Tk -fullscreen is ignored in some LaunchAgent
    contexts; fall back to borderless geometry + Cocoa frame when needed.
    Returns a short mode tag for stderr diagnostics.
    """
    import tkinter as tk

    root.geometry(f"{screen_w}x{screen_h}+0+0")
    try:
        root.attributes("-fullscreen", True)
        root.attributes("-topmost", True)
    except tk.TclError:
        pass
    root.update_idletasks()
    rw, rh = root.winfo_width(), root.winfo_height()
    if rw >= int(screen_w * 0.85) and rh >= int(screen_h * 0.85):
        return "native-fullscreen"

    try:
        root.attributes("-fullscreen", False)
    except tk.TclError:
        pass
    try:
        root.overrideredirect(True)
    except tk.TclError:
        pass
    root.geometry(f"{screen_w}x{screen_h}+0+0")
    root.update_idletasks()
    _nswindow_fill_screen(title, screen_w, screen_h)
    return "geometry-fullscreen"


def _boost_window_level(title: str) -> None:
    """
    Find the tkinter NSWindow by title and raise it to NSScreenSaverWindowLevel
    with collection-behaviour flags that keep it above fullscreen Spaces.
    No-op if pyobjc is unavailable or the window cannot be found.
    """
    if not _HAS_PYOBJC:
        return
    try:
        _CanJoinAll   = AppKit.NSWindowCollectionBehaviorCanJoinAllSpaces
        _FSAux        = AppKit.NSWindowCollectionBehaviorFullScreenAuxiliary
        _Stationary   = AppKit.NSWindowCollectionBehaviorStationary
        _IgnoreCycle  = AppKit.NSWindowCollectionBehaviorIgnoresCycle

        for win in AppKit.NSApplication.sharedApplication().windows():
            if win.title() == title:
                win.setLevel_(AppKit.NSScreenSaverWindowLevel)
                win.setCollectionBehavior_(
                    _CanJoinAll | _FSAux | _Stationary | _IgnoreCycle
                )
                win.makeKeyAndOrderFront_(None)
                return
    except Exception:  # pyobjc boost is best-effort
        pass


# ── main blocker ──────────────────────────────────────────────────────────────

def run_blocker(payload: dict[str, Any]) -> int:
    """
    Build and run the fullscreen tkinter blocking popup.
    Returns 0 for OK/auto-close, 2 for pause.
    """
    import tkinter as tk

    title               = str(payload.get("title", "Sleep Warning"))
    message             = str(payload.get("message", ""))
    min_display         = int(payload.get("min_display_seconds", 0))
    auto_close          = int(payload.get("auto_close_seconds", 0))
    pause_available     = bool(payload.get("pause_available", False))
    pause_duration      = int(payload.get("pause_duration_minutes", 0))
    result_file         = str(payload.get("result_file", ""))

    exit_code: list[int] = [0]
    dismissed = threading.Event()

    # ── root window ───────────────────────────────────────────────────────────
    root = tk.Tk()
    root.title(title)
    root.configure(bg=_BG_OVERLAY)

    screen_w, screen_h = _screen_pixels(root)
    fs_mode = _apply_fullscreen(root, title, screen_w, screen_h)
    print(
        f"popup-blocker: display={screen_w}x{screen_h} fullscreen_mode={fs_mode} "
        f"pyobjc={_HAS_PYOBJC}",
        file=sys.stderr,
    )

    root.focus_force()
    try:
        root.grab_set()
    except tk.TclError:
        pass  # grab_set may fail in headless/restricted environments

    # Prevent the OS close button from bypassing the min-display lock
    root.protocol("WM_DELETE_WINDOW", lambda: None)

    panel_w = max(400, min(720, screen_w - 80))

    # ── finish helper ─────────────────────────────────────────────────────────
    def _finish(label: str, code: int = 0) -> None:
        if dismissed.is_set():
            return
        dismissed.set()
        _write_result(result_file, label)
        exit_code[0] = code
        try:
            root.grab_release()
        except tk.TclError:
            pass
        try:
            root.quit()
            root.destroy()
        except tk.TclError:
            pass

    # ── layout: overlay canvas + centre panel ─────────────────────────────────
    canvas = tk.Canvas(root, bg=_BG_OVERLAY, highlightthickness=0)
    canvas.place(relwidth=1, relheight=1)

    panel = tk.Frame(root, bg=_BG_PANEL, padx=44, pady=36)
    panel.place(relx=0.5, rely=0.5, anchor="center", width=panel_w)

    # ── warning icon ──────────────────────────────────────────────────────────
    tk.Label(
        panel,
        text="⚠",
        font=("Helvetica Neue", 60),
        fg=_CLR_ICON,
        bg=_BG_PANEL,
    ).pack(pady=(8, 4))

    # ── title ─────────────────────────────────────────────────────────────────
    tk.Label(
        panel,
        text="Sleep Warning",
        font=("Helvetica Neue", 26, "bold"),
        fg=_CLR_TITLE,
        bg=_BG_PANEL,
        wraplength=panel_w - 100,
        justify="center",
    ).pack(pady=(0, 14))

    # ── message body ──────────────────────────────────────────────────────────
    tk.Label(
        panel,
        text=message,
        font=("Helvetica Neue", 14),
        fg=_CLR_BODY,
        bg=_BG_PANEL,
        wraplength=panel_w - 80,
        justify="center",
    ).pack(pady=(0, 18))

    # ── separator ─────────────────────────────────────────────────────────────
    tk.Frame(panel, height=1, bg="#3A3A3C").pack(fill=tk.X, padx=8, pady=(0, 14))

    # ── live countdown label ──────────────────────────────────────────────────
    countdown_var = tk.StringVar(value="")
    tk.Label(
        panel,
        textvariable=countdown_var,
        font=("Helvetica Neue", 13),
        fg=_CLR_WARN,
        bg=_BG_PANEL,
        wraplength=panel_w - 80,
        justify="center",
    ).pack(pady=(0, 14))

    # ── buttons ───────────────────────────────────────────────────────────────
    btn_frame = tk.Frame(panel, bg=_BG_PANEL)
    btn_frame.pack(pady=(6, 10))

    _btn_kw = dict(
        font=("Helvetica Neue", 15, "bold"),
        fg=_CLR_BTN_TXT,
        activeforeground=_CLR_BTN_TXT,
        disabledforeground=_CLR_BTN_TXT_DISABLED,
        bd=0,
        padx=26,
        pady=12,
        cursor="arrow",
        relief=tk.FLAT,
        highlightthickness=0,
    )

    if pause_available and pause_duration > 0:
        pause_label = f"Pause {pause_duration} min"
        tk.Button(
            btn_frame,
            text=pause_label,
            bg=_CLR_PAUSE,
            activebackground=_CLR_PAUSE,
            command=lambda: _finish(pause_label, 2),
            **_btn_kw,
        ).pack(side=tk.LEFT, padx=(0, 14))

    ok_text   = tk.StringVar(value="OK" if min_display <= 0 else f"OK ({min_display}s)")
    ok_enabled: list[bool] = [min_display <= 0]

    ok_btn = tk.Button(
        btn_frame,
        textvariable=ok_text,
        bg=_CLR_OK_ON if ok_enabled[0] else _CLR_OK_OFF,
        activebackground=_CLR_OK_ON,
        state=tk.NORMAL if ok_enabled[0] else tk.DISABLED,
        command=lambda: _finish("OK", 0),
        **_btn_kw,
    )
    ok_btn.pack(side=tk.LEFT)

    # ── keyboard shortcuts (only active when OK is enabled) ───────────────────
    def _maybe_dismiss(_event: "tk.Event[Any] | None" = None) -> None:
        if ok_enabled[0]:
            _finish("OK", 0)

    root.bind("<Return>", _maybe_dismiss)
    root.bind("<Escape>", _maybe_dismiss)

    # ── tick: countdown + auto-close + keep-on-top ───────────────────────────
    start_mono = time.monotonic()

    def _tick() -> None:
        if dismissed.is_set():
            return

        elapsed = time.monotonic() - start_mono

        if not ok_enabled[0]:
            remaining = max(0.0, min_display - elapsed)
            if remaining <= 0:
                ok_enabled[0] = True
                ok_btn.config(bg=_CLR_OK_ON, state=tk.NORMAL)
                ok_text.set("OK")
                # Show auto-close info now if applicable
                if auto_close > 0:
                    left = max(0.0, auto_close - elapsed)
                    s = int(left) + 1
                    countdown_var.set(
                        f"Auto-closing in {s} second{'s' if s != 1 else ''}…"
                    )
                else:
                    countdown_var.set("")
            else:
                secs = int(remaining) + 1
                ok_text.set(f"OK ({secs}s)")
                countdown_var.set(
                    f"Please wait — {secs} second{'s' if secs != 1 else ''} remaining."
                )
        elif auto_close > 0:
            remaining_close = max(0.0, auto_close - elapsed)
            if remaining_close <= 0:
                _finish("OK", 0)
                return
            secs = int(remaining_close) + 1
            countdown_var.set(
                f"Auto-closing in {secs} second{'s' if secs != 1 else ''}…"
            )

        # Periodically force the window back to front
        try:
            root.attributes("-topmost", True)
            root.lift()
            root.focus_force()
        except tk.TclError:
            return

        root.after(500, _tick)

    root.after(300, _tick)

    # ── pyobjc boost after initial render (level + frame again post-layout) ───
    if _HAS_PYOBJC:
        def _post_render_boost() -> None:
            _nswindow_fill_screen(title, screen_w, screen_h)
            _boost_window_level(title)

        root.after(250, _post_render_boost)

    root.mainloop()
    return exit_code[0]


# ── entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    try:
        payload: dict[str, Any] = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"popup-blocker-darwin: invalid JSON input: {exc}", file=sys.stderr)
        raise SystemExit(1)

    code = run_blocker(payload)
    raise SystemExit(code)


if __name__ == "__main__":
    main()
