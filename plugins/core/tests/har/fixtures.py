#!/usr/bin/env python3
"""Build the HAR fixtures the toolkit's tests run against.

Hand-built, never captured: a real capture carries a real session, and every
fixture here exists to make one specific claim in
`docs/design/0002-har-analysis-toolkit.md` falsifiable. A generator rather than
committed files because half of what is being tested is byte-level — base64
payloads, gzip frames, a lone surrogate, a multi-byte character positioned
before a later entry — and none of that is reviewable as committed JSON.

    python3 fixtures.py --output-dir DIR    # writes every fixture

Deterministic: same bytes every run, so an offset asserted in a test means the
same thing tomorrow.
"""

from __future__ import annotations

import argparse
import base64
import gzip
import json
import zlib
from pathlib import Path
from typing import Any

CREATOR = {"name": "arsenal-fixture", "version": "1.0"}


def _entry(
    *,
    url: str,
    method: str = "GET",
    status: int = 200,
    mime: str = "application/json",
    text: str | None = None,
    encoding: str | None = None,
    req_headers: list[tuple[str, str]] | None = None,
    resp_headers: list[tuple[str, str]] | None = None,
    resource_type: str | None = "xhr",
    from_cache: bool | None = False,
    started: str = "2026-08-30T12:00:00.000Z",
    time_ms: float = 120.0,
    page: str | None = "page_1",
    post: dict[str, Any] | None = None,
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """One HAR entry, with only the fields a fixture needs spelled out."""
    from urllib.parse import parse_qsl, urlsplit

    parts = urlsplit(url)
    content: dict[str, Any] = {"size": len(text or ""), "mimeType": mime}
    if text is not None:
        content["text"] = text
    if encoding:
        content["encoding"] = encoding
    entry: dict[str, Any] = {
        "startedDateTime": started,
        "time": time_ms,
        "request": {
            "method": method,
            "url": url,
            "httpVersion": "HTTP/1.1",
            "headers": [{"name": n, "value": v} for n, v in (req_headers or [])],
            "queryString": [
                {"name": n, "value": v} for n, v in parse_qsl(parts.query, keep_blank_values=True)
            ],
            "cookies": [],
            "headersSize": -1,
            "bodySize": len(json.dumps(post)) if post else 0,
        },
        "response": {
            "status": status,
            "statusText": {200: "OK", 404: "Not Found", 302: "Found", 500: "Server Error"}.get(
                status, ""
            ),
            "httpVersion": "HTTP/1.1",
            "headers": [{"name": n, "value": v} for n, v in (resp_headers or [])],
            "cookies": [],
            "content": content,
            "redirectURL": "",
            "headersSize": -1,
            "bodySize": content["size"],
        },
        "cache": {},
        "timings": {"send": 1.0, "wait": 100.0, "receive": 19.0},
    }
    if page is not None:
        entry["pageref"] = page
    if post is not None:
        entry["request"]["postData"] = post
    if resource_type is not None:
        entry["_resourceType"] = resource_type
    if from_cache is not None:
        entry["_fromCache"] = from_cache
    if extra:
        entry.update(extra)
    return entry


def _log(entries: list[dict[str, Any]], pages: bool = True) -> dict[str, Any]:
    log: dict[str, Any] = {"version": "1.2", "creator": CREATOR, "entries": entries}
    if pages:
        log["pages"] = [
            {
                "id": "page_1",
                "title": "https://jobs.example.com/search",
                "startedDateTime": "2026-08-30T12:00:00.000Z",
                "pageTimings": {"onContentLoad": 400, "onLoad": 900},
            }
        ]
    return {"log": log}


def basic() -> dict[str, Any]:
    """A Chrome-shaped capture: a document, a redirect chain, a paginated JSON API."""
    json_hdrs = [("content-type", "application/json; charset=utf-8")]
    auth = [
        ("accept", "application/json"),
        ("authorization", "Bearer live-token-aaaa"),
        ("user-agent", "Mozilla/5.0"),
    ]
    entries = [
        _entry(
            url="https://jobs.example.com/search",
            mime="text/html",
            resource_type="document",
            text="<html><body><h1>Senior Rust Engineer</h1></body></html>",
            resp_headers=[("content-type", "text/html; charset=utf-8")],
            time_ms=310.0,
        ),
        _entry(
            url="https://jobs.example.com/old-api/jobs",
            status=302,
            mime="text/plain",
            text="",
            resp_headers=[("location", "https://api.example.com/api/jobs?page=1&loc=NY")],
            time_ms=40.0,
        ),
    ]
    for page in (1, 2, 3):
        payload = {
            "page": page,
            "total": 3,
            "results": [
                {"id": page * 10 + i, "title": f"Senior Rust Engineer {page}.{i}", "salary": None}
                for i in range(2)
            ],
        }
        entries.append(
            _entry(
                url=f"https://api.example.com/api/jobs?page={page}&loc=NY",
                text=json.dumps(payload),
                req_headers=auth,
                resp_headers=json_hdrs,
                time_ms=90.0 + page * 15,
            )
        )
    entries.append(
        _entry(
            url="https://api.example.com/api/jobs?page=4&loc=NY",
            status=404,
            text=json.dumps({"error": "no such page"}),
            req_headers=auth,
            resp_headers=json_hdrs,
            time_ms=35.0,
        )
    )
    entries.append(
        _entry(
            url="https://cdn.example.com/logo.png",
            mime="image/png",
            resource_type="image",
            text=base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"\x00" * 512).decode(),
            encoding="base64",
            resp_headers=[("content-type", "image/png")],
            from_cache=True,
            time_ms=12.0,
        )
    )
    return _log(entries)


