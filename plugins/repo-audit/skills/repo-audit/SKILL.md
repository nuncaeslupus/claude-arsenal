---
name: repo-audit
description: Finds real problems in a repository (bugs, security issues, missing edge cases and tests), rated by severity and confidence, and queues the worthwhile ones. Use when the user wants a repo audited. Not for a write-up (explain-repo) or diff review (code-review).
---

# repo-audit

Reads a repository the way an experienced engineer doing a real audit would:
understand it, hunt for what is actually wrong, report every finding with how
serious and how certain it is, then queue the ones worth acting on as gated
work. Works on any repository or a named subset; `explain-repo` turns the
results into a human-facing document.

CANARY: repo-audit-loaded-2026-09-20-fb78d23e-6a5b7d83932f7e55

## When to load

Load this when the ask is about the repo (or a real subset) as a whole —
"audit this for bugs", "what would break here". For one diff, one bug, or one
feature, use `code-review` or `execution`.

## How to use

1. **Orient.** Read the README, the root memory file (`CLAUDE.md` /
   `AGENTS.md`) and the top-level layout. Then size the work, because
   fan-out costs more than it saves on a small repo. As a starting value:
   under about 150 source files or 20k lines, do the whole audit inline;
   above that, one worker per major subsystem (and per taxonomy group where a
   subsystem is itself large). Workers run on the session's model, or on
   `models.workers` from `arsenal/config.toml` when that file sets it; the
   summary says which.
2. **Understand.** Read each subsystem against
   [Research categories](references/research-categories.md), citing real file
   paths.
3. **Hunt.** Work through [Issue taxonomy](references/issue-taxonomy.md),
   scoped to the subset asked for, skipping what the repo's own linter already
   catches. A bug finding needs a real check: a repro, a failing test, or a
   code path traced end to end, plus a file:line and a one-sentence failure
   scenario ("input X causes Y"). Architecture observations need evidence but
   not a repro. A hunch with no trigger is not a finding.
4. **Report.** Give every finding a severity (high / medium / low) and a
   confidence (high / medium / low), and report all of them, including
   uncertain ones, labelled as such. Build the ledger as JSON and validate it
   (shape in [Output shape](references/output-shape.md)):

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/validate_findings.py" --input findings.json
   ```

   Re-derive every number in the report with a command, and keep the command
   in the working notes.
5. **Queue.** As a separate last step, choose which findings become work,
   usually the ones with medium-or-higher severity and confidence; the
   fix / queue / issue / ledger decision is in
   [Output shape](references/output-shape.md). Queue a task only when the
   target repo has `arsenal/tasks/`:

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/create_task.py" --title "<finding, as a job>" --tag <category> --body "<failure scenario + suggested direction>" --tasks-dir <target-repo>/arsenal/tasks
   ```

   Run `validate_markdown.py --input-dir <changed-docs> --repo-root <target-repo>`
   on any Markdown the target repo will receive, and expect exit 0 before
   proposing it.

## Gotchas

- **Where a finding lands, and what stays out of the target repo,** are
  decided in [Output shape](references/output-shape.md); read it before step 5.
- **A worker's count or suspected bug is a hypothesis.** Check it with the
  step 3 standard before it goes in the report as fact.
- **"No documentation exists for X" is a finding.** A real, shipped subsystem
  that nothing describes reads as though it does not exist.
- **Queue rather than fix when a maintainer's judgment is needed.** A stale
  number or broken link is safe to correct directly; anything else becomes a
  task, an issue or a ledger row, and no pull request is opened unasked,
  because the maintainer owns what merges.

## References — load on demand

- [Research categories](references/research-categories.md) — before
  understanding, to scope each subsystem read.
- [Issue taxonomy](references/issue-taxonomy.md) — before hunting; includes
  optional architecture prompts.
- [Output shape](references/output-shape.md) — before reporting and queueing:
  the ledger shape, the destination, and the fix / queue / issue / ledger
  decision.
