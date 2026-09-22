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

# Private repo/owner names that have shipped by accident before. Regexes, so
# `nuncaeslupus/claude-arsenal` — the public upstream, which shipped prose may
# legitimately name — does not trip the owner pattern.
DENY=('integral-job-search' 'nuncaeslupus/(?!claude-arsenal)')

fail=0
for name in "${DENY[@]}"; do
    # Shipped tree only: plugins/*/skills/ is what /init vendors. docs/ and
    # docs/design/ are internal, and the conversation records under
    # docs/design/notes/ are verbatim history nobody should rewrite.
    hits=$(grep -rnP --binary-files=without-match "${name}" "${REPO_ROOT}"/plugins/*/skills/ 2>/dev/null \
        | grep -v '/__pycache__/' || true)
    if [[ -n "${hits}" ]]; then
        echo "FAIL: '${name}' is a private name in the shipped tree — use a placeholder" >&2
        echo "${hits}" >&2
        fail=1
    fi
done

[[ ${fail} -eq 0 ]] || exit 1
echo "PASS: generic_examples_test — no private repo names in the shipped tree"
