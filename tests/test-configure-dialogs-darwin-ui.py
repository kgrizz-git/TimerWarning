#!/usr/bin/env python3
"""Unit tests for the macOS configure-wizard tkinter dialogs in lib/.

Covers configure_dialogs_darwin_{window,time_ui,text_ui,list_ui,table_ui}.py,
the one-shot CLIs configure-dialogs-darwin-{time,text,table}.py, and the
dialog daemon configure-dialogs-darwin-daemon.py.

Nothing here opens a window. Widgets are recorded fakes, and run_modal is a
hook that clicks a button or presses a key instead of blocking. The modules
are imported from lib/ so coverage counts their lines. Importing tkinter does
not need a display, so these tests run the same with or without one.

Run:
    python3 tests/test-configure-dialogs-darwin-ui.py
"""

from __future__ import annotations

import importlib
import importlib.util
import io
import json
import sys
import tkinter as tk
import types
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = REPO_ROOT / "lib"
sys.path.insert(0, str(LIB_DIR))

import configure_dialogs_darwin_list_ui as list_ui  # noqa: E402
import configure_dialogs_darwin_table_ui as table_ui  # noqa: E402
import configure_dialogs_darwin_text_ui as text_ui  # noqa: E402
import configure_dialogs_darwin_time_ui as time_ui  # noqa: E402
import configure_dialogs_darwin_window as cd_window  # noqa: E402


def load_script(filename: str, name: str) -> types.ModuleType:
    """Import a hyphenated lib/ script without running its __main__ block."""
    spec = importlib.util.spec_from_file_location(name, LIB_DIR / filename)
    assert spec is not None and spec.loader is not None, filename
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class FakeWidget:
    """A widget that records its constructor arguments and tiny bits of state."""

    def __init__(self, kind: str, *args, **kwargs):
        self.kind = kind
        self.args = args
        self.kwargs = kwargs
        self.command = kwargs.get("command")
        self.text = kwargs.get("text")
        self.value = None
        self.selected: tuple = ()
        self.inserted: list = []
        self.headings: dict = {}
        self.columns: dict = {}
        self.handlers: dict = {}

    def bind(self, sequence, func, add=None):
        self.handlers[sequence] = func

    def get(self, *_args):
        return self.value

    def set(self, value):
        self.value = value

    def insert(self, *args, **kwargs):
        self.inserted.append((args, kwargs))

    def heading(self, col, **kwargs):
        self.headings[col] = kwargs

    def column(self, col, **kwargs):
        self.columns[col] = kwargs

    def selection(self):
        return self.selected

    def selection_set(self, item):
        self.selected = (item,)

    def curselection(self):
        return self.selected

    def __getattr__(self, name):
        # pack, grid, configure, bind, focus and the rest are no-ops.
        if name.startswith("__"):
            raise AttributeError(name)
        return mock.MagicMock(name=name)


class Harness:
    """Fake ttk plus fake tk widgets that remember what a dialog built."""

    def __init__(self):
        self.widgets: list[FakeWidget] = []
        self.ttk = types.SimpleNamespace(
            **{
                kind: self._factory(kind)
                for kind in (
                    "Frame", "LabelFrame", "Label", "Button", "Combobox", "Scrollbar", "Treeview",
                )
            }
        )

    def _factory(self, kind):
        def make(*args, **kwargs):
            widget = FakeWidget(kind, *args, **kwargs)
            self.widgets.append(widget)
            return widget

        return make

    def make_tk(self, kind):
        return self._factory(kind)

    def of(self, kind):
        return [w for w in self.widgets if w.kind == kind]

    def button(self, label):
        return next(w for w in self.of("Button") if w.text == label)


def make_window():
    window = mock.MagicMock(name="window")
    window.handlers = {}

    def bind(sequence, func, add=None):
        window.handlers[sequence] = func

    window.bind.side_effect = bind
    return window


def run_dialog(module, show, window, payload, harness, action):
    """Run show(window, payload) with run_modal replaced by *action*."""
    fake_cd = mock.MagicMock(name="cd_window")
    fake_cd.run_modal.side_effect = lambda _w: action()
    patches = [
        mock.patch.object(module, "ttk", harness.ttk),
        mock.patch.object(module, "_cd_window", fake_cd),
    ]
    for p in patches:
        p.start()
    try:
        return show(window, payload), fake_cd
    finally:
        for p in patches:
            p.stop()


