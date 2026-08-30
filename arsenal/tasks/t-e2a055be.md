---
id: t-e2a055be
title: "Make the map unasked-for: session-start step 0c and the volunteering rule"
priority: 5
deps: [t-c230a7b5]
tags: [CORE]
---

Design: `docs/design/0003-capability-discovery.md` § 5–7.

The flag from t-c230a7b5 is a mechanism nobody invokes until this lands. A discovery
mechanism that waits to be invoked serves only people who already know the answer.

- `AGENTS.md` session-start step **0c** (inside "Refresh the bundle", not a new
  numbered step): run `--list-sections`, plus the one-sentence behavioural rule —
  when a later task is squarely covered by a section this repo did not install, say
  so once before doing the work the long way.
- `references/capability-map.md`: the rule stated generally, both failure modes
  (silence and pestering), the worked examples, `--section NAME`, and where the
  manifest comes from. Indexed in the AGENTS.md references table.
- `init` SKILL.md: a line pointing at the flag.
- CHANGELOG entry + `.bundle-version` minor bump + `make sync-version`.
- Report the measured `make context-budget` delta in the PR body.

PR 2 of the stack; only this one bumps the version.


## Acceptance gate

```bash
bash plugins/core/tests/bundle_refs_test.sh
make sync-version-check
make context-budget
```
