# Workspace and composition

Load when deciding where a skill lives, debugging skill discovery, or
planning a plugin migration.

## Single-depth folder layout

```
plugins/<plugin>/skills/<skill>/SKILL.md          # ← discovered
plugins/<plugin>/skills/<scope>/<skill>/SKILL.md  # ← INVISIBLE
.claude/skills/<skill>/SKILL.md                   # ← discovered (personal/project scope)
```

Skill discovery walks one level under each library root. A nested
container directory is silently invisible to the registry — there is
no warning, the skill simply never appears. The only fix is to
flatten: drop the container dir and promote the skill folder one
level up.

## Scope tiers

| Tier | Path | When to use |
|---|---|---|
| Project | `<repo>/.claude/skills/<name>/` | Repo-shipped skills everyone in the project uses, but not packaged as a plugin yet. |
| Personal | `~/.claude/skills/<name>/` | Per-developer preferences. Extend, never override repo skills. |
| Plugin | distributed via `/plugin install <plugin>@<marketplace>` | Cross-repo or cross-team sharing. Names get a `<plugin>:<skill>` namespace. The Claude Code plugin manifest does not support formal dependencies between plugins — coupling between plugins is documented in the marketplace description and via prose routing in SKILL.md bodies. |

A personal skill named the same as a project skill takes precedence
locally — useful for a developer override, dangerous if it diverges
silently. Avoid name collision.

## Cross-cwd discovery

Claude Code's skill router walks one level under `.claude/skills/`,
which makes opening a sub-directory IDE (e.g. VS Code in a
sub-package) see only that sub-tree. The fix is plugin distribution:
ship the skills as a plugin, and `/plugin install <plugin>@<marketplace>`
makes them surface from any cwd.

## Plugin namespacing

Once a marketplace publishes a plugin, every skill it ships becomes
namespaced as `<marketplace-slug>:<plugin>:<skill>`. For this
marketplace:

- `skill-creator` (inside the `skill-creator` plugin) ⇒
  `claude-arsenal:skill-creator:skill-creator`. Inside the slash
  command surface that is `/skill-creator:skill-creator`; the inner
  duplication is intentional ("plugin owns one same-named skill").
- `specify` (inside the `core` plugin) ⇒
  `claude-arsenal:core:specify`. Slash form `/core:specify`.

Conventions:

- Plugin slug describes the plugin's scope (`skill-creator`, `core`).
  Single noun when possible.
- Skill names inside the plugin keep their existing folder name. Any
  `<scope>-` prefix is dropped when the plugin slug already encodes
  the scope (`core:triage-issues`, not `core:platform-triage-issues`).

## Composition rules

- **One capability per skill.** A capability skill named `github`
  does GitHub. Not GitHub *and* GitLab. If the description uses
  "and", split.
- **Workflows are orchestrators.** A workflow SKILL names capabilities
  in prose ("use the `github` skill to read the PR; use `ship`
  to confirm the cut") and lets the model route. It does not link to
  peer SKILL.md or peer scripts.
- **Capability skills don't call other capability skills.** If
  capability A needs B, the workflow that loads A also loads B and
  composes.
- **Generic capabilities lose any team-specific prefix** so consumers
  outside the originating team can adopt them later without renaming.

## Name collisions with upstream skills

Personal-scope skills (`~/.claude/skills/<name>/`) take precedence
over plugin-scope skills with the same name, so a name this
marketplace shares with a skill shipped elsewhere is a name that can
be silently shadowed.

This meta-skill was called `skill-creator` until v1.0.0, which is also
the name of the meta-skill in `anthropics/skills/` and of a built-in on
some surfaces. Sharing it was deliberate — continuity with the research
literature — and it went wrong in the way shadowing always does: a
cloud session invoking `skill-creator` got the built-in, whose surface
is eval- and benchmark-focused, in place of this one's validator,
library auditor, alignment runner, and rubric. Nothing announced the
substitution. A skill that is *missing* is obvious; a skill quietly
replaced by a different skill of the same name is not, and this one is
a gate, so the failure was silent in both directions.

Hence `skill-workshop`. When picking a name for a new skill, check it
against the skills your consumers already have, not just against this
library — and prefer a name no upstream would plausibly choose.
Namespacing (`claude-arsenal:skill-workshop:skill-workshop`) resolves
the plugin-scope case, but it does not help a bare invocation or a
vendored copy, which is where the shadowing actually bites.
