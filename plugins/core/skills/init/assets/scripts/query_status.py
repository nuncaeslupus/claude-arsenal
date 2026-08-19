#!/usr/bin/env python3
"""query_status.py — the board: what is open, claimed, done, and what is blocking.

Reads the task graph from the repository and the state from the GitHub issues the
caller already fetched, so it needs no network of its own and cannot disagree with
what the selector sees — both derive from the same two inputs.

    python3 claude-arsenal/scripts/query_status.py --issues /tmp/issues.json [--detail]

Exit: 0 always; 1 with --fail-on-problems if any task has no gate, no handle, or a
dependency that does not exist.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# task_select.py is the single implementation of "read the graph, derive state",
# and it sits beside this file — in the bundle at runtime, in the init skill's
# assets here. Importing it is what keeps the board and the selector from ever
# disagreeing: both answer from the same code, not from two copies kept in step
# by hand.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from task_select import (
    TERMINAL,
    effective_state,
    load_tasks,
    state_from_issues,
    task_id_from_issue,
)


def blocking(task: dict[str, Any], state: dict[str, str]) -> list[str]:
    return [d for d in task["deps"] if state.get(d) not in TERMINAL]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tasks-dir", type=Path, default=Path("arsenal/tasks"))
    parser.add_argument("--issues", type=Path, help="JSON array of arsenal:task issues")
    parser.add_argument("--detail", action="store_true")
    parser.add_argument("--fail-on-problems", action="store_true")
    args = parser.parse_args(argv)

    issues: list[dict[str, Any]] = []
    if args.issues and args.issues.is_file():
        payload = json.loads(args.issues.read_text(encoding="utf-8"))
        if isinstance(payload, dict):
            payload = payload.get("issues", [])
        issues = [i for i in payload if isinstance(i, dict)]

    tasks, warnings = load_tasks(args.tasks_dir)
    state = effective_state(tasks, state_from_issues(issues, warnings=warnings))
    handled = {t for i in issues if (t := task_id_from_issue(i))}

    counts = {"open": 0, "claimed": 0, "done": 0, "cancelled": 0, "blocked": 0}
    problems: list[str] = []
    known_ids = {t["id"] for t in tasks}
    for task in tasks:
        current = state.get(task["id"], "open")
        if current == "open" and blocking(task, state):
            counts["blocked"] += 1
        else:
            counts[current] = counts.get(current, 0) + 1
        # Finished work is held to a different standard: it needs no issue to
        # claim it and no gate to run again. Reporting it as a problem would
        # bury the live tasks that genuinely have one.
        if task.get("status") in TERMINAL:
            continue
        if not task["gate"]:
            problems.append(f"{task['id']}: no fenced gate block — nothing would be checked")
        if task["id"] not in handled:
            problems.append(f"{task['id']}: no issue handle — not claimable until one exists")
        for dep in task["deps"]:
            if dep not in known_ids:
                problems.append(f"{task['id']}: depends on unknown task {dep}")

    print(
        f"tasks: {len(tasks)} — "
        + ", ".join(f"{k} {v}" for k, v in counts.items() if v or k in {"open", "claimed", "done"})
    )

    if args.detail:
        for task in sorted(tasks, key=lambda t: (-int(t["priority"]), t["id"])):
            current = state.get(task["id"], "open")
            blockers = blocking(task, state)
            marks = []
            if blockers:
                marks.append("blocked-by " + ",".join(blockers))
            if not task["gate"]:
                marks.append("no-gate")
            if task["id"] not in handled:
                marks.append("no-handle")
            suffix = f"  [{'; '.join(marks)}]" if marks else ""
            print(f"  {task['id']}  p{task['priority']:<3} {current:<9} {task['title']}{suffix}")

    for warning in warnings:
        print(f"query_status: {warning}", file=sys.stderr)
    for problem in problems:
        print(f"query_status: {problem}", file=sys.stderr)

    if problems and args.fail_on_problems:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
