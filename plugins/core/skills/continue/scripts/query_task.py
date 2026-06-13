#!/usr/bin/env python3
"""query_task.py - Query the next eligible task or report status for /continue."""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

QUEUE_FILE = "claude-arsenal/queue/tasks.jsonl"
QUEUE_EVAL = "claude-arsenal/bin/queue_eval.sh"


def _load_queue(path: Path) -> list[dict]:
    if not path.exists():
        return []
    rows = []
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


def _fuzzy_match(rows: list[dict], search: str) -> dict | None:
    search_lower = search.lower()
    open_rows = [r for r in rows if r.get("status") == "open"]
    for row in open_rows:
        if search_lower in (row.get("title") or "").lower():
            return row
    return None


def main() -> None:
    p = argparse.ArgumentParser(description="Pick the next task for /continue.")
    p.add_argument("--workspace", metavar="NAME", help="Scope to a workspace.")
    p.add_argument("--search", metavar="TEXT", help="Fuzzy-match a task title.")
    p.add_argument("--queue", default=QUEUE_FILE, help="Path to queue.jsonl")
    args = p.parse_args()

    queue_path = Path(args.queue)

    if args.search:
        rows = _load_queue(queue_path)
        match = _fuzzy_match(rows, args.search)
        if match:
            print(json.dumps(match))
        else:
            open_count = sum(1 for r in rows if r.get("status") == "open")
            print(f"no_match  open={open_count}", file=sys.stderr)
            sys.exit(1)
        return

    # Run queue_eval.sh with optional workspace scope. Pass the workspace via
    # the environment, never interpolated into a shell string — a workspace
    # name with shell metacharacters would otherwise inject commands.
    env = os.environ.copy()
    if args.workspace:
        env["LOOP_WORKSPACE"] = args.workspace
    result = subprocess.run(
        ["bash", QUEUE_EVAL],
        capture_output=True,
        text=True,
        env=env,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)
    output = result.stdout.strip()
    if output:
        print(output)
    else:
        rows = _load_queue(queue_path)
        open_count = sum(1 for r in rows if r.get("status") == "open")
        ws_suffix = f" in workspace {args.workspace!r}" if args.workspace else ""
        print(f"no_eligible_task{ws_suffix}  open={open_count}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
