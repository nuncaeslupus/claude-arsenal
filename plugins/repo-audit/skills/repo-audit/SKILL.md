---
name: repo-audit
description: Use when the user wants to find real problems in a repository — bugs, security issues, missing edge cases or tests — across the repo or a subset. Triggers — "audit this repo for bugs", "find everything wrong with this". Hunts a checklist, verifies each candidate, queues confirmed findings as arsenal tasks or issues. For a human write-up, use `explain-repo`. Do NOT use for reviewing a diff or implementing a feature — use `code-review` or `specify`.
---

# repo-audit

Reads a repository the way an experienced engineer doing a real audit would —
understand it, then hunt across a real checklist for what's actually wrong,
verify every candidate before trusting it, then turn each confirmed finding
into properly-gated work instead of a list nobody acts on. Works on any
repository, or a named subset of one; `explain-repo` handles turning the
results into a human-facing document.

CANARY: repo-audit-loaded-2026-09-20-fb78d23e-6a5b7d83932f7e55

## When to load

Load this when the ask is about the repo (or a real subset of it) as a
whole — "audit this for bugs", "what would break here", "find everything
wrong with this codebase" — not when it's about one diff, one bug, or one
feature already in hand. If the request is really "review this PR" or "fix
this test", defer to `code-review` or `execution`; this skill stands back
from the whole repository, not from a change already made to it.

## How to use

Five passes, in order. Each has its own check — don't start the next until
the current one's check is satisfied.

1. **Orient.** Read the README, the root memory file (`CLAUDE.md` /
   `AGENTS.md`), and the top-level directory listing directly — cheap, and it
   shows what's worth delegating. Ask the user (`AskUserQuestion`) which
   model — Sonnet, Opus, Haiku, or Fable — the worker agents spawned below
   should run on: a wide fan-out is a cost/thoroughness tradeoff that's the
   user's call, not a default to assume. Skip the question and use Sonnet
   when there's no one to ask (an unattended run). Pass the answer as every
   worker's `model` from here on. *Check: name the repo's purpose and its
   3–5 major subsystems, and have the worker model set, before spawning
   anything.*
2. **Understand.** One parallel research agent per major subsystem — see
   [Research categories](references/research-categories.md). *Check: every
   agent's report cites a real file path, not a paraphrase of another
   agent's report.*
3. **Hunt.** One parallel research agent per checklist group in
   [Issue taxonomy](references/issue-taxonomy.md) — correctness, concurrency,
   security, error handling, API design, dead code/performance, tests,
   conventions. Scope to whatever subset was asked for; skip what a linter
   already configured in this repo would have caught. *Check: every
   candidate finding names a file:line and a one-sentence failure scenario —
   "input X causes Y" — not a general risk statement.*
4. **Verify.** Every candidate from passes 2 and 3 — an architecture claim
   as much as a suspected bug — gets checked independently before it's
   trusted: reproduce it, read the actual code path, or run the check that
   would confirm it. See
   [Adversarial checklist](references/adversarial-checklist.md) for the
   architecture side. *Check: each finding is marked CONFIRMED (reproduced
   or directly verified) or DROPPED (didn't hold up) — nothing ships as
   "probably".*
5. **Act.** For each CONFIRMED finding, decide fix / queue / issue / ledger
   — see [Output shape](references/output-shape.md) for the decision and
   for how the write-up's own destination (repo vs. user-only) is decided.
   Build the findings ledger as structured JSON and validate it before
   writing anything:

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/validate_findings.py" --input findings.json
   ```

   If the target repo will receive new or edited Markdown, sanity-check it
   before proposing the diff:

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/validate_markdown.py" --input-dir <path-to-changed-docs> --repo-root <target-repo>
   ```

   To queue a finding as an arsenal task (only when the target repo has
   `arsenal/tasks/`):

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/create_task.py" --title "<finding, as a job>" --tag <category> --body "<failure scenario + suggested direction>" --tasks-dir <target-repo>/arsenal/tasks
   ```

   *Check: every number in the final output has the command that re-derived
   it sitting next to it in the working notes; both validators exit 0 before
   anything is published or proposed.*

## Gotchas

- **The method is not the target repo's to keep.** The repo being audited
  gets verified documentation fixes and new reference material where
  something real is genuinely undocumented — never the audit methodology
  itself, a findings scratch file, or the checklist references. Confirm
  with the user if a request is ambiguous about which repo receives what.
- **"Fix arsenal-style" means queue it, not commit it unasked.** A
  confirmed finding that needs real implementation work becomes a task —
  title, category tag, failure scenario, and a concrete acceptance gate —
  ready for a human or a future worker session to claim and execute. It is
  not an army of agents editing the repo unsupervised; that trades one risk
  (a bug ships) for a worse one (an unreviewed fleet of edits ships).
- **A sub-agent's count — or a sub-agent's bug — is a hypothesis, not a
  fact.** Both a numeric claim and a suspected bug have been wrong before in
  the same way a confident paraphrase goes wrong. The verify pass exists
  because of this, not as a formality; don't skip it under time pressure.
- **The orchestrator's model isn't this skill's to set.** These steps run as
  whatever model the current session already is — no tool call changes that
  mid-run. Getting a specific model to orchestrate (deciding what to hunt
  for, writing each worker's prompt, reading its report back) means
  starting or switching the session to it *before* invoking repo-audit; only
  the fan-out workers' model is a setting this skill can apply, via the
  question in the Orient pass.
- **"No documentation exists for X" is itself a finding.** Skip it and the
  audit undersells the repo: a subsystem that's real, tested, and shipped
  reads as though it doesn't exist, because nothing describes it outside
  the code that implements it.
- **Don't fix what needs a maintainer's judgment.** A stale number or a
  broken cross-link is safe to correct directly. A dead config key, a design
  trade-off, or a missing feature is a finding to queue or report — never a
  PR opened unasked. See [Output shape](references/output-shape.md).

## References — load on demand

- [Research categories](references/research-categories.md) — load before
  the understand pass, to scope what each agent investigates.
- [Issue taxonomy](references/issue-taxonomy.md) — load before the hunt
  pass, to scope one worker per checklist group.
- [Adversarial checklist](references/adversarial-checklist.md) — load
  before the verify pass, for the architecture-claim side of it.
- [Output shape](references/output-shape.md) — load before the act pass —
  the fix/queue/issue/ledger decision, the write-up's destination, and the
  validator/task-creation scripts' exact contracts.
