# Design 0001 — GitHub Issues as the queue

**Status:** Proposed — awaiting decision before implementation
**Supersedes:** the `arsenal-queue` coordination branch (`AGENTS.md` § *Queue coordination branch*)
**Closes or dissolves:** #137, #139, #142, #144, #145, #146 (see § *Disposition of open issues*)

---

## 1. Why change anything

Two complaints arrived from opposite ends and turn out to be the same complaint.

**From consumers (#144):** the vendored `claude-arsenal/` tree cannot be consumed
as a `git subtree`, because host-owned state (`queue/`, `session/`, `project/`)
lives *inside* the prefix that upstream owns and overwrites. Every consumer that
tries pays for a bespoke vendor-and-assemble workaround, and every upgrade is one
mistake away from taking the task ledger with it.

**From the maintainer:** the coordination branch is unpleasant to live with.

They are the same problem. The ledger is a *file*, so it has to live somewhere in
the working tree; because it must also be written atomically by concurrent
sessions, it has to live on a *shared branch*; and because the main tree must not
change branch, that branch needs a *side worktree*. Each fix creates the next
constraint. The result is measurable:

| Concern | Lines |
|---|---|
| `queue_branch.sh` — worktree lifecycle, project-id stamping, legacy fallback | 395 |
| `queue_sync.sh` — port rows written on the default branch onto the ledger branch | 190 |
| `claim.sh` / `release.sh` — optimistic-push CAS, status transitions | 515 |
| `queue_doctor.py` + `queue_doctor.sh` — detect ledger/reality divergence | 635 |
| `queue_batch.sh` / `queue_eval.sh` — selection | 204 |
| `verify_claim.sh`, `reconcile_merged.sh`, `update_task_row.py` | 300 |
| `create_task.py`, `query_task.py`, `query_status.py` | 461 |
| **Total queue machinery** | **2,700** |

Plus 417 lines of tests that exist only to hold that machinery upright
(`claim_contention.sh` 202, `queue_project_identity_test.sh` 90,
`queue_branch_reuse_test.sh` 66, `continue_queue_dir_test.sh` 59).

Almost none of this is about *what work to do next*. It is about synthesizing a
compare-and-swap, a durable ledger, and a status-vs-reality reconciler — three
things GitHub already provides, for a repository that is already on GitHub.

---

## 2. Constraints, verified rather than assumed

Everything below was measured in a Claude Code **web** session (the surface the
whole vendoring story exists to serve), against this repository, on 2026-08-19.
They are what rules several attractive designs out.

| Probe | Result |
|---|---|
| `command -v gh` | **absent** |
| `curl https://api.github.com/repos/...` with `$GITHUB_TOKEN` | **403** — `"GitHub access is not enabled for this session"` |
| `git push origin <sha>:refs/heads/<new-branch>` | **allowed** |
| `git push origin <sha>:refs/arsenal/claims/42` | **403** |
| `git push origin <sha>:refs/notes/<name>` | **403** |
| `git push origin <sha>:refs/tags/<name>` | **403** |
| `git push origin --delete <branch>` | **403** — refs cannot be deleted |
| GitHub MCP tools (`mcp__github__*`) | **available** |

Three consequences, each of which kills a design that looks good on paper:

1. **`gh` is not the portable access path.** `reconcile_merged.sh`, the
   `--closed-issues` doctor check and `open_task_pr.sh`'s PR creation are all
   `command -v gh`-gated, so on the web surface they are silently inert *today*.
   The queue's PR-truth layer does not run where the queue most needs it.
2. **Custom ref namespaces are not usable.** A per-task lock at
   `refs/arsenal/claims/<n>` is otherwise ideal — create-only push is a true
   compare-and-swap, it needs no worktree and no checkout, and such refs are
   invisible to a normal clone (verified locally: a fresh clone's `git branch -a`
   shows only `main`). The sandbox rejects it. So do tags and notes.
3. **Refs cannot be deleted.** Any lock whose release is "delete the ref" is
   unimplementable here, and any design that accumulates per-task refs
   accumulates them permanently.

> **Read (2) and (3) together and the current design's own guarantee is
> narrower than documented:** the coordination branch works because
> `refs/heads/*` writes are allowed, but nothing on this surface can ever clean
> it up. "Its history is disposable and can be squashed any time" is not true
> from a web session.

The only writable primitive is *create-or-fast-forward a branch*. The only
portable GitHub access is *the model's own tools*. A design has to be built from
those two facts, not around them.

---

## 3. The proposal

**The issue tracker is the queue.** An issue *is* a task — not a mirror of one,
not a thing synced into one. There is no `tasks.jsonl`, no coordination branch,
no side worktree, and no sync step, because there is no second copy of the truth.

The machinery splits into three layers by what each thing actually is:

| Layer | What it is | Where it runs |
|---|---|---|
| **Ledger** | GitHub Issues — bodies, labels, assignees, sub-issues, linked PRs | GitHub |
| **Selection** | a pure function: given a JSON snapshot of issues, which task is next? | local script, no network, no git |
| **Access** | reading and writing issues | the model, via whatever it has: MCP, `gh`, or REST |

The selection layer is the only part that has to be a script, because it is the
only part that is a computation. Everything else is either GitHub's job or a
protocol step in `AGENTS.md`.

### 3.1 Task schema

Every field of today's task row has a native home. Nothing needs a parallel store.

| `tasks.jsonl` field | Where it lives now |
|---|---|
| `id` | the issue number |
| `title` | the issue title |
| `payload` (`<id>.md`) | the issue body |
| acceptance gate | a fenced ` ```bash ` block in the issue body — unchanged in meaning, `gate_run.sh` still runs it |
| `status: open` | issue open, no `arsenal:claimed` label |
| `status: in_progress` | `arsenal:claimed` + assignee |
| `status: done` | a linked PR is open (`Closes #N`) |
| `status: merged` | **issue closed — GitHub does this itself when the PR merges** |
| `status: blocked` | derived from deps, not stored |
| `status: escalated` | `arsenal:escalated` label |
| `priority` | `arsenal:p0`…`arsenal:p3` — one closed vocabulary, one documented meaning |
| `deps` | `Depends: #12, #13` in the body, and/or a native sub-issue parent |
| `requires` (surface caps) | `arsenal:needs:<cap>` |
| `workspace` | `arsenal:ws:<name>` |
| `tags` | plain labels |
| `assignee`, `claimed_at` | issue assignee; claim-comment timestamp |
| `pr` | the native PR link |
| `attempts` / `max_attempts` | `arsenal:attempt:<n>` label, bumped on each failed release |
| `issue` | **gone — it is the issue** |

Two of these are worth calling out because they delete whole categories of bug:

- **Status is derived, not stored.** Today a status field can disagree with
  reality — a `done` whose PR was never opened, an `in_progress` whose session
  died, a `merged` whose PR was closed unmerged. `queue_doctor.py` is 590 lines
  of detecting exactly that class of divergence. When "done" *means* "a linked PR
  is open", the divergence is not detected, it is unrepresentable.
- **`merged` is free.** A PR that says `Closes #N` closes the issue on merge.
  `reconcile_merged.sh` (84 lines, and inert on web anyway) has nothing left to do.

### 3.2 Claiming

Today's claim is a linearizable CAS: two sessions race to fast-forward one ref
and git lets exactly one win. The replacement is weaker, and this is the one
place the proposal genuinely gives something up. It is worth being exact about
what, and why the trade is right.

**Protocol.** To claim issue `#N`:

1. Refuse if it is closed, carries `arsenal:claimed`, has an assignee, or has an
   unsatisfied dep.
2. Post a claim comment: `<!-- arsenal-claim session=<sid> -->`.
3. Add `arsenal:claimed` and self-assign.
4. **Settle and verify:** re-read the issue's claim comments. The winner is the
   one with the earliest `created_at`, ties broken by session id. If that is not
   mine, remove my label and assignment and move on.

**Why this is enough.** The scenario the strong lock protects against is two
*orchestrator sessions* racing for one task. That is not the common case: the
fan-out model is one orchestrator dispatching N workers, and a single process
needs no distributed lock at all. Concurrent orchestrators are the rare case, and
the cost of losing the race is bounded and visible — two PRs for one issue, which
a human sees immediately and closes one of. Weigh that against what the strong
lock costs *every* consumer in the common case: a branch, a worktree, a sync
script, a project-identity guard against cross-repo contamination, and 2,700
lines. The current design pays a permanent tax to prevent a rare, cheap,
self-announcing failure.

**Honest statement of the weakening:** GitHub's API is not linearizable across
replicas, so a sufficiently narrow race can let two sessions both believe they
won. The settle-and-verify step bounds it; it does not eliminate it. If a
consumer genuinely runs concurrent orchestrators and cannot tolerate that, the
mitigation is one orchestrator per repository, not a coordination branch.

### 3.3 Where host state lives

```
claude-arsenal/          # upstream only — /init owns it, may overwrite freely
  AGENTS.md  .bundle-version  bin/  scripts/  agents/
.arsenal/                # host-owned — never touched by /init or an upgrade
  session/               # handover.md, host_branch, surface_profile.json, rescue_refs
  project/               # overview.md, <workspace>/plan.md
  cache/issues.json      # last issue snapshot (see § 4)
```

The path is `ARSENAL_HOME`, defaulting to `.arsenal/` at the repo root. Per the
consumer's argument in #144, the resolver **refuses** a path inside the upstream
prefix rather than warning about it: a `.gitignore` line is a convention, a
resolver plus a test is a mechanism. With `queue/` gone entirely and the rest
moved out, `claude-arsenal/` contains only files upstream owns — which is exactly
#144's fix (2), and what makes fix (1) (shipping the bundle as an artifact whose
root *is* the bundle) a later delivery change rather than another migration.

