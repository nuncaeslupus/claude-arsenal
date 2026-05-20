# claude-arsenal

A Claude Code marketplace. One install gives any project the
`skill-creator` meta-skill (which gates every authoring or editing
change inside a `skills/` folder against a rubric) plus a generic
engineering-workflow plugin (`core`: discovery → design → execution →
review → release-readiness, plus `github`, `lsp-setup`, and
`session-end`).

---

## Install

Inside a Claude Code session:

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
/plugin install skill-creator@claude-arsenal   # turns on the gate
/plugin install core@claude-arsenal             # engineering workflows
```

Verify:

```text
Help me create a new skill          # loads skill-creator (with the canary phrase)
Investigate why login is slow       # loads core:discovery
```

Full install guide and update/uninstall flow:
[`docs/INSTALL.md`](docs/INSTALL.md).
File-ownership table and customisation rule: [`docs/UPDATE.md`](docs/UPDATE.md).

---

## What's in it

| Plugin | Role |
|---|---|
| `skill-creator` | Meta-skill. Validates SKILL.md + references + scripts against the rubric. Hooks block unguarded edits inside `skills/` folders. |
| `core` | Engineering workflows: `discovery`, `design`, `execution`, `review`, `release-readiness`, `github`, `lsp-setup`, `session-end`. |

The active rubric is at
[`plugins/skill-creator/skills/skill-creator/references/skill-rules.md`](plugins/skill-creator/skills/skill-creator/references/skill-rules.md),
sourced from
[`docs/research/claude-skill-system_v1.17.md`](docs/research/claude-skill-system_v1.17.md)
(the upstream research archive, committed verbatim).

---

## For contributors

Dev-mode walkthrough (full version: [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)):

```bash
git clone https://github.com/nuncaeslupus/claude-arsenal
cd claude-arsenal
uv sync
make help            # list targets
make smoke           # validate all plugins
make dev             # claude --plugin-dir ./plugins/skill-creator --plugin-dir ./plugins/core
```

Project layout, branch policy, and the cite form are documented in
[`CLAUDE.md`](CLAUDE.md) (internal-only — not shipped to consumers).

---

## License

TBD before v0.1.0.
