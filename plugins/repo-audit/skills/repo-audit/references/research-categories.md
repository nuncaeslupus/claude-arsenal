# Research categories

Load before the fan-out pass, to scope what each parallel research agent
investigates. One agent per category below that's actually present in the
target repo — skip a category that doesn't apply rather than forcing a
finding.

## The checklist

1. **Coordination and sync.** How does concurrent work avoid stepping on
   itself? Look for task/issue trackers, claim or lock mechanisms, CI
   concurrency groups, feature flags, branch-protection config. If nothing
   coordinates concurrent work, that's a finding too — most repos are fine
   without it; say so rather than implying a gap.
2. **Versioning and release.** Where does a version number live — one file,
   or several that can drift? What actually enforces a bump? What publishes
   or tags a release, and what happens if that pipeline is unavailable when
   a change merges? Grep for past incidents in a changelog before assuming
   the answer is theoretical.
3. **CI and testing.** What runs on every push or PR, and what's required
   versus advisory? Get the real test count from the test runner's own
   output or the CI config, never from a README's claim about itself —
   READMEs drift.
4. **Observability.** How would someone know the system is healthy without
   reading every change by hand? Status scripts, dashboards, audit
   commands, health checks. If the answer is "read the PRs," that's the
   finding.
5. **Cost and efficiency.** Is efficiency a claim or a measurement? Look for
   anything that reports tokens, time, or spend, or scripts whose entire
   job is avoiding repeated expensive work (a cache, a memoized computation,
   a "read the summary, not the whole file" convention).
6. **Quality gates on the artifact itself.** Is there a mechanism enforcing
   the project's own standards on new contributions — linters, custom
   validators, pre-commit hooks, required reviews, a rubric? A repo that
   preaches discipline but doesn't enforce it on itself is a real finding.
7. **Applied examples.** Is there a real, worked instance of the project's
   own process being used on itself — dogfooding? That's usually the most
   convincing evidence a design actually works, and it's often missed
   because it doesn't live in the README.

## What "concise, cited" means for an agent's report

Ask each research agent to return findings as: a claim, the file:line that
backs it, and — for anything numeric — the exact command that would
re-derive it. A report that reads as a confident paragraph with no citation
is unusable; ask for a redo scoped tighter rather than accepting it.
