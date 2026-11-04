"""The redaction filter: every canary kind, token equality, per-run salts."""

from __future__ import annotations

import _redact as rd
import pytest

SALT = b"s" * 32


@pytest.mark.parametrize(
    "kind", ["email", "phone", "mac", "imei", "iccid", "imsi", "serial", "ssid", "coord", "account"]
)
def test_each_canary_kind_is_redacted(fx, built, cli, kind):
    code, doc, _ = cli(
        "query_bugreport",
        "show",
        "--input",
        str(built("modern")),
        "--section",
        _SECTION[kind],
        "--limit",
        "0",
    )
    assert code == 0
    text = str(doc)
    value = fx.CANARIES[kind]
    assert value not in text, kind
    if kind == "coord":
        assert value.split(",")[0] not in text


_SECTION = {
    "email": "account",
    "account": "account",
    "phone": "iphonesubinfo",
    "mac": "wifi",
    "imei": "iphonesubinfo",
    "iccid": "iphonesubinfo",
    "imsi": "iphonesubinfo",
    "serial": "SYSTEM PROPERTIES",
    "ssid": "wifi",
    "coord": "location",
}


def test_equal_values_share_a_token_within_one_run():
    out = rd.filter("a canary.user@example.com b canary.user@example.com", SALT)
    tokens = [w for w in out.split() if w.startswith("<email:")]
    assert len(tokens) == 2 and tokens[0] == tokens[1]


def test_tokens_differ_across_runs():
    a, b = rd.new_salt(), rd.new_salt()
    assert a != b
    assert rd.filter("x@example.com", a) != rd.filter("x@example.com", b)


def test_masked_android_mac_is_left_alone():
    assert rd.filter("mac 02:00:00:00:00:00", SALT) == "mac 02:00:00:00:00:00"


def test_harvested_national_number_is_masked():
    harvested = rd.harvest(["mLine1Number=+12025550142"])
    assert "2025550142" in harvested
    assert "2025550142" not in rd.filter("dialed 2025550142 ok", SALT, harvested)


def test_non_luhn_digit_run_passes():
    assert rd.filter("count 123456789012345", SALT) == "count 123456789012345"
