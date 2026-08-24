# claude-arsenal

**A Claude Code marketplace for people who want the agent to work like an engineer.**

Specs before code. Failing tests before implementations. Acceptance gates with
numbers behind them. A task queue that several agents can work in parallel
without stepping on each other. And a meta-skill that holds every skill in your
repo — including its own — to a rubric drawn from published research.

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
/plugin install core@claude-arsenal
/plugin install skill-workshop@claude-arsenal
```

[![CI](https://github.com/nuncaeslupus/claude-arsenal/actions/workflows/ci.yml/badge.svg)](https://github.com/nuncaeslupus/claude-arsenal/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Why this exists

Most agent setups fail the same four ways. This is what each of them is answered
with.

| The failure | The answer here |
|---|---|
| The agent writes code before anyone agreed what the problem was | **Spec-driven**: `specify` → `design` → `execution` → `review` → `ship`, each with its own output document |
| "Done" means the agent said so | **Gates with numbers**: a task's acceptance gate is a fenced block a script runs, against a committed measurement |
| Tests get written after the code, to fit it | **RED → GREEN → RECORD**: the check that proves the gate fails must fail first, for the expected reason |
| Skills that sound useful but never load | **A rubric and a validator**: 132 checkable rows, a mechanical pass, and a hook that blocks unguarded edits |

---

## The four things you actually get

### 1. `skill-workshop` — a skill author that has read the literature

Writing a skill is easy. Writing one that *fires when it should*, doesn't
collide with its siblings, and doesn't quietly cost every session tokens it
never earns back — that's the hard part, and it has a research answer.

`skill-workshop` distills [a 4,658-line research
archive](docs/research/claude-skill-system_v1.17.md) — Anthropic's official skill
documentation, the `anthropics/skills` shipping repository, and academic sources
— into two rubrics it walks on every edit:

- **107 structural rows** ([`skill-rules.md`](plugins/skill-workshop/skills/skill-workshop/references/skill-rules.md)) — frontmatter, naming, workspace topology, script CLI conventions, reference chunking.
- **25 content-quality rows** ([`content-quality-rules.md`](plugins/skill-workshop/skills/skill-workshop/references/content-quality-rules.md)) — prose shape, trigger quality, example currency, and procedural shape.

That last one is grounded in measurement, not taste. Across ~8,100 agent trial
records, *procedural anchoring* — stable action sequences, setup steps,
verification routines — carried the large majority of cases where a skill
changed the outcome, while explicit knowledge injection carried a small minority
(Jiang et al., [*Demystifying Agent
Skills*](https://arxiv.org/abs/2608.14036)). So the rubric requires that every
step names how to confirm it worked. "Run the tests" fails the check; "run `make
test`; it exits 0" passes it.

Three things enforce it, in increasing order of teeth:

```bash
validate.py <skill>          # sub-second mechanical pass — frontmatter, links, CLI canon
audit_library.py <library>   # whole-library: description-overlap matrix, listing budget
```

…and a **PreToolUse hook** that blocks an edit inside any `skills/` folder unless
`skill-workshop` is loaded first. It keys on what a Bash command *writes*, not
what it mentions, so `sed -i`, `tee`, a heredoc and a `python3 -c` one-liner are
all covered — the routes a session naturally reaches for.

Rules that predict failures nobody has observed don't get to stay. Every row
traces to something that actually went wrong.

### 2. Spec-driven development, with documents you can hand to a human

```text
specify  →  design  →  execution  →  review  →  ship
```

Each stage owns one artifact and one validator. `specify` produces the
problem analysis and options; `design` produces contracts, the task split, the
risk register, and the sequencing.

Both of them **publish an annotatable reader** before they report done — a
self-contained HTML page with a note field per section, notes auto-saving in the
browser and an Export button that writes them back out as Markdown. Re-run it
with those notes in hand and they land back in the document. A spec nobody read
is a spec nobody agreed to.

### 3. Test-first execution, and gates that hold a number

`execution` works each task through three motions:

- **RED** — write the check that proves the gate, and confirm it fails *for the expected reason*. A bug fix starts as a regression test; a metric gate starts as a measurement that misses the threshold.
- **GREEN** — implement, reading before writing and matching existing patterns.
- **RECORD** — commit the evidence before starting the next task.

`<!-- test-discipline: test-after -->` in your `CLAUDE.md` switches the
discipline if your project genuinely works that way. It's a per-repo flag, not a
per-session argument.

The gate itself is mechanical. A task declares it as a fenced block:

````markdown
```gate
line_coverage >= 0.90
evidence: coverage.json
key: totals.percent_covered
```
````

`gate_run.sh` asserts `measured <op> threshold` against the committed file. A
declared gate with no evidence file — or evidence that violates it — is a hard
failure. It can never pass vacuously, which is the whole point: **`done` means
the gate passed, and the number is in the repo.**

There is a third outcome besides pass and fail. `status-key` lets evidence say
`unmeasured` — the check ran, and what it found is that this can't be scored
yet. Without that, honest "not yet" reads as failure and pressures the author
into weakening the gate to something measurable, which is exactly the pressure
gates exist to remove.

### 4. A task queue that is a DAG, and agents that run it in parallel

Two ideas, and everything else follows.

**The repository defines the work.** Tasks are files in `arsenal/tasks/` —
versioned, reviewed in the PR that adds them, readable with no network,
identical for every agent. `deps:` between them makes the board a dependency
graph, so `/continue` picks the next **unblocked** task rather than the next one
in a list.

**GitHub coordinates who is doing it.** An issue is a *handle* for a task, not a
copy of it. A claim is an atomic ref creation that GitHub itself arbitrates —
two agents racing for the same task, one ref push wins, the loser moves on. No
coordination branch, no side worktree, no ledger file two sessions have to keep
in step.

```bash
/queue-add --title "Extract the surface probe" --deps t-3f8a91c2 --size M
/continue                  # claim the next unblocked task and work it
/continue CLI              # …scoped to a tag
/queue-status              # counts, plus an audit for missing gates and broken deps
```

Each task ends in its own PR, opened only if its gate passed and the host's own
gate passed. Abandoned claims are released by a shipped GitHub Actions workflow,
so a session that dies mid-task doesn't wedge the board.

Full model, including the migration path for an existing repo:
[`docs/queue.md`](docs/queue.md).

---

## Install

Inside a Claude Code session:

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
/plugin install skill-workshop@claude-arsenal   # turns on the skill-edit gate
/plugin install core@claude-arsenal             # engineering workflows + queue
```

