"""The delimiter scanner: offsets, occurrence ids, timed-out sections."""

from __future__ import annotations

import _brlib as br


def _ids(path):
    return [s["id"] for s in br.scan(path.read_bytes())]


def test_bare_cr_does_not_shift_section_offsets(built):
    plain = br.scan(built("modern", seed=3).read_bytes())
    cr = br.scan(built("modern", seed=3, traps=("cr",)).read_bytes())
    assert b"\r" in built("modern", seed=3, traps=("cr",)).read_bytes()
    assert [(s["id"], s["start"], s["end"]) for s in plain] == [
        (s["id"], s["start"], s["end"]) for s in cr
    ]


def test_service_in_two_blocks_gets_two_occurrence_ids(built):
    ids = _ids(built("modern", traps=("dup-service",)))
    assert [i for i in ids if i.startswith("meminfo#")] == ["meminfo#1", "meminfo#2"]
    rows = br.scan(built("modern", traps=("dup-service",)).read_bytes())
    blocks = [s["block"] for s in rows if s["name"] == "meminfo"]
    assert blocks == ["HIGH", None]


def test_timed_out_section_is_flagged(built):
    rows = br.scan(built("modern", traps=("timeout",)).read_bytes())
    assert [s["name"] for s in rows if s["timed_out"]] == ["EXAMPLE HAL DUMP"]


def test_every_layout_finds_its_oem_sections(fx, built):
    for layout, names in fx._OEM_SECTIONS.items():
        found = {s["name"] for s in br.scan(built(layout).read_bytes())}
        assert set(names) <= found, (layout, set(names) - found)


def test_samsung_normal_block_is_a_dumpsys_parent(built):
    rows = br.scan(built("samsung").read_bytes())
    assert "DUMPSYS NORMAL" in {s["name"] for s in rows}
    assert any(s["kind"] == "service" and s["name"] == "battery" for s in rows)
