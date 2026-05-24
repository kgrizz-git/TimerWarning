## Goal

Ensure **no GUI dialog anywhere ever crashes under non‑UTF locales**, while still preferring “fancy” Unicode symbols when a UTF‑8 locale is available and confirmed.

This specifically targets known failures where GTK dialog tools (`yad` / `zenity`) can exit immediately when passed UTF‑8 text under a non‑UTF locale (e.g. `LANG=C`), causing popups/config dialogs to fail.

## Plan (implemented)

- **Centralize UTF‑8 detection and fallback behavior**
  - Best-effort: attempt to switch the process environment to a UTF‑8 locale when available (`C.UTF-8`, `en_US.UTF-8`, `en_US.utf8`).
  - If UTF‑8 still can’t be confirmed, **sanitize user-visible dialog strings to ASCII** so GUI tools never receive Unicode bytes.

- **Apply the safeguard at the right layer**
  - Wrap the tool-agnostic dialog helpers (`lib/configure-dialogs.sh`) so **all wizard/uninstall dialogs** automatically inherit the behavior.
  - Patch any modules that call `yad/zenity/kdialog` directly (not via wrappers), notably:
    - `lib/popup-display.sh`
    - `manual-uninstall-guide.sh`
    - `tests/test-popup.sh`

- **Regression test**
  - Add a small test that forces ASCII fallback and asserts the resulting text contains **no non-ASCII bytes**, and that key symbol replacements occur.

## Changes made

### Added: shared helper module

- `lib/unicode-dialog-safety.sh`
  - **`dialog_prepare_utf8_locale`**: best-effort UTF‑8 locale setup + cached decision.
  - **`dialog_safe_text`**: returns original text when UTF‑8 confirmed, else ASCII-sanitized text.
  - **`dialog_sanitize_to_ascii`**: replaces common symbols and strips remaining non-ASCII bytes.
  - **Testing hook**: `DIALOG_SAFETY_FORCE_ASCII=1` forces ASCII mode (no environment changes), used by tests.

### Hardened: dialog wrapper layer (wizard / uninstall flows)

- `lib/configure-dialogs.sh`
  - Sources `lib/unicode-dialog-safety.sh` and sanitizes all user-visible strings passed to GUI tools:
    - titles, main text, button labels
    - list items
    - multi-column list column headers and data cells
  - Includes a hard fallback no-op `dialog_safe_text()` if the helper cannot be sourced (to keep dialogs functional).

### Hardened: direct popup invocations

- `lib/popup-display.sh`
  - Sources `lib/unicode-dialog-safety.sh`.
  - Uses `dialog_prepare_utf8_locale` when available (otherwise uses existing `ensure_utf8_locale_for_dialogs`).
  - Sanitizes:
    - the main popup message (including ⚠️ / ⏱️ content)
    - window title
    - dynamically updated countdown message used for minimum-display-time enforcement

### Hardened: manual uninstall GUI step dialogs

- `manual-uninstall-guide.sh`
  - Sanitizes per-step dialog text and title before feeding it into `yad/zenity/kdialog`.

### Updated: test popup

- `tests/test-popup.sh`
  - Sources `lib/unicode-dialog-safety.sh`.
  - Prefers UTF‑8 locale via `dialog_prepare_utf8_locale`, but always uses `dialog_safe_text()` for title/message so the test itself cannot crash under non‑UTF locales.

### Added: regression test

- `tests/test-non-utf-dialog-safety.sh`
  - Forces ASCII fallback mode (`DIALOG_SAFETY_FORCE_ASCII=1`).
  - Asserts output is ASCII-only and spot-checks key replacements (WARNING/TIMER/OK/->).

## Test run log updates

- Updated `dev-docs/testing-assessments/test-history.md` with results for `test-non-utf-dialog-safety.sh`.

## What happens if no UTF‑8 locale is configured?

When the process runs under a non‑UTF locale (e.g. `LANG=C`, `LC_ALL=C`) **and a UTF‑8 locale cannot be switched to/confirmed**:

- **GUI dialogs (yad/zenity/kdialog)**
  - Any dialog strings routed through `lib/configure-dialogs.sh` are automatically passed through `dialog_safe_text()` and will be **ASCII-only**.
  - `lib/popup-display.sh` now also sanitizes its popup title/text/countdown strings before invoking `yad/zenity/kdialog`, so popups should **not crash** due to Unicode bytes.
  - `manual-uninstall-guide.sh` GUI step dialogs sanitize their title/body text before invoking GUI tools.

- **Console output (no GUI involved)**
  - Scripts like `status.sh`, `uninstall.sh`, and `manual-uninstall-guide.sh` print some Unicode (arrows, box-drawing, warning/info symbols). Under non‑UTF locales these characters may render as **garbled text** depending on terminal/fonts, but the scripts should still **run normally** (they don’t “crash” due to Unicode in typical shells; the main crash vector was GTK dialog tools parsing UTF‑8).

