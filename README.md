# claude-arsenal

A Claude Code marketplace. One install gives any project the
`skill-workshop` meta-skill (which gates every authoring or editing
change inside a `skills/` folder against a rubric) plus a generic
engineering-workflow plugin (`core`: specify → design → execution →
review → ship, plus `github`, `session-end`, and the
Python toolchain skills `python-bootstrap`, `pypi-release`,
`coverage-gaps`, `dep-upgrade`, and `mutmut-report`).

---

## Install

Inside a Claude Code session:

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
/plugin install skill-workshop@claude-arsenal   # turns on the gate
/plugin install core@claude-arsenal             # engineering workflows
```

Verify:

```text
Help me create a new skill          # loads skill-workshop (with the canary phrase)
Investigate why login is slow       # loads core:specify
```

### Every surface

The skills live **in the project repo, committed**. A cloud session — web,
`claude --cloud`, the desktop and mobile apps, Claude Tag, routines — runs on a
fresh clone on another machine; it never sees your `~/.claude/` and does not
install plugins your repo asks for. It reads what you committed.

`/init` does all of it — copies the skills into `.claude/skills/`, wires the
skill-edit gate into `.claude/settings.json`, creates `claude-arsenal/`:

```bash
/init
git add .claude claude-arsenal arsenal .github CLAUDE.md .gitignore && git commit -m "chore: add claude-arsenal"
```

Without Claude Code on the machine, the same script runs from a clone — see
[`docs/INSTALL.md`](docs/INSTALL.md#2-set-up-a-project).

Full install guide and update/uninstall flow:
[`docs/INSTALL.md`](docs/INSTALL.md).
File-ownership table and customisation rule: [`docs/UPDATE.md`](docs/UPDATE.md).
How the task queue works (task files, issue handles, atomic claims, fan-out,
per-task PRs, migration): [`docs/queue.md`](docs/queue.md).

---

## What's in it

| Plugin | Role |
|---|---|
| `skill-workshop` | Meta-skill. Validates SKILL.md + references + scripts against the rubric. Hooks block unguarded edits inside `skills/` folders. |
| `core` | Engineering workflows: `specify`, `design`, `execution`, `review`, `ship`, `github`, `session-end`; plus Python toolchain skills `python-bootstrap`, `pypi-release`, `coverage-gaps`, `dep-upgrade`, `mutmut-report`; plus the task queue (`init`, `continue`, `queue-add`, `queue-status`) that fans out work to parallel worker subagents. Tasks are files in `arsenal/tasks/`; a GitHub issue is each task's handle, and claiming is an atomic ref creation, so several sessions can work the same repo without colliding. See `docs/queue.md`. |

The active rubric is at
[`plugins/skill-workshop/skills/skill-workshop/references/skill-rules.md`](plugins/skill-workshop/skills/skill-workshop/references/skill-rules.md),
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
make dev             # claude --plugin-dir ./plugins/skill-workshop --plugin-dir ./plugins/core
```

Project layout, branch policy, and the cite form are documented in
[`CLAUDE.md`](CLAUDE.md) (internal-only — not shipped to consumers).

---

## License

MIT — see [`LICENSE`](LICENSE).
