# Plan: proofsheet — light review pages and open items

**Date**: 2026-11-19
**Specification**: `arsenal/project/proofsheet/spec.md`
**Author**: Claude
**Revision**: 1
**Status**: draft
**Revision log**:
- r1 — first draft

> Review record, kept the way the spec keeps its own: each round of notes bumps
> **Revision** with a log line naming the export it applied. Approval is
> `approved (YYYY-MM-DD, revision N)`, plus `— without annotations` when there were none.

---

## Technical solution

### Architecture overview

One shared page core and three front ends. `page_core.py` inlines `page-core.css` and
`page-core.js` into any page and writes the review-notes v1 block on export;
`review_notes.py` parses and validates that block. The spec reader, the review digest and
the new `proofsheet.py` build their own bodies and call the core for everything else. A
separate `open_items.py` owns the open-items store; `proofsheet.py milestone` reads it and
`open_items.py apply` writes verdicts back.

### Data flow

1. A front end reads its input (Markdown document, PR records, item manifest or the
   open-items store) and renders item bodies.
2. `page_core.py` wraps them with the shared CSS/JS and writes one HTML file.
3. The person comments and gives verdicts; the page autosaves locally and exports a
   Markdown notes file carrying the review-notes v1 block.
4. `proofsheet.py import` / the reader's existing import / `apply_decisions.py` read the
   block. For milestone pages, `open_items.py apply` moves decided items to the decision log.

### State changes

| Where | Store | Change | Description |
|-------|-------|--------|-------------|
| Host repo | `arsenal/evidence/open.jsonl` | CREATE/UPDATE | open items, append-only per PR |
| Host repo | `arsenal/evidence/decisions.jsonl`, `decisions.md` | CREATE/UPDATE | answered items and their readable log |
| Host repo | `arsenal/evidence/files/<id>/` | CREATE | evidence files |
| Host repo | `.gitattributes` | UPDATE | `merge=union` for the two JSONL files, written by `/init` |

### Technology choices

| Choice | Justification |
|--------|--------------|
| Plain HTML elements (`img`, `audio`, `video`) | No player code to ship or maintain; works offline |
| JSONL for the stores | Append-only lines merge cleanly; one line per item is easy to diff |
| No new dependency | `markdown` is already required by the reader |

### Out of scope

- Regions, pixel marking, audio/video editing, an in-page issue list, a server.
- Domain-kit viewers (a kit adds its own item kind later, inside the budget).
- Changing the reader's Markdown parsing or the digest's decision logic.

---

## Implementation tasks

