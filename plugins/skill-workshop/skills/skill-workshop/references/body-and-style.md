# Body and style

## Contents

- [Length budget](#length-budget)
- [What belongs in the body](#what-belongs-in-the-body)
- [Recommended sections](#recommended-sections)
- [What does NOT belong in the body](#what-does-not-belong-in-the-body)
- [Runbook shape](#runbook-shape)
- [Code blocks](#code-blocks)
- [Tone and voice](#tone-and-voice)
- [Negative triggers in the description](#negative-triggers-in-the-description)
- [Forbidden inside the skill folder](#forbidden-inside-the-skill-folder)
- [Self-contained](#self-contained)

Load when the SKILL.md body is over 400 lines, when readability needs
work, or when reviewing a skill that wanders.

## Length budget

- ≤500 lines hard fail.
- ≤400 lines warn — split into references before this becomes a habit.
- ≤200 lines is the comfortable target for capability skills.
- Workflow skills sit at ~300 lines because routing prose adds bulk.

The body is loaded into context every time the skill activates.
References are loaded lazily, so move depth there.

## What belongs in the body

- The skill's purpose, in one sentence.
- A *post-activation* "When to load" section — see below.
- The exact CLI / function calls a user typically wants.
- Hard constraints the agent must hold across the whole task.
- A list of references with one-line "load this when…" trigger each.
- Ideally a `## Gotchas` section — see below.

## Recommended sections

No section heading is mandatory. The validator does not require any
specific heading structure. But Anthropic's own skill-creator
identifies a recurring pattern and treats one of these sections
("Gotchas") as the single most valuable.

| Section | Purpose |
|---|---|
| `## Overview` (or no heading) | One-sentence purpose and "when to load". |
| `## Workflow` / `## How to use` | The canonical CLI / function-call sequence. |
| `## Examples` | Worked examples — promote to a reference if >30 lines. |
| `## Gotchas` | Real failures observed during use. Each entry says *what* goes wrong AND *why*, not just the prohibition. |
| `## References` | Link list with one-line "load this when…" triggers. |

The `Gotchas` section earns its keep over time. Seed it on day one
with the failure modes you discovered while authoring; add to it
whenever a real session surfaces a new one.

### Activation trigger vs. post-activation "When to load"

These are two different surfaces and must not be conflated.

- **Frontmatter `description`** is the activation trigger. It is the
  only thing the model sees in the skill listing *before* the body
  loads, so it decides *whether* the skill activates. Capped at ~1024
  characters.
- **Body "When to load" section** is read *after* the skill is already
  in context. It earns its keep when it does at least one of:
  1. **Self-check** — gives the agent a chance to defer if activation
     was a near-miss ("if you're already inside workflow Y, defer").
  2. **Nuance that doesn't fit in 1024 chars** — long edge cases the
     activation trigger can't hold.
  3. **Meta guidance while the skill is loaded** — e.g. "the body is
     short; references are lazy-loaded; don't pre-fetch all of them".

If the body "When to load" only restates the description, drop it.
Repetition without one of the three roles above wastes the budget.

## What does NOT belong in the body

- Long examples — move to a reference.
- Reasoning, justification, derivations — move to a reference or to the
  research doc.
- Time references ("recently we changed X", "yesterday's incident") —
  these rot. State the current rule, not its history.
- Names of who decided what — irrelevant to the agent.
- TODOs / stubs / "will be added later" — finish or remove.
- Markdown links to peer skills' SKILL.md or scripts — never. Always
  reference peer skills by name in prose.

## Runbook shape

A skill earns its keep as a procedural anchor, not as a knowledge
store. Across ~8,100 agent trial records, procedural anchoring —
stable action sequences, setup steps, verification routines — carried
the large majority of the cases where a skill changed the outcome,
while explicit knowledge injection carried a small minority (Jiang et
al., *Demystifying Agent Skills*, https://arxiv.org/abs/2608.14036).
The same study measured the payoff concentrating in execution
robustness: environment-setup and output-format failures fell sharply,
while high-level reasoning errors held steady.

Two consequences for the body.

**Every step carries its own check.** Name what confirms the step
worked — the command, its exit code, the file that now exists. A step
written as "run the tests" leaves the agent no way to distinguish a
pass from a suite that never ran; "run `make test`; it exits 0" does.
Steps without checks are where a run diverges silently and keeps going.

**Background moves to a reference.** Imperative voice is not the same
as procedural content: a section can be verb-first from top to bottom
and still be a tutorial about a domain. Keep the ordered actions in the
body and push the explanation behind a reference, where it costs
nothing until something opens it.

## Code blocks

- Fenced with triple backticks plus a language tag (`bash`, `python`,
  `yaml`, `json`).
- Balanced — every opening fence has a closing fence. The validator
  fails on imbalance.
- Short. If a code block is over 30 lines, it is probably a script —
  put it in `scripts/` and reference it.

## Tone and voice

- **Body voice: imperative.** "Run the validator", "Check the SHA",
  "Open the reference". Verb-first instructions.
- **Description voice: third person.** "Use when …", "Triggered by
  …". Never first or second person in the description.
- Avoid second person ("you should", "you'll see") inside the body
  too — it breaks consistency with Anthropic's own skill-creator
  guidance. The validator soft-warns on `you`-prefixed instructions.
- Terse. One short paragraph beats five bullet points; one bullet
  beats a paragraph when the items are parallel.

## Negative triggers in the description

The description should usually include an explicit *do-not-use*
clause when the skill's surface vocabulary risks false-positive
triggers. Phrases like `Do NOT use for X`, `Avoid for Y`, or
`not for Z`. Anthropic's `docx`/`pptx`/`pdf` skills all do this. The
validator soft-warns when no negative-trigger phrase is present.

## Forbidden inside the skill folder

- `README.md`, `AGENTS.md`, `CHANGELOG.md`, `NOTES.md` at the skill
  root. These are not loaded by Claude Code skill discovery and only
  add confusion. Promote their content to `references/` or delete it.
- Loose `.md` files outside `references/` (anything not `SKILL.md` and
  not under `references/`). The validator flags them.

## Self-contained

A skill must read sensibly with no other skill loaded. Don't say "as
discussed in the related skill"; restate the relevant constraint or
say "see the `<related-workflow>` skill" by name.
