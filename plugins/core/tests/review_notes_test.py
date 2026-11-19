"""Tests for review_notes.py — the shared review-notes v1 export block."""

import importlib.util
import json
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "skills/init/assets/scripts/review_notes.py"
_spec = importlib.util.spec_from_file_location("review_notes", SCRIPT)
assert _spec and _spec.loader
rn = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rn)

FULL = {
    "v": 1,
    "page": "tavern-round-2",
    "built": "2026-11-19T17:30Z",
    "source": "abc123",
    "items": {
        "tavern": {
            "verdict": "fix",
            "note": "door too small --> scale it",
            "compare": ["v1", "v2"],
            "blocks": [{"quote": "The door", "note": "bigger"}],
        },
        "intro": {"verdict": "fine", "note": "", "blocks": []},
        "api": {"verdict": "not-a-bug", "note": "intended", "blocks": []},
        "spec-1": {"verdict": None, "note": "a plain reader note", "blocks": []},
    },
}


def test_roundtrip_all_fields_identical() -> None:
    export = "# Notes\n\nsome markdown\n\n" + rn.render_block(FULL) + "\n"
    assert rn.parse_block(export) == FULL


def test_unknown_keys_kept_on_import() -> None:
    obj = json.loads(json.dumps(FULL))
    obj["future"] = {"x": 1}
    obj["items"]["intro"]["region"] = [1, 2, 3, 4]
    assert rn.parse_block(rn.render_block(obj)) == obj


def test_missing_block_raises() -> None:
    with pytest.raises(rn.NotesError, match="no `<!-- review-notes"):
        rn.parse_block("# just notes\n")


@pytest.mark.parametrize(
    ("mutate", "message"),
    [
        (lambda o: o.__setitem__("v", 2), "version"),
        (lambda o: o["items"]["intro"].__setitem__("verdict", "maybe"), "verdict"),
        (lambda o: o["items"]["intro"].__setitem__("blocks", ["x"]), "blocks"),
        (lambda o: o.__setitem__("items", []), "items"),
    ],
)
def test_invalid_object_rejected(mutate, message) -> None:
    obj = json.loads(json.dumps(FULL))
    mutate(obj)
    with pytest.raises(rn.NotesError, match=message):
        rn.validate(obj)


def test_cli_parse_exit_codes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    good = tmp_path / "good.md"
    good.write_text(rn.render_block(FULL), encoding="utf-8")
    assert rn.main(["parse", str(good)]) == 0
    assert json.loads(capsys.readouterr().out) == FULL
    bad = tmp_path / "bad.md"
    bad.write_text("nothing", encoding="utf-8")
    assert rn.main(["parse", str(bad)]) == 1