def traps() -> dict[str, Any]:
    """Every structural trap § 3.4 and § 5.1 name, in one file."""
    entries = [
        # A base64 body a naive grep would miss entirely.
        _entry(
            url="https://api.example.com/api/secret-listing",
            text=base64.b64encode(
                json.dumps({"hidden": "Principal Ocaml Developer"}).encode()
            ).decode(),
            encoding="base64",
            resp_headers=[("content-type", "application/json")],
        ),
        # A captured request whose body the exporter did not save. Not a miss.
        _entry(
            url="https://api.example.com/api/no-body",
            text=None,
            resp_headers=[("content-type", "application/json")],
        ),
        # `_fromCache` absent entirely: the third state.
        _entry(
            url="https://api.example.com/api/unknown-cache",
            text=json.dumps({"ok": True}),
            from_cache=None,
            resp_headers=[("content-type", "application/json")],
        ),
        # Repeated query names and repeated Set-Cookie: the pairs-not-objects case.
        _entry(
            url="https://api.example.com/api/jobs?tag=a&tag=b&loc=NY",
            text=json.dumps({"tags": ["a", "b"]}),
            resp_headers=[
                ("content-type", "application/json"),
                ("set-cookie", "sid=abc; HttpOnly"),
                ("set-cookie", "csrf=def; Secure"),
            ],
        ),
        # A GraphQL-shaped POST body.
        _entry(
            url="https://api.example.com/graphql",
            method="POST",
            post={
                "mimeType": "application/json",
                "text": json.dumps({"query": "{ jobs(first: 20) { title } }"}),
            },
            text=json.dumps({"data": {"jobs": [{"title": "Staff Engineer"}]}}),
            resp_headers=[("content-type", "application/json")],
        ),
        # A websocket carrying the data the page renders.
        _entry(
            url="wss://live.example.com/stream",
            mime="",
            text=None,
            resource_type="websocket",
            status=101,
            extra={
                "_webSocketMessages": [
                    {"type": "send", "time": 1.0, "opcode": 1, "data": '{"sub":"jobs"}'},
                    {"type": "receive", "time": 1.2, "opcode": 1, "data": '{"job":"Rustacean"}'},
                    {"type": "receive", "time": 1.4, "opcode": 1, "data": '{"job":"Gopher"}'},
                ]
            },
        ),
        # Braces and escaped quotes inside a body — the scanner's actual problem.
        _entry(
            url="https://api.example.com/api/nested",
            text='{"note": "a } inside a string, and a \\" escaped quote, and [ ] brackets"}',
            resp_headers=[("content-type", "application/json")],
        ),
    ]
    return _log(entries)


