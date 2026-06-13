---
name: loop-start
description: When the user wants to run the worker loop over queue.jsonl. Do NOT start before running loop-init.
user-invocable: true
metadata:
  type: workflow
---

# loop-start

Starts the orchestrator session that repeatedly picks the next unblocked task from the queue, applies credit guards (`CLAUDE_CODE_DISABLE_1M_CONTEXT=1`, `CLAUDE_CODE_DISABLE_FAST_MODE=1`), and launches a worker subagent in an isolated worktree via the Task tool. Loops until the queue is empty or a hard stop is requested.

CANARY: loop-start-loaded-2026-06-13-fb78d23e-574058bcc7fe3f46

## When to load

Load this skill when:

- The user says "start the loop", "run the workers", or "process the queue".
- `.loop/state/queue.jsonl` has open tasks and a worker session should run.
- The orchestrator needs to be resumed after a session boundary.

## How to use

Before starting, verify prerequisites:

```bash
# Check that .loop/ is initialized
ls .loop/core/AGENTS.md .loop/state/queue.jsonl

# Check open task count
python3 .claude/skills/loop-status/scripts/query_status.py
```

Then start the orchestrator loop:

1. Set credit guard env vars: `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` and `CLAUDE_CODE_DISABLE_FAST_MODE=1`.
2. Run `.loop/core/scripts/queue_eval.sh` to pick the next unblocked task matching surface capabilities.
3. Run `.loop/core/scripts/claim.sh <task-id>` — on `won`, launch a Task-tool worker subagent with `isolation: worktree`.
4. On `lost`, re-run `.loop/core/scripts/queue_eval.sh` immediately (another session won the race).
5. Worker completes → `.loop/core/scripts/release.sh <task-id> done` → loop back to step 2.
6. Loop exits when `.loop/core/scripts/queue_eval.sh` returns no eligible task.

## Gotchas

- **Credit guards must be set before the first Task-tool call.** Setting them after dispatch has no effect on the already-launched subagent.
- **`isolation: worktree` leaks absolute paths.** The worker prompt must include a relative-path directive (see `.loop/core/agents/worker.md`) to avoid tool calls against the wrong root.
