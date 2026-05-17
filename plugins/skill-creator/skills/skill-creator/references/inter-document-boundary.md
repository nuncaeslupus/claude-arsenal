# Inter-document boundary

## Contents

- [The four surfaces](#the-four-surfaces)
- [Decision rules](#decision-rules)
- [Common mistakes](#common-mistakes)
- [When to delete instead](#when-to-delete-instead)

Load when deciding whether a piece of information belongs in a SKILL,
in `CLAUDE.md`, in `docs/`, or in code comments.

## The four surfaces

| Surface | Loaded | Targeted at | Example |
|---|---|---|---|
| `CLAUDE.md` (root + nested) | **Always**, every session | The agent, every task | Repo invariants, conventions, branch naming. |
| `docs/<topic>.md` `@`-imported from `CLAUDE.md` | **Always**, every session — same as `CLAUDE.md` | Humans (browser) + agent (auto-loaded) | Long-form invariants like coding conventions; the `@`-import is a length-relief mechanism for `CLAUDE.md`. |
| `docs/<topic>.md` not `@`-imported | **Read-on-demand**, by link or grep | Humans first, agent when explicitly pointed | Architecture write-ups, runbooks, research archives. |
| `.claude/skills/<skill>/SKILL.md` | **On demand**, when triggered | The agent, for one capability or workflow | "How do I fetch a Jira ticket?" |
| `.claude/skills/<skill>/references/*.md` | **On demand**, after the skill is in context | The agent, deep details | "What's the cosine threshold?" |

`@`-import in `CLAUDE.md` is `@docs/path/to/file.md`. The imported
file becomes part of `CLAUDE.md`'s loaded payload — semantically
identical to inlining its contents. Use it when the content belongs
in `CLAUDE.md` by load-semantics but is too long to live there
directly, or needs to render cleanly for humans browsing the repo.

### `@`-import is a project-memory-layer feature

`@`-import is the canonical anti-duplication tool **at the
project-memory layer only** — i.e. `CLAUDE.md` and `AGENTS.md`.
Recursive depth limit: **5 hops**. `@` directives inside fenced code
blocks are not evaluated.

**Skills do not use `@`-import.** A `SKILL.md` must not `@`-import
another file; references/ are loaded by following markdown links
after the skill is in context, not by import expansion. The
validator warns on any `@docs/...` or `@<file>.md` directive inside
`SKILL.md` or its references — it's outside the documented contract
for the skill layer.

### `CLAUDE.md` length

The Anthropic guidance is explicit: `CLAUDE.md` is loaded in **full**
regardless of length — there is no truncation cap (unlike `MEMORY.md`,
which is capped at 200 lines or 25KB). The 200-line figure for
`CLAUDE.md` is a *target*, not a truncation cap. Going over warns
because adherence quality drops, not because content is lost.

### `AGENTS.md` interop

If the repository serves multiple agents (Claude Code + Codex /
Cursor / Aider), the canonical pattern is:

1. Put cross-tool invariants in `<root>/AGENTS.md`.
2. `<root>/CLAUDE.md`'s **first content line** is `@AGENTS.md`.
3. Claude-specific additions follow that import.

Symlinking `CLAUDE.md` to `AGENTS.md` is a documented failure mode
in CI pipelines (ENOENT crash), so use the `@AGENTS.md` import
instead. The validator enforces both (first-line position; not a
symlink).

## Decision rules

Use this ladder when adding a new piece of information.

1. **Does every task in the repo need to know this?**
   - Yes, and it fits in a handful of bullets ⇒ `CLAUDE.md` directly.
   - Yes, and it is long-form (multiple sections, worked examples) ⇒
     `docs/<topic>.md` and `@`-import from `CLAUDE.md`. Same load
     semantics; just factored out for readability.
   - No ⇒ continue.
2. **Is this a procedure the agent runs only when a specific trigger
   fires?**
   - Yes ⇒ that capability or workflow's `SKILL.md`.
   - No ⇒ continue.
3. **Is it a deep detail (worked example, full check list, rule
   derivation) that the agent only needs in a fraction of activations
   of one skill?**
   - Yes ⇒ that skill's `references/`.
   - No ⇒ continue.
4. **Is it long-form, mostly for humans, occasionally for the agent
   when explicitly pointed?**
   - Yes ⇒ `docs/`.

## Common mistakes

- **Big project rules in a SKILL.** If the rule applies regardless of
  task ("we use 4-space indents"), put it in `CLAUDE.md` so it is
  always loaded. A SKILL only fires for its trigger.
- **Capability prose in `CLAUDE.md`.** If the rule applies only when
  doing one specific kind of task (e.g. running a particular service
  workflow), it does not belong in the always-loaded file. Move it
  into the matching skill.
- **Skill reference material `@`-imported into `CLAUDE.md`.** A
  skill's `references/<topic>.md` is meant to load only when the
  skill is in scope. `@`-importing it from `CLAUDE.md` makes it
  always-loaded and breaks the lazy-loading budget. If the content
  is genuinely always-needed, move it out of the skill into a
  standalone `docs/<topic>.md` and `@`-import that.
- **Long worked examples in the SKILL body.** Promote them to
  `references/`. The body should fit in a short read.
- **Cross-skill prose links.** A SKILL never links to another skill's
  SKILL or references. Mention by name; let the model load.

## When to delete instead

If a rule is no longer in force, delete its mention. Never leave
"~~~old behaviour~~~" or "(deprecated; do not do this)" — the agent
reads both and gets confused. Git history preserves the old text.
