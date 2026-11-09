#!/usr/bin/env bash
# generic_examples_test.sh — shipped examples must not name a private repo.
#
# `claude-arsenal` is installed into arbitrary repos by arbitrary people, so an
# example naming a specific downstream project teaches a convention that is not
# the reader's. The har skill shipped a `--ua-suffix` worked example naming one
# private repo for several versions: copy it and your crawler identifies itself
# as someone else's project (#446).
#
# The distinction this enforces is provenance vs convention. Naming a repo as
# HISTORY — "a consumer's review found X in 3.6.3" — is fine and stays. Naming
# one inside an example, a default, or an instruction is not. A denylist cannot
# tell those apart, so it is deliberately narrow: the names already known to
# have leaked, checked in the tree a consumer actually receives. It catches the
# recurrence, not the first occurrence of the next name.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Private names that have shipped by accident before, stored as the sha256 of
# the lowercased name: a plain-text denylist would publish the very names it
# keeps out of the tree. Add one with `printf %s name | tr A-Z a-z | sha256sum`.
DENY_SHA256=(
    068d4106854a8a1986fb219270da129d17379da4d2dbb71e3e5caae3166c6ee2
    759f00304d1cc4809c256be08b653cc13f587dcd90373e4195ff55ba9a484867
    5562917bc9c0b7e3d6bc1bc3afd370019e01a04086ff671fa6103214eea0b24d
)
# The owner is public anyway (it is the upstream's URL), so it stays a regex:
# `nuncaeslupus/claude-arsenal` and `nuncaeslupus/drawspec`, the public tool
# specs and plans draw diagrams with, may be named; any other repo of it not.
OWNER='nuncaeslupus/(?!claude-arsenal|drawspec)'

# Shipped tree only: plugins/*/skills/ is what /init vendors. docs/ and
# docs/design/ are internal, and the conversation records under
# docs/design/notes/ are verbatim history nobody should rewrite.
SHIPPED=("${REPO_ROOT}"/plugins/*/skills/)

fail=0
hits=$(grep -rnP --binary-files=without-match --exclude-dir=__pycache__ "${OWNER}" "${SHIPPED[@]}" || true)
if [[ -n "${hits}" ]]; then
    echo "FAIL: a private repo of the upstream owner is named in the shipped tree" >&2
    echo "${hits}" >&2
    fail=1
fi

# Hash every word (letters, digits, `-`, `_`) and report the file:line of a match.
hits=$(python3 - "${DENY_SHA256[*]}" "${SHIPPED[@]}" <<'PY'
import hashlib, re, sys
from pathlib import Path
deny = set(sys.argv[1].split())
for root in sys.argv[2:]:
    for path in sorted(Path(root).rglob("*")):
        if not path.is_file() or "__pycache__" in path.parts:
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for no, line in enumerate(lines, 1):
            for word in set(re.findall(r"[\w-]+", line.lower())):
                if hashlib.sha256(word.encode()).hexdigest() in deny:
                    print(f"{path}:{no}")
PY
)
if [[ -n "${hits}" ]]; then
    echo "FAIL: a known private name is in the shipped tree — use a placeholder" >&2
    echo "${hits}" >&2
    fail=1
fi

[[ ${fail} -eq 0 ]] || exit 1
echo "PASS: generic_examples_test — no private repo names in the shipped tree"
