---
name: loop-init
description: When the user needs .loop/ set up in a host repo. Not for repos where .loop/core/ exists — use loop-upgrade instead.
user-invocable: true
argument-hint: "[--repo-path PATH]"
---

# loop-init

Bootstraps the loop-orchestrator framework in the host repository by copying the `.loop/core/` tree, creating an empty `.loop/state/` scaffold, and inserting the `@.loop/core/AGENTS.md` import line into the host `CLAUDE.md`. Run once per repo; re-running is safe (idempotent via the upgrade path).

CANARY: loop-init-loaded-2026-06-13-fb78d23e-e401d45197396b32

## When to load

Load this skill when:

- A repo needs the loop-orchestrator set up for the first time.
- The user asks to "init the loop", "set up the task queue", or "install the orchestrator".
- `.loop/` does not exist and the user wants to start using workers.

Defer to `loop-upgrade` when `.loop/core/` already exists and only an upgrade is needed.

## How to use

```bash
# Step 1 — copy core/ from the plugin bundle into the host repo
python3 .claude/skills/loop-init/scripts/init_loop.py --repo-path .

# Step 2 — verify the result
ls .loop/core/ .loop/state/
grep "@.loop/core/AGENTS.md" CLAUDE.md
```

The script copies `.loop/core/` from the plugin's bundled tree, creates
`.loop/state/queue.jsonl` (empty), `.loop/state/tasks/`, and
`.loop/state/handover.md` (placeholder). It then appends the one-line
import to `CLAUDE.md` if not already present.

## Gotchas

- **Idempotency requires a VERSION match.** If `.loop/core/VERSION` already exists and differs from the plugin version, the script aborts and directs to `loop-upgrade`.
- **CLAUDE.md import must be at root.** The `@.loop/core/AGENTS.md` line must appear in the host root `CLAUDE.md`, not a nested file, for post-compaction re-injection to work.
