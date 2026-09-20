# The fleet — parallel dispatch, quota governance, and unattended ticks

> **Status:** the layer above the queue. It needs the queue
> ([`docs/queue.md`](queue.md)) underneath it — an orchestrator dispatches
> workers against the same atomic claim mechanism described there. This page
> covers what that one doesn't: several workers running at once, a budget that
> stops itself before going over, and a session running the board with nobody
> watching.
>
> The source of truth is three vendored reference files a consumer only
> receives after `/init`: `references/worker-loop.md`,
> `references/orchestrator-tick.md`, `references/quota-governance.md` (plus
> `agents/worker.md`), under `plugins/core/skills/init/assets/`. Nothing
> outside them explains the fleet today — this page exists to close that gap
> for anyone reading the repository itself, before they've installed anything.

---

## Two roles, one claim mechanism

**The orchestrator** is a live Claude Code session. It owns the board: it
claims tasks (the atomic git-ref creation from `docs/queue.md`), dispatches
workers, reviews what comes back, and merges. It is also the only side that
can ever release a claim.

**A worker** is a subagent the orchestrator dispatches via the Task tool, one
per claimed task, with `isolation: worktree`. A worker never claims or
releases anything — completion is a property of its PR merging, not a command
it runs. It reads its task file, runs the repo's `host-setup` command once,
writes the failing test (RED), implements (GREEN), runs the task gate and the
host gate, gets an independent reviewer subagent to clear the change, then
opens a PR through `open_task_pr.sh` — which writes `Closes #<issue>` and
archives the task file into `tasks/_history/` inside that same PR's diff. From
that point the merge does the rest: closing the issue, unblocking dependents.

Workers run up to `ARSENAL_MAX_WORKERS` at a time (default `2` — the
validated git-push concurrency ceiling; pushing it higher raises claim-race
churn and merge-conflict surface, not throughput).

---

## Isolation is established empirically, never assumed

The Task tool's `isolation: worktree` flag is **silently ignored on some
surfaces** — observed on Claude Code on the web, where a "worker" actually
runs in the orchestrator's own tree and moves its `HEAD`. Assuming it worked
would let concurrent workers clobber one tree, so the orchestrator proves it
instead:

1. `worktree_probe.sh` — if worktrees don't work here at all, the session
   sets `ARSENAL_MAX_WORKERS=1` and runs one worker at a time for the rest of
   the session.
2. Otherwise, the **first batch is a single worker**, and isolation is
   confirmed from that worker's own reported root, not from whether `HEAD`
   moved. The verdict is written to a sentinel
   (`arsenal/session/worktree_isolation`), and `task_select.py` reads that
   sentinel itself — a parallel batch is mechanically impossible until
   isolation is *proven*, not just requested.

A restore after a worker (`worker_postcheck.sh`) is destructive by design — a
`restored` result runs `git reset --hard && git clean -fd` in the tree it's
invoked from. That is safe only because the loop's precondition is a clean
main working tree before the first dispatch; cutting a branch or editing
there while workers are running is the one thing that turns a safety net into
data loss (a rescue ref is written first, but recovering from it is a manual
step, not automatic).

---

## Quota governance — two independent stops, not one

Before every dispatch round, `budget_check.sh` checks, in order:

1. **A refusal.** If the surface can report `status: "rejected"` (the
   vocabulary a cloud session's own session-info call returns), that stops
   the loop regardless of any percentage — a refusal is a fact already
   established, not a forecast.
2. **A percentage forecast.** `rate_limits.json`, written by a statusLine
   command from the `rate_limits` block Claude Code feeds it, gives
   `used_percentage` for the `five_hour` and `seven_day` windows. At or above
   `ARSENAL_QUOTA_STOP_PCT` (default `90`) on either one, the loop stops.
3. **A round cap**, always available regardless of the above:
   `ARSENAL_MAX_ITERATIONS` (default `50` dispatch rounds per session, `0`
   disables it).

**A statusLine is a terminal affordance.** A cloud session — the web app, the
desktop and mobile apps, a routine — never runs one, so `rate_limits.json` is
never written and the percentage check fails **open** on every round, by
design (missing data reads as "quota not observable", not as "safe"). On
those surfaces, `ARSENAL_MAX_ITERATIONS` stops being a backstop and becomes
the entire ceiling. `ARSENAL_RATE_LIMITS_FILE` exists as a seam: any
orchestrator that can learn its own quota some other way can write that path
itself and the percentage guard starts working.

### A session can see its siblings — but only report it

Every check above is scoped to *this* session. That gap was not theoretical:
nine independent orchestrators once each saw a compliant budget and shared
one five-hour window between them, because nothing compared notes. The fix
is a report, not a gate: `budget_check.sh` lists other sessions' transcript
files modified in the last `ARSENAL_CONCURRENCY_WINDOW_MIN` minutes (default
`15`) and prints how many to stderr. It never changes the exit code — recent
activity isn't proof a session is still running, and turning it into a stop
would invent a threshold nobody asked for. It's also **CLI-only in
practice**: a cloud session's container has no sibling transcripts to find,
so the check is silent there for the same reason it would be silent on a
genuinely solo run — silence on that surface means "not observable", not
"confirmed alone".

### Where the window actually went

`usage_report.py --since <date>` answers the question `budget_check.sh`
can't: which session and which *model* spent it. It separates dispatched
(worker) turns from the orchestrator's own, because that split is the only
direct evidence of what model a fleet's workers actually ran on —
`models.workers` in `arsenal/config.toml` says what *should* have run; this
says what did. The gap between the two has cost real quota with nothing
misconfigured anywhere a person could see: naming a `model:` on every Task
dispatch explicitly is the only path that reliably honors the configured
value, because cloud surfaces give every Bash call a fresh shell — an
exported env var does not survive to the next tool call.

---

## What a scheduler can and can't do

`.github/workflows/arsenal-queue.yml` runs board hygiene unattended — closing
issues a merge should have closed, releasing claims from PRs closed without
merging, opening issue handles for new task files, sweeping stale claims. It
is worth having on for exactly that.

It can never review a finding or decide what merges, because a GitHub Actions
job has no Claude session inside it. A "tick" — one bounded pass of fetch,
open PRs, review, merge, report — needs judgement at the review and merge
steps, so it can only run bound to a live, already-open interactive session.
A trigger built to spawn a **fresh session per firing** stores no MCP
connectors at creation, so a fired session has no channel to GitHub's API at
all on a surface where REST is also refused, and it blocks on the tick's
first step. A green `arsenal-queue` Actions run is evidence the hygiene ran —
it is never evidence a tick ran.

---

## Surface compatibility

No file in this project cross-tabulates runtime surface against capability
before this one. Built from what the reference docs establish directly:

| Surface | Worktree isolation | GitHub write access | Quota visibility | Can run a tick |
|---|---|---|---|---|
| CLI | Honored | Full (`gh` or REST) | Real (`rate_limits.json` via statusLine) | Yes |
| Web | Silently ignored — probed every session, clamps to 1 worker when unproven | Proxied: pushes restricted to the session's own branch; claim refs can never be deleted from here | None — round cap only | Only if bound to this same open session |
| Desktop / mobile app | Same tool grant as web | Same as web | Same as web | Same as web |
| Claude Tag (Slack), a spawned worker | N/A — never holds the orchestrator role | Plain `git` only, zero `mcp__*` tools: can push a branch, cannot open a PR or merge | N/A | No — no channel to GitHub's API |
| Routine (fresh session per firing) | N/A | No MCP connectors at creation | None | No — blocks at the tick's first step unless bound to an already-open session |

Desktop and mobile inherit the same tool grant as web by construction
(`CLAUDE_CODE_REMOTE` is set on all of them), but the specific failure modes
in the table — silent worktree fallback, restricted pushes — are documented
as directly observed on web; treat the desktop/mobile row as "the same grant,
not independently confirmed" rather than "measured".

---

## Observability without reading every PR

Three scripts, in increasing order of scope:

- **`merge_ready.sh <pr>`** — the verdict for one PR: is it mergeable right
  now, and if not, what's blocking it.
- **`pr_audit.py`** — the same verdict for every open PR at once, plus any
  claim ref that has no open PR behind it. This is the bird's-eye view: one
  row per PR (head SHA, age, CI state, review state, the computed next
  action), read without opening any of them.
- **`usage_report.py`** — not correctness, cost: turns, context, and spend
  per session and per model, over a date range.

`query_status.py` (the queue-status script) is the fourth angle, and the one
that needs no GitHub write access at all — it reads issue metadata and local
task files only, never PR content, and `--fail-on-problems` turns its audit
into something CI can gate on.

None of these read a PR's diff. They read state GitHub already tracks, which
is the point — the fleet is designed to be checked without becoming a second
reviewer of every change it produces.

---

## Configuration

The knobs that matter most, of roughly a dozen `ARSENAL_*` environment
variables (the full list is in the vendored `worker-loop.md` after `/init`):

| Knob | Default | Effect |
|---|---|---|
| `ARSENAL_MAX_WORKERS` | `2` | Workers per dispatch round. Forced to `1` when worktree isolation isn't proven. |
| `ARSENAL_QUOTA_STOP_PCT` | `90` | Stop before dispatch at/above this used-percentage, either window. |
| `ARSENAL_MAX_ITERATIONS` | `50` | Per-session dispatch-round cap. The real ceiling on any surface with no statusLine. |
| `ARSENAL_CONCURRENCY_WINDOW_MIN` | `15` | How far back to look for a sibling session's transcript (report-only). |
| `ARSENAL_RATE_LIMITS_FILE` | `<session>/rate_limits.json` | Override to feed quota data from a surface with no statusLine. |
| `models.workers` / `models.orchestrator` (`arsenal/config.toml`) | `sonnet` / unset | Which model workers dispatch as; which model this repo expects driving the orchestrator (advisory — nothing can enforce the second one). |

---

## Limits

- **CLI-first.** Parallel fan-out and per-task PRs are validated there; the
  surface table above is what's known to differ elsewhere — verify before
  relying on either on the web, desktop, mobile, Claude Tag, or a routine.
- **No self-repair without the workflow.** If
  `.github/workflows/arsenal-queue.yml` isn't installed — or GitHub Actions
  is disabled, which is the default on a fork of a consumer's repo until
  someone opts in under Settings → Actions — abandoned claims are never
  released and new task files never get an issue handle. Nothing in a
  session's own startup re-derives which claims are stale; `query_status.py
  --fail-on-problems` will surface the drift, but only if someone runs it.
- **GitHub only.** Claims, task handles, and hygiene are all GitHub's REST
  and git APIs specifically (`api.github.com` is not configurable). There is
  no path to GitLab, Bitbucket, or a plain git remote.
- **Quota governance degrades to a round cap on every cloud surface.** With
  no statusLine there is no `rate_limits.json`, and `ARSENAL_MAX_ITERATIONS`
  is what's actually stopping the loop, not a spend percentage.
