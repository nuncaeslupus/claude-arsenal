# Notes: T<N> — <task-title>

> Scratch for `tmp/<task-id>-notes.md`. Ephemeral — gitignored by the
> host repo, never committed. Capture decisions and deviations while
> implementing; the durable record is `status/plan.md` (task status) and
> the PR description. Delete the file once the PR is open.

**Task**: T<N> from `status/plan.md`
**Branch**: `<ticket-id>-description`

---

## Failing test (red)

- Test: `<path>::<test_name>`
- Asserts: <what assertion proves this task is done>
- Confirmed failing for the expected reason: yes / no

## Decisions & deviations

| Decision | Reason |
|----------|--------|
| <deviation from the plan or spec> | <why> |

## Scratch

- <findings, dead ends, commands worth remembering while working>

## Before opening the PR

- [ ] Red test from above now passes (green)
- [ ] Lint + full test suite pass
- [ ] `status/plan.md` task status updated
- [ ] No debug code, commented-out blocks, or secrets left behind