| T# | Description | Service | Size | Depends | Gate | Tests |
|----|-------------|---------|------|---------|------|-------|
| T1 | review-notes v1: schema, write and parse the embedded block (`scripts/review_notes.py`) | core scripts | S | — | `review_notes_tests_failed == 0` | `test_roundtrip_all_fields_identical` in `plugins/core/tests/review_notes_test.py` — writing then parsing a block returns the same object; `test_unknown_keys_kept_on_import` — extra keys survive |
| T2 | Shared page core: `page-core.css`/`.js`, `page_core.py`; the reader adopts it with no behaviour change; speech-bubble icon; note fields take the UI font | core scripts | M | T1 | `reader_tests_failed == 0` | `test_reader_uses_page_core_only` in `plugins/core/tests/page_core_test.py` — the reader's `<style>` is the core plus ≤ 30 lines; `test_note_font_matches_ui_font` — headless computed fonts are equal on a picture-heavy reader; `test_comment_icon_is_bubble` — no ✎ glyph in a built page |
| T3 | Digest adopts the page core and exports review-notes v1 | core scripts | S | T2 | `digest_tests_failed == 0` | `test_digest_export_parses_as_review_notes` in `plugins/core/tests/digest_test.py` — the export validates against v1 |
| T4 | `proofsheet.py build`: manifest, item kinds, compare, verdicts, embedded or linked media | core scripts | L | T2 | `proofsheet_build_tests_failed == 0` | `test_build_all_kinds_offline` in `plugins/core/tests/proofsheet_test.py` — no external URL, one player per media item; `test_compare_any_pair` — two versions render side by side; `test_media_over_limit_links` — 21 MB of fixtures switches to linked media |
| T5 | `proofsheet.py import` and `--repo-copy` with `proofsheet-repo-media` | core scripts | M | T4 | `proofsheet_import_tests_failed == 0` | `test_import_roundtrip_every_kind` in `plugins/core/tests/proofsheet_test.py` — the page's export imports to the same object; `test_repo_media_auto_caps_at_5mb` — auto drops media past 5 MB |
| T6 | `open_items.py`: add, list, answer, apply; `decisions.md`; `merge=union` via `/init` | core scripts | M | T1 | `open_items_tests_failed == 0` | `test_answer_moves_item_to_decisions` in `plugins/core/tests/open_items_test.py` — the item leaves open.jsonl and appears in both decision files; `test_two_branches_append_merge_clean` — union merge keeps both lines |
| T7 | Board line: open items and oldest age in `query_status.py`; same count in the digest header | core scripts | S | T6, T3 | `query_status_tests_failed == 0` | `test_board_prints_open_items_line` in `plugins/core/tests/query_status_test.py` — 3 items, oldest 4 days, prints `open items: 3 (oldest 4d)` |
| T8 | `proofsheet.py milestone` from the store; `open_items.py apply` closes decided items | core scripts | M | T5, T6 | `milestone_tests_failed == 0` | `test_milestone_export_closes_items` in `plugins/core/tests/proofsheet_test.py` — two verdicts close two items, the third stays open |
| T9 | `proofsheet` skill (written with skill-workshop, `workflow` section), reader reference update, size-budget CI check, version bump | skills + CI | M | T7, T8 | `proofsheet_budget_violations == 0` | `test_budget_page_core_and_script` in `plugins/core/tests/proofsheet_budget_test.sh` — page core ≤ 40 KB and `proofsheet.py` ≤ 900 lines; `make context-budget` stays within the cap |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

**Merge order**: T1; then T2 and T6 in parallel; then T3, T4; then T5, T7; then T8; T9 last
(only T9 bumps `.bundle-version`, per the stacking rule).
**Branch pattern**: `proofsheet-T<N>-description` from the default branch

### Dependency graph

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies",
 "nodes": [
  {"id": "T1", "text": "T1\nreview-notes v1: schema, write and…"},
  {"id": "T2", "text": "T2\nShared page core: page-core.css/.js…"},
  {"id": "T3", "text": "T3\nDigest adopts the page core and exp…"},
  {"id": "T4", "text": "T4\nproofsheet.py build: manifest, item…"},
  {"id": "T5", "text": "T5\nproofsheet.py import and --repo-cop…"},
  {"id": "T6", "text": "T6\nopenitems.py: add, list, answer, ap…"},
  {"id": "T7", "text": "T7\nBoard line: open items and oldest a…"},
  {"id": "T8", "text": "T8\nproofsheet.py milestone from the st…"},
  {"id": "T9", "text": "T9\nproofsheet skill (written with skil…"}
 ],
 "edges": [
  {"from": "T1", "to": "T2"},
  {"from": "T2", "to": "T3"},
  {"from": "T2", "to": "T4"},
  {"from": "T4", "to": "T5"},
  {"from": "T1", "to": "T6"},
  {"from": "T3", "to": "T7"},
  {"from": "T6", "to": "T7"},
  {"from": "T5", "to": "T8"},
  {"from": "T6", "to": "T8"},
  {"from": "T7", "to": "T9"},
  {"from": "T8", "to": "T9"}
 ]}
```

## Evidence log

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|

---

## Sign-off

- [ ] Plan reviewed
- [ ] Ready for execution
