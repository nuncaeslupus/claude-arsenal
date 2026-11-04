"""`analyze_bugreport.py`: deterministic output and the `--family` spellings."""

from __future__ import annotations

import json
import re

import pytest

TOKEN = re.compile(r"<[a-z_]+:[0-9a-f]{8}>")
SCENARIOS = ("thrashing", "churn", "thermal")


def test_analyze_json_is_byte_identical_across_runs_modulo_tokens(built, cli):
    path = str(built("modern", SCENARIOS))
    runs = [
        cli("analyze_bugreport", "--input", path, "--family", "memory,anr", "--json") for _ in "ab"
    ]
    assert all(code == 0 for code, _, _ in runs)
    a, b = (TOKEN.sub("<t>", json.dumps(doc)) for _, doc, _ in runs)
    assert a == b


@pytest.mark.parametrize("spelling", ["memory", "F6", "f6", " Memory "])
def test_family_accepts_slug_and_f_number(built, cli, spelling):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", SCENARIOS)), "--family", spelling
    )
    assert code == 0
    assert {f["family"] for f in doc["findings"]} == {"F6"}
    assert doc["summary"]["detectors_run"] == 2


def test_unknown_family_is_usage_error(built, cli):
    code, _, err = cli("analyze_bugreport", "--input", str(built("modern")), "--family", "nope")
    assert code == 2 and "unknown family" in err
