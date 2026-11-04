"""The capped envelope: valid JSON, whole rows, `--limit 0` and `--output`."""

from __future__ import annotations

import json

import _brlib as br


def test_capped_output_is_valid_json_with_envelope():
    rows = [{"i": i, "pad": "x" * 100} for i in range(200)]
    doc = br.budget("t/1", rows, limit=None, cap=br.OUTPUT_BUDGET)
    text = json.dumps(doc)
    assert len(text.encode()) <= br.OUTPUT_BUDGET
    assert doc["truncated"] is True and doc["shown"] + doc["omitted"] == doc["total"] == 200
    assert doc["rows"] == rows[: doc["shown"]] and doc["full"]


def test_limit_zero_lifts_the_cap():
    rows = [{"pad": "x" * 100} for _ in range(200)]
    doc = br.budget("t/1", rows, limit=0, cap=br.OUTPUT_BUDGET)
    assert doc["truncated"] is False and doc["shown"] == 200


def test_uncapped_doc_always_says_truncated_false():
    assert br.budget("t/1", [1, 2], limit=None, cap=br.SMALL_BUDGET)["truncated"] is False


def test_output_file_gets_everything_stdout_one_line(built, cli, tmp_path):
    out = tmp_path / "all.json"
    code, env, _ = cli(
        "query_bugreport",
        "show",
        "--input",
        str(built("modern")),
        "--section",
        "SYSTEM LOG",
        "--output",
        str(out),
    )
    assert code == 0 and env["output"] == str(out) and env["truncated"] is False
    full = json.loads(out.read_text())
    assert full["shown"] == full["total"] > 100
