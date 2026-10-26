#!/usr/bin/env python3
"""Headless checks for the macOS TimerWarning Dock-icon helpers.

The helpers are ``apply_app_icon`` in ``lib/configure_dialogs_darwin_window.py``
and ``_apply_app_icon`` in ``lib/popup-blocker-darwin.py``. Both set
``root.iconphoto(True, image)`` and keep the image on ``root._sw_app_icon``.

Inputs: the two library modules and ``assets/icon-256.png``.
Output: a PASS line, or a SKIP line and exit 0 when tkinter cannot be imported.
This does not open a Tk window. PhotoImage is replaced with a fake so the test
can run without a display.

Requirements: Python 3. tkinter must be importable; a GUI session is not required.
"""

from __future__ import annotations

import importlib.util
import shutil
import sys
import tempfile
from pathlib import Path
from types import ModuleType
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
sys.path.insert(0, str(LIB))


def _skip(message: str) -> None:
    print(f"SKIP: {message}")
    raise SystemExit(0)


try:
    import tkinter as tk
except ImportError as exc:
    _skip(f"tkinter is not importable ({exc})")


class _Root:
    """Stand-in for a Tk root. Records iconphoto and keeps assigned attributes."""

    def iconphoto(self, default: bool, image: object) -> None:
        self.icon_default = default
        self.icon_image = image


class _FakeImage:
    """Records the file path PhotoImage would have loaded."""

    def __init__(self, master: object = None, file: str | None = None) -> None:
        self.master = master
        self.file = file


def _assert_loaded(root: _Root, image: _FakeImage, expected_name: str) -> None:
    if root.icon_default is not True:
        raise SystemExit("FAIL: iconphoto was not asked to set the default icon")
    if root.icon_image is not image:
        raise SystemExit("FAIL: iconphoto did not receive the loaded image")
    if getattr(root, "_sw_app_icon", None) is not image:
        raise SystemExit("FAIL: the image reference was not kept on the root")
    if Path(str(image.file)).name != expected_name:
        raise SystemExit(f"FAIL: expected {expected_name}, loaded {image.file}")


def _load(name: str, path: Path) -> ModuleType:
    """Load a module by path, including hyphenated names such as popup-blocker-darwin.py."""
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"FAIL: cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _check_apply(filename: str, module_name: str, function_name: str) -> None:
    """Exercise one helper against a temp install layout and the repo fallback."""
    with tempfile.TemporaryDirectory(prefix="popup-icon-tk.") as raw:
        root_dir = Path(raw)
        lib_dir = root_dir / "lib"
        assets = root_dir / "assets"
        lib_dir.mkdir()
        assets.mkdir()
        shutil.copy(LIB / filename, lib_dir / filename)
        shutil.copy(ROOT / "assets" / "icon-256.png", assets / "icon-256.png")
        installed = lib_dir / "timerwarning-icon.png"
        installed.write_bytes(b"installed-icon")
        module = _load(module_name, lib_dir / filename)
        apply_icon = getattr(module, function_name)
        created: list[_FakeImage] = []

        def fake_photo(*_args: object, **kwargs: object) -> _FakeImage:
            image = _FakeImage(master=kwargs.get("master"), file=kwargs.get("file"))  # type: ignore[arg-type]
            created.append(image)
            return image

        def broken(*_args: object, **_kwargs: object) -> _FakeImage:
            raise tk.TclError("unreadable icon")

        with patch.object(tk, "PhotoImage", fake_photo):
            root = _Root()
            apply_icon(root)
            if len(created) != 1:
                raise SystemExit(f"FAIL: {function_name} loaded {len(created)} images")
            _assert_loaded(root, created[0], "timerwarning-icon.png")

            installed.unlink()
            created.clear()
            fallback = _Root()
            apply_icon(fallback)
            if len(created) != 1:
                raise SystemExit(f"FAIL: {function_name} did not fall back to the repo asset")
            _assert_loaded(fallback, created[0], "icon-256.png")

            assets.joinpath("icon-256.png").unlink()
            created.clear()
            missing = _Root()
            apply_icon(missing)
            if created:
                raise SystemExit(f"FAIL: {function_name} loaded an image when no file exists")
            if hasattr(missing, "_sw_app_icon"):
                raise SystemExit(f"FAIL: {function_name} set an icon when no file exists")

        installed.write_bytes(b"installed-icon")
        with patch.object(tk, "PhotoImage", broken):
            bad = _Root()
            try:
                apply_icon(bad)
            except tk.TclError as exc:
                raise SystemExit(f"FAIL: {function_name} let TclError escape: {exc}") from exc
            if hasattr(bad, "_sw_app_icon"):
                raise SystemExit(f"FAIL: {function_name} kept an icon after TclError")


def main() -> None:
    _check_apply(
        "configure_dialogs_darwin_window.py",
        "configure_dialogs_darwin_window",
        "apply_app_icon",
    )
    _check_apply(
        "popup-blocker-darwin.py",
        "popup_blocker_darwin",
        "_apply_app_icon",
    )
    print("PASS: macOS icon helpers set, skip, and swallow icon failures")


if __name__ == "__main__":
    main()
