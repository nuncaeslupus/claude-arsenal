---
name: explain-repo
description: Use when the user wants a human-facing document about a repository — a pitch, a deep-dive, interview-prep Q&A, an onboarding guide, or a status brief. Triggers — "explain this repo", "write this up for an interview". Builds from an existing `repo-audit` analysis when available. Always for the user, never the repo. Do NOT use to find bugs — use `repo-audit`.
---

# explain-repo

Turns a repository into whichever document a human actually needs from it —
not a single format, five purpose-built ones. Reads `repo-audit`'s findings
when they exist so the honest parts are already verified, not invented on
the spot.

CANARY: explain-repo-loaded-2026-09-21-fb78d23e-409ac59f361f8f40

## When to load

Load this when the ask is for a document *about* the repo, for a human
reader — "explain this", "write it up", "prep me to talk about this",
"onboarding doc". Not when the ask is to find problems in the repo (use
`repo-audit`) or to change the repo's own code or docs (use `execution` or
whatever skill owns that file). If a request mixes both — "audit this and
then write me an explainer" — run `repo-audit` first; this skill's whole
value is building on verified findings rather than fresh guesses.

## How to use

1. **Get the source material.** Look for an existing `repo-audit` findings
   JSON first — it's already been through a verify pass, so its claims are
   load-bearing. If none exists, do a light orient-only read (README, root
   memory file, top-level layout) instead, and say plainly that this
   document skips the deep verification a full audit would have done.
   *Check: can name what evidence backs each claim before writing prose
   around it.*
2. **Pick the type.** See
   [Document types](references/document-types.md) for the five defaults
   (pitch, deep-dive, interview prep, onboarding, status brief) and what
   each is actually for. Ask which is wanted if it's not obvious, rather
   than guessing and rewriting.
3. **Write it.** This is the part that can't be scripted — the judgment is
   what makes one document a pitch and another a deep-dive from the same
   facts. Keep every claim traceable to something the source material
   actually established.
4. **Render and publish, as the user's document.** Build the page with
   `${CLAUDE_SKILL_DIR}/scripts/create_artifact.py` (see its module
   docstring for the input JSON shape) and publish it as an Artifact when
   the tool is available, otherwise a local file. State plainly when handing
   it over: this is for the user, not committed to the repo. *Check: the
   handoff message says who the document is for, not just what it
   contains.*

## Gotchas

- **A document is not a repo contribution.** Every one of the five types is
  for the person who asked, full stop — never propose committing a pitch,
  a deep-dive, or an interview-prep doc into the target repo. If something
  in it is genuinely worth the repo having (a corrected fact, a missing
  reference page), that's a separate, narrow, specific fix — not a reason
  to commit the document itself.
- **Unverified material reads as verified unless flagged.** A document
  built from a light read instead of a full `repo-audit` pass looks
  identical to one built from verified findings unless it says otherwise.
  Say which one this is, especially for interview prep, where the whole
  value is that the hard questions were already checked.
- **The findings ledger's `queued` and `issue` rows are an asset, not an
  embarrassment.** A known rough edge with a task already queued for it is
  a stronger answer — in interview prep, in an onboarding guide's "first
  tasks" — than either hiding it or admitting it with nothing behind the
  admission.

## References — load on demand

- [Document types](references/document-types.md) — load before choosing a
  type and writing, for what each of the five is for and what feeds it.
