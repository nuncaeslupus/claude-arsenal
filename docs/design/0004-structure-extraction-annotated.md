# Locating and verifying extraction paths — Specification (annotated edition)

> Generated 2026-08-31. This is the document with a **note slot** after every section. Read it in any Markdown app. To annotate, replace the `_(your notes…)_` placeholder under any section. When done, send the file back — notes are acted on.

---

# 0004 Structure Extraction

## Preamble & scope

**Date**: 2026-08-31
**Status**: reviewed — open questions resolved; ready to plan
**Section**: `extract` (default off)
**Related**: `docs/design/0002-har-analysis-toolkit.md` (§ 6 decisions, § 7 out of scope)

<!-- -->

> **✎ Notes** · `SPEC · intro`
> _(your notes here — replace this line)_

## §1 Requirements

A generic tool that answers, for a document you did not produce:

1. **Where is this value?** Given a string seen on a page or in a response,
   return the paths or selectors that yield it.
2. **Will that location hold?** Given several samples, rank each candidate by
   whether it means the same thing across all of them.
3. **Does this still work?** Given a stored set of paths and a fresh sample,
   report which still resolve and what changed.

It emits generic expressions and verdicts. It does not emit any project's
connector or parser format — that translation belongs to whatever owns the
schema, which is the same line `0002 § 7` already draws.

<!-- -->

> **✎ Notes** · `SPEC §1`
> _(your notes here — replace this line)_

## §2 Problem statement

The HAR toolkit takes a capture to an endpoint and a runnable request. It stops
one step short of a scraper. After `create_repro.py` you have a request that
returns the right bytes, and you still do not know *where inside those bytes*
your data is, or whether that location survives page 2.

Every shipped tool runs **path → value**: `--json-path a.b[*].c`, `--css h1`,
`jq`. Nothing runs **value → path**. So the last step of every scraping session
is done by eye — dump a body, scroll the JSON, guess a key, try it on another
page — and the result is an unrecorded judgement that nobody can re-check when
the site moves.

That gap is worse than tedious, because the artifact it produces is a
*commitment*. A scraper encodes "the title is at `data.results[*].title`" and
then depends on it indefinitely. Today that commitment is made from a single
sample, by eye, with no record of the alternatives that were rejected and no
test that fails when it stops being true. The failure mode is silent: a site
moves a field, the selector still resolves to *something*, and the scraper
quietly collects the wrong column. Detecting that — not merely detecting a
selector that stopped resolving — is the bar this has to clear; § 5.4 sets out
how far it gets and where it stops.

**Who is affected.** Anyone building an extraction workflow against a source
they do not control. The motivating case is a job-search aggregator whose
per-site connectors are static JSON descriptors carrying JSON key paths and CSS
selectors — but nothing about the need is specific to that repo, which is the
argument for the tool living here rather than there.

**Urgency.** Planned improvement, not a blocker. The work it replaces is
currently possible, just manual, unrecorded, and unverifiable.

<!-- -->

> **✎ Notes** · `SPEC §2`
> _(your notes here — replace this line)_

### Success criteria (measurable)

| # | Criterion | Threshold |
|---|---|---|
| SC1 | Default output of every command | ≤ 4096 bytes, matching the `har` budget |
| SC2 | `locate` over a 10 MB JSON document, cold | ≤ 3 s wall, ≤ 200 MB peak RSS |
| SC3 | A candidate reported **stable** across *k* samples resolves in all *k* | no exceptions — a candidate failing any provided sample is never ranked stable |
| SC4 | Commands from a saved body to a verified descriptor | ≤ 3 |
| SC5 | `verify` against a sample where a field stopped resolving or changed arity | exits non-zero **and** names the field and the observed difference |
| SC5b | `verify` where an expression still resolves at the same arity but yields a different-shaped value | reported as **changed**, non-zero — this is the § 2 failure, and the structural checks alone do not see it |
| SC6 | A value reachable by more than one path | every candidate reported, ranked; never silently collapsed to the first |
| SC7 | Resident listing cost of the new skill | ≤ 130 tokens, matching `har` |
| SC8 | Expressions emitted by `locate` | 100 % re-resolvable by `verify` without hand-editing — the two share one grammar |

SC8 is the one that makes the rest worth having: a tool that suggests a path it
cannot itself evaluate has moved the guesswork rather than removed it. SC5b is
the one that makes it honest: without it `verify` passes on exactly the
breakage § 2 exists to catch.

<!-- -->

> **✎ Notes** · `SPEC › Success criteria (measurable)`
> _(your notes here — replace this line)_

## §3 Affected systems

