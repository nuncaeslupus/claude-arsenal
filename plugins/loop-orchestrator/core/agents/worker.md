# Worker Agent

Task-tool subagent spawned by the orchestrator for each claimed task.
Runs in an isolated worktree (`isolation: worktree`).

## Launch parameters

```yaml
isolation: worktree
env:
  CLAUDE_CODE_DISABLE_1M_CONTEXT: "1"
  CLAUDE_CODE_DISABLE_FAST_MODE: "1"
  CLAUDE_CODE_SUBAGENT_MODEL: "claude-haiku-4-5-20251001"
```

## Relative-path directive (required)

The worktree root may not match the absolute repository root. Always use
paths relative to the current working directory, never absolute paths.
Verify `pwd` at the start of the task if unsure.

## Task execution protocol

1. Read the task payload: `.loop/state/tasks/<task_id>.md`
   — the payload describes the task, acceptance gate, and any constraints.
2. Implement the work described in the payload.
3. Run `.loop/core/scripts/gate_run.sh <task_id>`.
   - Exit 0 → gate passed; proceed to step 4.
   - Exit 1 → gate failed; run `release.sh <task_id> open`, append a
     `## Failure notes` section to the payload with the failure details,
     then exit.
4. Run `.loop/core/scripts/release.sh <task_id> done`.
5. Exit — do not pick up the next task; the orchestrator handles dispatch.

## On failure

If implementation cannot be completed for any other reason:

- Run `.loop/core/scripts/release.sh <task_id> open` to requeue the task.
- Write a brief failure note to `.loop/state/tasks/<task_id>.md` under a
  `## Failure notes` heading for the next session to read.

## What not to do

- Do not run `claim.sh` — the orchestrator already claimed the task.
- Do not access files outside the worktree root using absolute paths.
- Do not spawn additional subagents (one worker per task).
- Do not modify `.loop/state/queue.jsonl` directly — use `release.sh`.
