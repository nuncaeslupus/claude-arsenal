# Updating claude-arsenal

`/plugin update claude-arsenal` rewrites the marketplace cache. This
page tells you which files survive that rewrite, which get
overwritten, and how to customise a vendored skill without losing your
edits on the next update.

---

## What's new in a given version

You don't have to go hunting for this. `/init`'s upgrade banner (and
`check_update.sh`, for a subtree install) prints every changelog entry
between your installed version and the version you're updating to,
automatically, every time you update — new skills, new flags, new options,
breaking changes. The session-start protocol already runs `init.py --silent`
every session, so the banner shows up on the first session after a plugin
update even if you never run `/init` by hand.

The entries themselves live in
`plugins/core/skills/init/assets/CHANGELOG.md` inside the marketplace repo,
one `## [X.Y.Z]` section per version bump. Read it directly if you want to
look ahead before updating; nothing below duplicates it.

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

## Which install do you have?

Three installs exist and they update by different routes, so the first question
is which one you are looking at. One command splits them in two:

```bash
git log --basic-regexp --grep='git-subtree-dir: claude-arsenal\(/\)\?$' \
    --max-count=1 --format=%H | grep -q . && echo subtree || echo non-subtree
```

That is the same test `check_update.sh` makes (`_is_subtree`), down to
`--basic-regexp` — a consumer with `grep.patternType=fixed` in their git config
would otherwise match nothing and see every subtree report as a non-subtree one.

Git cannot tell the two non-subtree installs apart, because they leave the same
history; what separates them is whether the machine has the marketplace plugin.

| | **Plugin install** (the common one) | **Clone-based install** | **Subtree install** |
|---|---|---|---|
| How it got here | `/init`, from the marketplace plugin | `init.py` run from a clone of upstream (`docs/INSTALL.md`) — the cloud-only, CI and fresh-container route | `git subtree add --prefix=claude-arsenal` |
| Tell-tale | no `arsenal` remote, no subtree merge, and `/plugin` lists `claude-arsenal` | the same git state, but no plugin installed | a subtree merge in the history |
| How you update | `/plugin update claude-arsenal`, then `/init` | re-clone upstream at the newer tag and run its `init.py --repo-path .` | `check_update.sh`, then a subtree merge |
| `check_update.sh --check-only` | **INERT — and that is correct.** It reports drift for subtree installs only. Nothing to act on. | **INERT — and that is correct.** Same reason. | reports drift against the newest tag |

The two non-subtree rows are what trips people up. `check_update.sh` runs on
every session (session-start step 0a) and, finding no remote and no subtree,
says the bundle "cannot be updated by merge" — which is true, and reads like a
fault. It is not: neither install was ever going to update by merge. Re-run
`init.py` by whichever of the two routes you have and the bundle is current.

Do not read that message as "you must install the plugin". A clone-based
install has no plugin to update, and telling one to run `/plugin update` sends
it after something that does not exist there.

Adding `git remote add arsenal <marketplace-url>` to a plugin install is
optional. It upgrades that message from inert to a real version comparison,
which is useful — but a remote is local git config, so every clone needs it
added again, and it still cannot merge anything without a subtree.

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
2. **Delete the vendor marker if one came with the copy:** `rm -f
   <project>/.claude/skills/specify/.arsenal-vendored`. This is what actually
   protects a fork, and it is worth being exact about. `/init` replaces a
   skill folder with `shutil.rmtree` when it carries `.arsenal-vendored`, and
   leaves it alone when it does not — project-level precedence decides which
   skill *loads*, not which files survive an upgrade. Copying from the cache
   (step 1) is safe because the marketplace does not ship the marker; copying
   from another project's `.claude/skills/`, which is the more natural thing to
   do once you have a fork you like, carries it — and the next `/init` deletes
   your fork without a word. The prune pass removes a marked folder the same
   way when its section is switched off.
3. Edit the copy. With no marker it is yours: `/init` prints
   `skills: <name> exists and is not arsenal-vendored — left alone`. Look for
   that line after the next upgrade; it is the receipt that your fork survived.
4. (Optional) Document the divergence in your project's `CLAUDE.md` so
   teammates know the local version is the source of truth.
5. Run `validate.py` on the fork before committing — the meta-skill's
   rubric still applies:

   ```bash
   uv run python \
     ~/.claude/plugins/cache/claude-arsenal/plugins/skill-workshop/skills/skill-workshop/scripts/validate.py \
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
  ~/.claude/plugins/cache/claude-arsenal/plugins/skill-workshop/skills/skill-workshop/scripts/audit_library.py \
  ~/.claude/plugins/cache/claude-arsenal/plugins/*/skills \
  --by-plugin
```

A breach prints `OVER cap by N chars` and a hint to `/plugin disable
<plugin>` for tasks that do not need that plugin's skills.

---

## Upgrading

Re-run `/init` and commit. One command refreshes everything upstream owns:

