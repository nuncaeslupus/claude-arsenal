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
The first plugin to land is `skill-creator` (S2) — the meta-skill that
gates every other edit inside a `skills/` folder.

Migration status lives in `docs/migration-baseline.md` (deleted at S6
once the merges of `github/` and `session-end/` land inside
`plugins/core/skills/`). The full migration plan lives at
`~/.claude/plans/first-i-want-to-resilient-puddle.md`.

---

## Working in this repo

| If the task is… | Use… |
|---|---|
| Authoring or modifying a skill | `/skill-creator:skill-creator` (once S2 lands) — runs the rubric and writes findings. |
| Touching a SKILL.md / references / scripts inside a plugin | The pre-edit hook (S2) blocks unless `skill-creator` is loaded. |
| Adding a new plugin | Scaffold `plugins/<name>/.claude-plugin/plugin.json`, then add the entry to `.claude-plugin/marketplace.json`. |
| Running the rule-drift check | `make audit-rule-drift` (S2 — diffs `references/skill-rules.md` against `docs/research/claude-skill-system_v1.17.md`). |
| Updating dependencies | `uv sync`, then commit `uv.lock`. |

The Makefile is the entry point for every routine action. Run `make help`
to list targets. Targets that depend on unported scripts exit non-zero
with a clear message until the relevant stage lands.

---

## Layout

```
.claude-plugin/marketplace.json         # marketplace manifest
docs/
  migration-baseline.md                 # S0 baseline; deleted at S6
  research/claude-skill-system_v1.17.md # the upstream research archive (lands at S2)
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

## Branch policy during migration

- Migration work lives on `feat/claude-arsenal-migration` until S8.
- The repo is renamed `my-skills` → `claude-arsenal` at S8 via `git mv`,
  preserving history.
- Do not push the migration branch to `origin` until S2 ends with a
  user-review pause (decision recorded at S0).

After v0.1.0 (S8), default policy is conventional-commits on short-lived
feature branches with PR review. The `github/` skill (post-S6 merge)
documents the canonical commit/branch format.

---

## What lives where (and what does not)

- **Global preferences** (Python defaults, Makefile policy, "don't add
  features beyond what was asked", "surgical changes only") live in
  `~/.claude/CLAUDE.md` and apply automatically. **Not duplicated here.**
- **Marketplace-local conventions** (plugin layout, branch policy, the
  `claude-arsenal:<plugin>:<skill>` cite form) live in **this** file.
- **Skill rubric** (the ~98 author-checkable rule rows that the
  validator enforces) lives in
  `plugins/skill-creator/skills/skill-creator/references/skill-rules.md`
  once S2 lands. The validator cites rule IDs back to
  `docs/research/claude-skill-system_v1.17.md § <section>`.
- **Deferred rules** (the ~91 meta-only governance IDs) live one-line-each
  in `plugins/skill-creator/skills/skill-creator/references/research-coverage.md`
  with `§` anchors back to the research doc.

---

## Cite form

When referencing a skill or its reference, use the marketplace-namespaced
form:

- Skill: `claude-arsenal:<plugin>:<skill>` (e.g. `claude-arsenal:core:discovery`).
- Reference: `claude-arsenal:<plugin>:<skill> § references/<file>.md`.
- Rubric row: cite the rule ID (e.g. `R-FM-3`) and let the validator's
  `findings.md` carry the file:line back-reference.

`R-*` and `Q-*` IDs **must not appear in SKILL.md body prose** —
`Q-EVER-1` (the content-quality scanner) enforces this. They live in
rubric rows and validator findings only.

---

## Listing budget

The skills index has an 8000-character cap (name + description per
skill). `audit_library.py plugins/*/skills --by-plugin` (S2) reports
per-plugin contribution and headroom. Aim for ≥50 % headroom across the
default install set; tell consumers to run the same audit against their
local cache when they hit the cap.
