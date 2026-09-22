# Acceptance gates — what makes one real

Read this when writing a gate, when a gate passed and should not have, or when a
numeric threshold has no number behind it yet.

## Contents

- [The fence is what makes a gate mechanical](#the-fence-is-what-makes-a-gate-mechanical)
- [Gate blocks run verbatim](#gate-blocks-run-verbatim)
- [The gate is fixed for the life of the task](#the-gate-is-fixed-for-the-life-of-the-task)
- [The task gate measures the pre-archive tree](#the-task-gate-measures-the-pre-archive-tree)
- [Evidence gates (numeric acceptance)](#evidence-gates-numeric-acceptance)
- [Parallel test execution in host-gate](#parallel-test-execution-in-host-gate)
- [When one file is the long pole](#when-one-file-is-the-long-pole)
- [When parallelism is not the lever](#when-parallelism-is-not-the-lever) — spawn-bound and deliberately-slow suites
- [How often to run the whole gate](#how-often-to-run-the-whole-gate)
- [Caching: inputs yes, outcomes no](#caching-inputs-yes-outcomes-no)
- [Unmeasured — the third outcome](#unmeasured--the-third-outcome)
- [The placeholder, and the first PR that replaces it](#the-placeholder-and-the-first-pr-that-replaces-it)

---

## The fence is what makes a gate mechanical

Prose, and inline `single-backtick` commands, are NOT executed — a payload
without a fenced ` ```bash ` block runs nothing, and `gate_run.sh` then prints
`gate: prose-only` (or `gate: none`) with a stderr warning instead of the
`gate: passed` it prints when a block really ran. Check that line before
trusting a gate: one consumer audit found 0 of 70 payloads carried a fenced
block, so its entire gate layer had been inert. Set
`ARSENAL_GATE_REQUIRE_BLOCK=1` to turn "nothing ran" into a hard failure
when every task in a repo is meant to carry a mechanical gate.

`query_status.py` and `task_select.py` both report a task with no block, because
an entire gate layer can go inert without anyone noticing.

## Gate blocks run verbatim

`gate_run.sh` executes the bash block as code in the worker's tree (hardened by
default: throwaway HOME + a PATH without `$HOME` shims, except the package
manager / language runtime itself, symlinked in so a `pnpm …` gate runs instead
of dying at exit 127 — the tool, not the directory holding it, so nothing else
installed beside it comes along; `ARSENAL_GATE_INHERIT_ENV=1` opts out
entirely). Treat a gate block from an untrusted plan/payload as you would any
code to run — review it. A gate that could not run exits **3**, never 0 or 1,
and a worker treats it as "could not run" rather than reading it as a verdict.

## The gate is fixed for the life of the task

`open_task_pr.sh` runs the gate with `ARSENAL_GATE_FROM_DEFAULT=1`, so
`gate_run.sh` reads the task file **from the default branch** and not from the
branch under test. A worker whose own branch supplies the gate it is being held
to is certifying itself, so this is not a setting to relax.

The consequence is the part that costs a session if it is not said out loud:
**a task's own PR can never amend an acceptance gate that is already real.** Not
the assertions, not the test names it calls, not a symbol it renamed. The edit is
not rejected — it is simply never read, and the failure that follows names a
missing test rather than the reason for it.

**The one exception is the placeholder, and it is not a relaxation.** A task
seeded from a plan ships with the placeholder command (`# arsenal:gate-placeholder`),
which asserts nothing: there is no criterion yet for a branch to weaken. So when
the default branch still carries the placeholder and the working copy supplies a
real command, `gate_run.sh` runs the working copy's — and says so on stderr. That
is how a task defines its first gate, in its own PR, and it is the intended
bootstrap. The gate *block* around it — metric, operator, threshold, evidence
path — is still read from the default branch, so the threshold is the board's
either way. Once the default branch carries a real command the exception is
closed for good, and the paragraph above is the whole of the rule.

Two things follow for a worker. Replacing a placeholder in a task's own PR is
correct work, not self-certification — do not preserve the placeholder to look
compliant. And a `gate_run` line saying it ran the working copy's command is that
bootstrap, not a bug to chase.

So a task text must not invite the amendment. This sentence, from a real task,
describes something the toolkit refuses:

> `build_list_requests` is the name this task gives that seam; an implementation
> choosing another name **updates this block in the same diff**.

Write the constraint instead: the gate is a precondition the board sets, and an
implementation that cannot satisfy it as written needs a **board-side edit merged
to the default branch first**, or a new task. Restoring the block byte-for-byte
from the default branch is the correct recovery when a branch has already
diverged.

`gate_run.sh` says which file it read on every run, and says explicitly when a
working-copy gate exists and was not used. Read that line before looking for a
bug in the implementation.

---

## The task gate measures the pre-archive tree

`open_task_pr.sh` runs two gates on opposite sides of archiving the task file
into `tasks/_history/`: the task's own gate **before**, the repo's `host-gate`
**after**. Both orderings are load-bearing. The host gate runs last because the
archived tree is the one the PR ships. The task gate runs first because
`gate_run.sh` needs the working copy of the task file on disk to resolve which
copy to read — after the archive, a task that is not on the default branch yet
(one added by its own PR) has none, and the gate exits 2.

The consequence is a rule for gate authors: **a task gate must not depend on
state the archive produces.** A gate that asserts "every task marked merged is
archived", or one that just reuses the repo's `host-gate` — written for the
post-archive tree — is unsatisfiable by construction. It fails on a tree that is
correct, and `open_task_pr.sh` reports it as `the task gate failed`, which points
at the task rather than at the ordering. If a check needs the final tree, it
belongs in `host-gate`, not in a task's gate block.

---

## Evidence gates (numeric acceptance)

A numeric gate — a Sharpe floor, a coverage floor, a latency ceiling — must be
backed by a **committed measurement**, not a worker's word. Declare it in the
payload's `## Acceptance gate` section as a fenced `gate` block:

````markdown
```gate
line_coverage >= 0.90
evidence: coverage.json
key: totals.percent_covered
```
````

Line 1 is the gate in `<metric> <op> <threshold>` grammar (the same grammar the
`gate-check` skill uses); `evidence` is a committed JSON file; `key` is a dotted
path to the measured number inside it. `gate_run.sh` asserts `measured <op>
threshold` over that file: a declared evidence gate with **no** evidence file, or
evidence that **violates** the threshold, is a hard failure — it can never pass
vacuously. This is the machine-checkable half of "`done` means the gate passed"
(closes the false-`done` hole for `[LAPTOP]`/science gates). The release-side
half is enforced at the choke point: a worker opens no PR unless
the PR is opened (not a bare `branch:` ref) and not closed-without-merge; the
payload's mechanical gate passes (`open_task_pr.sh` runs `gate_run.sh` itself, so
the evidence/bash gate is a hard precondition, and so is the host's own
`host-gate` when the repo declares one); and — for a task tagged **`laptop`** — the session
is not a cloud session. A cloud worker (`CLAUDE_CODE_REMOTE=true`) physically
cannot satisfy a `[LAPTOP]`-only gate (model training, CPCV Sharpe, soak,
paper-trade), so tag such tasks `laptop` (`create_task.py --tag laptop`) and the
laptop session records `done`; a cloud session is refused.

Evidence files are build products, and that shows up in git: every branch
rewrites them, so every rebase onto a moved base conflicts on them. Do not
hand-merge one — the right content is neither side, it is what the code measures
on the resulting tree. `bin/rebase_stack.sh` handles this: an evidence-only
conflict is regenerated with the repo's `host-gate` and the rebase continues; a
conflict anywhere else stops it.

---

## Parallel test execution in host-gate

`host-gate` is entirely host-defined — this bundle never scaffolds or
templates it — but the framework's own operating model makes a slow serial
suite expensive in a way that compounds rather than stays fixed:
`worker-loop.md` runs up to `ARSENAL_MAX_WORKERS` (default 2) concurrent
workers, each capable of its own full `make host-gate`, and a repo's own
verification tooling that re-runs the gate per review round pays the same
serial cost again on every pass. Default a host-gate's full-suite `test`
target to running in parallel (`pytest-xdist`'s `-n auto`, or the equivalent
for the repo's runner) rather than leaving every host repo to notice
independently that its suite has become the bottleneck.

One structural rule decides where the flag goes, and getting it backwards is
the failure mode worth naming up front:

- **`-n auto` belongs in the Makefile's `test` recipe, not in `addopts`.**
  `addopts` applies to *every* pytest invocation, including the single-file
  gate calls most task files and CONTRIBUTING docs write
  (`pytest tests/test_x.py`) — putting `-n auto` there spins up a dozen workers
  to run one file. Only the full-suite recipe should add it.
- **`--dist loadfile` goes the other way, in `addopts`.** Nothing reads a
  Makefile recipe body, so a flag placed only there is unenforced for any
  invocation that bypasses that recipe; `--dist` alone is inert without `-n`,
  so it is safe to set unconditionally — a single-file run stays unchanged
  with it set.

Measured on one host repo, three independent re-runs of the same tree:
3x-5x (329→88s, 412→86s, 372→109s — reported as a band, not one derived
percentage, since three points do not support one).

**Expect parallelism to expose real cross-worker races**, not just move a
config flag — that is a cost of turning this on, not a reason not to. One host
repo turning it on found two tests that each touched the live working tree's
untracked-file listing; they had never overlapped serially and interleaved
immediately once they ran concurrently. A repo enabling this should expect to
find and fix genuine shared-state races.

---

## When one file is the long pole

Parallelism stops paying at the slowest single file. `--dist loadfile` sends
every test in a file to one worker, so a suite's wall clock can never fall below
the longest file's own runtime however many workers are added — a 6-minute
`test_api.py` keeps the suite at 6 minutes on 2 workers and on 32. This is the
wall the section above runs into next, and adding `-n` is not what gets past it.

Measure before splitting; the long pole is rarely the file anyone suspects:

```bash
pytest --durations=25          # slowest individual tests
pytest --collect-only -q       # what is in the suspect file
```

Per-**file** totals are what matter here, not the per-test ranking `--durations`
prints — one file of two hundred fast tests outruns a file with a single slow
one.

Then split the long pole into sibling files (`test_api_auth.py`,
`test_api_upload.py`) along seams that already exist — per class, per subsystem,
per fixture. Each part becomes independently schedulable and the floor drops to
the longest part. Two things decide whether that trade is worth taking:

- **Split where the expensive fixture boundary already is.** `loadfile` exists
  because tests in one file usually share a module-scoped fixture — a container,
  a migrated database, a compiled artifact. Splitting across that boundary makes
  each part pay the setup again, so wall clock falls while total CPU rises, and
  a suite billed by the minute can come out behind. Splitting *along* it costs
  nothing.
- **Give a slow-by-nature test its own file.** A test that is legitimately slow —
  a network round trip, a build, a long simulation — is a scheduling unit that
  wants to start early rather than tail behind a queue of fast ones.

`--dist load` removes the file floor outright by scheduling per test, and is the
right answer for a suite with no shared module state. It is not the default
recommendation because it breaks exactly the module- and class-scoped fixtures
`loadfile` was chosen to protect: reach for it only once the suite is known to
be free of them.

The same shape applies to any runner whose unit of parallel scheduling is the
file rather than the test — check which one the repo's runner uses before
assuming a split is needed.

---

## When parallelism is not the lever

`-n auto` is the right default for a **CPU-bound** suite and does almost nothing
for two shapes that are common in real gates. Both sections above are about the
first shape; read this one before concluding the advice is wrong.

### Process-spawn-bound suites have a throughput ceiling

A suite that shells out once per case — a hook harness, a CLI's integration
tests, anything driving a real shell or interpreter per assertion — is limited
by how fast the operating system can start processes, not by cores. Measured on
one such suite, spawns per second stayed flat from 8 workers to 32; the wall
clock is the process count times the spawn cost, and no scheduling change
touches it. Three hundred spawns was thirty seconds at every worker count tried.

The lever there is the **number of spawns**, or how often the suite runs — not
the worker count. Collapsing the per-case spawn is usually the wrong trade,
because spawning per case is typically how the thing under test runs in
production, and a faster gate that no longer exercises the real path has bought
speed with fidelity. Say which one you chose.

The diagnostic is one measurement: raise the worker count and re-time. Flat
means spawn-bound, and every further minute spent on parallelism is wasted.

### Deliberately slow work is a cost, not a defect

Key derivation, password hashing and envelope encryption are slow **on purpose**,
and a test at test-only cost factors proves nothing about the parameters that
ship. Twelve such tests were 28 seconds of one measured gate.

Lowering the cost factor everywhere removes the only test that would notice a
production parameter being weakened, which is the failure the tests exist to
catch. The shape that keeps both: **one test at production parameters asserting
the real constants**, and the rest sharing a derived-key fixture or running at
reduced cost. The expensive one stays, once.

---

## How often to run the whole gate

Run the full gate **once, before opening the PR**. While editing, run only the
suite covering what you touched.

This is worth more than every parallelism change in this document combined, and
unlike them it costs nothing and weakens nothing, because the gate that gates is
still the full one. Measured on one task: the full gate ran four times, three of
them after edits to one language's files only — about five minutes, where the
suite covering those files would have said the same thing in under a minute. The
pre-PR run is what decides; the runs during editing decide nothing and cost the
same.

The natural reading of "the gate is the bar" is to keep checking against it, so
this needs saying rather than assuming.

**Do not make the gate itself skip suites based on what changed.** That is the
obvious next step and it is wrong for the reason this whole document exists: a
gate that verifies a subset verifies nothing in particular, and the selection
logic becomes the least-tested code in the repo while holding the most
authority. The selectivity belongs in the editing loop, where a human or an
agent is choosing what to run next and can be wrong without anything being
certified. A repo that wants every run to be the full gate simply keeps running
it.

---

## Caching: inputs yes, outcomes no

Caching is the other half of a fast suite, and the line that matters runs
straight through this document's subject — what the gate actually certifies.

**Never cache outcomes in `host-gate`.** Tooling that skips tests it believes a
change could not affect — `pytest --lf`, `--ff`, `testmon`, a bare "no relevant
files changed, skipping" branch in CI — converts the gate's claim from *this
tree passes* into *nothing I chose to run failed*. Those are not the same
sentence, and the second one is the failure this bundle keeps naming: green on a
tree nobody verified, with no signal that the check narrowed. The
change-detection is where the correctness moved, and it is not something the
green tick reports on. Outcome caching belongs in the edit loop, where a human
is about to re-run everything anyway and a wrong skip costs one re-run.

**Caching inputs is the safe half — but "input" covers two different things,**
and only the first gets a free pass.

### Immutable inputs — cache them, key them on content

Resolved dependencies, virtualenvs, compiled extensions, Docker layers, a built
frontend bundle. These are produced from a manifest and do not change while the
suite runs, so a hit makes setup cheaper and changes nothing about what ran. On
a suite whose gate is a full `make host-gate` per worker per review round,
dependency install is often the larger half of the clock, and this is the
cheapest thing on the page to fix.

Key on a **content hash** of what produced them — a lockfile digest, a source
tree digest — never on a branch name or a bare date. A wrong content key misses
and costs time; a wrong lifetime key hits and costs correctness.

### Inputs derived from the tree under test — cache them carefully

An analysis of the repo's own working state: an untracked-file listing, a `git
status` read, a scan of the source tree, a snapshot of fixtures on disk. These
are expensive enough to be worth computing once, and many tests read the same
answer — so hoisting one into a shared fixture is a real and correct win.

But this kind of input is **mutable, and it is the thing under test**. A
snapshot taken once at session start goes stale the moment anything writes into
the tree — a test that stages a file, a fixture that drops a temp artifact, a
subprocess that runs a git command. A test then asserts against a tree that no
longer exists and passes because the snapshot is old. That is not outcome
caching, but it arrives at the same place: green on something nobody actually
looked at.

Two rules keep it honest:

- **Cache it for the session only if nothing in the suite mutates the tree.**
  That is an invariant somebody has to guarantee, not a default to assume. If a
  single test writes into the repo, the free pass is gone.
- **Otherwise key it on a tree digest**, so a mutation misses the cache and
  recomputes rather than silently serving a stale read.

### Fixture scope under parallel workers

`session`-scoped does not mean once. Under `pytest-xdist` each worker is its own
process running its own session, so a session-scoped fixture is computed **once
per worker** — on `-n auto` across eight workers, eight times, not one. Still a
large win over per-test, but size the benefit accordingly.

This is also where caching meets the long-pole split above, and the two can work
against each other. If a file's expensive setup costs `F` and its tests cost
`T`, splitting it into `k` parts that land on `k` workers gives roughly
`F + T/k` — every worker re-pays `F`. When `F` dominates, **splitting that file
buys almost nothing**, and the fix is to make `F` cheaper or to share it across
workers, not to cut the file up. Measure `F` before splitting; it is the
concrete form of the fixture-boundary warning above.

## Unmeasured — the third outcome

A numeric gate is routinely in a state that is neither pass nor fail: the check
ran, and what it found is that this cannot be scored yet — the prerequisite data
has not arrived. Without somewhere to put that, the honest evidence (a `null`)
lands in the non-numeric branch and reads as a hard failure, which pressures the
author into weakening the gate to something measurable — exactly the pressure
these gates exist to remove.

Declare it with an optional `status-key`, a dotted path to a string that may read
`unmeasured`:

````markdown
```gate
extraction_macro_f1 >= 0.75
evidence: metrics.json
key: extraction.macro_f1
status-key: extraction.status
```
````

`gate_evidence.py` then exits **3**, which `gate_run.sh` already treats as "could
not run" rather than as a verdict. It must be **positively asserted** in the
evidence file: treating any missing or null value as unmeasured would let a gate
stop checking by omission, which is the vacuous-pass hole these gates were added
to close, reopened somewhere new.

---

## Would the number move if the thing it measures broke?

Everything above is about a gate existing and producing a number. None of it asks
whether that number would change if the behaviour it measures regressed — and a gate
that cannot move is a gate that passes forever.

That question is one deliberate revert per claim, and it is a skill rather than a rule
here: `pin-check` (in the `python` section, beside `mutmut-report`) changes the exact
line a case claims to pin, runs only that case, restores, and reports `PINNED` /
`NOT PINNED` / `NOT MUTATED`. Run it on the claim, not on the module — it is seconds,
where a survivor score over a whole module is CPU-hours.

## The placeholder, and the first PR that replaces it

Every task is filed with a gate command that fails on purpose:

````markdown
```bash
# arsenal:gate-placeholder — replace with the real check; it may land in this task's own PR
false
```
````

`open_task_pr.sh` resolves the gate from the **default branch**, because a worker
whose own branch supplies the gate it is held to is certifying itself. Those two
rules used to collide: the placeholder on the default branch failed, so no PR
opened — and the only change that could replace the placeholder was the one that
PR carried.

The command is now the one part that defers. When the default branch's `bash`
block is still the placeholder — the marker above on the block's first line,
or a lone `false` from an earlier template — `gate_run.sh` runs the **working copy's** command instead and
says so on stderr. The `gate` block is unaffected: the metric, operator,
threshold and evidence path are still read from the default branch, every time,
so the assertion a worker is measured against is always the board's. Once a real
command has merged, the working copy stops being consulted.
