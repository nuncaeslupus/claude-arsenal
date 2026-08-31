---
id: t-101b0bba
title: "har stage 5: compare_har.py, skill docs, and the flag-parity check"
deps: [t-7675f12c]
priority: 5
tags: [EXTRACT]
status: merged
---

Plan T9–T10. Spec §§ 4.5, 5.2.

- `compare_har.py`: deterministic one-to-one pairing on `(method, scheme, host, port, path, query pairs in captured order, hash of request body)`. `pageref` is not in the key — page ids are local to a capture, so including it would turn the same request in two captures into a removal plus an addition. Leftovers are reported as additions or removals, never paired with something that merely resembles them.
- SKILL.md complete, `references/filters.md` and `references/recipes.md`, evals.
- The flag-parity test: sibling scripts expose identical selection flags. § 5.2 asks for consistency as a contract rather than a convention, so it is checked.

Gates: `invented_changes_on_repeat_url_fixture == 0`, `resident_listing_tokens_with_extract <= 130` (SC7), `shared_flag_parity_failures == 0`.


## Acceptance gate

```bash
bash plugins/core/tests/har_test.sh
make audit
make context-budget
```
