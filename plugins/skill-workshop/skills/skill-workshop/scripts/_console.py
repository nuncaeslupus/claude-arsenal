"""Internal console helper for skill-workshop scripts.

Stderr-first output with prefix icons. Colour optional (termcolor when
available + stderr is a TTY). Stdout is reserved for the data payload
(JSON) and never written to from this module.
"""

from __future__ import annotations

import sys
from typing import TextIO

try:
    from termcolor import colored as _colored

    _HAS_COLOR = True
except Exception:  # pragma: no cover - termcolor optional
    _HAS_COLOR = False

    def _colored(text: str, *_: object, **__: object) -> str:  # type: ignore[misc]
        return text


_ICONS = {
    "start": "▶",
    "ok": "✓",
    "fail": "✗",
    "warn": "⚠",
    "info": "ℹ",  # noqa: RUF001
}
_COLORS = {
    "start": "blue",
    "ok": "green",
    "fail": "red",
    "warn": "yellow",
    "info": "cyan",
}


def _emit(kind: str, message: str, *, file: TextIO = sys.stderr) -> None:
    icon = _ICONS.get(kind, "")
    line = f"{icon} {message}" if icon else message
    color = _COLORS.get(kind)
    if color and _HAS_COLOR and getattr(file, "isatty", lambda: False)():
        line = _colored(line, color)
    print(line, file=file)


def start(message: str) -> None:
    _emit("start", message)


def ok(message: str) -> None:
    _emit("ok", message)


def fail(message: str) -> None:
    _emit("fail", message)


def warn(message: str) -> None:
    _emit("warn", message)


def info(message: str) -> None:
    _emit("info", message)