| System | Role | Change |
|---|---|---|
| `plugins/core/skills/locate/` | The skill itself | New |
| `extract` section | Home for it; already default-off | Registration only |
| `plugins/core/skills/har/` | Upstream producer of the bodies this reads | **None** — coupling is via files on disk, not imports |
| `sections.json` | Shipped capability map | Regenerated by `make sync-sections` |
| `.bundle-version` + `CHANGELOG.md` | Consumer-facing release | Minor bump — a new skill |
| `context_budget.py` / `make audit` | Listing budget | Validation only; see § 6 |

**Deliberately not shared with `har`.** The obvious move is to import
`_harlib`'s decode chain and `query_har`'s `schema_of`. This spec says no: the
new skill reads files that are already decoded on disk, so it needs none of the
HAR-shaped logic, and a cross-skill import would make `extract`'s two skills
un-installable apart. The one real duplication — JSON shape summarisation, ~40
lines — is cheaper copied than coupled. Revisit only if a third consumer appears.

<!-- -->

> **✎ Notes** · `SPEC §3`
> _(your notes here — replace this line)_

## §4 Impact

| Dimension | Severity | Notes |
|---|---|---|
| Data | Low | Reads local files; writes only a descriptor the user asks for |
| API | Low | New surface, nothing existing changes |
| Performance | Low | Bounded by SC2; reverse lookup is the only new cost centre |
| User | Low | Default-off section — zero cost to anyone who does not enable it |
| Operational | Low | No infrastructure |
| **Security** | **Medium** | Inputs are untrusted documents pulled from sites the user does not control — see § 8 |
| Risk if nothing changes | Medium | The last mile of every scraping session stays manual and unverifiable; connector rot stays silent |

<!-- -->

> **✎ Notes** · `SPEC §4`
> _(your notes here — replace this line)_

## §5 The operations

Three commands. The split is by question asked, not by format — each handles
both JSON and HTML, because a session moves between them without wanting to
learn two tools.

<!-- -->

> **✎ Notes** · `SPEC §5`
> _(your notes here — replace this line)_

### §5.1 describe.py — what am I looking at

Bounded structural summary of a document: keys, types, array lengths and
repeated shapes for JSON; tag/class skeleton and repeated-block detection for
HTML. Content is summarised, never dumped — this is `query_har.py --schema`
generalised to a file that has no capture around it.

Answers "is there a list of records in here, and how deep is it" in one command,
which is the question that decides whether the endpoint is worth pursuing.

<!-- -->

> **✎ Notes** · `SPEC §5.1`
> _(your notes here — replace this line)_

### §5.2 locate.py — value → path, ranked

```
locate.py --input body.json --value "Senior Rust Engineer"
locate.py --input page.html --value "Senior Rust Engineer" --samples p1.html p2.html p3.html
```

The core new capability. Walks the document and returns every expression that
yields the value, ranked. With `--samples`, each candidate is re-evaluated
against every sample and ranked by agreement:

| Rank | Meaning |
|---|---|
| `stable` | Resolves in every sample, same arity, plausible as a field |
| `varies` | Resolves everywhere but arity or position moves between samples |
| `sample-specific` | Resolves in some samples only |
| `brittle` | Resolves, but only via a positional chain with no semantic anchor |

**Ambiguity is output, not a tiebreak** (SC6). When a value sits at three paths,
all three are printed with their ranks. Choosing is the operator's job; the tool
exists to make the choice informed, and a tool that silently picked the first
would reintroduce exactly the unrecorded judgement this replaces.

`--emit-descriptor` writes the chosen candidates out.

<!-- -->

> **✎ Notes** · `SPEC §5.2`
> _(your notes here — replace this line)_

### §5.3 verify.py — does this still hold

```
verify.py --descriptor site.json --input fresh.html
```

Per-field verdict — resolves, missing, arity changed, now ambiguous, or
**shape changed** against the witness (§ 5.4) — and a non-zero exit when any
field fails (SC5). This is the connector's regression
test, and the direct analogue of `compare_har.py` one layer down: the same
"tell me when the site moved" job, against a document instead of a capture.

<!-- -->

> **✎ Notes** · `SPEC §5.3`
> _(your notes here — replace this line)_

### §5.4 The descriptor format

Verification needs something on disk, and this is the one place the spec risks
becoming somebody's schema. The rule that keeps it from doing so is not *be as
small as possible* — an under-specified descriptor just pushes the missing parts
into every consumer, which is the duplication this tool exists to remove. The
rule is: **carry what any extraction workflow would need, carry nothing that
belongs to one.**

