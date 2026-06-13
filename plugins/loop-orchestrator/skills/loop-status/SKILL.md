---
name: loop-status
description: When the user wants queue progress — open/in-progress/done/blocked counts from queue.jsonl.
user-invocable: true
argument-hint: "[--detail]"
---

# loop-status

Reports task counts by status from `.loop/state/queue.jsonl`: total, open, in-progress, done, and blocked. With `--detail`, lists each task's ID, title, status, assignee, and unmet dependency IDs.

CANARY: loop-status-loaded-2026-06-13-fb78d23e-284aba58f54e983d

## When to load

Load this skill when:

- The user asks "how is the queue?", "what tasks are left?", or "loop status".
- Checking whether all tasks are done before closing a loop session.
- Diagnosing a stuck queue (tasks in `blocked` status with unmet deps).

## How to use

```bash
# Summary counts
python3 .claude/skills/loop-status/scripts/queue_status.py

# Full task list
python3 .claude/skills/loop-status/scripts/queue_status.py --detail
```

## Gotchas

- **`in_progress` tasks with no active assignee signal a crashed session.** An `in_progress` row whose `assignee` session is gone means the claim was never released; run `release.sh <task-id> open` to reset it.
- **`blocked` does not mean failed.** A task is `blocked` only when its `deps[]` list contains IDs that are not yet `done`. It will become eligible automatically once dependencies complete.
