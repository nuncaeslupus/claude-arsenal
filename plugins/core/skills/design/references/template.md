# Design: <title>

**Date**: YYYY-MM-DD
**Ticket / PR**: <id>
**Discovery**: link to discovery document or summary
**Author**: <name>

---

## 1. Technical solution

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

## 2. Contracts

### API contracts

#### `METHOD /v1/path`

- **Auth**: required / internal only
- **Request**:
  ```json
  {}
  ```
- **Response (200)**:
  ```json
  {}
  ```
- **Errors**: 400, 401, 404, 500
- **Backwards compatible**: yes / no

### Inter-service contracts

| Caller | Callee | Protocol | Contract | Failure handling |
|--------|--------|----------|----------|-----------------|
| | | HTTP / message-queue | | retry / dead-letter |

### Database migrations

| Service | Database | Change | Reversible | Forward-compatible |
|---------|----------|--------|------------|-------------------|
| | | | yes/no | yes/no |

---

## 3. Implementation tasks

1. **T1** — <description> | Service: <service> | Size: S/M/L
2. **T2** — <description> | Service: <service> | Size: S/M/L | Depends: T1
3. **T3** — <description> | Service: <service> | Size: S/M/L | Depends: T1
4. **T4** — <description> | Service: <service> | Size: S/M/L | Depends: T2, T3

**Merge order**: T1 first, then T2/T3 (parallel), then T4
**Branch pattern**: `<ticket-id>-T<N>-description` from the default branch

---

## 4. Risks & Validation

| Risk | Likelihood | Impact | Mitigation | Validation |
|------|-----------|--------|------------|------------|
| | Low/Med/High | Low/Med/High | | <unit/integration/manual/perf/security> |

---

## Sign-off

- [ ] Design reviewed by second engineer
- [ ] Contracts agreed with consuming services
- [ ] Migration strategy validated
- [ ] Ready for execution
