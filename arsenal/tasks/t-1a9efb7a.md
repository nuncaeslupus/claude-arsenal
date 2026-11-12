---
id: t-1a9efb7a
title: "review: bundle refresh silently changes create_reader.py's output name and markup"
priority: 5
requires: [human:gate]
---

Imported from issue #623

**Severity:** medium · **Confidence:** high · **Category:** release

### Finding
Re-vendoring a consumer from 5.0.1 to 5.26.0 changed `claude-arsenal/scripts/create_reader.py`'s contract with no migration note the refresh surfaces:

- output file was `<stem>-reader.html`; it is now `<project>-<stem>-v<n>-<stamp>-reader.html` (plus an `-annotated.md`)
- each section was `<article class="sec">`; it is now `<article class="sec l2" …>`

A consumer whose own code wraps the generator had a test locating the old file name and counting the old marker; CI went red on the re-vendor PR with `FileNotFoundError`. The consumer's wrapper itself still worked.

### Evidence
Reproduced on 2026-11-11 during a re-vendor: `uv run --with markdown python3 claude-arsenal/scripts/create_reader.py --input carta.md --output-dir out --name T` writes `out/rd-carta-v1-<stamp>-reader.html`; the consumer test expected `out/carta-reader.html`.

### Suggested direction
Treat bundle scripts' CLI output (file names, stable markers) as an interface: note changes to it in the CHANGELOG under a "changed output" line that `init.py` prints on refresh, or print the written path in a machine-readable form (`--json`) so wrappers do not guess it.

_Found while re-vendoring after the repo review of 2026-11-11. Not fixed in claude-arsenal; the consumer test was adapted._

## Acceptance gate

<!-- This task came from an issue, so its "gate" is prose. Write a real check
     below, then DELETE the `requires: [human:gate]` line in the front matter.
     Until that line is gone the selector will not offer this task, which is
     deliberate: a prose gate runs nothing, and a gate that runs nothing passes
     everything. -->

```bash
# arsenal:gate-placeholder — replace with the real check; it may land in this task's own PR
false
```