```json
{
  "version": 1,
  "kind": "json",
  "source": {
    "tool": "locate/1",
    "derived_from": ["p1.json", "p2.json", "p3.json"],
    "derived_at": "2026-08-31T14:00:00Z"
  },
  "record": {"expr": "data.results[*]", "arity": "many"},
  "fields": {
    "title": {
      "expr": "title",
      "type": "string",
      "arity": "one",
      "required": true,
      "witness": {"len_p50": 34, "len_p90": 61, "charset": "latin-mixed-case"},
      "alternatives": [{"expr": "header.name", "rank": "varies"}]
    }
  }
}
```

**`record` — the repeating element fields are relative to.** A page yields
*records*, and a descriptor of independent whole-document expressions cannot
guarantee that the third title belongs to the third company. Any two `many`
fields could resolve to lists of different lengths, or the same length in
different orders, and nothing would notice. Anchoring every field to a record
root makes alignment structural instead of hoped-for. This is the one addition
that is a genuine correctness fix rather than a convenience.

**`alternatives` — what `locate` ranked and the operator did not pick.** § 2's
complaint is that the choice is an unrecorded judgement; recording only the
winner fixes half of it. When the primary breaks, the runners-up and their ranks
are already on disk, which is exactly what the next session needs and would
otherwise re-derive from scratch.

**`source` — which samples this was derived from, and when.** A descriptor
ranked `stable` across three samples is a different claim from one derived from
a single page, and SC3 is unfalsifiable after the fact unless the file says
which it was.

**`type`, `required`, `witness`** — the value's type; whether absence is a
failure or an ordinary optional field, so `verify` does not cry wolf on a job
with no salary listed; and the shape signature below.

**What stays out, and why the line still holds.** No transforms, no pagination,
no auth, no request construction, no rate limits, no output mapping. Every one
of those is about *what a consumer does with a source*, and the moment one
appears here this file starts competing with the schema of whatever reads it.
Everything above is about *where the data is and whether it is still there* —
verification metadata, not extraction policy. The test for any future key is
that question, not its size.

**Why the witness is not scope creep.** `expr` and `arity` alone verify that an
expression still resolves to the right number of things — and that is not the
failure § 2 describes. When a site swaps two same-shaped fields, the expression
resolves, the arity is unchanged, and a purely structural `verify` reports
success while the scraper collects the wrong column. Shipping a tool whose
headline claim is "tell me when the site moved" that cannot see the most common
way a site moves would be worse than shipping nothing, because it would be
trusted.

The witness is a bounded *shape signature* of what the expression yielded when
the descriptor was written: type, length distribution, character-class profile.
Deliberately not the values — those are content, they rot on every ordinary
edit, and on a site behind a login they may be somebody's data.

**What it still cannot catch, stated plainly.** Two fields of genuinely
indistinguishable shape — two medium-length title-case strings — can swap and
the witness will not notice. No structural check can, short of understanding the
content, which this tool does not attempt. The witness narrows the silent-swap
window; it does not close it. `verify` therefore reports **changed** rather than
**broken** for a shape mismatch, and a clean `verify` means "nothing detectable
moved", never "the data is right". A spec that claimed otherwise would be making
the same overreach twice.

<!-- -->

> **✎ Notes** · `SPEC §5.4`
> _(your notes here — replace this line)_

## §6 Options

The real decision is HTML. JSON reverse lookup is a bounded tree walk with no
dependency question; HTML needs a DOM and a selector engine, and this repo's
shipped scripts run under **bare `python3` with no installed packages** — the
`core tests` CI job exists to prove exactly that.

| | A. Stdlib only | B. Require `lxml` | C. JSON first, HTML later |
|---|---|---|---|
| **Description** | Build the DOM with `html.parser`; emit and evaluate selectors from a grammar the tool defines | Real CSS/XPath engine | Ship JSON reverse lookup; defer HTML |
| **Selector vocabulary** | Restricted: `tag`, `.class`, `#id`, descendant, `:nth-of-type` | Full CSS | n/a |
| **Scope** | 3 scripts, ~600 lines | 3 scripts, ~400 lines + a dependency | 2 scripts, ~350 lines |
| **Effort** | Medium | Small | Small |
| **Pros** | Installs anywhere; no toolchain; matches every other shipped script | Richer selectors, less code | Smallest first step; defers the hard question |
| **Cons** | Restricted vocabulary; we own the evaluator | **Breaks the no-dependency rule** — the `core tests` job would have to stop proving what it exists to prove, for every skill, not just this one | Leaves the motivating case half-served — the job-search connectors carry CSS selectors |
| **Compatibility** | Full | Would need a documented install step | Full |

**The asymmetry that decides it**: this tool *generates* the selectors it later
evaluates. It never has to parse an arbitrary selector someone else wrote. So
the restricted vocabulary of option A is a constraint on what we emit, not a
gap in what we can handle — which is a far weaker limitation than it first
appears, and it disappears entirely for JSON.

