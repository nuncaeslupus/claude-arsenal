# Claude Arsenal — Specification (annotated edition)

> Generated 2026-08-31. This is the document with a **note slot** after every section. Read it in any Markdown app. To annotate, replace the `_(your notes…)_` placeholder under any section. When done, send the file back — notes are acted on.

---

# 0003 Capability Discovery

## Preamble & scope

**Status:** Proposed — implementation plan for a requirement already merged
**Requires:** skill sections (#273, v2.8.0)
**Specified by:** `docs/design/0002-har-analysis-toolkit.md` § 5.5, which states
the requirement and the behaviour and defers the implementation to here.

> **Why this exists.** Sections made the install set a choice, and a choice
> creates a thing nobody knows about. A consumer who never enabled `python`
> has no way to learn that `coverage-gaps` exists, because the only place a
> skill announces itself is the resident skills listing — which lists exactly
> the skills that were installed. Default-off without discovery is a tool
> that ships and is never found.

<!-- -->

> **✎ Notes** · `SPEC · intro`
> _(your notes here — replace this line)_

## §1 The problem, stated precisely

The failure is **not** "the consumer cannot find the tool when they go
looking". It is that **they never go looking**, because nothing ever told them
there was anything to look for. Every discovery mechanism that waits to be
invoked — a `--help`, a docs page, a `README` table — serves only people who
already know the answer.

So the mechanism has to push, once, cheaply, into every session:

> A session must begin knowing the whole map of what this marketplace can do,
> not just what this repo installed.

And it has to be **general**. `har`/`extract` is the first case that made the
gap visible; a discovery path built for it alone leaves the identical hole open
for the next section and the one after. The map covers every section and every
skill, installed or not, now and for whatever ships later.

<!-- -->

> **✎ Notes** · `SPEC §1`
> _(your notes here — replace this line)_

### Success criteria

| # | Criterion | How it is checked |
|---|---|---|
| SC1 | A session in a repo with `python` off can name `coverage-gaps` and say what it does, without network or plugin access | `list_sections_test.sh`: install with `--profile general`, assert the flag's output names `python` and its five skills |
| SC2 | The map is truthful about what is installed *here* | test asserts `on`/`off` markers match `.claude/skills/` contents after `--sections`/`--profile` installs |
| SC3 | The map costs under ~120 tokens of session context, once per session | `context_budget.py` reports the AGENTS.md delta; the command's own output is measured in the test |
| SC4 | A new section cannot ship without appearing on the map | `make sync-sections-check` in CI fails when a shipped `section:` has no manifest entry |
| SC5 | The map works from a vendored copy with the plugin absent | test runs the flag from `<repo>/.claude/skills/init/scripts/init.py` with no marketplace checkout on the path |

<!-- -->

> **✎ Notes** · `SPEC › Success criteria`
> _(your notes here — replace this line)_

## §2 The one hard constraint

**A vendored `init.py` cannot see the skills it did not install.**

`_source_skills_dir()` returns the directory `init` lives in. In the
marketplace that is `plugins/core/skills/` and holds all 18 skills. In a
consumer it is `.claude/skills/` — which `_vendor_skills` has already pruned
down to the installed set. `_known_sections()` therefore answers "which
sections exist" correctly only in the marketplace, and in a consumer answers
"which sections you already have", which is precisely the question that does
not need asking.

Every design that scans disk fails SC1 for this reason. The map has to be
**shipped data**, written at authoring time in the marketplace and travelling
with the bundle.

<!-- -->

> **✎ Notes** · `SPEC §2`
> _(your notes here — replace this line)_

## §3 The manifest

`plugins/core/skills/init/assets/sections.json` — generated, committed, and
CI-checked against the skills it describes.

```json
{
  "generated_by": "scripts/sync_sections.py",
  "sections": [
    {
      "name": "extract",
      "default": false,
      "blurb": "structured data out of artifacts you did not produce",
      "skills": [
        {"name": "har", "description": "When the user has a HAR capture …"}
      ]
    }
  ]
}
```

Three fields per section and two per skill, and each earns its place:

- **`blurb`** is the only hand-written field, and the only one with no other
  home. A skill's `description` is written to trigger loading; a *section*
  has no frontmatter, so its one-line summary lives in the generator's
  `SECTION_BLURBS` table and is copied here. Four entries today.
- **`description`** is copied verbatim from each skill's frontmatter. It is
  not printed by the default map — it is what `--section NAME` prints, which
  is how a session checks whether an uninstalled skill actually fits before
  recommending it. For installed skills this duplicates the resident listing;
  for uninstalled ones it is the only copy that exists, which is the point.
- **`default`** so the map can say what a fresh install would have done.

<!-- -->

> **✎ Notes** · `SPEC §3`
> _(your notes here — replace this line)_

### Why a file rather than a constant in init.py

A generated block inside a hand-edited script is a merge conflict waiting to
happen and invites hand-editing the generated half. `assets/` is already the
vendored-data directory (`AGENTS.md`, `CHANGELOG.md`, `.bundle-version`,
`workflows/`), and `_vendor_skills` copies the whole `init/` tree, so a file
there is reachable identically from the marketplace and from a consumer:
`Path(__file__).resolve().parent.parent / "assets" / "sections.json"`. No
bundle-path resolution, no `--repo-path` dependency, one code path (SC5).

<!-- -->

> **✎ Notes** · `SPEC › Why a file rather than a constant in init.py`
> _(your notes here — replace this line)_

### Generation and the drift guard

`scripts/sync_sections.py`, mirroring `sync_version.py` — rewrite in place, or
`--check` to fail on drift, wired as `make sync-sections` / `make
sync-sections-check` and run in CI next to `sync-version-check`.

It reads every `plugins/*/skills/*/SKILL.md`, groups by the `section:`
frontmatter key (absent ⇒ `core`, matching `_skill_section`), and writes the
manifest. It **fails** when a section it found has no `SECTION_BLURBS` entry:
that is SC4, and it is the whole reason the check exists. Adding a skill in a
new section without a one-line description of that section is a CI failure,
not a silently blank line on every consumer's map.

The `section:` frontmatter is parsed the same way `init.py` parses it — the
frontmatter block only, so the word in body prose cannot re-file a skill. The
two parsers agreeing is asserted by a test rather than by shared code: the
scripts do not share a module because `init.py` is vendored and
`sync_sections.py` is not.

<!-- -->

> **✎ Notes** · `SPEC › Generation and the drift guard`
> _(your notes here — replace this line)_

## §4 init.py --list-sections

Prints the map and exits 0. Writes nothing — no config, no vendoring, no
bundle refresh. That matters because the session-start protocol runs it
unattended on every session including compaction restarts; a discovery command
with a side effect is a discovery command nobody dares run.

```
$ python3 .claude/skills/init/scripts/init.py --list-sections
skill sections — 2 of 4 installed here
  core      on   the bundle: installer, queue engine, and the skills the protocol names
  workflow  on   spec → design → execute → review → ship
  python    off  the Python toolchain — coverage-gaps, dep-upgrade, mutmut-report, pypi-release, python-bootstrap
  extract   off  structured data out of artifacts you did not produce — har
  off sections: `init.py --sections a,b` or edit [skills] in arsenal/config.toml; `--section NAME` for detail
```

Four decisions in that shape:

1. **Skills are named for `off` sections and not for `on` ones.** An installed
   skill is already in the resident listing with its full description; naming
   it again on the map is paying twice for the same fact. An uninstalled one
   appears nowhere else at all. The asymmetry is the budget (SC3): it keeps
   the common case — most sections installed — at one short line each.
2. **One line per section, never one per skill.** With four sections it would
   not matter; the map has to stay a map at twelve. `--section NAME` is where
   per-skill detail lives, on demand.
3. **`on`/`off` is read from disk**, not from `arsenal/config.toml`: a section
   is on here if `.claude/skills/` holds any of its skills. That is what a
   session can actually load, and it stays right when a config edit has not
   been applied by an `init.py` run yet. Config is the fallback when
   `.claude/skills/` is absent.
4. **The last line is in the output, not in `AGENTS.md`.** Anything a session
   needs *at the moment it reads the map* can be paid once per session in the
   command's stdout rather than every turn in the resident file.

Degraded mode: a manifest that is missing (a consumer whose bundle predates
this version) falls back to a disk scan and says so — `sections (installed
only — bundle predates the shipped map; run check_update.sh)`. Wrong-but-
labelled beats a traceback in a protocol step.

<!-- -->

> **✎ Notes** · `SPEC §4`
> _(your notes here — replace this line)_

## §5 The session-start step

`AGENTS.md` § Session-start protocol gains step **0c**, inside the existing
"Refresh the bundle" step rather than as a new numbered step — the numbers are
cited from `references/` and from other skills, and renumbering them to add a
one-command step is churn that buys nothing.

Four lines, and the behavioural commitment is one sentence of them:

> c. **Read the capability map** — `python3 .claude/skills/init/scripts/init.py
> --list-sections` prints every skill section this marketplace ships and
> whether it is installed here. It is read, not filed: when a later task is
> squarely covered by a section this repo did **not** install, say so once,
> before doing the work the long way.
> → `claude-arsenal/references/capability-map.md`

<!-- -->

> **✎ Notes** · `SPEC §5`
> _(your notes here — replace this line)_

## §6 The behaviour, and its two failure modes

The commitment is behavioural, not documentary. A repo gets a task that a skill
it did not install would do properly; the session knows that skill exists,
because it read the map at start-up; it says so before doing the work the hard
way:

> This repo does not have the `extract` section installed, which ships `har` —
> HAR capture analysis for exactly this. Enable it with `--sections extract`,
> or say the word and I will continue with the browser.

The scraping example is 0002's; the rule is general and is written that way in
`references/capability-map.md`. A Python repo that never enabled `python` and
is asked where its test coverage gaps are should mention `coverage-gaps`.

Bounded on both sides, because both failure modes are real:

| Failure | What it looks like |
|---|---|
| Silence | Grinding through a task with a browser while the right tool sits one config line away, unmentioned. The one this exists to fix. |
| Pestering | Naming a section on every loosely related request, until it reads as an upsell and gets ignored — which costs the first failure back. |

The trigger is **squarely covered**: the task is what the skill is for, not
adjacent to it. And the session **says it once and then does what was asked** —
the person deciding whether to install is the one who knows whether it is worth
it, and a decision not to install is not re-litigated later in the session.

<!-- -->

> **✎ Notes** · `SPEC §6`
> _(your notes here — replace this line)_

## §7 What it costs

Measured, per this repo's rule, not estimated:

| Where | What | Paid |
|---|---|---|
| `AGENTS.md` step 0c + refs row | **+139 tokens** measured (4370 → 4509 resident) | every turn, every session |
| `--list-sections` stdout | **496 bytes / ~125 tokens** at 3 sections, measured | once per session (and once per compaction restart) |
| `sections.json` | 7.6 KB on disk | never in context; `--section NAME` reads it |
| `references/capability-map.md` | ~900 tokens | only when opened |

Both resident numbers are `make context-budget` before and after, not estimates:
the step and its references row cost **139 tokens of the 5000-token resident
budget**, leaving 491 headroom. That is more than the "a few lines" reading of
the diff suggests, which is exactly why the rule is to measure — five lines of
prose in a file imported on every turn is not a five-line change.

Set against: one session that reaches for a browser, or hand-writes something a
shipped skill already does, because it did not know it had an alternative.

<!-- -->

> **✎ Notes** · `SPEC §7`
> _(your notes here — replace this line)_

## §8 Out of scope

- **Installing a section from inside a session.** The map recommends;
  `--sections` installs; a session that could silently re-vendor its own skill
  set is a much larger change than this one and is not needed for the
  behaviour.
- **Per-skill on/off.** Sections are the unit. Nothing here changes that.
- **Blurbs in SKILL.md frontmatter.** A `metadata: blurb:` key across 18 skills
  to save a four-entry table is churn; revisit if the table reaches a dozen.
- **Third-party marketplaces.** The manifest describes this bundle only.

<!-- -->

> **✎ Notes** · `SPEC §8`
> _(your notes here — replace this line)_

## §9 Delivery

| Task | Contents | PR | Bump |
|---|---|---|---|
| C | `query_status.py` handle check, `make queue-doctor` fetch, CI token, this note, the three task files | 0 | patch |
| A | `sections.json`, `sync_sections.py`, `make sync-sections{,-check}`, CI wiring, `--list-sections` / `--section NAME`, `list_sections_test.sh` | 1 (on 0) | minor |
| B | `AGENTS.md` step 0c + refs row, `references/capability-map.md`, `init` SKILL.md note | 2 (on 1) | minor |

Split so that PR 1 is a self-contained, testable capability and PR 2 is the
wiring that makes it happen unasked. PR 0 is a prerequisite found while queuing
the other two: `make queue-doctor` reports every task file as handle-less
because it passes no `--issues`, so the first task file added to this repo makes
its own dogfood job unpassable.

**Every PR in this stack bumps `.bundle-version`, which the stacking rule says
intermediate PRs should not.** That rule assumes an intermediate PR ships
nothing a consumer vendors; all three of these touch `plugins/core/skills/`, and
CI's `version-bump` job requires a bump — correctly, since each one changes what
a consumer gets. The rule holds for stacks that refactor toward a release; it
does not fit a stack whose every step is shippable.

<!-- -->

> **✎ Notes** · `SPEC §9`
> _(your notes here — replace this line)_

