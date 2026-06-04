# claude-arsenal

A Claude Code marketplace. One install gives any project the
`skill-creator` meta-skill (which gates every authoring or editing
change inside a `skills/` folder against a rubric) plus a generic
engineering-workflow plugin (`core`: specify → design → execution →
review → ship, plus `github`, `lsp-setup`, `session-end`, and the
Python toolchain skills `python-bootstrap`, `pypi-release`,
`coverage-gaps`, `dep-upgrade`, and `mutmut-report`).

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
Investigate why login is slow       # loads core:specify
```

### Claude Code web (vendoring)

Claude Code **on the web** has no plugin support, so vendor the skills into the
project's committed `.claude/skills/`. `docs/INSTALL.md` ships a copy-paste
`make update-skills` target (clone + pin + run `scripts/vendor-skills.sh`) to add
to the **consuming** project; then:

```bash
make update-skills                  # the target you added from docs/INSTALL.md
git add .claude/skills && git commit -m "chore: vendor claude-arsenal skills"
```

Full flow (the `vendor-skills.sh` script, the `.arsenal-vendored` marker, and
why `skill-creator` is excluded by default):
[`docs/INSTALL.md`](docs/INSTALL.md#use-on-claude-code-web-vendoring).

Full install guide and update/uninstall flow:
[`docs/INSTALL.md`](docs/INSTALL.md).
File-ownership table and customisation rule: [`docs/UPDATE.md`](docs/UPDATE.md).

---

## What's in it

| Plugin | Role |
|---|---|
| `skill-creator` | Meta-skill. Validates SKILL.md + references + scripts against the rubric. Hooks block unguarded edits inside `skills/` folders. |
| `core` | Engineering workflows: `specify`, `design`, `execution`, `review`, `ship`, `github`, `lsp-setup`, `session-end`; plus Python toolchain skills `python-bootstrap`, `pypi-release`, `coverage-gaps`, `dep-upgrade`, `mutmut-report`. |

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

MIT — see [`LICENSE`](LICENSE).
