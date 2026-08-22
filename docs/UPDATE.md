# Updating claude-arsenal

`/plugin update claude-arsenal` rewrites the marketplace cache. This
page tells you which files survive that rewrite, which get
overwritten, and how to customise a vendored skill without losing your
edits on the next update.

---

## What v0.32.0 adds on upgrade

Re-running `/init` after this upgrade writes one new file outside the vendored
prefix: `.github/workflows/arsenal-queue.yml`. It is the queue's upkeep — closing
a task whose merge did not close it, releasing the claim on a PR closed without
merging, opening issue handles for new task files, and sweeping claims left by
crashed sessions. `/init` prints what it installed and which permissions it asks
GitHub for, and never overwrites a copy you have edited.

Delete it to opt out — `/init` records that choice as `queue-automation = false`
in `arsenal/config.toml` and never reinstalls it (the session-start protocol runs
`init --silent` every session, so a file-only check would undo the deletion on
every start). Set the key back to `true` to restore it. Merging still completes a
task without the workflow, because
`open_task_pr.sh` now writes `Closes #<issue>` and archives the task file inside
the PR — what is lost is the cleanup that happens when no session is running.

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
| `<project>/claude-arsenal/**` | plugin (vendored bundle) | **No** — refreshed by `init.py`; never edit here. |
| `<project>/arsenal/**` | consumer — tasks, specs, plans, config, session | Yes. Never written by an update. |

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

## Upgrading when the skills come from the plugin

Since v0.39.0 a consuming repo declares the marketplace in its own
`.claude/settings.json`, so cloud sessions install the plugin at session start
and there is nothing to re-vendor. Upgrading is two steps:

```bash
# 1. Bump the pin in .claude/settings.json
#      "ref": "v0.38.0"  ->  "ref": "v0.39.0"

# 2. Refresh the runtime bundle (AGENTS.md, references/, bin/, scripts/)
python3 .claude/skills/init/scripts/init.py --repo-path .   # or /init
```

`claude-arsenal/` is still upstream's and still refreshed by `init.py`;
`arsenal/` is still yours and still never written to.

If the repo has leftover `.claude/skills/` copies from before the switch, `/init`
reports them and prunes on `--migrate-plugins yes` — leaving them means every
skill is live twice, namespaced and not.

---

## Refreshing the vendored trees (fallback)

Consumers still using the [vendoring fallback](INSTALL.md#vendoring-fallback)
have two trees to keep up to date, and exactly one of them is upstream's:

- **`.claude/skills/`** — the flattened skill files; refreshed by
  `make update-skills` (or directly with `<clone>/scripts/vendor-skills.sh`).
- **`claude-arsenal/`** — the runtime bundle (`AGENTS.md`, `references/`, `bin/`,
  `scripts/`); refreshed by re-running `init.py`.

`arsenal/` is **yours** — tasks, specs, plans, config, session state — and no
update writes to it. That split is the whole point: upstream owns one directory
and may overwrite it freely, so an upgrade can never touch your work.

```bash
# 1. Re-vendor the skills
make update-skills

# 2. Refresh claude-arsenal/ (bin/, scripts/, references/, AGENTS.md)
python3 .claude/skills/init/scripts/init.py --repo-path .

# 3. Commit both trees
git add .claude/skills claude-arsenal
git commit -m "chore: vendor claude-arsenal @ vX.Y.Z"
```

`init.py --repo-path .` is idempotent: it overwrites stale bundle files and
scaffolds anything missing under `arsenal/`, but never rewrites an `arsenal/`
file that already exists.

### Coming from a release before v0.25.0

v0.25.0 replaced the `arsenal-queue` coordination branch with task files, issue
handles, and atomic claims, and moved host-owned state out of the vendored
prefix. Run the migration once, after refreshing the trees above:

```bash
python3 claude-arsenal/scripts/arsenal_migrate.py            # dry run — writes nothing
python3 claude-arsenal/scripts/arsenal_migrate.py --apply
```

It converts queue rows into `arsenal/tasks/<id>.md` files (ids preserved, so
`deps` keep resolving), moves `session/` and `project/` to `arsenal/`, and seeds
`arsenal/config.toml`. Finished tasks are recorded in
`arsenal/tasks/_migrated-history.md` rather than resurrected as work. Re-running
is safe. `docs/queue.md` covers the model and the few cleanup steps a sandboxed
session cannot do for you (deleting the old branch and worktree).

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
"Only overwrites stale scripts" reads like a safety guarantee, and for your
`arsenal/` tree it is — but `init.py` decides staleness by **checksum against the
plugin source**, so a script you patched locally is by definition stale and gets
overwritten, printing only `refreshed: bin/<name>.sh`. That is the intended
design, and it means **the bundle is not a place to fix bugs**: patch it
upstream and re-vendor, or your fix disappears at the next session start without
a warning. A consumer repo lost two gate-enforcement fixes this way before
noticing they were still present only because the fixes had *also* been
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
