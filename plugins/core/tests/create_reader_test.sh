#!/usr/bin/env bash
# create_reader_test.sh — the reader's two round-trip properties.
#
# Both defects this covers were found downstream, on a vendored copy (#219): the
# reseeding path asked for a `notes.json` that nothing produces, and a title that
# strips to nothing named the export `-spec-notes-<date>.md`. Neither is visible
# from generating a reader and looking at it — they only show on the way back in.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READER="${SCRIPT_DIR}/../skills/init/assets/scripts/create_reader.py"
[[ -f "${READER}" ]] || { echo "SKIP: create_reader.py not found" >&2; exit 0; }
# The skill documents `uv run --with markdown python3` for exactly this reason:
# `markdown` is not a project dependency. Falling straight to SKIP would leave a
# test that never runs anywhere, which is the inert-gate failure this repo keeps
# finding in other people's checks.
if python3 -c "import markdown" 2>/dev/null; then
    PY=(python3)
elif command -v uv >/dev/null 2>&1; then
    PY=(uv run --quiet --with markdown python3)
else
    echo "SKIP: no python3 with markdown, and no uv to supply it" >&2; exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

mkdir -p "${tmp}/status"
cat > "${tmp}/status/specification.md" <<'EOF'
# Widget Overhaul

Intro prose.

## Problem

The widget is bad.

## Success criteria

The widget is good.
EOF

run_reader() { (cd "${tmp}" && "${PY[@]}" "${READER}" "$@" 2>&1); }

# --- 1: the export is named for the reader, not just the document kind ---
run_reader --input status/specification.md --output-dir status --name "Widget Overhaul" >/dev/null \
    || fail "generating a reader failed"
grep -q "widget-overhaul-spec-notes-" "${tmp}/status/spec-reader.html" \
    || fail "the export filename does not carry the project slug"

# --- 2: a title that strips to nothing still names a file ---
#     `--name "项目"` left file_slug as `-spec`, and the download as
#     `-spec-notes-<date>.md` — a dotfile-adjacent name on some systems and
#     meaningless on all of them.
run_reader --input status/specification.md --output-dir status --name "项目" >/dev/null \
    || fail "generating a reader with a non-ASCII title failed"
grep -q "'-spec-notes-'" "${tmp}/status/spec-reader.html" \
    && fail "an empty slug still produces a leading-dash export name"
grep -qE "doc-[0-9a-f]{8}-spec-notes-" "${tmp}/status/spec-reader.html" \
    || fail "an empty slug did not fall back to a usable stem"

# --- 2b: and two such titles do not share that stem ---
#     A fixed `doc` named every one of them the same, so two readers exported
#     the same filename and shared a localStorage namespace: one project's
#     notes came up under another project's headings.
first=$(grep -o "doc-[0-9a-f]\{8\}-spec-notes-" "${tmp}/status/spec-reader.html" | head -1)
run_reader --input status/specification.md --output-dir status --name "項目乙" >/dev/null \
    || fail "generating a reader with a second non-ASCII title failed"
second=$(grep -o "doc-[0-9a-f]\{8\}-spec-notes-" "${tmp}/status/spec-reader.html" | head -1)
[[ -n "${first}" && -n "${second}" ]] || fail "no fallback stem found in one of the readers"
[[ "${first}" != "${second}" ]] \
    || fail "two titles that strip to nothing still share a stem: ${first}"
# ...and the stem is stable, or the notes stored under it are lost on the next run.
run_reader --input status/specification.md --output-dir status --name "項目乙" >/dev/null
[[ "$(grep -o "doc-[0-9a-f]\{8\}-spec-notes-" "${tmp}/status/spec-reader.html" | head -1)" == "${second}" ]] \
    || fail "the fallback stem changed between runs — the storage namespace would not survive"

# --- 3: seeding accepts what the page actually exports ---
#     buildExport() returns Markdown with the note data in a trailing
#     SPEC-NOTES-DATA comment. The instructions said to hand it back as
#     notes.json, which is a JSON decode error on the file the page produced.
domid=$(grep -o 'data-key="[^"]*"' "${tmp}/status/spec-reader.html" | head -1 | sed 's/data-key="//; s/"//')
[[ -n "${domid}" ]] || fail "no annotatable section found in the generated reader"
cat > "${tmp}/status/returned-export.md" <<EOF
# Specification notes

_Exported 2026-08-25 · 1 note._

## Widget Overhaul

