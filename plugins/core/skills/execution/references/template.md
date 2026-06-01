# Execution: <title>

**Date**: YYYY-MM-DD
**Ticket / PR**: <id>
**Design**: link to design document
**Task**: T<N> from design
**Author**: <name>

---

## 1. Implementation plan

### Task scope

- **Task from design**: T<N> — <description>
- **Service(s)**: <service>
- **Dependencies**: T<N-1> merged? yes/no
- **Branch**: `<ticket-id>-description`

### Files affected

| File | Action | Description |
|------|--------|-------------|
| `<service>/app/...` | Create / Modify | |
| `<service>/tests/...` | Create / Modify | |
| `<service>/migrations/...` | Create | |

### Prerequisites verified

- [ ] Design approved
- [ ] engineering-core gates complete
- [ ] Branch created from latest default branch
- [ ] Local environment running
- [ ] Prerequisite tasks merged
- [ ] Failing test designed (red)

---

## 2. Tests and validation

### Tests written

| Type | File | What it covers |
|------|------|---------------|
| Unit | `<service>/tests/...` | |
| Integration | `<service>/tests/...` | |
| Edge case | `<service>/tests/...` | |

### Test results

```
<test-command> <service>    → PASS / FAIL
<lint-command> <service>    → PASS / FAIL
<e2e-command>               → PASS / FAIL (if applicable)
```

### Manual verification

- [ ] Endpoint responds correctly at the configured base URL
- [ ] Data stored correctly in database
- [ ] Audit logs generated (if security-relevant)
- [ ] Backwards compatibility verified (if API change)

---

## 3. Changes made

### Commits

| Commit | Description |
|--------|-------------|
| `abc1234` | <what this commit does> |
| `def5678` | <what this commit does> |

### Contract compliance

- [ ] API contract matches design: <endpoint>
- [ ] Database migration matches design: <migration>
- [ ] Inter-service contract matches design: <caller → callee>

### Key decisions during implementation

| Decision | Reason |
|----------|--------|
| <any deviation from design> | <why> |

