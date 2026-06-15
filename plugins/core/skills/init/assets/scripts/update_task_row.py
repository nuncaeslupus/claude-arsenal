#!/usr/bin/env python3
"""update_task_row.py — Update a single task row in tasks.jsonl.

Usage: update_task_row.py <task_id> <new_status> <queue_path> <pr_url> <reset_attempts>

  task_id        Task ID to update (e.g. lo-a3f8).
  new_status     Requested status: done|merged|open|blocked|in_progress|escalated.
  queue_path     Path to tasks.jsonl.
  pr_url         PR URL to record (empty string to skip).
  reset_attempts "1" to clear the attempts counter and bypass the cap check; "" otherwise.

Prints the final resolved status to stdout (may differ from new_status when
auto-escalation fires on an exhausted attempt cap).

Exit: 0 on success, 1 on error.
"""
import json
import sys
from pathlib import Path


def update_task_row(
    task_id: str,
    new_status: str,
    queue_path: Path,
    pr_url: str,
    reset_attempts: str,
) -> str:
    """Update the task row and return the final status written."""
    rows: list[dict] = []
    for line in queue_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            try:
                data = json.loads(line)
                if not isinstance(data, dict):
                    raise ValueError(f"expected JSON object, got {type(data).__name__}")
                rows.append(data)
            except (json.JSONDecodeError, ValueError) as e:
                print(
                    f"update_task_row: invalid line in queue file: {line!r} ({e})",
                    file=sys.stderr,
                )
                sys.exit(1)

    updated = False
    final_status = new_status
    for row in rows:
        if row.get("id") == task_id:
            current_status = row.get("status")
            if new_status == "open":
                if reset_attempts == "1":
                    row["attempts"] = 0
                    final_status = "open"
                elif current_status == "in_progress":
                    current = row.get("attempts", 0) + 1
                    cap = row.get("max_attempts", 3)
                    row["attempts"] = current
                    final_status = "escalated" if current >= cap else "open"
                elif current_status == "escalated":
                    final_status = "escalated"
                else:
                    final_status = "open"
            row["status"] = final_status
            if final_status not in ("in_progress",):
                row["assignee"] = None
            if pr_url:
                row["pr"] = pr_url
            updated = True

    if not updated:
        print(f"update_task_row: task {task_id} not found", file=sys.stderr)
        sys.exit(1)

    queue_path.write_text(
        "\n".join(json.dumps(r, separators=(",", ":")) for r in rows) + "\n",
        encoding="utf-8",
    )
    return final_status


def main() -> None:
    if len(sys.argv) != 6:
        print(
            "usage: update_task_row.py"
            " <task_id> <new_status> <queue_path> <pr_url> <reset_attempts>",
            file=sys.stderr,
        )
        sys.exit(1)

    task_id, new_status, queue_path_str, pr_url, reset_attempts = sys.argv[1:6]
    queue_path = Path(queue_path_str)

    final_status = update_task_row(task_id, new_status, queue_path, pr_url, reset_attempts)
    print(final_status)


if __name__ == "__main__":
    main()