**Problem**  \`S1\`
> the note a reviewer wrote

<!-- SPEC-NOTES-DATA
{"${domid}": "the note a reviewer wrote"}
-->
EOF
out=$(run_reader --input status/specification.md --output-dir status \
        --name "Widget Overhaul" --notes status/returned-export.md)
grep -q "seeding from" <<<"${out}" || fail "the returned export was not read as a seed: ${out}"
grep -q "the note a reviewer wrote" "${tmp}/status/spec-annotated.md" \
    || fail "the seeded note did not reach the annotated Markdown"
grep -q "the note a reviewer wrote" "${tmp}/status/spec-reader.html" \
    || fail "the seeded note did not reach the HTML reader"

# --- 4: a plain JSON object still seeds, and a bad file is reported ---
printf '{"%s": "from plain json"}\n' "${domid}" > "${tmp}/status/notes.json"
out=$(run_reader --input status/specification.md --output-dir status --name "Widget Overhaul")
grep -q "seeding from" <<<"${out}" || fail "notes.json is still the default seed: ${out}"
grep -q "from plain json" "${tmp}/status/spec-annotated.md" || fail "the JSON seed did not apply"

printf 'just prose, no notes anywhere\n' > "${tmp}/status/notes.json"
out=$(run_reader --input status/specification.md --output-dir status --name "Widget Overhaul")
grep -q "could not read" <<<"${out}" || fail "an unreadable seed file should be reported: ${out}"
grep -q "✓" <<<"${out}" || fail "an unreadable seed should not stop the reader being written: ${out}"

# --- 6: a note that quotes the export marker still round-trips ---
#     The block was matched as `{.*?}` up to a `-->`, so a note containing one
#     ended the object early; the truncated JSON read as unparseable and the
#     reviewer's notes were dropped on the way back in.
cat > "${tmp}/status/marker-export.md" <<EOF
# Specification notes

<!-- SPEC-NOTES-DATA
{"${domid}": "the block ends at } --> or so I assumed", "x": "second note"}
-->
EOF
out=$(run_reader --input status/specification.md --output-dir status \
        --name "Widget Overhaul" --notes status/marker-export.md)
grep -q "seeding from" <<<"${out}" || fail "a note quoting the marker broke the seed: ${out}"
grep -q "or so I assumed" "${tmp}/status/spec-annotated.md" \
    || fail "the note quoting the marker did not reach the annotated Markdown"

# --- 6b: a note that quotes the export MARKER still round-trips ---
#     Selection ran FORWARD from the first marker, and the first one in an
#     export is inside the reviewer's own prose — the note is embedded verbatim
#     above the data block. Decoding there failed, the export was rejected whole,
#     and the reader was regenerated without the notes it had just been handed.
cat > "${tmp}/status/quoted-marker.md" <<EOF
# Specification notes

**Problem**  \`S1\`
> I went looking for the <!-- SPEC-NOTES-DATA block

<!-- SPEC-NOTES-DATA
{"${domid}": "I went looking for the <!-- SPEC-NOTES-DATA block"}
-->
EOF
out=$(run_reader --input status/specification.md --output-dir status \
        --name "Widget Overhaul" --notes status/quoted-marker.md)
grep -q "seeding from" <<<"${out}" || fail "a note quoting the marker broke the seed: ${out}"
grep -q "went looking for" "${tmp}/status/spec-annotated.md" \
    || fail "the note quoting the marker did not survive the round trip"
# The page's own Import button parses the same file with its own scanner, and it
# had the same defect — a plain lastIndexOf lands inside that note's JSON string.
grep -q "SPEC-NOTES-DATA/gm" "${tmp}/status/spec-reader.html" \
    || fail "the in-page importer does not anchor the marker to a line start"

# --- 7: a note that is not text is reported, not raised ---
printf '{"%s": {"nested": 1}}\n' "${domid}" > "${tmp}/status/bad-types.json"
out=$(run_reader --input status/specification.md --output-dir status \
        --name "Widget Overhaul" --notes status/bad-types.json)
grep -q "Traceback" <<<"${out}" && fail "a non-string note value must not raise: ${out}"
grep -q "must be strings" <<<"${out}" || fail "a non-string note value should be named: ${out}"

# --- 8: an unreadable seed that is also the output is refused, not overwritten ---
#     `spec-annotated.md` carries no SPEC-NOTES-DATA block, so pointing --notes
#     at it always fails to parse — and continuing rewrote the very file whose
#     notes could not be read.
printf 'notes a reviewer typed straight into the annotated file\n' \
    > "${tmp}/status/spec-annotated.md"
out=$(run_reader --input status/specification.md --output-dir status \
        --name "Widget Overhaul" --notes status/spec-annotated.md); rc=$?
[[ ${rc} -ne 0 ]] || fail "overwriting an unreadable seed with this run's own output must fail"
grep -q "refusing to overwrite" <<<"${out}" || fail "the refusal should say why: ${out}"
grep -q "reviewer typed straight" "${tmp}/status/spec-annotated.md" \
    || fail "the file that could not be read was overwritten anyway"

# --- 5: --notes pointing at nothing is an error, not a silent empty seed ---
out=$(run_reader --input status/specification.md --output-dir status --notes status/nope.md); rc=$?
[[ ${rc} -ne 0 ]] || fail "--notes with a missing file should fail loudly"

# --- 6: the export names the revision it annotates (#468) ---
#     No `**Revision**` line (the spec above) keeps the old name; one adds -r<N>.
run_reader --input status/specification.md --output-dir status --name "Widget Overhaul" >/dev/null \
    || fail "regenerating the reader failed"
grep -q "widget-overhaul-spec-notes-'+today()+'.md" "${tmp}/status/spec-reader.html" \
    || fail "a spec with no Revision header should keep the unsuffixed export name"
sed -i 's/^Intro prose.$/**Revision**: 3\n\nIntro prose./' "${tmp}/status/specification.md"
run_reader --input status/specification.md --output-dir status --name "Widget Overhaul" >/dev/null \
    || fail "generating a revisioned reader failed"
grep -q "widget-overhaul-spec-notes-'+today()+'-r3.md" "${tmp}/status/spec-reader.html" \
    || fail "the export filename does not carry the spec's revision"
grep -q '<meta name="arsenal-source-sha256" content="[0-9a-f]\{64\}">' "${tmp}/status/spec-reader.html" \
    || fail "the reader does not record the digest of the source it rendered"

# --- 9: ```drawspec fences render to inline SVG (#466) ---
#     A fake drawspec via ARSENAL_DRAWSPEC, so none of this needs the network.
#     It logs every call, fails `validate` on a document containing BROKEN, and
#     renders a marked SVG.
fake="${tmp}/fake-drawspec"
calls="${tmp}/drawspec-calls.log"
cat > "${fake}" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "${calls}"
doc=\$(cat)
case "\$1" in
  validate) if grep -q BROKEN <<<"\${doc}"; then echo "/nodes/0/text: fake violation" >&2; exit 1; fi
            echo "- : a valid flow document" ;;
  render) echo '<svg xmlns="http://www.w3.org/2000/svg" data-fake="drawspec"><text>drawn</text></svg>' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "${fake}"
