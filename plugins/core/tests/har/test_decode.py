"""The encoding matrix: the right bytes, or a plain refusal — never mojibake.

Encoding is where this tool most plausibly fails quietly, so every case in spec
§ 8 gets an assertion rather than incidental coverage. The shared claim of all
of them: `decode_body` either returns the correct text or returns `ok=False`
with a reason. A silently mangled string is a wrong answer that looks like a
right one, which is worse than no answer at all.
"""

from __future__ import annotations

import base64
import json

import pytest


def _entries(harlib, path):
    data = path.read_bytes()
    return data, harlib.scan_entries(data)


def _by_name(harlib, path):
    data, spans = _entries(harlib, path)
    out = {}
    for span in spans:
        entry = harlib.read_entry(data, span)
        name = entry["request"]["url"].rsplit("/", 1)[-1]
        headers = {h["name"].lower(): h["value"] for h in entry["response"]["headers"]}
        out[name] = (entry["response"]["content"], headers.get("content-encoding"))
    return out


DECODABLE = {
    "identity-utf8": "Développeur Sénior",
    "base64-utf8": "Développeur Sénior",
    "base64-gzip": "Développeur Sénior",
    "base64-deflate": "Développeur Sénior",
    "base64-raw-deflate": "Développeur Sénior",
    "latin1-declared": "Développeur",
    "sjis-declared": "東京",
    "bom-json": "Développeur Sénior",
    "wrongly-declared": "Développeur Sénior",
    "literal-multibyte": "Ingénieur",
}

# Cases that CANNOT be decoded correctly. The requirement is not that the tool
# succeeds — it is that it refuses, with a reason, instead of inventing text.
UNDECODABLE = {
    "latin1-undeclared": "undecodable",
    "sjis-undeclared": "undecodable",
    "invalid-bytes": "undecodable",
    "lone-surrogate": "surrogate",
    "base64-brotli": "br",
}


@pytest.mark.parametrize("name,expected", sorted(DECODABLE.items()))
def test_decode_body_returns_the_right_text(harlib, fixtures_dir, name, expected):
    content, encoding = _by_name(harlib, fixtures_dir / "encodings.har")[name]
    decoded = harlib.decode_body(content, content_encoding=encoding)
    assert decoded.ok, f"{name}: {decoded.reason}"
    assert expected in (decoded.text or ""), f"{name}: got {decoded.text!r}"


@pytest.mark.parametrize("name,reason_fragment", sorted(UNDECODABLE.items()))
def test_decode_body_refuses_rather_than_mangling(harlib, fixtures_dir, name, reason_fragment):
    content, encoding = _by_name(harlib, fixtures_dir / "encodings.har")[name]
    decoded = harlib.decode_body(content, content_encoding=encoding)
    assert not decoded.ok, f"{name}: claimed success with {decoded.text!r}"
    assert decoded.text is None
    assert reason_fragment in (decoded.reason or ""), f"{name}: reason was {decoded.reason!r}"


def test_decode_body_wrongly_declared_charset_reports_the_override(harlib, fixtures_dir):
    """Taking a wrong `charset=` on faith yields "Dﾃｩveloppeur" — mojibake that reads as success."""
    content, encoding = _by_name(harlib, fixtures_dir / "encodings.har")["wrongly-declared"]
    decoded = harlib.decode_body(content, content_encoding=encoding)
    assert decoded.charset_source == "utf-8-over-declared"
    assert "shift_jis" in (decoded.reason or ""), "the override has to be reported, not silent"


def test_decode_body_bom_wins_over_everything(harlib, fixtures_dir):
    content, encoding = _by_name(harlib, fixtures_dir / "encodings.har")["bom-json"]
    decoded = harlib.decode_body(content, content_encoding=encoding)
    assert decoded.charset_source == "bom"
    assert json.loads(decoded.text)["title"] == "Développeur Sénior"


def test_absent_body_is_not_a_failed_decode(harlib, fixtures_dir):
    """"No body was captured" and "no match" are different answers.

    Conflating them sends a session hunting for an endpoint it already found.
    """
    entries = _by_name(harlib, fixtures_dir / "traps.har")
    content, _ = entries["no-body"]
    decoded = harlib.decode_body(content)
    assert decoded.present is False
    assert decoded.ok is False
    assert "no body captured" in decoded.reason


def test_base64_body_is_decoded_before_it_is_searched(harlib, fixtures_dir):
    """A naive grep of the raw file silently misses every hit inside a base64 body."""
    entries = _by_name(harlib, fixtures_dir / "traps.har")
    content, _ = entries["secret-listing"]
    raw = (fixtures_dir / "traps.har").read_text(encoding="utf-8", errors="replace")
    assert "Principal Ocaml Developer" not in raw, "fixture no longer exercises the trap"
    decoded = harlib.decode_body(content)
    assert decoded.ok and "Principal Ocaml Developer" in decoded.text


def test_a_body_that_fails_its_declared_codec_does_not_raise(harlib):
    """One mislabelled body must never end a walk over every entry.

    `_decompress` used to catch `(OSError, zlib.error, ValueError)`.
    `brotli.error` is none of the three — it subclasses `Exception` directly —
    so a body labelled `br` that did not decode raised out of `matches_body`
    and out of the command, and the other four hundred entries went unreported.
    The exit read as a broken tool rather than as one bad response.
    """
    source = b"\x00\x01\x02 not brotli \xff"
    raw, applied, problem = harlib._decompress(source, "br")
    assert raw == source, "the undecoded bytes must come back for the caller to report"
    assert applied == "br"
    assert problem, "bytes that are neither brotli nor text must be reported, not raised"

    # Asserted on the tuple as well as through the call: `brotli` is optional
    # and absent from the stdlib-only install these scripts are written for, so
    # on this interpreter the call above never reaches the handler. Without this
    # line the regression would be untested exactly where it was found.
    if harlib.brotli is not None:  # pragma: no cover - depends on the interpreter
        assert harlib.brotli.error in harlib._CODEC_ERRORS


def test_a_body_stored_decoded_under_its_original_encoding_header_still_reads(harlib):
    """The `record_har_content="embed"` shape: decoded bytes, `content-encoding` kept.

    This is what an agent's own capture looks like, so treating the declared
    codec as the last word would make the toolkit unusable on the captures the
    skill tells a session to take.
    """
    body = b'{"title":"Senior Engineer"}'
    decoded = harlib.decode_body(
        {
            "text": base64.b64encode(body).decode(),
            "encoding": "base64",
            "mimeType": "application/json",
        },
        content_encoding="br",
    )
    assert decoded.ok, decoded.reason
    assert "Senior Engineer" in (decoded.text or "")


def test_bytes_that_are_neither_compressed_nor_text_are_still_reported(harlib):
    """The guard above must not swallow a genuinely broken body."""
    decoded = harlib.decode_body(
        {
            "text": base64.b64encode(b"\x1f\x8b\x08 not really gzip \xff\xfe").decode(),
            "encoding": "base64",
            "mimeType": "application/octet-stream",
        },
        content_encoding="gzip",
    )
    assert not decoded.ok
    assert "decompression failed" in (decoded.reason or "")