class WindowHelperTests(unittest.TestCase):
    def test_stable_geometry_centers_the_dialog(self):
        window = mock.MagicMock()
        window.winfo_screenwidth.return_value = 2000
        window.winfo_screenheight.return_value = 1200
        cd_window.set_stable_geometry(window, 500, 300)
        window.geometry.assert_called_once_with("500x300+750+300")

    def test_stable_geometry_never_goes_negative(self):
        window = mock.MagicMock()
        window.winfo_screenwidth.return_value = 100
        window.winfo_screenheight.return_value = 100
        cd_window.set_stable_geometry(window, 500, 300)
        window.geometry.assert_called_once_with("500x300+0+0")

    def test_stable_geometry_falls_back_without_a_screen(self):
        window = mock.MagicMock()
        window.winfo_screenwidth.side_effect = tk.TclError("no display")
        cd_window.set_stable_geometry(window, 500, 300)
        window.geometry.assert_called_once_with("500x300")

    def test_close_modal_destroys_a_plain_toplevel(self):
        window = mock.MagicMock(spec=tk.Toplevel)
        cd_window.close_modal(window)
        window.destroy.assert_called_once_with()

    def test_close_modal_quits_the_root(self):
        window = mock.MagicMock(name="root")
        cd_window.close_modal(window)
        window.quit.assert_called_once_with()

    def test_close_modal_withdraws_a_reusable_toplevel(self):
        window = mock.MagicMock(spec=tk.Toplevel)
        window._sw_reusable_modal = True
        done = mock.MagicMock()
        window._sw_modal_done_var = done
        cd_window.close_modal(window)
        window.withdraw.assert_called_once_with()
        done.set.assert_called_once_with(True)
        window.destroy.assert_not_called()

    def test_close_modal_tolerates_tcl_errors_on_a_reusable_toplevel(self):
        window = mock.MagicMock(spec=tk.Toplevel)
        window._sw_reusable_modal = True
        window.withdraw.side_effect = tk.TclError("gone")
        done_var = mock.MagicMock()
        done_var.set.side_effect = tk.TclError("gone")
        window._sw_modal_done_var = done_var
        cd_window.close_modal(window)

    def test_run_modal_runs_the_mainloop_for_a_root(self):
        window = mock.MagicMock(name="root")
        cd_window.run_modal(window)
        window.update_idletasks.assert_called_once_with()
        window.mainloop.assert_called_once_with()

    def test_run_modal_waits_for_a_plain_toplevel(self):
        window = mock.MagicMock(spec=tk.Toplevel)
        window.master = mock.MagicMock()
        cd_window.run_modal(window)
        window.deiconify.assert_called_once_with()
        window.grab_set.assert_called_once_with()
        window.master.wait_window.assert_called_once_with(window)
        window.grab_release.assert_called_once_with()
        window.withdraw.assert_not_called()

    def test_run_modal_waits_on_a_variable_for_a_reusable_toplevel(self):
        window = mock.MagicMock(spec=tk.Toplevel)
        window.master = mock.MagicMock()
        window._sw_reusable_modal = True
        with mock.patch.object(cd_window.tk, "BooleanVar") as boolean_var:
            cd_window.run_modal(window)
        window.master.wait_variable.assert_called_once_with(boolean_var.return_value)
        window.master.wait_window.assert_not_called()
        window.withdraw.assert_called_once_with()
        self.assertIsNone(window._sw_modal_done_var)

    def test_run_modal_survives_tcl_errors(self):
        window = mock.MagicMock(spec=tk.Toplevel)
        window.master = mock.MagicMock()
        window._sw_reusable_modal = True
        window.deiconify.side_effect = tk.TclError("unmapped")
        window.grab_release.side_effect = tk.TclError("gone")
        window.withdraw.side_effect = tk.TclError("gone")
        with mock.patch.object(cd_window.tk, "BooleanVar"):
            cd_window.run_modal(window)
        window.master.wait_variable.assert_called_once()

    def test_cleanup_skips_a_destroyed_window(self):
        window = mock.MagicMock()
        window.winfo_exists.return_value = False
        cd_window.cleanup_modal_window(window)
        window.winfo_children.assert_not_called()

    def test_cleanup_skips_when_the_interpreter_is_gone(self):
        window = mock.MagicMock()
        window.winfo_exists.side_effect = tk.TclError("gone")
        cd_window.cleanup_modal_window(window)
        window.winfo_children.assert_not_called()

    def test_cleanup_destroys_children_of_a_plain_window(self):
        window = mock.MagicMock()
        window.winfo_exists.return_value = True
        children = [mock.MagicMock(), mock.MagicMock()]
        window.winfo_children.return_value = children
        window._sw_reusable_modal = False
        cd_window.cleanup_modal_window(window)
        for child in children:
            child.destroy.assert_called_once_with()
        window.unbind.assert_not_called()

    def test_cleanup_resets_bindings_on_a_reusable_window(self):
        window = mock.MagicMock()
        window.winfo_exists.return_value = True
        window.winfo_children.return_value = []
        window._sw_reusable_modal = True
        cd_window.cleanup_modal_window(window)
        self.assertEqual(
            [c.args[0] for c in window.unbind.call_args_list],
            ["<Map>", "<Return>", "<Escape>", "<FocusOut>"],
        )
        window.protocol.assert_called_once_with("WM_DELETE_WINDOW", "")

    def test_cleanup_tolerates_tcl_errors_while_unbinding(self):
        window = mock.MagicMock()
        window.winfo_exists.return_value = True
        window.winfo_children.return_value = []
        window._sw_reusable_modal = True
        window.unbind.side_effect = tk.TclError("gone")
        window.protocol.side_effect = tk.TclError("gone")
        cd_window.cleanup_modal_window(window)

    def test_app_icon_is_set_when_a_file_exists(self):
        root = mock.MagicMock()
        with mock.patch.object(Path, "is_file", return_value=True), \
                mock.patch.object(cd_window.tk, "PhotoImage") as photo:
            cd_window.apply_app_icon(root)
        root.iconphoto.assert_called_once_with(True, photo.return_value)
        self.assertIs(root._sw_app_icon, photo.return_value)

    def test_app_icon_keeps_the_default_on_a_tk_error(self):
        root = mock.MagicMock()
        with mock.patch.object(Path, "is_file", return_value=True), \
                mock.patch.object(cd_window.tk, "PhotoImage", side_effect=tk.TclError("bad")):
            cd_window.apply_app_icon(root)
        root.iconphoto.assert_not_called()

    def test_app_icon_does_nothing_without_a_file(self):
        root = mock.MagicMock()
        with mock.patch.object(Path, "is_file", return_value=False), \
                mock.patch.object(cd_window.tk, "PhotoImage") as photo:
            cd_window.apply_app_icon(root)
        photo.assert_not_called()

    def test_frontmost_raises_then_drops_topmost_after_the_grace_period(self):
        root = mock.MagicMock()
        callbacks = {}
        root.bind.side_effect = lambda seq, func, add=None: callbacks.setdefault(seq, func)
        cd_window.apply_initial_frontmost(root)
        root.lift.assert_called_once_with()
        root.focus_force.assert_called_once_with()
        root.attributes.assert_called_with("-topmost", True)
        grace_ms, end_grace = root.after.call_args_list[0].args
        self.assertEqual(grace_ms, cd_window._GRACE_MS)

        root.attributes.reset_mock()
        callbacks["<FocusOut>"]()
        root.attributes.assert_not_called()  # still inside the grace period

        end_grace()
        callbacks["<FocusOut>"]()
        root.attributes.assert_called_once_with("-topmost", False)

        # The 50 ms and idle re-asserts run the raise again.
        root.lift.reset_mock()
        root.after.call_args_list[1].args[1]()
        root.after_idle.call_args.args[0]()
        self.assertEqual(root.lift.call_count, 2)

    def test_frontmost_tolerates_tcl_errors(self):
        root = mock.MagicMock()
        root.lift.side_effect = tk.TclError("gone")
        root.attributes.side_effect = tk.TclError("gone")
        callbacks = {}
        root.bind.side_effect = lambda seq, func, add=None: callbacks.setdefault(seq, func)
        cd_window.apply_initial_frontmost(root)
        root.after.call_args_list[0].args[1]()
        callbacks["<FocusOut>"]()


