# Plan: locating and verifying extraction paths

**Date**: 2026-08-31
**Specification**: `docs/design/0004-structure-extraction.md` (reviewed, open questions resolved)
**Prerequisite**: none — the `extract` section already exists and is already default-off

> The spec fixes *what* the three commands answer and *why* each guarantee is
> worth its cost. This plan fixes *what gets built in what order*, the two module
> boundaries the three scripts share, and the measurable gate that proves each
> stage landed. Every gate below is derived from a numbered success criterion or
> a § 8 risk; where a gate is not a number, the spec's own wording says why it
> cannot be.

---

## Technical solution

### Architecture overview

```text
plugins/core/skills/locate/         section: extract   (default OFF)
  SKILL.md                          when to reach for each command; the 3-command recipe
  references/
    expressions.md                  the expression grammar, one place
    descriptor.md                   the descriptor format, field by field
  scripts/
    _doc.py                         parse + walk JSON and HTML into one node model — no CLI
    _expr.py                        emit and evaluate expressions — no CLI
    describe.py                     bounded structural summary
    locate.py                       value -> ranked candidates, --emit-descriptor
    verify.py                       descriptor + fresh sample -> per-field verdict
  evals/
plugins/core/tests/
  locate_test.sh                    bash wrapper: CLI-level assertions, bare python3
  locate/test_*.py                  pytest: walker, grammar, ranking, witness units
  locate/fixtures/                  hand-built documents, one per problem
```

Two non-CLI modules and three commands. The split is not cosmetic — each module
exists to make one spec guarantee structural rather than hoped-for:

**`_expr.py` exists because of SC8.** The spec requires that every expression
`locate` emits is re-resolvable by `verify` without hand-editing. The only way to
guarantee that is for emission and evaluation to be one module with one grammar,
so they cannot drift into two dialects that agree on the easy cases. This is the
same argument `0002 § 5.2` made for `_filters.py`, applied to a stronger claim:
there the shared module prevented *flag* drift between siblings, here it prevents
a tool from suggesting a path it cannot itself evaluate.

**`_doc.py` exists because there are three commands and two formats.** Without a
single node model that is six code paths; with one it is three commands over one
tree. It is also where the § 8 traversal cap lives, so the bound is enforced once
rather than remembered three times.

### Module contracts

`_doc.py` — everything that touches the document itself:

| Function | Contract |
|---|---|
| `parse(data, kind) -> Node` | JSON via `json.loads`, HTML via an `html.parser` subclass. `kind` auto-detected from content, `--kind` overrides. **Never executes anything in the document** — no scripts, no entities that fetch, no `eval` (§ 8, code-execution risk). |
| `walk(node, max_depth, max_nodes) -> Iterator[Step]` | Bounded traversal. When a cap is hit it **yields a `Step` marking the cut and the caller reports it**; it never returns a short list that reads as a complete one. An unreported truncation turns "the value is not in this document" into a lie, which is worse than refusing. |
| `summarise(node, depth) -> Shape` | Types, key sets, array lengths, repeated-block detection. Content is counted, never carried. The JSON half is the 15 lines of `query_har.schema_of` copied deliberately (§ 3); the HTML half is new. |

`_expr.py` — the grammar, both directions:

| Function | Contract |
|---|---|
| `emit(steps) -> str` | A walk path to an expression string. JSON: dotted with `[i]` / `[*]`, keys needing escapes quoted. HTML: `tag`, `.class`, `#id`, descendant, `:nth-of-type` — the restricted vocabulary § 6 chose, which is a constraint on what we *emit*, not a gap in what we can handle. |
| `evaluate(expr, node) -> list[Value]` | The only evaluator. A walker over parsed data — **never `eval`, never `exec`, never interpolated into a shell**. `0002` learned that the hard way when a hostile fixture's own header text reached a shell; a JSON path from an untrusted page gets no exception. |
| `rank(candidate, samples) -> Rank` | `stable` / `varies` / `sample-specific` / `brittle`. Computed **only from samples actually provided** — with fewer than two samples `stable` is not a reachable value at all (§ 8, the high-severity risk). A positional chain with no semantic anchor ranks `brittle` **by name**, so a weak selector is visibly weak rather than quietly equal. |
| `witness(values) -> dict` | Bounded shape signature: type, length percentiles, character-class profile. **Never the values** — those are content, they rot on every ordinary edit, and behind a login they may be somebody's data. |
| `budget(lines, cap=4096) -> tuple[list[str], str]` | SC1, applied once for every command. Copied from `har` for the reason § 3 gives: `extract`'s two skills must install apart. |

**`emit` and `evaluate` are inverses, and that is a test, not a convention.**
`evaluate(emit(p), doc)` must yield exactly the node at `p`, for every node of
every fixture. That property is SC8, and it is what makes the ranked output
worth reading.

### State changes

