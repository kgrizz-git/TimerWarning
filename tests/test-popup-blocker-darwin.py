#!/usr/bin/env python3
"""Unit tests for lib/popup-blocker-darwin.py.

All GUI, pyobjc, and subprocess/BSD surface is mocked: nothing here opens a
real window, calls osascript, or touches a real NSWindow.  The module under
test is imported directly from the repository lib/ directory so statement
coverage counts (do NOT copy it elsewhere before importing).

Run:
    python3 tests/test-popup-blocker-darwin.py          # plain
    python3 -m coverage run --source=lib tests/test-popup-blocker-darwin.py
    python3 -m coverage report --include='*popup-blocker-darwin*'
"""

from __future__ import annotations

import io
import json
import sys
import tempfile
import types
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = REPO_ROOT / "lib"

# Import the real module from the repository lib/ (hyphenated filename →
# importlib).  No copy, no temp dir: coverage must see these exact lines.
import importlib.util

_spec = importlib.util.spec_from_file_location(
    "popup_blocker_darwin", LIB_DIR / "popup-blocker-darwin.py"
)
mod = importlib.util.module_from_spec(_spec)
sys.modules["popup_blocker_darwin"] = mod
_spec.loader.exec_module(mod)

FAKE_TITLE = "ALERT: Restricted time window"


# ── fakes ─────────────────────────────────────────────────────────────────────

def build_fake_tk():
    """Build a fake `tkinter` module with record-keeping widget classes."""
    tk_mod = types.ModuleType("tkinter")

    class TclError(Exception):
        pass

    widgets: list = []       # every Canvas/Frame/Label/Button created
    roots: list = []         # every Tk() created
    buttons: list = []       # buttons only, appended live as they are built

    class FakeWidget:
        def __init__(self, master=None, *args, **kwargs):
            self.master = master
            self.kwargs = dict(kwargs)
            widgets.append(self)

        def pack(self, **kw):
            self.pack_kw = kw

        def place(self, **kw):
            self.place_kw = kw

        def config(self, **kw):
            self.kwargs.update(kw)

    class FakeButton(FakeWidget):
        def __init__(self, master=None, *args, **kwargs):
            super().__init__(master, *args, **kwargs)
            buttons.append(self)

    class FakeStringVar:
        instances: list = []

        def __init__(self, master=None, value=""):
            self._value = value
            FakeStringVar.instances.append(self)

        def set(self, value):
            self._value = value

        def get(self):
            return self._value

    class FakeRoot:
        # TclError trigger flags live on the class so tests can preset them
        # before run_blocker creates the instance.
        raise_tcl_on_attributes = False
        raise_tcl_on_grab_set = False
        raise_tcl_on_grab_release = False
        raise_tcl_on_quit = False

        def __init__(self):
            roots.append(self)
            self.after_calls = []      # (delay_ms, callback)
            self.mainloop_count = 0
            self.grab_set_called = False
            self.grab_release_called = False
            self.destroyed = False
            self.quitted = False
            self.title_text = None
            self.iconphoto_calls = []
            self.bindings = []

        def title(self, text):
            self.title_text = text

        def configure(self, **kw):
            self.config_kw = kw

        def iconphoto(self, *args):
            self.iconphoto_calls.append(args)

        def focus_force(self):
            self.focus_force_count = getattr(self, "focus_force_count", 0) + 1

        def grab_set(self):
            if self.raise_tcl_on_grab_set:
                raise TclError("headless")
            self.grab_set_called = True

        def grab_release(self):
            if self.raise_tcl_on_grab_release:
                raise TclError("already gone")
            self.grab_release_called = True

        def protocol(self, name, handler):
            self.protocols = getattr(self, "protocols", {})
            self.protocols[name] = handler

        def bind(self, sequence, handler):
            self.bindings.append((sequence, handler))

        def after(self, delay, callback):
            self.after_calls.append((delay, callback))

        def mainloop(self):
            self.mainloop_count += 1

        def quit(self):
            if self.raise_tcl_on_quit:
                raise TclError("window already gone")
            self.quitted = True

        def destroy(self):
            self.destroyed = True

        def attributes(self, key, value=None):
            if self.raise_tcl_on_attributes:
                raise TclError(key)

        def overrideredirect(self, value):
            self.overridden = value

        def geometry(self, geom):
            self.geom = geom

        def update_idletasks(self):
            pass

        def winfo_screenwidth(self):
            return 1440

        def winfo_screenheight(self):
            return 900

        def winfo_width(self):
            return 1440

        def winfo_height(self):
            return 900

        def lift(self):
            pass

    tk_mod.TclError = TclError
    tk_mod.Tk = FakeRoot
    tk_mod.Canvas = FakeWidget
    tk_mod.Frame = FakeWidget
    tk_mod.Label = FakeWidget
    tk_mod.Button = FakeButton
    tk_mod.StringVar = FakeStringVar
    tk_mod.PhotoImage = mock.MagicMock(name="PhotoImage")
    # constants referenced by the module (only compared/passed through)
    tk_mod.FLAT = "flat"
    tk_mod.LEFT = "left"
    tk_mod.X = "x"
    tk_mod.NORMAL = "normal"
    tk_mod.DISABLED = "disabled"
    tk_mod._widgets = widgets
    tk_mod._buttons = buttons  # live reference, not a build-time snapshot
    tk_mod._roots = roots
    return tk_mod


