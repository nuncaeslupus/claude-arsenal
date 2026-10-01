# Research addendum — 2026-10

Findings recorded after `claude-skill-system_v1.17.md` was frozen. That
archive stays unchanged; new rubric rows cite the `§` sections below, and
`audit_rule_drift.py` reads this file alongside it, so a rule ID defined here
counts as documented.

Recorded 2026-10-01, from the 5.5-generation prompting guides and an audit of
the shipped tree against them.

## Contents

- [Sources](#sources)
- [Prompt style](#prompt-style)
- [Reference usage](#reference-usage)
- [Review conduct](#review-conduct)
- [Scope and procedure](#scope-and-procedure)
- [Rules reworded](#rules-reworded)
- [Review bot behaviour](#review-bot-behaviour)

## Sources

Fetched 2026-10-01:

- `platform.claude.com/docs/en/build-with-claude/prompt-engineering/` —
  prompting guides for Opus 5.5, Opus 5, Sonnet 5.5, Fable 5.1, and the
  general prompting best practices.
- `code.claude.com/docs/en/` — skills, sub-agents and hooks.

The shipped digest of these guides is
`plugins/skill-workshop/skills/skill-workshop/references/model-prompting.md`
(rules G1–G21).

## Prompt style

The 5.5 generation follows instructions literally, verifies its own work,
delegates readily and finishes long tasks when told the scope. Prompt text
written to push older models now over-steers. Each rule below has a
mechanical check in `validate.py` (`content.style-*`), reported as a
non-blocking style finding until the shipped tree is clean.

- **R-STYLE-1** — ALL-CAPS emphasis (`MUST`, `NEVER`, `ALWAYS`, `CRITICAL`,
  `IMPORTANT`, `Do NOT`) stays at or below about 3 per 100 prose lines.
  Emphasis now causes over-triggering; a stated reason works better (G11).
- **R-STYLE-2** — No `if in doubt, use X` or `always use X`. Tools that once
  under-triggered now over-trigger on these; say when the tool helps (G11).
- **R-STYLE-3** — No `think step by step` / `think carefully` / `think hard`,
  and no request for reasoning in the response. Effort controls thinking;
  asking for written reasoning can draw a refusal (G1).
- **R-STYLE-4** — No ritual re-checks: `double-check`, `re-verify`, a final
  verification step, verifying one's own work, a subagent to verify. A line
  that names a concrete test, build or typecheck command is a real check and
  is exempt (G2).
- **R-STYLE-5** — No `only report high/critical severity` or
  `be conservative` in review prompts. Followed literally, they under-report;
  report everything with severity and filter separately (G7).
- **R-STYLE-6** — No `hold all findings`, no instruction to minimise tool
  calls, no `avoid the generic AI look`. The first two suppress useful work;
  the last is too vague to act on — name the pattern to avoid (G8, G15).
- **R-STYLE-7** — No hard-coded model names in shipped prose or scripts; use
  tier aliases or config. Exempt: lowercase tier aliases used as config
  defaults, and the consumer `CHANGELOG.md` (G19).
- **R-STYLE-8** — No `Shall I…`, `Next I'll…` or `Do you want me to…` in
  step text for work already requested. An unattended run that ends on a
  question stalls (G4).

## Reference usage

Measured on the shipped tree: several skills load a reference on every
invocation, so splitting it out of `SKILL.md` saved nothing and added a read.

- A reference read on every invocation belongs in `SKILL.md`; if inlining
  makes the skill too big, the skill is too big.
- Every reference link in `SKILL.md` states when to load it. `validate.py`
  reports a mention whose sentence carries no condition
  (`content.ref-unconditional`) (G20).

## Review conduct

- **Q-REV-1** — Review prompts ask for every finding with severity and
  confidence; filtering is a separate step (G7).
- **Q-REV-2** — Delegation is reserved for large, independent, parallel work;
  a subagent is never spawned to verify the delegator's own work (G6).

## Scope and procedure

- **Q-SCOPE-1** — Unrequested changes (cleanup, extra tests, pre-existing
  bugs) are listed as follow-ups in the summary, not made (G3).
- **Q-PROC-1 (reworded)** — Steps that produce code name a real check; no
  ritual confirmation lines (G2).
- **Q-PROSE-1 (reworded)** — `should`, not `must`; shorter paragraphs are
  allowed, and formatting rules say when to format rather than banning it
  (G9, G10).

## Rules reworded

- **R-XPOLL-6** — The two-`###`-subsections-plus-a-fence proxy applies to
  procedural skills only. A reference-style skill has no steps to illustrate.
- **R-CONDUCT-4** — The agent-teams caveat drops its model versions; it names
  the experimental status and the structural limits only (G19).
- **R-LLMJ-5** — The judge model is a configured tier alias, not a pinned
  model id (G19).

## Review bot behaviour

Observed 2026-10-01 from issue threads; vendor documentation was not
reachable, so entries marked *unverified* rest on a single report. These feed
the bot-availability states (`ok`, `skipped`, `rate-limited`, `absent`) and
the manual trigger a bounded bot wait sends once.

| Bot | Manual trigger | Skip / limit evidence | Done signal |
|---|---|---|---|
| CodeRabbit (`coderabbitai[bot]`) | `@coderabbitai review` (incremental), `@coderabbitai full review`; when paused, `@coderabbitai resume` | Commit status stays SUCCESS even when skipped — read its description: `Review skipped: …`, `Review rate limited`. Summary comment is edited in place (read the current body); markers `Reviews paused`, `Review limit reached`, `Rate limit exceeded`. Auto-pauses after about five reviewed commits. Ignores trigger comments from bot authors. | Status description `Review completed` |
| Gemini Code Assist (`gemini-code-assist[bot]`) | `/gemini review` | Reviews only on PR open, not on push, so each new head needs a trigger. Quota notice `You have reached your daily quota limit` as a new comment. No status check. | A PR review in state COMMENTED |
| Claude Code Review (`claude[bot]`) | `@claude review` (not on drafts) | Check run `Claude Code Review`; a known failure completes neutral with no output after a two-hour timeout. | Check run conclusion with output |
| Copilot (`copilot-pull-request-reviewer[bot]`; GraphQL may omit `[bot]`) | Request it as a reviewer (REST `requested_reviewers`), not a comment | Pending while listed in `requested_reviewers`. | A review, always COMMENTED |
| Others (*unverified*) | `@sourcery-ai review`, `@greptileai review`, `bugbot run`, `/review` (qodo) | — | — |
