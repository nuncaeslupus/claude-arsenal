#!/usr/bin/env python3
"""create_task.py - Append a new task to .loop/state/queue.jsonl.
Validates schema and dependency edges before writing.
"""
import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

QUEUE_FILE = ".loop/state/queue.jsonl"


def _load_queue(path: Path) -> list[dict]:
    rows: list[dict] = []
    if not path.exists():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            try:
                data = json.loads(line)
                if isinstance(data, dict):
                    rows.append(data)
            except json.JSONDecodeError:
                pass
    return rows


def _generate_id(title: str) -> str:
    seed = f"{title}-{time.time()}"
    return "lo-" + hashlib.sha256(seed.encode()).hexdigest()[:4]


def add_task(
    title: str,
    priority: int,
    requires: list[str],
    deps: list[str],
    queue_path: Path,
) -> str:
    rows = _load_queue(queue_path)
    existing_ids = {r["id"] for r in rows}

    for dep in deps:
        if dep not in existing_ids:
            sys.exit(
                f"add_task: dep '{dep}' not found in queue. "
                f"Existing IDs: {sorted(existing_ids) or '(empty queue)'}"
            )

    task_id = _generate_id(title)
    attempts = 0
    while task_id in existing_ids:
        task_id = _generate_id(title + str(attempts))
        attempts += 1
        if attempts > 100:
            sys.exit("add_task: could not generate a unique ID after 100 attempts")

    row: dict = {
        "id": task_id,
        "title": title,
        "status": "open",
        "priority": priority,
        "requires": requires,
        "deps": [{"id": d, "type": "blocks"} for d in deps],
        "assignee": None,
        "payload": f"tasks/{task_id}.md",
    }

    queue_path.parent.mkdir(parents=True, exist_ok=True)
    with queue_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, separators=(",", ":")) + "\n")

    return task_id


def main() -> None:
    p = argparse.ArgumentParser(description="Add a task to the loop queue.")
    p.add_argument("--title", required=True, help="Task title")
    p.add_argument("--priority", type=int, default=0, help="Task priority (higher = more urgent)")
    p.add_argument(
        "--requires", action="append", default=[], metavar="CAP",
        help="Surface capability requirement (e.g. surface:cli). Repeatable.",
    )
    p.add_argument(
        "--deps", action="append", default=[], metavar="ID",
        help="Task ID this task blocks on (repeatable).",
    )
    p.add_argument("--queue", default=QUEUE_FILE, help="Path to queue.jsonl")
    args = p.parse_args()

    task_id = add_task(args.title, args.priority, args.requires, args.deps, Path(args.queue))
    print(task_id)


if __name__ == "__main__":
    main()
