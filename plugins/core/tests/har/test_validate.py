"""`validate_har.py` separates a bad capture from a bad query.

The capability report is the half that earns the script: a search that finds
nothing because the exporter never saved response bodies looks exactly like a
search that finds nothing because the endpoint is elsewhere, and only one of
those is worth another hour.
"""

from __future__ import annotations

import json


def test_validate_reports_absent_bodies_as_capability_not_error(validate_mod, scratch, tmp_path):
    """A capture with no bodies is valid, unusable for content search, and says so."""
    har = scratch / "basic.har"
    doc = json.loads(har.read_text())
    for entry in doc["log"]["entries"]:
        entry["response"]["content"].pop("text", None)
    stripped = tmp_path / "nobodies.har"
    stripped.write_text(json.dumps(doc, ensure_ascii=False))

    errors, warnings, report = validate_mod.validate(stripped)
    assert errors == [], "a capture without bodies is still a valid HAR"
    assert report["response_bodies"] == 0
    assert any("no response bodies captured" in w for w in warnings)
    assert any("Save all as HAR" in w for w in warnings), "the warning must say how to fix it"


def test_validate_accepts_every_fixture(validate_mod, fixtures_dir):
    for name in ("basic", "traps", "encodings", "hostile", "compare_a", "compare_b"):
        errors, _, report = validate_mod.validate(fixtures_dir / f"{name}.har")
        assert errors == [], f"{name}: {errors}"
        assert report["entries"] > 0


def test_validate_rejects_a_file_that_is_not_a_har(validate_mod, tmp_path):
    bad = tmp_path / "notahar.json"
    bad.write_text('{"hello": "world"}')
    errors, _, _ = validate_mod.validate(bad)
    assert errors and "not a HAR" in errors[0]


def test_validate_reports_missing_required_fields_per_entry(validate_mod, tmp_path):
    bad = tmp_path / "broken.har"
    bad.write_text(json.dumps({"log": {"version": "1.2", "entries": [{"request": {}}]}}))
    errors, _, _ = validate_mod.validate(bad)
    assert any("no `response` object" in e for e in errors)
    assert any("request has no `method`" in e for e in errors)


def test_validate_distinguishes_binary_bodies_from_undecodable_ones(validate_mod, fixtures_dir):
    """Reporting a PNG as an undecodable body trains a reader to ignore the count."""
    _, _, report = validate_mod.validate(fixtures_dir / "basic.har")
    assert report["binary_bodies"] == 1, "the PNG entry is binary, not broken"
    assert report["undecodable_bodies"] == 0

    _, warnings, enc = validate_mod.validate(fixtures_dir / "encodings.har")
    assert enc["undecodable_bodies"] == 5, "the five genuinely unreadable bodies must be counted"
    assert any("could not be decoded" in w for w in warnings)


def test_validate_reports_the_three_cache_states_separately(validate_mod, fixtures_dir):
    _, _, report = validate_mod.validate(fixtures_dir / "traps.har")
    assert report["from_cache"]["unknown"] == 1, "the entry with no _fromCache is its own state"


def test_validate_flags_a_capture_whose_offsets_cannot_be_trusted(validate_mod, tmp_path):
    """The offsets every body-touching command depends on are checked here, once."""
    truncated = tmp_path / "cut.har"
    truncated.write_text('{"log": {"version": "1.2", "entries": [{"request": ')
    errors, _, _ = validate_mod.validate(truncated)
    assert errors, "a truncated capture must not validate"


def test_a_null_response_is_a_finding_not_a_traceback(validate_mod, tmp_path):
    """`"response": null` is what a proxy writes when the response never arrived.

    `get("response", {})` supplies its default only when the key is *absent*, so
    the chained `.get` raised `AttributeError` on exactly the capture this
    script exists to be pointed at. A traceback reads as "the validator is
    broken" rather than as "the capture is", which is the one failure mode it
    does not get to have.
    """
    bad = tmp_path / "nullresponse.har"
    bad.write_text(
        json.dumps(
            {
                "log": {
                    "version": "1.2",
                    "creator": {"name": "proxy", "version": "1"},
                    "entries": [
                        {"request": {"method": "GET", "url": "https://x.invalid/"},
                         "response": None},
                        "not even an object",
                        {"request": {"method": "GET", "url": "https://x.invalid/b"},
                         "response": {"status": 200, "content": {"text": "hi"}}},
                    ],
                }
            }
        )
    )

    errors, _, report = validate_mod.validate(bad)
    # Two, not three: the capability report counts the entries it could read,
    # and the bare string is reported as an error rather than counted as one.
    assert report["entries"] == 2
    assert any("response" in e for e in errors), "the null response must be reported"
    assert any("not an object" in e for e in errors), "the bare string must be reported"
