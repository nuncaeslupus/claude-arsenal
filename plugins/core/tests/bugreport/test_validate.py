"""validate_bugreport.py: facts per layout, UTF-16, non-bugreports."""

from __future__ import annotations

import pytest

LAYOUTS = ("pre-p", "modern", "samsung", "xiaomi", "oneplus", "huawei", "android9")


@pytest.mark.parametrize("container", ["txt", "zip", "zip-bare", "zip-text"])
@pytest.mark.parametrize("layout", LAYOUTS)
def test_validate_reports_layout_facts_per_fixture(fx, built, cli, layout, container):
    code, doc, _ = cli("validate_bugreport", "--input", str(built(layout, container=container)))
    want = fx.facts(layout)
    assert code == 0 and doc["is_bugreport"] is True
    assert doc["header"]["android_release"] == want["android_release"]
    assert doc["header"]["oem"] == want["oem"] and doc["header"]["sdk"] == want["sdk"]
    assert doc["input"]["kind"] == ("txt" if container == "txt" else "zip")


@pytest.mark.parametrize(
    "trap", ["cr", "utf16", "nul", "locale", "unsampled-pss", "timeout", "dup-service"]
)
def test_every_trap_validates(built, cli, trap):
    code, doc, _ = cli("validate_bugreport", "--input", str(built(traps=(trap,))))
    assert code == 0 and doc["sections"] > 10


def test_utf16_input_is_reported_transcoded(built, cli):
    _, doc, _ = cli("validate_bugreport", "--input", str(built(traps=("utf16",))))
    assert doc["input"]["encoding"] == "utf-16" and doc["input"]["transcoded"] is True


def test_non_bugreport_reports_reason(tmp_path, cli):
    p = tmp_path / "x.txt"
    p.write_text("hello\n")
    code, doc, _ = cli("validate_bugreport", "--input", str(p))
    assert code == 1 and doc["is_bugreport"] is False and "not a bugreport" in doc["reason"]
