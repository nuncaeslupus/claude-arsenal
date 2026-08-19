# Orchestrator guide

> **Superseded.** The queue described below ran on the `arsenal-queue`
> coordination branch, which no longer exists. See **`docs/queue.md`** for the
> current model and `docs/design/0001-issues-as-the-queue.md` for why it changed.
> The worker-dispatch, budget and PR sections below still describe how the loop
> fans out, but every queue command named here has been replaced.


How to operate the `claude-arsenal` task queue: one **orchestrator** session
fans out work to many **worker** subagents, each task lands as a reviewable
PR, and the loop throttles itself before exhausting your token quota.

This guide assumes the host repo has already been bootstrapped with
[`/init`](INSTALL.md). The mechanics it describes live in
`claude-arsenal/AGENTS.md` (imported into the host `CLAUDE.md`) and the scripts
under `claude-arsenal/bin/`.

---

## Mental model: orchestrator vs worker

There are two roles, and they run on two different kinds of git ref:

| | Orchestrator | Worker |
|---|---|---|
| **Count** | one per session | up to `ARSENAL_MAX_WORKERS` at a time |
| **Runs on** | the coordination branch (`arsenal-queue`) | an isolated `git worktree` on a feature branch off `origin/main` |
| **Owns** | the queue: claim, dispatch, release | one task: implement, gate, push, open a PR |
| **Spawned by** | you (`continue` / `/continue`) | the orchestrator, via the Task tool (`isolation: worktree`) |

The **orchestrator** lives on the `arsenal-queue` branch for its entire life.
That branch is the cross-session lock: every claim is a one-line commit to
`claude-arsenal/queue/tasks.jsonl` pushed to the shared `arsenal-queue` ref, and
git lets exactly one racing session fast-forward it. **The remote ref is the
lock — there is no other channel between sessions.**

Each **worker** runs in its own throwaway worktree on a feature branch cut from
the host default branch (`origin/main`), so its PR diff contains only that
task's code. Workers never touch `tasks.jsonl` and never run on `arsenal-queue`.
A worker reports its outcome (done / failed, PR URL, failure notes) back to the
orchestrator, which is the single writer that records it on `arsenal-queue`.

### The one invariant you must preserve

**`arsenal-queue` must be unprotected and pushable, and the session must run on
it.** If you protect it (required PRs/reviews), every claim push is rejected and
the loop stops with an `error:` from `claim.sh`. `queue_branch.sh` puts the
session on the branch at start-up; `claim.sh` / `release.sh` refuse to run off
it. The branch is never merged into `main` — it is a disposable, append-only
ledger of `claim:` / `release:` commits.

---

## Starting an orchestrator session

### Claude Code on the web

1. Open the repo and start a new session.
2. Type **`continue`** (the natural-language form; the web surface has no slash
   commands). This loads the `continue` skill, runs `queue_branch.sh` to enter
   `arsenal-queue`, and starts the worker loop on the next unblocked task.

The session-start protocol in the host `CLAUDE.md` also fires `continue`
behaviour automatically, so even a bare "pick up where we left off" works.

### Claude Code CLI / desktop / IDE

