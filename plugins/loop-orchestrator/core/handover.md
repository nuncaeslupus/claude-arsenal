# Loop Session Handover

<!-- Written by /loop-start at the end of each orchestrator session. -->
<!-- A new session reading this file alone can resume without additional context. -->

## Last task

- **ID**: <!-- e.g. lo-a3f8 -->
- **Title**: <!-- task title -->
- **Status at handover**: <!-- open | in_progress | done | blocked -->
- **Payload**: <!-- e.g. .loop/state/tasks/lo-a3f8.md -->

## What was done this session

<!-- One-paragraph summary of work completed. Include commit SHAs if relevant. -->

## What remains

<!-- Bulleted list of sub-tasks or acceptance-criteria items not yet met. -->

## How to continue

1. Read `.loop/core/AGENTS.md` for the worker loop algorithm.
2. Run `.loop/core/scripts/queue_eval.sh` to get the next unblocked task.
3. If the last task is still `in_progress` with no active assignee, run:
   `.loop/core/scripts/release.sh <task_id> open` to requeue it first.
4. Then proceed with the standard loop-start protocol.

## Surface profile at handover

<!-- Copy of .loop/state/surface_profile.json contents for quick reference. -->

## Queue snapshot at handover

<!-- Output of: python3 .claude/skills/loop-status/scripts/query_status.py --detail -->
