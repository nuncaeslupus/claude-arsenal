"""F2 thermal: a throttling episode in the history fires even after the device cooled."""

from __future__ import annotations


def _thermal(built, cli, scenarios):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", scenarios)), "--family", "thermal"
    )
    assert code == 0
    return doc


def test_throttling_history_fires_thermal(built, cli):
    doc = _thermal(built, cli, ("thermal",))
    (f,) = doc["findings"]
    assert f["id"] == "thermal.throttling" and f["severity"] == "high"
    assert f["facts"] == {"status_now": 1, "status_worst": 3, "changes": 4}


def test_cool_device_fires_no_thermal(built, cli):
    doc = _thermal(built, cli, ())
    assert doc["findings"] == [] and doc["not_parsed"] == []
    assert doc["views"]["thermal"]["status_worst"] == 0
