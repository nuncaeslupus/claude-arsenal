---
name: pin-check
description: Use when the user wants to know whether a test really pins the behaviour it claims to — reverts that one line, runs only the scoped test, restores, and reports PINNED / NOT PINNED. Triggers — "does this test actually catch that", "is this claim pinned". Do NOT use for whole-suite mutation scoring (see mutmut-report) or line coverage (see coverage-gaps).
argument-hint: "--source FILE --replace OLD --with NEW --test TARGET"
user-invocable: true
metadata:
  section: python
---

# pin-check

One deliberate revert per claim, aimed at one case: *is this sentence pinned, or
merely true?*

CANARY: pin-check-loaded-2026-09-15-1c4de0b7-9a2f61d08e4b7c35

Three skills answer three different questions about the same suite, and
consumers keep collapsing them into one:

| | question | budget |
|---|---|---|
| `coverage-gaps` | was this line executed? | seconds |
| `mutmut-report` | of thousands of automatic mutants, which survived? | CPU-hours |
| **this one** | this claim says a case pins it — does it? | seconds |

## Step 1 — Name the claim, not the file

A run needs the exact text the claim is about and the **one** test that is
supposed to catch it changing. Both halves matter: a whole-suite run makes this
expensive enough that nobody does it, and that is how a repo ends up with 54
mutations each re-running 4,000 tests.

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/pin_check.py" \
    --source dimensions/schedule_flexibility.yaml \
    --replace "asynchronous" --with "async" \
    --test tests/<the-one-case>.py
```

`--expect-count N` refuses to run unless the target occurs exactly N times —
mutating three call sites at once is a different experiment from the one the
claim is about. `--root DIR` (repeatable) names the trees to purge bytecode
from when the package is not under the working directory. Extra arguments after
the flags are forwarded to `pytest`.

## Step 2 — Read the verdict, and the exit code

| verdict | exit | means |
|---|---|---|
| `PINNED` | 0 | the target changed and the scoped test went red. The claim holds. |
| `NOT PINNED` | 1 | the target changed and the test stayed green. The fixture asserts something true, not something pinned. |
| `NOT MUTATED` | 3 | the target is not in the file, or occurs a different number of times than `--expect-count`. **Nothing was tested** — this is not a green. |
| `INCONCLUSIVE` | 4 | the test was already failing before the mutation, or the file could not be restored. |
| error | 2 | bad arguments, or a sentinel from a killed run is still on disk. |

`NOT MUTATED` and `INCONCLUSIVE` exist because both were reported as results by
sessions doing this by hand: a `sed` that matched nothing reads exactly like
"not pinned", and a scoped test that was already red goes red under any
mutation at all.

## Step 3 — Act on it

- `NOT PINNED` → the case needs an assertion about the value that changed, or a
  case that exercises the path. Write it, then re-run this script: `PINNED` is
  the receipt.
- `PINNED` → say so in the review, citing the mutation that produced it. A claim that has
  been pin-checked is a claim someone else does not have to re-derive.
- Report the mutation itself — source, target, replacement, test — not just the
  verdict. The verdict is only as good as the mutation that produced it.

## What this script does that a hand cycle does not

Do not do this by hand once the script exists. Three of its four failure modes
are invisible to a person and each produces a confident wrong answer:

- **Stale bytecode.** CPython validates a `.pyc` against the source's mtime at
  one-second resolution plus its size, so an equal-length mutation reverted
  inside the same second leaves both unchanged and the *mutated* bytecode runs.
  The script purges `__pycache__` before every run and runs with bytecode
  writing off.
- **The resident module.** Clearing `__pycache__` does not help a module that is
  already imported — an in-process driver scores the code as it was when the
  process started, which manufactures findings against correct code. Every run
  here is a fresh subprocess.
- **The unasserted target.** Occurrences are counted and refused at zero, and
  the file is re-read after the write, before any test runs.
- **The abandoned mutation.** The restore is in a `finally`, the restored bytes
  are compared against what was read, and the original is held in a sentinel
  file beside the source for the whole window — so a killed run is recoverable
  instead of leaving a mutated tree the next session reads as the code. A later
  run that finds a sentinel refuses to start and prints how to restore.

## Scope

One claim, one mutation, one scoped test. For a survivor score over a whole
module use `mutmut-report`; for which lines never ran at all use
`coverage-gaps`. Mutating a file this script cannot restore — anything not under
version control, or a generated file — is out of scope: check it in first.
