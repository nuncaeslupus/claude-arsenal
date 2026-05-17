# claude-arsenal

A Claude Code marketplace. One install gives any project the
`skill-creator` meta-skill (which gates every other edit inside a
`skills/` folder against a rubric) plus a generic engineering-workflow
plugin (`core`: discovery → design → execution → review →
release-readiness).

> **Status: pre-v0.1.0.** The repo is in the middle of a marketplace
> migration tracked at `docs/migration-baseline.md` and
> `~/.claude/plans/first-i-want-to-resilient-puddle.md`. Plugins land
> incrementally at S2 (`skill-creator`) and S4–S6 (`core`). Do not
> install yet — wait for the v0.1.0 tag.

---

## Install (post-v0.1.0)

Inside a Claude Code session:

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
/plugin install skill-creator@claude-arsenal   # turns on the gate
/plugin install core@claude-arsenal             # engineering workflows
```

Verify:

```text
/skill-creator:skill-creator        # loads with a canary phrase
/core:discovery                     # workflow skill is listed
```

Full install guide and update / uninstall flow: `docs/INSTALL.md`.

---

## What's in it

| Plugin | Role |
|---|---|
| `skill-creator` | Meta-skill. Validates SKILL.md + references + scripts against a 98-rule rubric. Hooks block unguarded edits inside `skills/` folders. |
| `core` | Engineering workflows: discovery, design, execution, review, release-readiness, session-summary, github. |

The active rubric is at
`plugins/skill-creator/skills/skill-creator/references/skill-rules.md`,
sourced from
`docs/research/claude-skill-system_v1.17.md` (the upstream research
archive, committed verbatim).

---

## For contributors

Dev-mode walkthrough (full version: `docs/CONTRIBUTING.md`):

```bash
git clone https://github.com/nuncaeslupus/claude-arsenal
cd claude-arsenal
uv sync
make help            # list targets
make smoke           # validate all plugins (post-S2)
claude --plugin-dir ./plugins/skill-creator --plugin-dir ./plugins/core
```

Project layout, branch policy, and the cite form are documented in
`CLAUDE.md` (internal-only — not shipped to consumers).

---

## License

TBD before v0.1.0.