```bash
/init                      # or: python3 <clone>/plugins/core/skills/init/scripts/init.py --repo-path .
git add .claude claude-arsenal .github && git commit -m "chore: update claude-arsenal"
```

It re-copies the skills into `.claude/skills/`, prunes any the new version no
longer ships, and refreshes `claude-arsenal/` (`AGENTS.md`, `references/`,
`bin/`, `scripts/`). It never writes into `arsenal/` — your tasks, specs,
plans, config and session state are yours and no upgrade touches them.

On the CLI, `/plugin update claude-arsenal` refreshes the plugin that gives you
`/init` itself. That is a different thing from what your project ships:
updating one does not update the other, and it is the project commit that every
session actually loads.

> **Before v2.0.0** the skills were vendored by a separate `vendor-skills.sh`
> step, and v1.0.0–v1.1.0 additionally declared the plugins in the host repo's
> `.claude/settings.json`. Cloud sessions ignore that declaration, so `/init`
> now removes it and does the vendoring itself. Nothing to do but re-run it.

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

**An old pin re-installs the same version and reports success.** Before v2.0.0
the pin was a literal `ARSENAL_REF` in the consumer's Makefile, and nothing
compared it against the latest tag: a repo three releases behind re-vendored the
*same old version* and printed `vendored N skill(s)` — a success message for an
update that did not happen. `/init` from an installed plugin no longer has that
failure mode, but the clone-based form still takes a `--branch`, so check it:

```bash
git ls-remote --refs --tags https://github.com/nuncaeslupus/claude-arsenal.git 'refs/tags/v*' \
  | sed 's|.*refs/tags/||' | sort -V | tail -1
```

`check_update.sh` is the automated counterpart, but it is **inert unless the
consumer added an `arsenal` git remote**, which most have no reason to do.

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

Whether you can roll back at all depends on which install you have — the table
under *Which install do you have?* splits them. **Two of the three pin a ref and
roll back cleanly. The plugin install does not.**

**Clone-based install.** Re-clone upstream at the older tag and re-run its
installer against your project — the same command as a forward update, with
`--branch` pointing backwards:

```bash
git clone --depth 1 --branch v4.12.0 \
    https://github.com/nuncaeslupus/claude-arsenal.git /tmp/arsenal-rollback
python3 /tmp/arsenal-rollback/plugins/core/skills/init/scripts/init.py --repo-path .
```

**Subtree install.** Both halves of the install are in your own history, so
this is a path restore and nothing more — no merge to unpick, no script to run.
Restore them together:

```bash
git log --oneline -- claude-arsenal | head   # pick the commit before the bad update
git checkout <sha> -- claude-arsenal .claude/skills
git commit -m "chore: roll claude-arsenal back to v4.12.0"
```

**Both paths, not just `claude-arsenal/`.** The subtree carries the bundle —
`AGENTS.md`, `bin/`, `scripts/`, `workflows/` — and nothing else; the skills a
session loads were vendored into `.claude/skills/` and are versioned there. Re-running
`init.py` will not fix a half-restore either: a vendored `init.py` vendors *from*
`.claude/skills/`, so pointed at itself it is a no-op.

If you keep a fork of a vendored skill under `.claude/skills/` (§ *Customising a
vendored skill*), name the vendored subdirectories instead of the whole tree —
the restore does not know which ones are yours.

Reverting the merge commit works too, but `check_update.sh` merges with
`--squash`, so the history holds a squash commit *and* a merge of it and
`git revert -m 1` fails on the wrong one. The path restore sidesteps that.

`check_update.sh` will offer the newest tag again on the next session. That is
correct — it compares against the newest tag, not against what you chose — and
it is your cue to pin deliberately rather than merge on sight.

**Plugin install — there is no self-service rollback.** `/plugin update` fetches
the tip of `main`, and so does removing and re-adding the marketplace: both
rebuild the cache from the same commit, so the remove/add pair this page used to
recommend restored nothing at all. Nothing in the marketplace manifest takes a
version, so there is no older release to ask for.

What you can actually do, in order:

1. **Check the cache for the tag.** The cache is a git clone, so if the tag is
   there you can sit on the old bundle until the next update:

   ```bash
   cd ~/.claude/plugins/cache/claude-arsenal
   git tag -l 'v*' | tail -5          # a shallow clone may list none
   git checkout v4.12.0               # then re-run /init to re-vendor
   ```

   This is a stopgap, not a pin: the next `/plugin update` wipes the cache and
   takes the checkout with it.

2. **Move to the clone-based install**, which takes `--branch` and therefore
   rolls back properly. `docs/INSTALL.md` has the route; it is the same one CI
   and fresh containers use.

3. **File an issue** against `nuncaeslupus/claude-arsenal` with the commit SHA
   the cache holds (`git -C ~/.claude/plugins/cache/claude-arsenal rev-parse
   HEAD`) and the version you were on before. A bad release is worth a fix
   forward, which every install gets on its normal update route.
