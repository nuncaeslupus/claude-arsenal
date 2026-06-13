# Loop Orchestrator

<!-- loop-orchestrator v0.1.0 — imported via @.loop/core/AGENTS.md -->

This file is imported by the host repo's `CLAUDE.md` via the one-line adoption:

```
@.loop/core/AGENTS.md
```

It configures the loop-orchestrator framework: worker dispatch, credit guards,
the queue protocol, and the post-compaction self-rehydration directive.

---

## Post-compaction self-rehydration

If context was just compacted and this orchestrator context is missing,
re-read `.loop/core/AGENTS.md` immediately before continuing any work.
The full loop state is in `.loop/state/`; the session's in-progress task
(if any) is in `.loop/state/handover.md`.

---

## Credit guards — apply before any Task-tool dispatch

Set these variables in the orchestrator session before spawning any worker:

```
CLAUDE_CODE_DISABLE_1M_CONTEXT=1
CLAUDE_CODE_DISABLE_FAST_MODE=1
CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001
```

**Version requirement**: Claude Code ≥ v2.1.172. Check with `claude --version`
before starting; older versions do not support `statusLine.rate_limits`.

---

## Worker loop algorithm

Run this loop when `/loop-start` is invoked:

1. Read `.loop/state/surface_profile.json` (or run `detect_surface.sh` if absent).
2. Run `.loop/core/scripts/queue_eval.sh` → task JSON on stdout, empty if exhausted.
3. If empty → loop done; report summary to user and stop.
4. Apply credit guards (step above, if not already set this session).
5. Run `.loop/core/scripts/claim.sh <task_id> <session_id>`.
   - `won` → proceed to step 6.
   - `lost` → another worker claimed it first; return to step 2.
6. Spawn **Task-tool worker subagent** (see `agents/worker.md`):
   - `isolation: worktree`
   - Inject the relative-path directive and the task payload path.
7. Worker completes → `.loop/core/scripts/release.sh <task_id> done` is called by the worker.
8. Return to step 2.

---

## Agent definitions

| Agent | File | When used |
|-------|------|-----------|
| Worker | `agents/worker.md` | Spawned via Task tool per claimed task |
| Reviewer | `agents/reviewer.md` | Cloud Routine on GitHub PR events |

---

## Queue format

Each line of `.loop/state/queue.jsonl` is a JSON object:

```json
{
  "id": "lo-a3f8",
  "title": "...",
  "status": "open|in_progress|done|blocked",
  "priority": 0,
  "requires": ["surface:cli"],
  "deps": [{"id": "lo-b2c1", "type": "blocks"}],
  "assignee": null,
  "payload": "tasks/lo-a3f8.md"
}
```

---

## State directory layout

```
.loop/
  core/         ← plugin-owned; upgraded by /loop-upgrade
    AGENTS.md
    agents/
    scripts/
    REVIEW.md
    VERSION
  state/        ← host-owned; never touched by upgrade
    queue.jsonl
    tasks/
    handover.md
    surface_profile.json
```
