# Installing claude-arsenal

`claude-arsenal` is a Claude Code marketplace. Installing it gives any
project two plugins:

- **`skill-workshop`** — the meta-skill that gates every authoring or
  editing change to a skill, plus the validator/auditor/scaffolder
  scripts everything else is checked against.
- **`core`** — generic engineering workflow skills (`specify`,
  `design`, `execution`, `review`, `ship`, `github`, `gate-check`,
  `session-end`), the Python toolchain skills
  (`python-bootstrap`, `pypi-release`, `coverage-gaps`, `dep-upgrade`,
  `mutmut-report`), and the git-backed DAG task queue (`init`,
  `continue`, `queue-add`, `queue-status`). `/init` asks which of these
  **sections** a repo wants and installs only those — see "Choosing what gets
  installed" below. `init` injects a proactive
  session-protocol block into `CLAUDE.md` so Claude auto-seeds the queue
  from workspace plans and auto-starts workers every session without any
  commands. Works on CC Web (no hooks needed).

Both plugins are pure-data (markdown + Python helpers + shell hooks).
No background daemons; nothing runs unless Claude loads a skill or a
hook fires.

---

## 1. Prerequisites

| Tool | Why | Verify |
|---|---|---|
| Claude Code v2.x+ | Marketplace + plugin loader | `claude --version` |
| `git` | Marketplace install fetches via git | `git --version` |
| Python 3.12+ | Scripts shipped under `skill-workshop/scripts/` | `python3 --version` |
| `uv` (optional) | Required only if you want to run `make smoke` / `make audit` on a local checkout | `uv --version` |

Consumers who never run the scripts directly only need Claude Code and
git — the meta-skill's hooks are plain shell.

## 2. Set up a project

**One rule to remember: the skills live in the project repo, committed.**
That is what makes them work everywhere. A cloud session — Claude Code on the
web, `claude --cloud`, the desktop and mobile apps, Claude Tag, routines —
runs on a fresh clone of your repository on a different machine. It never sees
your `~/.claude/`, and it does not install plugins your repo asks for. What it
reads is what you committed.

`/init` does the whole thing: it copies the skills into `.claude/skills/`,
wires the skill-edit gate into `.claude/settings.json`, and creates the
`claude-arsenal/` runtime tree.

