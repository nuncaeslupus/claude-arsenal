"""F5 crashes: a package crashing three times fires; a `.pb` tombstone names its signal."""

from __future__ import annotations


def _crashes(built, cli, scenarios, **kw):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", scenarios, **kw)), "--family", "crashes"
    )
    assert code == 0 and doc["not_parsed"] == []
    return doc


def test_repeat_crash_counts_per_package(built, cli):
    doc = _crashes(built, cli, ("crash-loop",))
    (f,) = doc["findings"]
    assert f["id"] == "crashes.repeat_crash"
    assert f["facts"] == {"crashes": 3, "exception": "java.lang.IllegalStateException"}
    assert f["subjects"] == [{"package": "com.example.app", "role": "victim"}]
    assert doc["views"]["crashes"]["java"] == [
        {"package": "com.example.app", "crashes": 3, "exception": "java.lang.IllegalStateException"}
    ]


def test_pb_tombstone_in_zip_fires_native_crash(built, cli):
    doc = _crashes(built, cli, ("crash-loop",), container="zip")
    native = [f for f in doc["findings"] if f["id"] == "crashes.native_crash"]
    assert native[0]["facts"]["signal"] == "SIGABRT"
    assert native[0]["evidence"] == [{"member": "FS/data/tombstones/tombstone_01.pb"}]


def test_text_tombstone_and_no_crash_fire_nothing(built, cli):
    doc = _crashes(built, cli, (), container="zip")
    assert doc["findings"] == [] and doc["views"]["crashes"] == {"java": [], "native": []}
