#!/usr/bin/env python3
"""
Non-GUI tests for macOS configure tkinter modal dialog patterns.

Catches regressions like Toplevel.mainloop() (blank daemon windows on macOS).
Runs without opening visible dialogs when tkinter is unavailable (static checks only).
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
sys.path.insert(0, str(LIB))

import configure_dialogs_darwin_window as cd_window  # noqa: E402

UI_MODULES = (
    LIB / "configure_dialogs_darwin_table_ui.py",
    LIB / "configure_dialogs_darwin_time_ui.py",
    LIB / "configure_dialogs_darwin_text_ui.py",
)
DAEMON = LIB / "configure-dialogs-darwin-daemon.py"


def _tkinter_usable() -> bool:
    try:
        import tkinter as tk

        root = tk.Tk()
        root.withdraw()
        root.destroy()
        return True
    except Exception:
        return False


class StaticModalPatternTests(unittest.TestCase):
    """Source-level guards for modal dialog wiring."""

    def test_ui_modules_use_run_modal_not_mainloop(self) -> None:
        for path in UI_MODULES:
            text = path.read_text(encoding="utf-8")
            with self.subTest(module=path.name):
                self.assertIn("_cd_window.run_modal(window)", text)
                self.assertNotIn("window.mainloop()", text)

    def test_ui_modules_use_close_modal_not_quit(self) -> None:
        for path in UI_MODULES:
            text = path.read_text(encoding="utf-8")
            with self.subTest(module=path.name):
                self.assertIn("_cd_window.close_modal(window)", text)
                self.assertNotIn("window.quit()", text)

    def test_daemon_does_not_grab_before_content(self) -> None:
        text = DAEMON.read_text(encoding="utf-8")
        run_dialog = text.split("def _run_dialog", 1)[1].split("def main", 1)[0]
        self.assertNotIn("grab_set()", run_dialog)

    def test_daemon_does_not_transient_withdrawn_root(self) -> None:
        text = DAEMON.read_text(encoding="utf-8")
        run_dialog = text.split("def _run_dialog", 1)[1].split("def main", 1)[0]
        self.assertNotIn("dialog.transient(", run_dialog)

    def test_table_dialog_has_oneshot_fallback(self) -> None:
        text = (LIB / "configure-dialogs-darwin.sh").read_text(encoding="utf-8")
        self.assertIn("_cd_darwin_run_table_oneshot", text)
        self.assertIn('_cd_darwin_run_table_oneshot "${json_payload}"', text)

    def test_window_module_documents_toplevel_wait_window(self) -> None:
        text = (LIB / "configure_dialogs_darwin_window.py").read_text(encoding="utf-8")
        self.assertIn("root.wait_window(window)", text)
        self.assertIn("deiconify()", text)


@unittest.skipUnless(_tkinter_usable(), "tkinter display not available")
class RuntimeModalBehaviorTests(unittest.TestCase):
    """Verify run_modal/close_modal dispatch without blocking on a real dialog."""

    def test_run_modal_toplevel_uses_root_wait_window(self) -> None:
        import tkinter as tk

        root = tk.Tk()
        root.withdraw()
        top = tk.Toplevel(root)
        top.withdraw()

        calls: list[str] = []

        def fake_wait_window(window: tk.Misc) -> None:
            calls.append(f"wait:{window}")
            top.destroy()

        root.wait_window = fake_wait_window  # type: ignore[method-assign]

        cd_window.run_modal(top)
        self.assertEqual(calls, [f"wait:{top}"])
        root.destroy()

    def test_run_modal_tk_uses_mainloop(self) -> None:
        import tkinter as tk

        root = tk.Tk()
        root.withdraw()

        calls: list[str] = []

        def fake_mainloop() -> None:
            calls.append("mainloop")

        root.mainloop = fake_mainloop  # type: ignore[method-assign]

        cd_window.run_modal(root)
        self.assertEqual(calls, ["mainloop"])
        root.destroy()

    def test_close_modal_toplevel_destroys(self) -> None:
        import tkinter as tk

        root = tk.Tk()
        root.withdraw()
        top = tk.Toplevel(root)
        top.withdraw()

        cd_window.close_modal(top)
        self.assertFalse(top.winfo_exists())
        root.destroy()

    def test_close_modal_tk_quits(self) -> None:
        import tkinter as tk

        root = tk.Tk()
        root.withdraw()
        with mock.patch.object(root, "quit") as quit_mock:
            cd_window.close_modal(root)
            quit_mock.assert_called_once()
        root.destroy()


if __name__ == "__main__":
    unittest.main(verbosity=2)
