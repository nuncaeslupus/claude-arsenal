---
name: queue-add
description: When the user wants to add a task to the claude-arsenal queue. Do NOT use to update or remove existing tasks.
user-invocable: true
argument-hint: "--title TITLE [--priority N] [--workspace NAME] [--requires surface:X] [--deps lo-XXXX]"
---

# queue-add

Appends a new task row to `claude-arsenal/queue/tasks.jsonl` with a hash-based ID, title, priority, optional workspace scope, surface requirements, and dependency edges. Validates schema and dependency edges before writing.

CANARY: queue-add-loaded-2026-06-13-fb78d23e-c3d4e5f6a7b8c9d0

## When to load

Load this skill when:

- The user wants to add a task, ticket, or work item to the queue.
- Phrasing: "add a task", "queue this up", "enqueue", "/queue-add".
- Seeding the queue from a list of tasks before starting workers.

## How to use

```bash
python3 .claude/skills/queue-add/scripts/create_task.py \
  --title "Implement claim.sh" \
  --priority 10 \
  --workspace BACKEND \
  --requires "surface:cli" \
  --deps lo-a1b2
```

The script generates a `lo-XXXX` hash ID, writes the row, and prints the assigned ID.
Use the printed ID as a `--deps` argument when adding dependent tasks.

## Gotchas

- **Deps must already exist in the queue.** The script rejects `--deps` values that do not match an existing task ID.
- **`requires` values are exact strings.** Use `surface:cli` or `surface:web`; unrecognised values pass through but will never match a worker's surface profile.
- **`--workspace` scopes the task.** When set, `queue_eval.sh` with `LOOP_WORKSPACE=X` will only return tasks for that workspace.
