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
    import sys

    target = tmp_path / "derived.har"
    code, _, _ = derive("basic", "--type", "xhr", "--output", str(target))
    assert code == 0

    analyze = sys.modules["_har_analyze_cli"]
    import io
    from contextlib import redirect_stdout

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
