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

## 2026-08-24 — four shipped flags sit outside the argument canon

**What:** after the canon adopted the library's domain flags, four warnings
remain: `init.py --silent` and `--repo-path`, `analyze_mutmut.py --max`, and
`new_task.py`'s `new` verb. Each duplicates something already canonical —
`--quiet`, `--root`, `--limit`, and the `create` verb — so these are findings
the check is right to raise, not gaps in the list.
**Where:** `plugins/core/skills/{init,mutmut-report,queue-add}/scripts/`.
**Suggested fix:** deferred, not blocked. Each rename is a vendored-interface
break touching six to ten files including consumer-facing docs and the shipped
`AGENTS.md`, so it wants a deliberate pass with aliases and a major bump, not a
drive-by rename.
**Resolved 2026-08-31 (v3.0.0)**, and one of the four was misdiagnosed here.
`--silent` and `--max` took canonical aliases (`--quiet`, `--limit`) with the
old spellings still working. `new_task.py` became `create_task.py` — the one
real break, which is what the major carries. But `--repo-path` is **not** a
duplicate of `--root`: `init.py` already uses `--root` for the workspace root
it creates, so collapsing them would merge two concepts rather than remove a
synonym. It joined the canon instead. Reading the argparse block, rather than
trusting this entry, is what caught that.

## 2026-08-23 — loading-verification evals are never executed

**What:** every skill ships `evals/loading_verification.json` and the
validator checks its schema, but nothing runs the prompts. The canary
half is enforced; trigger rate is unmeasured.
**Where:** `plugins/*/skills/*/evals/`, `Makefile`, `.github/workflows/`.
**Suggested fix:** blocked, not deferred. `claude plugin eval` ships in
the build but is gated by `tengu_gb_eval_authed_enable`, a GrowthBook
flag resolved server-side per organization — nothing local opens it (no
telemetry, GrowthBook, gateway, Bedrock or Vertex setting is suppressing
the flag fetch, and the build is current), so it waits on Anthropic
enabling the org. A `claude -p` harness was measured and rejected: $0.098 per prompt, no clean room
(`--bare` loses auth; without it, hooks and other plugins skew routing),
one fixture repo per skill. When it opens, retest `continue` first — it
did not fire on its own load prompt.

## 2026-05-08 — container directories swallow skills silently

**What:** a SKILL.md nested one container directory deep
(`plugins/<plugin>/skills/<scope>/<name>/SKILL.md`) never registers
with skill discovery. No warning fires — the skill is simply invisible.
**Where:** any plugin that groups skills under a category folder.
**Suggested fix:** promote each nested SKILL.md one level up (drop the
container dir, or rename the dir to be the skill itself).
