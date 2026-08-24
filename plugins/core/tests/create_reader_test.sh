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
grep -q "doc-spec-notes-" "${tmp}/status/spec-reader.html" \
    || fail "an empty slug did not fall back to a usable stem"

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

# --- 5: --notes pointing at nothing is an error, not a silent empty seed ---
out=$(run_reader --input status/specification.md --output-dir status --notes status/nope.md); rc=$?
[[ ${rc} -ne 0 ]] || fail "--notes with a missing file should fail loudly"

echo "PASS: create_reader_test — all gates passed"
