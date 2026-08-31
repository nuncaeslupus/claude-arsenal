# claude-arsenal — internal CLAUDE.md

This file is **internal to the `claude-arsenal` marketplace**. It is not
shipped to consumers; it describes how Claude operates *inside this repo*
during plugin development. Consumer projects use their own `CLAUDE.md`.

It does **not** redeclare global preferences from `~/.claude/CLAUDE.md` —
those still apply when you operate here. This file only adds the
marketplace-local conventions on top.

---

## What this repo is

`claude-arsenal` is a Claude Code marketplace. Plugins live at
`plugins/<name>/`; each plugin ships skills, hooks, and optional agents.
The `skill-workshop` plugin is the meta-skill that gates every other edit
inside a `skills/` folder.

The migration plan that built this repo is preserved in the author's
local `~/.claude/plans/` (historical reference only; v0.1.0 is the
cutover).

---

## Working in this repo

| If the task is… | Use… |
|---|---|
| Authoring or modifying a skill | `/skill-workshop:skill-workshop` — runs the rubric and writes findings. |
| Touching a SKILL.md / references / scripts inside a plugin | The pre-edit hook blocks unless `skill-workshop` is loaded. |
| Adding a new plugin | Scaffold `plugins/<name>/.claude-plugin/plugin.json`, then add the entry to `.claude-plugin/marketplace.json`. |
| Running the rule-drift check | `make audit-rule-drift` — diffs `references/skill-rules.md` against `docs/research/claude-skill-system_v1.17.md`. |
| Checking what a change costs a consumer's context | `make context-budget` — reports the resident/on-invocation/on-demand tiers and fails over the resident cap. |
| Checking this repo's own queue health | `make queue-doctor` — runs the queue consistency checker on `status/queue/` (dogfood). |
| Updating dependencies | `uv sync`, then commit `uv.lock`. |
| Bumping `.bundle-version` | Also add a `## [<version>]` entry to `plugins/core/skills/init/assets/CHANGELOG.md` — CI's `version-bump` job requires the heading; see § Versioning. |

The Makefile is the entry point for every routine action. Run `make help`
to list targets.

### Dogfooding the queue

This repo runs its own backlog on the same queue consumers get: task files in
`arsenal/tasks/`, one `arsenal:task` issue per task as its handle. `make
queue-doctor` (and the `queue doctor` CI job) runs `query_status.py` over it on
every push with `--fail-on-problems`, so a task with no fenced gate, no issue
handle, or a dep no task file declares fails the build.

`arsenal/tasks/` is currently empty, which makes that check pass vacuously — it
is a guard on the backlog, not evidence there is one. Add task files as review
work comes in rather than treating a green `queue-doctor` as a full dogfood.

**This repo does not run `arsenal-queue.yml` itself.** The workflow ships in
`plugins/core/skills/init/assets/workflows/` and `/init` installs it into a
*consumer's* `.github/workflows/`, where it calls `claude-arsenal/scripts/…`.
Upstream has no vendored `claude-arsenal/` prefix — it is the source of it — so
those paths do not resolve here. The dogfood covers the task files and the board;
the workflow's behaviour is covered by `plugins/core/tests/queue_hooks_test.sh`,
which exercises its planners directly.

---

## Layout

```
.claude-plugin/marketplace.json         # marketplace manifest
docs/
  research/claude-skill-system_v1.17.md # the upstream research archive
  INSTALL.md, UPDATE.md, CONTRIBUTING.md # consumer + dev docs
plugins/
  <plugin>/.claude-plugin/plugin.json   # per-plugin manifest
  <plugin>/hooks/hooks.json             # if the plugin ships hooks
  <plugin>/skills/<skill>/SKILL.md      # the actual skill content
  <plugin>/skills/<skill>/references/   # lazy-loaded references
  <plugin>/skills/<skill>/scripts/      # helper scripts (uv run python …)
  <plugin>/skills/<skill>/evals/        # eval prompts + loading verification
  core/skills/init/assets/workflows/    # shipped Actions, installed by /init
  core/skills/init/assets/CHANGELOG.md  # consumer-facing changelog, one entry per bump
Makefile                                # dev entry point
pyproject.toml                          # uv + ruff + mypy config
```

