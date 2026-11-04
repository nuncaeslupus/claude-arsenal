"""Shared fixtures: synthetic bugreports built per test session, never captured (D-9)."""

from __future__ import annotations

import json
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

HERE = Path(__file__).resolve().parent
SCRIPTS = HERE.parent.parent / "skills" / "bugreport" / "scripts"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(HERE))

import make_fixture  # noqa: E402


@pytest.fixture(scope="session")
def fx() -> Any:
    return make_fixture


@pytest.fixture(scope="session")
def built(tmp_path_factory: pytest.TempPathFactory) -> Callable[..., Path]:
    """`built(layout, scenarios, **kw)` -> path, each distinct build written once."""
    out = tmp_path_factory.mktemp("bugreports")
    cache: dict[str, Path] = {}

    def get(layout: str = "modern", scenarios: tuple[str, ...] = (), **kw: Any) -> Path:
        key = repr((layout, scenarios, sorted(kw.items())))
        if key not in cache:
            cache[key] = make_fixture.build(layout, scenarios, out_dir=out, **kw)
        return cache[key]

    return get


@pytest.fixture
def cli(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> Callable[..., tuple[int, Any, str]]:
    """`cli(module_name, *argv)` -> (exit, parsed stdout JSON or raw text, stderr)."""
    import importlib

    import _console

    # _console binds sys.stderr as a default when imported; resolve it at call time instead
    emit = _console._emit
    monkeypatch.setattr(_console, "_emit", lambda kind, msg: emit(kind, msg, file=sys.stderr))

    def call(name: str, *argv: str) -> tuple[int, Any, str]:
        mod = importlib.import_module(name)
        code = mod.main([*argv, "--output-dir", str(tmp_path / "cache")])
        out, err = capsys.readouterr()
        try:
            return code, json.loads(out), err
        except ValueError:
            return code, out, err

    return call
