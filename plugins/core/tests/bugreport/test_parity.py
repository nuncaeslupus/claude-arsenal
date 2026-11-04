"""Sibling scripts spell the shared flags the same way."""

from __future__ import annotations

import re
import subprocess
import sys

from conftest import SCRIPTS

QUERY = ("sections", "locate", "sample", "show", "timeline", "summary")
ENVELOPE = [["analyze_bugreport.py"], ["compare_bugreport.py"]] + [
    ["query_bugreport.py", sub] for sub in QUERY
]
REPORT = [["validate_bugreport.py"], ["analyze_bugreport.py"], ["create_bugreport.py"]] + [
    ["query_bugreport.py", sub] for sub in QUERY
]


def _flags(argv: list[str]) -> set[str]:
    out = subprocess.run(
        [sys.executable, str(SCRIPTS / argv[0]), *argv[1:], "--help"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return set(re.findall(r"^\s+(--[\w-]+)", out, re.M))


def test_sibling_scripts_share_input_output_limit_flags():
    for argv in ENVELOPE:
        assert {"--input", "--output", "--limit"} <= _flags(argv), argv
    for argv in REPORT:
        assert {"--input", "--output-dir", "--force", "--json"} <= _flags(argv), argv


def test_runtime_imports_are_stdlib_only():
    import ast

    local = {p.stem for p in SCRIPTS.glob("*.py")}
    bad = []
    for path in SCRIPTS.glob("*.py"):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        guarded = {id(n) for t in ast.walk(tree) if isinstance(t, ast.Try) for n in ast.walk(t)}
        for node in ast.walk(tree):
            if id(node) in guarded:  # optional, with a fallback (termcolor in _console)
                continue
            if isinstance(node, ast.Import):
                names = [a.name for a in node.names]
            elif isinstance(node, ast.ImportFrom) and not node.level:
                names = [node.module or ""]
            else:
                continue
            for top in (n.split(".")[0] for n in names):
                if top not in sys.stdlib_module_names and top not in local:
                    bad.append(f"{path.name}: {top}")
    assert not bad, bad
