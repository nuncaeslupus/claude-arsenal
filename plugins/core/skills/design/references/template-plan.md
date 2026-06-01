# Plan: <title>

> Seed for `status/plan.md`. `design` creates it from the technical
> solution and the task split. Pairs with `status/specification.md`
> (problem, options, contracts, risks); `execution` works the task table
> and updates each task's status as it goes.

**Date**: YYYY-MM-DD
**Specification**: `status/specification.md`
**Author**: <name>

---

## Technical solution

### Architecture overview

<How the change fits into the existing system. Diagram if helpful.>

### Data flow

<How data moves through affected services.>

### State changes

| Service | Database | Change | Description |
|---------|----------|--------|-------------|
| | | CREATE/UPDATE/DELETE | |

### Technology choices

| Choice | Justification |
|--------|--------------|
| | |

### Out of scope

- <What is explicitly NOT changing>

---

## Implementation tasks

| T# | Description | Service | Size | Depends | Tests |
|----|-------------|---------|------|---------|-------|
| T1 | <description> | <service> | S/M/L | — | <files + testability statement> |
| T2 | <description> | <service> | S/M/L | T1 | <files + testability statement> |
| T3 | <description> | <service> | S/M/L | T1 | <files + testability statement> |
| T4 | <description> | <service> | S/M/L | T2, T3 | <files + testability statement> |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

**Merge order**: T1 first, then T2/T3 (parallel), then T4
**Branch pattern**: `<ticket-id>-T<N>-description` from the default branch

### Dependency graph

```
T1 ──┬─> T2 ──┐
     └─> T3 ──┴─> T4
```

---

## Sign-off

- [ ] Design reviewed by second engineer
- [ ] Contracts agreed with consuming services
- [ ] Migration strategy validated
- [ ] Ready for execution
