#!/usr/bin/env python3
"""handle_sync.py — find task files that have no issue handle yet.

This is the one sync step the design keeps, and it is worth being precise about
why it is not the old `queue_sync.sh` in a new coat. That script reconciled
*state* in both directions between two copies of a ledger, which is where its
conflicts and its path-traversal bug came from. This one is one-directional and
idempotent: a task file exists, so an issue should point at it. Nothing flows
back, and running it twice changes nothing.

If it never runs, work is delayed — a task nobody opened an issue for is simply
not claimable yet — but nothing is corrupted.

    handle_sync.py --tasks-dir arsenal/tasks --issues /tmp/issues.json

Prints one JSON object per missing handle, ready to create with whatever GitHub
channel the surface offers:

    {"task":"t-3f8a91c2","title":"…","labels":["arsenal:task"],"body":"…"}

Exit: 0 when everything has a handle or the missing ones were printed,
2 on unreadable input.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from task_select import TERMINAL, load_tasks, task_id_from_issue


def missing_handles(
    tasks: list[dict[str, Any]], issues: list[dict[str, Any]], *, label: str
) -> list[dict[str, Any]]:
    handled = {task_id for issue in issues if (task_id := task_id_from_issue(issue))}
    out: list[dict[str, Any]] = []
    for task in tasks:
        if task["id"] in handled:
            continue
        # `load_tasks` includes finished tasks on purpose — their ids must
        # resolve so dependents unblock and their gates stay on disk. But an
        # issue handle carries *state*, and a merged task's state is already
        # final, so it needs no handle. Without this, a repo that has been
        # running a while proposes an issue for every task it ever completed,
        # and a session following the protocol literally opens them: dozens of
        # spurious tasks that read as open and unclaimed, and that a selector
        # will hand straight back out.
        if str(task.get("status") or "") in TERMINAL:
            continue
        out.append(
            {
                "task": task["id"],
                "title": task["title"],
                "labels": [label],
                "body": (
                    f"`arsenal-task: {task['id']}`\n\n"
                    f"Task defined in `{task['path']}`"
                ),
            }
        )
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--tasks-dir", type=Path, default=Path("arsenal/tasks"))
    parser.add_argument("--issues", type=Path, required=True, help="JSON array of issues")
    parser.add_argument("--label", default="arsenal:task")
    args = parser.parse_args(argv)

    try:
        payload = json.loads(args.issues.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"handle_sync: cannot read --issues — {exc}", file=sys.stderr)
        return 2
    if isinstance(payload, dict):
        payload = payload.get("issues", [])

    tasks, warnings = load_tasks(args.tasks_dir)
    for warning in warnings:
        print(f"handle_sync: {warning}", file=sys.stderr)

    rows = missing_handles(
        tasks, [i for i in payload if isinstance(i, dict)], label=args.label
    )
    for row in rows:
        print(json.dumps(row, separators=(",", ":")))
    if not rows:
        print("handle_sync: every task has an issue handle", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