| Artifact | Change | Notes |
|---|---|---|
| `--emit-descriptor` file | CREATE | Destination resolved and verified inside `--output-dir` before any write, names flattened — the `query_har.py --extract-body` defence, unchanged |
| The input document | never written | Asserted by a test comparing the input digest before and after every command |
| `sections.json` | REGENERATE | `make sync-sections` — a new skill in an existing section |
| Nothing else | — | No sidecar, no cache, no index. `locate` re-reads; SC2 says it can afford to |

### Technology choices

| Choice | Justification |
|---|---|
| stdlib only (`json`, `html.parser`, `re`, `unicodedata`, `hashlib`) | Option A. The no-dependency guarantee is a property of the whole bundle and the `core tests` job exists to prove it; spending it on one skill's selector convenience would be the expensive kind of shortcut |
| One node model for both formats | Three commands over one tree instead of six code paths, and one place for the traversal cap |
| No import from `har` | § 3. The two `extract` skills must be installable apart, and the real duplication is 15 lines — measured, not estimated. Cheaper copied than coupled |
| pytest for the unit layer, bash for the CLI layer | The walker, the grammar round-trip and the witness are unit problems. `make test` still discovers everything through `locate_test.sh`, which runs under bare `python3` |
| Descriptor rejects unknown top-level keys | Makes "adding a key needs a spec amendment, not a patch" (§ 8) mechanical instead of a promise |

### Out of scope

Per spec § 5.4 and § 7: transforms, pagination, auth, request construction, rate
limits, output mapping, and any project's connector format. XML and CSV are
deferred by open question 3 — cheap to add, deliberately not added without a
real case. Also out of scope for this plan: sharing anything with `har`.

---

## Implementation tasks

| T# | Description | Size | Depends | Gate | Tests |
|----|-------------|------|---------|------|-------|
| T1 | `locate` skill scaffold (SKILL.md stub + argparse stubs); `_doc.py` parse/walk/summarise; fixtures; `describe.py` | M | — | `resident_token_delta_without_extract == 0` (the `general` row stays 862 listing tokens) and `walk_cap_hits_reported == walk_cap_hits_occurred` — an unreported truncation is the failure, not the cap | `test_section_extract_still_defaults_off_with_two_skills` in `plugins/core/tests/skill_sections_test.sh` · `test_walk_reports_the_cut_rather_than_returning_a_short_list` in `locate/test_doc.py` · `test_describe_html_reports_repeated_blocks_not_content` |
| T2 | `_expr.py`: JSON grammar, `emit` + `evaluate`, escaping | L | T1 | `emit_evaluate_roundtrip_failures == 0` over **every node of every fixture** (SC8) and `dynamic_execution_nodes_in_locate_scripts == 0` — `eval`, `exec`, `compile`, `os.system` and every `subprocess` call, asserted over the parsed AST across all five scripts, not by grep in one of them | `test_every_emitted_expression_reresolves_to_its_own_node` in `locate/test_expr.py` — the SC8 property, over all fixtures · `test_key_containing_a_dot_and_a_bracket_roundtrips` · `test_no_locate_script_reaches_eval_exec_or_a_shell` — the risk says "never `eval`, and never interpolated into a shell", so the check covers both halves and every script, not the one where the paths arrive |
| T3 | `locate.py` — JSON, single sample, ranked candidates, `--json` | L | T2 | `locate_seconds_10mb <= 3` and `locate_peak_rss_mb <= 200` (SC2, CI-measured); `candidates_reported / candidates_found == 1.0` for the multi-path fixture (SC6); `stable_ranks_from_a_single_sample == 0`; `max_default_output_bytes <= 4096` (SC1) | `test_value_at_three_paths_reports_all_three_with_ranks` in `locate/test_locate.py` · `test_single_sample_can_never_rank_stable` · `test_json_output_under_budget_still_parses` — truncation drops whole candidates, never bytes |
| T4 | HTML DOM, selector generation, `--samples` cross-sample ranking | L | T3 | `stable_candidates_resolving_in_every_sample == 1.0` with **no exceptions** (SC3); `positional_only_chains_ranked_brittle == 1.0`; `emit_evaluate_roundtrip_failures == 0` for HTML too (SC8, second half) | `test_a_candidate_failing_any_sample_is_never_stable` in `locate/test_rank.py` — SC3 stated as its own test, since it is the verdict the tool's value rests on · `test_positional_chain_without_a_semantic_anchor_ranks_brittle` · `test_emitted_css_selector_reresolves_on_its_own_document` |
| T5 | `verify.py`, the § 5.4 descriptor, `--emit-descriptor`, `record` anchoring | L | T4 | `verify_exit_nonzero_on_a_broken_field == true` **and names the field and the observed difference** (SC5); `shape_change_at_unchanged_arity_reported_changed == true` (SC5b); `descriptor_roundtrip_failures == 0`; `commands_from_saved_body_to_verified_descriptor <= 3` (SC4); `files_written_outside_output_dir == 0` for the hostile-path fixture | `test_same_arity_different_shape_reports_changed_not_ok` in `locate/test_verify.py` — SC5b, the case a structural check alone passes · `test_absent_optional_field_is_not_a_failure` · `test_witness_carries_no_values_from_the_document` · `test_descriptor_with_an_unknown_top_level_key_is_refused` · `test_emit_descriptor_traversal_path_stays_inside_output_dir` |
| T6 | SKILL.md complete, `references/expressions.md` + `descriptor.md`, evals, budget check | M | T5 | `resident_listing_tokens_locate <= 130` (SC7); `locate_scripts_importing_har == 0`; `all_profile_listing_headroom >= 20%` | `test_no_locate_script_imports_from_har` in `locate/test_isolation.py` — makes § 3's install-apart claim falsifiable rather than asserted · evals `loading_verification.json` |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

