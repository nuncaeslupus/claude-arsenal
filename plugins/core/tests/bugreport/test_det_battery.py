"""F1 battery: a fast screen-off drain fires and names the wakelock holder."""

from __future__ import annotations


def _battery(cli, path):
    code, doc, _ = cli("analyze_bugreport", "--input", str(path), "--family", "battery")
    assert code == 0 and doc["not_parsed"] == []
    return doc


def test_foreground_app_screen_off_fires_drain(built, cli):
    doc = _battery(cli, built("modern", ("battery-drain",)))
    (f,) = doc["findings"]
    assert f["id"] == "battery.screen_off_drain" and f["facts"]["rate_pct_h"] == 7.31
    assert f["subjects"] == [
        {"package": "com.example.heavy", "uid": 10211, "partial_h": 4.28, "role": "cause"}
    ]


def test_checkin_v15_and_v36_both_parse(built, cli, tmp_path):
    src = built("modern", ("battery-drain",))
    old = tmp_path / "v15.txt"
    text = src.read_text()
    assert "vers,36," in text
    old.write_text(text.replace("vers,36,", "vers,15,"))
    for path in (src, old):
        assert [f["id"] for f in _battery(cli, path)["findings"]] == ["battery.screen_off_drain"]


def test_normal_screen_off_drain_fires_nothing(built, cli):
    doc = _battery(cli, built("modern"))
    assert doc["findings"] == [] and doc["views"]["battery"]["rate_pct_h"] == 2.31
