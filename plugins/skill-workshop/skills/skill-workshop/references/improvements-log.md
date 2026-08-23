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
validator checks its schema, but no Makefile target and no CI job ever
runs the prompts inside it. Trigger-rate and misapplication claims
therefore have no measurement behind them.
**Where:** `plugins/*/skills/*/evals/`, `Makefile`, `.github/workflows/`.
**Suggested fix:** deferred — needs a runner design (which model, how
scored, how often) rather than a drive-by target.

## 2026-05-08 — container directories swallow skills silently

**What:** a SKILL.md nested one container directory deep
(`plugins/<plugin>/skills/<scope>/<name>/SKILL.md`) never registers
with skill discovery. No warning fires — the skill is simply invisible.
**Where:** any plugin that groups skills under a category folder.
**Suggested fix:** promote each nested SKILL.md one level up (drop the
container dir, or rename the dir to be the skill itself).
