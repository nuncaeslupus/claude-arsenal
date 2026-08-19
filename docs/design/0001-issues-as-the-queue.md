# Design 0001 — Repo-defined tasks, issue-coordinated claims

**Status:** Proposed (revision 2) — awaiting decision before implementation
**Supersedes:** the `arsenal-queue` coordination branch (`AGENTS.md` § *Queue coordination branch*)
**Addresses:** #137, #139, #142, #143, #144, #145, #146

> **Revision 2 changed the conclusion.** Revision 1 proposed moving tasks *into*
> GitHub Issues and host state into a hidden `.arsenal/`. Measurement (§ 2) and
> maintainer constraints (§ 3) rule both out. What survives is the part that was
> right — the coordination branch has to go — for a stronger reason than
> revision 1 gave.

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
| Who has claimed what, what is done | **one GitHub issue** | the only mutable channel writable from every surface |

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

This is also why there is no `queue_sync.sh` any more. Tasks arrive the way every
other file arrives: on a branch, through a PR, onto the default branch. There is
no second copy on a coordination branch to reconcile against.

### 3.2 Claiming across surfaces

One issue per repository — the **coordination issue** — holds the claim log in
its comments. To claim `T-0042`:

1. Read the task files at the current commit; compute the eligible set (deps
   satisfied, surface `requires` met).
2. Read the coordination issue's comments; a claim is live if it has no matching
   release and its lease has not expired.
3. Post `claim T-0042 session=<id>`.
4. Re-read. **The earliest comment id for that task wins**; if it is not yours,
   drop it and take the next eligible task.

Comment ids are server-assigned and totally ordered, so this is a bakery lock,
not a guess. It needs exactly two operations — *post comment* and *list
comments* — both in the guaranteed built-in tool set on every surface. It works
identically from the CLI, the desktop app, the mobile app and the web, which is
requirement 3.

**What it gives up:** GitHub's API is not linearizable across replicas, so a
narrow race can let two sessions both believe they won. The re-read bounds it
without eliminating it. The cost when it happens is two branches for one task —
visible and cheap. The current design's CAS is strictly stronger, and unusable
on the surface that matters, which makes the comparison moot.

**Why one issue and not one per task:** issue-per-task means every task
definition gets copied into an issue, which is the duplication this design
exists to remove, and it fills the tracker with rows. One issue keeps the
tracker clean and the claim log in one place. Issue-per-task remains an option
if a visible board is wanted more than a quiet tracker.

### 3.3 The public-repo concern is withdrawn

Revision 1 raised it because *task content* was moving into issues: on a public
repo, private ledger rows would have become public. Under this design task
content never leaves the repository — if the repo is public the task files are
already public, and the coordination issue carries only task ids and session
ids. There is no new exposure. Disregard that open question.

### 3.4 Layout

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

### 3.5 Configuration that survives updates

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
3. **It owns `merge-policy`** (§ 3.5) — reading it, and refusing to merge beyond
   what the consumer authorised.

---

## 6. What is still unverified

One thing, and it only affects § 4's optional improvement:

**Does a committed skills-directory plugin load on the web?** The docs say
project-scope `@skills-dir` plugins load "only after you accept the workspace
trust dialog", and it is unclear whether a cloud session satisfies that. A
canary is already pushed to the `arsenal-probe-delete-me` branch:
`.claude/skills/plain-canary/` (plain) and `.claude/skills/plugcanary/` (plugin
layout). Start one cloud session on that branch and ask which skills it sees —
`PLAIN-CANARY-4713`, `PLUG-CANARY-8829`, both, or neither. Nothing else in this
design depends on the answer.

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
2. **`arsenal/` layout + `config.toml`** (including `merge-policy`, and #143's
   budget) with migration from the current tree. Independently valuable.
3. **Task files + the pure selector** — DAG, priority, `requires`, gates, unit
   tested with no git and no network.
4. **Claim protocol + `github` skill as the access layer** (§ 5).
5. **Delete** the coordination-branch machinery and its tests.
6. **Optional:** skills-directory plugin layout, if § 6 confirms it.