: > "${calls}"

#     A document with no fence never runs drawspec — it must not become a
#     dependency of every reader.
ARSENAL_DRAWSPEC="${fake}" run_reader --input status/specification.md --output-dir status \
    --name "Widget Overhaul" >/dev/null || fail "a fence-free document failed with drawspec configured"
[[ ! -s "${calls}" ]] || fail "a document with no drawspec fence invoked drawspec: $(cat "${calls}")"
ARSENAL_DRAWSPEC="${tmp}/no-such-drawspec" run_reader --input status/specification.md \
    --output-dir status --name "Widget Overhaul" >/dev/null \
    || fail "a fence-free document needed a runnable drawspec"

mkdir -p "${tmp}/diagrams"
cat > "${tmp}/diagrams/plan.md" <<'EOF'
# Diagram Plan

## Flow

Before the picture.

```drawspec
{"version": 1, "kind": "flow", "nodes": [{"id": "a", "text": "A step"}]}
```

After the picture.

## Code

```json
{"not": "a diagram"}
```
EOF
out=$(ARSENAL_DRAWSPEC="${fake}" run_reader --input diagrams/plan.md --output-dir diagrams --name demo) \
    || fail "a document with a valid drawspec fence failed: ${out}"
html="${tmp}/diagrams/plan-reader.html"
grep -q '<figure class="drawspec"><svg xmlns="http://www.w3.org/2000/svg" data-fake="drawspec">' "${html}" \
    || fail "the drawspec fence was not rendered to inline SVG"
