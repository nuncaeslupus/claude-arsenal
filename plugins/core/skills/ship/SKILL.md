---
name: ship
description: When the user is confirming a change is ready for production before merge — compatibility, tests, observability, rollback. Do NOT use for implementation (see execution) or PR review (see review).
metadata:
  type: workflow
---

# Ship Workflow

CANARY: ship-loaded-2026-06-01-969928a90f431ecb

Reads `status/specification.md` to know what should be shipping. Confirms scope coverage, compatibility, tests, observability, and rollback before the merge.

## Steps

### Step 1: Confirm final scope

- Intended vs actual scope. Any drift? Any missing pieces?
- If drift → decide: acceptable or split into separate PR?
- If scope grew significantly → does the risk assessment need updating?

### Step 2: Confirm objective coverage

- Does the change solve the stated problem?
- All acceptance criteria satisfied?
- If partial delivery → is the partial state safe and functional?

### Step 3: Compatibility check

- [ ] Backwards compatible with previous API version (if API changes)
- [ ] Database migration is forward-compatible (no destructive changes in same deploy)
- [ ] Inter-service contracts maintained or migrated
- [ ] Client notification sent (if public API changes)

### Step 4: Test confirmation

- [ ] All unit/integration tests pass (including the tests written first for this change)
- [ ] E2E tests pass (if applicable)
- [ ] Manual testing completed for high-risk paths
- [ ] No flaky tests introduced

### Step 5: Observability check

- [ ] New endpoints have tracing instrumentation
- [ ] Error conditions produce meaningful log entries
- [ ] Business metrics updated (if applicable)
- [ ] Alerts configured for new failure modes (if applicable)

### Step 6: Deployment plan

- [ ] Deployment order defined (if multi-service)
- [ ] Feature flags configured (if gradual rollout)
- [ ] Data migration tested (if applicable)
- [ ] Rollback plan documented
- [ ] On-call team aware (if high-risk)

### Step 7: Produce ship output

Load `references/template.md` when producing the ship output document.

---

## Abbreviation

**Abbreviated ship** = Steps 2 + 4 + Go/No-Go. Whether abbreviation is allowed depends on project conventions documented in the host repo's `CLAUDE.md`.