class TimeDialogTests(unittest.TestCase):
    def test_hour_normalisation(self):
        cases = {1: "1", 12: "12", 0: "12", -3: "12", 13: "1", 24: "12", "7": "7", "x": "11", None: "11"}
        for value, expected in cases.items():
            with self.subTest(value=value):
                self.assertEqual(time_ui._norm_hour(value), expected)

    def test_minute_normalisation(self):
        cases = {
            "00": "00", "15": "15", "45": "45", "7": "00", "8": "15",
            "20": "15", "53": "00", "abc": "00", " 30 ": "30",
        }
        for value, expected in cases.items():
            with self.subTest(value=value):
                self.assertEqual(time_ui._norm_minute(value), expected)

    def test_ampm_normalisation(self):
        self.assertEqual(time_ui._norm_ampm("pm"), "PM")
        self.assertEqual(time_ui._norm_ampm(" PM "), "PM")
        self.assertEqual(time_ui._norm_ampm("am"), "AM")
        self.assertEqual(time_ui._norm_ampm("junk"), "AM")

    def _show(self, payload, action):
        harness = Harness()
        window = make_window()
        result, fake_cd = run_dialog(
            time_ui, time_ui.show_time_dialog, window, payload, harness,
            lambda: action(harness, window),
        )
        return result, harness, window, fake_cd

    def test_ok_returns_the_start_and_end_as_a_range(self):
        payload = {
            "start": {"hour": 9, "minute": "30", "ampm": "PM"},
            "end": {"hour": 6, "minute": "00", "ampm": "AM"},
        }
        result, _h, _w, fake_cd = self._show(payload, lambda h, w: h.button("OK").command())
        self.assertEqual(result, (True, "9:30PM-6:00AM", 0))
        fake_cd.close_modal.assert_called_once()

    def test_defaults_when_the_payload_has_no_times(self):
        result, *_ = self._show({}, lambda h, w: h.button("OK").command())
        self.assertEqual(result, (True, "11:00AM-11:00AM", 0))

    def test_edited_comboboxes_are_read_back(self):
        def action(h, w):
            start, end = h.of("Combobox")[:3], h.of("Combobox")[3:]
            for widget, value in zip(start + end, ("3", "45", "pm", "14", "07", "am")):
                widget.set(value)
            h.button("OK").command()

        result, *_ = self._show({}, action)
        self.assertEqual(result, (True, "3:45PM-2:00AM", 0))

    def test_cancel_button_returns_a_cancel(self):
        result, *_ = self._show({}, lambda h, w: h.button("Cancel").command())
        self.assertEqual(result, (False, None, 1))

    def test_return_accepts_and_escape_cancels(self):
        result, *_ = self._show({}, lambda h, w: w.handlers["<Return>"](None))
        self.assertEqual(result[0:2], (True, "11:00AM-11:00AM"))
        result, *_ = self._show({}, lambda h, w: w.handlers["<Escape>"](None))
        self.assertEqual(result, (False, None, 1))

    def test_closing_the_window_cancels(self):
        def action(h, w):
            protocol = next(c for c in w.protocol.call_args_list if c.args[0] == "WM_DELETE_WINDOW")
            protocol.args[1]()

        result, *_ = self._show({}, action)
        self.assertEqual(result, (False, None, 1))

    def test_day_and_hint_labels_are_shown_only_when_given(self):
        _r, plain, *_ = self._show({}, lambda h, w: h.button("OK").command())
        plain_labels = [w.text for w in plain.of("Label")]
        self.assertNotIn("Day: Monday", plain_labels)
        _r, rich, *_ = self._show(
            {"day_name": " Monday ", "hint_text": "Pick a range", "title": "T", "width": 600, "height": 400},
            lambda h, w: h.button("OK").command(),
        )
        labels = [w.text for w in rich.of("Label")]
        self.assertIn("Day: Monday", labels)
        self.assertIn("Pick a range", labels)


