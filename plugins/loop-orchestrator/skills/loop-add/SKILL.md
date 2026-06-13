---
name: loop-add
description: When the user wants to add a task to the loop queue — appends a row to queue.jsonl.
user-invocable: true
argument-hint: "--title TITLE [--priority N] [--requires surface:X] [--deps lo-XXXX]"
---

# loop-add

Appends a new task row to `.loop/state/queue.jsonl` with a hash-based ID, title, priority, surface requirements, and dependency edges. Validates the resulting row against the queue schema before writing.

CANARY: loop-add-loaded-2026-06-13-fb78d23e-07a0eca4c9e64e67

## When to load

Load this skill when:

- The user wants to add a task, ticket, or work item to the queue.
- Phrasing: "add a task", "queue this up", "enqueue", "/loop-add".
- Seeding the queue from a list of tasks before starting workers.

## How to use

```bash
python3 .claude/skills/loop-add/scripts/add_task.py \
  --title "Implement claim.sh" \
  --priority 10 \
  --requires "surface:cli" \
  --deps lo-a1b2
```

The script generates a `lo-XXXX` hash ID, writes the row, and prints
the assigned ID. Use the printed ID as a `--deps` argument when adding
dependent tasks.

## Gotchas

- **Deps must already exist in the queue.** The script rejects `--deps` values that do not match an existing task ID to prevent orphaned edges.
- **`requires` values are exact strings.** Use `surface:cli` or `surface:web`, not free-form text; unrecognised values pass through but will never match a worker's surface profile.
