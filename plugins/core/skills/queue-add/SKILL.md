---
name: queue-add
description: When the user wants to add a task to the claude-arsenal queue. Do NOT use to update or remove existing tasks.
user-invocable: true
argument-hint: "--title TITLE [--priority N] [--workspace NAME] [--tag TAG] [--requires surface:X] [--deps t-XXXXXXXX] [--max-attempts N]"
---

# queue-add

Creates a task as a file in the repository — `arsenal/tasks/<id>.md` — carrying its
title, priority, dependencies, and acceptance gate, then prints the issue handle to open
for it. The file is the task; the issue is only a handle, so agents can claim it and the
board stays visible.

CANARY: queue-add-loaded-2026-06-13-fb78d23e-c3d4e5f6a7b8c9d0

## When to load

Load this skill when:

- The user wants to add a task, ticket, or work item to the queue.
- Phrasing: "add a task", "queue this up", "enqueue", "/queue-add".
- Seeding the queue from a list of tasks before starting workers.

## How to use

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/new_task.py" \
  --title "Extract the surface probe into its own script" \
  --priority 5 \
  --deps t-aaaa1111 \
  --requires "surface:cli" \
  --tag CLI \
  --workspace BACKEND
```

It prints the new task id on stdout and, on stderr, the exact issue to open. Create that
issue with whatever GitHub access this surface offers — the built-in GitHub tools, `gh`,
or the REST API — with the `arsenal:task` label and the `<!-- arsenal-task: <id> -->` marker in the
body. **The marker is what links issue to task**; without it the task is invisible to the
selector, and without the label the issue is never treated as claimable work.

Use the printed id as a `--deps` argument when adding dependent tasks.

## Write a real gate

The generated file contains a deliberately failing gate. Replace it before the task is
claimed:

````markdown
## Acceptance gate

```bash
bash <the test that proves this task is done>
```
````

The fenced block is what makes a gate mechanical. Prose, and inline `single-backtick`
commands, are never executed — so a gate written as prose runs nothing, and a gate that
runs nothing passes everything. One consumer audit found 0 of 70 payloads carried a
fenced block, meaning an entire gate layer had been inert for months. `task_select.py`
reports `gate: false` for a task with no block, so the problem is visible rather than
silent, and the placeholder fails until it is replaced rather than passing by default.

Load `${CLAUDE_SKILL_DIR}/references/payload-template.md` for the fuller task-body shape:
the test names a worker should write failing first, and one reference anchor per spec
section or sibling pattern needed to start — spare them the grep.

## Gotchas

- **Deps must already exist.** `--deps` is rejected if no task file declares that id. The
  selector treats an unknown dep as unsatisfied, so a typo would otherwise block the task
  forever and silently.
- **Ids are random, not derived from the title.** Two agents adding tasks at the same time
  cannot collide, and no coordination is needed to mint one.
- **`requires` values are exact strings.** `surface:cli` or `surface:web`; an unrecognised
  value passes through but will never match a surface, so the task never becomes eligible.
- **`--tag` (repeatable) adds free-form labels.** `/continue CLI` scopes the loop to tasks
  carrying tag `CLI`. Tags are orthogonal to `--workspace` and `--requires`.
- **`--max-attempts N` (default 3) caps retries.** Each retry claims the next attempt ref;
  past the cap the task stops being offered and needs a human.
- **The task file must be merged to the default branch to count.** Task files are read
  from the default branch so every agent computes the same graph — a task on an unmerged
  branch is not yet part of the queue. That is the same rule as any other change to the
  project.
