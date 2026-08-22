# Scripts and CLI conventions

## Contents

- [Where scripts live](#where-scripts-live)
- [Argument naming canon](#argument-naming-canon)
- [Forbidden synonyms](#forbidden-synonyms)
- [Output discipline](#output-discipline)
- [Module layout](#module-layout)
- [Naming](#naming)
- [Print conventions](#print-conventions)
- [Duplication header](#duplication-header)

Load before adding a script to a skill, reviewing a script, or
diagnosing a validator script-failure.

## Where scripts live

Three sanctioned locations, in order of preference:

1. **Inside the skill that owns the helper** —
   `.claude/skills/<skill>/scripts/` or
   `plugins/<plugin>/skills/<skill>/scripts/`. Default for any helper
   a single skill needs.

2. **Plugin-shared, at `plugins/<plugin>/scripts/_shared/`** — when ≥2
   skills inside the *same plugin* need the same helper. Each
   consuming skill's own scripts import it as
   `from _shared.<helper> import …`. Single source of truth, no
   drift possible. The trade-off: skills inside the plugin become
   non-portable — lifting one out without bringing `_shared/` with
   it breaks the import. Prefer this over duplication when the
   helper is plugin-scoped and no skill outside the plugin needs it.

3. **Duplicated across skills with a sibling header** — when ≥2
   skills *across different plugins or top-level libraries* need
   the same helper, OR when a skill must remain liftable on its
   own. Each copy carries the `DUPLICATED ACROSS SKILLS:` header
   listing every sibling (see [Duplication header](#duplication-header));
   `sync_duplicates.py` detects SHA drift between copies. The
   shipping `anthropics/skills` repo uses this pattern exclusively
   — there is no programmatic cross-skill helper resolution in
   skill discovery itself.

Container-runtime scripts (paths outside the repo tree, e.g. inside a
Docker image's `/app/...` layout) are an exception — capability skills
reference them by absolute path. The validator allow-lists the
specific container-path prefixes (`/app/`, `/tmp/`, `/usr/`, …) so
those don't fail the missing-script check.

## Argument naming canon

Every script uses argparse with the following long-form names where
the concept applies. The validator allow-lists these and warns on
synonyms.

| Concept | Canonical flag |
|---|---|
| Single output file | `--output FILE` |
| Output directory | `--output-dir DIR` |
| Single input file | `--input FILE` |
| Input directory | `--input-dir DIR` |
| Generic identifier | `--id` |
| Named entity | `--name` |
| Tag / label | `--tag` / `--label` |
| Force JSON-to-stdout | `--json` |
| Result count cap | `--limit N` |
| Time-window start | `--since DATE-OR-RELATIVE` |

Skill-domain-specific args (e.g. `--driver`, `--connector-id`,
`--browser`) are tolerated when the skill owns its own vocabulary;
extend the canon list in `validate.py` rather than introducing a new
generic synonym.

## Forbidden synonyms

Validator flags any of these — pick the canonical equivalent:

- `--out`, `--out-path`, `--output-folder`, `--output-file` ⇒ `--output` / `--output-dir`
- `--in`, `--in-path`, `--input-folder` ⇒ `--input` / `--input-dir`

## Output discipline

- **stdout**: machine-readable payload (JSON) **only**.
- **stderr**: human-readable progress, errors, warnings.
- Exit codes: `0` success, `1` data/result failure, `2` internal /
  usage error.
- A script with `--json` should switch to stdout-only-JSON mode and
  silence its progress output.

This lets agents pipe `--json` output into `jq` without parsing
banners, while interactive humans still see ▶ ✓ ✗ on stderr.

## Module layout

- A `main()` function returning an exit code.
- A `if __name__ == "__main__": sys.exit(main())` guard.
- No top-level work — all I/O behind `main()`.
- Imports stdlib-first, then third-party, then local.
- **For HTTP, use `requests`, not `urllib`.** Semgrep's `python.lang.security.audit.dynamic-urllib-use-detected` rule blocks `urllib.request.urlopen(<variable>)` because `urllib` accepts `file://` schemes — a user-controlled URL can read local files. `requests.get` rejects `file://` by default, same call site, no extra surface. Every existing skill script that hits an API uses `requests`; matching the convention also skips the blocking-rule headache.

```python
#!/usr/bin/env python3
"""verb_noun.py — one-line summary."""

import argparse
import json
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    # ... do work ...
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## Naming

- Pattern: `verb_noun.py`. Snake case.
- Allowed verbs: `fetch_`, `query_`, `analyze_`, `create_`,
  `validate_`, `compare_`, `sync_`, `init_`, `audit_`, `run_`. Other
  verbs warn.
- Noun is the data domain (e.g. `repo_status`, `release_notes`,
  `cache_metrics`).

The verb signals what the script does. `fetch_` reads a remote thing.
`query_` parameterised search. `analyze_` derives a report. `create_`
mutates external state. `validate_` checks. `compare_` diffs two
inputs.

## Print conventions

User-facing scripts use the `_console.py` helper colocated in the
skill (or a duplicated copy) for consistent prefix-icons and colours:

| Icon | Meaning | Channel |
|---|---|---|
| `▶` | Start of a step | stderr |
| `✓` | Step succeeded | stderr |
| `✗` | Step failed | stderr |
| `⚠` | Warning, non-fatal | stderr |
| `ℹ` | Informational milestone | stderr |

Bold for headings, dim for paths. Errors and warnings always go to
stderr; informational milestones too. Stdout is reserved for the data
payload.

JSON-only scripts (no `--json` flag because they are always JSON) skip
the helper entirely — they print only the JSON payload to stdout and
errors to stderr.

The validator flags ad-hoc `print("Error:")` / `print("[ERR]")` and
suggests routing through `_console.error()`.

## Duplication header

When a script is duplicated across skills, every copy starts with a
docstring header listing its sibling copies:

```python
"""<verb_noun>.py — one-line summary.

DUPLICATED ACROSS SKILLS:
- plugins/<plugin-a>/skills/<skill-x>/scripts/<verb_noun>.py (canonical)
- plugins/<plugin-b>/skills/<skill-y>/scripts/<verb_noun>.py
- .claude/skills/<top-level-skill>/scripts/<verb_noun>.py

Keep all copies in sync. Update via skill-workshop's sync_duplicates.py
"""
```

The marker line is **`DUPLICATED ACROSS SKILLS:`** followed by
bulleted paths. `sync_duplicates.py` parses this header to identify
sibling sets, computes per-file SHA-256, and surfaces drift. The
canonical copy is the one annotated `(canonical)`; if absent, the
first listed entry is treated as canonical.