class TextDialogTests(unittest.TestCase):
    def test_save_action_detection(self):
        for label in ("Yes, save", "yes", "Save changes", "SAVE"):
            self.assertTrue(text_ui._is_save_action(label), label)
        for label in ("No", "Back to Main Menu", "Cancel"):
            self.assertFalse(text_ui._is_save_action(label), label)

    def _show(self, payload, action):
        harness = Harness()
        window = make_window()
        text_widget = FakeWidget("Text")
        with mock.patch.object(text_ui.tk, "Text", return_value=text_widget):
            result, fake_cd = run_dialog(
                text_ui, text_ui.show_text_dialog, window, payload, harness,
                lambda: action(harness, window),
            )
        return result, harness, window, text_widget

    def test_the_text_is_inserted_and_made_read_only(self):
        _r, _h, _w, widget = self._show({"text": "hello"}, lambda h, w: h.button("Close").command())
        self.assertEqual(widget.inserted, [(("1.0", "hello"), {})])

    def test_without_buttons_close_is_the_only_button(self):
        result, harness, *_ = self._show({}, lambda h, w: h.button("Close").command())
        self.assertEqual(result, (True, None, 0))
        self.assertEqual([b.text for b in harness.of("Button")], ["Close"])

    def test_without_buttons_escape_and_window_close_dismiss(self):
        result, *_ = self._show({}, lambda h, w: w.handlers["<Escape>"](None))
        self.assertEqual(result, (True, None, 0))

    def test_a_save_button_gives_exit_code_zero(self):
        payload = {"buttons": ["Yes, save", "No"]}
        result, harness, *_ = self._show(payload, lambda h, w: h.button("Yes, save").command())
        self.assertEqual(result, (True, "Yes, save", 0))
        self.assertEqual([b.text for b in harness.of("Button")], ["No", "Yes, save"])

    def test_a_non_save_button_gives_exit_code_one(self):
        payload = {"buttons": ["Yes, save", "No"]}
        result, *_ = self._show(payload, lambda h, w: h.button("No").command())
        self.assertEqual(result, (False, "No", 1))

    def test_return_presses_the_default_button(self):
        payload = {"buttons": ["Yes, save", "No"], "default_button": "No"}
        result, *_ = self._show(payload, lambda h, w: w.handlers["<Return>"](None))
        self.assertEqual(result, (False, "No", 1))
        result, *_ = self._show({"buttons": ["Yes, save", "No"]}, lambda h, w: w.handlers["<Return>"](None))
        self.assertEqual(result, (True, "Yes, save", 0))

    def test_escape_picks_the_last_button(self):
        payload = {"buttons": ["Yes, save", "Back to Main Menu"]}
        result, *_ = self._show(payload, lambda h, w: w.handlers["<Escape>"](None))
        self.assertEqual(result, (False, "Back to Main Menu", 1))

    def test_closing_with_buttons_but_no_choice_is_a_cancel(self):
        result, *_ = self._show({"buttons": ["Yes", "No"]}, lambda h, w: None)
        self.assertEqual(result, (False, None, 1))

    def test_a_non_list_buttons_value_is_ignored(self):
        result, harness, *_ = self._show({"buttons": "oops"}, lambda h, w: h.button("Close").command())
        self.assertEqual(result, (True, None, 0))


