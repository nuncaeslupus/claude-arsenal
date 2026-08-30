---
id: t-acea0a1b
title: "har stage 1: extract section, skill scaffold, validate_har.py, the offset index"
priority: 1
deps: [t-e2a055be]
tags: [EXTRACT]
---

Plan: `docs/design/0002-har-analysis-toolkit-plan.md` T1–T3. Spec: `0002-har-analysis-toolkit.md` §§ 3, 4.6, 5.1.

- `plugins/core/skills/har/` with `section: extract` (default OFF) and argparse stubs for all six scripts.
- Fixtures, hand-built: `basic`, `traps`, `encodings` (14 cases), `hostile`, `compare_a`/`compare_b`.
- `validate_har.py`: HAR 1.2 well-formedness plus the capability report — which optional fields this exporter omitted, whether bodies are present, whether they are base64.
- `_harlib.py`: the byte-offset scanner (binary mode, brace depth, string/escape aware), `--verify-offsets`, the decode chain (base64 -> content-encoding -> charset, honest failure never a mangled string), and the redaction primitives including URL re-serialization.
- `analyze_har.py --index`: the § 5.1 sidecar schema, same-directory temp + atomic rename, size+mtime for index-only reads and the content digest only before a byte-offset seek.

Gates: `offset_reparse_mismatches == 0`, `encoding_matrix_pass_rate == 1.0`, SC2 (<= 30 s / <= 400 MB on a 200 MB capture), SC3 (<= 1 s AND <= 150 MB peak for an index-only query — a reader that materialises every row satisfies the time bound and blows the memory one), and a 0-token resident delta for repos without `extract`.


## Acceptance gate

```bash
bash plugins/core/tests/har_test.sh
make sync-sections-check
make context-budget
```
