"""`create_bugreport.py --redact`: no canary survives, binaries dropped, output still analyzes."""

from __future__ import annotations

import shutil
import zipfile

from make_fixture import CANARIES

FS_TEXT = "FS/data/misc/example/notes.txt"
# SSID and coordinates are keyed on their context, so they appear as a dump prints them
MEMBER = "\n".join(
    [
        *(v for k, v in CANARIES.items() if k not in ("ssid", "coord")),
        f'SSID: "{CANARIES["ssid"]}"',
        f"last location=Location[fused {CANARIES['coord']} hAcc=12.0]",
        "",
    ]
)


def _leaks(data: bytes) -> list[str]:
    text = data.decode("utf-8", "replace")
    return [k for k, v in CANARIES.items() if v in text]


def test_redacted_txt_carries_no_canary(built, cli, tmp_path):
    out = tmp_path / "shared.txt"
    code, doc, _ = cli(
        "create_bugreport", "--redact", "--input", str(built("modern")), "--output", str(out)
    )
    assert code == 0 and doc["redacted"]
    assert _leaks(out.read_bytes()) == []  # pii_in_redacted_copy == 0


def test_redacted_zip_drops_pb_and_proto_members(built, cli, tmp_path):
    src = tmp_path / "in.zip"
    shutil.copy(built("modern", ("crash-loop",), container="zip"), src)
    with zipfile.ZipFile(src, "a") as z:
        z.writestr("proto/x.proto", b"\x08\x01binary")
        z.writestr("FS/data/misc/wmtrace/visible_windows.zip", b"PK\x03\x04")
        z.writestr(FS_TEXT, MEMBER)
    out = tmp_path / "shared.zip"
    code, doc, _ = cli("create_bugreport", "--redact", "--input", str(src), "--output", str(out))
    assert code == 0
    assert {"proto/x.proto", "FS/data/misc/wmtrace/visible_windows.zip"} <= set(doc["dropped"])
    assert doc["dropped_total"] == len(doc["dropped"])
    with zipfile.ZipFile(out) as z:
        names = z.namelist()
        assert FS_TEXT in names and "proto/x.proto" not in names
        assert not any(n.endswith(".pb") for n in names)
        assert {n: _leaks(z.read(n)) for n in names if _leaks(z.read(n))} == {}


def test_output_equal_to_input_is_refused(built, cli, tmp_path):
    src = tmp_path / "r.txt"
    shutil.copy(built("modern"), src)
    code, _, err = cli("create_bugreport", "--redact", "--input", str(src), "--output", str(src))
    assert code == 2 and "is the input" in err


def test_existing_output_needs_force(built, cli, tmp_path):
    out = tmp_path / "shared.txt"
    out.write_text("keep")
    args = ("create_bugreport", "--redact", "--input", str(built("modern")), "--output", str(out))
    assert cli(*args)[0] == 2 and out.read_text() == "keep"
    assert cli(*args, "--force")[0] == 0


def test_redacted_copy_still_indexes_and_analyzes(built, cli, tmp_path):
    src = built("modern", ("thrashing",), container="zip")
    out = tmp_path / "shared.zip"
    assert cli("create_bugreport", "--redact", "--input", str(src), "--output", str(out))[0] == 0

    def ids(path):
        code, doc, _ = cli("analyze_bugreport", "--input", str(path), "--json")
        assert code == 0
        return sorted(f["id"] for f in doc["findings"])

    assert ids(out) == ids(src)