class ListDialogTests(unittest.TestCase):
    def _show(self, payload, action, selected=None):
        """Run the dialog; *selected* replaces the preselected row before *action*."""
        harness = Harness()
        window = make_window()
        listbox = FakeWidget("Listbox")
        with mock.patch.object(list_ui.tk, "Listbox", return_value=listbox):
            result, fake_cd = run_dialog(
                list_ui, list_ui.show_list_dialog, window, payload, harness,
                lambda: (setattr(listbox, "selected", selected) if selected is not None else None,
                         action(harness, window, listbox))[1],
            )
        return result, harness, window, listbox

    def test_no_items_is_an_error(self):
        with self.assertRaises(ValueError):
            self._show({"items": []}, lambda h, w, lb: None)
        with self.assertRaises(ValueError):
            self._show({}, lambda h, w, lb: None)

    def test_items_are_inserted_in_order_as_strings(self):
        _r, _h, _w, listbox = self._show(
            {"items": ["a", 2, "c"]}, lambda h, w, lb: h.button("Cancel").command()
        )
        self.assertEqual([args[1] for args, _ in listbox.inserted], ["a", "2", "c"])

    def test_ok_returns_the_selected_item(self):
        result, *_ = self._show(
            {"items": ["a", "b", "c"]}, lambda h, w, lb: h.button("OK").command(), selected=(1,)
        )
        self.assertEqual(result, (True, "b", 0, False))

    def test_ok_with_nothing_selected_keeps_the_dialog_open(self):
        calls = []

        def action(h, w, lb):
            h.button("OK").command()
            calls.append(lb.selected)
            h.button("Cancel").command()

        result, *_ = self._show({"items": ["a"]}, action, selected=())
        self.assertEqual(result, (False, None, 1, False))
        self.assertEqual(calls, [()])

    def test_double_click_and_return_accept(self):
        result, *_ = self._show({"items": ["a", "b"]}, lambda h, w, lb: lb.handlers["<Double-1>"](None), selected=(1,))
        self.assertEqual(result[:2], (True, "b"))
        result, *_ = self._show({"items": ["a", "b"]}, lambda h, w, lb: w.handlers["<Return>"](None))
        self.assertEqual(result[:2], (True, "a"))

    def test_escape_cancels(self):
        result, *_ = self._show({"items": ["a"]}, lambda h, w, lb: w.handlers["<Escape>"](None))
        self.assertEqual(result, (False, None, 1, False))

    def test_the_shown_flag_follows_the_map_event(self):
        result, *_ = self._show(
            {"items": ["a"]},
            lambda h, w, lb: (w.handlers["<Map>"](None), h.button("Cancel").command()),
        )
        self.assertEqual(result, (False, None, 1, True))

    def test_the_message_is_shown_only_when_given(self):
        _r, plain, *_ = self._show({"items": ["a"]}, lambda h, w, lb: h.button("Cancel").command())
        self.assertEqual(plain.of("Label"), [])
        _r, withmsg, *_ = self._show(
            {"items": ["a"], "message": "Pick one", "title": "T", "width": 400, "height": 250},
            lambda h, w, lb: h.button("Cancel").command(),
        )
        self.assertEqual([w.text for w in withmsg.of("Label")], ["Pick one"])


