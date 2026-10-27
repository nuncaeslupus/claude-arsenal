#!/usr/bin/env bash
# reader_layout_test.sh — where the reader puts note fields, how it looks, and
# what its files are called (#505).
#
# Reported from use: note fields sat under bare headings — a `##` followed
# straight by its `###` options got a field with nothing to comment on — so they
# read as placed at random; and every reader was `spec-reader.html`, so several
# downloaded ones (and their exports) could not be told apart.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READER="${here}/../skills/init/assets/scripts/create_reader.py"
PLAN_V="${here}/../skills/design/scripts/validate_plan.py"
[[ -f "${READER}" ]] || { echo "SKIP: create_reader.py not found" >&2; exit 0; }
if python3 -c "import markdown" 2>/dev/null; then
    PY=(python3)
elif command -v uv >/dev/null 2>&1; then
    PY=(uv run --quiet --with markdown python3)
else
    echo "SKIP: no python3 with markdown, and no uv to supply it" >&2; exit 0
fi

base="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "${base}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
repo="${base}/yourproject"
mkdir -p "${repo}/status"
# Pin the clock (read as UTC) so the reader's `<YYYY-MM-DD-HHMM>` stamp is known.
export SOURCE_DATE_EPOCH=1760462100
today=$(date -u -d "@${SOURCE_DATE_EPOCH}" +%F-%H%M)
run_reader() { (cd "${repo}" && "${PY[@]}" "${READER}" "$@" 2>&1); }

cat > "${repo}/status/specification.md" <<'EOF'
# Widget Overhaul

**Revision**: 2

Intro prose.

## 1. Problem

The widget is bad.

## 2. Options

### Option A — patch it

Cheap, and it leaves the bad part in.

### Option B — rebuild it

Costly, and it removes the bad part.

---

## 3. Decisions

| Decision | Gate |
|----------|------|
| Rebuild | `p95_latency_ms <= 200` |

## Appendix

---
EOF

# --- 1: one note field per section with body text, none on a bare heading ---
out="$(run_reader --input status/specification.md --output-dir status --name "Widget Overhaul")" \
    || fail "generating the reader failed: ${out}"
html="${repo}/status/yourproject-spec-v2-${today}-reader.html"
md="${repo}/status/yourproject-spec-v2-${today}-annotated.md"
[[ -f "${html}" && -f "${md}" ]] || fail "outputs are not named <repo>-spec-v<N>-<date>: $(ls "${repo}/status")"
python3 - "${html}" <<'PY' || fail "note fields are not one per section with body text"
import sys
from html.parser import HTMLParser

class Sections(HTMLParser):
    """Per <article class="sec">: whether it has a body, and the order of body/note."""
    def __init__(self):
        super().__init__()
        self.secs, self.cur, self.depth = [], None, 0
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = (a.get("class") or "").split()
        if tag == "article" and "sec" in cls:
            self.cur = {"id": a.get("id"), "seq": []}
            self.secs.append(self.cur)
            self.depth = 1
            return
        if self.cur is None:
            return
        if tag == "article":
            self.depth += 1
        if tag == "div" and "sec-body" in cls:
            self.cur["seq"].append("body")
        if tag == "div" and "note" in cls:
            self.cur["seq"].append("note")
    def handle_endtag(self, tag):
        if self.cur is not None and tag == "article":
            self.depth -= 1
            if self.depth == 0:
                self.cur = None

p = Sections()
p.feed(open(sys.argv[1], encoding="utf-8").read())
by_id = {s["id"]: s["seq"] for s in p.secs}
heading_only = [i for i, seq in by_id.items() if "body" not in seq and "note" in seq]
assert len(heading_only) == 0, f"note_fields_on_heading_only_blocks = {len(heading_only)}: {heading_only}"
for i, seq in by_id.items():
    if "body" in seq:
        assert seq == ["body", "note"], f"{i}: expected one note after the body, got {seq}"
bare = [i for i, seq in by_id.items() if not seq]
# 2. Options (straight into its ### options) and the Appendix (only a rule) are bare.
assert len(bare) == 2, f"expected the two bare headings to carry nothing, got {bare}"
assert sum(seq.count("note") for seq in by_id.values()) == 5, by_id
PY
grep -q "0 / 5 notes" "${html}" || fail "the note counter does not count note fields"
grep -q "5 note field(s)" <<<"${out}" || fail "the run does not report its note fields: ${out}"
python3 - "${md}" <<'PY' || fail "the annotated Markdown puts a slot under a bare heading"
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.split(r"^(?=#{2,3} )", text, flags=re.M)
for b in blocks[1:]:
    head = b.splitlines()[0]
    slot = "**✎ Notes**" in b
    if head.startswith(("## §2 ", "## Appendix")):
        assert not slot, f"slot under bare heading {head!r}"
    else:
        assert b.count("**✎ Notes**") == 1, f"{head!r} has {b.count('**✎ Notes**')} slots"
