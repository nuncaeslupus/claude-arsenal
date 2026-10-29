#!/usr/bin/env bash
# render_diagrams_test.sh — drawspec fences get an image GitHub can show, idempotently,
# and the HTML reader still draws each diagram once.
#
# A fake drawspec via ARSENAL_DRAWSPEC, so none of this needs the network.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SCRIPT_DIR}/../skills/init/assets/scripts"
RENDER="${SCRIPTS}/render_diagrams.py"
READER="${SCRIPTS}/create_reader.py"

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

fake="${tmp}/fake-drawspec"
cat > "${fake}" <<'EOF'
#!/usr/bin/env bash
doc=$(cat)
if grep -q BROKEN <<<"${doc}"; then echo "/nodes/0: fake violation" >&2; exit 1; fi
case "$1" in
  validate) echo "- : valid" ;;
  render) n=$(grep -o '"text": "[^"]*"' <<<"${doc}" | head -1)
          echo "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 120 40\" role=\"img\"><text fill=\"currentColor\">${n}</text></svg>" ;;
  *) exit 2 ;;
esac
EOF
chmod +x "${fake}"
export ARSENAL_DRAWSPEC="${fake}"

mkdir -p "${tmp}/status"
doc="${tmp}/status/plan.md"
cat > "${doc}" <<'EOF'
# Plan

Before.

```drawspec
{"version": 1, "kind": "flow", "title": "Build order", "nodes": [{"id": "a", "text": "One"}]}
```

<details><summary>Notes</summary>

Not a diagram.

</details>

```drawspec
{"version": 1, "kind": "flow", "nodes": [{"id": "b", "text": "Two"}]}
```

After.
EOF

# 1: --check on a fresh document reports drift and writes nothing.
python3 "${RENDER}" --check "${doc}" >/dev/null && fail "--check passed a document never rendered"
[[ -e "${tmp}/status/diagrams" ]] && fail "--check wrote files"

# 2: a run writes one SVG per fence and an image line above each, titled when it can be.
python3 "${RENDER}" "${doc}" >/dev/null || fail "render failed"
for n in 1 2; do [[ -f "${tmp}/status/diagrams/plan-${n}.svg" ]] || fail "plan-${n}.svg not written"; done
grep -qx '!\[Build order\](diagrams/plan-1.svg) <!-- drawspec-render -->' "${doc}" || fail "no titled image for block 1"
grep -qx '!\[Diagram 2\](diagrams/plan-2.svg) <!-- drawspec-render -->' "${doc}" || fail "no image for block 2"
[[ $(grep -c '^<details><summary>Diagram source</summary>$' "${doc}") -eq 2 ]] || fail "source not collapsed"
grep -q 'prefers-color-scheme:dark' "${tmp}/status/diagrams/plan-1.svg" || fail "SVG ink ignores dark mode"
grep -q 'width="120" height="40"' "${tmp}/status/diagrams/plan-1.svg" || fail "SVG has no intrinsic size"
grep -q '<summary>Notes</summary>' "${doc}" || fail "an author's own <details> was touched"

# 3: a rerun changes nothing, and --check agrees.
cp "${doc}" "${tmp}/once.md"
python3 "${RENDER}" "${doc}" >/dev/null || fail "rerun failed"
cmp -s "${doc}" "${tmp}/once.md" || fail "a rerun changed the document: $(diff "${tmp}/once.md" "${doc}")"
python3 "${RENDER}" --check "${doc}" >/dev/null || fail "--check failed a current document"

# 4: an edited diagram is drift; a removed one leaves no orphan SVG.
sed -i 's/"Two"/"Three"/' "${doc}"
python3 "${RENDER}" --check "${doc}" >/dev/null && fail "--check missed an edited diagram"
python3 - "${doc}" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"!\[Diagram 2\].*?</details>\n", "", s, flags=re.S)
open(p, "w").write(s)
PY
python3 "${RENDER}" "${doc}" >/dev/null || fail "render after removing a block failed"
[[ -e "${tmp}/status/diagrams/plan-2.svg" ]] && fail "an orphan SVG was left behind"

# 5: a block drawspec refuses fails the run and names it.
sed -i 's/"One"/"BROKEN"/' "${doc}"
out=$(python3 "${RENDER}" "${doc}" 2>&1) && fail "a refused block passed"
grep -q "drawspec block 1" <<<"${out}" || fail "the failure does not name the block: ${out}"
sed -i 's/"BROKEN"/"One"/' "${doc}"
python3 "${RENDER}" "${doc}" >/dev/null || fail "render failed after the fix"

# 6: the reader drops the image and the wrapper, draws each diagram once, keeps the
#    author's own <details>.
if python3 -c "import markdown" 2>/dev/null; then PY=(python3)
elif command -v uv >/dev/null 2>&1; then PY=(uv run --quiet --with markdown python3)
else echo "PASS (reader half skipped: no markdown)"; exit 0; fi
(cd "${tmp}" && "${PY[@]}" "${READER}" --input status/plan.md --output-dir status --name demo >/dev/null) \
    || fail "the reader failed on a rendered document"
html=$(ls "${tmp}"/status/*-reader.html | head -1)
[[ $(grep -o '<figure class="drawspec">' "${html}" | wc -l) -eq 1 ]] || fail "the reader did not draw the diagram once"
grep -q 'diagrams/plan-1.svg' "${html}" && fail "the reader kept the GitHub image"
grep -q 'Diagram source' "${html}" && fail "the reader kept the source wrapper"
grep -q 'Notes' "${html}" || fail "the reader dropped an author's own <details>"

echo "PASS: render_diagrams"
