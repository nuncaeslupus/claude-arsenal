"""F8 peripherals: GPS held in the background fires and names the holder."""

from __future__ import annotations


def _peripherals(built, cli, scenarios):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", scenarios)), "--family", "peripherals"
    )
    assert code == 0 and doc["not_parsed"] == []
    return doc


def test_gps_held_by_background_app_fires(built, cli):
    (f,) = _peripherals(built, cli, ("gps-background",))["findings"]
    assert f["id"] == "peripherals.gps_background"
    assert f["facts"] == {"total_h": 2.0, "background_h": 1.92}
    assert f["subjects"][0]["package"] == "com.example.heavy"


def test_no_gps_fires_nothing(built, cli):
    doc = _peripherals(built, cli, ())
    assert doc["findings"] == [] and doc["views"]["peripherals"]["gps"] == []
