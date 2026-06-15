---
name: queue-status
description: When the user wants queue progress counts by status. Do NOT use to modify task status.
user-invocable: true
argument-hint: "[--detail]"
---

# queue-status

Reports task counts by status from `claude-arsenal/queue/tasks.jsonl`: total, open, in-progress, done, merged, and blocked. With `--detail`, lists each task's ID, title, status, assignee, and unmet dependency IDs.

CANARY: queue-status-loaded-2026-06-13-fb78d23e-d4e5f6a7b8c9d0e1

## When to load

Load this skill when:

- The user asks "how is the queue?", "what tasks are left?", "queue status", or "/queue-status".
- Checking whether all tasks are done before closing a loop session.
- Diagnosing a stuck queue (tasks in `blocked` status with unmet deps).

## How to use

```bash
# Summary counts
python3 .claude/skills/queue-status/scripts/query_status.py

# Full task list
python3 .claude/skills/queue-status/scripts/query_status.py --detail
```

## Gotchas

- **`in_progress` tasks with no active assignee signal a crashed session.** Use the bundle release script to reset it to `open` status (see `claude-arsenal/AGENTS.md`).
- **`blocked` does not mean failed.** A task becomes eligible automatically once its dependencies complete.
