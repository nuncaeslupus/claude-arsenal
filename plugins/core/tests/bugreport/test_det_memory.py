"""F6 memory: thrashing fires on full swap plus a busy reclaimer, and only then."""

from __future__ import annotations

import pytest

LAYOUTS = ("pre-p", "modern", "samsung", "xiaomi", "oneplus", "huawei", "android9")


def _analyze(cli, path, *extra):
    code, doc, _ = cli("analyze_bugreport", "--input", str(path), "--limit", "0", *extra)
    assert code == 0
    return doc


def test_swap_97pct_with_kswapd_cpu_fires_thrashing(built, cli):
    doc = _analyze(cli, built("modern", ("thrashing",)), "--family", "memory")
    top = doc["findings"][0]
    assert top["id"] == "memory.swap_thrashing" and top["severity"] == "critical"
    assert top["facts"]["swap_pct"] == 97.1 and top["facts"]["kswapd_cpu_pct"] >= 58
    assert top["subjects"][0] == {
        "package": "com.example.heavy",
        "pid": 4400,
        "role": "holder",
        "pss_mb": 2048,
    }
    assert doc["views"]["memory"]["lmk_kills"][0]["package"] == "com.example.heavy"


def test_unsampled_pss_falls_back_to_rss(built, cli):
    doc = _analyze(cli, built("modern", traps=("unsampled-pss",)), "--family", "memory")
    rows = {r["package"]: r for r in doc["views"]["memory"]["procstats_24h"]}
    assert rows["com.example.app"]["metric"] == "rss"
    assert rows["com.example.app"]["mem_mb"] == 90
    assert rows["com.example.heavy"]["metric"] == "pss"


@pytest.mark.parametrize("layout", LAYOUTS)
def test_healthy_memory_fixture_fires_nothing(built, cli, layout):
    doc = _analyze(cli, built(layout))
    assert doc["findings"] == []
    assert doc["not_parsed"] == []
