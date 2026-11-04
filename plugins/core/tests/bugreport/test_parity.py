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
