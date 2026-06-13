---
name: loop-init
description: When the user needs .loop/ set up in a host repo. Not for repos where .loop/core/ exists — use loop-upgrade instead.
user-invocable: true
argument-hint: "[--repo-path PATH]"
---

# loop-init

Bootstraps the loop-orchestrator framework in the host repository. After init, every
session automatically seeds the queue from `status/plan.md` (if present) and starts
workers — no commands needed. Run once per repo; re-running is safe (idempotent).

CANARY: loop-init-loaded-2026-06-13-fb78d23e-e401d45197396b32

## When to load

Load this skill when:

- A repo needs the loop-orchestrator set up for the first time.
- The user asks to "init the loop", "set up the task queue", or "install the orchestrator".
- `.loop/` does not exist and the user wants to start using workers.

Defer to `loop-upgrade` when `.loop/core/` already exists and only an upgrade is needed.

## How to use

```bash
python3 .claude/skills/loop-init/scripts/init_loop.py --repo-path .
```

The script:
1. Copies `.loop/core/` from the plugin bundle.
2. Creates `.loop/state/` scaffold: `queue.jsonl`, `tasks/`, `handover.md`, `surface_profile.json`.
3. Injects a session-start protocol block + `@.loop/core/AGENTS.md` import into `CLAUDE.md`.

After init, opening any session in the project will automatically:
- Seed the queue from `status/plan.md` if the queue is empty.
- Resume the worker loop if tasks are open.
- Write `handover.md` at session end.

## Gotchas

- **Idempotency requires a VERSION match.** If `.loop/core/VERSION` already exists and differs from the plugin version, the script aborts and directs to `loop-upgrade`.
- **CC Web without hooks**: `detect_surface.sh` won't auto-run, but init writes a permissive `surface_profile.json` (`surface:cli` + `surface:web`) so all tasks are eligible regardless.
- **CLAUDE.md block must be at root.** The injected block must appear in the host root `CLAUDE.md`, not a nested file.