---

## 4. What is given up

| Loss | Mitigation |
|---|---|
| **Offline operation.** Claiming needs the network. | `.arsenal/cache/issues.json` holds the last snapshot, so `/queue-status` and selection still answer offline. Claiming fails loudly rather than silently diverging. |
| **Repos with no remote, or not on GitHub.** | Out of scope, and said so plainly rather than half-supported. `/queue-add` errors with a clear reason instead of writing a ledger nothing will ever read. |
| **Linearizable claiming.** | § 3.2 — bounded, visible, cheap failure; one orchestrator per repo if that is not acceptable. |
| **Issue-tracker noise.** Tasks that were private ledger rows become public issues. | For a public repo this is a real change in posture. Labels keep them filterable, but it should be a deliberate choice, not a surprise. |
| **API rate limits.** | The snapshot cache plus conditional requests; selection never re-fetches. |

---

## 5. Disposition of the open issues

| Issue | Under this design |
|---|---|
| #142 — open issues are invisible work | **Dissolved.** Issues *are* the queue; there is nothing to import and nothing to forget. |
| #144 — bundle is not subtree-consumable | **Fixed** by § 3.3. |
| #139 — `queue_sync.sh` path traversal | **Dissolved** with the script. |
| #146 — `priority` carries two conventions | **Fixed** by the closed `arsenal:p0..p3` vocabulary. |
| #145 — doctor never reads payload contents | **Mostly dissolved.** What survives is a body linter: does this issue carry a fenced gate block? |
| #137 — `release.sh --pr` accepts any string | **Mostly dissolved.** "Done" is derived from a real linked PR, not from a string a caller passed. |
| #140 — `.gitignore` omits `session/rescue_refs` | **Simplified** — one ignorable root. |
| #138, #147 — `worker_postcheck.sh` bugs | **Unaffected.** Still real, still to fix. The blast radius shrinks because `queue_branch.sh` no longer moves the main tree's branch. |
| #143 — hardcoded listing budget | **Independent.** Small, worth doing regardless. |
| #141 — `create_reader.py` nits | **Independent.** |

