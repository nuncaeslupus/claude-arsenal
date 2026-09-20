# Output shape

Load before synthesizing the artifact and the findings ledger, or before
running either validator script.

## Three deliverables, not one

1. **The write-up.** A self-interview-style artifact (Q&A sections, an
   adversarial section, comparisons if useful, a findings summary) built
   with `${CLAUDE_SKILL_DIR}/scripts/create_artifact.py` — see that script's
   module docstring for the exact input JSON shape. Publish it as an
   Artifact when the Artifact tool is available; otherwise write it to a
   local Markdown or HTML file and say so. This is for the person who
   asked, not for the target repo — it never gets committed there.
2. **Verified, low-risk doc fixes.** A stale number, a broken cross-link, a
   factual claim the code contradicts — corrected directly in the target
   repo, through its own normal contribution path (its branch naming,
   commit style, version-bump rules — read them first, don't assume this
   repo's conventions). Run `${CLAUDE_SKILL_DIR}/scripts/validate_markdown.py`
   against any new or changed `.md` files before proposing them.
3. **The findings ledger.** Every finding, split by what happened to it —
   fixed directly, flagged for the maintainer's call, or reported as a bug
   (with a suggested direction, not a unilateral fix). Build it as JSON
   matching `${CLAUDE_SKILL_DIR}/scripts/validate_findings.py`'s input
   shape, run the validator, then feed the same structure into
   `create_artifact.py`'s `ledger` field so it renders inside the write-up.

## What never goes into the target repo

The audit methodology itself — this skill's references, the adversarial
question bank, a findings scratch file, the raw research-agent transcripts.
Those are this skill's working material, not the target repo's
documentation. If a genuinely new subsystem turns out to be undocumented
anywhere, the fix is a new reference page describing *that subsystem*, in
the target repo's own doc conventions — never a copy of this skill's
process.

## Splitting "fix it" from "report it"

Fix directly: anything mechanically verifiable and low-risk — a count that's
provably wrong, a link that's provably broken, a claim the code provably
contradicts.

Report instead of fixing: anything that trades off one design against
another, removes or changes behavior, or needs the maintainer's product
judgment — a dead config key (wire it up, or delete it — that's their call),
a missing feature, an architectural gap. File it as an issue in the target
repo (if the audit has write access there) or as a ledger row the user acts
on themselves; don't open a PR for it unasked.