class TableDialogTests(unittest.TestCase):
    ROWS = [["Mon", "7-23"], ["Tue", "8-17"]]

    def _show(self, payload, action, selected=None):
        harness = Harness()
        window = make_window()
        trees = []
        original = harness.ttk.Treeview

        def make_tree(*args, **kwargs):
            tree = original(*args, **kwargs)
            trees.append(tree)
            return tree

        harness.ttk.Treeview = make_tree
        result, _cd = run_dialog(
            table_ui, table_ui.show_table_dialog, window, payload, harness,
            lambda: action(harness, window, trees[0]),
        )
        return result, harness, window, trees[0]

    def payload(self, **extra):
        return {"columns": ["Day", "Hours"], "rows": self.ROWS, **extra}

    def test_missing_columns_is_an_error(self):
        with self.assertRaises(ValueError):
            self._show({"rows": []}, lambda h, w, t: None)

    def test_print_column_out_of_range_is_an_error(self):
        for bad in (0, 3, -1):
            payload = self.payload(print_column=bad)
            with self.subTest(print_column=bad), self.assertRaises(ValueError):
                self._show(payload, lambda h, w, t: None)

    def test_headings_columns_and_rows_are_built(self):
        _r, _h, _w, tree = self._show(self.payload(), lambda h, w, t: h.button("Cancel").command())
        self.assertEqual(tree.headings["c0"], {"text": "Day"})
        self.assertEqual(tree.headings["c1"], {"text": "Hours"})
        self.assertEqual(tree.columns["c0"]["width"], 110)
        self.assertEqual(tree.columns["c1"]["width"], 180)
        self.assertEqual(
            [kw["values"] for _a, kw in tree.inserted], [["Mon", "7-23"], ["Tue", "8-17"]]
        )

    def test_short_rows_are_padded_with_empty_cells(self):
        _r, _h, _w, tree = self._show(
            {"columns": ["A", "B"], "rows": [["only"]]}, lambda h, w, t: h.button("Cancel").command()
        )
        self.assertEqual(tree.inserted[0][1]["values"], ["only", ""])

    def test_the_first_row_is_preselected_so_ok_returns_it(self):
        result, *_ = self._show(self.payload(), lambda h, w, t: h.button("OK").command())
        self.assertEqual(result, (True, "Mon", 0, False))

    def test_print_column_chooses_which_cell_is_returned(self):
        result, *_ = self._show(self.payload(print_column=2), lambda h, w, t: h.button("OK").command())
        self.assertEqual(result[:2], (True, "7-23"))

    def test_a_chosen_row_is_returned(self):
        def action(h, w, tree):
            tree.selected = ("1",)
            h.button("OK").command()

        result, *_ = self._show(self.payload(), action)
        self.assertEqual(result[:2], (True, "Tue"))

    def test_ok_with_nothing_selected_keeps_the_dialog_open(self):
        def action(h, w, tree):
            tree.selected = ()
            h.button("OK").command()
            h.button("Cancel").command()

        result, *_ = self._show(self.payload(), action)
        self.assertEqual(result, (False, None, 1, False))

    def test_double_click_return_and_escape(self):
        result, *_ = self._show(self.payload(), lambda h, w, t: t.handlers["<Double-1>"](None))
        self.assertEqual(result[:2], (True, "Mon"))
        result, *_ = self._show(self.payload(), lambda h, w, t: w.handlers["<Return>"](None))
        self.assertEqual(result[:2], (True, "Mon"))
        result, *_ = self._show(self.payload(), lambda h, w, t: w.handlers["<Escape>"](None))
        self.assertEqual(result[:2], (False, None))

    def test_an_empty_table_is_not_preselected(self):
        result, *_ = self._show(
            {"columns": ["A"], "rows": []}, lambda h, w, t: h.button("OK").command()
        )
        self.assertEqual(result, (False, None, 1, False))

    def test_the_shown_flag_follows_the_map_event(self):
        result, *_ = self._show(
            self.payload(message="Pick", title="T"),
            lambda h, w, t: (w.handlers["<Map>"](None), h.button("Cancel").command()),
        )
        self.assertEqual(result, (False, None, 1, True))


