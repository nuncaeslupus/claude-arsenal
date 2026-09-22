# Performance tuning — reading the timings, and what each shape means

Load this when the loop feels slow: a gate that takes long enough that someone
is tempted to skip it, a review that runs more rounds than the change deserves,
or a task-to-PR cycle nobody can account for.

It is a map, not a second copy of the advice. Every remedy below is already
written somewhere in this bundle; what was missing was the number that says
which one applies. `bin/_timing.sh` records that number, this file routes it.

## Contents

- [Get the numbers first](#get-the-numbers-first) — the report, and what it is reading
- [Read the table in this order](#read-the-table-in-this-order) — total, then p95, then n
- [The shapes, and where the remedy is written](#the-shapes-and-where-the-remedy-is-written)
- [Phases: reading an `a:b` row](#phases-reading-an-ab-row) — what is inside a boundary, and recording your own
- [What these numbers cannot tell you](#what-these-numbers-cannot-tell-you) — and how to get the rest

---

## Get the numbers first

```bash
python3 claude-arsenal/scripts/arsenal_timings.py
```

`--days N` narrows the window (default 30); `--days 0` reads everything the
file still holds. If the host repo's Makefile wires a `timings` target at that
script, `make timings` is the same thing.

Collection is always on and costs a few milliseconds per boundary. Four bundle
scripts write it — `gate_run.sh`, `open_task_pr.sh`, `adversarial_review.sh`,
`merge_ready.sh` — appending one tab-separated row each to
`tmp/arsenal-metrics/metrics.tsv`: a timestamp, an event name, a label, a
duration, an exit code, a task id. No paths, no file contents, no diff. The
directory carries a `*` .gitignore, so the file is never committed, and nothing
is ever uploaded anywhere.

There is one file per repo, in the **main** checkout: a worker running in a
throwaway worktree appends to it too, so a fleet's numbers survive the worktree
being torn down and the report covers all of them at once.

Reading is on demand — this script, run by a person with a question. Nothing
enters a context window until then, which is the point: the data has to already
exist when the problem appears, because that is exactly when you cannot go back
and collect it.

`ARSENAL_METRICS=off` in the environment stops collection entirely.
`ARSENAL_METRICS_MAX_LINES` (default 5000) bounds the file.

## Read the table in this order

**Total, before p95.** The rows are ordered by total time for a reason: a
90-second step that runs once a day is not the bottleneck that a 9-second one
running 200 times is. Optimising the slow-looking row is how a day disappears
into something nobody was waiting on.

**Then p95, against p50.** p50 is what a run costs; p95 is what the loop feels,
because the tail is what a person sits through. Close together means the step
has one speed and the remedy is to make that speed lower. Far apart means some
runs are doing something the others are not — and `slowest single runs` at the
bottom of the report names which ones, so there is a concrete thing to go and
look at rather than a distribution to reason about.

**Then n.** A high count is the multiplier, and it is often the real finding:
`review rounds per change` is printed separately for exactly that reason.

## The shapes, and where the remedy is written

| What the report shows | What it means | Read |
|---|---|---|
| `gate` total dominates, n is high | The gate is fine; it is being run too often | `references/evidence-gates.md` § How often to run the whole gate |
| `gate` p95 high, n low, one suite obviously the long pole | A single file or suite is setting the floor | `references/evidence-gates.md` § When one file is the long pole |
| `gate` barely moved after parallelising | The suite is process-spawn-bound, not CPU-bound — more workers cannot help | `references/evidence-gates.md` § When parallelism is not the lever |
| `gate` slow and one suite is a KDF / crypto / deliberately-slow check | Some of that cost is the point, and dropping it drops the thing being tested | `references/evidence-gates.md` § Deliberately slow work is a cost, not a defect |
| `review-round` p50 high | Each round is re-running checks the session already ran | `references/pre-pr-review.md` § Making a round cheaper |
| `review rounds per change` median > 1 | The round count, not the round cost, is the bill | `references/pre-pr-review.md` § Rounds, and § The cap, and the three ways out |
| `merge-ready` n very high | The loop is waiting on CI, not on anything local | `references/github-automation.md` § Merge policy |
| `task-pr` total far exceeds its parts | The time is between the boundaries, not inside them | § What these numbers cannot tell you, below |
| One `task-pr:<phase>` row is most of the `task-pr` row | That phase is the bill, and the rest of the loop is noise beside it | The section that owns the phase — `host-gate` and `task-gate` → `references/evidence-gates.md`; `review` → `references/pre-pr-review.md` |
| A gate step sweeps many modules, one process each | Interpreter startup is being paid once per module, and parallelism cannot reach it | `references/evidence-gates.md` § One process per module pays interpreter startup per module |
| `review-round` p50 high and the reviewer re-runs the whole suite per mutation | The suite's scope during the mutate-restore cycle, not the round count | `references/pre-pr-review.md` § Scope the suite while mutating |

A row with a non-zero `fail` count is worth reading before any of this. A gate
that fails fast and gets re-run is cheap per call and expensive per change, and
the timing table shows it as a fast step rather than as the problem it is.

## Phases: reading an `a:b` row

A row named `a:b` is a **phase inside** `a`, not time on top of it. The phases
under a parent are contiguous and sum to it, so `task-pr` 13m26s with a
`task-pr:host-gate` of 13m25s is one thirteen-minute wait whose cause is now
named — not two.

`open_task_pr.sh` reports ten: `review`, `task-gate`, `fetch`, `issue`,
`branch`, `archive`, `host-gate`, `commit`, `push`, `pr`. Whichever one was
running when a refused run exited carries its non-zero exit code, so the `fail`
column says *where* the loop stops, not only that it did.

**A host can record its own sub-targets the same way.** `host-gate` is the
host's command, and this bundle cannot know it is four make targets — so a
Makefile that wants the breakdown writes it, through the same entry point and
into the same file:

```bash
source claude-arsenal/bin/_timing.sh
s=$(date +%s); make test; rc=$?; e=$(date +%s)
arsenal_timing_record host-gate:test "" "$(( (e - s) * 1000 ))" "${rc}"
```

`host-gate:test` then appears in the table beside everything else. That is the
difference between a report that says the gate is slow and one that says which
target inside it is — and it is the part nobody should have to hand-instrument
twice.

## What these numbers cannot tell you

**There is no per-suite breakdown, unless you record one.** A gate block is one
command from the bundle's side: `gate_run.sh` measures the block, not the suites
inside it, and it cannot see into a `make test` that runs three of them. If the
table says the gate is the bottleneck and you need to know which suite, record
them yourself — § Phases above is the entry point, and the answer is one run
away.

**Time outside a bundle script is unmeasured.** Reading files, writing the
change, thinking: none of it runs through a boundary arsenal owns, so none of it
appears here. A `task-pr` row much larger than the `gate` and `review-round`
rows under the same task id is that gap, and it is not evidence of a slow gate.
The phases narrow it to what happens inside one script; they say nothing about
the session that ran before it.

**Nothing is comparable across repos.** The file is local, per-repo, and stays
that way. A p95 here means something about this machine and this suite, and
nothing at all about anybody else's.
