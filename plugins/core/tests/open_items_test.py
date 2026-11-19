"""Tests for open_items.py — the open-items store and decision log."""

import argparse
import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[1] / "skills/init/assets/scripts"
sys.path.insert(0, str(SCRIPTS))
_spec = importlib.util.spec_from_file_location("open_items", SCRIPTS / "open_items.py")
assert _spec and _spec.loader
oi = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(oi)
import review_notes  # noqa: E402


@pytest.fixture
def repo(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.chdir(tmp_path)
    monkeypatch.delenv("ARSENAL_HOME", raising=False)
    return tmp_path


def _add(what: str, **kw: str) -> str:
    fields = {"kind": "question", "evidence": None, "severity": None, "confidence": None}
    fields |= {"fix": None, "pr": None, "where": "scenes/a.png"} | kw
    return str(oi.add(argparse.Namespace(what=what, **fields)))


def test_add_appends_and_lists(repo: Path) -> None:
    a = _add("door too small", kind="evidence", fix="scale door")
    b = _add("which palette?")
    rows = oi.read_jsonl(repo / "arsenal/evidence/open.jsonl")
    assert [r["id"] for r in rows] == [a, b]
    assert rows[0]["kind"] == "evidence" and rows[0]["fix"] == "scale door"
    assert "arsenal/evidence/open.jsonl merge=union" in (repo / ".gitattributes").read_text()


def test_answer_moves_item_to_decisions(repo: Path) -> None:
    a = _add("door too small", fix="scale door")
    b = _add("keep me")
    oi.answer(a, "fix", "yes, 1.3x", "reviewer")
    store = repo / "arsenal/evidence"
    assert [r["id"] for r in oi.open_rows(store)] == [b]
    decided = oi.read_jsonl(store / "decisions.jsonl")
    assert (
        decided[0]["id"] == a and decided[0]["verdict"] == "fix" and decided[0]["by"] == "reviewer"
    )
    md = (store / "decisions.md").read_text()
    assert a in md and "**fix**" in md and "yes, 1.3x" in md


def test_answer_unknown_id_fails(repo: Path) -> None:
    with pytest.raises(oi.ItemError, match="no open item"):
        oi.answer("oi-00000000", "fine")


def test_apply_closes_only_decided_open_items(repo: Path, tmp_path: Path) -> None:
    a, b, c = _add("one"), _add("two"), _add("three")
    notes = {
        "v": 1,
        "items": {
            a: {"verdict": "fine", "note": "", "blocks": []},
            b: {"verdict": "not-a-bug", "note": "intended", "blocks": []},
            c: {"verdict": None, "note": "later", "blocks": []},
            "oi-gone": {"verdict": "fix", "note": "", "blocks": []},
        },
    }
    export = tmp_path / "export.md"
    export.write_text("# notes\n" + review_notes.render_block(notes), encoding="utf-8")
    done = oi.apply_export(export, "reviewer")
    assert {d["id"] for d in done} == {a, b}
    assert [r["id"] for r in oi.open_rows(repo / "arsenal/evidence")] == [c]


def test_two_branches_append_merge_clean(repo: Path) -> None:
    def git(*args: str) -> str:
        return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout

    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@example.com")
    git("config", "user.name", "t")
    _add("base item")
    git("add", "-A")
    git("commit", "-qm", "base")
    git("checkout", "-qb", "one")
    _add("from branch one")
    git("commit", "-qam", "one")
    git("checkout", "-q", "main")
    _add("from main")
    git("commit", "-qam", "main")
    git("merge", "-q", "--no-edit", "one")
    whats = [r["what"] for r in oi.read_jsonl(repo / "arsenal/evidence/open.jsonl")]
    assert sorted(whats) == ["base item", "from branch one", "from main"]


def test_answer_racing_append_merges_without_resurrecting(repo: Path) -> None:
    def git(*args: str) -> None:
        subprocess.run(["git", *args], check=True, capture_output=True, text=True)

    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@example.com")
    git("config", "user.name", "t")
    _add("one")
    two = _add("two")
    git("add", "-A")
    git("commit", "-qm", "base")
    git("checkout", "-qb", "answer")
    oi.answer(two, "fine")
    git("add", "-A")
    git("commit", "-qm", "answer two")
    git("checkout", "-q", "main")
    _add("three")
    git("commit", "-qam", "append three")
    git("merge", "-q", "--no-edit", "answer")
    store = repo / "arsenal/evidence"
    assert [r["what"] for r in oi.open_rows(store)] == ["one", "three"]
    assert [r["id"] for r in oi.read_jsonl(store / "decisions.jsonl")] == [two]


def test_gitattributes_at_repo_root_from_subdir(
    repo: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    subprocess.run(["git", "init", "-q"], check=True)
    (repo / "sub").mkdir()
    monkeypatch.chdir(repo / "sub")
    monkeypatch.setenv("ARSENAL_HOME", str(repo / "arsenal"))
    _add("from a subdirectory")
    assert not (repo / "sub/.gitattributes").exists()
    assert "arsenal/evidence/open.jsonl merge=union" in (repo / ".gitattributes").read_text()


def test_cli_answer_fix_prints_task_line(repo: Path, capsys: pytest.CaptureFixture[str]) -> None:
    a = _add("door too small", fix="scale door")
    assert oi.main(["answer", a, "--verdict", "fix"]) == 0
    out = capsys.readouterr().out
    assert f"{a}: fix" in out and 'create_task.py --title "Fix: scale door"' in out
    assert oi.main(["answer", a, "--verdict", "fine"]) == 1


def test_arsenal_home_relocates_store(repo: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ARSENAL_HOME", "host/arsenal")
    _add("relocated")
    assert (repo / "host/arsenal/evidence/open.jsonl").exists()
