"""Shared fixtures: the HAR files, built once per test session into a temp dir."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
SCRIPTS = HERE.parent.parent / "skills" / "har" / "scripts"
sys.path.insert(0, str(SCRIPTS))


def _load(name: str):
    """Import one of the skill's scripts by path.

    Registered in `sys.modules` before execution: `@dataclass` resolves types
    through `sys.modules[cls.__module__]`, so a module that is executed without
    being registered raises on its first dataclass rather than on anything to do
    with the test.
    """
    key = f"_har_{name}"
    if key in sys.modules:
        return sys.modules[key]
    spec = importlib.util.spec_from_file_location(key, SCRIPTS / f"{name}.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[key] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="session")
def harlib():
    """The real `_harlib` module — imported by name, not loaded a second time.

    Loading it under a private name would give the tests a *different* module
    object from the one the scripts import, with different exception classes:
    `pytest.raises(harlib.HarStructureError)` would then fail to catch the
    error the script actually raised, and the test would look like a bug in the
    code rather than in its own wiring.
    """
    import _harlib

    return _harlib


@pytest.fixture(scope="session")
def analyze():
    return _load("analyze_har")


@pytest.fixture(scope="session")
def validate_mod():
    return _load("validate_har")


@pytest.fixture(scope="session")
def fixtures_dir(tmp_path_factory) -> Path:
    """Every fixture HAR, generated deterministically. Built, never captured."""
    sys.path.insert(0, str(HERE))
    import fixtures  # type: ignore[import-not-found]

    out = tmp_path_factory.mktemp("har-fixtures")
    fixtures.write_all(out)
    return out


@pytest.fixture
def scratch(fixtures_dir, tmp_path) -> Path:
    """A writable copy of the fixtures, so index sidecars do not leak between tests."""
    import shutil

    target = tmp_path / "har"
    shutil.copytree(fixtures_dir, target)
    return target
