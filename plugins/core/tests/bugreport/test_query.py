"""query_bugreport.py primitives: selectors, locate, sample sniffing, show, budgets."""

from __future__ import annotations

import json

import pytest
import query_bugreport as q


def _run(cli, built, *argv, **build):
    return cli("query_bugreport", argv[0], "--input", str(built(**build)), *argv[1:])


def test_ambiguous_bare_name_exits_2_with_candidates(built, cli):
    code, _, err = _run(cli, built, "show", "--section", "meminfo", traps=("dup-service",))
    assert code == 2 and "meminfo#1" in err and "meminfo#2" in err


def test_case_insensitive_unique_match_selects(built, cli):
    code, doc, _ = _run(cli, built, "show", "--section", "BATTERY", "--grep", "level")
    assert code == 0 and doc["section"] == "battery#1"


def test_unknown_section_exits_2(built, cli):
    code, _, _ = _run(cli, built, "show", "--section", "nosuch")
    assert code == 2


def test_locate_counts_hits_without_lines(built, cli):
    code, doc, _ = _run(cli, built, "locate", "--grep", "ExampleSync")
    assert code == 0 and doc["rows"][0]["id"] == "SYSTEM LOG#1"
    assert set(doc["rows"][0]) == {"id", "hits", "first"}
    assert len(json.dumps(doc).encode()) <= 2048


@pytest.mark.parametrize(
    ("lines", "fmt"),
    [
        (["level: 54", "status: 3", "health: 2", "voltage: 3912"], "kv"),
        (
            [
                "USER PID PPID VSZ RSS",
                "root 1 0 100 10",
                "system 200 1 300 30",
                "u0_a1 4321 200 900 90",
            ],
            "table",
        ),
        (["a:", "  b:", "    c: 1", "    d: 2", "  e:"], "tree"),
        (["9,0,i,vers,36,214", "9,0,i,uid,1000,android", "9,0,l,pr,system,0,1,2"], "csv"),
        (
            [
                "11-03 14:00:00.000  1000  1234  1250 I ExampleSync: ok",
                "11-03 14:00:01.000  1000  1234  1250 W ExampleSync: slow",
            ],
            "log",
        ),
        (["something", "else entirely"], "unknown"),
    ],
)
def test_sample_sniffs_kv_table_tree_csv_log(lines, fmt):
    assert q.sniff(lines)[0] == fmt


@pytest.mark.parametrize(
    ("section", "fmt"),
    [
        ("battery", "kv"),
        ("CHECKIN BATTERYSTATS", "csv"),
        ("SYSTEM LOG", "log"),
        ("KERNEL LOG", "log"),
    ],
)
def test_sample_on_fixture_sections(built, cli, section, fmt):
    code, doc, _ = _run(cli, built, "sample", "--section", section)
    assert code == 0 and doc["format"] == fmt
    assert len(json.dumps(doc).encode()) <= 2048
    assert all(len(r) <= 200 for r in doc["rows"])


def test_show_returns_offsets_that_point_at_the_line(built, cli):
    path = built()
    code, doc, _ = cli(
        "query_bugreport",
        "show",
        "--input",
        str(path),
        "--section",
        "battery",
        "--grep",
        "level",
        "--no-redact",
    )
    assert code == 0
    row = doc["rows"][0]
    data = path.read_bytes()
    assert data[row["offset"] : row["offset"] + len(row["line"])].decode() == row["line"]


def test_show_context_adds_neighbours(built, cli):
    _, doc, _ = _run(
        cli, built, "show", "--section", "battery", "--grep", "level", "--context", "1"
    )
    assert [r["line"].strip() for r in doc["rows"]] == ["present: true", "level: 54", "scale: 100"]


def test_sections_rows_and_cap(built, cli):
    code, doc, _ = _run(cli, built, "sections")
    assert code == 0 and doc["shown"] == doc["total"] > 20
    assert len(json.dumps(doc).encode()) <= 4096
    assert {"id", "kind", "block", "size"} <= set(doc["rows"][0])


def test_bad_regex_exits_2(built, cli):
    code, _, err = _run(cli, built, "locate", "--grep", "(")
    assert code == 2 and "regular expression" in err
