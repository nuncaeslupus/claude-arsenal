# Installing claude-arsenal

`claude-arsenal` is a Claude Code marketplace. Installing it gives any
project two plugins:

- **`skill-creator`** — the meta-skill that gates every authoring or
  editing change to a skill, plus the validator/auditor/scaffolder
  scripts everything else is checked against.
- **`core`** — generic engineering workflow skills (`specify`,
  `design`, `execution`, `review`, `ship`, `github`,
  `lsp-setup`, `session-end`, `mutmut-report`).

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

## 4. Verify

| Check | Expected |
|---|---|
| Type `Help me create a new skill` | The `skill-creator` skill loads. Body contains the canary line `CANARY: skill-creator-loaded-2026-05-17-35c7fe06977dd6f1`. |
| Type `Investigate why login is slow` | `core:specify` loads. |
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
0 with `10 clean skills` and a budget summary.

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