Verify it took:

```text
Help me create a new skill          # loads skill-workshop (announces a canary phrase)
Investigate why login is slow       # loads core:specify
```

### Then vendor it — this is the part that matters

A cloud session — web, `claude --cloud`, the desktop and mobile apps, Claude
Tag, routines — runs on a fresh clone on another machine. It never sees your
`~/.claude/`, and it does not install the plugins your repo asks for. **It reads
what you committed.**

`/init` handles that: it copies the skills into `.claude/skills/`, wires the
skill-edit gate into `.claude/settings.json`, and creates `claude-arsenal/` with
the scripts, references, and workflows.

```bash
/init
git add .claude claude-arsenal arsenal .github CLAUDE.md .gitignore
git commit -m "chore: add claude-arsenal"
```

Now every surface gets the same skills, because they're in the repo.

Without Claude Code on the machine, the same script runs from a clone — see
[`docs/INSTALL.md`](docs/INSTALL.md#2-set-up-a-project).

---

## The skills

| | |
|---|---|
| **Workflow** | `specify` · `design` · `execution` · `review` · `ship` |
| **Queue** | `init` · `queue-add` · `queue-status` · `continue` · `gate-check` |
| **Git / GitHub** | `github` (Conventional Commits, branch naming, the PR review loop) |
| **Session** | `session-end` (handoff, retrospective, PR audit) |
| **Python toolchain** | `python-bootstrap` · `pypi-release` · `dep-upgrade` · `coverage-gaps` · `mutmut-report` |
| **Meta** | `skill-workshop` |

---

## Context budget is a review criterion, not an afterthought

This is a skill set for working *better* with Claude, and a session's context
window is the resource it spends to do that. A skill occupying context it does
not earn back makes every session slightly worse at everything else.

So the cost is measured, and CI fails over it:

| Tier | What's in it | Paid |
|---|---|---|
| **Resident** | vendored `AGENTS.md` + every skill's name and description | every turn, every session, forever |
| **On invocation** | one `SKILL.md` body | once, when that skill triggers |
| **On demand** | `references/`, agent definitions | only when something opens them |

`make context-budget` reports all three. The resident tier is capped at 5,000
tokens. When a change pushes it over, what grew moves behind a reference or into
a script — the cap does not get raised.

The same discipline shapes the skills themselves. Anything deterministic —
ordering, resolution, parsing, a consistency check — is a script whose output is
a line or two, not prose the model is asked to re-derive on every run.

---

## For contributors

```bash
git clone https://github.com/nuncaeslupus/claude-arsenal
cd claude-arsenal
uv sync
make help            # every target
make smoke           # validate all plugins
make test            # 31 behaviour tests
make dev             # run Claude with both plugins loaded from the working tree
```

The repo dogfoods its own queue and its own gate: editing a skill here goes
through `skill-workshop` like anywhere else. Layout, branch policy, and
versioning rules are in [`CLAUDE.md`](CLAUDE.md) (internal — not shipped to
consumers). Full walkthrough: [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).

**Docs:** [install](docs/INSTALL.md) ·
[update & uninstall](docs/UPDATE.md) ·
[the task queue](docs/queue.md) ·
[contributing](docs/CONTRIBUTING.md) ·
[the research archive](docs/research/claude-skill-system_v1.17.md)

---

## License

MIT — see [`LICENSE`](LICENSE).