class TempHomeTest(unittest.TestCase):
    """Base: give the module a safe __file__ and restore globals afterwards."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)
        # Preserve module globals any test may mutate.
        self._saved = dict(
            _HAS_PYOBJC=mod._HAS_PYOBJC,
            _AppKit=getattr(mod, "AppKit", None),
            __file__=mod.__file__,
            _time=mod.time,
        )
        self.addCleanup(self._restore)

    def _restore(self):
        mod._HAS_PYOBJC = self._saved["_HAS_PYOBJC"]
        if self._saved["_AppKit"] is not None:
            mod.AppKit = self._saved["_AppKit"]
        else:
            if hasattr(mod, "AppKit"):
                del mod.AppKit
        mod.__file__ = self._saved["__file__"]
        mod.time = self._saved["_time"]

    def repoint_module_file(self, target: Path) -> None:
        """Point mod.__file__ at a fake path under tmp for icon-path tests."""
        mod.__file__ = str(target / "popup-blocker-darwin.py")


# ── _write_result ────────────────────────────────────────────────────────────

class TestWriteResult(TempHomeTest):
    def test_writes_label_and_newline(self):
        result_file = self.tmp / "result.txt"
        mod._write_result(str(result_file), "OK")
        self.assertEqual(result_file.read_text(encoding="utf-8"), "OK\n")

    def test_pause_label_written(self):
        result_file = self.tmp / "result2.txt"
        mod._write_result(str(result_file), "Pause 7 min")
        self.assertEqual(result_file.read_text(encoding="utf-8"), "Pause 7 min\n")

    def test_empty_path_is_noop(self):
        # Must return without touching the filesystem.
        mod._write_result("", "OK")  # no exception expected

    def test_bad_path_is_swallowed(self):
        # Nonexistent parent directory → OSError → silently ignored.
        bad = self.tmp / "no-such-dir" / "result.txt"
        mod._write_result(str(bad), "OK")  # no exception expected
        self.assertFalse(bad.exists())

    def test_path_is_a_directory_is_swallowed(self):
        # Writing to a directory path raises OSError (IsADirectoryError), which
        # is an OSError subclass: swallowed.
        target_dir = self.tmp / "adir"
        target_dir.mkdir()
        mod._write_result(str(target_dir), "OK")


# ── _screen_pixels ───────────────────────────────────────────────────────────

class TestScreenPixels(TempHomeTest):
    def test_pyobjc_nsscreen_preferred(self):
        fake_appkit = mock.MagicMock(name="AppKit")
        screen = mock.MagicMock()
        screen.frame.return_value.size.width = 1512
        screen.frame.return_value.size.height = 982
        fake_appkit.NSScreen.mainScreen.return_value = screen
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        root = mock.MagicMock()
        self.assertEqual(mod._screen_pixels(root), (1512, 982))
        # tk metrics must not have been consulted.
        root.winfo_screenwidth.assert_not_called()

    def test_pyobjc_screen_too_small_falls_back_to_winfo(self):
        fake_appkit = mock.MagicMock(name="AppKit")
        screen = mock.MagicMock()
        screen.frame.return_value.size.width = 199
        screen.frame.return_value.size.height = 150
        fake_appkit.NSScreen.mainScreen.return_value = screen
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        root = mock.MagicMock()
        root.winfo_screenwidth.return_value = 2560
        root.winfo_screenheight.return_value = 1440
        self.assertEqual(mod._screen_pixels(root), (2560, 1440))

    def test_pyobjc_main_screen_none_falls_back_to_winfo(self):
        fake_appkit = mock.MagicMock(name="AppKit")
        fake_appkit.NSScreen.mainScreen.return_value = None
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        root = mock.MagicMock()
        root.winfo_screenwidth.return_value = 1920
        root.winfo_screenheight.return_value = 1080
        self.assertEqual(mod._screen_pixels(root), (1920, 1080))

    def test_no_pyobjc_uses_winfo(self):
        mod._HAS_PYOBJC = False
        root = mock.MagicMock()
        root.winfo_screenwidth.return_value = 1440
        root.winfo_screenheight.return_value = 900
        self.assertEqual(mod._screen_pixels(root), (1440, 900))

    def test_winfo_unusable_falls_back_to_default(self):
        mod._HAS_PYOBJC = False
        root = mock.MagicMock()
        root.winfo_screenwidth.return_value = 100
        root.winfo_screenheight.return_value = 50
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(mod._screen_pixels(root), (1728, 1117))
        self.assertIn("unusable", err.getvalue())

    def test_pyobjc_exception_falls_back_to_winfo(self):
        fake_appkit = mock.MagicMock(name="AppKit")
        fake_appkit.NSScreen.mainScreen.side_effect = RuntimeError("boom")
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        root = mock.MagicMock()
        root.winfo_screenwidth.return_value = 800
        root.winfo_screenheight.return_value = 600
        self.assertEqual(mod._screen_pixels(root), (800, 600))


# ── _nswindow_fill_screen / _boost_window_level ──────────────────────────────

def make_fake_appkit_with_windows(titles):
    fake = mock.MagicMock(name="AppKit")
    wins = []
    for t in titles:
        w = mock.MagicMock()
        w.title.return_value = t
        wins.append(w)
    fake.NSApplication.sharedApplication.return_value.windows.return_value = wins
    fake.NSScreenSaverWindowLevel = 1237
    fake.NSWindowCollectionBehaviorCanJoinAllSpaces = 1
    fake.NSWindowCollectionBehaviorFullScreenAuxiliary = 2
    fake.NSWindowCollectionBehaviorStationary = 4
    fake.NSWindowCollectionBehaviorIgnoresCycle = 8
    return fake, wins


class TestNswindowFillScreen(TempHomeTest):
    def test_no_pyobjc_is_noop(self):
        mod._HAS_PYOBJC = False
        self.assertIsNone(mod._nswindow_fill_screen(FAKE_TITLE, 100, 100))

    def test_matching_window_is_resized_and_raised(self):
        fake_appkit, wins = make_fake_appkit_with_windows(["other", FAKE_TITLE])
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        mod._nswindow_fill_screen(FAKE_TITLE, 1440, 900)
        fake_appkit.NSMakeRect.assert_called_once_with(0, 0, 1440, 900)
        target = wins[1]
        target.setFrame_display_.assert_called_once_with(
            fake_appkit.NSMakeRect.return_value, True
        )
        target.setLevel_.assert_called_once_with(fake_appkit.NSScreenSaverWindowLevel)
        target.makeKeyAndOrderFront_.assert_called_once_with(None)
        # First (non-matching) window untouched.
        wins[0].setFrame_display_.assert_not_called()

    def test_no_matching_window_is_harmless(self):
        fake_appkit, _ = make_fake_appkit_with_windows(["something-else"])
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        mod._nswindow_fill_screen(FAKE_TITLE, 1440, 900)  # no exception
        for w in fake_appkit.NSApplication.sharedApplication.return_value.windows.return_value:
            w.setFrame_display_.assert_not_called()

    def test_pyobjc_exception_is_swallowed(self):
        fake_appkit, _ = make_fake_appkit_with_windows([])
        fake_appkit.NSApplication.sharedApplication.return_value.windows.side_effect = (
            RuntimeError("boom")
        )
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        mod._nswindow_fill_screen(FAKE_TITLE, 1440, 900)  # no exception


class TestBoostWindowLevel(TempHomeTest):
    def test_no_pyobjc_is_noop(self):
        mod._HAS_PYOBJC = False
        self.assertIsNone(mod._boost_window_level(FAKE_TITLE))

    def test_matching_window_boosted_with_collection_flags(self):
        fake_appkit, wins = make_fake_appkit_with_windows(["a", FAKE_TITLE, "b"])
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        mod._boost_window_level(FAKE_TITLE)
        target = wins[1]
        target.setLevel_.assert_called_once_with(fake_appkit.NSScreenSaverWindowLevel)
        target.setCollectionBehavior_.assert_called_once_with(
            1 | 2 | 4 | 8
        )
        target.makeKeyAndOrderFront_.assert_called_once_with(None)
        for other in (wins[0], wins[2]):
            other.setLevel_.assert_not_called()

    def test_no_matching_window_is_harmless(self):
        fake_appkit, wins = make_fake_appkit_with_windows(["zzz"])
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        mod._boost_window_level(FAKE_TITLE)  # no exception
        wins[0].setLevel_.assert_not_called()

    def test_pyobjc_exception_is_swallowed(self):
        fake_appkit, _ = make_fake_appkit_with_windows([])
        fake_appkit.NSApplication.sharedApplication.return_value.windows.side_effect = (
            RuntimeError("boom")
        )
        mod.AppKit = fake_appkit
        mod._HAS_PYOBJC = True
        mod._boost_window_level(FAKE_TITLE)  # no exception


# ── _apply_fullscreen ────────────────────────────────────────────────────────

class TestApplyFullscreen(TempHomeTest):
    def setUp(self):
        super().setUp()
        mod._HAS_PYOBJC = False

    def test_native_fullscreen_when_big_enough(self):
        root = mock.MagicMock()
        root.winfo_width.return_value = 1440
        root.winfo_height.return_value = 900
        with mock.patch.object(mod, "_nswindow_fill_screen") as fill:
            mode = mod._apply_fullscreen(root, FAKE_TITLE, 1440, 900)
        self.assertEqual(mode, "native-fullscreen")
        root.geometry.assert_called_once_with("1440x900+0+0")
        root.attributes.assert_any_call("-fullscreen", True)
        root.attributes.assert_any_call("-topmost", True)
        root.update_idletasks.assert_called_once()
        fill.assert_not_called()

    def test_falls_back_to_geometry_fullscreen(self):
        root = mock.MagicMock()
        # Reported size far smaller than the screen → fallback path.
        root.winfo_width.return_value = 300
        root.winfo_height.return_value = 200
        with mock.patch.object(mod, "_nswindow_fill_screen") as fill:
            mode = mod._apply_fullscreen(root, FAKE_TITLE, 1440, 900)
        self.assertEqual(mode, "geometry-fullscreen")
        # corner steps: revert native fullscreen, go borderless, re-geometry,
        # retake screen size, then Cocoa-frame the window.
        root.attributes.assert_any_call("-fullscreen", False)
        root.overrideredirect.assert_called_once_with(True)
        self.assertEqual(root.geometry.call_count, 2)
        self.assertEqual(root.geometry.call_args_list[-1][0][0], "1440x900+0+0")
        self.assertEqual(root.update_idletasks.call_count, 2)
        fill.assert_called_once_with(FAKE_TITLE, 1440, 900)

    def test_tcl_errors_on_attributes_are_survived(self):
        import tkinter as real_tk

        root = mock.MagicMock()
        root.attributes.side_effect = real_tk.TclError("headless")
        root.overrideredirect.side_effect = real_tk.TclError("headless")
        root.winfo_width.return_value = 300
        root.winfo_height.return_value = 200
        with mock.patch.object(mod, "_nswindow_fill_screen") as fill:
            mode = mod._apply_fullscreen(root, FAKE_TITLE, 1440, 900)
        self.assertEqual(mode, "geometry-fullscreen")
        fill.assert_called_once()


# ── _apply_app_icon ──────────────────────────────────────────────────────────

class TestApplyAppIcon(TempHomeTest):
    def setUp(self):
        super().setUp()
        # Spec-limited mock: unlike a plain MagicMock, unset attributes raise
        # AttributeError, so getattr(root, "_sw_app_icon", None) is truthful.
        self.root = mock.Mock(spec=["iconphoto"])

    def test_no_icon_file_found_is_harmless(self):
        self.repoint_module_file(self.tmp / "missing" / "side")
        with mock.patch("tkinter.PhotoImage") as photo:
            mod._apply_app_icon(self.root)
        photo.assert_not_called()
        self.root.iconphoto.assert_not_called()

    def test_icon_found_uses_photoimage_and_keeps_reference(self):
        here = self.tmp / "here"
        here.mkdir()
        (here / "timerwarning-icon.png").write_bytes(b"png")
        self.repoint_module_file(here)
        sentinel = object()
        # _apply_app_icon resolves the parent via .resolve(), so compare
        # against the resolved candidate path.
        expected_file = str((here / "timerwarning-icon.png").resolve())
        with mock.patch("tkinter.PhotoImage", return_value=sentinel) as photo:
            mod._apply_app_icon(self.root)
        photo.assert_called_once_with(master=self.root, file=expected_file)
        self.root.iconphoto.assert_called_once_with(True, sentinel)
        self.assertIs(self.root._sw_app_icon, sentinel)

    def test_photoimage_tcl_error_is_survived(self):
        import tkinter as real_tk

        here = self.tmp / "here2"
        here.mkdir()
        (here / "timerwarning-icon.png").write_bytes(b"png")
        self.repoint_module_file(here)
        with mock.patch(
            "tkinter.PhotoImage", side_effect=real_tk.TclError("bad image")
        ) as photo:
            mod._apply_app_icon(self.root)
        photo.assert_called_once()
        self.root.iconphoto.assert_not_called()


# ── run_blocker ──────────────────────────────────────────────────────────────

class RunBlockerTest(TempHomeTest):
    """run_blocker with the whole tkinter surface faked; no window ever opens."""

    def setUp(self):
        super().setUp()
        self.fake_tk = build_fake_tk()
        self.tk_patcher = mock.patch.dict(sys.modules, {"tkinter": self.fake_tk})
        self.tk_patcher.start()
        self.addCleanup(self.tk_patcher.stop)
        mod._HAS_PYOBJC = False  # pyobjc boost lines are exercised separately

        self.result_file = self.tmp / "blocker-result.txt"
        self.payload = {
            "title": FAKE_TITLE,
            "message": "You are in a restricted period.",
            "min_display_seconds": 0,
            "auto_close_seconds": 0,
            "pause_available": False,
            "pause_duration_minutes": 0,
            "result_file": str(self.result_file),
        }

    # -- helpers ------------------------------------------------------------
    def _run(self, payload=None):
        code = mod.run_blocker(payload if payload is not None else dict(self.payload))
        return code, self.fake_tk._roots[-1]

    def _ok_button(self):
        return [b for b in self.fake_tk._buttons if "textvariable" in b.kwargs][-1]

    def _pause_button(self):
        return [b for b in self.fake_tk._buttons if "text" in b.kwargs][-1]

    def _tick(self, root):
        for delay, fn in root.after_calls:
            if delay == 300 and fn.__name__ == "_tick":
                return fn
        self.fail("tick callback was not scheduled")

    # -- tests ---------------------------------------------------------------
    def test_success_path_ok_button_writes_result(self):
        code, root = self._run()
        self.assertEqual(code, 0)
        # Window lifecycle happened on the fake, never for real.
        self.assertEqual(root.mainloop_count, 1)
        self.assertFalse(root.destroyed or root.quitted)
        self.assertEqual(root.title_text, FAKE_TITLE)
        self.assertTrue(root.grab_set_called)
        self.assertIn("WM_DELETE_WINDOW", root.protocols)
        self.assertIsNone(root.protocols["WM_DELETE_WINDOW"]())
        # OK button starts enabled and dismisses via its command → result write.
        ok = self._ok_button()
        self.assertEqual(ok.kwargs["state"], self.fake_tk.NORMAL)
        ok.kwargs["command"]()
        self.assertTrue(root.grab_release_called)
        self.assertTrue(root.quitted)
        self.assertTrue(root.destroyed)
        self.assertEqual(self.result_file.read_text(encoding="utf-8"), "OK\n")

    def test_keyboard_shortcuts_dismiss_when_ok_enabled(self):
        code, root = self._run()
        self.assertEqual(code, 0)
        sequences = [seq for seq, _ in root.bindings]
        self.assertIn("<Return>", sequences)
        self.assertIn("<Escape>", sequences)
        for _, handler in root.bindings:
            handler(None)  # guard: only OK fires once; later calls are no-ops
        self.assertEqual(self.result_file.read_text(encoding="utf-8"), "OK\n")

    def test_pause_button_writes_pause_result(self):
        self.payload["pause_available"] = True
        self.payload["pause_duration_minutes"] = 5
        code, root = self._run()
        self.assertEqual(code, 0)  # pre-dismiss default; pause not yet clicked
        pause = self._pause_button()
        self.assertEqual(pause.kwargs["text"], "Pause 5 min")
        pause.kwargs["command"]()
        self.assertEqual(self.result_file.read_text(encoding="utf-8"), "Pause 5 min\n")

    def test_early_validation_failure_never_opens_window(self):
        self.payload["min_display_seconds"] = "not-a-number"
        with self.assertRaises(ValueError):
            mod.run_blocker(self.payload)
        # int() blows up before Tk() — no window was ever requested.
        self.assertEqual(len(self.fake_tk._roots), 0)

    def test_lock_countdown_during_min_display(self):
        self.payload["min_display_seconds"] = 30
        code, root = self._run()
        tick = self._tick(root)
        mod_ok_before = [b for b in self.fake_tk._buttons if "textvariable" in b.kwargs][-1]
        self.assertEqual(mod_ok_before.kwargs["state"], self.fake_tk.DISABLED)
        tick()
        ok_text = self._ok_button().kwargs["textvariable"]
        self.assertRegex(ok_text.get(), r"^OK \(\d+s\)$")
        countdown_var = self.fake_tk.StringVar.instances[0]  # created before ok_text
        self.assertIn("Please wait", countdown_var.get())

    def test_ok_unlocks_after_min_display_elapses(self):
        # Advancing clock: run_blocker captures start_mono=t0, the tick call
        # sees t0+100 → elapsed 100 > min_display 10 → OK unlocks.
        class FakeClock:
            def __init__(self, start):
                self.now = start

            def monotonic(self):
                current = self.now
                self.now += 100.0
                return current

        self.payload["min_display_seconds"] = 10
        self.payload["auto_close_seconds"] = 90
        with mock.patch.object(mod, "time", FakeClock(0.0)):
            code, root = self._run()
            tick = self._tick(root)
            tick()
        ok = self._ok_button()
        self.assertEqual(ok.kwargs["state"], self.fake_tk.NORMAL)
        ok_text = ok.kwargs["textvariable"]
        self.assertEqual(ok_text.get(), "OK")
        countdown_var = self.fake_tk.StringVar.instances[0]  # created before ok_text
        self.assertIn("Auto-closing in", countdown_var.get())

    def test_tick_reschedules_itself_and_keeps_window_on_top(self):
        code, root = self._run()
        tick = self._tick(root)
        before = len(root.after_calls)
        tick()
        self.assertEqual(len(root.after_calls), before + 1)
        self.assertEqual(root.after_calls[-1][0], 500)

    def test_tick_survives_tcl_error_from_topmost(self):
        code, root = self._run()
        tick = self._tick(root)
        before = len(root.after_calls)
        root.raise_tcl_on_attributes = True
        tick()  # TclError path → early return, NO re-schedule
        self.assertEqual(len(root.after_calls), before)
        root.raise_tcl_on_attributes = False

    def test_auto_close_tick_finishes_and_writes_result(self):
        # Advancing clock: tick sees elapsed 100 ≥ auto_close 5 → _finish("OK").
        class FakeClock:
            def __init__(self, start):
                self.now = start

            def monotonic(self):
                current = self.now
                self.now += 100.0
                return current

        self.payload["auto_close_seconds"] = 5
        with mock.patch.object(mod, "time", FakeClock(0.0)):
            code, root = self._run()
            tick = self._tick(root)
            tick()
        self.assertEqual(root.quitted and root.destroyed, True)
        self.assertEqual(self.result_file.read_text(encoding="utf-8"), "OK\n")

    def test_finish_is_idempotent(self):
        code, root = self._run()
        ok = self._ok_button()
        ok.kwargs["command"]()
        before_destroy = root.destroyed
        # Invoking again is guarded by the dismissed Event: no rewrite, no crash.
        ok.kwargs["command"]()
        self.assertEqual(root.destroyed, before_destroy)
        old = self.result_file.read_text(encoding="utf-8")
        ok.kwargs["command"]()
        self.assertEqual(self.result_file.read_text(encoding="utf-8"), old)

    def test_tick_returns_early_once_dismissed(self):
        code, root = self._run()
        tick = self._tick(root)
        self._ok_button().kwargs["command"]()  # dismiss
        before = len(root.after_calls)
        tick()  # dismissed guard → early return, no re-schedule
        self.assertEqual(len(root.after_calls), before)

    def test_grab_set_tcl_error_is_survived(self):
        self.fake_tk.Tk.raise_tcl_on_grab_set = True  # preset: root not built yet
        code, root = self._run()
        self.assertEqual(code, 0)
        self.assertFalse(root.grab_set_called)  # raise happened, was swallowed

    def test_finish_tcl_errors_are_survived(self):
        code, root = self._run()
        root.raise_tcl_on_grab_release = True
        root.raise_tcl_on_quit = True
        self._ok_button().kwargs["command"]()  # must not raise
        self.assertEqual(self.result_file.read_text(encoding="utf-8"), "OK\n")

    def test_unlock_without_auto_close_clears_countdown(self):
        class FakeClock:
            def __init__(self, start):
                self.now = start

            def monotonic(self):
                current = self.now
                self.now += 100.0
                return current

        self.payload["min_display_seconds"] = 10
        self.payload["auto_close_seconds"] = 0
        with mock.patch.object(mod, "time", FakeClock(0.0)):
            code, root = self._run()
            tick = self._tick(root)
            tick()  # unlock branch with no auto-close → countdown cleared
        countdown_var = self.fake_tk.StringVar.instances[0]
        self.assertEqual(countdown_var.get(), "")

    def test_auto_close_countdown_while_ok_enabled(self):
        # Clock advances 1 s per monotonic() call: tick sees elapsed 1 s of a
        # 5 s auto-close window → "Auto-closing in 5 second…" and re-schedule.
        class FakeClock:
            def __init__(self):
                self.now = 0.0

            def monotonic(self):
                self.now += 1.0
                return self.now

        self.payload["auto_close_seconds"] = 5
        with mock.patch.object(mod, "time", FakeClock()):
            code, root = self._run()
            tick = self._tick(root)
            before = len(root.after_calls)
            tick()
        countdown_var = self.fake_tk.StringVar.instances[0]
        self.assertIn("Auto-closing in 5 second", countdown_var.get())
        self.assertEqual(len(root.after_calls), before + 1)

    def test_post_render_boost_is_scheduled_when_pyobjc(self):
        # Real pyobjc is installed on dev machines, so AppKit must be faked too:
        # mainScreen → None forces _screen_pixels onto the fake root's winfo
        # metrics (1440x900) → native-fullscreen, no fallback fill call.
        fake_appkit = mock.MagicMock(name="AppKit")
        fake_appkit.NSScreen.mainScreen.return_value = None
        fake_appkit.NSMakeRect = mock.MagicMock(name="NSMakeRect")
        fake_appkit.NSScreenSaverWindowLevel = 1237
        self.payload["auto_close_seconds"] = 0
        with mock.patch.object(mod, "_HAS_PYOBJC", True), mock.patch.object(
            mod, "AppKit", fake_appkit
        ), mock.patch.object(mod, "_nswindow_fill_screen") as fill, mock.patch.object(
            mod, "_boost_window_level"
        ) as boost:
            code, root = self._run()
            boosts = [(d, fn) for d, fn in root.after_calls if d == 250]
            self.assertEqual(len(boosts), 1)
            boosts[0][1]()  # post-render boost fires after layout
        fill.assert_called_once_with(FAKE_TITLE, 1440, 900)
        boost.assert_called_once_with(FAKE_TITLE)


# ── main ─────────────────────────────────────────────────────────────────────

class TestMain(TempHomeTest):
    def test_invalid_json_exits_1_without_running_blocker(self):
        err = io.StringIO()
        with mock.patch.object(sys, "stdin", io.StringIO("{not json")), mock.patch.object(
            mod, "run_blocker"
        ) as rb, redirect_stderr(err):
            with self.assertRaises(SystemExit) as ctx:
                mod.main()
        self.assertEqual(ctx.exception.code, 1)
        rb.assert_not_called()
        self.assertIn("invalid JSON input", err.getvalue())

    def test_empty_stdin_counts_as_invalid_json(self):
        with mock.patch.object(sys, "stdin", io.StringIO("")), mock.patch.object(
            mod, "run_blocker"
        ) as rb:
            with self.assertRaises(SystemExit) as ctx:
                mod.main()
        self.assertEqual(ctx.exception.code, 1)
        rb.assert_not_called()

    def test_valid_payload_runs_blocker_and_propagates_code(self):
        payload = {"title": "t", "result_file": "/tmp/x"}
        with mock.patch.object(sys, "stdin", io.StringIO(json.dumps(payload))), \
                mock.patch.object(mod, "run_blocker", return_value=2) as rb:
            with self.assertRaises(SystemExit) as ctx:
                mod.main()
        self.assertEqual(ctx.exception.code, 2)
        rb.assert_called_once()
        self.assertEqual(rb.call_args[0][0], payload)


if __name__ == "__main__":
    unittest.main(verbosity=2)
