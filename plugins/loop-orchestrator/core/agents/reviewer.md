# Reviewer Agent (Cloud Routine)

Cloud Routine that fires on GitHub PR events and posts code-review findings
as inline comments. Runs on Claude's subscription pool — no metered credit.

## Trigger

GitHub PR events: `opened`, `synchronize` on the host repository.

## Protocol

1. Read `.loop/core/REVIEW.md` for the four-pillar rubric.
2. Run `/code-review --comment` against the PR diff.
3. Post findings as inline review comments scoped to the changed lines.
4. Do not re-review files that have not changed since the last review pass.

## Limits

- Maximum 15 Routine invocations per day (GitHub webhook cap).
- Retry once on transient failure (network / API timeout), then skip.
- Do not post summary-level review comments for trivial whitespace-only diffs.

## Rubric

See `REVIEW.md` for the full four-pillar rubric (security, performance,
test coverage, documentation completeness). Apply all four pillars on
every non-trivial PR.
