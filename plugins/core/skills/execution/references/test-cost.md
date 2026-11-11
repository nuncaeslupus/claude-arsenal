# Test cost — what a test is owed for, and what it may cost

Load this when a task adds more than a handful of tests, when a new test takes
about a second or more, when a test needs a large fixture or a re-imported
module, or when reviewing the tests a diff adds.

Where this comes from: a measured review of seven repositories built with this
workflow, prompted by slow CI. None of them was slow because it had too many
tests. The time was in four places, and each is cheap to avoid when the test is
written and expensive to find afterwards.

## What a test is owed for

One test per **failure mode** of logic that can actually fail: a branch, a
boundary, a parser, an error path, anything that can lose or corrupt data or
money. Not one per function, and not one per line of the diff.

Before writing a test, name the bug it would catch. If the only way it fails is
someone deliberately changing what it pins, it is a change detector.

## Do not write

| Kind | What it looks like | Instead |
|---|---|---|
| Prose test | Greps a README, a skill, a doc or a changelog for wording; polices a number written in a doc | Nothing, or a linter step outside the suite. Derive the number from the source rather than testing the copy. |
| Gate re-measurement | Re-runs an acceptance gate or evidence measurement (a whole-corpus run, a benchmark, a regenerate-and-diff) that a gate command or CI job already runs | Test the measuring function on a three-row input; leave the full measurement to the gate. |
| Constant or glue | Pins a constant, a format string, a config value, a getter, a layer that only forwards, "is defined" | Nothing. The caller's test covers it. |
| Duplicate | A second test for a path another test already pins | One test; a table when the cases differ only in data. |
| Implementation pin | Asserts on internals or mocks so tightly that any refactor fails it and no behaviour bug does | Assert on what a caller can observe. |

## Build expensive fixtures once

The single largest cost found: 73% of one suite's time was a module re-imported,
or a large capture re-parsed, before **every** test. A sibling file that loaded
the same module once ran the same kind of test twenty times faster.

- Parse, import, build or start it once per module or file (`scope="module"`,
  `beforeAll`, a `setUpClass`, one `mktemp` tree per shell file) and share it
  across tests that only read it.
- Keep a per-test rebuild only for tests that mutate the fixture, and group
  those together so the rest do not pay for them.
- Prefer a small hand-written input over a real capture. Keep one test on the
  real capture, not every test.

## The one-second rule

A test slower than about a second needs a reason written beside it, or it goes
in a slow tier (a marker, a tag, a separate directory or target) that does not
run on every push: main-only, nightly, or when the paths it covers change. In
one suite 0.8% of the tests were half the run. Find them with the runner's own
report (`pytest --durations=20`, a verbose or JSON reporter, `time` per shell
test file) before pushing, not after CI feels slow.

Sleeping to wait for something is a slow test with no reason: inject the clock
or the timeout.

## Then check the CI shape

Most of the cost in that review was not tests at all but workflows that ran
everything on every push. With the bundle vendored, this prints what is missing
(cancel-in-progress, job timeouts, costly runners on pull requests, path
filters):

```bash
python3 claude-arsenal/scripts/ci_shape.py
```

`claude-arsenal/references/ci-minutes.md` has the trigger block that fixes it.

## What this is not

Not a reason to skip tests on logic that branches, parses or can lose data, and
not a licence to delete an existing test without saying what protection goes
with it. A suite can be large and proportionate; the question is always what
each test would catch and what it costs per push.
