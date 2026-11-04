"""Input resolution: zip main entry, UTF-16, the not-a-bugreport rule."""

from __future__ import annotations

import zipfile

import _brlib as br
import pytest


def test_zip_without_main_entry_picks_largest_dumpstate_text(built):
    path = built("modern", container="zip-bare")
    with zipfile.ZipFile(path) as zf:
        assert "main_entry.txt" not in zf.namelist()
        assert br.main_entry(zf).filename == "dumpstate-2026-11-03-14-22-05.txt"


def test_zip_main_entry_txt_is_honoured(built, tmp_path):
    rpt = br.open_report(built("modern", container="zip"), output_dir=tmp_path)
    assert rpt.index["input"]["main_entry"] == "bugreport-example-2026-11-03-14-22-05.txt"


def test_text_only_zip_with_any_name_is_read(built, tmp_path):
    rpt = br.open_report(
        built("modern", container="zip-text", main_name="example.txt"), output_dir=tmp_path
    )
    assert rpt.header["captured_local"] == "2026-11-03 14:22:05"


def test_utf16_input_is_transcoded(built, tmp_path):
    rpt = br.open_report(built("modern", traps=("utf16",)), output_dir=tmp_path)
    assert rpt.index["input"]["transcoded"] is True
    assert rpt.find("battery")


def test_random_text_is_not_a_bugreport(tmp_path):
    p = tmp_path / "notes.txt"
    p.write_text("just some notes\n" * 10)
    with pytest.raises(br.NotABugreport):
        br.open_report(p, output_dir=tmp_path / "cache")


def test_nul_and_invalid_utf8_bytes_do_not_break_the_index(built, tmp_path):
    rpt = br.open_report(built("modern", traps=("nul",)), output_dir=tmp_path)
    assert rpt.index["input"]["nul_bytes"] > 0
    assert rpt.find("SYSTEM LOG")
