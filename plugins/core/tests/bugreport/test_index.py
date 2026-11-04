"""The index cache: no section text, override root, staleness, interruption, pruning."""

from __future__ import annotations

import json
import os
import zipfile

import _brlib as br
import pytest


def test_index_holds_no_section_text(fx, built, tmp_path):
    rpt = br.open_report(built("modern", container="zip"), output_dir=tmp_path)
    text = (rpt.keydir / "index.json").read_text()
    for value in fx.CANARIES.values():
        assert value not in text


def test_output_dir_overrides_cache_root(built, tmp_path, monkeypatch):
    home = tmp_path / "home"
    monkeypatch.setenv("XDG_CACHE_HOME", str(home))
    monkeypatch.setenv("HOME", str(home))
    br.open_report(built("modern"), output_dir=tmp_path / "mine")
    assert not home.exists()
    assert any((tmp_path / "mine").iterdir())


def test_cache_dir_and_index_are_private(built, tmp_path):
    rpt = br.open_report(built("modern"), output_dir=tmp_path)
    assert rpt.keydir.stat().st_mode & 0o777 == 0o700
    assert (rpt.keydir / "index.json").stat().st_mode & 0o777 == 0o600


def test_middle_edit_keeping_size_and_mtime_triggers_rebuild(fx, tmp_path):
    path = fx.build("modern", seed=2, target_mb=9, out_dir=tmp_path)
    rpt = br.open_report(path, output_dir=tmp_path / "c")
    pads = [s for s in rpt.sections if s["name"].startswith("example_pad")]
    a, b = pads[0], pads[1]
    st = path.stat()
    data = path.read_bytes()
    i = a["start"] + br.CHUNK + 200  # inside a's body, past the first MiB
    j = data.index(b"\n", b["start"]) + 1  # just after b's opener line
    assert i > br.CHUNK and j < st.st_size - br.CHUNK
    path.write_bytes(data[:i] + data[i + 10 : j] + b"x" * 10 + data[j:])
    os.utime(path, ns=(st.st_atime_ns, st.st_mtime_ns))
    rpt = br.open_report(path, output_dir=tmp_path / "c")  # same key: the index is reused
    sec = rpt.select(b["id"])
    assert rpt.raw(sec).startswith(b"DUMP OF SERVICE " + b["name"].encode())
    assert rpt.select(b["id"])["start"] == b["start"] - 10


def test_interrupted_build_keeps_previous_index(built, tmp_path, monkeypatch):
    path = built("modern")
    rpt = br.open_report(path, output_dir=tmp_path)
    before = (rpt.keydir / "index.json").read_bytes()

    def boom(*_a, **_k):
        raise KeyboardInterrupt

    monkeypatch.setattr(br.json, "dumps", boom)
    with pytest.raises(KeyboardInterrupt):
        br.open_report(path, output_dir=tmp_path, force=True)
    assert (rpt.keydir / "index.json").read_bytes() == before
    assert not [p for p in rpt.keydir.iterdir() if p.name.startswith(".tmp-")]


def test_prune_keeps_five_most_recent_keys(fx, tmp_path):
    root = tmp_path / "c"
    for seed in range(7):
        br.open_report(fx.build("modern", seed=seed, out_dir=tmp_path), output_dir=root)
    assert len([d for d in root.iterdir() if br._is_ours(d)]) == br.KEEP_KEYS


def test_prune_leaves_foreign_dirs_alone(built, tmp_path):
    root = tmp_path / "c"
    root.mkdir()
    foreign = root / "0123456789abcdef"
    foreign.mkdir()
    (foreign / "index.json").write_text(json.dumps({"schema": "someone.else/1"}))
    (root / "notes").mkdir()
    br.open_report(built("modern"), output_dir=root)
    assert foreign.exists() and (root / "notes").exists()


def test_zip_past_the_extract_ceiling_is_refused(built, tmp_path, monkeypatch):
    monkeypatch.setattr(br, "EXTRACT_CEILING", 1024)
    with pytest.raises(br.ReportError, match="refused"):
        br.open_report(built("modern", container="zip"), output_dir=tmp_path)


def test_missing_reading_target_rebuilds(built, tmp_path):
    rpt = br.open_report(built("modern", container="zip"), output_dir=tmp_path)
    (rpt.keydir / "main.txt").unlink()
    rpt = br.open_report(built("modern", container="zip"), output_dir=tmp_path)
    assert rpt.find("battery")


def test_zip_input_reads_fs_listing(built, tmp_path):
    path = built("modern", container="zip")
    rpt = br.open_report(path, output_dir=tmp_path)
    with zipfile.ZipFile(path) as zf:
        fs = [n for n in zf.namelist() if n.startswith("FS/")]
    assert sorted(f["path"] for f in rpt.index["fs"]) == sorted(fs)
