"""F9 storage: low free space on /data fires with the largest caches."""

from __future__ import annotations


def _storage(built, cli, scenarios):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", scenarios)), "--family", "storage"
    )
    assert code == 0 and doc["not_parsed"] == []
    return doc


def test_low_free_space_fires_with_top_caches(built, cli):
    (f,) = _storage(built, cli, ("low-storage",))["findings"]
    assert f["id"] == "storage.low_free_space" and f["facts"]["free_pct"] == 2
    assert [s["package"] for s in f["subjects"]] == [
        "com.example.heavy",
        "com.example.app",
        "com.example.notes",
    ]
    assert f["subjects"][0]["cache_mb"] == 4096


def test_ten_pct_free_fires_nothing(built, cli):
    doc = _storage(built, cli, ())
    assert doc["findings"] == [] and doc["views"]["storage"]["free_pct"] == 10
