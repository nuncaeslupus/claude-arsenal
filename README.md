# claude-arsenal

[![CI](https://github.com/nuncaeslupus/claude-arsenal/actions/workflows/ci.yml/badge.svg)](https://github.com/nuncaeslupus/claude-arsenal/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/nuncaeslupus/claude-arsenal?label=release&sort=semver)](https://github.com/nuncaeslupus/claude-arsenal/tags)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<p align="center">
  <img src="https://raw.githubusercontent.com/nuncaeslupus/claude-arsenal/main/docs/hero.png" width="100%" alt="claude-arsenal: an engineering sheet with the wordmark, a terminal installing the marketplace and running a RED, GREEN, RECORD gate check, the plugins, and the spec-driven pipeline from explore-idea to ship">
</p>

**A Claude Code plugin marketplace that makes the agent work like an engineer: specs before code, tests before implementations, and a gated task queue several agents can work in parallel.**

Agent sessions tend to start coding before the problem is agreed, call work "done"
because they said so, and lose track of what is in flight between sessions.
claude-arsenal ships skills for a spec-driven workflow, acceptance gates that a
script runs against committed evidence, and a task queue stored as files in your
repo and coordinated through GitHub. `/init` vendors all of it into the repository,
so every session, local or cloud, loads the same skills.

## Quick start

Inside a Claude Code session:

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
/plugin install core@claude-arsenal
```

Then, in the project you want set up:

```text
/init
```

```bash
git add .claude claude-arsenal arsenal .github CLAUDE.md .gitignore
git commit -m "chore: add claude-arsenal"
```

Without Claude Code on the machine (CI, a fresh container), run the same installer
from a clone pinned to a release tag:

```bash
git clone --depth 1 --branch v5.10.1 https://github.com/nuncaeslupus/claude-arsenal.git /tmp/arsenal
python3 /tmp/arsenal/plugins/core/skills/init/scripts/init.py --repo-path . --profile general
```

## Example

Two task files in `arsenal/tasks/`, the second depending on the first:

````markdown
---
id: t-aaaa1111
title: "Add a --json flag to the CLI"
priority: 5
deps: []
---

## Acceptance gate
```bash
make test
```
````

````markdown
---
id: t-bbbb2222
title: "Document the JSON output"
priority: 10
deps: [t-aaaa1111]
---

## Acceptance gate
```bash
grep -q -- '--json' README.md
```
````

With their GitHub issues saved as JSON (`number`, `title`, `state`, `labels`,
`assignees`), the board shows one open task and one blocked, and the selector
returns the unblocked one:

```text
$ python3 claude-arsenal/scripts/query_status.py --issues issues.json
tasks: 2 — open 1, claimed 0, done 0, blocked 1

$ python3 claude-arsenal/scripts/task_select.py --issues issues.json
{"id":"t-aaaa1111","title":"Add a --json flag to the CLI","label":"Add a --json flag to…","display":"Add a --json flag to… (t-aaaa1111)","path":"arsenal/tasks/t-aaaa1111.md","priority":5,"gate":true}
```

`/queue-next` runs this for you, claims the task, works it test-first, and opens a
PR with `Closes #<issue>` once the gate passes.

## Use with AI agents

claude-arsenal is built for Claude Code. There is no MCP server; the interface is
skills, a vendored `AGENTS.md`, and scripts with line-oriented or JSON output.

### Plugins

| Plugin | Install | Contents |
|---|---|---|
| `core` | `/plugin install core@claude-arsenal` | Workflow, queue, GitHub, session and Python toolchain skills |
| `skill-workshop` | `/plugin install skill-workshop@claude-arsenal` | Meta-skill for writing and editing skills: rubric, validator, library auditor |
| `repo-audit` | `/plugin install repo-audit@claude-arsenal` | `repo-audit` finds and verifies problems in any repo and queues them as gated tasks; `explain-repo` turns the results into a pitch, deep-dive, onboarding guide or status brief |

### Skills

| Group | Skills |
|---|---|
| Workflow | `explore-idea` · `specify` · `design` · `execution` · `review` · `ship` · `gate-check` |
| Queue | `init` · `queue-add` · `queue-next` · `queue-status` |
| Git / session | `github` (Conventional Commits, PR review loop) · `session-end` (handoff, retrospective, PR audit) |
| Python | `python-bootstrap` · `pypi-release` · `dep-upgrade` · `coverage-gaps` · `mutmut-report` · `pin-check` |
| Extract | `har` (HAR / network-capture analysis) |
| Meta | `skill-workshop` |

`/init` installs skills by section (`core`, `workflow`, `python`, `extract`), chosen
with `--profile minimal|general|python|all` or `--sections`, and records the choice
in `arsenal/config.toml`. `init.py --list-sections` shows what is installed.

### How a session uses it

`/init` writes a session-protocol block into the host `CLAUDE.md` that imports
`claude-arsenal/AGENTS.md`. Every session then, without being asked:

1. Detects its GitHub channel: `claude-arsenal/bin/github_channel.sh --detect` prints `gh`, `rest` or `none` (`none` means use the agent's own GitHub tools).
2. Fetches the `arsenal:task` issues and reads the board with `query_status.py`, reporting tasks with no gate, no issue handle, or unknown deps.
3. Picks the next unblocked task with `task_select.py` and claims it with `claude-arsenal/bin/claim_task.sh <id>`, which creates a git ref on GitHub. The result is `won`, `lost` (take the next task), `manual` (make the call with your own tools) or `error`. Exactly one caller wins.
4. Works the task (`execution`: RED, GREEN, RECORD), runs its gate, and opens a PR with `claude-arsenal/bin/open_task_pr.sh`. Merging closes the issue, archives the task file and unblocks dependents.
5. Writes `arsenal/session/handover.md` for the next session.

Merging follows `merge-policy` in `arsenal/config.toml`. Full protocol:
[`plugins/core/skills/init/assets/AGENTS.md`](plugins/core/skills/init/assets/AGENTS.md).

## How it works

- **Spec-driven pipeline.** `explore-idea` → `specify` → `design` → `execution` → `review` → `ship`; each stage owns one document and one validator. `specify` and `design` also publish an HTML reader with a note field per section; the exported notes feed the next revision.
- **Test-first execution.** RED (the check fails for the expected reason), GREEN (implement), RECORD (commit the evidence). `<!-- test-discipline: test-after -->` in `CLAUDE.md` switches it per repo.
- **Gates with numbers.** A task's gate is a fenced `bash` block, or a `gate` block (`line_coverage >= 0.90`, `evidence: coverage.json`) that `gate_run.sh` checks against a committed file. Missing evidence fails; `unmeasured` is a third outcome, distinct from fail.
- **Queue as a DAG.** Tasks are files under `arsenal/tasks/`, read from the default branch, so every agent computes the same order. Issues are handles, not copies. A shipped Actions workflow releases abandoned claims and creates missing handles.
- **Parallel workers.** An orchestrator runs up to `ARSENAL_MAX_WORKERS` workers, each in its own git worktree, behind a quota guard that stops before a rate-limit window is exhausted.
- **Skill rubric.** `skill-workshop` checks skills against structural and content-quality rubrics drawn from [a research archive](docs/research/claude-skill-system_v1.17.md). A PreToolUse hook blocks edits inside `skills/` until it is loaded.
- **Context budget.** `make context-budget` measures what an install costs every session; CI fails when it goes over the set budget.

## Usage

| Command | What it does |
|---|---|
| `/init` | Vendor skills, scripts and workflows into the repo; safe to re-run |
| `/queue-add --title "..." --priority 5 --deps t-xxxxxxxx` | Add a task file |
| `/queue-next [TAG \| WORKSPACE \| text]` | Claim and work the next unblocked task |
| `/queue-status` | Counts plus an audit for missing gates and broken deps |
| `/session-end` | Handoff, retrospective, PR audit |

Configuration lives in `arsenal/config.toml`: `host-gate`, `preflight-gate`,
`merge-policy`, `[models]`, `[skills]`. Updating and uninstalling:
[`docs/UPDATE.md`](docs/UPDATE.md).

## Limitations

- GitHub only: claims, handles and cleanup use GitHub issues, refs and Actions.
- Parallel dispatch is CLI-first; cloud surfaces lose parts of worktree isolation and pushes ([`docs/fleet.md`](docs/fleet.md)).
- Queue cleanup needs GitHub Actions enabled (off by default on forks).
- bash/POSIX tooling; on Windows use WSL or Git Bash.

## Documentation

[Install](docs/INSTALL.md) ·
[Update & uninstall](docs/UPDATE.md) ·
[Task queue](docs/queue.md) ·
[Fleet](docs/fleet.md) ·
[Models](docs/MODELS.md) ·
[Contributing](docs/CONTRIBUTING.md) ·
[Research archive](docs/research/claude-skill-system_v1.17.md)

## Development

```bash
git clone https://github.com/nuncaeslupus/claude-arsenal
cd claude-arsenal
uv sync
make help    # every target
make smoke   # validate manifests and skills, audit the library
make test    # behaviour tests
make lint    # ruff + mypy
make dev     # Claude Code with the plugins loaded from the working tree
```

Layout, versioning and branch policy: [`CLAUDE.md`](CLAUDE.md).

## Related projects

- [drawspec](https://github.com/nuncaeslupus/drawspec) — declarative diagram spec → clean SVG/PNG/text, writable by LLMs; MCP server included.
- [doc-control](https://github.com/nuncaeslupus/doc-control) — lets AI agents edit Word documents as tracked changes.
- [literary-critic](https://github.com/nuncaeslupus/literary-critic) — LLM manuscript analysis the way a professional editor would.
- [integral-job-search](https://github.com/nuncaeslupus/integral-job-search) — candidate-centred job search run in Claude Code.

## License

MIT — see [`LICENSE`](LICENSE).