### Merge order and PRs

| PR | Tasks | Spec stage | Bump |
|---|---|---|---|
| 1 | T1 | 1 | minor — new skill |
| 2 | T2, T3 | 2 | minor |
| 3 | T4 | 3 | minor |
| 4 | T5 | 4 | minor |
| 5 | T6 | 5 | minor |

Stacked in order; each rebased with `--onto` after the one below it merges.
**Every PR bumps**, for the reason recorded in `0003-capability-discovery.md`
§ 9: the stacking rule's "only the last PR bumps" assumes an intermediate PR
ships nothing a consumer vendors, and all five of these touch
`plugins/core/skills/`, where CI's `version-bump` job requires a bump —
correctly, since each changes what a consumer gets.

**PRs 1–2 are the useful minimum**, which is the spec's own § 9 line: they
answer "where is my value in this JSON" for a real document, and that is the
half of the motivating case that is pure gain over doing it by eye. If the work
stops there it stops somewhere coherent.

### Fixtures — built by hand, never captured

One file per problem, so a failure names its cause:

| Fixture | Exercises |
|---|---|
| `records.json` | A paginated API shape: `data.results[*]` with title, company, nested location — the `record` anchoring case |
| `multipath.json` | One value reachable at three distinct paths, so SC6 has something to report |
| `awkward.json` | Keys containing `.`, `[`, quotes and a newline; an empty array; a null where a string is expected; 40-level nesting for the depth cap |
| `page1.html` / `page2.html` / `page3.html` | The same listing rendered three ways: one where a class is stable, one where only position is, one where a block is absent — the four ranks each have a sample that produces them |
| `shifted.html` | Two same-shaped fields swapped relative to `page1.html`. The **accepted-limit** fixture: it pins that `verify` reports `changed` on the shape it can see and documents the swap it cannot |
| `hostile.json` / `hostile.html` | `../` and separators in a value used as a filename stem, a reserved device name, shell metacharacters, a `<script>` body, an entity that would fetch if anything resolved entities |

Hand-built because a real page carries a real session, and because each fixture
exists to make one claim in the spec falsifiable.

---

## Evidence log

`execution` appends one row per task as it lands: measured value, the exact
command, the commit SHA, and environment provenance. A gated task is not done
until its row is complete and the measured value meets the gate.

| T# | Gate | Measured | Command | Commit | Env |
|----|------|----------|---------|--------|-----|
| | | _(empty — filled as tasks land)_ | | | |

**SC2 carries a CI number, not a local one.** It is a wall-clock and peak-RSS
bound, and a laptop measurement of either says nothing about the runner a
consumer's CI uses. It follows `0002`'s benchmark provenance rule: measured on
`ubuntu-22.04` via a `workflow_dispatch` job, with the seed and document size
recorded in the row, and a regression guard at 1/10 scale on every push so a
regression is caught between benchmark runs.

**SC4 is counted, not estimated.** "Commands from a saved body to a verified
descriptor" is `describe` -> `locate --emit-descriptor` -> `verify`, which is
three by construction; the gate exists to catch a design that quietly needs a
fourth, so the row records the actual invocation list.

---

## Sign-off

- [ ] Spec § 2 success criteria SC1–SC8 each have a passing gate row — including
      both halves of SC5, since SC5b is the one that keeps `verify` honest.
- [ ] Spec § 8 risks each have either a test or an explicit accepted-risk note.
      The same-shape swap is the accepted one: `shifted.html` pins what `verify`
      does see, and § 5.4's wording is what stops a clean run being read as "the
      data is right".
- [ ] `make context-budget` `general` row unchanged — `extract` is in no
      profile, so a repo without it pays nothing for either of its skills.
- [ ] `make audit` listing headroom recorded for `--profile all` with `locate`
      installed. Expected ≈ 21 % against the 8000-char cap (5918 today, plus a
      skill of `har`'s size at 367 chars). The install genuinely close to the cap
      is still `python` at 31 %, which this change does not touch.
- [ ] `make sync-sections` run and `sections.json` committed.
- [ ] Annotations from the reader applied, or the reviewer's go-ahead recorded.
