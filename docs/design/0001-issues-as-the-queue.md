# Design 0001 — Repo-defined tasks, issue handles, atomic claims

**Status:** Proposed (revision 4) — awaiting decision before implementation
**Supersedes:** the `arsenal-queue` coordination branch (`AGENTS.md` § *Queue coordination branch*)
**Addresses:** #137, #139, #142, #143, #144, #145, #146

> **What changed across revisions.** Rev 1 proposed moving tasks *into* GitHub
> Issues and host state into a hidden `.arsenal/`; measurement and the
> maintainer's requirements ruled both out. Rev 2 kept tasks in the repo but
> claimed them with an ordered-comment "bakery" lock, which was not atomic. Rev 3
> replaced that with a real compare-and-swap — `POST /git/refs` returns 422 when
> the ref exists — and settled the vendoring question by experiment (§ 6). Rev 4
> answers four questions rev 3 left implicit: which commit the DAG is read from
> and how a task file finds its issue (§ 3.1), how agents identify themselves
> (§ 3.3), and why merging a PR now updates the queue by itself (§ 3.4). It also
> retracts an overclaim: there *is* one small, one-directional sync step, and
> § 3.1 says so. The conclusion that has held throughout: the coordination
> branch has to go.

---

## 1. Requirements this has to satisfy

Stated by the maintainer, and treated here as non-negotiable:

1. **Always works** — every surface: Claude Code CLI, the Claude desktop and
   mobile apps, Claude Code on the web, and any sandbox those impose.
2. **Always up to date** — a session never operates on a stale bundle.
3. **Always takes tasks in order** — including two sessions open at once on
   *different* surfaces.
4. **Always installable, easily updatable.**
5. **Specs, plans and tasks are part of the project** — versioned with the code,
   not in an external system and not hidden away.

Requirement 5 is what revision 1 got wrong, and requirement 1 is what the
current design gets wrong.

---

## 2. Verified surface capabilities

