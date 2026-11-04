"""F7 network: a Wi-Fi scan storm names its requester, and never the network."""

from __future__ import annotations

import json


def _network(built, cli, scenarios, *extra):
    code, doc, _ = cli(
        "analyze_bugreport",
        "--input",
        str(built("modern", scenarios)),
        "--family",
        "network",
        *extra,
    )
    assert code == 0 and doc["not_parsed"] == []
    return doc


def test_wifi_scan_storm_fires_with_requester(built, cli):
    (f,) = _network(built, cli, ("scan-storm",))["findings"]
    assert f["id"] == "network.scan_storm" and f["facts"] == {"scans": 2400, "per_h": 461.5}
    assert f["subjects"] == [{"package": "com.example.heavy", "uid": 10211, "role": "cause"}]


def test_ssid_never_appears_in_network_claims(built, cli, fx):
    doc = _network(built, cli, ("scan-storm",), "--no-redact", "--limit", "0")
    assert fx.CANARIES["ssid"] not in json.dumps(doc)


def test_quiet_wifi_fires_nothing(built, cli):
    assert _network(built, cli, ())["findings"] == []
