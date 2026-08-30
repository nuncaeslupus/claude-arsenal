"""The sidecar: what it records, when it is trusted, and what it never leaks.

The index is what makes every later query cheap, so three properties matter more
than its contents: an index-only read never opens the capture (that is the whole
premise), an offset is never trusted on size and mtime alone (they are not a
content identity), and an interrupted build never replaces a good index with a
half-written one.
"""

from __future__ import annotations

import json

import pytest


def _rows(analyze, har):
    """Header plus every row, materialised — the index itself is a stream."""
    header, rows = analyze.ensure_index(har)
    return header, list(rows)


def test_index_records_query_and_headers_as_pairs_not_objects(analyze, scratch):
    """`?tag=a&tag=b` is two values for one name, and `Set-Cookie` repeats.

    Collapsing either into an object keeps the last one silently, which makes a
    filter miss a request that plainly contains the value it asked for — and
    only on the sites that use repetition.
    """
    _, rows = _rows(analyze, scratch / "traps.har")
    row = next(r for r in rows if r["path"] == "/api/jobs")
    assert row["query"] == [["tag", "a"], ["tag", "b"], ["loc", "NY"]]
    cookies = [v for k, v in row["respHeaders"] if k == "set-cookie"]
    assert len(cookies) == 2, "both Set-Cookie headers must survive indexing"


def test_index_keeps_cache_three_state(analyze, scratch):
    """`_fromCache` is true, false, or *the exporter never said* — never folded to false."""
    _, rows = _rows(analyze, scratch / "traps.har")
    states = {r["path"]: r["cache"] for r in rows}
    assert states["/api/unknown-cache"] is None
    assert states["/api/no-body"] is False


def test_index_redacts_sensitive_header_values_but_keeps_them_comparable(analyze, scratch):
    """A bare marker would make two different Authorization values compare equal.

    That destroys the constant-versus-varying split that finds the auth header,
    so redacted values carry a salted fingerprint instead.
    """
    _, rows = _rows(analyze, scratch / "basic.har")
    auth = [v for r in rows for k, v in r["reqHeaders"] if k == "authorization"]
    assert auth, "fixture has no Authorization header to redact"
    assert all(v.startswith("<redacted:") for v in auth)
    assert "live-token-aaaa" not in (scratch / "basic.har.index.jsonl").read_text()
    assert len(set(auth)) == 1, "identical values must stay identical after redaction"


def test_index_strips_userinfo_and_fragment_from_urls(analyze, scratch):
    """An OAuth implicit flow puts a live token in the fragment, where no name rule looks."""
    _, rows = _rows(analyze, scratch / "hostile.har")
    text = (scratch / "hostile.har.index.jsonl").read_text()
    assert "hunter2" not in text
    assert "live-dddd" not in text
    assert "live-cccc" not in text
    assert not any("#" in r["url"] for r in rows)
    assert not any("@" in r["url"].split("?")[0] for r in rows)


def test_index_only_query_never_opens_the_har(analyze, scratch, monkeypatch):
    """SC3's premise: metadata answers are independent of the capture's body bytes."""
    har = scratch / "basic.har"
    analyze.build_index(har)

    opened: list[str] = []
    real_open = type(har).open

    def watched(self, *args, **kwargs):
        opened.append(self.name)
        return real_open(self, *args, **kwargs)

    monkeypatch.setattr(type(har), "open", watched)
    _header, rows = analyze.load_index(har)
    assert len(rows) == 7
    assert har.name not in opened, "an index-only read opened the capture itself"


def test_stale_index_is_rejected_on_size_and_mtime(analyze, scratch):
    har = scratch / "basic.har"
    analyze.build_index(har)
    assert analyze.load_index(har) is not None
    har.write_bytes(har.read_bytes() + b" ")
    assert analyze.load_index(har) is None, "a changed capture must invalidate its index"


def test_offsets_are_not_trusted_on_size_and_mtime_alone(analyze, harlib, scratch):
    """A copy-preserving move carries both across two different files.

    So no byte offset is ever trusted on their word — the digest is checked once
    per run before the first seek, which is the one cost a body-touching command
    was already going to pay.
    """
    har = scratch / "basic.har"
    header, _ = _rows(analyze, har)
    other = (scratch / "traps.har").read_bytes()
    with pytest.raises(harlib.HarStructureError) as excinfo:
        analyze.verify_for_seek(har, header, other)
    assert "changed since its index was built" in str(excinfo.value)
    analyze.verify_for_seek(har, header, har.read_bytes())


def test_interrupted_index_build_leaves_the_previous_sidecar(analyze, scratch, monkeypatch):
    """The failure the atomic rename prevents.

    A truncated JSONL has a perfectly valid header line, so the next run would
    trust it and answer every query from a partial index. A digest over the
    *input* cannot detect damage to the output.
    """
    har = scratch / "basic.har"
    path, _count, _ = analyze.build_index(har)
    good = path.read_text()

    def boom(entry, span, salt):
        raise KeyboardInterrupt("interrupted mid-build")

    monkeypatch.setattr(analyze, "build_row", boom)
    with pytest.raises(KeyboardInterrupt):
        analyze.build_index(har)

    assert path.read_text() == good, "a failed build replaced a good index"
    leftovers = list(har.parent.glob(".har-index-*.tmp"))
    assert leftovers == [], f"temporary index files left behind: {leftovers}"


def test_index_carries_no_bodies(analyze, scratch):
    """The sidecar is a metadata index. A body in it would defeat the whole point."""
    _, rows = _rows(analyze, scratch / "basic.har")
    text = (scratch / "basic.har.index.jsonl").read_text()
    assert "Senior Rust Engineer" not in text
    assert all("text" not in row for row in rows)
    assert any(row["hasRespBody"] for row in rows), "presence must still be recorded"


def test_resource_type_inference_is_reported_as_inferred(analyze, harlib, scratch):
    """A filter that silently guesses is a filter whose result cannot be trusted."""
    har = scratch / "basic.har"
    data = har.read_bytes()
    doc = json.loads(data)
    for entry in doc["log"]["entries"]:
        entry.pop("_resourceType", None)
    har.write_text(json.dumps(doc, ensure_ascii=False))
    _, stream = analyze.ensure_index(har, rebuild=True)
    rows = list(stream)
    assert {r["typeSrc"] for r in rows} == {"inferred"}
    assert any(r["type"] == "document" for r in rows)
    assert any(r["type"] == "image" for r in rows)


def test_open_index_streams_rather_than_materialising(analyze, scratch):
    """SC3's memory bound: the reader must not build a list of every row.

    Materialising 50k rows cost 239 MB and 1.26 s before a single one had been
    looked at — the index doing exactly what it was built to avoid, against a
    smaller file. Streaming brought that to 19.5 MB and 0.28 s.
    """
    import types

    har = scratch / "basic.har"
    analyze.build_index(har)
    header, rows = analyze.open_index(har)
    assert isinstance(rows, types.GeneratorType), "open_index returned a materialised sequence"
    assert header["entries"] == 7
    assert sum(1 for _ in rows) == 7


def test_truncated_index_is_reported_when_the_stream_ends_short(analyze, harlib, scratch):
    """An index that declares more rows than it holds is a truncated index."""
    har = scratch / "basic.har"
    path, _count, _ = analyze.build_index(har)
    lines = path.read_text().splitlines(keepends=True)
    path.write_text("".join(lines[:-2]))
    _, rows = analyze.open_index(har)
    with pytest.raises(harlib.HarStructureError) as excinfo:
        list(rows)
    assert "truncated" in str(excinfo.value)
