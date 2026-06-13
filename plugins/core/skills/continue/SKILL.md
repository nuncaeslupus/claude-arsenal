---
name: continue
description: When the user wants to resume work or run the worker loop — picks the next unblocked task, optionally scoped to a workspace or matched by title text. Use /continue [workspace|text]. Do NOT use before running init.
user-invocable: true
argument-hint: "[WORKSPACE | search-text]"
---

# continue

Resumes session work by picking the next unblocked task from the queue and running the worker loop. Optionally scoped to a workspace or a fuzzy-matched task title.

CANARY: continue-loaded-2026-06-13-fb78d23e-b2c3d4e5f6a7b8c9

## When to load

Load this skill when:

- The user types `/continue`, "continue", "resume", "run the workers", or "WORKSPACE: Continue".
- The session needs to pick up where a previous session left off.
- The user provides a workspace name or task search string after the command.

## How to use

```bash
# Pick globally best unblocked task
python3 .claude/skills/continue/scripts/query_task.py

# Scope to a workspace
python3 .claude/skills/continue/scripts/query_task.py --workspace FRONTEND

# Fuzzy-match a task title
python3 .claude/skills/continue/scripts/query_task.py --search "implement login"
```

Then proceed with the **Worker loop algorithm** from `claude-arsenal/AGENTS.md`:
1. Read workspace context: `claude-arsenal/project/<workspace>/context.md` and `handover.md`.
2. Claim the task using the bundle claim script (see `claude-arsenal/AGENTS.md` § Worker loop algorithm).
3. Spawn worker subagent.
4. Release on completion using the bundle release script.
5. Loop back to step 1.

## Gotchas

- **`WORKSPACE: Continue`** as natural language (e.g. "FRONTEND: Continue") is equivalent to `/continue FRONTEND` — scope to that workspace.
- **Blocked workspace**: if `LOOP_WORKSPACE=X queue_eval.sh` returns empty but global queue has tasks, report what's blocking and offer to fall back to global queue.
- **No open tasks**: if the queue is empty but workspace plans exist, seed from plans first (see AGENTS.md "Queue seeding").
