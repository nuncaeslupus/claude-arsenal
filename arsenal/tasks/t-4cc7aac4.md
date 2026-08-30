---
id: t-4cc7aac4
title: "har stage 3: analyze_har.py insight modes"
deps: [t-275b3739]
priority: 1
tags: [EXTRACT]
---

Plan T6. Spec § 4.1.

Overview, `--stats FIELD`, `--errors`, `--endpoints`, `--headers`, `--cookies`, `--redirects`, `--slowest`/`--largest`, `--websockets`.

`--endpoints` is the one that earns the stage: collapsing `/api/jobs?page=1..3&loc=NY` into one row reporting `page` varying over 1-3 and `loc` constant is the difference between reading 40 URLs and reading how to iterate the site.

`--headers` must keep working under redaction, which is why redacted values carry a salted fingerprint rather than a bare marker — equal values stay equal, so the constant-versus-varying split still finds the auth header.

Gate: `endpoint_rows_for_paginated_fixture == 1` with `page` varying and `loc` constant.


## Acceptance gate

```bash
bash plugins/core/tests/har_test.sh --stage 3
```
