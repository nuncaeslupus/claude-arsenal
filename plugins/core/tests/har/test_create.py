"""A derived capture must be safe to commit, and honest when it is not.

SC5 counts secrets in the *bounded* fields, which is exactly why the body rules
need gates of their own: a file with every header redacted and a session token
sitting in a response body satisfies SC5 and is not safe to hand anyone.
"""

from __future__ import annotations

import json

import pytest


@pytest.fixture
def derive(scratch):
    import importlib.util
    import io
    import sys
    from contextlib import redirect_stderr, redirect_stdout
    from pathlib import Path

    scripts = Path(__file__).resolve().parent.parent.parent / "skills" / "har" / "scripts"
    spec = importlib.util.spec_from_file_location("_har_create", scripts / "create_har.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["_har_create"] = module
    spec.loader.exec_module(module)

    def run(fixture: str, *args: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = module.main(["--input", str(scratch / f"{fixture}.har"), *args])
        return code, out.getvalue(), err.getvalue()

    return run


def test_no_secrets_survive_in_the_bounded_fields(derive, scratch, tmp_path):
    """SC5: `secrets_in_bounded_fields_of_output == 0`."""
    target = tmp_path / "derived.har"
    code, _, err = derive("hostile", "--output", str(target))
    assert code == 0, err

    text = target.read_text()
    for secret in ("live-aaaa", "live-bbbb", "live-cccc", "live-dddd", "hunter2"):
        assert secret not in text, f"{secret} survived into a file meant to be committable"
    assert "#access_token" not in text, "a fragment carrying a token survived"


def test_derived_har_drops_bodies_by_default(derive, tmp_path):
    """Redaction covers named fields; a body is unbounded text.

    A derived HAR that kept bodies by default would hand back a file that looks
    sanitised and is not — which is worse than one that obviously is not.
    """
    target = tmp_path / "derived.har"
    code, out, _ = derive("basic", "--output", str(target))
    assert code == 0
    assert "bodies dropped" in out

    doc = json.loads(target.read_text())
    for entry in doc["log"]["entries"]:
        assert "text" not in entry["response"]["content"], "a response body survived"
        assert "text" not in (entry["request"].get("postData") or {})
    assert "Senior Rust Engineer" not in target.read_text()


def test_keep_bodies_declares_the_result_sensitive(derive, tmp_path):
    """Opting back in has to say what was opted into, in the command's own output."""
    target = tmp_path / "fixture.har"
    code, out, _ = derive("basic", "--keep-bodies", "--output", str(target))
    assert code == 0
    assert "bodies KEPT" in out
    assert "as sensitive as the capture" in out
    assert "Senior Rust Engineer" in target.read_text()


def test_the_derived_file_is_a_valid_har(derive, validate_mod, tmp_path):
    target = tmp_path / "derived.har"
    code, _, _ = derive("basic", "--type", "xhr", "--output", str(target))
    assert code == 0
    errors, _, report = validate_mod.validate(target)
    assert errors == [], errors
    assert report["entries"] == 5


def test_header_analysis_still_works_on_a_derived_file(derive, tmp_path):
    """The reason redaction is a fingerprint everywhere and not a literal marker.

    A bare `<redacted>` would make every Authorization in the derived file
    compare equal, so `--headers` on it would report every header constant — a
    file that looks analysable and is not.
    """
    import importlib.util
    import io
    import sys
    from contextlib import redirect_stdout
    from pathlib import Path

    target = tmp_path / "derived.har"
    code, _, _ = derive("basic", "--type", "xhr", "--output", str(target))
    assert code == 0

    # Loaded here rather than borrowed from `sys.modules`: relying on another
    # test file having run first makes this pass in the full suite and fail on
    # its own, which is the kind of green nobody should trust.
    scripts = Path(__file__).resolve().parent.parent.parent / "skills" / "har" / "scripts"
    key = "_har_analyze_cli"
    if key in sys.modules:
        analyze = sys.modules[key]
    else:
        spec = importlib.util.spec_from_file_location(key, scripts / "analyze_har.py")
        analyze = importlib.util.module_from_spec(spec)
        sys.modules[key] = analyze
        spec.loader.exec_module(analyze)

    out = io.StringIO()
    with redirect_stdout(out):
        assert analyze.main(["--input", str(target), "--headers"]) == 0
    assert "constant  authorization: <redacted:" in out.getvalue()
    assert "candidate auth" in out.getvalue()


def test_output_equal_to_input_is_refused_before_open(derive, scratch):
    """A direct writer would truncate the source while still reading it."""
    code, _, err = derive("basic", "--output", str(scratch / "basic.har"))
    assert code == 2
    assert "Refusing" in err
    assert json.loads((scratch / "basic.har").read_text())["log"]["entries"], (
        "the input capture was damaged by a refused run"
    )


def test_drop_types_removes_the_bulk(derive, tmp_path):
    target = tmp_path / "small.har"
    code, _out, _ = derive("basic", "--drop-types", "--output", str(target))
    assert code == 0
    doc = json.loads(target.read_text())
    assert all(e.get("_resourceType") != "image" for e in doc["log"]["entries"])


def test_selection_narrows_what_is_written(derive, tmp_path):
    target = tmp_path / "only404.har"
    code, _, _ = derive("basic", "--status", "404", "--output", str(target))
    assert code == 0
    doc = json.loads(target.read_text())
    assert len(doc["log"]["entries"]) == 1
    assert doc["log"]["entries"][0]["response"]["status"] == 404


def test_an_interrupted_write_leaves_no_partial_file(derive, tmp_path, monkeypatch):
    """Same-directory temp plus atomic rename: the old file or the new one, never half."""
    import sys

    target = tmp_path / "derived.har"
    derive("basic", "--output", str(target))
    good = target.read_text()

    module = sys.modules["_har_create"]
    monkeypatch.setattr(module.json, "dump", lambda *a, **k: (_ for _ in ()).throw(OSError("disk")))
    with pytest.raises(OSError):
        derive("basic", "--output", str(target))

    assert target.read_text() == good
    assert list(tmp_path.glob(".har-derive-*.tmp")) == [], "a temporary file was left behind"


def test_two_different_credentials_do_not_redact_to_the_same_marker(derive, tmp_path):
    """The bug a single-credential fixture cannot catch.

    Deriving the marker from the salt alone — `<redacted:{salt[:8]}>` — is the
    literal-marker failure wearing a fingerprint's clothes: it looks like a
    fingerprint and makes every value compare equal, so `--headers` on the
    derived file reports every header constant. With one distinct credential in
    the fixture, every test still passes.
    """
    import json as _json

    target = tmp_path / "derived.har"
    code, _, err = derive("hostile", "--output", str(target))
    assert code == 0, err

    doc = _json.loads(target.read_text())
    markers = [
        header["value"]
        for entry in doc["log"]["entries"]
        for header in entry["request"]["headers"]
        if header["name"].lower() == "authorization"
    ]
    assert len(markers) >= 3, "the fixture no longer carries several credentials"
    assert all(m.startswith("<redacted:") for m in markers)
    assert len(set(markers)) == len(markers), (
        f"different credentials redacted to the same marker: {markers}"
    )
    assert not any("live-user" in _json.dumps(doc) for _ in [0])


def test_identical_credentials_still_redact_identically(derive, tmp_path):
    """The other half: equal values must stay equal, or header analysis dies."""
    import json as _json

    target = tmp_path / "derived.har"
    code, _, _ = derive("basic", "--type", "xhr", "--output", str(target))
    assert code == 0

    doc = _json.loads(target.read_text())
    markers = {
        header["value"]
        for entry in doc["log"]["entries"]
        for header in entry["request"]["headers"]
        if header["name"].lower() == "authorization"
    }
    assert len(markers) == 1, f"one credential produced several markers: {markers}"


def test_fingerprints_do_not_carry_across_two_derivations(derive, tmp_path):
    """The negative half of the salt contract, which nothing else pins.

    The salt is per RUN and never stored, so the same credential derived twice
    fingerprints differently. That is deliberate: comparability is scoped to one
    artifact, and every consumer of it — `--headers`, `compare_har.py` — works
    inside a single file. A future change that persisted the salt "so the
    markers line up" would make the fingerprints a stable pseudonym for a live
    credential across every artifact that ever carried it, which is the property
    redaction exists to remove. This test goes red on that change.
    """
    import json as _json

    def authorizations(name: str) -> set[str]:
        """Derive the fixture into `name` and return its distinct auth markers."""
        target = tmp_path / name
        code, _, err = derive("basic", "--type", "xhr", "--output", str(target))
        assert code == 0, err
        doc = _json.loads(target.read_text())
        return {
            header["value"]
            for entry in doc["log"]["entries"]
            for header in entry["request"]["headers"]
            if header["name"].lower() == "authorization"
        }

    first, second = authorizations("one.har"), authorizations("two.har")
    assert len(first) == len(second) == 1, "fixture must carry exactly one credential here"
    assert first != second, (
        "the same credential fingerprinted identically across two runs — the salt "
        "is being persisted, making the marker a stable pseudonym for a live value"
    )


def test_a_body_predicate_actually_narrows_the_fixture(derive, scratch, tmp_path):
    """`--response-match` is the natural way to say "keep the entry that carried this".

    The loop used to evaluate only the index phase, so the three body flags were
    accepted, documented in `--help`, and ignored: the fixture came out as the
    whole capture, every other host the page talked to included. The mistake
    announced itself as a large file rather than as an error, which is the one
    way it would not get noticed.
    """
    source = json.loads((scratch / "basic.har").read_text())
    total = len(source["log"]["entries"])
    assert total > 1, "the fixture must have something to narrow away"

    target = tmp_path / "fixture.har"
    code, _, err = derive(
        "basic", "--response-match", "Senior Rust Engineer 2", "--keep-bodies",
        "--output", str(target),
    )
    assert code == 0, err

    kept = json.loads(target.read_text())["log"]["entries"]
    assert 0 < len(kept) < total, f"kept {len(kept)} of {total} — the body phase did not run"
    assert all(
        "Senior Rust Engineer 2" in (e["response"]["content"].get("text") or "") for e in kept
    )


def test_the_derived_capture_may_not_be_written_over_its_source(derive, scratch):
    """A capture records one moment on a live site; re-recording will not reproduce it."""
    source = scratch / "basic.har"
    before = source.read_bytes()
    code, _, err = derive("basic", "--output", str(source))
    assert code == 2, "writing the input capture must be refused"
    assert "--output is the capture" in err
    assert source.read_bytes() == before