def encodings() -> dict[str, Any]:
    """The 14-case matrix of spec § 8 — where this tool most plausibly fails quietly."""
    body = {"title": "Développeur Sénior", "city": "東京"}
    utf8 = json.dumps(body, ensure_ascii=False).encode("utf-8")
    latin1 = json.dumps({"title": "Développeur"}, ensure_ascii=False).encode("latin-1")
    sjis = json.dumps({"city": "東京"}, ensure_ascii=False).encode("shift_jis")

    def b64(raw: bytes) -> str:
        return base64.b64encode(raw).decode()

    raw_deflate = zlib.compressobj(-1, zlib.DEFLATED, -zlib.MAX_WBITS)
    raw_deflate_bytes = raw_deflate.compress(utf8) + raw_deflate.flush()

    # (name, body text, content.encoding, mimeType, Content-Encoding header)
    cases: list[tuple[str, str, str | None, str, str | None]] = [
        # 1. identity text, no encoding field
        ("identity-utf8", json.dumps(body, ensure_ascii=False), None, "application/json", None),
        # 2. base64 utf-8
        ("base64-utf8", b64(utf8), "base64", "application/json", None),
        # 3. base64 gzip, declared
        ("base64-gzip", b64(gzip.compress(utf8)), "base64", "application/json", "gzip"),
        # 4. base64 zlib-wrapped deflate, UNDECLARED — sniffed from its header
        ("base64-deflate", b64(zlib.compress(utf8)), "base64", "application/json", None),
        # 5. raw deflate (no zlib wrapper) — the other thing "deflate" means
        ("base64-raw-deflate", b64(raw_deflate_bytes), "base64", "application/json", "deflate"),
        # 6. brotli, declared, with a payload that is not valid brotli: whether
        #    the module is installed or not, the only acceptable outcome is an
        #    honest failure naming `br` — never a plausible-looking string.
        ("base64-brotli", b64(b"\x1b\x00\x00not-really-brotli"), "base64",
         "application/json", "br"),
        # 7. latin-1 declared
        ("latin1-declared", b64(latin1), "base64", "application/json; charset=latin-1", None),
        # 8. latin-1 undeclared — undecodable, and must say so
        ("latin1-undeclared", b64(latin1), "base64", "application/json", None),
        # 9. shift_jis declared
        ("sjis-declared", b64(sjis), "base64", "application/json; charset=shift_jis", None),
        # 10. shift_jis undeclared — undecodable, and must say so
        ("sjis-undeclared", b64(sjis), "base64", "application/json", None),
        # 11. declared charset is WRONG: utf-8 bytes labelled shift_jis. Taking
        #     the label on faith yields "Dﾃｩveloppeur" — mojibake that looks like
        #     a successful read.
        ("wrongly-declared", b64(utf8), "base64", "application/json; charset=shift_jis", None),
        # 12. BOM-prefixed JSON
        ("bom-json", b64(b"\xef\xbb\xbf" + utf8), "base64", "application/json", None),
        # 13. invalid byte sequence — must say so, never mangle
        ("invalid-bytes", b64(b'{"t": "\xff\xfe\xfa bad"}'), "base64", "application/json", None),
        # 14. an unpaired surrogate, which survives json.loads and then raises on
        #     every encode downstream unless it is caught where it is read
        # The surrogate has to be IN the body text, not an escape describing one:
        # json.dumps of a lone surrogate yields the ASCII text `\ud800`, which is
        # not the failure being tested. Written literally, it round-trips through
        # the fixture file as an escape and comes back a surrogate.
        ("lone-surrogate", '{"t": "' + "\ud800" + '"}', None, "application/json", None),
    ]
    entries = []
    for name, text, encoding, mime, content_encoding in cases:
        headers = [("content-type", mime)]
        if content_encoding:
            headers.append(("content-encoding", content_encoding))
        entries.append(
            _entry(
                url=f"https://api.example.com/enc/{name}",
                text=text,
                encoding=encoding,
                mime=mime,
                resp_headers=headers,
            )
        )
    # THE case that separates byte offsets from character offsets: a literal
    # multi-byte body positioned BEFORE a later entry. An index built on str
    # positions passes every ASCII fixture and misses this one.
    entries.insert(
        1,
        _entry(
            url="https://api.example.com/enc/literal-multibyte",
            text=json.dumps({"title": "Ingénieur — 東京 — café ☕" * 40}, ensure_ascii=False),
            mime="application/json",
            resp_headers=[("content-type", "application/json; charset=utf-8")],
        ),
    )
    return _log(entries)


