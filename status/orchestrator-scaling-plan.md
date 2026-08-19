# Plan: Orchestrator scaling — per-task PRs, parallel fan-out, token-budget stop, tag/workspace scoping (+ operator guide)

> **ARCHIVED** — describes the coordination-branch queue (`arsenal-queue`, `tasks.jsonl`, `queue_eval.sh`/`claim.sh`/`release.sh`),
> replaced in v0.25.0 by task files, issue handles and atomic claim refs.
> Kept as the record of how the design got here; see `docs/queue.md` for what
> actually runs. Script names below no longer exist.

## Context

The `claude-arsenal` queue orchestrator currently runs a **strictly serial** loop: one
orchestrator session (on the `arsenal-queue` coordination branch) picks → claims → spawns
**one** Task-tool worker subagent (`isolation: worktree`) → waits → releases → repeats.
Three operational capabilities the user expected are **not implemented today**:

1. **Per-task PRs** — `worker.md` implements the task and runs `gate_run.sh`, but `release.sh`
   only commits the **queue file**. The worker's actual **code never gets committed, pushed, or
   surfaced** — it dies in the ephemeral worktree. There is no way to "check their PRs."
2. **Parallel fan-out** — a single orchestrator cannot run multiple workers at once; parallelism
   only comes from launching multiple orchestrator sessions.
3. **Token-budget stop** — no mechanism to halt the loop at a quota threshold; only the
   per-worker "credit guards" (haiku model, disabled 1M/fast mode) exist.

This plan designs all three plus a written operator guide. The pre-existing `status/specification.md`
and `status/plan.md` already establish the intent (R-WORKER-3 quota governance via
`statusLine.rate_limits`; workers as worktree Task subagents; a separate reviewer layer).

**Outcome:** one orchestrator can fan out N workers, each task lands as a reviewable PR, and the
loop self-throttles before exhausting quota — with a docs page explaining how to operate it.

> The user will execute this in a **new session**. This is plan-only.

---

## Key grounding facts (verified this session)

