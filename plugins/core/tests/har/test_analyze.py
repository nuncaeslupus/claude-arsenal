"""The insight modes: what a capture says once it is reduced.

`--endpoints` is the one that earns the script, so it gets the sharpest test.
Collapsing three paginated requests into one row that names the parameter which
varies is the difference between reading forty URLs and reading how to iterate
the site — and the failure mode is not an error, it is a listing that is merely
less useful, which nobody notices.
"""

from __future__ import annotations

import pytest


@pytest.fixture
def analyze_cli(scratch):
    import importlib.util
    import io
    import sys
    from contextlib import redirect_stderr, redirect_stdout
    from pathlib import Path

    scripts = Path(__file__).resolve().parent.parent.parent / "skills" / "har" / "scripts"
    spec = importlib.util.spec_from_file_location("_har_analyze_cli", scripts / "analyze_har.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["_har_analyze_cli"] = module
    spec.loader.exec_module(module)

    def run(fixture: str, *args: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = module.main(["--input", str(scratch / f"{fixture}.har"), *args])
        return code, out.getvalue(), err.getvalue()

    return run


def test_endpoints_collapses_pagination_to_one_template(analyze_cli):
    """The gate: one row for the paginated API, `page` varying and `loc` constant."""
    code, out, _ = analyze_cli("basic", "--endpoints")
    assert code == 0

    rows = [line for line in out.splitlines() if line and not line.startswith("    ")]
    jobs = [line for line in rows if "/api/jobs" in line]
    assert len(jobs) == 1, f"the paginated API should collapse to one row, got {jobs}"
    assert "x4" in jobs[0], "the row must say how many requests it collapsed"

    detail = out.split(jobs[0], 1)[1].splitlines()[1:3]
    body = "\n".join(detail)
    assert "loc = NY  (constant)" in body
    assert "page varies over 4" in body


def test_endpoints_collapses_identifier_segments_but_not_real_words(analyze_cli, harlib):
    """A template that collapses path words invents endpoints that do not exist."""
    import sys

    module = sys.modules["_har_analyze_cli"]
    assert module.path_template("/api/jobs/12345") == "/api/jobs/{id}"
    assert module.path_template("/api/jobs/deadbeefcafe1234") == "/api/jobs/{id}"
    assert module.path_template("/api/jobs/search") == "/api/jobs/search"
    assert module.path_template("/v2/users/me") == "/v2/users/me"


def test_headers_split_constant_from_varying_under_redaction(analyze_cli):
    """The split only survives redaction because redacted values keep a fingerprint.

    With a bare `<redacted>` marker every Authorization value would compare
    equal, and the constant-versus-varying answer would be constant for
    everything — which is the same as no answer.
    """
    code, out, _ = analyze_cli("basic", "--headers")
    assert code == 0
    assert "constant  authorization: <redacted:" in out
    assert "candidate auth" in out, "the whole point is naming the auth candidate"
    assert "live-token-aaaa" not in out


def test_cookies_keep_their_names_and_flags(analyze_cli):
    """Values are redacted; names and attributes say which cookie authenticates."""
    code, out, _ = analyze_cli("traps", "--cookies")
    assert code == 0
    assert "sid [HttpOnly]" in out
    assert "csrf [Secure]" in out
    assert "abc" not in out and "def" not in out, "cookie values must not survive"


def test_errors_lists_non_2xx_with_the_body_that_explains_them(analyze_cli):
    """An API that returns 404 with a reason has told you how to fix the request."""
    code, out, _ = analyze_cli("basic", "--errors")
    assert code == 0
    assert "404 Not Found" in out
    assert "no such page" in out, "the body snippet is the point of this mode"


def test_errors_does_not_call_a_websocket_upgrade_an_error(analyze_cli):
    """A 101 is a handshake succeeding. Listing it teaches a reader to skim."""
    code, out, _ = analyze_cli("traps", "--errors")
    assert code == 0
    assert "101" not in out
    assert "no non-2xx" in out


def test_redirects_falls_back_to_the_location_header(analyze_cli):
    """Exporters leave `redirectURL` empty often enough that the chain needs it."""
    code, out, _ = analyze_cli("basic", "--redirects")
    assert code == 0
    assert "302" in out
    assert "api.example.com/api/jobs?page=1" in out, "the redirect target was not resolved"


def test_websockets_report_frames_a_body_search_would_never_find(analyze_cli):
    """A site streaming over a socket has no HTTP body to search — the capture looks empty."""
    code, out, _ = analyze_cli("traps", "--websockets")
    assert code == 0
    assert "3 frames (1 sent, 2 received)" in out
    assert "Rustacean" in out


def test_stats_rejects_a_field_it_cannot_compute(analyze_cli):
    code, _, err = analyze_cli("basic", "--stats", "banana")
    assert code == 2
    assert "choose status, host, mime, type, method, size or time" in err


def test_stats_buckets_sizes_and_times(analyze_cli):
    for field in ("status", "host", "mime", "type", "method", "size", "time"):
        code, out, err = analyze_cli("basic", "--stats", field)
        assert code == 0, f"--stats {field}: {err}"
        assert out.startswith(f"{field} over 7 entries")


def test_index_only_modes_never_open_the_capture(analyze_cli, scratch, monkeypatch):
    """The overview, the histograms and the endpoint collapse are metadata questions."""
    from pathlib import Path

    analyze_cli("basic", "--index")
    reads: list[str] = []
    real = Path.read_bytes

    def watched(self):
        reads.append(self.name)
        return real(self)

    monkeypatch.setattr(Path, "read_bytes", watched)
    for args in (("--endpoints",), ("--headers",), ("--stats", "host"), ("--largest",)):
        reads.clear()
        code, _, _ = analyze_cli("basic", *args)
        assert code == 0
        assert not any(n.endswith(".har") for n in reads), f"{args} opened the capture: {reads}"


def test_every_mode_stays_within_the_byte_budget(analyze_cli):
    for args in (
        ("--endpoints",), ("--headers",), ("--cookies",), ("--errors",),
        ("--redirects",), ("--slowest",), ("--largest",), ("--websockets",),
        ("--stats", "host"), (),
    ):
        code, out, _ = analyze_cli("encodings", *args)
        assert code == 0
        assert len(out.encode()) <= 4096, f"{args} produced {len(out.encode())} bytes"