def hostile() -> dict[str, Any]:
    """Untrusted input in every field an artifact is built from."""
    entries = [
        _entry(
            url="https://api.example.com/../../etc/passwd?a=1",
            text=json.dumps({"ok": 1}),
            resp_headers=[("content-type", "application/json")],
        ),
        _entry(
            url="https://api.example.com/a%2f..%2f..%2fCON.txt",
            text=json.dumps({"ok": 2}),
            resp_headers=[("content-type", "application/json")],
        ),
        _entry(
            url="https://api.example.com/api/submit",
            method="POST",
            post={"mimeType": "text/plain", "text": "@/etc/passwd"},
            text=json.dumps({"ok": 3}),
            req_headers=[("x-note", "'; rm -rf / #"), ("authorization", "Bearer live-aaaa")],
            resp_headers=[("content-type", "application/json")],
        ),
        _entry(
            url="https://user:hunter2@api.example.com/api/login?access_token=live-bbbb",
            text=json.dumps({"ok": 4}),
            resp_headers=[("content-type", "application/json"), ("set-cookie", "sid=live-cccc")],
        ),
        _entry(
            url="https://api.example.com/callback#access_token=live-dddd",
            text=json.dumps({"ok": 5}),
            resp_headers=[("content-type", "application/json")],
        ),
    ]
    return _log(entries)


def compare_pair() -> tuple[dict[str, Any], dict[str, Any]]:
    """Two captures of the same flow: repeats, a status change, an added parameter."""

    def side(status_third: int, extra_param: bool) -> dict[str, Any]:
        entries = [
            _entry(
                url="https://api.example.com/api/jobs?page=1",
                text=json.dumps({"n": i}),
                resp_headers=[("content-type", "application/json")],
            )
            for i in range(3)
        ]
        entries[2]["response"]["status"] = status_third
        url = "https://api.example.com/api/detail?id=7"
        if extra_param:
            url += "&expand=salary"
        entries.append(
            _entry(url=url, text=json.dumps({"id": 7}), resp_headers=[("x-a", "1")])
        )
        return _log(entries)

    return side(200, False), side(500, True)


FIXTURES = {
    "basic.har": basic,
    "traps.har": traps,
    "encodings.har": encodings,
    "hostile.har": hostile,
}


def _dump(doc: dict[str, Any]) -> bytes:
    """Serialise a fixture, keeping literal multi-byte characters as themselves.

    `ensure_ascii=False` is the point of this function: escaping every non-ASCII
    character would make `encodings.har` pure ASCII and quietly delete the one
    case that separates byte offsets from character offsets.

    `backslashreplace` handles the other end: an unpaired surrogate cannot be
    UTF-8 encoded at all, so it is written as the JSON escape `\\udNNN`, which
    `json.loads` reads back as the surrogate the fixture is testing.
    """
    return json.dumps(doc, ensure_ascii=False, indent=1).encode("utf-8", "backslashreplace")


def write_all(output_dir: Path) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    written = []
    a, b = compare_pair()
    builders: list[tuple[str, dict[str, Any]]] = [
        *((name, build()) for name, build in FIXTURES.items()),
        ("compare_a.har", a),
        ("compare_b.har", b),
    ]
    for name, doc in builders:
        path = output_dir / name
        path.write_bytes(_dump(doc))
        written.append(path)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    for path in write_all(args.output_dir):
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
