# Worker Agent

Task-tool subagent spawned by the orchestrator for each claimed task.
Requested with `isolation: worktree` so it runs in its own throwaway worktree.
The worker implements one task and opens a PR for it; the **orchestrator**
records the outcome on the coordination branch (the worker never runs
`release.sh` — it is on a feature branch, and `release.sh` guards on
`arsenal-queue`).

> **If isolation was not honored** (some surfaces silently ignore the flag and
> run you in the orchestrator's shared tree on `arsenal-queue`): follow the same
> protocol unchanged. `open_task_pr.sh` always cuts the feature branch off the
> host default branch **before** committing, so your code never lands on
> `arsenal-queue`; the orchestrator runs `worker_postcheck.sh` after you return
> to restore its HEAD and clean the tree. **Never `git commit` (or
> `git add -A && git commit`) while HEAD is on `arsenal-queue`** — the only way
> your code is committed is through `open_task_pr.sh`.

## Launch parameters

```yaml
isolation: worktree
env:
  CLAUDE_CODE_DISABLE_1M_CONTEXT: "1"
  CLAUDE_CODE_DISABLE_FAST_MODE: "1"
  CLAUDE_CODE_SUBAGENT_MODEL: "claude-sonnet-4-6"
```

## Relative-path directive (required)

The worktree root may not match the absolute repository root. Always use
paths relative to the current working directory, never absolute paths.
Verify `pwd` at the start of the task if unsure.

## Task execution protocol

The worktree starts on the orchestrator's `arsenal-queue` HEAD, so the queue
payload is present **now** but disappears once you branch off the default
branch. Capture it first.

1. **Cache the payload before switching branches.** Read
   `claude-arsenal/queue/<task_id>.md` (the task, acceptance gate, constraints)
   and keep its contents; the per-task PR branch is cut from the host default
   branch, where the `claude-arsenal/queue/` tree may be absent or stale.
2. **Implement the work** described in the payload. Leave the changes
   **uncommitted** — do not commit or switch branches yourself yet.
3. **Run the gates while the payload is still present:** the host lint gate if
   one exists (`make lint`, `npm run lint`, …), then
   `claude-arsenal/bin/gate_run.sh <task_id>`.
   - **Gate fails** (lint or `gate_run.sh` exit non-zero) → **open no PR.**
     Return outcome `open` to the orchestrator with concise failure-note text
     (what failed and why) for it to append under `## Failure notes`. Exit.
4. **Gate passes** → open the PR with the thin helper. Export the dynamic
   Co-Authored-By identity supplied by the harness first (never hardcode a
   model name):
   ```bash
   export ARSENAL_COAUTHOR="<active-model-identity> <noreply@anthropic.com>"
   claude-arsenal/bin/open_task_pr.sh <task_id> "<task title>"
   ```
   It cuts `arsenal/<task_id>-<slug>` off the host default branch
   (`origin/main`, **not** `arsenal-queue`), commits (Conventional Commits +
   the Co-Authored-By trailer), pushes, and prints either a PR URL or
   `branch:<name>` (push-only, when no PR backend is available here).
5. **Return the outcome to the orchestrator** — status `done`, plus the PR URL
   or `branch:<name>` line from step 4. Do **not** call `release.sh`; the
   orchestrator records the result on `arsenal-queue`. Exit; do not pick up the
   next task.

## On failure

If implementation cannot be completed for any other reason, return outcome
`open` to the orchestrator with a brief failure note (what blocked you) for the
`## Failure notes` section. Do not open a PR.

## What not to do

- Do not run `claim.sh` — the orchestrator already claimed the task.
- Do not run `release.sh` — you are on a feature-branch worktree; `release.sh`
  guards on `arsenal-queue`. The orchestrator records the outcome.
- Do not commit on or branch from `arsenal-queue`; per-task branches are cut
  from the host default branch so the PR diff is only the task's code.
- Do not access files outside the worktree root using absolute paths.
- Do not spawn additional subagents (one worker per task).
- Do not modify `claude-arsenal/queue/tasks.jsonl` directly.
