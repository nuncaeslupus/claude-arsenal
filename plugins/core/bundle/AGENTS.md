# Claude Arsenal

<!-- claude-arsenal v0.2.0 — imported via @claude-arsenal/AGENTS.md -->

This file is imported by the host repo's `CLAUDE.md` via the session-protocol block
that `/init` injects. It provides the mechanics behind the proactive directives
in that block: queue seeding, worker dispatch, credit guards, and state layout.

---

## Session-start protocol

At the start of every session (fresh start, context compaction, or cold restart):

1. **Read handover.md** — if `claude-arsenal/session/handover.md` has content beyond the
   template placeholder, read it for the previous session's last task, queue
   snapshot, and continuation instructions.
2. **Run queue_eval** — `claude-arsenal/bin/queue_eval.sh`.
   - Returns task JSON → go to **Worker loop algorithm**.
   - Returns empty + workspace plans exist → go to **Queue seeding from workspace plans**.
   - Returns empty + `status/plan.md` exists → go to **Queue seeding from plan.md**.
   - Returns empty + no plan → report done or ask user.
3. **After any session with open tasks**: write `claude-arsenal/session/handover.md` using
   the template at `claude-arsenal/session/handover.md` before ending the session.

---

## Queue seeding from workspace plans

When `claude-arsenal/queue/tasks.jsonl` is empty and workspace plans exist (per
`claude-arsenal/project/overview.md`), seed the queue from each workspace's plan
without asking the user first.

For each workspace listed in the overview:
1. Read `claude-arsenal/project/<workspace>/plan.md` for the implementation-tasks table.
2. Seed tasks for that workspace using `--workspace <NAME>` flag on `create_task.py`.

The table columns are: `T# | Description | Location | Size | Depends | Gate | Tests`

**Steps:**

1. Add tasks with no dependencies first, capturing each printed ID
   (priority: S=10, M=5, L=1):
   ```bash
   python3 .claude/skills/queue-add/scripts/create_task.py \
     --title "T1: <Description>" \
     --priority 10 \
     --workspace FRONTEND \
     --queue claude-arsenal/queue/tasks.jsonl
   # → prints e.g. lo-a3f8
   ```

2. Add tasks whose deps are now in the queue:
   ```bash
   python3 .claude/skills/queue-add/scripts/create_task.py \
     --title "T3: <Description>" \
     --priority 5 \
     --workspace FRONTEND \
     --deps lo-a3f8 \
     --queue claude-arsenal/queue/tasks.jsonl
   ```

3. For each task, create its payload file at `claude-arsenal/queue/<id>.md`:

   ```markdown
   # T1: <Description>

   ## Acceptance gate
   <Gate column content — prose describing what must be true.>

   If the check is mechanically runnable, also add a bash block:
   ```bash
   bash tests/my_feature_test.sh
   ```
   gate_run.sh executes this block automatically before release.sh done.
   Prose-only gates are verified by worker judgment with no script run.

   ## Tests
   <Tests column content>

   ## Location
   <Location column content>
   ```

4. Proceed to the **Worker loop algorithm**.

---

## Queue seeding from plan.md

When `claude-arsenal/queue/tasks.jsonl` is empty and `status/plan.md` exists, seed
the queue from the implementation-tasks table without asking the user first.

The table columns are: `T# | Description | Location | Size | Depends | Gate | Tests`

**Steps:**

1. Add tasks with no dependencies first, capturing each printed ID
   (priority: S=10, M=5, L=1):
   ```bash
   python3 .claude/skills/queue-add/scripts/create_task.py \
     --title "T1: <Description>" \
     --priority 10 \
     --queue claude-arsenal/queue/tasks.jsonl
   # → prints e.g. lo-a3f8
   ```

2. Add tasks whose deps are now in the queue:
   ```bash
   python3 .claude/skills/queue-add/scripts/create_task.py \
     --title "T3: <Description>" \
     --priority 5 \
     --deps lo-a3f8 \
     --queue claude-arsenal/queue/tasks.jsonl
   ```

3. For each task, create its payload file at `claude-arsenal/queue/<id>.md`:

   ```markdown
   # T1: <Description>

   ## Acceptance gate
   <Gate column content — prose describing what must be true.>

   If the check is mechanically runnable, also add a bash block:
   ```bash
   bash tests/my_feature_test.sh
   ```
   gate_run.sh executes this block automatically before release.sh done.
   Prose-only gates are verified by worker judgment with no script run.

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
2. Run `claude-arsenal/bin/queue_eval.sh` → task JSON on stdout, empty if exhausted.
3. If empty → loop done; report summary and write handover.md.
4. Run `claude-arsenal/bin/claim.sh <task_id> <session_id>`.
   - `won` → proceed to step 5.
   - `lost` → another worker claimed it; return to step 2.
5. Spawn **Task-tool worker subagent** (see `agents/worker.md`):
   - `isolation: worktree`
   - Inject relative-path directive and task payload path.
6. Worker completes → `claude-arsenal/bin/release.sh <task_id> done` (called by worker).
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

---

## Queue format

Each line of `claude-arsenal/queue/tasks.jsonl` is a JSON object:

```json
{
  "id": "lo-a3f8",
  "title": "T1: ...",
  "status": "open|in_progress|done|blocked",
  "priority": 0,
  "requires": [],
  "deps": [{"id": "lo-b2c1", "type": "blocks"}],
  "assignee": null,
  "workspace": "FRONTEND",
  "payload": "lo-a3f8.md"
}
```

---

## State directory layout

```
claude-arsenal/
  AGENTS.md           ← this file; imported via @claude-arsenal/AGENTS.md
  agents/
    worker.md         ← worker subagent definition
  bin/                ← shell scripts; refreshed by /init on re-run
    queue_eval.sh
    claim.sh
    release.sh
    gate_run.sh
    detect_surface.sh
    workspace_list.sh
  project/            ← host-owned; never touched by /init re-run
    overview.md       ← workspace index
    <WORKSPACE>/
      spec.md
      plan.md
      context.md
      handover.md
  queue/              ← host-owned; never touched by /init re-run
    tasks.jsonl       ← the DAG queue
    <id>.md           ← task payloads
  session/            ← host-owned; never touched by /init re-run
    handover.md       ← live; updated each session
    surface_profile.json  ← gitignored; written by detect_surface.sh hook
```
