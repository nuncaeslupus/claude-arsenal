#!/usr/bin/env bash
# outline_test.sh — outline.sh must print a file's shape and not its prose.
#
# The script exists to make "follow the existing module" cheap, so the two
# things worth pinning down are that the declarations survive and that the
# bodies do not. A version that quietly dropped a `def` would send a worker
# back to reading whole files; a version that leaked docstrings would cost what
# it was written to save.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTLINE="${SCRIPT_DIR}/../skills/init/assets/bin/outline.sh"
[[ -f "${OUTLINE}" ]] || { echo "SKIP: ${OUTLINE} not found" >&2; exit 0; }

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

cat > "${tmpdir}/sample.py" <<'EOF'
"""A module whose docstring is deliberately long.

It explains at length why the design is what it is, which is exactly the prose
a worker copying a signature does not need to pay for.
"""

DEFAULT_TIMEOUT = 30
_PRIVATE_RE = "x"


def measure(path):
    """Do the thing, with a rationale nobody copying the shape needs."""
    unlikely_body_token = 1
    return unlikely_body_token


class Evidence:
    def write_evidence(self, value):
        return value
EOF

out=$(bash "${OUTLINE}" "${tmpdir}/sample.py" 2>&1) || fail "outline.sh exited non-zero: ${out}"

for want in "DEFAULT_TIMEOUT" "def measure" "class Evidence" "def write_evidence"; do
    grep -q "${want}" <<<"${out}" || fail "outline dropped '${want}': ${out}"
done

# The point of the script: bodies and prose stay out.
grep -q "unlikely_body_token" <<<"${out}" && fail "outline leaked a function body"
grep -q "deliberately long" <<<"${out}" && fail "outline leaked the docstring prose"

# Line numbers are what make the follow-up `sed -n 'START,ENDp'` possible.
grep -qE '^[0-9]+:' <<<"${out}" || fail "outline must print line numbers: ${out}"

# Cheaper than the file it summarises — the whole reason it exists.
full=$(wc -c < "${tmpdir}/sample.py")
short=$(wc -c <<<"${out}")
(( short < full )) || fail "outline (${short}B) is not smaller than the file (${full}B)"

# Shell, the other language the bundle is written in.
cat > "${tmpdir}/sample.sh" <<'EOF'
#!/usr/bin/env bash
ARSENAL_HOME="${ARSENAL_HOME:-arsenal}"
_resolve_issue() {
    local hidden_body_token=1
    echo "${hidden_body_token}"
}
EOF
out=$(bash "${OUTLINE}" "${tmpdir}/sample.sh" 2>&1)
grep -q "_resolve_issue" <<<"${out}" || fail "shell function missing from outline: ${out}"
grep -q "hidden_body_token" <<<"${out}" && fail "outline leaked a shell function body"

# A file with no structure says so, rather than returning nothing and inviting
# the caller to read it in full to find out why.
printf 'just prose\nmore prose\n' > "${tmpdir}/notes.txt"
out=$(bash "${OUTLINE}" "${tmpdir}/notes.txt" 2>&1)
grep -q "no declarations matched" <<<"${out}" || fail "a prose file must say so: ${out}"

# An unreadable path is reported, not silently skipped.
bash "${OUTLINE}" "${tmpdir}/does-not-exist.py" >/dev/null 2>&1 \
    && fail "a missing file must exit non-zero"

# No arguments prints usage rather than hanging on stdin.
bash "${OUTLINE}" >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "no arguments must exit 2 with usage"

# Several files are labelled, so a multi-file outline stays readable.
out=$(bash "${OUTLINE}" "${tmpdir}/sample.py" "${tmpdir}/sample.sh" 2>&1)
grep -q "==> ${tmpdir}/sample.py <==" <<<"${out}" || fail "multi-file output must label each file"
grep -q "_resolve_issue" <<<"${out}" || fail "multi-file output must include every file"

echo "PASS: outline_test — declarations kept, bodies and prose dropped"
