"""`query_bugreport.py summary`: every field, every layout, ≤ 2048 B."""

from __future__ import annotations

import json

import pytest

LAYOUTS = ("pre-p", "modern", "samsung", "xiaomi", "oneplus", "huawei", "android9")
FIELDS = {
    "device": {"manufacturer", "model", "codename"},
    "build": {"release", "sdk", "build", "security_patch"},
    "capture": {"time", "timezone", "clock"},
    "coverage": {
        "system_log",
        "event_log",
        "kernel_log",
        "batterystats_since_charge",
        "procstats_windows",
        "anr",
        "tombstones",
    },
    "file": {"input_bytes", "text_bytes", "sections", "largest", "proto_members"},
    "battery": {"level", "status", "health", "temperature_c"},
    "apps": {"installed", "user"},
}


@pytest.mark.parametrize("layout", LAYOUTS)
def test_summary_reports_every_field_per_layout(fx, built, cli, layout):
    code, doc, _ = cli("query_bugreport", "summary", "--input", str(built(layout, container="zip")))
    assert code == 0 and len(json.dumps(doc).encode()) <= 2048
    for group, keys in FIELDS.items():
        assert set(doc[group]) == keys, group
        assert all(v is not None for v in doc[group].values()), group
    for key in ("uptime_s", "boot_reason", "storage_free"):
        assert doc[key] is not None
    assert doc["device"]["manufacturer"] == fx.facts(layout)["oem"]
    assert doc["battery"]["status"] == "discharging" and doc["battery"]["temperature_c"] == 31.2


def test_summary_coverage_windows_match_fixture_bounds(fx, built, cli):
    _, doc, _ = cli("query_bugreport", "summary", "--input", str(built()))
    bounds = fx.facts("modern")["bounds"]
    for key, name in (
        ("system_log", "SYSTEM LOG"),
        ("event_log", "EVENT LOG"),
        ("kernel_log", "KERNEL LOG"),
    ):
        assert [doc["coverage"][key]["first"], doc["coverage"][key]["last"]] == bounds[name]


def test_absent_fields_read_unknown(built, cli):
    _, doc, _ = cli("query_bugreport", "summary", "--input", str(built(scenarios=("no-clock",))))
    assert doc["capture"]["clock"] == "none"
    assert doc["coverage"]["kernel_log"] == {"first": "unknown", "last": "unknown"}
    assert doc["coverage"]["anr"]["count"] == 0  # a txt report has no FS/ members
