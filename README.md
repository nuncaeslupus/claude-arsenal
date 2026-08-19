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

Claude Code **on the web** (claude.ai/code) has no `/plugin` or marketplace
support — it only reads skills **committed into the project** at
`.claude/skills/`. So vendor them there. `docs/INSTALL.md` ships a copy-paste
`make update-skills` target (clone pinned `ARSENAL_REF` → `scripts/vendor-skills.sh`)
to add to the **consuming** project; then:

```bash
make update-skills                  # the target you added from docs/INSTALL.md
git add .claude/skills && git commit -m "chore: vendor claude-arsenal skills"
```

The default vendors `core` only; **`skill-creator` is excluded** (its gate is a
plugin hook that does not run on the web — pass `--plugins all` to include it
anyway). Full flow (the `vendor-skills.sh` script, the `.arsenal-vendored`
marker, and the exclusion rationale):
[`docs/INSTALL.md`](docs/INSTALL.md#use-on-claude-code-web-vendoring).

Full install guide and update/uninstall flow:
[`docs/INSTALL.md`](docs/INSTALL.md).
File-ownership table and customisation rule: [`docs/UPDATE.md`](docs/UPDATE.md).
Operating the task queue (orchestrator vs worker, fan-out, per-task PRs,
token-budget stop): [`docs/orchestrator-guide.md`](docs/orchestrator-guide.md).

---

## What's in it

| Plugin | Role |
|---|---|
| `skill-creator` | Meta-skill. Validates SKILL.md + references + scripts against the rubric. Hooks block unguarded edits inside `skills/` folders. |
| `core` | Engineering workflows: `specify`, `design`, `execution`, `review`, `ship`, `github`, `lsp-setup`, `session-end`; plus Python toolchain skills `python-bootstrap`, `pypi-release`, `coverage-gaps`, `dep-upgrade`, `mutmut-report`; plus the task queue (`init`, `continue`, `queue-add`, `queue-status`) that fans out work to parallel worker subagents. Tasks are files in `arsenal/tasks/`; a GitHub issue is each task's handle, and claiming is an atomic ref creation, so several sessions can work the same repo without colliding. See `docs/queue.md`. |

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