PY
echo "PASS: note_fields_on_heading_only_blocks == 0; every section with body text has exactly one"

# --- 2: a seeded note on a now-bare heading keeps its field ---
key="$(python3 - "${html}" <<'PY'
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
print(re.search(r'<article class="sec l2 bare" id="([^"]+)"', html).group(1))
PY
)"
[[ -n "${key}" ]] || fail "no bare section found to seed"
printf '{"%s": "a note from an earlier revision"}\n' "${key}" > "${repo}/status/old.json"
run_reader --input status/specification.md --output-dir status --name "Widget Overhaul" \
    --notes status/old.json >/dev/null || fail "seeding failed"
grep -q "data-key=\"${key}\"" "${html}" || fail "a seeded note on a bare heading lost its field"
grep -q "a note from an earlier revision" "${md}" || fail "a seeded note on a bare heading was dropped from the Markdown"
echo "PASS: a note seeded on a bare heading is kept, not dropped"

# --- 3: the styles: measure, hierarchy, distinct notes, dark mode, phone width ---
grep -q -- "--measure:70ch" "${html}" || fail "no readable line length (~70ch)"
grep -q "max-width:var(--measure)" "${html}" || fail "prose is not held to the measure"
grep -q "prefers-color-scheme:dark" "${html}" || fail "no dark palette"
grep -q "@media(max-width:600px)" "${html}" || fail "no phone-width layout"
grep -q "h3.sec-h{font-size:1.3rem" "${html}" && grep -q "h4.sec-h{font-size:1.08rem" "${html}" \
    || fail "## and ### headings are not told apart"
grep -q "border:1.5px dashed var(--note-line)" "${html}" || fail "an empty note field does not look like one"
grep -q '<label class="note-head" for="n-' "${html}" || fail "the note heading is not the field's label"
grep -q "sec-h{[^}]*sticky" "${html}" && fail "section headings are sticky again — they cover the text under them"
echo "PASS: the reader's styles cover measure, hierarchy, note fields, dark mode and phone width"

# --- 4: Export clears the unsaved flag only on a confirmed copy ---
grep -q "dirty=false;setState('✓ Backup saved" "${html}" \
    && fail "a requested download is still counted as a saved backup"
grep -q "cp.then(function(){dirty=false;" "${html}" || fail "a confirmed clipboard copy does not clear the flag"
grep -q "Download requested" "${html}" || fail "the export does not say the download was only requested"
echo "PASS: a requested download is not reported as a saved backup"

# --- 5: earlier readers go, an annotated file with typed notes stays ---
printf '# old\n\n## A\n\n<!-- -->\n\n> **✎ Notes** · `x`\n> a hand-typed note\n' \
    > "${repo}/status/yourproject-spec-v1-2026-01-01-annotated.md"
printf '# old\n\n## A\n\n<!-- -->\n\n> **✎ Notes** · `x`\n> _(your notes here — replace this line)_\n' \
    > "${repo}/status/yourproject-spec-v1-2026-01-02-annotated.md"
echo old > "${repo}/status/yourproject-spec-v1-2026-01-01-reader.html"
echo other > "${repo}/status/yourproject-plan-v1-2026-01-01-reader.html"
run_reader --input status/specification.md --output-dir status --name "Widget Overhaul" >/dev/null \
    || fail "regenerating failed"
[[ ! -e "${repo}/status/yourproject-spec-v1-2026-01-01-reader.html" ]] || fail "a superseded reader was kept"
[[ ! -e "${repo}/status/yourproject-spec-v1-2026-01-02-annotated.md" ]] || fail "an untouched superseded annotated file was kept"
[[ -e "${repo}/status/yourproject-spec-v1-2026-01-01-annotated.md" ]] || fail "an annotated file with typed notes was deleted"
[[ -e "${repo}/status/yourproject-plan-v1-2026-01-01-reader.html" ]] || fail "another document's reader was deleted"
echo "PASS: a rebuild replaces its earlier readers and keeps anything typed into"

# --- 6: --output names the reader explicitly ---
run_reader --input status/specification.md --output "out/custom-reader.html" --name "Widget Overhaul" >/dev/null \
    || fail "--output failed"
