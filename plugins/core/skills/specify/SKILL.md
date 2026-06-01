---
name: specify
description: When the user is investigating a problem or scoping a new feature with unclear impact — analyzes it and proposes options. Do NOT use for already-scoped work (see design), implementation (see execution), or routine code edits.
metadata:
  type: workflow
---

# Specify Workflow

CANARY: specify-loaded-2026-06-01-7f9501625b833979

Owns sections 1–4 of `status/specification.md`: problem statement, affected systems, options, recommendation. Creates the file if it does not exist; appends/updates these sections if it does. Per-task scratch goes in `tmp/` (not committed); never in `status/`.

## Steps

### Step 1: Understand the problem

Clarify what is actually being asked. Separate symptoms from root causes.

- **What is happening?** — Observable behavior, errors, or gaps
- **What should be happening?** — Expected behavior or desired outcome
- **Since when?** — Timeline, triggers, or recent changes that may be related
- **Who is affected?** — End users, internal teams, other services, clients
- **What is the urgency?** — Blocking production, degrading performance, or planned improvement?

Output: a clear, one-paragraph **problem statement**.

### Step 2: Identify affected systems

Map which parts of the codebase and infrastructure are involved.

- **Primary service(s)/component(s)**: where the change or fix will happen
- **Dependent systems**: services, modules, or components that consume from or feed into the primary
- **Shared resources**: databases, queues, caches, external APIs
- **Infrastructure**: cloud resources, deployment configs
- **Frontends/clients**: any UI or API consumer that surfaces the affected functionality

Trace dependencies through code, configuration, and communication patterns.

Output: a **dependency map** listing each system, its role, and whether it needs changes or just validation.

### Step 3: Explain impact

For each affected system, assess what happens if the change ships — and what happens if it doesn't.

- **Data impact**: stored data, integrity, or data flows?
- **API impact**: public or internal API contracts? Requires versioning?
- **Performance impact**: latency, throughput, or resource usage?
- **User impact**: will end users or API clients notice? Will they need action?
- **Operational impact**: deployment coordination, monitoring changes, runbook updates?
- **Risk if nothing changes**: cost of inaction?

Output: an **impact assessment** with severity (Low / Medium / High) per dimension.

### Step 4: Propose options

Present 2-3 viable approaches. For each:

- **Description**: what the approach does in plain language
- **Scope**: which services and files are touched
- **Effort**: Small / Medium / Large
- **Tradeoffs**: pros and cons (technical debt, risk, maintainability)
- **Compatibility**: backwards compatible? Requires API versioning?
- **Dependencies**: infrastructure changes, team coordination, client notification?

Always include at least one conservative option (minimal change, lowest risk)
and one option that addresses the root cause more thoroughly.

Output: a **comparison table** of options.

### Step 5: Recommend next step

- **Recommended option**: which and why
- **Immediate next action**: first thing to do (e.g., "create branch, start with migration in service X")
- **Gates check**: if the engineering-core skill is available, verify against its gates (objective, scope, impacted services, compatibility, risk, validation, release readiness)
- **Open questions**: anything unresolved that needs input before starting

Output: a clear **recommendation with action item**.

---

## Abbreviation

**Abbreviated specify** = Steps 1 + 2 (one paragraph each). Whether abbreviation is allowed depends on project conventions documented in the host repo's `CLAUDE.md`.

Load `references/template.md` when creating or updating `status/specification.md` (sections 1–4).
