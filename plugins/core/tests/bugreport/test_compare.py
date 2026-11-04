"""`compare_bugreport.py`: identical inputs compare empty, real moves are reported."""

from __future__ import annotations

import json
from pathlib import Path

import analyze_bugreport
import compare_bugreport


def _analyze(path, tmp_path, name, capsys, *extra):
    """One analyze run with its own cache, so its redaction salt differs from every other run."""
    out = tmp_path / f"{name}.json"
    argv = [
        "--input",
        str(path),
        "--output",
        str(out),
        "--output-dir",
        str(tmp_path / name),
        *extra,
    ]
    assert analyze_bugreport.main(argv) == 0
    capsys.readouterr()
    return str(out)


def _compare(capsys, *argv):
    code = compare_bugreport.main(list(argv))
    out, err = capsys.readouterr()
    return code, json.loads(out) if code == 0 else out, err


def test_same_report_twice_compares_empty(built, tmp_path, capsys):
    path = built("modern", ("thrashing", "battery-drain", "sideloaded"))
    a = _analyze(path, tmp_path, "a", capsys, "--family", "memory,battery,security")
    b = _analyze(path, tmp_path, "b", capsys, "--family", "memory,battery,security")
    # each report salts its own tokens: the same identifier must still pair
    for path, hexed in ((a, "11111111"), (b, "22222222")):
        doc = json.loads(Path(path).read_text())
        doc["findings"][0]["subjects"][0]["package"] = f"<serial:{hexed}>"
        Path(path).write_text(json.dumps(doc))
    code, doc, _ = _compare(capsys, "--input", a, "--against", b)
    assert code == 0
    # invented_changes_on_identical_inputs == 0
    assert doc["changes"] == [] and doc["rankings"] == []
    assert doc["summary"] == {"new": 0, "changed": 0, "gone": 0}


def test_new_and_gone_findings_pair_on_id_and_package(built, tmp_path, capsys):
    old = _analyze(built("modern", ("thrashing",)), tmp_path, "old", capsys)
    new = _analyze(built("modern", ("battery-drain",)), tmp_path, "new", capsys)
    code, doc, _ = _compare(capsys, "--input", new, "--against", old)
    assert code == 0
    by = {(r["change"], r["id"]) for r in doc["changes"]}
    assert ("new", "battery.screen_off_drain") in by
    assert ("gone", "memory.swap_thrashing") in by


def test_schema_major_mismatch_exits_1(built, cli, tmp_path, capsys):
    a = _analyze(built("modern"), tmp_path, "a", capsys)
    doc = json.loads(Path(a).read_text())
    doc["schema"] = "bugreport.analyze/2"
    b = tmp_path / "b.json"
    b.write_text(json.dumps(doc))
    code, _, err = _compare(capsys, "--input", str(b), "--against", a)
    assert code == 1 and "schema majors differ" in err


def test_not_an_analyze_document_exits_1(tmp_path, capsys):
    p = tmp_path / "x.json"
    p.write_text('{"schema": "bugreport.query/1"}')
    assert _compare(capsys, "--input", str(p), "--against", str(p))[0] == 1
