# Content quality rules

## Contents

- [Purpose](#purpose)
- [How to read this file](#how-to-read-this-file)
- [Gate protocol](#gate-protocol)
- [Findings format](#findings-format)
- [A. Prose shape](#a-prose-shape)
- [B. Example currency](#b-example-currency)
- [C. Reference cost](#c-reference-cost)
- [D. Evergreen-doc-style](#d-evergreen-doc-style)
- [E. Trigger and boundary quality](#e-trigger-and-boundary-quality)
- [F. Procedural shape](#f-procedural-shape)
- [Out of scope for this checklist](#out-of-scope-for-this-checklist)

## Purpose

This file is the second of two author-checkable rule lists every skill
walks. The first — `references/skill-rules.md` — covers **structural
shape**: frontmatter keys, body length, anchor presence, naming. Its
rules are mostly pattern-matchable; a reviewer can tick them off in a
glance.

This file covers **content quality**: whether the prose a reader
actually faces reads cleanly, whether examples still resolve, whether
the description disambiguates from sibling skills. The rules are
**interpretive** by design. Each one forces the reviewer to read a
stretch of prose and make a judgment, not just confirm a token exists.

The two rubrics together drive the gate. Structural pass first
(cheap, deterministic), content pass second (slower, judgment-heavy).
A skill that passes both is well-formed *and* well-written.

## How to read this file

Each rule has four parts:

- **ID** — local to this rubric (`Q-PROSE-1`, `Q-EX-2`, …). The
  `Q-` prefix marks it as a quality rule so findings from the two
  rubrics never collide on ID.
- **Tier** — `must` (alignment failure surfaces as a must finding) or
  `should` (surfaces as a should finding).
- **Check** — one-line statement of what alignment looks like. The
  negation of this line is the finding message.
- **Deep dive** — pointer to the topical reference where the *why*
  and worked examples live.

If a rule's check needs more than one line to evaluate, the deep-dive
reference is the place to read.

## Gate protocol

The gate runs at the same two moments as the structural rubric:

**1. Per-edit gate (mandatory, in-session).** When a commit touches
any file inside a skill folder, walk every rule in this file against
the **current state** of every file in that skill folder, in addition
to the structural walk. Both walks evaluate alignment, not change.
Append both findings blocks to `findings.md` under the same dated
header.

**2. Bulk audit (periodic).** Run the `audit_alignment.py` runner
twice — once with `--input references/skill-rules.md`, once with
`--input references/content-quality-rules.md`. Each run emits per-skill
prompt blocks that a Claude session walks one at a time. No Anthropic
API call.

**Must behavior.** When a `must` finding fires, surface the list to
the user and stop. Do not auto-fix. The user fixes (Claude applies),
dismisses with a reason captured in the commit body, or defers
(recorded in `findings.md`; commit proceeds, the finding stays
visible).

**Should behavior.** Surface in the same findings list; the commit
proceeds regardless. The user acts when they choose.

## Findings format

Append a content-pass block under the same dated header as the
structural pass. Distinguish the two by a `(content)` tag after the
rule ID so reviewers can tell which rubric flagged which issue.

```
## 2026-05-15

SKILL.md is not aligned with the guidelines:
  must   line 88   Paragraph runs 187 words without sub-structure  (Q-PROSE-1 content)
  should line 142  Gotcha "be careful with tokens" lacks a concrete failure mode  (Q-EX-4 content)

references/topic-a.md is not aligned with the guidelines:
  should line 4    Opens with "This document covers …" rather than a trigger  (Q-REF-3 content)

(other files in this skill are aligned)
```

A clean run writes a single line under the same date:

```
## 2026-05-15 — all files aligned with guidelines
```

`findings.md` is gitignored: it is the author's living log, not part
of the PR diff.

---

## A. Prose shape

Deep dive: `references/body-and-style.md`.

These rules force the reviewer to read each paragraph and decide
whether it would land cleanly on a tired reader's first pass. A token
search cannot answer that.

| ID | Tier | Check |
|---|---|---|
| Q-PROSE-1 | must | No paragraph in `SKILL.md` or any `references/*.md` exceeds ~120 words (~6 sentences) without internal structure (sub-bullets, sub-heading, code block). A long unbroken paragraph signals dense reasoning that should be split. |
| Q-PROSE-2 | should | The first sentence of every `##` section makes the most important claim of that section. Sections where the lede only emerges in paragraph 2 fail. |
| Q-PROSE-3 | should | The `SKILL.md` body holds imperative voice ("Run X, then Y") throughout — not just at the start. Mid-body switches to second person (`you should …`) or passive (`X is run by …`) fail. |
| Q-PROSE-4 | should | Bare `MUST` / `ALWAYS` / `NEVER` / `IMPORTANT` styling is justified inline (the next clause names a concrete failure if violated) or rewritten as plain prose. Categorical assertions without a reason train readers to skip them. |
| Q-PROSE-5 | should | Each bullet list is parallel: every bullet shares the same grammatical shape and the same level of detail. A list that mixes single-word items and full-sentence items breaks the reader's rhythm. |

## B. Example currency

Deep dive: `references/body-and-style.md`, `references/scripts-and-cli-conventions.md`.

These rules force a file-existence check and a "could this fail
today" judgment on every example and gotcha.

| ID | Tier | Check |
|---|---|---|
| Q-EX-1 | must | Every script-invocation example in `SKILL.md` or `references/*.md` names a script that exists on disk today. A `python3 .../missing.py` line is a stale example. |
| Q-EX-2 | must | Every file path in body prose (other than `<placeholder>` forms) resolves on disk. `plugins/<plugin>/skills/<name>/scripts/<known-script>.py` must exist; `<token>` / `<ticket>` placeholders are fine. |
| Q-EX-3 | should | Each prescriptive paragraph (one that says "do X" or "run Y") either ships an example or is one self-contained sentence. Prescriptions without examples are unverifiable. |
| Q-EX-4 | should | Each entry in a `## Gotchas` section names a concrete failure mode a reviewer can imagine triggering today. "Be careful", "Watch out for", "It depends" without specifics fails. |
| Q-EX-5 | should | Each gotcha entry says *what* goes wrong AND *why*. A bare prohibition with no underlying mechanism rots — readers can't tell when it stops applying. |

## C. Reference cost

Deep dive: `references/references-and-chunking.md`.

These rules force a cumulative-byte tally and a relevance read on
each reference's opening lines.

| ID | Tier | Check |
|---|---|---|
| Q-REF-1 | should | Cumulative byte size across all `references/*.md` cited at lazy-load time stays under ~20 KB (rough proxy for ~5000 tokens, the Anthropic level-2 budget). A skill loading >5 references typically over-loads. |
| Q-REF-2 | must | Every reference file is cited at least once from `SKILL.md` with a concrete "load when X" trigger, not a topic. "Load this for backend details" fails; "Load when extending the rule set" passes. |
| Q-REF-3 | should | A reference's first paragraph (or its `summary` / `load_when` frontmatter when present) states the trigger and the audience. References opening with "This document covers …" fail. |

## D. Evergreen-doc-style

Deep dive: `references/body-and-style.md`. Cross-cuts the
`feedback_evergreen_doc_style` and `feedback_no_skill_counts` memory
entries.

These rules guard against the four categories of content rot every
prior refactor has had to clean up. The reviewer reads each `## `
section in `SKILL.md` and every `references/*.md` looking for these
markers.

| ID | Tier | Check |
|---|---|---|
| Q-EVER-1 | must | No research / rule IDs (`R-FM-1`, `R-BODY-9`, `R-XPOLL-5`, `Q-PROSE-1`, …) appear in `SKILL.md` body prose or in any `references/*.md` other than this file and `skill-rules.md` themselves. IDs are rubric vocabulary, not reader vocabulary. |
| Q-EVER-2 | must | No PR numbers (`#22790`), project ticket branch names (`PROJ-1234-…`), or phase markers (`PR8`, `phase 2`) appear in committed body prose. They date the file and rot quickly. Fenced code blocks showing a real git command are exempt. |
| Q-EVER-3 | must | No concrete skill counts (`28 skills`, `five workflow skills`) appear in body prose or committed docs. Use relative phrases ("the library", "each plugin's skills"). |
| Q-EVER-4 | should | No dated callouts (`as of 2026-05-13`, `recently we …`, `yesterday's incident`) appear in body prose. State the current rule, not its history. |
| Q-EVER-5 | should | First-person plural (`we`, `our`, `the team`) is avoided in body prose. `SKILL.md` instructs an agent; first-person plural breaks the imperative voice. Naming the plugin / library is fine ("this plugin's skills"). |

## E. Trigger and boundary quality

Deep dive: `references/frontmatter-and-naming.md`,
`references/inter-document-boundary.md`.

These rules force the reviewer to read the `description` and the
"When to load" section as if they were the only thing the model sees
at activation time.

| ID | Tier | Check |
|---|---|---|
| Q-TRIG-1 | must | The frontmatter `description` trigger names a concrete surface — file path, URL pattern, command name, error string. "Use when working with X" or "Triggers on X-related tasks" fails; "Triggers on any `api.example.com/v2/` URL" passes. |
| Q-TRIG-2 | should | The `description` negative-trigger names a sibling skill (or a specific alternative tool) the user might otherwise pattern-match to. "Do NOT use for unrelated tasks" fails; "Do NOT use for raw HTTP requests (see `github`)" passes. |
| Q-TRIG-3 | should | The `description`'s *what* claim and *when* claim are independent. A tautology ("Use when working with X to work with X") fails. The two clauses must add information when read together. |
| Q-TRIG-4 | should | The body "When to load" section either (a) self-checks with a defer-if clause, (b) adds nuance the 1024-char description could not hold, or (c) gives meta-guidance for after-load behaviour. A section that only restates the description wastes the budget. |
| Q-TRIG-5 | should | Cross-skill mentions in body prose name the sibling skill ("use the `specify` skill") rather than describe its function vaguely ("the workflow that handles specification tasks"). A reviewer should be able to look up the named skill. |

## F. Procedural shape

Deep dive: `references/body-and-style.md`.

These rules force the reviewer to read the body as the agent executes
it, step by step, and ask two questions at each one: can the agent tell
whether this step worked, and is this a step at all rather than a
paragraph about the domain. Voice checks miss both — a body can be
verb-first throughout and still be a tutorial with no checkable state.

| ID | Tier | Check |
|---|---|---|
| Q-PROC-1 | should | Each step in a procedural `SKILL.md` names how to confirm it succeeded — a command, an exit code, a file that now exists, an observable state. "Run the tests" fails; "run `make test`; it exits 0" passes. A step whose outcome the agent cannot check is where execution diverges without anything noticing. |
| Q-PROC-2 | should | The body reads as a sequence of actions, not an explanation of a domain. Material that teaches *why* moves to `references/`; the body keeps what to do, in what order. A section a reader could mistake for a tutorial fails. |

## Out of scope for this checklist

- Anything `skill-rules.md` already covers structurally (frontmatter
  shape, naming regex, body length cap, anchor-presence checks). Walk
  the structural rubric for those.
- Anything `validate.py` already detects mechanically (broken
  cross-cites, missing scripts, dangling anchors). Those surface
  during a normal validator run and need no human judgment.
- Style preferences that have not produced an observed failure mode
  (Oxford commas, em-dashes vs en-dashes, capitalisation of
  identifiers). Promote one only when an incident makes the case.
- Per-domain content correctness (is this gotcha *factually* true for
  this API / this system?). That is review territory, not rubric
  territory — the rubric checks shape and currency, not subject-matter
  accuracy.
