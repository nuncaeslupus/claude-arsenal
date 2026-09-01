"""Comparison must never invent a change that did not happen.

A capture routinely repeats the same method and URL, so the failure mode is not
missing a difference — it is pairing two entries that merely resemble each
other and reporting the gap between them as a change.
"""

from __future__ import annotations

import json

import pytest


@pytest.fixture
def compare(scratch):
    import importlib.util
    import io
    import sys
    from contextlib import redirect_stderr, redirect_stdout
    from pathlib import Path

    scripts = Path(__file__).resolve().parent.parent.parent / "skills" / "har" / "scripts"
    spec = importlib.util.spec_from_file_location("_har_compare", scripts / "compare_har.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["_har_compare"] = module
    spec.loader.exec_module(module)

    def run(left: str, right: str, *args: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = module.main(
                [
                    "--input", str(scratch / f"{left}.har"),
                    "--against", str(scratch / f"{right}.har"),
                    *args,
                ]
            )
        return code, out.getvalue(), err.getvalue()

    run.module = module  # type: ignore[attr-defined]
    return run


def test_identical_captures_report_no_differences(compare):
    code, out, _ = compare("compare_a", "compare_a")
    assert code == 0, "identical captures must exit 0"
    assert "no differences" in out


def test_repeated_identical_requests_pair_in_capture_order(compare):
    """Three requests to one URL, one of which changed status.

    The gate: `invented_changes_on_repeat_url_fixture == 0`. A matcher that
    pairs by URL alone reports up to three changes here; one changed, so
    exactly one must be reported.
    """
    code, out, _ = compare("compare_a", "compare_b")
    assert code == 1
    status_changes = [line for line in out.splitlines() if "status" in line and "→" in line]
    assert len(status_changes) == 1, f"expected exactly one status change, got {status_changes}"
    assert "200 → 500" in status_changes[0]


def test_a_positional_match_says_so(compare):
    """A reader has to be able to tell a real match from "both were the third repeat"."""
    code, out, _ = compare("compare_a", "compare_b")
    assert code == 1
    assert "(positional match)" in out


def test_a_changed_parameter_set_is_not_paired(compare):
    """`?id=7` and `?id=7&expand=salary` are different requests.

    Pairing them and calling the gap a change is how a diff tool starts
    inventing history. The pattern is named separately instead.
    """
    code, out, _ = compare("compare_a", "compare_b")
    assert code == 1
    assert "parameters added: expand" in out
    assert "- https://api.example.com/api/detail?id=7" in out
    assert "+ https://api.example.com/api/detail?id=7&expand=salary" in out


def test_pageref_absent_from_identity_key(compare, analyze, scratch):
    """HAR page ids are local to a capture.

    Including one in the key would make the same request in two captures — the
    exact thing a diff is looking for — appear as a removal plus an addition.
    """
    module = compare.module
    _, rows_a = analyze.ensure_index(scratch / "compare_a.har")
    row = next(iter(rows_a))
    other = dict(row)
    other["page"] = "page_99"
    assert module.identity(row) == module.identity(other)


def test_the_authority_is_part_of_identity(compare, analyze, scratch):
    """Two captures hitting the same path on different hosts must never pair."""
    module = compare.module
    _, rows = analyze.ensure_index(scratch / "compare_a.har")
    row = next(iter(rows))
    for field, value in (("host", "evil.example.com"), ("scheme", "http"), ("port", "8443")):
        other = dict(row)
        other[field] = value
        assert module.identity(row) != module.identity(other), f"{field} is not in the key"


def test_query_order_is_part_of_identity(compare, analyze, scratch):
    """Sorting would make `?tag=a&tag=b` and `?tag=b&tag=a` the same request."""
    module = compare.module
    _, rows = analyze.ensure_index(scratch / "compare_a.har")
    row = dict(next(iter(rows)))
    row["query"] = [["tag", "a"], ["tag", "b"]]
    reversed_row = dict(row)
    reversed_row["query"] = [["tag", "b"], ["tag", "a"]]
    assert module.identity(row) != module.identity(reversed_row)


def test_json_output_is_machine_readable(compare):
    code, out, _ = compare("compare_a", "compare_b", "--json")
    assert code == 1
    payload = json.loads(out)
    assert payload["paired"] == 3
    assert payload["only_input"] and payload["only_against"]


def test_selection_narrows_the_comparison(compare):
    """The shared grammar applies here too — compare what was selected, not everything."""
    code, out, _ = compare("compare_a", "compare_b", "--status", "500")
    assert code in (0, 1)
    assert "entries —" in out
    header = out.splitlines()[0]
    assert header.startswith("0 vs 1 entries"), header


def test_two_searches_that_differ_only_in_the_post_body_are_not_equal(compare):
    """The one question a diff of two captures is asked, on the shape that hides it.

    A modern board's list endpoint is very often a POST whose URL never varies
    and whose body carries the entire query. The pairing key used to fall back
    to hashing the request's *mime type*, so every `application/json` POST to
    one URL hashed alike and a capture of one search compared equal to a capture
    of another — a confident "no change" on the only difference there was.
    """
    code, out, _ = compare("search_post_a", "search_post_b")
    assert code == 1, f"two different searches compared equal:\n{out}"
    assert "1 only in" in out, out


def test_a_capture_compared_with_itself_still_pairs_on_the_body_hash(compare):
    """The fix must not make every POST unpairable, which would invent changes."""
    code, out, _ = compare("search_post_a", "search_post_a")
    assert code == 0, out
    assert "no differences" in out