---

## 6. Migration

For a consumer already running the current design, `arsenal_migrate.py`:

1. Reads `tasks.jsonl` from the coordination branch (or the working tree).
2. Creates one issue per non-terminal task: body from the payload, labels from
   priority/workspace/tags/requires, and a `arsenal-task-id: <old-id>` marker so
   a re-run is idempotent rather than duplicating.
3. Rewrites `deps` to the new issue numbers in a second pass.
4. Records terminal tasks in a single closed summary issue rather than
   resurrecting them.
5. Moves `session/` and `project/` to `.arsenal/`.
6. Prints what to delete by hand: the `arsenal-queue` branch and the side
   worktree. **It cannot delete them itself from a web session** (§ 2, constraint
   3) — this is stated in the output rather than attempted and silently failed.

---

## 7. Staged delivery

1. **This document.** Decide before building.
2. **State relocation** (`ARSENAL_HOME`, the refusing resolver, `/init` writing
   the new layout, migration of an existing tree). Independently valuable and
   the prerequisite for everything else.
3. **Selection layer** — `queue_select.py` as a pure function over an issue
   snapshot, with the dep/priority/tag/workspace/surface logic ported from
   `queue_batch.sh` and unit-tested without git or network.
4. **Protocol rewrite** — `AGENTS.md` session protocol, claim/release,
   `/queue-add`, `/queue-status`, `/continue`, `worker.md`.
5. **Deletion** — the coordination branch machinery and its tests.
6. **Bundle packaging** (#144 fix 1) — optional, and cheap once step 2 landed.

---

## 8. Open questions

1. **Public repos.** Turning ledger rows into public issues is a visible posture
   change. Acceptable for this repo; should `/init` ask, or default to a
   `arsenal:task` label that keeps them filterable and let the consumer decide?
2. **`project/` is human-authored.** Specs and plans under `.arsenal/project/`
   are content people read and edit, and a dotdir hides them. Keep them visible
   (`docs/`-adjacent) with only machine state under `.arsenal/`, or accept the
   dotdir for the sake of one ignorable root?
3. **Does anything still need `tasks.jsonl`?** This repo dogfoods `status/queue/`
   and CI runs `queue doctor` over it. That check becomes a lint over issue
   bodies — confirm nothing else depends on the file format.