- Current state lives under `claude-arsenal/` (the old spec's `.loop/` names were renamed);
  scripts are in `plugins/core/skills/init/assets/bin/`, the worker def in
  `plugins/core/skills/init/assets/agents/worker.md`, the loop in `…/assets/AGENTS.md`.
- `/init` (`plugins/core/skills/init/scripts/init.py`) copies `assets/bin/*` into the host
  `claude-arsenal/bin/` (checksum-refresh) and injects `@claude-arsenal/AGENTS.md` into host `CLAUDE.md`.
  **Any new `bin/` script propagates automatically via the existing copy logic.**
- `queue_eval.sh` returns **exactly one** best task (`max(priority)`, line 75); claim/release push
  to the coordination branch by explicit refspec with race-vs-config error classification.
- `statusLine.rate_limits` (Pro/Max only, CC ≥ ~v2.1.132) is delivered **only** to a statusLine
  command's **stdin JSON**: `rate_limits.five_hour.used_percentage` (0–100), `.resets_at` (epoch),
  same for `seven_day`. Not available via env var / CLI / file unless a statusLine script writes it out.
- **Editing these files is gated** by the `skill-creator` pre-edit hook (`plugins/*/skills/*`).
  In a normal session, start with `/skill-creator` so the marker drops, then edit.
- Reuse sources: `plugins/core/skills/execution/SKILL.md` (worktree/branch pattern, lines 27–42),
  `plugins/core/skills/github/SKILL.md` (Conventional Commits, `feat/`–`fix/` naming, dynamic
  Co-Authored-By, PR body template, pre-PR lint gate), `plugins/core/skills/github/scripts/query_pr_state.py`.

---

## Deliverable 1 — Operator guide (docs, no behavior change)

**New file:** `docs/orchestrator-guide.md`, linked from `README`/`docs/INSTALL.md`.

Covers, grounded in real behavior:
- Mental model (orchestrator vs worker; coordination branch vs feature worktrees).
- Exactly how to start an orchestrator: **CC Web** (open repo → new session → `continue`);
  **CLI** (`claude` → `/continue`); first-time `/init` + queue seeding.
- How to follow workers (inline Task subagent output; `git worktree list`; `git log` on
  `arsenal-queue`; `## Failure notes` in payloads).
- The new capabilities below (per-task PRs, fan-out, budget stop, tag/workspace scoping) and their
  config knobs/caveats, including the `/continue TAG WORKSPACE` form.
- Invariants: `arsenal-queue` must be unprotected + pushable; session must run on it.

This deliverable can ship **independently** and should be written to match whatever subset of 2–5 lands.

---

## Deliverable 2 — Per-task PRs

**Goal:** each claimed task's code is committed on a feature branch off the host default branch,
pushed, and opened as a PR; gate runs before the PR; failures requeue cleanly.

**Changes:**
- **`agents/worker.md`** — extend the task-execution protocol (currently steps 1–5). New flow:
  1. **Read and cache the payload BEFORE switching branches** — copy
     `claude-arsenal/queue/<id>.md` to a temp path outside the repo (e.g. `/tmp/<id>.md`), or read it
     via `git show arsenal-queue:claude-arsenal/queue/<id>.md`. The `claude-arsenal/queue/` tree may be
     absent or stale on the default branch, so the payload must be captured first (review: line 80).
  2. Create a feature branch **from the host default branch** inside the worktree:
     `DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD || echo origin/main)`;
     `git checkout -b arsenal/<task-id>-<slug> "$DEFAULT"` (slug derived from title).
     *(Branch off `origin/main`, NOT `arsenal-queue`, so the PR diff is only the task's code.)*
  3. Implement the work using the cached payload.
  4. Run host lint gate if present (`make lint`/`npm run lint`) then `gate_run.sh <id>` —
     **gate failure → release `open` (which must commit+push the updated payload, incl. `## Failure
     notes`, back to `arsenal-queue`), do NOT open a PR, exit.**
  5. Commit (Conventional Commits + dynamic `Co-Authored-By`, per `github` skill — never hardcode model),
     `git push -u origin <branch>`, open PR via the `github` skill conventions (`## Summary` / `## Test plan` body).
  6. Release `done --pr <url>` — records the PR URL on the queue row **and** commits+pushes the
     payload/queue changes back to `arsenal-queue`; worktree edits to the payload are otherwise lost on
     cleanup (review: line 86). Exit.
  > **Design tension (line 80/86 ⇒ resolve in execution):** steps 4/6 update queue/payload state on
  > `arsenal-queue`, but the worktree is now on a feature branch, and `release.sh` *guards* on being on
  > the coordination branch. The two cannot both hold in one checkout. **Recommended resolution:** the
  > **orchestrator** (already on `arsenal-queue`) performs release + payload-writeback after the worker
  > subagent returns its outcome (`done|open`, PR URL, failure notes) — instead of the worker calling
  > `release.sh` from its feature-branch worktree. Alternatively, make release/writeback branch-agnostic
  > (operate on the coordination ref via a temp index / dedicated worktree). **See open question below.**
- **New helper `bin/open_task_pr.sh <task_id> <title>`** (thin, reused by worker): derive slug + branch,
  commit (Conventional + Co-Authored-By placeholder resolved by harness), push, create the PR, print the URL.
  Keeps `worker.md` declarative and the git/PR mechanics testable in isolation. Mirror `release.sh`
  conventions (`LANG=C`, explicit remote via `ARSENAL_QUEUE_REMOTE`/origin, backoff).
- **Queue schema** — add optional `"pr": "<url|number>"` to the row (append-compatible; older readers ignore).
  Update `release.sh` to accept an optional `--pr <url>` and persist it. `release.sh` must also stage the
  **payload file** `claude-arsenal/queue/<id>.md` (not only `tasks.jsonl`) so `## Failure notes` / PR-URL
  edits are committed+pushed to `arsenal-queue` rather than lost (review: line 86). Reflect in `AGENTS.md`
  "Queue format".
- **`worker.md` "What not to do"** — keep "don't touch tasks.jsonl directly / don't claim"; add
  "branch from the default branch, never from `arsenal-queue`."

**Reuse:** `execution` worktree/branch pattern; `github` commit/branch/PR-body/lint conventions;
`query_pr_state.py` if the orchestrator later polls.

**Risk to verify:** in CC **Web** the git proxy may restrict pushes to the session's designated branch
(we hit HTTP 403 pushing a tag/`main` this session). Per-task feature-branch pushes must be confirmed to
work on Web; on CLI this is unrestricted. Document the constraint; if Web blocks it, per-task PRs are a
CLI-first capability.

**Review layer (out of scope, note as follow-on):** `status/spec` envisions a Cloud Routine running
`/code-review` on PR-opened (R-REVIEW-1). Not built here; the operator reviews/merges, or wires the
existing `subscribe_pr_activity`/`github` loop separately.

---

## Deliverable 3 — Parallel fan-out

**Goal:** one orchestrator claims up to N independent tasks and dispatches N workers concurrently.

**Changes:**
- **New `bin/queue_batch.sh [--max N]`** — reuse all of `queue_eval.sh`'s filtering (status=open,
  blocking-deps-done, capability `requires`, workspace), but return **up to N** highest-priority tasks
  such that **no task in the batch blocks another task in the batch** (intra-batch dep check). Emit JSONL.
  Default N from `ARSENAL_MAX_WORKERS`.
- **`AGENTS.md` worker loop** — replace the serial step 2–7 with a batched version:
  1. Credit guards once per session.
  2. **Budget check** (Deliverable 4) — if over threshold, stop + handover.
  3. `queue_batch.sh --max $ARSENAL_MAX_WORKERS` → list (empty ⇒ done).
  4. For each task, `claim.sh <id>` (reuse as-is, called sequentially — each push is atomic; `lost`
     drops that task from the batch, `error` stops the loop).
  5. **Spawn all won tasks as Task-tool workers in a single message** (parallel), each `isolation: worktree`.
  6. Wait for all; each worker self-releases (`done`/`open`).
  7. Loop to step 2.
- **Default `ARSENAL_MAX_WORKERS`** — conservative **2** (R-SUBSTRATE-3 validated git-push concurrency only
  at ≤2-worker scale per `status/plan.md`). Configurable; document that higher N increases claim-race churn
  and PR/merge-conflict surface.

**Reuse (unchanged):** `worker.md`, `claim.sh`, `release.sh`, `gate_run.sh`, credit guards, worktree isolation.
Only **selection** (one→N) and **loop shape** change.

**Note:** workers are isolated by worktree, so they won't clobber each other; file-level conflicts between
two independent tasks surface at PR/merge time (acceptable, same as human parallel branches).

**Release contention (review: line 138):** concurrent worker completions trigger concurrent queue-state
pushes to `arsenal-queue`. `release.sh` **already** implements a `LANG=C` fetch–rebase(`--autostash`)–push
retry with backoff and race-vs-config error classification (built in #52/#53 follow-up), which serializes
these. Keep `ARSENAL_MAX_WORKERS` small (default 2 — the validated git-push concurrency ceiling); the
retry count may need raising if N grows. If release moves to the orchestrator (see Deliverable 2 design
tension), contention collapses to a single writer and this is moot.

---

## Deliverable 4 — Token-budget stop

**Goal:** halt the loop before quota exhaustion, at a configurable threshold.

**Mechanism (the only viable one — `rate_limits` is statusLine-stdin only):**
- **New `bin/statusline_capture.sh`** — reads statusLine stdin JSON, writes
  `claude-arsenal/session/rate_limits.json` **atomically** (write to `…/rate_limits.json.tmp` in the same
  dir, then `mv` into place) so a concurrent `budget_check.sh` read never sees a partial/corrupt file
  (review: line 149). Gitignored like `surface_profile.json`; contains `five_hour.used_percentage` +
  `seven_day.used_percentage` + `resets_at`. Still prints a short status line. Registered in host
  `.claude/settings.json` under `statusLine` with a `refreshInterval`.
- **New `bin/budget_check.sh`** — reads `rate_limits.json`; exit 0 if both windows are **under**
  `ARSENAL_QUOTA_STOP_PCT` (default **90**, set to 80 per preference), exit 3 if over (loud, distinct).
  If the file is absent/stale or data missing (non-Pro/Max, pre-first-response, old CC), exit 0 with a
  one-line warning — **fail-open** so the loop still runs where quota isn't observable.
- **`AGENTS.md`** — add the pre-dispatch budget check (Deliverable 3 step 2): over threshold ⇒ stop loop,
  write `handover.md`, report remaining % + reset time. Document in a new "Quota governance" section.
- **`/init`** — optionally write the `statusLine` block into host `.claude/settings.json` (or document it),
  and add `claude-arsenal/session/rate_limits.json` to `.gitignore` (reuse the existing gitignore step).

**Caveats to document:** Pro/Max subscription only; value is a snapshot at last message (use
`refreshInterval`); requires recent Claude Code. On API/metered or older CC, the check fails open.

---

## Deliverable 5 — Multi-axis `/continue` scoping (`/continue TAG WORKSPACE`)

**Goal:** `/continue CLI FRONTEND` runs the loop over only the tasks that carry tag `CLI`
**and** belong to workspace `FRONTEND`. Tokens are bare words, **order-independent, inferred**.
Tags (e.g. `CLI`/`WEB`) are a new free-form label axis, orthogonal to `workspace` and to the
automatic surface-capability filter (`requires`/`surface_profile.json`).

Supports **one or more tags** and **zero or one workspace** per invocation, e.g.
`/continue CLI` (1 tag), `/continue CLI WEB` (2 tags, no workspace),
`/continue CLI LINUX FRONTEND` (tags CLI+LINUX, workspace FRONTEND), `/continue` (no scoping).
A task must carry **every** requested tag (AND) and, if a workspace is given, match it.

**Changes:**
- **Schema:** add optional `"tags": ["CLI"]` (array of strings) to the queue row. Append-compatible;
  older readers ignore it. Reflect in `AGENTS.md` § Queue format.
- **`create_task.py`** (`/queue-add`): add `--tag` (repeatable) / `--tags` to set the array.
- **Selection scripts** `queue_eval.sh` + new `queue_batch.sh`: add a `LOOP_TAGS` env filter
  (comma/space-separated). A candidate qualifies only if it carries **all** requested tags
  **and** matches `LOOP_WORKSPACE` (existing). Both axes AND together; both empty ⇒ no scoping.
- **`query_task.py` + `continue/SKILL.md`:** parse **N positional tokens**. Resolve each token by
  membership, order-independent:
  1. matches a known **workspace** (distinct `workspace` values in the queue / `project/overview.md`)
     → set `LOOP_WORKSPACE` (error if two different workspaces given);
  2. else matches a known **tag** (distinct `tags` values in the queue) → add to `LOOP_TAGS`;
  3. else → fall back to existing fuzzy `--search` on title; **multiple unknown tokens are joined with
     spaces into a single search query** (review: line 190).
  Update `argument-hint` to `"[TAG | WORKSPACE | search-text] …"` and document the inferred multi-token form
  + the AND semantics in "How to use"/Gotchas.
- **`AGENTS.md`:** document `tags` in Queue format and tag×workspace scoping in the worker loop and seeding.

**Reuse:** mirrors the existing `--workspace`/`LOOP_WORKSPACE` plumbing exactly; the only new concepts are
the `tags` field and the membership-based token inference.

**Edge cases to specify:** token matching neither workspace nor tag → search-text (current behavior);
duplicate-axis collision (two workspaces) → error with a clear message; a name that is both a workspace
and a tag → resolve as workspace first (documented).

---

## Cross-cutting work

- **Bundle propagation:** new `bin/*.sh` (`queue_batch.sh`, `open_task_pr.sh`, `budget_check.sh`,
  `statusline_capture.sh`) are picked up by `init.py`'s existing `assets/bin/*` copy — confirm they're
  in the copy set and `chmod +x`. Add each to the `bin/` listing in `AGENTS.md` § State directory layout.
- **`skill-creator` gate:** begin the implementation session with `/skill-creator` (drops the marker) before
  editing anything under `plugins/*/skills/*`.
- **New env knobs** (document in `AGENTS.md` and the operator guide):
  `ARSENAL_MAX_WORKERS` (default 2), `ARSENAL_QUOTA_STOP_PCT` (default 90), `LOOP_TAGS` (selection
  filter, set by `/continue` token inference), reuse existing `LOOP_WORKSPACE` /
  `ARSENAL_QUEUE_BRANCH` / `ARSENAL_QUEUE_REMOTE`.
- **Tests** (`plugins/core/tests/`, mirror `claim_contention.sh` style — pure bash, temp git remotes):
  - `queue_batch_test.sh` — seed a DAG; assert batch excludes intra-batch-blocked tasks, respects `--max`,
    priority order, and `LOOP_TAGS`×`LOOP_WORKSPACE` AND-filtering.
  - `continue_scope_test.sh` — seed tasks with tags/workspaces; assert token inference resolves
    `CLI FRONTEND` to tag+workspace (order-independent), and unknown tokens fall back to search.
  - `budget_check_test.sh` — write synthetic `rate_limits.json` over/under threshold + missing-file; assert
    exit 0/3/fail-open.
  - `open_task_pr_test.sh` — against a bare temp remote, assert branch created off default, commit message is
    Conventional, push lands (skip actual `gh`/MCP PR creation — stub or guard).
  - Extend the fan-out path: confirm two `claim.sh` calls in a row on one batch behave (one commit each).
- **Gate:** `make smoke` + `make lint` + `make audit-rule-drift` must stay green (note: repo CI is
  billing-blocked until end of June; rely on local gates).

---

## Verification (end-to-end)

1. **Per-task PR (CLI):** `/init` a scratch repo, seed one task, `continue`; assert a feature branch off
   `main`, a commit with Conventional message, a pushed branch, an opened PR, queue row `status=done` + `pr` set.
2. **Fan-out:** seed 3 independent tasks, `ARSENAL_MAX_WORKERS=2 continue`; assert 2 workers dispatched in
   one batch, both release `done`, the 3rd picked next round; no double-claim (reuse contention semantics).
3. **Budget stop:** write `rate_limits.json` at 95%, `ARSENAL_QUOTA_STOP_PCT=90 continue`; assert the loop
   stops before dispatch, writes handover, reports reset time. Then set 10% and assert it proceeds.
   Test fail-open by deleting the file.
4. **Bash tests** above all green; `make smoke`/`lint`/`audit-rule-drift` exit 0.
5. **Scoping:** seed tasks tagged `CLI`/`WEB` across workspaces `FRONTEND`/`BACKEND`; run
   `/continue CLI FRONTEND` and assert only CLI∧FRONTEND tasks are picked; `/continue FRONTEND CLI`
   (reversed) yields the same set; an unknown token falls back to title search.
6. **Web caveat:** if testing on Web, explicitly verify a per-task feature-branch push is not 403-blocked
   by the proxy; if it is, mark per-task PRs CLI-only in the guide.

---

## Defaults chosen (override at execution time if desired)

- Worker **opens the PR itself** (one PR per task) — this is what makes "check their PRs" answerable.
- `ARSENAL_MAX_WORKERS=2` (validated concurrency ceiling), `ARSENAL_QUOTA_STOP_PCT=90`.
- Gate runs **before** the PR; gate failure requeues and opens **no** PR.
- Budget check **fails open** when quota isn't observable.

## Open design decision (surfaced by PR #53 review)

**Who performs release + payload-writeback under per-task PRs?** Because the worker switches its
worktree to a feature branch (off `main`) while queue/payload state lives on `arsenal-queue` (and
`release.sh` guards on that branch), the worker cannot both hold a feature checkout and run `release.sh`.

- **Option A (recommended):** the **orchestrator** runs release + payload-writeback on `arsenal-queue`
  after the worker returns its outcome. Cleaner contract, single queue-writer (kills release contention),
  matches the original "orchestrator dispatches/releases" intent. Cost: worker must return structured
  outcome (status, PR URL, failure notes) instead of self-releasing.
- **Option B:** make `release.sh` branch-agnostic (write the queue/payload commit onto the coordination
  ref via a temp index or a dedicated `arsenal-queue` worktree), so the worker can still self-release
  from its feature checkout. Keeps the current worker contract; more git plumbing.

Defaulting to **A** in the execution session unless decided otherwise.

## Out of scope (note as follow-ons)

- Cloud Routine `/code-review` reviewer (R-REVIEW-1) and auto-merge.
- Batch (single-commit) claim — looping `claim.sh` is simpler and reused.
- Per-surface queue partitioning / threshold `requires` expressions (already out per `status/plan.md`).
