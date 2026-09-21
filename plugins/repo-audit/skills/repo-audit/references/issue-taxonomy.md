# Issue taxonomy

## Contents

- [How to use this list](#how-to-use-this-list)
- [A. Correctness and logic](#a-correctness-and-logic)
- [B. Concurrency and resource safety](#b-concurrency-and-resource-safety)
- [C. Security](#c-security)
- [D. Error handling and edge cases](#d-error-handling-and-edge-cases)
- [E. API design and forgotten use cases](#e-api-design-and-forgotten-use-cases)
- [F. Dead code, duplication, and performance](#f-dead-code-duplication-and-performance)
- [G. Tests and verification gaps](#g-tests-and-verification-gaps)
- [H. Conventions and documentation](#h-conventions-and-documentation)
- [What this list is not](#what-this-list-is-not)

Load before the hunt pass, to scope one research agent per group below. Eight
groups is a default, not a rule — combine light groups on a small repo, or
split a heavy one (e.g. security on a repo handling payment data) into two.

## How to use this list

Each group below is a dispatch unit: one research agent reads it, then walks
the target scope (the whole repo, or whatever subset was asked for) looking
for concrete instances, not abstract risk. Every candidate finding needs a
file:line and a one-sentence failure scenario — "input X causes Y" — before
it is worth reporting. A finding with no concrete trigger is a hunch, and
hunches go through the verify pass before they're trusted (see the skill
body's Verify step), not straight into the ledger.

## A. Correctness and logic

- Off-by-one errors in loops, slices, and range bounds.
- Inverted or short-circuited boolean conditions (`and`/`or` swapped, a
  negation that doesn't cover what the comment says it covers).
- `is` used where `==` was meant (or vice versa) — identity vs. equality bugs.
- Mutable default arguments that persist across calls.
- Bare `except:` or overly broad exception classes that swallow real errors
  alongside the one they were written for.
- Floating-point equality comparisons where a tolerance was needed.
- Type confusion: a value assumed to be one type (str/int/None) that a caller
  can actually pass as another.

## B. Concurrency and resource safety

- Shared mutable state read and written from more than one thread, async
  task, or process with no synchronization.
- Check-then-act sequences that aren't atomic (a existence/permission check
  followed by a separate operation that assumes the check still holds).
- Deadlock potential — two or more locks that can be acquired in different
  orders by different call paths.
- Unclosed files, sockets, connections, or subprocess handles — anything
  acquired without a context manager or a matching `close()` on every exit
  path, including exceptions.
- Unbounded caches, queues, or in-memory accumulators with no eviction.

## C. Security

Grounded in the OWASP Top 10 categories, adapted to what actually shows up in
a codebase read rather than a running scan:

- Injection: string-built SQL, shell commands, or file paths from
  unsanitized input.
- Hardcoded credentials, API keys, or tokens — including in test fixtures
  and comments, which leak the same way.
- Unsafe deserialization (`pickle`, `eval`, `exec`, `yaml.load` without
  `SafeLoader`) on data that could be attacker-controlled.
- Path traversal — a file path built from user input with no containment
  check.
- Missing or bypassable authorization checks on an operation that clearly
  needs one.
- Insecure randomness (`random`, not a CSPRNG) used for anything
  security-sensitive — tokens, session ids, password-reset codes.
- A dependency pin known to carry a disclosed CVE at a version this repo is
  actually on — check what's pinned, not what's theoretically available.

## D. Error handling and edge cases

- A function whose signature or docstring implies it handles empty input,
  `None`, zero, negative numbers, or unicode, but doesn't.
- Silent failures — a caught exception that's logged (or not even that) and
  then execution continues as if nothing happened, where the caller had no
  way to know.
- External calls (network, subprocess, filesystem) with no timeout, so a
  hung dependency hangs the caller forever.
- Error messages that include something sensitive (a stack trace, a
  credential, an internal path) in a context a user or log aggregator external
  to the team can see.

## E. API design and forgotten use cases

- A function whose real preconditions aren't validated, so a caller outside
  the ones the author had in mind gets a confusing failure deep inside
  instead of a clear one at the boundary.
- A change that's backward-incompatible for an existing caller but isn't
  flagged as one anywhere (changelog, version bump, deprecation notice).
  Cross-reference: `docs/CONTRIBUTING.md`-style versioning rules if the repo
  has them.
- A function that does substantially more than its name says, so a caller
  reading the signature can't predict its side effects.
- An assumption baked into the implementation (single-threaded, single
  tenant, one locale, one timezone) that the surrounding code doesn't
  actually guarantee.

## F. Dead code, duplication, and performance

- Unreachable code (a branch that can't execute given its guard), unused
  imports, variables, and functions with zero callers.
- Copy-pasted logic in more than one place that should be a shared helper —
  especially when the copies have already started to drift.
- N+1 query or request patterns (a loop issuing one call per item where a
  single batched call would do).
- A quadratic-or-worse algorithm over input that can realistically grow
  large, where a linear approach is available.
- Loading an entire dataset into memory where streaming or pagination was
  available and the dataset isn't bounded.

## G. Tests and verification gaps

- An error path, edge case, or documented precondition with no test
  exercising it.
- A test that doesn't actually pin the behavior its name claims — this
  taxonomy names the gap; use the `pin-check` skill to confirm one
  specific suspect (revert the line, confirm the test fails for that
  reason).
- A test that depends on execution order, wall-clock time, or network
  access without being marked as such — a latent flake, not a bug in
  product code, but worth the same finding shape.

## H. Conventions and documentation

- A deviation from a convention the repo documents itself (its `CLAUDE.md` /
  `AGENTS.md`, a style guide, a linter config it doesn't actually enforce).
- Inconsistent error-handling or logging style across modules doing
  materially the same kind of work.
- Documentation gaps and architecture/mechanism questions — this overlaps
  with the understand pass; the skill body's research-categories reference
  covers that half specifically.

## What this list is not

Not a linter's rule set — a linter already runs in CI if this repo has one,
and re-finding what `ruff`/`eslint`/`clippy` already catches wastes a
worker's pass. Skip anything a fast, already-configured tool would have
caught; spend the research budget on what needs reading and judgment.
