# Loop Orchestrator

<!-- loop-orchestrator v0.1.0 — imported via @.loop/core/AGENTS.md -->

This file is imported by the host repo's `CLAUDE.md` via the session-protocol block
that `/loop-init` injects. It provides the mechanics behind the proactive directives
in that block: queue seeding, worker dispatch, credit guards, and state layout.

---

## Session-start protocol

At the start of every session (fresh start, context compaction, or cold restart):

1. **Read handover.md** — if `.loop/state/handover.md` has content beyond the
   template placeholder, read it for the previous session's last task, queue
   snapshot, and continuation instructions.
2. **Run queue_eval** — `.loop/core/scripts/queue_eval.sh`.
   - Returns task JSON → go to **Worker loop algorithm**.
   - Returns empty + `status/plan.md` exists → go to **Queue seeding from plan.md**.
   - Returns empty + no plan → report done or ask user.
3. **After any session with open tasks**: write `.loop/state/handover.md` using
   the template at `.loop/core/handover.md` before ending the session.

---

## Queue seeding from plan.md

When `queue.jsonl` is empty and `status/plan.md` exists, seed the queue from the
implementation-tasks table without asking the user first.

The table columns are: `T# | Description | Location | Size | Depends | Gate | Tests`

**Steps:**

1. Add tasks with no dependencies first, capturing each printed ID:
   ```bash
   python3 .claude/skills/loop-add/scripts/create_task.py \
     --title "T1: <Description>" \
     --priority <10=S, 5=M, 1=L> \
     --queue .loop/state/queue.jsonl
   # → prints e.g. lo-a3f8
   ```

2. Add tasks whose deps are now in the queue:
   ```bash
   python3 .claude/skills/loop-add/scripts/create_task.py \
     --title "T3: <Description>" \
     --priority 5 \
     --deps lo-a3f8 \
     --queue .loop/state/queue.jsonl
   ```

3. For each task, create its payload file at `.loop/state/tasks/<id>.md`:
   ```markdown
   # T1: <Description>

   ## Acceptance gate
   <Gate column content>

   ## Tests
   <Tests column content>

   ## Location
   <Location column content>
   ```

4. Proceed to the **Worker loop algorithm**.

---

## Worker loop algorithm

Run when the queue has open tasks:

1. Apply credit guards (see below) if not already set this session.
2. Run `.loop/core/scripts/queue_eval.sh` → task JSON on stdout, empty if exhausted.
3. If empty → loop done; report summary and write handover.md.
4. Run `.loop/core/scripts/claim.sh <task_id> <session_id>`.
   - `won` → proceed to step 5.
   - `lost` → another worker claimed it; return to step 2.
5. Spawn **Task-tool worker subagent** (see `agents/worker.md`):
   - `isolation: worktree`
   - Inject relative-path directive and task payload path.
6. Worker completes → `.loop/core/scripts/release.sh <task_id> done` (called by worker).
7. Return to step 2.

---

## Credit guards — set before any Task-tool dispatch

```
CLAUDE_CODE_DISABLE_1M_CONTEXT=1
CLAUDE_CODE_DISABLE_FAST_MODE=1
CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001
```

**Version requirement**: Claude Code ≥ v2.1.172. Check with `claude --version`
before starting; older versions do not support `statusLine.rate_limits`.

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
  "title": "T1: ...",
  "status": "open|in_progress|done|blocked",
  "priority": 0,
  "requires": [],
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
    handover.md  ← template
  state/        ← host-owned; never touched by upgrade
    queue.jsonl
    tasks/
    handover.md  ← live; updated each session
    surface_profile.json
```