---

## Branch policy

Default policy is conventional-commits on short-lived feature branches
with PR review. The `github` skill documents the canonical
commit/branch format.

The repo was renamed `my-skills` → `claude-arsenal` at v0.1.0 via the
GitHub Settings UI (preserves history and sets up redirects); no
`git mv` was performed on the working tree.

### Multi-PR autonomous work — stacking rule

When a plan produces **N PRs that will be merged in sequence**, follow the stacking rule documented in the `github` skill's SKILL.md (shipped to consumers). Key points: branches must stack from the start, and **only the last PR in the stack bumps `.bundle-version`** — intermediate PRs ship content at the current version. After each merge, rebase the next branch with `--onto` to skip the now-merged commits.

---

## Versioning — mandatory on every PR

Every PR that ships user-visible changes **must** bump
`plugins/core/skills/init/assets/.bundle-version` before merging.
The `tag-release` workflow reads this file on every push to `main` and
creates a new git tag (`v<version>`) automatically if it does not already
exist. Consumer projects pin to these tags to re-vendor the marketplace.

The same PR must also add a `## [<version>] - <date>` entry to
`plugins/core/skills/init/assets/CHANGELOG.md` describing the change from a
downstream consumer's point of view — a new skill, flag, option, or breaking
change, not an internal refactor. CI's `version-bump` job fails the build if
the bumped version has no matching heading there (it checks the heading
exists, not that the content is useful — write one worth reading). This is
not paperwork: `/init`'s upgrade banner and `check_update.sh` print the
entries between a consumer's installed version and the one they're updating
to, automatically, on every update — a blank or lazy entry is a blank message
in every consumer's session.

