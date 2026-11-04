"""The provenance checkup: one command from a thrashing report to its diagnosis."""

from __future__ import annotations

import pytest


def test_checkup_on_thrashing_fixture_ranks_thrashing_first(built, cli):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", ("thrashing",), container="zip"))
    )
    assert code == 0
    ids = [f["id"] for f in doc["findings"]]
    assert ids[0] == "memory.swap_thrashing"
    assert "anr.under_pressure" in ids and "anr.main_thread" not in ids
    victims = [s for f in doc["findings"] for s in f["subjects"] if s["role"] == "victim"]
    assert {v["package"] for v in victims} == {"com.example.app", "com.android.phone"}
    assert doc["findings"][0]["subjects"][0]["package"] == "com.example.heavy"


LAYOUTS = ("pre-p", "modern", "samsung", "xiaomi", "oneplus", "huawei", "android9")
FIRES = {
    "thrashing": ["memory.swap_thrashing", "anr.under_pressure"],
    "anr-idle": ["anr.main_thread"],
    "churn": ["memory.restart_loop"],
    "thermal": ["thermal.throttling"],
}


@pytest.mark.parametrize("layout", LAYOUTS)
@pytest.mark.parametrize("scenario", FIRES)
def test_each_scenario_fires_exactly_its_findings(built, cli, layout, scenario):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built(layout, (scenario,))), "--limit", "0"
    )
    assert code == 0 and doc["not_parsed"] == []
    assert [f["id"] for f in doc["findings"]] == FIRES[scenario]
