#!/usr/bin/env bash
# reader_pictures_test.sh — pictures attached to reader notes, on the Python side.
#
# A reviewer can paste a screenshot into a note; the reader then exports a .zip of
# the notes Markdown plus `<base>-img/NN.ext`, mapped to their notes by a
# SPEC-NOTES-PICTURES block. This pins what `create_reader.py` does with that
# export: `--notes` takes the .zip (or the unzipped .md beside its `-img/`),
# seeds the rebuilt reader with the pictures, and `--bake` writes them as files
# under the note they belong to. It also pins that a 5.33.1 export, which has no
# pictures, still seeds. The browser half is reader_pictures_browser.js.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READER="${here}/../skills/init/assets/scripts/create_reader.py"
OLD_EXPORT="${here}/fixtures/yourproject-spec-v1-2026-11-22-1222-notes.md"
[[ -f "${READER}" ]] || { echo "FAIL: create_reader.py not found" >&2; exit 1; }
if python3 -c "import markdown" 2>/dev/null; then
    PY=(python3)
elif command -v uv >/dev/null 2>&1; then
    PY=(uv run --quiet --with markdown python3)
else
    [[ -n "${CI:-}" ]] && { echo "FAIL: no markdown in CI; the reader would go untested" >&2; exit 1; }
    echo "SKIP: no python3 with markdown, and no uv to supply it" >&2; exit 0
fi

base="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "${base}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
repo="${base}/yourproject"
mkdir -p "${repo}/status"
git init -q "${repo}"
run_reader() { (cd "${repo}" && "${PY[@]}" "${READER}" "$@" 2>&1); }

cat > "${repo}/status/specification.md" <<'EOF'
# Widget Overhaul

**Revision**: 2

## 1. Problem

The widget is bad.

It breaks on Tuesdays.

## 2. Options

Patch it or rebuild it.
EOF

# An export as the reader writes it: a section note with a picture, a block note
# that is only a picture, zipped with its pictures.
python3 - "${base}" <<'EOF'
import json, struct, sys, zipfile, zlib
from pathlib import Path
out = Path(sys.argv[1])
def png(rgb):
    raw = b"".join(b"\x00" + bytes(rgb) * 4 for _ in range(4))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
b = "yourproject-spec-v2-2026-11-22-1300-notes"
pics = {"s-spec-1": [f"{b}-img/01.png"], "s-spec-1~zzz": [f"{b}-img/02.png"]}
data = {"s-spec-1": "See the screenshot.", "s-spec-1~zzz": "", "s-spec-1~zzz~q": "It breaks on Tuesdays."}
md = "\n".join(["# Specification notes", "", "<!-- SPEC-NOTES-DOC yourproject-spec-v2 -->",
                "<!-- SPEC-NOTES-PICTURES", json.dumps(pics), "-->",
                "<!-- SPEC-NOTES-DATA", json.dumps(data), "-->"])
with zipfile.ZipFile(out / f"{b}.zip", "w") as z:
    z.writestr(f"{b}.md", md)
    z.writestr(f"{b}-img/01.png", png((255, 0, 0)))
    z.writestr(f"{b}-img/02.png", png((0, 0, 255)))
unz = out / "unzipped"
unz.mkdir()
with zipfile.ZipFile(out / f"{b}.zip") as z:
    z.extractall(unz)
(out / "secret.png").write_bytes(png((0, 255, 0)))
(unz / "escape.md").write_text(md.replace(f"{b}-img/01.png", "../secret.png"), encoding="utf-8")
EOF
zip="${base}/yourproject-spec-v2-2026-11-22-1300-notes.zip"
unzipped_md="${base}/unzipped/yourproject-spec-v2-2026-11-22-1300-notes.md"

# 1. --notes takes the .zip and seeds the rebuilt reader with its pictures.
out=$(run_reader --input status/specification.md --output-dir status --notes "${zip}" --no-markdown) \
    || fail "--notes <.zip> failed: ${out}"
grep -q "2 picture(s)" <<<"${out}" || fail "seeding did not count the pictures: ${out}"
html=$(ls "${repo}"/status/*-reader.html)
grep -q 'SPEC_SEED_PICTURES={"s-spec-1": \["data:image/png;base64,' "${html}" \
    || fail "the rebuilt reader does not carry the section note's picture"
grep -q '"s-spec-1~zzz": \["data:image/png;base64,' "${html}" \
    || fail "a block note holding only a picture lost it"

# 2. --bake writes each picture as a file under the note it belongs to.
out=$(run_reader --input status/specification.md --output-dir status --notes "${zip}" --bake) \
    || fail "--bake with a .zip failed: ${out}"
reviewed=$(ls "${repo}"/status/*-reviewed.md)
rel=$(grep -o '!\[note picture 1\]([^)]*)' "${reviewed}" | head -1 | sed 's/.*(\(.*\))/\1/')
[[ -n "${rel}" && -s "${repo}/status/${rel}" ]] || fail "reviewed copy has no picture file under its note: ${rel:-none}"
[[ $(grep -c '!\[note picture 1\]' "${reviewed}") -eq 2 ]] \
    || fail "the picture-only block note is missing from the reviewed copy"
grep -q 'data:image' "${reviewed}" && fail "the reviewed .md inlines a picture as base64"

# 3. An unzipped export seeds too: pictures resolve beside the .md.
out=$(run_reader --input status/specification.md --output-dir "${base}/u" --notes "${unzipped_md}" --no-markdown) \
    || fail "--notes <unzipped .md> failed: ${out}"
grep -q "2 picture(s)" <<<"${out}" || fail "the unzipped export's pictures were not found: ${out}"

# 4. A path outside the export's folder is never read; it is named as missing.
out=$(run_reader --input status/specification.md --output-dir "${base}/e" --notes "${base}/unzipped/escape.md" --no-markdown) \
    || fail "--notes with an escaping path failed outright: ${out}"
grep -q "picture ../secret.png .* was not found" <<<"${out}" || fail "an escaping path was not refused: ${out}"
grep -q "1 picture(s)" <<<"${out}" || fail "the other picture should still seed: ${out}"

# 5. A 5.33.1 export (no pictures) seeds a later revision; the note whose section
#    is gone is kept under "Unplaced notes", not dropped.
out=$(run_reader --input status/specification.md --output-dir "${base}/old" --notes "${OLD_EXPORT}") \
    || fail "a 5.33.1 export no longer seeds: ${out}"
grep -q "(4 notes)" <<<"${out}" || fail "the 5.33.1 export was not read whole: ${out}"
ann=$(ls "${base}"/old/*-annotated.md)
grep -q "Section note on problem." "${ann}" || fail "the section note did not carry over"
grep -q "Block note on Tuesdays" "${ann}" || fail "the block note did not carry over"
reader_md=$(ls "${base}"/old/*-reader.md)
grep -A6 "Unplaced notes" "${reader_md}" | grep -q "Note on a section that will vanish" \
    || fail "the note on a removed section was dropped"

echo "PASS: reader pictures — .zip and unzipped seeding, reviewed-copy files, path confinement, 5.33.1 export"
