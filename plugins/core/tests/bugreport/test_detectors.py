"""The detector loop: one broken detector is a `not_parsed` row, never a dead run."""

from __future__ import annotations

import _detectors as det


def test_raising_detector_becomes_not_parsed_row(built, cli, monkeypatch):
    det.load()

    def broken(ctx):
        raise ZeroDivisionError

    monkeypatch.setitem(
        det.REGISTRY,
        "zz.broken",
        det.Detector("zz.broken", "F6", ("meminfo",), {"zz.never": "zz.never"}, broken),
    )
    code, doc, _ = cli("analyze_bugreport", "--input", str(built("modern")), "--json")
    assert code == 0
    row = next(r for r in doc["not_parsed"] if r["detector"] == "zz.broken")
    assert row["reason"] == "error: ZeroDivisionError"
    assert row["route"].startswith("query_bugreport.py sample --input R --section meminfo#")
