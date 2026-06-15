#!/usr/bin/env python3
"""test_status_escalated.py — Unit tests for escalated task support in query_status.py.
Exit: 0 on PASS, 1 on FAIL.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
STATUS_PY = SCRIPT_DIR.parent / "skills" / "queue-status" / "scripts" / "query_status.py"

if not STATUS_PY.exists():
    print(f"SKIP: query_status.py not found at {STATUS_PY}", file=sys.stderr)
    sys.exit(0)


def run_status(queue_path: Path, detail: bool = False) -> str:
    cmd = [sys.executable, str(STATUS_PY), "--queue", str(queue_path)]
    if detail:
        cmd.append("--detail")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"query_status.py failed: {result.stderr}")
    return result.stdout


def write_queue(path: Path, rows: list[dict]) -> None:
    path.write_text(
        "\n".join(json.dumps(r, separators=(",", ":")) for r in rows) + "\n",
        encoding="utf-8",
    )


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


with tempfile.TemporaryDirectory() as tmpdir:
    queue = Path(tmpdir) / "tasks.jsonl"

    # --- QS-ESC-01: summary line contains escalated=1 ---
    write_queue(queue, [
        {"id": "lo-e001", "title": "T1", "status": "escalated",
         "max_attempts": 3, "attempts": 3,
         "priority": 0, "requires": [], "deps": [], "assignee": None, "payload": "lo-e001.md"},
    ])
    out = run_status(queue)
    if "escalated=1" not in out:
        fail(f"QS-ESC-01: expected 'escalated=1' in summary, got: {out!r}")
    print("PASS QS-ESC-01: summary contains escalated=1")

    # --- QS-ESC-02: --detail shows attempts=3/max_attempts=3 ---
    out = run_status(queue, detail=True)
    if "attempts=3/3" not in out:
        fail(f"QS-ESC-02: expected 'attempts=3/3' in detail, got: {out!r}")
    if "needs human reset" not in out:
        fail(f"QS-ESC-02: expected 'needs human reset' in detail, got: {out!r}")
    print("PASS QS-ESC-02: detail shows attempt budget and reset hint")

    # --- QS-ESC-03: escalated does NOT satisfy blocking deps ---
    write_queue(queue, [
        {"id": "lo-e002", "title": "Blocker", "status": "escalated",
         "max_attempts": 3, "attempts": 3,
         "priority": 0, "requires": [], "deps": [], "assignee": None, "payload": "lo-e002.md"},
        {"id": "lo-e003", "title": "Dependent", "status": "open",
         "priority": 0, "requires": [], "deps": [{"id": "lo-e002", "type": "blocks"}],
         "assignee": None, "payload": "lo-e003.md"},
    ])
    out = run_status(queue, detail=True)
    if "unmet_deps=['lo-e002']" not in out and "unmet_deps=[\"lo-e002\"]" not in out:
        fail(f"QS-ESC-03: escalated task should not satisfy blocking dep, got: {out!r}")
    print("PASS QS-ESC-03: escalated task does not satisfy blocking deps")

    # --- QS-ESC-04: empty queue shows escalated=0 ---
    queue.write_text("", encoding="utf-8")
    out = run_status(queue)
    if "escalated=0" not in out:
        fail(f"QS-ESC-04: expected 'escalated=0' in empty queue summary, got: {out!r}")
    print("PASS QS-ESC-04: empty queue summary includes escalated=0")

    # --- QS-ESC-05: non-escalated tasks still show assignee in --detail ---
    write_queue(queue, [
        {
            "id": "lo-e004", "title": "InProgress", "status": "in_progress",
            "priority": 0, "requires": [], "deps": [],
            "assignee": "session-abc", "payload": "lo-e004.md",
        },
    ])
    out = run_status(queue, detail=True)
    if "session-abc" not in out:
        fail(f"QS-ESC-05: in_progress task should still show assignee, got: {out!r}")
    print("PASS QS-ESC-05: non-escalated tasks show assignee in detail")

print("\nAll QS-ESC tests passed.")
