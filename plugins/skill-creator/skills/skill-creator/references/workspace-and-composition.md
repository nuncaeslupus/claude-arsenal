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
- `discovery` (inside the `core` plugin) ⇒
  `claude-arsenal:core:discovery`. Slash form `/core:discovery`.

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
  in prose ("use the `github` skill to read the PR; use `release-readiness`
  to confirm the cut") and lets the model route. It does not link to
  peer SKILL.md or peer scripts.
- **Capability skills don't call other capability skills.** If
  capability A needs B, the workflow that loads A also loads B and
  composes.
- **Generic capabilities lose any team-specific prefix** so consumers
  outside the originating team can adopt them later without renaming.

## Name collisions with upstream skills

Some skill names exist in `anthropics/skills/` (notably the
`skill-creator` meta-skill). This marketplace deliberately uses the
same name to keep continuity with the research literature; its
surface is intentionally different (mechanical validator,
plugin-shipped, memory-layer validator, no description-optimisation
loop).

Personal-scope skills (`~/.claude/skills/<name>/`) take precedence
over plugin-scope skills with the same name. If a developer installs
the upstream `skill-creator` personally, the marketplace one is
shadowed. Two cures:

1. Until the plugin lands: have the developer remove the personal
   copy or rename it (`mv ~/.claude/skills/skill-creator
   ~/.claude/skills/upstream-skill-creator`). The plugin skill will
   then surface again.
2. After the plugin lands: skills are namespaced
   (`claude-arsenal:skill-creator:skill-creator`); the collision goes
   away.