[[ -f "${repo}/out/custom-reader.html" && -f "${repo}/out/custom-annotated.md" ]] \
    || fail "--output did not write the named reader and its Markdown: $(ls "${repo}/out" 2>&1)"
[[ -f "${html}" ]] || fail "--output removed the default-named reader elsewhere"
echo "PASS: --output overrides the generated name"

# --- 7: the review record accepts the new export name ---
printf '# Plan\n\n**Revision**: 2\n**Status**: draft\n**Revision log**:\n- r2 — applied `yourproject-plan-v1-2026-01-04-notes.md`\n\n## Technical solution\n' \
    > "${repo}/status/plan.md"
out="$(python3 "${PLAN_V}" --input "${repo}/status/plan.md" 2>&1)"
case "$out" in *"yourproject-plan-v1-2026-01-04-notes.md"*) ;; *) fail "a missing dated notes file was not flagged: $out" ;; esac
echo "PASS: the review record names dated exports"

# --- 8: block notes — a ✎ on each paragraph, item and table; seeded notes keep their quote ---
grep -q 'data-ref="SPEC §1"' "${html}" || fail "articles do not carry the label a block note takes"
grep -q 'bn-btn' "${html}" || fail "the reader has no block-note button"
printf '%s' '{"s-spec-1~abc":"Bad how?","s-spec-1~abc~q":"The widget is bad.","s-spec-1~zzz":"orphaned","s-gone~q1":"homeless"}' \
    > "${repo}/notes.json"
run_reader --input status/specification.md --output-dir blk --name "Widget Overhaul" --notes notes.json >/dev/null \
    || fail "seeding block notes failed"
md="$(cat "${repo}"/blk/*-annotated.md)"
case "$md" in *'> ¶ _“The widget is bad.”_'*'> Bad how?'*) ;; *) fail "a seeded block note lost its quote or text: ${md}" ;; esac
case "$md" in *'> ¶ _(text changed since this note)_'*'> orphaned'*) ;; *) fail "a block note with no quote was dropped" ;; esac
case "$md" in *'Unplaced notes'*'> homeless'*) ;; *) fail "a note whose section is gone was dropped from the Markdown" ;; esac
echo "PASS: block notes are seeded into the annotated Markdown with their quoted paragraph"

# The same, in a browser, where one is installed: open a note on a paragraph, reload,
# and export — the note comes back below that paragraph and the export quotes it.
if command -v node >/dev/null 2>&1 && node -e "require('playwright')" 2>/dev/null; then
    cat > "${base}/blk.js" <<'JS'
const {chromium}=require('playwright');
(async()=>{const b=await chromium.launch();const p=await (await b.newContext({acceptDownloads:true})).newPage();
 const errs=[];p.on('pageerror',e=>errs.push(e.message));
 await p.goto('file://'+process.argv[2]);
 await p.locator('#s-spec-1 .sec-body > p .bn-btn').click();await p.keyboard.type('noted here');
 await p.locator('h1').click();
 await p.locator('#s-spec-3 .bn-btn').first().click();await p.locator('h1').click();   // emptied → folds away
 await p.waitForTimeout(450);await p.reload();
 const box=await p.locator('#s-spec-1 .sec-body > p + .bnote textarea').inputValue();
 const open=await p.locator('.bnote').count();
 const [dl]=await Promise.all([p.waitForEvent('download'),p.click('#btn-export')]);
 const out=require('fs').readFileSync(await dl.path(),'utf8');
 // A note whose section is gone lands under "Unplaced notes", quote intact.
 const ns=await p.evaluate(()=>{for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);
   if(k.indexOf('~')>0)return k.slice(0,k.indexOf('s-spec-'));}return '';});
 await p.evaluate(ns=>{localStorage.setItem(ns+'s-gone~x','lost?');localStorage.setItem(ns+'s-gone~x~q','old text');},ns);
 await p.reload();
 const unplaced=await p.locator('#bn-unplaced textarea').inputValue();
 console.log(JSON.stringify({box,open,errs,quoted:out.includes('> ¶ _“The widget is bad.”_'),unplaced}));await b.close();})();
JS
    res="$(node "${base}/blk.js" "${html}" 2>&1)" || fail "block-note browser check crashed: ${res}"
    [[ "${res}" == '{"box":"noted here","open":1,"errs":[],"quoted":true,"unplaced":"lost?"}' ]] \
        || fail "block note did not survive a reload or export: ${res}"
    echo "PASS: a block note opens below its paragraph, survives a reload and exports its quote"
else
    echo "SKIP: block-note browser check — node with playwright not available" >&2
fi

echo "PASS: reader_layout_test — all gates passed"
