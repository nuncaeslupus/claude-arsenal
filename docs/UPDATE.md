# Updating claude-arsenal

`/plugin update claude-arsenal` rewrites the marketplace cache. This
page tells you which files survive that rewrite, which get
overwritten, and how to customise a vendored skill without losing your
edits on the next update.

---

## File ownership

| Path | Owner | Survives `/plugin update`? |
|---|---|---|
| `~/.claude/plugins/cache/claude-arsenal/**` | plugin | **No** — wiped and rewritten. |
| `~/.claude/plugins/cache/claude-arsenal/**/findings.md` | author-local log | **No** — wiped on update; never commit findings upstream from cache. |
| `~/.claude/CLAUDE.md` | consumer | Yes. |
| `~/.claude/settings.json` | consumer | Yes. |
| `~/.claude/keybindings.json` | consumer | Yes. |
| `<project>/CLAUDE.md` | consumer | Yes. |
| `<project>/.claude/skills/**` | consumer | Yes. |
| `<project>/.claude/settings.json` | consumer | Yes. |
| `<project>/.claude/settings.local.json` | consumer (gitignored) | Yes. |
| `<project>/<skill>/findings.md` | consumer (gitignored) | Yes. |

Anything under the cache directory is regenerated wholesale. Anything
under `~/.claude/` (outside the cache) or your project root is yours.

---

## Customising a vendored skill

**Never edit files in the cache directory.** The next `/plugin update`
will discard your changes silently.

To customise a skill the marketplace ships:

1. Copy the skill folder into your project: `cp -r
   ~/.claude/plugins/cache/claude-arsenal/plugins/core/skills/specify
   <project>/.claude/skills/`.
2. Edit the copy. Claude Code resolves skills with project-level
   precedence over plugin-level, so your fork takes over.
3. (Optional) Document the divergence in your project's `CLAUDE.md` so
   teammates know the local version is the source of truth.
4. Run `validate.py` on the fork before committing — the meta-skill's
   rubric still applies:

   ```bash
   uv run python \
     ~/.claude/plugins/cache/claude-arsenal/plugins/skill-creator/skills/skill-creator/scripts/validate.py \
     <project>/.claude/skills/specify
   ```

If the cache later ships a fix to the original skill, you have to
rebase your fork manually — `/plugin update` does not touch your
project-level copy.

---

## Audit after an update

After a non-trivial update, confirm the listing budget still has
headroom:

```bash
uv run python \
  ~/.claude/plugins/cache/claude-arsenal/plugins/skill-creator/skills/skill-creator/scripts/audit_library.py \
  ~/.claude/plugins/cache/claude-arsenal/plugins/*/skills \
  --by-plugin
```

A breach prints `OVER cap by N chars` and a hint to `/plugin disable
<plugin>` for tasks that do not need that plugin's skills.

---

## Refreshing the vendored `claude-arsenal/` runtime tree (CC web)

Consumers who vendor the skills for Claude Code on the web have two
separate trees to keep up to date:

- **`.claude/skills/`** — the flattened skill files; refreshed by
  `make update-skills` (or directly with `<clone>/scripts/vendor-skills.sh`).
- **`claude-arsenal/`** — the queue runtime tree (`bin/`, `AGENTS.md`,
  `queue/`); refreshed by re-running `init.py`.

To update both after bumping `ARSENAL_REF` in your Makefile:

```bash
# 1. Re-vendor the skills
make update-skills

# 2. Re-run init to refresh claude-arsenal/bin/ scripts
#    (queue data in claude-arsenal/queue/ is never touched)
python3 .claude/skills/init/scripts/init.py --repo-path .

# 3. Commit both trees
git add .claude/skills claude-arsenal
git commit -m "chore: vendor claude-arsenal @ vX.Y.Z"
```

`init.py --repo-path .` is idempotent: it only overwrites stale
`claude-arsenal/bin/` scripts and the `AGENTS.md` header; your
`tasks.jsonl`, per-task payloads, and project-local `CLAUDE.md` edits
are left untouched.

### Two ways this silently does nothing (or undoes your work)

Both were hit by a real consumer repo in one session:

**A stale `ARSENAL_REF` makes `make update-skills` a successful no-op.** The pin
is a literal in the consumer's Makefile and nothing compares it against the
latest tag, so a repo pinned three releases back re-vendors the *same old
version* and reports `vendored N skill(s)` — a success message for an update
that did not happen. `check_update.sh` is the automated counterpart, but it is
**inert unless the consumer added an `arsenal` git remote**, which vendoring
consumers have no reason to do. Check the pin against the tag list before
assuming you are current:

```bash
git ls-remote --tags https://github.com/nuncaeslupus/claude-arsenal.git 'refs/tags/v*' \
  | sed 's|.*refs/tags/||' | sort -V | tail -1
```

**A local edit to `claude-arsenal/bin/` is reverted by the next `init.py`.**
"Only overwrites stale scripts" reads like a safety guarantee, and for queue
data it is — but `init.py` decides staleness by **checksum against the plugin
source**, so a script you patched locally is by definition stale and gets
overwritten, printing only `refreshed: bin/<name>.sh`. That is the intended
design, and it means **the bundle is not a place to fix bugs**: patch it
upstream and re-vendor, or your fix disappears at the next session start
without a warning. A consumer repo lost two gate-enforcement fixes this way
before noticing they were still present only because the fixes had *also* been
committed to the consumer's own tree.


---

## Rolling back

Marketplace install does not pin a version — `/plugin update` always
fetches the tip of `main`. If a fresh update breaks something:

```text
/plugin marketplace remove claude-arsenal
/plugin marketplace add github:nuncaeslupus/claude-arsenal
```

If that does not help, file an issue against
`nuncaeslupus/claude-arsenal` with the commit SHA the cache currently
holds (`git -C ~/.claude/plugins/cache/claude-arsenal rev-parse HEAD`).