`.bundle-version` is the **single canonical version** for the whole repo.
The plugin manifests (`plugins/*/.claude-plugin/plugin.json`), the
vendored `AGENTS.md` header, and the consumer `ARSENAL_REF` pin examples
in `docs/INSTALL.md` all carry a copy of it that is **derived, never
hand-edited**: after bumping `.bundle-version`, run `make sync-version` to
propagate it. CI's `make sync-version-check` fails the build if any copy
drifts. (Historically these drifted independently — issue #80.)

Tagging is automatic via that workflow. **If GitHub Actions is unavailable**
(an outage, no runners, a spending limit), the push-triggered run never fires
and the release ships **untagged** — which is invisible from here but breaks
every consumer: `check_update.sh` gates on the newest tag, so they keep being
told the previous version is the latest. This has happened twice (`v0.20.4`,
`v0.21.0`).

Two things now cover it:

- `tag-release.yml` also runs on a daily `schedule` and on `workflow_dispatch`,
  so a tag missed during an outage is created automatically once Actions
  recovers. It is a no-op when the tag already exists.
- `make tag` from `main` remains the immediate fallback (creates+pushes
  `v<.bundle-version>`, skips if it exists, refuses a version lower than the
  latest tag, mirroring the workflow).

### Tagging is NOT automatic when Actions is down — ask the user to do it

**After merging any version bump, run `make release-check`.** It asks the remote
— not the local repo — whether `v<.bundle-version>` is published. Never assume
the workflow ran.

When it reports `NO TAG`, **a Claude session usually cannot fix it**: the git
proxy in a cloud session (web, desktop and mobile apps, Claude Tag, routines)
rejects pushes to `refs/tags/*`, so `make tag` will create the tag locally and
fail to publish it. Verified, not assumed.

So in that situation the rule is: **stop and ask the user to run it from their
own machine.** Say it plainly, with the command and the reason:

> `v<version>` is merged but not tagged, and I cannot push tags from this
> session. Consumers gate updates on the newest remote tag, so until this runs
> they will keep being told the previous version is current:
> ```
> git checkout main && git pull && make tag
> ```

Do not treat this as a minor loose end and do not let it fall off the end of a
session — an untagged release looks completely fine from inside this repo while
being invisible to every consumer of it. That is exactly how `v0.20.4` and
`v0.21.0` shipped untagged.

Never work around it by editing `check_update.sh`, moving a consumer's pin to a
branch, or telling the user the release is done. The only fix is a real tag on
the remote.

Bump rules:
- **Patch** (`x.y.Z`) — bug fixes, doc corrections, validator tweaks.
- **Minor** (`x.Y.0`) — new skills, new workflow steps, new hooks, new flags.
- **Major** (`X.0.0`) — breaking changes to skill interfaces or plugin layout.

PRs that only touch `CLAUDE.md`, `docs/`, CI config, the `Makefile`, or
`pyproject.toml` dev tooling may skip the bump — none of it is vendored by a
consumer, which is exactly what the `version bump` CI job checks: it requires a
bump only when `plugins/*/skills/`, `plugins/*/.claude-plugin/` or
`.claude-plugin/` changes. All other PRs must include the bump commit, or the
reviewer should request it before merging.

---

## What lives where (and what does not)

- **Global preferences** (Python defaults, Makefile policy, "don't add
  features beyond what was asked", "surgical changes only") live in
  `~/.claude/CLAUDE.md` and apply automatically. **Not duplicated here.**
- **Marketplace-local conventions** (plugin layout, branch policy, the
  `claude-arsenal:<plugin>:<skill>` cite form) live in **this** file.
- **Skill rubric** (the ~98 author-checkable rule rows that the
  validator enforces) lives in
  `plugins/skill-workshop/skills/skill-workshop/references/skill-rules.md`.
  The validator cites rule IDs back to
  `docs/research/claude-skill-system_v1.17.md § <section>`.
- **Deferred rules** (the ~91 meta-only governance IDs) live one-line-each
  in `plugins/skill-workshop/skills/skill-workshop/references/research-coverage.md`
  with `§` anchors back to the research doc.

---

## Cite form

When referencing a skill or its reference, use the marketplace-namespaced
form:

- Skill: `claude-arsenal:<plugin>:<skill>` (e.g. `claude-arsenal:core:specify`).
- Reference: `claude-arsenal:<plugin>:<skill> § references/<file>.md`.
- Rubric row: cite the rule ID (e.g. `R-FM-3`) and let the validator's
  `findings.md` carry the file:line back-reference.

`R-*` and `Q-*` IDs **must not appear in SKILL.md body prose** —
`Q-EVER-1` (the content-quality scanner) enforces this. They live in
rubric rows and validator findings only.

---

## Context budget — the standing constraint

This marketplace is a skill set for working *better* with Claude, and a session's
context window is the resource it is spending to do that. A skill that occupies
context it does not earn back makes every session that installs it slightly
worse at everything else. So context cost is a first-class review criterion
here, alongside correctness — not a nice-to-have someone gets to later.

**`make context-budget`** puts a number on it. It reports three tiers, which
matter because they are paid on completely different schedules:

| tier | what is in it | when it is paid |
|---|---|---|
| **Resident** | vendored `AGENTS.md` + the `name`/`description` of every **installed** skill | every turn of every session, forever |
| **On invocation** | one `SKILL.md` body | once, when that skill triggers |
| **On demand** | `references/`, agent definitions | only when something opens them |

The listing is billed **per install**, not per repo: the report resolves each
skill's `section:` through `init.py`'s own profiles and prints one row per
install a consumer can reach — `minimal`, `general` (what `/init` gives you),
`python`, `all`, and `maximal`. A default-off section costs nothing to anyone
who did not enable it, and a plugin `/init` never vendors (`skill-workshop`)
costs nothing to anybody. Read the `general` row to see what a change did to
everyone, and the `maximal` row to see what it did to the person who opted in.

The resident tier is capped (`RESIDENT_TOKEN_BUDGET` in the Makefile, currently
5000 tokens) and CI fails over it — applied to `maximal`, the largest bill a
consumer can choose. When a change pushes it over, move what grew
behind a reference or into a script — **do not raise the cap.** The cap is the
composite of two guards that already existed: `bundle_refs_test.sh` holds
`AGENTS.md` to 250 lines, and `make audit` holds the skills index to 8000
characters (see *Listing budget* below).

### The four moves, in order of preference

Every token question here has come down to one of these. Reach for them in this
order, because each is strictly cheaper than the one after it:

1. **A script, not a paragraph.** Anything deterministic — ordering, resolution,
   parsing, a consistency check — belongs in a script whose output is a line or
   two, not in prose the model is asked to remember and re-derive. `task_select.py`
   exists because "which task is next" is a computation, and a computation
   charged to context is charged on every session that runs it.
2. **Narrow the fetch, not the reader.** When a step tells a session to pull data
   in, say which fields. The session-start protocol asks for `number`, `title`,
   `state`, `labels`, `assignees` and pointedly not `body`: on a 40-issue board
   that is ~1.2k tokens instead of ~9k, for the same answer. Any new instruction
   that lands external data in context states its field list.
3. **Shape before prose.** When a step says to follow an existing file, name the
   cheap way to read it — `bin/outline.sh` prints declarations only, 25–33×
   smaller than the file — and open the body only where the logic actually
   matters. This repo writes long rationale docstrings deliberately; they are
   for someone judging a design, not for someone copying a signature.
4. **On demand, not resident.** Content only some sessions need goes in
   `references/` with a concrete "load this when…" trigger. A reference costs
   nothing until it is opened; a paragraph in `AGENTS.md` costs every session
   that never needed it.

### What this asks of a change

State the context cost of anything that adds to the resident tier, or that puts
data in context on a path a session takes every time. "It is only a few lines"
is a claim about the diff, not about the cost — the cost is those lines times
every turn of every session in every consumer repo. If a step genuinely needs
the tokens, say why it earns them; that is a fine answer, and an unexamined one
is not.

Cost claims in this repo are measured, not estimated by eye. Both the numbers
above came from real boards and real files, and `make context-budget` is there
so the next one can be too.

## Listing budget

The skills index has an 8000-character cap (name + description per
skill). Locally, `make audit` reports per-plugin contribution and
headroom; under the hood it runs
`audit_library.py plugins/*/skills --by-plugin`, which is also what
consumers should point at their own `~/.claude/plugins/cache` when they
hit the cap. Aim for ≥50 % headroom across the default install set.

---

## Host-repo CLAUDE.md flags consumed by core skills

Core skills read optional HTML-comment markers from the **host repo's**
`CLAUDE.md` (not this one) to adapt their behavior. This is the full
registry of flags a core skill honors:

- `<!-- test-discipline: test-first | test-after -->` — default
  `test-first`. Read by `execution`: `test-after` writes tests alongside
  the change instead of failing-test-first (see `execution` Step 2a).
- `<!-- session-end: handoff=yes | ticket | no -->` — no default (the
  skill asks once, then writes the marker). Read by `session-end`: `yes`
  writes `status/handoff.md`; `ticket` and `no` skip it (Step 1).
- `<!-- github-skill: projects=classic | v2 | none -->` — auto-detected
  on first run. Read by `github` to skip GitHub Projects re-detection in
  later sessions.

Markers are per-host-repo and optional; absent a marker each skill uses
its default (or asks once, for `session-end`).

### This repo's own markers

The registry above describes what a *consumer's* `CLAUDE.md` may set, but
`claude-arsenal` is itself a host repo whenever a session runs inside it, so the
markers it sets for its own sessions live here:

<!-- session-end: handoff=no -->

`handoff=no` because the ledger here is already the merged work — the PRs, the
`skill-workshop` improvements log, and the vendored docs under
`plugins/core/skills/init/assets/`. `status/specification.md` and
`status/plan.md` are archived records of a design that never shipped, not a live
plan a handoff would keep current, so a `status/handoff.md` would be a fourth
place to keep in sync and the first to go stale.
