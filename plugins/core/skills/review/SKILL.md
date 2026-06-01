---
name: review
description: When the user is reviewing a PR, diff, design doc, or proposal — risks, tech debt, standards compliance. Do NOT use for implementation (see execution), design (see design), or release sign-off (see release-readiness).
metadata:
  type: workflow
---

# Review Workflow

CANARY: review-loaded-2026-05-19-da60b2aa44b817de

## Steps

### Step 1: Understand intention

Read PR description/ticket. State the intention in one sentence before proceeding.
If the intention is unclear, ask before reviewing code.

### Step 2: Check engineering standards compliance

If engineering standards exist in the host repo (a project-level `engineering-core` skill or equivalent), verify:

- [ ] Code structure follows repo conventions
- [ ] Tech stack follows the approved stack
- [ ] Code conventions (naming, async patterns, type hints, no hardcoded secrets)
- [ ] API versioning (backwards compatible? New version if breaking?)
- [ ] Security (auth on new endpoints, input validation, audit logging, no sensitive data in logs)
- [ ] Configuration (URLs via env vars, safe defaults)

### Step 3: Check functional correctness

- Does the code actually solve the stated problem?
- Are there edge cases not handled?
- Are error paths handled correctly (not silently swallowed)?
- Is the data flow correct (inputs → processing → outputs)?
- Are there race conditions, deadlocks, or concurrency issues?

### Step 4: Check test coverage

- Are new code paths covered by tests?
- Are edge cases tested?
- Are error conditions tested?
- Do tests actually assert meaningful behavior (not just "it doesn't crash")?
- If no tests exist and the change is non-trivial → flag as blocker

### Step 5: Check operational readiness

- Will this change affect deployment? (migration, feature flag, coordination)
- Are there observability gaps? (new endpoints without tracing, new errors without alerts)
- Is the change backwards compatible with running instances during deploy?
- Is rollback straightforward?

### Step 6: Produce review output

Load `references/template.md` when producing the review output document.

---

## Abbreviation

**Abbreviated review** = Step 1 + quick diff scan + verdict. Whether abbreviation is allowed depends on project conventions documented in the host repo's `CLAUDE.md`.