Option B's cost is also not local. The no-dependency guarantee is a property of
the whole bundle, and spending it on one skill's convenience would be the
expensive kind of shortcut.

<!-- -->

> **✎ Notes** · `SPEC §6`
> _(your notes here — replace this line)_

## §7 Recommendation

**Option A.** Stdlib only, both formats, three scripts, in the `extract` section.

**Name**: `locate`. It names the capability that does not exist anywhere else,
which is what a description has to trigger on; `describe` and `verify` are the
supporting acts.

**First action**: a plan document with staged tasks and gates, in the same shape
as `0002-...-plan.md`.

**Budget check.** `extract` costs 386 listing chars today; a second skill of
similar size puts `--profile all` near 21 % headroom against the 8000-char cap,
still inside the ≥ 50 % *default-install* target because neither skill is in
`general`. The install genuinely close to the cap remains `python` at 31 %,
which this change does not touch.

<!-- -->

> **✎ Notes** · `SPEC §7`
> _(your notes here — replace this line)_

### Open questions — resolved on review

1. **Name** — `locate`. Settled; carried into § 3 and § 7.
2. **Descriptor scope** — widened. The brief was "everything that can be useful
   in general", which § 5.4 now implements: `record`, `alternatives`, `source`,
   `type` and `required` join `expr`, `arity` and `witness`. The generic/
   connector line moved from *smallest possible* to *anything an extraction
   workflow needs, nothing one workflow owns* — a better line, because the
   minimal version pushed the missing parts into every consumer. `record` in
   particular was a correctness gap, not a convenience.
3. **XML/CSV** — deferred, as asked. `describe` could cover both cheaply; adding
   formats without a real case is how a focused tool stops being one, and the
   decision costs nothing to revisit.

<!-- -->

> **✎ Notes** · `SPEC › Open questions — resolved on review`
> _(your notes here — replace this line)_

## §8 Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Reverse lookup blows up on a large or deeply nested document | Medium — an unusable tool at exactly the size where it is most wanted | Bounded traversal with an explicit depth and node cap, reported when hit; SC2 measures it |
| A `stable` rank that is not stable | **High — the tool's whole value is that verdict** | Rank is computed only from samples actually provided, never inferred; SC3 admits no exceptions; a single-sample run cannot return `stable` at all |
| Generated selectors are positional and break on any markup change | Medium | Semantic anchors preferred and positional chains ranked `brittle` **by name**, so a weak selector is visibly weak rather than quietly equal |
| Ambiguity silently resolved | Medium — reintroduces the unrecorded judgement this replaces | SC6: every candidate printed |
| **An untrusted document drives code execution** | **High** | Expressions are evaluated by a walker over parsed data, never `eval`, and never interpolated into a shell — the rule `0002` learned the hard way, where a hostile fixture's own header text reached a shell. No exception for "just a JSON path" |
| A path or value written to an output file escapes `--output-dir` | High | Same defence as `query_har.py --extract-body`: names flattened, destination resolved and checked inside the directory before any write |
| Two same-shaped fields swap and `verify` passes | Medium — **accepted limit**, not mitigated | The witness catches a shape change, and nothing structural catches a swap between genuinely indistinguishable shapes. Documented in § 5.4 so a clean `verify` is read as "nothing detectable moved", never as "the data is right" — an overclaimed green is worse than a known gap |
| Descriptor format grows into a connector schema | Medium — the tool stops being generic and starts competing with its consumers | § 5.4 fixes the field set; adding a key needs a spec amendment, not a patch |
| Duplication with `har` drifts | Low | ~40 lines of shape summarisation, copied deliberately (§ 3); the alternative couples two skills that must install apart |
| The skill does not earn its resident cost | Low | Default-off section; SC7 caps the listing |

<!-- -->

> **✎ Notes** · `SPEC §8`
> _(your notes here — replace this line)_

## §9 Delivery

| Stage | Contents |
|---|---|
| 1 | Skill scaffold, section registration, fixtures, `describe.py` |
| 2 | `locate.py` — JSON, single sample, ranked candidates |
| 3 | `locate.py` — HTML DOM, selector generation, `--samples` ranking |
| 4 | `verify.py`, the descriptor format, `--emit-descriptor` |
| 5 | SKILL.md, references, evals, budget check |

**Stages 1–2 are the useful minimum**: they answer "where is my value in this
JSON" for a real document, which is the half of the motivating case that is pure
gain over doing it by eye.

Authoring runs through `skill-workshop`, which the pre-edit hook enforces for
anything under `skills/`.

<!-- -->

> **✎ Notes** · `SPEC §9`
> _(your notes here — replace this line)_

