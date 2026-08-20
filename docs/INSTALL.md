# Installing claude-arsenal

`claude-arsenal` is a Claude Code marketplace. Installing it gives any
project two plugins:

- **`skill-creator`** — the meta-skill that gates every authoring or
  editing change to a skill, plus the validator/auditor/scaffolder
  scripts everything else is checked against.
- **`core`** — generic engineering workflow skills (`specify`,
  `design`, `execution`, `review`, `ship`, `github`, `gate-check`,
  `lsp-setup`, `session-end`), the Python toolchain skills
  (`python-bootstrap`, `pypi-release`, `coverage-gaps`, `dep-upgrade`,
  `mutmut-report`), and the git-backed DAG task queue (`init`,
  `continue`, `queue-add`, `queue-status`). `init` injects a proactive
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
| Python 3.12+ | Scripts shipped under `skill-creator/scripts/` | `python3 --version` |
| `uv` (optional) | Required only if you want to run `make smoke` / `make audit` on a local checkout | `uv --version` |

Consumers who never run the scripts directly only need Claude Code and
git — the meta-skill's hooks are plain shell.

## 2. Add the marketplace

Inside a Claude Code session:

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
```

Claude clones the repo into `~/.claude/plugins/cache/claude-arsenal/`
and registers the two plugins.

## 3. Install plugins in order

Install `skill-creator` **first**. Its `PreToolUse` hook blocks
`Edit|Write|MultiEdit` inside any `plugins/*/skills/*` folder unless
the meta-skill is loaded — install it before `core` so the gate covers
`core`'s own skills from the first edit.

```text
/plugin install skill-creator@claude-arsenal
/plugin install core@claude-arsenal
```

After installing `core`, run `/init` once in any project where you
want the task queue bootstrapped.

## 4. Verify

| Check | Expected |
|---|---|
| Type `Help me create a new skill` | The `skill-creator` skill loads. Body contains the canary line `CANARY: skill-creator-loaded-2026-05-17-35c7fe06977dd6f1`. |
| Type `Investigate why login is slow` | `core:specify` loads. |
| Type `Set up the task queue in this repo` | `core:init` loads. |
| (local checkout) `make audit` | Per-plugin listing-budget breakdown prints; `PASS — under cap.` |

The canary is the cheapest signal that the plugin loaded the *correct*
SKILL.md rather than a stale cache. If you see the slash command but
not the canary, run `/plugin update claude-arsenal`.

## 5. Optional `/sc` alias

If you want the meta-skill on a short slash, bind `/sc` →
`/skill-creator:skill-creator` in `~/.claude/keybindings.json`. The
`keybindings-help` skill (built into Claude Code) walks you through the
JSON shape if you have not edited that file before.

## 6. Updating

```text
/plugin update claude-arsenal
```

This rewrites everything under
`~/.claude/plugins/cache/claude-arsenal/`. See `docs/UPDATE.md` for the
table of which files are plugin-owned (wiped on update) vs
consumer-owned (preserved).

## 7. Uninstall

```text
/plugin uninstall core@claude-arsenal
/plugin uninstall skill-creator@claude-arsenal
/plugin marketplace remove claude-arsenal
```

Remove `core` first — `skill-creator`'s gate stops being useful once
the plugin it guards is gone, and removing in this order avoids any
brief window where the gate would block a clean-up edit.

---

## Use on Claude Code web (vendoring)

Claude Code **on the web** (claude.ai/code) has **no plugin or marketplace
support** — `/plugin` and `/plugin marketplace add` are CLI/IDE/desktop only.
The web environment only reads config **committed into the project repo**:
`.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.mcp.json`, and
hooks in `.claude/settings.json`.

So to use these skills on the web, **vendor** them into the consuming
project's `.claude/skills/`. The canonical copies stay here in
`plugins/<plugin>/skills/<skill>/`; the vendored copies are generated build
output you regenerate, never hand-edit. `scripts/vendor-skills.sh` flattens
the marketplace layout into the flat layout web expects and tags each copy
with a `.arsenal-vendored` marker (so re-runs clean up renamed/removed skills
without touching skills you authored yourself).

### Agent playbook — set up or update for the web

When the user says *"install/update claude-arsenal from its repo to be used
in Claude Code web"*, run these steps from the consuming project root. They
are identical for first-time install and for updates — every step is
idempotent.

1. **Clone the marketplace** at the ref you want (a release tag, or `main`
   for the latest):

   ```bash
   rm -rf /tmp/arsenal && git clone --depth 1 https://github.com/nuncaeslupus/claude-arsenal.git /tmp/arsenal
   ```

2. **Flatten the skills** into `.claude/skills/`. Re-runs prune skills the
   marketplace has since dropped or renamed and never touch skills you
   authored yourself:

   ```bash
   bash /tmp/arsenal/scripts/vendor-skills.sh --src /tmp/arsenal --dest .claude/skills --plugins core
   ```

3. **Bootstrap the task queue.** The `init` skill ships its own bundle under
   `assets/`, so this resolves with no plugin tree present — the key reason
   the queue works on the web at all:

   ```bash
   python3 .claude/skills/init/scripts/init.py --repo-path .
   ```

   This creates `claude-arsenal/` (queue, `bin/` scripts, `AGENTS.md` and the
   `references/` it points at) and
   injects the session-protocol block into `CLAUDE.md`. Re-running only
   refreshes stale `claude-arsenal/bin/` files; your queue and project data
   are left untouched.

4. **Commit both trees** so the next web session sees them:

   ```bash
   git add .claude/skills claude-arsenal CLAUDE.md .gitignore
   git commit -m "chore: vendor + bootstrap claude-arsenal for web"
   ```

The `make update-skills` target below wraps step 2 for repeatability; steps 3
and 4 stay explicit because they write into your repo.

For **updating** an already-vendored repo — and the two ways that silently
fails — see `docs/UPDATE.md` § *Refreshing the vendored `claude-arsenal/`
runtime tree*.

Add this target to the **consuming project's** Makefile:

```make
ARSENAL_REPO    ?= https://github.com/nuncaeslupus/claude-arsenal.git
ARSENAL_REF     ?= v0.36.1           # pin to a tag — upgrade deliberately
ARSENAL_PLUGINS ?= core  # comma list, or "all" to include skill-creator

update-skills:  ## vendor claude-arsenal skills into .claude/skills (for CC web)
	@tmp=$$(mktemp -d); trap 'rm -rf $$tmp' EXIT; \
	git clone --depth 1 --branch $(ARSENAL_REF) $(ARSENAL_REPO) $$tmp >/dev/null 2>&1 && \
	bash $$tmp/scripts/vendor-skills.sh --src $$tmp --dest .claude/skills --plugins $(ARSENAL_PLUGINS)
```

Then:

```bash
make update-skills          # regenerates .claude/skills/ from the pinned tag
git add .claude/skills      # commit so the next web session sees them
git commit -m "chore: vendor claude-arsenal skills @ v0.36.1"
```

`core` is already the default. To vendor everything including
`skill-creator`:

```make
ARSENAL_PLUGINS ?= all
```

To **update** later, bump `ARSENAL_REF` to a newer tag and re-run
`make update-skills` — it overwrites the vendored copies and prunes any that
the new tag dropped, leaving your own `.claude/skills/` entries untouched.
Run `bash <clone>/scripts/vendor-skills.sh --src <clone> --list` to preview
what a ref would vendor.

> **`skill-creator` is excluded by default** — you author skills in the
> marketplace, not in a consuming project, and its pre-edit gate is a *plugin*
> hook that does not run on the web. Pass `--plugins all` only if you really
> want the meta-skill vendored too (ungated).

---

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
  ~/.claude/plugins/cache/claude-arsenal/plugins/skill-creator/skills/skill-creator/scripts/audit_library.py \
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
   The pre-edit hook refuses if `skill-creator` is not loaded — Claude
   will load it.
2. Edit `SKILL.md` / references / scripts.
3. Claude runs `validate.py <skill-path>` automatically at *work-done*
   (the meta-skill's gate). Findings land in
   `<skill>/findings.md` (gitignored).
4. Fix findings → re-validate → exit 0. Then commit.

If you prefer to run the validator yourself:

```bash
uv run python \
  plugins/skill-creator/skills/skill-creator/scripts/validate.py \
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
