"""Selection and output: what matches, what is shown, and what the budget does.

The output rules are as much a feature as the filters. A command that dumps 400
entries into a session's context has answered the question and cost more than
the answer was worth; one that caps at 20 with no way to see the rest has
decided what may be asked. Both failures are tested here.
"""

from __future__ import annotations

import json

import pytest


@pytest.fixture
def query(scratch):
    """Run `query_har.py` against a fixture and return (exit code, stdout, stderr)."""
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
        argv = ["--input", str(scratch / f"{fixture}.har"), *args]
        with redirect_stdout(out), redirect_stderr(err):
            code = module.main(argv)
        return code, out.getvalue(), err.getvalue()

    run.module = module  # type: ignore[attr-defined]
    return run


def test_response_match_finds_the_request_behind_a_string_on_the_page(query):
    """The operation the whole toolkit exists for."""
    code, out, _ = query("basic", "--response-match", "Senior Rust Engineer 2")
    assert code == 0
    assert out.count("\n") == 1, "the string is in exactly one entry"
    assert "page=2" in out


def test_commands_to_locate_the_endpoint_is_two(query):
    """SC4. First names the entry; second says what it returns."""
    code, out, _ = query("basic", "--response-match", "Senior Rust Engineer 2")
    assert code == 0
    index = int(out.split()[0])

    code, shape, _ = query("basic", "--show", str(index), "--schema")
    assert code == 0
    assert '"results"' in shape and '"title": "str"' in shape


def test_no_cache_excludes_only_false_not_unknown(query):
    """Three-state, not two.

    Folding "the exporter never recorded it" into `false` would make --no-cache
    mean different things on a Chrome capture and a Playwright one, silently —
    the class of bug this toolkit exists to prevent.
    """
    _, unknown, _ = query("traps", "--unknown-cache")
    assert "unknown-cache" in unknown and unknown.count("\n") == 1

    _, false_only, _ = query("traps", "--no-cache")
    assert "unknown-cache" not in false_only

    _, _cached, err = query("traps", "--from-cache")
    assert "no entries matched" in err


def test_every_default_mode_stays_within_the_byte_budget(query):
    """SC1: 4096 bytes, enforced by truncation and not only by --limit."""
    for args in (
        (),
        ("--type", "xhr"),
        ("--json",),
        ("--show", "1"),
        ("--limit", "100"),
    ):
        code, out, _ = query("encodings", *args)
        assert code == 0
        assert len(out.encode()) <= 4096, f"{args} produced {len(out.encode())} bytes"


def test_json_output_under_budget_still_parses(query):
    """Bounded output must remain machine-readable.

    The budget drops whole entries from a fixed envelope, never bytes from the
    middle of a structure — a truncated JSON document is not a smaller answer,
    it is no answer.
    """
    code, out, _ = query("encodings", "--json", "--limit", "100")
    assert code == 0
    payload = json.loads(out)
    assert len(out.encode()) <= 4096
    assert payload["shown"] <= payload["matched"]
    if payload["shown"] < payload["matched"]:
        assert payload["truncated"] is True


def test_limit_zero_removes_both_caps(query):
    """Small by default, complete on request."""
    _, capped, _ = query("encodings", "--limit", "3")
    _, uncapped, _ = query("encodings", "--limit", "0")
    rows = [line for line in capped.splitlines() if line.strip() and not line.startswith("…")]
    assert len(rows) == 3
    assert "more entr" in capped, "a capped result must say what it dropped and why"
    assert len([line for line in uncapped.splitlines() if line.strip()]) == 15


def test_output_path_writes_the_complete_result(query, tmp_path):
    target = tmp_path / "all.txt"
    code, _, err = query("encodings", "--limit", "3", "--output", str(target))
    assert code == 0
    assert target.read_text().count("\n") == 15, "--output is full fidelity, not the capped view"
    assert str(target) in err


def test_a_value_pattern_on_a_redacted_header_requires_secrets(query):
    """The index stores those values redacted, so the answer has to come from the capture."""
    code, _, err = query("basic", "--has-header", "authorization=Bearer")
    assert code == 2
    assert "--secrets" in err

    code, out, _ = query("basic", "--has-header", "authorization=Bearer live", "--secrets")
    assert code == 0 and out.strip()


def test_header_presence_alone_needs_no_capture_read(query, monkeypatch):
    """Presence queries stay on the index — that is what keeps them flat in body bytes."""
    from pathlib import Path

    reads: list[str] = []
    real = Path.read_bytes

    def watched(self):
        reads.append(self.name)
        return real(self)

    # Build the index first: the build reads the capture once, by definition.
    # What must not happen is a *query* reading it afterwards.
    query("basic", "--limit", "1")

    monkeypatch.setattr(Path, "read_bytes", watched)
    code, out, _ = query("basic", "--has-header", "authorization")
    assert code == 0 and out.strip()
    assert not any(name.endswith(".har") for name in reads), f"opened the capture: {reads}"


def test_status_grammar_accepts_codes_classes_and_ranges(query):
    for spec, expect in (("404", 1), ("2xx", 5), ("300-399", 1), ("404,302", 2)):
        code, out, err = query("basic", "--status", spec)
        assert code == 0, f"--status {spec}: {err}"
        assert out.count("\n") == expect, f"--status {spec} matched {out.count(chr(10))}"


def test_a_bad_status_spec_is_a_usage_error_not_an_empty_result(query):
    code, _, err = query("basic", "--status", "banana")
    assert code == 2
    assert "expected 200, 4xx or 400-499" in err


def test_repeated_query_parameters_are_both_findable(query):
    """`?tag=a&tag=b` — collapsing pairs into an object keeps only the last one."""
    for value in ("a", "b"):
        code, out, _ = query("traps", "--param", f"tag={value}")
        assert code == 0, f"tag={value} was not found"
        assert "tag=a&tag=b" in out


def test_no_match_exits_non_zero_and_says_so(query):
    code, out, err = query("basic", "--url", "definitely-not-here")
    assert code == 1
    assert "no entries matched" in err
    assert out == ""
