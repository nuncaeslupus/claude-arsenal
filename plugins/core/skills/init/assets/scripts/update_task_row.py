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
import contextlib
import json
import os
import sys
import tempfile
from pathlib import Path


def _atomic_write_jsonl(path: Path, rows: list[dict]) -> None:
    """Serialize rows and replace `path` atomically (QIC-13).

    Write to a temp file in the same directory, fsync, then rename — a rename is
    atomic on POSIX, so a crash mid-write can never leave a truncated/corrupt
    ledger; readers see either the old file or the fully-written new one.
    """
    payload = "\n".join(json.dumps(r, separators=(",", ":")) for r in rows) + "\n"
    fd, tmp_name = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".", suffix=".tmp")
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(payload)
            fh.flush()
            os.fsync(fh.fileno())
        tmp.replace(path)
    except BaseException:
        with contextlib.suppress(OSError):
            tmp.unlink()
        raise


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
                    current = int(row.get("attempts") or 0) + 1
                    cap = int(row.get("max_attempts") or 3)
                    row["attempts"] = current
                    final_status = "escalated" if current >= cap else "open"
                elif current_status == "escalated":
                    final_status = "escalated"
                else:
                    final_status = "open"
            row["status"] = final_status
            if final_status not in ("in_progress",):
                row["assignee"] = None
                # Release the lease (QIC: claimed_at lease). claim.sh stamps
                # claimed_at when a task goes in_progress; clear it on any exit
                # from in_progress so a completed/re-opened task is never seen as
                # a stale (crashed) claim by the doctor / reclaim path.
                row.pop("claimed_at", None)
            if final_status in ("done", "merged"):
                row["attempts"] = 0
            if pr_url:
                row["pr"] = pr_url
            updated = True

    if not updated:
        print(f"update_task_row: task {task_id} not found", file=sys.stderr)
        sys.exit(1)

    _atomic_write_jsonl(queue_path, rows)
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
