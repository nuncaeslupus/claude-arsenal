# Issue taxonomy

Load before hunting. Nine groups is a default, not a rule: on a small repo one
reader covers them all inline; on a large one, give each worker the groups
that fit its subsystem, or split a heavy one (security on a repo handling
payment data).

Each group is a dispatch unit and a question, not a checklist. A worker reads
its group, then reads the code on its own terms. Every candidate needs a
`file:line` and a one-sentence failure scenario — "input X causes Y" — before
it is worth reporting; a finding with no concrete trigger is a hunch, and
a hunch is checked (repro, failing test, traced path) before it is reported
as a bug.

## The groups

1. **Correctness and logic.** Where does the code do something other than what
   its name, signature or comment says? Read the boundaries: loop bounds,
   branch conditions, what a caller can actually pass.
2. **Concurrency and resource safety.** What does this repo assume it is alone
   in doing? Look for state two paths can touch at once, check-then-act
   sequences that are not atomic, and anything acquired that some exit path
   never releases.
3. **Security.** Follow attacker-controlled data to where it becomes a
   command, a path, a query or an object. Then check what is pinned: a CVE
   matters at the version this repo is actually on, not the one available.
   Credentials in test fixtures and comments leak exactly like credentials in
   source.
4. **Error handling and edge cases.** When this fails, who finds out? Look for
   failures that are swallowed, external calls with no timeout, and error text
   carrying something the reader of a log should not see.
5. **API design and forgotten use cases.** Which caller did the author not
   have in mind? A precondition nobody validates, a change nothing flags as
   breaking, and an assumption — single-threaded, one tenant, one timezone —
   that the surrounding code does not guarantee.
6. **Dead code, duplication, and performance.** What is here that nothing
   reaches, and what is here twice? Drifted copies matter more than identical
   ones. For cost, ask what grows: per-item work inside a loop over input that
   can realistically get large.
7. **Tests and verification gaps.** Which claim is untested, and which test
   does not pin what its name says? This group names the gap; use the
   `pin-check` skill to confirm one specific suspect.
8. **Conventions and documentation.** Where does the repo disagree with
   itself? Its own `CLAUDE.md`, a linter config nothing enforces, a documented
   count that has drifted. Architecture and mechanism questions belong to the
   understand pass instead — the research-categories reference covers that.
9. **Simplicity and instruction economy.** What costs more to read than it
   earns? Instructions are paid by every session that loads them, so a
   procedure stated three times, a checklist whose items restate the step
   above, and an enumerated list where one open question would do all make the
   agent do the job worse, not better. The same question applies to code: a
   guard that cannot fire, a layer that only forwards. This group found real
   defects the other eight missed, including in this file.

## What this list is not

Not a linter's rule set. A linter already runs in CI if this repo has one, and
re-finding what `ruff`/`eslint`/`clippy` catches wastes a worker's pass. It is
also not a list of patterns to grep for: naming the patterns hands a worker
something to match instead of code to read, and the defects that matter here
are the ones no pattern names.

## Optional prompts for architecture claims

Use these when a doc or design asserts something about behaviour. Each is a
question to trace in code; an observation needs evidence, not a repro.

- **Other surfaces.** Does it behave the same locally, on a hosted runner, in
  CI, in a fork? Name the capability missing on each.
- **Automation off.** If CI or automation is down or never set up, what
  silently stops, and who would notice?
- **Declared but dead.** Is any config key accepted but never read? Grep where
  it is read, not only where it is declared.
- **Lock-in.** Which vendor, host, OS or language is it tied to, and is that
  stated?
- **Update footguns.** Can an update lose local work, or report success while
  doing nothing?
- **Missing pieces.** What would a comparable mature project have that this
  lacks (ownership, security policy, release notes)? Say settings you cannot
  see from the filesystem are unverifiable.
- **Write paths.** Do calls that mutate external state handle timeouts,
  retries and partial failure?
- **"Automatic" claims.** Trace the code path behind each; if it lives in an
  optional component, the claim is overstated for anyone without it.