### If you have Claude Code on your machine

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
/plugin install core@claude-arsenal
```

Then, from the project you want set up:

```text
/init
```

```bash
git add .claude claude-arsenal arsenal .github CLAUDE.md .gitignore && git commit -m "chore: add claude-arsenal"
```

That is it. The plugin gave you `/init`; the commit is what every later
session — yours, a teammate's, a cloud one — actually loads.

### Choosing what gets installed

`/init` asks what kind of project this is before it installs anything, because
every installed skill costs a row in the resident skills listing of every
session from then on — whether or not it ever triggers.

| Profile | Sections installed |
|---|---|
| `minimal` | `core` — `init`, `continue`, `queue-add`, `queue-status`, `github`, `session-end` |
| `general` | `core` + `workflow` (`specify`, `design`, `execution`, `review`, `ship`, `gate-check`) |
| `python` | `core` + `workflow` + `python` (`python-bootstrap`, `pypi-release`, `coverage-gaps`, `dep-upgrade`, `mutmut-report`) |

`core` is always installed: the vendored session protocol names those skills
directly. To skip the question, pass it up front:

```bash
python3 .../init.py --repo-path . --profile python
```

The answer is recorded as an editable `[skills]` table in `arsenal/config.toml`:

```toml
[skills]
workflow = true
python = false
```

Flip a value and the next `/init` adds or prunes that section's skills, and the
change sticks — unlike deleting a vendored skill folder, which the next session's
`init.py --silent` puts straight back. Upgrading a repo installed before sections
existed changes nothing: the sections already in use are detected and recorded.

### If you do not (cloud-only, CI, a fresh container)

No plugin needed — the same script runs straight from a clone:

```bash
git clone --depth 1 --branch v2.11.0 https://github.com/nuncaeslupus/claude-arsenal.git /tmp/arsenal
python3 /tmp/arsenal/plugins/core/skills/init/scripts/init.py --repo-path .
git add .claude claude-arsenal arsenal .github CLAUDE.md .gitignore && git commit -m "chore: add claude-arsenal"
```

Pin `--branch` to a release tag and bump it deliberately.

### Authoring skills? Add `skill-workshop` too

```text
/plugin install skill-workshop@claude-arsenal
```

Only needed in repos where you write or edit skills. `/init` already installs
its **gate** — the hook that blocks a skill edit until the meta-skill is
loaded — because that ships in the `core` bundle and travels with the commit.
The meta-skill itself is a plugin, so it is CLI-only.

## 3. Updating

Re-run `/init` (or the `init.py` line above at a newer tag) and commit. It
refreshes the vendored skills and the `claude-arsenal/` bundle, prunes skills
the new version no longer ships, and never touches `arsenal/` — your tasks,
specs, plans and config.

On the CLI, `/plugin update claude-arsenal` refreshes the plugin that gives
you `/init` itself. That is a separate thing from what your project ships, and
updating one does not update the other.

## 4. Verify

| Check | Expected |
|---|---|
| Type `Investigate why login is slow` | `specify` loads. |
| Type `Set up the task queue in this repo` | `init` loads. |
| `ls .claude/skills` | 17 skill folders, each with a `.arsenal-vendored` marker |
| Ask Claude to edit any `SKILL.md` without loading the meta-skill | **blocked** by the gate |
| (local checkout) `make audit` | Per-plugin listing-budget breakdown; `PASS — under cap.` |

Skills loaded from the project are **unprefixed** (`specify`). If you also
installed the plugins on the CLI you will additionally see `core:specify`, and
both are live at once — see *What runs where* below.

## 5. Optional `/sc` alias

If you want the meta-skill on a short slash, bind `/sc` →
`/skill-workshop:skill-workshop` in `~/.claude/keybindings.json`. The
`keybindings-help` skill (built into Claude Code) walks you through the
JSON shape if you have not edited that file before.

## 6. Uninstall

```text
/plugin uninstall core@claude-arsenal
/plugin uninstall skill-workshop@claude-arsenal
/plugin marketplace remove claude-arsenal
```

Remove `core` first — `skill-workshop`'s gate stops being useful once
the plugin it guards is gone, and removing in this order avoids any
brief window where the gate would block a clean-up edit.

---

## What runs where

| | CLI / IDE / desktop | Cloud session |
|---|---|---|
| Skills committed in `.claude/skills/` | ✅ loads, unprefixed | ✅ loads, unprefixed |
| Hooks in `.claude/settings.json` | ✅ | ✅ |
| `claude-arsenal/` runtime tree | ✅ | ✅ |
| Plugins from `/plugin install` | ✅ namespaced (`core:specify`) | ❌ user-scoped, does not travel |
| Plugins declared in the repo's `.claude/settings.json` | ✅ registers on trust | ❌ ignored |
| Plugin hooks (`hooks/hooks.json`) | ✅ | ❌ |

Everything in the committed column works on both. That is why the setup flow
commits the skills rather than declaring them.

### Why the repo does not just declare the plugins

Claude Code's documentation describes `extraKnownMarketplaces` /
`enabledPlugins` in a repo's `.claude/settings.json` as installed at session
start. **On the cloud surface that does not happen**, verified against a live
session rather than inferred: with a correct declaration committed, the
marketplace public, and the pinned tag returning `200` from inside the sandbox,
`~/.claude/plugins/known_marketplaces.json` was absent and
`installed_plugins.json` was empty. Skills reach that surface through
account-level sync (`~/.claude/skills/synced/`); the web runtime does not fetch
a git marketplace on session start the way the CLI does.

The failure is silent — no error, just an absent skill — and a bare-name
invocation can then quietly resolve to an unrelated built-in of the same name.
So `/init` no longer writes that declaration, and removes one written by
v1.0.0 through v1.1.0.

### If you install the plugins as well

Nothing breaks, but every skill is live twice: `specify` from the commit and
`core:specify` from the plugin. Claude Code keeps both rather than letting one
override the other, so you pay the listing budget twice and two skills answer
the same request. Install `core` on the CLI to *get* `/init`, and let the
commit be what your project actually runs on.

`skill-workshop` is the exception worth installing per-machine: it is the
meta-skill you invoke while authoring, its gate already travels with `/init`,
and it is not something a project's own sessions need.

## Local checkout (optional)

You only need a local clone if you want to run the validator or
auditor outside a Claude Code session — for example, in a CI pipeline
that checks consumer-side `.claude/skills/` folders.

```bash
git clone https://github.com/nuncaeslupus/claude-arsenal
cd claude-arsenal
uv sync
make smoke
```

`make smoke` runs the validator on every shipped skill, audits the
listing budget, and walks `tests/skills_smoke.sh`. A clean run exits
0 with `19 clean skills` and a budget summary.

### Audit your installed cache

The same auditor works against the cache that `/plugin install` wrote:

```bash
uv run python \
  ~/.claude/plugins/cache/claude-arsenal/plugins/skill-workshop/skills/skill-workshop/scripts/audit_library.py \
  ~/.claude/plugins/cache/claude-arsenal/plugins/*/skills \
  --by-plugin
```

Use this if you suspect the cache is stale or want to confirm that the
listing budget still has headroom after stacking your own marketplaces
on top.

---

## Authoring loop (the finding-driven cycle)

Once both plugins are installed, the meta-skill is the gate. The
authoring loop is:

1. Inside a Claude Code session, ask Claude to start work on a skill.
   The pre-edit hook refuses if `skill-workshop` is not loaded — Claude
   will load it.
2. Edit `SKILL.md` / references / scripts.
3. Claude runs `validate.py <skill-path>` automatically at *work-done*
   (the meta-skill's gate). Findings land in
   `<skill>/findings.md` (gitignored).
4. Fix findings → re-validate → exit 0. Then commit.

If you prefer to run the validator yourself:

```bash
uv run python \
  plugins/skill-workshop/skills/skill-workshop/scripts/validate.py \
  plugins/core/skills/specify
```

Exit codes: `0` clean, `1` findings (see `findings.md`), `2` internal
error.

---

## Troubleshooting

**The slash command exists but the skill doesn't load.**
Stale cache. `/plugin update claude-arsenal` rewrites it. If the
problem persists, `/plugin marketplace remove claude-arsenal &&
/plugin marketplace add github:nuncaeslupus/claude-arsenal` forces a
clean re-clone.

**A consumer-side `PreToolUse` hook fires before this marketplace's
gate.** Hook order follows `settings.json` precedence (user > project
> plugin). Run `claude --debug-hooks` to see the firing sequence; if a
consumer hook is incorrectly blocking the gate, reorder or scope its
matcher.

**`make smoke` fails locally but the marketplace install works.**
Almost always missing `uv sync` after pulling. `uv sync && make
smoke`. If the validator complains about a skill that ships in the
marketplace, file an issue — that's a regression.
