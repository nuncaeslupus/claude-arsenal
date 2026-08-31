"""The byte-offset scanner: every span is the entry the parser sees, in bytes.

A wrong span is the worst bug this toolkit can have, because it is silent: the
command returns a body, for the wrong request, with no error anywhere. So the
scanner is checked against the authoritative parse of every fixture rather than
against hand-written offsets.
"""

from __future__ import annotations

import json

import pytest

FIXTURES = ["basic", "traps", "encodings", "hostile", "compare_a", "compare_b"]


@pytest.mark.parametrize("name", FIXTURES)
def test_scan_entries_matches_the_parser_on_every_fixture(harlib, fixtures_dir, name):
    data = (fixtures_dir / f"{name}.har").read_bytes()
    spans = harlib.scan_entries(data)
    truth = json.loads(data)["log"]["entries"]

    assert len(spans) == len(truth), f"{name}: span count differs from the parsed entry count"
    for span, expected in zip(spans, truth, strict=True):
        assert harlib.read_entry(data, span) == expected, f"{name}: entry {span.index} differs"


def test_scan_entries_multibyte_before_entry_returns_correct_span(harlib, fixtures_dir):
    """The one case that separates byte offsets from character offsets.

    `encodings.har` puts a body full of literal `é`, `東京` and `☕` at index 1.
    An index built on `str` positions passes every ASCII fixture and returns the
    wrong entry for everything after this one.
    """
    data = (fixtures_dir / "encodings.har").read_bytes()
    spans = harlib.scan_entries(data)
    text = data.decode("utf-8")

    multibyte_span = spans[1]
    assert "literal-multibyte" in harlib.read_entry(data, multibyte_span)["request"]["url"]
    # The proof: past that entry, the byte offset and the character offset have
    # diverged, and the byte offset is the one that still lands on an entry.
    later = spans[5]
    assert len(text) < len(data), "fixture is pure ASCII — it cannot test this at all"
    assert data[later.offset : later.offset + 1] == b"{"
    assert text[later.offset : later.offset + 1] != "{", (
        "character and byte offsets still agree here; the fixture no longer exercises the bug"
    )
    assert harlib.read_entry(data, later)["request"]["url"].startswith("https://")


def test_scan_entries_ignores_braces_and_quotes_inside_bodies(harlib, fixtures_dir):
    """A `}` inside a response body is not a structural brace, and `\\"` does not end a string."""
    data = (fixtures_dir / "traps.har").read_bytes()
    spans = harlib.scan_entries(data)
    nested = [
        harlib.read_entry(data, s)
        for s in spans
        if "nested" in harlib.read_entry(data, s)["request"]["url"]
    ]
    assert len(nested) == 1
    assert "escaped quote" in nested[0]["response"]["content"]["text"]


def test_scan_entries_rejects_a_truncated_capture(harlib, fixtures_dir):
    data = (fixtures_dir / "basic.har").read_bytes()
    with pytest.raises(harlib.HarStructureError):
        harlib.scan_entries(data[: len(data) // 2])


def test_verify_offsets_reports_zero_problems_on_every_fixture(analyze, scratch):
    """The gate: `offset_reparse_mismatches == 0`."""
    for name in FIXTURES:
        har = scratch / f"{name}.har"
        _, count, problems = analyze.build_index(har, verify=True)
        assert problems == [], f"{name}: {problems}"
        assert count > 0
