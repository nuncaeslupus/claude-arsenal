"""F11 battery health: a learned capacity under 80% of design fires."""

from __future__ import annotations


def _health(built, cli, scenarios):
    code, doc, _ = cli(
        "analyze_bugreport",
        "--input",
        str(built("modern", scenarios)),
        "--family",
        "battery-health",
    )
    assert code == 0 and doc["not_parsed"] == []
    return doc


def test_capacity_below_80pct_of_design_fires(built, cli):
    (f,) = _health(built, cli, ("battery-degraded",))["findings"]
    assert f["id"] == "battery-health.degraded"
    assert f["facts"] == {"design_mah": 4000, "learned_mah": 2900, "ratio": 0.725}


def test_healthy_capacity_fires_nothing(built, cli):
    doc = _health(built, cli, ())
    assert doc["findings"] == [] and doc["views"]["battery-health"]["ratio"] == 0.963