1. Launch `claude` in the repo.
2. Run **`/continue`**. Same flow as above, with slash-command scoping
   available (see [Scoping](#scoping-which-tasks-to-run)).

### First time in a repo

If `claude-arsenal/` does not exist yet, run **`/init`** once to scaffold it,
then seed the queue (from `status/plan.md`, from per-workspace plans, or with
`/queue-add`) and `continue`. See [`docs/INSTALL.md`](INSTALL.md).

---

## Scoping: which tasks to run

`/continue` accepts any number of **bare-word, order-independent** tokens. Each
token is resolved by membership against the live queue:

1. **Workspace** (matches a `workspace` value) → sets the workspace filter.
   At most one workspace per invocation; two distinct workspaces is an error.
2. **Tag** (matches a `tags` value) → added to the tag filter. Multiple tags
   are **ANDed** — a task must carry every requested tag.
3. **Neither** → treated as fuzzy title search text (multiple unknown tokens are
   joined into one search string).

A name that is both a workspace and a tag resolves as the **workspace** first.

```text
/continue                 # global: next unblocked task, no scoping
/continue FRONTEND        # workspace FRONTEND only
/continue CLI             # tag CLI only
/continue CLI WEB         # tag CLI AND tag WEB (no workspace)
/continue CLI FRONTEND    # tag CLI AND workspace FRONTEND
/continue FRONTEND CLI    # identical to the line above (order-independent)
/continue implement login # no match → fuzzy title search
```

Tags are a free-form label axis you attach with `/queue-add --tag CLI --tag WEB`
(repeatable). They are orthogonal to `workspace` and to the automatic
surface-capability filter (`requires` / `surface_profile.json`).

---

## Following the workers

While the loop runs, you can watch progress several ways:

- **Inline Task output** — each worker is a Task subagent; its transcript
  streams in the orchestrator session as it implements and opens its PR.
- **`git worktree list`** — shows the live worker worktrees and the feature
  branch each one is on.
- **`git log <arsenal-queue>`** — the `claim:` / `release:` ledger; one
  `claim:` and one `release:` commit per completed task. Lost claim races leave
  nothing, so this is a clean audit trail of what was picked up and finished.
- **The PRs** — each finished task opens a PR off `origin/main`. `release.sh`
  records the URL on the queue row (`"pr"` field); `git log` on `arsenal-queue`
  and `/queue-status` surface it.
- **`## Failure notes`** — a task whose gate fails is released back to `open`
  with a `## Failure notes` section appended to `claude-arsenal/queue/<id>.md`,
  written back to `arsenal-queue` so the next session can read why.

---

## Capabilities and config knobs

| Knob | Default | What it does |
|---|---|---|
| `ARSENAL_MAX_WORKERS` | `2` | Max workers dispatched per batch. `2` is the validated git-push concurrency ceiling; higher N increases claim-race churn and PR/merge-conflict surface. |
| `ARSENAL_QUOTA_STOP_PCT` | `90` | Stop the loop before dispatch when either rate-limit window is at/above this used-percentage. |
| `ARSENAL_QUEUE_BRANCH` | `arsenal-queue` | The coordination branch. Must stay unprotected and pushable. |
| `ARSENAL_QUEUE_REMOTE` | `origin` | Remote the queue branch is pushed to. |
| `LOOP_WORKSPACE` | _(unset)_ | Workspace filter; normally set by `/continue` token inference. |
| `LOOP_TAGS` | _(unset)_ | Comma/space-separated tag filter (ANDed); set by `/continue` token inference. |

### Parallel fan-out

The loop budget-checks, calls `queue_batch.sh --max $ARSENAL_MAX_WORKERS` for up
to N independent tasks (no task in the batch blocks another), claims each, then
spawns **all won workers in a single message** so they run concurrently. It
waits for the batch, runs `worker_postcheck.sh` + `release.sh` for each, and
loops. Keep `ARSENAL_MAX_WORKERS` small; release contention on `arsenal-queue`
is serialised by `release.sh`'s fetch–rebase–push retry, but churn grows with N.

Fan-out is only safe when each worker runs in its own `git worktree`. The Task
tool's `isolation: worktree` flag is **silently ignored on some surfaces** (see
the Web caveat), so the loop establishes isolation empirically: it runs
`worktree_probe.sh`, dispatches a lone first worker, and checks the post-worker
assertion (`worker_postcheck.sh`). If isolation turns out to be unavailable, it
**forces `ARSENAL_MAX_WORKERS=1` and runs serialized in-place** — one worker at
a time, with `worker_postcheck.sh` restoring HEAD to `arsenal-queue` and
cleaning the tree between tasks so the coordination ledger never carries a
worker's code. See `claude-arsenal/AGENTS.md` → *Worker loop algorithm* step 0.

### Token-budget stop

`statusline_capture.sh` (registered as the host `statusLine` command by `/init`)
writes `claude-arsenal/session/rate_limits.json` (gitignored) from the
`rate_limits` block Claude Code feeds a statusLine on stdin. Before every
dispatch, the loop runs `budget_check.sh`:

- Either window at/above `ARSENAL_QUOTA_STOP_PCT` → **exit 3**: the loop stops,
  writes `handover.md`, and reports the reset time.
- Data missing (non-Pro/Max plan, before the first response, or older Claude
  Code) → **exit 0, fail-open**: the loop runs where quota isn't observable.

Caveats: `rate_limits` is **Pro/Max subscription only** and is a snapshot at the
last message (a `refreshInterval` on the statusLine keeps it fresh). On
API/metered usage or older Claude Code the budget check fails open.

### Per-task PRs

Each worker branches off `origin/main` (never `arsenal-queue`), implements,
runs the host lint gate plus `gate_run.sh`, then:

- **Gate fails** → no PR; the orchestrator releases the task back to `open` and
  writes `## Failure notes` to the payload on `arsenal-queue`.
- **Gate passes** → the worker commits (Conventional Commits + the dynamic
  `Co-Authored-By` from the `github` skill — never a hardcoded model name),
  pushes, and opens a PR via `open_task_pr.sh`. The orchestrator records the URL
  with `release.sh done --pr <url>`.

> **Web caveat:** Claude Code on the web differs from the CLI in two ways, so
> per-task PRs **and** parallel fan-out are **CLI-first** — verify both on the
> web before relying on them there:
>
> 1. **Restricted pushes.** Git may be routed through a proxy that restricts
>    pushes to the session's designated branch (feature-branch pushes can return
>    HTTP 403).
> 2. **Silent worktree fallback.** The Task tool's `isolation: worktree` flag
>    may be silently ignored: the worker then runs in the orchestrator's shared
>    tree on `arsenal-queue`, moving its HEAD onto the feature branch and
>    leaving pre-PR edits transiently on the ledger. The loop detects this
>    (`worktree_probe.sh` + a lone first worker + `worker_postcheck.sh`) and
>    falls back to serialized `ARSENAL_MAX_WORKERS=1` in-place mode.
>
> On the CLI both are unrestricted: pushes are unproxied and `isolation:
> worktree` is honored.

