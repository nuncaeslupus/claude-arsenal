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
The `skill-creator` plugin is the meta-skill that gates every other edit
inside a `skills/` folder.

The migration plan that built this repo is preserved in the author's
local `~/.claude/plans/` (historical reference only; v0.1.0 is the
cutover).

---

## Working in this repo

| If the task is… | Use… |
|---|---|
| Authoring or modifying a skill | `/skill-creator:skill-creator` — runs the rubric and writes findings. |
| Touching a SKILL.md / references / scripts inside a plugin | The pre-edit hook blocks unless `skill-creator` is loaded. |
| Adding a new plugin | Scaffold `plugins/<name>/.claude-plugin/plugin.json`, then add the entry to `.claude-plugin/marketplace.json`. |
| Running the rule-drift check | `make audit-rule-drift` — diffs `references/skill-rules.md` against `docs/research/claude-skill-system_v1.17.md`. |
| Checking this repo's own queue health | `make queue-doctor` — runs the queue consistency checker on `status/queue/` (dogfood). |
| Updating dependencies | `uv sync`, then commit `uv.lock`. |

The Makefile is the entry point for every routine action. Run `make help`
to list targets.

### Dogfooding the queue

This repo tracks its own review backlog as a real queue at `status/queue/`
(`tasks.jsonl` + per-task payloads, one per open review issue) so the queue
tooling runs against this project, not only against consumers. `make
queue-doctor` (and the `queue doctor` CI job) runs `queue_doctor.py` over it on
every push — orphan payloads, broken deps, false-`done`, or a leaked secret in a
payload fail the build. Each task carries an `issue` field; `--closed-issues`
flags any task whose linked GitHub issue is already closed, so the backlog and
the issues stay in sync (prune the task when its issue closes).

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

`.bundle-version` is the **single canonical version** for the whole repo.
The plugin manifests (`plugins/*/.claude-plugin/plugin.json`), the
vendored `AGENTS.md` header, and the consumer `ARSENAL_REF` pin examples
in `docs/INSTALL.md` all carry a copy of it that is **derived, never
hand-edited**: after bumping `.bundle-version`, run `make sync-version` to
propagate it. CI's `make sync-version-check` fails the build if any copy
drifts. (Historically these drifted independently — issue #80.)

Tagging is automatic via that workflow. **If GitHub Actions is unavailable**
(an outage), the tag will not be created until Actions resume — run `make tag`
from `main` as a one-command fallback (it creates+pushes `v<.bundle-version>`,
skips if it exists, and refuses a version lower than the latest tag, mirroring
the workflow).

Bump rules:
- **Patch** (`x.y.Z`) — bug fixes, doc corrections, validator tweaks.
- **Minor** (`x.Y.0`) — new skills, new workflow steps, new hooks, new flags.
- **Major** (`X.0.0`) — breaking changes to skill interfaces or plugin layout.

PRs that only touch `CLAUDE.md`, `docs/`, CI config, or `pyproject.toml`
dev tooling may skip the bump. All other PRs must include the bump commit
or the reviewer should request it before merging.

---

## What lives where (and what does not)

- **Global preferences** (Python defaults, Makefile policy, "don't add
  features beyond what was asked", "surgical changes only") live in
  `~/.claude/CLAUDE.md` and apply automatically. **Not duplicated here.**
- **Marketplace-local conventions** (plugin layout, branch policy, the
  `claude-arsenal:<plugin>:<skill>` cite form) live in **this** file.
- **Skill rubric** (the ~98 author-checkable rule rows that the
  validator enforces) lives in
  `plugins/skill-creator/skills/skill-creator/references/skill-rules.md`.
  The validator cites rule IDs back to
  `docs/research/claude-skill-system_v1.17.md § <section>`.
- **Deferred rules** (the ~91 meta-only governance IDs) live one-line-each
  in `plugins/skill-creator/skills/skill-creator/references/research-coverage.md`
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
