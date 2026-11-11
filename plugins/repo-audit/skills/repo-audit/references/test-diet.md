# Test diet — which tests should not be there, or not on every push

Load this in every audit's hunt pass: the report carries a `Test diet` section
whatever the scope (`references/output-shape.md` § Deliverables). The aim is a
faster CI with no real protection lost, and all code that can fail tested. It
is the other half of group 7 of the issue taxonomy: that group asks what is
untested, this asks what is tested at a cost it does not earn.

Measure first, read second. A suite that looks large is often proportionate,
and the time is usually somewhere a line count does not show.

## 1. Measure

1. **CI shape.** Read the workflows and the test config: what runs on every
   push or PR, in how many jobs and OS legs, serial or parallel, any path
   filter, any fast/slow split. Where the target repo vendors the arsenal
   bundle, `python3 claude-arsenal/scripts/ci_shape.py --repo-root <target>`
   prints the missing cancel-in-progress and job timeouts, a version or OS
   matrix and non-Linux runners on the PR path, commands run by two jobs, and
   missing path filters; otherwise check those by reading. Either way, read for
   what no script sees: release or installer builds on every PR push, a step
   run twice (a typecheck, then a build that typechecks), a deploy workflow
   repeating CI, a serial test runner.
2. **Counts and ratios.** Test count and lines per test file, source lines per
   module, and the ratio between them. Keep every command in the working notes.
3. **One timed run.** If dependencies install cheaply (try once; give up after
   one failure), run the suite once with per-test durations — the runner's
   duration report, a verbose or JSON reporter, `time` per shell test file.
   Record total wall time and the slowest tests and files. If it cannot be
   run, say so and label every saving as derived from structure, not measured.

4. **The other direction.** List source modules above a few hundred lines
   with no test file naming them. One with branching, parsing or data-loss
   logic is a finding (category `untested`), reported beside the cuts.

Then read only the suspicious files: the largest, the slowest, the highest
test-to-source ratio. Sample; do not read everything.

## 2. Classify

Each finding names one category.

| Category | What it is |
|---|---|
| `duplicate` | Several tests pin the same path or failure mode, or a test re-runs a measurement a gate job already runs. Keep one. |
| `parametrize` | N near-identical cases that should be one table or property test. |
| `trivial` | Pins a constant, a format, config, a getter, glue or a layer that only forwards; cannot realistically break, or breaking it is harmless. |
| `implementation` | Asserts internals or mocks so tightly it fails on any refactor and catches no behaviour bug. |
| `meta` | Tests about the repo's own docs, prose or process: grep-the-README, changelog wording, a number written in a doc. Belongs in a linter or nowhere. |
| `historic` | A regression test for code or a layout that no longer exists. |
| `slow-tier` | Valuable but slow: end-to-end, golden sweeps, subprocess-heavy, or an expensive fixture rebuilt per test. Keep it; share the fixture, or move it off the every-push path (main-only, nightly, path-filtered). |
| `ci-config` | Not a test problem: a version or OS matrix on every PR push, release builds or costly OS legs on the PR path, no cancel of superseded runs, no timeout, no path filter, a step or job run twice, a serial runner, no caching. |
| `untested` | A core module with branching, parsing or data-loss logic and no test file. The one category that adds tests. |

Look for the per-test fixture first. A module re-imported or a large capture
re-parsed before every test hides inside otherwise good tests, and comparing
the median test time of two files that exercise the same module exposes it.

## 3. Report

- **Every cut states the protection lost** — usually "none, covered by
  `<test>`" or "none, the `<job>` gate runs it". A cut that cannot say this is
  not ready to recommend.
- **Every saving states how it was derived**: summed durations from the timed
  run, or job counts from the workflow when nothing was run.
- **"Proportionate, keep" is a valid verdict.** Say it plainly, list the areas
  checked and judged worth their cost, and do not manufacture cuts.
- **Never recommend cutting** tests on money, data-loss or security paths, or
  on parsers with real branch logic, however slow. Those move tiers at most.
- Sort by size of the win. CI-shape findings usually come first: they save
  whole runs, where test cuts save seconds.
- Judge against the defaults a session is given when it writes tests and CI:
  `claude-arsenal/references/ci-minutes.md` § CI defaults, and the `execution`
  skill's `references/test-cost.md`. A repo that departs from one with a
  written reason has an override, not a finding.

Findings go in the ledger like any other, with the category as the tag.