Measured from a cloud session against this repository on 2026-08-19, plus the
documented contract in `code.claude.com/docs`. "Cloud" covers Claude Code on the
web, the mobile and Desktop apps, Claude Tag and routines — [the docs state all
of them run in the same cloud environments](https://code.claude.com/docs/en/cloud-environments).

| Capability | CC CLI (local) | Cloud session |
|---|---|---|
| Install plugins / marketplaces | yes | **no** — `/plugin` "aren't available" |
| Committed `.claude/skills/` | yes | yes |
| `gh` CLI | if installed | **no** — absent, and not in *Installed tools* |
| GitHub REST via `curl` + `$GITHUB_TOKEN` | yes | **no** — 403, verified |
| Built-in GitHub tools (issues, PRs, comments) | only if configured | **yes, always** |
| GitHub GraphQL / **Projects v2** | yes | **no** — proxy serves a pinned set only |
| `git clone` / `fetch` | yes | yes |
| `git push` to the session's **working branch** | yes | yes |
| `git push` to **another branch** | yes | **documented as blocked** (see below) |
| `git push` to custom refs / tags / notes | yes | **no** — 403, verified |
| `git push --delete` (any ref) | yes | **no** — 403, verified |
| Create a ref via the GitHub API (`POST /git/refs`) | yes | **yes** — 422 on collision, verified |
| Arbitrary outbound network | yes | depends on the environment's access level |

Three quotes carry most of the weight:

> **"Push protection: `git push` works only against the session's current
> working branch; cloning, fetching, and PR operations work normally."**

> **"Cloud sessions include built-in GitHub tools that let Claude read issues,
> list pull requests, fetch diffs, and post comments without any setup."**

> **"GitHub operations use a separate proxy that is independent of this
> setting"** — i.e. GitHub keeps working even at network access level **None**.

**Why there is no `gh`:** it is not a Claude-app quirk and not a bug. Cloud
sessions ship `git, jq, yq, ripgrep, tmux, vim, nano` and no `gh`, and real
GitHub credentials are deliberately kept outside the VM — "authentication is
handled through a secure proxy using scoped credentials." The session gets a
scoped git credential plus the built-in GitHub tools; it never gets a token it
could spend on the API directly. That is why `curl` with `$GITHUB_TOKEN` returns
403 while `git push` succeeds.

### 2.1 The finding that decides the design

The coordination branch requires pushing to a branch that is **not** the
session's working branch. That is the one git operation the cloud sandbox
documents as unsupported.

It currently succeeds anyway — verified: this session pushed to an unrelated
branch and to an unrelated ref-namespace, and only the branch push was allowed.
So enforcement today is looser than the contract. **Building on that is building
on leniency that is documented to be withdrawn.** The maintainer's instinct
about the queue branch turns out to be right for a sharper reason than
ergonomics: it is the least portable primitive available, and it is the load
bearing one.

### 2.2 What *is* portable

Two channels are available on every surface:

- **The repository itself** — clone and fetch anywhere; push to your own working
  branch anywhere.
- **GitHub Issues and PRs** — guaranteed in cloud sessions through the built-in
  tools, independent of network access level; on the CLI through `gh` or a
  configured MCP server.

Anything the design needs must be built from those two. Nothing else qualifies.

---

## 3. The design

**The repository defines the work. Issues coordinate who is doing it.**

| Concern | Where it lives | Why |
|---|---|---|
| Specs, plans, task definitions, the **DAG**, acceptance gates | **files in the repo** | requirement 5; versioned, reviewable, offline, no second copy |
| Which task is next | **computed locally** from those files | deterministic, no network |
| Visibility: the board, who is on what | **one `arsenal:task` issue per task** | the only mutable channel writable from every surface |
| The claim itself (mutual exclusion) | **an atomic ref, `arsenal/claims/<id>`** | `POST /git/refs` is a real compare-and-swap (§ 3.3) |

### 3.1 Where the DAG is stored

In the task files, in the repo. One file per task:

```markdown
---
id: T-0042
title: Extract the surface probe into its own script
priority: 2
deps: [T-0038, T-0039]
requires: [surface:cli]
---

## Acceptance gate
```bash
bash tests/surface_probe_test.sh
```
```

The DAG is the union of the `deps` fields — versioned with the code, reviewed in
the PR that adds the task, and readable with no network. Ordering is a pure
function over that set plus the claim state, so **"take tasks in order" never
depends on a network call being available**, only on which tasks are claimed.

**Which version of the repo?** Always the **default branch**, fetched at session
start — never the session's own working branch. Every agent therefore computes
the identical DAG no matter what branch it happens to be on. A task is not part
of the graph until its file is merged, which is the same rule as any other
change to the project.

**How a task file finds its issue.** The issue body carries a marker:

```
<!-- arsenal-task: T-0042 -->
```

Scanning the `arsenal:task` issues yields the whole task-id → issue-number map,
so nothing has to be written back into the task file. That matters: the file
stays pure project content, and there is no chicken-and-egg between "create the
issue to learn its number" and "commit the file that stores it".

**The one sync step, stated honestly.** A task file merged to the default branch
with no issue yet is invisible work. So there *is* a reconcile — "for every task
file without an `arsenal:task` issue, create one" — and earlier revisions of this
document oversold "no sync at all". The difference from `queue_sync.sh` is what
it does: this one is **one-directional** (files → issues) and **idempotent**,
creating a missing handle and nothing else. It never reconciles *state* in two
directions, which is where the old script's conflicts and path-traversal bug
(#139) came from. If it fails to run, work is delayed, never corrupted.

**Why not put the deps in the issues instead?** It is the obvious alternative and
it does remove the mapping entirely — `Depends: #123` in the issue body, or
native sub-issues. It is rejected because it moves the dependency graph out of
the project: it stops being versioned, stops being reviewable in the PR that
introduces it, and stops being readable offline. That is requirement 5. The
issue may still *mirror* the deps as `#`-references so GitHub renders the links,
but the files remain authoritative.

**Blocked means "closed as completed by a merged PR"** — not merely "closed". An
issue closed by hand, or as not-planned, must not unblock its dependents, or a
stray close silently releases work that was never done.

This is also why there is no `queue_sync.sh` any more. Tasks arrive the way every
other file arrives: on a branch, through a PR, onto the default branch. There is
no second copy on a coordination branch to reconcile against.

### 3.2 Task handles: one issue per task, labelled

Each task file gets a GitHub issue that acts as its **handle**, not a copy of it.
The body is a stub:

```
Task T-0042 — defined in `arsenal/tasks/T-0042.md`

<!-- arsenal-task: T-0042 -->
```

Every such issue carries the label **`arsenal:task`**. That label is the
boundary between machine-managed work and ordinary issues people file: nothing
without it is ever treated as claimable, so a feature request or a discussion
thread can never be picked up by a worker. It is also what makes #142 work in
the useful direction — file an issue from a phone, label it, and it becomes a
task once its task file lands.

Because the definition stays in the repo and the issue holds only a pointer,
there is no second copy to reconcile, and therefore no `queue_sync.sh`.

### 3.3 Claiming — atomic, not probabilistic

Two different things can go wrong, and they need different mechanisms. Revision
2 conflated them.

**S1 — never take work someone else already holds.** A human assigns themselves
an issue, or another agent is already on it. This is not a race: the assignment
happened long before. It is a precondition check, and it is exact. Refuse to
claim if the issue is closed, carries `arsenal:claimed`, has an assignee, or has
an open linked PR.

**S2 — two Claude sessions racing for the same free task.** This *is* a race,
and it needs a real lock. Note that assignee cannot resolve it: every session
authenticates as the same GitHub identity, so "is it assigned?" cannot tell two
sessions apart. It distinguishes humans from the machine (S1) and nothing else.

GitHub provides an atomic primitive for S2, verified against this repository:

```
POST /repos/{owner}/{repo}/git/refs   →  422 "Reference already exists"
```

**Creating a ref is a compare-and-swap.** Exactly one concurrent creator gets
201; every other gets 422. It is server-side, it is documented behaviour, and it
is reachable through the built-in GitHub tools that § 2 established are
available on every surface — no `gh`, no git push, no worktree, no coordination
branch.

So the claim protocol is:

1. Compute the eligible set locally from the task files (deps satisfied,
   `requires` met).
2. **S1 check** on the candidate's issue: open, no assignee, no
   `arsenal:claimed`, no open linked PR.
3. **S2 claim**: create `arsenal/claims/T-0042` at the base commit.
   - **201** — the claim is yours. Nobody else can hold it. Then mark the issue:
     self-assign and add `arsenal:claimed`, so humans can see it in the UI.
   - **422** — another session holds it. Take the next eligible task.
4. Work the task, open the PR with `Closes #N`.

There is no settle interval, no tie-break, and no window in which two sessions
both believe they won. The bakery scheme in revision 2 is withdrawn: it was the
best available before this primitive was found, and it is strictly worse.

**Retries and stale claims.** A ref cannot be deleted from a cloud session (§ 2,
verified), so a claim ref is not released — it is superseded. Attempt *n* claims
`arsenal/claims/T-0042.a<n>`, bounded by the task's `max-attempts`. A crashed
session therefore blocks nothing: the next attempt takes the next ref.

**Agent identity.** The claim is recorded on the issue as a comment naming the
session, so a human can always see *which* agent holds a task and open it:

```
Claimed by session cse_01VXiATzWWmYhFYV6ZqXpG18
https://claude.ai/code/cse_01VXiATzWWmYhFYV6ZqXpG18
```

The identifier resolves in this order: `CLAUDE_CODE_REMOTE_SESSION_ID` (a
`cse_…` id that is also a session URL, so the claim is clickable), then
`CLAUDE_CODE_SESSION_ID` (a local session uuid), then a hard failure.

**There is no `CLAUDE_SESSION_ID`, and the current code depends on it.**
`claim.sh:24` reads `${CLAUDE_SESSION_ID:-"session-$$"}`; that variable is not
set on this surface — verified — so every claim today is attributed to a
**process id**. That is why the ledger carries meaningless assignees and why
`queue_doctor` needs a "crashed claim (no assignee)" check. Falling back to `$$`
must be removed rather than carried over: an identifier that does not identify
anything is worse than refusing to claim.

**The cost, stated plainly.** Claim refs accumulate — roughly one per task ever
claimed, grouped under `arsenal/claims/` so they collapse in GitHub's branch
UI. They can be pruned from a CLI session or a scheduled job, never from a cloud
session. This is the price of a guarantee that holds on every surface, and it is
the one real drawback of this design.

**One caveat consumers must be warned about:** creating a ref fires GitHub's
`push`/`create` events. A repository whose workflows trigger on unfiltered
`on: push` would run CI on every claim. `/init` must check for this and tell the
consumer to scope their workflows:

```yaml
on:
  push:
    branches-ignore: ['arsenal/**']
```

### 3.4 Completion is a property of merging

This is the failure the current design has that nothing else fixes: **merging a
PR and updating the queue are two separate acts, and the second gets forgotten.**
`release.sh` has to be run, `reconcile_merged.sh` has to be run, and on cloud
sessions `reconcile_merged.sh` cannot run at all because it is `gh`-gated (§ 2).

With an issue handle, the PR body carries `Closes #N` and **GitHub closes the
issue itself when the PR merges**. There is no second act to forget. That single
property removes `release.sh`'s status bookkeeping, `reconcile_merged.sh`
entirely, and the whole false-`done` class of bug (#137) — a task cannot be
recorded complete without a real merged PR, because the recording *is* the merge.

Two caveats that must be documented, or this quietly does not work:

1. **Only into the default branch.** GitHub closes linked issues when the PR
   merges into the repository's *default* branch. A PR merged into some other
   base does not close anything.
2. **Stacked PRs need the keyword in the commit message.** This repo's own
   `CLAUDE.md` mandates stacking for multi-PR work, where intermediate PRs target
   the previous branch rather than `main`. For those, a `Closes #N` in the *PR
   body* never fires. Put it in the **commit message**, which closes the issue
   when that commit finally lands on the default branch.

### 3.5 The public-repo concern is withdrawn

Revision 1 raised it because *task content* was moving into issues: on a public
repo, private ledger rows would have become public. Under this design the issue
is a stub — a title, a pointer to the task file, and a label. The content it
points at is already in the repository, at the same visibility. Nothing is
exposed that was not exposed before. Disregard that open question.

### 3.6 Layout

```
arsenal/                 # host-owned. Project content: visible, versioned, yours
  config.toml            # host configuration — never written by an update
  specs/  plans/         # specifications and plans
  tasks/T-0042.md        # task definitions + DAG + gates
  session/handover.md    # session state
.claude/skills/          # vendored upstream — regenerated, never hand-edited
```

`arsenal/` is deliberately **not** a dotdir: requirement 5 says specs and plans
are project content that people read and edit, and hiding them contradicts that.
Upstream owns `.claude/skills/` and may overwrite it freely; it scaffolds
`arsenal/` on first init and never writes there again. That is #144's fix —
the vendored prefix contains only upstream content — reached without hiding the
consumer's own work.

### 3.7 Configuration that survives updates

Everything a consumer can tune lives in `arsenal/config.toml`, which upstream
never rewrites. Skills read it; nobody edits a skill to configure behaviour.

```toml
# How far must a task PR get before it may merge?
#   always              — merge as soon as it is open
#   after-ci            — merge once CI is green
#   after-ci-and-review — also wait for a bot/human review, if one exists
#   never               — never merge; the human reviews every PR
merge-policy = "after-ci"

test-discipline = "test-first"       # or test-after
session-end     = "handoff"          # handoff | ticket | none
listing-budget  = 8000               # #143 — the audit's budget, per consumer
```

This replaces the `<!-- flag: value -->` HTML comments currently scattered in the
host `CLAUDE.md`. Those work, but they are three different syntaxes in a file
whose main job is prose, and a consumer cannot see the whole configuration in
one place. One file, one format, and it answers #143 (a hardcoded 8000-char
budget a consumer cannot change) with the same mechanism rather than a bespoke
flag.

`merge-policy` is asked once, at `/init`, and written to the file — never asked
again, and never lost to an upgrade.

---

## 4. Installation and updates

Vendoring stays, because on cloud sessions `/plugin` is unavailable and a
committed `.claude/skills/` is the only channel. What improves:

- **A pinned ref and a single command.** `arsenal/config.toml` records the
  pinned upstream version; one `make arsenal-update` re-vendors and rewrites the
  pin. Nothing else in the repo is touched, because upstream no longer owns
  anything outside `.claude/skills/`.
- **Possibly real plugin semantics on the CLI from the same tree.** The docs
  describe *skills-directory plugins*: a committed `.claude/skills/<name>/` with
  a `.claude-plugin/plugin.json` loads as `<name>@skills-dir` with no marketplace
  and no install step. If that layout also degrades to plain skills on the web,
  one committed tree serves both surfaces — plugin on the CLI, plain skills on
  the web. **Unverified — see § 6.**

---

## 5. Should the `github` skill change?

Yes, and it has a concrete bug.

1. **It must become the GitHub access layer.** Today scripts call `gh` directly
   and gate on `command -v gh`, so on cloud sessions `reconcile_merged.sh`, the
   `--closed-issues` doctor check and `open_task_pr.sh`'s PR creation are
   silently inert — they degrade to nothing exactly where the queue runs. The
   skill should probe once for the available channel (built-in tools → `gh` →
   none), record it, and be the single documented way every other skill asks for
   a GitHub operation. "No `gh`" must stop meaning "skip the step".
2. **`projects=v2` cannot work on cloud** and should be removed or marked
   CLI-only. The proxy "serves only a pinned set of GraphQL operations", and
   Projects v2 is GraphQL-only: "Claude can't reach GitHub APIs that exist only
   in GraphQL, such as Projects v2, through the proxy." The flag currently
   promises something unreachable on half the surfaces.
3. **It owns `merge-policy`** (§ 3.7) — reading it, and refusing to merge beyond
   what the consumer authorised.

---

## 6. Canary result — vendoring stays flat

**Measured, not assumed.** A cloud session was run against a checkout carrying
both layouts side by side:

| Layout | Loaded on the web? |
|---|---|
| `.claude/skills/plain-canary/SKILL.md` | **yes** — appeared as `plain-canary` |
| `.claude/skills/plugcanary/.claude-plugin/plugin.json` + `skills/plug-canary/SKILL.md` | **no** — never reached the session |

So § 4's optional improvement is dead: a skills-directory plugin committed to
`.claude/skills/` does **not** load on the web. Vendoring stays flat, exactly as
it is today.

The probe also surfaced a footgun worth documenting for consumers: the plugin
directory was ignored *entirely* — not merely demoted to a plain skill — because
`plugcanary/` has no `SKILL.md` at its own top level. A consumer who arranges a
vendored tree that way ships **nothing**, silently, with no error. The vendoring
script should reject any directory under `.claude/skills/` that has no top-level
`SKILL.md`.

---

## 7. Disposition of the open issues

| Issue | Under this design |
|---|---|
| #144 — bundle is not subtree-consumable | **Fixed** — upstream owns only `.claude/skills/`; `arsenal/` is the consumer's. |
| #142 — open issues are invisible work | **Fixed differently.** Tasks are repo files, so nothing is invisible; an issue can be imported by adding a task file that references it. |
| #139 — `queue_sync.sh` path traversal | **Dissolved** — no coordination branch, so no sync script. |
| #146 — `priority` carries two conventions | **Fixed** — one documented `priority` field in the task front-matter. |
| #143 — hardcoded listing budget | **Fixed** by `arsenal/config.toml`. |
| #145 — doctor never reads payload contents | **Mostly dissolved**; what remains is a lint over task files for a fenced gate block. |
| #137 — `release.sh --pr` accepts any string | **Mostly dissolved** — merge state is read from GitHub, not passed as a string. |
| #140 — `.gitignore` omits `session/rescue_refs` | **Simplified** — one host-owned root. |
| #138, #147 — `worker_postcheck.sh` bugs | **Unaffected.** Still real; smaller blast radius once nothing switches the main tree's branch. |
| #141 — `create_reader.py` nits | **Independent.** |

---

## 8. What gets deleted

`queue_branch.sh` (395), `queue_sync.sh` (190), `reconcile_merged.sh` (84),
`verify_claim.sh` (86), `update_task_row.py` (130), and the four tests that exist
only to hold the coordination branch upright (417) — **1,302 lines outright**.
`claim.sh`, `release.sh`, `queue_doctor.py` and `queue_batch.sh` (1,354) are
rewritten far smaller: selection becomes a pure function over task files, and the
ledger-vs-reality divergence most of `queue_doctor.py` detects stops being
representable.

A worktree-free proof of the alternative was run before writing this: a ledger
branch *can* be read, modified and compare-and-swapped with pure plumbing
(`cat-file`, `mktree`, `commit-tree`, `push --force-with-lease=<ref>:<sha>`) with
no checkout and no worktree — 395 lines of worktree lifecycle were never
necessary even for the current design. It is recorded here because it is the
fallback if the issue-based claim ever proves insufficient, and because it
shows the branch machinery was accidental complexity, not a requirement.

---

## 9. Staged delivery

1. **This document.** Decide first.
2. **`arsenal/` layout + `config.toml`** (including `merge-policy` and #143's
   listing budget), with migration from the current tree. Independently
   valuable, and the prerequisite for the rest.
3. **Task files + the pure selector** — DAG, priority, `requires`, gates. Unit
   tested with no git and no network.
4. **Claim protocol** (§ 3.3) and the `github` skill as the access layer (§ 5),
   including the `on: push` warning at `/init`.
5. **Delete** the coordination-branch machinery and its tests.
6. **Harden vendoring** — reject a `.claude/skills/` subdirectory with no
   top-level `SKILL.md`, per § 6.

Two fixes worth pulling forward into stage 2, because they are live bugs rather
than design work: the `CLAUDE_SESSION_ID` fallback to `$$` (§ 3.3), and the
`gh`-gated steps that silently no-op on cloud sessions (§ 5).
