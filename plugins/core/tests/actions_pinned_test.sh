#!/usr/bin/env bash
# actions_pinned_test.sh — every remote GitHub Action this repo runs or ships is
# pinned to a full commit SHA. A mutable tag (`@v4`) runs whatever the tag points
# at tomorrow, with the workflow's token; tag-release.yml holds contents: write.
# Covers this repo's workflows and everything shipped under plugins/*/skills/
# (workflow templates and the YAML snippets in references). Local `./` actions
# and `docker://` refs are exempt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bad="$(cd "$ROOT" && grep -rnE '^\s*(-\s*)?uses:\s*[^./ #]' \
    .github/workflows plugins/*/skills 2>/dev/null |
    grep -vE 'uses:\s*docker://' |
    grep -vE 'uses:\s*[^ #]+@[0-9a-f]{40}(\s|$)')"
if [[ -n "$bad" ]]; then
    echo "FAIL: action not pinned to a 40-hex commit SHA:" >&2
    echo "$bad" >&2
    exit 1
fi
echo "PASS: all remote actions pinned by SHA"