class OneShotCliTests(unittest.TestCase):
    def run_cli(self, module, stdin_text):
        stdout, stderr = io.StringIO(), io.StringIO()
        with mock.patch.object(sys, "stdin", io.StringIO(stdin_text)), \
                redirect_stdout(stdout), redirect_stderr(stderr):
            with self.assertRaises(SystemExit) as raised:
                module.main()
        return raised.exception.code, stdout.getvalue(), stderr.getvalue()

    def check_invalid_json(self, module):
        with mock.patch.object(module.tk, "Tk") as tk_root:
            code, out, err = self.run_cli(module, "{not json")
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("Invalid JSON input", err)
        tk_root.assert_not_called()

    def test_time_cli(self):
        module = load_script("configure-dialogs-darwin-time.py", "cd_time_cli")
        self.check_invalid_json(module)
        with mock.patch.object(module.tk, "Tk") as tk_root, \
                mock.patch.object(module._cd_window, "apply_app_icon") as icon, \
                mock.patch.object(module.time_ui, "show_time_dialog", return_value=(True, "9:00AM-5:00PM", 0)):
            code, out, _err = self.run_cli(module, "{}")
        self.assertEqual((code, out), (0, "9:00AM-5:00PM\n"))
        icon.assert_called_once_with(tk_root.return_value)
        tk_root.return_value.destroy.assert_called_once_with()
        with mock.patch.object(module.tk, "Tk"), \
                mock.patch.object(module._cd_window, "apply_app_icon"), \
                mock.patch.object(module.time_ui, "show_time_dialog", return_value=(False, None, 1)):
            code, out, _err = self.run_cli(module, "{}")
        self.assertEqual((code, out), (1, ""))

    def test_text_cli(self):
        module = load_script("configure-dialogs-darwin-text.py", "cd_text_cli")
        self.check_invalid_json(module)
        with mock.patch.object(module.tk, "Tk") as tk_root, \
                mock.patch.object(module._cd_window, "apply_app_icon"), \
                mock.patch.object(module.text_ui, "show_text_dialog", return_value=(True, "Yes, save", 0)):
            code, out, _err = self.run_cli(module, "{}")
        self.assertEqual((code, out), (0, "Yes, save\n"))
        tk_root.return_value.destroy.assert_called_once_with()
        with mock.patch.object(module.tk, "Tk"), \
                mock.patch.object(module._cd_window, "apply_app_icon"), \
                mock.patch.object(module.text_ui, "show_text_dialog", return_value=(False, None, 1)):
            code, out, _err = self.run_cli(module, "{}")
        self.assertEqual((code, out), (1, ""))

    def test_table_cli(self):
        module = load_script("configure-dialogs-darwin-table.py", "cd_table_cli")
        self.check_invalid_json(module)
        with mock.patch.object(module.tk, "Tk") as tk_root, \
                mock.patch.object(module._cd_window, "apply_app_icon"), \
                mock.patch.object(module.table_ui, "show_table_dialog", return_value=(True, "Mon", 0, True)):
            code, out, _err = self.run_cli(module, "{}")
        self.assertEqual((code, out), (0, "Mon\n"))
        tk_root.return_value.destroy.assert_called_once_with()
        with mock.patch.object(module.tk, "Tk"), \
                mock.patch.object(module._cd_window, "apply_app_icon"), \
                mock.patch.object(module.table_ui, "show_table_dialog", return_value=(False, None, 1, True)):
            code, out, _err = self.run_cli(module, "{}")
        self.assertEqual((code, out), (1, ""))


