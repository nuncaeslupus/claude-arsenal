# Refactor cookbook

## Contents

- [Split an oversized SKILL](#split-an-oversized-skill)
- [Promote a loose .md to references](#promote-a-loose-md-to-references)
- [Add ToCs to references](#add-tocs-to-references)
- [Tighten a description](#tighten-a-description)
- [Merge two skills](#merge-two-skills)
- [Extract a capability](#extract-a-capability)
- [Retire a skill](#retire-a-skill)
- [Redirect callers via prose](#redirect-callers-via-prose)
- [Duplicate-and-document a helper](#duplicate-and-document-a-helper)

Load when restructuring the skill library. Each entry is a recipe
with the steps you should run, the validation gate after, and the
common pitfall.

## Split an oversized SKILL

**When:** body >400 lines, or a section is loaded in <50% of activations.

1. Identify the lazy-loadable section. It is usually a worked example,
   a check list, or a rule derivation.
2. Move it to `references/<topic>.md`. If it is >100 lines, add a
   `## Contents` ToC.
3. In `SKILL.md`, replace the section with a one-line link bullet:
   `- [Topic](references/topic.md) — load when ...`.
4. Run `validate.py` on the skill. Fix any path / link warnings.
5. Run a smoke prompt that previously needed the moved content; verify
   the agent now opens the reference.

**Pitfall:** moving content but leaving a stub of the same length.
Either move it cleanly or don't move it.

## Promote a loose .md to references

**When:** the skill folder has `NOTES.md` / `README.md` / `CHANGELOG.md`
at the root.

1. Skim the file. If the content is dead, delete.
2. If it is live but capability-specific, move to
   `references/<topic>.md` and add a link from `SKILL.md`.
3. If it is project-wide (not capability-specific), move to `docs/`
   or `CLAUDE.md` per the boundary rules.
4. Run `validate.py`.

## Add ToCs to references

**When:** any `references/*.md` is over 100 lines without a ToC.

1. Open the reference. Skip its own frontmatter / title.
2. Insert a `## Contents` heading + bullets linking to each `##`
   heading in the file.
3. Anchors are auto-generated from the heading slug — verify by
   clicking through.

## Tighten a description

**When:** validate.py warns on `description` cosine ≥0.85 with a
sibling, or the skill is mis-routing.

1. Identify the trigger phrase that would distinguish the two skills.
   Usually a URL pattern, an exact CLI form, or an entity ID format.
2. Add the distinguishing trigger to one description; remove
   overlapping vocabulary from the other.
3. Re-run `audit_library.py`. Cosine should drop below 0.85.
4. If it doesn't, the two skills probably should merge — see below.

## Merge two skills

**When:** descriptions overlap structurally (both fetch X, both
investigate Y) and routing is genuinely ambiguous.

1. Pick a winning name. Capability skills win generic; workflow skills
   win when they orchestrate.
2. Move the loser's content into the winner's body or references.
3. Move the loser's scripts into the winner's `scripts/`.
4. Delete the loser's folder.
5. Update every prose mention of the loser across SKILL.md files.
   `git grep` is your friend.
6. Run `audit_library.py` to confirm description-overlap drops.

## Extract a capability

**When:** a workflow skill ends up running ≥3 invocations of the same
external tool, or two workflow skills both embed Tool X logic.

1. Create a new capability skill named after the tool (`tool`, no
   prefix if generic).
2. Move the tool-specific scripts into the new skill's `scripts/`.
3. Move tool-specific reference material into the new skill's
   `references/`.
4. In the workflow skills, replace embedded tool prose with a one-line
   prose mention: "Use the `tool` capability skill to fetch X."
5. Re-run validators on all touched skills.

## Retire a skill

**When:** the skill's content has migrated elsewhere, or it duplicates
a sibling.

1. Decide whether anything should be folded into another skill's
   references (capture rare bug catalogues there) before deletion.
2. Delete the folder.
3. Search for prose mentions of the skill name across all `SKILL.md`
   files; rewrite them to point at the new owner.
4. Update `MEMORY.md` if it mentions the dead skill name.

## Redirect callers via prose

**When:** a skill name has changed or its scope has narrowed.

1. In every workflow that previously routed to the old name, replace
   the prose mention with the new name.
2. Do not link to the new SKILL.md; just say its name (the model
   will route).
3. Run a smoke prompt against the old workflow; confirm the new
   capability activates.

## Duplicate-and-document a helper

**When:** a script is needed by two skills and there is no clean home
in only one.

1. Pick the canonical owner. The capability skill that knows the
   helper's domain wins (e.g. `jira` owns `fetch_jira_ticket.py`).
2. Copy the script into each consumer's `scripts/`.
3. Top of each copy gets the duplication header listing every
   sibling path, with the canonical marked `(canonical)`.
4. Run `sync_duplicates.py --check`; should report a clean group with
   matching SHAs.
5. Whenever the canonical changes, run
   `sync_duplicates.py --apply <canonical-path>` to propagate.