---

## Queue health checks

`queue_doctor.sh` is a read-only audit of the queue and its payloads. The
orchestrator runs it at session start (advisory — it never halts the loop), and
you can run it any time:

```bash
claude-arsenal/bin/queue_doctor.sh                   # full audit (auto-enables the gh/git layers)
claude-arsenal/bin/queue_doctor.sh --fail-on error   # gate mode: non-zero exit on findings
ARSENAL_DOCTOR_OFFLINE=1 claude-arsenal/bin/queue_doctor.sh   # structural only, no gh/git
```

It reports: orphaned payloads (a `tasks.jsonl` row with no payload file, or a
payload file with no row — including one tracked only on the default branch),
broken or cyclic `deps`, crashed `in_progress` claims (no assignee), stale or
`branch:`-only `pr` fields, likely secrets committed into a payload, and — when
`gh` is present — `done`/`merged` rows whose PR is closed-unmerged (the
false-`done` case). Findings carry three severities (`error` > `warn` > `info`);
`--fail-on` (default `warn`) sets the threshold that makes the exit code
non-zero, so it doubles as a CI / `make` gate:

```yaml
# .github/workflows/queue-doctor.yml (consumer repo) — fail the build on a dirty queue
- run: claude-arsenal/bin/queue_doctor.sh --fail-on error
```

---

## Troubleshooting

- **`claim.sh` returns `error:` and the loop stops** — you are off
  `arsenal-queue`, or it is protected, or it has no upstream. Re-run
  `queue_branch.sh` or remove the branch protection. This is a misconfiguration,
  not a race; the loop is right to stop rather than spin.
- **`queue_batch.sh` returns nothing** — no unblocked task matches the current
  `LOOP_WORKSPACE` / `LOOP_TAGS` scope. Drop the scope or seed more tasks.
- **The loop stops immediately with a quota message** — `budget_check.sh` hit
  the threshold. Wait for the reported reset, raise `ARSENAL_QUOTA_STOP_PCT`, or
  clear `claude-arsenal/session/rate_limits.json` to fail open.
- **`git worktree list` shows one checkout and the orchestrator's HEAD jumped to
  a worker's feature branch** — worktree isolation was silently ignored (common
  on the web). This is expected and handled: the loop forces
  `ARSENAL_MAX_WORKERS=1` and `worker_postcheck.sh` restores HEAD to
  `arsenal-queue` between tasks. If `worker_postcheck.sh` exits 2 (could not
  restore), the tree has uncommittable state — inspect `git status`, return to
  `arsenal-queue` manually, then resume.

---

## Design decisions

### Why the queue lives in `core`, not its own plugin

The queue skills (`continue`, `queue-add`, `queue-status`, plus the runtime
tree `init` lays down) ship inside `core` rather than a standalone `queue`
plugin. This was weighed deliberately (issue #82):

- **Cohesion / opt-out is a real but minor win.** A separate plugin would let
  consumers disable the queue and group its skills together. But the queue is
  tightly coupled to `core`'s `init` (which writes the runtime tree) and
  `continue` (the orchestrator entry point); splitting it means threading that
  coupling across two plugins for a cohesion-only gain.
- **Extraction does not relieve the listing budget.** The 8000-char skills
  index cap is **global across all installed skills**, so moving descriptions
  into another plugin leaves the aggregate unchanged. The only lever that
  restores headroom is trimming descriptions — which is what we do instead
  (see below).

**Decision:** keep the queue in `core`; do not extract. Revisit only if a
consumer needs to ship the queue *without* the rest of `core`.

### Listing-budget headroom

The index cap is global. When headroom gets tight, trim the longest skill
descriptions (preserving trigger keywords and the `Do NOT` boundary that keeps
them distinct) rather than restructuring plugins. `make audit` reports the
per-plugin breakdown and remaining headroom. Reaching the repo's ≥50%-headroom
aim across the full default install set would require trimming well beyond the
few longest descriptions, at the cost of trigger coverage — so treat 50% as a
direction, and keep the longest descriptions honest rather than chasing the
exact number.
