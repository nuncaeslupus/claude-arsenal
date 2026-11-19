# proofsheet — Specification

> Readable copy of the specification: the document and its pictures. Generated 2026-11-19. The annotatable version is [`claude-arsenal-spec-v1-2026-11-19-1659-reader.html`](claude-arsenal-spec-v1-2026-11-19-1659-reader.html).

## Preamble & scope

**Date**: 2026-11-19
**Ticket / PR**: none yet (follows `references/helmwork.md`, PR #642)
**Author**: Claude
**Revision**: 1
**Status**: draft
**Revision log**:
- r1 — first draft

> Review record. Each round of reviewer notes makes a new revision: bump
> **Revision**, add a log line naming the export it applied, and commit that
> export beside this file in the same commit. On approval set **Status** to
> `approved (YYYY-MM-DD, revision N)`.

## §1 Problem statement

The annotatable reader (`create_reader.py`) works well for one job: a person reads a spec
or plan and leaves notes anchored to the paragraph they are about. Everything else a
person is asked to judge has no such page. Images, audio, video, diffs and competing
variants reach the person as loose files or chat text, and the notes come back as prose
written from memory, which is exactly what Helmwork's rule "comment in place, not
afterwards" forbids. Helmwork also makes evidence review a mandatory step and requires
open items to wait in the repository, not in a conversation; today a question raised in
one PR lives in that PR's body or in chat and is easily lost before the milestone that
needs it.

Three smaller defects make the existing pages feel like separate tools: the reader and the
review digest each carry their own stylesheet, the note fields on picture-heavy reader
pages use a different font from the rest of the page, and the ✎ pencil beside each
paragraph reads as "edit this text" when it means "comment on this".

The fix must stay light. A page that grows region drawing, pixel marking, audio editing or
an issue tracker is a web app in disguise; that work belongs to a separate rich review
tool outside this bundle.

**Success criteria (measurable)**:

- [ ] `proofsheet.py build MANIFEST` writes one self-contained HTML file that opens from
      disk in a current browser with no network access, for items of kind `text`, `image`,
      `audio`, `video` and `diff` (test: build a fixture manifest, assert no external URL
      in the output, load it headless and find one rendered player per media item).
- [ ] Every item has a comment field, a verdict (`fine` / `fix` / `not-a-bug`), and, when
      it has two or more versions, a side-by-side compare of any two (headless test).
- [ ] Export and import round-trip without loss: `proofsheet.py import EXPORT` returns the
      same JSON the page exported (test over a fixture with every item kind and verdict).
- [ ] One comment-and-verdict format (`review-notes v1`, §4) is written by proofsheet
      pages, the spec reader and the review digest (test: each generator's export parses
      with the same schema).
- [ ] Size budget: the shared page core (CSS + JS) is ≤ 40 KB unminified; proofsheet's own
      Python is ≤ 900 lines; no runtime dependency beyond what the reader already needs
      (`markdown`). A CI check fails the build past either number.
- [ ] One stylesheet: reader, digest and proofsheet pages embed the same
      `page-core.css`; no generator carries its own `<style>` rules beyond a page-specific
      block of ≤ 30 lines (test greps the generators).
- [ ] Note fields use the page's UI font on every page type, including picture-heavy
      readers (headless test compares computed `font-family` of a note field and a button).
- [ ] The paragraph comment control is a speech-bubble SVG icon, with an accessible label
      "Comment on this", on every page type.
- [ ] `arsenal/evidence/open.jsonl` exists as the open-items store: a PR can append items,
      the board (`query_status.py`) prints the open count and the age of the oldest, and an
      answered item moves to `arsenal/evidence/decisions.jsonl` (tests on the script).
- [ ] A milestone evidence page is built from the open-items store in one command, and
      importing its export closes the items it decided.

## §2 Systems & Impact

| System | Type | Role | Needs changes? | Impact | Severity |
|--------|------|------|----------------|--------|----------|
| `scripts/create_reader.py` | Primary | Builds spec and plan readers | Yes | Moves its CSS and note JS into the shared core; adopts the speech-bubble icon and the shared notes format; existing `…-annotated.md` export keeps working | Med |
| `scripts/digest.py` | Dependent | Builds the PR review digest | Yes | Adopts the shared stylesheet and notes format; its approve / deny / question decisions map onto the format's verdicts | Med |
| `scripts/proofsheet.py` (new) | Primary | Builds review pages from a manifest; imports exports; builds the milestone page | Yes | New script | Med |
| `scripts/open_items.py` (new) | Primary | Appends, lists, answers and closes open items | Yes | New script; small | Low |
| `assets/page-core.css`, `page-core.js` (new) | Shared resource | One look and one note/verdict behaviour for every page | Yes | Single source the generators inline at build time | Med |
| `scripts/query_status.py` | UI | The board | Yes | One extra line: open items and oldest age | Low |
| `references/annotatable-reader.md` | Docs | Rules for handing over a reader | Yes | Points to proofsheet for non-text review | Low |
| `references/helmwork.md` | Docs | The method | Small | Names the store path once it exists | Low |
| `/init` sections | Infrastructure | What a consumer installs | Yes | The `proofsheet` skill joins the default-on `workflow` section; nothing added to the always-installed tier | Low |
| Existing readers already handed out | Data | Old HTML files in host repos | No | Keep working; their exports still import | Low |

**Impact dimensions**: Data (two new JSONL files per host repo), User-facing (every review
page changes look slightly), Performance (page size grows with embedded media; see §4),
Risk of inaction (review of non-text output stays prose-from-memory; open questions keep
getting lost between PRs).

## §3 Options

### Option A: Extend the reader in place (Conservative)

- **Description**: Teach `create_reader.py` to accept media items next to Markdown
  sections, and add verdict controls to its notes.
- **Scope**: One script grows; digest untouched; open items as a separate small script.
- **Effort**: Small
- **Tradeoffs**: Quickest, but a 2,000-line script built around parsing Markdown sections
  takes on a second, unrelated input model. The stylesheet split with the digest stays.
- **Compatibility**: Full.

### Option B: Shared page core, two front ends (Recommended)

- **Description**: Extract the reader's look and note behaviour into a shared core
  (`page-core.css` + `page-core.js` + a small Python helper that inlines them and writes
  the export format). The reader becomes the front end for Markdown documents; the new
  `proofsheet.py` is the front end for item manifests; the digest adopts the core. A small
  `open_items.py` owns the store.
- **Scope**: Refactor of the reader's chrome (not its Markdown parsing), one new script,
  one new store script, digest restyle, board line.
- **Effort**: Medium
- **Tradeoffs**: More moving parts than A for the first delivery, but each later page type
  (a domain kit's viewer included) costs only its item renderer, and the look stays one.
- **Compatibility**: Old readers and their exports keep working; the new export carries the
  old Markdown plus an embedded JSON block.

### Option C: A standalone review app (Rejected by decision)

- **Description**: A served web app with regions, pixel marking, an issue list.
- **Scope**: Its own project.
- **Effort**: Large
- **Tradeoffs**: This is the rich review tool Helmwork places outside the bundle. Listed
  only to fix the boundary.
- **Compatibility**: n/a

### Comparison

| | Option A | Option B | Option C |
|---|---|---|---|
| Effort | Small | Medium | Large |
| Risk | Medium: one script doing two jobs | Low | High |
| Completeness | Partial: no shared look | Full | Beyond scope |
| Compatibility | Full | Full | n/a |
| Maintenance | Worsens with each media kind | One core, thin front ends | A second product |

## §4 Recommendation

**Recommended option**: Option B — the same small cost now buys one look and one notes
format for every page, which is what makes reviews feel like one tool.

### What proofsheet is

A skill (`proofsheet`) and a script (`scripts/proofsheet.py`):

```text
proofsheet.py build MANIFEST [--out FILE] [--link-media]   # one HTML page
proofsheet.py import EXPORT [--json]                       # notes and verdicts back as JSON
proofsheet.py milestone [--out FILE]                       # page from arsenal/evidence/open.jsonl
```

Manifest (JSON; TOML accepted):

```json
{"title": "Tavern scene, round 2",
 "items": [
   {"id": "tavern", "label": "Tavern background", "kind": "image",
    "versions": [{"label": "v1", "src": "out/tavern-v1.png"},
                 {"label": "v2", "src": "out/tavern-v2.png"}],
    "context": "Markdown shown above the item: what changed, what to look at"},
   {"id": "intro", "label": "Intro jingle", "kind": "audio",
    "versions": [{"label": "A", "src": "a.ogg"}, {"label": "B", "src": "b.ogg"}]},
   {"id": "api", "label": "CLI change", "kind": "diff", "versions": [{"src": "change.diff"}]}
 ]}
```

**Item kinds**: `text` (Markdown, with paragraph comments as in the reader), `image`,
`audio`, `video` (the browser's own `<img>`, `<audio>`, `<video>` elements), `diff`
(unified diff, coloured, side by side when wide enough). A domain kit may register one
more kind through a small renderer (e.g. pixel art at an integer zoom with its palette),
inside the same size budget.

**Per item**: a comment field, a verdict (`fine` / `fix` / `not-a-bug`), and, with two or
more versions, a compare view: two versions side by side, any pair chosen from a menu;
images also get an A/B flip in place. Text items keep paragraph comments.

**Media**: embedded as data URIs by default, so the page is one file. Past 20 MB of media
in total, `build` stops and asks for `--link-media`, which references files beside the page
instead and says so in the page header.

**Export**: the same Markdown notes file the reader writes today, plus one embedded block:

```text
<!-- review-notes {"v":1,"page":"tavern-round-2","built":"2026-11-19T17:30Z",
  "items":{"tavern":{"verdict":"fix","note":"door too small","compare":["v1","v2"],
                     "blocks":[]},
           "intro":{"verdict":"fine","note":"","blocks":[]}}} -->
```

That block is the shared **review-notes v1** format: `items` keyed by item id (for the
reader, by section key), each with `verdict` (or null), `note`, and `blocks` (paragraph
comments: `quote` + `note`). The reader writes it with `verdict: null`; the digest maps
approve / deny / question to `fine` / `fix` / a note with `verdict: null`.

### What proofsheet does not do

No regions or drawing, no pixel-level marking, no audio or video editing, no issue list
inside the page, no server, no accounts. A feature that needs one of these, or breaks the
size budget, belongs to the rich review tool.

### One look

`page-core.css` and `page-core.js` hold the tokens, type, buttons, note fields, verdict
controls, save/export/import and the speech-bubble comment icon. Every generator inlines
them at build time, so pages stay single files. Light theme first, dark through the same
tokens. Fixes on the way: note fields take the UI font on every page; the ✎ pencil
becomes a speech-bubble SVG labelled "Comment on this".

### Open items between PRs

- **Store**: `arsenal/evidence/open.jsonl`, one item per line, in Helmwork's issue format:
  `{"id","opened","pr","kind":"question|evidence","what","where","evidence":[paths],
  "severity","confidence","fix"}`. Evidence files go in `arsenal/evidence/files/<id>/`.
- **Writing**: `open_items.py add …` from any PR; the line merges with the PR, so nothing is
  lost if the conversation ends.
- **Seeing**: the board prints `open items: N (oldest Nd)`; the review digest shows the
  same count.
- **Answering**: the milestone page (or a single answer in chat, applied with
  `open_items.py answer ID --verdict … --note …`) moves the item to
  `arsenal/evidence/decisions.jsonl` with the verdict, the date and who answered. A `fix`
  verdict also prints a ready-to-queue task line; a `not-a-bug` verdict is the input that
  tunes the check that raised it.
- **Relation to the digest**: a digest question is about one PR and dies with it; an open
  item is about the product and survives until answered. A digest question the person
  wants kept is converted with one command.

**Immediate next action**: on approval, `design` writes the plan; its first task is the
review-notes v1 format and the shared page core, adopted by the reader.

**Open questions**:
- [ ] Does `proofsheet` ship in the default-on `workflow` section (recommended: yes; its
      listing costs about 40 tokens and nothing resident), or in its own default-off one?
- [ ] Is 20 MB the right point to switch to linked media, given pages are often opened on a
      phone?
- [ ] Should the decision log stay JSONL only, or also render a short Markdown summary for
      people browsing the repository?

**Decisions log**:

| ID | Decision | Status | Date |
|----|----------|--------|------|
| D-1 | Proofsheet lives in claude-arsenal as a skill and script; no new repository | agreed | 2026-11-19 |
| D-2 | Light pages only; regions, pixel zoom, editing and issue tracking go to a separate rich review tool | agreed | 2026-11-19 |
| D-3 | Only Helmwork and proofsheet are named; domain kits are sections named for their domain | agreed | 2026-11-19 |
| D-4 | Open items wait in a repository file each PR appends to, shown on the board; answers move to a decision log | agreed | 2026-11-19 |
| D-5 | One stylesheet for all bundle HTML; speech-bubble icon replaces the pencil | agreed | 2026-11-19 |


> Sections 5–6 (contracts, risks) are appended by `design`.