class DaemonTests(unittest.TestCase):
    def setUp(self):
        self.daemon = load_script("configure-dialogs-darwin-daemon.py", "cd_daemon")
        self.dialog = mock.MagicMock(name="dialog")
        self.root = mock.MagicMock(name="root")
        self.fake_ui = {
            "list_ui": self.fake_module("show_list_dialog", (True, "b", 0, True)),
            "table_ui": self.fake_module("show_table_dialog", (True, "Mon", 0, True)),
            "text_ui": self.fake_module("show_text_dialog", (True, "Yes", 0)),
            "time_ui": self.fake_module("show_time_dialog", (True, "9:00AM-5:00PM", 0)),
        }
        for name, fake in self.fake_ui.items():
            setattr(self.daemon, name, fake)

    @staticmethod
    def fake_module(function: str, result: tuple) -> mock.MagicMock:
        module = mock.MagicMock()
        getattr(module, function).return_value = result
        return module

    def run_op(self, op, **fields):
        return self.daemon._run_dialog(self.root, self.dialog, op, {"op": op, **fields})

    def test_list_table_time_and_text_results(self):
        self.assertEqual(self.run_op("list"), {"ok": True, "value": "b", "shown": True})
        self.assertEqual(self.run_op("table"), {"ok": True, "value": "Mon", "shown": True})
        self.assertEqual(self.run_op("time"), {"ok": True, "value": "9:00AM-5:00PM"})
        self.assertEqual(self.run_op("text"), {"ok": True, "value": "Yes", "exit_code": 0})

    def test_cancelled_results(self):
        self.fake_ui["list_ui"].show_list_dialog.return_value = (False, None, 1, False)
        self.fake_ui["table_ui"].show_table_dialog.return_value = (False, None, 1, True)
        self.fake_ui["time_ui"].show_time_dialog.return_value = (False, None, 1)
        self.fake_ui["text_ui"].show_text_dialog.return_value = (False, None, 1)
        self.assertEqual(self.run_op("list"), {"ok": False, "cancelled": True, "shown": False})
        self.assertEqual(self.run_op("table"), {"ok": False, "cancelled": True, "shown": True})
        self.assertEqual(self.run_op("time"), {"ok": False, "cancelled": True})
        self.assertEqual(self.run_op("text"), {"ok": False, "cancelled": True})

    def test_a_text_dialog_dismissed_with_a_label_still_reports_it(self):
        self.fake_ui["text_ui"].show_text_dialog.return_value = (False, "No", 1)
        self.assertEqual(self.run_op("text"), {"ok": True, "value": "No", "exit_code": 1})

    def test_unknown_op_is_an_error(self):
        self.assertEqual(self.run_op("bogus"), {"ok": False, "error": "unknown op: bogus"})

    def test_the_dialog_is_released_and_hidden_afterwards(self):
        self.dialog.winfo_exists.return_value = True
        self.run_op("time")
        self.dialog.grab_release.assert_called_once_with()
        self.dialog.withdraw.assert_called_once_with()

    def test_a_destroyed_dialog_is_left_alone(self):
        self.dialog.winfo_exists.return_value = False
        self.run_op("time")
        self.dialog.grab_release.assert_not_called()
        self.dialog.withdraw.assert_not_called()

    def test_tcl_errors_during_cleanup_are_ignored(self):
        self.dialog.winfo_exists.side_effect = tk.TclError("gone")
        self.assertTrue(self.run_op("time")["ok"])

    def test_ui_modules_are_imported_lazily(self):
        for name in self.fake_ui:
            setattr(self.daemon, name, None)
        modules = {
            f"configure_dialogs_darwin_{op}_ui": fake
            for op, fake in (
                ("list", self.fake_ui["list_ui"]), ("table", self.fake_ui["table_ui"]),
                ("text", self.fake_ui["text_ui"]), ("time", self.fake_ui["time_ui"]),
            )
        }
        with mock.patch.dict(sys.modules, modules):
            self.assertTrue(self.run_op("list")["ok"])
            self.assertTrue(self.run_op("table")["ok"])
            self.assertTrue(self.run_op("time")["ok"])
            self.assertTrue(self.run_op("text")["ok"])

    def test_warm_imports_loads_all_four_modules(self):
        for name in self.fake_ui:
            setattr(self.daemon, name, None)
        self.daemon._warm_imports()
        self.assertIs(self.daemon.list_ui, list_ui)
        self.assertIs(self.daemon.table_ui, table_ui)
        self.assertIs(self.daemon.text_ui, text_ui)
        self.assertIs(self.daemon.time_ui, time_ui)

    def run_main(self, lines):
        stdout = io.StringIO()
        root = mock.MagicMock(name="root")
        with mock.patch.object(self.daemon.tk, "Tk", return_value=root), \
                mock.patch.object(self.daemon.tk, "Toplevel"), \
                mock.patch.object(self.daemon, "_warm_imports"), \
                mock.patch.object(cd_window, "apply_app_icon") as icon, \
                mock.patch.object(sys, "stdin", io.StringIO(lines)), \
                redirect_stdout(stdout):
            with self.assertRaises(SystemExit) as raised:
                self.daemon.main()
        responses = [json.loads(line) for line in stdout.getvalue().splitlines()]
        return raised.exception.code, responses, root, icon

    def test_main_answers_each_request_and_quits(self):
        lines = "\n".join([
            "",
            "not json",
            json.dumps({"op": "bogus"}),
            json.dumps({"op": "time"}),
            json.dumps({"op": "quit"}),
            json.dumps({"op": "time"}),
        ])
        code, responses, root, icon = self.run_main(lines)
        self.assertEqual(code, 0)
        self.assertEqual(responses[0], {"ok": True, "ready": True})
        self.assertTrue(responses[1]["error"].startswith("invalid json"))
        self.assertEqual(responses[2], {"ok": False, "error": "unknown op: bogus"})
        self.assertEqual(responses[3], {"ok": True, "value": "9:00AM-5:00PM"})
        self.assertEqual(responses[4], {"ok": True, "quit": True})
        self.assertEqual(len(responses), 5)  # nothing after quit
        root.withdraw.assert_called_once_with()
        root.destroy.assert_called_once_with()
        icon.assert_called_once_with(root)

    def test_main_exits_cleanly_at_end_of_input(self):
        code, responses, root, _icon = self.run_main("")
        self.assertEqual(code, 0)
        self.assertEqual(responses, [{"ok": True, "ready": True}])
        root.destroy.assert_not_called()


if __name__ == "__main__":
    unittest.main()
