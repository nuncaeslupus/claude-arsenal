# Improvements log

Load when an observed gotcha needs recording, or before planning the
next refactor pass to harvest accumulated notes.

## Format

Entries are dated, terse, and structured:

```markdown
## YYYY-MM-DD — short title

**What:** one-line observation.
**Where:** file path or skill name.
**Suggested fix:** one short recommendation, or "deferred" if the
fix needs a separate plan.
```

No multi-paragraph rationale — link to a tracker ticket / PR / memory
note if context is needed.

## When to add an entry

Add an entry when *any* of:

- A script flag is undocumented or behaves differently from the docs.
- A skill triggered when it shouldn't have, or didn't trigger when it
  should.
- A refactor uncovered a structural issue that should outlast the
  current PR.
- A repeated friction shows up across sessions.

If you find yourself fixing the same issue twice, the entry is overdue.

## When to drain entries

When planning the next skill-system refactor (or every quarter,
whichever comes first), open this log and decide for each entry:

- *Fix it now* — schedule into the upcoming PR.
- *Promote to a rule* — move into the matching reference doc and add
  a validator check.
- *Drop* — no longer relevant; remove the entry.

The log should rarely exceed 30 entries. If it does, drain.

## Entries

<!-- Newest first. Add new entries at the top. -->

## 2026-08-23 — loading-verification evals are never executed

**What:** every skill ships `evals/loading_verification.json` and the
validator checks its schema, but nothing ever runs the prompts. The
schema half is sound — canary presence, canary-to-SKILL.md match and
library-wide canary uniqueness are all enforced, and a scan found no
skill whose `negative_control` leaks into its own body, no empty or
duplicated prompt array, and no `skill` field disagreeing with its
folder. The unmeasured half is trigger rate.
**Where:** `plugins/*/skills/*/evals/`, `Makefile`, `.github/workflows/`.
**Suggested fix:** blocked, not deferred. `claude plugin eval` is the
right runner and needs no code here, but it answers `plugin eval is
currently in early access`. A hand-rolled harness on `claude -p` was
measured and rejected: `--bare` skips keychain reads so the run fails
`Not logged in` without an API key, and its tool list carries no
`Skill` entry to detect against; without `--bare`, SessionStart hooks
and every other installed plugin compete for the same prompt, so the
number describes the operator's machine rather than the description
under test. Each skill would also need a fixture repo — a gate prompt
against an empty directory measures missing context, not routing.
Revisit when early access opens.

## 2026-05-08 — container directories swallow skills silently

**What:** a SKILL.md nested one container directory deep
(`plugins/<plugin>/skills/<scope>/<name>/SKILL.md`) never registers
with skill discovery. No warning fires — the skill is simply invisible.
**Where:** any plugin that groups skills under a category folder.
**Suggested fix:** promote each nested SKILL.md one level up (drop the
container dir, or rename the dir to be the skill itself).
