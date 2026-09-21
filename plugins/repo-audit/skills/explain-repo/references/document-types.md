# Document types

## Contents

- [Choosing a type](#choosing-a-type)
- [Pitch](#pitch)
- [Deep-dive](#deep-dive)
- [Interview prep](#interview-prep)
- [Onboarding guide](#onboarding-guide)
- [Status brief](#status-brief)
- [Input: what feeds every type](#input-what-feeds-every-type)

Load before writing, to pick the shape and know what each one is actually
for. Five defaults, not a closed list — a genuinely different need (a
security posture summary, a migration guide) is the same discipline in a
new shape; don't force it into the nearest of these five if it doesn't fit.

## Choosing a type

Ask, if it's not already obvious from the request: who reads this, and what
do they decide or do afterward? The answer picks the type — these are
audiences and purposes first, templates second.

## Pitch

**For:** someone deciding whether to look closer — evaluate, adopt, or take
an interest. One page. Leads with what the repo actually does and the one
or two things that make it worth attention, backed by something concrete
(a real number, a real mechanism) rather than adjectives. Ends before it
overstays — this is a hook, not the deep-dive.

## Deep-dive

**For:** genuinely understanding how the thing works, mechanism by
mechanism. The fullest of the five: a self-interview or Q&A structure works
well here because it mirrors how understanding actually gets built —
"how does X work" followed by "and what happens when Y" — but any structure
that goes deep without hand-waving is fine. Include the honest limits
alongside the mechanisms; a deep-dive that only explains the happy path
isn't deep.

## Interview prep

**For:** defending or discussing the project out loud — a job interview, a
stakeholder Q&A, a design review. Shape it as "if they ask X, say Y": a
cheat-sheet of crisp answers, plus the deeper material to expand from if
asked a follow-up. Draw the honest-limits material from what the source
analysis already verified, and from the findings ledger's `queued`/`issue`
rows specifically — "here's a known rough edge, and here's the task already
queued for it" is a stronger answer than either silence or an unprepared
admission, because the adversarial work has already been done.

## Onboarding guide

**For:** a new contributor's first real session in the repo. Practical, not
narrative: where the major pieces live, how to run it and confirm it works,
what the project's own conventions are (cite its `CLAUDE.md`/`AGENTS.md` if
it has one), and two or three concrete first tasks — pull these from the
findings ledger's `queued` rows when they exist, since those are
already-scoped, gated work waiting to be claimed.

## Status brief

**For:** a stakeholder or teammate check-in on where things stand. What's
solid (verified, working, tested), what's fragile (confirmed findings not
yet resolved), what's in flight (queued tasks, filed issues), framed by
recency — what changed since the last time this was generated, if that's
known. Short; this is a status update, not the deep-dive.

## Input: what feeds every type

Prefer an existing `repo-audit` findings JSON (the shape
`validate_findings.py` checks) as the source of record — it's already been
through the hunt and verify passes, so its claims are load-bearing. When
none exists, a light orient-only read (README, root memory file, top-level
layout — the same first step `repo-audit`'s own understand pass starts
with) is an acceptable fallback for the Pitch or Onboarding types, which
don't need deep verification to be useful. Interview prep and the Status
brief specifically lean on verified findings and ledger status — say so if
generating either from a light read instead, so the reader knows the
adversarial work hasn't actually been done yet.