grep -q 'DRAWSPEC-FIGURE' "${html}" && fail "a drawspec placeholder leaked into the reader"
grep -q '&quot;kind&quot;: &quot;flow&quot;' "${html}" \
    && fail "the drawspec source was shown as code instead of drawn"
grep -q '<code class="language-json">' "${html}" || fail "an ordinary JSON fence stopped rendering as code"
grep -q '^validate -$' "${calls}" || fail "drawspec validate was not run before render: $(cat "${calls}")"
[[ "$(head -1 "${calls}")" == "validate -" ]] || fail "render ran before validate: $(cat "${calls}")"
grep -q '^```drawspec$' "${tmp}/diagrams/plan-annotated.md" \
    || fail "the annotated Markdown lost the drawspec source"

#     A diagram drawspec refuses fails the run, names the block, and writes nothing.
rm -f "${html}"
sed -i 's/"A step"/"BROKEN step"/' "${tmp}/diagrams/plan.md"
out=$(ARSENAL_DRAWSPEC="${fake}" run_reader --input diagrams/plan.md --output-dir diagrams --name demo); rc=$?
[[ ${rc} -ne 0 ]] || fail "an invalid drawspec diagram did not fail the build"
grep -q "diagrams/plan.md § Flow, drawspec block 1" <<<"${out}" || fail "the failure does not name the block: ${out}"
grep -q "fake violation" <<<"${out}" || fail "drawspec's own message was not passed on: ${out}"
[[ ! -f "${html}" ]] || fail "a reader was written despite the broken diagram"

#     No runnable drawspec and a fence to draw: a loud failure, not a dropped picture.
out=$(ARSENAL_DRAWSPEC="${tmp}/no-such-drawspec" run_reader --input diagrams/plan.md \
        --output-dir diagrams --name demo); rc=$?
[[ ${rc} -ne 0 ]] || fail "a drawspec fence with no drawspec to run did not fail"
grep -q "ARSENAL_DRAWSPEC" <<<"${out}" || fail "the missing-drawspec failure does not say what to set: ${out}"
echo "PASS: drawspec fences render, validate first, fail loudly, and cost fence-free documents nothing"

#     One real render, when drawspec can be had here (PATH, or uvx and a network).
if command -v drawspec >/dev/null 2>&1 || { command -v uvx >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 && \
        timeout 180 uvx --quiet --from git+https://github.com/nuncaeslupus/drawspec drawspec --version \
        >/dev/null 2>&1; }; then
    sed -i 's/"BROKEN step"/"A step"/' "${tmp}/diagrams/plan.md"
    out=$(env -u ARSENAL_DRAWSPEC "${PY[@]}" "${READER}" --input "${tmp}/diagrams/plan.md" \
            --output-dir "${tmp}/diagrams" --name demo 2>&1) || fail "a real drawspec render failed: ${out}"
    grep -q '<figure class="drawspec"><svg[^>]*viewBox=' "${html}" \
        || fail "the real drawspec render did not land in the reader"
    echo "PASS: a real drawspec render lands in the reader"
else
    echo "SKIP: real drawspec smoke — no drawspec on PATH and no uvx/network to fetch it" >&2
fi

echo "PASS: create_reader_test — all gates passed"

# --- a storage failure must not silence the unload warning ------------------
# `save()` sets `dirty` on the SUCCESS path only. When the first
# `localStorage.setItem` throws — a private window, blocked site data — the
# catch marked storage unusable and left `dirty` false, so `beforeunload` said
# nothing and the note the reviewer had just typed was lost on navigation. The
# one place their work exists is the one place that must not fail quietly.
reader_html="$(find "$tmp" -name '*reader*.html' | head -1)"
[ -n "$reader_html" ] || reader_html="$(find "$tmp" -name 'spec-reader.html' | head -1)"
if [ -n "$reader_html" ] && [ -f "$reader_html" ]; then
    grep -q "dirty=true;lsOK=false" "$reader_html" \
        || fail "a localStorage write failure leaves dirty false — the unload warning never fires"
    echo "PASS: a storage failure still arms the unload warning"

    # And a blocked download must not be reported as a saved backup: in the
    # no-storage mode the download IS the only copy, so clearing `dirty` after
    # it failed removes the last thing standing between the reviewer and losing
    # their notes.
    grep -q "var saved=download" "$reader_html" \
        || fail "the export handler ignores download()'s result"
    grep -q "Download blocked" "$reader_html" \
        || fail "a blocked download is not reported to the reviewer"
    echo "PASS: a blocked download is reported, not counted as a backup"
fi
