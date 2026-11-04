"""The fixture generator: deterministic, reserved-range only, every layout builds."""

from __future__ import annotations

import hashlib
import re
import zipfile

import pytest


def test_same_arguments_build_byte_identical_fixture(fx, tmp_path):
    for container in ("txt", "zip"):
        a = fx.build("samsung", ("multi-day",), seed=7, container=container, out_dir=tmp_path / "a")
        b = fx.build("samsung", ("multi-day",), seed=7, container=container, out_dir=tmp_path / "b")
        assert hashlib.sha256(a.read_bytes()).digest() == hashlib.sha256(b.read_bytes()).digest()


def test_seeds_carry_only_reserved_range_identifiers(fx):
    text = (fx.SEEDS / "sections.tmpl").read_text()
    # the seed holds placeholders, never values: anything identifier-shaped is a leak
    assert not re.search(r"\b\d{14,19}\b", text), "a bare long digit run in seeds/"
    macs = set(re.findall(r"(?:[0-9a-f]{2}:){5}[0-9a-f]{2}", text, re.I))
    assert macs <= {"02:00:00:00:00:00"}, macs  # Android's masked MAC, the redact exemption
    emails = set(re.findall(r"[\w.+-]+@[\w.-]+\.\w+", text))
    assert all(e.endswith(("@example.com", "@build-host")) for e in emails), emails
    c = fx.CANARIES
    assert c["imei"].startswith("001001") and c["iccid"].startswith("899999")
    assert c["imsi"].startswith("310999")
    assert c["phone"].startswith("+1202555")  # NANP fictional 555-01xx
    assert c["mac"].lower().startswith("00:00:5e:00:53")  # RFC 7042 documentation range
    assert c["email"].endswith("@example.com")


@pytest.mark.parametrize("container", ["txt", "zip", "zip-bare", "zip-text"])
@pytest.mark.parametrize(
    "layout", ["pre-p", "modern", "samsung", "xiaomi", "oneplus", "huawei", "android9"]
)
def test_every_layout_and_container_builds(fx, tmp_path, layout, container):
    path = fx.build(layout, container=container, out_dir=tmp_path)
    if container == "txt":
        data = path.read_bytes()
    else:
        with zipfile.ZipFile(path) as zf:
            main = max(
                (
                    i
                    for i in zf.infolist()
                    if "dumpstate" in i.filename or i.filename.startswith("bugreport")
                ),
                key=lambda i: i.file_size,
            )
            data = zf.read(main)
    assert b"== dumpstate: " in data[:4096]
