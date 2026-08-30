"""Getting data out: to files, to a shape, to a value.

The security-relevant one is `--extract-body`. A HAR's URLs are attacker-
controlled in exactly the way a response body is, and this is the command that
turns a URL into a path on disk. An arbitrary file write driven by an untrusted
document is the worst outcome available in this toolkit, so it gets two guards
and a test for each.
"""

from __future__ import annotations

import json

import pytest


@pytest.fixture
def query(scratch):
    import importlib.util
    import io
    import sys
    from contextlib import redirect_stderr, redirect_stdout
    from pathlib import Path

    scripts = Path(__file__).resolve().parent.parent.parent / "skills" / "har" / "scripts"
    spec = importlib.util.spec_from_file_location("_har_query", scripts / "query_har.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["_har_query"] = module
    spec.loader.exec_module(module)

    def run(fixture: str, *args: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = module.main(["--input", str(scratch / f"{fixture}.har"), *args])
        return code, out.getvalue(), err.getvalue()

    run.module = module  # type: ignore[attr-defined]
    return run


def test_extract_body_traversal_path_stays_inside_output_dir(query, tmp_path):
    """The gate: `extracted_files_outside_output_dir == 0`.

    The hostile fixture asks for `../../etc/passwd`, `a%2f..%2f..%2fCON.txt`,
    and a reserved Windows device name. Every one has to land as a flat file
    inside the directory that was named.
    """
    out_dir = tmp_path / "bodies"
    code, _out, _ = query("hostile", "--extract-body", "--output-dir", str(out_dir))
    assert code == 0

    written = sorted(p for p in out_dir.rglob("*") if p.is_file())
    assert written, "nothing was extracted"
    for path in written:
        assert path.parent == out_dir, f"{path} escaped the output directory"
        assert ".." not in path.name
        assert "/" not in path.name

    escaped = sorted(p for p in tmp_path.rglob("passwd*") if p.parent != out_dir)
    assert escaped == [], f"files landed outside the output directory: {escaped}"


def test_extract_body_warns_that_bodies_are_not_redacted(query, tmp_path):
    """Redaction reaches named fields; a body is unbounded text. Say so, once, per run."""
    code, out, _ = query(
        "hostile", "--extract-body", "--output-dir", str(tmp_path / "b")
    )
    assert code == 0
    assert "as sensitive as the capture" in out


def test_extract_body_counts_entries_with_no_body_separately(query, tmp_path):
    code, out, _ = query("traps", "--extract-body", "--output-dir", str(tmp_path / "b"))
    assert code == 0
    assert "skipped" in out
    assert "none captured" in out, "an absent body is not a failed write"


def test_extract_body_without_output_dir_is_a_usage_error(query):
    code, _, err = query("basic", "--extract-body")
    assert code == 2
    assert "--output-dir" in err


def test_schema_of_paginated_json_reports_shape_not_content(query):
    """Often 100x smaller than the body, and usually the actual question."""
    code, out, _ = query("basic", "--show", "2", "--schema")
    assert code == 0
    shape = json.loads(out)
    assert shape["page"] == "int"
    assert shape["results"][0].endswith("items of")
    assert shape["results"][1] == {"id": "int", "title": "str", "salary": "NoneType"}
    assert "Senior Rust Engineer" not in out, "a schema must not carry the content"


def test_json_path_pulls_one_value_out_of_a_body(query):
    code, out, _ = query("basic", "--show", "2", "--json-path", "results[*].title")
    assert code == 0
    assert "Senior Rust Engineer 1.0" in out
    assert "Senior Rust Engineer 1.1" in out


def test_json_path_that_matches_nothing_says_so(query):
    code, out, _ = query("basic", "--show", "2", "--json-path", "nope.not.here")
    assert code == 0
    assert "<no match>" in out


def test_css_selector_extracts_text(query):
    code, out, _ = query("basic", "--show", "0", "--css", "h1")
    assert code == 0
    assert "Senior Rust Engineer" in out


def test_an_unsupported_css_selector_is_refused_by_name(query):
    """A selector that silently matches nothing is indistinguishable from a changed page."""
    code, out, _ = query("basic", "--show", "0", "--css", "div > p:nth-child(2)")
    assert code == 0
    assert "only `tag`, `.class` and `#id` are supported" in out


def test_extraction_reports_a_body_that_was_never_captured(query):
    """Distinct from "no match" — the difference is an hour of looking in the wrong place."""
    code, out, _ = query("traps", "--show", "1", "--schema")
    assert code == 0
    assert "NO BODY CAPTURED" in out


def test_extraction_reports_a_body_it_cannot_decode(query):
    code, out, _ = query("encodings", "--show", "10", "--schema")
    assert code == 0
    assert "could not decode" in out or "cannot extract" in out
