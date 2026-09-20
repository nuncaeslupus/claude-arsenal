---
name: repo-audit
description: Use when the user wants to analyze, document, or improve a repository from the outside — how it works, what's undocumented or inconsistent, whether to trust or adopt it. Triggers — "audit this repo", "what would break here", "explain this codebase end to end". Runs a multi-pass audit (research fan-out, an adversarial pass on failure modes, independent re-verification of every number) and produces a findings-backed write-up plus a ledger of verified fixes versus items flagged for a maintainer's call. Owns scripts — create_artifact.py, validate_findings.py, validate_markdown.py. Do NOT use for reviewing a diff, debugging one failure, or implementing a feature — use `code-review` or `specify`.
---

# repo-audit

Explains a repository the way its own author would have to, for someone who
wasn't in on every decision — then tries to break every claim it just made,
so the answers hold up under a real follow-up question. Works on any
repository; interview prep, onboarding, and due diligence are use cases of
the output, not the skill's identity.

CANARY: repo-audit-loaded-2026-09-20-fb78d23e-6a5b7d83932f7e55

## When to load

Load this when the ask is about the repo as a whole — "explain how this
works", "what would break here", "audit this and improve the docs", "should
we adopt/fork this" — not when it's about one diff, one bug, or one feature.
If the request is really "review this PR" or "fix this test", defer to
`code-review` or `execution`; this skill stands back from the whole
repository, not from a change to it.

## How to use

Four passes, in order. Each has its own check — don't start the next until
the current one's check is satisfied.

1. **Orient.** Read the README, the root memory file (`CLAUDE.md` /
   `AGENTS.md`), and the top-level directory listing directly — cheap, and it
   shows what's worth delegating. *Check: name the repo's purpose and its
   3–5 major subsystems before spawning anything.*
2. **Fan out.** One parallel research agent per major subsystem — see
   [Research categories](references/research-categories.md) for the
   checklist (coordination/sync, versioning and release, CI, observability,
   cost/efficiency, quality gates, applied examples). Ask each agent for
   concise, file:line-cited findings, not a transcript. *Check: every agent's
   report cites a real file path, not a paraphrase of another agent's
   report.*
3. **Break it.** A second pass, adversarial on purpose — see
   [Adversarial checklist](references/adversarial-checklist.md). Where the
   first pass explains the design, this one tries to falsify it: what fails
   on a different deployment surface, what happens with a dependency turned
   off, what's configurable versus hardcoded, what's structurally missing.
   *Check: at least one finding in this pass is a genuine inconsistency
   between what a doc claims and what the code does, or an explicit
   statement that none was found, backed by what was actually checked.*
4. **Verify, then synthesize.** Before a numeric or countable claim goes into
   the output, re-derive it directly (grep, `wc`, a one-off script) rather
   than repeating a sub-agent's count. Build the findings ledger as
   structured JSON and check it before writing prose:

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/validate_findings.py" --input findings.json
   ```

   If the target repo will receive new or edited Markdown, sanity-check it
   before proposing the diff:

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/validate_markdown.py" --input-dir <path-to-changed-docs> --repo-root <target-repo>
   ```

   Render the self-interview artifact's HTML from the same structured data —
   see [Output shape](references/output-shape.md) for the input schema —
   rather than hand-writing the page's CSS and markup from scratch:

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/create_artifact.py" --input write-up.json --output write-up.html
   ```

   *Check: every number in the final output has the command that re-derived
   it sitting next to it in the working notes; both validators exit 0 before
   the artifact is published or a doc fix is proposed.*

## Gotchas

- **The method is not the target repo's to keep.** The repo being audited
  gets verified documentation fixes and new reference material where
  something real is genuinely undocumented — never the audit methodology
  itself, a findings scratch file, or the adversarial question bank. Those
  belong in this skill, not in the repo under audit. Confirm with the user
  if a request is ambiguous about which repo receives what.
- **A sub-agent's count is a hypothesis, not a fact.** A parallel research
  agent's numeric claim — rule counts, test counts, line counts — has been
  wrong before in exactly the way a confident paraphrase goes wrong: right
  method, off by a header row. Re-run the count yourself before it lands in
  committed prose.
- **"No documentation exists for X" is itself a finding.** Skip it and the
  audit undersells the repo: a subsystem that's real, tested, and shipped
  reads as though it doesn't exist, because nothing describes it outside
  the code that implements it. Treat total silence about something real as
  seriously as a doc that's actively wrong.
- **Don't fix what needs a maintainer's judgment.** A stale number or a
  broken cross-link is safe to correct directly. A dead config key, a design
  trade-off, or a missing feature is a finding to report — file it as an
  issue or a ledger row, not a PR to open unasked. See
  [Output shape](references/output-shape.md).

## References — load on demand

- [Research categories](references/research-categories.md) — load before the
  fan-out pass, to scope what each agent investigates.
- [Adversarial checklist](references/adversarial-checklist.md) — load before
  the break-it pass.
- [Output shape](references/output-shape.md) — load before synthesizing the
  artifact and the findings ledger, or before running either validator
  script.
